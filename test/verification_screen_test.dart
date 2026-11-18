import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/app/app.dart';

void main() {
  testWidgets('blank personal inputs display errors and do not advance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ModMoveApp(screen: 'verification-personal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    // Không còn ô nhập số CCCD/GPLX (2026-11-18); thiếu ảnh thì không sang bước sau.
    expect(find.text('Số CCCD'), findsNothing);
    expect(find.text('Số giấy phép lái xe'), findsNothing);
    expect(find.text('Giấy tờ cá nhân'), findsOneWidget);
  });
  testWidgets(
    'vehicle form retains edited fields after going back and forward',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ModMoveApp(screen: 'verification-vehicle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('field-plate')),
        '30C-456.78',
      );
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('30C-456.78'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
