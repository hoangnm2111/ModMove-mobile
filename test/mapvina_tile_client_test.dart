import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/maps/mapvina_tile_client.dart';

void main() {
  final uri = Uri.parse(
    'https://tiles.mapvina.com/test.png?key=test-private-key',
  );

  test(
    'loading lasts until the image body is received, not just headers',
    () async {
      final body = StreamController<List<int>>();
      final statuses = <MapVinaTileIssue?>[];
      final loading = <bool>[];
      final client = MapVinaTileClient(
        statuses.add,
        onLoadingChanged: loading.add,
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(body.stream, 200),
        ),
      );
      addTearDown(client.close);
      final response = await client.send(http.Request('GET', uri));
      expect(loading, [true]);
      expect(statuses, isEmpty);
      final bytes = response.stream.toBytes();
      body.add([1, 2, 3]);
      await body.close();
      await bytes;
      expect(loading, [true, false]);
      expect(statuses, [null]);
    },
  );

  test('body failures release loading and redact keyed URLs', () async {
    final statuses = <MapVinaTileIssue?>[];
    final loading = <bool>[];
    final client = MapVinaTileClient(
      statuses.add,
      onLoadingChanged: loading.add,
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream<List<int>>.error(http.ClientException('Failed $uri', uri)),
          200,
        ),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      client.get(uri),
      throwsA(
        predicate(
          (e) =>
              e is http.ClientException &&
              e.uri == null &&
              !e.message.contains('test-private-key'),
        ),
      ),
    );
    expect(loading, [true, false]);
    expect(statuses, [MapVinaTileIssue.connection]);
  });

  test(
    'missing geographic data is distinct from access, quota and server failures',
    () async {
      final statuses = <MapVinaTileIssue?>[];
      var code = 404;
      final client = MapVinaTileClient(
        statuses.add,
        client: MockClient((_) async => http.Response('', code)),
      );
      addTearDown(client.close);
      for (final status in [404, 403, 401, 429, 503, 200]) {
        code = status;
        await client.get(uri);
      }
      expect(statuses, [
        MapVinaTileIssue.noData,
        MapVinaTileIssue.accessDenied,
        MapVinaTileIssue.accessDenied,
        MapVinaTileIssue.rateLimited,
        MapVinaTileIssue.serviceUnavailable,
        null,
      ]);
    },
  );

  test('cancelled offscreen tiles do not display a network failure', () async {
    final statuses = <MapVinaTileIssue?>[];
    final client = MapVinaTileClient(
      statuses.add,
      client: MockClient((_) async => throw http.RequestAbortedException(uri)),
    );
    addTearDown(client.close);
    await expectLater(
      client.get(uri),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(statuses, isEmpty);
  });

  test(
    'connection failures redact the URL and a successful retry clears status',
    () async {
      final statuses = <MapVinaTileIssue?>[];
      var fail = true;
      final client = MapVinaTileClient(
        statuses.add,
        client: MockClient((_) async {
          if (fail) throw http.ClientException('Network failed for $uri', uri);
          return http.Response('', 200);
        }),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(uri),
        throwsA(
          predicate(
            (e) =>
                e is http.ClientException &&
                e.uri == null &&
                !e.toString().contains('test-private-key'),
          ),
        ),
      );
      fail = false;
      await client.get(uri);
      expect(statuses, [MapVinaTileIssue.connection, null]);
    },
  );
}
