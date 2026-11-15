import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../notifications/app_notice.dart';
import '../notifications/notice_catalog.dart';
import '../notifications/notification_cubit.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// Đánh dấu "ở dưới đây có NoticeHost vẽ banner": nếu thiếu (ví dụ test dựng riêng một MaterialApp),
/// [showNotice] quay về SnackBar để thông báo không bị mất.
class _NoticeHostScope extends InheritedWidget {
  const _NoticeHostScope({required super.child});
  static bool exists(BuildContext context) => context.getInheritedWidgetOfExactType<_NoticeHostScope>() != null;
  @override
  bool updateShouldNotify(_NoticeHostScope oldWidget) => false;
}

/// Mã đơn đang mở ở màn chi tiết (null nếu không có): chạm banner của đúng đơn này thì không mở thêm màn.
final openOrderId = ValueNotifier<int?>(null);

/// Đẩy thông báo theo mã trong danh mục ([noticeCatalog]); `data` điền vào chữ dự phòng và chọn đích khi chạm.
void notify(BuildContext context, String type, [Map<String, String> data = const {}, String? body]) {
  final notice = noticeFor(type, data: data, body: body);
  if (_NoticeHostScope.exists(context)) {
    context.read<NotificationCubit>().push(notice);
    return;
  }
  _fallbackSnack(context, notice.body.isEmpty ? notice.title : notice.body, error: notice.kind == NoticeKind.error);
}

/// Báo kết quả của thao tác làm mất phiên đăng nhập (đăng xuất, xoá tài khoản). Khi phiên kết thúc app xoá sạch
/// hộp thông báo và màn hiện tại bị đóng, nên phải lấy [cubit] trước khi thao tác và đẩy ở khung hình kế tiếp.
void notifyAfterSignOut(NotificationCubit cubit, String type, {String? body}) {
  WidgetsBinding.instance.addPostFrameCallback((_) => cubit.push(noticeFor(type, body: body)));
  WidgetsBinding.instance.scheduleFrame();
}

/// [NotificationCubit] nếu có (màn dựng riêng trong test thì không có).
NotificationCubit? maybeNotices(BuildContext context) {
  try {
    return context.read<NotificationCubit>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Câu ngắn của thao tác (kết quả hoặc lỗi nhập liệu): hiện banner trên đỉnh màn, thay cho SnackBar.
void showNotice(BuildContext context, String text, {bool error = false}) => notify(context, error ? 'ACTION_ERROR' : 'ACTION_DONE', const {}, text);

void _fallbackSnack(BuildContext context, String text, {required bool error}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.red : AppColors.ink, behavior: SnackBarBehavior.floating));
}

/// Vẽ banner thông báo trên đỉnh mọi màn (đặt ở `MaterialApp.builder`). Chạm banner gọi [onOpen] rồi đóng;
/// vuốt lên để đóng; tự đóng sau `notice.duration`.
class NoticeHost extends StatelessWidget {
  const NoticeHost({super.key, required this.child, required this.onOpen});
  final Widget child;
  final void Function(AppNotice) onOpen;

  @override
  Widget build(BuildContext context) => _NoticeHostScope(
    child: Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: BlocBuilder<NotificationCubit, NotificationState>(
                buildWhen: (a, b) => a.showing?.id != b.showing?.id,
                builder: (context, state) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: state.showing == null ? const SizedBox.shrink(key: ValueKey('no-notice')) : NoticeBanner(key: ValueKey(state.showing!.id), notice: state.showing!, onOpen: onOpen),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class NoticeBanner extends StatefulWidget {
  const NoticeBanner({super.key, required this.notice, required this.onOpen});
  final AppNotice notice;
  final void Function(AppNotice) onOpen;
  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<NotificationCubit>();
    final id = widget.notice.id;
    _timer = Timer(widget.notice.duration, () {
      // Chỉ đóng nếu banner này vẫn đang hiện (người dùng có thể đã đóng tay).
      if (cubit.state.showing?.id == id) cubit.dismissCurrent();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  (Color, Color, String) get _style => switch (widget.notice.kind) {
    NoticeKind.success => (AppColors.green, AppColors.greenBg, 'check'),
    NoticeKind.info => (const Color(0xFF1D4ED8), const Color(0xFFEAF1FF), 'info'),
    NoticeKind.warning => (AppColors.amber, AppColors.amberBg, 'warning'),
    NoticeKind.error => (AppColors.red, AppColors.redBg, 'warning'),
  };

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final (fg, bg, icon) = _style;
    final cubit = context.read<NotificationCubit>();
    return Dismissible(
      key: ValueKey('dismiss-${notice.id}'),
      direction: DismissDirection.up,
      onDismissed: (_) => cubit.dismissCurrent(),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Material(
          color: bg,
          elevation: 6,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              cubit.dismissCurrent();
              widget.onOpen(notice);
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fg.withValues(alpha: .35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: AppIcon(icon, size: 20, color: fg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notice.title.isNotEmpty)
                          Text(
                            notice.title,
                            style: appText(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
                          ),
                        if (notice.body.isNotEmpty) Text(notice.body, style: appText(size: 12.5, color: AppColors.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
