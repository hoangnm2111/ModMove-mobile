import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/session_store.dart';
import '../data/auth_api.dart';

/// Trạng thái đăng nhập toàn app: null = khách vãng lai.
class AuthCubit extends Cubit<Session?> {
  AuthCubit({required this.api, required this.sessions}) : super(sessions.current);
  final AuthApi api;
  final SessionStore sessions;

  Future<Session> login(String email, String password) async {
    final session = await api.login(email, password);
    await sessions.save(session);
    emit(session);
    return session;
  }

  /// Đăng xuất: thu hồi refresh token trên server (lỗi mạng vẫn xoá phiên cục bộ).
  Future<void> logout() async {
    if (sessions.current != null) {
      try {
        await api.logout();
      } catch (_) {}
    }
    await expire();
  }

  /// Phiên hết hạn (refresh token không dùng được) → về trạng thái khách.
  Future<void> expire() async {
    await sessions.save(null);
    if (!isClosed) emit(null);
  }
}
