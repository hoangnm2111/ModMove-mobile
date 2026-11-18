/// Cấu hình chạy app. Đổi bằng `--dart-define`, ví dụ:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5133/api`
abstract final class AppConfig {
  /// Emulator Android truy cập máy host qua 10.0.2.2 (không dùng localhost).
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5133/api');

  /// API key MapVina (lấy ở account.mapvina.com). Ví dụ:
  /// `flutter run --dart-define=MAPVINA_KEY=khoa_cua_ban`
  /// Mặc định `public_key` chỉ để thử, có hạn mức thấp.
  static const mapVinaKey = String.fromEnvironment('MAPVINA_KEY', defaultValue: 'public_key');

  /// Style gốc của MapVina (chuẩn MapLibre), giữ nguyên không chỉnh.
  static const mapVinaStyleUrl = 'https://maps.mapvina.com/styles/v2/streets.json?key=$mapVinaKey';

  /// Thời gian chờ mỗi request.
  static const requestTimeout = Duration(seconds: 20);

  /// `true` → luồng tài xế chạy bằng dữ liệu mô phỏng trong máy (không gọi BE).
  /// Mặc định `false`: hồ sơ, nhận đơn, chuyến đi gọi thẳng BE (api/driver/*).
  static const useMockDriver = bool.fromEnvironment('USE_MOCK_DRIVER');

  /// Toạ độ giả cho tài xế khi test trên máy ảo (GPS máy ảo mặc định ở Mỹ,
  /// ngoài bán kính ghép đơn). Ví dụ:
  /// `--dart-define=DRIVER_FAKE_LAT=10.7769 --dart-define=DRIVER_FAKE_LNG=106.7009`
  static const _fakeLat = String.fromEnvironment('DRIVER_FAKE_LAT');
  static const _fakeLng = String.fromEnvironment('DRIVER_FAKE_LNG');

  /// `null` khi không đặt (dùng GPS thật của máy).
  static (double, double)? get driverFakeLocation {
    final lat = double.tryParse(_fakeLat);
    final lng = double.tryParse(_fakeLng);
    return lat == null || lng == null ? null : (lat, lng);
  }

  /// Chu kỳ đồng bộ với BE khi tài xế đang đăng nhập (vị trí, đơn gần, chuyến).
  static const driverPollInterval = Duration(seconds: 5);
}
