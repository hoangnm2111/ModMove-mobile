import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/notifications/app_notice.dart';
import 'package:modmove_mobile/core/notifications/notice_catalog.dart';
import 'package:modmove_mobile/core/notifications/notification_cubit.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/notifications/notifications_screen.dart';

Widget _app(NotificationCubit cubit, Widget home) => BlocProvider.value(value: cubit, child: MaterialApp(theme: buildAppTheme(), home: home));

void _fill(NotificationCubit cubit, int count) {
  for (var i = 1; i <= count; i++) {
    cubit.push(noticeFor('ORDER_ACCEPTED', body: 'Nội dung $i', data: {'orderId': '$i'}, at: DateTime.now().add(Duration(seconds: i))));
  }
}

void main() {
  late NotificationCubit cubit;
  setUp(() => cubit = NotificationCubit());
  tearDown(() => cubit.close());

  testWidgets('chuông hiện số chưa đọc, ẩn khi 0, quá 9 thì hiện 9+', (t) async {
    await t.pumpWidget(_app(cubit, Scaffold(appBar: AppBar(actions: [NotificationBell(onTap: () {})]))));
    expect(find.byKey(const Key('bell-badge')), findsNothing);
    _fill(cubit, 3);
    await t.pump();
    await t.pump();
    expect(find.text('3'), findsOneWidget);
    _fill(cubit, 0);
    for (var i = 4; i <= 12; i++) {
      cubit.push(noticeFor('ORDER_ACCEPTED', data: {'orderId': '$i'}));
    }
    await t.pump();
    await t.pump();
    expect(find.text('9+'), findsOneWidget);
    cubit.markAllRead();
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('bell-badge')), findsNothing);
  });

  testWidgets('màn hình liệt kê mới nhất trước kèm thời gian tương đối', (t) async {
    _fill(cubit, 3);
    await t.pumpWidget(_app(cubit, NotificationsScreen(onOpen: (_) {})));
    await t.pump();
    final titles = t.widgetList<Text>(find.textContaining('Nội dung')).map((w) => w.data).toList();
    expect(titles, ['Nội dung 3', 'Nội dung 2', 'Nội dung 1']);
    expect(find.text('vừa xong'), findsWidgets);
  });

  testWidgets('mở màn hình thì đánh dấu đã đọc hết', (t) async {
    _fill(cubit, 4);
    expect(cubit.state.unread, 4);
    await t.pumpWidget(_app(cubit, NotificationsScreen(onOpen: (_) {})));
    await t.pump();
    await t.pump();
    expect(cubit.state.unread, 0);
  });

  testWidgets('chạm một mục gọi onOpen với đúng thông báo', (t) async {
    _fill(cubit, 2);
    AppNotice? opened;
    await t.pumpWidget(_app(cubit, NotificationsScreen(onOpen: (n) => opened = n)));
    await t.pump();
    await t.tap(find.text('Nội dung 1'));
    expect(opened?.orderId, 1);
  });

  testWidgets('hộp thư trống hiện "Chưa có thông báo"', (t) async {
    await t.pumpWidget(_app(cubit, NotificationsScreen(onOpen: (_) {})));
    await t.pump();
    expect(find.text('Chưa có thông báo'), findsOneWidget);
  });

  testWidgets('chuông vẫn hiện khi màn dựng riêng không có NotificationCubit', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(appBar: AppBar(actions: [NotificationBell(onTap: () {})]))));
    expect(find.byType(NotificationBell), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });
}
