import '../../../core/network/api_client.dart';
import '../domain/push_repository.dart';

/// Gửi token FCM của máy lên BE: `PUT api/account/fcmtoken { token }` (204). Mỗi tài khoản giữ một token,
/// máy đăng ký sau cùng nhận thông báo.
class RemotePushTokenRepository implements PushTokenRepository {
  const RemotePushTokenRepository(this._api);
  final ApiClient _api;

  @override
  Future<void> register(String token) async {
    await _api.put('/account/FcmToken', {'token': token});
  }
}
