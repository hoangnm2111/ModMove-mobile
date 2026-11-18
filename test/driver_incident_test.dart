import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_api.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_location_source.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/api_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/usecases/driver_trip_actions.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/active_trip_bloc.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/trip_components.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/trip_contact_actions.dart';

import 'driver_backend_test.dart' show FakeBackend;

class _Here implements DriverLocationSource {
  GpsSample get _sample => GpsSample(const GeoPoint(10.7769, 106.7009), at: DateTime.now());
  @override
  Future<GpsSample?> current() async => _sample;
  @override
  Stream<GpsSample> watch() => Stream.value(_sample);
}

class _NoPhotos implements CargoPhotoRepository {
  @override
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source) async => null;
}

TripIncident _incident({bool byYou = true, IncidentStatus status = IncidentStatus.open, String? decision}) => TripIncident(
  id: 21,
  orderId: 7,
  orderCode: 'MM1',
  type: IncidentType.vehicleBreakdown,
  description: 'Xe hỏng',
  reportedByYou: byYou,
  status: status,
  decision: decision,
  createdAt: DateTime(2026, 11, 11),
);

({ApiDriverTripRepository repo, FakeBackend backend}) _repo() {
  final backend = FakeBackend();
  final api = DriverApi(
    ApiClient(
      sessions: MemorySessionStore(const Session(accessToken: 'a', refreshToken: 'r', userId: 5, fullName: 'T', role: 'Driver')),
      client: MockClient(backend.handle),
      baseUrl: 'http://test/api',
    ),
  );
  final repo = ApiDriverTripRepository(
    api: api,
    location: _Here(),
    access: const DriverAccess(approved: true, active: true),
    pollInterval: const Duration(hours: 1),
  );
  return (repo: repo, backend: backend);
}

Future<void> _acceptTrip(ApiDriverTripRepository repo) async {
  repo.onSessionChanged(isDriver: true);
  await repo.refresh();
  await repo.openOffer('7');
  await repo.acceptOffer('7');
  await repo.arrive();
}

void main() {
  group('mô hình sự cố', () {
    test('chỉ sự cố do tài xế báo còn mở mới chặn chuyến', () {
      expect(_incident().blocksTrip, isTrue);
      expect(_incident(status: IncidentStatus.inProgress).blocksTrip, isTrue);
      expect(_incident(byYou: false).blocksTrip, isFalse);
      expect(_incident(status: IncidentStatus.resolved, decision: 'ContinueTrip').blocksTrip, isFalse);
      expect(_incident(status: IncidentStatus.cancelled).blocksTrip, isFalse);
    });

    test('chuyến phân biệt sự cố chặn và sự cố của khách', () {
      final job = DeliveryJob(
        id: '7',
        pickup: 'A',
        dropoff: 'B',
        pickupPoint: const GeoPoint(0, 0),
        dropoffPoint: const GeoPoint(0, 0),
        createdAt: DateTime(2026),
      );
      expect(ActiveTrip(job: job, incidents: [_incident(byYou: false)]).blockingIncident, isNull);
      expect(ActiveTrip(job: job, incidents: [_incident(byYou: false)]).customerOpenIncident, isNotNull);
      expect(ActiveTrip(job: job, incidents: [_incident()]).blockingIncident?.id, 21);
    });

    test('kết quả hủy đơn hướng dẫn đưa hàng về điểm lấy', () {
      const outcome = IncidentOutcome(
        IncidentOutcomeKind.orderCancelled,
        orderCode: 'MM1',
        note: 'Hủy do sự cố. [Cargo: ReturnToPickup]',
      );
      expect(outcome.title, contains('MM1'));
      expect(outcome.message, contains('Hủy do sự cố.'));
      expect(outcome.message, contains('đưa hàng về điểm lấy'));
      expect(outcome.message, isNot(contains('[Cargo')));
    });
  });

  group('với BE', () {
    test('báo sự cố gửi đúng nội dung và chuyến bị khóa; bước tiếp theo bị BE từ chối với câu riêng cho tài xế', () async {
      final env = _repo();
      addTearDown(env.repo.close);
      env.repo.onSessionChanged(isDriver: true);
      await env.repo.refresh();
      await env.repo.openOffer('7');
      await env.repo.acceptOffer('7');

      final id = await env.repo.reportIncident(
        IncidentDraft(
          type: IncidentType.vehicleBreakdown,
          description: '  Xe hỏng giữa đường  ',
          photos: [CargoPhoto(kind: CargoPhotoKind.overall, name: 'x.png', bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]))],
        ),
      );
      expect(id, 21);
      final body = env.backend.bodies['post /driver/incidents'] as Map;
      expect(body['incidentType'], 'VehicleBreakdown');
      expect(body['description'], 'Xe hỏng giữa đường');
      expect((body['photoUrls'] as List).single, contains('cloudinary'));
      expect(body['latitude'], 10.7769);

      final trip = env.repo.current.trip!;
      expect(trip.blockingIncident?.status, IncidentStatus.open);
      expect(env.repo.current.notice, contains('tạm dừng'));

      // Gọi một bước khi đang có sự cố mở: BE trả 422 INCIDENT_PENDING (ở màn cũ).
      await expectLater(
        env.repo.arrive(),
        throwsA(isA<TripFailure>().having((e) => e.message, 'message', 'Bạn đang có sự cố chờ điều phối viên xử lý.')),
      );
    });

    test('mô tả trống không được gửi', () async {
      final env = _repo();
      addTearDown(env.repo.close);
      await _acceptTrip(env.repo);
      await expectLater(env.repo.reportIncident(const IncidentDraft(type: IncidentType.other, description: '   ')), throwsA(isA<TripFailure>()));
      expect(env.backend.requests, isNot(contains('post /driver/incidents')));
    });

    test('điều phối viên cho tiếp tục chuyến: sự cố đóng và tài xế nhận kết quả một lần', () async {
      final env = _repo();
      addTearDown(env.repo.close);
      await _acceptTrip(env.repo);
      await env.repo.reportIncident(const IncidentDraft(type: IncidentType.other, description: 'Kẹt xe'));
      expect(env.repo.current.trip!.blockingIncident, isNotNull);

      env.backend.incidents.first['resolutionStatus'] = 'InProgress';
      await env.repo.refresh();
      expect(env.repo.current.trip!.blockingIncident?.status, IncidentStatus.inProgress);

      env.backend.incidents.first
        ..['resolutionStatus'] = 'Resolved'
        ..['resolutionDecision'] = 'ContinueTrip'
        ..['resolutionNote'] = 'Đã kiểm tra, đi tiếp.';
      await env.repo.refresh();
      expect(env.repo.current.trip!.blockingIncident, isNull);
      final outcome = env.repo.current.incidentOutcome!;
      expect(outcome.kind, IncidentOutcomeKind.continueTrip);
      expect(outcome.note, 'Đã kiểm tra, đi tiếp.');
      env.repo.acknowledgeOutcome();
      expect(env.repo.current.incidentOutcome, isNull);
    });

    test('đổi tài xế: đơn rời khỏi tài xế cũ (204) và quyết định được đọc từ api/driver/incidents', () async {
      final env = _repo();
      addTearDown(env.repo.close);
      await _acceptTrip(env.repo);
      await env.repo.reportIncident(const IncidentDraft(type: IncidentType.vehicleBreakdown, description: 'Hỏng xe'));
      env.backend.incidents.first
        ..['resolutionStatus'] = 'Resolved'
        ..['resolutionDecision'] = 'ReassignDriver'
        ..['resolutionNote'] = 'Đã chuyển sang tài xế gần nhất.'
        ..['resolvedAt'] = '2026-11-11T14:10:00+00:00';
      env.backend.activeGone = true;
      await env.repo.refresh();
      expect(env.repo.current.trip, isNull);
      expect(env.repo.current.incidentOutcome?.kind, IncidentOutcomeKind.reassignedAway);
      expect(env.repo.current.incidentOutcome?.note, contains('tài xế gần nhất'));
    });

    test('sự cố do khách báo chỉ nhắc: không khóa các bước', () async {
      final env = _repo();
      addTearDown(env.repo.close);
      await _acceptTrip(env.repo);
      env.backend.incidents.add({
        'id': 30,
        'incidentType': 'Other',
        'description': 'Khách hàng báo cáo sự cố, Điều phối viên đang xử lý.',
        'photoUrls': [],
        'reportedByYou': false,
        'resolutionStatus': 'Open',
        'createdAt': '2026-11-11T14:00:00+00:00',
      });
      await env.repo.refresh();
      final trip = env.repo.current.trip!;
      expect(trip.blockingIncident, isNull);
      expect(trip.customerOpenIncident?.id, 30);
      expect(trip.customerOpenIncident?.photoUrls, isEmpty);
    });
  });

  group('giao diện', () {
    test('khóa bước đến nơi khi có sự cố mở của tài xế; sự cố khách không khóa', () async {
      Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));
      final mock = MockDriverTripRepository(delay: Duration.zero, autoOffer: false);
      addTearDown(mock.close);
      await mock.setOnline(true);
      await mock.openOffer(mock.current.jobs.first.id);
      await mock.acceptOffer(mock.current.jobs.first.id);
      await mock.simulate(TripSimulation.nearPickup);
      final bloc = ActiveTripBloc(DriverTripActions(mock), const _NoContact());
      addTearDown(bloc.close);
      await settle();
      expect(bloc.state.canArrive, isTrue);

      await mock.reportIncident(const IncidentDraft(type: IncidentType.other, description: 'Kẹt xe'));
      await settle();
      expect(bloc.state.paused, isTrue);
      expect(bloc.state.canArrive, isFalse);

      await mock.simulate(TripSimulation.dispatcherStarts);
      await settle();
      expect(bloc.state.blockingIncident?.status, IncidentStatus.inProgress);

      await mock.simulate(TripSimulation.dispatcherContinues);
      await settle();
      expect(bloc.state.paused, isFalse);
      expect(bloc.state.canArrive, isTrue);
      expect(mock.current.incidentOutcome?.kind, IncidentOutcomeKind.continueTrip);

      await mock.simulate(TripSimulation.customerReportsIncident);
      await settle();
      expect(bloc.state.paused, isFalse);
      expect(bloc.state.customerIncident, isNotNull);
    });

    testWidgets('banner hiện đúng chữ theo trạng thái sự cố', (tester) async {
      final job = DeliveryJob(
        id: '7',
        pickup: 'A',
        dropoff: 'B',
        pickupPoint: const GeoPoint(0, 0),
        dropoffPoint: const GeoPoint(0, 0),
        createdAt: DateTime(2026),
      );
      Future<void> show(ActiveTrip trip) async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: IncidentBanner(trip))));
        await tester.pump();
      }

      await show(ActiveTrip(job: job, incidents: [_incident()]));
      expect(find.textContaining('Đang chờ điều phối viên'), findsOneWidget);
      await show(ActiveTrip(job: job, incidents: [_incident(status: IncidentStatus.inProgress)]));
      expect(find.textContaining('Điều phối viên đang xử lý sự cố #21'), findsOneWidget);
      await show(ActiveTrip(job: job, incidents: [_incident(byYou: false)]));
      expect(find.byKey(const Key('incident-banner-customer')), findsOneWidget);
      expect(find.byKey(const Key('incident-banner-blocking')), findsNothing);
    });

    testWidgets('form báo sự cố: mô tả trống không gửi, có cảnh báo tạm dừng, lý do nhanh điền câu mở đầu', (tester) async {
      IncidentDraft? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<IncidentDraft>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => IncidentFormSheet(photos: _NoPhotos(), latitude: 10.7, longitude: 106.7),
                    );
                  },
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(find.textContaining('chuyến sẽ tạm dừng'), findsOneWidget);

      await tester.ensureVisible(find.text('Gửi sự cố'));
      await tester.tap(find.text('Gửi sự cố'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập mô tả sự cố.'), findsOneWidget);
      expect(result, isNull);

      // Không còn nút "Lý do nhanh" và không tự điền câu: mô tả để trống cho tài xế tự viết, dữ liệu gửi đi là đúng chữ họ nhập.
      expect(find.text('Lý do nhanh'), findsNothing);
      final field = tester.widget<TextField>(find.byKey(const Key('incident-description')));
      expect(field.controller!.text, isEmpty);
      // Vẫn chọn được đúng 4 loại của BE.
      expect(find.byKey(const ValueKey('incident-type-Other')), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-type-Accident')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('incident-description')), 'Khách vắng mặt tại điểm lấy 15 phút');
      await tester.ensureVisible(find.text('Gửi sự cố'));
      await tester.tap(find.text('Gửi sự cố'));
      await tester.pumpAndSettle();
      expect(result?.type, IncidentType.other);
      expect(result?.description, 'Khách vắng mặt tại điểm lấy 15 phút');
      expect(result?.latitude, 10.7);
    });
  });
}

class _NoContact implements TripContactRepository {
  const _NoContact();
  @override
  Future<bool> callCustomer(String phone) async => true;
  @override
  Future<bool> openNavigation(GeoPoint destination) async => true;
}
