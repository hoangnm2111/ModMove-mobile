import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/driver_wallet_repository.dart';

class WalletState {
  const WalletState({
    this.balance,
    this.payment,
    this.busy = false,
    this.error,
  });
  final WalletBalance? balance;
  final DepositPayment? payment;
  final bool busy;
  final String? error;
}

class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this.repository) : super(const WalletState());
  final DriverWalletRepository repository;
  Future<void> refresh() => _run(
    () async => WalletState(
      balance: await repository.balance(),
      payment: state.payment,
    ),
  );
  Future<void> topUp(int amount) => _run(
    () async => WalletState(
      balance: state.balance,
      payment: await repository.topUp(amount),
    ),
  );
  Future<void> _run(Future<WalletState> Function() action) async {
    if (state.busy) return;
    emit(
      WalletState(balance: state.balance, payment: state.payment, busy: true),
    );
    try {
      final next = await action();
      if (!isClosed) emit(next);
    } catch (e) {
      if (!isClosed) {
        emit(
          WalletState(
            balance: state.balance,
            payment: state.payment,
            error: e is WalletFailure
                ? e.message
                : 'Chưa xử lý được giao dịch. Vui lòng kiểm tra lại.',
          ),
        );
      }
    }
  }
}
