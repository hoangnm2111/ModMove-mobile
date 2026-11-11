import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/notifications/app_notice.dart';
import 'package:modmove_mobile/core/notifications/notice_catalog.dart';
import 'package:modmove_mobile/core/notifications/notification_cubit.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/notice_banner.dart';
import 'package:modmove_mobile/features/customer/presentation/widgets/customer_widgets.dart';

Widget _host(NotificationCubit cubit, {void Function(AppNotice)? onOpen, Widget? home}) => BlocProvider.value(
  value: cubit,
  child: MaterialApp(
    theme: buildAppTheme(),
    builder: (context, child) => NoticeHost(onOpen: onOpen ?? (_) {}, child: child!),
    home: home ?? const Scaffold(body: SizedBox.expand()),
  ),
);

/// Lần pump đầu dựng banner, lần sau chạy xong hoạt ảnh trượt xuống.
Future<void> _shown(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  late NotificationCubit cubit;
  setUp(() => cubit = NotificationCubit());
  tearDown(() => cubit.close());

  testWidgets('banner hiện tiêu đề và nội dung ở đỉnh màn rồi tự đóng sau 4 giây', (t) async {
    await t.pumpWidget(_host(cubit));
    cubit.push(noticeFor('ORDER_ACCEPTED', title: 'Đơn đã có tài xế', body: 'Tài xế đã nhận đơn MM01.'));
    await _shown(t);
    expect(find.text('Đơn đã có tài xế'), findsOneWidget);
    expect(find.text('Tài xế đã nhận đơn MM01.'), findsOneWidget);
    expect(t.getTopLeft(find.byType(NoticeBanner)).dy, lessThan(100));
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.text('Đơn đã có tài xế'), findsNothing);
    expect(cubit.state.showing, isNull);
  });

  testWidgets('chạm banner gọi onOpen với đúng thông báo rồi đóng', (t) async {
    AppNotice? opened;
    await t.pumpWidget(_host(cubit, onOpen: (n) => opened = n));
    final notice = noticeFor('ORDER_ACCEPTED', body: 'Tài xế đã nhận đơn.', data: {'orderId': '7'});
    cubit.push(notice);
    await _shown(t);
    await t.tap(find.byType(NoticeBanner));
    await t.pumpAndSettle();
    expect(opened?.orderId, 7);
    expect(cubit.state.showing, isNull);
  });

  testWidgets('vuốt lên để đóng', (t) async {
    await t.pumpWidget(_host(cubit));
    cubit.push(noticeFor('ORDER_ACCEPTED', body: 'Tài xế đã nhận đơn.'));
    await _shown(t);
    await t.fling(find.byType(NoticeBanner), const Offset(0, -300), 1000);
    await t.pumpAndSettle();
    expect(find.byType(NoticeBanner), findsNothing);
    expect(cubit.state.showing, isNull);
  });

  testWidgets('hai thông báo dồn: hiện lần lượt, không đè nhau', (t) async {
    await t.pumpWidget(_host(cubit));
    cubit.push(noticeFor('ORDER_CANCELLED', body: 'Đơn A bị hủy.', data: {'orderId': '1'}));
    cubit.push(noticeFor('ORDER_CANCELLED', body: 'Đơn B bị hủy.', data: {'orderId': '2'}));
    await _shown(t);
    expect(find.text('Đơn A bị hủy.'), findsOneWidget);
    expect(find.text('Đơn B bị hủy.'), findsNothing);
    await t.pump(const Duration(seconds: 7));
    await t.pumpAndSettle();
    expect(find.text('Đơn B bị hủy.'), findsOneWidget);
    await t.pump(const Duration(seconds: 7));
    await t.pumpAndSettle();
    expect(find.byType(NoticeBanner), findsNothing);
  });

  testWidgets('showSnack vẫn dùng được và hiện dưới dạng banner màu lỗi', (t) async {
    await t.pumpWidget(
      _host(
        cubit,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(onPressed: () => showSnack(ctx, 'Nhập email và mật khẩu.', error: true), child: const Text('bấm')),
          ),
        ),
      ),
    );
    await t.tap(find.text('bấm'));
    await _shown(t);
    expect(find.text('Nhập email và mật khẩu.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final banner = t.widget<Material>(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(Material)).first);
    expect(banner.color, AppColors.redBg);
    await t.pump(const Duration(seconds: 7));
    await t.pumpAndSettle();
  });

  testWidgets('không có NoticeHost thì showSnack quay về SnackBar', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(onPressed: () => showSnack(ctx, 'Lưu rồi.'), child: const Text('bấm'))),
        ),
      ),
    );
    await t.tap(find.text('bấm'));
    await t.pump();
    expect(find.text('Lưu rồi.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
