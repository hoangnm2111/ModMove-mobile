import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/network/api_exception.dart';
import 'package:modmove_mobile/core/session/session_store.dart';

const _session = Session(accessToken: 'old', refreshToken: 'r1', userId: 3, fullName: 'Khách hàng Demo', role: 'Customer');

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  test('gắn Bearer token và trả JSON', () async {
    late http.Request seen;
    final api = ApiClient(
      sessions: MemorySessionStore(_session),
      baseUrl: 'http://api',
      client: MockClient((req) async {
        seen = req;
        return _json({'ok': true});
      }),
    );
    expect(await api.get('/customer/Orders', query: {'page': 1, 'search': ''}), {'ok': true});
    expect(seen.headers['Authorization'], 'Bearer old');
    expect(seen.url.toString(), 'http://api/customer/Orders?page=1');
  });

  test('401 → refresh một lần → gửi lại với token mới và lưu phiên mới', () async {
    final store = MemorySessionStore(_session);
    var refreshCalls = 0;
    final api = ApiClient(
      sessions: store,
      baseUrl: 'http://api',
      client: MockClient((req) async {
        if (req.url.path.endsWith('/public/Auth/refresh')) {
          refreshCalls++;
          expect(jsonDecode(req.body)['refreshToken'], 'r1');
          return _json({'accessToken': 'new', 'refreshToken': 'r2'});
        }
        return req.headers['Authorization'] == 'Bearer new' ? _json({'id': 1}) : _json({'code': 'UNAUTHORIZED'}, 401);
      }),
    );
    final results = await Future.wait([api.get('/customer/Orders/1'), api.get('/customer/Orders/2')]);
    expect(results, [
      {'id': 1},
      {'id': 1},
    ]);
    expect(refreshCalls, 1); // single-flight
    expect(store.current?.accessToken, 'new');
    expect(store.current?.refreshToken, 'r2');
  });

  test('refresh thất bại → báo phiên hết hạn', () async {
    var expired = false;
    final api = ApiClient(
      sessions: MemorySessionStore(_session),
      baseUrl: 'http://api',
      client: MockClient((req) async => _json({'code': 'UNAUTHORIZED'}, 401)),
      onSessionExpired: () => expired = true,
    );
    await expectLater(api.get('/customer/Orders'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(expired, isTrue);
  });

  test('mã lỗi backend → câu tiếng Việt, giữ code', () async {
    final api = ApiClient(
      sessions: MemorySessionStore(_session),
      baseUrl: 'http://api',
      client: MockClient((_) async => _json({'status': 422, 'code': 'COMPLAINT_OPEN', 'detail': 'An open complaint…'}, 422)),
    );
    await expectLater(
      api.post('/customer/Orders/8/confirm-receipt'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'COMPLAINT_OPEN').having((e) => e.message, 'message', errorMessages['COMPLAINT_OPEN'])),
    );
  });

  test('lỗi VALIDATION lấy lỗi theo trường đầu tiên', () async {
    final api = ApiClient(
      sessions: MemorySessionStore(),
      baseUrl: 'http://api',
      client: MockClient((_) async => _json({'status': 400, 'code': 'VALIDATION', 'errors': {'Email': ['Email không hợp lệ.']}}, 400)),
    );
    await expectLater(api.post('/public/Auth/login', {}), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email không hợp lệ.')));
  });

  test('mất kết nối → ApiException.network', () async {
    final api = ApiClient(
      sessions: MemorySessionStore(),
      baseUrl: 'http://api',
      client: MockClient((_) async => throw http.ClientException('down')),
    );
    await expectLater(api.get('/public/VehicleTypes'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK')));
  });

  for (final (name, refresh) in <(String, Future<http.Response> Function())>[
    ('mất mạng', () async => throw http.ClientException('down')),
    ('503', () async => _json({'code': 'SERVER_ERROR'}, 503)),
    ('429', () async => _json({'code': 'TOO_MANY_REQUESTS'}, 429)),
  ]) {
    test('refresh lỗi tạm thời ($name) → giữ phiên, không đăng xuất', () async {
      final store = MemorySessionStore(_session);
      var expired = false;
      final api = ApiClient(
        sessions: store,
        baseUrl: 'http://api',
        client: MockClient((req) => req.url.path.endsWith('/public/Auth/refresh') ? refresh() : Future.value(_json({'code': 'UNAUTHORIZED'}, 401))),
        onSessionExpired: () => expired = true,
      );
      await expectLater(api.get('/customer/Orders'), throwsA(isA<ApiException>()));
      expect(expired, isFalse);
      expect(store.current?.refreshToken, 'r1');
    });
  }

  String jwt(DateTime exp) => 'h.${base64Url.encode(utf8.encode(jsonEncode({'exp': exp.millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.s';

  test('freshToken: token còn hạn thì giữ, sắp hết hạn thì refresh trước', () async {
    final live = jwt(DateTime.now().add(const Duration(minutes: 10)));
    final store = MemorySessionStore(Session(accessToken: live, refreshToken: 'r1', userId: 3, fullName: 'K', role: 'Customer'));
    var refreshCalls = 0;
    final api = ApiClient(
      sessions: store,
      baseUrl: 'http://api',
      client: MockClient((req) async {
        refreshCalls++;
        return _json({'accessToken': 'new', 'refreshToken': 'r2'});
      }),
    );
    expect(await api.freshToken(), live);
    expect(refreshCalls, 0);
    await store.save(store.current!.withTokens(jwt(DateTime.now().add(const Duration(seconds: 30))), 'r1'));
    expect(await api.freshToken(), 'new');
    expect(refreshCalls, 1);
    expect(store.current?.refreshToken, 'r2');
  });
}
