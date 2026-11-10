import '../../../core/domain/result_page.dart';
import '../../../core/network/api_client.dart';
import '../../driver_trip/domain/entities/trip_models.dart';
import '../../driver_trip/domain/usecases/validate_cargo_photo.dart';
import '../domain/driver_incident_repository.dart';

class RemoteDriverIncidentRepository implements DriverIncidentRepository {
  const RemoteDriverIncidentRepository(this.api);
  final ApiClient api;
  Future<T> _read<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiFailure catch (e) {
      throw IncidentFailure(
        e.status == 404
            ? 'Không tìm thấy sự cố hoặc bạn không có quyền xem.'
            : e.message,
        status: e.status,
      );
    }
  }

  @override
  Future<ResultPage<DriverIncident>> list({
    int page = 1,
    String? orderId,
    String? status,
  }) => _read(() async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'pageSize': '20',
        'orderId': ?orderId,
        'status': ?status,
      },
    ).query;
    final json =
        await api.request('GET', '/api/driver/incidents?$query') as Map;
    return ResultPage(
      [for (final row in json['items'] as List) _parse(row as Map)],
      (json['pageNumber'] as num).toInt(),
      (json['totalCount'] as num).toInt(),
      json['hasNextPage'] == true,
    );
  });
  @override
  Future<DriverIncident> detail(String id) => _read(
    () async => _parse(
      await api.request(
            'GET',
            '/api/driver/incidents/${Uri.encodeComponent(id)}',
          )
          as Map,
    ),
  );
  @override
  Future<String> upload(CargoPhoto photo) => _read(() async {
    const ValidateCargoPhoto()(photo);
    final json =
        await api.upload('/api/driver/uploads', photo.name, photo.bytes) as Map;
    return json['url'] as String;
  });
  @override
  Future<String> report(IncidentReport report) async {
    report.validate();
    try {
      final result =
          await api.request(
                'POST',
                '/api/driver/incidents',
                body: {
                  'orderId': int.parse(report.orderId),
                  'incidentType': report.type.api,
                  'description': report.description.trim(),
                  'photoUrls': report.photos,
                  if (report.location != null) ...{
                    'latitude': report.location!.latitude,
                    'longitude': report.location!.longitude,
                  },
                },
              )
              as Map;
      final id = result['incidentId']?.toString();
      if (id == null || (int.tryParse(id) ?? 0) < 1) {
        throw const IncidentFailure(
          'Chưa xác nhận được mã sự cố. Hãy kiểm tra danh sách trước khi gửi lại.',
          uncertain: true,
        );
      }
      return id;
    } on ApiFailure catch (e) {
      throw IncidentFailure(
        e.code == 'INCIDENT_NOT_ALLOWED'
            ? 'Chỉ báo sự cố từ lúc nhận đơn đến trước khi giao hàng xong.'
            : e.message,
        uncertain: e.status == 0 || e.status >= 500,
        status: e.status,
      );
    }
  }

  DriverIncident _parse(Map json) {
    final mine = json['reportedByYou'] == true;
    // Respect customer-report privacy even if a future response includes extra fields.
    return DriverIncident(
      id: '${json['id']}',
      orderId: '${json['orderId']}',
      orderCode: '${json['orderCode']}',
      orderStatus: '${json['orderStatus']}',
      type: '${json['incidentType']}',
      description: mine
          ? '${json['description']}'
          : 'Khách hàng báo cáo sự cố, Điều phối viên đang xử lý.',
      photos: mine
          ? List<String>.unmodifiable(json['photoUrls'] as List? ?? [])
          : const [],
      location: mine && json['latitude'] != null && json['longitude'] != null
          ? GeoPoint(
              (json['latitude'] as num).toDouble(),
              (json['longitude'] as num).toDouble(),
            )
          : null,
      reportedByYou: mine,
      status: '${json['resolutionStatus']}',
      decision: json['resolutionDecision'] as String?,
      note: json['resolutionNote'] as String?,
      createdAt: DateTime.parse('${json['createdAt']}'),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse('${json['resolvedAt']}'),
    );
  }
}
