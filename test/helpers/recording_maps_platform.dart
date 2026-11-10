import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Records the native SDK boundary; it does not pretend to render Google tiles.
class RecordingMapsPlatform extends GoogleMapsFlutterPlatform {
  final createdIds = <int>{};
  final cameraUpdates = <CameraUpdate>[];
  final circleUpdates = <CircleUpdates>[];
  final markerUpdates = <MarkerUpdates>[];
  final disposedIds = <int>{};
  MapWidgetConfiguration? widgetConfiguration;
  MapObjects? objects;

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapObjects mapObjects = const MapObjects(),
    MapConfiguration mapConfiguration = const MapConfiguration(),
  }) {
    this.widgetConfiguration = widgetConfiguration;
    objects = mapObjects;
    if (createdIds.add(creationId)) onPlatformViewCreated(creationId);
    return const SizedBox.expand(key: Key('native-map-test-surface'));
  }

  @override
  Future<void> init(int mapId) async {}
  @override
  void dispose({required int mapId}) => disposedIds.add(mapId);
  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    cameraUpdates.add(cameraUpdate);
  }

  @override
  Future<void> animateCameraWithConfiguration(
    CameraUpdate cameraUpdate,
    CameraUpdateAnimationConfiguration configuration, {
    required int mapId,
  }) async {
    cameraUpdates.add(cameraUpdate);
  }

  @override
  Future<void> updateCircles(
    CircleUpdates updates, {
    required int mapId,
  }) async {
    circleUpdates.add(updates);
  }

  @override
  Future<void> updateMarkers(
    MarkerUpdates updates, {
    required int mapId,
  }) async {
    markerUpdates.add(updates);
  }

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration update, {
    required int mapId,
  }) async {}
  @override
  Future<void> updatePolylines(
    PolylineUpdates update, {
    required int mapId,
  }) async {}
  @override
  Future<void> updatePolygons(
    PolygonUpdates update, {
    required int mapId,
  }) async {}
  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates update, {
    required int mapId,
  }) async {}
  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates update, {
    required int mapId,
  }) async {}
  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates update, {
    required int mapId,
  }) async {}
  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}
  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();
  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream.empty();
}
