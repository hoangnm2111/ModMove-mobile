import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../bloc/active_trip_bloc.dart';
import '../widgets/trip_components.dart';
import 'pickup_navigation_screen.dart';

class ActiveTripScreen extends StatelessWidget {
  const ActiveTripScreen({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ActiveTripBloc, ActiveTripState>(
    builder: (context, state) {
      final trip = state.session.trip;
      if (trip == null || !trip.ongoing) {
        return Scaffold(
          appBar: const AppHeader('Chuyến giao hàng'),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Notice(
                  'Chuyến đã hủy hoặc không còn hoạt động.',
                  icon: 'warning',
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  'Về trang chủ',
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                ),
              ],
            ),
          ),
        );
      }
      if (trip.stage == TripStage.accepted) {
        return PickupNavigationScreen(state: state);
      }
      return Scaffold(
        appBar: const AppHeader('Đã đến điểm lấy hàng'),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const PickupStepper(1),
              RouteCard(trip.job),
              const SizedBox(height: 16),
              const Notice(
                'Đã thông báo cho khách. Chuẩn bị kiểm tra hàng và chụp bằng chứng.',
                icon: 'check',
              ),
            ],
          ),
        ),
      );
    },
  );
}
