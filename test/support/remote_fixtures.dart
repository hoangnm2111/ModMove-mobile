import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:modmove_mobile/core/network/api_client.dart';

class MemorySessionStore implements SessionStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Map<String, dynamic> tokens([
  String token = 'access',
  String role = 'Driver',
]) => {
  'accessToken': token,
  'refreshToken': 'refresh-$token',
  'userId': 8,
  'fullName': 'Tài Xế Test',
  'role': role,
};
http.Response jsonResponse(Object value, [int code = 200]) => http.Response(
  jsonEncode(value),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
final testVehicle = {
  'id': 3,
  'name': 'Xe tải 1 tấn',
  'maxLoadWeightKg': 1000,
  'cargoBedLengthCm': 310,
  'cargoBedWidthCm': 160,
  'cargoBedHeightCm': 160,
  'baseFare': 90000,
  'pricePerKm': 15000,
  'minimumFare': 90000,
};
Map<String, dynamic> driverStatus({bool online = false, int? orderId}) => {
  'hasProfile': true,
  'approvalStatus': 'Approved',
  'isOnline': online,
  'vehicleTypeId': 3,
  'licensePlate': '51C-123.45',
  'depositBalance': 250000,
  'earningsBalance': 120000,
  'activeOrderId': orderId,
  'isGpsStale': false,
  'canReceiveOrders': online && orderId == null,
};
Map<String, dynamic> nearbyOrder(DateTime now) => {
  'orderId': 42,
  'orderCode': 'MM0042',
  'pickupAddress': '12 Nguyễn Văn Linh',
  'pickupLatitude': 10.7348,
  'pickupLongitude': 106.7057,
  'dropoffAddress': '85 Điện Biên Phủ',
  'dropoffLatitude': 10.8001,
  'dropoffLongitude': 106.7102,
  'distanceToPickupKm': 1.2,
  'estimatedDistanceKm': 8.4,
  'estimatedDurationMin': 35,
  'totalFee': 240000,
  'commissionAmount': 36000,
  'driverEarning': 204000,
  'paymentMethod': 'Cash',
  'payerRole': 'Receiver',
  'hasLoadingService': false,
  'cargoType': 'Furniture',
  'cargoQuantity': 8,
  'cargoWeightKg': 250,
  'cargoLengthCm': 80,
  'cargoWidthCm': 60,
  'cargoHeightCm': 50,
  'cargoPhotoUrls': [],
  'createdAt': now.toUtc().toIso8601String(),
};
