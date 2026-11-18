import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../session/session_store.dart';
import 'api_exception.dart';

/// HTTP client cho ModMove.WebApi: gắn Bearer token, tự làm mới access token khi 401
/// (một lần cho nhiều request đồng thời), chuẩn hoá lỗi thành [ApiException].
class ApiClient {
  ApiClient({required this.sessions, http.Client? client, this.baseUrl = AppConfig.apiBaseUrl, this.onSessionExpired}) : _http = client ?? http.Client();

  final SessionStore sessions;
  final String baseUrl;
  final http.Client _http;

  /// Gọi khi refresh token không dùng được nữa (đăng xuất ở UI).
  void Function()? onSessionExpired;

  Future<String?>? _refreshing;

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return Uri.parse('$baseUrl$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Upload một ảnh (multipart, field `file`). BE chỉ nhận image/jpeg hoặc image/png ≤ 5 MB.
  Future<dynamic> upload(String path, File file) async {
    final lower = file.path.toLowerCase();
    final type = lower.endsWith('.png') ? MediaType('image', 'png') : MediaType('image', 'jpeg');
    Future<http.BaseRequest> build() async {
      final req = http.MultipartRequest('POST', _uri(path));
      req.files.add(await http.MultipartFile.fromPath('file', file.path, contentType: type));
      return req;
    }

    return _execute(build);
  }

  /// Upload ảnh đã nằm trong bộ nhớ (ảnh chụp/chọn từ thư viện của tài xế).
  /// Cùng quy tắc với [upload]: field `file`, JPG/PNG ≤ 5 MB.
  Future<dynamic> uploadBytes(String path, String fileName, List<int> bytes) async {
    final type = fileName.toLowerCase().endsWith('.png') ? MediaType('image', 'png') : MediaType('image', 'jpeg');
    Future<http.BaseRequest> build() async {
      final req = http.MultipartRequest('POST', _uri(path));
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName, contentType: type));
      return req;
    }

    return _execute(build);
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, Object?>? query}) {
    Future<http.BaseRequest> build() async {
      final req = http.Request(method, _uri(path, query));
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return req;
    }

    return _execute(build);
  }

  Future<dynamic> _execute(Future<http.BaseRequest> Function() build, {bool retried = false}) async {
    final req = await build();
    final token = sessions.current?.accessToken;
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';

    final res = await _network(_http.send(req).then(http.Response.fromStream));

    final isAuthCall = req.url.path.contains('/public/Auth/');
    if (res.statusCode == 401 && !retried && !isAuthCall && sessions.current != null) {
      final newToken = await _refreshOnce();
      if (newToken != null) return _execute(build, retried: true);
      onSessionExpired?.call();
    }

    final text = utf8.decode(res.bodyBytes);
    final dynamic data = text.isEmpty ? null : _tryJson(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException.fromProblem(res.statusCode, data is Map<String, dynamic> ? data : null);
  }

  /// Access token còn hạn ít nhất 60 giây; sắp hết thì refresh trước. SignalR cần hàm này vì khi
  /// kết nối lại nó không đi qua [_execute] nên không tự refresh khi bị 401. `null` = hết phiên.
  Future<String?> freshToken() async {
    final token = sessions.current?.accessToken;
    if (token == null || !_expiresSoon(token)) return token;
    final next = await _refreshOnce();
    if (next == null) onSessionExpired?.call();
    return next;
  }

  /// Một lần refresh cho nhiều request đồng thời (refresh token chỉ dùng được một lần).
  Future<String?> _refreshOnce() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  /// `null` = server từ chối refresh token (hết phiên thật). Mất mạng, 429, 5xx: ném [ApiException]
  /// và giữ phiên, để sóng yếu đúng lúc token hết hạn không đăng xuất người dùng.
  Future<String?> _refresh() async {
    final current = sessions.current;
    if (current == null) return null;
    final res = await _network(
      _http.post(_uri('/public/Auth/refresh'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refreshToken': current.refreshToken})),
    );
    if (res.statusCode == 429 || res.statusCode >= 500) {
      final body = _tryJson(utf8.decode(res.bodyBytes));
      throw ApiException.fromProblem(res.statusCode, body is Map<String, dynamic> ? body : null);
    }
    if (res.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final next = current.withTokens(j['accessToken'] as String, j['refreshToken'] as String);
    await sessions.save(next);
    return next.accessToken;
  }

  /// Timeout, mất mạng → [ApiException.network].
  static Future<T> _network<T>(Future<T> request) async {
    try {
      return await request.timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException.network;
    } on SocketException {
      throw ApiException.network;
    } on http.ClientException {
      throw ApiException.network;
    }
  }

  /// Đọc `exp` của JWT; không đọc được thì để server quyết định.
  static bool _expiresSoon(String jwt) {
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1])))) as Map;
      final exp = DateTime.fromMillisecondsSinceEpoch((payload['exp'] as num).toInt() * 1000);
      return DateTime.now().isAfter(exp.subtract(const Duration(seconds: 60)));
    } catch (_) {
      return false;
    }
  }

  static dynamic _tryJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  void close() => _http.close();
}
