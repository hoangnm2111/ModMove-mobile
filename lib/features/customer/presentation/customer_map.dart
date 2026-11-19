import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/maps/mapvina_map.dart';
import '../../../core/platform/maps_configuration.dart';
import '../domain/customer_models.dart';
import '../domain/customer_places.dart';
import 'customer_cubits.dart';
import 'customer_widgets.dart';

class CustomerTrackingMap extends StatefulWidget {
  const CustomerTrackingMap(this.snapshot, {super.key, this.searching = false});
  final bool searching;
  final TrackingSnapshot snapshot;
  @override
  State<CustomerTrackingMap> createState() => _CustomerTrackingMapState();
}

class _CustomerTrackingMapState extends State<CustomerTrackingMap> {
  final controller = MapController();
  bool ready = false;
  LatLng point(GeoPosition p) => LatLng(p.latitude, p.longitude);
  void fit() {
    if (!ready) return;
    final t = widget.snapshot;
    controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          point(t.pickup),
          point(t.dropoff),
          if (t.driver != null) point(t.driver!),
        ],
        padding: const EdgeInsets.all(40),
        maxZoom: 16,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.snapshot;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.searching ? 330 : 310,
        child: Stack(
          children: [
            MapVinaMap(
              controller: controller,
              center: point(t.driver ?? t.pickup),
              zoom: 13,
              onReady: () {
                ready = true;
                fit();
              },
              markers: [
                mapVinaMarker(
                  'pickup',
                  point(t.pickup),
                  Icons.inventory_2_outlined,
                  Colors.green,
                  'Điểm lấy hàng',
                ),
                mapVinaMarker(
                  'dropoff',
                  point(t.dropoff),
                  Icons.place,
                  AppColors.orange,
                  'Điểm giao hàng',
                ),
                if (t.driver != null)
                  mapVinaMarker(
                    'driver',
                    point(t.driver!),
                    Icons.local_shipping,
                    AppColors.orange,
                    'Vị trí cuối của tài xế',
                  ),
              ],
              circles: widget.searching
                  ? [
                      CircleMarker(
                        point: point(t.pickup),
                        radius: 350,
                        useRadiusInMeter: true,
                        color: AppColors.orange.withValues(alpha: .12),
                        borderColor: AppColors.orange.withValues(alpha: .3),
                        borderStrokeWidth: 1,
                      ),
                    ]
                  : [],
            ),
            Positioned(
              right: 8,
              bottom: 32,
              child: IconButton.filledTonal(
                onPressed: fit,
                tooltip: 'Xem toàn bộ hành trình',
                icon: const Icon(Icons.center_focus_strong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceState {
  const PlaceState({
    this.results = const [],
    this.selected,
    this.busy = false,
    this.error,
  });
  final List<CustomerPlace> results;
  final CustomerPlace? selected;
  final bool busy;
  final String? error;
}

class PlaceCubit extends Cubit<PlaceState> {
  PlaceCubit(this.places) : super(const PlaceState());
  final CustomerPlaces places;
  int _version = 0;
  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    final version = ++_version;
    emit(const PlaceState(busy: true));
    try {
      final values = await places.search(query.trim());
      if (!isClosed && version == _version) {
        emit(
          PlaceState(
            results: values,
            error: values.isEmpty
                ? 'Không tìm thấy địa chỉ. Hãy nhập thêm phường, quận hoặc thành phố.'
                : null,
          ),
        );
      }
    } catch (e) {
      if (!isClosed && version == _version) {
        emit(PlaceState(error: customerError(e)));
      }
    }
  }

  void clearSelection() {
    ++_version;
    emit(const PlaceState());
  }

  void select(CustomerPlace place) {
    ++_version;
    emit(PlaceState(results: state.results, selected: place));
  }

  Future<void> pin(GeoPosition position) async {
    final version = ++_version;
    emit(const PlaceState(busy: true));
    try {
      final p = await places.reverse(position);
      if (!isClosed && version == _version) emit(PlaceState(selected: p));
    } catch (e) {
      if (!isClosed && version == _version) {
        emit(PlaceState(error: customerError(e)));
      }
    }
  }

  Future<void> locate() async {
    if (state.busy) return;
    final version = ++_version;
    emit(const PlaceState(busy: true));
    try {
      final p = await places.locate();
      if (!isClosed && version == _version) await pin(p);
    } catch (e) {
      if (!isClosed && version == _version) {
        emit(PlaceState(error: customerError(e)));
      }
    }
  }
}

class CustomerPlaceScreen extends StatefulWidget {
  const CustomerPlaceScreen({
    super.key,
    this.title = 'Chọn địa chỉ',
    this.initialAddress = '',
  });
  final String title, initialAddress;
  @override
  State<CustomerPlaceScreen> createState() => _CustomerPlaceScreenState();
}

class _CustomerPlaceScreenState extends State<CustomerPlaceScreen> {
  late final query = TextEditingController(text: widget.initialAddress);
  late final Future<bool> configured = MapsConfiguration.isConfigured();
  final controller = MapController();
  bool mapReady = false;
  @override
  void dispose() {
    query.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<PlaceCubit, PlaceState>(
    listener: (_, s) {
      if (s.selected != null && mapReady) {
        controller.move(
          LatLng(s.selected!.position.latitude, s.selected!.position.longitude),
          16,
        );
      }
    },
    builder: (context, s) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: TextField(
                controller: query,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  FocusScope.of(context).unfocus();
                  context.read<PlaceCubit>().search(value);
                },
                onChanged: (_) {
                  context.read<PlaceCubit>().clearSelection();
                  setState(() {});
                },
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Tìm địa chỉ: số nhà, đường, thành phố',
                  counterText: '',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(14),
                    child: AppIcon('search', color: AppColors.secondary),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        context.read<PlaceCubit>().search(query.text),
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            if (s.busy) const LinearProgressIndicator(),
            if (s.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: CustomerNotice(s.error!, error: true),
              ),
            if (s.results.isNotEmpty)
              SizedBox(
                height: 160,
                child: ListView(
                  children: s.results
                      .map(
                        (p) => ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(p.address),
                          onTap: () => context.read<PlaceCubit>().select(p),
                        ),
                      )
                      .toList(),
                ),
              ),
            FutureBuilder<bool>(
              future: configured,
              builder: (context, config) {
                if (config.data != true) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Bạn có thể nhập đầy đủ số nhà, đường, phường/xã và tỉnh/thành phố, rồi chọn “Dùng địa chỉ đã nhập”. Hệ thống sẽ xác định tuyến đường khi tính giá cước.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final p = s.selected?.position;
                return SizedBox(
                  height: 280,
                  child: MapVinaMap(
                    controller: controller,
                    center: p == null
                        ? const LatLng(10.7769, 106.7009)
                        : LatLng(p.latitude, p.longitude),
                    zoom: 13,
                    onReady: () => mapReady = true,
                    onTap: (p) => context.read<PlaceCubit>().pin(
                      GeoPosition(p.latitude, p.longitude),
                    ),
                    markers: [
                      if (p != null)
                        mapVinaMarker(
                          'selected',
                          LatLng(p.latitude, p.longitude),
                          Icons.place,
                          AppColors.orange,
                          'Địa chỉ đã chọn',
                        ),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.selected != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vị trí đã chọn',
                            style: appText(size: 20, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const AppIcon('map-pin', color: AppColors.orange),
                              const SizedBox(width: 10),
                              Expanded(child: Text(s.selected!.address)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: s.busy
                        ? null
                        : context.read<PlaceCubit>().locate,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Dùng vị trí hiện tại'),
                  ),
                  const SizedBox(height: 8),
                  if (s.selected == null)
                    FilledButton(
                      onPressed: query.text.trim().length < 5
                          ? null
                          : () => Navigator.pop(
                              context,
                              BookingAddress(query.text.trim()),
                            ),
                      child: const Text('Dùng địa chỉ đã nhập'),
                    ),
                  if (s.selected != null)
                    FilledButton(
                      onPressed: s.busy || s.selected == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              BookingAddress(
                                s.selected!.address,
                                position: s.selected!.position,
                              ),
                            ),
                      child: const Text('Chọn địa chỉ này'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
