import '../../../core/network/api_client.dart';
import '../../../core/domain/result_page.dart';
import '../domain/driver_wallet_repository.dart';

class RemoteWalletRepository implements DriverWalletRepository {
  const RemoteWalletRepository(this.api);
  final ApiClient api;
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiFailure catch (e) {
      throw WalletFailure(e.message);
    }
  }

  @override
  Future<WalletBalance> balance() => _guard(() async {
    final data = await api.request('GET', '/api/driver/wallet') as Map;
    final bank = data['bankAccount'] as Map?;
    return WalletBalance(
      (data['depositBalance'] as num).round(),
      (data['earningsBalance'] as num).round(),
      debt: (data['commissionDebt'] as num).round(),
      withdrawable: (data['maxWithdrawableAmount'] as num).round(),
      minimumDeposit: (data['minCodDeposit'] as num).round(),
      canReceiveCash: data['canReceiveCod'] == true,
      pendingWithdrawal: data['hasPendingWithdrawal'] == true,
      pendingAmount: (data['pendingWithdrawalAmount'] as num).round(),
      active: data['walletStatus'] == 'Active',
      bank: bank == null
          ? null
          : DriverBankAccount(
              '${bank['bankName']}',
              '${bank['bankAccountNumber']}',
              '${bank['bankAccountHolder']}',
            ),
    );
  });
  @override
  Future<DepositPayment> topUp(int amount) => _guard(() async {
    if (amount < 50000) {
      throw const WalletFailure('Số tiền nạp tối thiểu là 50.000đ.');
    }
    final data =
        await api.request(
              'POST',
              '/api/driver/wallet/topup',
              body: {'amount': amount, 'platform': 'App'},
            )
            as Map;
    final url = Uri.parse(data['checkoutUrl'] as String);
    if (url.scheme != 'https' || !url.hasAuthority) {
      throw const WalletFailure('Đường dẫn thanh toán không hợp lệ.');
    }
    return DepositPayment(
      url,
      DateTime.parse(data['expiresAt'] as String),
      (data['amount'] as num).round(),
      id: '${data['transactionId']}',
      qrCode: data['qrCode'] as String?,
    );
  });

  @override
  Future<ResultPage<WalletTransaction>> transactions({int page = 1}) =>
      _ledger('transactions', page);
  @override
  Future<ResultPage<WalletTransaction>> withdrawals({int page = 1}) =>
      _ledger('withdrawals', page);
  Future<ResultPage<WalletTransaction>> _ledger(String path, int page) =>
      _guard(() async {
        final data =
            await api.request(
                  'GET',
                  '/api/driver/wallet/$path?page=$page&pageSize=20',
                )
                as Map;
        return ResultPage(
          [
            for (final row in data['items'] as List)
              WalletTransaction(
                id: '${row['id'] ?? row['transactionId']}',
                type: '${row['transactionType'] ?? 'WithdrawEarnings'}',
                amount: (row['amount'] as num).round(),
                balanceAfter: (row['balanceAfter'] as num).round(),
                status: '${row['transactionStatus']}',
                createdAt: DateTime.parse('${row['createdAt']}'),
                orderId: row['orderId']?.toString(),
                orderCode: row['orderCode'] as String?,
              ),
          ],
          (data['pageNumber'] as num).toInt(),
          (data['totalCount'] as num).toInt(),
          data['hasNextPage'] == true,
        );
      });
  @override
  Future<void> saveBank(DriverBankAccount bank) => _guard(() async {
    if (bank.name.trim().isEmpty ||
        bank.name.trim().length > 100 ||
        bank.holder.trim().isEmpty ||
        bank.holder.trim().length > 100 ||
        !RegExp(r'^[0-9A-Za-z]{6,30}$').hasMatch(bank.number.trim())) {
      throw const WalletFailure(
        'Nhập ngân hàng, tên chủ tài khoản và số tài khoản hợp lệ (6–30 chữ hoặc số).',
      );
    }
    await api.request(
      'PUT',
      '/api/driver/wallet/bank-account',
      body: {
        'bankName': bank.name.trim(),
        'bankAccountNumber': bank.number.trim(),
        'bankAccountHolder': bank.holder.trim(),
      },
    );
  });
  @override
  Future<WithdrawalReceipt> withdraw(int amount) => _guard(() async {
    if (amount <= 0) throw const WalletFailure('Số tiền rút phải lớn hơn 0đ.');
    final data =
        await api.request(
              'POST',
              '/api/driver/wallet/withdrawals',
              body: {'amount': amount},
            )
            as Map;
    return WithdrawalReceipt(
      '${data['transactionId']}',
      (data['amount'] as num).round(),
      (data['debtDeducted'] as num).round(),
    );
  });
}
