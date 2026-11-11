import '../entities/driver_application.dart';

abstract interface class DriverRepository {
  DriverApplication loadCachedApplication();
  Future<ApplicationReceipt> submit(DriverApplication application);
}

abstract interface class DocumentPhotoRepository {
  Future<SelectedPhoto?> pick(PhotoSource source);
}

/// Async profile API. The basic interface remains useful for isolated fixtures.
abstract interface class DriverProfileRepository implements DriverRepository {
  Future<DriverApplication> refresh();
  Future<DriverApplication> saveDraft(DriverApplication application);
  Future<VerificationDocument> upload(DocumentKind kind, SelectedPhoto photo);
  Future<DriverApplication> setAvailability(bool online);
  Future<List<DriverApplication>> history();
}

/// Demo controls are deliberately separate from a driver's production rights.
abstract interface class DriverReviewSimulator {
  Future<void> review(ApprovalStatus decision, int expectedVersion);
  Future<void> failNext(String operation);
  Future<void> setAccountActive(bool active);
  Future<void> reset({bool completeDraft = false});
}

/// Danh mục loại xe lấy từ BE; chỉ repository gọi BE mới có.
abstract interface class VehicleTypeCatalog {
  Future<List<VehicleTypeOption>> vehicleTypes();
}

/// Bộ nhớ hồ sơ trong máy cần xoá khi đăng xuất / đổi tài khoản.
abstract interface class ProfileLocalCache {
  void clear();
}
