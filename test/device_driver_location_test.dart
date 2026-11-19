import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/device_driver_location.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';

class TestGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  bool enabled = true;
  int requests = 0, starts = 0, cancels = 0, reads = 0;
  AndroidSettings? streamSettings;
  final stream = StreamController<Position>.broadcast();
  TestGeolocator() {
    stream.onCancel = () => cancels++;
  }

  Position get fix => Position(
    latitude: 10.7769,
    longitude: 106.7009,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission = LocationPermission.whileInUse;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    return fix;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    starts++;
    streamSettings = locationSettings as AndroidSettings;
    return stream.stream;
  }
}

void main() {
  late GeolocatorPlatform previous;
  late TestGeolocator platform;
  late DeviceDriverLocation location;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = platform = TestGeolocator();
    location = DeviceDriverLocation();
  });
  tearDown(() async {
    await location.stopTracking();
    await platform.stream.close();
    GeolocatorPlatform.instance = previous;
  });
  Matcher issue(DriverLocationIssue expected) => throwsA(
    isA<DriverLocationFailure>().having((e) => e.issue, 'issue', expected),
  );

  test(
    'polling never requests permission; a user gesture can grant it',
    () async {
      await expectLater(
        location.current(),
        issue(DriverLocationIssue.permissionDenied),
      );
      expect(platform.requests, 0);
      final fix = await location.current(requestPermission: true);
      expect(platform.requests, 1);
      expect(fix.point.latitude, 10.7769);
      platform.permission = LocationPermission.denied;
      await expectLater(
        location.current(),
        issue(DriverLocationIssue.permissionDenied),
      );
    },
  );
  test(
    'permanent denial and disabled service have different recovery states',
    () async {
      platform.permission = LocationPermission.deniedForever;
      await expectLater(
        location.current(requestPermission: true),
        issue(DriverLocationIssue.permissionBlocked),
      );
      platform.enabled = false;
      await expectLater(
        location.current(requestPermission: true),
        issue(DriverLocationIssue.serviceDisabled),
      );
      expect(platform.requests, 0);
      expect(platform.reads, 0);
    },
  );
  test(
    'polling and transient stream errors keep one foreground subscription',
    () async {
      platform.permission = LocationPermission.whileInUse;
      await location.startTracking();
      platform.stream.add(platform.fix);
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 4; i++) {
        await location.startTracking();
        await location.current();
      }
      expect(platform.starts, 1);
      expect(platform.reads, 0);
      expect(platform.streamSettings?.forceLocationManager, true);
      expect(platform.streamSettings?.foregroundNotificationConfig, isNotNull);
      platform.stream.addError(StateError('temporary acquisition failure'));
      await Future<void>.delayed(Duration.zero);
      await location.startTracking();
      platform.stream.add(platform.fix);
      await Future<void>.delayed(Duration.zero);
      await location.current();
      expect(platform.starts, 1);
      expect(platform.cancels, 0);
      await location.stopTracking();
      expect(platform.cancels, 1);
    },
  );
  test(
    'revoked access closes the stream and can recover after permission is restored',
    () async {
      platform.permission = LocationPermission.whileInUse;
      await location.startTracking();
      platform.permission = LocationPermission.denied;
      platform.stream.addError(PermissionDeniedException('permission revoked'));
      await Future<void>.delayed(Duration.zero);
      expect(platform.cancels, 1);
      await expectLater(
        location.startTracking(),
        issue(DriverLocationIssue.permissionDenied),
      );
      await location.current(requestPermission: true);
      await location.startTracking();
      expect(platform.starts, 2);
    },
  );
}
