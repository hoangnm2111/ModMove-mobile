import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/customer/domain/customer_models.dart';
import 'package:modmove_mobile/features/customer/domain/customer_repository.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_cubits.dart';
import 'support/customer_fixtures.dart';
import 'support/remote_fixtures.dart';

void main() {
  test(
    'rebooking retired cargo asks for a new type and keeps the other inputs',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      final c = BookingCubit(
        t.repository,
        initial: validDraft.copyWith(cargoType: 'RETIRED'),
      );
      addTearDown(c.close);
      await c.initialize();
      expect(c.state.draft.cargoType, isEmpty);
      expect(c.state.draft.photos, validDraft.photos);
      expect(c.state.draft.pickup, validDraft.pickup);
      expect(c.state.fare, isNull);
    },
  );
  test(
    'changing cargo beyond the selected vehicle prevents requesting an invalid quote',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      final c = BookingCubit(t.repository);
      addTearDown(c.close);
      await c.initialize();
      c.edit(validDraft.copyWith(weight: 600));
      await c.estimate();
      expect(c.state.error, contains('Chọn lại loại xe'));
      expect(
        t.requests.where((r) => r.url.path.endsWith('/FareEstimate')),
        isEmpty,
      );
    },
  );
  test(
    'leaving during SignalR connection does not restart polling after disposal',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      final periodic = <Timer>[];
      await runZoned(
        () async {
          final realtime = _PendingRealtime();
          final c = CustomerOrderCubit(t.repository, 1, realtime);
          final initializing = c.initialize();
          await realtime.entered.future;
          expect(c.state.order, isNotNull);
          final closing = c.close();
          await realtime.stopping.future;
          realtime.started.complete();
          await Future<void>.delayed(Duration.zero);
          realtime.stopped.complete();
          await Future.wait([initializing, closing]);
          expect(c.isClosed, true);
        },
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createPeriodicTimer(zone, duration, callback);
            periodic.add(timer);
            return timer;
          },
        ),
      );
      for (final timer in periodic) {
        timer.cancel();
      }
      expect(periodic, isEmpty);
    },
  );
  test(
    'unknown create result blocks retry until the user checks the order list',
    () async {
      final t = CustomerTestApi(
        handler: (r) async =>
            r.method == 'POST' && r.url.path.endsWith('/orders')
            ? jsonResponse({'code': 'SERVER_ERROR'}, 500)
            : null,
      );
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository);
      addTearDown(c.close);
      await c.initialize();
      c.edit(validDraft);
      await c.estimate();
      await c.submit();
      expect(c.state.needsOrderCheck, true);
      await c.submit();
      c.edit(validDraft.copyWith(receiver: 'Changed'));
      expect(c.state.draft.receiver, validDraft.receiver);
      expect(
        t.requests
            .where((r) => r.method == 'POST' && r.url.path.endsWith('/orders'))
            .length,
        1,
      );
      c.confirmedNoOrderCreated();
      expect(c.state.needsOrderCheck, false);
    },
  );
  test(
    'refresh drops a QR superseded by the latest server payment link',
    () async {
      var link = 'https://pay.payos.vn/old';
      final expires = DateTime.now()
          .add(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String();
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.endsWith('/payment')) {
            return jsonResponse({
              'checkoutUrl': link,
              'qrCode': 'old-qr',
              'amount': 90000,
              'expiresAt': expires,
            });
          }
          if (r.url.path.endsWith('/orders/1')) {
            final order = customerOrder(status: 'Pending', payment: 'Unpaid');
            order['payment'] = {
              'transactionStatus': 'Pending',
              'checkoutUrl': link,
              'expiresAt': expires,
              'paidAt': null,
              'isExpired': false,
            };
            return jsonResponse(order);
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final c = CustomerOrderCubit(t.repository, 1, TestCustomerRealtime());
      addTearDown(c.close);
      await c.initialize();
      await c.createPayment();
      expect(c.state.payment!.qr, 'old-qr');
      link = 'https://pay.payos.vn/new';
      await c.refresh();
      expect(c.state.payment, isNull);
      expect(c.state.order!.checkoutUrl, link);
    },
  );
  test(
    'quote is invalidated by route, cargo, vehicle, loading or coupon, not by payer',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository);
      addTearDown(c.close);
      await c.initialize();
      c.edit(validDraft);
      await c.estimate();
      expect(c.state.fare!.total, 90000);
      c.edit(c.state.draft.copyWith(payment: 'Cash', payer: 'Receiver'));
      expect(c.state.fare, isNotNull);
      for (final change in [
        (BookingDraft d) => d.copyWith(pickup: 'New pickup'),
        (BookingDraft d) => d.copyWith(weight: 6),
        (BookingDraft d) => d.copyWith(vehicleId: 2),
        (BookingDraft d) => d.copyWith(loading: true),
        (BookingDraft d) => d.copyWith(coupon: 'NEW'),
      ]) {
        c.edit(validDraft);
        await c.estimate();
        expect(c.state.fare, isNotNull);
        c.edit(change(c.state.draft));
        expect(c.state.fare, isNull);
      }
    },
  );
  test(
    'FARE_CHANGED preserves all data and forces a fresh quote before retry',
    () async {
      final t = CustomerTestApi(
        handler: (r) async =>
            r.method == 'POST' && r.url.path.endsWith('/orders')
            ? jsonResponse({'code': 'FARE_CHANGED'}, 422)
            : null,
      );
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository);
      addTearDown(c.close);
      await c.initialize();
      c.edit(validDraft);
      await c.estimate();
      await c.submit();
      expect(c.state.error, contains('Giá cước'));
      expect(c.state.fare, isNull);
      expect(c.state.draft.photos, validDraft.photos);
      expect(c.state.draft.receiver, validDraft.receiver);
      await c.submit();
      expect(
        t.requests
            .where((r) => r.method == 'POST' && r.url.path.endsWith('/orders'))
            .length,
        1,
      );
    },
  );
  test(
    'submit and uploads are serialized; double taps cannot create two orders',
    () async {
      final done = Completer<void>();
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.method == 'POST' && r.url.path.endsWith('/orders')) {
            await done.future;
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
      final sending = c.submit();
      await c.submit();
      c.edit(validDraft.copyWith(receiver: 'Should not change'));
      await c.upload('cargo.png', Uint8List(1));
      expect(c.state.busy, true);
      expect(c.state.draft.receiver, validDraft.receiver);
      done.complete();
      await sending;
      expect(c.state.created!.id, 99);
      await c.submit();
      expect(
        t.requests
            .where((r) => r.method == 'POST' && r.url.path.endsWith('/orders'))
            .length,
        1,
      );
      expect(t.requests.any((r) => r.url.path.endsWith('/Uploads')), false);
    },
  );
  test(
    'network quote failure never replaces API data with a mock fare',
    () async {
      final t = CustomerTestApi(
        handler: (r) async => r.url.path.endsWith('/FareEstimate')
            ? jsonResponse({'code': 'SERVER_ERROR'}, 500)
            : null,
      );
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository);
      addTearDown(c.close);
      await c.initialize();
      c.edit(validDraft);
      await c.estimate();
      expect(c.state.fare, isNull);
      expect(c.state.error, isNotNull);
      expect(c.state.draft.photos, validDraft.photos);
    },
  );
  test('stale list response cannot overwrite a newer search', () async {
    final old = Completer<PageResult<int>>();
    var calls = 0;
    final c = PagedCubit<int>(
      (p) => ++calls == 1
          ? old.future
          : Future.value(const PageResult([2], 1, 1, false)),
    );
    addTearDown(c.close);
    final first = c.load();
    await c.load();
    old.complete(const PageResult([1], 1, 1, false));
    await first;
    expect(c.state.items, [2]);
  });
  test('failed supplemental upload retains already uploaded photos', () async {
    var uploads = 0;
    final t = CustomerTestApi(
      handler: (r) async => r.url.path.endsWith('/Uploads') && ++uploads > 1
          ? jsonResponse({}, 500)
          : null,
    );
    addTearDown(t.close);
    await t.login();
    final c = CustomerEvidenceCubit(t.repository);
    addTearDown(c.close);
    await c.add('cargo.png', Uint8List(4));
    expect(c.state.photos.length, 1);
    await c.add('cargo.png', Uint8List(4));
    expect(c.state.photos.length, 1);
    expect(c.state.error, isNotNull);
  });
  test(
    'live location rejects older events and avoids routing HTTP call per GPS update',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      final realtime = TestCustomerRealtime();
      final c = CustomerOrderCubit(t.repository, 1, realtime);
      addTearDown(c.close);
      await c.initialize();
      await c.loadTracking();
      final fresh = DateTime.now().add(const Duration(seconds: 10));
      realtime.controller.add(
        CustomerRealtimeEvent(position: const GeoPosition(11, 107), at: fresh),
      );
      await Future<void>.delayed(Duration.zero);
      realtime.controller.add(
        CustomerRealtimeEvent(
          position: const GeoPosition(9, 105),
          at: fresh.subtract(const Duration(seconds: 1)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.state.tracking!.driver!.latitude, 11);
      expect(c.state.tracking!.minutes, isNull);
      expect(
        t.requests.where((r) => r.url.path.endsWith('/tracking')).length,
        1,
      );
    },
  );
  test(
    'server removal of driver GPS clears the previously displayed location',
    () async {
      var removed = false;
      final t = CustomerTestApi(
        handler: (r) async {
          if (removed && r.url.path.endsWith('/tracking')) {
            return jsonResponse({
              'pickup': {'latitude': 10.7, 'longitude': 106.7},
              'dropoff': {'latitude': 10.8, 'longitude': 106.8},
              'driver': null,
              'eta': null,
            });
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final c = CustomerOrderCubit(t.repository, 1, TestCustomerRealtime());
      addTearDown(c.close);
      await c.initialize();
      await c.loadTracking();
      expect(c.state.tracking!.driver, isNotNull);
      removed = true;
      await c.loadTracking();
      expect(c.state.tracking!.driver, isNull);
      expect(c.state.tracking!.minutes, isNull);
    },
  );
  test(
    'reassigned driver discards an in-flight GPS response for the old driver',
    () async {
      var changed = false, trackingCalls = 0;
      final pending = Completer<void>(), entered = Completer<void>();
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.endsWith('/orders/1')) {
            final raw = customerOrder();
            if (changed) (raw['driver'] as Map)['phoneNumber'] = '0901111111';
            return jsonResponse(raw);
          }
          if (r.url.path.endsWith('/tracking')) {
            final call = ++trackingCalls;
            if (call == 2) {
              entered.complete();
              await pending.future;
            }
            return jsonResponse({
              'pickup': {'latitude': 10.7, 'longitude': 106.7},
              'dropoff': {'latitude': 10.8, 'longitude': 106.8},
              'driver': call <= 2
                  ? {
                      'latitude': 10.75,
                      'longitude': 106.75,
                      'at': DateTime.now().toUtc().toIso8601String(),
                      'isStale': false,
                    }
                  : null,
              'eta': null,
            });
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final c = CustomerOrderCubit(t.repository, 1, TestCustomerRealtime());
      addTearDown(c.close);
      await c.initialize();
      await c.loadTracking();
      final old = c.loadTracking();
      await entered.future;
      changed = true;
      await c.refresh();
      expect(c.state.tracking, isNull);
      final next = c.stream.firstWhere((s) => s.tracking != null);
      pending.complete();
      await old;
      final updated = await next.timeout(const Duration(seconds: 2));
      expect(updated.tracking!.driver, isNull);
      expect(trackingCalls, 3);
    },
  );
  test(
    'an action queued during refresh runs once and then reloads authoritative state',
    () async {
      final refreshing = Completer<void>();
      var hold = false;
      final t = CustomerTestApi(
        handler: (r) async {
          if (hold && r.method == 'GET' && r.url.path.endsWith('/orders/1')) {
            await refreshing.future;
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final c = CustomerOrderCubit(t.repository, 1, TestCustomerRealtime());
      addTearDown(c.close);
      await c.initialize();
      hold = true;
      final reload = c.refresh();
      var actions = 0;
      final action = c.act(() async {
        actions++;
      });
      await c.act(() async {
        actions++;
      });
      expect(actions, 0);
      refreshing.complete();
      await reload;
      await action;
      expect(actions, 1);
      expect(c.state.acting, false);
    },
  );
}

class _PendingRealtime implements CustomerRealtime {
  final started = Completer<void>(), stopped = Completer<void>();
  final entered = Completer<void>(), stopping = Completer<void>();
  @override
  Stream<CustomerRealtimeEvent> get events => const Stream.empty();
  @override
  Future<void> start(int id) {
    entered.complete();
    return started.future;
  }

  @override
  Future<void> stop() {
    if (!stopping.isCompleted) stopping.complete();
    return stopped.future;
  }
}
