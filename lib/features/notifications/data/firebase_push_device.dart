// The backend sends HTTP v1 `message.token`, not Firebase Installation IDs.
// Keep the token API until the backend adopts FCM's registration/FID contract.
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/push_message.dart';
import '../domain/push_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Android displays notification payloads here. Do not create a duplicate.
}

class FirebasePushDevice implements PushDevice {
  final _local = FlutterLocalNotificationsPlugin();
  final _opened = StreamController<PushMessage>.broadcast();
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _ready = false;
  static const _channel = AndroidNotificationChannel(
    'modmove_notifications',
    'Thông báo ModMove',
    description: 'Đơn hàng, hoàn tiền, sự cố, hồ sơ và ví ModMove',
    importance: Importance.high,
  );
  PushMessage _message(RemoteMessage message) => PushMessage(
    data: message.data,
    id: message.messageId,
    title: message.notification?.title,
    body: message.notification?.body,
  );
  PushMessage? _payload(String? payload) {
    try {
      final json = jsonDecode(payload ?? '') as Map<String, dynamic>;
      return PushMessage(
        data: Map<String, dynamic>.from(json['data'] as Map),
        id: json['id'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> initialize() async {
    if (!Platform.isAndroid) return false;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 15));
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final message = _payload(response.payload);
          if (message != null) _opened.add(message);
        },
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!
          .createNotificationChannel(_channel);
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _opened.add(_message(message)),
      );
      _ready = true;
      return true;
    } catch (_) {
      // Missing local client configuration must not prevent sign-in or CI builds.
      return false;
    }
  }

  @override
  Stream<String> get tokenChanges =>
      _ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();
  @override
  Stream<PushMessage> get messages =>
      _ready ? FirebaseMessaging.onMessage.map(_message) : const Stream.empty();
  @override
  Stream<PushMessage> get opened => _opened.stream;
  @override
  Future<PushMessage?> initialMessage() async {
    if (!_ready) return null;
    final remote = await FirebaseMessaging.instance.getInitialMessage();
    if (remote != null) return _message(remote);
    final local = await _local.getNotificationAppLaunchDetails();
    return local?.didNotificationLaunchApp == true
        ? _payload(local?.notificationResponse?.payload)
        : null;
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (!_ready) return PushPermission.unavailable;
    final settings = request
        ? await FirebaseMessaging.instance.requestPermission()
        : await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional
        ? PushPermission.allowed
        : PushPermission.denied;
  }

  @override
  Future<String?> token() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    return FirebaseMessaging.instance.getToken().timeout(
      const Duration(seconds: 20),
    );
  }

  @override
  Future<void> show(PushMessage message) => _local.show(
    id: (message.id ?? jsonEncode(message.data)).hashCode & 0x7fffffff,
    title: message.title ?? 'ModMove',
    body: message.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
    ),
    payload: jsonEncode({'id': message.id, 'data': message.data}),
  );
  @override
  Future<void> clear() async {
    if (!_ready) return;
    await _local.cancelAll();
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken().timeout(
      const Duration(seconds: 5),
    );
  }

  @override
  Future<void> openSettings() => const MethodChannel(
    'vn.modmove/notifications',
  ).invokeMethod('openSettings');
  @override
  Future<void> close() async {
    await _openedSubscription?.cancel();
    await _opened.close();
  }
}
