import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/formatting/vietnam_time.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/driver_navigation.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/trip_history_repository.dart';
import '../bloc/trip_history_cubit.dart';
import '../widgets/trip_components.dart';

String tripStatusLabel(String status) => switch (status) {
  'Accepted' => 'Đã nhận',
  'Arrived' => 'Đã đến lấy',
  'PickedUp' => 'Chờ duyệt ảnh',
  'InTransit' => 'Đang giao',
  'Delivered' => 'Đã giao',
  'Completed' => 'Đã tất toán',
  'Cancelled' => 'Đã hủy',
  _ => status,
};

class TripEarningsScreen extends StatelessWidget {
  const TripEarningsScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        TripDetailCubit(context.read<TripHistoryRepository>(), id)..refresh(),
    child: const _EarningsBody(),
  );
}

class _EarningsBody extends StatelessWidget {
  const _EarningsBody();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TripDetailCubit, TripDetailState>(
    builder: (context, state) {
      final trip = state.trip;
      final settled = trip?.stage == TripStage.completed;
      return Scaffold(
        appBar: AppHeader(
          'Thu nhập chuyến',
          actions: [
            IconButton(
              onPressed: state.busy
                  ? null
                  : context.read<TripDetailCubit>().refresh,
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: const DriverNavigation(1),
        body: RefreshIndicator(
          onRefresh: context.read<TripDetailCubit>().refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.busy) const LinearProgressIndicator(),
              if (state.error != null)
                TripError(
                  state.error!,
                  retry: context.read<TripDetailCubit>().refresh,
                ),
              if (trip != null) ...[
                AppCard(
                  child: Row(
                    children: [
                      const AppIcon('truck', size: 36, color: AppColors.orange),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${trip.job.displayCode}',
                              style: appText(weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _stage(trip.stage),
                              style: appText(
                                size: 12,
                                color: settled
                                    ? AppColors.green
                                    : AppColors.orange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vietnamStamp(
                                trip.completedAt ??
                                    trip.deliveredAt ??
                                    trip.job.createdAt,
                              ),
                              style: appText(
                                size: 11,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RouteCard(trip.job),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: AppColors.peach,
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Chi tiết thu nhập',
                          style: appText(
                            size: 16,
                            weight: FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                      MoneyLine('Cước quãng đường', trip.job.distanceFee),
                      MoneyLine('Dịch vụ bốc xếp', trip.job.serviceFee),
                      MoneyLine('Giảm giá', -trip.job.discount),
                      MoneyLine('Tổng cước', trip.job.fare),
                      MoneyLine(
                        'Phí nền tảng (${(trip.job.commissionRate * 100).toStringAsFixed(0)}%)',
                        -trip.job.commission,
                      ),
                      MoneyLine(
                        settled ? 'Thực nhận' : 'Thu nhập dự kiến',
                        trip.job.net,
                        accent: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Notice(
                  settled
                      ? 'Chuyến đã được tất toán'
                      : trip.stage == TripStage.cancelled
                      ? 'Chuyến đã hủy'
                      : 'Chưa tất toán',
                  detail: settled
                      ? trip.job.cash
                            ? 'Tiền cước đã thu trực tiếp; phí nền tảng được khấu trừ từ ký quỹ.'
                            : 'Thu nhập được ghi nhận vào ví theo kết quả xử lý của hệ thống.'
                      : trip.stage == TripStage.cancelled
                      ? trip.reason
                      : 'Thu nhập chỉ được ghi nhận khi đơn chuyển Hoàn thành. Khách xác nhận nhận hàng hoặc hệ thống xử lý sau thời hạn quy định.',
                  icon: settled ? 'check' : 'clock',
                  success: settled,
                  peach: !settled,
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      AppIcon(
                        trip.job.cash ? 'cash' : 'qr-code',
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${trip.job.cash ? 'Tiền mặt' : 'PayOS'} · ${trip.job.paid ? 'Đã thanh toán' : 'Chưa thanh toán'}',
                          style: appText(size: 13),
                        ),
                      ),
                      Text(
                        vnd(trip.job.fare),
                        style: appText(size: 13, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (trip.deliveryPhotoUrl != null) ...[
                  const SizedBox(height: 12),
                  const SectionTitle('Bằng chứng giao hàng', size: 15),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      trip.deliveryPhotoUrl!,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 120,
                        child: Center(child: Text('Chưa tải được ảnh')),
                      ),
                    ),
                  ),
                ],
                for (final incident in trip.incidents) ...[
                  const SizedBox(height: 10),
                  Notice(
                    'Sự cố #${incident.id}',
                    detail:
                        '${incident.description}\n${incident.resolution ?? 'Đang chờ điều phối xử lý'}',
                    peach: true,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/incident-detail',
                      arguments: incident.id,
                    ),
                    child: const Text('Xem chi tiết sự cố'),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  'Xem ví tài xế',
                  onPressed: () => Navigator.pushNamed(context, '/wallet'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
  String _stage(TripStage stage) => tripStatusLabel(
    {
      TripStage.accepted: 'Accepted',
      TripStage.arrived: 'Arrived',
      TripStage.pickedUp: 'PickedUp',
      TripStage.inTransit: 'InTransit',
      TripStage.delivered: 'Delivered',
      TripStage.completed: 'Completed',
      TripStage.cancelled: 'Cancelled',
    }[stage]!,
  );
}

class MoneyLine extends StatelessWidget {
  const MoneyLine(this.label, this.amount, {super.key, this.accent = false});
  final String label;
  final int amount;
  final bool accent;
  @override
  Widget build(BuildContext context) => Container(
    color: accent ? AppColors.peach : null,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: appText(
              size: 13,
              color: accent ? AppColors.orange : AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          vnd(amount),
          style: appText(
            size: accent ? 20 : 14,
            weight: FontWeight.w700,
            color: accent ? AppColors.orange : AppColors.ink,
          ),
        ),
      ],
    ),
  );
}
