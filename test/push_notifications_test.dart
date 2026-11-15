import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/auth/data/auth_api.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:modmove_mobile/features/notifications/data/remote_push_token_repository.dart';
import 'package:modmove_mobile/features/notifications/domain/push_message.dart';
import 'package:modmove_mobile/features/notifications/domain/push_repository.dart';
import 'package:modmove_mobile/features/notifications/presentation/push_cubit.dart';

class Device implements PushDevice {
  bool configured = true;
  PushPermission allowed = PushPermission.allowed;
  String value = 'device-one';
  int shown = 0, cleared = 0, requests = 0;
  Completer<void>? clearGate;
  PushMessage? initial;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final taps = StreamController<PushMessage>.broadcast();
  @override
  Stream<String> get tokenChanges => refresh.stream;
  @override
  Stream<PushMessage> get messages => foreground.stream;
  @override
  Stream<PushMessage> get opened => taps.stream;
  @override
  Future<bool> initialize() async => configured;
  @override
  Future<PushMessage?> initialMessage() async => initial;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) requests++;
    return allowed;
  }

  @override
  Future<String?> token() async => value;
  @override
  Future<void> show(PushMessage message) async {
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

const decided = PushMessage(id: 'message-1', data: {'type': 'INCIDENT_DECIDED', 'incidentId': '6', 'orderId': '12'});

void main() {
  test('ID thông báo chỉ nhận số nguyên dương, loại lạ không điều hướng', () {
    expect(decided.orderId, '12');
    expect(decided.incidentId, '6');
    expect(decided.actionable, isTrue);
    for (final value in ['../wallet', '-1', '0', '1?x=2']) {
      expect(PushMessage(data: {'type': 'ORDER_ACCEPTED', 'orderId': value}).orderId, isNull);
    }
    expect(const PushMessage(data: {}).actionable, isFalse);
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

  test('thiếu cấu hình Firebase thì app vẫn dùng được, không đăng ký token', () async {
    device.configured = false;
    await push.initialize();
    await push.attach('8');
    expect(push.state.permission, PushPermission.unavailable);
    expect(registration.tokens, isEmpty);
  });

  test('từ chối quyền thì không lấy token; bật lại rồi mở lại app mới đăng ký', () async {
    device.allowed = PushPermission.denied;
    await push.initialize();
    await push.attach('8');
    expect(push.state.permission, PushPermission.denied);
    expect(registration.tokens, isEmpty);
    device.allowed = PushPermission.allowed;
    await push.synchronize();
    expect(push.state.registered, isTrue);
    expect(registration.tokens, ['device-one']);
  });

  test('đăng ký lỗi thì thử lại và token đổi sẽ được gửi lại', () async {
    registration.fail = true;
    await push.initialize();
    await push.attach('8');
    expect(push.state.error, isNotNull);
    registration.fail = false;
    await push.synchronize();
    device.value = 'rotated';
    device.refresh.add('rotated');
    await flush();
    expect(registration.tokens, ['device-one', 'device-one', 'rotated']);
    expect(push.state.registered, isTrue);
  });

  test('đăng xuất chờ yêu cầu đăng ký đang chạy xong rồi mới trả token và xoá thông báo', () async {
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
  });

  test('chạm thông báo khi mở lạnh được giữ lại; đăng xuất thì xoá và bỏ qua lần chạm muộn', () async {
    device.initial = decided;
    await push.initialize();
    await push.attach('8');
    expect(push.state.pending?.incidentId, '6');
    await push.detach();
    device.taps.add(decided);
    await flush();
    expect(push.state.pending, isNull);
    await push.attach('9');
    expect(push.state.pending, isNull);
  });

  test('thông báo khi đang mở app chỉ hiện một lần; chạm điều hướng một lần; đăng xuất rồi không hiện nữa', () async {
    await push.initialize();
    await push.attach('8');
    device.foreground.add(decided);
    device.foreground.add(decided);
    await flush();
    expect(device.shown, 1);
    device.taps.add(decided);
    await flush();
    expect(push.state.pending?.type, 'INCIDENT_DECIDED');
    push.consume();
    device.taps.add(decided);
    await flush();
    expect(push.state.pending, isNull);
    await push.detach();
    device.foreground.add(const PushMessage(id: 'late', data: {'type': 'ORDER_ACCEPTED'}));
    await flush();
    expect(device.shown, 1);
  });

  test('app đang mở và đã tự hiện banner thì không tạo thêm thông báo hệ thống (tránh trùng với SignalR)', () async {
    final handled = <String>[];
    final own = PushCubit(
      device,
      registration,
      onForeground: (message) {
        handled.add(message.type);
        return message.type != 'UNKNOWN_TYPE';
      },
    );
    addTearDown(own.close);
    await own.initialize();
    await own.attach('8');
    device.foreground.add(decided);
    await flush();
    expect(handled, ['INCIDENT_DECIDED']);
    expect(device.shown, 0);
    // App không tự hiện được (trả false) thì vẫn rơi về thông báo hệ thống, không mất thông báo.
    device.foreground.add(const PushMessage(id: 'x', data: {'type': 'UNKNOWN_TYPE'}));
    await flush();
    expect(device.shown, 1);
  });

  test('phiên hết hạn huỷ lần gắn đang chờ dọn máy', () async {
    await push.initialize();
    device.clearGate = Completer<void>();
    final firstDetach = push.detach();
    final staleAttach = push.attach('8');
    final expiration = push.detach();
    device.clearGate!.complete();
    await Future.wait([firstDetach, staleAttach, expiration]);
    expect(registration.tokens, isEmpty);
    expect(push.state.registered, isFalse);
  });

  test('đổi tài khoản thì xoá đăng ký cũ rồi đăng ký lại', () async {
    await push.initialize();
    await push.attach('8');
    device.value = 'account-two';
    await push.attach('9');
    expect(device.cleared, 1);
    expect(registration.tokens, ['device-one', 'account-two']);
    expect(push.state.registered, isTrue);
  });

  test('đăng ký dùng PUT api/account/FcmToken và đăng xuất gửi kèm fcmToken của máy này', () async {
    final requests = <String>[];
    final bodies = <String, Object?>{};
    final sessions = MemorySessionStore(const Session(accessToken: 'a', refreshToken: 'r', userId: 8, fullName: 'K', role: 'Customer'));
    final api = ApiClient(
      sessions: sessions,
      baseUrl: 'http://test/api',
      client: MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        requests.add(key);
        if (request.body.isNotEmpty) bodies[key] = jsonDecode(request.body);
        return http.Response('', 204);
      }),
    );
    final real = PushCubit(device, RemotePushTokenRepository(api));
    addTearDown(real.close);
    await real.initialize();
    await real.attach('8');
    expect(requests, ['PUT /api/account/FcmToken']);
    expect(bodies['PUT /api/account/FcmToken'], {'token': 'device-one'});

    final auth = AuthCubit(api: AuthApi(api), sessions: sessions, detachPush: real.detach);
    addTearDown(auth.close);
    await auth.logout();
    expect(requests.last, 'POST /api/account/Logout');
    expect(bodies['POST /api/account/Logout'], {'fcmToken': 'device-one'});
    expect(sessions.current, isNull);
    expect(device.cleared, 1);
  });
}
