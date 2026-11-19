import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:modmove_mobile/features/notifications/data/remote_push_token_repository.dart';
import 'package:modmove_mobile/features/notifications/domain/driver_notification.dart';
import 'package:modmove_mobile/features/notifications/domain/push_repository.dart';
import 'package:modmove_mobile/features/notifications/presentation/push_cubit.dart';
import 'support/remote_fixtures.dart';

class Device implements PushDevice {
  bool configured = true;
  PushPermission allowed = PushPermission.allowed;
  String value = 'device-one';
  int shown = 0, cleared = 0, requests = 0;
  Completer<void>? clearGate;
  DriverNotification? initial;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<DriverNotification>.broadcast();
  final taps = StreamController<DriverNotification>.broadcast();
  @override
  Stream<String> get tokenChanges => refresh.stream;
  @override
  Stream<DriverNotification> get messages => foreground.stream;
  @override
  Stream<DriverNotification> get opened => taps.stream;
  @override
  Future<bool> initialize() async => configured;
  @override
  Future<DriverNotification?> initialMessage() async => initial;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) requests++;
    return allowed;
  }

  @override
  Future<String?> token() async => value;
  @override
  Future<void> show(DriverNotification message) async {
    shown++;
  }

  @override
  Future<void> clear() async {
    cleared++;
    await clearGate?.future;
  }

  @override
  Future<void> openSettings() async {}
  @override
  Future<void> close() async {
    await refresh.close();
    await foreground.close();
    await taps.close();
  }
}

class Registration implements PushTokenRepository {
  final tokens = <String>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> register(String token) async {
    tokens.add(token);
    await gate?.future;
    if (fail) throw StateError('offline');
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
const incident = DriverNotification(
  id: 'message-1',
  data: {'type': 'INCIDENT_DECIDED', 'incidentId': '6'},
);

void main() {
  test('notification routes reject untrusted IDs and unknown types', () {
    expect(incident.route, '/incident-detail');
    expect(incident.argument, '6');
    for (final value in ['../wallet', '-1', '0', '1?x=2']) {
      expect(
        DriverNotification(
          data: {'type': 'NEW_MATCHING_ORDER', 'orderId': value},
        ).route,
        isNull,
      );
    }
    expect(
      const DriverNotification(
        data: {'type': 'WITHDRAWAL_DECIDED', 'amount': '999999'},
      ).route,
      '/wallet',
    );
    expect(
      const DriverNotification(
        data: {'type': 'UNKNOWN', 'route': '/wallet'},
      ).route,
      isNull,
    );
  });
  late Device device;
  late Registration registration;
  late PushCubit push;
  setUp(() {
    device = Device();
    registration = Registration();
    push = PushCubit(device, registration);
  });
  tearDown(() async {
    await push.close();
  });

  test(
    'missing Firebase config keeps app usable without registration',
    () async {
      device.configured = false;
      await push.initialize();
      await push.attach('8');
      expect(push.state.permission, PushPermission.unavailable);
      expect(registration.tokens, isEmpty);
    },
  );
  test(
    'permission denial skips token; enabling then resuming registers',
    () async {
      device.allowed = PushPermission.denied;
      await push.initialize();
      await push.attach('8');
      expect(push.state.permission, PushPermission.denied);
      expect(registration.tokens, isEmpty);
      device.allowed = PushPermission.allowed;
      await push.synchronize();
      expect(push.state.registered, isTrue);
      expect(registration.tokens, ['device-one']);
    },
  );
  test('failed registration retries and refresh replaces token', () async {
    registration.fail = true;
    await push.initialize();
    await push.attach('8');
    expect(push.state.error, isNotNull);
    expect(push.state.permission, PushPermission.allowed);
    registration.fail = false;
    await push.synchronize();
    device.value = 'rotated';
    device.refresh.add('rotated');
    await flush();
    expect(registration.tokens, ['device-one', 'device-one', 'rotated']);
    expect(push.state.registered, isTrue);
  });
  test(
    'refresh during registration sends latest token after current request',
    () async {
      registration.gate = Completer<void>();
      await push.initialize();
      final attach = push.attach('8');
      await flush();
      device.value = 'new-token';
      device.refresh.add('new-token');
      await flush();
      registration.gate!.complete();
      await attach;
      await flush();
      expect(registration.tokens, ['device-one', 'new-token']);
    },
  );
  test(
    'logout drains PUT before returning token and clearing notifications',
    () async {
      registration.gate = Completer<void>();
      await push.initialize();
      final attach = push.attach('8');
      await flush();
      final detach = push.detach();
      device.refresh.add('late-token');
      await flush();
      expect(device.cleared, 0);
      registration.gate!.complete();
      await attach;
      expect(await detach, 'device-one');
      expect(device.cleared, 1);
      expect(push.state.registered, isFalse);
      expect(registration.tokens, ['device-one']);
    },
  );
  test(
    'cold tap retained for restored session; logout clears it and ignores late taps',
    () async {
      device.initial = incident;
      await push.initialize();
      await push.attach('8');
      expect(push.state.pending?.argument, '6');
      await push.detach();
      device.taps.add(incident);
      await flush();
      expect(push.state.pending, isNull);
      await push.attach('9');
      expect(push.state.pending, isNull);
    },
  );
  test(
    'foreground messages display once; taps navigate once; no display after logout',
    () async {
      await push.initialize();
      await push.attach('8');
      device.foreground.add(incident);
      device.foreground.add(incident);
      await flush();
      expect(device.shown, 1);
      device.taps.add(incident);
      await flush();
      expect(push.state.pending?.route, '/incident-detail');
      push.consume();
      device.taps.add(incident);
      await flush();
      expect(push.state.pending, isNull);
      await push.detach();
      device.foreground.add(const DriverNotification(id: 'late', data: {}));
      await flush();
      expect(device.shown, 1);
    },
  );
  test(
    'expired session cancels an attach waiting for device cleanup',
    () async {
      await push.initialize();
      device.clearGate = Completer<void>();
      final firstDetach = push.detach();
      final staleAttach = push.attach('8');
      final expiration = push.detach();
      device.clearGate!.complete();
      await Future.wait([firstDetach, staleAttach, expiration]);
      expect(registration.tokens, isEmpty);
      expect(push.state.registered, isFalse);
    },
  );

  test(
    'switching account clears old device registration before registering again',
    () async {
      await push.initialize();
      await push.attach('8');
      device.value = 'account-two';
      await push.attach('9');
      expect(device.cleared, 1);
      expect(registration.tokens, ['device-one', 'account-two']);
      expect(push.state.registered, isTrue);
    },
  );

  test('real registration and logout use backend token contract', () async {
    final requests = <String>[];
    final api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        final body = jsonDecode(request.body) as Map;
        if (request.method == 'PUT') {
          expect(body, {'token': 'device-token'});
        } else {
          expect(body, {'fcmToken': 'device-token'});
        }
        return jsonResponse({}, 204);
      }),
    );
    await api.saveSession(tokens());
    await RemotePushTokenRepository(api).register('device-token');
    await RemoteAuthRepository(
      api,
      detachPush: () async => 'device-token',
    ).logout();
    expect(requests, ['PUT /api/account/FcmToken', 'POST /api/account/logout']);
    expect(api.session, isNull);
    await api.close();
  });
}
