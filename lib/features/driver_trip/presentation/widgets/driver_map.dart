import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapvina_gl/mapvina_gl.dart' as mv;
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../domain/entities/driver_matching_policy.dart';
import '../../domain/entities/trip_models.dart';
import 'driver_map_marker.dart';

// mapvina_gl 1.0.1 wipes the native API key whenever a map is created, so the key is set again
// from Kotlin after creation (MainActivity) and only then is the real MapVina style loaded.
const _keyChannel = MethodChannel('vn.modmove/mapvina');
const _emptyStyle = '{"version":8,"sources":{},"layers":[]}';
const _orange = '#F66818';
const _loadTimeout = Duration(seconds: 12); // the plugin has no "style failed" callback
// Each road costs one of MapVina Free's 200 routes/day, shared with fare estimates and customer ETA.
// shortcut: refreshed per 1 km driven, not when the driver leaves the drawn road; add an off-route check if drivers complain.
const _roadRefreshMeters = 1000;

/// Bản đồ MapVina: vị trí tài xế, vòng nhận đơn và đường thật tới điểm lấy hàng.
class DriverMap extends StatefulWidget {
  const DriverMap({
    super.key,
    this.route = false,
    this.available = true,
    this.searching = false,
    this.searchRadiusMeters = DriverMatchingPolicy.searchRadiusMeters,
    this.position,
    this.destination,
    this.loadRoute,
  }) : assert(searchRadiusMeters > 0);

  final bool route, available, searching;
  final double searchRadiusMeters;
  final GeoPoint? position, destination;

  /// Lấy đường lái xe thật (qua backend). Lỗi hoặc `null` thì vẽ đường thẳng.
  final Future<List<GeoPoint>?> Function(GeoPoint from, GeoPoint to)? loadRoute;

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  mv.MapVinaMapController? _map;
  Timer? _timeout;
  var _mapGeneration = 0; // a new key rebuilds the platform view on retry
  var _keyed = false; // the empty style loaded and the API key was restored
  var _ready = false; // the MapVina style loaded: annotations may be drawn
  var _failed = false;
  var _foreground = true;
  var _syncing = false, _dirty = false;
  Duration _lastFrame = Duration.zero;

  mv.Symbol? _driver;
  mv.Circle? _pickup;
  mv.Fill? _area;
  mv.Line? _line;
  final _ripples = <mv.Fill>[];

  List<GeoPoint>? _road;
  GeoPoint? _roadFrom;
  var _roadBusy = false;

  GeoPoint get _point => widget.position ?? const GeoPoint(10.724, 106.7057);
  mv.LatLng get _center => _latLng(_point);
  bool get _coverageVisible => widget.searching && !widget.route;
  bool get _hasRoute => widget.route && widget.destination != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addListener(_animateCoverage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
    if (!widget.available) {
      _resetMap();
      return;
    }
    if (oldWidget.destination != widget.destination) {
      _road = null;
      _roadFrom = null;
    }
    if (widget.searching && !oldWidget.searching) unawaited(_showArea());
    unawaited(_sync());
    _loadRoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPulse();
  }

  void _syncPulse() {
    final animate =
        _ready &&
        widget.available &&
        _coverageVisible &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _lastFrame = Duration.zero;
      _pulse.repeat();
    } else if (!animate && _pulse.isAnimating) {
      _pulse.stop();
      unawaited(_sync()); // drops the ripples
    }
  }

  void _animateCoverage() {
    // Limit native fill updates to about 15 fps; the map itself is never rebuilt.
    final elapsed = _pulse.lastElapsedDuration ?? Duration.zero;
    if (elapsed - _lastFrame < const Duration(milliseconds: 66)) return;
    _lastFrame = elapsed;
    unawaited(_sync());
  }

  void _resetMap() {
    _timeout?.cancel();
    _map = null;
    _keyed = _ready = false;
    _driver = _pickup = _area = _line = null;
    _ripples.clear();
  }

  void _retry() => setState(() {
    _resetMap();
    _failed = false;
    _mapGeneration++;
  });

  void _fail() {
    if (!mounted) return;
    _resetMap();
    setState(() => _failed = true);
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
      // A (re)loaded style has no annotations or images left.
      _driver = _pickup = _area = _line = null;
      _ripples.clear();
      await map.addImage('truck', await DriverMapMarker.load());
      if (!mounted) return;
      _ready = true;
      _syncPulse();
      await _sync();
      await _showArea();
      _loadRoad();
    } on PlatformException {
      _fail();
    } on MissingPluginException {
      _fail();
    }
  }

  /// One pass at a time: ripples ask for ~15 redraws a second, a slow redraw must not stack up.
  Future<void> _sync() async {
    if (_syncing) {
      _dirty = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _dirty = false;
        await _draw();
      } while (_dirty && mounted);
    } on PlatformException {
      // The map went away mid-draw (screen closed); nothing to repair.
    } finally {
      _syncing = false;
    }
  }

  Future<void> _draw() async {
    final map = _map;
    if (map == null || !_ready || !mounted) return;
    final me = _center;

    if (_driver == null) {
      _driver = await map.addSymbol(
        mv.SymbolOptions(geometry: me, iconImage: 'truck', iconSize: .8),
      );
    } else {
      await map.updateSymbol(_driver!, mv.SymbolOptions(geometry: me));
    }

    await _drawCoverage(map, me);

    final to = widget.destination;
    if (!_hasRoute || to == null) {
      if (_line != null) await map.removeLine(_line!);
      if (_pickup != null) await map.removeCircle(_pickup!);
      _line = _pickup = null;
      return;
    }
    final end = _latLng(to);
    final road = _road;
    final line = mv.LineOptions(
      geometry: road == null ? [me, end] : [me, ...road.map(_latLng), end],
      lineColor: _orange,
      lineWidth: road == null ? 3 : 5,
      lineOpacity: road == null ? .55 : 1,
    );
    if (_line == null) {
      _line = await map.addLine(line);
    } else {
      await map.updateLine(_line!, line);
    }
    _pickup ??= await map.addCircle(
      mv.CircleOptions(
        geometry: end,
        circleRadius: 8,
        circleColor: '#1E9E5A',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ),
    );
  }

  Future<void> _drawCoverage(mv.MapVinaMapController map, mv.LatLng me) async {
    if (!_coverageVisible) {
      for (final fill in [?_area, ..._ripples]) {
        await map.removeFill(fill);
      }
      _area = null;
      _ripples.clear();
      return;
    }
    final area = mv.FillOptions(
      geometry: [_ring(me, widget.searchRadiusMeters)],
      fillColor: _orange,
      fillOpacity: .12,
      fillOutlineColor: _orange,
    );
    if (_area == null) {
      _area = await map.addFill(area);
    } else {
      await map.updateFill(_area!, area);
    }

    final waves = _pulse.isAnimating ? 2 : 0;
    while (_ripples.length > waves) {
      await map.removeFill(_ripples.removeLast());
    }
    for (var i = 0; i < waves; i++) {
      final phase = (_pulse.value + i * .5) % 1;
      final ripple = mv.FillOptions(
        geometry: [_ring(me, widget.searchRadiusMeters * (.08 + .92 * phase))],
        fillColor: _orange,
        fillOpacity: .22 * (1 - phase),
        fillOutlineColor: _orange,
      );
      if (i < _ripples.length) {
        await map.updateFill(_ripples[i], ripple);
      } else {
        _ripples.add(await map.addFill(ripple));
      }
    }
  }

  /// Asks the backend for the road, at most once per [_roadRefreshMeters] of driving.
  void _loadRoad() {
    final to = widget.destination, load = widget.loadRoute;
    if (!_ready || !_hasRoute || to == null || load == null || _roadBusy) return;
    final from = _point;
    if (_roadFrom != null && _roadFrom!.distanceTo(from) < _roadRefreshMeters) return;
    _roadBusy = true;
    _roadFrom = from; // set before the call: a failure must not be retried at every GPS poll
    load(from, to)
        .then<List<GeoPoint>?>((road) => road, onError: (_) => null)
        .then((road) {
          _roadBusy = false;
          if (!mounted || road == null) return;
          final first = _road == null;
          _road = road;
          unawaited(_sync());
          if (first) unawaited(_showArea()); // later refreshes must not move the camera under the driver
        });
  }

  Future<void> _moveCamera(mv.CameraUpdate update) async {
    final map = _map;
    if (map == null || !_ready) return;
    try {
      await map.animateCamera(update);
    } on PlatformException {
      if (mounted) {
        showNotice(context, 'Chưa điều khiển được bản đồ. Vui lòng thử lại.', error: true);
      }
    }
  }

  Future<void> _showArea() async {
    final me = _center;
    if (_coverageVisible) {
      final latitudeDelta = widget.searchRadiusMeters / 111320;
      final longitudeDelta = latitudeDelta / _cosLat(me.latitude);
      await _moveCamera(
        mv.CameraUpdate.newLatLngBounds(
          mv.LatLngBounds(
            southwest: mv.LatLng(me.latitude - latitudeDelta, me.longitude - longitudeDelta),
            northeast: mv.LatLng(me.latitude + latitudeDelta, me.longitude + longitudeDelta),
          ),
          left: 28,
          top: 28,
          right: 28,
          bottom: 28,
        ),
      );
    } else if (_hasRoute) {
      final points = [me, _latLng(widget.destination!), ...?_road?.map(_latLng)];
      final lats = points.map((p) => p.latitude), lngs = points.map((p) => p.longitude);
      await _moveCamera(
        mv.CameraUpdate.newLatLngBounds(
          mv.LatLngBounds(
            southwest: mv.LatLng(lats.reduce(math.min) - .001, lngs.reduce(math.min) - .001),
            northeast: mv.LatLng(lats.reduce(math.max) + .001, lngs.reduce(math.max) + .001),
          ),
          left: 40,
          top: 150, // the ETA and turn cards sit over the top of the map
          right: 40,
          bottom: 40,
        ),
      );
    } else {
      await _moveCamera(mv.CameraUpdate.newLatLngZoom(me, 14));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _pulse.dispose();
    // MapVinaMap owns and disposes its platform controller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.available || _failed) return _UnavailableMap(onRetry: _retry);
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              mv.MapVinaMap(
                key: ValueKey('mapvina-$_mapGeneration'),
                styleString: _emptyStyle,
                initialCameraPosition: mv.CameraPosition(
                  target: _center,
                  zoom: _coverageVisible ? 10.5 : 14,
                ),
                onMapCreated: (controller) {
                  _map = controller;
                  _timeout = Timer(_loadTimeout, _fail);
                },
                onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
                // ListView must not steal vertical drags that start on the map.
                gestureRecognizers: {
                  Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
                },
                tiltGesturesEnabled: false,
                logoEnabled: true,
              ),
              Positioned(
                right: 8,
                bottom: 40, // clear of MapVina's attribution button
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapControl('Phóng to', 'plus', () => _moveCamera(mv.CameraUpdate.zoomIn())),
                      _MapControl('Thu nhỏ', 'minus', () => _moveCamera(mv.CameraUpdate.zoomOut())),
                      _MapControl('Về vị trí tài xế', 'target', _showArea),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            _coverageVisible
                ? 'Vùng nhận đơn · ${(widget.searchRadiusMeters / 1000).toStringAsFixed(0)} km'
                : widget.route
                ? 'Đường đến điểm lấy hàng'
                : 'Vị trí tài xế',
            style: appText(size: 11, color: AppColors.secondary),
          ),
        ),
      ],
    );
  }
}

mv.LatLng _latLng(GeoPoint point) => mv.LatLng(point.latitude, point.longitude);

double _cosLat(double latitude) =>
    math.cos(latitude * math.pi / 180).abs().clamp(.1, 1).toDouble();

/// A circle of [meters] as a 64-segment polygon: the map has no circle sized in metres.
List<mv.LatLng> _ring(mv.LatLng center, double meters) {
  final dLat = meters / 111320;
  final dLng = dLat / _cosLat(center.latitude);
  return [
    for (var i = 0; i <= 64; i++)
      mv.LatLng(
        center.latitude + dLat * math.sin(i * math.pi / 32),
        center.longitude + dLng * math.cos(i * math.pi / 32),
      ),
  ];
}

class _MapControl extends StatelessWidget {
  const _MapControl(this.label, this.icon, this.onPressed);
  final String label, icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    visualDensity: VisualDensity.compact,
    icon: AppIcon(icon, size: 21),
  );
}

class _UnavailableMap extends StatelessWidget {
  const _UnavailableMap({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.pale,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon('map', size: 30, color: AppColors.muted),
            const SizedBox(height: 6),
            const Text('Chưa tải được bản đồ', textAlign: TextAlign.center),
            const Text(
              'Bạn vẫn có thể xem địa chỉ và thông tin chuyến.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            TextButton(onPressed: onRetry, child: const Text('Thử lại bản đồ')),
          ],
        ),
      ),
    ),
  );
}
