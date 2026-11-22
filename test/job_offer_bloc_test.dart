import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/usecases/driver_trip_actions.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/job_offer_bloc.dart';

void main() {
  test(
    'offer uses one absolute 10-minute matching deadline across reopen and background (K-02)',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 11, 8, 9);
        final repo = MockDriverTripRepository(
          delay: Duration.zero,
          autoOffer: false,
          clock: () => start.add(async.elapsed),
        );
        final bloc = JobOfferBloc(DriverTripActions(repo));
        repo.setOnline(true);
        async.elapse(Duration.zero);
        bloc.add(OfferOpened(repo.current.jobs.first.id));
        async.elapse(Duration.zero);
        expect(bloc.state.seconds, 600);
        final deadline = bloc.state.offer!.deadline;
        final firstId = bloc.state.offer!.job.id;
        async.elapse(const Duration(seconds: 7));
        expect(bloc.state.seconds, 593);
        bloc.add(OfferOpened(repo.current.jobs.last.id));
        async.elapse(Duration.zero);
        bloc.add(OfferOpened(firstId));
        async.elapse(Duration.zero);
        expect(bloc.state.offer!.deadline, deadline);
        bloc.add(OfferOpened(bloc.state.offer!.job.id));
        async.elapse(Duration.zero);
        expect(bloc.state.offer!.deadline, deadline);
        repo.setForeground(false);
        async.elapse(const Duration(seconds: 594));
        expect(bloc.state.seconds, 0);
        expect(bloc.state.canAccept, isFalse);
        expect(bloc.state.status, OfferStatus.expired);
        bloc.close();
        repo.close();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    },
  );
  test('decline clears the offer and does not immediately show it again', () {
    fakeAsync((async) {
      final repo = MockDriverTripRepository(
        delay: Duration.zero,
        autoOffer: false,
      );
      final bloc = JobOfferBloc(DriverTripActions(repo));
      repo.setOnline(true);
      async.elapse(Duration.zero);
      final id = repo.current.jobs.first.id;
      bloc.add(OfferOpened(id));
      async.elapse(Duration.zero);
      bloc.add(OfferDeclined());
      async.elapse(Duration.zero);
      expect(bloc.state.status, OfferStatus.declined);
      expect(repo.current.offer, isNull);
      expect(repo.current.jobs.any((job) => job.id == id), isFalse);
      bloc.close();
      repo.close();
      async.flushMicrotasks();
    });
  });
}
