import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/session_store.dart';
import '../data/auth_api.dart';

/// Trạng thái đăng nhập toàn app: null = khách vãng lai.
class AuthCubit extends Cubit<Session?> {
  AuthCubit({required this.api, required this.sessions, this.detachPush})
    : super(sessions.current);
  final AuthApi api;
  final SessionStore sessions;

  /// Huỷ đăng ký thông báo đẩy trên máy và trả về token FCM của máy này (PushCubit.detach).
  final Future<String?> Function()? detachPush;

  Future<String?> _detach() async {
    try {
      return await detachPush?.call();
    } catch (_) {
      return null;
    }
  }

  Future<Session> login(String email, String password) async {
    final session = await api.login(email, password);
    await sessions.save(session);
    emit(session);
    return session;
  }

  /// Đăng xuất: thu hồi refresh token trên server (lỗi mạng vẫn xoá phiên cục bộ).
  Future<void> logout() async {
    // Gỡ token trước, gửi kèm `fcmToken` để BE chỉ xoá đúng thiết bị này (máy khác đăng ký sau vẫn nhận push).
    final fcmToken = await _detach();
    if (sessions.current != null) {
      try {
        await api.logout(fcmToken: fcmToken);
      } catch (_) {}
    }
    await _clearSession();
  }

  /// Phiên hết hạn (refresh token không dùng được) → về trạng thái khách.
  Future<void> expire() async {
    await _detach();
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await sessions.save(null);
    if (!isClosed) emit(null);
  }
}
