import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/presentation/booking/booking_cubit.dart';

import 'fixtures.dart';

const _session = Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'Khách', role: 'Customer');

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

/// Lỗi cũ: mã giảm giá chưa đủ giá trị tối thiểu làm báo giá thất bại → màn hình hiện 0 ₫ và 0 km,
/// khách không biết cước thật là bao nhiêu để hiểu vì sao chưa đủ điều kiện.
void main() {
  late List<String?> couponsAsked;

  BookingCubit build() {
    couponsAsked = [];
    final client = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('/public/VehicleTypes')) {
        return _json([
          {'id': 1, 'name': 'Xe van 500kg', 'maxLoadWeightKg': 500, 'cargoBedLengthCm': 300, 'cargoBedWidthCm': 150, 'cargoBedHeightCm': 150, 'baseFare': 50000, 'pricePerKm': 10000, 'minimumFare': 80000},
        ]);
      }
      if (p.endsWith('/public/Lookups/cargo-types')) {
        return _json([
          {'code': 'GOODS', 'name': 'Hàng hoá', 'description': null},
        ]);
      }
      if (p.endsWith('/customer/Coupons')) return _json(paged([]));
      if (p.endsWith('/public/FareEstimate')) {
        final coupon = (jsonDecode(req.body) as Map)['couponCode'] as String?;
        couponsAsked.add(coupon);
        if (coupon != null && coupon.isNotEmpty) {
          return _json({'status': 422, 'title': 'x', 'code': 'COUPON_MIN_ORDER_NOT_MET'}, 422);
        }
        return _json({'distanceKm': 10.43, 'durationMinutes': 21, 'distanceFee': 154300, 'serviceFee': 0, 'discountAmount': 0, 'totalFee': 154300});
      }
      return _json({'code': 'NOT_FOUND'}, 404);
    });
    final api = ApiClient(sessions: MemorySessionStore(_session), baseUrl: 'http://api', client: client);
    return BookingCubit(CustomerApi(api));
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 900));

  test('mã chưa đủ giá trị tối thiểu: vẫn hiện cước không có mã, kèm lỗi mã, và chặn đặt đơn', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.loadLookups();
    cubit.update(
      (d) => d.copyWith(
        pickupAddress: '208 Nguyễn Hữu Cảnh, Bình Thạnh',
        dropoffAddress: '268 Lý Thường Kiệt, Quận 10',
        weightKg: 20,
        lengthCm: 40,
        widthCm: 30,
        heightCm: 30,
        vehicleTypeId: 1,
        couponCode: 'MODMOVE100K',
        agreedWarranty: true,
      ),
    );
    await settle();

    expect(cubit.state.estimate, isNotNull);
    expect(cubit.state.estimate!.totalFee, 154300);
    expect(cubit.state.estimate!.distanceKm, 10.43);
    expect(cubit.state.couponError, 'Đơn chưa đạt giá trị tối thiểu để dùng mã này.');
    expect(cubit.state.estimateError, isNull);
    // Gọi hai lần: có mã (bị từ chối) rồi không mã (CustomerApi gửi null khi mã trống) để lấy cước.
    expect(couponsAsked, ['MODMOVE100K', null]);
    // Vẫn không cho đặt đơn khi mã còn lỗi.
    expect(cubit.validate(3), 'Đơn chưa đạt giá trị tối thiểu để dùng mã này.');
  });

  test('bỏ mã đi thì hết lỗi và đặt được', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.loadLookups();
    cubit.update(
      (d) => d.copyWith(
        pickupAddress: '208 Nguyễn Hữu Cảnh, Bình Thạnh',
        dropoffAddress: '268 Lý Thường Kiệt, Quận 10',
        weightKg: 20,
        lengthCm: 40,
        widthCm: 30,
        heightCm: 30,
        vehicleTypeId: 1,
        couponCode: 'MODMOVE100K',
        agreedWarranty: true,
      ),
    );
    await settle();
    cubit.update((d) => d.copyWith(couponCode: ''));
    await settle();

    expect(cubit.state.couponError, isNull);
    expect(cubit.state.estimate!.totalFee, 154300);
    expect(cubit.validate(3), isNull);
  });
}
