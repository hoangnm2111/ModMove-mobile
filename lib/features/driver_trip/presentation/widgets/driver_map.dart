import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/platform/maps_configuration.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/driver_matching_policy.dart';
import '../../domain/entities/trip_models.dart';
import 'driver_map_marker.dart';

/// Native Google Maps. Trip/GPS data still comes from the trip repository.
class DriverMap extends StatefulWidget {
  const DriverMap({
    super.key,
    this.route = false,
    this.available = true,
    this.searching = false,
    this.searchRadiusMeters = DriverMatchingPolicy.searchRadiusMeters,
    this.position,
    this.destination,
  }) : assert(searchRadiusMeters > 0);

  final bool route, available, searching;
  final double searchRadiusMeters;
  final GeoPoint? position, destination;

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  GoogleMapController? _google;
  BitmapDescriptor? _vehicleIcon;
  bool? _configured;
  bool _foreground = true;
  Duration _lastFrame = Duration.zero;

  LatLng get _position =>
      _latLng(widget.position ?? const GeoPoint(10.724, 106.7057));
  bool get _coverageVisible => widget.searching && !widget.route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..addListener(_animateCoverage);
    unawaited(_loadConfiguration());
  }

  Future<void> _loadConfiguration() async {
    final configured = await MapsConfiguration.isConfigured();
    if (!mounted) return;
    setState(() => _configured = configured);
    _syncPulse();
    if (configured && _vehicleIcon == null) {
      final icon = await DriverMapMarker.load();
      if (mounted) setState(() => _vehicleIcon = icon);
    }
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
    if (!widget.available) _google = null;
    if (widget.searching && !oldWidget.searching) unawaited(_showArea());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPulse();
  }

  void _syncPulse() {
    final animate =
        _configured == true &&
        widget.available &&
        _coverageVisible &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _lastFrame = Duration.zero;
      _pulse.repeat();
    } else if (!animate) {
      _pulse.stop();
    }
  }

  void _animateCoverage() {
    // Limit native circle updates to about 15 fps; don't recreate the map.
    final elapsed = _pulse.lastElapsedDuration ?? Duration.zero;
    if (elapsed - _lastFrame < const Duration(milliseconds: 66)) return;
    _lastFrame = elapsed;
    setState(() {});
  }

  Future<void> _moveCamera(CameraUpdate update) async {
    final controller = _google;
    if (controller == null) return;
    try {
      await controller.animateCamera(update);
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa điều khiển được bản đồ. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _showArea() async {
    if (_coverageVisible) {
      final latitudeDelta = widget.searchRadiusMeters / 111320;
      final longitudeDelta =
          latitudeDelta /
          math.cos(_position.latitude * math.pi / 180).abs().clamp(.1, 1);
      await _moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _position.latitude - latitudeDelta,
              _position.longitude - longitudeDelta,
            ),
            northeast: LatLng(
              _position.latitude + latitudeDelta,
              _position.longitude + longitudeDelta,
            ),
          ),
          28,
        ),
      );
    } else if (widget.route && widget.destination != null) {
      final destination = _latLng(widget.destination!);
      await _moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              math.min(_position.latitude, destination.latitude) - .001,
              math.min(_position.longitude, destination.longitude) - .001,
            ),
            northeast: LatLng(
              math.max(_position.latitude, destination.latitude) + .001,
              math.max(_position.longitude, destination.longitude) + .001,
            ),
          ),
          40,
        ),
      );
    } else {
      await _moveCamera(CameraUpdate.newLatLngZoom(_position, 14));
    }
  }

  Set<Circle> _circles() {
    if (!_coverageVisible) return {};
    return {
      Circle(
        circleId: const CircleId('dispatch-boundary'),
        center: _position,
        radius: widget.searchRadiusMeters,
        fillColor: AppColors.orange.withValues(alpha: .07),
        strokeColor: AppColors.orange.withValues(alpha: .45),
        strokeWidth: 1,
      ),
      if (_pulse.isAnimating)
        for (var i = 0; i < 2; i++) _ripple(i, (_pulse.value + i * .5) % 1),
    };
  }

  Circle _ripple(int index, double phase) => Circle(
    circleId: CircleId('dispatch-pulse-$index'),
    center: _position,
    radius: widget.searchRadiusMeters * (.08 + .92 * phase),
    fillColor: AppColors.orange.withValues(alpha: .10 * (1 - phase)),
    strokeColor: AppColors.orange.withValues(alpha: .32 * (1 - phase)),
    strokeWidth: 2,
    zIndex: 1,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    // GoogleMap owns and disposes its platform controller.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.available || _configured == false) {
      return _UnavailableMap(
        configured: _configured == true,
        onRetry: _loadConfiguration,
      );
    }
    if (_configured == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GoogleMap(
                key: const Key('google-driver-map'),
                initialCameraPosition: CameraPosition(
                  target: _position,
                  zoom: _coverageVisible ? 10.5 : 14,
                ),
                onMapCreated: (controller) {
                  if (!mounted || !widget.available) return;
                  _google = controller;
                  unawaited(_showArea());
                },
                // ListView must not steal vertical drags that start on the map.
                gestureRecognizers: {
                  Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
                },
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                padding: const EdgeInsets.only(right: 48),
                markers: {
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: _position,
                    anchor: const Offset(.5, .5),
                    flat: true,
                    icon:
                        _vehicleIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                    infoWindow: const InfoWindow(
                      title: 'Vị trí tài xế thử nghiệm',
                    ),
                  ),
                  if (widget.destination != null)
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: _latLng(widget.destination!),
                      infoWindow: const InfoWindow(title: 'Điểm lấy hàng'),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                    ),
                },
                circles: _circles(),
                polylines: widget.route && widget.destination != null
                    ? {
                        Polyline(
                          polylineId: const PolylineId('mock-pickup-direction'),
                          color: AppColors.orange,
                          width: 4,
                          patterns: [PatternItem.dash(14), PatternItem.gap(8)],
                          points: [_position, _latLng(widget.destination!)],
                        ),
                      }
                    : {},
              ),
              Positioned(
                right: 8,
                bottom: 24,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapControl(
                        'Phóng to',
                        'plus',
                        () => _moveCamera(CameraUpdate.zoomIn()),
                      ),
                      _MapControl(
                        'Thu nhỏ',
                        'minus',
                        () => _moveCamera(CameraUpdate.zoomOut()),
                      ),
                      _MapControl('Về vị trí tài xế', 'target', _showArea),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Outside the native map so Google attribution is never covered.
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            _coverageVisible
                ? 'Vùng nhận đơn · ${(widget.searchRadiusMeters / 1000).toStringAsFixed(0)} km · Vị trí thử nghiệm'
                : widget.route
                ? 'Vị trí / hướng đến điểm lấy mô phỏng'
                : 'Vị trí tài xế thử nghiệm',
            style: appText(size: 11, color: AppColors.secondary),
          ),
        ),
      ],
    );
  }
}

LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

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
  const _UnavailableMap({required this.configured, required this.onRetry});
  final bool configured;
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
            Text(
              configured
                  ? 'Chưa tải được Google Maps'
                  : 'Google Maps chưa được cấu hình',
              textAlign: TextAlign.center,
            ),
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
