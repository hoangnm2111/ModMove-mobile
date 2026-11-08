class WalletBalance {
  const WalletBalance(this.deposit, this.earnings);
  final int deposit, earnings;
}

class DepositPayment {
  const DepositPayment(this.checkoutUrl, this.expiresAt, this.amount);
  final Uri checkoutUrl;
  final DateTime expiresAt;
  final int amount;
}

class WalletFailure implements Exception {
  const WalletFailure(this.message);
  final String message;
}

abstract interface class DriverWalletRepository {
  Future<WalletBalance> balance();
  Future<DepositPayment> topUp(int amount);
}
