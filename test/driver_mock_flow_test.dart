import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/app/app.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/screens/driver_dashboard.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/api_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/demo_photo_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/device_photo_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/services/mock_driver_api.dart';
import 'package:modmove_mobile/features/onboarding/data/services/profile_mock_store.dart';
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

class PersistedProfileStore implements ProfileMockStore {
  String? _saved;
  @override
  Future<Map<String, dynamic>?> read() async =>
      _saved == null ? null : jsonDecode(_saved!) as Map<String, dynamic>;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    _saved = jsonEncode(value);
  }
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
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
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
      addTearDown(driver.close);
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
      addTearDown(driver.close);
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
    'pending and approved profiles survive restart and receive a trip',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = PersistedProfileStore();
      var api = MockDriverApi(
        initial: MockDriverApi.freshApplication(complete: true),
        store: store,
        latency: Duration.zero,
      );
      var driver = controller(api);
      await tester.pumpWidget(ModMoveApp(driverController: driver));
      await tester.pumpAndSettle();
      await click(tester, find.text('Đăng ký tài xế  →'));
      await click(tester, find.text('Tiếp tục'));
      await click(tester, find.text('Gửi hồ sơ xét duyệt'));
      expect(find.text('Hồ sơ đang chờ duyệt'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

      Future<void> restartAndOpenProfile() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        api = MockDriverApi(
          restored: await store.read(),
          store: store,
          latency: Duration.zero,
        );
        driver = controller(api);
        await tester.pumpWidget(ModMoveApp(driverController: driver));
        await tester.pumpAndSettle();
        await click(tester, find.text('Tài khoản'));
      }

      await restartAndOpenProfile();
      expect(find.text('Hồ sơ đang chờ duyệt'), findsOneWidget);
      expect(find.byKey(const Key('open-driver-home')), findsNothing);
      await click(tester, find.text('Mô phỏng'));
      await click(tester, find.byKey(const Key('demo-approve')));
      await click(tester, find.byTooltip('Quay lại'));
      expect(find.text('Hồ sơ đã duyệt'), findsOneWidget);
      await restartAndOpenProfile();
      expect(find.text('Hồ sơ đã duyệt'), findsOneWidget);
      expect(driver.version, 1);
      await click(tester, find.byKey(const Key('open-driver-home')));
      expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
      await click(tester, find.byKey(const Key('driver-online')));
      expect(find.text('Bạn đang trực tuyến'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.text('Xem chi tiết'), findsOneWidget);
      await click(tester, find.text('Xem chi tiết'));
      await click(tester, find.byKey(const Key('accept-job')));
      expect(find.text('Đến điểm lấy hàng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guest home -> registration -> review -> profile -> accept trip through UI',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = MockDriverApi(latency: Duration.zero);
      final driver = controller(api);
      await tester.pumpWidget(ModMoveApp(driverController: driver));
      await tester.pumpAndSettle();
      await click(tester, find.text('Đăng ký tài xế  →'));
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
      expect(find.byKey(const Key('open-driver-home')), findsNothing);
      expect(driver.version, 1);
      await click(tester, find.text('Mô phỏng'));
      await click(tester, find.byKey(const ValueKey('demo-reject')));
      expect(driver.status, ApprovalStatus.rejected);
      await click(tester, find.byTooltip('Quay lại'));
      await click(tester, find.text('Cập nhật giấy tờ'));
      await chooseSample(tester, DocumentKind.licenseBack, 'Xem / Thay ảnh');
      await click(tester, find.text('Tiếp tục'));
      await chooseSample(tester, DocumentKind.inspection, 'Thay ảnh');
      await click(tester, find.text('Gửi lại hồ sơ'));
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
      await click(tester, find.byTooltip('Quay lại'));
      await click(tester, find.byKey(const Key('open-driver-home')));
      expect(find.text('Trang chủ tài xế'), findsOneWidget);
      expect(find.text('Bạn đang trực tuyến'), findsOneWidget);
      final trips = tester
          .element(find.byType(DriverDashboard))
          .read<DriverTripRepository>();
      expect(trips.current.online, isTrue);
      await click(tester, find.text('Tài khoản'));
      expect(find.text('Hồ sơ đã duyệt'), findsOneWidget);
      expect(find.text('Nguyễn Minh Anh'), findsNWidgets(2));
      await click(tester, find.text('Đơn hàng'));
      expect(find.text('Trang chủ tài xế'), findsOneWidget);
      await click(tester, find.text('12 Nguyễn Văn Linh, Quận 7'));
      await click(tester, find.text('Xem chi tiết'));
      await click(tester, find.byKey(const Key('accept-job')));
      expect(trips.current.trip!.stage, TripStage.accepted);
      expect(find.text('Đến điểm lấy hàng'), findsOneWidget);
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
