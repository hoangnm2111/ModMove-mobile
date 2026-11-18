import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/usecases/validate_driver_application.dart';
import '../models/driver_application_dto.dart';
import 'profile_mock_store.dart';

/// In-process HTTP transport: real Request/Response + JSON, no listening server.
/// The endpoints are a proposed demo contract, not an existing backend API.
class MockDriverApi {
  MockDriverApi({
    DriverApplication? initial,
    Map<String, dynamic>? restored,
    this.store,
    this.latency = const Duration(milliseconds: 450),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _database = restored ?? _seed(initial ?? freshApplication());
    if (_database['schema'] != 1) {
      throw const FormatException('Unsupported mock profile schema');
    }
    client = MockClient(_handle);
    DriverApplicationDto.fromJson(_profile);
  }

  final ProfileMockStore? store;
  final Duration latency;
  final DateTime Function() _now;
  late final http.Client client;
  late Map<String, dynamic> _database;
  Future<void> _queue = Future.value();
  String? _failure;
  final List<String> requests = [];

  DriverApplication get cachedApplication =>
      DriverApplicationDto.fromJson(_profile);
  Map<String, dynamic> get _profile =>
      _database['profile'] as Map<String, dynamic>;
  List<dynamic> get _history => _database['history'] as List;
  Map<String, dynamic> get _uploads =>
      _database['uploads'] as Map<String, dynamic>;
  Map<String, dynamic> get _receipts =>
      _database['receipts'] as Map<String, dynamic>;

  static DriverApplication freshApplication({bool complete = false}) =>
      DriverApplication(
        status: ApprovalStatus.draft,
        fields: {
          'fullName': 'Nguyễn Minh Anh',
          'phone': '0901234678',
          'vehicleType': 'Xe tải 1 tấn',
          'plate': complete ? '29C-123.45' : '',
          'payload': complete ? '1000' : '',
          'length': complete ? '3,1' : '',
          'width': complete ? '1,6' : '',
          'height': complete ? '1,6' : '',
        },
        documents: {
          for (final kind in DocumentKind.values)
            kind: VerificationDocument(
              remoteReference: complete ? 'seed://${kind.name}' : null,
            ),
        },
      );

  static Map<String, dynamic> _seed(DriverApplication application) => {
    'schema': 1,
    'profile': DriverApplicationDto.toJson(application),
    'history': application.version > 0
        ? [DriverApplicationDto.toJson(application)]
        : <dynamic>[],
    'uploads': {
      for (final entry in application.documents.entries)
        if (entry.value.remoteReference != null)
          entry.value.remoteReference!: {
            'kind': entry.key.name,
            ...DriverApplicationDto.documentToJson(entry.value),
          },
    },
    'receipts': <String, dynamic>{},
    'nextUpload': 1,
  };

  Future<http.Response> _handle(http.Request request) async {
    await Future<void>.delayed(latency);
    final response = Completer<http.Response>();
    // Serialize validation + mutation + disk save to model an atomic server transaction.
    _queue = _queue.then((_) async {
      final before = jsonEncode(_database);
      var status = 200;
      Object body;
      try {
        final input = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        body = _route(request, input);
        if (request.method != 'GET') await store?.write(_database);
      } on _ApiFailure catch (error) {
        _database = jsonDecode(before) as Map<String, dynamic>;
        status = error.status;
        body = {'message': error.message};
      } catch (_) {
        _database = jsonDecode(before) as Map<String, dynamic>;
        status = 500;
        body = {
          'message': 'Không lưu được dữ liệu mô phỏng. Vui lòng thử lại.',
        };
      }
      requests.add(
        '${_now().toIso8601String()} ${request.method} ${request.url.path} → $status',
      );
      if (requests.length > 30) requests.removeAt(0);
      response.complete(
        http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
    });
    return response.future;
  }

  Object _route(http.Request request, Map<String, dynamic> body) {
    final path = request.url.path;
    final operation = switch ((request.method, path)) {
      ('GET', '/v1/driver/application') => 'load',
      ('PUT', '/v1/driver/draft') => 'save',
      ('POST', '/v1/driver/documents') => 'upload',
      ('POST', '/v1/driver/applications') => 'submit',
      ('PATCH', '/v1/driver/availability') => 'availability',
      _ => null,
    };
    if (operation != null && _failure == operation) {
      _failure = null;
      throw const _ApiFailure(
        503,
        'Kết nối mô phỏng bị gián đoạn. Dữ liệu vẫn được giữ; hãy thử lại.',
      );
    }
    if (request.method == 'GET' && path == '/v1/driver/application') {
      return _profile;
    }
    if (request.method == 'GET' && path == '/v1/driver/applications') {
      return {'items': _history.reversed.toList()};
    }

    if (request.method == 'POST' && path == '/v1/demo/failure') {
      _failure = body['operation'] as String?;
      return {'ok': true};
    }
    if (request.method == 'POST' && path == '/v1/demo/reset') {
      _database = _seed(
        freshApplication(complete: body['completeDraft'] == true),
      );
      _failure = null;
      return _profile;
    }
    if (request.method == 'POST' && path == '/v1/demo/account') {
      _profile['accountActive'] = body['active'] == true;
      if (_profile['accountActive'] == false) _profile['online'] = false;
      return _profile;
    }
    if (request.method == 'POST' && path == '/v1/demo/review') {
      return _review(body);
    }
    if (request.method == 'PATCH' && path == '/v1/driver/availability') {
      final value = body['online'] == true;
      if (value && !cachedApplication.canGoOnline) {
        throw const _ApiFailure(
          403,
          'Chỉ hồ sơ đã duyệt và tài khoản đang hoạt động mới được trực tuyến.',
        );
      }
      _profile['online'] = value;
      return _profile;
    }
    if (request.method == 'POST' && path == '/v1/driver/documents') {
      return _upload(body);
    }
    if (request.method == 'PUT' && path == '/v1/driver/draft') {
      final candidate = _editableCandidate(body);
      _profile['fields'] = candidate['fields'];
      _profile['documents'] = candidate['documents'];
      return _profile;
    }
    if (request.method == 'POST' && path == '/v1/driver/applications') {
      return _submit(body, request.headers['idempotency-key']);
    }
    throw const _ApiFailure(404, 'Không có endpoint mô phỏng này.');
  }

  Map<String, dynamic> _editableCandidate(Map<String, dynamic> body) {
    if (!cachedApplication.canEdit) {
      throw const _ApiFailure(
        409,
        'Hồ sơ đang chờ duyệt hoặc đã được duyệt. Vui lòng tải lại trạng thái.',
      );
    }
    if (body['version'] != _profile['version']) {
      throw const _ApiFailure(
        409,
        'Phiên bản hồ sơ đã thay đổi. Vui lòng tải lại.',
      );
    }
    final candidate = DriverApplicationDto.toJson(
      DriverApplicationDto.fromJson(body),
    );
    final previous =
        (_profile['status'] == 'rejected' && _history.isNotEmpty
                ? (_history.last as Map)['documents']
                : _profile['documents'])
            as Map;
    final incoming = candidate['documents'] as Map;
    for (final kind in DocumentKind.values) {
      final old = previous[kind.name] as Map;
      final next = incoming[kind.name] as Map;
      // Decision flags are server-owned, never trusted from the client.
      next['accepted'] = old['accepted'];
      next['rejectionReason'] = old['rejectionReason'];
      next['replaced'] = old['rejectionReason'] != null
          ? next['reference'] != null && next['reference'] != old['reference']
          : next['replaced'];
    }
    return candidate;
  }

  Map<String, dynamic> _upload(Map<String, dynamic> body) {
    final kind = DocumentKind.values.byName(body['kind'] as String);
    if (!cachedApplication.canEditDocument(kind)) {
      throw const _ApiFailure(403, 'Giấy tờ này đang được khóa.');
    }
    final bytes = base64Decode(body['bytes'] as String);
    final name = body['fileName'] as String;
    final error = const ValidateDriverApplication().image(name, bytes);
    if (error != null) throw _ApiFailure(422, error);
    final reference = 'mock://documents/${_database['nextUpload']}';
    _database['nextUpload'] = (_database['nextUpload'] as int) + 1;
    final document = {
      'reference': reference,
      'fileName': name,
      'bytes': body['bytes'],
      'accepted': false,
      'replaced': true,
      'rejectionReason':
          (_profile['documents'] as Map)[kind.name]['rejectionReason'],
    };
    _uploads[reference] = {'kind': kind.name, ...document};
    return document;
  }

  Object _submit(Map<String, dynamic> body, String? key) {
    if (key == null || key.isEmpty) {
      throw const _ApiFailure(400, 'Thiếu mã chống gửi trùng.');
    }
    if (_receipts.containsKey(key)) {
      final saved = _receipts[key] as Map;
      if (saved['request'] != jsonEncode(body)) {
        throw const _ApiFailure(409, 'Mã yêu cầu đã dùng cho dữ liệu khác.');
      }
      return saved['receipt']!;
    }
    final candidate = _editableCandidate(body);
    final application = DriverApplicationDto.fromJson(candidate);
    const validation = ValidateDriverApplication();
    if (validation.vehicle(application.fields).isNotEmpty) {
      throw const _ApiFailure(422, 'Vui lòng kiểm tra thông tin hồ sơ.');
    }
    // Deterministic duplicate data case available for a classroom demo.
    if (application.fields['plate']?.toUpperCase() == '99C-999.99') {
      throw const _ApiFailure(409, 'Biển số đã có trong dữ liệu mô phỏng.');
    }
    if (validation.missingDocuments(application).isNotEmpty) {
      throw const _ApiFailure(
        422,
        'Vui lòng bổ sung hoặc thay đủ ảnh được yêu cầu.',
      );
    }
    for (final entry in application.documents.entries) {
      final upload = _uploads[entry.value.remoteReference];
      if (upload == null || (upload as Map)['kind'] != entry.key.name) {
        throw const _ApiFailure(
          422,
          'Ảnh chưa tải lên thành công hoặc không đúng loại giấy tờ.',
        );
      }
      final document = (candidate['documents'] as Map)[entry.key.name] as Map;
      document['bytes'] = upload['bytes'];
      document['fileName'] = upload['fileName'];
    }
    candidate['status'] = 'pending';
    candidate['version'] = (_profile['version'] as int) + 1;
    candidate['accountActive'] = _profile['accountActive'];
    candidate['online'] = false;
    candidate['submittedAt'] = _now().toUtc().toIso8601String();
    candidate['reviewedAt'] = null;
    _database['profile'] = candidate;
    _history.add(jsonDecode(jsonEncode(candidate)));
    final receipt = {
      'version': candidate['version'],
      'submittedAt': candidate['submittedAt'],
    };
    _receipts[key] = {'request': jsonEncode(body), 'receipt': receipt};
    return receipt;
  }

  Object _review(Map<String, dynamic> body) {
    if (_profile['status'] != 'pending' ||
        body['expectedVersion'] != _profile['version']) {
      throw const _ApiFailure(409, 'Chỉ xét duyệt đúng phiên bản đang chờ.');
    }
    final decision = body['decision'];
    if (decision != 'approved' && decision != 'rejected') {
      throw const _ApiFailure(422, 'Quyết định không hợp lệ.');
    }
    _profile['status'] = decision;
    _profile['reviewedAt'] = _now().toUtc().toIso8601String();
    _profile['online'] = false;
    final documents = _profile['documents'] as Map;
    for (final kind in DocumentKind.values) {
      final document = documents[kind.name] as Map;
      final rejected =
          decision == 'rejected' &&
          (kind == DocumentKind.licenseBack || kind == DocumentKind.inspection);
      document['accepted'] = !rejected;
      document['replaced'] = false;
      document['rejectionReason'] = !rejected
          ? null
          : kind == DocumentKind.licenseBack
          ? 'Ảnh bị mờ, vui lòng chụp lại.'
          : 'Giấy tờ hết hạn, vui lòng cập nhật.';
    }
    final index = _history.indexWhere(
      (item) => (item as Map)['version'] == _profile['version'],
    );
    _history[index] = jsonDecode(jsonEncode(_profile));
    return _profile;
  }

  void close() => client.close();
}

class _ApiFailure implements Exception {
  const _ApiFailure(this.status, this.message);
  final int status;
  final String message;
}
