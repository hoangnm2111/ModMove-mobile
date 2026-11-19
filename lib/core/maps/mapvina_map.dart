import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../platform/maps_configuration.dart';
import 'mapvina_tile_client.dart';

/// MapVina's published Streets Raster v2 tiles; no Google SDK or tiles.
class MapVinaMap extends StatefulWidget {
  // MapVina raster v2 ends at XYZ z16. A 512px tile with zoomOffset -1
  // reaches this native level at Flutter Map camera zoom 17.
  static const double maxZoom = 17;
  const MapVinaMap({
    super.key,
    required this.center,
    this.zoom = 14,
    this.controller,
    this.markers = const [],
    this.circles = const [],
    this.polylines = const [],
    this.onTap,
    this.onReady,
    this.onZoomChanged,
    this.httpClient,
  });
  final LatLng center;
  final double zoom;
  final MapController? controller;
  final List<Marker> markers;
  final List<CircleMarker> circles;
  final List<Polyline> polylines;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onReady;
  final ValueChanged<double>? onZoomChanged;

  /// Optional transport for deterministic map rendering tests. Owned by this map.
  final http.Client? httpClient;
  @override
  State<MapVinaMap> createState() => _MapVinaMapState();
}

class _MapVinaMapState extends State<MapVinaMap> {
  late Future<String> key = MapsConfiguration.apiKey();
  late final _http = MapVinaTileClient(
    _tileStatus,
    client: widget.httpClient,
    onLoadingChanged: _loadingStatus,
  );
  late final _provider = NetworkTileProvider(
    httpClient: _http,
    cachingProvider: const DisabledMapCachingProvider(),
    silenceExceptions: true,
    attemptDecodeOfHttpErrorResponses: false,
  );
  MapVinaTileIssue? issue;
  bool statusScheduled = false;
  MapVinaTileIssue? nextIssue;
  bool loading = false, nextLoading = false;
  int generation = 0;
  void _tileStatus(MapVinaTileIssue? value) {
    nextIssue = value;
    _scheduleStatus();
  }

  void _loadingStatus(bool value) {
    nextLoading = value;
    _scheduleStatus();
  }

  void _scheduleStatus() {
    if (statusScheduled || !mounted) return;
    statusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      statusScheduled = false;
      if (mounted && (issue != nextIssue || loading != nextLoading)) {
        setState(() {
          issue = nextIssue;
          loading = nextLoading;
        });
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: key,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if ((snapshot.data ?? '').isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Bản đồ chưa được cấu hình. Bạn vẫn có thể dùng địa chỉ và thông tin chuyến.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: widget.controller,
                  options: MapOptions(
                    initialCenter: widget.center,
                    initialZoom: widget.zoom,
                    minZoom: 2,
                    maxZoom: MapVinaMap.maxZoom,
                    onMapReady: widget.onReady,
                    onPositionChanged: (camera, _) =>
                        widget.onZoomChanged?.call(camera.zoom),
                    onTap: widget.onTap == null
                        ? null
                        : (_, point) => widget.onTap!(point),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey(generation),
                      urlTemplate:
                          'https://tiles.mapvina.com/raster-tiles/v2/{z}/{x}/{y}.png?key={apiKey}',
                      additionalOptions: {'apiKey': snapshot.data!},
                      userAgentPackageName: 'vn.modmove.modmove_mobile',
                      tileDimension: 512,
                      zoomOffset: -1,
                      maxNativeZoom: 17,
                      tileProvider: _provider,
                      tileDisplay: const TileDisplay.instantaneous(),
                      tileBuilder: (context, child, tile) {
                        final targetZoom = MapCamera.of(
                          context,
                        ).zoom.round().clamp(0, 17);
                        // flutter_map retains ancestor tiles while downloading.
                        // Do not stretch those low-detail images across several
                        // zoom levels when the user repeatedly presses +.
                        return tile.coordinates.z == targetZoom
                            ? child
                            : const SizedBox.shrink();
                      },
                    ),
                    if (widget.circles.isNotEmpty)
                      CircleLayer(circles: widget.circles),
                    if (widget.polylines.isNotEmpty)
                      PolylineLayer(polylines: widget.polylines),
                    MarkerLayer(markers: widget.markers),
                  ],
                ),
                if (loading && issue == null)
                  Positioned(
                    left: 12,
                    top: 8,
                    child: IgnorePointer(
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đang tải bản đồ…',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (issue != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      color: Colors.white,
                      child: Padding(
                        // Leave room for zoom/recenter controls overlaid by callers.
                        padding: const EdgeInsets.fromLTRB(12, 0, 64, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                issue!.message,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                issue = null;
                                nextIssue = null;
                                generation++;
                              }),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (snapshot.data == 'public_key')
                    const Expanded(
                      child: Text('Thử nghiệm', style: TextStyle(fontSize: 10)),
                    ),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('https://mapvina.com')),
                    child: const Text(
                      '© MapVina',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  const Text(' · ', style: TextStyle(fontSize: 11)),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                    child: const Text(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

Marker mapVinaMarker(
  String id,
  LatLng point,
  IconData icon,
  Color color,
  String label,
) => Marker(
  key: ValueKey(id),
  point: point,
  width: 46,
  height: 46,
  child: Tooltip(
    message: label,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(icon, color: color, size: 26),
    ),
  ),
);
