import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/push_message.dart';
import 'push_cubit.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader('Thông báo'),
    body: BlocBuilder<PushCubit, PushState>(
      builder: (context, state) {
        final push = context.read<PushCubit>();
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
              state.registered ? 'Đã bật thông báo' : 'Thông báo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nhận thông báo khi tài xế nhận đơn, đến điểm lấy hàng, giao hàng, khi có kết quả '
              'hoàn tiền, sự cố hoặc rút tiền. Chạm vào thông báo để xem thông tin mới nhất.',
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
