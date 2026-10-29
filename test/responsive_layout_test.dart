import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/app/app.dart';

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(360, 800), 1.3),
  ]) {
    for (final screen in [
      'home',
      'pricing',
      'verification-personal',
      'verification-vehicle',
      'profile-approved',
      'profile-pending',
      'profile-rejected',
    ]) {
      testWidgets('$screen stays usable at $size with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(ModMoveApp(screen: screen));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
