import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';

void main() {
  test(
    'arrival requires fresh GPS within 500m; cancellation blocks arrival',
    () async {
      var now = DateTime(2026, 11, 8, 9);
      final repo = MockDriverTripRepository(
        delay: Duration.zero,
        autoOffer: false,
        clock: () => now,
      );
      addTearDown(repo.close);
      await repo.setOnline(true);
      final id = repo.current.jobs.first.id;
      await repo.openOffer(id);
      await repo.acceptOffer(id);
      await expectLater(repo.arrive(), throwsA(isA<TripFailure>()));
      expect(repo.current.trip!.stage, TripStage.accepted);
      await repo.simulate(TripSimulation.nearPickup);
      repo.setForeground(false);
      now = now.add(const Duration(seconds: 31));
      await expectLater(repo.arrive(), throwsA(isA<TripFailure>()));
      repo.setForeground(true);
      await repo.arrive();
      final arrivedAt = repo.current.trip!.arrivedAt;
      await repo.arrive();
      expect(repo.current.trip!.arrivedAt, arrivedAt);
      await repo.simulate(TripSimulation.cancelOrder);
      await expectLater(repo.arrive(), throwsA(isA<TripFailure>()));
    },
  );
  test(
    'first accept wins atomically and a second active job is forbidden',
    () async {
      final repo = MockDriverTripRepository(
        delay: Duration.zero,
        autoOffer: false,
      );
      addTearDown(repo.close);
      await repo.setOnline(true);
      final jobs = repo.current.jobs;
      await repo.openOffer(jobs.first.id);
      final results = await Future.wait(
        List.generate(2, (_) async {
          try {
            await repo.acceptOffer(jobs.first.id);
            return true;
          } on TripFailure {
            return false;
          }
        }),
      );
      expect(results.where((won) => won).length, 1);
      expect(repo.current.trip!.job.id, jobs.first.id);
      expect(repo.current.jobs, isEmpty);
      await expectLater(
        repo.openOffer(jobs.last.id),
        throwsA(isA<TripFailure>()),
      );
      await expectLater(repo.setOnline(false), throwsA(isA<TripFailure>()));
    },
  );
  test('accept revalidates race, expiry and account eligibility', () async {
    var now = DateTime(2026, 11, 8, 9);
    final repo = MockDriverTripRepository(
      delay: Duration.zero,
      autoOffer: false,
      clock: () => now,
    );
    addTearDown(repo.close);
    await repo.setOnline(true);
    await repo.openOffer(repo.current.jobs.first.id);
    final id = repo.current.offer!.job.id;
    await repo.simulate(TripSimulation.acceptElsewhere);
    await expectLater(repo.acceptOffer(id), throwsA(isA<TripFailure>()));
    expect(repo.current.trip, isNull);
    await repo.simulate(TripSimulation.newOffer);
    final secondId = repo.current.offer!.job.id;
    now = now.add(const Duration(seconds: 30));
    await expectLater(repo.acceptOffer(secondId), throwsA(isA<TripFailure>()));
    expect(repo.current.trip, isNull);
    await repo.simulate(TripSimulation.newOffer);
    final thirdId = repo.current.offer!.job.id;
    repo.updateAccess(const DriverAccess(approved: true, active: false));
    await expectLater(repo.acceptOffer(thirdId), throwsA(isA<TripFailure>()));
  });
  test(
    'network failure rolls acceptance back and retry succeeds once',
    () async {
      final repo = MockDriverTripRepository(
        delay: Duration.zero,
        autoOffer: false,
      );
      addTearDown(repo.close);
      await repo.setOnline(true);
      await repo.openOffer(repo.current.jobs.first.id);
      final id = repo.current.offer!.job.id;
      await repo.simulate(TripSimulation.requestFailure);
      await expectLater(repo.acceptOffer(id), throwsA(isA<TripFailure>()));
      expect(repo.current.trip, isNull);
      await repo.acceptOffer(id);
      expect(repo.current.trip!.stage, TripStage.accepted);
    },
  );
  test(
    'only approved active drivers can go online and see matching jobs',
    () async {
      final repo = MockDriverTripRepository(
        delay: Duration.zero,
        autoOffer: false,
        access: const DriverAccess(approved: false, active: true),
      );
      addTearDown(repo.close);
      await expectLater(repo.setOnline(true), throwsA(isA<TripFailure>()));
      expect(repo.current.jobs, isEmpty);
      repo.updateAccess(const DriverAccess(approved: true, active: true));
      await repo.setOnline(true);
      expect(repo.current.jobs, hasLength(2));
      await repo.simulate(TripSimulation.lowDeposit);
      // BE (tiền cọc tối thiểu áp dụng cho mọi đơn): thiếu tiền cọc thì không thấy đơn nào.
      expect(repo.current.jobs, isEmpty);
      repo.updateAccess(const DriverAccess(approved: true, active: false));
      expect(repo.current.online, isFalse);
      expect(repo.current.jobs, isEmpty);
    },
  );
  test(
    'GPS pings every five seconds, stops offline and resumes without duplicate timers',
    () {
      fakeAsync((async) {
        final repo = MockDriverTripRepository(
          delay: Duration.zero,
          autoOffer: false,
        );
        repo.setOnline(true);
        async.elapse(Duration.zero);
        expect(repo.current.pings, 1);
        async.elapse(const Duration(seconds: 10));
        expect(repo.current.pings, 3);
        repo.setForeground(false);
        async.elapse(const Duration(seconds: 20));
        expect(repo.current.pings, 3);
        repo.setForeground(true);
        async.elapse(const Duration(seconds: 5));
        expect(repo.current.pings, 5);
        repo.setOnline(false);
        async.elapse(Duration.zero);
        async.elapse(const Duration(seconds: 10));
        expect(repo.current.pings, 5);
        repo.close();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
      });
    },
  );
  test('lost GPS hides jobs and prevents going online', () async {
    final repo = MockDriverTripRepository(
      delay: Duration.zero,
      autoOffer: false,
    );
    addTearDown(repo.close);
    await repo.setOnline(true);
    await repo.simulate(TripSimulation.gpsLost);
    expect(repo.current.jobs, isEmpty);
    await repo.setOnline(false);
    await expectLater(repo.setOnline(true), throwsA(isA<TripFailure>()));
    await repo.simulate(TripSimulation.gpsRestored);
    await repo.setOnline(true);
    expect(repo.current.jobs, isNotEmpty);
  });
}
