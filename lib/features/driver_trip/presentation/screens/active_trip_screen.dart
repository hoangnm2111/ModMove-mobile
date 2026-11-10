import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../bloc/active_trip_bloc.dart';
import '../widgets/trip_components.dart';
import '../widgets/trip_contact_actions.dart';
import 'pickup_navigation_screen.dart';
import 'cargo_inspection_screen.dart';
import 'pickup_approval_screen.dart';
import 'driver_simulation_sheet.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import 'delivery_screen.dart';

class ActiveTripScreen extends StatelessWidget {
  const ActiveTripScreen({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ActiveTripBloc, ActiveTripState>(
    builder: (context, state) {
      final trip = state.session.trip;
      if (trip?.stage == TripStage.delivered ||
          trip?.stage == TripStage.completed) {
        return DeliverySuccessScreen(trip!);
      }
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
                const TripIncidentHistoryLink(),
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
        if (!trip.job.detailsAvailable) {
          return Scaffold(
            appBar: const AppHeader('Chuyến đang thực hiện'),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Notice(
                'Bạn đang có đơn #${trip.job.id}.',
                detail:
                    'Server xác nhận đơn đang hoạt động. API chi tiết chuyến dành cho tài xế chưa được cung cấp.',
              ),
            ),
          );
        }
        return PickupNavigationScreen(state: state);
      }
      if (trip.editable) return CargoInspectionScreen(tripState: state);
      if (trip.stage == TripStage.pickedUp) {
        return PickupApprovalScreen(state: state);
      }
      if (trip.stage == TripStage.inTransit &&
          context.read<DriverTripRepository>() is! TripSimulator) {
        return DeliveryScreen(key: ValueKey(trip.job.id), tripState: state);
      }
      return Scaffold(
        appBar: AppHeader(
          'Đang giao hàng',
          onHelp: () => showTripSimulation(context),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const PickupStepper(3),
              RouteCard(trip.job),
              const SizedBox(height: 16),
              const Notice(
                'Khách đã xác nhận hàng. Chuyến đã bắt đầu giao.',
                icon: 'check',
              ),
              const SizedBox(height: 16),
              if (state.error != null) TripError(state.error!),
              PrimaryButton(
                'Mở chỉ đường giao hàng',
                icon: 'navigation',
                onPressed: state.busy
                    ? null
                    : () => context.read<ActiveTripBloc>().add(
                        ExternalNavigationOpened(),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
