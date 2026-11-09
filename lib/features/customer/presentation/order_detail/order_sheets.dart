import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';
import '../../domain/order_rules.dart';
import '../labels.dart';
import '../widgets/customer_widgets.dart';

/// Mở một bottom sheet biểu mẫu; trả về true nếu thao tác thành công.
Future<bool> showActionSheet(BuildContext context, Widget child) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child)),
      ),
    ) ??
    false;

class _Form extends StatefulWidget {
  const _Form({required this.title, required this.children, required this.submitLabel, required this.onSubmit, this.danger = false});
  final String title, submitLabel;
  final List<Widget> children;
  final Future<bool> Function() onSubmit;
  final bool danger;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      SectionTitle(widget.title),
      const SizedBox(height: 12),
      ...widget.children,
      const SizedBox(height: 16),
      PrimaryButton(
        widget.submitLabel,
        busy: _busy,
        onPressed: () async {
          setState(() => _busy = true);
          final ok = await widget.onSubmit();
          if (!context.mounted) return;
          setState(() => _busy = false);
          if (ok) Navigator.pop(context, true);
        },
      ),
    ],
  );
}

Widget _gap() => const SizedBox(height: 12);

/* ------------------------------------------------------------ Huỷ đơn (UC-CUS-29) */
class CancelOrderSheet extends StatefulWidget {
  const CancelOrderSheet({super.key, required this.api, required this.order});
  final CustomerApi api;
  final OrderDetail order;
  @override
  State<CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<CancelOrderSheet> {
  late final Future<List<LookupItem>> _reasons = widget.api.cancellationReasons();
  String? _code;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final paid = o.paymentMethod == 'PayOS' && o.paymentStatus == 'Paid';
    return _Form(
      title: 'Huỷ đơn ${o.code}',
      submitLabel: 'Xác nhận huỷ',
      danger: true,
      onSubmit: () async {
        if (_code == null) {
          showSnack(context, 'Chọn lý do huỷ.', error: true);
          return false;
        }
        if (_code == 'OTHER' && _reason.text.trim().isEmpty) {
          showSnack(context, 'Ghi rõ lý do khi chọn "Khác".', error: true);
          return false;
        }
        return runAction(
          context,
          () => widget.api.cancelOrder(o.id, _code!, _reason.text.trim()),
          success: 'Đã huỷ đơn ${o.code}.${paid ? ' Yêu cầu hoàn 100% đã gửi tới Admin.' : ''}',
        );
      },
      children: [
        Notice(
          'Huỷ miễn phí khi đơn đang tìm tài xế hoặc tài xế đã nhận (GB-22).'
          '${paid ? ' Đơn đã thanh toán sẽ được hoàn 100% (${money(o.totalFee)}) sau khi Admin duyệt.' : ''}',
          icon: 'info',
        ),
        _gap(),
        FutureBuilder<List<LookupItem>>(
          future: _reasons,
          builder: (_, snap) => DropdownButtonFormField<String>(
            initialValue: _code,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Lý do huỷ'),
            items: [for (final r in snap.data ?? const <LookupItem>[]) DropdownMenuItem(value: r.code, child: Text(r.name))],
            onChanged: (v) => setState(() => _code = v),
          ),
        ),
        _gap(),
        TextField(controller: _reason, maxLength: 500, decoration: InputDecoration(labelText: _code == 'OTHER' ? 'Ghi rõ lý do *' : 'Ghi chú thêm')),
      ],
    );
  }
}

/* ------------------------------------------------------------ Từ chối ảnh lấy hàng (UC-CUS-12) */
class RejectPickupSheet extends StatefulWidget {
  const RejectPickupSheet({super.key, required this.api, required this.order});
  final CustomerApi api;
  final OrderDetail order;
  @override
  State<RejectPickupSheet> createState() => _RejectPickupSheetState();
}

class _RejectPickupSheetState extends State<RejectPickupSheet> {
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Form(
    title: 'Từ chối ảnh lấy hàng',
    submitLabel: 'Gửi từ chối',
    onSubmit: () async {
      if (_reason.text.trim().isEmpty) {
        showSnack(context, 'Nêu lý do để tài xế chụp lại.', error: true);
        return false;
      }
      return runAction(context, () => widget.api.reviewPickup(widget.order.id, approve: false, reason: _reason.text.trim()), success: 'Đã từ chối ảnh. Tài xế sẽ chụp lại.');
    },
    children: [
      Notice('Lần gửi ảnh thứ ${widget.order.proof?.submissionCount ?? 1}/5. Sau lần từ chối thứ 5, tài xế phải báo sự cố (GB-11).', icon: 'warning', peach: true),
      _gap(),
      TextField(
        controller: _reason,
        maxLines: 3,
        maxLength: 500,
        decoration: const InputDecoration(labelText: 'Lý do từ chối', hintText: 'VD: Ảnh mờ, thiếu thùng hàng số 2…'),
      ),
    ],
  );
}

/* ------------------------------------------------------------ Khiếu nại (UC-CUS-21/22) */
class ComplaintSheet extends StatefulWidget {
  const ComplaintSheet({super.key, required this.api, required this.order});
  final CustomerApi api;
  final OrderDetail order;
  @override
  State<ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<ComplaintSheet> {
  late final Future<List<LookupItem>> _reasons = widget.api.complaintReasons();
  String? _code;
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  List<String> _photos = const [];

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return _Form(
      title: 'Khiếu nại đơn ${o.code}',
      submitLabel: 'Gửi khiếu nại',
      onSubmit: () async {
        final amount = int.tryParse(_amount.text) ?? 0;
        if (_code == null) {
          showSnack(context, 'Chọn lý do khiếu nại.', error: true);
          return false;
        }
        if (_code == 'OTHER' && _reason.text.trim().isEmpty) {
          showSnack(context, 'Mô tả lý do khi chọn "Khác".', error: true);
          return false;
        }
        if (amount <= 0 || amount > o.totalFee) {
          showSnack(context, 'Số tiền yêu cầu từ 1đ đến ${money(o.totalFee)}.', error: true);
          return false;
        }
        return runAction(
          context,
          () => widget.api.submitComplaint(orderId: o.id, reasonCode: _code!, reason: _reason.text.trim(), evidenceUrls: _photos, requestedAmount: amount),
          success: 'Đã gửi khiếu nại. Điều phối viên sẽ xem xét.',
        );
      },
      children: [
        Notice(
          'Khiếu nại trong 24 giờ sau khi giao (GB-18). Khi khiếu nại đang mở, đơn chưa hoàn tất.'
          '${o.paymentMethod == 'Cash' ? ' Đơn tiền mặt: tranh chấp tiền xử lý ngoài hệ thống.' : ''}',
          icon: 'info',
        ),
        _gap(),
        FutureBuilder<List<LookupItem>>(
          future: _reasons,
          builder: (_, snap) => DropdownButtonFormField<String>(
            initialValue: _code,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Lý do khiếu nại'),
            items: [for (final r in snap.data ?? const <LookupItem>[]) DropdownMenuItem(value: r.code, child: Text(r.name))],
            onChanged: (v) => setState(() => _code = v),
          ),
        ),
        _gap(),
        TextField(controller: _reason, maxLines: 3, maxLength: 1000, decoration: InputDecoration(labelText: _code == 'OTHER' ? 'Mô tả chi tiết *' : 'Mô tả chi tiết')),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'Số tiền yêu cầu hoàn (tối đa ${money(o.totalFee)})'),
        ),
        _gap(),
        PhotoPicker(label: 'Ảnh bằng chứng', urls: _photos, max: OrderRules.maxEvidencePhotos, upload: widget.api.upload, onChanged: (p) => setState(() => _photos = p)),
      ],
    );
  }
}

/* ------------------------------------------------------------ Báo sự cố (UC-CUS-15) */
class IncidentSheet extends StatefulWidget {
  const IncidentSheet({super.key, required this.api, required this.order});
  final CustomerApi api;
  final OrderDetail order;
  @override
  State<IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<IncidentSheet> {
  String _type = 'Other';
  final _desc = TextEditingController();
  List<String> _photos = const [];

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Form(
    title: 'Báo sự cố – ${widget.order.code}',
    submitLabel: 'Gửi báo cáo',
    onSubmit: () async {
      if (_desc.text.trim().isEmpty) {
        showSnack(context, 'Vui lòng mô tả sự cố.', error: true);
        return false;
      }
      return runAction(
        context,
        () => widget.api.reportIncident(orderId: widget.order.id, type: _type, description: _desc.text.trim(), photoUrls: _photos),
        success: 'Đã gửi báo cáo sự cố. Điều phối viên sẽ xử lý.',
      );
    },
    children: [
      const Notice('Từ khi tài xế đến điểm lấy, bạn không tự huỷ được đơn. Điều phối viên sẽ quyết định tiếp tục, đổi tài xế hoặc huỷ.', icon: 'info'),
      _gap(),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in incidentTypeLabel.entries) ChoiceChip(label: Text(e.value), selected: _type == e.key, onSelected: (_) => setState(() => _type = e.key)),
        ],
      ),
      _gap(),
      TextField(controller: _desc, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Mô tả sự cố')),
      PhotoPicker(label: 'Ảnh minh chứng', urls: _photos, max: OrderRules.maxEvidencePhotos, upload: widget.api.upload, onChanged: (p) => setState(() => _photos = p)),
    ],
  );
}

/* ------------------------------------------------------------ Hoàn tiền cho sự cố (UC-CUS-17/18) */
class IncidentRefundSheet extends StatefulWidget {
  const IncidentRefundSheet({super.key, required this.api, required this.order, required this.incident});
  final CustomerApi api;
  final OrderDetail order;
  final MyIncident incident;
  @override
  State<IncidentRefundSheet> createState() => _IncidentRefundSheetState();
}

class _IncidentRefundSheetState extends State<IncidentRefundSheet> {
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  List<String> _photos = const [];

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Form(
    title: 'Yêu cầu hoàn tiền – sự cố #${widget.incident.id}',
    submitLabel: 'Gửi yêu cầu',
    onSubmit: () async {
      final amount = int.tryParse(_amount.text) ?? 0;
      if (_reason.text.trim().isEmpty) {
        showSnack(context, 'Nêu lý do yêu cầu hoàn tiền.', error: true);
        return false;
      }
      if (amount <= 0 || amount > widget.order.totalFee) {
        showSnack(context, 'Số tiền từ 1đ đến ${money(widget.order.totalFee)}.', error: true);
        return false;
      }
      return runAction(
        context,
        () => widget.api.requestIncidentRefund(incidentId: widget.incident.id, reason: _reason.text.trim(), evidenceUrls: _photos, requestedAmount: amount),
        success: 'Đã gửi yêu cầu hoàn tiền.',
      );
    },
    children: [
      const Notice('Chỉ áp dụng đơn PayOS đã thanh toán. Số được duyệt không vượt số bạn yêu cầu (GB-42).', icon: 'info'),
      _gap(),
      TextField(controller: _reason, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Lý do')),
      TextField(
        controller: _amount,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: 'Số tiền yêu cầu (tối đa ${money(widget.order.totalFee)})'),
      ),
      _gap(),
      PhotoPicker(label: 'Ảnh bằng chứng', urls: _photos, max: OrderRules.maxEvidencePhotos, upload: widget.api.upload, onChanged: (p) => setState(() => _photos = p)),
    ],
  );
}

/* ------------------------------------------------------------ Trả lời Dispatcher (GB-43) */
class ReplyInfoSheet extends StatefulWidget {
  const ReplyInfoSheet({super.key, required this.api, required this.refund});
  final CustomerApi api;
  final MyRefund refund;
  @override
  State<ReplyInfoSheet> createState() => _ReplyInfoSheetState();
}

class _ReplyInfoSheetState extends State<ReplyInfoSheet> {
  final _reply = TextEditingController();
  List<String> _photos = const [];

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = (OrderRules.maxEvidencePhotos - widget.refund.evidenceUrls.length).clamp(0, 5);
    return _Form(
      title: 'Bổ sung thông tin',
      submitLabel: 'Gửi trả lời',
      onSubmit: () async {
        if (_reply.text.trim().isEmpty) {
          showSnack(context, 'Nhập câu trả lời.', error: true);
          return false;
        }
        return runAction(context, () => widget.api.replyRefund(widget.refund.id, _reply.text.trim(), _photos), success: 'Đã gửi thông tin bổ sung.');
      },
      children: [
        if (widget.refund.infoRequestNote != null) Notice('Điều phối viên hỏi: ${widget.refund.infoRequestNote}', icon: 'info', peach: true),
        _gap(),
        TextField(controller: _reply, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Câu trả lời')),
        if (room > 0)
          PhotoPicker(label: 'Ảnh bổ sung', urls: _photos, max: room, upload: widget.api.upload, onChanged: (p) => setState(() => _photos = p))
        else
          Text('Đã đủ 5 ảnh bằng chứng.', style: appText(size: 12, color: AppColors.muted)),
      ],
    );
  }
}

/* ------------------------------------------------------------ Đánh giá (UC-CUS-25) */
class RatingSheet extends StatefulWidget {
  const RatingSheet({super.key, required this.api, required this.order});
  final CustomerApi api;
  final OrderDetail order;
  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  int _stars = 5;
  final _comment = TextEditingController();
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Form(
    title: 'Đánh giá chuyến ${widget.order.code}',
    submitLabel: 'Gửi đánh giá',
    onSubmit: () => runAction(context, () => widget.api.rate(widget.order.id, _stars, _comment.text.trim()), success: 'Cảm ơn bạn đã đánh giá!'),
    children: [
      if (widget.order.driver != null) Text('Tài xế: ${widget.order.driver!.fullName}', textAlign: TextAlign.center, style: appText(color: AppColors.secondary)),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var n = 1; n <= 5; n++)
            IconButton(
              tooltip: '$n sao',
              iconSize: 38,
              onPressed: () => setState(() => _stars = n),
              icon: Icon(n <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.amber),
            ),
        ],
      ),
      TextField(controller: _comment, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Nhận xét')),
      Text('Mỗi đơn đánh giá 1 lần, không sửa được, trong 1 ngày sau khi hoàn thành (GB-20).', style: appText(size: 11.5, color: AppColors.muted)),
    ],
  );
}

/* ------------------------------------------------------------ Thanh toán PayOS (UC-CUS-27) */
/// Tạo phiên PayOS (platform=App), mở trang thanh toán ngoài app, đếm ngược 10 phút.
/// Trạng thái "đã trả" chỉ tin webhook → [onCheck] tải lại đơn, trả về true nếu Paid.
class PayOsSheet extends StatefulWidget {
  const PayOsSheet({super.key, required this.api, required this.order, required this.onCheck});
  final CustomerApi api;
  final OrderDetail order;
  final Future<bool> Function() onCheck;
  @override
  State<PayOsSheet> createState() => _PayOsSheetState();
}

class _PayOsSheetState extends State<PayOsSheet> {
  PaymentSession? _session;
  String? _error;
  bool _creating = false, _checking = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _create();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => (_creating = true, _error = null));
    try {
      final s = await widget.api.createPayment(widget.order.id);
      if (mounted) setState(() => _session = s);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _open() async {
    final url = _session?.checkoutUrl;
    if (url == null) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'Không mở được trang thanh toán.', error: true);
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final paid = await widget.onCheck();
    if (!mounted) return;
    setState(() => _checking = false);
    if (paid) {
      showSnack(context, 'Đã nhận thanh toán. Đơn đang được gửi tới tài xế.');
      Navigator.pop(context, true);
    } else {
      showSnack(context, 'Chưa nhận được xác nhận từ PayOS. Nếu vừa chuyển khoản, đợi vài giây rồi kiểm tra lại.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final left = s == null ? Duration.zero : s.expiresAt.difference(DateTime.now());
    final expired = s != null && left.isNegative;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionTitle('Thanh toán PayOS – ${widget.order.code}'),
        const SizedBox(height: 12),
        if (_error != null) Notice(_error!, icon: 'warning', peach: true),
        if (_creating && s == null) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (s != null) ...[
          AppCard(
            color: AppColors.pale,
            child: Column(
              children: [
                Text('SỐ TIỀN CẦN THANH TOÁN', style: appText(size: 11, weight: FontWeight.w700, color: AppColors.secondary)),
                const SizedBox(height: 4),
                Text(money(s.amount), style: appText(size: 28, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  expired ? 'Mã đã hết hạn' : 'Mã hết hạn sau ${countdown(left)}',
                  style: appText(size: 13, weight: FontWeight.w700, color: expired ? AppColors.red : AppColors.amber),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!expired)
            PrimaryButton('Mở trang thanh toán PayOS', icon: 'qr-code', onPressed: _open)
          else
            const Notice('Mã cũ không còn nhận chuyển khoản. Hãy tạo mã mới cho cùng đơn.', icon: 'warning', peach: true),
        ],
        const SizedBox(height: 10),
        Text(
          'Đơn chỉ hiện cho tài xế sau khi PayOS xác nhận (GB-31). Mỗi mã sống 10 phút; đơn chưa thanh toán sau 30 phút sẽ tự huỷ (GB-13).',
          style: appText(size: 11.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _creating ? null : _create, child: const Text('Tạo mã mới'))),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: s == null || _checking ? null : _check,
                child: Text(_checking ? 'Đang kiểm tra…' : 'Đã thanh toán – kiểm tra'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Mở Google Maps (app hoặc web) chỉ đường – không cần API key.
Future<void> openDirections(BuildContext context, GeoPoint to, {GeoPoint? from}) async {
  final params = {
    'api': '1',
    'destination': '${to.latitude},${to.longitude}',
    if (from != null) 'origin': '${from.latitude},${from.longitude}',
  };
  final ok = await launchUrl(Uri.https('www.google.com', '/maps/dir/', params), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'Không mở được bản đồ.', error: true);
}

/// Gọi điện.
Future<void> callPhone(BuildContext context, String phone) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
  if (!ok && context.mounted) showSnack(context, 'Không gọi được $phone.', error: true);
}

/// Nhãn dùng chung trong chi tiết đơn.
Tone refundTone(String status) => toneOf(refundStatusTone, status);
