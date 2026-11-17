import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';
import 'customer_cubits.dart';
import 'customer_widgets.dart';
import 'customer_profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, this.guest = false});
  final bool guest;
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: tab == 2
          ? widget.guest
                ? _GuestAccount()
                : const CustomerProfileScreen()
          : tab == 1
          ? widget.guest
                ? _GuestAccount()
                : const CustomerOrdersScreen()
          : _CustomerDashboard(
              guest: widget.guest,
              openOrders: () => setState(() => tab = 1),
            ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Đơn hàng',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Tài khoản',
        ),
      ],
    ),
  );
}

class _GuestAccount extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(),
          sectionTitle('Kết nối với ModMove'),
          const Text(
            'Đăng nhập để đặt giao hàng, theo dõi đơn và quản lý tài khoản.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.read<AuthCubit>().show(AuthStage.login),
            child: const Text('Đăng nhập / Đăng ký'),
          ),
        ],
      ),
    ),
  );
}

class _CustomerDashboard extends StatelessWidget {
  const _CustomerDashboard({required this.guest, required this.openOrders});
  final bool guest;
  final VoidCallback openOrders;
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => ResourceCubit<BookingCatalog>(
          context.read<CustomerRepository>().catalog,
        )..load(),
      ),
      if (!guest)
        BlocProvider(
          create: (_) => PagedCubit<OrderSummary>(
            (p) => context.read<CustomerRepository>().orders(
              page: p,
              view: 'Active',
            ),
          )..load(),
        ),
    ],
    child: Builder(
      builder: (context) => RefreshIndicator(
        onRefresh: () async {
          await context.read<ResourceCubit<BookingCatalog>>().load();
          if (!guest && context.mounted) {
            await context.read<PagedCubit<OrderSummary>>().load();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const AppLogo(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ModMove',
                        style: appText(size: 23, weight: FontWeight.w800),
                      ),
                      const Text('Giao hàng theo cách của bạn'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Thông báo',
                  onPressed: guest
                      ? () => context.read<AuthCubit>().show(AuthStage.login)
                      : () => Navigator.pushNamed(context, '/notifications'),
                  icon: const Icon(Icons.notifications_none),
                ),
              ],
            ),
            const SizedBox(height: 24),
            CustomerCard(
              color: AppColors.peach,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bạn gửi hàng.\nModMove lo hành trình.',
                          style: appText(size: 22, weight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.local_shipping_rounded,
                        size: 40,
                        color: AppColors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Chọn xe phù hợp, biết trước giá cước và theo dõi chuyến giao.',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Đặt giao hàng'),
                      onPressed: () async {
                        if (guest) {
                          context.read<AuthCubit>().show(AuthStage.login);
                          return;
                        }
                        await Navigator.pushNamed(context, '/booking');
                        if (context.mounted) {
                          context.read<PagedCubit<OrderSummary>>().load();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (!guest) ...[
              Row(
                children: [
                  Expanded(child: sectionTitle('Đơn đang thực hiện')),
                  TextButton(
                    onPressed: openOrders,
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
              BlocBuilder<PagedCubit<OrderSummary>, ListState<OrderSummary>>(
                builder: (context, s) => Column(
                  children: [
                    if (s.busy) const LinearProgressIndicator(),
                    if (s.error != null) CustomerNotice(s.error!, error: true),
                    if (!s.busy && s.items.isEmpty)
                      const CustomerCard(
                        child: Text(
                          'Chưa có đơn đang thực hiện. Tạo đơn mới khi bạn cần gửi hàng.',
                        ),
                      ),
                    for (final o in s.items.take(2))
                      CustomerOrderTile(
                        o,
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/order',
                            arguments: o.id,
                          );
                          if (context.mounted) {
                            context.read<PagedCubit<OrderSummary>>().load();
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
            sectionTitle('Dịch vụ vận chuyển'),
            BlocBuilder<
              ResourceCubit<BookingCatalog>,
              ResourceState<BookingCatalog>
            >(
              builder: (context, s) => Column(
                children: [
                  if (s.busy) const LinearProgressIndicator(),
                  if (s.error != null) CustomerNotice(s.error!, error: true),
                  if (s.data != null) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: s.data!.vehicles
                          .map(
                            (v) => SizedBox(
                              width: 160,
                              child: CustomerCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.local_shipping_outlined,
                                      color: AppColors.orange,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      v.name,
                                      style: appText(weight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tối đa ${v.weight.toStringAsFixed(0)} kg',
                                      style: appText(
                                        size: 12,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    for (final p in s.data!.policies)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(p.name),
                        leading: const Icon(
                          Icons.verified_user_outlined,
                          size: 22,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Text(p.description),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CustomerOrderTile extends StatelessWidget {
  const CustomerOrderTile(this.order, {super.key, required this.onTap});
  final OrderSummary order;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CustomerCard(
    padding: 0,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.code,
                    style: appText(weight: FontWeight.w700),
                  ),
                ),
                StatusPill(
                  order.needsPayment ? 'AwaitingPayment' : order.status,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.trip_origin,
                  size: 16,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.pickup,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.dropoff,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.vehicle,
                    style: appText(size: 12, color: AppColors.secondary),
                  ),
                ),
                Text(
                  money(order.total),
                  style: appText(
                    weight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});
  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  String view = 'Active', search = '';
  CustomerOrderFilter filter = const CustomerOrderFilter();
  final searchInput = TextEditingController();
  late final PagedCubit<OrderSummary> cubit;
  @override
  void initState() {
    super.initState();
    final repo = context.read<CustomerRepository>();
    cubit = PagedCubit(
      (p) => repo.orders(page: p, view: view, search: search, filter: filter),
    )..load();
  }

  @override
  void dispose() {
    cubit.close();
    searchInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: cubit,
    child: BlocBuilder<PagedCubit<OrderSummary>, ListState<OrderSummary>>(
      builder: (context, s) => RefreshIndicator(
        onRefresh: () => cubit.load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            sectionTitle('Đơn hàng của tôi'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Active', label: Text('Đang giao')),
                ButtonSegment(value: 'History', label: Text('Lịch sử')),
                ButtonSegment(value: 'All', label: Text('Tất cả')),
              ],
              selected: {view},
              onSelectionChanged: (v) {
                setState(() {
                  view = v.first;
                  filter = CustomerOrderFilter(
                    from: filter.from,
                    to: filter.to,
                    phone: filter.phone,
                  );
                });
                cubit.load();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchInput,
              maxLength: 100,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Mã đơn, địa chỉ hoặc người nhận',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchInput.clear();
                    search = '';
                    cubit.load();
                  },
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                search = v.trim();
                cubit.load();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.filter_list),
                    label: Text(
                      filter.isEmpty ? 'Lọc đơn hàng' : 'Đang áp dụng bộ lọc',
                    ),
                    onPressed: () async {
                      final value =
                          await showModalBottomSheet<CustomerOrderFilter>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => _OrderFilterSheet(filter),
                          );
                      if (value == null || !mounted) return;
                      setState(() {
                        filter = value;
                        if (value.status != null && view != 'All') {
                          view =
                              ['Completed', 'Cancelled'].contains(value.status)
                              ? 'History'
                              : 'Active';
                        }
                      });
                      cubit.load();
                    },
                  ),
                ),
                if (!filter.isEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => filter = const CustomerOrderFilter());
                      cubit.load();
                    },
                    child: const Text('Bỏ lọc'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (s.busy) const LinearProgressIndicator(),
            if (s.error != null) CustomerNotice(s.error!, error: true),
            if (!s.busy && s.items.isEmpty)
              const CustomerCard(
                child: Text('Không có đơn phù hợp. Kéo xuống để tải lại.'),
              ),
            for (final order in s.items)
              CustomerOrderTile(
                order,
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    '/order',
                    arguments: order.id,
                  );
                  if (mounted) cubit.load();
                },
              ),
            if (s.hasNext)
              OutlinedButton(
                onPressed: s.busy ? null : () => cubit.load(more: true),
                child: const Text('Xem thêm đơn'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _OrderFilterSheet extends StatefulWidget {
  const _OrderFilterSheet(this.value);
  final CustomerOrderFilter value;
  @override
  State<_OrderFilterSheet> createState() => _OrderFilterSheetState();
}

class _OrderFilterSheetState extends State<_OrderFilterSheet> {
  late String status = widget.value.status ?? '';
  late final phone = TextEditingController(text: widget.value.phone);
  late DateTime? from = widget.value.from, to = widget.value.to;
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  String date(DateTime value) => '${value.day}/${value.month}/${value.year}';
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sectionTitle('Lọc đơn hàng'),
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Tất cả trạng thái'),
                ),
                for (final value in [
                  'Pending',
                  'Accepted',
                  'Arrived',
                  'PickedUp',
                  'InTransit',
                  'Delivered',
                  'Completed',
                  'Cancelled',
                ])
                  DropdownMenuItem(
                    value: value,
                    child: Text(statusLabel(value)),
                  ),
              ],
              onChanged: (value) => setState(() => status = value ?? ''),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: phone,
              maxLength: 15,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại người nhận',
                helperText: 'Có thể nhập một phần số điện thoại',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ||
                      RegExp(r'^[0-9]{1,15}$').hasMatch(value!.trim())
                  ? null
                  : 'Chỉ nhập từ 1 đến 15 chữ số',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                from == null
                    ? 'Chọn khoảng ngày tạo đơn'
                    : '${date(from!)} – ${date(to ?? from!)}',
              ),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: from == null
                      ? null
                      : DateTimeRange(start: from!, end: to ?? from!),
                  helpText: 'Ngày tạo đơn (giờ Việt Nam)',
                  saveText: 'Chọn',
                );
                if (range != null && mounted) {
                  setState(() {
                    from = range.start;
                    to = range.end;
                  });
                }
              },
            ),
            if (from != null)
              TextButton(
                onPressed: () => setState(() {
                  from = null;
                  to = null;
                }),
                child: const Text('Bỏ khoảng ngày'),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  CustomerOrderFilter(
                    status: status.isEmpty ? null : status,
                    from: from,
                    to: to,
                    phone: phone.text.trim(),
                  ),
                );
              },
              child: const Text('Áp dụng bộ lọc'),
            ),
          ],
        ),
      ),
    ),
  );
}
