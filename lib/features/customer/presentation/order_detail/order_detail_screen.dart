import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';
import '../../domain/order_rules.dart';
import '../booking/booking_cubit.dart';
import '../labels.dart';
import '../widgets/customer_widgets.dart';
import 'order_detail_cubit.dart';
import 'order_sheets.dart';

/// Chi tiết đơn của khách. [openPayment] = true khi vừa đặt đơn PayOS (mở thanh toán ngay).
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.openPayment = false, this.onReorder});
  final int orderId;
  final bool openPayment;
  final ValueChanged<BookingDraft>? onReorder;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => OrderDetailCubit(context.read<CustomerApi>(), orderId)..load(),
    child: _DetailView(openPayment: openPayment, onReorder: onReorder),
  );
}

class _DetailView extends StatefulWidget {
  const _DetailView({required this.openPayment, this.onReorder});
  final bool openPayment;
  final ValueChanged<BookingDraft>? onReorder;
  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> with WidgetsBindingObserver {
  Timer? _refresh, _trackRefresh;
  bool _paymentOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<OrderDetailCubit>();
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) => cubit.load(withTracking: false));
    _trackRefresh = Timer.periodic(const Duration(seconds: 60), (_) => cubit.loadTracking());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _trackRefresh?.cancel();
    super.dispose();
  }

  /// Quay lại app từ trang PayOS (deep link) hoặc từ nền → tải lại đơn.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<OrderDetailCubit>().load();
  }

  Future<void> _sheet(Widget sheet) async {
    if (await showActionSheet(context, sheet) && mounted) await context.read<OrderDetailCubit>().load();
  }

  Future<void> _pay(OrderDetail o) async {
    final cubit = context.read<OrderDetailCubit>();
    await _sheet(
      PayOsSheet(
        api: cubit.api,
        order: o,
        onCheck: () async {
          await cubit.load(withTracking: false);
          return cubit.state.order?.paymentStatus == 'Paid';
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OrderDetailCubit, OrderDetailState>(
    listener: (context, s) {
      final o = s.order;
      if (widget.openPayment && !_paymentOpened && o != null && OrderRules.awaitingPayment(o.status, o.paymentMethod, o.paymentStatus)) {
        _paymentOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _pay(o));
      }
    },
    builder: (context, s) {
      final cubit = context.read<OrderDetailCubit>();
      final o = s.order;
      return Scaffold(
        appBar: AppHeader(
          o?.code ?? 'Chi tiết đơn',
          actions: [IconButton(tooltip: 'Làm mới', onPressed: () => cubit.load(), icon: const AppIcon('refresh', color: AppColors.secondary))],
        ),
        body: o == null
            ? (s.error != null ? ErrorView(s.error!, onRetry: () => cubit.load()) : const Center(child: CircularProgressIndicator()))
            : RefreshIndicator(
                onRefresh: () => cubit.load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  children: [
                    Row(
                      children: [
                        StatusPill(o.status, paymentMethod: o.paymentMethod, paymentStatus: o.paymentStatus),
                        const SizedBox(width: 8),
                        if (o.paymentMethod == 'PayOS' && !OrderRules.awaitingPayment(o.status, o.paymentMethod, o.paymentStatus))
                          Pill(toneOf(paymentStatusTone, o.paymentStatus)),
                        const Spacer(),
                        Text('Tạo ${dateTime(o.createdAt)}', style: appText(size: 11.5, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OrderProgress(o),
                    const SizedBox(height: 12),
                    _NextAction(
                      order: o,
                      hasOpenComplaint: OrderRules.hasOpenComplaint(s.refunds),
                      rated: s.rating != null,
                      onPay: () => _pay(o),
                      onCancel: () => _sheet(CancelOrderSheet(api: cubit.api, order: o)),
                      onIncident: () => _sheet(IncidentSheet(api: cubit.api, order: o)),
                      onRejectPickup: () => _sheet(RejectPickupSheet(api: cubit.api, order: o)),
                      onComplaint: () => _sheet(ComplaintSheet(api: cubit.api, order: o)),
                      onRate: () => _sheet(RatingSheet(api: cubit.api, order: o)),
                      onDone: () => cubit.load(),
                    ),
                    const SizedBox(height: 12),
                    if (OrderStatus.trackable.contains(o.status)) _TrackingCard(state: s, onRefresh: cubit.loadTracking),
                    if (o.proof != null) _ProofCard(o.proof!),
                    _DriverCard(o),
                    _RouteCargoCard(o),
                    _FareCard(o),
                    _IncidentsCard(
                      order: o,
                      incidents: s.incidents,
                      onReport: () => _sheet(IncidentSheet(api: cubit.api, order: o)),
                      onRefund: (i) => _sheet(IncidentRefundSheet(api: cubit.api, order: o, incident: i)),
                    ),
                    _RefundsCard(
                      refunds: s.refunds,
                      onReply: (r) => _sheet(ReplyInfoSheet(api: cubit.api, refund: r)),
                      onWithdraw: (r) async {
                        final ok = await _confirm(context, 'Rút yêu cầu', 'Bạn chắc chắn muốn rút yêu cầu này? Không thể hoàn tác.');
                        if (ok && context.mounted && await runAction(context, () => cubit.api.withdrawRefund(r.id), success: 'Đã rút yêu cầu.')) {
                          await cubit.load();
                        }
                      },
                    ),
                    if (s.rating != null) _RatingCard(s.rating!),
                    _HistoryCard(o),
                    if (widget.onReorder != null)
                      OutlinedButton.icon(
                        onPressed: () => widget.onReorder!(_draftFrom(o)),
                        icon: const AppIcon('refresh', size: 18, color: AppColors.orange),
                        label: const Text('Đặt lại đơn tương tự'),
                      ),
                  ],
                ),
              ),
      );
    },
  );

  /// GB-34: không sửa đơn đã gửi → tạo đơn mới từ thông tin cũ.
  BookingDraft _draftFrom(OrderDetail o) => BookingDraft(
    pickupAddress: o.pickupAddress,
    dropoffAddress: o.dropoffAddress,
    receiverName: o.receiverName,
    receiverPhone: o.receiverPhone,
    cargoType: o.cargo.cargoType,
    quantity: o.cargo.quantity,
    weightKg: o.cargo.weightKg,
    lengthCm: o.cargo.lengthCm,
    widthCm: o.cargo.widthCm,
    heightCm: o.cargo.heightCm,
    photos: o.cargo.photoUrls,
    specialNotes: o.cargo.specialNotes ?? '',
    loadingService: o.hasLoadingService,
  );
}

Future<bool> _confirm(BuildContext context, String title, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đồng ý')),
        ],
      ),
    ) ??
    false;

/* ---------------------------------------------------------------- Việc cần làm tiếp theo */
class _NextAction extends StatefulWidget {
  const _NextAction({
    required this.order,
    required this.hasOpenComplaint,
    required this.rated,
    required this.onPay,
    required this.onCancel,
    required this.onIncident,
    required this.onRejectPickup,
    required this.onComplaint,
    required this.onRate,
    required this.onDone,
  });
  final OrderDetail order;
  final bool hasOpenComplaint, rated;
  final VoidCallback onPay, onCancel, onIncident, onRejectPickup, onComplaint, onRate;
  final Future<void> Function() onDone;
  @override
  State<_NextAction> createState() => _NextActionState();
}

class _NextActionState extends State<_NextAction> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    final done = await runAction(context, f, success: ok);
    if (mounted) setState(() => _busy = false);
    if (done) await widget.onDone();
  }

  Widget _box(Color bg, Color fg, String icon, String title, String body, List<Widget> actions) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(icon, size: 22, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: appText(size: 14.5, weight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(body, style: appText(size: 12.5, color: AppColors.secondary)),
                ],
              ),
            ),
          ],
        ),
        if (actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: actions)],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final api = context.read<CustomerApi>();
    final now = DateTime.now();
    final cancel = OutlinedButton(onPressed: widget.onCancel, child: const Text('Huỷ đơn'));
    final incident = OutlinedButton(onPressed: widget.onIncident, child: const Text('Báo sự cố'));

    switch (o.status) {
      case OrderStatus.pending:
        if (OrderRules.awaitingPayment(o.status, o.paymentMethod, o.paymentStatus)) {
          return _box(
            AppColors.redBg,
            AppColors.red,
            'credit-card',
            'Thanh toán để bắt đầu tìm tài xế',
            'Đơn PayOS chỉ được gửi tới tài xế sau khi thanh toán (GB-31). Đơn tự huỷ nếu chưa thanh toán – còn ${timeLeft(OrderRules.unpaidDeadline(o).difference(now))}.'
                '${o.payment?.isExpired == true ? ' Mã trước đã hết hạn, hãy tạo mã mới.' : ''}',
            [FilledButton(onPressed: widget.onPay, child: Text('Thanh toán ${money(o.totalFee)}')), cancel],
          );
        }
        return _box(
          AppColors.amberBg,
          AppColors.amber,
          'clock',
          'Đang tìm tài xế gần điểm lấy',
          'Đơn hiển thị cho mọi tài xế đủ điều kiện; tài xế nhận trước được giao đơn. Không ai nhận trong 10 phút, đơn tự huỷ (GB-24).',
          [cancel],
        );
      case OrderStatus.accepted:
        return _box(AppColors.peach, AppColors.orange, 'truck', 'Tài xế ${o.driver?.fullName ?? ''} đang tới điểm lấy', 'Bạn vẫn có thể huỷ miễn phí cho tới khi tài xế đến (GB-22).', [cancel]);
      case OrderStatus.arrived:
        return _box(AppColors.pale, AppColors.secondary, 'navigation', 'Tài xế đã đến điểm lấy', 'Tài xế đang kiểm hàng và chụp ảnh để bạn duyệt. Từ bước này không tự huỷ được; có vấn đề hãy báo sự cố.', [incident]);
      case OrderStatus.pickedUp:
        if (OrderRules.pickupReviewPending(o)) {
          return _box(
            AppColors.amberBg,
            AppColors.amber,
            'clipboard-check',
            'Duyệt ảnh lấy hàng (lần ${o.proof?.submissionCount ?? 1}/5)',
            'Kiểm tra ảnh tài xế vừa chụp bên dưới. Chuyến chỉ bắt đầu sau khi bạn duyệt (GB-26).',
            [
              FilledButton(
                onPressed: _busy ? null : () => _run(() => api.reviewPickup(o.id, approve: true), 'Đã duyệt ảnh. Tài xế bắt đầu vận chuyển.'),
                child: const Text('Duyệt, cho xuất phát'),
              ),
              OutlinedButton(onPressed: widget.onRejectPickup, child: const Text('Từ chối, chụp lại')),
            ],
          );
        }
        return _box(
          AppColors.pale,
          AppColors.secondary,
          'camera',
          'Chờ tài xế gửi lại ảnh lấy hàng',
          o.proof?.rejectionReason != null ? 'Bạn đã từ chối: “${o.proof!.rejectionReason}”.' : 'Tài xế sẽ gửi ảnh để bạn duyệt.',
          [incident],
        );
      case OrderStatus.inTransit:
        return _box(AppColors.pale, AppColors.secondary, 'route', 'Hàng đang được vận chuyển', 'Theo dõi vị trí tài xế bên dưới. Có vấn đề (hỏng hàng, trễ, sai tuyến…) hãy báo sự cố.', [incident]);
      case OrderStatus.delivered:
        final deadline = OrderRules.complaintDeadline(o);
        final left = deadline?.difference(now) ?? Duration.zero;
        final canComplain = !left.isNegative && left.inSeconds > 0 && !widget.hasOpenComplaint;
        return _box(
          AppColors.greenBg,
          AppColors.green,
          'box',
          'Hàng đã giao – kiểm tra và xác nhận',
          widget.hasOpenComplaint
              ? 'Đơn đang có khiếu nại mở. Đơn sẽ hoàn tất sau khi khiếu nại được đóng.'
              : 'Hàng ổn: xác nhận đã nhận hàng. Có vấn đề: khiếu nại (còn ${timeLeft(left)}). Xác nhận rồi sẽ không khiếu nại được; quá 24 giờ đơn tự hoàn tất (GB-18, GB-23).',
          [
            if (!widget.hasOpenComplaint)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _confirm(context, 'Xác nhận đã nhận hàng', 'Bạn đã kiểm tra hàng của đơn ${o.code} và hàng nguyên vẹn? Sau khi xác nhận bạn không thể khiếu nại.')) {
                          await _run(() => api.confirmReceipt(o.id), 'Đơn ${o.code} đã hoàn thành. Cảm ơn bạn!');
                        }
                      },
                child: const Text('Xác nhận đã nhận hàng'),
              ),
            if (canComplain)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                onPressed: widget.onComplaint,
                child: const Text('Khiếu nại'),
              ),
          ],
        );
      case OrderStatus.completed:
        final deadline = OrderRules.ratingDeadline(o);
        final left = deadline?.difference(now) ?? Duration.zero;
        if (widget.rated) return _box(AppColors.greenBg, AppColors.green, 'check', 'Đơn đã hoàn thành', 'Cảm ơn bạn đã đánh giá chuyến đi.', const []);
        return _box(
          AppColors.greenBg,
          AppColors.green,
          'check',
          'Đơn đã hoàn thành',
          left.inSeconds > 0 ? 'Hãy đánh giá tài xế (còn ${timeLeft(left)}, chỉ 1 lần – GB-20).' : 'Đã quá thời hạn 1 ngày để đánh giá.',
          [if (left.inSeconds > 0) FilledButton(onPressed: widget.onRate, child: const Text('Đánh giá tài xế'))],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/* ---------------------------------------------------------------- Theo dõi */
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.state, required this.onRefresh});
  final OrderDetailState state;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final t = state.tracking;
    const target = {'Pickup': 'tới điểm lấy', 'Handover': 'tới chỗ nhận bàn giao', 'Dropoff': 'tới điểm giao'};
    final toPickup = t != null && (t.etaTarget == 'Pickup' || (t.etaTarget == null && ['Accepted', 'Arrived'].contains(t.orderStatus)));
    return SectionCard(
      title: 'Theo dõi tài xế',
      trailing: IconButton(tooltip: 'Cập nhật vị trí', onPressed: onRefresh, icon: const AppIcon('refresh', size: 20, color: AppColors.orange)),
      child: t == null
          ? Text(state.trackingError ?? 'Đang tải vị trí…', style: appText(size: 13, color: AppColors.secondary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Thời gian dự kiến',
                        value: t.etaMinutes == null ? '—' : '${t.etaMinutes} phút',
                        hint: t.etaTarget == null ? 'Chưa tính được' : target[t.etaTarget] ?? '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        label: 'Vị trí tài xế',
                        value: t.driver == null ? 'Chưa có GPS' : (t.driverStale ? 'Mất tín hiệu' : 'Trực tiếp'),
                        hint: t.driverAt == null ? '' : 'Cập nhật ${timeAgo(t.driverAt!)}',
                        color: t.driver == null || t.driverStale ? AppColors.amber : AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openDirections(context, toPickup ? t.pickup : t.dropoff, from: t.driver),
                  icon: const AppIcon('map', size: 18, color: AppColors.orange),
                  label: Text(t.driver == null ? 'Xem tuyến trên bản đồ' : 'Xem tài xế ${toPickup ? 'tới điểm lấy' : 'tới điểm giao'}'),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.hint, this.color = AppColors.ink});
  final String label, value, hint;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: appText(size: 11, color: AppColors.secondary)),
        Text(value, style: appText(size: 16, weight: FontWeight.w800, color: color)),
        if (hint.isNotEmpty) Text(hint, style: appText(size: 11, color: AppColors.muted)),
      ],
    ),
  );
}

/* ---------------------------------------------------------------- Các thẻ thông tin */
class _ProofCard extends StatelessWidget {
  const _ProofCard(this.p);
  final OrderProof p;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Ảnh lấy hàng & giao hàng',
    trailing: Pill(toneOf(proofStatusTone, p.proofStatus)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh lấy hàng (lần gửi ${p.submissionCount}/5)', style: appText(size: 12.5, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        PhotoStrip(p.pickupPhotoUrls),
        if (p.rejectionReason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Lý do từ chối gần nhất: ${p.rejectionReason}', style: appText(size: 12, color: AppColors.red))),
        const SizedBox(height: 12),
        Text('Ảnh giao hàng (POD)', style: appText(size: 12.5, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        PhotoStrip([if (p.deliveryPhotoUrl != null) p.deliveryPhotoUrl!], emptyText: 'Chưa giao hàng'),
        if (p.deliveredAt != null) Text('Giao lúc ${dateTime(p.deliveredAt!)}', style: appText(size: 11.5, color: AppColors.muted)),
      ],
    ),
  );
}

class _DriverCard extends StatelessWidget {
  const _DriverCard(this.o);
  final OrderDetail o;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Tài xế',
    child: o.driver == null
        ? Text(o.status == OrderStatus.cancelled ? 'Không có tài xế.' : 'Chưa có tài xế nhận đơn.', style: appText(size: 13, color: AppColors.secondary))
        : Row(
            children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.ink, child: Text(o.driver!.fullName.isEmpty ? 'T' : o.driver!.fullName[0], style: appText(color: Colors.white, weight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.driver!.fullName, style: appText(size: 15, weight: FontWeight.w700)),
                    Text('${o.vehicleTypeName} • ${o.driver!.licensePlate ?? '—'}', style: appText(size: 12.5, color: AppColors.secondary)),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Gọi ${o.driver!.phoneNumber}',
                style: IconButton.styleFrom(backgroundColor: AppColors.orange),
                onPressed: () => callPhone(context, o.driver!.phoneNumber),
                icon: const AppIcon('phone', color: Colors.white, size: 20),
              ),
            ],
          ),
  );
}

class _RouteCargoCard extends StatelessWidget {
  const _RouteCargoCard(this.o);
  final OrderDetail o;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Lộ trình & hàng hoá',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _place('map-pin', AppColors.orange, 'Điểm lấy', o.pickupAddress),
        const SizedBox(height: 8),
        _place('target', AppColors.green, 'Điểm giao • ${o.receiverName} (${o.receiverPhone})', o.dropoffAddress),
        const SizedBox(height: 6),
        Text('${o.distanceKm} km • ~${o.durationMin} phút • ${o.vehicleTypeName}${o.hasLoadingService ? ' • Có bốc xếp' : ''}', style: appText(size: 12, color: AppColors.muted)),
        const Divider(height: 22),
        KvRow('Loại hàng', o.cargo.cargoTypeName ?? o.cargo.cargoType),
        KvRow('Số lượng / KL', '${o.cargo.quantity} kiện • ${o.cargo.weightKg} kg'),
        KvRow('Món lớn nhất', '${o.cargo.lengthCm}×${o.cargo.widthCm}×${o.cargo.heightCm} cm'),
        if (o.cargo.specialNotes != null) KvRow('Ghi chú', o.cargo.specialNotes!),
        const SizedBox(height: 6),
        PhotoStrip(o.cargo.photoUrls, size: 60),
      ],
    ),
  );

  Widget _place(String icon, Color color, String label, String address) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppIcon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: appText(size: 11.5, color: AppColors.secondary)),
            Text(address, style: appText(size: 13.5, weight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );
}

class _FareCard extends StatelessWidget {
  const _FareCard(this.o);
  final OrderDetail o;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Cước phí & thanh toán',
    child: Column(
      children: [
        KvRow('Cước quãng đường (${o.distanceKm} km)', money(o.distanceFee)),
        if (o.serviceFee > 0) KvRow('Phí bốc xếp', money(o.serviceFee)),
        if (o.discountAmount > 0) KvRow('Giảm giá ${o.couponCode ?? ''}', '-${money(o.discountAmount)}', valueColor: AppColors.green),
        const Divider(),
        KvRow('Tổng cước', money(o.totalFee), strong: true),
        KvRow('Hình thức', paymentMethodLabel[o.paymentMethod] ?? o.paymentMethod),
        if (o.payerRole != null) KvRow('Người trả', payerRoleLabel[o.payerRole] ?? o.payerRole!),
        KvRow('Trạng thái', toneOf(paymentStatusTone, o.paymentStatus).label),
        if (o.payment?.paidAt != null) KvRow('Thanh toán lúc', dateTime(o.payment!.paidAt!)),
      ],
    ),
  );
}

class _IncidentsCard extends StatelessWidget {
  const _IncidentsCard({required this.order, required this.incidents, required this.onReport, required this.onRefund});
  final OrderDetail order;
  final List<MyIncident> incidents;
  final VoidCallback onReport;
  final ValueChanged<MyIncident> onRefund;
  @override
  Widget build(BuildContext context) {
    final canReport = OrderRules.canReportIncident(order);
    if (incidents.isEmpty && !canReport) return const SizedBox.shrink();
    return SectionCard(
      title: 'Sự cố (${incidents.length})',
      trailing: canReport ? TextButton(onPressed: onReport, child: const Text('Báo sự cố')) : null,
      child: incidents.isEmpty
          ? Text('Chưa có sự cố nào.', style: appText(size: 13, color: AppColors.muted))
          : Column(
              children: [
                for (final i in incidents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      color: AppColors.pale,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('#${i.id} – ${incidentTypeLabel[i.incidentType] ?? i.incidentType}', style: appText(size: 13, weight: FontWeight.w700))),
                              Pill(toneOf(incidentStatusTone, i.status)),
                            ],
                          ),
                          Text('${i.reportedByYou ? 'Bạn báo' : 'Tài xế báo'} • ${dateTime(i.createdAt)}', style: appText(size: 11, color: AppColors.muted)),
                          const SizedBox(height: 4),
                          Text(i.description, style: appText(size: 13)),
                          if (i.photoUrls.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: PhotoStrip(i.photoUrls, size: 54)),
                          if (i.decision != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Kết quả: ${incidentDecisionLabel[i.decision] ?? i.decision}${i.note == null ? '' : ' – ${i.note}'}', style: appText(size: 12.5, weight: FontWeight.w600)),
                            ),
                          if (i.status == 'Cancelled' && i.note != null) Text('Lý do huỷ sự cố: ${i.note}', style: appText(size: 12, color: AppColors.secondary)),
                          if (OrderRules.canRequestIncidentRefund(order))
                            TextButton(onPressed: () => onRefund(i), child: const Text('Yêu cầu hoàn tiền cho sự cố này')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RefundsCard extends StatelessWidget {
  const _RefundsCard({required this.refunds, required this.onReply, required this.onWithdraw});
  final List<MyRefund> refunds;
  final ValueChanged<MyRefund> onReply, onWithdraw;
  @override
  Widget build(BuildContext context) {
    if (refunds.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Khiếu nại & hoàn tiền (${refunds.length})',
      child: Column(
        children: [
          for (final r in refunds)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                color: AppColors.pale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${refundSourceLabel[r.sourceType] ?? r.sourceType} #${r.id}', style: appText(size: 13, weight: FontWeight.w700))),
                        Pill(refundTone(r.status)),
                      ],
                    ),
                    Text(dateTime(r.createdAt), style: appText(size: 11, color: AppColors.muted)),
                    if (r.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.reason, style: appText(size: 13))),
                    const SizedBox(height: 4),
                    Text(
                      'Yêu cầu: ${money(r.requestedAmount)}${r.approvedAmount == null ? '' : ' • Được duyệt: ${money(r.approvedAmount!)}'}',
                      style: appText(size: 12.5, weight: FontWeight.w600),
                    ),
                    if (r.processedAt != null) Text('Đã chuyển khoản ${dateTime(r.processedAt!)}', style: appText(size: 12, color: AppColors.green)),
                    if (r.evidenceUrls.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: PhotoStrip(r.evidenceUrls, size: 54)),
                    if (r.infoRequestNote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Notice('Điều phối viên hỏi: ${r.infoRequestNote}', icon: 'info', peach: true, detail: r.customerReply == null ? null : 'Bạn trả lời: ${r.customerReply}'),
                      ),
                    if (r.decisionReason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Quyết định của Admin: ${r.decisionReason}', style: appText(size: 12.5))),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (r.waitingForYourReply) TextButton(onPressed: () => onReply(r), child: const Text('Bổ sung thông tin')),
                        if (OrderRules.canWithdrawRefund(r)) TextButton(onPressed: () => onWithdraw(r), child: const Text('Rút yêu cầu')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard(this.r);
  final MyRating r;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Đánh giá của bạn',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [for (var n = 1; n <= 5; n++) Icon(n <= r.stars ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.amber, size: 22)]),
        if (r.comment != null) Text('“${r.comment}”', style: appText(size: 13, color: AppColors.secondary)),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(this.o);
  final OrderDetail o;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Lịch sử trạng thái',
    child: Column(
      children: [
        for (final (i, h) in o.history.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(radius: 5, backgroundColor: i == o.history.length - 1 ? AppColors.orange : AppColors.line),
                  if (i < o.history.length - 1) Container(width: 2, height: 38, color: AppColors.line),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(toneOf(orderStatusTone, h.toStatus).label, style: appText(size: 13, weight: FontWeight.w700)),
                      Text('${dateTime(h.changedAt)} • ${changedByLabel[h.changedByRole] ?? h.changedByRole}', style: appText(size: 11, color: AppColors.muted)),
                      if (h.note != null) Text('“${h.note}”', style: appText(size: 12, color: AppColors.secondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}
