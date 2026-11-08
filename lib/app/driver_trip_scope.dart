import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import '../features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import '../features/driver_trip/domain/entities/trip_models.dart';
import '../features/driver_trip/domain/repositories/driver_trip_repository.dart';
import '../features/driver_trip/domain/usecases/driver_trip_actions.dart';
import '../features/driver_trip/presentation/bloc/driver_home_bloc.dart';
import '../features/driver_trip/presentation/bloc/job_offer_bloc.dart';

class DriverTripScope extends StatefulWidget {
  const DriverTripScope({super.key, required this.child, this.repository});
  final Widget child;
  final DriverTripRepository? repository;
  @override
  State<DriverTripScope> createState() => _DriverTripScopeState();
}

class _DriverTripScopeState extends State<DriverTripScope>
    with WidgetsBindingObserver {
  late final DriverTripRepository _repository;
  late final StreamSubscription<DriverPresentationState> _profileSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final driver = context.read<DriverController>();
    _repository =
        widget.repository ??
        MockDriverTripRepository(
          access: DriverAccess(
            approved: driver.canGoOnline,
            active: driver.accountActive,
          ),
          availabilityGateway: driver.setOnline,
        );
    _profileSubscription = driver.stream.listen((state) {
      final profile = state.application;
      if (profile != null) {
        _repository.updateAccess(
          DriverAccess(
            approved: profile.canGoOnline,
            active: profile.accountActive,
          ),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive includes native camera/gallery overlays. Only pause GPS once
    // the app is actually backgrounded; resume never resets offer deadlines.
    if (state == AppLifecycleState.paused) _repository.setForeground(false);
    if (state == AppLifecycleState.resumed) _repository.setForeground(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_profileSubscription.cancel());
    if (widget.repository == null) {
      unawaited((_repository as MockDriverTripRepository).close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepositoryProvider<DriverTripRepository>.value(
        value: _repository,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => DriverHomeBloc(DriverTripActions(_repository)),
            ),
            BlocProvider(
              create: (_) => JobOfferBloc(DriverTripActions(_repository)),
            ),
          ],
          child: widget.child,
        ),
      );
}
