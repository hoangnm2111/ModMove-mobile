import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';

void main() {
  testWidgets(
    'primary actions invoke callbacks and remain disabled while busy',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Column(
              children: [
                PrimaryButton('Tiếp tục', onPressed: () => taps++),
                PrimaryButton('Đang gửi', onPressed: () => taps++, busy: true),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tiếp tục'));
      await tester.pump();
      expect(taps, 1);
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(taps, 1);
    },
  );

  testWidgets(
    'navigation exposes selected state and reports a new destination',
    (tester) async {
      var destination = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(
              selected: 0,
              onSelect: (value) => destination = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dịch vụ'));
      expect(destination, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
