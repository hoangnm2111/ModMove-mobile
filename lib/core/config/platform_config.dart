/// Giới hạn nghiệp vụ và số liệu Admin chỉnh được, lấy từ BE (`GET /public/Config`).
/// Nguồn thật là BE (`BusinessRules` và `platform_settings`); app không tự giữ bản sao.
///
/// Tiền (phí bốc xếp, tiền cọc) và bán kính ghép đơn do Admin chỉnh nên **không có số dự phòng**: chưa tải được thì
/// [AppRules.config] là null và giao diện không hiện số tiền. Các giới hạn còn lại có số dự phòng ([PlatformRules.fallback])
/// chỉ để biểu mẫu vẫn kiểm tra được khi chưa gọi được BE; BE luôn kiểm tra lại.
class PlatformRules {
  const PlatformRules({
    required this.maxCargoPhotos,
    required this.maxPhotoSizeMb,
    required this.maxOrderNoteLength,
    required this.minPickupPhotos,
    required this.maxPickupSubmissions,
    required this.maxEvidencePhotos,
    required this.matchingTimeoutMinutes,
    required this.unpaidPaymentMinutes,
    required this.payOsCodeMinutes,
    required this.complaintWindowHours,
    required this.ratingWindowHours,
    required this.autoCompleteHours,
    required this.arrivalRadiusMeters,
    required this.passwordMinLength,
    required this.passwordMaxLength,
    required this.otpLifetimeMinutes,
    required this.maxFailedLogins,
    required this.loginLockMinutes,
  });

  final int maxCargoPhotos, maxPhotoSizeMb, maxOrderNoteLength;
  final int minPickupPhotos, maxPickupSubmissions, maxEvidencePhotos;
  final int matchingTimeoutMinutes, unpaidPaymentMinutes, payOsCodeMinutes;
  final int complaintWindowHours, ratingWindowHours, autoCompleteHours;
  final int arrivalRadiusMeters;
  final int passwordMinLength, passwordMaxLength;
  final int otpLifetimeMinutes, maxFailedLogins, loginLockMinutes;

  /// Số dự phòng khi chưa gọi được BE (trùng `BusinessRules` của BE tại thời điểm viết).
  static const fallback = PlatformRules(
    maxCargoPhotos: 5,
    maxPhotoSizeMb: 5,
    maxOrderNoteLength: 500,
    minPickupPhotos: 2,
    maxPickupSubmissions: 5,
    maxEvidencePhotos: 5,
    matchingTimeoutMinutes: 10,
    unpaidPaymentMinutes: 30,
    payOsCodeMinutes: 10,
    complaintWindowHours: 24,
    ratingWindowHours: 24,
    autoCompleteHours: 24,
    arrivalRadiusMeters: 500,
    passwordMinLength: 8,
    passwordMaxLength: 20,
    otpLifetimeMinutes: 5,
    maxFailedLogins: 5,
    loginLockMinutes: 10,
  );

  factory PlatformRules.fromJson(Map<String, dynamic> j) {
    int i(String key, int fallbackValue) => j[key] is num ? (j[key] as num).toInt() : fallbackValue;
    const f = PlatformRules.fallback;
    return PlatformRules(
      maxCargoPhotos: i('maxCargoPhotos', f.maxCargoPhotos),
      maxPhotoSizeMb: i('maxPhotoSizeMb', f.maxPhotoSizeMb),
      maxOrderNoteLength: i('maxOrderNoteLength', f.maxOrderNoteLength),
      minPickupPhotos: i('minPickupPhotos', f.minPickupPhotos),
      maxPickupSubmissions: i('maxPickupSubmissions', f.maxPickupSubmissions),
      maxEvidencePhotos: i('maxEvidencePhotos', f.maxEvidencePhotos),
      matchingTimeoutMinutes: i('matchingTimeoutMinutes', f.matchingTimeoutMinutes),
      unpaidPaymentMinutes: i('unpaidPaymentMinutes', f.unpaidPaymentMinutes),
      payOsCodeMinutes: i('payOsCodeMinutes', f.payOsCodeMinutes),
      complaintWindowHours: i('complaintWindowHours', f.complaintWindowHours),
      ratingWindowHours: i('ratingWindowHours', f.ratingWindowHours),
      autoCompleteHours: i('autoCompleteHours', f.autoCompleteHours),
      arrivalRadiusMeters: i('arrivalRadiusMeters', f.arrivalRadiusMeters),
      passwordMinLength: i('passwordMinLength', f.passwordMinLength),
      passwordMaxLength: i('passwordMaxLength', f.passwordMaxLength),
      otpLifetimeMinutes: i('otpLifetimeMinutes', f.otpLifetimeMinutes),
      maxFailedLogins: i('maxFailedLogins', f.maxFailedLogins),
      loginLockMinutes: i('loginLockMinutes', f.loginLockMinutes),
    );
  }
}

/// Phản hồi của `GET /public/Config`.
class PlatformConfig {
  const PlatformConfig({
    required this.loadingFee,
    required this.requiredDeposit,
    required this.matchingRadiusKm,
    required this.rules,
  });

  /// VND cộng thêm khi khách chọn dịch vụ bốc xếp.
  final double loadingFee;

  /// VND tài xế cần giữ để nhận đơn tiền mặt.
  final double requiredDeposit;

  /// Bán kính (km) quanh điểm lấy hàng mà đơn được gửi tới tài xế.
  final double matchingRadiusKm;
  final PlatformRules rules;

  factory PlatformConfig.fromJson(Map<String, dynamic> j) => PlatformConfig(
    loadingFee: (j['loadingFee'] as num).toDouble(),
    requiredDeposit: (j['requiredDeposit'] as num).toDouble(),
    matchingRadiusKm: (j['matchingRadiusKm'] as num).toDouble(),
    rules: PlatformRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
  );
}

/// Số liệu hiện hành toàn app. [config] là null cho tới khi BE trả lời; [rules] luôn có giá trị.
abstract final class AppRules {
  static PlatformConfig? config;
  static PlatformRules get rules => config?.rules ?? PlatformRules.fallback;

  static void apply(PlatformConfig value) => config = value;

  /// Chỉ dùng cho test: quay về trạng thái chưa nhận được số liệu từ BE.
  static void reset() => config = null;
}
