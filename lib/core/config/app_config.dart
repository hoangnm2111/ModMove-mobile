/// Cấu hình chạy app. Đổi bằng `--dart-define`, ví dụ:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5133/api`
abstract final class AppConfig {
  /// Emulator Android truy cập máy host qua 10.0.2.2 (không dùng localhost).
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5133/api');

  /// Key MapVina riêng cho máy dev (tuỳ chọn): `flutter run --dart-define=MAPVINA_KEY=khoa_cua_ban`.
  /// Mặc định để trống: bản đồ lấy style, tile, font qua BE (`/public/Map/*`), BE thêm key của hệ thống,
  /// nên app không giữ key MapVina.
  static const _ownMapVinaKey = String.fromEnvironment('MAPVINA_KEY');

  /// SDK MapVina bắt buộc có một key khác rỗng khi tạo bản đồ; khi đi qua BE, giá trị này không được dùng tới.
  static const mapVinaKey = _ownMapVinaKey == '' ? 'via-backend' : _ownMapVinaKey;

  /// Style bản đồ (chuẩn MapLibre): qua BE, hoặc thẳng MapVina khi máy dev tự có key.
  static const mapVinaStyleUrl = _ownMapVinaKey == ''
      ? '$apiBaseUrl/public/Map/style'
      : 'https://maps.mapvina.com/styles/v2/streets.json?key=$_ownMapVinaKey';

  /// Thời gian chờ mỗi request.
  static const requestTimeout = Duration(seconds: 20);

  /// `true` → luồng tài xế chạy bằng dữ liệu mô phỏng trong máy (không gọi BE).
  /// Mặc định `false`: hồ sơ, nhận đơn, chuyến đi gọi thẳng BE (api/driver/*).
  static const useMockDriver = bool.fromEnvironment('USE_MOCK_DRIVER');

  /// Chu kỳ đồng bộ với BE khi tài xế đang đăng nhập (vị trí, đơn gần, chuyến).
  static const driverPollInterval = Duration(seconds: 5);
}
