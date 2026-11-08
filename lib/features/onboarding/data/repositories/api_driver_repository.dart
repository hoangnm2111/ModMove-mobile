import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../domain/entities/driver_application.dart';
import '../../domain/repositories/driver_repository.dart';
import '../models/driver_application_dto.dart';

class ApiDriverRepository
    implements DriverProfileRepository, DriverReviewSimulator {
  ApiDriverRepository({
    required this._client,
    required this._cached,
    this.baseUrl = 'https://mock.modmove.local/v1',
  });
  final http.Client _client;
  final String baseUrl;
  DriverApplication _cached;
  String? _submissionBody, _submissionKey;
  int _sequence = 0;
  final String _clientId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    String? requestKey,
  ]) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers['content-type'] = 'application/json';
      if (requestKey != null) request.headers['idempotency-key'] = requestKey;
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 15));
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApplicationFailure(
          decoded['message'] as String? ?? 'Yêu cầu chưa thành công.',
        );
      }
      return decoded;
    } on ApplicationFailure {
      rethrow;
    } catch (_) {
      throw const ApplicationFailure(
        'Không kết nối được. Vui lòng thử lại; dữ liệu đã nhập vẫn được giữ.',
      );
    }
  }

  @override
  DriverApplication loadCachedApplication() => _cached;
  @override
  Future<DriverApplication> refresh() async =>
      _cached = DriverApplicationDto.fromJson(
        await _request('GET', '/driver/application'),
      );
  @override
  Future<DriverApplication> saveDraft(DriverApplication application) async =>
      _cached = DriverApplicationDto.fromJson(
        await _request(
          'PUT',
          '/driver/draft',
          DriverApplicationDto.toJson(application),
        ),
      );
  @override
  Future<VerificationDocument> upload(
    DocumentKind kind,
    SelectedPhoto photo,
  ) async => DriverApplicationDto.documentFromJson(
    await _request('POST', '/driver/documents', {
      'kind': kind.name,
      'fileName': photo.name,
      'bytes': base64Encode(photo.bytes),
    }),
  );

  @override
  Future<ApplicationReceipt> submit(DriverApplication application) async {
    final body = DriverApplicationDto.toJson(application);
    final encoded = jsonEncode(body);
    if (_submissionBody != encoded) {
      _submissionBody = encoded;
      _submissionKey = 'profile-$_clientId-${++_sequence}';
    }
    final result = await _request(
      'POST',
      '/driver/applications',
      body,
      _submissionKey,
    );
    final receipt = ApplicationReceipt(
      result['version'] as int,
      DateTime.parse(result['submittedAt'] as String).toLocal(),
    );
    _cached = DriverApplicationDto.fromJson({
      ...body,
      'status': 'pending',
      'version': receipt.version,
      'submittedAt': result['submittedAt'],
      'reviewedAt': null,
      'online': false,
    });
    return receipt;
  }

  @override
  Future<DriverApplication> setAvailability(bool online) async =>
      _cached = DriverApplicationDto.fromJson(
        await _request('PATCH', '/driver/availability', {'online': online}),
      );
  @override
  Future<List<DriverApplication>> history() async {
    final response = await _request('GET', '/driver/applications');
    return (response['items'] as List)
        .map(
          (item) => DriverApplicationDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> review(ApprovalStatus decision, int expectedVersion) async {
    await _request('POST', '/demo/review', {
      'decision': decision.name,
      'expectedVersion': expectedVersion,
    });
  }

  @override
  Future<void> failNext(String operation) async {
    await _request('POST', '/demo/failure', {'operation': operation});
  }

  @override
  Future<void> setAccountActive(bool active) async {
    await _request('POST', '/demo/account', {'active': active});
  }

  @override
  Future<void> reset({bool completeDraft = false}) async {
    await _request('POST', '/demo/reset', {'completeDraft': completeDraft});
    _submissionBody = null;
    _submissionKey = null;
  }

  void close() => _client.close();
}
