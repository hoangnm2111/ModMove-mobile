import 'push_message.dart';

abstract interface class PushDevice {
  Stream<String> get tokenChanges;
  Stream<PushMessage> get messages;
  Stream<PushMessage> get opened;
  Future<bool> initialize();
  Future<PushMessage?> initialMessage();
  Future<PushPermission> permission({bool request = false});
  Future<String?> token();
  Future<void> show(PushMessage message);
  Future<void> clear();
  Future<void> openSettings();
  Future<void> close();
}

abstract interface class PushTokenRepository {
  Future<void> register(String token);
}
