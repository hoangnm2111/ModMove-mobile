import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/customer_visuals.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/driver_notification.dart';
import 'push_cubit.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key, this.customer = false});
  final bool customer;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader('Thông báo'),
    body: BlocBuilder<PushCubit, PushState>(
      builder: (context, state) {
        final push = context.read<PushCubit>();
        if (customer) {
          return _CustomerNotificationContent(state: state, push: push);
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              state.registered
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              state.registered
                  ? 'Đã bật thông báo'
                  : customer
                  ? 'Thông báo đơn hàng'
                  : 'Thông báo tài xế',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              customer
                  ? 'Nhận cập nhật tài xế, ảnh lấy hàng, giao hàng và kết quả hỗ trợ / hoàn tiền. Chạm vào thông báo để xem thông tin mới nhất.'
                  : 'Nhận thông báo đơn mới, kết quả duyệt hồ sơ, phản hồi sự cố '
                        'và yêu cầu rút tiền. Chạm vào thông báo để xem thông tin mới nhất.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (state.permission == PushPermission.unavailable)
              const Notice(
                'Bản cài đặt này chưa kết nối được Firebase. Liên hệ nhóm phát triển để kiểm tra cấu hình.',
                icon: 'warning',
              )
            else ...[
              if (state.permission == PushPermission.denied)
                const Notice(
                  'Android chưa cho phép ModMove hiển thị thông báo. Bật quyền trong cài đặt thông báo.',
                  icon: 'warning',
                ),
              if (state.error != null) Notice(state.error!, icon: 'warning'),
              PrimaryButton(
                state.registered ? 'Kiểm tra kết nối' : 'Bật thông báo',
                busy: state.busy,
                onPressed: state.busy
                    ? null
                    : () => push.synchronize(request: true, force: true),
              ),
              TextButton(
                onPressed: push.openSettings,
                child: const Text('Mở cài đặt thông báo Android'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _CustomerNotificationContent extends StatelessWidget {
  const _CustomerNotificationContent({required this.state, required this.push});
  final PushState state;
  final PushCubit push;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const CustomerIllustration('notifications', height: 146),
      const CustomerPageHeading('Theo dõi chuyến giao dễ dàng'),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: state.registered ? AppColors.greenBg : AppColors.amberBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AppIcon(
              state.registered ? 'check' : 'bell',
              color: state.registered ? AppColors.green : AppColors.amber,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.registered
                    ? 'Đã bật thông báo'
                    : 'Thông báo chưa sẵn sàng',
                style: appText(
                  size: 16,
                  weight: FontWeight.w700,
                  color: state.registered ? AppColors.green : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: const Column(
          children: [
            ListTile(
              leading: AppIcon('van'),
              title: Text('Cập nhật trạng thái đơn'),
              subtitle: Text(
                'Theo dõi tài xế nhận đơn, lấy hàng và giao hàng.',
              ),
            ),
            Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: AppIcon('image'),
              title: Text('Ảnh lấy hàng cần xác nhận'),
              subtitle: Text(
                'Kiểm tra ảnh tài xế gửi để tiếp tục chuyến giao.',
              ),
            ),
            Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: AppIcon('shield'),
              title: Text('Phản hồi sự cố và hoàn tiền'),
              subtitle: Text('Cập nhật phản hồi và kết quả xử lý yêu cầu.'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (state.permission == PushPermission.unavailable)
        const Notice(
          'Bản cài đặt này chưa kết nối được Firebase. Liên hệ nhóm phát triển để kiểm tra cấu hình.',
          icon: 'warning',
        )
      else ...[
        if (state.permission == PushPermission.denied)
          const Notice(
            'Android chưa cho phép ModMove hiển thị thông báo. Bật quyền trong cài đặt thông báo.',
            icon: 'warning',
          ),
        if (state.error != null) Notice(state.error!, icon: 'warning'),
        OutlinedButton.icon(
          onPressed: push.openSettings,
          icon: const AppIcon('bell', color: AppColors.orange),
          label: const Text('Mở cài đặt thông báo'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: state.busy
              ? null
              : () => push.synchronize(request: true, force: true),
          child: Text(
            state.busy
                ? 'Đang kiểm tra…'
                : state.registered
                ? 'Kiểm tra kết nối'
                : 'Bật thông báo',
          ),
        ),
      ],
      const SizedBox(height: 18),
      Text(
        'Thông báo giúp bạn xử lý kịp thời các bước của đơn hàng.',
        textAlign: TextAlign.center,
        style: appText(size: 12, color: AppColors.secondary),
      ),
    ],
  );
}
