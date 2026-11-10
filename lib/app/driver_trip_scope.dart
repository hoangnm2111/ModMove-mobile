import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/onboarding/presentation/controllers/driver_controller.dart';
import '../features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import '../features/driver_trip/domain/entities/trip_models.dart';
import '../features/driver_trip/domain/repositories/driver_trip_repository.dart';
import '../features/driver_trip/domain/repositories/trip_history_repository.dart';
import '../features/driver_trip/domain/usecases/driver_trip_actions.dart';
import '../features/driver_trip/presentation/bloc/driver_home_bloc.dart';
import '../features/driver_trip/presentation/bloc/job_offer_bloc.dart';
import '../features/driver_trip/presentation/bloc/active_trip_bloc.dart';
import '../features/driver_trip/data/repositories/platform_trip_contact_repository.dart';
import '../features/driver_trip/data/repositories/device_cargo_photo_repository.dart';
import '../features/driver_trip/presentation/bloc/evidence_cubit.dart';

class DriverTripScope extends StatefulWidget {
  const DriverTripScope({
    super.key,
    required this.child,
    this.repository,
    this.cargoPhotos,
  });
  final Widget child;
  final DriverTripRepository? repository;
  final CargoPhotoRepository? cargoPhotos;
  @override
  State<DriverTripScope> createState() => _DriverTripScopeState();
}

class _DriverTripScopeState extends State<DriverTripScope>
    with WidgetsBindingObserver {
  late final DriverTripRepository _repository;
  late final DriverHomeBloc _homeBloc;
  late final DriverController _driver;
  late final StreamSubscription<DriverPresentationState> _profileSubscription;
  late final StreamSubscription<DriverSession> _tripSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final driver = context.read<DriverController>();
    _driver = driver;
    _repository =
        widget.repository ??
        MockDriverTripRepository(
          access: DriverAccess(
            approved: driver.canGoOnline,
            active: driver.accountActive,
          ),
          availabilityGateway: driver.saveOnline,
          initialOnline: driver.online,
        );
    _homeBloc = DriverHomeBloc(DriverTripActions(_repository));
    _tripSubscription = _repository.changes.listen((session) {
      driver.receiveOnline(session.online);
    });
    driver.availabilityDelegate = (value) async {
      final success = await _homeBloc.changeAvailability(value);
      if (!success) driver.reportAvailabilityError(_homeBloc.state.error);
      return success;
    };
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
    _driver.availabilityDelegate = null;
    unawaited(_homeBloc.close());
    unawaited(_profileSubscription.cancel());
    unawaited(_tripSubscription.cancel());
    if (widget.repository == null) {
      unawaited((_repository as MockDriverTripRepository).close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<DriverTripRepository>.value(value: _repository),
      RepositoryProvider<CargoPhotoRepository>(
        create: (_) => widget.cargoPhotos ?? DeviceCargoPhotoRepository(),
      ),
      RepositoryProvider<TripContactRepository>(
        create: (_) => const PlatformTripContactRepository(),
      ),
      if (_repository is DriverDeliveryRepository)
        RepositoryProvider<DriverDeliveryRepository>.value(
          value: _repository as DriverDeliveryRepository,
        ),
      if (_repository is TripHistoryRepository)
        RepositoryProvider<TripHistoryRepository>.value(
          value: _repository as TripHistoryRepository,
        ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => EvidenceCubit(
            DriverTripActions(_repository),
            widget.cargoPhotos ?? DeviceCargoPhotoRepository(),
          ),
        ),
        BlocProvider.value(value: _homeBloc),
        BlocProvider(
          create: (_) => JobOfferBloc(DriverTripActions(_repository)),
        ),
        BlocProvider(
          create: (_) => ActiveTripBloc(
            DriverTripActions(_repository),
            const PlatformTripContactRepository(),
          ),
        ),
      ],
      child: widget.child,
    ),
  );
}
