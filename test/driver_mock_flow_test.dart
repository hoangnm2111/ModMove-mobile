import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/app/app.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/api_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/demo_photo_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/device_photo_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/services/mock_driver_api.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';
import 'package:modmove_mobile/features/onboarding/domain/repositories/driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/usecases/driver_usecases.dart';
import 'package:modmove_mobile/features/onboarding/presentation/controllers/driver_controller.dart';

class TestPhotos implements DocumentPhotoRepository {
  @override
  Future<SelectedPhoto?> pick(PhotoSource source) async => SelectedPhoto(
    'document.png',
    File('assets/images/demo-document.png').readAsBytesSync(),
  );
}

DriverController controller(
  MockDriverApi api, {
  DocumentPhotoRepository? photos,
}) {
  final repository = ApiDriverRepository(
    client: api.client,
    cached: api.cachedApplication,
  );
  return DriverController(
    loadApplication: GetDriverApplication(repository),
    submitApplication: SubmitDriverApplication(
      repository,
      requireUploadedDocuments: true,
    ),
    pickPhoto: PickDocumentPhoto(
      photos ?? DemoPhotoRepository(DevicePhotoRepository()),
    ),
    profile: ManageDriverProfile(repository),
    simulator: repository,
    onDispose: repository.close,
  );
}

Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chooseSample(
  WidgetTester tester,
  DocumentKind kind,
  String action,
) async {
  final card = find.byKey(ValueKey('document-${kind.name}'));
  await click(tester, find.descendant(of: card, matching: find.text(action)));
  await click(tester, find.byKey(const ValueKey('choose-sample-photo')));
}

void main() {
  test(
    'failed upload retains bytes across reload and retry needs no new picker',
    () async {
      final api = MockDriverApi(latency: Duration.zero);
      final driver = controller(api, photos: TestPhotos());
      addTearDown(driver.dispose);
      await driver.failNext('upload');
      expect(
        await driver.pickDocument(
          DocumentKind.citizenFront,
          PhotoSource.sample,
        ),
        isNotNull,
      );
      expect(driver.documents[DocumentKind.citizenFront]!.bytes, isNotNull);
      expect(
        driver.documents[DocumentKind.citizenFront]!.remoteReference,
        isNull,
      );
      await driver.refresh();
      expect(driver.uploadErrors, contains(DocumentKind.citizenFront));
      expect(await driver.retryUpload(DocumentKind.citizenFront), isNull);
      expect(driver.uploadErrors, isEmpty);
      expect(
        driver.documents[DocumentKind.citizenFront]!.remoteReference,
        startsWith('mock://'),
      );
    },
  );

  test(
    'controller blocks in-flight duplicate submission and preserves draft on failure',
    () async {
      final api = MockDriverApi(
        initial: MockDriverApi.freshApplication(complete: true),
        latency: const Duration(milliseconds: 1),
      );
      final driver = controller(api, photos: TestPhotos());
      addTearDown(driver.dispose);
      await driver.failNext('submit');
      final first = driver.submit();
      expect(driver.submitting, isTrue);
      expect(await driver.submit(), contains('đang được xử lý'));
      expect(await first, isNotNull);
      expect(driver.status, ApprovalStatus.draft);
      expect(driver.submitting, isFalse);
      expect(await driver.submit(), isNull);
      expect(driver.version, 1);
      expect(driver.versions, hasLength(1));
    },
  );

  testWidgets(
    'registration -> reject -> correct -> approve -> online entirely through UI',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = MockDriverApi(latency: Duration.zero);
      final driver = controller(api);
      await tester.pumpWidget(
        ModMoveApp(screen: 'driver-onboarding', driverController: driver),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('field-citizenId')),
        '001201000123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('field-license')),
        '790123456789',
      );
      for (final kind in DocumentKind.values.take(4)) {
        await chooseSample(tester, kind, 'Tải ảnh lên');
        expect(driver.documents[kind]!.remoteReference, isNotNull);
      }
      await click(tester, find.text('Tiếp tục'));
      for (final entry in {
        'plate': '29C-123.45',
        'payload': '1000',
        'length': '3,1',
        'width': '1,6',
        'height': '1,6',
      }.entries) {
        final field = find.byKey(ValueKey('field-${entry.key}'));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      for (final kind in DocumentKind.values.skip(4)) {
        await chooseSample(tester, kind, 'Tải ảnh');
      }
      await click(tester, find.text('Gửi hồ sơ xét duyệt'));
      expect(find.text('Hồ sơ đang chờ duyệt'), findsOneWidget);
      expect(driver.version, 1);
      await click(tester, find.text('Mô phỏng'));
      await click(tester, find.byKey(const ValueKey('demo-reject')));
      expect(driver.status, ApprovalStatus.rejected);
      await click(tester, find.byTooltip('Quay lại'));
      await click(tester, find.text('Cập nhật giấy tờ'));
      await chooseSample(tester, DocumentKind.licenseBack, 'Xem / Thay ảnh');
      await click(tester, find.text('Tiếp tục'));
      await chooseSample(tester, DocumentKind.inspection, 'Thay ảnh');
      await click(tester, find.text('Gửi hồ sơ xét duyệt'));
      expect(driver.version, 2);
      await click(tester, find.text('Mô phỏng'));
      await click(tester, find.byKey(const ValueKey('demo-approve')));
      await click(tester, find.byTooltip('Quay lại'));
      await click(tester, find.byKey(const ValueKey('driver-online')));
      expect(driver.online, isTrue);
      expect(api.cachedApplication.online, isTrue);
      await click(tester, find.text('Lịch sử các lần gửi'));
      expect(find.text('Phiên bản 2'), findsOneWidget);
      expect(driver.versions.map((item) => item.version), [2, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'upload retry and API submit failure remain actionable on the form',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = MockDriverApi(
        initial: MockDriverApi.freshApplication(complete: true),
        latency: Duration.zero,
      );
      final driver = controller(api);
      await tester.pumpWidget(
        ModMoveApp(screen: 'verification-vehicle', driverController: driver),
      );
      await tester.pumpAndSettle();
      await click(tester, find.text('Mô phỏng'));
      await click(tester, find.byKey(const ValueKey('fail-upload')));
      await click(tester, find.byTooltip('Quay lại'));
      await chooseSample(tester, DocumentKind.vehicle, 'Thay ảnh');
      expect(find.text('Chưa tải lên thành công'), findsOneWidget);
      await click(tester, find.byKey(const ValueKey('retry-vehicle')));
      expect(
        driver.documents[DocumentKind.vehicle]!.remoteReference,
        startsWith('mock://'),
      );
      await click(tester, find.text('Mô phỏng'));
      await click(tester, find.byKey(const ValueKey('fail-submit')));
      await click(tester, find.byTooltip('Quay lại'));
      await click(tester, find.text('Gửi hồ sơ xét duyệt'));
      expect(driver.status, ApprovalStatus.draft);
      expect(find.text('Gửi hồ sơ xét duyệt'), findsOneWidget);
      await click(tester, find.text('Gửi hồ sơ xét duyệt'));
      expect(driver.status, ApprovalStatus.pending);
      expect(tester.takeException(), isNull);
    },
  );
}
