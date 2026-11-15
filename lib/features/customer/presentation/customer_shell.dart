import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../notifications/notifications_screen.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../data/customer_api.dart';
import '../domain/entities/customer_models.dart';
import 'account_screen.dart';
import 'booking/booking_cubit.dart';
import 'booking/booking_screen.dart';
import 'order_detail/order_detail_screen.dart';
import 'orders/orders_screen.dart';
import 'ratings_screen.dart';
import 'widgets/customer_widgets.dart';

/// Khung app phía khách: Trang chủ • Đơn hàng • Đánh giá • Tài khoản.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _tab = 0;
  int _ordersKey = 0; // đổi key để danh sách đơn tải lại sau khi đặt đơn

  Future<void> _book([BookingDraft? initial]) async {
    final created = await Navigator.push<CreatedOrder>(context, MaterialPageRoute(builder: (_) => BookingScreen(initial: initial)));
    if (created == null || !mounted) return;
    notify(context, 'ORDER_CREATED', {'orderId': '${created.id}', 'orderCode': created.code});
    setState(() => _ordersKey++);
    await _open(created.id, openPayment: created.payOs);
  }

  Future<void> _open(int id, {bool openPayment = false}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: id,
          openPayment: openPayment,
          onReorder: (draft) {
            Navigator.pop(context);
            _book(draft);
          },
        ),
      ),
    );
    if (mounted) setState(() => _ordersKey++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _tab,
      children: [
        _HomeTab(key: ValueKey('home$_ordersKey'), onBook: _book, onOpen: _open),
        OrdersScreen(key: ValueKey('orders$_ordersKey'), onOpen: _open, onBook: _book),
        RatingsScreen(onOpen: _open),
        const AccountScreen(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
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
          icon: Icon(Icons.star_outline_rounded, color: AppColors.secondary),
          selectedIcon: Icon(Icons.star_rounded, color: AppColors.orange),
          label: 'Đánh giá',
        ),
        NavigationDestination(
          icon: AppIcon('user', color: AppColors.secondary),
          selectedIcon: AppIcon('user-filled', color: AppColors.orange),
          label: 'Tài khoản',
        ),
      ],
    ),
  );
}

/// Trang chủ khách: đặt xe + đơn đang thực hiện + hỗ trợ.
class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key, required this.onBook, required this.onOpen});
  final void Function([BookingDraft? initial]) onBook;
  final void Function(int id, {bool openPayment}) onOpen;
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<Paged<OrderSummary>> _active = _load();
  Future<Paged<OrderSummary>> _load() => context.read<CustomerApi>().orders(view: 'Active', pageSize: 10);

  @override
  Widget build(BuildContext context) {
    final name = context.select((AuthCubit c) => c.state?.fullName ?? '');
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          final next = _load();
          setState(() {
            _active = next;
          });
          await next;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            Row(
              children: [
                const BrandLogo(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ModMove',
                        style: appText(size: 28, weight: FontWeight.w800, color: AppColors.orange, spacing: -1),
                      ),
                      Text('Xin chào, $name', style: appText(size: 15, color: AppColors.secondary)),
                    ],
                  ),
                ),
                NotificationBell(onTap: () => Navigator.pushNamed(context, '/inbox')),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(child: Image.asset('assets/images/hero-delivery.png', fit: BoxFit.cover)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chở hàng lớn,\nthật dễ dàng', style: appText(size: 24, weight: FontWeight.w800, height: 1.15)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 190,
                          child: Text('Báo giá theo quãng đường thực, thanh toán PayOS hoặc tiền mặt.', style: appText(size: 13, color: AppColors.secondary)),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 190,
                          child: PrimaryButton('Đặt xe ngay', icon: 'truck', onPressed: () => widget.onBook()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle('Đơn đang thực hiện', size: 16),
            const SizedBox(height: 8),
            FutureBuilder<Paged<OrderSummary>>(
              future: _active,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return ErrorView(
                    errorText(snap.error!),
                    onRetry: () => setState(() {
                      _active = _load();
                    }),
                  );
                }
                final items = snap.data!.items;
                if (items.isEmpty) return Text('Bạn không có đơn nào đang chạy.', style: appText(color: AppColors.muted));
                return Column(
                  children: [
                    for (final o in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OrderCard(order: o, onTap: () => widget.onOpen(o.id)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            AppCard(
              onTap: () => showSupportSheet(context),
              child: Row(
                children: [
                  const AppIcon('headphones', color: AppColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cần hỗ trợ?', style: appText(weight: FontWeight.w700)),
                        Text('Gửi câu hỏi, đội ngũ ModMove sẽ liên hệ lại.', style: appText(size: 12, color: AppColors.secondary)),
                      ],
                    ),
                  ),
                  const AppIcon('chevron-right', color: AppColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
