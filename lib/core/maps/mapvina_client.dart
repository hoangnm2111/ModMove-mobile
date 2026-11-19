import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../platform/maps_configuration.dart';

class MapVinaFailure implements Exception {
  const MapVinaFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class MapVinaPlace {
  const MapVinaPlace(this.address, this.point);
  final String address;
  final LatLng point;
}

class MapVinaRoute {
  const MapVinaRoute(this.points, this.meters, this.seconds, this.instructions);
  final List<LatLng> points;
  final double meters, seconds;
  final List<String> instructions;
}

/// Dedicated provider client. App session tokens are never sent to MapVina.
class MapVinaClient {
  MapVinaClient({http.Client? client, String? apiKey})
    : _http = client ?? http.Client(),
      _key = apiKey;
  final http.Client _http;
  final String? _key;

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> args,
  ) async {
    final key = _key ?? await MapsConfiguration.apiKey();
    if (key.isEmpty) {
      throw const MapVinaFailure(
        'Bản đồ chưa được cấu hình. Bạn vẫn có thể nhập địa chỉ thủ công.',
      );
    }
    try {
      final uri = Uri.https('maps.mapvina.com', path, {
        ...args,
        'key': key,
        'language': 'vi',
      });
      final response = await _http
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 429) {
        throw const MapVinaFailure(
          'Dịch vụ bản đồ đang giới hạn lượt truy cập. Vui lòng thử lại sau.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const MapVinaFailure(
          'Chưa kết nối được dịch vụ bản đồ. Vui lòng thử lại.',
        );
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) throw const FormatException();
      final status = body['status'];
      if (status == 'ZERO_RESULTS' || status == 'NOT_FOUND') return {};
      if (status == 'OVER_QUERY_LIMIT') {
        throw const MapVinaFailure(
          'Dịch vụ bản đồ đang giới hạn lượt truy cập. Vui lòng thử lại sau.',
        );
      }
      if (status != 'OK') {
        throw const MapVinaFailure(
          'Dịch vụ bản đồ chưa xử lý được yêu cầu. Vui lòng thử lại sau.',
        );
      }
      return body;
    } on MapVinaFailure {
      rethrow;
    } on TimeoutException {
      throw const MapVinaFailure(
        'Dịch vụ bản đồ phản hồi chậm. Bạn có thể nhập địa chỉ thủ công hoặc thử lại.',
      );
    } catch (_) {
      // Provider URLs contain the key; never expose raw errors or payloads.
      throw const MapVinaFailure(
        'Chưa tải được dữ liệu bản đồ. Kiểm tra kết nối rồi thử lại.',
      );
    }
  }

  List<MapVinaPlace> _places(Map<String, dynamic> data) {
    final results = data['results'];
    if (results is! List) return [];
    return results
        .whereType<Map>()
        .map((p) {
          final address = p['formatted_address'] ?? p['name'];
          final location = p['geometry'] is Map
              ? p['geometry']['location']
              : null;
          final lat = location is Map ? location['lat'] : null;
          final lng = location is Map ? location['lng'] : null;
          if (address is! String ||
              address.trim().isEmpty ||
              lat is! num ||
              lng is! num ||
              !lat.isFinite ||
              !lng.isFinite ||
              lat.abs() > 90 ||
              lng.abs() > 180) {
            return null;
          }
          return MapVinaPlace(
            address.trim(),
            LatLng(lat.toDouble(), lng.toDouble()),
          );
        })
        .whereType<MapVinaPlace>()
        .take(5)
        .toList();
  }

  Future<List<MapVinaPlace>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return _places(
      await _get('/api/v2/place/textsearch/json', {'query': query.trim()}),
    );
  }

  Future<MapVinaPlace> reverse(LatLng point) async {
    final places = _places(
      await _get('/api/v2/geocode/json', {
        'latlng': '${point.latitude},${point.longitude}',
        'size': '1',
      }),
    );
    if (places.isEmpty) {
      throw const MapVinaFailure(
        'Chưa xác định được địa chỉ tại điểm này. Hãy nhập địa chỉ thủ công.',
      );
    }
    // Reverse lookup supplies the label; retain the exact pin/GPS coordinates.
    return MapVinaPlace(places.first.address, point);
  }

  Future<MapVinaRoute> route(LatLng from, LatLng to) async {
    final data = await _get('/route/v2/directions/json', {
      'origin': '${from.latitude},${from.longitude}',
      'destination': '${to.latitude},${to.longitude}',
      'mode': 'driving',
    });
    try {
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        throw const MapVinaFailure(
          'Chưa tìm được tuyến đường đến địa chỉ này.',
        );
      }
      final route = routes.first as Map;
      final points = decodePolyline(
        route['overview_polyline']['points'] as String,
      );
      if (points.length < 2) throw const FormatException();
      double meters = 0, seconds = 0;
      final instructions = <String>[];
      for (final leg in route['legs'] as List) {
        meters += (leg['distance']['value'] as num).toDouble();
        seconds += (leg['duration']['value'] as num).toDouble();
        for (final step in (leg['steps'] as List? ?? [])) {
          final html = step['html_instructions'];
          if (html is String) {
            final plain = html
                .replaceAll(RegExp('<[^>]*>'), ' ')
                .replaceAll('&nbsp;', ' ')
                .replaceAll('&amp;', '&')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            if (plain.isNotEmpty) instructions.add(plain);
          }
        }
      }
      if (!meters.isFinite || !seconds.isFinite || meters < 0 || seconds < 0) {
        throw const FormatException();
      }
      return MapVinaRoute(points, meters, seconds, instructions);
    } on MapVinaFailure {
      rethrow;
    } catch (_) {
      throw const MapVinaFailure(
        'Dữ liệu tuyến đường chưa hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  void close() => _http.close();
}

List<LatLng> decodePolyline(String encoded) {
  if (encoded.length > 200000) throw const FormatException();
  var index = 0, lat = 0, lng = 0;
  int delta() {
    var result = 0, shift = 0, byte = 0;
    do {
      if (index >= encoded.length || shift > 30) throw const FormatException();
      byte = encoded.codeUnitAt(index++) - 63;
      if (byte < 0 || byte > 63) throw const FormatException();
      result |= (byte & 31) << shift;
      shift += 5;
    } while (byte >= 32);
    return result.isOdd ? ~(result >> 1) : result >> 1;
  }

  final points = <LatLng>[];
  while (index < encoded.length) {
    lat += delta();
    lng += delta();
    if (lat.abs() > 9000000 || lng.abs() > 18000000) {
      throw const FormatException();
    }
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
