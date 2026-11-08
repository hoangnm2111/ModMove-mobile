import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/usecases/driver_trip_actions.dart';

enum OfferStatus {
  idle,
  available,
  accepting,
  accepted,
  declined,
  expired,
  unavailable,
}

class JobOfferState {
  const JobOfferState({
    this.offer,
    this.seconds = 0,
    this.status = OfferStatus.idle,
    this.error,
  });
  final JobOffer? offer;
  final int seconds;
  final OfferStatus status;
  final String? error;
  bool get canAccept =>
      offer != null && seconds > 0 && status == OfferStatus.available;
}

sealed class JobOfferEvent {}

class OfferOpened extends JobOfferEvent {
  OfferOpened(this.id);
  final String id;
}

class OfferDeclined extends JobOfferEvent {}

class OfferAccepted extends JobOfferEvent {}

class OfferTicked extends JobOfferEvent {}

class OfferSessionUpdated extends JobOfferEvent {
  OfferSessionUpdated(this.session);
  final DriverSession session;
}

class JobOfferBloc extends Bloc<JobOfferEvent, JobOfferState> {
  JobOfferBloc(this.actions) : super(const JobOfferState()) {
    on<JobOfferEvent>(_handle, transformer: sequential());
    _subscription = actions.repository.changes.listen(
      (s) => add(OfferSessionUpdated(s)),
    );
    add(OfferSessionUpdated(actions.repository.current));
  }
  final DriverTripActions actions;
  late final StreamSubscription<DriverSession> _subscription;
  Timer? _timer;
  void _timerFor(JobOfferState next) {
    if (next.status == OfferStatus.available ||
        next.status == OfferStatus.accepting) {
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => add(OfferTicked()),
      );
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _handle(JobOfferEvent event, Emitter<JobOfferState> emit) async {
    void publish(JobOfferState next) {
      _timerFor(next);
      emit(next);
    }

    JobOfferState available(JobOffer offer, {String? error}) {
      final seconds = offer.remainingAt(actions.repository.now);
      return JobOfferState(
        offer: offer,
        seconds: seconds,
        status: seconds == 0 ? OfferStatus.expired : OfferStatus.available,
        error: error,
      );
    }

    if (event is OfferSessionUpdated) {
      final session = event.session;
      if (state.offer != null &&
          session.trip?.job.id == state.offer!.job.id &&
          session.trip!.ongoing) {
        publish(
          JobOfferState(offer: state.offer, status: OfferStatus.accepted),
        );
      } else if (session.offer != null) {
        final offer = session.offer!;
        if (offer.remainingAt(actions.repository.now) == 0) {
          publish(JobOfferState(offer: offer, status: OfferStatus.expired));
          return;
        }
        if (!session.jobs.any((job) => job.id == offer.job.id)) {
          publish(
            JobOfferState(
              offer: offer,
              status: OfferStatus.unavailable,
              error: session.notice ?? 'Đơn không còn khả dụng.',
            ),
          );
        } else {
          publish(
            available(
              offer,
              error: state.offer?.job.id == offer.job.id ? state.error : null,
            ),
          );
        }
      } else if (state.status == OfferStatus.available) {
        publish(
          JobOfferState(
            offer: state.offer,
            status: state.offer!.remainingAt(actions.repository.now) == 0
                ? OfferStatus.expired
                : OfferStatus.unavailable,
          ),
        );
      }
      return;
    }
    if (event is OfferTicked) {
      if (state.offer != null && state.status == OfferStatus.available) {
        final seconds = state.offer!.remainingAt(actions.repository.now);
        if (seconds != state.seconds) {
          publish(available(state.offer!, error: state.error));
        }
      }
      return;
    }
    try {
      if (event is OfferOpened) {
        await actions.repository.openOffer(event.id);
        publish(available(actions.repository.current.offer!));
      } else if (event is OfferDeclined) {
        await actions.repository.declineOffer();
        publish(
          JobOfferState(offer: state.offer, status: OfferStatus.declined),
        );
      } else if (event is OfferAccepted && state.canAccept) {
        final offer = state.offer!;
        publish(
          JobOfferState(
            offer: offer,
            seconds: state.seconds,
            status: OfferStatus.accepting,
          ),
        );
        await actions.accept(offer.job.id);
        publish(JobOfferState(offer: offer, status: OfferStatus.accepted));
      }
    } catch (error) {
      final message = error is TripFailure
          ? error.message
          : 'Kết nối gián đoạn. Vui lòng thử lại.';
      final offer = state.offer ?? actions.repository.current.offer;
      if (offer != null &&
          actions.repository.current.jobs.any(
            (job) => job.id == offer.job.id,
          )) {
        publish(available(offer, error: message));
      } else {
        publish(
          JobOfferState(
            offer: offer,
            status: OfferStatus.unavailable,
            error: message,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
