import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/domain/entities/customer_models.dart';

void main() {
  group('tài khoản nhận hoàn tiền (BE R-01)', () {
    test('tên chủ tài khoản: in hoa, bỏ dấu, chỉ A-Z và dấu cách', () {
      expect(PayoutAccountInput.normalizeHolder('Nguyễn Văn Đạt'), 'NGUYEN VAN DAT');
      expect(PayoutAccountInput.normalizeHolder('trần thị b-1'), 'TRAN THI B');
    });

    test('kiểm tra theo luật của BE', () {
      String? check(String? bank, String number, String holder) => PayoutAccountInput.validate(bankCode: bank, number: number, holder: holder);
      expect(check(null, '123456', 'A B'), isNotNull);
      expect(check('970436', '12345', 'A B'), contains('6 đến 19'));
      expect(check('970436', '12345678901234567890', 'A B'), contains('6 đến 19'));
      expect(check('970436', '123456', 'A'), contains('2 đến 100'));
      expect(check('970436', '0900000005', 'NGUYEN VAN A'), isNull);
    });

    test('gửi khiếu nại kèm payoutAccount đúng hình dạng BE', () async {
      Map<String, dynamic>? sent;
      String? path;
      final client = MockClient((request) async {
        path = request.url.path;
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'refundId': 5}), 201, headers: {'content-type': 'application/json'});
      });
      final api = CustomerApi(
        ApiClient(
          sessions: MemorySessionStore(const Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'K', role: 'Customer')),
          client: client,
          baseUrl: 'http://test/api',
        ),
      );
      await api.submitComplaint(
        orderId: 9,
        reasonCode: 'DAMAGED',
        requestedAmount: 100000,
        payoutAccount: const PayoutAccountInput(bankCode: '970436', accountNumber: '0900000005', accountHolder: 'NGUYEN VAN A'),
      );
      expect(path, '/api/customer/Refunds/complaints');
      expect(sent!['payoutAccount'], {'useSuggested': false, 'bankCode': '970436', 'accountNumber': '0900000005', 'accountHolder': 'NGUYEN VAN A'});
    });

    test('chi tiết khoản hoàn hiện tài khoản đã che số và cần khai tài khoản', () {
      final refund = MyRefund.fromJson({
        'id': 3,
        'orderId': 9,
        'sourceType': 'Cancellation',
        'refundStatus': 'Approved',
        'requestedAmount': 150000,
        'createdAt': '2026-11-11T08:00:00+00:00',
        'needsPayoutAccount': true,
        'payoutAccount': {'bankCode': '970436', 'bankName': 'Vietcombank', 'maskedAccountNumber': '•••• 0005', 'accountHolder': 'NGUYEN VAN A'},
        'payoutFailureReason': 'Sai tên chủ tài khoản',
      });
      expect(refund.needsPayoutAccount, isTrue);
      expect(refund.payoutAccount!.maskedAccountNumber, '•••• 0005');
      expect(refund.payoutFailureReason, 'Sai tên chủ tài khoản');
    });
  });
}
