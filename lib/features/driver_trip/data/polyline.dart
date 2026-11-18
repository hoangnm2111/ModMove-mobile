import '../domain/entities/trip_models.dart';

/// Giải mã polyline kiểu Google. MapVina Directions dùng 5 chữ số thập phân (đã đối chiếu với toạ độ trong cùng response).
List<GeoPoint> decodePolyline(String encoded, {int precision = 5}) {
  final scale = _pow10(precision);
  final points = <GeoPoint>[];
  var i = 0, lat = 0, lng = 0;
  int next() {
    var shift = 0, value = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(i++) - 63;
      value |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (value & 1) != 0 ? ~(value >> 1) : value >> 1;
  }

  while (i < encoded.length) {
    lat += next();
    lng += next();
    points.add(GeoPoint(lat / scale, lng / scale));
  }
  return points;
}

double _pow10(int n) => n == 0 ? 1 : 10 * _pow10(n - 1);
