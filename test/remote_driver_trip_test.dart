import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/remote_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/data/services/driver_tracking_connection.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_location_gateway.dart';
import 'support/remote_fixtures.dart';

class TestLocation implements DriverLocationGateway {
  TestLocation(this.clock);
  final DateTime Function() clock;
  bool denied = false;
  @override
  Future<GpsFix> current({bool requestPermission = false}) async {
    if (denied) throw const TripFailure('Cần quyền GPS');
    return GpsFix(const GeoPoint(10.724, 106.7057), clock());
  }
}

class TestTracking implements DriverTrackingConnection {
  final controller = StreamController<void>.broadcast();
  int sent = 0, pauses = 0;
  @override
  Stream<void> get updates => controller.stream;
  @override
  Future<void> send(GpsFix fix) async {
    sent++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> close() => controller.close();
}

void main() {
  late ApiClient api;
  late RemoteDriverTripRepository repo;
  late TestLocation location;
  late TestTracking tracking;
  late DateTime now;
  bool online = true;
  int? activeId;
  int acceptCode = 204, accepts = 0, patches = 0;
  setUp(() async {
    now = DateTime.utc(2026, 11, 8);
    online = true;
    activeId = null;
    acceptCode = 204;
    accepts = 0;
    patches = 0;
    location = TestLocation(() => now);
    tracking = TestTracking();
    api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient((r) async {
        switch (r.url.path) {
          case '/api/driver/status':
            return jsonResponse(
              driverStatus(online: online, orderId: activeId),
            );
          case '/api/driver/matching/orders':
            return jsonResponse([nearbyOrder(now)]);
          case '/api/driver/online-status':
            patches++;
            online = r.body.contains('true');
            return http.Response('', 204);
          case '/api/driver/matching/orders/42/accept':
            accepts++;
            if (acceptCode == 204) {
              activeId = 42;
              return http.Response('', 204);
            }
            if (acceptCode == 599) {
              activeId = 42;
              throw http.ClientException('response lost');
            }
            return jsonResponse({'code': 'CONFLICT'}, acceptCode);
          default:
            throw StateError('Unexpected ${r.url.path}');
        }
      }),
    );
    await api.saveSession(tokens());
    repo = RemoteDriverTripRepository(
      api,
      location,
      tracking,
      clock: () => now,
    );
    await repo.initialize();
  });
  tearDown(() async {
    await repo.close();
    await api.close();
  });
  test(
    'server money, payer and GPS drive the actual offer; missing customer is not invented',
    () {
      final job = repo.current.offer!.job;
      expect(job.net, 204000);
      expect(job.payment, PaymentMethod.cashReceiver);
      expect(job.customerPhone, isEmpty);
      expect(job.customerName, isEmpty);
      expect(tracking.sent, 1);
      expect(repo.current.deposit, 250000);
    },
  );
  test('refresh never restarts the 30-second offer countdown', () async {
    final deadline = repo.current.offer!.deadline;
    now = now.add(const Duration(seconds: 20));
    await repo.refresh();
    expect(repo.current.offer!.deadline, deadline);
    now = now.add(const Duration(seconds: 11));
    await repo.refresh();
    expect(repo.current.offer, isNull);
    await expectLater(repo.openOffer('42'), throwsA(isA<TripFailure>()));
    expect(accepts, 0);
  });
  test('409 removes offer and never creates a local accepted trip', () async {
    acceptCode = 409;
    await expectLater(repo.acceptOffer('42'), throwsA(isA<TripFailure>()));
    expect(repo.current.trip, isNull);
    expect(repo.current.offer, isNull);
    expect(accepts, 1);
  });
  test(
    'successful accept persists details; unavailable trip API never advances it',
    () async {
      await repo.acceptOffer('42');
      expect(repo.current.trip!.stage, TripStage.accepted);
      await expectLater(repo.arrive(), throwsA(isA<TripFailure>()));
      expect(repo.current.trip!.stage, TripStage.accepted);
      await repo.close();
      tracking = TestTracking();
      repo = RemoteDriverTripRepository(
        api,
        location,
        tracking,
        clock: () => now,
      );
      await repo.initialize();
      expect(repo.current.trip!.job.pickup, '12 Nguyễn Văn Linh');
      expect(repo.current.jobs, isEmpty);
    },
  );
  test(
    'lost accept response reconciles status instead of sending duplicate acceptance',
    () async {
      acceptCode = 599;
      await repo.acceptOffer('42');
      expect(repo.current.trip!.job.id, '42');
      expect(accepts, 1);
    },
  );
  test(
    'permission denied prevents online PATCH; background stops GPS sends',
    () async {
      location.denied = true;
      await expectLater(repo.setOnline(true), throwsA(isA<TripFailure>()));
      expect(patches, 0);
      location.denied = false;
      final sent = tracking.sent;
      repo.setForeground(false);
      await repo.refresh();
      expect(tracking.sent, sent);
      expect(tracking.pauses, 1);
    },
  );
  test(
    'server active order without cached details is represented without fake addresses',
    () async {
      activeId = 100;
      await repo.refresh();
      expect(repo.current.trip!.job.id, '100');
      expect(repo.current.trip!.job.detailsAvailable, false);
      expect(repo.current.trip!.job.pickup, isEmpty);
      expect(repo.current.jobs, isEmpty);
    },
  );
}
