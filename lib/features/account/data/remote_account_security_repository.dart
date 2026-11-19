import '../../../core/network/api_client.dart';
import '../domain/account_security_repository.dart';

class RemoteAccountSecurityRepository implements AccountSecurityRepository {
  const RemoteAccountSecurityRepository(this.api);
  final ApiClient api;
  Future<void> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      await api.request(method, path, body: body);
    } on ApiFailure catch (e) {
      throw AccountSecurityFailure(e.message);
    }
  }

  @override
  Future<void> changePassword(String current, String next) => _send(
    'POST',
    '/api/account/Password',
    {'currentPassword': current, 'newPassword': next},
  );
  @override
  Future<void> deleteAccount() => _send('DELETE', '/api/driver/Account');
}
