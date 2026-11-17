import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';
import 'customer_cubits.dart';
import 'customer_widgets.dart';

class CustomerRatingsScreen extends StatelessWidget {
  const CustomerRatingsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        PagedCubit<CustomerRating>(context.read<CustomerRepository>().ratings)
          ..load(),
    child: Scaffold(
      appBar: AppBar(title: const Text('Đánh giá của tôi')),
      body: BlocBuilder<PagedCubit<CustomerRating>, ListState<CustomerRating>>(
        builder: (context, s) => RefreshIndicator(
          onRefresh: () => context.read<PagedCubit<CustomerRating>>().load(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const CustomerNotice(
                'Mỗi chuyến được đánh giá một lần trong vòng 24 giờ sau hoàn thành. Đánh giá đã gửi không thể chỉnh sửa.',
              ),
              if (s.busy) const LinearProgressIndicator(),
              if (s.error != null) CustomerNotice(s.error!, error: true),
              if (!s.busy && s.items.isEmpty)
                const CustomerEmptyState(
                  title: 'Chưa có đánh giá',
                  message:
                      'Bạn có thể đánh giá sau khi hoàn thành chuyến giao.',
                  icon: 'star',
                ),
              for (final r in s.items)
                CustomerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.code, style: appText(weight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      _Stars(r.stars),
                      const SizedBox(height: 10),
                      Text(r.driver),
                      if (r.comment.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(r.comment),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        dateLabel(r.created),
                        style: appText(size: 12, color: AppColors.secondary),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/order',
                          arguments: r.orderId,
                        ),
                        child: const Text('Xem đơn hàng'),
                      ),
                    ],
                  ),
                ),
              if (s.hasNext)
                OutlinedButton(
                  onPressed: s.busy
                      ? null
                      : () => context.read<PagedCubit<CustomerRating>>().load(
                          more: true,
                        ),
                  child: const Text('Xem thêm'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RatingData {
  const RatingData(this.order, this.existing);
  final OrderDetail order;
  final CustomerRating? existing;
}

class CustomerRateScreen extends StatefulWidget {
  const CustomerRateScreen({super.key, required this.orderId});
  final int orderId;
  @override
  State<CustomerRateScreen> createState() => _CustomerRateScreenState();
}

class _CustomerRateScreenState extends State<CustomerRateScreen> {
  final comment = TextEditingController(), action = ActionCubit();
  late final ResourceCubit<RatingData> data;
  int stars = 5;
  @override
  void initState() {
    super.initState();
    final repo = context.read<CustomerRepository>();
    data = ResourceCubit(() async {
      final order = await repo.order(widget.orderId);
      var page = 1;
      CustomerRating? existing;
      while (true) {
        final ratings = await repo.ratings(page++);
        final found = ratings.items.where((r) => r.orderId == widget.orderId);
        if (found.isNotEmpty) {
          existing = found.first;
          break;
        }
        if (!ratings.hasNext) break;
      }
      return RatingData(order, existing);
    })..load();
  }

  @override
  void dispose() {
    data.close();
    action.close();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: data),
      BlocProvider.value(value: action),
    ],
    child: Scaffold(
      appBar: AppBar(title: const Text('Đánh giá chuyến giao')),
      body: BlocBuilder<ResourceCubit<RatingData>, ResourceState<RatingData>>(
        builder: (context, s) => BlocBuilder<ActionCubit, ActionState>(
          builder: (context, a) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.busy) const LinearProgressIndicator(),
                if (s.error != null) ...[
                  CustomerNotice(s.error!, error: true),
                  TextButton(
                    onPressed: data.load,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (s.data case final d?) ...[
                  const DeliveryBanner(height: 108),
                  const SizedBox(height: 24),
                  Text(
                    'Chuyến giao của bạn thế nào?',
                    textAlign: TextAlign.center,
                    style: appText(size: 23, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.peach,
                      child: Text(
                        d.order.driverName.trim().isEmpty
                            ? 'M'
                            : d.order.driverName
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .where((p) => p.isNotEmpty)
                                  .take(2)
                                  .map((p) => p[0])
                                  .join()
                                  .toUpperCase(),
                        style: appText(
                          size: 24,
                          weight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    d.order.driverName,
                    textAlign: TextAlign.center,
                    style: appText(size: 22, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(d.order.summary.code, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (d.existing != null) ...[
                    Center(child: _Stars(d.existing!.stars)),
                    const SizedBox(height: 16),
                    Text(d.existing!.comment),
                    const SizedBox(height: 16),
                    const CustomerNotice(
                      'Bạn đã đánh giá chuyến này. Đánh giá không thể chỉnh sửa.',
                    ),
                  ] else if (!d.order.canRateAt(DateTime.now()))
                    const CustomerNotice(
                      'Chuyến chưa hoàn thành hoặc đã quá 24 giờ để gửi đánh giá.',
                    )
                  else ...[
                    const Text(
                      'Trải nghiệm giao hàng của bạn thế nào?',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => IconButton(
                          tooltip: '${i + 1} sao',
                          onPressed: a.busy
                              ? null
                              : () => setState(() => stars = i + 1),
                          icon: Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.orange,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        'Rất không hài lòng',
                        'Chưa hài lòng',
                        'Bình thường',
                        'Hài lòng',
                        'Rất hài lòng',
                      ][stars - 1],
                      textAlign: TextAlign.center,
                      style: appText(
                        color: AppColors.orange,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: comment,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Chia sẻ thêm (không bắt buộc)',
                      ),
                    ),
                    const CustomerNotice(
                      'Sau khi gửi, bạn không thể sửa đánh giá.',
                    ),
                    if (a.error != null) CustomerNotice(a.error!, error: true),
                    FilledButton(
                      onPressed: a.busy
                          ? null
                          : () async {
                              if (!await confirmCustomerAction(
                                    context,
                                    'Gửi đánh giá $stars sao?',
                                    'Đánh giá sẽ được lưu và không thể chỉnh sửa.',
                                  ) ||
                                  !context.mounted) {
                                return;
                              }
                              await action.run(
                                () => context.read<CustomerRepository>().rate(
                                  widget.orderId,
                                  stars,
                                  comment.text,
                                ),
                              );
                              if (mounted) await data.load();
                            },
                      child: Text(a.busy ? 'Đang gửi…' : 'Gửi đánh giá'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Stars extends StatelessWidget {
  const _Stars(this.stars);
  final int stars;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (i) => Icon(
        i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
        color: AppColors.amber,
      ),
    ),
  );
}
