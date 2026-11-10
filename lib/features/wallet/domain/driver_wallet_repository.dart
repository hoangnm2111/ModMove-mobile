import '../../../core/domain/result_page.dart';

class WalletBalance {
  const WalletBalance(
    this.deposit,
    this.earnings, {
    this.debt = 0,
    this.withdrawable = 0,
    this.minimumDeposit = 200000,
    this.canReceiveCash = false,
    this.pendingWithdrawal = false,
    this.pendingAmount = 0,
    this.active = true,
    this.bank,
  });
  final int deposit, earnings;
  final int debt, withdrawable, minimumDeposit, pendingAmount;
  final bool canReceiveCash, pendingWithdrawal, active;
  final DriverBankAccount? bank;
}

class DriverBankAccount {
  const DriverBankAccount(this.name, this.number, this.holder);
  final String name, number, holder;
  String get masked => number.length > 4
      ? '•••• ${number.substring(number.length - 4)}'
      : number;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.orderCode,
  });
  final String id, type, status;
  final int amount, balanceAfter;
  final DateTime createdAt;
  final String? orderId, orderCode;
  bool get credit => type == 'TopUpDeposit' || type == 'TripEarning';
}

class WithdrawalReceipt {
  const WithdrawalReceipt(this.id, this.amount, this.debtDeducted);
  final String id;
  final int amount, debtDeducted;
}

class DepositPayment {
  const DepositPayment(
    this.checkoutUrl,
    this.expiresAt,
    this.amount, {
    this.id = '',
    this.qrCode,
  });
  final Uri checkoutUrl;
  final DateTime expiresAt;
  final int amount;
  final String id;
  final String? qrCode;
}

class WalletFailure implements Exception {
  const WalletFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class DriverWalletRepository {
  Future<WalletBalance> balance();
  Future<DepositPayment> topUp(int amount);
  Future<ResultPage<WalletTransaction>> transactions({int page = 1});
  Future<ResultPage<WalletTransaction>> withdrawals({int page = 1});
  Future<void> saveBank(DriverBankAccount bank);
  Future<WithdrawalReceipt> withdraw(int amount);
}
