import 'dart:async';
import 'dart:typed_data';
import 'package:modmove_mobile/core/domain/result_page.dart';
import 'package:modmove_mobile/features/driver_trip/data/models/driver_trip_dto.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/incidents/domain/driver_incident_repository.dart';
import 'remote_fixtures.dart';

final incidentTime = DateTime.utc(2026, 11, 11, 3, 15);
Map<String, dynamic> incidentJson({int id = 6, bool mine = true}) => {
  'id': id,
  'orderId': 42,
  'orderCode': 'MM0042',
  'orderStatus': 'InTransit',
  'incidentType': 'VehicleBreakdown',
  'description': 'Xe bị thủng lốp, cần hỗ trợ.',
  'photoUrls': ['https://images.test/evidence.png'],
  'latitude': 10.73,
  'longitude': 106.7,
  'reportedByYou': mine,
  'resolutionStatus': 'InProgress',
  'resolutionDecision': null,
  'resolutionNote': 'Điều phối đã nhận thông tin.',
  'createdAt': incidentTime.toIso8601String(),
  'resolvedAt': null,
};
DriverIncident incident({
  String id = '6',
  String status = 'InProgress',
  String? decision,
  String? note,
  IncidentReport? from,
}) => DriverIncident(
  id: id,
  orderId: from?.orderId ?? '42',
  orderCode: 'MM0042',
  orderStatus: 'InTransit',
  type: from?.type.api ?? 'VehicleBreakdown',
  description: from?.description ?? 'Xe bị thủng lốp, cần hỗ trợ.',
  photos: from?.photos ?? [],
  reportedByYou: true,
  status: status,
  createdAt: incidentTime,
  decision: decision,
  note: note ?? 'Điều phối đã nhận thông tin.',
  resolvedAt: status == 'Resolved'
      ? incidentTime.add(const Duration(minutes: 12))
      : null,
  location: from?.location,
);

class IncidentTestRepository implements DriverIncidentRepository {
  List<DriverIncident> items = [incident()];
  List<({int page, String? order, String? status})> queries = [];
  List<IncidentReport> reports = [];
  int uploads = 0;
  Object? listError, detailError, uploadError, reportError;
  bool saveBeforeFailure = false;
  @override
  Future<ResultPage<DriverIncident>> list({
    int page = 1,
    String? orderId,
    String? status,
  }) async {
    queries.add((page: page, order: orderId, status: status));
    if (listError != null) throw listError!;
    final rows = items
        .where(
          (e) =>
              (orderId == null || e.orderId == orderId) &&
              (status == null || e.status == status),
        )
        .toList();
    return ResultPage(rows, page, rows.length, false);
  }

  @override
  Future<DriverIncident> detail(String id) async {
    if (detailError != null) throw detailError!;
    return items.firstWhere((e) => e.id == id);
  }

  @override
  Future<String> upload(CargoPhoto photo) async {
    uploads++;
    if (uploadError != null) throw uploadError!;
    return 'https://images.test/photo-$uploads.png';
  }

  @override
  Future<String> report(IncidentReport report) async {
    reports.add(report);
    if (reportError == null || saveBeforeFailure) {
      items.insert(0, incident(id: '7', status: 'Open', from: report));
    }
    if (reportError != null) throw reportError!;
    return '7';
  }
}

class IncidentTestTrips implements DriverTripRepository {
  final controller = StreamController<DriverSession>.broadcast(sync: true);
  @override
  DriverSession current = DriverSession(
    trip: DriverTripDto.parse(tripDetail(incidentTime, stage: 'InTransit')),
    fix: GpsFix(const GeoPoint(10.73, 106.7), incidentTime),
  );
  @override
  DateTime now = incidentTime;
  @override
  Stream<DriverSession> get changes => controller.stream;
  void update(DriverSession value) {
    current = value;
    controller.add(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class IncidentTestPicker implements CargoPhotoRepository {
  int calls = 0;
  CargoPhoto? next = photo(1);
  static CargoPhoto photo(int id) => CargoPhoto(
    kind: CargoPhotoKind.overall,
    name: 'photo-$id.png',
    bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, id]),
  );
  @override
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source) async {
    calls++;
    return next;
  }
}

class IncidentTestContact implements TripContactRepository {
  @override
  Future<bool> callCustomer(String phone) async => true;
  @override
  Future<bool> openNavigation(GeoPoint destination) async => true;
}
