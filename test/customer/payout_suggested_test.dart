import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/customer/domain/entities/customer_models.dart';

void main() {
  test('chọn tài khoản PayOS gợi ý thì gửi useSuggested, không gửi lại số tài khoản (FE-07)', () {
    expect(const PayoutAccountInput.suggested().toJson(), {'useSuggested': true, 'bankCode': null, 'accountNumber': null, 'accountHolder': null});
    expect(const PayoutAccountInput(bankCode: '970436', accountNumber: '0123456789', accountHolder: 'NGUYEN VAN A').toJson()['useSuggested'], isFalse);
  });

  test('chi tiết khoản hoàn đọc tài khoản gợi ý (số đã che) từ BE', () {
    final r = MyRefund.fromJson({
      'id': 5,
      'orderId': 8,
      'sourceType': 'Cancellation',
      'refundStatus': 'Approved',
      'requestedAmount': 181400,
      'createdAt': '2026-11-12T10:00:00Z',
      'needsPayoutAccount': true,
      'suggestedPayoutAccount': {'bankCode': '970436', 'bankName': 'Vietcombank', 'maskedAccountNumber': '******6789', 'accountHolder': 'NGUYEN VAN A'},
    });
    expect(r.suggestedPayoutAccount?.bankName, 'Vietcombank');
    expect(r.suggestedPayoutAccount?.maskedAccountNumber, '******6789');
  });
}
