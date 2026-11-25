import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/customer/data/booking_draft_store.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/domain/entities/customer_models.dart';
import 'package:modmove_mobile/features/customer/domain/order_rules.dart';
import 'package:modmove_mobile/features/customer/presentation/booking/booking_cubit.dart';

import 'fixtures.dart';

const _session = Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'Khách', role: 'Customer');

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

const _route = BookingDraft(
  pickupAddress: '12 Nguyễn Huệ, Hoàn Kiếm',
  senderName: 'Chị Hoa',
  senderPhone: '0987654321',
  dropoffAddress: '45 Cầu Giấy, Hà Nội',
  receiverName: 'Anh Nam',
  receiverPhone: '+84 912 345 678',
);

/// Đặt xe trên app theo cùng luật với web: người gửi, ghi chú, số di động, hai điểm khác nhau, báo giá lại trước khi gửi.
void main() {
  group('InputRules', () {
    test('chỉ nhận số di động Việt Nam: 0 hoặc +84, đầu 3/5/7/8/9, 8 chữ số', () {
      for (final ok in ['0912345678', '+84912345678', '0381234567', '0 912 345 678', '0912.345.678']) {
        expect(InputRules.phone(ok), isTrue, reason: ok);
      }
      for (final bad in ['0212345678', '091234567', '09123456789', '+8402345678', '123', '0612345678']) {
        expect(InputRules.phone(bad), isFalse, reason: bad);
      }
      expect(InputRules.normalizePhone('+84 912 345 678'), '0912345678');
    });

    test('hai địa chỉ giống nhau không phân biệt hoa thường và khoảng trắng hai đầu', () {
      expect(InputRules.sameAddress(' 12 Nguyễn Huệ ', '12 nguyễn huệ'), isTrue);
      expect(InputRules.sameAddress('12 Nguyễn Huệ', '14 Nguyễn Huệ'), isFalse);
    });
  });

  group('mô hình dữ liệu từ BE', () {
    test('chi tiết đơn có người gửi và ghi chú hai điểm', () {
      final o = OrderDetail.fromJson({
        ...orderDetailJson(),
        'senderName': 'Chị Hoa',
        'senderPhone': '0987654321',
        'pickupNote': 'Cửa hầm B1',
        'dropoffNote': 'Gọi trước 15 phút',
      });
      expect(
        (o.senderName, o.senderPhone, o.pickupNote, o.dropoffNote),
        ('Chị Hoa', '0987654321', 'Cửa hầm B1', 'Gọi trước 15 phút'),
      );
    });

    test('đơn đặt trước khi có người gửi: các trường là null, ghi chú trống cũng là null', () {
      final old = OrderDetail.fromJson(orderDetailJson());
      expect((old.senderName, old.senderPhone, old.pickupNote, old.dropoffNote), (null, null, null, null));
      final blank = OrderDetail.fromJson({...orderDetailJson(), 'senderName': '  ', 'pickupNote': ''});
      expect((blank.senderName, blank.pickupNote), (null, null));
    });

    test('báo giá có hai điểm và đường đi; BE cũ không trả thì là null', () {
      final e = FareEstimate.fromJson({
        'distanceKm': 10.4,
        'durationMinutes': 21,
        'distanceFee': 154000,
        'serviceFee': 0,
        'discountAmount': 0,
        'totalFee': 154000,
        'pickup': {'latitude': 21.03, 'longitude': 105.85},
        'dropoff': {'latitude': 21.04, 'longitude': 105.8},
        'polyline': '_p~iF~ps|U',
      });
      expect((e.pickup!.latitude, e.dropoff!.longitude, e.polyline), (21.03, 105.8, '_p~iF~ps|U'));
      final legacy = FareEstimate.fromJson({
        'distanceKm': 10.4,
        'durationMinutes': 21,
        'distanceFee': 154000,
        'serviceFee': 0,
        'discountAmount': 0,
        'totalFee': 154000,
      });
      expect((legacy.pickup, legacy.dropoff, legacy.polyline), (null, null, null));
    });

    test('đặt lại đơn cũ: đưa người gửi, ghi chú và mô tả vào nháp mới', () {
      // OrderDetailScreen._draftFrom dùng đúng các trường này.
      final o = OrderDetail.fromJson({
        ...orderDetailJson(),
        'senderName': 'Chị Hoa',
        'senderPhone': '0987654321',
        'pickupNote': 'Cửa hầm B1',
      });
      final d = BookingDraft(
        pickupAddress: o.pickupAddress,
        senderName: o.senderName ?? '',
        senderPhone: o.senderPhone ?? '',
        pickupNote: o.pickupNote ?? '',
      );
      expect(d.hasContent, isTrue);
      expect(d.toJson()['senderName'], 'Chị Hoa');
      expect(BookingDraft.fromJson(d.toJson()).pickupNote, 'Cửa hầm B1');
    });
  });

  group('validate', () {
    BookingCubit cubit(BookingDraft d) => BookingCubit(
      CustomerApi(
        ApiClient(
          sessions: MemorySessionStore(_session),
          baseUrl: 'http://api',
          client: MockClient((_) async => _json({})),
        ),
      ),
      initial: d,
    );

    test('bước lộ trình cần người gửi, số di động hợp lệ và hai điểm khác nhau', () {
      expect(cubit(_route).validate(0), isNull);
      expect(cubit(_route.copyWith(senderName: ' ')).validate(0), 'Nhập tên người gửi.');
      expect(cubit(_route.copyWith(senderPhone: '0212345678')).validate(0), 'Nhập số điện thoại người gửi hợp lệ.');
      expect(
        cubit(_route.copyWith(dropoffAddress: ' 12 nguyễn huệ, hoàn kiếm ')).validate(0),
        'Điểm giao hàng phải khác điểm lấy hàng.',
      );
      expect(cubit(_route.copyWith(pickupNote: 'a' * 501)).validate(0), contains('tối đa 500 ký tự'));
      expect(cubit(_route.copyWith(dropoffNote: 'a' * 501)).validate(0), contains('tối đa 500 ký tự'));
    });

    test('mô tả và ghi chú bốc xếp gộp lại không quá 500 ký tự', () {
      final cargo = _route.copyWith(
        cargoType: 'GOODS',
        weightKg: 10,
        lengthCm: 10,
        widthCm: 10,
        heightCm: 10,
        photos: ['u'],
        noProhibitedCargo: true,
      );
      expect(cubit(cargo.copyWith(description: 'Tủ lạnh')).validate(1), isNull);
      expect(
        cubit(cargo.copyWith(description: 'a' * 300, specialNotes: 'b' * 300)).validate(1),
        contains('tối đa 500 ký tự'),
      );
      expect(
        BookingCubit.cargoNotes(cargo.copyWith(description: ' Tủ lạnh ', specialNotes: 'Dễ vỡ')),
        'Tủ lạnh • Dễ vỡ',
      );
      expect(BookingCubit.cargoNotes(cargo.copyWith(description: '', specialNotes: '')), isNull);
    });

    test('cam kết hàng cấm chỉ hỏi ở bước cuối: bước hàng hoá không còn chặn vì chưa tick', () {
      final cargo = _route.copyWith(cargoType: 'GOODS', description: 'Tủ lạnh', weightKg: 10, lengthCm: 10, widthCm: 10, heightCm: 10, photos: ['u']);
      expect(cubit(cargo).validate(1), isNull);
    });

    test('bước thanh toán cần cả cam kết hàng cấm và chính sách bảo hành', () {
      expect(
        cubit(_route.copyWith(agreedWarranty: true)).validate(3),
        'Vui lòng đồng ý chính sách bảo hành và cam kết không gửi hàng cấm.',
      );
      expect(
        cubit(_route.copyWith(noProhibitedCargo: true)).validate(3),
        'Vui lòng đồng ý chính sách bảo hành và cam kết không gửi hàng cấm.',
      );
    });
  });

  group('gửi đơn', () {
    late List<Map<String, dynamic>> created;
    late double nextTotal;

    BookingCubit build({BookingDraftStore? store}) {
      created = [];
      nextTotal = 154000;
      final client = MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/public/VehicleTypes')) {
          return _json([
            {
              'id': 1,
              'name': 'Xe van 500kg',
              'maxLoadWeightKg': 500,
              'cargoBedLengthCm': 300,
              'cargoBedWidthCm': 150,
              'cargoBedHeightCm': 150,
              'baseFare': 50000,
              'pricePerKm': 10000,
              'minimumFare': 80000,
            },
          ]);
        }
        if (p.endsWith('/public/Lookups/cargo-types')) {
          return _json([
            {'code': 'GOODS', 'name': 'Hàng hoá', 'description': null},
          ]);
        }
        if (p.endsWith('/customer/Coupons')) return _json(paged([]));
        if (p.endsWith('/public/FareEstimate')) {
          return _json({
            'distanceKm': 10.43,
            'durationMinutes': 21,
            'distanceFee': nextTotal,
            'serviceFee': 0,
            'discountAmount': 0,
            'totalFee': nextTotal,
            'pickup': {'latitude': 21.03, 'longitude': 105.85},
            'dropoff': {'latitude': 21.04, 'longitude': 105.80},
            'polyline': '_p~iF~ps|U_ulLnnqC',
          });
        }
        if (p.endsWith('/customer/Orders') && req.method == 'POST') {
          created.add(jsonDecode(req.body) as Map<String, dynamic>);
          return _json({'orderId': 9, 'orderCode': 'MM9', 'totalFee': nextTotal});
        }
        return _json({'code': 'NOT_FOUND'}, 404);
      });
      return BookingCubit(
        CustomerApi(ApiClient(sessions: MemorySessionStore(_session), baseUrl: 'http://api', client: client)),
        store: store,
      );
    }

    final ready = _route.copyWith(
      pickupNote: 'Cửa hầm B1',
      dropoffNote: 'Gọi trước 15 phút',
      cargoType: 'GOODS',
      description: 'Tủ lạnh',
      specialNotes: 'Dễ vỡ',
      weightKg: 20,
      lengthCm: 40,
      widthCm: 30,
      heightCm: 30,
      photos: ['https://res.cloudinary.com/x.jpg'],
      vehicleTypeId: 1,
      noProhibitedCargo: true,
      agreedWarranty: true,
      paymentMethod: 'Cash',
    );

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 900));

    test('gửi người gửi, ghi chú hai điểm, ghi chú hàng đã gộp và số điện thoại dạng 0…', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.loadLookups();
      cubit.update((_) => ready);
      await settle();
      expect(cubit.state.estimate!.pickup!.latitude, 21.03);
      expect(cubit.state.estimate!.polyline, isNotNull);

      await cubit.submit();

      final body = created.single;
      expect(body['senderName'], 'Chị Hoa');
      expect(body['senderPhone'], '0987654321');
      expect(body['receiverPhone'], '0912345678');
      expect(body['pickupNote'], 'Cửa hầm B1');
      expect(body['dropoffNote'], 'Gọi trước 15 phút');
      expect((body['cargo'] as Map)['specialNotes'], 'Tủ lạnh • Dễ vỡ');
      expect(body['expectedTotalFee'], 154000);
      expect(body['payerRole'], 'Sender');
    });

    test('giá đổi ngay trước khi gửi: không tạo đơn, hiện giá mới để khách xem lại', () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.loadLookups();
      cubit.update((_) => ready);
      await settle();
      nextTotal = 160000;

      await expectLater(cubit.submit(), throwsA(isA<FareChangedException>()));

      expect(created, isEmpty);
      expect(cubit.state.estimate!.totalFee, 160000);
      expect(cubit.state.submitting, isFalse);
      await cubit.submit(); // bấm đặt lại với giá mới
      expect(created.single['expectedTotalFee'], 160000);
    });

    test('nháp được lưu, mở lại không có mã giảm giá và ô đồng ý; gửi đơn xong thì xoá', () async {
      final store = MemoryBookingDraftStore();
      final first = build(store: store);
      await first.loadLookups();
      first.update((_) => ready.copyWith(couponCode: 'MODMOVE30'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await first.close();

      final again = build(store: store);
      addTearDown(again.close);
      await again.loadLookups();
      await again.restoreDraft();
      expect(again.state.restored, isTrue);
      expect(again.state.draft.senderName, 'Chị Hoa');
      expect(again.state.draft.pickupNote, 'Cửa hầm B1');
      expect(again.state.draft.couponCode, '');
      expect(again.state.draft.noProhibitedCargo, isFalse);
      expect(again.state.draft.agreedWarranty, isFalse);

      again.restart();
      expect(again.state.draft.hasContent, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(await store.load(), isNull);
    });

    test('nháp quá 24 giờ thì bỏ', () async {
      var now = DateTime(2026, 11, 24, 8);
      final store = MemoryBookingDraftStore(now: () => now);
      await store.save(ready.toJson(), 1);
      now = now.add(const Duration(hours: 24, minutes: 1));
      expect(await store.load(), isNull);
    });
  });
}
