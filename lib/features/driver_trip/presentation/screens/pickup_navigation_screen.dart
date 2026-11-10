import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../bloc/active_trip_bloc.dart';
import '../widgets/driver_map.dart';
import '../widgets/trip_components.dart';
import '../widgets/trip_contact_actions.dart';
import 'driver_simulation_sheet.dart';
import '../../domain/repositories/driver_trip_repository.dart';

class PickupNavigationScreen extends StatelessWidget {
  const PickupNavigationScreen({super.key, required this.state});
  final ActiveTripState state;
  @override
  Widget build(BuildContext context) {
    final trip = state.session.trip!;
    final demo = context.read<DriverTripRepository>() is TripSimulator;
    return Scaffold(
      appBar: AppHeader(
        'Đến điểm lấy hàng',
        onHelp: demo ? () => showTripSimulation(context) : null,
      ),
      body: LayoutBuilder(
        builder: (context, size) => SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: (size.maxHeight - 260).clamp(240, 650).toDouble(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DriverMap(
                        liveLocation: !demo,
                        route: true,
                        available: state.session.mapAvailable,
                        position: state.session.fix?.point,
                        destination: trip.job.collectionPoint,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 70,
                      child: Column(
                        children: [
                          AppCard(
                            shadow: true,
                            onTap: () => context.read<ActiveTripBloc>().add(
                              ExternalNavigationOpened(),
                            ),
                            child: Row(
                              children: [
                                const AppIcon('truck', size: 21),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    state.fresh && !demo
                                        ? 'Cách điểm lấy ${km(state.distance)}'
                                        : state.fresh
                                        ? 'Còn ${km(state.distance)} · ${(state.distance / 260).ceil().clamp(1, 60)} phút'
                                        : 'Đang chờ vị trí GPS',
                                    style: appText(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: AppColors.green,
                                    ),
                                  ),
                                ),
                                const AppIcon('chevron-right', size: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppCard(
                            shadow: true,
                            child: Row(
                              children: [
                                AppIcon(
                                  state.distance <= 500
                                      ? 'map-pin'
                                      : 'turn-right',
                                  size: 36,
                                  color: AppColors.orange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        !demo
                                            ? 'Mở Google Maps để xem chỉ đường'
                                            : state.distance <= 500
                                            ? 'Bạn đã ở gần điểm lấy'
                                            : state.distance > 900
                                            ? 'Rẽ phải sau 300 m'
                                            : 'Đi thẳng đến điểm lấy',
                                        style: appText(
                                          size: 15,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        state.distance <= 500
                                            ? 'Kiểm tra địa chỉ trước khi dừng'
                                            : 'Vào đường ${trip.job.pickup.replaceFirst(RegExp(r'^\d+\s+'), '').split(',').first}',
                                        style: appText(
                                          size: 12,
                                          color: AppColors.secondary,
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
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCED2DA),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.peach,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const AppIcon(
                            'map-pin',
                            color: AppColors.orange,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.job.handoverPoint == null
                                    ? trip.job.pickup
                                    : 'Điểm bàn giao từ tài xế trước',
                                style: appText(
                                  size: 15,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                trip.job.customerPhone.isEmpty
                                    ? 'Chưa có thông tin liên hệ từ server'
                                    : '${trip.job.customerName} · ${trip.job.customerPhone}',
                                style: appText(size: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Gọi khách',
                          onPressed:
                              state.busy || trip.job.customerPhone.isEmpty
                              ? null
                              : () => context.read<ActiveTripBloc>().add(
                                  CustomerCalled(),
                                ),
                          icon: const AppIcon('phone', color: AppColors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!state.fresh)
                      const TripError(
                        'Vị trí không khả dụng hoặc quá 30 giây. Bật lại GPS để xác nhận đến điểm.',
                      ),
                    if (state.error != null) TripError(state.error!),
                    if (state.receipt != null)
                      Notice(
                        'Yêu cầu ${state.receipt} đã được gửi đến điều phối.',
                        icon: 'check',
                      ),
                    const Notice(
                      'Chỉ xác nhận khi cách điểm lấy hoặc bàn giao không quá 500 m.',
                      icon: 'warning',
                      peach: true,
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      'Đã đến điểm lấy hàng',
                      key: const Key('arrive-pickup'),
                      busy: state.busy,
                      onPressed: state.canArrive
                          ? () => context.read<ActiveTripBloc>().add(
                              ArrivalRequested(),
                            )
                          : null,
                    ),
                    TextButton(
                      onPressed: state.busy
                          ? null
                          : () => showTripIncident(context),
                      child: const Text('Báo sự cố'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
