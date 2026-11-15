import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';
import '../domain/customer_places.dart';
import 'customer_cubits.dart';
import 'customer_map.dart';
import 'customer_widgets.dart';

class CustomerBookingScreen extends StatefulWidget {
  const CustomerBookingScreen({super.key, required this.onCreated});
  final void Function(int) onCreated;
  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  final _form = GlobalKey<FormState>();
  final _pickup = TextEditingController(), _dropoff = TextEditingController();
  final _coupon = TextEditingController();
  int step = 0;
  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _coupon.dispose();
    super.dispose();
  }

  BookingCubit get cubit => context.read<BookingCubit>();
  Future<void> checkCreatedOrder() async {
    await Navigator.pushNamed(context, '/orders');
    if (!mounted) return;
    final checked = await confirmCustomerAction(
      context,
      'Đã kiểm tra danh sách đơn?',
      'Chỉ gửi lại nếu bạn chắc chắn chưa có đơn vừa đặt trong danh sách. Nếu đã có đơn, quay về và mở đơn đó.',
      action: 'Chưa có đơn, cho phép gửi lại',
    );
    if (checked && mounted) cubit.confirmedNoOrderCreated();
  }

  Future<void> chooseAddress(bool pickup) async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => PlaceCubit(context.read<CustomerPlaces>()),
          child: const CustomerPlaceScreen(),
        ),
      ),
    );
    if (value == null || !mounted) return;
    (pickup ? _pickup : _dropoff).text = value;
    cubit.edit(
      pickup
          ? cubit.state.draft.copyWith(pickup: value)
          : cubit.state.draft.copyWith(dropoff: value),
    );
  }

  Widget field(
    String label,
    String value,
    void Function(String) changed, {
    bool number = false,
    int? maxLength,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(label),
      initialValue: value,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLength: maxLength,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, counterText: ''),
      onChanged: changed,
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Vui lòng nhập ${label.toLowerCase()}'
          : null,
    ),
  );
  Future<void> addPhoto() async {
    try {
      final image = await pickCustomerPhoto(context);
      if (image != null && mounted) {
        await cubit.upload(image.name, await image.readAsBytes());
      }
    } catch (_) {
      if (mounted) {
        cubit.error('Chưa chọn được ảnh. Kiểm tra quyền camera hoặc thư viện.');
      }
    }
  }

  void next() {
    if (!_form.currentState!.validate()) return;
    final d = cubit.state.draft;
    if (step == 0 &&
        !RegExp(r'^(0[0-9]{9}|\+84[0-9]{9})$').hasMatch(d.phone.trim())) {
      cubit.error('Nhập số điện thoại Việt Nam hợp lệ của người nhận.');
      return;
    }
    if (step == 1 &&
        (d.photos.isEmpty ||
            d.cargoType.isEmpty ||
            d.quantity < 1 ||
            d.weight <= 0 ||
            [d.length, d.width, d.height].any((v) => v < 1 || v > 2000))) {
      cubit.error(
        'Nhập đầy đủ loại hàng, số lượng, cân nặng, kích thước và tải ít nhất 1 ảnh.',
      );
      return;
    }
    if (step == 2 && cubit.state.fare == null) {
      cubit.error('Chọn xe và tính giá cước trước khi tiếp tục.');
      return;
    }
    setState(() => step++);
  }

  Future<void> coupons() async {
    final repo = context.read<CustomerRepository>();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider(
        create: (_) => PagedCubit<Coupon>((page) => repo.coupons(page))..load(),
        child: const _CouponSheet(),
      ),
    );
    if (selected != null && mounted) {
      _coupon.text = selected;
      cubit.edit(cubit.state.draft.copyWith(coupon: selected));
    }
  }

  void policies(List<Choice> values) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          sectionTitle('Chính sách dịch vụ'),
          if (values.isEmpty)
            const Text('Chưa có nội dung chính sách được công bố.'),
          for (final p in values) ...[
            sectionTitle(p.name),
            SelectableText(p.description),
            const Divider(),
          ],
        ],
      ),
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<BookingCubit, BookingState>(
    listenWhen: (a, b) => a.created != b.created,
    listener: (_, s) {
      if (s.created != null) widget.onCreated(s.created!.id);
    },
    builder: (context, s) {
      final d = s.draft, catalog = s.catalog, locked = s.busy || s.uploading;
      return PopScope(
        canPop: !locked,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Đặt giao hàng'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: locked
                  ? null
                  : () => step > 0
                        ? setState(() => step--)
                        : Navigator.maybePop(context),
            ),
          ),
          bottomNavigationBar: catalog == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: FilledButton(
                      onPressed: locked
                          ? null
                          : s.needsOrderCheck
                          ? checkCreatedOrder
                          : step == 3
                          ? cubit.submit
                          : next,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          s.busy
                              ? 'Đang xử lý…'
                              : s.uploading
                              ? 'Đang tải ảnh…'
                              : s.needsOrderCheck
                              ? 'Kiểm tra đơn vừa gửi'
                              : step == 3
                              ? 'Xác nhận đặt đơn'
                              : 'Tiếp tục',
                        ),
                      ),
                    ),
                  ),
                ),
          body: catalog == null
              ? Center(
                  child: s.error == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: CustomerNotice(s.error!, error: true),
                            ),
                            OutlinedButton(
                              onPressed: cubit.initialize,
                              child: const Text('Tải lại danh mục'),
                            ),
                          ],
                        ),
                )
              : AbsorbPointer(
                  absorbing: locked || s.needsOrderCheck,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: List.generate(
                              4,
                              (i) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: i <= step
                                              ? AppColors.orange
                                              : AppColors.line,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        [
                                          'Địa chỉ',
                                          'Hàng hóa',
                                          'Loại xe',
                                          'Thanh toán',
                                        ][i],
                                        style: appText(
                                          size: 11,
                                          weight: i == step
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: i <= step
                                              ? AppColors.orange
                                              : AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (s.error != null)
                            CustomerNotice(s.error!, error: true),
                          if (step == 0) ...[
                            sectionTitle('Hàng của bạn đi đâu?'),
                            const Text(
                              'Nhập địa chỉ đầy đủ để tài xế tìm đúng điểm lấy và giao hàng.',
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _pickup,
                              decoration: InputDecoration(
                                labelText: 'Địa chỉ lấy hàng',
                                prefixIcon: const Icon(
                                  Icons.trip_origin,
                                  color: AppColors.orange,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Chọn trên bản đồ',
                                  onPressed: () => chooseAddress(true),
                                  icon: const Icon(Icons.map_outlined),
                                ),
                              ),
                              onChanged: (v) =>
                                  cubit.edit(d.copyWith(pickup: v)),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Nhập địa chỉ lấy hàng'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _dropoff,
                              decoration: InputDecoration(
                                labelText: 'Địa chỉ giao hàng',
                                prefixIcon: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.green,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Chọn trên bản đồ',
                                  onPressed: () => chooseAddress(false),
                                  icon: const Icon(Icons.map_outlined),
                                ),
                              ),
                              onChanged: (v) =>
                                  cubit.edit(d.copyWith(dropoff: v)),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Nhập địa chỉ giao hàng'
                                  : null,
                            ),
                            sectionTitle('Thông tin người nhận'),
                            field(
                              'Tên người nhận',
                              d.receiver,
                              (v) => cubit.edit(d.copyWith(receiver: v)),
                              maxLength: 100,
                            ),
                            field(
                              'Số điện thoại người nhận',
                              d.phone,
                              (v) => cubit.edit(d.copyWith(phone: v)),
                              number: true,
                              maxLength: 12,
                            ),
                          ],
                          if (step == 1) ...[
                            sectionTitle('Bạn cần gửi gì?'),
                            DropdownButtonFormField<String>(
                              initialValue: d.cargoType.isEmpty
                                  ? null
                                  : d.cargoType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Loại hàng',
                              ),
                              items: catalog.cargoTypes
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.code,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  cubit.edit(d.copyWith(cargoType: v)),
                              validator: (v) =>
                                  v == null ? 'Chọn loại hàng' : null,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: field(
                                    'Số kiện',
                                    d.quantity.toString(),
                                    (v) => cubit.edit(
                                      d.copyWith(
                                        quantity: int.tryParse(v) ?? 0,
                                      ),
                                    ),
                                    number: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: field(
                                    'Tổng cân nặng (kg)',
                                    d.weight == 0 ? '' : d.weight.toString(),
                                    (v) => cubit.edit(
                                      d.copyWith(
                                        weight: double.tryParse(v) ?? 0,
                                      ),
                                    ),
                                    number: true,
                                  ),
                                ),
                              ],
                            ),
                            const Text('Kích thước kiện lớn nhất'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: field(
                                    'Dài (cm)',
                                    d.length == 0 ? '' : '${d.length}',
                                    (v) => cubit.edit(
                                      d.copyWith(length: int.tryParse(v) ?? 0),
                                    ),
                                    number: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: field(
                                    'Rộng (cm)',
                                    d.width == 0 ? '' : '${d.width}',
                                    (v) => cubit.edit(
                                      d.copyWith(width: int.tryParse(v) ?? 0),
                                    ),
                                    number: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: field(
                                    'Cao (cm)',
                                    d.height == 0 ? '' : '${d.height}',
                                    (v) => cubit.edit(
                                      d.copyWith(height: int.tryParse(v) ?? 0),
                                    ),
                                    number: true,
                                  ),
                                ),
                              ],
                            ),
                            sectionTitle('Ảnh hàng hóa · ${d.photos.length}/5'),
                            const Text(
                              'Chụp rõ hàng và bao bì. Từ 1–5 ảnh JPG/PNG, tối đa 5 MB mỗi ảnh.',
                            ),
                            const SizedBox(height: 14),
                            PhotoStrip(
                              d.photos,
                              remove: (url) => cubit.edit(
                                d.copyWith(
                                  photos: d.photos
                                      .where((p) => p != url)
                                      .toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (d.photos.length < 5)
                              OutlinedButton.icon(
                                onPressed: addPhoto,
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: Text(
                                  s.uploading
                                      ? 'Đang tải ảnh…'
                                      : 'Thêm ảnh hàng hóa',
                                ),
                              ),
                            const SizedBox(height: 18),
                            TextFormField(
                              initialValue: d.notes,
                              maxLines: 3,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                labelText:
                                    'Ghi chú cho tài xế (không bắt buộc)',
                              ),
                              onChanged: (v) =>
                                  cubit.edit(d.copyWith(notes: v)),
                            ),
                          ],
                          if (step == 2) ...[
                            sectionTitle('Chọn xe phù hợp'),
                            const Text(
                              'Tải trọng tính cho toàn bộ hàng; kích thước tính theo kiện lớn nhất.',
                            ),
                            const SizedBox(height: 16),
                            for (final vehicle in catalog.vehicles)
                              CustomerCard(
                                color: d.vehicleId == vehicle.id
                                    ? AppColors.peach
                                    : Colors.white,
                                padding: 0,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(14),
                                  leading: Icon(
                                    Icons.local_shipping_outlined,
                                    color: vehicle.fits(d)
                                        ? AppColors.orange
                                        : AppColors.muted,
                                    size: 30,
                                  ),
                                  title: Text(
                                    vehicle.name,
                                    style: appText(weight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    '${vehicle.weight.toStringAsFixed(0)} kg · ${vehicle.length} × ${vehicle.width} × ${vehicle.height} cm${vehicle.fits(d) ? '' : '\nHàng vượt sức chứa của xe'}',
                                  ),
                                  trailing: Icon(
                                    d.vehicleId == vehicle.id
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: AppColors.orange,
                                  ),
                                  enabled: vehicle.fits(d),
                                  onTap: () => cubit.edit(
                                    d.copyWith(vehicleId: vehicle.id),
                                  ),
                                ),
                              ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: d.loading,
                              title: const Text('Cần tài xế hỗ trợ bốc xếp'),
                              subtitle: const Text(
                                'Phí được tính trong báo giá',
                              ),
                              onChanged: (v) =>
                                  cubit.edit(d.copyWith(loading: v)),
                            ),
                            OutlinedButton.icon(
                              onPressed: cubit.estimate,
                              icon: const Icon(Icons.calculate_outlined),
                              label: const Text('Tính giá cước'),
                            ),
                            if (s.fare != null) ...[
                              const SizedBox(height: 12),
                              CustomerCard(
                                color: AppColors.peach,
                                child: Column(
                                  children: [
                                    detailRow(
                                      'Quãng đường',
                                      '${s.fare!.distance} km · khoảng ${s.fare!.minutes} phút',
                                    ),
                                    priceBreakdown(
                                      s.fare!.distanceFee,
                                      s.fare!.serviceFee,
                                      s.fare!.discount,
                                      s.fare!.total,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          if (step == 3) ...[
                            sectionTitle('Kiểm tra và thanh toán'),
                            CustomerCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  detailRow('Lấy hàng', d.pickup),
                                  detailRow('Giao đến', d.dropoff),
                                  detailRow(
                                    'Người nhận',
                                    '${d.receiver} · ${d.phone}',
                                  ),
                                  detailRow(
                                    'Hàng hóa',
                                    '${d.quantity} kiện · ${d.weight} kg',
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => step = 0),
                                    child: const Text('Chỉnh sửa thông tin'),
                                  ),
                                ],
                              ),
                            ),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'PayOS',
                                  label: Text('PayOS / QR'),
                                  icon: Icon(Icons.qr_code_2),
                                ),
                                ButtonSegment(
                                  value: 'Cash',
                                  label: Text('Tiền mặt'),
                                  icon: Icon(Icons.payments_outlined),
                                ),
                              ],
                              selected: {d.payment},
                              onSelectionChanged: (v) =>
                                  cubit.edit(d.copyWith(payment: v.first)),
                            ),
                            if (d.payment == 'Cash')
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: DropdownButtonFormField<String>(
                                  initialValue: d.payer,
                                  decoration: const InputDecoration(
                                    labelText: 'Người thanh toán',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Sender',
                                      child: Text('Người gửi'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Receiver',
                                      child: Text('Người nhận'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      cubit.edit(d.copyWith(payer: v)),
                                ),
                              ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _coupon,
                              decoration: InputDecoration(
                                labelText: 'Mã giảm giá',
                                suffixIcon: IconButton(
                                  tooltip: 'Chọn ưu đãi',
                                  onPressed: coupons,
                                  icon: const Icon(Icons.local_offer_outlined),
                                ),
                              ),
                              onFieldSubmitted: (v) {
                                cubit.edit(
                                  cubit.state.draft.copyWith(coupon: v),
                                );
                                cubit.estimate();
                              },
                              onChanged: (v) => cubit.edit(
                                cubit.state.draft.copyWith(coupon: v),
                              ),
                            ),
                            TextButton(
                              onPressed: cubit.estimate,
                              child: const Text('Áp dụng mã / Cập nhật giá'),
                            ),
                            if (s.fare != null)
                              CustomerCard(
                                color: AppColors.peach,
                                child: priceBreakdown(
                                  s.fare!.distanceFee,
                                  s.fare!.serviceFee,
                                  s.fare!.discount,
                                  s.fare!.total,
                                ),
                              )
                            else
                              const CustomerNotice(
                                'Giá cước cần được tính lại sau khi thay đổi thông tin hoặc mã giảm giá.',
                              ),
                            TextButton(
                              onPressed: () => policies(catalog.policies),
                              child: const Text(
                                'Xem chính sách bảo đảm, bồi hoàn và hàng cấm',
                              ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: d.committed,
                              onChanged: (v) => cubit.edit(
                                cubit.state.draft.copyWith(committed: v),
                              ),
                              title: const Text(
                                'Tôi xác nhận không gửi hàng cấm và đồng ý chính sách dịch vụ.',
                              ),
                            ),
                            const CustomerNotice(
                              'Kiểm tra thông tin trước khi đặt. Sau khi gửi đơn, bạn cần hủy và đặt lại nếu muốn thay đổi địa chỉ hoặc hàng hóa.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );
}

class _CouponSheet extends StatelessWidget {
  const _CouponSheet();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 460,
    child: BlocBuilder<PagedCubit<Coupon>, ListState<Coupon>>(
      builder: (context, s) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          sectionTitle('Ưu đãi dành cho bạn'),
          if (s.busy) const LinearProgressIndicator(),
          if (s.error != null) CustomerNotice(s.error!, error: true),
          if (!s.busy && s.items.isEmpty)
            const Text('Hiện chưa có mã giảm giá khả dụng.'),
          for (final c in s.items)
            ListTile(
              leading: const Icon(
                Icons.local_offer_outlined,
                color: AppColors.orange,
              ),
              title: Text(c.code),
              subtitle: Text(
                'Giảm ${money(c.discount)} · Đơn từ ${money(c.minimum)}\nHết hạn ${dateLabel(c.expires)}',
              ),
              onTap: () => Navigator.pop(context, c.code),
            ),
          if (s.hasNext)
            TextButton(
              onPressed: s.busy
                  ? null
                  : () => context.read<PagedCubit<Coupon>>().load(more: true),
              child: const Text('Xem thêm'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Không dùng mã giảm giá'),
          ),
        ],
      ),
    ),
  );
}
