import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/customer_models.dart';
import '../domain/customer_places.dart';

class DeviceCustomerPlaces implements CustomerPlaces {
  static const channel = MethodChannel('vn.modmove/customer_places');
  Future<List<CustomerPlace>> _call(
    String method,
    Map<String, Object> args,
  ) async {
    try {
      final list = await channel
          .invokeListMethod<dynamic>(method, args)
          .timeout(const Duration(seconds: 20));
      return (list ?? [])
          .map(
            (v) => CustomerPlace(
              v['address'] as String,
              GeoPosition(
                (v['latitude'] as num).toDouble(),
                (v['longitude'] as num).toDouble(),
              ),
            ),
          )
          .toList();
    } catch (_) {
      throw const CustomerFailure(
        'Không tìm được địa chỉ trên thiết bị. Hãy nhập địa chỉ đầy đủ hoặc thử lại.',
      );
    }
  }

  @override
  Future<List<CustomerPlace>> search(String query) =>
      _call('search', {'query': query});
  @override
  Future<CustomerPlace> reverse(GeoPosition position) async {
    final list = await _call('reverse', {
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    if (list.isEmpty) {
      throw const CustomerFailure('Không xác định được địa chỉ tại điểm này.');
    }
    return list.first;
  }

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
