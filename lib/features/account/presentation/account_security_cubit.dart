import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/account_input.dart';
import '../domain/account_security_repository.dart';

class AccountSecurityState {
  const AccountSecurityState({this.busy = false, this.error, this.completed});
  final bool busy;
  final String? error, completed;
}

class AccountSecurityCubit extends Cubit<AccountSecurityState> {
  AccountSecurityCubit(this.repository) : super(const AccountSecurityState());
  final AccountSecurityRepository repository;
  Future<void> changePassword(
    String current,
    String next,
    String confirm,
  ) async {
    if (state.busy || isClosed) return;
    if (current.isEmpty ||
        !isValidNewPassword(next) ||
        next != confirm ||
        next == current) {
      emit(
        const AccountSecurityState(
          error:
              'Nhập mật khẩu hiện tại và mật khẩu mới khác nhau, 8–100 ký tự gồm chữ và số. Hai ô mật khẩu mới phải khớp.',
        ),
      );
      return;
    }
    await _run(
      () => repository.changePassword(current, next),
      'Đã đổi mật khẩu. Hãy đăng nhập bằng mật khẩu mới.',
    );
  }

  Future<void> deleteAccount() =>
      _run(repository.deleteAccount, 'Tài khoản đã ngừng hoạt động.');
  Future<void> _run(Future<void> Function() action, String notice) async {
    if (state.busy || isClosed) return;
    emit(const AccountSecurityState(busy: true));
    try {
      await action();
      if (!isClosed) emit(AccountSecurityState(busy: true, completed: notice));
    } catch (e) {
      if (!isClosed) {
        emit(
          AccountSecurityState(
            error: e is AccountSecurityFailure
                ? e.message
                : 'Chưa xử lý được yêu cầu. Vui lòng thử lại.',
          ),
        );
      }
    }
  }
}
