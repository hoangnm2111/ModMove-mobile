import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/notifications/app_notice.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';
import '../../domain/order_rules.dart';
import '../booking/booking_cubit.dart';
import '../labels.dart';
import '../widgets/customer_widgets.dart';
import 'order_detail_cubit.dart';
import '../../../../core/widgets/phone_button.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/notifications/notification_cubit.dart';
import '../../../../core/widgets/notice_banner.dart';
import 'order_sheets.dart';

/// Chi tiết đơn của khách. [openPayment] = true khi vừa đặt đơn PayOS (mở thanh toán ngay).
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.openPayment = false,
    this.onReorder,
  });
  final int orderId;
  final bool openPayment;
  final ValueChanged<BookingDraft>? onReorder;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        OrderDetailCubit(context.read<CustomerApi>(), orderId)..load(),
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
  final _incidentsKey = GlobalKey();
  int _ticks = 0;
  bool _paymentOpened = false;
  StreamSubscription<AppNotice>? _pushed;
  late final int _orderId;

  /// Lúc tài xế báo "đã đến điểm giao" (null nếu chưa); chỉ có ý nghĩa khi đơn còn đang giao.
  DateTime? _dropoffArrivedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<OrderDetailCubit>();
    _orderId = cubit.orderId;
    openOrderId.value = _orderId;
    // Có thông báo mới của đúng đơn này (SignalR) → tải lại ngay, không đợi chu kỳ.
    NotificationCubit? notices;
    try {
      notices = context.read<NotificationCubit>();
    } on ProviderNotFoundException {
      notices = null; // dựng riêng (test): không có hộp thông báo
    }
    // BE không lưu bước "đến điểm giao" (chỉ gửi thông báo): lấy từ hộp thông báo của phiên và từ thông báo mới.
    _dropoffArrivedAt = notices?.state.inbox
        .where(
          (n) => n.type == 'DRIVER_ARRIVED_DROPOFF' && n.orderId == _orderId,
        )
        .map((n) => n.at)
        .firstOrNull;
    _pushed = notices?.pushed.listen((n) {
      if (n.orderId != _orderId) return;
      if (n.type == 'DRIVER_ARRIVED_DROPOFF' && mounted) {
        setState(() => _dropoffArrivedAt = n.at);
      }
      cubit.load(withTracking: false);
    });
    // Còn sự cố mở (của ai cũng được) thì tải lại mỗi 15 giây; bình thường mỗi 20 giây.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      final state = cubit.state;
      final open =
          state.order?.pendingDriverIncidentId != null ||
          state.incidents.any(
            (i) => i.status == 'Open' || i.status == 'InProgress',
          );
      if (open || ++_ticks % 2 == 0) cubit.load(withTracking: false);
    });
    _trackRefresh = Timer.periodic(
      const Duration(seconds: 60),
      (_) => cubit.loadTracking(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _trackRefresh?.cancel();
    _pushed?.cancel();
    if (openOrderId.value == _orderId) openOrderId.value = null;
    super.dispose();
  }

  /// Quay lại app từ trang PayOS (deep link) hoặc từ nền → tải lại đơn.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<OrderDetailCubit>().load();
    }
  }

  Future<void> _sheet(Widget sheet) async {
    if (await showActionSheet(context, sheet) && mounted) {
      await context.read<OrderDetailCubit>().load();
    }
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
        latestPayment: () => cubit.state.order?.payment,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<OrderDetailCubit, OrderDetailState>(
    listener: (context, s) {
      final o = s.order;
      if (widget.openPayment &&
          !_paymentOpened &&
          o != null &&
          OrderRules.awaitingPayment(
            o.status,
            o.paymentMethod,
            o.paymentStatus,
          )) {
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
          actions: [
            IconButton(
              tooltip: 'Làm mới',
              onPressed: () => cubit.load(),
              icon: const AppIcon('refresh', color: AppColors.secondary),
            ),
          ],
        ),
        body: o == null
            ? (s.error != null
                  ? ErrorView(s.error!, onRetry: () => cubit.load())
                  : const Center(child: CircularProgressIndicator()))
            : RefreshIndicator(
                onRefresh: () => cubit.load(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  children: [
                    Row(
                      children: [
                        StatusPill(
                          o.status,
                          paymentMethod: o.paymentMethod,
                          paymentStatus: o.paymentStatus,
                        ),
                        const SizedBox(width: 8),
                        if (o.paymentMethod == 'PayOS' &&
                            !OrderRules.awaitingPayment(
                              o.status,
                              o.paymentMethod,
                              o.paymentStatus,
                            ))
                          Pill(toneOf(paymentStatusTone, o.paymentStatus)),
                        const Spacer(),
                        Text(
                          'Tạo ${dateTime(o.createdAt)}',
                          style: appText(size: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OrderProgress(
                      o,
                      dropoffArrivedAt: o.status == OrderStatus.inTransit
                          ? _dropoffArrivedAt
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (o.pendingDriverIncidentId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          key: const Key('driver-incident-banner'),
                          color: AppColors.redBg,
                          borderColor: AppColors.red,
                          onTap: () {
                            final target = _incidentsKey.currentContext;
                            if (target != null) {
                              Scrollable.ensureVisible(
                                target,
                                duration: const Duration(milliseconds: 300),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              const AppIcon('warning', color: AppColors.red),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tài xế đã báo sự cố #${o.pendingDriverIncidentId}. Chuyến tạm dừng chờ điều phối viên xử lý.',
                                  style: appText(
                                    size: 13,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const AppIcon('chevron-right', size: 16),
                            ],
                          ),
                        ),
                      ),
                    _NextAction(
                      order: o,
                      dropoffArrivedAt: o.status == OrderStatus.inTransit
                          ? _dropoffArrivedAt
                          : null,
                      hasOpenComplaint: OrderRules.hasOpenComplaint(s.refunds),
                      rated: s.rating != null,
                      onPay: () => _pay(o),
                      onCancel: () =>
                          _sheet(CancelOrderSheet(api: cubit.api, order: o)),
                      onIncident: () =>
                          _sheet(IncidentSheet(api: cubit.api, order: o)),
                      onRejectPickup: () =>
                          _sheet(RejectPickupSheet(api: cubit.api, order: o)),
                      onComplaint: () =>
                          _sheet(ComplaintSheet(api: cubit.api, order: o)),
                      onRate: () =>
                          _sheet(RatingSheet(api: cubit.api, order: o)),
                      onDone: () => cubit.load(),
                    ),
                    const SizedBox(height: 12),
                    if (OrderStatus.trackable.contains(o.status))
                      _TrackingCard(state: s, onRefresh: cubit.loadTracking),
                    if (o.proof != null) _ProofCard(o.proof!),
                    _DriverCard(o),
                    _RouteCargoCard(o),
                    _FareCard(o),
                    _IncidentsCard(
                      key: _incidentsKey,
                      order: o,
                      incidents: s.incidents,
                      refunds: s.refunds,
                      onReport: () =>
                          _sheet(IncidentSheet(api: cubit.api, order: o)),
                      onRefund: (i) => _sheet(
                        IncidentRefundSheet(
                          api: cubit.api,
                          order: o,
                          incident: i,
                        ),
                      ),
                      onReply: (r) =>
                          _sheet(ReplyInfoSheet(api: cubit.api, refund: r)),
                      onPayout: (r) =>
                          _sheet(PayoutAccountSheet(api: cubit.api, refund: r)),
                      onWithdraw: (r) => _withdrawRefund(r, o),
                    ),
                    _RefundsCard(
                      // Khoản hoàn của một sự cố đã nằm trong thẻ sự cố tương ứng.
                      refunds: [
                        for (final r in s.refunds)
                          if (!(r.incidentId != null &&
                              s.incidents.any((i) => i.id == r.incidentId)))
                            r,
                      ],
                      onReply: (r) =>
                          _sheet(ReplyInfoSheet(api: cubit.api, refund: r)),
                      onPayout: (r) =>
                          _sheet(PayoutAccountSheet(api: cubit.api, refund: r)),
                      onWithdraw: (r) => _withdrawRefund(r, o),
                    ),
                    if (s.rating != null) _RatingCard(s.rating!),
                    _HistoryCard(o),
                    if (widget.onReorder != null)
                      OutlinedButton.icon(
                        onPressed: () => widget.onReorder!(_draftFrom(o)),
                        icon: const AppIcon(
                          'refresh',
                          size: 18,
                          color: AppColors.orange,
                        ),
                        label: const Text('Đặt lại đơn tương tự'),
                      ),
                  ],
                ),
              ),
      );
    },
  );

  Future<void> _withdrawRefund(MyRefund r, OrderDetail o) async {
    final cubit = context.read<OrderDetailCubit>();
    final ok = await _confirm(
      context,
      'Rút yêu cầu',
      'Bạn chắc chắn muốn rút yêu cầu này? Không thể hoàn tác.',
    );
    if (ok &&
        mounted &&
        await runAction(
          context,
          () => cubit.api.withdrawRefund(r.id),
          notice: 'REFUND_WITHDRAWN',
          data: {'orderId': '${r.orderId}', 'orderCode': o.code},
        )) {
      await cubit.load();
    }
  }

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

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    ) ??
    false;

/* ---------------------------------------------------------------- Việc cần làm tiếp theo */
class _NextAction extends StatefulWidget {
  const _NextAction({
    required this.order,
    this.dropoffArrivedAt,
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

  /// Tài xế đã báo đến điểm giao lúc này (đơn đang `InTransit`).
  final DateTime? dropoffArrivedAt;
  final bool hasOpenComplaint, rated;
  final VoidCallback onPay,
      onCancel,
      onIncident,
      onRejectPickup,
      onComplaint,
      onRate;
  final Future<void> Function() onDone;
  @override
  State<_NextAction> createState() => _NextActionState();
}

class _NextActionState extends State<_NextAction> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function() f,
    String ok, {
    String? notice,
    Map<String, String> data = const {},
  }) async {
    setState(() => _busy = true);
    var pending = false;
    final done = await runAction(
      context,
      () async {
        try {
          await f();
        } on ApiException catch (e) {
          // BE từ chối vì tài xế vừa báo sự cố: tải lại để hiện banner và khóa nút.
          pending = e.code == 'INCIDENT_PENDING';
          rethrow;
        }
      },
      success: ok,
      notice: notice,
      data: data,
      noticeBody: notice == null ? null : ok,
    );
    if (mounted) setState(() => _busy = false);
    if (done || pending) await widget.onDone();
  }

  Widget _box(
    Color bg,
    Color fg,
    String icon,
    String title,
    String body,
    List<Widget> actions,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
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
                  Text(
                    title,
                    style: appText(size: 14.5, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: appText(size: 12.5, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final api = context.read<CustomerApi>();
    final now = DateTime.now();
    final cancel = OutlinedButton(
      onPressed: widget.onCancel,
      child: const Text('Huỷ đơn'),
    );
    final incident = OutlinedButton(
      onPressed: widget.onIncident,
      child: const Text('Báo sự cố'),
    );

    switch (o.status) {
      case OrderStatus.pending:
        if (OrderRules.awaitingPayment(
          o.status,
          o.paymentMethod,
          o.paymentStatus,
        )) {
          return _box(
            AppColors.redBg,
            AppColors.red,
            'credit-card',
            'Thanh toán để bắt đầu tìm tài xế',
            'Đơn PayOS chỉ được gửi tới tài xế sau khi thanh toán. Đơn tự huỷ nếu chưa thanh toán – còn ${timeLeft(OrderRules.unpaidDeadline(o).difference(now))}.'
                '${o.payment?.isExpired == true ? ' Mã trước đã hết hạn, hãy tạo mã mới.' : ''}',
            [
              FilledButton(
                onPressed: widget.onPay,
                child: Text('Thanh toán ${money(o.totalFee)}'),
              ),
              cancel,
            ],
          );
        }
        return _box(
          AppColors.amberBg,
          AppColors.amber,
          'clock',
          'Đang tìm tài xế gần điểm lấy',
          'Đơn hiển thị cho mọi tài xế đủ điều kiện; tài xế nhận trước được giao đơn. Không ai nhận trong 10 phút, đơn tự huỷ.',
          [cancel],
        );
      case OrderStatus.accepted:
        return _box(
          AppColors.peach,
          AppColors.orange,
          'truck',
          'Tài xế ${o.driver?.fullName ?? ''} đang tới điểm lấy',
          'Bạn vẫn có thể huỷ miễn phí cho tới khi tài xế đến.',
          [cancel],
        );
      case OrderStatus.arrived:
        return _box(
          AppColors.pale,
          AppColors.secondary,
          'navigation',
          'Tài xế đã đến điểm lấy',
          'Tài xế đang kiểm hàng và chụp ảnh để bạn duyệt. Từ bước này không tự huỷ được; có vấn đề hãy báo sự cố.',
          [incident],
        );
      case OrderStatus.pickedUp:
        if (OrderRules.pickupReviewPending(o)) {
          return _box(
            AppColors.amberBg,
            AppColors.amber,
            'clipboard-check',
            'Duyệt ảnh lấy hàng lần ${o.proof?.submissionCount ?? 1}/5',
            OrderRules.canApprovePickup(o)
                ? 'Kiểm tra ảnh tài xế vừa chụp bên dưới. Chuyến chỉ bắt đầu sau khi bạn duyệt.'
                : 'Chưa duyệt được khi tài xế đang có sự cố. Bạn vẫn có thể từ chối để tài xế chụp lại.',
            [
              FilledButton(
                key: const Key('approve-pickup'),
                onPressed: _busy || !OrderRules.canApprovePickup(o)
                    ? null
                    : () => _run(
                        () => api.reviewPickup(o.id, approve: true),
                        'Đã duyệt ảnh. Tài xế bắt đầu vận chuyển.',
                      ),
                child: const Text('Duyệt, cho xuất phát'),
              ),
              OutlinedButton(
                onPressed: widget.onRejectPickup,
                child: const Text('Từ chối, chụp lại'),
              ),
            ],
          );
        }
        return _box(
          AppColors.pale,
          AppColors.secondary,
          'camera',
          'Chờ tài xế gửi lại ảnh lấy hàng',
          o.proof?.rejectionReason != null
              ? 'Bạn đã từ chối: “${o.proof!.rejectionReason}”.'
              : 'Tài xế sẽ gửi ảnh để bạn duyệt.',
          [incident],
        );
      case OrderStatus.inTransit:
        if (widget.dropoffArrivedAt case final arrivedAt?) {
          final payCash =
              o.paymentMethod == 'Cash' &&
              o.payerRole == 'Receiver' &&
              o.paymentStatus != 'Paid';
          return _box(
            AppColors.greenBg,
            AppColors.green,
            'map-pin',
            'Tài xế đã đến điểm giao',
            'Tài xế báo đã tới điểm giao lúc ${timeOfDay(arrivedAt)}.'
                '${payCash ? ' Người nhận thanh toán ${money(o.totalFee)} tiền mặt cho tài xế.' : ''}'
                ' Tài xế sẽ chụp ảnh giao hàng để hoàn tất; sau đó bạn xác nhận nhận hàng hoặc khiếu nại trong 24 giờ.'
                ' Có vấn đề với hàng, hãy báo sự cố ngay.',
            [incident],
          );
        }
        return _box(
          AppColors.pale,
          AppColors.secondary,
          'route',
          'Hàng đang được vận chuyển',
          'Theo dõi vị trí tài xế bên dưới. Có vấn đề hãy báo sự cố.',
          [incident],
        );
      case OrderStatus.delivered:
        final deadline = OrderRules.complaintDeadline(o);
        final left = deadline?.difference(now) ?? Duration.zero;
        final canComplain =
            !left.isNegative && left.inSeconds > 0 && !widget.hasOpenComplaint;
        return _box(
          AppColors.greenBg,
          AppColors.green,
          'box',
          'Hàng đã giao – kiểm tra và xác nhận',
          widget.hasOpenComplaint
              ? 'Đơn đang có khiếu nại mở. Đơn sẽ hoàn tất sau khi khiếu nại được đóng.'
              : 'Hàng ổn: xác nhận đã nhận hàng. Có vấn đề: khiếu nại (còn ${timeLeft(left)}). Xác nhận rồi sẽ không khiếu nại được; quá 24 giờ đơn tự hoàn tất.',
          [
            if (!widget.hasOpenComplaint)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _confirm(
                          context,
                          'Xác nhận đã nhận hàng',
                          'Bạn đã kiểm tra hàng của đơn ${o.code} và hàng nguyên vẹn? Sau khi xác nhận bạn không thể khiếu nại.',
                        )) {
                          await _run(
                            () => api.confirmReceipt(o.id),
                            'Đơn ${o.code} đã hoàn thành. Cảm ơn bạn!',
                            notice: 'RECEIPT_CONFIRMED',
                            data: {'orderId': '${o.id}', 'orderCode': o.code},
                          );
                        }
                      },
                child: const Text('Xác nhận đã nhận hàng'),
              ),
            if (canComplain)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                ),
                onPressed: widget.onComplaint,
                child: const Text('Khiếu nại'),
              ),
          ],
        );
      case OrderStatus.completed:
        final deadline = OrderRules.ratingDeadline(o);
        final left = deadline?.difference(now) ?? Duration.zero;
        if (widget.rated) {
          return _box(
            AppColors.greenBg,
            AppColors.green,
            'check',
            'Đơn đã hoàn thành',
            'Cảm ơn bạn đã đánh giá chuyến đi.',
            const [],
          );
        }
        return _box(
          AppColors.greenBg,
          AppColors.green,
          'check',
          'Đơn đã hoàn thành',
          left.inSeconds > 0
              ? 'Hãy đánh giá tài xế (còn ${timeLeft(left)}, chỉ 1 lần).'
              : 'Đã quá thời hạn 1 ngày để đánh giá.',
          [
            if (left.inSeconds > 0)
              FilledButton(
                onPressed: widget.onRate,
                child: const Text('Đánh giá tài xế'),
              ),
          ],
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
    const target = {
      'Pickup': 'tới điểm lấy',
      'Handover': 'tới chỗ nhận bàn giao',
      'Dropoff': 'tới điểm giao',
    };
    final toPickup =
        t != null &&
        (t.etaTarget == 'Pickup' ||
            (t.etaTarget == null &&
                ['Accepted', 'Arrived'].contains(t.orderStatus)));
    return SectionCard(
      title: 'Theo dõi tài xế',
      trailing: IconButton(
        tooltip: 'Cập nhật vị trí',
        onPressed: onRefresh,
        icon: const AppIcon('refresh', size: 20, color: AppColors.orange),
      ),
      child: t == null
          ? Text(
              state.trackingError ?? 'Đang tải vị trí…',
              style: appText(size: 13, color: AppColors.secondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Thời gian dự kiến',
                        value: t.etaMinutes == null
                            ? '—'
                            : '${t.etaMinutes} phút',
                        hint: t.etaTarget == null
                            ? 'Chưa tính được'
                            : target[t.etaTarget] ?? '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        label: 'Vị trí tài xế',
                        value: t.driver == null
                            ? 'Chưa có GPS'
                            : (t.driverStale ? 'Mất tín hiệu' : 'Trực tiếp'),
                        hint: t.driverAt == null
                            ? ''
                            : 'Cập nhật ${timeAgo(t.driverAt!)}',
                        color: t.driver == null || t.driverStale
                            ? AppColors.amber
                            : AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openDirections(
                    context,
                    toPickup ? t.pickup : t.dropoff,
                    from: t.driver,
                  ),
                  icon: const AppIcon('map', size: 18, color: AppColors.orange),
                  label: Text(
                    t.driver == null
                        ? 'Xem tuyến trên bản đồ'
                        : 'Xem tài xế ${toPickup ? 'tới điểm lấy' : 'tới điểm giao'}',
                  ),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.hint,
    this.color = AppColors.ink,
  });
  final String label, value, hint;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.pale,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: appText(size: 11, color: AppColors.secondary)),
        Text(
          value,
          style: appText(size: 16, weight: FontWeight.w800, color: color),
        ),
        if (hint.isNotEmpty)
          Text(hint, style: appText(size: 11, color: AppColors.muted)),
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
        Text(
          'Ảnh lấy hàng lần ${p.submissionCount}/5',
          style: appText(size: 12.5, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        PhotoStrip(p.pickupPhotoUrls),
        if (p.rejectionReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Lý do từ chối gần nhất: ${p.rejectionReason}',
              style: appText(size: 12, color: AppColors.red),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Ảnh giao hàng',
          style: appText(size: 12.5, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        PhotoStrip([
          if (p.deliveryPhotoUrl != null) p.deliveryPhotoUrl!,
        ], emptyText: 'Chưa giao hàng'),
        if (p.deliveredAt != null)
          Text(
            'Giao lúc ${dateTime(p.deliveredAt!)}',
            style: appText(size: 11.5, color: AppColors.muted),
          ),
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
        ? Text(
            o.status == OrderStatus.cancelled
                ? 'Không có tài xế.'
                : 'Chưa có tài xế nhận đơn.',
            style: appText(size: 13, color: AppColors.secondary),
          )
        : Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.ink,
                child: Text(
                  o.driver!.fullName.isEmpty ? 'T' : o.driver!.fullName[0],
                  style: appText(color: Colors.white, weight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.driver!.fullName,
                      style: appText(size: 15, weight: FontWeight.w700),
                    ),
                    Text(
                      '${o.vehicleTypeName} • ${o.driver!.licensePlate ?? '—'}',
                      style: appText(size: 12.5, color: AppColors.secondary),
                    ),
                    Text(
                      o.driver!.phoneNumber,
                      style: appText(size: 13, weight: FontWeight.w600),
                    ),
                  ],
                ),
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
        _place(
          'target',
          AppColors.green,
          'Điểm giao • ${o.receiverName}',
          o.dropoffAddress,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, top: 4),
          child: Row(
            children: [
              Flexible(
                child: PhoneText(
                  o.receiverPhone,
                  style: appText(size: 13, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${o.distanceKm} km • ~${o.durationMin} phút • ${o.vehicleTypeName}${o.hasLoadingService ? ' • Có bốc xếp' : ''}',
          style: appText(size: 12, color: AppColors.muted),
        ),
        const Divider(height: 22),
        KvRow('Loại hàng', o.cargo.cargoTypeName ?? o.cargo.cargoType),
        KvRow(
          'Số lượng / KL',
          '${o.cargo.quantity} kiện • ${o.cargo.weightKg} kg',
        ),
        KvRow(
          'Món lớn nhất',
          '${o.cargo.lengthCm}×${o.cargo.widthCm}×${o.cargo.heightCm} cm',
        ),
        if (o.cargo.specialNotes != null)
          KvRow('Ghi chú', o.cargo.specialNotes!),
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
        KvRow('Cước quãng đường ${o.distanceKm} km', money(o.distanceFee)),
        if (o.serviceFee > 0) KvRow('Phí bốc xếp', money(o.serviceFee)),
        if (o.discountAmount > 0)
          KvRow(
            'Giảm giá ${o.couponCode ?? ''}',
            '-${money(o.discountAmount)}',
            valueColor: AppColors.green,
          ),
        const Divider(),
        KvRow('Tổng cước', money(o.totalFee), strong: true),
        KvRow(
          'Hình thức',
          paymentMethodLabel[o.paymentMethod] ?? o.paymentMethod,
        ),
        if (o.payerRole != null)
          KvRow('Người trả', payerRoleLabel[o.payerRole] ?? o.payerRole!),
        KvRow('Trạng thái', toneOf(paymentStatusTone, o.paymentStatus).label),
        if (o.payment?.paidAt != null)
          KvRow('Thanh toán lúc', dateTime(o.payment!.paidAt!)),
      ],
    ),
  );
}

class _IncidentsCard extends StatelessWidget {
  const _IncidentsCard({
    super.key,
    required this.order,
    required this.incidents,
    required this.refunds,
    required this.onReport,
    required this.onRefund,
    required this.onReply,
    required this.onPayout,
    required this.onWithdraw,
  });
  final OrderDetail order;
  final List<MyIncident> incidents;
  final List<MyRefund> refunds;
  final VoidCallback onReport;
  final ValueChanged<MyIncident> onRefund;
  final ValueChanged<MyRefund> onReply, onPayout, onWithdraw;
  List<MyRefund> _linkedRefunds(MyIncident i) => [
    for (final r in refunds)
      // Gồm cả hoàn "huỷ đơn vì sự cố" (sourceType=Cancellation nhưng có incidentId).
      if (r.incidentId == i.id) r,
  ];

  @override
  Widget build(BuildContext context) {
    final canReport = OrderRules.canReportIncident(order);
    if (incidents.isEmpty && !canReport) return const SizedBox.shrink();
    return SectionCard(
      title: 'Sự cố ${incidents.length}',
      trailing: canReport
          ? TextButton(onPressed: onReport, child: const Text('Báo sự cố'))
          : null,
      child: incidents.isEmpty
          ? Text(
              'Chưa có sự cố nào.',
              style: appText(size: 13, color: AppColors.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in [
                  (
                    title: 'Tài xế báo',
                    items: incidents.where((i) => !i.reportedByYou).toList(),
                  ),
                  (
                    title: 'Bạn báo',
                    items: incidents.where((i) => i.reportedByYou).toList(),
                  ),
                ])
                  if (group.items.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        group.title.toUpperCase(),
                        style: appText(
                          size: 11,
                          weight: FontWeight.w800,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    for (final i in group.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          color: AppColors.pale,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '#${i.id} – ${incidentTypeLabel[i.incidentType] ?? i.incidentType}',
                                      style: appText(
                                        size: 13,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Pill(toneOf(incidentStatusTone, i.status)),
                                ],
                              ),
                              Text(
                                dateTime(i.createdAt),
                                style: appText(
                                  size: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(i.description, style: appText(size: 13)),
                              if (i.photoUrls.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: PhotoStrip(i.photoUrls, size: 54),
                                ),
                              if (i.status == 'InProgress')
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Điều phối viên đang xử lý',
                                    style: appText(
                                      size: 12.5,
                                      weight: FontWeight.w600,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                ),
                              if (i.status == 'Resolved' && i.decision != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Kết quả: ${incidentDecisionLabel[i.decision] ?? i.decision}${i.note == null ? '' : ' – ${i.note}'}',
                                    style: appText(
                                      size: 12.5,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (i.status == 'Cancelled')
                                Text(
                                  'Báo cáo đã bị hủy${i.note == null ? '' : ': ${i.note}'}',
                                  style: appText(
                                    size: 12,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              // Khoản hoàn của riêng sự cố này nằm ngay trong thẻ; còn khoản mở thì không gửi thêm.
                              ..._linkedRefunds(i).map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _RefundTile(
                                    r,
                                    onReply: onReply,
                                    onPayout: onPayout,
                                    onWithdraw: onWithdraw,
                                    nested: true,
                                  ),
                                ),
                              ),
                              if (OrderRules.canRequestIncidentRefund(order) &&
                                  !_linkedRefunds(i).any(
                                    (r) =>
                                        r.isOpen ||
                                        r.sourceType == 'Cancellation',
                                  ))
                                TextButton(
                                  onPressed: () => onRefund(i),
                                  child: const Text(
                                    'Yêu cầu hoàn tiền cho sự cố này',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}

class _RefundsCard extends StatelessWidget {
  const _RefundsCard({
    required this.refunds,
    required this.onReply,
    required this.onWithdraw,
    required this.onPayout,
  });
  final List<MyRefund> refunds;
  final ValueChanged<MyRefund> onReply, onWithdraw, onPayout;
  @override
  Widget build(BuildContext context) {
    if (refunds.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Hoàn tiền và khiếu nại ${refunds.length}',
      child: Column(
        children: [
          for (final r in refunds)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RefundTile(
                r,
                onReply: onReply,
                onPayout: onPayout,
                onWithdraw: onWithdraw,
              ),
            ),
        ],
      ),
    );
  }
}

/// Một khoản hoàn tiền (dùng trong thẻ Hoàn tiền & khiếu nại và bên trong thẻ sự cố tương ứng).
class _RefundTile extends StatelessWidget {
  const _RefundTile(
    this.r, {
    required this.onReply,
    required this.onPayout,
    required this.onWithdraw,
    this.nested = false,
  });
  final MyRefund r;
  final ValueChanged<MyRefund> onReply, onPayout, onWithdraw;

  /// Nằm trong thẻ sự cố: nền trắng để tách khỏi nền xám của thẻ sự cố.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.pale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${refundSourceLabel[r.sourceType] ?? r.sourceType} #${r.id}',
                  style: appText(size: 13, weight: FontWeight.w700),
                ),
              ),
              Pill(refundTone(r.status)),
            ],
          ),
          Text(
            dateTime(r.createdAt),
            style: appText(size: 11, color: AppColors.muted),
          ),
          if (r.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(r.reason, style: appText(size: 13)),
            ),
          const SizedBox(height: 4),
          Text(
            'Yêu cầu: ${money(r.requestedAmount)}${r.approvedAmount == null ? '' : ' • Được duyệt: ${money(r.approvedAmount!)}'}',
            style: appText(size: 12.5, weight: FontWeight.w600),
          ),
          if (r.processedAt != null)
            Text(
              'Đã chuyển khoản ${dateTime(r.processedAt!)}',
              style: appText(size: 12, color: AppColors.green),
            ),
          if (r.evidenceUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: PhotoStrip(r.evidenceUrls, size: 54),
            ),
          if (r.infoRequestNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Notice(
                'Điều phối viên hỏi: ${r.infoRequestNote}',
                icon: 'info',
                peach: true,
                detail: r.customerReply == null
                    ? null
                    : 'Bạn trả lời: ${r.customerReply}',
              ),
            ),
          if (r.decisionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Quyết định của Admin: ${r.decisionReason}',
                style: appText(size: 12.5),
              ),
            ),
          if (r.payoutAccount != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tài khoản nhận hoàn tiền: ${r.payoutAccount!.bankName} • ${r.payoutAccount!.maskedAccountNumber} • ${r.payoutAccount!.accountHolder}',
                style: appText(size: 12.5),
              ),
            ),
          if (r.needsPayoutAccount)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Notice(
                'Bạn chưa khai tài khoản nhận hoàn tiền nên quản trị viên chưa thể chuyển khoản.',
                icon: 'warning',
                peach: true,
              ),
            ),
          if (r.payoutFailureReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Notice(
                'Chuyển khoản hoàn tiền bị lỗi: ${r.payoutFailureReason}. Hãy kiểm tra hoặc nhập tài khoản khác.',
                icon: 'warning',
                peach: true,
              ),
            ),
          if (r.bankReferenceCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Mã chuyển khoản: ${r.bankReferenceCode}',
                style: appText(size: 12.5),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (r.needsPayoutAccount ||
                  r.status == 'Failed' ||
                  (r.payoutAccount != null &&
                      (r.status == 'Requested' || r.status == 'Approved')))
                TextButton(
                  onPressed: () => onPayout(r),
                  child: Text(
                    r.payoutAccount == null
                        ? 'Khai tài khoản nhận tiền'
                        : 'Sửa tài khoản nhận tiền',
                  ),
                ),
              if (r.waitingForYourReply)
                TextButton(
                  onPressed: () => onReply(r),
                  child: const Text('Bổ sung thông tin'),
                ),
              if (OrderRules.canWithdrawRefund(r))
                TextButton(
                  onPressed: () => onWithdraw(r),
                  child: const Text('Rút yêu cầu'),
                ),
            ],
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
        Row(
          children: [
            for (var n = 1; n <= 5; n++)
              Icon(
                n <= r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.amber,
                size: 22,
              ),
          ],
        ),
        if (r.comment != null)
          Text(
            '“${r.comment}”',
            style: appText(size: 13, color: AppColors.secondary),
          ),
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
                  CircleAvatar(
                    radius: 5,
                    backgroundColor: i == o.history.length - 1
                        ? AppColors.orange
                        : AppColors.line,
                  ),
                  if (i < o.history.length - 1)
                    Container(width: 2, height: 38, color: AppColors.line),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        toneOf(orderStatusTone, h.toStatus).label,
                        style: appText(size: 13, weight: FontWeight.w700),
                      ),
                      Text(
                        '${dateTime(h.changedAt)} • ${changedByLabel[h.changedByRole] ?? h.changedByRole}',
                        style: appText(size: 11, color: AppColors.muted),
                      ),
                      if (h.note != null)
                        Text(
                          '“${h.note}”',
                          style: appText(size: 12, color: AppColors.secondary),
                        ),
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
