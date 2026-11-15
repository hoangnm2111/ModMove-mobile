import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notice_banner.dart';
import 'auth_cubit.dart';

/// Nút "Đăng xuất" dùng chung cho khách và tài xế: hỏi lại, gọi `POST /account/Logout`
/// (thu hồi refresh token, gỡ token FCM của máy này), rồi xoá phiên cục bộ.
/// Mất mạng vẫn đăng xuất được ở máy này (AuthCubit.logout bỏ qua lỗi gọi BE).
/// Tự ẩn khi chưa đăng nhập hoặc khi không có AuthCubit (ví dụ test dựng riêng một màn).
class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key});
  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _busy = false;

  Future<void> _logout(AuthCubit auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ phải đăng nhập lại để tiếp tục sử dụng.'),
        actions: [
          TextButton(key: const Key('logout-cancel'), onPressed: () => Navigator.pop(dialog, false), child: const Text('Ở lại')),
          FilledButton(
            key: const Key('logout-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final notices = maybeNotices(context);
    try {
      await auth.logout();
      if (notices != null) notifyAfterSignOut(notices, 'LOGGED_OUT');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AuthCubit auth;
    try {
      auth = context.watch<AuthCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final Session? session = auth.state;
    if (session == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const Key('logout-button'),
      onPressed: _busy ? null : () => _logout(auth),
      icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout, size: 18, color: AppColors.red),
      label: Text('Đăng xuất', style: appText(color: AppColors.red, weight: FontWeight.w700)),
    );
  }
}
