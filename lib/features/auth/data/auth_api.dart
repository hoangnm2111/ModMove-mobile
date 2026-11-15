import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_store.dart';

/// Đăng nhập / đăng ký / OTP / quên mật khẩu (Controllers/Public/AuthController).
class AuthApi {
  AuthApi(this._api);
  final ApiClient _api;

  Future<Session> login(String email, String password) async =>
      Session.fromJson(await _api.post('/public/Auth/login', {'email': email.trim().toLowerCase(), 'password': password}) as Map<String, dynamic>);

  /// Đăng ký Customer (hoặc Driver khi [asDriver], endpoint `register-driver` dành cho app); gửi OTP về email.
  ///
  /// Từ BE 2026-11-12 bước này chỉ gửi OTP: tài khoản được tạo khi `verify-email` thành công.
  Future<void> register({required String fullName, required String phone, required String email, required String password, bool asDriver = false}) async {
    try {
      await _api.post(asDriver ? '/public/Auth/register-driver' : '/public/Auth/register', {
        'fullName': fullName.trim(),
        'phoneNumber': phone.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      });
    } on ApiException catch (e) {
      // 409 ở đây chỉ có một nghĩa: email hoặc số điện thoại đã có tài khoản.
      if (e.status == 409) throw ApiException('Email hoặc số điện thoại đã có tài khoản. Hãy đăng nhập hoặc dùng thông tin khác.', code: e.code, status: e.status);
      rethrow;
    }
  }

  /// Xác minh email cần kèm đúng mật khẩu đã đăng ký (A-02).
  Future<void> verifyEmail(String email, String code, String password) =>
      _api.post('/public/Auth/verify-email', {'email': email.trim().toLowerCase(), 'code': code.trim(), 'password': password});

  /// purpose: Register | ResetPassword. Luôn 204.
  Future<void> resendOtp(String email, String purpose) =>
      _api.post('/public/Auth/otp/resend', {'email': email.trim().toLowerCase(), 'purpose': purpose});

  Future<void> forgotPassword(String email) => _api.post('/public/Auth/forgot-password', {'email': email.trim().toLowerCase()});

  Future<void> resetPassword(String email, String code, String newPassword) =>
      _api.post('/public/Auth/reset-password', {'email': email.trim().toLowerCase(), 'code': code.trim(), 'newPassword': newPassword});

  /// App gửi kèm FCM token (nếu có) để server chỉ xoá đúng token máy này (9.2).
  Future<void> logout({String? fcmToken}) => _api.post('/account/Logout', fcmToken == null ? null : {'fcmToken': fcmToken});
}
