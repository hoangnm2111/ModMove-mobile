import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this.api, {this.detachPush});
  final ApiClient api;
  final Future<String?> Function()? detachPush;
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiFailure catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  bool get signedIn => api.session != null;
  @override
  Stream<void> get expired => api.expired;
  @override
  Future<void> restore() => _guard(api.restore);
  @override
  Future<void> login(String email, String password) => _guard(() async {
    final response = await api.request(
      'POST',
      '/api/public/auth/login',
      authenticated: false,
      body: {'email': email.trim(), 'password': password},
    );
    await api.saveSession(response as Map<String, dynamic>);
  });
  @override
  Future<void> register(
    String name,
    String phone,
    String email,
    String password, {
    String role = 'Driver',
  }) => _guard(() async {
    await api.request(
      'POST',
      role == 'Customer'
          ? '/api/public/auth/register'
          : '/api/public/auth/register-driver',
      authenticated: false,
      body: {
        'fullName': name.trim(),
        'phoneNumber': phone.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
  });
  @override
  Future<void> forgotPassword(String email) => _guard(() async {
    await api.request(
      'POST',
      '/api/public/auth/forgot-password',
      authenticated: false,
      body: {'email': email.trim()},
    );
  });
  @override
  Future<void> resetPassword(String email, String code, String password) =>
      _guard(() async {
        await api.request(
          'POST',
          '/api/public/auth/reset-password',
          authenticated: false,
          body: {
            'email': email.trim(),
            'code': code.trim(),
            'newPassword': password,
          },
        );
      });
  @override
  Future<void> verify(String email, String code, String password) =>
      _guard(() async {
        await api.request(
          'POST',
          '/api/public/auth/verify-email',
          authenticated: false,
          body: {
            'email': email.trim(),
            'code': code.trim(),
            'password': password,
          },
        );
      });
  @override
  Future<void> resend(String email) => _guard(() async {
    await api.request(
      'POST',
      '/api/public/auth/otp/resend',
      authenticated: false,
      body: {'email': email.trim(), 'purpose': 'Register'},
    );
  });
  @override
  Future<void> logout() => _guard(() async {
    // An offline logout must still remove credentials from this device.
    try {
      final fcmToken = await detachPush?.call();
      await api.request(
        'POST',
        '/api/account/logout',
        body: {'fcmToken': ?fcmToken},
      );
    } finally {
      await api.clearSession();
    }
  });
}
