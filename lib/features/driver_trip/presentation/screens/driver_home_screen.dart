import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/entities/driver_matching_policy.dart';
import '../bloc/driver_home_bloc.dart';
import '../widgets/driver_map.dart';
import '../widgets/trip_components.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({
    super.key,
    this.onJob,
    this.onActiveTrip,
    this.onSimulation,
    this.onNotifications,
  });
  final ValueChanged<DeliveryJob>? onJob;
  final VoidCallback? onActiveTrip, onSimulation, onNotifications;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DriverHomeBloc, DriverHomeState>(
    builder: (context, state) {
      final session = state.session;
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Trang chủ tài xế'),
          actions: [
            IconButton(
              tooltip: 'Thông báo',
              onPressed:
                  onNotifications ??
                  () => showInfoSheet(
                    context,
                    'Thông báo',
                    session.notice ?? 'Bạn chưa có thông báo mới.',
                  ),
              icon: const AppIcon('bell'),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          driver: true,
          selected: 0,
          onSelect: (i) {
            if (i == 3) Navigator.pushNamed(context, '/profile');
            if (i == 1) {
              if (onSimulation == null) {
                Navigator.pushNamed(context, '/trips');
                return;
              }
              if (session.trip?.ongoing ?? false) {
                onActiveTrip?.call();
              } else {
                showInfoSheet(
                  context,
                  'Đơn hàng',
                  'Chưa có chuyến đang thực hiện. Bật hoạt động để nhận đơn gần bạn.',
                );
              }
            }
            if (i == 2) {
              if (onSimulation == null) {
                Navigator.pushNamed(context, '/wallet');
                return;
              }
              showInfoSheet(
                context,
                'Số dư ví',
                'Ký quỹ: ${vnd(session.deposit)}\nThu nhập: ${vnd(session.earnings)}',
              );
            }
          },
        ),
        body: RefreshIndicator(
          onRefresh: () async =>
              context.read<DriverHomeBloc>().add(HomeRefreshed()),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: AppCard(
                  color: session.online ? AppColors.greenBg : AppColors.pale,
                  borderColor: session.online
                      ? const Color(0xFFC1E9CD)
                      : AppColors.line,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: session.online
                              ? AppColors.green
                              : AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.online
                                  ? 'Bạn đang trực tuyến'
                                  : 'Bạn đang ngoại tuyến',
                              style: appText(size: 15, weight: FontWeight.w700),
                            ),
                            Text(
                              session.online
                                  ? (session.trip?.ongoing ?? false)
                                        ? 'Đang thực hiện chuyến'
                                        : 'Đang tìm chuyến phù hợp'
                                  : 'Bật hoạt động để nhận đơn',
                              style: appText(size: 11),
                            ),
                          ],
                        ),
                      ),
                      if (state.loading)
                        const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          key: const Key('driver-online'),
                          value: session.online,
                          onChanged: (value) => context
                              .read<DriverHomeBloc>()
                              .add(AvailabilityChanged(value)),
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.orange,
                        ),
                    ],
                  ),
                ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TripError(
                    state.error!,
                    retry: () =>
                        context.read<DriverHomeBloc>().add(HomeRefreshed()),
                  ),
                ),
              if (!session.gpsEnabled)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: TripError(
                    'Chưa có quyền vị trí. Bật lại GPS để xem đơn và xác nhận đến điểm.',
                  ),
                ),
              SizedBox(
                height: 220,
                child: DriverMap(
                  liveLocation: onSimulation == null,
                  available: session.mapAvailable,
                  position: session.fix?.point,
                  searching:
                      session.online &&
                      session.gpsEnabled &&
                      !(session.trip?.ongoing ?? false),
                  searchRadiusMeters: DriverMatchingPolicy.searchRadiusMeters,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (session.trip?.ongoing ?? false) ...[
                      const SectionTitle('Chuyến đang thực hiện', size: 16),
                      const SizedBox(height: 8),
                      AppCard(
                        onTap: onActiveTrip,
                        child: Row(
                          children: [
                            const AppIcon('truck', color: AppColors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '#${session.trip!.job.id}\n${session.trip!.job.pickup}',
                                style: appText(
                                  size: 13,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const AppIcon('chevron-right'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Row(
                        children: [
                          const Expanded(
                            child: SectionTitle('Đơn gần bạn', size: 16),
                          ),
                          TextButton(
                            onPressed: () => context.read<DriverHomeBloc>().add(
                              HomeRefreshed(),
                            ),
                            child: const Text('Làm mới'),
                          ),
                        ],
                      ),
                      if (session.jobs.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              SvgPicture.asset(
                                'assets/illustrations/empty-jobs.svg',
                                height: 100,
                              ),
                              Text(
                                session.online
                                    ? 'Chưa có đơn phù hợp'
                                    : 'Sẵn sàng cho chuyến tiếp theo?',
                                style: appText(weight: FontWeight.w600),
                              ),
                              Text(
                                session.online
                                    ? 'Đơn mới sẽ được cập nhật tự động.'
                                    : 'Bật công tắc để bắt đầu nhận chuyến.',
                                style: appText(
                                  size: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ...session.jobs.map(
                        (job) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _NearbyJob(
                            job,
                            session,
                            onTap: () => onJob?.call(job),
                          ),
                        ),
                      ),
                    ],
                    if (session.deposit < 200000 && onSimulation != null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Notice(
                          'Ký quỹ dưới 200.000đ: tạm ẩn các đơn tiền mặt.',
                          peach: true,
                        ),
                      ),
                    AppCard(
                      color: const Color(0xFFFAF9F7),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng hợp ca làm hôm nay',
                            style: appText(size: 14, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              _summary(
                                'route',
                                !session.shift.available
                                    ? '—'
                                    : '${session.shift.completed}',
                                'chuyến',
                              ),
                              const SizedBox(width: 5),
                              _summary(
                                'coins',
                                !session.shift.available
                                    ? '—'
                                    : vnd(session.shift.income),
                                'Thu nhập',
                              ),
                              const SizedBox(width: 5),
                              _summary(
                                'chart-bar',
                                onSimulation == null
                                    ? '${session.jobs.length}'
                                    : '${session.shift.acceptanceRate}%',
                                onSimulation == null
                                    ? 'Đơn gần bạn'
                                    : 'Tỷ lệ nhận',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _balance('shield', 'Ký quỹ', session.deposit),
                        const SizedBox(width: 8),
                        _balance('wallet', 'Thu nhập', session.earnings),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${onSimulation == null ? 'GPS thiết bị' : 'Mô phỏng • GPS'} ${session.online || session.trip != null ? '5 giây/lần' : 'đã tắt'}',
                            style: appText(size: 9, color: AppColors.muted),
                          ),
                        ),
                        if (onSimulation != null)
                          TextButton(
                            onPressed: onSimulation,
                            child: const Text(
                              'Kịch bản thử',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _summary(String icon, String value, String label) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          AppIcon(icon, size: 19, color: AppColors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: appText(size: 12, weight: FontWeight.w700)),
                Text(
                  label,
                  style: appText(size: 10, color: AppColors.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _balance(String icon, String label, int amount) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          AppIcon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: appText(size: 10, color: AppColors.secondary),
                ),
                Text(
                  vnd(amount),
                  style: appText(size: 13, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const AppIcon('chevron-right', size: 15),
        ],
      ),
    ),
  );
}

class _NearbyJob extends StatelessWidget {
  const _NearbyJob(this.job, this.session, {this.onTap});
  final DeliveryJob job;
  final DriverSession session;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(11),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: Text(
                km(session.fix!.point.distanceTo(job.pickupPoint)),
                style: appText(size: 13, weight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _stop(job.pickup, true),
                  const SizedBox(height: 6),
                  _stop(job.dropoff, false),
                ],
              ),
            ),
            const AppIcon('chevron-right', size: 15),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const AppIcon('box', size: 17),
            const SizedBox(width: 5),
            Text(
              job.vehicle,
              style: appText(size: 11, color: AppColors.secondary),
            ),
            const SizedBox(width: 12),
            AppIcon(job.cash ? 'cash' : 'credit-card', size: 17),
            const SizedBox(width: 4),
            Text(job.cash ? 'Tiền mặt' : 'PayOS', style: appText(size: 11)),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Thu nhập',
                  style: appText(size: 10, color: AppColors.muted),
                ),
                Text(
                  vnd(job.net),
                  style: appText(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
  Widget _stop(String text, bool pickup) => Row(
    children: [
      AppIcon(
        pickup ? 'target' : 'map-pin',
        size: 12,
        color: pickup ? AppColors.green : AppColors.orange,
      ),
      const SizedBox(width: 7),
      Expanded(child: Text(text, style: appText(size: 11.5))),
    ],
  );
}
