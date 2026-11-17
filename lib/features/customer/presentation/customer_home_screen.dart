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
  String ordersView = 'Active';
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
                : CustomerOrdersScreen(initialView: ordersView)
          : _CustomerDashboard(
              guest: widget.guest,
              openOrders: (view) => setState(() {
                ordersView = view;
                tab = 1;
              }),
            ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: AppIcon('home', color: AppColors.secondary),
            selectedIcon: AppIcon('home-filled', color: AppColors.orange),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: AppIcon('orders', color: AppColors.secondary),
            selectedIcon: AppIcon('orders', color: AppColors.orange),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: AppIcon('user', color: AppColors.secondary),
            selectedIcon: AppIcon('user-filled', color: AppColors.orange),
            label: 'Tài khoản',
          ),
        ],
      ),
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
  final ValueChanged<String> openOrders;

  Future<void> book(BuildContext context) async {
    if (guest) {
      context.read<AuthCubit>().show(AuthStage.login);
      return;
    }
    await Navigator.pushNamed(context, '/booking');
    if (context.mounted) context.read<PagedCubit<OrderSummary>>().load();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => ResourceCubit<BookingCatalog>(
          context.read<CustomerRepository>().catalog,
        )..load(),
      ),
      if (!guest) ...[
        BlocProvider(
          create: (_) => ResourceCubit<CustomerProfile>(
            context.read<CustomerRepository>().profile,
          )..load(),
        ),
        BlocProvider(
          create: (_) => PagedCubit<OrderSummary>(
            (p) => context.read<CustomerRepository>().orders(
              page: p,
              view: 'Active',
            ),
          )..load(),
        ),
      ],
    ],
    child: Builder(
      builder: (context) => RefreshIndicator(
        onRefresh: () async {
          await context.read<ResourceCubit<BookingCatalog>>().load();
          if (!guest && context.mounted) {
            await context.read<PagedCubit<OrderSummary>>().load();
            if (context.mounted) {
              await context.read<ResourceCubit<CustomerProfile>>().load();
            }
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CustomerBrand(
              trailing: IconButton(
                tooltip: 'Thông báo',
                icon: const AppIcon('bell'),
                onPressed: guest
                    ? () => context.read<AuthCubit>().show(AuthStage.login)
                    : () => Navigator.pushNamed(context, '/notifications'),
              ),
            ),
            if (!guest)
              BlocBuilder<
                ResourceCubit<CustomerProfile>,
                ResourceState<CustomerProfile>
              >(
                builder: (_, s) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    s.data == null
                        ? 'Giao hàng theo cách của bạn'
                        : 'Chào ${s.data!.name}',
                    style: appText(size: 15, weight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            DeliveryBanner(
              title: 'Gửi hàng\nnhẹ tênh',
              action: 'Đặt giao hàng',
              onPressed: () => book(context),
              height: 170,
            ),
            const SizedBox(height: 12),
            sectionTitle('Bạn muốn gửi gì?'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, icon) in [
                  ('Đồ dùng', 'customer-parcel'),
                  ('Hàng hóa', 'customer-cargo'),
                  ('Chuyển đồ', 'customer-moving'),
                ])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: label == 'Chuyển đồ' ? 0 : 10,
                      ),
                      child: CustomerCard(
                        padding: 0,
                        child: InkWell(
                          onTap: () => book(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 6,
                            ),
                            child: Column(
                              children: [
                                CustomerServiceIcon(icon),
                                const SizedBox(height: 12),
                                Text(
                                  label,
                                  style: appText(
                                    size: 13,
                                    weight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (!guest) ...[
              Row(
                children: [
                  Expanded(child: sectionTitle('Đơn đang giao')),
                  TextButton(
                    onPressed: () => openOrders('Active'),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
              BlocBuilder<PagedCubit<OrderSummary>, ListState<OrderSummary>>(
                builder: (context, s) => Column(
                  children: [
                    if (s.busy) const LinearProgressIndicator(),
                    if (s.error != null) CustomerNotice(s.error!, error: true),
                    if (!s.busy && s.error == null && s.items.isEmpty)
                      const CustomerCard(
                        child: CustomerEmptyState(
                          title: 'Sẵn sàng cho chuyến giao mới',
                          message:
                              'Đơn đang giao sẽ xuất hiện tại đây để bạn theo dõi.',
                        ),
                      ),
                    for (final order in s.items.take(2))
                      CustomerOrderTile(
                        order,
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/order',
                            arguments: order.id,
                          );
                          if (context.mounted) {
                            context.read<PagedCubit<OrderSummary>>().load();
                          }
                        },
                      ),
                  ],
                ),
              ),
              CustomerCard(
                padding: 0,
                child: ListTile(
                  leading: const AppIcon('history'),
                  title: const Text('Lịch sử đơn hàng'),
                  trailing: const AppIcon('chevron-right', size: 20),
                  onTap: () => openOrders('History'),
                ),
              ),
            ],
            BlocBuilder<
              ResourceCubit<BookingCatalog>,
              ResourceState<BookingCatalog>
            >(
              builder: (_, s) => Column(
                children: [
                  if (s.busy && guest) const LinearProgressIndicator(),
                  if (s.error != null) CustomerNotice(s.error!, error: true),
                  if (s.data != null)
                    CustomerCard(
                      padding: 0,
                      child: ExpansionTile(
                        leading: const AppIcon(
                          'shield',
                          color: AppColors.orange,
                        ),
                        title: const Text('Dịch vụ & chính sách'),
                        children: [
                          for (final v in s.data!.vehicles)
                            ListTile(
                              leading: const AppIcon('van'),
                              title: Text(v.name),
                              subtitle: Text('Tải trọng tối đa ${v.weight} kg'),
                            ),
                          for (final p in s.data!.policies)
                            ExpansionTile(
                              title: Text(p.name),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    18,
                                  ),
                                  child: Text(p.description),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  order.code,
                  style: appText(size: 16, weight: FontWeight.w800),
                ),
                StatusPill(
                  order.needsPayment ? 'AwaitingPayment' : order.status,
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomerRouteSummary(pickup: order.pickup, dropoff: order.dropoff),
            const Divider(height: 28),
            Row(
              children: [
                const AppIcon('van', size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.vehicle,
                    style: appText(size: 12, color: AppColors.secondary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  money(order.total),
                  style: appText(
                    size: 19,
                    weight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon('map-pin', size: 18, color: AppColors.orange),
                  const SizedBox(width: 8),
                  Text(
                    ['Completed', 'Cancelled'].contains(order.status)
                        ? 'Xem chi tiết'
                        : 'Theo dõi đơn',
                    style: appText(
                      color: AppColors.orange,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key, this.initialView = 'Active'});
  final String initialView;
  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  late String view;
  String search = '';
  CustomerOrderFilter filter = const CustomerOrderFilter();
  final searchInput = TextEditingController();
  late final PagedCubit<OrderSummary> cubit;
  @override
  void initState() {
    super.initState();
    view = widget.initialView;
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
            const CustomerBrand(compact: true),
            const SizedBox(height: 16),
            const DeliveryBanner(height: 96),
            const CustomerPageHeading('Đơn hàng'),
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
