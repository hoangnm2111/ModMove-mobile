import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/auth_repository.dart';

enum AuthStage {
  restoring,
  login,
  register,
  verify,
  forgot,
  reset,
  guest,
  signedIn,
}

class AuthState {
  const AuthState(this.stage, {this.busy = false, this.error, this.notice});
  final AuthStage stage;
  final bool busy;
  final String? error, notice;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.repository) : super(const AuthState(AuthStage.restoring)) {
    _expired = repository.expired.listen((_) {
      if (!isClosed) {
        emit(
          const AuthState(
            AuthStage.login,
            notice: 'Vui lòng đăng nhập để tiếp tục.',
          ),
        );
      }
    });
  }
  final AuthRepository repository;
  late final StreamSubscription<void> _expired;
  void show(AuthStage stage) {
    if (!state.busy) emit(AuthState(stage));
  }

  Future<void> restore() async {
    try {
      await repository.restore();
      emit(
        AuthState(repository.signedIn ? AuthStage.signedIn : AuthStage.login),
      );
    } catch (_) {
      emit(
        const AuthState(
          AuthStage.login,
          error: 'Chưa đọc được phiên đăng nhập. Vui lòng đăng nhập lại.',
        ),
      );
    }
  }

  Future<void> _run(
    Future<void> Function() call,
    AuthStage next, {
    String? notice,
  }) async {
    if (state.busy) return;
    final stage = state.stage;
    emit(AuthState(stage, busy: true));
    try {
      await call();
      if (!isClosed) emit(AuthState(next, notice: notice));
    } catch (e) {
      if (!isClosed) {
        emit(
          AuthState(
            stage,
            error: e is AuthFailure
                ? e.message
                : 'Chưa xử lý được. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  Future<void> login(String email, String password) =>
      _run(() => repository.login(email, password), AuthStage.signedIn);
  Future<void> register(
    String name,
    String phone,
    String email,
    String password, {
    String role = 'Driver',
  }) => _run(
    () => repository.register(name, phone, email, password, role: role),
    AuthStage.verify,
    notice: 'Nhập mã OTP đã gửi tới email của bạn.',
  );
  Future<void> verify(String email, String code, String password) =>
      _run(() async {
        await repository.verify(email, code, password);
        await repository.login(email, password);
      }, AuthStage.signedIn);
  Future<void> resend(String email) => _run(
    () => repository.resend(email),
    AuthStage.verify,
    notice: 'Đã yêu cầu gửi lại OTP. Kiểm tra email của bạn.',
  );
  Future<void> forgot(String email) => _run(
    () => repository.forgotPassword(email),
    AuthStage.reset,
    notice: 'Nếu email đã đăng ký, mã xác minh sẽ được gửi tới hộp thư.',
  );
  Future<void> reset(String email, String code, String password) => _run(
    () => repository.resetPassword(email, code, password),
    AuthStage.login,
    notice: 'Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới.',
  );
  Future<void> logout({String? notice}) async {
    try {
      await repository.logout();
    } catch (_) {
      /* local token was cleared */
    }
    if (!isClosed) emit(AuthState(AuthStage.login, notice: notice));
  }

  @override
  Future<void> close() async {
    await _expired.cancel();
    return super.close();
  }
}
