import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/driver_matching_policy.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/driver_map.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/driver_map_marker.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/widgets/mock_driver_map.dart';
import 'helpers/recording_maps_platform.dart';

const configurationChannel = MethodChannel('vn.modmove/maps_configuration');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GoogleMapsFlutterPlatform original;
  late RecordingMapsPlatform platform;
  var configured = true;
  setUp(() {
    original = GoogleMapsFlutterPlatform.instance;
    platform = RecordingMapsPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    configured = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          configurationChannel,
          (_) async => configured,
        );
  });
  tearDown(() {
    GoogleMapsFlutterPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(configurationChannel, null);
  });

  Future<void> mount(
    WidgetTester tester, {
    bool searching = true,
    bool reduceMotion = false,
    GeoPoint position = const GeoPoint(10.724, 106.7057),
  }) async {
    await tester.runAsync(DriverMapMarker.load);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: SizedBox(
              height: 220,
              child: DriverMap(searching: searching, position: position),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'Google map receives gestures, meter-based coverage and moving GPS',
    (tester) async {
      await mount(tester);
      expect(find.byType(GoogleMap), findsOneWidget);
      final gestures = platform.widgetConfiguration!.gestureRecognizers;
      expect(gestures.single.type, EagerGestureRecognizer);
      final boundary = platform.objects!.circles.singleWhere(
        (circle) => circle.circleId.value == 'dispatch-boundary',
      );
      expect(boundary.radius, DriverMatchingPolicy.searchRadiusMeters);
      expect(boundary.center, const LatLng(10.724, 106.7057));
      await tester.pump(const Duration(milliseconds: 500));
      final before = platform.objects!.circles.singleWhere(
        (circle) => circle.circleId.value == 'dispatch-pulse-0',
      );
      await tester.pump(const Duration(milliseconds: 500));
      final after = platform.objects!.circles.singleWhere(
        (circle) => circle.circleId.value == 'dispatch-pulse-0',
      );
      expect(after.radius, greaterThan(before.radius));
      expect(after.radius, lessThanOrEqualTo(boundary.radius));
      expect(after.strokeColor.a, lessThan(before.strokeColor.a));
      expect(platform.circleUpdates, isNotEmpty);
      expect(platform.createdIds, hasLength(1));

      final cameraCommands = platform.cameraUpdates.length;
      await mount(tester, position: const GeoPoint(10.730, 106.708));
      expect(
        platform.objects!.markers.single.position,
        const LatLng(10.730, 106.708),
      );
      expect(
        platform.objects!.circles.every(
          (circle) => circle.center == const LatLng(10.730, 106.708),
        ),
        isTrue,
      );
      // GPS changes must not snap a map that the driver has panned away.
      expect(platform.cameraUpdates.length, cameraCommands);
      await tester.tap(find.byTooltip('Phóng to'));
      await tester.pump();
      expect(platform.cameraUpdates.last.toJson(), ['zoomIn']);
      await tester.tap(find.byTooltip('Thu nhỏ'));
      await tester.pump();
      expect(platform.cameraUpdates.last.toJson(), ['zoomOut']);
      await tester.tap(find.byTooltip('Về vị trí tài xế'));
      await tester.pump();
      expect(
        (platform.cameraUpdates.last.toJson() as List).first,
        'newLatLngBounds',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(platform.disposedIds, platform.createdIds);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pulse pauses in background, honors reduced motion and stops offline',
    (tester) async {
      await mount(tester);
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final paused = platform.circleUpdates.length;
      await tester.pump(const Duration(seconds: 1));
      expect(platform.circleUpdates.length, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(platform.circleUpdates.length, greaterThan(paused));

      await mount(tester, reduceMotion: true);
      await tester.pumpAndSettle();
      expect(platform.objects!.circles, hasLength(1));
      expect(platform.objects!.circles.single.radius, 5000);
      await mount(tester, searching: false);
      await tester.pumpAndSettle();
      expect(platform.objects!.circles, isEmpty);
      expect(find.textContaining('Vùng nhận đơn'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing key uses interactive mock map and configured restart uses Google',
    (tester) async {
      configured = false;
      await mount(tester, reduceMotion: true);
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.text('Bản đồ mô phỏng · Tìm đơn 5 km'), findsOneWidget);
      expect(find.byType(MockDriverMap), findsOneWidget);
      expect(platform.createdIds, isEmpty);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final transform = viewer.transformationController!;
      await tester.tap(find.byTooltip('Phóng to'));
      await tester.pumpAndSettle();
      expect(transform.value.getMaxScaleOnAxis(), closeTo(1.35, .001));
      final beforePan = transform.value.clone();
      await tester.drag(find.byType(InteractiveViewer), const Offset(30, 15));
      await tester.pumpAndSettle();
      expect(transform.value, isNot(beforePan));
      await tester.tap(find.byTooltip('Về vị trí tài xế'));
      await tester.pumpAndSettle();
      expect(transform.value, Matrix4.identity());
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      configured = true;
      await mount(tester, reduceMotion: true);
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsOneWidget);
      expect(find.byType(MockDriverMap), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallback pulse pauses in background and stops offline', (
    tester,
  ) async {
    configured = false;
    await mount(tester);
    double phase() =>
        tester.widget<MockDriverMap>(find.byType(MockDriverMap)).phase;
    final first = phase();
    await tester.pump(const Duration(milliseconds: 500));
    expect(phase(), isNot(first));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = phase();
    await tester.pump(const Duration(milliseconds: 500));
    expect(phase(), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await mount(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MockDriverMap>(find.byType(MockDriverMap)).animate,
      isFalse,
    );
    await mount(tester, searching: false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MockDriverMap>(find.byType(MockDriverMap)).searching,
      isFalse,
    );
    expect(find.text('Bản đồ mô phỏng'), findsOneWidget);
    expect(platform.createdIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
