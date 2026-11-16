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
    this.delivered = false,
  });
  final DriverSession session;
  final DateTime now;
  final bool busy, delivered;
  final String? error, receipt;
  /// Sự cố do tài xế báo còn mở: khóa các bước của chuyến. Sự cố do khách báo chỉ nhắc, không khóa.
  TripIncident? get blockingIncident => session.trip?.blockingIncident;
  TripIncident? get customerIncident => session.trip?.customerOpenIncident;
  bool get paused => blockingIncident != null;
  bool get fresh => session.gpsEnabled && (session.fix?.freshAt(now) ?? false);
  double get distance => session.trip == null || session.fix == null
      ? double.infinity
      : session.fix!.point.distanceTo(session.trip!.job.pickupPoint);
  /// GB-52 (D-02): bán kính xác nhận đến điểm lấy hàng / hoàn tất giao hàng. Chỉ app kiểm tra, BE không kiểm tra lại.
  static const arrivalRadiusM = 500.0;

  /// GPS mới (nên đã có vị trí) và cách điểm giao không quá [arrivalRadiusM].
  bool get atDropoff =>
      fresh &&
      session.trip != null &&
      session.fix!.point.distanceTo(session.trip!.job.dropoffPoint) <=
          arrivalRadiusM;
  /// GPS mới và cách điểm lấy hàng không quá [arrivalRadiusM] (thu tiền người gửi chỉ làm được ở đây).
  bool get atPickup =>
      fresh &&
      session.trip != null &&
      session.fix!.point.distanceTo(session.trip!.job.pickupPoint) <=
          arrivalRadiusM;
  bool get canArrive =>
      fresh &&
      distance <= arrivalRadiusM &&
      session.trip?.stage == TripStage.accepted &&
      !paused &&
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
  IncidentReported(this.draft);
  final IncidentDraft draft;
}

class DropoffArrived extends ActiveTripEvent {}

class CashCollected extends ActiveTripEvent {}

class DeliveryCompleted extends ActiveTripEvent {
  DeliveryCompleted(this.proof);
  final CargoPhoto proof;
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
          event.session,
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
                : trip.job.pickupPoint,
          )) {
        throw const TripFailure(
          'Không mở được Google Maps. Hãy dùng địa chỉ điểm lấy hàng.',
        );
      }
      String? receipt;
      var delivered = false;
      if (event is IncidentReported) {
        final id = await actions.repository.reportIncident(event.draft);
        receipt = 'Đã gửi sự cố #$id';
      }
      if (event is DropoffArrived) await actions.repository.arriveDropoff();
      if (event is CashCollected) await actions.repository.collectCash();
      if (event is DeliveryCompleted) {
        await actions.repository.deliver(event.proof);
        delivered = true;
      }
      emit(
        ActiveTripState(
          actions.repository.current,
          actions.repository.now,
          receipt: receipt,
          delivered: delivered,
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
