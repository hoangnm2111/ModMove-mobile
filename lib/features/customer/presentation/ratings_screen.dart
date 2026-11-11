import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/customer_api.dart';
import '../domain/entities/customer_models.dart';
import 'widgets/customer_widgets.dart';

/// UC-CUS-26 – Đánh giá đã gửi: GET /customer/Ratings.
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key, required this.onOpen});
  final void Function(int id, {bool openPayment}) onOpen;
  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  late Future<Paged<MyRating>> _future = _load();
  Future<Paged<MyRating>> _load() => context.read<CustomerApi>().ratings(pageSize: 50);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đánh giá của tôi'), automaticallyImplyLeading: false),
    body: RefreshIndicator(
      onRefresh: () async {
        final next = _load();
        setState(() {
          _future = next;
        });
        await next;
      },
      child: FutureBuilder<Paged<MyRating>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ListView(
              children: [
                ErrorView(
                  errorText(snap.error!),
                  onRetry: () => setState(() {
                    _future = _load();
                  }),
                ),
              ],
            );
          }
          final items = snap.data!.items;
          if (items.isEmpty) return ListView(children: const [EmptyView('Bạn chưa đánh giá chuyến nào.')]);
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = items[i];
              return AppCard(
                onTap: () => widget.onOpen(r.orderId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.orderCode, style: appText(weight: FontWeight.w800)),
                        Expanded(
                          child: Text(
                            ' • Tài xế ${r.driverName}',
                            overflow: TextOverflow.ellipsis,
                            style: appText(size: 12.5, color: AppColors.secondary),
                          ),
                        ),
                        Text(date(r.createdAt), style: appText(size: 11.5, color: AppColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [for (var n = 1; n <= 5; n++) Icon(n <= r.stars ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.amber, size: 20)]),
                    if (r.comment != null) Text('“${r.comment}”', style: appText(size: 13, color: AppColors.secondary)),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
