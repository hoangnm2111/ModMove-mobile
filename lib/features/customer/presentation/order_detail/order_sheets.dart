import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/notice_banner.dart';
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
        child: SafeArea(
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child),
        ),
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

/// Ô nhập tài khoản nhận hoàn tiền: chọn ngân hàng (lookups/banks), số tài khoản, chủ tài khoản.
class _PayoutFields extends StatefulWidget {
  const _PayoutFields({required this.api, required this.controller});
  final CustomerApi api;
  final _PayoutController controller;
  @override
  State<_PayoutFields> createState() => _PayoutFieldsState();
}

class _PayoutController {
  String? bankCode;
  final number = TextEditingController();
  final holder = TextEditingController();
  void dispose() {
    number.dispose();
    holder.dispose();
  }

  /// null nếu hợp lệ, ngược lại là câu báo lỗi.
  String? validate() => PayoutAccountInput.validate(bankCode: bankCode, number: number.text, holder: holder.text);

  PayoutAccountInput get input => PayoutAccountInput(bankCode: bankCode!, accountNumber: number.text, accountHolder: holder.text.trim());
}

class _PayoutFieldsState extends State<_PayoutFields> {
  late final Future<List<LookupItem>> _banks = widget.api.banks();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Tài khoản nhận tiền hoàn', style: appText(size: 14, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      FutureBuilder<List<LookupItem>>(
        future: _banks,
        builder: (_, snap) => DropdownButtonFormField<String>(
          initialValue: widget.controller.bankCode,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ngân hàng'),
          items: [for (final b in snap.data ?? const <LookupItem>[]) DropdownMenuItem(value: b.code, child: Text(b.name))],
          onChanged: (v) => setState(() => widget.controller.bankCode = v),
        ),
      ),
      TextField(
        controller: widget.controller.number,
        keyboardType: TextInputType.number,
        maxLength: 19,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Số tài khoản (6 đến 19 chữ số)'),
      ),
      TextField(
        controller: widget.controller.holder,
        textCapitalization: TextCapitalization.characters,
        maxLength: 100,
        onChanged: (v) {
          final n = PayoutAccountInput.normalizeHolder(v);
          if (n != v) {
            widget.controller.holder.value = TextEditingValue(
              text: n,
              selection: TextSelection.collapsed(offset: n.length),
            );
          }
        },
        decoration: const InputDecoration(labelText: 'Chủ tài khoản (chữ in hoa, không dấu)'),
      ),
      Text('Hệ thống chỉ hiển thị lại 4 số cuối. Quản trị viên dùng thông tin này để chuyển khoản hoàn tiền.', style: appText(size: 11, color: AppColors.muted)),
    ],
  );
}

/// Khai hoặc sửa tài khoản nhận hoàn tiền cho một khoản hoàn đã gửi.
class PayoutAccountSheet extends StatefulWidget {
  const PayoutAccountSheet({super.key, required this.api, required this.refund});
  final CustomerApi api;
  final MyRefund refund;
  @override
  State<PayoutAccountSheet> createState() => _PayoutAccountSheetState();
}

class _PayoutAccountSheetState extends State<PayoutAccountSheet> {
  final _payout = _PayoutController();
  @override
  void dispose() {
    _payout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Form(
    title: 'Tài khoản nhận hoàn tiền – khoản #${widget.refund.id}',
    submitLabel: 'Lưu tài khoản',
    onSubmit: () async {
      final error = _payout.validate();
      if (error != null) {
        showSnack(context, error, error: true);
        return false;
      }
      return runAction(context, () => widget.api.setRefundPayoutAccount(widget.refund.id, _payout.input), success: 'Đã lưu tài khoản nhận hoàn tiền.');
    },
    children: [
      if (widget.refund.payoutFailureReason != null)
        Notice('Lần chuyển khoản trước bị lỗi: ${widget.refund.payoutFailureReason}. Hãy nhập tài khoản khác hoặc kiểm tra lại.', icon: 'warning', peach: true),
      if (widget.refund.payoutFailureReason != null) _gap(),
      _PayoutFields(api: widget.api, controller: _payout),
    ],
  );
}

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
          notice: 'ORDER_CANCELLED',
          data: {'orderId': '${o.id}', 'orderCode': o.code},
          noticeBody: 'Đã huỷ đơn ${o.code}.${paid ? ' Yêu cầu hoàn 100% đã gửi tới Admin.' : ''}',
        );
      },
      children: [
        Notice(
          'Huỷ miễn phí khi đơn đang tìm tài xế hoặc tài xế đã nhận.'
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
        TextField(
          controller: _reason,
          maxLength: 500,
          decoration: InputDecoration(labelText: _code == 'OTHER' ? 'Ghi rõ lý do *' : 'Ghi chú thêm'),
        ),
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
      Notice('Lần gửi ảnh thứ ${widget.order.proof?.submissionCount ?? 1}/5. Sau lần từ chối thứ 5, tài xế phải báo sự cố.', icon: 'warning', peach: true),
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
  final _payout = _PayoutController();
  List<String> _photos = const [];

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    _payout.dispose();
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
        final payoutError = _payout.validate();
        if (payoutError != null) {
          showSnack(context, payoutError, error: true);
          return false;
        }
        return runAction(
          context,
          () => widget.api.submitComplaint(orderId: o.id, reasonCode: _code!, reason: _reason.text.trim(), evidenceUrls: _photos, requestedAmount: amount, payoutAccount: _payout.input),
          notice: 'COMPLAINT_SUBMITTED',
          data: {'orderId': '${o.id}', 'orderCode': o.code},
        );
      },
      children: [
        Notice(
          'Khiếu nại trong 24 giờ sau khi giao. Khi khiếu nại đang mở, đơn chưa hoàn tất.'
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
        TextField(
          controller: _reason,
          maxLines: 3,
          maxLength: 1000,
          decoration: InputDecoration(labelText: _code == 'OTHER' ? 'Mô tả chi tiết *' : 'Mô tả chi tiết'),
        ),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'Số tiền yêu cầu hoàn (tối đa ${money(o.totalFee)})'),
        ),
        _gap(),
        PhotoPicker(label: 'Ảnh bằng chứng', urls: _photos, max: OrderRules.maxEvidencePhotos, upload: widget.api.upload, onChanged: (p) => setState(() => _photos = p)),
        _gap(),
        _PayoutFields(api: widget.api, controller: _payout),
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

/// Lý do nhanh của khách: bấm thì chọn loại sự cố và điền câu mở đầu (trễ, sai tuyến, vắng mặt đều ghi là `Other`).
const incidentQuickReasons = <({String label, String type, String starter})>[
  (label: 'Hàng hư hỏng', type: 'DamagedCargo', starter: 'Hàng bị hư hỏng: '),
  (label: 'Tài xế đến trễ', type: 'Other', starter: 'Tài xế đến trễ: '),
  (label: 'Đi sai tuyến', type: 'Other', starter: 'Tài xế đi sai tuyến: '),
  (label: 'Không liên lạc được tài xế / tài xế vắng mặt', type: 'Other', starter: 'Không liên lạc được với tài xế: '),
  (label: 'Tai nạn', type: 'Accident', starter: 'Tai nạn trên đường: '),
  (label: 'Khác', type: 'Other', starter: ''),
];

class _IncidentSheetState extends State<IncidentSheet> {
  String _type = 'Other';
  String _quick = 'Khác';
  final _desc = TextEditingController();
  List<String> _photos = const [];

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  void _pick(({String label, String type, String starter}) reason) {
    setState(() {
      _quick = reason.label;
      _type = reason.type;
      // Chỉ thay câu mở đầu khi khách chưa tự viết thêm.
      final current = _desc.text.trim();
      if (current.isEmpty || incidentQuickReasons.any((r) => r.starter.isNotEmpty && r.starter.trim() == current)) {
        _desc.text = reason.starter;
        _desc.selection = TextSelection.collapsed(offset: _desc.text.length);
      }
    });
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
        notice: 'INCIDENT_REPORTED',
        data: {'orderId': '${widget.order.id}', 'orderCode': widget.order.code},
        noticeBody: 'Đã gửi báo cáo sự cố của đơn ${widget.order.code}. Điều phối viên sẽ xử lý.',
      );
    },
    children: [
      const Notice(
        'Điều phối viên sẽ kiểm tra và có thể cho tiếp tục, đổi tài xế hoặc hủy đơn. '
        'Tài xế chỉ nhận thông báo chung, không thấy nội dung bạn viết. Chuyến vẫn tiếp tục trong lúc chờ xử lý.',
        icon: 'info',
      ),
      _gap(),
      Text('Lý do nhanh', style: appText(size: 13, weight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final r in incidentQuickReasons) ChoiceChip(key: ValueKey('incident-reason-${r.label}'), label: Text(r.label), selected: _quick == r.label, onSelected: (_) => _pick(r))],
      ),
      _gap(),
      TextField(
        key: const Key('customer-incident-description'),
        controller: _desc,
        maxLines: 3,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Mô tả sự cố'),
      ),
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
  final _payout = _PayoutController();
  List<String> _photos = const [];

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    _payout.dispose();
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
      final payoutError = _payout.validate();
      if (payoutError != null) {
        showSnack(context, payoutError, error: true);
        return false;
      }
      return runAction(
        context,
        () => widget.api.requestIncidentRefund(incidentId: widget.incident.id, reason: _reason.text.trim(), evidenceUrls: _photos, requestedAmount: amount, payoutAccount: _payout.input),
        notice: 'INCIDENT_REFUND_REQUESTED',
        data: {'orderId': '${widget.order.id}', 'orderCode': widget.order.code},
      );
    },
    children: [
      const Notice('Chỉ áp dụng đơn PayOS đã thanh toán. Số được duyệt không vượt số bạn yêu cầu.', icon: 'info'),
      _gap(),
      TextField(
        controller: _reason,
        maxLines: 3,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Lý do'),
      ),
      TextField(
        controller: _amount,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: 'Số tiền yêu cầu (tối đa ${money(widget.order.totalFee)})'),
      ),
      _gap(),
      PhotoPicker(label: 'Ảnh bằng chứng', urls: _photos, max: OrderRules.maxEvidencePhotos, upload: widget.api.upload, onChanged: (p) => setState(() => _photos = p)),
      _gap(),
      _PayoutFields(api: widget.api, controller: _payout),
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
        return runAction(context, () => widget.api.replyRefund(widget.refund.id, _reply.text.trim(), _photos), notice: 'REFUND_INFO_REPLIED', data: {'orderId': '${widget.refund.orderId}'});
      },
      children: [
        if (widget.refund.infoRequestNote != null) Notice('Điều phối viên hỏi: ${widget.refund.infoRequestNote}', icon: 'info', peach: true),
        _gap(),
        TextField(
          controller: _reply,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Câu trả lời'),
        ),
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
    onSubmit: () => runAction(context, () => widget.api.rate(widget.order.id, _stars, _comment.text.trim()), notice: 'RATING_SUBMITTED'),
    children: [
      if (widget.order.driver != null)
        Text(
          'Tài xế: ${widget.order.driver!.fullName}',
          textAlign: TextAlign.center,
          style: appText(color: AppColors.secondary),
        ),
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
      TextField(
        controller: _comment,
        maxLines: 3,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Nhận xét'),
      ),
      Text('Mỗi đơn đánh giá 1 lần, không sửa được, trong 1 ngày sau khi hoàn thành.', style: appText(size: 11.5, color: AppColors.muted)),
    ],
  );
}

/* ------------------------------------------------------------ Thanh toán PayOS (UC-CUS-27) */
/// Tạo phiên PayOS (platform=App), mở trang thanh toán ngoài app, đếm ngược 10 phút.
/// Trạng thái "đã trả" chỉ tin webhook → [onCheck] tải lại đơn, trả về true nếu Paid.
class PayOsSheet extends StatefulWidget {
  const PayOsSheet({super.key, required this.api, required this.order, required this.onCheck, this.latestPayment});
  final CustomerApi api;
  final OrderDetail order;
  final Future<bool> Function() onCheck;

  /// Thông tin thanh toán mới nhất của đơn (sau khi tải lại), để phân biệt hết hạn/thất bại/huỷ.
  final OrderPayment? Function()? latestPayment;
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
    final data = {'orderId': '${widget.order.id}', 'orderCode': widget.order.code, 'amount': money(widget.order.totalFee)};
    if (paid) {
      notify(context, 'PAYMENT_CONFIRMED', data);
      Navigator.pop(context, true);
    } else {
      // Chưa có tiền: phân biệt hết hạn, thất bại, bị hủy và chưa trả (đang chờ).
      final latest = widget.latestPayment?.call();
      final expired = latest?.isExpired == true || (_session?.expiresAt.isBefore(DateTime.now()) ?? false);
      final type = expired
          ? 'PAYMENT_EXPIRED'
          : switch (latest?.transactionStatus) {
              'Failed' => 'PAYMENT_FAILED',
              'Cancelled' => 'PAYMENT_CANCELLED',
              'Expired' => 'PAYMENT_EXPIRED',
              _ => 'PAYMENT_PENDING',
            };
      notify(context, type, data);
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
        if (_creating && s == null)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (s != null) ...[
          AppCard(
            color: AppColors.pale,
            child: Column(
              children: [
                Text(
                  'SỐ TIỀN CẦN THANH TOÁN',
                  style: appText(size: 11, weight: FontWeight.w700, color: AppColors.secondary),
                ),
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
        Text('Đơn chỉ hiện cho tài xế sau khi PayOS xác nhận. Mỗi mã sống 10 phút; đơn chưa thanh toán sau 30 phút sẽ tự huỷ.', style: appText(size: 11.5, color: AppColors.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _creating ? null : _create, child: const Text('Tạo mã mới')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(onPressed: s == null || _checking ? null : _check, child: Text(_checking ? 'Đang kiểm tra…' : 'Đã thanh toán – kiểm tra')),
            ),
          ],
        ),
      ],
    );
  }
}

/// Mở Google Maps (app hoặc web) chỉ đường – không cần API key.
Future<void> openDirections(BuildContext context, GeoPoint to, {GeoPoint? from}) async {
  final params = {'api': '1', 'destination': '${to.latitude},${to.longitude}', if (from != null) 'origin': '${from.latitude},${from.longitude}'};
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
