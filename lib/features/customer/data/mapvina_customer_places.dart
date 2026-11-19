import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/maps/mapvina_client.dart';
import '../domain/customer_models.dart';
import '../domain/customer_places.dart';

class MapVinaCustomerPlaces implements CustomerPlaces {
  MapVinaCustomerPlaces({MapVinaClient? client})
    : _client = client ?? MapVinaClient();
  final MapVinaClient _client;
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MapVinaFailure catch (e) {
      throw CustomerFailure(e.message);
    }
  }

  @override
  Future<List<CustomerPlace>> search(String query) => _guard(
    () async => (await _client.search(query))
        .map(
          (p) => CustomerPlace(
            p.address,
            GeoPosition(p.point.latitude, p.point.longitude),
          ),
        )
        .toList(),
  );
  @override
  Future<CustomerPlace> reverse(GeoPosition position) => _guard(() async {
    final place = await _client.reverse(
      LatLng(position.latitude, position.longitude),
    );
    return CustomerPlace(place.address, position);
  });
  void close() => _client.close();

  @override
  Future<GeoPosition> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const CustomerFailure('Hãy bật vị trí trên thiết bị.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const CustomerFailure(
        'Chưa được cấp quyền vị trí. Bạn vẫn có thể nhập địa chỉ thủ công.',
      );
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GeoPosition(p.latitude, p.longitude);
    } catch (_) {
      throw const CustomerFailure('Chưa lấy được GPS. Vui lòng thử lại.');
    }
  }
}
