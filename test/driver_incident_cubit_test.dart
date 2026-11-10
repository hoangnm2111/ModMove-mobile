import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/domain/result_page.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/incidents/domain/driver_incident_repository.dart';
import 'package:modmove_mobile/features/incidents/presentation/incident_cubits.dart';
import 'support/incident_fixtures.dart';

class DelayedIncidents extends IncidentTestRepository {
  final reads = <Completer<ResultPage<DriverIncident>>>[];
  @override
  Future<ResultPage<DriverIncident>> list({
    int page = 1,
    String? orderId,
    String? status,
  }) {
    queries.add((page: page, order: orderId, status: status));
    final pending = Completer<ResultPage<DriverIncident>>();
    reads.add(pending);
    return pending.future;
  }
}

void main() {
  late IncidentTestRepository repo;
  late IncidentTestTrips trips;
  late IncidentTestPicker picker;
  late IncidentReportCubit report;
  setUp(() {
    repo = IncidentTestRepository();
    trips = IncidentTestTrips();
    picker = IncidentTestPicker();
    report = IncidentReportCubit(repo, trips, picker, '42');
  });
  tearDown(() async {
    await report.close();
    await trips.controller.close();
  });

  test(
    'submit without photos sends selected type and fresh GPS once',
    () async {
      report.selectType(IncidentType.accident);
      report.describe('  Cần hỗ trợ  ');
      await Future.wait([report.submit(), report.submit()]);
      expect(repo.reports, hasLength(1));
      expect(repo.reports.single.type, IncidentType.accident);
      expect(repo.reports.single.description, 'Cần hỗ trợ');
      expect(repo.reports.single.photos, isEmpty);
      expect(repo.reports.single.location!.latitude, 10.73);
      expect(report.state.createdId, '7');
      expect(report.state.ready, false);
    },
  );
  test('stale GPS is omitted; driver can report without a GPS fix', () async {
    trips.now = incidentTime.add(const Duration(minutes: 1));
    report.describe('Cần hỗ trợ');
    await report.submit();
    expect(repo.reports.single.location, isNull);
  });
  test(
    'trip changed while typing prevents submission for the old order',
    () async {
      report.describe('Cần hỗ trợ');
      trips.update(DriverSession());
      await report.submit();
      expect(report.state.canReport, false);
      expect(repo.reports, isEmpty);
    },
  );
  test('trip cancelled during preflight never posts', () async {
    final delayed = DelayedIncidents();
    final cubit = IncidentReportCubit(delayed, trips, picker, '42')
      ..describe('Cần hỗ trợ');
    addTearDown(cubit.close);
    final pending = cubit.submit();
    trips.update(
      DriverSession(
        trip: trips.current.trip!.copyWith(stage: TripStage.cancelled),
      ),
    );
    delayed.reads.single.complete(const ResultPage([], 1, 0, false));
    await pending;
    expect(delayed.reports, isEmpty);
    expect(cubit.state.error, contains('Chuyến đã thay đổi'));
  });
  test('failed upload blocks submit and retains photo for retry', () async {
    repo.uploadError = const IncidentFailure('Không tải được ảnh');
    report.describe('Cần hỗ trợ');
    await report.add(CargoPhotoSource.camera);
    expect(report.state.photos.single.error, 'Không tải được ảnh');
    expect(report.state.ready, false);
    await report.submit();
    expect(repo.reports, isEmpty);
    repo.uploadError = null;
    await report.retry(0);
    expect(report.state.ready, true);
    await report.submit();
    expect(repo.reports.single.photos, ['https://images.test/photo-2.png']);
  });
  test(
    'invalid and sample photos never upload; cancelled picker is harmless',
    () async {
      await report.add(CargoPhotoSource.sample);
      expect(picker.calls, 0);
      picker.next = null;
      await report.add(CargoPhotoSource.gallery);
      picker.next = CargoPhoto(
        kind: CargoPhotoKind.overall,
        name: 'document.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      await report.add(CargoPhotoSource.gallery);
      expect(repo.uploads, 0);
      expect(report.state.photos, isEmpty);
      expect(report.state.error, contains('JPG/PNG'));
      expect(report.state.busy, false);
    },
  );
  test(
    'rejects duplicate photos and caps at five; removal permits replacement',
    () async {
      await report.add(CargoPhotoSource.gallery);
      await report.add(CargoPhotoSource.gallery);
      expect(report.state.error, contains('đã được thêm'));
      for (var i = 2; i <= 6; i++) {
        picker.next = IncidentTestPicker.photo(i);
        await report.add(CargoPhotoSource.gallery);
      }
      expect(repo.uploads, 5);
      expect(report.state.photos, hasLength(5));
      report.remove(1);
      await report.add(CargoPhotoSource.gallery);
      expect(repo.uploads, 6);
      expect(report.state.photos, hasLength(5));
    },
  );
  test(
    'saved report with lost response reconciles receipt without a second POST',
    () async {
      repo.reportError = const IncidentFailure(
        'Server unavailable',
        uncertain: true,
      );
      repo.saveBeforeFailure = true;
      report.describe('Xe bị thủng lốp, cần hỗ trợ.');
      await report.submit();
      expect(report.state.createdId, '7');
      expect(report.state.uncertain, false);
      expect(repo.reports, hasLength(1));
      expect(repo.queries, hasLength(2));
    },
  );
  test(
    'older identical report is not accepted as receipt; retries only GET',
    () async {
      repo.reportError = const IncidentFailure(
        'Connection lost',
        uncertain: true,
      );
      report.describe('Xe bị thủng lốp, cần hỗ trợ.');
      await report.submit();
      expect(report.state.createdId, isNull);
      expect(report.state.uncertain, true);
      report.describe('Different report');
      expect(report.state.description, 'Xe bị thủng lốp, cần hỗ trợ.');
      await report.submit();
      repo.listError = const IncidentFailure('Offline');
      await report.reconcile();
      expect(report.state.uncertain, true);
      expect(report.state.error, 'Offline');
      expect(repo.reports, hasLength(1));
      repo.listError = null;
      repo.items.insert(0, incident(id: '8', from: repo.reports.single));
      await report.reconcile();
      expect(report.state.createdId, '8');
    },
  );
  test('preflight failure makes no POST and allows later retry', () async {
    repo.listError = const IncidentFailure('Offline');
    report.describe('Cần hỗ trợ');
    await report.submit();
    expect(repo.reports, isEmpty);
    expect(report.state.uncertain, false);
    expect(report.state.ready, true);
  });
  test('business refusal stays editable and shows server failure', () async {
    repo.reportError = const IncidentFailure('Chuyến đã hoàn tất', status: 422);
    report.describe('Cần hỗ trợ');
    await report.submit();
    expect(report.state.error, 'Chuyến đã hoàn tất');
    expect(report.state.uncertain, false);
    expect(report.state.createdId, isNull);
  });
  test(
    'detail keeps last result offline but clears it when access is revoked',
    () async {
      final detail = IncidentDetailCubit(repo, '6');
      addTearDown(detail.close);
      await detail.refresh();
      repo.detailError = const IncidentFailure('Offline');
      await detail.refresh();
      expect(detail.state.item!.id, '6');
      repo.detailError = const IncidentFailure('Not found', status: 404);
      await detail.refresh();
      expect(detail.state.item, isNull);
      expect(detail.state.error, 'Not found');
    },
  );
  test('latest filter wins even if an old request finishes later', () async {
    final delayed = DelayedIncidents();
    final list = IncidentListCubit(delayed, orderId: '42');
    addTearDown(list.close);
    final first = list.refresh();
    final second = list.filter('Resolved');
    delayed.reads[1].complete(
      ResultPage([incident(id: '9', status: 'Resolved')], 1, 1, false),
    );
    await second;
    delayed.reads[0].complete(ResultPage([incident()], 1, 1, false));
    await first;
    expect(list.state.status, 'Resolved');
    expect(list.state.data!.items.single.id, '9');
    expect(delayed.queries.every((q) => q.order == '42'), true);
  });
  test(
    'pagination deduplicates moving page boundaries and preserves filter',
    () async {
      final delayed = DelayedIncidents();
      final list = IncidentListCubit(delayed);
      addTearDown(list.close);
      final first = list.filter('Open');
      delayed.reads[0].complete(ResultPage([incident(id: '9')], 1, 3, true));
      await first;
      final second = list.more();
      await list.more(); // An overlapping tap must not request another page.
      expect(delayed.queries.last, (page: 2, order: null, status: 'Open'));
      expect(delayed.reads, hasLength(2));
      delayed.reads[1].complete(
        ResultPage([incident(id: '9'), incident(id: '8')], 2, 3, false),
      );
      await second;
      expect(list.state.data!.items.map((e) => e.id), ['9', '8']);
    },
  );
}
