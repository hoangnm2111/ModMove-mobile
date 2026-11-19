abstract interface class AccountSecurityRepository {
  Future<void> changePassword(String current, String next);
  Future<void> deleteAccount();
}

class AccountSecurityFailure implements Exception {
  const AccountSecurityFailure(this.message);
  final String message;
}
