import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/usecases/driver_trip_actions.dart';

sealed class DriverHomeEvent {}

class HomeRefreshed extends DriverHomeEvent {}

class AvailabilityChanged extends DriverHomeEvent {
  AvailabilityChanged(this.online);
  final bool online;
}

class SessionReceived extends DriverHomeEvent {
  SessionReceived(this.session);
  final DriverSession session;
}

class DriverHomeState {
  const DriverHomeState(this.session, {this.loading = false, this.error});
  final DriverSession session;
  final bool loading;
  final String? error;
}

class DriverHomeBloc extends Bloc<DriverHomeEvent, DriverHomeState> {
  DriverHomeBloc(this.actions)
    : super(DriverHomeState(actions.repository.current)) {
    on<DriverHomeEvent>(_handle, transformer: sequential());
    _subscription = actions.repository.changes.listen(
      (s) => add(SessionReceived(s)),
    );
  }
  final DriverTripActions actions;
  late final StreamSubscription<DriverSession> _subscription;
  Future<void> _handle(
    DriverHomeEvent event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (event is SessionReceived) {
      emit(DriverHomeState(event.session, error: state.error));
      return;
    }
    emit(DriverHomeState(state.session, loading: true));
    try {
      if (event is AvailabilityChanged) await actions.setOnline(event.online);
      if (event is HomeRefreshed) await actions.repository.refresh();
      emit(DriverHomeState(actions.repository.current));
    } catch (e) {
      emit(
        DriverHomeState(
          actions.repository.current,
          error: e is TripFailure
              ? e.message
              : 'Chưa tải được dữ liệu. Thử lại.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
