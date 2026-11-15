import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:modmove_mobile/features/customer/domain/customer_models.dart';
import 'package:modmove_mobile/features/customer/data/remote_customer_repository.dart';
import 'package:modmove_mobile/features/notifications/domain/driver_notification.dart';
import 'support/customer_fixtures.dart';
import 'support/remote_fixtures.dart';

void main() {
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
