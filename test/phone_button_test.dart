import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/widgets/phone_button.dart';

void main() {
  testWidgets('số điện thoại có nút gọi, số trống hiện dấu gạch', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [PhoneText('0900000003'), PhoneText('')]))));
    await tester.pumpAndSettle();
    expect(find.text('0900000003'), findsOneWidget);
    expect(find.bySemanticsLabel('Gọi 0900000003'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byType(PhoneCallButton), findsOneWidget);
  });
}
