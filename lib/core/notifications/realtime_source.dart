import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../session/session_store.dart';
import 'app_notice.dart';
import 'notice_catalog.dart';
import 'notification_cubit.dart';

/// `http://host:5133/api` (hoặc có `/` cuối) → `http://host:5133/hubs/tracking`.
String hubUrl(String apiBaseUrl) => '${apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '')}/hubs/tracking';

/// Nguồn thông báo thời gian thực của BE. Tách khỏi SignalR để test bằng nguồn giả.
abstract class RealtimeSource {
  /// Mỗi phần tử là payload `{ type, title, body, data }` của `NotificationReceived`.
  Stream<Map<String, Object?>> get notifications;

  /// Mỗi phần tử là payload `{ driverProfileId, orderId?, latitude, longitude, at }` của `LocationUpdated` (B12).
  Stream<Map<String, Object?>> get locations;

  /// Khách theo dõi đơn của mình (`JoinOrder`); kết nối lại thì tự gọi lại. BE không có `LeaveOrder`: rời đơn chỉ
  /// là bỏ khỏi danh sách nhớ (nhóm trên server mất khi ngắt kết nối).
  Future<void> joinOrder(int orderId);
  void leaveOrder(int orderId);

  /// Kết nối. `token` được gọi lại ở MỖI lần (kết nối lại) để luôn dùng access token mới nhất.
  Future<void> start(Future<String?> Function() token);
  Future<void> stop();
}

/// Không làm gì: dùng khi chạy test hoặc không có BE.
class NoRealtimeSource implements RealtimeSource {
  const NoRealtimeSource();
  @override
  Stream<Map<String, Object?>> get notifications => const Stream.empty();
  @override
  Stream<Map<String, Object?>> get locations => const Stream.empty();
  @override
  Future<void> joinOrder(int orderId) async {}
  @override
  void leaveOrder(int orderId) {}
  @override
  Future<void> start(Future<String?> Function() token) async {}
  @override
  Future<void> stop() async {}
}

/// Nguồn mặc định: SignalR thật; `flutter test` thì tắt để test không tự nối mạng.
RealtimeSource defaultRealtimeSource(String apiBaseUrl) => Platform.environment['FLUTTER_TEST'] == 'true' ? const NoRealtimeSource() : SignalRRealtimeSource(apiBaseUrl);

/// Các đơn khách đang theo dõi: nhớ để gọi lại `JoinOrder` sau mỗi lần nối/kết nối lại (B12).
class OrderRooms {
  OrderRooms(this._invoke);
  final Future<void> Function(String method, int orderId) _invoke;
  final _ids = <int>{};

  Future<void> join(int orderId) {
    _ids.add(orderId);
    return _invoke('JoinOrder', orderId);
  }

  void leave(int orderId) => _ids.remove(orderId);

  Future<void> rejoin() async {
    for (final id in _ids.toList()) {
      await _invoke('JoinOrder', id);
    }
  }

  void clear() => _ids.clear();
}

/// SignalR `/hubs/tracking`: nhận sự kiện `NotificationReceived` và `LocationUpdated`. Lỗi kết nối chỉ ghi log, không đẩy banner;
/// mất kết nối thì tự kết nối lại (`withAutomaticReconnect`), mỗi lần dùng token hiện tại.
class SignalRRealtimeSource implements RealtimeSource {
  SignalRRealtimeSource(this.apiBaseUrl);
  final String apiBaseUrl;
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  final _locations = StreamController<Map<String, Object?>>.broadcast();
  HubConnection? _connection;
  late final _rooms = OrderRooms(_invokeRoom);

  @override
  Stream<Map<String, Object?>> get notifications => _controller.stream;

  @override
  Stream<Map<String, Object?>> get locations => _locations.stream;

  @override
  Future<void> joinOrder(int orderId) => _rooms.join(orderId);

  @override
  void leaveOrder(int orderId) => _rooms.leave(orderId);

  /// Chưa nối thì thôi: `start` và `onreconnected` sẽ join lại các đơn đã nhớ.
  Future<void> _invokeRoom(String method, int orderId) async {
    final connection = _connection;
    if (connection == null || connection.state != HubConnectionState.Connected) return;
    try {
      await connection.invoke(method, args: [orderId]);
    } catch (error) {
      debugPrint('SignalR $method($orderId) lỗi: $error');
    }
  }

  @override
  Future<void> start(Future<String?> Function() token) async {
    if (_connection != null) return;
    final connection = HubConnectionBuilder().withUrl(hubUrl(apiBaseUrl), options: HttpConnectionOptions(accessTokenFactory: () async => await token() ?? '')).withAutomaticReconnect().build();
    connection.on('NotificationReceived', (args) {
      final payload = args?.firstOrNull;
      if (payload is Map) _controller.add(payload.cast<String, Object?>());
    });
    connection.on('LocationUpdated', (args) {
      final payload = args?.firstOrNull;
      if (payload is Map) _locations.add(payload.cast<String, Object?>());
    });
    connection.onreconnected(({connectionId}) => unawaited(_rooms.rejoin()));
    _connection = connection;
    try {
      await connection.start();
      await _rooms.rejoin();
    } catch (error) {
      debugPrint('SignalR chưa kết nối được: $error');
    }
  }

  @override
  Future<void> stop() async {
    final connection = _connection;
    _connection = null;
    _rooms.clear();
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (_) {
      /* đã đóng */
    }
  }
}

/// Nối nguồn thời gian thực với [NotificationCubit]: payload → [noticeFor] → banner và hộp thông báo.
class RealtimeBridge {
  RealtimeBridge(this._source, this._cubit, this._sessions);
  final RealtimeSource _source;
  final NotificationCubit _cubit;
  final SessionStore _sessions;
  StreamSubscription<Map<String, Object?>>? _subscription;

  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _source.notifications.listen(_onPayload, onError: (_) {});
    // Đọc token mới nhất ở mỗi lần kết nối (ApiClient đã tự refresh khi 401 nên SessionStore luôn mới).
    await _source.start(() async => _sessions.current?.accessToken);
  }

  /// Đăng xuất / hết phiên: ngắt kết nối, bỏ nghe và xoá hộp thông báo.
  Future<void> stop() async {
    // Xoá ngay (đồng bộ) trước khi chờ ngắt kết nối: thông báo "đã đăng xuất / đã xoá tài khoản" đẩy sau đó
    // không bị lệnh xoá đến muộn cuốn mất.
    _cubit.clear();
    await _subscription?.cancel();
    _subscription = null;
    await _source.stop();
  }

  void _onPayload(Map<String, Object?> payload) {
    final type = payload['type'];
    if (type is! String || type.isEmpty) return; // payload sai dạng: bỏ qua
    final raw = payload['data'];
    final data = raw is Map ? {for (final e in raw.entries) '${e.key}': '${e.value}'} : <String, String>{};
    String? text(Object? v) => v is String ? v : null;
    final AppNotice notice = noticeFor(type, data: data, title: text(payload['title']), body: text(payload['body']));
    _cubit.push(notice);
  }
}
