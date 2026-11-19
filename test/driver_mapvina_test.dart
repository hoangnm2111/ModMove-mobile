import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:modmove_mobile/core/maps/mapvina_map.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/driver_map.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/mock_driver_map.dart';

void main() {
  const channel = MethodChannel('vn.modmove/maps_configuration');
  var configured = true;
  setUp(() {
    configured = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => configured ? 'test-key' : '',
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  Future<void> mount(
    WidgetTester tester, {
    bool searching = true,
    bool reduceMotion = false,
    bool live = false,
    GeoPoint position = const GeoPoint(10.724, 106.7057),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: SizedBox(
              height: 500,
              child: DriverMap(
                searching: searching,
                position: position,
                liveLocation: live,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  List<CircleMarker> circles(WidgetTester tester) =>
      tester.widget<MapVinaMap>(find.byType(MapVinaMap)).circles;
  testWidgets(
    'MapVina shows meter-based coverage and moves the driver without snapping camera',
    (tester) async {
      await mount(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
      final boundary = circles(tester).first;
      expect(boundary.radius, 5000);
      expect(boundary.useRadiusInMeter, true);
      expect(boundary.point, const LatLng(10.724, 106.7057));
      final tile = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(tile.urlTemplate, startsWith('https://tiles.mapvina.com/'));
      expect(tile.tileDimension, 512);
      expect(tile.maxNativeZoom, 17);
      expect(tile.zoomOffset, -1);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = map.mapController!;
      controller.move(const LatLng(11, 107), 12);
      await tester.pump();
      await mount(tester, position: const GeoPoint(10.73, 106.708));
      expect(
        tester.widget<MapVinaMap>(find.byType(MapVinaMap)).markers.single.point,
        const LatLng(10.73, 106.708),
      );
      expect(controller.camera.center, const LatLng(11, 107));
      await tester.tap(find.byTooltip('Phóng to'));
      await tester.pump();
      expect(controller.camera.zoom, 13);
      await tester.tap(find.byTooltip('Về vị trí tài xế'));
      await tester.pump();
      expect(controller.camera.center.latitude, closeTo(10.73, .001));
      expect(controller.camera.zoom, 16);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Phóng to'));
        await tester.pump();
      }
      expect(controller.camera.zoom, MapVinaMap.maxZoom);
      final plus = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Phóng to',
      );
      expect(tester.widget<IconButton>(plus).onPressed, isNull);
      await tester.tap(find.byTooltip('Thu nhỏ'));
      await tester.pump();
      expect(tester.widget<IconButton>(plus).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'MapVina pulse pauses in background and stops with reduced motion or offline',
    (tester) async {
      await mount(tester);
      await tester.pump(const Duration(milliseconds: 300));
      final first = circles(tester)[1].radius;
      await tester.pump(const Duration(milliseconds: 300));
      expect(circles(tester)[1].radius, isNot(first));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final paused = circles(tester)[1].radius;
      await tester.pump(const Duration(seconds: 1));
      expect(circles(tester)[1].radius, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await mount(tester, reduceMotion: true);
      expect(circles(tester), hasLength(1));
      await mount(tester, searching: false);
      expect(circles(tester), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('missing configuration keeps demo maps separate from live GPS', (
    tester,
  ) async {
    configured = false;
    await mount(tester, reduceMotion: true);
    expect(find.byType(MockDriverMap), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, reduceMotion: true, live: true);
    expect(find.byType(MockDriverMap), findsNothing);
    expect(find.textContaining('Bản đồ chưa được cấu hình'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
