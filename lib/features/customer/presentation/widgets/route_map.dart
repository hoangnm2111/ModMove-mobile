import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapvina_gl/mapvina_gl.dart' as mv;

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../driver_trip/data/polyline.dart';
import '../../domain/entities/customer_models.dart';

// Same start-up as the driver map: mapvina_gl resets the native key when a map is created, so the key is set
// again from Kotlin first and only then the real style (served by the backend, which holds the MapVina key) is loaded.
const _keyChannel = MethodChannel('vn.modmove/mapvina');
const _emptyStyle = '{"version":8,"sources":{},"layers":[]}';
const _loadTimeout = Duration(seconds: 12);

/// Bản đồ lộ trình đặt xe: điểm lấy (cam), điểm giao (xanh) và đường đi BE trả về trong báo giá.
/// Không có đường đi thì nối thẳng hai điểm. Bản đồ lỗi thì hiện ô báo và nút thử lại.
class RouteMap extends StatefulWidget {
  const RouteMap({super.key, required this.pickup, required this.dropoff, this.polyline, this.height = 220});
  final GeoPoint pickup, dropoff;
  final String? polyline;
  final double height;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  mv.MapVinaMapController? _map;
  Timer? _timeout;
  var _generation = 0;
  var _keyed = false, _ready = false, _failed = false;
  mv.Line? _line;
  mv.Circle? _from, _to;

  mv.LatLng _ll(double lat, double lng) => mv.LatLng(lat, lng);
  mv.LatLng get _a => _ll(widget.pickup.latitude, widget.pickup.longitude);
  mv.LatLng get _b => _ll(widget.dropoff.latitude, widget.dropoff.longitude);

  List<mv.LatLng> get _path {
    final p = widget.polyline;
    if (p == null || p.isEmpty) return [_a, _b];
    final road = decodePolyline(p);
    return road.length > 1 ? road.map((g) => _ll(g.latitude, g.longitude)).toList() : [_a, _b];
  }

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    final moved =
        old.pickup.latitude != widget.pickup.latitude ||
        old.pickup.longitude != widget.pickup.longitude ||
        old.dropoff.latitude != widget.dropoff.latitude ||
        old.dropoff.longitude != widget.dropoff.longitude ||
        old.polyline != widget.polyline;
    if (moved) unawaited(_draw(fit: true));
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null || !mounted) return;
    try {
      if (!_keyed) {
        _keyed = true;
        await _keyChannel.invokeMethod<void>('setApiKey', AppConfig.mapVinaKey);
        await map.setStyle(AppConfig.mapVinaStyleUrl);
        return;
      }
      _timeout?.cancel();
      _line = _from = _to = null; // a reloaded style has no annotations left
      _ready = true;
      await _draw(fit: true);
    } on PlatformException {
      _fail();
    } on MissingPluginException {
      _fail();
    }
  }

  Future<void> _draw({bool fit = false}) async {
    final map = _map;
    if (map == null || !_ready || !mounted) return;
    try {
      final path = _path;
      final line = mv.LineOptions(
        geometry: path,
        lineColor: '#F66818',
        lineWidth: path.length > 2 ? 5 : 3,
        lineOpacity: path.length > 2 ? 1 : .6,
      );
      if (_line == null) {
        _line = await map.addLine(line);
      } else {
        await map.updateLine(_line!, line);
      }
      Future<mv.Circle> dot(mv.Circle? c, mv.LatLng at, String color) async {
        final o = mv.CircleOptions(
          geometry: at,
          circleRadius: 7,
          circleColor: color,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        );
        if (c == null) return map.addCircle(o);
        await map.updateCircle(c, o);
        return c;
      }

      _from = await dot(_from, _a, '#F66818');
      _to = await dot(_to, _b, '#1E9E5A');
      if (fit) {
        final pts = [...path, _a, _b];
        final lats = pts.map((p) => p.latitude), lngs = pts.map((p) => p.longitude);
        await map.animateCamera(
          mv.CameraUpdate.newLatLngBounds(
            mv.LatLngBounds(
              southwest: _ll(lats.reduce(math.min) - .002, lngs.reduce(math.min) - .002),
              northeast: _ll(lats.reduce(math.max) + .002, lngs.reduce(math.max) + .002),
            ),
            left: 30,
            top: 30,
            right: 30,
            bottom: 30,
          ),
        );
      }
    } on PlatformException {
      // The map went away mid-draw (step changed); nothing to repair.
    }
  }

  void _fail() {
    if (!mounted) return;
    _timeout?.cancel();
    setState(() {
      _failed = true;
      _map = null;
      _keyed = _ready = false;
    });
  }

  void _retry() => setState(() {
    _failed = false;
    _generation++;
  });

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: widget.height,
      child: _failed
          ? ColoredBox(
              color: AppColors.line,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Chưa tải được bản đồ.', style: appText(size: 13, color: AppColors.secondary)),
                    TextButton(onPressed: _retry, child: const Text('Thử lại')),
                  ],
                ),
              ),
            )
          : mv.MapVinaMap(
              key: ValueKey('route-map-$_generation'),
              styleString: _emptyStyle,
              initialCameraPosition: mv.CameraPosition(target: _a, zoom: 12),
              onMapCreated: (c) {
                _map = c;
                _timeout = Timer(_loadTimeout, _fail);
              },
              onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
              // The booking form scrolls: drags that start on the map move the map.
              gestureRecognizers: {Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)},
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              logoEnabled: true,
            ),
    ),
  );
}
