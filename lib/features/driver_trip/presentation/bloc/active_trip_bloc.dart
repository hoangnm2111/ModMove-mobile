import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/usecases/driver_trip_actions.dart';

class ActiveTripState {
  const ActiveTripState(
    this.session,
    this.now, {
    this.busy = false,
    this.error,
    this.receipt,
  });
  final DriverSession session;
  final DateTime now;
  final bool busy;
  final String? error, receipt;
  bool get fresh => session.gpsEnabled && (session.fix?.freshAt(now) ?? false);
  double get distance => session.trip == null || session.fix == null
      ? double.infinity
      : session.fix!.point.distanceTo(session.trip!.job.collectionPoint);
  bool get canArrive =>
      fresh &&
      distance <= 500 &&
      session.trip?.stage == TripStage.accepted &&
      !busy;
}

sealed class ActiveTripEvent {}

class ActiveTripUpdated extends ActiveTripEvent {
  ActiveTripUpdated(this.session);
  final DriverSession session;
}

class ArrivalRequested extends ActiveTripEvent {}

class CustomerCalled extends ActiveTripEvent {}

class ExternalNavigationOpened extends ActiveTripEvent {}

class IncidentReported extends ActiveTripEvent {
  IncidentReported(this.message);
  final String message;
}

class ActiveTripBloc extends Bloc<ActiveTripEvent, ActiveTripState> {
  ActiveTripBloc(this.actions, this.contact)
    : super(
        ActiveTripState(actions.repository.current, actions.repository.now),
      ) {
    on<ActiveTripEvent>(_handle, transformer: sequential());
    _subscription = actions.repository.changes.listen(
      (s) => add(ActiveTripUpdated(s)),
    );
    _freshness = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.session.trip != null) {
        add(ActiveTripUpdated(actions.repository.current));
      }
    });
  }
  final DriverTripActions actions;
  final TripContactRepository contact;
  late final StreamSubscription<DriverSession> _subscription;
  late final Timer _freshness;
  Future<void> _handle(
    ActiveTripEvent event,
    Emitter<ActiveTripState> emit,
  ) async {
    if (event is ActiveTripUpdated) {
      emit(
        ActiveTripState(
          actions.repository.current,
          actions.repository.now,
          error: state.error,
          receipt: state.receipt,
        ),
      );
      return;
    }
    emit(ActiveTripState(state.session, actions.repository.now, busy: true));
    try {
      final trip = actions.repository.current.trip;
      if (trip == null) {
        throw const TripFailure('Chưa có chuyến đang thực hiện.');
      }
      if (event is ArrivalRequested) await actions.arrive();
      if (event is CustomerCalled &&
          !await contact.callCustomer(trip.job.customerPhone)) {
        throw TripFailure(
          'Không mở được ứng dụng gọi điện. Số khách: ${trip.job.customerPhone}',
        );
      }
      if (event is ExternalNavigationOpened &&
          !await contact.openNavigation(
            trip.stage == TripStage.inTransit
                ? trip.job.dropoffPoint
                : trip.job.collectionPoint,
          )) {
        throw const TripFailure(
          'Không mở được Google Maps. Hãy dùng địa chỉ điểm lấy hàng.',
        );
      }
      String? receipt;
      if (event is IncidentReported) {
        receipt = await actions.repository.reportIncident(event.message);
      }
      emit(
        ActiveTripState(
          actions.repository.current,
          actions.repository.now,
          receipt: receipt,
        ),
      );
    } catch (e) {
      emit(
        ActiveTripState(
          actions.repository.current,
          actions.repository.now,
          error: e is TripFailure
              ? e.message
              : 'Chưa thể thực hiện. Vui lòng thử lại.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _freshness.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
