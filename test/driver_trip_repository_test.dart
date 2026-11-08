import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';

void main() {
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
      expect(repo.current.jobs.single.payment, PaymentMethod.payos);
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
