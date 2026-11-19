import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/incidents/data/remote_driver_incident_repository.dart';
import 'package:modmove_mobile/features/incidents/domain/driver_incident_repository.dart';
import 'support/incident_fixtures.dart';
import 'support/remote_fixtures.dart';

void main() {
  test(
    'list sends filters/pagination and detail preserves resolution and GPS',
    () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer access');
          if (r.url.path.endsWith('/6')) {
            return jsonResponse({
              ...incidentJson(),
              'resolutionStatus': 'Resolved',
              'resolutionDecision': 'ReassignDriver',
              'resolvedAt': incidentTime.toIso8601String(),
            });
          }
          expect(r.url.queryParameters, {
            'page': '2',
            'pageSize': '20',
            'orderId': '42',
            'status': 'InProgress',
          });
          return jsonResponse(
            pageFixture([incidentJson()], page: 2, total: 21),
          );
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final repo = RemoteDriverIncidentRepository(api);
      final page = await repo.list(
        page: 2,
        orderId: '42',
        status: 'InProgress',
      );
      expect(page.total, 21);
      expect(page.items.single.createdAt.isUtc, true);
      final detail = await repo.detail('6');
      expect(detail.decision, 'ReassignDriver');
      expect(detail.closed, true);
      expect(detail.location!.latitude, 10.73);
      expect(detail.photos, hasLength(1));
    },
  );
  test(
    'customer reports never expose private description/photos/GPS',
    () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient(
          (_) async => jsonResponse(incidentJson(mine: false)),
        ),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final item = await RemoteDriverIncidentRepository(api).detail('6');
      expect(item.description, isNot(contains('thủng lốp')));
      expect(item.photos, isEmpty);
      expect(item.location, isNull);
      expect(item.note, 'Điều phối đã nhận thông tin.');
    },
  );
  for (final type in IncidentType.values) {
    test('report sends ${type.api}, uploaded URLs and optional GPS', () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/driver/incidents');
          final body = jsonDecode(r.body) as Map;
          expect(body, {
            'orderId': 42,
            'incidentType': type.api,
            'description': 'Cần hỗ trợ',
            'photoUrls': ['https://images.test/1.png'],
            'latitude': 10.73,
            'longitude': 106.7,
          });
          return jsonResponse({'incidentId': 9}, 201);
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      expect(
        await RemoteDriverIncidentRepository(api).report(
          IncidentReport(
            orderId: '42',
            type: type,
            description: ' Cần hỗ trợ ',
            photos: ['https://images.test/1.png'],
            location: const GeoPoint(10.73, 106.7),
          ),
        ),
        '9',
      );
    });
  }
  test(
    'validation blocks blank/long descriptions and excessive/duplicate/unuploaded photos',
    () {
      for (final description in ['', '   ', 'x' * 1001]) {
        expect(
          () => IncidentReport(
            orderId: '42',
            type: IncidentType.other,
            description: description,
          ).validate(),
          throwsA(isA<IncidentFailure>()),
        );
      }
      for (final photos in [
        List.generate(6, (i) => 'https://images.test/$i.png'),
        ['local.png'],
        ['https://images.test/1.png', 'https://images.test/1.png'],
      ]) {
        expect(
          () => IncidentReport(
            orderId: '42',
            type: IncidentType.other,
            description: 'x',
            photos: photos,
          ).validate(),
          throwsA(isA<IncidentFailure>()),
        );
      }
      expect(
        () => IncidentReport(
          orderId: '42',
          type: IncidentType.other,
          description: 'x' * 1000,
        ).validate(),
        returnsNormally,
      );
    },
  );
  for (final status in [422, 500]) {
    test('HTTP $status distinguishes refusal from uncertain save', () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient(
          (_) async => jsonResponse({
            'code': 'INCIDENT_NOT_ALLOWED',
            'message': 'Error',
          }, status),
        ),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      expect(
        RemoteDriverIncidentRepository(api).report(
          const IncidentReport(
            orderId: '42',
            type: IncidentType.other,
            description: 'x',
          ),
        ),
        throwsA(
          isA<IncidentFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            status == 500,
          ),
        ),
      );
    });
  }
  test('missing receipt is uncertain; missing detail maps to 404', () async {
    final api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient(
        (r) async => jsonResponse({}, r.method == 'POST' ? 201 : 404),
      ),
    );
    addTearDown(api.close);
    await api.saveSession(tokens());
    final repo = RemoteDriverIncidentRepository(api);
    await expectLater(
      repo.report(
        const IncidentReport(
          orderId: '42',
          type: IncidentType.other,
          description: 'x',
        ),
      ),
      throwsA(
        isA<IncidentFailure>().having((e) => e.uncertain, 'uncertain', true),
      ),
    );
    await expectLater(
      repo.detail('9'),
      throwsA(isA<IncidentFailure>().having((e) => e.status, 'status', 404)),
    );
  });
  test('upload uses authenticated multipart driver endpoint', () async {
    final api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient((r) async {
        expect(r.url.path, '/api/driver/uploads');
        expect(r.headers['content-type'], startsWith('multipart/form-data'));
        expect(r.headers['Authorization'], 'Bearer access');
        expect(latin1.decode(r.bodyBytes), contains('filename="photo-1.png"'));
        return jsonResponse({'url': 'https://images.test/upload.png'}, 201);
      }),
    );
    addTearDown(api.close);
    await api.saveSession(tokens());
    expect(
      await RemoteDriverIncidentRepository(
        api,
      ).upload(IncidentTestPicker.photo(1)),
      'https://images.test/upload.png',
    );
  });
}
