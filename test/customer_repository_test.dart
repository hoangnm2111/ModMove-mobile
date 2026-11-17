import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/domain/account_input.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:modmove_mobile/features/customer/domain/customer_models.dart';
import 'package:modmove_mobile/features/customer/data/remote_customer_repository.dart';
import 'package:modmove_mobile/features/notifications/domain/driver_notification.dart';
import 'support/customer_fixtures.dart';
import 'support/remote_fixtures.dart';

void main() {
  test(
    'international Vietnam phone is normalized for signup, profile and booking',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await RemoteAuthRepository(t.api).register(
        'Customer',
        '+84901234567',
        'c@test.local',
        'Password123',
        role: 'Customer',
      );
      expect(requestBody(t.requests.last)['phoneNumber'], '0901234567');
      await t.login();
      await t.repository.updateProfile('Customer', ' +84901234567 ');
      expect(requestBody(t.requests.last)['phoneNumber'], '0901234567');
      await t.repository.book(validDraft.copyWith(phone: '+84901234567'), fare);
      expect(requestBody(t.requests.last)['receiverPhone'], '0901234567');
      expect(isVietnamesePhone('+840901234567'), false);
      expect(isVietnamesePhone('phone0901234567'), false);
      expect(isValidNewPassword('12345678'), false);
      expect(isValidNewPassword('Abc12345'), true);
    },
  );
  test(
    'history filters preserve calendar dates and combine server-side predicates',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      await t.repository.orders(
        page: 3,
        view: 'History',
        search: 'Q1 & Q2',
        filter: CustomerOrderFilter(
          status: 'Cancelled',
          from: DateTime(2026, 11, 1),
          to: DateTime(2026, 11, 17),
          phone: '090',
        ),
      );
      expect(t.requests.last.url.queryParameters, {
        'page': '3',
        'view': 'History',
        'search': 'Q1 & Q2',
        'status': 'Cancelled',
        'fromDate': '2026-11-01',
        'toDate': '2026-11-17',
        'receiverPhone': '090',
      });
    },
  );
  test(
    'invalid oversized or non-finite booking values never reach the API',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      for (final draft in [
        validDraft.copyWith(pickup: 'x' * 256),
        validDraft.copyWith(weight: double.nan),
        validDraft.copyWith(weight: double.infinity),
        validDraft.copyWith(coupon: 'A' * 51),
        validDraft.copyWith(payment: 'Cash', payer: ''),
      ]) {
        await expectLater(
          t.repository.book(draft, fare),
          throwsA(isA<CustomerFailure>()),
        );
      }
      expect(t.requests, isEmpty);
    },
  );
  test(
    'rebooking preserves cargo codes but requires fresh vehicle, fare and consent',
    () async {
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.endsWith('/orders/1')) {
            final j = customerOrder(status: 'Cancelled');
            j['couponCode'] = 'EXPIRED';
            (j['proof'] as Map)['rejectionReason'] = 'Chụp lại tem niêm phong';
            (j['proof'] as Map)['pickupSubmissionCount'] = 3;
            return jsonResponse(j);
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final order = await t.repository.order(1);
      final draft = BookingDraft.fromOrder(order);
      expect(draft.cargoType, 'OTHER');
      expect(draft.receiver, order.summary.receiver);
      expect(draft.notes, order.notes);
      expect(draft.vehicleId, isNull);
      expect(draft.coupon, isEmpty);
      expect(draft.committed, false);
      expect(order.pickupSubmissionCount, 3);
      expect(order.pickupRejection, 'Chụp lại tem niêm phong');
    },
  );
  test(
    'registration role uses separate real endpoint and reset uses OTP contract',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      final auth = RemoteAuthRepository(t.api);
      await auth.register(
        'Customer',
        '0901234567',
        'c@test.local',
        'Password123',
        role: 'Customer',
      );
      await auth.forgotPassword('c@test.local');
      await auth.resetPassword('c@test.local', '123456', 'NewPassword123');
      expect(t.requests.map((r) => r.url.path), [
        '/api/public/auth/register',
        '/api/public/auth/forgot-password',
        '/api/public/auth/reset-password',
      ]);
      expect(requestBody(t.requests.last), {
        'email': 'c@test.local',
        'code': '123456',
        'newPassword': 'NewPassword123',
      });
      expect(
        t.requests.every((r) => !r.headers.containsKey('Authorization')),
        true,
      );
    },
  );
  test('Admin and Dispatcher cannot be restored as mobile roles', () {
    for (final role in ['Admin', 'Administrator', 'Dispatcher', '']) {
      expect(
        () => ApiSession.fromJson(tokens('access', role)),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test(
    'public catalog is anonymous; orders filter is URL encoded and authenticated',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      final catalog = await t.repository.catalog();
      expect(catalog.vehicles.single.weight, 500);
      expect(
        t.requests.every((r) => !r.headers.containsKey('Authorization')),
        true,
      );
      await t.login();
      await t.repository.orders(page: 2, view: 'History', search: 'MM & Q1');
      expect(t.requests.last.url.queryParameters, {
        'page': '2',
        'view': 'History',
        'search': 'MM & Q1',
      });
      expect(t.requests.last.headers['Authorization'], 'Bearer access');
    },
  );
  test(
    'booking sends full declaration and authoritative expected fare; PayOS has no cash payer',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      final result = await t.repository.book(validDraft, fare);
      final body = requestBody(t.requests.last);
      expect(result.id, 99);
      expect(body['expectedTotalFee'], 90000);
      expect(body['payerRole'], isNull);
      expect(body['cargo'], {
        'cargoType': 'OTHER',
        'quantity': 2,
        'weightKg': 5.0,
        'lengthCm': 20,
        'widthCm': 30,
        'heightCm': 40,
        'photoUrls': validDraft.photos,
        'specialNotes': '',
      });
      expect(body['prohibitedGoodsCommitment'], true);
      expect(body.containsKey('weightKg'), false);
      await t.repository.book(
        validDraft.copyWith(payment: 'Cash', payer: 'Receiver'),
        fare,
      );
      expect(requestBody(t.requests.last)['payerRole'], 'Receiver');
    },
  );
  test('invalid declarations do not send a booking request', () async {
    final t = CustomerTestApi();
    addTearDown(t.close);
    await t.login();
    for (final draft in [
      validDraft.copyWith(photos: []),
      validDraft.copyWith(committed: false),
      validDraft.copyWith(quantity: 0),
    ]) {
      await expectLater(
        t.repository.book(draft, fare),
        throwsA(isA<CustomerFailure>()),
      );
    }
    expect(t.requests, isEmpty);
  });
  test('vehicle fit allows rotation but not excess weight/dimensions', () {
    const v = Vehicle(1, 'Xe', 100, 100, 70, 50);
    expect(
      v.fits(validDraft.copyWith(length: 50, width: 100, height: 70)),
      true,
    );
    expect(v.fits(validDraft.copyWith(weight: 101)), false);
    expect(v.fits(validDraft.copyWith(length: 101)), false);
  });
  test(
    'pickup review, receipt and cancellation use the exact server actions',
    () async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      await t.repository.reviewPickup(1, false, 'Chụp lại mặt kiện');
      await t.repository.confirmReceipt(1);
      await t.repository.cancel(1, 'OTHER', 'Thay đổi địa chỉ');
      expect(t.requests.map((r) => r.url.path), [
        '/api/customer/orders/1/pickup-evidence',
        '/api/customer/orders/1/confirm-receipt',
        '/api/customer/orders/1/cancel',
      ]);
      expect(requestBody(t.requests[0]), {
        'approve': false,
        'reason': 'Chụp lại mặt kiện',
      });
      expect(requestBody(t.requests[2]), {
        'reasonCode': 'OTHER',
        'reason': 'Thay đổi địa chỉ',
      });
    },
  );
  test('incident includes real GPS and already uploaded photo URLs', () async {
    final t = CustomerTestApi();
    addTearDown(t.close);
    await t.login();
    await t.repository.report(
      1,
      'DamagedCargo',
      'Hàng móp',
      validDraft.photos,
      const GeoPosition(10.7, 106.7),
    );
    final body = requestBody(t.requests.last);
    expect(body['latitude'], 10.7);
    expect(body['longitude'], 106.7);
    expect(body['photoUrls'], validDraft.photos);
  });
  test('refund bank suggestions never send a masked number back', () async {
    final t = CustomerTestApi();
    addTearDown(t.close);
    await t.login();
    await t.repository.setPayout(
      1,
      const PayoutAccount(
        suggested: true,
        number: '******6789',
        bankCode: '970436',
        holder: 'A',
      ),
    );
    expect(requestBody(t.requests.last), {
      'useSuggested': true,
      'bankCode': null,
      'accountNumber': null,
      'accountHolder': null,
    });
  });
  test('processed refunds cannot be withdrawn or have their bank edited', () {
    final r = RemoteCustomerRepository.refundModel(
      customerRefund(status: 'Processed'),
    );
    expect(r.canSetBank, false);
    expect(r.canWithdraw, false);
    expect(
      RemoteCustomerRepository.refundModel(
        customerRefund(source: 'Cancellation'),
      ).canWithdraw,
      false,
    );
  });
  test(
    'refund creation and supplemental evidence are correctly routed',
    () async {
      final t = CustomerTestApi(
        handler: (r) async =>
            r.method == 'POST' && r.url.path.endsWith('/complaints')
            ? jsonResponse({'refundId': 23}, 201)
            : null,
      );
      addTearDown(t.close);
      await t.login();
      final id = await t.repository.complain(
        1,
        'OTHER',
        'Hỏng hàng',
        validDraft.photos,
        10000,
        const PayoutAccount(
          bankCode: '970436',
          number: '123456789',
          holder: 'NGUYEN A',
        ),
      );
      expect(id, 23);
      expect(requestBody(t.requests.last)['requestedAmount'], 10000);
      await t.repository.replyRefund(23, 'Đã bổ sung', []);
      expect(t.requests.last.url.path, '/api/customer/Refunds/23/reply');
      expect(requestBody(t.requests.last), {
        'reply': 'Đã bổ sung',
        'photoUrls': [],
      });
      await t.repository.withdrawRefund(23);
      expect(t.requests.last.url.path, '/api/customer/Refunds/23/withdraw');
    },
  );
  test(
    'payment return URL is not evidence of Paid and link errors produce no QR',
    () async {
      final t = CustomerTestApi(
        handler: (r) async => r.url.path.endsWith('/payment')
            ? jsonResponse({'code': 'SERVER_ERROR', 'detail': 'private'}, 500)
            : null,
      );
      addTearDown(t.close);
      await t.login();
      await expectLater(
        t.repository.payment(1),
        throwsA(isA<CustomerFailure>()),
      );
      expect(requestBody(t.requests.last), {'platform': 'App'});
    },
  );
  test(
    'complaint and rating windows follow Delivered versus Completed and 24 hours',
    () async {
      var raw = customerOrder(
        status: 'Delivered',
        at: DateTime.utc(2026, 1, 1),
      );
      final t = CustomerTestApi(handler: (r) async => jsonResponse(raw));
      addTearDown(t.close);
      await t.login();
      var o = await t.repository.order(1);
      expect(o.canComplainAt(DateTime.utc(2026, 1, 1, 23, 59)), true);
      expect(o.canComplainAt(DateTime.utc(2026, 1, 2)), false);
      expect(o.canRateAt(DateTime.utc(2026, 1, 1, 23)), false);
      raw = customerOrder(status: 'Completed', at: DateTime.utc(2026, 1, 1));
      o = await t.repository.order(1);
      expect(o.canRateAt(DateTime.utc(2026, 1, 1, 23)), true);
      expect(o.canComplainAt(DateTime.utc(2026, 1, 1, 23)), false);
    },
  );
  test(
    'driver incident blocks pickup approval; no fake matching countdown without paid timestamp',
    () async {
      var raw = customerOrder(pendingIncident: 8);
      final t = CustomerTestApi(handler: (r) async => jsonResponse(raw));
      addTearDown(t.close);
      await t.login();
      expect((await t.repository.order(1)).canReview, false);
      raw = customerOrder(status: 'Pending', payment: 'Unpaid');
      expect((await t.repository.order(1)).matchingStarted, isNull);
      raw = customerOrder(status: 'Pending');
      expect((await t.repository.order(1)).matchingStarted, isNotNull);
      raw['payment'] = null;
      expect((await t.repository.order(1)).matchingStarted, isNull);
    },
  );
  test(
    'customer notifications route by known type and validated positive IDs',
    () {
      const incoming = DriverNotification(
        data: {'type': 'PICKUP_PHOTOS_TO_REVIEW', 'orderId': '12'},
      );
      expect(incoming.canOpen, true);
      expect(incoming.customerRoute, '/order');
      expect(incoming.route, isNull);
      expect(
        const DriverNotification(
          data: {
            'type': 'REFUND_INFO_REQUESTED',
            'orderId': '1',
            'refundId': '8',
          },
        ).customerRoute,
        '/refund',
      );
      expect(
        const DriverNotification(
          data: {'type': 'ORDER_ACCEPTED', 'orderId': '-1'},
        ).customerRoute,
        isNull,
      );
      expect(
        const DriverNotification(
          data: {'type': 'UNKNOWN', 'orderId': '1'},
        ).canOpen,
        false,
      );
    },
  );
}
