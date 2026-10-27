import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/main.dart';

void main() {
  testWidgets(
    'service selection opens its matching public fare and tabs update it',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ModMoveApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bán tải'));
      await tester.pumpAndSettle();
      expect(find.text('Xe bán tải'), findsOneWidget);
      expect(find.text('100.000đ'), findsNWidgets(2));
      await tester.tap(find.text('Xe tải'));
      await tester.pumpAndSettle();
      expect(find.text('Xe tải 1 tấn'), findsOneWidget);
      expect(find.text('180.000đ'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chở hàng lớn,\nthật dễ dàng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
