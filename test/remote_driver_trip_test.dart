import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/remote_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/data/services/driver_tracking_connection.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_location_gateway.dart';
import 'support/remote_fixtures.dart';

class TestLocation
    implements
        DriverLocationGateway,
        DriverLocationLifecycle,
        DriverLocationSettings {
  TestLocation(this.clock);
  final DateTime Function() clock;
  bool denied = false;
  DriverLocationIssue? problem;
  bool grantOnRequest = false;
  int permissionRequests = 0, appSettings = 0, locationSettings = 0;
  GeoPoint point = const GeoPoint(10.7348, 106.7057);
  Duration age = Duration.zero;
  bool started = false;
  @override
  Future<void> startTracking() async {
    started = true;
  }

  @override
  Future<void> stopTracking() async {
    started = false;
  }

  @override
  Future<GpsFix> current({bool requestPermission = false}) async {
    if (requestPermission) {
      permissionRequests++;
      if (grantOnRequest) denied = false;
    }
    final issue =
        problem ?? (denied ? DriverLocationIssue.permissionDenied : null);
    if (issue != null) {
      throw DriverLocationFailure(issue, 'Vị trí chưa sẵn sàng');
    }
    return GpsFix(point, clock().subtract(age));
  }

  @override
  Future<bool> openAppSettings() async {
    appSettings++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettings++;
    return true;
  }
}

class TestTracking implements DriverTrackingConnection {
  final controller = StreamController<void>.broadcast();
  int sent = 0, pauses = 0;
  bool fail = false;
  @override
  Stream<void> get updates => controller.stream;
  @override
  Future<void> send(GpsFix fix) async {
    if (fail) throw const TripFailure('Kết nối theo dõi gián đoạn');
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
  String stage = 'Accepted', proof = 'Pending';
  int attempts = 0, writes = 0;
  bool paid = false, loseWriteResponse = false;
  setUp(() async {
    now = DateTime.utc(2026, 11, 8);
    online = true;
    activeId = null;
    acceptCode = 204;
    accepts = 0;
    patches = 0;
    stage = 'Accepted';
    proof = 'Pending';
    attempts = 0;
    writes = 0;
    paid = false;
    loseWriteResponse = false;
    location = TestLocation(() => now);
    tracking = TestTracking();
    api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient((r) async {
        if (r.url.path.startsWith('/api/driver/trips/') && r.method == 'GET') {
          return jsonResponse(
            tripDetail(
              now,
              id: int.parse(r.url.path.split('/').last),
              stage: stage,
              proofStatus: proof,
              attempts: attempts,
              paid: paid,
            ),
          );
        }
        switch (r.url.path) {
          case '/api/driver/wallet/earnings':
            return jsonResponse({'completedTrips': 3, 'netEarnings': 430000});
          case '/api/driver/matching/orders/42':
            return jsonResponse({
              ...nearbyOrder(now),
              'canAccept': true,
              'distanceFee': 220000,
              'serviceFee': 40000,
              'discountAmount': 20000,
              'vehicleTypeName': 'Xe tải 1 tấn',
              'matchingExpiresAt': now
                  .add(const Duration(seconds: 12))
                  .toIso8601String(),
            });
          case '/api/driver/trips/42/arrive':
            writes++;
            stage = 'Arrived';
            if (loseWriteResponse) throw http.ClientException('response lost');
            return http.Response('', 204);
          case '/api/driver/trips/42/pickup':
            expect(jsonDecode(r.body)['photoUrls'], hasLength(2));
            writes++;
            stage = 'PickedUp';
            proof = 'Pending';
            attempts++;
            return http.Response('', 204);
          case '/api/driver/trips/42/deliver':
            expect(
              jsonDecode(r.body)['deliveryPhotoUrl'],
              'https://images.test/pod.png',
            );
            writes++;
            stage = 'Delivered';
            paid = true;
            activeId = null;
            if (loseWriteResponse) throw http.ClientException('response lost');
            return http.Response('', 204);
          case '/api/driver/uploads':
            expect(
              r.headers['content-type'],
              startsWith('multipart/form-data'),
            );
            return jsonResponse({'url': 'https://images.test/pod.png'});
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
  test(
    'job details use backend fee breakdown and shorter matching deadline',
    () async {
      await repo.openOffer('42');
      expect(repo.current.offer!.job.distanceFee, 220000);
      expect(repo.current.offer!.job.discount, 20000);
      expect(repo.current.offer!.remainingAt(now), 12);
      expect(repo.current.shift.completed, 3);
      now = now.add(const Duration(seconds: 13));
      await expectLater(repo.acceptOffer('42'), throwsA(isA<TripFailure>()));
      expect(accepts, 0);
    },
  );
  test('409 removes offer and never creates a local accepted trip', () async {
    acceptCode = 409;
    await expectLater(repo.acceptOffer('42'), throwsA(isA<TripFailure>()));
    expect(repo.current.trip, isNull);
    expect(repo.current.offer, isNull);
    expect(accepts, 1);
  });
  test(
    'accepted trip loads server contacts and restores actual stage after restart',
    () async {
      await repo.acceptOffer('42');
      expect(repo.current.trip!.stage, TripStage.accepted);
      expect(repo.current.trip!.job.customerPhone, '0901234567');
      await repo.arrive();
      expect(repo.current.trip!.stage, TripStage.arrived);
      await repo.close();
      tracking = TestTracking();
      repo = RemoteDriverTripRepository(
        api,
        location,
        tracking,
        clock: () => now,
      );
      await repo.initialize();
      expect(repo.current.trip!.stage, TripStage.arrived);
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
    'permission denied prevents online PATCH; a foreground location service keeps sending in background',
    () async {
      location.denied = true;
      await expectLater(repo.setOnline(true), throwsA(isA<TripFailure>()));
      expect(patches, 0);
      location.denied = false;
      final sent = tracking.sent;
      repo.setForeground(false);
      now = now.add(const Duration(seconds: 6));
      await repo.refresh();
      expect(tracking.sent, sent + 1);
      expect(tracking.pauses, 0);
      expect(location.started, true);
    },
  );
  test(
    'server active order is recovered on a new device without a local cache',
    () async {
      activeId = 100;
      await repo.refresh();
      expect(repo.current.trip!.job.id, '100');
      expect(repo.current.trip!.job.detailsAvailable, true);
      expect(repo.current.trip!.job.pickup, '12 Nguyễn Văn Linh');
      expect(repo.current.jobs, isEmpty);
    },
  );
  test(
    'restored online driver can grant location without toggling server availability',
    () async {
      location.denied = true;
      now = now.add(const Duration(seconds: 6));
      await repo.refresh();
      await repo.refresh();
      expect(location.permissionRequests, 0);
      expect(repo.current.online, true);
      expect(repo.current.gpsEnabled, false);
      expect(repo.current.fix, isNull);
      expect(repo.current.jobs, isEmpty);
      expect(
        repo.current.locationFailure?.issue,
        DriverLocationIssue.permissionDenied,
      );
      location.grantOnRequest = true;
      await repo.recoverLocation();
      expect(location.permissionRequests, 1);
      expect(repo.current.gpsEnabled, true);
      expect(repo.current.locationFailure, isNull);
      expect(repo.current.jobs, isNotEmpty);
      expect(patches, 0);
    },
  );
  test(
    'blocked permission and disabled service open the corresponding settings once',
    () async {
      for (final issue in [
        DriverLocationIssue.permissionBlocked,
        DriverLocationIssue.serviceDisabled,
      ]) {
        location.problem = issue;
        await repo.recoverLocation();
        expect(repo.current.locationFailure?.issue, issue);
        expect(repo.current.gpsEnabled, false);
      }
      expect(location.appSettings, 1);
      expect(location.locationSettings, 1);
      expect(location.permissionRequests, 0);
      expect(patches, 0);
      location.problem = null;
      final recovered = repo.changes.firstWhere((s) => s.gpsEnabled);
      repo.setForeground(true);
      await recovered;
      expect(repo.current.locationFailure, isNull);
    },
  );
  test(
    'returning from settings clears the GPS error without going online',
    () async {
      online = false;
      location.denied = true;
      await expectLater(
        repo.setOnline(true),
        throwsA(isA<DriverLocationFailure>()),
      );
      location.denied = false;
      await repo.refresh();
      expect(repo.current.online, false);
      expect(repo.current.gpsEnabled, true);
      expect(repo.current.locationFailure, isNull);
      expect(patches, 0);
    },
  );
  test(
    'tracking connection failure does not label available GPS as denied',
    () async {
      now = now.add(const Duration(seconds: 6));
      tracking.fail = true;
      final failed = repo.changes.firstWhere((s) => s.notice != null);
      repo.setForeground(true);
      await failed;
      expect(repo.current.gpsEnabled, true);
      expect(repo.current.locationFailure, isNull);
      expect(repo.current.notice, 'Kết nối theo dõi gián đoạn');
    },
  );
  test(
    'pickup resubmission follows server review and stops after five attempts',
    () async {
      await repo.acceptOffer('42');
      await repo.arrive();
      Future<void> submit() => repo.submitInspection(
        evidence: const [
          UploadedEvidence(CargoPhotoKind.overall, 'https://images.test/a.png'),
          UploadedEvidence(CargoPhotoKind.secured, 'https://images.test/b.png'),
        ],
        checklist: [true, true, true, true],
        note: '',
        cashCollected: false,
      );
      await submit();
      expect(repo.current.trip!.review, EvidenceReview.pending);
      expect(repo.current.trip!.attempts, 1);
      proof = 'Rejected';
      await repo.refresh();
      expect(repo.current.trip!.editable, true);
      await submit();
      expect(attempts, 2);
      attempts = 5;
      proof = 'Rejected';
      await repo.refresh();
      expect(repo.current.trip!.editable, false);
      await expectLater(submit(), throwsA(isA<TripFailure>()));
      stage = 'InTransit';
      proof = 'Verified';
      await repo.refresh();
      expect(repo.current.trip!.stage, TripStage.inTransit);
    },
  );
  test(
    'delivery requires uploaded POD and COD; lost response is reconciled without replay',
    () async {
      await repo.acceptOffer('42');
      stage = 'InTransit';
      attempts = 1;
      proof = 'Verified';
      await repo.refresh();
      await expectLater(
        repo.deliver(
          photoUrl: 'https://images.test/pod.png',
          cashCollected: false,
        ),
        throwsA(isA<TripFailure>()),
      );
      expect(writes, 0);
      final photo = CargoPhoto(
        kind: CargoPhotoKind.overall,
        name: 'pod.png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      );
      final uploaded = await repo.upload(photo, (_) {});
      await expectLater(
        repo.deliver(photoUrl: uploaded.reference, cashCollected: true),
        throwsA(isA<TripFailure>()),
      );
      expect(
        writes,
        0,
      ); // Still at pickup: uploaded POD alone cannot complete a trip.
      location.point = repo.current.trip!.job.dropoffPoint;
      location.age = const Duration(seconds: 31);
      await expectLater(
        repo.deliver(photoUrl: uploaded.reference, cashCollected: true),
        throwsA(isA<TripFailure>()),
      );
      expect(writes, 0);
      location.age = Duration.zero;
      loseWriteResponse = true;
      await repo.deliver(photoUrl: uploaded.reference, cashCollected: true);
      expect(repo.current.trip!.stage, TripStage.delivered);
      expect(repo.current.trip!.ongoing, false);
      expect(
        repo.current.earnings,
        120000,
      ); // never credit predicted earnings locally
      expect(writes, 1);
      await repo.refresh();
      expect(repo.current.trip!.stage, TripStage.delivered);
    },
  );
  test('lost arrival response does not repeat the POST', () async {
    await repo.acceptOffer('42');
    loseWriteResponse = true;
    await repo.arrive();
    expect(repo.current.trip!.stage, TripStage.arrived);
    expect(writes, 1);
  });
}
