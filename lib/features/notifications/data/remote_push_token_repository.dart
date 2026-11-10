import '../../../core/network/api_client.dart';
import '../domain/push_repository.dart';

class RemotePushTokenRepository implements PushTokenRepository {
  const RemotePushTokenRepository(this.api);
  final ApiClient api;
  @override
  Future<void> register(String token) async {
    await api.request('PUT', '/api/account/FcmToken', body: {'token': token});
  }
}
