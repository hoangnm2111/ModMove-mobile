import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/formatting/vietnam_time.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/driver_navigation.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/repositories/trip_history_repository.dart';
import '../bloc/trip_history_cubit.dart';
import '../widgets/trip_components.dart';
import 'trip_earnings_screen.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        TripHistoryCubit(context.read<TripHistoryRepository>())..load(),
    child: const _HistoryBody(),
  );
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<TripHistoryCubit, TripHistoryState>(
    builder: (context, state) {
      final cubit = context.read<TripHistoryCubit>();
      return Scaffold(
        appBar: const AppHeader('Chuyến của tôi'),
        bottomNavigationBar: const DriverNavigation(1),
        body: RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('Tất cả')),
                  ButtonSegment(value: 'Active', label: Text('Đang chạy')),
                  ButtonSegment(value: 'History', label: Text('Lịch sử')),
                ],
                selected: {state.view},
                showSelectedIcon: false,
                onSelectionChanged: (s) => cubit.load(view: s.single),
              ),
              const SizedBox(height: 16),
              if (state.busy) const LinearProgressIndicator(),
              if (state.error != null)
                TripError(state.error!, retry: cubit.load),
              if (state.data?.items.isEmpty == true && !state.busy) ...[
                SvgPicture.asset(
                  'assets/illustrations/empty-jobs.svg',
                  height: 180,
                ),
                const Center(
                  child: Text('Chưa có chuyến trong danh sách này.'),
                ),
              ],
              for (final trip in state.data?.items ?? <TripSummary>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: () async {
                      final repository = context.read<DriverTripRepository>();
                      if (repository.current.trip?.job.id == trip.id &&
                          (repository.current.trip?.ongoing ?? false)) {
                        await Navigator.pushNamed(context, '/active-trip');
                      } else {
                        await Navigator.pushNamed(
                          context,
                          '/trip-earnings',
                          arguments: trip.id,
                        );
                      }
                      if (context.mounted) cubit.load();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppIcon('truck', color: AppColors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '#${trip.code}',
                                style: appText(weight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              tripStatusLabel(trip.status),
                              style: appText(size: 11, color: AppColors.orange),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(trip.pickup, style: appText(size: 13)),
                        const SizedBox(height: 6),
                        Text(
                          trip.dropoff,
                          style: appText(size: 13, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vietnamStamp(trip.createdAt),
                                style: appText(
                                  size: 11,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                            Text(
                              vnd(trip.fare),
                              style: appText(weight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.data?.hasNext == true)
                TextButton(
                  onPressed: state.busy ? null : () => cubit.load(more: true),
                  child: const Text('Tải thêm chuyến'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
