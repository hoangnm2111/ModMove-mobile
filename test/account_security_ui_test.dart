import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/account/domain/account_security_repository.dart';
import 'package:modmove_mobile/features/account/presentation/account_security_cubit.dart';
import 'package:modmove_mobile/features/account/presentation/account_security_screen.dart';

class SecurityRepository implements AccountSecurityRepository {
  int deletes = 0;
  @override
  Future<void> changePassword(String current, String next) async {}
  @override
  Future<void> deleteAccount() async {
    deletes++;
    throw const AccountSecurityFailure(
      'Ví còn số dư hoặc nợ. Hãy xử lý ví trước khi xóa tài khoản.',
    );
  }
}

void main() {
  testWidgets(
    'account security fits narrow large text and deletion needs explicit acknowledgement',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = SecurityRepository();
      final cubit = AccountSecurityCubit(repository);
      addTearDown(cubit.close);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const AccountSecurityScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final picture = await render.toImage(pixelRatio: 2);
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('test/screenshots/account-security.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.scrollUntilVisible(
        find.text('Xóa tài khoản'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Xóa tài khoản'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận xóa');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(repository.deletes, 0);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.deletes, 1);
      expect(cubit.state.error, contains('Ví còn số dư'));
      expect(cubit.state.completed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
