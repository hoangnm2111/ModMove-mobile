import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapvina_gl/mapvina_gl.dart' as mv;
import 'package:modmove_mobile/features/driver_trip/data/polyline.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/driver_map.dart';

void main() {
  group('decodePolyline', () {
    test('MapVina polyline from the real Directions answer', () {
      final points = decodePolyline(r'svt`Ak{bjSKBeAXa@Ls@ReAZ}@VE@E@a@L');
      expect(points.first.latitude, closeTo(10.760896, 1e-5));
      expect(points.first.longitude, closeTo(106.679739, 1e-5));
      expect(points.last.latitude, closeTo(10.762624, 1e-5)); // the step's end_location
      expect(points.last.longitude, closeTo(106.679063, 1e-5));
    });

    test('Google documentation example', () {
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points.map((p) => (p.latitude, p.longitude)), [
        (38.5, -120.2),
        (40.7, -120.95),
        (43.252, -126.453),
      ]);
    });

    test('empty string has no points', () => expect(decodePolyline(''), isEmpty));
  });

  group('DriverMap', () {
    testWidgets('shows the retry screen when the map is unavailable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DriverMap(available: false))),
      );
      expect(find.text('Chưa tải được bản đồ'), findsOneWidget);
      expect(find.text('Thử lại bản đồ'), findsOneWidget);
      expect(find.byType(mv.MapVinaMap), findsNothing);
    });

    testWidgets('mounts the MapVina map when available', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DriverMap(position: GeoPoint(10.7769, 106.7009)))),
      );
      expect(find.byType(mv.MapVinaMap), findsOneWidget);
      expect(find.text('Vị trí tài xế'), findsOneWidget);
    });
  });
}
