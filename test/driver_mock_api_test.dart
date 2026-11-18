import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/onboarding/data/models/driver_application_dto.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/api_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/services/mock_driver_api.dart';
import 'package:modmove_mobile/features/onboarding/data/services/profile_mock_store.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';

class SwitchableStore implements ProfileMockStore {
  bool fail = false;
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>?> read() async => saved;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    if (fail) throw const FileSystemException('Disk unavailable');
    saved = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }
}

DriverApplication withDocuments(
  DriverApplication original,
  Map<DocumentKind, VerificationDocument> documents,
) => DriverApplicationDto.fromJson({
  ...DriverApplicationDto.toJson(original),
  'documents': {
    for (final item in documents.entries)
      item.key.name: DriverApplicationDto.documentToJson(item.value),
  },
});

void main() {
  late MockDriverApi api;
  late ApiDriverRepository repository;
  final photo = SelectedPhoto(
    'sample.png',
    File('assets/images/demo-document.png').readAsBytesSync(),
  );
  setUp(() {
    api = MockDriverApi(
      initial: MockDriverApi.freshApplication(complete: true),
      latency: Duration.zero,
    );
    repository = ApiDriverRepository(
      client: api.client,
      cached: api.cachedApplication,
    );
  });
  tearDown(() => repository.close());

  test(
    'submit -> reject -> replace both documents -> version 2 -> approve -> online',
    () async {
      expect((await repository.submit(api.cachedApplication)).version, 1);
      expect((await repository.refresh()).status, ApprovalStatus.pending);
      await expectLater(
        repository.setAvailability(true),
        throwsA(isA<ApplicationFailure>()),
      );
      await repository.review(ApprovalStatus.rejected, 1);
      var rejected = await repository.refresh();
      final before = DriverApplicationDto.toJson(
        (await repository.history()).single,
      );
      final license = await repository.upload(DocumentKind.licenseBack, photo);
      rejected = await repository.saveDraft(
        withDocuments(rejected, {
          ...rejected.documents,
          DocumentKind.licenseBack: license,
        }),
      );
      await expectLater(
        repository.submit(rejected),
        throwsA(isA<ApplicationFailure>()),
      );
      final inspection = await repository.upload(
        DocumentKind.inspection,
        photo,
      );
      rejected = await repository.saveDraft(
        withDocuments(rejected, {
          ...rejected.documents,
          DocumentKind.inspection: inspection,
        }),
      );
      expect((await repository.submit(rejected)).version, 2);
      await repository.review(ApprovalStatus.approved, 2);
      expect((await repository.setAvailability(true)).online, isTrue);
      final history = await repository.history();
      expect(history.map((item) => item.version), [2, 1]);
      expect(DriverApplicationDto.toJson(history.last), before);
      expect(history.first.status, ApprovalStatus.approved);
    },
  );

  test(
    'same idempotency key coalesces concurrent retries into one version',
    () async {
      final draft = api.cachedApplication;
      final receipts = await Future.wait([
        repository.submit(draft),
        repository.submit(draft),
      ]);
      expect(receipts.map((item) => item.version), [1, 1]);
      expect(await repository.history(), hasLength(1));
    },
  );

  test(
    'independent concurrent submit requests cannot create two pending versions',
    () async {
      final second = ApiDriverRepository(
        client: api.client,
        cached: api.cachedApplication,
      );
      final draft = api.cachedApplication;
      final outcomes = await Future.wait([
        repository
            .submit(draft)
            .then<Object>((r) => r, onError: (Object e) => e),
        second.submit(draft).then<Object>((r) => r, onError: (Object e) => e),
      ]);
      expect(outcomes.whereType<ApplicationReceipt>(), hasLength(1));
      expect(outcomes.whereType<ApplicationFailure>(), hasLength(1));
      expect(await repository.history(), hasLength(1));
    },
  );

  test('pending blocks upload, draft edits and duplicate decisions', () async {
    final original = api.cachedApplication;
    await repository.submit(original);
    await expectLater(
      repository.saveDraft(original),
      throwsA(isA<ApplicationFailure>()),
    );
    await expectLater(
      repository.upload(DocumentKind.vehicle, photo),
      throwsA(isA<ApplicationFailure>()),
    );
    await expectLater(
      repository.review(ApprovalStatus.approved, 99),
      throwsA(isA<ApplicationFailure>()),
    );
    await repository.review(ApprovalStatus.approved, 1);
    await expectLater(
      repository.review(ApprovalStatus.rejected, 1),
      throwsA(isA<ApplicationFailure>()),
    );
  });

  test(
    'client cannot forge accepted flags or reuse an old rejected reference',
    () async {
      await repository.submit(api.cachedApplication);
      await repository.review(ApprovalStatus.rejected, 1);
      final rejected = await repository.refresh();
      final body = DriverApplicationDto.toJson(rejected);
      for (final doc in (body['documents'] as Map).values) {
        (doc as Map)['accepted'] = true;
        doc['replaced'] = true;
        doc['rejectionReason'] = null;
      }
      final saved = await repository.saveDraft(
        DriverApplicationDto.fromJson(body),
      );
      expect(saved.documents[DocumentKind.licenseBack]!.accepted, isFalse);
      expect(saved.documents[DocumentKind.licenseBack]!.replaced, isFalse);
      await expectLater(
        repository.submit(saved),
        throwsA(isA<ApplicationFailure>()),
      );
    },
  );

  test(
    'approved account lock forces offline and approval alone cannot bypass it',
    () async {
      await repository.submit(api.cachedApplication);
      await repository.review(ApprovalStatus.approved, 1);
      await repository.setAvailability(true);
      await repository.setAccountActive(false);
      expect((await repository.refresh()).online, isFalse);
      await expectLater(
        repository.setAvailability(true),
        throwsA(isA<ApplicationFailure>()),
      );
      await repository.setAccountActive(true);
      expect((await repository.refresh()).online, isFalse);
      expect((await repository.setAvailability(true)).online, isTrue);
    },
  );

  test(
    'one-shot submit failure preserves draft and retry succeeds once',
    () async {
      final draft = api.cachedApplication;
      await repository.failNext('submit');
      await expectLater(
        repository.submit(draft),
        throwsA(isA<ApplicationFailure>()),
      );
      expect(await repository.history(), isEmpty);
      expect((await repository.refresh()).status, ApprovalStatus.draft);
      expect((await repository.submit(draft)).version, 1);
    },
  );

  test(
    'duplicate plate and missing uploaded reference are rejected by API',
    () async {
      final draft = DriverApplicationDto.toJson(api.cachedApplication);
      final plate = (draft['fields'] as Map)['plate'];
      (draft['fields'] as Map)['plate'] = '99C-999.99';
      await expectLater(
        repository.submit(DriverApplicationDto.fromJson(draft)),
        throwsA(isA<ApplicationFailure>()),
      );
      (draft['fields'] as Map)['plate'] = plate;
      (draft['documents'] as Map)['vehicle']['reference'] =
          'mock://does-not-exist';
      await expectLater(
        repository.submit(DriverApplicationDto.fromJson(draft)),
        throwsA(isA<ApplicationFailure>()),
      );
      expect(await repository.history(), isEmpty);
    },
  );

  test(
    'storage failure rolls back version, history and idempotency receipt',
    () async {
      final store = SwitchableStore()..fail = true;
      final server = MockDriverApi(
        initial: MockDriverApi.freshApplication(complete: true),
        store: store,
        latency: Duration.zero,
      );
      final repo = ApiDriverRepository(
        client: server.client,
        cached: server.cachedApplication,
      );
      addTearDown(repo.close);
      final draft = server.cachedApplication;
      await expectLater(repo.submit(draft), throwsA(isA<ApplicationFailure>()));
      expect(server.cachedApplication.version, 0);
      expect(await repo.history(), isEmpty);
      store.fail = false;
      expect((await repo.submit(draft)).version, 1);
      expect(await repo.history(), hasLength(1));
    },
  );

  test(
    'file persistence restores uploaded bytes, review history and online state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'modmove-profile-test-',
      );
      final file = File('${directory.path}/state.json');
      addTearDown(() async {
        if (await file.exists()) await file.delete();
        final temporary = File('${file.path}.tmp');
        if (await temporary.exists()) await temporary.delete();
        await directory.delete();
      });
      final store = FileProfileMockStore(file);
      final server = MockDriverApi(
        initial: MockDriverApi.freshApplication(complete: true),
        store: store,
        latency: Duration.zero,
      );
      final repo = ApiDriverRepository(
        client: server.client,
        cached: server.cachedApplication,
      );
      addTearDown(repo.close);
      final uploaded = await repo.upload(DocumentKind.vehicle, photo);
      final draft = await repo.saveDraft(
        withDocuments(server.cachedApplication, {
          ...server.cachedApplication.documents,
          DocumentKind.vehicle: uploaded,
        }),
      );
      await repo.submit(draft);
      await repo.review(ApprovalStatus.approved, 1);
      await repo.setAvailability(true);
      final restored = MockDriverApi(
        restored: await store.read(),
        store: store,
        latency: Duration.zero,
      );
      addTearDown(restored.close);
      expect(restored.cachedApplication.online, isTrue);
      expect(restored.cachedApplication.status, ApprovalStatus.approved);
      expect(
        restored.cachedApplication.documents[DocumentKind.vehicle]!.bytes,
        photo.bytes,
      );
      final restoredRepo = ApiDriverRepository(
        client: restored.client,
        cached: restored.cachedApplication,
      );
      expect(await restoredRepo.history(), hasLength(1));
    },
  );
}
