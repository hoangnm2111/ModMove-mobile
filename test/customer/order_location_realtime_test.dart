import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/notifications/realtime_source.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/presentation/order_detail/order_detail_cubit.dart';

import 'fixtures.dart';

/// MB-6 (A1): khách nhận `LocationUpdated` của đúng đơn đang xem.
CustomerApi _api() {
  http.Response json(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
  final client = MockClient((request) async {
    final p = request.url.path;
    if (p.endsWith('/customer/Orders/7/tracking')) {
      return json({
        'orderId': 7,
        'orderStatus': 'InTransit',
        'pickup': {'latitude': 10.0, 'longitude': 106.0},
        'dropoff': {'latitude': 10.9, 'longitude': 106.9},
        'driver': {'latitude': 10.5, 'longitude': 106.5, 'at': '2026-11-18T02:00:00Z', 'isStale': true},
        'eta': {'target': 'Dropoff', 'durationMinutes': 12},
      });
    }
    if (p.endsWith('/customer/Orders/7')) return json(orderDetailJson(id: 7, status: 'InTransit', proofStatus: 'Verified'));
    return json(paged([])); // sự cố, hoàn tiền, đánh giá: rỗng
  });
  final sessions = MemorySessionStore(const Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'K', role: 'Customer'));
  return CustomerApi(ApiClient(sessions: sessions, client: client, baseUrl: 'http://test/api'));
}

Map<String, Object?> _payload(int orderId, double lat, double lng, String at) => {'driverProfileId': 3, 'orderId': orderId, 'latitude': lat, 'longitude': lng, 'at': at};

void main() {
  late StreamController<Map<String, Object?>> locations;
  late OrderDetailCubit cubit;
  setUp(() {
    locations = StreamController<Map<String, Object?>>.broadcast(sync: true);
    cubit = OrderDetailCubit(_api(), 7, locations: locations.stream);
  });
  tearDown(() async {
    await cubit.close();
    await locations.close();
  });

  test('LocationUpdated đúng đơn: đổi vị trí và giờ, hết mất tín hiệu, giữ nguyên ETA', () async {
    await cubit.load();
    expect(cubit.state.tracking!.driverStale, isTrue);
    locations.add(_payload(7, 10.6, 106.6, '2026-11-18T03:30:00Z'));
    final t = cubit.state.tracking!;
    expect((t.driver!.latitude, t.driver!.longitude), (10.6, 106.6));
    expect(t.driverAt!.isAtSameMomentAs(DateTime.utc(2026, 11, 18, 3, 30)), isTrue);
    expect(t.driverStale, isFalse);
    expect((t.etaTarget, t.etaMinutes), ('Dropoff', 12));
    expect(t.dropoff.latitude, 10.9);
  });

  test('LocationUpdated của đơn khác hoặc sai dạng thì bỏ qua', () async {
    await cubit.load();
    locations.add(_payload(8, 10.6, 106.6, '2026-11-18T03:30:00Z'));
    locations.add({'orderId': 7, 'latitude': 'x'});
    locations.add({'latitude': 10.6, 'longitude': 106.6});
    expect(cubit.state.tracking!.driver!.latitude, 10.5);
    expect(cubit.state.tracking!.driverStale, isTrue);
  });

  test('chưa tải được tracking thì chưa có gì để cập nhật', () {
    locations.add(_payload(7, 10.6, 106.6, '2026-11-18T03:30:00Z'));
    expect(cubit.state.tracking, isNull);
  });

  test('OrderRooms: nhớ các đơn đã join, kết nối lại thì gọi lại JoinOrder, đã leave thì không', () async {
    final calls = <String>[];
    final rooms = OrderRooms((method, orderId) async => calls.add('$method $orderId'));
    await rooms.join(5);
    await rooms.join(6);
    rooms.leave(5);
    calls.clear();
    await rooms.rejoin();
    expect(calls, ['JoinOrder 6']);
  });
}
