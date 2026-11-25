import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/widgets/password_field.dart';

void main() {
  testWidgets('ô mật khẩu mặc định ẩn; bấm con mắt thì hiện, bấm lần nữa thì ẩn lại', (tester) async {
    final controller = TextEditingController(text: 'Bi-mat-123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordField(controller: controller, label: 'Mật khẩu mới'),
        ),
      ),
    );

    bool obscured() => tester.widget<EditableText>(find.byType(EditableText)).obscureText;
    expect(obscured(), isTrue);

    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(obscured(), isFalse);
    expect(controller.text, 'Bi-mat-123'); // nội dung không đổi

    await tester.tap(find.byTooltip('Ẩn mật khẩu'));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  testWidgets('mỗi ô có con mắt riêng: hiện ô này không làm lộ ô kia', (tester) async {
    final a = TextEditingController(), b = TextEditingController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PasswordField(controller: a, label: 'Mật khẩu hiện tại'),
              PasswordField(controller: b, label: 'Mật khẩu mới'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Hiện mật khẩu').first);
    await tester.pump();

    final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(fields.map((f) => f.obscureText), [false, true]);
  });
}
