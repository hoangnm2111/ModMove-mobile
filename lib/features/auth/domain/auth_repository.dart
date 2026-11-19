abstract interface class AuthRepository {
  bool get signedIn;
  Stream<void> get expired;
  Future<void> restore();
  Future<void> login(String email, String password);
  Future<void> register(
    String name,
    String phone,
    String email,
    String password, {
    String role = 'Driver',
  });
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String email, String code, String password);
  Future<void> verify(String email, String code, String password);
  Future<void> resend(String email);
  Future<void> logout();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}
