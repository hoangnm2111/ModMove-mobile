import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/maps/mapvina_client.dart';
import '../../../../core/maps/mapvina_map.dart';
import '../../../../core/platform/maps_configuration.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/driver_matching_policy.dart';
import '../../domain/entities/trip_models.dart';
import 'mock_driver_map.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({
    super.key,
    this.route = false,
    this.available = true,
    this.searching = false,
    this.searchRadiusMeters = DriverMatchingPolicy.searchRadiusMeters,
    this.position,
    this.destination,
    this.liveLocation = false,
  }) : assert(searchRadiusMeters > 0);
  final bool route, available, searching, liveLocation;
  final double searchRadiusMeters;
  final GeoPoint? position, destination;
  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController pulse;
  final controller = MapController();
  final client = MapVinaClient();
  bool? configured;
  bool ready = false, foreground = true, routeBusy = false;
  double cameraZoom = 14;
  MapVinaRoute? road;
  String? routeError;
  DateTime? requestedAt;
  int version = 0, mapGeneration = 0;
  Duration lastFrame = Duration.zero;
  LatLng get position => point(
    widget.position ?? widget.destination ?? const GeoPoint(10.7769, 106.7009),
  );
  bool get coverage =>
      widget.searching &&
      !widget.route &&
      (!widget.liveLocation || widget.position != null);
  LatLng point(GeoPoint p) => LatLng(p.latitude, p.longitude);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pulse =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2600),
        )..addListener(() {
          final elapsed = pulse.lastElapsedDuration ?? Duration.zero;
          if (elapsed - lastFrame < const Duration(milliseconds: 66)) return;
          lastFrame = elapsed;
          if (mounted) setState(() {});
        });
    unawaited(loadConfiguration());
  }

  Future<void> loadConfiguration() async {
    final value = await MapsConfiguration.isConfigured();
    if (!mounted) return;
    setState(() => configured = value);
    syncPulse();
    if (value) unawaited(loadRoute());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPulse();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    syncPulse();
  }

  @override
  void didUpdateWidget(DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPulse();
    final changedDestination =
        widget.destination?.latitude != oldWidget.destination?.latitude ||
        widget.destination?.longitude != oldWidget.destination?.longitude;
    if (changedDestination || widget.route != oldWidget.route) {
      version++;
      road = null;
      routeError = null;
      requestedAt = null;
      routeBusy = false;
      unawaited(loadRoute());
    } else if (widget.position != null && oldWidget.position == null) {
      unawaited(loadRoute());
    }
    if (widget.searching && !oldWidget.searching && ready) showArea();
  }

  void syncPulse() {
    final animate =
        configured != null &&
        widget.available &&
        coverage &&
        foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !pulse.isAnimating) {
      lastFrame = Duration.zero;
      pulse.repeat();
    } else if (!animate) {
      pulse.stop();
    }
  }

  Future<void> loadRoute({bool force = false}) async {
    if (!widget.route ||
        !widget.liveLocation ||
        configured != true ||
        widget.position == null ||
        widget.destination == null ||
        routeBusy) {
      return;
    }
    if (!force && requestedAt != null) return;
    final current = ++version;
    requestedAt = DateTime.now();
    setState(() {
      routeBusy = true;
      routeError = null;
    });
    try {
      final result = await client.route(position, point(widget.destination!));
      if (!mounted || current != version) return;
      setState(() => road = result);
      if (ready) showArea();
    } on MapVinaFailure catch (e) {
      if (mounted && current == version) setState(() => routeError = e.message);
    } finally {
      if (mounted && current == version) setState(() => routeBusy = false);
    }
  }

  void showArea() {
    if (!ready) return;
    if (coverage) {
      final lat = widget.searchRadiusMeters / 111320;
      final lng =
          lat / math.cos(position.latitude * math.pi / 180).abs().clamp(.1, 1);
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(position.latitude - lat, position.longitude - lng),
            LatLng(position.latitude + lat, position.longitude + lng),
          ),
          padding: const EdgeInsets.all(30),
        ),
      );
    } else if (widget.route && widget.destination != null) {
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: [position, point(widget.destination!), ...?road?.points],
          padding: const EdgeInsets.all(40),
          maxZoom: 16,
        ),
      );
    } else {
      controller.move(position, 14);
    }
  }

  List<CircleMarker> circles() => !coverage
      ? []
      : [
          CircleMarker(
            key: const Key('dispatch-boundary'),
            point: position,
            radius: widget.searchRadiusMeters,
            useRadiusInMeter: true,
            color: AppColors.orange.withValues(alpha: .07),
            borderColor: AppColors.orange.withValues(alpha: .45),
            borderStrokeWidth: 1,
          ),
          if (pulse.isAnimating)
            for (var i = 0; i < 2; i++) ripple(i, (pulse.value + i * .5) % 1),
        ];
  CircleMarker ripple(int i, double phase) => CircleMarker(
    key: ValueKey('dispatch-pulse-$i'),
    point: position,
    radius: widget.searchRadiusMeters * (.08 + .92 * phase),
    useRadiusInMeter: true,
    color: AppColors.orange.withValues(alpha: .10 * (1 - phase)),
    borderColor: AppColors.orange.withValues(alpha: .32 * (1 - phase)),
    borderStrokeWidth: 2,
  );
  @override
  void dispose() {
    version++;
    WidgetsBinding.instance.removeObserver(this);
    pulse.dispose();
    controller.dispose();
    client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.available) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chưa tải được bản đồ'),
            const Text(
              'Bạn vẫn có thể xem địa chỉ và thông tin chuyến.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: loadConfiguration,
              child: const Text('Thử lại bản đồ'),
            ),
          ],
        ),
      );
    }
    if (configured == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (configured == false && !widget.liveLocation) {
      return MockDriverMap(
        route: widget.route,
        searching: coverage,
        phase: pulse.value,
        animate: pulse.isAnimating,
        searchRadiusMeters: widget.searchRadiusMeters,
        position: widget.position,
        destination: widget.destination,
      );
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MapVinaMap(
                key: ValueKey('mapvina-driver-$mapGeneration'),
                controller: controller,
                center: position,
                zoom: coverage ? 10.5 : 14,
                onReady: () {
                  setState(() {
                    ready = true;
                    cameraZoom = controller.camera.zoom;
                  });
                  showArea();
                },
                onZoomChanged: (zoom) {
                  if (cameraZoom != zoom) setState(() => cameraZoom = zoom);
                },
                markers: [
                  if (widget.position != null || !widget.liveLocation)
                    mapVinaMarker(
                      'driver',
                      position,
                      Icons.local_shipping,
                      AppColors.orange,
                      widget.liveLocation
                          ? 'Vị trí tài xế'
                          : 'Vị trí thử nghiệm',
                    ),
                  if (widget.destination != null)
                    mapVinaMarker(
                      'destination',
                      point(widget.destination!),
                      Icons.place,
                      Colors.green,
                      'Điểm đến',
                    ),
                ],
                circles: circles(),
                polylines: road == null
                    ? []
                    : [
                        Polyline(
                          points: road!.points,
                          color: AppColors.orange,
                          strokeWidth: 5,
                        ),
                      ],
              ),
              if (routeBusy)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(),
                ),
              Positioned(
                right: 8,
                bottom: 32,
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Phóng to',
                        onPressed: !ready || cameraZoom >= MapVinaMap.maxZoom
                            ? null
                            : () {
                                if (ready) {
                                  controller.move(
                                    controller.camera.center,
                                    (controller.camera.zoom + 1).clamp(
                                      2,
                                      MapVinaMap.maxZoom,
                                    ),
                                  );
                                }
                              },
                        icon: const AppIcon('plus', size: 21),
                      ),
                      IconButton(
                        tooltip: 'Thu nhỏ',
                        onPressed: !ready || cameraZoom <= 2
                            ? null
                            : () {
                                if (ready) {
                                  controller.move(
                                    controller.camera.center,
                                    (controller.camera.zoom - 1).clamp(
                                      2,
                                      MapVinaMap.maxZoom,
                                    ),
                                  );
                                }
                              },
                        icon: const AppIcon('minus', size: 21),
                      ),
                      IconButton(
                        tooltip: 'Về vị trí tài xế',
                        onPressed: () {
                          if (ready) controller.move(position, 16);
                        },
                        icon: const AppIcon('target', size: 21),
                      ),
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
            coverage
                ? 'Vùng nhận đơn · ${(widget.searchRadiusMeters / 1000).toStringAsFixed(0)} km · ${widget.liveLocation ? 'GPS thiết bị' : 'Vị trí thử nghiệm'}'
                : road != null
                ? 'MapVina · ${(road!.meters / 1000).toStringAsFixed(1)} km · ${(road!.seconds / 60).ceil()} phút'
                : widget.liveLocation
                ? (widget.position == null
                      ? 'Đang chờ vị trí GPS của tài xế'
                      : 'Vị trí GPS thiết bị')
                : 'Vị trí tài xế thử nghiệm',
            style: appText(size: 11, color: AppColors.secondary),
          ),
        ),
        if (widget.route && widget.liveLocation && widget.position != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (routeError != null)
                  Expanded(
                    child: Text(
                      routeError!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (road?.instructions.isNotEmpty == true)
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text(
                            'Hướng dẫn đường đi',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          for (final item in road!.instructions.indexed)
                            ListTile(
                              leading: Text('${item.$1 + 1}'),
                              title: Text(item.$2),
                            ),
                        ],
                      ),
                    ),
                    child: const Text('Hướng dẫn'),
                  ),
                TextButton(
                  onPressed: routeBusy ? null : () => loadRoute(force: true),
                  child: const Text('Cập nhật tuyến'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
