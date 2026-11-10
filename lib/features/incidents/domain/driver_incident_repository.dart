import '../../../core/domain/result_page.dart';
import '../../driver_trip/domain/entities/trip_models.dart';

enum IncidentType { vehicleBreakdown, damagedCargo, accident, other }

extension IncidentTypeApi on IncidentType {
  String get api => switch (this) {
    IncidentType.vehicleBreakdown => 'VehicleBreakdown',
    IncidentType.damagedCargo => 'DamagedCargo',
    IncidentType.accident => 'Accident',
    IncidentType.other => 'Other',
  };
}

class DriverIncident {
  const DriverIncident({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.orderStatus,
    required this.type,
    required this.description,
    required this.photos,
    required this.reportedByYou,
    required this.status,
    required this.createdAt,
    this.decision,
    this.note,
    this.resolvedAt,
    this.location,
  });
  final String id, orderId, orderCode, orderStatus, type, description, status;
  final List<String> photos;
  final bool reportedByYou;
  final String? decision, note;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final GeoPoint? location;
  bool get closed => status == 'Resolved' || status == 'Cancelled';
}

class IncidentReport {
  const IncidentReport({
    required this.orderId,
    required this.type,
    required this.description,
    this.photos = const [],
    this.location,
  });
  final String orderId, description;
  final IncidentType type;
  final List<String> photos;
  final GeoPoint? location;
  void validate() {
    if ((int.tryParse(orderId) ?? 0) < 1 ||
        description.trim().isEmpty ||
        description.trim().length > 1000) {
      throw const IncidentFailure(
        'Chọn chuyến và nhập mô tả từ 1 đến 1.000 ký tự.',
      );
    }
    if (photos.length > 5 ||
        photos.toSet().length != photos.length ||
        photos.any((url) => !url.startsWith('https://'))) {
      throw const IncidentFailure(
        'Chọn tối đa 5 ảnh khác nhau đã tải lên thành công.',
      );
    }
  }

  bool matches(DriverIncident item) =>
      item.reportedByYou &&
      item.orderId == orderId &&
      item.type == type.api &&
      item.description.trim() == description.trim() &&
      item.photos.length == photos.length &&
      item.photos.toSet().containsAll(photos);
}

class IncidentFailure implements Exception {
  const IncidentFailure(
    this.message, {
    this.uncertain = false,
    this.status = 0,
  });
  final String message;
  final bool uncertain;
  final int status;
}

abstract interface class DriverIncidentRepository {
  Future<ResultPage<DriverIncident>> list({
    int page = 1,
    String? orderId,
    String? status,
  });
  Future<DriverIncident> detail(String id);
  Future<String> upload(CargoPhoto photo);
  Future<String> report(IncidentReport report);
}
