import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/usecases/driver_trip_actions.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/evidence_cubit.dart';

CargoPhoto photo(CargoPhotoKind kind) => CargoPhoto(
  kind: kind,
  name: '${kind.name}.png',
  bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, kind.index]),
);

class TestPhotos implements CargoPhotoRepository {
  int calls = 0;
  @override
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source) async {
    calls++;
    return photo(kind);
  }
}

Future<MockDriverTripRepository> atPickup({bool cash = false}) async {
  final repo = MockDriverTripRepository(delay: Duration.zero, autoOffer: false);
  await repo.setOnline(true);
  final id = (cash ? repo.current.jobs.last : repo.current.jobs.first).id;
  await repo.openOffer(id);
  await repo.acceptOffer(id);
  await repo.simulate(TripSimulation.nearPickup);
  await repo.arrive();
  return repo;
}

Future<List<UploadedEvidence>> uploadBoth(
  MockDriverTripRepository repo,
) async => [
  for (final kind in CargoPhotoKind.values)
    await repo.upload(photo(kind), (_) {}),
];
void main() {
  test(
    'upload retry retains photo and only two photos plus checklist can submit',
    () async {
      final repo = await atPickup();
      final picker = TestPhotos();
      final cubit = EvidenceCubit(DriverTripActions(repo), picker);
      addTearDown(() async {
        await cubit.close();
        await repo.close();
      });
      await repo.simulate(TripSimulation.uploadFailure);
      await cubit.pick(CargoPhotoKind.overall, CargoPhotoSource.sample);
      final bytes = cubit.state.items[CargoPhotoKind.overall]!.photo.bytes;
      expect(cubit.state.uploadedCount, 0);
      expect(cubit.state.items[CargoPhotoKind.overall]!.error, isNotNull);
      await cubit.retry(CargoPhotoKind.overall);
      expect(picker.calls, 1);
      expect(
        cubit.state.items[CargoPhotoKind.overall]!.photo.bytes,
        same(bytes),
      );
      await cubit.submit();
      expect(repo.current.trip!.stage, TripStage.arrived);
      expect(cubit.state.error, isNotNull);
      await cubit.pick(CargoPhotoKind.secured, CargoPhotoSource.sample);
      for (var i = 0; i < 4; i++) {
        cubit.check(i, true);
      }
      expect(cubit.state.ready, isTrue);
      await Future.wait([cubit.submit(), cubit.submit()]);
      expect(repo.current.trip!.stage, TripStage.pickedUp);
      expect(repo.current.trip!.review, EvidenceReview.pending);
      expect(repo.current.trip!.attempts, 1);
      await cubit.pick(CargoPhotoKind.overall, CargoPhotoSource.sample);
      expect(picker.calls, 2);
      await repo.simulate(TripSimulation.customerApproves);
      expect(repo.current.trip!.stage, TripStage.inTransit);
    },
  );
  test(
    'rejection retains photos but requires retaking before resubmission',
    () async {
      final repo = await atPickup();
      final cubit = EvidenceCubit(DriverTripActions(repo), TestPhotos());
      addTearDown(() async {
        await cubit.close();
        await repo.close();
      });
      for (final kind in CargoPhotoKind.values) {
        await cubit.pick(kind, CargoPhotoSource.sample);
      }
      for (var i = 0; i < 4; i++) {
        cubit.check(i, true);
      }
      await cubit.submit();
      await repo.simulate(TripSimulation.customerRejects);
      await Future<void>.delayed(Duration.zero);
      expect(
        cubit.state.items.values.every((item) => item.needsRetake),
        isTrue,
      );
      expect(cubit.state.uploadedCount, 0);
      await cubit.retry(CargoPhotoKind.overall);
      expect(cubit.state.uploadedCount, 0);
      for (final kind in CargoPhotoKind.values) {
        await cubit.pick(kind, CargoPhotoSource.sample);
      }
      await cubit.submit();
      expect(repo.current.trip!.attempts, 2);
      expect(repo.current.trip!.review, EvidenceReview.pending);
    },
  );
  test(
    'server caps evidence at five submissions and rejects reused references',
    () async {
      final repo = await atPickup();
      addTearDown(repo.close);
      for (var i = 0; i < 5; i++) {
        final evidence = await uploadBoth(repo);
        await repo.submitInspection(
          evidence: evidence,
          checklist: [true, true, true, true],
          note: '',
          cashCollected: false,
        );
        await repo.simulate(TripSimulation.customerRejects);
        expect(repo.current.trip!.stage, TripStage.pickedUp);
        expect(repo.current.trip!.attempts, i + 1);
        await expectLater(
          repo.submitInspection(
            evidence: evidence,
            checklist: [true, true, true, true],
            note: '',
            cashCollected: false,
          ),
          throwsA(isA<TripFailure>()),
        );
      }
      expect(repo.current.trip!.editable, isFalse);
      await expectLater(
        repo.upload(photo(CargoPhotoKind.overall), (_) {}),
        throwsA(isA<TripFailure>()),
      );
    },
  );
  test(
    'cash sender must be collected; unowned evidence and invalid images fail',
    () async {
      final repo = await atPickup(cash: true);
      addTearDown(repo.close);
      await expectLater(
        repo.upload(
          CargoPhoto(
            kind: CargoPhotoKind.overall,
            name: 'bad.png',
            bytes: Uint8List(8),
          ),
          (_) {},
        ),
        throwsA(isA<TripFailure>()),
      );
      final evidence = await uploadBoth(repo);
      await expectLater(
        repo.submitInspection(
          evidence: evidence,
          checklist: [true, true, true, true],
          note: '',
          cashCollected: false,
        ),
        throwsA(isA<TripFailure>()),
      );
      await expectLater(
        repo.submitInspection(
          evidence: [
            const UploadedEvidence(CargoPhotoKind.overall, 'mock://other'),
            evidence.last,
          ],
          checklist: [true, true, true, true],
          note: '',
          cashCollected: true,
        ),
        throwsA(isA<TripFailure>()),
      );
      expect(repo.current.trip!.stage, TripStage.arrived);
      await repo.submitInspection(
        evidence: evidence,
        checklist: [true, true, true, true],
        note: 'Đủ hàng',
        cashCollected: true,
      );
      expect(repo.current.trip!.cashCollected, isTrue);
      expect(repo.current.trip!.note, 'Đủ hàng');
    },
  );
}
