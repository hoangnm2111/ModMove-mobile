import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';
import '../widgets/customer_widgets.dart';

class OrdersState {
  const OrdersState({this.view = 'All', this.search = '', this.items = const [], this.page = 0, this.total = 0, this.loading = false, this.error});
  final String view, search;
  final List<OrderSummary> items;
  final int page, total;
  final bool loading;
  final String? error;
  bool get hasMore => items.length < total;
}

/// UC-CUS-08/09/20 – GET /customer/Orders (lọc ở server, phân trang).
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this.api) : super(const OrdersState());
  final CustomerApi api;
  static const pageSize = 15;

  Future<void> load({String? view, String? search, bool more = false}) async {
    if (state.loading) return;
    final v = view ?? state.view, q = search ?? state.search;
    final page = more ? state.page + 1 : 1;
    emit(OrdersState(view: v, search: q, items: more ? state.items : const [], page: state.page, total: state.total, loading: true));
    try {
      final r = await api.orders(page: page, pageSize: pageSize, view: v, search: q.trim());
      emit(OrdersState(view: v, search: q, items: [...(more ? state.items : const <OrderSummary>[]), ...r.items], page: page, total: r.totalCount));
    } catch (e) {
      emit(OrdersState(view: v, search: q, items: state.items, page: state.page, total: state.total, error: e is ApiException ? e.message : '$e'));
    }
  }
}

const _views = {'All': 'Tất cả', 'Active': 'Đang thực hiện', 'Completed': 'Hoàn thành', 'Cancelled': 'Đã huỷ'};

/// Danh sách đơn của khách. [onOpen] mở chi tiết đơn.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, required this.onOpen, required this.onBook});
  final ValueChanged<int> onOpen;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => OrdersCubit(context.read<CustomerApi>())..load(),
    child: _OrdersView(onOpen: onOpen, onBook: onBook),
  );
}

class _OrdersView extends StatefulWidget {
  const _OrdersView({required this.onOpen, required this.onBook});
  final ValueChanged<int> onOpen;
  final VoidCallback onBook;
  @override
  State<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<_OrdersView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng của tôi'), automaticallyImplyLeading: false),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, s) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => cubit.load(search: v),
                decoration: InputDecoration(
                  hintText: 'Mã đơn, địa chỉ, tên người nhận…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: s.search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xoá tìm kiếm',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            cubit.load(search: '');
                          },
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final e in _views.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: s.view == e.key,
                        onSelected: (_) => cubit.load(view: e.key),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => cubit.load(),
                child: s.error != null && s.items.isEmpty
                    ? ListView(children: [ErrorView(s.error!, onRetry: () => cubit.load())])
                    : s.loading && s.items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : s.items.isEmpty
                    ? ListView(
                        children: [
                          EmptyView(
                            'Chưa có đơn hàng phù hợp.',
                            action: SizedBox(width: 180, child: PrimaryButton('Đặt xe ngay', onPressed: widget.onBook)),
                          ),
                        ],
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.extentAfter < 300 && s.hasMore && !s.loading) cubit.load(more: true);
                          return false;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                          itemCount: s.items.length + (s.hasMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => i >= s.items.length
                              ? const Center(
                                  child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
                                )
                              : OrderCard(order: s.items[i], onTap: () => widget.onOpen(s.items[i].id)),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});
  final OrderSummary order;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final o = order;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(o.code, style: appText(size: 14.5, weight: FontWeight.w800)),
              const SizedBox(width: 8),
              StatusPill(o.status, paymentMethod: o.paymentMethod, paymentStatus: o.paymentStatus),
              const Spacer(),
              Text(money(o.totalFee), style: appText(size: 14.5, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          _addr('map-pin', AppColors.orange, o.pickupAddress),
          const SizedBox(height: 4),
          _addr('target', AppColors.green, o.dropoffAddress),
          const SizedBox(height: 6),
          Text('${dateTime(o.createdAt)} • ${o.vehicleTypeName} • ${o.paymentMethod == 'PayOS' ? 'PayOS' : 'Tiền mặt'}', style: appText(size: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _addr(String icon, Color color, String text) => Row(
    children: [
      AppIcon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: appText(size: 12.5, color: AppColors.secondary),
        ),
      ),
    ],
  );
}
