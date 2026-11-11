import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/notifications/notification_cubit.dart';
import 'package:modmove_mobile/core/notifications/realtime_source.dart';
import 'package:modmove_mobile/core/session/session_store.dart';

class FakeRealtimeSource implements RealtimeSource {
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  final tokens = <String?>[];
  bool started = false;
  int stops = 0;

  void emit(Map<String, Object?> payload) => _controller.add(payload);

  @override
  Stream<Map<String, Object?>> get notifications => _controller.stream;

  Future<String?> Function()? _token;

  /// Giả lập SignalR kết nối lại: gọi token() lần nữa như `accessTokenFactory`.
  Future<void> reconnect() async => tokens.add(await _token!());

  @override
  Future<void> start(Future<String?> Function() token) async {
    started = true;
    _token = token;
    tokens.add(await token());
  }

  @override
  Future<void> stop() async {
    started = false;
    stops++;
  }
}

Session _session(String token) => Session(accessToken: token, refreshToken: 'r', userId: 3, fullName: 'K', role: 'Customer');

void main() {
  late FakeRealtimeSource fake;
  late NotificationCubit cubit;
  late MemorySessionStore sessions;
  late RealtimeBridge bridge;
  setUp(() {
    fake = FakeRealtimeSource();
    cubit = NotificationCubit();
    sessions = MemorySessionStore(_session('t1'));
    bridge = RealtimeBridge(fake, cubit, sessions);
  });
  tearDown(() => cubit.close());

  test('hubUrl bỏ hậu tố /api và thêm /hubs/tracking', () {
    expect(hubUrl('http://10.0.2.2:5133/api'), 'http://10.0.2.2:5133/hubs/tracking');
    expect(hubUrl('https://api.modmove.vn/api/'), 'https://api.modmove.vn/hubs/tracking');
  });

  test('payload của server thành thông báo với chữ của server', () async {
    await bridge.start();
    fake.emit({'type': 'REFUND_INFO_REQUESTED', 'title': 'Cần bổ sung', 'body': 'Gửi thêm ảnh', 'data': {'orderId': 9}});
    await pumpEventQueue();
    expect(cubit.state.showing!.body, 'Gửi thêm ảnh');
    expect(cubit.state.showing!.title, 'Cần bổ sung');
    expect(cubit.state.showing!.orderId, 9);
    expect(cubit.state.inbox, hasLength(1));
  });

  test('mã lạ vẫn hiện chữ của server, mức info, không sập', () async {
    await bridge.start();
    fake.emit({'type': 'SOMETHING_NEW', 'title': 'T', 'body': 'B'});
    await pumpEventQueue();
    expect(cubit.state.showing!.body, 'B');
    expect(cubit.state.showing!.kind.name, 'info');
  });

  test('payload sai dạng bị bỏ qua', () async {
    await bridge.start();
    fake.emit({'title': 1});
    fake.emit({'type': 5});
    fake.emit({'type': ''});
    await pumpEventQueue();
    expect(cubit.state.showing, isNull);
  });

  test('token được đọc lại ở mỗi lần kết nối (đổi token giữa hai lần)', () async {
    await bridge.start();
    expect(fake.tokens, ['t1']);
    await sessions.save(_session('t2'));
    await fake.reconnect();
    expect(fake.tokens, ['t1', 't2']);
  });

  test('stop ngắt nguồn, xoá hộp thư và bỏ qua sự kiện đến muộn', () async {
    await bridge.start();
    fake.emit({'type': 'ORDER_ACCEPTED', 'body': 'x', 'data': {'orderId': '1'}});
    await pumpEventQueue();
    expect(cubit.state.inbox, hasLength(1));
    await bridge.stop();
    expect(fake.started, isFalse);
    expect(cubit.state.inbox, isEmpty);
    expect(cubit.state.showing, isNull);
    fake.emit({'type': 'ORDER_ACCEPTED', 'body': 'muộn', 'data': {'orderId': '2'}});
    await pumpEventQueue();
    expect(cubit.state.showing, isNull);
  });

  test('đăng nhập tài khoản khác không thấy thông báo cũ', () async {
    await bridge.start();
    fake.emit({'type': 'ORDER_ACCEPTED', 'body': 'của tài khoản A', 'data': {'orderId': '1'}});
    await pumpEventQueue();
    await bridge.stop();
    await sessions.save(_session('tB'));
    await bridge.start();
    expect(cubit.state.inbox, isEmpty);
    expect(fake.tokens.last, 'tB');
  });

  test('gọi start hai lần chỉ nối một lần', () async {
    await bridge.start();
    await bridge.start();
    expect(fake.tokens, hasLength(1));
  });
}
