import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/remote_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';

import 'support/remote_fixtures.dart';

void main() {
  final photo = SelectedPhoto(
    'document.png',
    Uint8List.fromList([137, 80, 78, 71]),
  );

  test(
    'onboarding upload keeps a safe support reference from the server',
    () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/driver/uploads');
          expect(request.headers['Authorization'], 'Bearer access');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final multipart = latin1.decode(request.bodyBytes);
          expect(multipart, contains('name="file"; filename="document.png"'));
          expect(multipart, contains('content-type: image/png'));
          return jsonResponse({
            'code': 'SERVER_ERROR',
            'traceId': '0HUPLOAD:00000001',
            'detail': 'private storage credentials and exception details',
          }, 500);
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());

      await expectLater(
        RemoteDriverRepository(api).upload(DocumentKind.citizenFront, photo),
        throwsA(
          isA<ApplicationFailure>()
              .having(
                (e) => e.message,
                'upload explanation',
                contains('Máy chủ chưa tải được ảnh'),
              )
              .having(
                (e) => e.message,
                'support reference',
                contains('0HUPLOAD:00000001'),
              )
              .having(
                (e) => e.message,
                'no internal details',
                isNot(contains('private')),
              ),
        ),
      );
    },
  );

  test('oversized image rejected by a proxy gets a size explanation', () async {
    final api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient(
        (_) async =>
            http.Response('<html>Request Entity Too Large</html>', 413),
      ),
    );
    addTearDown(api.close);
    await api.saveSession(tokens());

    await expectLater(
      api.upload('/api/driver/uploads', photo.name, photo.bytes),
      throwsA(
        isA<ApiFailure>()
            .having((e) => e.status, 'status', 413)
            .having((e) => e.message, 'size explanation', contains('5 MB')),
      ),
    );
  });

  test(
    'upload does not display untrusted trace text or raw server HTML',
    () async {
      for (final response in [
        jsonResponse({
          'code': 'SERVER_ERROR',
          'traceId': 'secret\n<script>',
          'detail': 'private exception',
        }, 500),
        http.Response('<html>private proxy configuration</html>', 502),
      ]) {
        final api = ApiClient(
          store: MemorySessionStore(),
          client: MockClient((_) async => response),
        );
        addTearDown(api.close);
        await api.saveSession(tokens());
        await expectLater(
          api.upload('/api/customer/uploads', photo.name, photo.bytes),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.traceId, 'unsafe trace rejected', isNull)
                .having(
                  (e) => e.status,
                  'status preserved',
                  response.statusCode,
                )
                .having(
                  (e) => e.message,
                  'safe message',
                  contains('Máy chủ chưa tải được ảnh'),
                )
                .having(
                  (e) => e.message,
                  'no raw payload',
                  isNot(matches('secret|private|script|html')),
                ),
          ),
        );
      }
    },
  );

  test('upload validation explains image format and size', () async {
    final api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient(
        (_) async => jsonResponse({'code': 'VALIDATION'}, 400),
      ),
    );
    addTearDown(api.close);
    await api.saveSession(tokens());
    await expectLater(
      api.upload('/api/driver/uploads', photo.name, photo.bytes),
      throwsA(
        isA<ApiFailure>()
            .having((e) => e.code, 'code preserved', 'VALIDATION')
            .having(
              (e) => e.message,
              'supported images',
              contains('JPG hoặc PNG'),
            ),
      ),
    );
  });
}
