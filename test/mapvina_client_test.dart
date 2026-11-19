import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:modmove_mobile/core/maps/mapvina_client.dart';
import 'package:modmove_mobile/features/customer/data/mapvina_customer_places.dart';
import 'package:modmove_mobile/features/customer/domain/customer_models.dart';

http.Response utf8Response(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  Map<String, Object> place(double lat, double lng) => {
    'formatted_address': '12 Nguyễn Huệ, TP Hồ Chí Minh',
    'geometry': {
      'location': {'lat': lat, 'lng': lng},
    },
  };
  test(
    'search uses MapVina with encoded Vietnamese address and no app bearer',
    () async {
      final client = MapVinaClient(
        apiKey: 'test-key',
        client: MockClient((request) async {
          expect(request.url.host, 'maps.mapvina.com');
          expect(request.url.path, '/api/v2/place/textsearch/json');
          expect(
            request.url.queryParameters['query'],
            '12 Nguyễn Huệ & Quận 1',
          );
          expect(request.headers.containsKey('Authorization'), false);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'status': 'OK',
                'results': [place(10.77, 106.70)],
              }),
            ),
            200,
          );
        }),
      );
      addTearDown(client.close);
      final result = await client.search(' 12 Nguyễn Huệ & Quận 1 ');
      expect(result.single.address, contains('Nguyễn Huệ'));
      expect(result.single.point.latitude, 10.77);
    },
  );
  test(
    'reverse uses provider address but preserves the exact dropped pin',
    () async {
      final client = MapVinaClient(
        apiKey: 'test-key',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/geocode/json');
          expect(request.url.queryParameters['latlng'], '10.777123,106.701234');
          return utf8Response(
            jsonEncode({
              'status': 'OK',
              'results': [place(10.78, 106.71)],
            }),
            200,
          );
        }),
      );
      final repository = MapVinaCustomerPlaces(client: client);
      addTearDown(repository.close);
      const pin = GeoPosition(10.777123, 106.701234);
      final result = await repository.reverse(pin);
      expect(result.position, same(pin));
    },
  );
  test(
    'zero results and malformed coordinates are never fake locations',
    () async {
      for (final body in [
        {'status': 'ZERO_RESULTS'},
        {
          'status': 'OK',
          'results': [place(100, 106), place(10, 190)],
        },
      ]) {
        final client = MapVinaClient(
          apiKey: 'test-key',
          client: MockClient((_) async => utf8Response(jsonEncode(body), 200)),
        );
        addTearDown(client.close);
        expect(await client.search('Unknown'), isEmpty);
      }
    },
  );
  test(
    'quota and network errors never expose the key or provider payload',
    () async {
      for (final status in [403, 429, 500]) {
        final client = MapVinaClient(
          apiKey: 'private-key',
          client: MockClient(
            (_) async => utf8Response('private-key details', status),
          ),
        );
        addTearDown(client.close);
        await expectLater(
          client.search('Address'),
          throwsA(
            isA<MapVinaFailure>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('private-key')),
            ),
          ),
        );
      }
    },
  );
  test(
    'directions decode the road geometry and readable route steps',
    () async {
      final client = MapVinaClient(
        apiKey: 'test-key',
        client: MockClient((request) async {
          expect(request.url.path, '/route/v2/directions/json');
          expect(request.url.queryParameters['origin'], '38.5,-120.2');
          return utf8Response(
            jsonEncode({
              'status': 'OK',
              'routes': [
                {
                  'overview_polyline': {
                    'points': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                  },
                  'legs': [
                    {
                      'distance': {'value': 2000},
                      'duration': {'value': 300},
                      'steps': [
                        {'html_instructions': 'Rẽ <b>phải</b> &amp; đi tiếp'},
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      final route = await client.route(
        const LatLng(38.5, -120.2),
        const LatLng(43.252, -126.453),
      );
      expect(route.points, hasLength(3));
      expect(route.points.last.latitude, closeTo(43.252, .000001));
      expect(route.meters, 2000);
      expect(route.instructions.single, 'Rẽ phải & đi tiếp');
    },
  );
  test(
    'malformed route geometry fails instead of drawing a misleading line',
    () {
      expect(() => decodePolyline('~~~~~~'), throwsFormatException);
      expect(() => decodePolyline('\n'), throwsFormatException);
    },
  );
  test('missing key does not make a provider request', () async {
    var called = false;
    final client = MapVinaClient(
      apiKey: '',
      client: MockClient((_) async {
        called = true;
        return utf8Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    await expectLater(client.search('Address'), throwsA(isA<MapVinaFailure>()));
    expect(called, false);
  });
}
