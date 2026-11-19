import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../bloc/active_trip_bloc.dart';
import '../widgets/driver_map.dart';

void openTripNavigation(BuildContext context) {
  final bloc = context.read<ActiveTripBloc>();
  final live = context.read<DriverTripRepository>() is! TripSimulator;
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: MapVinaNavigationScreen(live: live),
      ),
    ),
  );
}

class MapVinaNavigationScreen extends StatelessWidget {
  const MapVinaNavigationScreen({super.key, required this.live});
  final bool live;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ActiveTripBloc, ActiveTripState>(
        builder: (_, state) {
          final trip = state.session.trip;
          if (trip == null || !trip.ongoing) {
            return Scaffold(
              appBar: AppBar(title: const Text('Đường đi')),
              body: const Center(
                child: Text('Chuyến đã kết thúc hoặc không còn hoạt động.'),
              ),
            );
          }
          final delivery = trip.stage == TripStage.inTransit;
          return Scaffold(
            appBar: AppBar(title: const Text('Dẫn đường MapVina')),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      delivery
                          ? trip.job.dropoff
                          : trip.job.handoverPoint != null
                          ? 'Điểm nhận hàng bàn giao'
                          : trip.job.pickup,
                    ),
                  ),
                  Expanded(
                    child: DriverMap(
                      route: true,
                      liveLocation: live,
                      position: state.session.fix?.point,
                      destination: delivery
                          ? trip.job.dropoffPoint
                          : trip.job.collectionPoint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
