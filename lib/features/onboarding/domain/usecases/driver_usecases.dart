import '../entities/driver_application.dart';
import '../repositories/driver_repository.dart';
import 'validate_driver_application.dart';

class GetDriverApplication {
  const GetDriverApplication(this.repository);
  final DriverRepository repository;
  DriverApplication call() => repository.loadCachedApplication();
}

class SubmitDriverApplication {
  const SubmitDriverApplication(
    this.repository, {
    this.validation = const ValidateDriverApplication(),
  });
  final DriverRepository repository;
  final ValidateDriverApplication validation;
  Future<ApplicationReceipt> call(DriverApplication application) {
    if (!application.canEdit) {
      throw const ApplicationFailure('Hồ sơ đã gửi hoặc đang được xử lý.');
    }
    if (validation.personal(application.fields).isNotEmpty ||
        validation.vehicle(application.fields).isNotEmpty) {
      throw const ApplicationFailure('Vui lòng kiểm tra thông tin hồ sơ.');
    }
    if (validation.missingDocuments(application).isNotEmpty) {
      throw const ApplicationFailure(
        'Vui lòng bổ sung hoặc thay lại các ảnh được yêu cầu.',
      );
    }
    return repository.submit(application);
  }
}

class PickDocumentPhoto {
  const PickDocumentPhoto(
    this.repository, {
    this.validation = const ValidateDriverApplication(),
  });
  final DocumentPhotoRepository repository;
  final ValidateDriverApplication validation;
  Future<SelectedPhoto?> call(PhotoSource source) async {
    final photo = await repository.pick(source);
    if (photo == null) return null;
    final error = validation.image(photo.name, photo.bytes);
    if (error != null) throw ApplicationFailure(error);
    return photo;
  }
}
