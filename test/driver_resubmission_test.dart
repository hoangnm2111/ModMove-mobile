import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/remote_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';
import 'package:modmove_mobile/features/onboarding/domain/repositories/driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/usecases/driver_usecases.dart';
import 'package:modmove_mobile/features/onboarding/presentation/controllers/driver_controller.dart';
import 'package:modmove_mobile/features/onboarding/presentation/screens/verification_screen.dart';
import 'support/remote_fixtures.dart';

const orderedKinds = [
  DocumentKind.licenseFront,
  DocumentKind.licenseBack,
  DocumentKind.registration,
  DocumentKind.inspection,
  DocumentKind.vehicle,
  DocumentKind.citizenFront,
  DocumentKind.citizenBack,
];
final originalUrls = [
  for (final kind in orderedKinds) 'https://images.test/${kind.name}.png',
];

class _Photos implements DocumentPhotoRepository {
  @override
  Future<SelectedPhoto?> pick(PhotoSource source) async => SelectedPhoto(
    'new.png',
    File('assets/images/demo-document.png').readAsBytesSync(),
  );
}

class _Backend {
  final store = MemorySessionStore();
  late ApiClient api;
  Map<String, dynamic> status = {
    'hasApplication': true,
    'profileApprovalStatus': 'Rejected',
    'latestVersionNumber': 1,
    'vehicleTypeName': testVehicle['name'],
    'citizenIdNumber': '079090000001',
    'driverLicenseNumber': '790000000001',
    'licensePlate': '51C-123.45',
    'maxLoadWeightKg': 900,
    'documentUrls': [...originalUrls],
    'rejectionReasons': ['Giấy đăng kiểm bị mờ, vui lòng thay ảnh.'],
  };
  Map<String, dynamic>? submitted;
  int uploads = 0;
  bool failUpload = false, failSubmit = false, failRead = false;

  Future<RemoteDriverRepository> open({int userId = 8}) async {
    api = ApiClient(
      store: store,
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/public/vehicletypes':
            return jsonResponse([testVehicle]);
          case '/api/driver/profile':
            if (failRead) return jsonResponse({'title': 'Unavailable'}, 503);
            return jsonResponse({
              'fullName': 'Tài xế Test',
              'phoneNumber': '0901234567',
            });
          case '/api/driver/status':
            return jsonResponse(driverStatus());
          case '/api/driver/onboarding/status':
            return jsonResponse(status);
          case '/api/driver/uploads':
            uploads++;
            if (failUpload) {
              return jsonResponse({'title': 'Upload failed'}, 503);
            }
            return jsonResponse({'url': 'https://images.test/new.png'});
          case '/api/driver/onboarding':
            if (failSubmit) {
              return jsonResponse({'title': 'Submit failed'}, 503);
            }
            submitted = jsonDecode(request.body) as Map<String, dynamic>;
            status = {
              ...status,
              ...submitted!,
              'latestVersionNumber': 2,
              'profileApprovalStatus': 'Pending',
              'rejectionReasons': null,
            };
            return jsonResponse(2, 201);
          default:
            throw StateError('Unexpected route: ${request.url.path}');
        }
      }),
    );
    addTearDown(api.close);
    await api.saveSession({...tokens(), 'userId': userId});
    final repository = RemoteDriverRepository(api);
    await repository.initialize();
    return repository;
  }
}

DriverController _controller(RemoteDriverRepository repo) => DriverController(
  loadApplication: GetDriverApplication(repo),
  submitApplication: SubmitDriverApplication(
    repo,
    validation: RemoteDriverRepository.validation,
    requireUploadedDocuments: true,
  ),
  pickPhoto: PickDocumentPhoto(_Photos()),
  profile: ManageDriverProfile(repo),
  validation: RemoteDriverRepository.validation,
);

void main() {
  test(
    'rejected application restores all submitted fields and seven photos without a local draft',
    () async {
      final driver = _controller(await _Backend().open());
      addTearDown(driver.close);
      expect(driver.status, ApprovalStatus.rejected);
      expect(driver.fields['citizenId'], '079090000001');
      expect(driver.fields['plate'], '51C-123.45');
      expect(driver.missingDocuments(), isEmpty);
      for (final (i, kind) in orderedKinds.indexed) {
        expect(driver.documents[kind]!.remoteReference, originalUrls[i]);
        expect(driver.documents[kind]!.replaced, isFalse);
      }
    },
  );

  test(
    'replace one photo and edit a field; preserve through refresh, restart and resubmission',
    () async {
      final backend = _Backend();
      final driver = _controller(await backend.open());
      addTearDown(driver.close);
      expect(
        await driver.pickDocument(DocumentKind.inspection, PhotoSource.gallery),
        isNull,
      );
      driver.setField('plate', '51C-999.99');
      expect(await driver.refresh(), isNull);
      expect(driver.fields['plate'], '51C-999.99');
      expect(
        driver.documents[DocumentKind.inspection]!.remoteReference,
        'https://images.test/new.png',
      );

      final restarted = _controller(await backend.open());
      addTearDown(restarted.close);
      expect(restarted.fields['plate'], '51C-999.99');
      expect(await restarted.submit(), isNull);
      expect(backend.uploads, 1);
      expect(
        backend.submitted!['documentUrls'],
        [...originalUrls]..[3] = 'https://images.test/new.png',
      );
      expect(backend.submitted!['licensePlate'], '51C-999.99');
      expect(backend.submitted!['citizenIdNumber'], '079090000001');
      expect(restarted.status, ApprovalStatus.pending);
      expect(restarted.canEdit, isFalse);
      expect(
        backend.store.values.keys.where((k) => k.startsWith('draft:')),
        isEmpty,
      );
    },
  );

  test(
    'a field-only correction resubmits the existing photos without uploading all again',
    () async {
      final backend = _Backend();
      backend.status['rejectionReasons'] = ['Sửa biển số xe.'];
      final driver = _controller(await backend.open());
      addTearDown(driver.close);
      driver.setField('plate', '51C-999.99');
      expect(await driver.submit(), isNull);
      expect(backend.uploads, 0);
      expect(backend.submitted!['documentUrls'], originalUrls);
    },
  );

  test(
    'legacy five-photo applications keep five images and request only the missing citizen ID pair',
    () async {
      final backend = _Backend();
      backend.status['documentUrls'] = originalUrls.take(5).toList();
      final driver = _controller(await backend.open());
      addTearDown(driver.close);
      expect(driver.missingDocuments(), [
        DocumentKind.citizenFront,
        DocumentKind.citizenBack,
      ]);
      for (var i = 0; i < 5; i++) {
        expect(
          driver.documents[orderedKinds[i]]!.remoteReference,
          originalUrls[i],
        );
      }
      expect(await driver.submit(), isNotNull);
      expect(backend.submitted, isNull);
    },
  );

  test(
    'failed replacement and refresh keep other documents and allow retry of that photo only',
    () async {
      final backend = _Backend()..failUpload = true;
      final driver = _controller(await backend.open());
      addTearDown(driver.close);
      expect(
        await driver.pickDocument(DocumentKind.inspection, PhotoSource.gallery),
        isNotNull,
      );
      expect(await driver.refresh(), isNull);
      expect(driver.documents[DocumentKind.inspection]!.bytes, isNotNull);
      expect(driver.missingDocuments(), [DocumentKind.inspection]);
      for (final (i, kind) in orderedKinds.indexed.where(
        (e) => e.$2 != DocumentKind.inspection,
      )) {
        expect(driver.documents[kind]!.remoteReference, originalUrls[i]);
      }
      backend.failUpload = false;
      expect(await driver.retryUpload(DocumentKind.inspection), isNull);
      expect(driver.missingDocuments(), isEmpty);
    },
  );

  test(
    'failed resubmission retains the corrected draft after restarting',
    () async {
      final backend = _Backend()..failSubmit = true;
      final driver = _controller(await backend.open());
      addTearDown(driver.close);
      await driver.pickDocument(DocumentKind.inspection, PhotoSource.gallery);
      driver.setField('plate', '51C-999.99');
      expect(await driver.submit(), isNotNull);
      final restarted = _controller(await backend.open());
      addTearDown(restarted.close);
      expect(restarted.status, ApprovalStatus.rejected);
      expect(restarted.fields['plate'], '51C-999.99');
      expect(
        restarted.documents[DocumentKind.inspection]!.remoteReference,
        'https://images.test/new.png',
      );
      expect(restarted.missingDocuments(), isEmpty);
    },
  );

  test('a failed refresh retains the current corrections', () async {
    final backend = _Backend();
    final driver = _controller(await backend.open());
    addTearDown(driver.close);
    driver.setField('plate', '51C-999.99');
    backend.failRead = true;
    expect(await driver.refresh(), isNotNull);
    expect(driver.fields['plate'], '51C-999.99');
    expect(driver.missingDocuments(), isEmpty);
    backend.failRead = false;
    expect(await driver.refresh(), isNull);
    expect(driver.fields['plate'], '51C-999.99');
  });

  test(
    'new application draft survives restart when the server has no submission yet',
    () async {
      final backend = _Backend();
      backend.status = {'hasApplication': false};
      final driver = _controller(await backend.open());
      addTearDown(driver.close);
      driver.setField('citizenId', '079090000001');
      driver.setField('vehicleType', testVehicle['name'] as String);
      await driver.pickDocument(DocumentKind.citizenFront, PhotoSource.gallery);
      final restarted = _controller(await backend.open());
      addTearDown(restarted.close);
      expect(restarted.status, ApprovalStatus.draft);
      expect(restarted.fields['citizenId'], '079090000001');
      expect(restarted.fields['vehicleType'], testVehicle['name']);
      expect(
        restarted.documents[DocumentKind.citizenFront]!.remoteReference,
        'https://images.test/new.png',
      );
    },
  );

  for (final decision in ['Pending', 'Approved', 'Rejected']) {
    test('new $decision version supersedes an old rejected draft', () async {
      final backend = _Backend();
      final driver = _controller(await backend.open());
      addTearDown(driver.close);
      await driver.pickDocument(DocumentKind.inspection, PhotoSource.gallery);
      backend.status = {
        ...backend.status,
        'latestVersionNumber': 2,
        'profileApprovalStatus': decision,
        'licensePlate': '51C-222.22',
        'documentUrls': [
          for (final kind in orderedKinds)
            'https://images.test/v2-${kind.name}.png',
        ],
      };
      final restarted = _controller(await backend.open());
      addTearDown(restarted.close);
      expect(restarted.version, 2);
      expect(restarted.fields['plate'], '51C-222.22');
      expect(
        restarted.documents[DocumentKind.inspection]!.remoteReference,
        'https://images.test/v2-inspection.png',
      );
      expect(
        backend.store.values.keys.where((k) => k.startsWith('draft:')),
        isEmpty,
      );
    });
  }

  test('drafts are isolated by driver account', () async {
    final backend = _Backend();
    final driver = _controller(await backend.open());
    addTearDown(driver.close);
    await driver.pickDocument(DocumentKind.inspection, PhotoSource.gallery);
    final other = _controller(await backend.open(userId: 99));
    addTearDown(other.close);
    expect(
      other.documents[DocumentKind.inspection]!.remoteReference,
      originalUrls[3],
    );
  });

  testWidgets(
    'rejected form explains selective corrections and shows prefilled fields',
    (tester) async {
      final driver = _controller(await _Backend().open());
      addTearDown(driver.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        BlocProvider.value(
          value: driver,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const VerificationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chỉ cập nhật mục được yêu cầu'), findsOneWidget);
      expect(find.textContaining('Giấy đăng kiểm bị mờ'), findsOneWidget);
      expect(
        find.text('Bản demo • Có thể lưu nháp và tiếp tục sau'),
        findsNothing,
      );
      final citizen = find.byKey(const ValueKey('field-citizenId'));
      await tester.ensureVisible(citizen);
      expect(
        tester.widget<TextFormField>(citizen).initialValue,
        '079090000001',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('replace just the requested photo and resubmit from the form', (
    tester,
  ) async {
    final backend = _Backend();
    final driver = _controller(await backend.open());
    addTearDown(driver.close);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var submitted = false;
    await tester.pumpWidget(
      BlocProvider.value(
        value: driver,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: VerificationScreen(
            initialStep: 1,
            onSubmitted: () => submitted = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('document-inspection'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: card, matching: find.text('Thay ảnh')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn từ thư viện'));
    await tester.pumpAndSettle();
    expect(driver.missingDocuments(), isEmpty);
    await tester.tap(find.text('Gửi lại hồ sơ'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
    expect(backend.uploads, 1);
    expect(
      backend.submitted!['documentUrls'],
      [...originalUrls]..[3] = 'https://images.test/new.png',
    );
    expect(driver.status, ApprovalStatus.pending);
    expect(tester.takeException(), isNull);
  });
}
