import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../domain/customer_models.dart';
import 'customer_cubits.dart';
import 'customer_map.dart';
import 'customer_widgets.dart';
import 'customer_payment_receipt.dart';

class CustomerOrderScreen extends StatefulWidget {
  const CustomerOrderScreen({super.key});
  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen>
    with WidgetsBindingObserver {
  bool trackingRequested = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      context.read<CustomerOrderCubit>().refresh();
    }
  }

  Future<void> confirmReceipt(OrderDetail order) async {
    final cubit = context.read<CustomerOrderCubit>();
    if (await confirmCustomerAction(
      context,
      'Bạn đã nhận đủ hàng?',
      'Chỉ xác nhận khi đã kiểm tra hàng. Đơn sẽ hoàn thành và tài xế được quyết toán; sau đó không thể mở khiếu nại giao hàng.',
    )) {
      await cubit.act(() => cubit.repository.confirmReceipt(order.summary.id));
    }
  }

  Future<void> review(OrderDetail order, bool approve) async {
    final cubit = context.read<CustomerOrderCubit>();
    String reason = '';
    if (!approve) {
      final result = await showDialog<String>(
        context: context,
        builder: (_) => const _ReasonDialog(),
      );
      if (result == null) return;
      reason = result;
    } else if (!await confirmCustomerAction(
      context,
      'Duyệt ảnh lấy hàng?',
      'Xác nhận ảnh thể hiện đúng hàng và tình trạng hàng của bạn. Tài xế sẽ bắt đầu giao hàng.',
    )) {
      return;
    }
    await cubit.act(
      () => cubit.repository.reviewPickup(order.summary.id, approve, reason),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CustomerOrderCubit, OrderState>(
    listener: (context, s) {
      if (s.order != null && !trackingRequested && !s.order!.summary.terminal) {
        trackingRequested = true;
        context.read<CustomerOrderCubit>().loadTracking();
      }
    },
    builder: (context, s) {
      final cubit = context.read<CustomerOrderCubit>(), o = s.order;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            o == null
                ? 'Chi tiết đơn hàng'
                : o.summary.needsPayment
                ? 'Thanh toán đơn hàng'
                : o.canReview
                ? 'Kiểm tra hàng hóa'
                : o.canConfirm
                ? 'Xác nhận nhận hàng'
                : o.summary.status == 'Pending'
                ? 'Đang tìm tài xế'
                : 'Theo dõi đơn hàng',
          ),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: s.acting ? null : cubit.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (s.busy || s.acting) const LinearProgressIndicator(),
              if (s.error != null) CustomerNotice(s.error!, error: true),
              if (o == null && !s.busy)
                OutlinedButton(
                  onPressed: cubit.refresh,
                  child: const Text('Tải lại đơn'),
                ),
              if (o != null) ...[
                CustomerCard(
                  color: AppColors.peach,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(
                        o.summary.needsPayment
                            ? 'AwaitingPayment'
                            : o.summary.status,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        o.summary.needsPayment
                            ? 'Thanh toán để tìm tài xế'
                            : _headline(o.summary.status),
                        style: appText(size: 23, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cập nhật lúc ${dateLabel(o.history.isEmpty ? o.summary.created : o.history.last.at)}',
                      ),
                      if (o.summary.status == 'Pending') ...[
                        const SizedBox(height: 12),
                        if (o.summary.needsPayment)
                          const Text('Thanh toán PayOS để bắt đầu tìm tài xế.')
                        else if (o.matchingStarted != null)
                          _LiveTime(
                            start: o.matchingStarted!,
                            duration: const Duration(minutes: 10),
                            label: 'Thời gian tìm tài xế còn lại',
                            expired:
                                'Hết thời gian dự kiến. Đang chờ hệ thống xác nhận trạng thái đơn.',
                          )
                        else
                          const Text(
                            'Đơn đang được gửi đến các tài xế phù hợp. Thời gian tìm tối đa 10 phút kể từ khi thanh toán.',
                          ),
                      ],
                    ],
                  ),
                ),
                if (o.summary.needsPayment)
                  _OrderPayment(
                    order: o,
                    payment: s.payment,
                    busy: s.acting,
                    onCreate: cubit.createPayment,
                    onRefresh: cubit.refresh,
                  ),
                if (o.pendingDriverIncident)
                  const CustomerNotice(
                    'Chuyến đang tạm dừng do sự cố tài xế. Điều phối đang xử lý; bạn chưa thể duyệt ảnh lấy hàng.',
                  ),
                if (!o.summary.terminal &&
                    !o.summary.needsPayment &&
                    !o.canReview &&
                    !o.canConfirm) ...[
                  if (s.tracking != null) ...[
                    CustomerTrackingMap(
                      s.tracking!,
                      searching: o.summary.status == 'Pending',
                    ),
                    const SizedBox(height: 14),
                    if (s.tracking!.driver != null)
                      _DriverPositionInfo(s.tracking!),
                  ],
                  if (s.trackingError != null)
                    CustomerNotice(s.trackingError!, error: true),
                  TextButton.icon(
                    onPressed: cubit.loadTracking,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Cập nhật vị trí và thời gian đến'),
                  ),
                ],
                if (o.pickupPhotos.isNotEmpty) ...[
                  sectionTitle('Ảnh kiểm tra khi lấy hàng'),
                  Text(
                    'Trạng thái ảnh: ${switch (o.proofStatus) {
                      'Pending' => 'Chờ bạn duyệt',
                      'Verified' => 'Đã duyệt',
                      'Rejected' => 'Cần chụp lại',
                      _ => o.proofStatus,
                    }}',
                  ),
                  const SizedBox(height: 12),
                  PhotoStrip(o.pickupPhotos, large: true),
                  if (o.pickupSubmissionCount > 0)
                    Text(
                      'Lần gửi ảnh: ${o.pickupSubmissionCount}/5',
                      style: appText(size: 12),
                    ),
                  if (o.pickupRejection.isNotEmpty)
                    CustomerNotice('Nội dung cần sửa: ${o.pickupRejection}'),
                  const SizedBox(height: 16),
                  if (o.canReview)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          child: OutlinedButton(
                            onPressed: s.acting ? null : () => review(o, false),
                            child: const Text('Yêu cầu chụp lại'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          child: FilledButton(
                            onPressed: s.acting ? null : () => review(o, true),
                            child: const Text('Duyệt ảnh'),
                          ),
                        ),
                      ],
                    ),
                ],
                if (o.deliveryPhoto.isNotEmpty) ...[
                  sectionTitle('Bằng chứng giao hàng'),
                  PhotoStrip([o.deliveryPhoto], large: true),
                  const SizedBox(height: 12),
                ],
                if (o.canConfirm) ...[
                  const CustomerNotice(
                    'Kiểm tra hàng trước khi xác nhận. Nếu hàng có vấn đề, hãy tạo khiếu nại trong 24 giờ sau giao hàng.',
                  ),
                  FilledButton(
                    onPressed: s.acting ? null : () => confirmReceipt(o),
                    child: const Text('Tôi đã nhận đủ hàng'),
                  ),
                ],
                if (o.canComplainAt(DateTime.now()))
                  TextButton.icon(
                    onPressed: s.acting
                        ? null
                        : () async {
                            await Navigator.pushNamed(
                              context,
                              '/complaint',
                              arguments: o,
                            );
                            if (mounted) cubit.refresh();
                          },
                    icon: const Icon(Icons.report_outlined),
                    label: const Text('Khiếu nại giao hàng'),
                  ),
                if (o.canRateAt(DateTime.now()))
                  OutlinedButton.icon(
                    onPressed: s.acting
                        ? null
                        : () async {
                            await Navigator.pushNamed(
                              context,
                              '/rate',
                              arguments: o.summary.id,
                            );
                            if (mounted) cubit.refresh();
                          },
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Đánh giá chuyến giao'),
                  ),
                CustomerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle('Hành trình'),
                      CustomerRouteSummary(
                        pickup: o.summary.pickup,
                        dropoff: o.summary.dropoff,
                      ),
                      const SizedBox(height: 12),
                      detailRow(
                        'Người nhận',
                        '${o.summary.receiver} · ${o.summary.phone}',
                      ),
                      detailRow('Loại xe', o.summary.vehicle),
                      if (o.driverName.isNotEmpty) ...[
                        const Divider(),
                        detailRow('Tài xế', o.driverName),
                        detailRow('Biển số xe', o.plate),
                        OutlinedButton.icon(
                          onPressed: () => openExternal(
                            context,
                            Uri(scheme: 'tel', path: o.driverPhone),
                          ),
                          icon: const Icon(Icons.call_outlined),
                          label: Text('Gọi tài xế · ${o.driverPhone}'),
                        ),
                      ],
                    ],
                  ),
                ),
                sectionTitle('Hàng hóa của bạn'),
                CustomerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      detailRow('Loại hàng', o.cargoType),
                      detailRow(
                        'Số lượng',
                        '${o.quantity} kiện · ${o.weight} kg',
                      ),
                      detailRow(
                        'Kích thước',
                        '${o.length} × ${o.width} × ${o.height} cm',
                      ),
                      if (o.notes.isNotEmpty) Text(o.notes),
                      const SizedBox(height: 12),
                      PhotoStrip(o.photos),
                    ],
                  ),
                ),
                sectionTitle('Thanh toán & biên nhận'),
                CustomerCard(
                  child: Column(
                    children: [
                      detailRow(
                        'Phương thức',
                        statusLabel(o.summary.paymentMethod),
                      ),
                      detailRow(
                        'Trạng thái',
                        statusLabel(o.summary.paymentStatus),
                      ),
                      if (o.paymentPaidAt != null)
                        detailRow(
                          'Thời điểm thanh toán',
                          dateLabel(o.paymentPaidAt!),
                        ),
                      if (o.couponCode.isNotEmpty)
                        detailRow('Mã giảm giá', o.couponCode),
                      if (o.summary.paymentMethod == 'Cash')
                        detailRow(
                          'Người trả tiền',
                          o.payer == 'Receiver' ? 'Người nhận' : 'Người gửi',
                        ),
                      priceBreakdown(
                        o.distanceFee,
                        o.serviceFee,
                        o.discount,
                        o.summary.total,
                      ),
                      if (o.summary.paymentStatus == 'Paid')
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CustomerPaymentReceipt(o),
                            ),
                          ),
                          icon: const AppIcon(
                            'receipt',
                            size: 18,
                            color: AppColors.orange,
                          ),
                          label: const Text('Xem biên nhận thanh toán'),
                        ),
                    ],
                  ),
                ),
                sectionTitle('Tiến trình đơn hàng'),
                for (final h in o.history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.orange,
                    ),
                    title: Text(statusLabel(h.status)),
                    subtitle: Text(
                      '${dateLabel(h.at)}${h.note.isEmpty ? '' : '\n${h.note}'}',
                    ),
                  ),
                if (o.summary.canReport)
                  OutlinedButton.icon(
                    onPressed: s.acting
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            '/report',
                            arguments: o.summary.id,
                          ),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Báo sự cố trong chuyến'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/incidents',
                    arguments: o.summary.id,
                  ),
                  child: const Text('Theo dõi sự cố và yêu cầu hoàn tiền'),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/refunds'),
                  child: const Text('Xem khiếu nại và khoản hoàn tiền'),
                ),
                if (o.summary.terminal)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Đặt lại với thông tin này'),
                    onPressed: s.acting
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            '/booking',
                            arguments: BookingDraft.fromOrder(o),
                          ),
                  ),
                if (o.summary.canCancel)
                  TextButton(
                    onPressed: s.acting
                        ? null
                        : () async {
                            final result =
                                await showModalBottomSheet<(String, String)>(
                                  context: context,
                                  isScrollControlled: true,
                                  showDragHandle: true,
                                  builder: (_) => BlocProvider(
                                    create: (_) => ResourceCubit<List<Choice>>(
                                      () => cubit.repository.choices(
                                        'cancellation-reasons',
                                      ),
                                    )..load(),
                                    child: const _CancelOrder(),
                                  ),
                                );
                            if (result != null) {
                              await cubit.act(
                                () => cubit.repository.cancel(
                                  o.summary.id,
                                  result.$1,
                                  result.$2,
                                ),
                              );
                            }
                          },
                    child: const Text('Hủy đơn hàng'),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
  String _headline(String status) => switch (status) {
    'Pending' => 'Đang kết nối tài xế gần bạn',
    'Accepted' => 'Tài xế đã nhận chuyến',
    'Arrived' => 'Tài xế đã đến lấy hàng',
    'PickedUp' => 'Kiểm tra ảnh hàng hóa',
    'InTransit' => 'Hàng đang trên đường',
    'Delivered' => 'Hàng đã được giao',
    'Completed' => 'Cảm ơn bạn đã tin chọn!',
    'Cancelled' => 'Đơn hàng đã hủy',
    _ => statusLabel(status),
  };
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final text = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Yêu cầu chụp lại'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: text,
        maxLength: 500,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Nội dung cần bổ sung hoặc thay đổi',
        ),
        validator: (v) => (v ?? '').trim().isEmpty
            ? 'Nhập lý do để tài xế sửa đúng ảnh'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, text.text.trim());
          }
        },
        child: const Text('Gửi yêu cầu'),
      ),
    ],
  );
}

class _CancelOrder extends StatefulWidget {
  const _CancelOrder();
  @override
  State<_CancelOrder> createState() => _CancelOrderState();
}

class _CancelOrderState extends State<_CancelOrder> {
  String? code;
  final reason = TextEditingController(), form = GlobalKey<FormState>();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .78,
    child: BlocBuilder<ResourceCubit<List<Choice>>, ResourceState<List<Choice>>>(
      builder: (context, s) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CustomerPageHeading('Hủy đơn hàng?'),
              const CustomerNotice(
                'Chỉ hủy được khi đang tìm tài xế hoặc tài xế chưa đến. Đơn PayOS đã trả tiền sẽ được hệ thống tạo yêu cầu hoàn tiền.',
              ),
              if (s.busy) const LinearProgressIndicator(),
              if (s.error != null) ...[
                CustomerNotice(s.error!, error: true),
                TextButton(
                  onPressed: context.read<ResourceCubit<List<Choice>>>().load,
                  child: const Text('Thử lại'),
                ),
              ],
              if (s.data != null)
                DropdownButtonFormField<String>(
                  initialValue: code,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lý do hủy'),
                  items: s.data!
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => code = v),
                  validator: (v) => v == null ? 'Chọn lý do' : null,
                ),
              const SizedBox(height: 18),
              TextFormField(
                controller: reason,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Chi tiết lý do'),
                validator: (v) => code == 'OTHER' && (v ?? '').trim().isEmpty
                    ? 'Nhập lý do cụ thể'
                    : null,
              ),
              FilledButton(
                onPressed: s.data == null
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        if (await confirmCustomerAction(
                              context,
                              'Xác nhận hủy đơn?',
                              'Thao tác này không thể hoàn tác.',
                              action: 'Hủy đơn',
                              destructive: true,
                            ) &&
                            context.mounted) {
                          Navigator.pop(context, (code!, reason.text.trim()));
                        }
                      },
                child: const Text('Xác nhận hủy đơn'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OrderPayment extends StatelessWidget {
  const _OrderPayment({
    required this.order,
    required this.payment,
    required this.busy,
    required this.onCreate,
    required this.onRefresh,
  });
  final OrderDetail order;
  final PaymentLink? payment;
  final bool busy;
  final VoidCallback onCreate, onRefresh;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _ClockCubit(),
    child: BlocBuilder<_ClockCubit, DateTime>(
      builder: (context, now) {
        final expires = payment?.expires ?? order.paymentExpires;
        final expired = expires != null && !now.isBefore(expires);
        final url = expired ? '' : payment?.url ?? order.checkoutUrl;
        return CustomerCard(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                order.summary.code,
                textAlign: TextAlign.center,
                style: appText(size: 15, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                money(order.summary.total),
                textAlign: TextAlign.center,
                style: appText(
                  size: 38,
                  weight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'PayOS / VietQR',
                textAlign: TextAlign.center,
                style: appText(size: 18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (payment != null && !expired && payment!.qr.isNotEmpty)
                Center(
                  child: QrImageView(
                    data: payment!.qr,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              if (expires != null && !expired)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Mã hết hạn sau ${expires.difference(now).inMinutes.toString().padLeft(2, '0')}:${(expires.difference(now).inSeconds % 60).toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: appText(
                      color: AppColors.amber,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              if (expired)
                const Text(
                  'Mã thanh toán đã hết hạn. Hãy tạo mã mới cho đơn này.',
                ),
              if (url.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => openExternal(context, Uri.parse(url)),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở trang thanh toán'),
                ),
              if (url.isEmpty)
                FilledButton(
                  onPressed: busy ? null : onCreate,
                  child: Text(
                    expired ? 'Tạo lại mã PayOS' : 'Tạo mã thanh toán PayOS',
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : onRefresh,
                child: const Text('Kiểm tra kết quả thanh toán'),
              ),
              const Text(
                'Chỉ chuyển tiền bằng mã hiện tại. Trạng thái sẽ được cập nhật khi hệ thống nhận xác nhận từ PayOS.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ClockCubit extends Cubit<DateTime> {
  _ClockCubit() : super(DateTime.now()) {
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => emit(DateTime.now()),
    );
  }
  late final Timer timer;
  @override
  Future<void> close() {
    timer.cancel();
    return super.close();
  }
}

class _LiveTime extends StatelessWidget {
  const _LiveTime({
    required this.start,
    required this.duration,
    required this.label,
    required this.expired,
  });
  final DateTime start;
  final Duration duration;
  final String label, expired;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _ClockCubit(),
    child: BlocBuilder<_ClockCubit, DateTime>(
      builder: (context, now) {
        final seconds = start
            .add(duration)
            .difference(now)
            .inSeconds
            .clamp(0, duration.inSeconds);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(seconds == 0 ? expired : label),
            if (seconds > 0)
              Text(
                '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                style: appText(
                  size: 30,
                  weight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _DriverPositionInfo extends StatelessWidget {
  const _DriverPositionInfo(this.tracking);
  final TrackingSnapshot tracking;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _ClockCubit(),
    child: BlocBuilder<_ClockCubit, DateTime>(
      builder: (context, now) {
        final stale =
            tracking.stale ||
            tracking.at == null ||
            now.difference(tracking.at!) >= const Duration(minutes: 5);
        return CustomerNotice(
          stale
              ? 'GPS tài xế đã cũ hoặc mất kết nối. Vị trí hiển thị là lần ghi nhận cuối.'
              : tracking.minutes != null
              ? 'Dự kiến đến ${switch (tracking.target) {
                  'Pickup' => 'điểm lấy hàng',
                  'Handover' => 'điểm bàn giao giữa hai tài xế',
                  'Dropoff' => 'điểm giao hàng',
                  _ => 'điểm đến',
                }}: ${tracking.minutes} phút.'
              : 'Vị trí tài xế được cập nhật lúc ${dateLabel(tracking.at!)}. Chưa có thời gian đến mới.',
        );
      },
    ),
  );
}
