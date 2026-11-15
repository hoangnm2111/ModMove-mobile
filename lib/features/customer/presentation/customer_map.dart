import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/platform/maps_configuration.dart';
import '../domain/customer_models.dart';
import '../domain/customer_places.dart';
import 'customer_cubits.dart';
import 'customer_widgets.dart';

class CustomerTrackingMap extends StatefulWidget {
  const CustomerTrackingMap(this.snapshot, {super.key});
  final TrackingSnapshot snapshot;
  @override
  State<CustomerTrackingMap> createState() => _CustomerTrackingMapState();
}

class _CustomerTrackingMapState extends State<CustomerTrackingMap> {
  late final Future<bool> configured = MapsConfiguration.isConfigured();
  GoogleMapController? controller;
  LatLng point(GeoPosition p) => LatLng(p.latitude, p.longitude);
  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: configured,
    builder: (context, s) {
      final t = widget.snapshot;
      if (s.data != true) {
        return const CustomerNotice(
          'Bản đồ Google chưa được cấu hình trên bản cài đặt này. Địa chỉ và trạng thái bên dưới vẫn được cập nhật từ hệ thống.',
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 290,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: point(t.driver ?? t.pickup),
              zoom: 13,
            ),
            onMapCreated: (c) => controller = c,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId('pickup'),
                position: point(t.pickup),
                infoWindow: const InfoWindow(title: 'Điểm lấy hàng'),
              ),
              Marker(
                markerId: const MarkerId('dropoff'),
                position: point(t.dropoff),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                infoWindow: const InfoWindow(title: 'Điểm giao hàng'),
              ),
              if (t.driver != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: point(t.driver!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange,
                  ),
                  infoWindow: const InfoWindow(title: 'Vị trí cuối của tài xế'),
                ),
            },
          ),
        ),
      );
    },
  );
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

  void select(CustomerPlace place) =>
      emit(PlaceState(results: state.results, selected: place));
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
    emit(const PlaceState(busy: true));
    try {
      final p = await places.locate();
      if (!isClosed) await pin(p);
    } catch (e) {
      if (!isClosed) emit(PlaceState(error: customerError(e)));
    }
  }
}

class CustomerPlaceScreen extends StatefulWidget {
  const CustomerPlaceScreen({super.key});
  @override
  State<CustomerPlaceScreen> createState() => _CustomerPlaceScreenState();
}

class _CustomerPlaceScreenState extends State<CustomerPlaceScreen> {
  final query = TextEditingController();
  late final Future<bool> configured = MapsConfiguration.isConfigured();
  GoogleMapController? controller;
  @override
  void dispose() {
    query.dispose();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<PlaceCubit, PlaceState>(
    listener: (_, s) {
      if (s.selected != null) {
        controller?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(
              s.selected!.position.latitude,
              s.selected!.position.longitude,
            ),
            16,
          ),
        );
      }
    },
    builder: (context, s) => Scaffold(
      appBar: AppBar(title: const Text('Chọn địa chỉ')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: TextField(
                controller: query,
                textInputAction: TextInputAction.search,
                onSubmitted: context.read<PlaceCubit>().search,
                decoration: InputDecoration(
                  hintText: 'Số nhà, đường, phường, thành phố',
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
            Expanded(
              child: FutureBuilder<bool>(
                future: configured,
                builder: (context, config) {
                  if (config.data != true) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Bản đồ Google chưa sẵn sàng. Bạn có thể tìm và chọn địa chỉ ở phía trên.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final p = s.selected?.position;
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: p == null
                          ? const LatLng(10.7769, 106.7009)
                          : LatLng(p.latitude, p.longitude),
                      zoom: 13,
                    ),
                    onMapCreated: (c) => controller = c,
                    myLocationButtonEnabled: false,
                    onTap: (p) => context.read<PlaceCubit>().pin(
                      GeoPosition(p.latitude, p.longitude),
                    ),
                    markers: {
                      if (p != null)
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: LatLng(p.latitude, p.longitude),
                        ),
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.selected != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(s.selected!.address),
                    ),
                  OutlinedButton.icon(
                    onPressed: s.busy
                        ? null
                        : context.read<PlaceCubit>().locate,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Dùng vị trí hiện tại'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: s.busy || s.selected == null
                        ? null
                        : () => Navigator.pop(context, s.selected!.address),
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
