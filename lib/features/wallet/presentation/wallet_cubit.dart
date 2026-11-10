import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/result_page.dart';
import '../domain/driver_wallet_repository.dart';

class WalletState {
  const WalletState({
    this.balance,
    this.payment,
    this.busy = false,
    this.error,
    this.transactions,
    this.withdrawals,
    this.paymentConfirmed = false,
    this.withdrawalUncertain = false,
    this.notice,
  });
  final WalletBalance? balance;
  final DepositPayment? payment;
  final bool busy;
  final String? error;
  final ResultPage<WalletTransaction>? transactions, withdrawals;
  final bool paymentConfirmed, withdrawalUncertain;
  final String? notice;
  WalletState copyWith({
    WalletBalance? balance,
    DepositPayment? payment,
    ResultPage<WalletTransaction>? transactions,
    ResultPage<WalletTransaction>? withdrawals,
    bool? busy,
    bool? paymentConfirmed,
    bool? withdrawalUncertain,
    String? error,
    String? notice,
  }) => WalletState(
    balance: balance ?? this.balance,
    payment: payment ?? this.payment,
    transactions: transactions ?? this.transactions,
    withdrawals: withdrawals ?? this.withdrawals,
    busy: busy ?? this.busy,
    paymentConfirmed: paymentConfirmed ?? this.paymentConfirmed,
    withdrawalUncertain: withdrawalUncertain ?? this.withdrawalUncertain,
    error: error,
    notice: notice,
  );
}

class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this.repository) : super(const WalletState());
  final DriverWalletRepository repository;
  Future<void> _reload() async {
    final balance = await repository.balance();
    final transactions = await repository.transactions();
    final withdrawals = await repository.withdrawals();
    final paid = transactions.items.any(
      (tx) =>
          tx.id == state.payment?.id &&
          tx.type == 'TopUpDeposit' &&
          tx.status == 'Completed',
    );
    if (!isClosed) {
      emit(
        state.copyWith(
          balance: balance,
          transactions: transactions,
          withdrawals: withdrawals,
          paymentConfirmed: state.paymentConfirmed || paid,
          withdrawalUncertain: false,
        ),
      );
    }
  }

  Future<void> refresh() => _run(_reload);
  Future<void> topUp(int amount) => _run(() async {
    final payment = await repository.topUp(amount);
    if (!isClosed) {
      emit(state.copyWith(payment: payment, paymentConfirmed: false));
    }
  });
  Future<void> saveBank(DriverBankAccount bank) => _run(() async {
    await repository.saveBank(bank);
    await _reload();
    if (!isClosed) emit(state.copyWith(notice: 'Đã lưu tài khoản ngân hàng.'));
  });
  Future<void> withdraw(int amount) => _run(() async {
    // Recheck the server immediately before a financial request.
    final balance = await repository.balance();
    if (!isClosed) emit(state.copyWith(balance: balance));
    if (!balance.active) {
      throw const WalletFailure('Ví đang bị khóa. Liên hệ hỗ trợ.');
    }
    if (balance.pendingWithdrawal) {
      throw const WalletFailure('Bạn đang có một yêu cầu rút tiền chờ xử lý.');
    }
    if (balance.bank == null) {
      throw const WalletFailure('Thêm tài khoản ngân hàng trước khi rút tiền.');
    }
    if (amount <= 0 || amount > balance.withdrawable) {
      throw const WalletFailure(
        'Số tiền phải lớn hơn 0 và không vượt số tiền có thể rút.',
      );
    }
    WithdrawalReceipt receipt;
    try {
      receipt = await repository.withdraw(amount);
    } catch (_) {
      // Never retry a withdrawal POST after a lost response.
      if (!isClosed) emit(state.copyWith(withdrawalUncertain: true));
      try {
        await _reload();
      } catch (_) {
        /* manual refresh is required */
      }
      rethrow;
    }
    try {
      await _reload();
    } catch (_) {
      if (!isClosed) emit(state.copyWith(withdrawalUncertain: true));
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          notice: 'Đã gửi yêu cầu #${receipt.id}. Chờ quản trị viên xử lý.',
        ),
      );
    }
  });
  Future<void> loadMore({bool withdrawals = false}) => _run(() async {
    final old = withdrawals ? state.withdrawals : state.transactions;
    if (old?.hasNext != true) return;
    final next = withdrawals
        ? await repository.withdrawals(page: old!.page + 1)
        : await repository.transactions(page: old!.page + 1);
    final merged = ResultPage(
      [...old.items, ...next.items],
      next.page,
      next.total,
      next.hasNext,
    );
    if (!isClosed) {
      emit(
        withdrawals
            ? state.copyWith(withdrawals: merged)
            : state.copyWith(transactions: merged),
      );
    }
  });
  Future<void> _run(Future<void> Function() action) async {
    if (state.busy || isClosed) return;
    emit(state.copyWith(busy: true));
    try {
      await action();
      if (!isClosed) emit(state.copyWith(busy: false, notice: state.notice));
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: e is WalletFailure
                ? e.message
                : 'Chưa xử lý được giao dịch. Vui lòng kiểm tra lại.',
          ),
        );
      }
    }
  }
}
