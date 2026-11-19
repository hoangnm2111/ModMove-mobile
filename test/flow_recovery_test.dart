import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fake_async/fake_async.dart';
import 'package:modmove_mobile/features/notifications/domain/driver_notification.dart';
import 'package:modmove_mobile/features/notifications/presentation/live_refresh.dart';
import 'package:modmove_mobile/core/domain/draft_store.dart';
import 'package:modmove_mobile/core/platform/file_draft_store.dart';
import 'package:modmove_mobile/features/account/domain/account_security_repository.dart';
import 'package:modmove_mobile/features/account/presentation/account_security_cubit.dart';
import 'package:modmove_mobile/features/customer/domain/customer_models.dart'
    as customer;
import 'package:modmove_mobile/features/customer/presentation/customer_cubits.dart';
import 'package:modmove_mobile/features/driver_trip/data/models/driver_trip_dto.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/trip_history_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/usecases/driver_trip_actions.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/evidence_cubit.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/delivery_cubit.dart';
import 'support/customer_fixtures.dart';
import 'support/remote_fixtures.dart';

class MemoryDrafts implements DraftStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(value)) as Map,
    );
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

Map<String, dynamic> quote({bool recovery = true}) => {
  'distanceKm': 8,
  'durationMinutes': 20,
  'distanceFee': 90000,
  'serviceFee': 0,
  'discountAmount': 0,
  'totalFee': 90000,
  'supportsBookingRecovery': recovery,
};

void main() {
  test(
    'an interrupted cargo upload keeps its bytes across restart and clears them only after retry succeeds',
    () async {
      var fail = true;
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.endsWith('/Uploads') && fail) {
            return jsonResponse({'code': 'SERVER_ERROR'}, 500);
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final drafts = MemoryDrafts();
      final first = BookingCubit(t.repository, drafts: drafts);
      await first.initialize();
      first.edit(validDraft);
      final bytes = Uint8List.fromList([137, 80, 78, 71, 1]);
      await first.upload('cargo.png', bytes);
      expect(first.state.draft.pendingPhoto?.bytes, bytes);
      expect(
        first.state.draft.validate(submit: true),
        contains('chưa tải xong'),
      );
      await first.close();
      final restored = BookingCubit(t.repository, drafts: drafts);
      addTearDown(restored.close);
      await restored.initialize();
      expect(restored.state.draft.pendingPhoto?.bytes, bytes);
      expect(restored.state.draft.photos, validDraft.photos);
      fail = false;
      await restored.retryPhoto();
      expect(restored.state.draft.pendingPhoto, isNull);
      expect(restored.state.draft.photos.length, validDraft.photos.length + 1);
    },
  );
  test(
    'an upload finishing after reassignment cannot restore POD from the old trip',
    () async {
      final trips = DraftTrips('InTransit');
      addTearDown(trips.events.close);
      final drafts = MemoryDrafts();
      final c = DeliveryCubit(trips, trips, DraftPhotos(), drafts: drafts);
      await Future<void>.delayed(Duration.zero);
      final uploaded = Completer<UploadedEvidence>();
      trips.uploadGate = uploaded;
      final picking = c.pick(CargoPhotoSource.camera);
      await Future<void>.delayed(Duration.zero);
      final next = tripDetail(DateTime.now(), stage: 'InTransit')..['id'] = 99;
      trips.trip = DriverTripDto.parse(next);
      trips.events.add(trips.current);
      await Future<void>.delayed(Duration.zero);
      uploaded.complete(
        const UploadedEvidence(
          CargoPhotoKind.overall,
          'https://images.test/old.png',
        ),
      );
      await picking;
      expect(c.state.photo, isNull);
      expect(c.state.uploaded, isNull);
      await c.close();
      expect(await drafts.read('delivery_42'), isNull);
    },
  );
  test(
    'tracking recovers automatically after the initial request fails and refreshes ETA periodically',
    () {
      fakeAsync((async) {
        var calls = 0;
        final t = CustomerTestApi(
          handler: (r) async {
            if (r.url.path.endsWith('/tracking') && ++calls == 1) {
              return jsonResponse({'code': 'SERVER_ERROR'}, 500);
            }
            return null;
          },
        );
        CustomerOrderCubit? cubit;
        t.login().then((_) {
          cubit = CustomerOrderCubit(
            t.repository,
            1,
            TestCustomerRealtime(),
            clock: async.getClock(DateTime(2026)).now,
          );
          cubit!.initialize();
        });
        async.flushMicrotasks();
        expect(cubit!.state.tracking, isNull);
        expect(cubit!.state.trackingError, isNotNull);
        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();
        expect(cubit!.state.tracking?.minutes, 10);
        expect(cubit!.state.trackingError, isNull);
        async.elapse(const Duration(seconds: 11));
        async.flushMicrotasks();
        expect(calls, 3);
        cubit!.close();
        t.close();
        async.flushMicrotasks();
      });
    },
  );

  testWidgets(
    'visible lists refresh periodically and on resume, and stop in background',
    (tester) async {
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveRefresh(
              onRefresh: () async {
                refreshes++;
              },
              child: ListView(children: const [Text('Orders')]),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 15));
      expect(refreshes, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(refreshes, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(refreshes, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'arrival and incident push payloads open the corresponding role screens',
    () {
      expect(
        const DriverNotification(
          data: {'type': 'DRIVER_ARRIVED_DROPOFF', 'orderId': '42'},
        ).customerRoute,
        '/order',
      );
      expect(
        const DriverNotification(
          data: {'type': 'INCIDENT_REPORTED', 'orderId': '42'},
        ).customerRoute,
        '/incidents',
      );
      final incident = const DriverNotification(
        data: {'type': 'INCIDENT_IN_PROGRESS', 'incidentId': '7'},
      );
      expect(incident.route, '/incident-detail');
      expect(incident.argument, '7');
    },
  );

  test(
    'an unknown booking survives a new cubit and retries exactly the same request key',
    () async {
      final store = MemoryDrafts();
      final keys = <String>[];
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.contains('/by-request/')) {
            return jsonResponse({'code': 'NOT_FOUND'}, 404);
          }
          if (r.url.path.endsWith('/FareEstimate')) {
            return jsonResponse(quote());
          }
          if (r.method == 'POST' && r.url.path.endsWith('/orders')) {
            final body = jsonDecode(r.body) as Map;
            keys.add(body['requestKey'] as String);
            if (keys.length == 1) {
              return jsonResponse({'code': 'SERVER_ERROR'}, 500);
            }
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final first = BookingCubit(t.repository, drafts: store);
      await first.initialize();
      first.edit(validDraft);
      await first.estimate();
      await first.submit();
      expect(first.state.needsOrderCheck, true);
      first.confirmedNoOrderCreated();
      expect(
        first.state.needsOrderCheck,
        true,
      ); // A supported request cannot bypass its key.
      await first.close();
      final restored = BookingCubit(t.repository, drafts: store);
      addTearDown(restored.close);
      await restored.initialize();
      expect(restored.state.needsOrderCheck, true);
      expect(restored.state.draft.receiver, validDraft.receiver);
      await restored.retryPending();
      expect(restored.state.created?.id, 99);
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
      expect(await store.read('booking'), isNull);
    },
  );

  test(
    'selected coordinates are sent and a server that ignores them cannot quote a different pickup',
    () async {
      var acknowledgesPins = false;
      final t = CustomerTestApi(
        handler: (r) async {
          if (!r.url.path.endsWith('/FareEstimate')) return null;
          final body = jsonDecode(r.body) as Map;
          expect(body['pickupPoint'], {
            'latitude': 10.777123,
            'longitude': 106.701234,
          });
          return jsonResponse({
            ...quote(),
            if (acknowledgesPins) 'pickupPoint': body['pickupPoint'],
          });
        },
      );
      addTearDown(t.close);
      final draft = validDraft.copyWith(
        pickupPoint: const customer.GeoPosition(10.777123, 106.701234),
      );
      await expectLater(
        t.repository.estimate(draft),
        throwsA(isA<customer.CustomerFailure>()),
      );
      acknowledgesPins = true;
      expect((await t.repository.estimate(draft)).total, 90000);
      expect(draft.copyWith(pickup: 'A different street').pickupPoint, isNull);
    },
  );

  test('regular booking drafts restore without trusting an old fare', () async {
    final t = CustomerTestApi();
    addTearDown(t.close);
    final drafts = MemoryDrafts();
    final first = BookingCubit(t.repository, drafts: drafts);
    await first.initialize();
    first.edit(validDraft);
    await first.estimate();
    await first.close();
    final restored = BookingCubit(t.repository, drafts: drafts);
    addTearDown(restored.close);
    await restored.initialize();
    expect(restored.state.draft.photos, validDraft.photos);
    expect(restored.state.fare, isNull);
  });

  test(
    'a stored request resolves to the existing order without another POST',
    () async {
      var found = false, posts = 0;
      final drafts = MemoryDrafts();
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.endsWith('/FareEstimate')) {
            return jsonResponse(quote());
          }
          if (r.url.path.contains('/by-request/')) {
            return found
                ? jsonResponse({
                    'orderId': 77,
                    'orderCode': 'MM77',
                    'totalFee': 90000,
                  })
                : jsonResponse({'code': 'NOT_FOUND'}, 404);
          }
          if (r.method == 'POST' && r.url.path.endsWith('/orders')) {
            posts++;
            found = true; // Committed, but the response was lost.
            return jsonResponse({'code': 'SERVER_ERROR'}, 500);
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository, drafts: drafts);
      addTearDown(c.close);
      await c.initialize();
      c.edit(validDraft);
      await c.estimate();
      await c.submit();
      expect(c.state.needsOrderCheck, true);
      await c.retryPending();
      expect(c.state.created?.id, 77);
      expect(posts, 1);
    },
  );

  test(
    'an unknown request can reprice after FARE_CHANGED while preserving its original key',
    () async {
      final keys = <String>[];
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.endsWith('/FareEstimate')) {
            return jsonResponse(quote());
          }
          if (r.url.path.contains('/by-request/')) {
            return jsonResponse({'code': 'NOT_FOUND'}, 404);
          }
          if (r.method == 'POST' && r.url.path.endsWith('/orders')) {
            keys.add((jsonDecode(r.body) as Map)['requestKey'] as String);
            if (keys.length == 1) {
              return jsonResponse({'code': 'SERVER_ERROR'}, 500);
            }
            if (keys.length == 2) {
              return jsonResponse({'code': 'FARE_CHANGED'}, 422);
            }
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository);
      addTearDown(c.close);
      await c.initialize();
      c.edit(validDraft);
      await c.estimate();
      await c.submit();
      await c.retryPending();
      expect(c.state.fare, isNull);
      expect(c.state.needsOrderCheck, false);
      await c.estimate();
      await c.submit();
      expect(c.state.created?.id, 99);
      expect(keys.toSet(), hasLength(1));
    },
  );

  test(
    'private file drafts survive new store instances and never cross accounts or API hosts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'modmove-drafts-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final a = FileDraftStore('https://a.test', '1', directory: directory);
      await a.write('booking', {'draft': 'first'});
      await a.write('booking', {'draft': 'latest', 'pending': true});
      expect(
        (await FileDraftStore(
          'https://a.test',
          '1',
          directory: directory,
        ).read('booking'))!['draft'],
        'latest',
      );
      expect(
        await FileDraftStore(
          'https://a.test',
          '2',
          directory: directory,
        ).read('booking'),
        isNull,
      );
      expect(
        await FileDraftStore(
          'https://b.test',
          '1',
          directory: directory,
        ).read('booking'),
        isNull,
      );
      await a.remove('booking');
      expect(await a.read('booking'), isNull);
    },
  );

  test(
    'pickup photos restore only for the same trip and submission attempt',
    () async {
      final trips = DraftTrips('Arrived');
      addTearDown(trips.events.close);
      final drafts = MemoryDrafts(), photos = DraftPhotos();
      final first = EvidenceCubit(
        DriverTripActions(trips),
        photos,
        drafts: drafts,
      );
      await Future<void>.delayed(Duration.zero);
      await first.pick(CargoPhotoKind.overall, CargoPhotoSource.camera);
      first.check(0, true);
      await first.close();
      final restored = EvidenceCubit(
        DriverTripActions(trips),
        photos,
        drafts: drafts,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        restored.state.items[CargoPhotoKind.overall]!.uploaded!.reference,
        'https://images.test/overall.png',
      );
      expect(restored.state.checklist.first, true);
      trips.trip = trips.trip.copyWith(
        stage: TripStage.pickedUp,
        attempts: 1,
        review: EvidenceReview.rejected,
      );
      trips.events.add(trips.current);
      await Future<void>.delayed(Duration.zero);
      expect(
        restored.state.items.values.every(
          (i) => i.needsRetake && i.uploaded == null,
        ),
        true,
      );
      await restored.close();
      final rejected = EvidenceCubit(
        DriverTripActions(trips),
        photos,
        drafts: drafts,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        rejected.state.items.values.every(
          (i) => i.needsRetake && i.uploaded == null,
        ),
        true,
      );
      await rejected.close();
    },
  );

  test(
    'delivery photo and cash confirmation restore, then clear when the trip ends',
    () async {
      final trips = DraftTrips('InTransit');
      addTearDown(trips.events.close);
      final drafts = MemoryDrafts(), photos = DraftPhotos();
      final first = DeliveryCubit(trips, trips, photos, drafts: drafts);
      await Future<void>.delayed(Duration.zero);
      await first.pick(CargoPhotoSource.camera);
      first.confirmCash(true);
      await first.close();
      final restored = DeliveryCubit(trips, trips, photos, drafts: drafts);
      await Future<void>.delayed(Duration.zero);
      expect(restored.state.uploaded, isNotNull);
      expect(restored.state.cash, true);
      trips.trip = trips.trip.copyWith(stage: TripStage.delivered);
      trips.events.add(trips.current);
      await Future<void>.delayed(Duration.zero);
      expect(restored.state.photo, isNull);
      await restored.close();
      expect(await drafts.read('delivery_42'), isNull);
    },
  );

  test('only this driver unresolved incidents hold the trip', () {
    final raw = tripDetail(DateTime.now(), stage: 'InTransit');
    raw['incidents'] = [
      {
        'id': 1,
        'description': 'Incident',
        'resolutionStatus': 'Open',
        'reportedByYou': false,
      },
    ];
    expect(DriverTripDto.parse(raw).onHold, false);
    (raw['incidents'] as List).first['reportedByYou'] = true;
    expect(DriverTripDto.parse(raw).onHold, true);
    (raw['incidents'] as List).first['resolutionStatus'] = 'Resolved';
    expect(DriverTripDto.parse(raw).onHold, false);
  });

  test(
    'GPS keeps recent ETA but expires it after a minute without a new route response',
    () {
      final now = DateTime.now();
      final snapshot = customer.TrackingSnapshot(
        const customer.GeoPosition(10, 106),
        const customer.GeoPosition(11, 107),
        const customer.GeoPosition(10, 106),
        now,
        false,
        12,
        'Dropoff',
        etaAt: now,
      );
      final moved = snapshot.withLocation(
        const customer.GeoPosition(10.1, 106.1),
        now.add(const Duration(seconds: 5)),
      );
      expect(moved.minutes, 12);
      expect(
        moved
            .withLocation(
              const customer.GeoPosition(10.2, 106.2),
              now.add(const Duration(seconds: 61)),
            )
            .minutes,
        isNull,
      );
    },
  );

  test(
    'driver password errors retain the session and successful changes complete once',
    () async {
      final repo = SecurityFake(), cubit = AccountSecurityCubit(SecurityFake());
      await cubit.changePassword('oldPass123', 'weak', 'weak');
      expect(cubit.state.error, isNotNull);
      await cubit.close();
      final c = AccountSecurityCubit(repo);
      addTearDown(c.close);
      repo.fail = true;
      await c.changePassword('oldPass123', 'newPass123', 'newPass123');
      expect(c.state.error, contains('Mật khẩu'));
      expect(c.state.completed, isNull);
      repo.fail = false;
      await c.changePassword('oldPass123', 'newPass123', 'newPass123');
      expect(c.state.completed, isNotNull);
      await c.changePassword('oldPass123', 'newPass123', 'newPass123');
      expect(repo.calls, 2);
    },
  );
}

class DraftTrips implements DriverTripRepository, DriverDeliveryRepository {
  Completer<UploadedEvidence>? uploadGate;
  DraftTrips(String stage)
    : trip = DriverTripDto.parse(tripDetail(DateTime.now(), stage: stage));
  ActiveTrip trip;
  final events = StreamController<DriverSession>.broadcast();
  @override
  DriverSession get current => DriverSession(trip: trip);
  @override
  Stream<DriverSession> get changes => events.stream;
  @override
  Future<UploadedEvidence> upload(
    CargoPhoto photo,
    void Function(double) progress,
  ) async => uploadGate != null
      ? await uploadGate!.future
      : UploadedEvidence(
          photo.kind,
          'https://images.test/${photo.kind.name}.png',
        );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DraftPhotos implements CargoPhotoRepository {
  @override
  Future<CargoPhoto?> pick(
    CargoPhotoKind kind,
    CargoPhotoSource source,
  ) async => CargoPhoto(
    kind: kind,
    name: '${kind.name}.png',
    bytes: Uint8List.fromList([1, 2, 3, kind.index]),
  );
}

class SecurityFake implements AccountSecurityRepository {
  bool fail = false;
  int calls = 0;
  @override
  Future<void> changePassword(String current, String next) async {
    calls++;
    if (fail) {
      throw const AccountSecurityFailure('Mật khẩu hiện tại chưa đúng.');
    }
  }

  @override
  Future<void> deleteAccount() async {}
}
