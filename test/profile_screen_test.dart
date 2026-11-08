import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/app/app.dart';
import 'package:modmove_mobile/features/onboarding/presentation/screens/driver_profile_screen.dart';
import 'package:modmove_mobile/features/onboarding/presentation/screens/verification_screen.dart';

void main() {
  testWidgets(
    'profile toggle cannot bypass the active trip availability guard',
    (tester) async {
      await tester.pumpWidget(const ModMoveApp(screen: 'profile-approved'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(DriverProfileScreen));
      final repo = context.read<DriverTripRepository>();
      await tester.runAsync(() async {
        await repo.openOffer(repo.current.jobs.first.id);
        await repo.acceptOffer(repo.current.offer!.job.id);
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('driver-online')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('driver-online')))
            .value,
        isTrue,
      );
      expect(repo.current.online, isTrue);
      expect(find.textContaining('Bạn đang có chuyến.'), findsOneWidget);
      final tripId = repo.current.trip!.job.id;
      await tester.tap(find.text('Đơn hàng'));
      await tester.pumpAndSettle();
      expect(find.text('Đến điểm lấy hàng'), findsOneWidget);
      expect(repo.current.trip!.job.id, tripId);
    },
  );
  for (final status in ['approved', 'pending', 'rejected']) {
    testWidgets('$status profile enforces online availability', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ModMoveApp(screen: 'profile-$status'));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('driver-online'));
      final control = tester.widget<Switch>(toggle);
      expect(control.onChanged != null, status == 'approved');
      expect(control.value, status == 'approved');
      expect(
        find.byKey(const Key('open-driver-home')),
        status == 'approved' ? findsOneWidget : findsNothing,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      if (status != 'approved') {
        await tester.tap(find.text('Đơn hàng'));
        await tester.pumpAndSettle();
        expect(find.text('Chưa thể nhận đơn'), findsOneWidget);
        expect(find.text('Trang chủ tài xế'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('vehicle tab and document preview show selected profile data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ModMoveApp(screen: 'profile-approved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phương tiện'));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin phương tiện'), findsOneWidget);
    expect(find.text('29C-123.45'), findsOneWidget);
    await tester.ensureVisible(find.text('Đăng ký xe'));
    await tester.tap(find.text('Đăng ký xe'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'correction opens the relevant step and preserves accepted fields',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ModMoveApp(screen: 'profile-rejected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giấy đăng kiểm'));
      await tester.pumpAndSettle();
      expect(find.byType(VerificationScreen), findsOneWidget);
      expect(find.text('Thông tin phương tiện'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('field-plate')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(find.text('Xem ảnh'), findsNWidgets(2));
      expect(find.text('Thay ảnh'), findsOneWidget);
    },
  );

  testWidgets('valid submission routes to a locked pending profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ModMoveApp(screen: 'verification-vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi hồ sơ xét duyệt'));
    await tester.pumpAndSettle();
    expect(find.byType(DriverProfileScreen), findsOneWidget);
    expect(find.text('Hồ sơ đang chờ duyệt'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('Cập nhật giấy tờ'), findsNothing);
  });
}
