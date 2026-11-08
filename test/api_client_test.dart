import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:modmove_mobile/features/auth/domain/auth_repository.dart';
import 'support/remote_fixtures.dart';

void main() {
  test('concurrent 401 responses rotate a refresh token only once', () async {
    var refreshes = 0;
    final client = ApiClient(
      store: MemorySessionStore(),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/refresh')) {
          refreshes++;
          expect(jsonDecode(r.body)['refreshToken'], 'refresh-access');
          await Future<void>.delayed(const Duration(milliseconds: 15));
          return jsonResponse(tokens('new'));
        }
        return r.headers['Authorization'] == 'Bearer new'
            ? jsonResponse({'ok': true})
            : jsonResponse({}, 401);
      }),
    );
    addTearDown(client.close);
    await client.saveSession(tokens());
    final results = await Future.wait([
      client.request('GET', '/api/driver/status'),
      client.request('GET', '/api/account/profile'),
    ]);
    expect(results.every((e) => e['ok'] == true), true);
    expect(refreshes, 1);
    expect(client.session!.refreshToken, 'refresh-new');
  });
  test(
    'invalid refresh clears stored credentials; network failures preserve them',
    () async {
      for (final status in [401, 503]) {
        final store = MemorySessionStore();
        final api = ApiClient(
          store: store,
          client: MockClient(
            (r) async => jsonResponse(
              {},
              r.url.path.endsWith('/refresh') ? status : 401,
            ),
          ),
        );
        addTearDown(api.close);
        await api.saveSession(tokens());
        await expectLater(
          api.request('GET', '/api/driver/status'),
          throwsA(isA<ApiFailure>()),
        );
        expect(api.session == null, status == 401);
        expect(store.values.isEmpty, status == 401);
      }
    },
  );
  test(
    'register uses Driver endpoint; verify includes original password',
    () async {
      final seen = <String>[];
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          seen.add(r.url.path);
          final body = jsonDecode(r.body) as Map;
          expect(body['password'], 'Password@123');
          if (r.url.path.endsWith('/verify-email')) {
            expect(body['code'], '123456');
            return http.Response('', 204);
          }
          return jsonResponse({'userId': 8, 'email': 'driver@test.local'});
        }),
      );
      addTearDown(api.close);
      final auth = RemoteAuthRepository(api);
      await auth.register(
        'Driver',
        '0901234567',
        'driver@test.local',
        'Password@123',
      );
      await auth.verify('driver@test.local', '123456', 'Password@123');
      expect(seen, [
        '/api/public/auth/register-driver',
        '/api/public/auth/verify-email',
      ]);
    },
  );
  test('customer login cannot enter the driver application', () async {
    final api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient(
        (_) async => jsonResponse(tokens('access', 'Customer')),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      RemoteAuthRepository(api).login('x@y.z', 'password'),
      throwsA(isA<AuthFailure>()),
    );
    expect(api.session, isNull);
  });
  test(
    'ProblemDetails status/code is preserved without exposing server internals',
    () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient(
          (_) async => jsonResponse({
            'code': 'CONFLICT',
            'detail': 'secret SQL trace',
          }, 409),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.request('GET', '/api/test', authenticated: false),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message.contains('secret'), 'safe error', false),
        ),
      );
    },
  );
}
