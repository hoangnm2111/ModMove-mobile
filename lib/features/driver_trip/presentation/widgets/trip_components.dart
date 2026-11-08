import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';

String vnd(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}đ';
String km(double meters) =>
    '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

class TripBadge extends StatelessWidget {
  const TripBadge(
    this.text, {
    super.key,
    this.color = AppColors.orange,
    this.background = AppColors.peach,
    this.icon,
  });
  final String text;
  final Color color, background;
  final String? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            style: appText(size: 11, weight: FontWeight.w600, color: color),
          ),
        ),
      ],
    ),
  );
}

class RouteCard extends StatelessWidget {
  const RouteCard(this.job, {super.key, this.distance, this.compact = false});
  final DeliveryJob job;
  final String? distance;
  final bool compact;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.all(compact ? 10 : 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 4),
            Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
            ),
            ...List.generate(
              compact ? 3 : 6,
              (_) => Container(
                width: 2,
                height: 3,
                color: AppColors.secondary,
                margin: const EdgeInsets.only(top: 3),
              ),
            ),
            const AppIcon('map-pin', size: 23, color: AppColors.orange),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.pickup,
                style: appText(
                  size: compact ? 12 : 15,
                  weight: FontWeight.w600,
                ),
              ),
              if (distance != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Cách bạn $distance',
                  style: appText(size: 12, color: AppColors.secondary),
                ),
              ],
              SizedBox(height: compact ? 10 : 24),
              Text(
                job.dropoff,
                style: appText(
                  size: compact ? 12 : 15,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class TripMetrics extends StatelessWidget {
  const TripMetrics(this.job, {super.key, this.vehicle = true});
  final DeliveryJob job;
  final bool vehicle;
  @override
  Widget build(BuildContext context) => AppCard(
    child: IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _metric(
              'map-pin',
              '${job.distanceKm.toString().replaceAll('.', ',')} km',
              'Tổng quãng đường',
            ),
          ),
          const VerticalDivider(width: 14),
          Expanded(
            child: _metric(
              'clock',
              '${job.minutes} phút',
              'Thời gian ước tính',
            ),
          ),
          if (vehicle) ...[
            const VerticalDivider(width: 14),
            Expanded(child: _metric('truck', job.vehicle, 'Loại xe')),
          ],
        ],
      ),
    ),
  );
  Widget _metric(String icon, String value, String label) => Column(
    children: [
      AppIcon(icon, size: 25),
      const SizedBox(height: 8),
      Text(
        value,
        textAlign: TextAlign.center,
        style: appText(size: 13, weight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: appText(size: 10, color: AppColors.secondary),
      ),
    ],
  );
}

class TripError extends StatelessWidget {
  const TripError(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      color: AppColors.redBg,
      borderColor: AppColors.red.withValues(alpha: .2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: appText(size: 13, color: AppColors.red)),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class PickupStepper extends StatelessWidget {
  const PickupStepper(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        4,
        (i) => Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: i == 0
                          ? Colors.transparent
                          : i <= step
                          ? AppColors.green
                          : AppColors.line,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < step
                          ? AppColors.green
                          : i == step
                          ? AppColors.orange
                          : AppColors.pale,
                      border: Border.all(
                        color: i <= step ? Colors.transparent : AppColors.line,
                      ),
                    ),
                    child: i < step
                        ? const AppIcon('check', color: Colors.white, size: 17)
                        : Text(
                            '${i + 1}',
                            style: appText(
                              weight: FontWeight.w600,
                              color: i == step
                                  ? Colors.white
                                  : AppColors.secondary,
                            ),
                          ),
                  ),
                  Expanded(
                    child: Divider(
                      color: i == 3
                          ? Colors.transparent
                          : i < step
                          ? AppColors.green
                          : AppColors.line,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  'Đến điểm',
                  'Kiểm tra hàng',
                  'Khách xác nhận',
                  'Bắt đầu chuyến',
                ][i],
                textAlign: TextAlign.center,
                style: appText(
                  size: 10,
                  color: i == step ? AppColors.orange : AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
