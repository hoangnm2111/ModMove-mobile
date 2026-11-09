/// Cấu hình chạy app. Đổi bằng `--dart-define`, ví dụ:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5133/api`
abstract final class AppConfig {
  /// Emulator Android truy cập máy host qua 10.0.2.2 (không dùng localhost).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5133/api',
  );

  /// Thời gian chờ mỗi request.
  static const requestTimeout = Duration(seconds: 20);
}
