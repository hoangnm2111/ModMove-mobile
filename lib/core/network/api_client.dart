import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status = 0, this.code = ''});
  final String message, code;
  final int status;
  @override
  String toString() => message;
}

abstract interface class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class ApiSession {
  const ApiSession(
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.fullName,
  );
  final String accessToken, refreshToken, userId, fullName;
  factory ApiSession.fromJson(Map<String, dynamic> json) {
    if (json['role'] != 'Driver') {
      throw const ApiFailure('Ứng dụng này dành cho tài khoản tài xế.');
    }
    return ApiSession(
      json['accessToken'] as String,
      json['refreshToken'] as String,
      '${json['userId']}',
      json['fullName'] as String,
    );
  }
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'fullName': fullName,
    'role': 'Driver',
  };
}

/// One client per session. Refresh rotation is serialized across REST and SignalR.
class ApiClient {
  ApiClient({
    required this.store,
    http.Client? client,
    String baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5133',
    ),
  }) : _http = client ?? http.Client(),
       baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '') {
    final uri = Uri.parse(this.baseUrl);
    if (!uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiFailure(
        'API_BASE_URL phải là địa chỉ server, không kèm /api.',
      );
    }
  }
  final http.Client _http;
  final SessionStore store;
  final String baseUrl;
  String get _sessionKey => 'session:$baseUrl';
  ApiSession? session;
  Future<void> _storageWrite = Future.value();
  Future<void> _persist(Future<void> Function() action) {
    final next = _storageWrite.then(
      (_) => action(),
      onError: (Object _) => action(),
    );
    _storageWrite = next;
    return next;
  }

  Future<void>? _refreshing;
  final _expired = StreamController<void>.broadcast();
  Stream<void> get expired => _expired.stream;

  Future<void> restore() async {
    final value = await store.read(_sessionKey);
    if (value != null) {
      session = ApiSession.fromJson(jsonDecode(value) as Map<String, dynamic>);
    }
  }

  Future<void> saveSession(Map<String, dynamic> json) async {
    final next = ApiSession.fromJson(json);
    session = next;
    try {
      await _persist(() => store.write(_sessionKey, jsonEncode(next.toJson())));
    } catch (_) {
      if (identical(session, next)) session = null;
      rethrow;
    }
  }

  Future<void> clearSession() async {
    session = null;
    try {
      await _persist(() => store.delete(_sessionKey));
    } finally {
      if (!_expired.isClosed) _expired.add(null);
    }
  }

  Future<String> accessToken() async {
    final token = session?.accessToken;
    if (token == null) {
      throw const ApiFailure('Vui lòng đăng nhập lại.', status: 401);
    }
    try {
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map;
      if ((claims['exp'] as num) * 1000 <
          DateTime.now().millisecondsSinceEpoch + 30000) {
        await _refresh();
      }
    } on FormatException {
      /* Test tokens may be opaque; REST still handles 401. */
    } on RangeError {
      /* See above. */
    }
    return session?.accessToken ??
        (throw const ApiFailure('Vui lòng đăng nhập lại.', status: 401));
  }

  Future<void> _refresh() async {
    final running = _refreshing;
    if (running != null) return running;
    final future = _rotate();
    _refreshing = future;
    try {
      await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _rotate() async {
    final before = session;
    if (before == null) {
      throw const ApiFailure('Vui lòng đăng nhập lại.', status: 401);
    }
    try {
      final result = await request(
        'POST',
        '/api/public/auth/refresh',
        body: {'refreshToken': before.refreshToken},
        authenticated: false,
      );
      if (identical(session, before)) {
        await saveSession(result as Map<String, dynamic>);
      }
    } on ApiFailure catch (e) {
      if (e.status == 401 || e.status == 403) await clearSession();
      rethrow;
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _send(() {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    return request;
  }, authenticated);

  Future<dynamic> upload(String path, String name, Uint8List bytes) => _send(
    () {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: name,
          contentType: http.MediaType(
            'image',
            name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg',
          ),
        ),
      );
      return request;
    },
    true,
  );

  Future<dynamic> _send(http.BaseRequest Function() build, bool auth) async {
    try {
      final userId = session?.userId;
      final token = auth ? await accessToken() : null;
      Future<http.Response> send(String? bearer) async {
        final req = build();
        req.headers['Accept'] = 'application/json';
        if (bearer != null) req.headers['Authorization'] = 'Bearer $bearer';
        return await (() async => http.Response.fromStream(
          await _http.send(req),
        ))().timeout(const Duration(seconds: 25));
      }

      var response = await send(token);
      if (response.statusCode == 401 && auth) {
        if (session == null || session!.userId != userId) {
          throw const ApiFailure(
            'Phiên đăng nhập đã thay đổi. Vui lòng thực hiện lại thao tác.',
            status: 401,
          );
        }
        if (session?.accessToken == token) await _refresh();
        response = await send(await accessToken());
        if (response.statusCode == 401) await clearSession();
      }
      dynamic json;
      if (response.bodyBytes.isNotEmpty) {
        try {
          json = jsonDecode(utf8.decode(response.bodyBytes));
        } on FormatException {
          /* Non-JSON errors get a safe generic message. */
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final problem = json is Map ? json : const {};
        final code = problem['code']?.toString() ?? '';
        throw ApiFailure(
          _message(response.statusCode, code),
          status: response.statusCode,
          code: code,
        );
      }
      if (response.statusCode != 204 && json == null) {
        throw const ApiFailure('Server trả dữ liệu không hợp lệ.');
      }
      return json;
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(
        'Server phản hồi chậm. Hãy tải lại để kiểm tra kết quả trước khi gửi lại.',
      );
    } catch (_) {
      throw const ApiFailure(
        'Không kết nối được server. Kiểm tra backend và mạng rồi thử lại.',
      );
    }
  }

  static String _message(int status, String code) => switch (code) {
    'EMAIL_NOT_VERIFIED' =>
      'Email chưa xác minh. Hãy xác minh OTP trước khi đăng nhập.',
    'VERIFY_PASSWORD_MISMATCH' =>
      'Mật khẩu không khớp với lần đăng ký. Kiểm tra rồi xác minh lại.',
    'ACCOUNT_INACTIVE' => 'Tài khoản đã bị khóa hoặc ngừng hoạt động.',
    'APPLICATION_NOT_EDITABLE' =>
      'Hồ sơ đang chờ duyệt hoặc đã duyệt. Hãy tải lại trạng thái.',
    'DRIVER_NOT_ELIGIBLE' =>
      'Chưa đủ điều kiện nhận đơn. Kiểm tra online, GPS, loại xe và số dư cọc.',
    'ORDER_CANCELLED' => 'Đơn hàng đã bị hủy.',
    'DRIVER_NOT_APPROVED' => 'Hồ sơ tài xế cần được duyệt trước.',
    _ => switch (status) {
      400 => 'Thông tin chưa hợp lệ. Kiểm tra các trường đã nhập.',
      401 => 'Thông tin đăng nhập không đúng hoặc phiên đã hết hạn.',
      403 => 'Tài khoản không được phép thực hiện thao tác này.',
      404 => 'Chức năng hoặc dữ liệu chưa có trên server.',
      409 =>
        'Dữ liệu đã được sử dụng hoặc vừa được người khác xử lý. Hãy tải lại.',
      422 =>
        'Chưa đủ điều kiện thực hiện. Kiểm tra hồ sơ và trạng thái hiện tại.',
      429 => 'Đã gửi quá nhiều yêu cầu. Vui lòng đợi một phút.',
      _ => 'Server chưa xử lý được yêu cầu. Vui lòng thử lại sau.',
    },
  };
  Future<void> close() async {
    _http.close();
    await _expired.close();
  }
}
