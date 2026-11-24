import '../../../../core/config/platform_config.dart';

abstract final class DriverMatchingPolicy {
  /// Bán kính nhận đơn quanh tài xế do Admin cấu hình (BE: MATCHING_RADIUS_KM). 0 = chưa biết (chưa nhận được số liệu từ BE),
  /// khi đó bản đồ không vẽ vùng phủ thay vì vẽ một số tự đoán.
  static double get searchRadiusMeters => (AppRules.config?.matchingRadiusKm ?? 0) * 1000;

  /// Chỉ cho chế độ mô phỏng (không gọi BE).
  static const mockSearchRadiusMeters = 5000.0;
}
