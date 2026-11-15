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
  late final PagedCubit<OrderSummary> cubit;
  @override
  void initState() {
    super.initState();
    final repo = context.read<CustomerRepository>();
    cubit = PagedCubit((p) => repo.orders(page: p, view: view, search: search))
      ..load();
  }

  @override
  void dispose() {
    cubit.close();
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
                setState(() => view = v.first);
                cubit.load();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Mã đơn, địa chỉ hoặc người nhận',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                search = v.trim();
                cubit.load();
              },
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
