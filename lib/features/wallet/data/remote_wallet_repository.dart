import '../../../core/network/api_client.dart';
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
    final data = await api.request('GET', '/api/driver/status') as Map;
    return WalletBalance(
      (data['depositBalance'] as num).round(),
      (data['earningsBalance'] as num).round(),
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
    );
  });
}
