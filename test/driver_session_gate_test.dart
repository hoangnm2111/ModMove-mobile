import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/app/app.dart';
import 'package:modmove_mobile/core/notifications/realtime_source.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'driver_backend_test.dart' show FakeBackend;

const _driver = Session(accessToken: 'a', refreshToken: 'r', userId: 5, fullName: 'Tài xế', role: 'Driver');

void main() {
  // Lỗi cũ: tài xế đã đăng nhập bấm "Trang chủ" (route /home) hoặc mở lại app thì rơi về
  // trang chủ công khai có nút "Đăng nhập" → trông như bị đăng xuất.
  for (final approval in ['Approved', 'Pending']) {
    testWidgets('tài xế đã đăng nhập ($approval) không bị đưa về trang công khai', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = FakeBackend(profileApproval: approval);
      await tester.pumpWidget(ModMoveApp(
        sessions: MemorySessionStore(_driver),
        httpClient: MockClient(backend.handle),
        realtimeSource: const NoRealtimeSource(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Đăng nhập'), findsNothing);
      expect(
        find.text(approval == 'Approved' ? 'Trang chủ tài xế' : 'Hồ sơ tài xế'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  }

  // Lỗi cũ: nhiều luồng tài xế đặt màn tài xế làm màn gốc (pushNamedAndRemoveUntil('/driver-home', ...)),
  // nên popUntil(isFirst) khi đăng xuất vẫn ở lại màn tài xế và các API báo "phiên hết hạn".
  testWidgets('đăng xuất khi màn gốc là trang chủ tài xế thì về trang chủ công khai', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    await tester.pumpWidget(ModMoveApp(
      sessions: MemorySessionStore(_driver),
      httpClient: MockClient(backend.handle),
      realtimeSource: const NoRealtimeSource(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Dựng lại đúng tình huống: màn tài xế là màn gốc, rồi mở thêm một màn tài xế phía trên.
    ModMoveApp.navigatorKey.currentState!.pushNamedAndRemoveUntil('/driver-home', (_) => false);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    ModMoveApp.navigatorKey.currentState!.pushNamed('/driver-trips');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Đăng nhập'), findsNothing);

    await ModMoveApp.navigatorKey.currentContext!.read<AuthCubit>().logout();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Trang chủ tài xế'), findsNothing);
    expect(find.text('Chuyến của tôi'), findsNothing);
    expect(find.text('Đăng nhập'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });
}
