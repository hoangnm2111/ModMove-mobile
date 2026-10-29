import '../entities/driver_application.dart';

abstract interface class DriverRepository {
  DriverApplication loadCachedApplication();
  Future<ApplicationReceipt> submit(DriverApplication application);
}

abstract interface class DocumentPhotoRepository {
  Future<SelectedPhoto?> pick(PhotoSource source);
}
