import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/demo_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';
import 'package:modmove_mobile/features/onboarding/domain/repositories/driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/usecases/driver_usecases.dart';
import 'package:modmove_mobile/features/onboarding/domain/usecases/validate_driver_application.dart';
import 'package:modmove_mobile/features/onboarding/presentation/controllers/driver_controller.dart';

class FakePhotos implements DocumentPhotoRepository {
  SelectedPhoto? photo;
  @override
  Future<SelectedPhoto?> pick(PhotoSource source) async => photo;
}

DriverController makeDriver(
  DemoDriverRepository repository,
  FakePhotos photos,
) => DriverController(
  loadApplication: GetDriverApplication(repository),
  submitApplication: SubmitDriverApplication(repository),
  pickPhoto: PickDocumentPhoto(photos),
);

void main() {
  const validation = ValidateDriverApplication();
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  test('image checks reject unsupported, mislabeled and oversized files', () {
    expect(validation.image('photo.png', png), isNull);
    expect(validation.image('photo.jpg', png), isNotNull);
    expect(validation.image('photo.gif', png), isNotNull);
    expect(
      validation.image('photo.png', Uint8List(5 * 1024 * 1024 + 1)),
      isNotNull,
    );
    expect(validation.image('photo.png', Uint8List(0)), isNotNull);
  });
  test('incomplete draft is not submitted and retains valid images', () async {
    final repo = DemoDriverRepository(delay: Duration.zero);
    final driver = makeDriver(repo, FakePhotos());
    expect(await driver.submit(), isNotNull);
    expect(repo.submissions, isEmpty);
    expect(driver.documents[DocumentKind.licenseFront]!.hasImage, isTrue);
    expect(driver.status, ApprovalStatus.draft);
  });
  test(
    'submission creates one pending version and blocks duplicate submission',
    () async {
      final repo = DemoDriverRepository(
        completeDraft: true,
        delay: Duration.zero,
      );
      final driver = makeDriver(repo, FakePhotos());
      expect(await driver.submit(), isNull);
      expect(driver.status, ApprovalStatus.pending);
      expect(driver.version, 1);
      expect(driver.canGoOnline, isFalse);
      expect(await driver.submit(), isNotNull);
      expect(repo.submissions, hasLength(1));
    },
  );
  test(
    'rejected items must be replaced while other documents can still be edited',
    () async {
      final repo = DemoDriverRepository(
        status: ApprovalStatus.rejected,
        delay: Duration.zero,
      );
      final photos = FakePhotos()..photo = SelectedPhoto('new.png', png);
      final driver = makeDriver(repo, photos);
      expect(await driver.submit(), isNotNull);
      // Giấy tờ không bị từ chối vẫn thay ảnh được (hồ sơ không còn khoá từng mục).
      expect(
        await driver.pickDocument(
          DocumentKind.licenseFront,
          PhotoSource.gallery,
        ),
        isNull,
      );
      expect(
        await driver.pickDocument(
          DocumentKind.licenseBack,
          PhotoSource.gallery,
        ),
        isNull,
      );
      expect(await driver.submit(), isNotNull);
      expect(
        await driver.pickDocument(DocumentKind.inspection, PhotoSource.gallery),
        isNull,
      );
      expect(await driver.submit(), isNull);
      expect(driver.version, 2);
      expect(driver.status, ApprovalStatus.pending);
      expect(driver.canEditDocument(DocumentKind.inspection), isFalse);
    },
  );
  test('online requires both approved documents and an active account', () {
    for (final status in ApprovalStatus.values) {
      final active = DemoDriverRepository(
        status: status,
      ).loadCachedApplication();
      expect(active.canGoOnline, status == ApprovalStatus.approved);
      final inactive = DemoDriverRepository(
        status: status,
        accountActive: false,
      ).loadCachedApplication();
      expect(inactive.canGoOnline, isFalse);
    }
  });
  test('invalid dimensions include non-finite and negative values', () {
    final fields = Map<String, String>.of(
      DemoDriverRepository(completeDraft: true).loadCachedApplication().fields,
    );
    fields['length'] = 'NaN';
    fields['width'] = '-1';
    fields['height'] = 'Infinity';
    expect(
      validation.vehicle(fields).keys,
      containsAll(['length', 'width', 'height']),
    );
  });
}
