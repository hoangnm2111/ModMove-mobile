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
  Future<void> start(Future<String?> Function() token) async {}
  @override
  Future<void> stop() async {}
}

/// Nguồn mặc định: SignalR thật; `flutter test` thì tắt để test không tự nối mạng.
RealtimeSource defaultRealtimeSource(String apiBaseUrl) => Platform.environment['FLUTTER_TEST'] == 'true' ? const NoRealtimeSource() : SignalRRealtimeSource(apiBaseUrl);

/// SignalR `/hubs/tracking`: nhận sự kiện `NotificationReceived`. Lỗi kết nối chỉ ghi log, không đẩy banner;
/// mất kết nối thì tự kết nối lại (`withAutomaticReconnect`), mỗi lần dùng token hiện tại.
class SignalRRealtimeSource implements RealtimeSource {
  SignalRRealtimeSource(this.apiBaseUrl);
  final String apiBaseUrl;
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  HubConnection? _connection;

  @override
  Stream<Map<String, Object?>> get notifications => _controller.stream;

  @override
  Future<void> start(Future<String?> Function() token) async {
    if (_connection != null) return;
    final connection = HubConnectionBuilder().withUrl(hubUrl(apiBaseUrl), options: HttpConnectionOptions(accessTokenFactory: () async => await token() ?? '')).withAutomaticReconnect().build();
    connection.on('NotificationReceived', (args) {
      final payload = args?.firstOrNull;
      if (payload is Map) _controller.add(payload.cast<String, Object?>());
    });
    _connection = connection;
    try {
      await connection.start();
    } catch (error) {
      debugPrint('SignalR chưa kết nối được: $error');
    }
  }

  @override
  Future<void> stop() async {
    final connection = _connection;
    _connection = null;
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
    await _subscription?.cancel();
    _subscription = null;
    await _source.stop();
    _cubit.clear();
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
