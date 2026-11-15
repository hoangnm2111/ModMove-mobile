import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../driver_trip/data/driver_api.dart';
import 'driver_account_models.dart';
import 'load_view.dart';

/// Điểm đánh giá trung bình, phân bố 5..1 sao và nhận xét từ khách (api/driver/ratings).
class DriverRatingsScreen extends StatelessWidget {
  const DriverRatingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverApi>();
    return Scaffold(
      appBar: const AppHeader('Đánh giá của khách'),
      body: LoadView<RatingsSummary>(
        load: () async => RatingsSummary.fromJson(await api.ratings()),
        builder: (context, ratings, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        ratings.average == null
                            ? '—'
                            : ratings.average!
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ','),
                        style: appText(
                          size: 34,
                          weight: FontWeight.w800,
                          color: AppColors.orange,
                        ),
                      ),
                      Text(
                        '${ratings.total} đánh giá',
                        style: appText(size: 11, color: AppColors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < 5; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '${5 - i}★',
                                    style: appText(size: 11),
                                  ),
                                ),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: ratings.total == 0
                                        ? 0
                                        : ratings.distribution[i] /
                                              ratings.total,
                                    minHeight: 6,
                                    color: AppColors.orange,
                                    backgroundColor: AppColors.pale,
                                  ),
                                ),
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '${ratings.distribution[i]}',
                                    textAlign: TextAlign.right,
                                    style: appText(size: 11),
                                  ),
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
            const SizedBox(height: 14),
            const SectionTitle('Nhận xét', size: 16),
            const SizedBox(height: 8),
            if (ratings.reviews.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('Chưa có đánh giá nào.')),
              ),
            for (final r in ratings.reviews.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '★' * r.stars + '☆' * (5 - r.stars),
                            style: appText(size: 14, color: AppColors.orange),
                          ),
                          const Spacer(),
                          Text(
                            '#${r.orderCode}',
                            style: appText(size: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                      if ((r.comment ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.comment!, style: appText(size: 13)),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${r.customer}${r.createdAt == null ? '' : ' · ${dateTime(r.createdAt!)}'}',
                        style: appText(size: 11, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
