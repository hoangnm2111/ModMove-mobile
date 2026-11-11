import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/format/formatters.dart';
import '../../core/notifications/app_notice.dart';
import '../../core/notifications/notification_cubit.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

/// Chuông thông báo kèm số chưa đọc (ẩn khi 0, hiện "9+" khi quá 9).
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Màn dựng riêng (không có NotificationCubit ở trên) vẫn hiện chuông, chỉ không có số chưa đọc.
    NotificationCubit? cubit;
    try {
      cubit = context.read<NotificationCubit>();
    } catch (_) {
      cubit = null;
    }
    if (cubit == null) {
      return IconButton(tooltip: 'Thông báo', onPressed: onTap, icon: const AppIcon('bell'));
    }
    return _bell(context);
  }

  Widget _bell(BuildContext context) => BlocBuilder<NotificationCubit, NotificationState>(
    buildWhen: (a, b) => a.unread != b.unread,
    builder: (context, state) {
      final unread = state.unread;
      return IconButton(
        tooltip: unread > 0 ? 'Thông báo, $unread chưa đọc' : 'Thông báo',
        onPressed: onTap,
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 9 ? '9+' : '$unread', key: const Key('bell-badge')),
          backgroundColor: AppColors.red,
          child: const AppIcon('bell'),
        ),
      );
    },
  );
}

/// Hộp thông báo của phiên: mới nhất trước. Mở màn hình là đánh dấu đã đọc hết; chạm một mục để tới màn hình liên quan.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onOpen});
  final void Function(AppNotice) onOpen;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationCubit>().markAllRead();
    });
  }

  (Color, String) _icon(NoticeKind kind) => switch (kind) {
    NoticeKind.success => (AppColors.green, 'check'),
    NoticeKind.info => (const Color(0xFF1D4ED8), 'info'),
    NoticeKind.warning => (AppColors.amber, 'warning'),
    NoticeKind.error => (AppColors.red, 'warning'),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader('Thông báo'),
    body: BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        if (state.inbox.isEmpty) {
          return Center(child: Text('Chưa có thông báo', style: appText(size: 14, color: AppColors.muted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: state.inbox.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final notice = state.inbox[index];
            final (color, icon) = _icon(notice.kind);
            return AppCard(
              key: ValueKey('notice-${notice.id}'),
              onTap: () => widget.onOpen(notice),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(icon, size: 22, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notice.title.isNotEmpty) Text(notice.title, style: appText(size: 14, weight: FontWeight.w800)),
                        if (notice.body.isNotEmpty) Text(notice.body, style: appText(size: 13, color: AppColors.secondary)),
                        const SizedBox(height: 4),
                        Text(timeAgo(notice.at), style: appText(size: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
