import 'driver_notification.dart';

abstract interface class PushDevice {
  Stream<String> get tokenChanges;
  Stream<DriverNotification> get messages;
  Stream<DriverNotification> get opened;
  Future<bool> initialize();
  Future<DriverNotification?> initialMessage();
  Future<PushPermission> permission({bool request = false});
  Future<String?> token();
  Future<void> show(DriverNotification message);
  Future<void> clear();
  Future<void> openSettings();
  Future<void> close();
}

abstract interface class PushTokenRepository {
  Future<void> register(String token);
}
