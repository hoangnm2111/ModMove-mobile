import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/notice_banner.dart';
import '../auth/presentation/auth_cubit.dart';
import '../driver_trip/data/driver_api.dart';

/// Q12 (BE 2026-11-12): tài xế xoá tài khoản = `Inactive` qua `DELETE api/driver/account`.
/// BE chặn khi còn đơn đang chạy (ACCOUNT_HAS_OPEN_ORDERS), rút tiền chờ (ACCOUNT_HAS_PENDING_WITHDRAWAL)
/// hoặc ví khác 0 (ACCOUNT_HAS_WALLET_BALANCE). Thành công thì đăng xuất khỏi máy này.
/// Tự ẩn khi chưa đăng nhập tài xế hoặc không có ApiClient (chạy dữ liệu mô phỏng / test).
class DeleteDriverAccountButton extends StatefulWidget {
  const DeleteDriverAccountButton({super.key});
  @override
  State<DeleteDriverAccountButton> createState() =>
      _DeleteDriverAccountButtonState();
}

class _DeleteDriverAccountButtonState extends State<DeleteDriverAccountButton> {
  bool _busy = false;

  Future<void> _delete(ApiClient api, AuthCubit auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xoá tài khoản tài xế?'),
        content: const Text(
          'Tài khoản chuyển sang vô hiệu hoá và bạn bị đăng xuất khỏi mọi thiết bị. Hồ sơ, xe, ví và lịch sử vẫn được giữ; quản trị viên có thể mở lại.\n\n'
          'Chỉ xoá được khi không có đơn đang chạy, không có yêu cầu rút tiền đang chờ và ví bằng 0.',
        ),
        actions: [
          TextButton(
            key: const Key('delete-driver-cancel'),
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            key: const Key('delete-driver-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xoá tài khoản'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final notices = maybeNotices(context);
    try {
      await DriverApi(api).deleteAccount();
      // BE đã thu hồi mọi refresh token: chỉ cần xoá phiên trên máy (gọi logout lúc này sẽ bị từ chối).
      await auth.expire();
      if (notices != null) {
        notifyAfterSignOut(
          notices,
          'ACTION_DONE',
          body: 'Tài khoản tài xế đã được vô hiệu hoá.',
        );
      }
    } catch (e) {
      if (mounted) {
        showNotice(
          context,
          e is ApiException
              ? e.message
              : 'Chưa xoá được tài khoản. Vui lòng thử lại.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ApiClient api;
    AuthCubit auth;
    try {
      api = context.read<ApiClient>();
      auth = context.watch<AuthCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    if (auth.state?.isDriver != true) return const SizedBox.shrink();
    return MenuTile(
      Icons.delete_outline,
      'Xoá tài khoản',
      key: const Key('delete-driver-account'),
      color: AppColors.red,
      onTap: _busy ? null : () => _delete(api, auth),
      leading: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}
