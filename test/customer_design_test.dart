import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/theme/customer_theme.dart';
import 'package:modmove_mobile/features/auth/domain/auth_repository.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_screen.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_widgets.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_payment_receipt.dart';
import 'support/customer_fixtures.dart';
import 'support/remote_fixtures.dart';

class _Auth implements AuthRepository {
  final calls = <String>[];
  String? role, password;
  @override
  bool get signedIn => false;
  @override
  Stream<void> get expired => const Stream.empty();
  @override
  Future<void> restore() async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> login(String email, String password) async {
    calls.add('login:$email');
    this.password = password;
  }

  @override
  Future<void> register(
    String name,
    String phone,
    String email,
    String password, {
    String role = 'Driver',
  }) async {
    calls.add('register:$email');
    this.role = role;
    this.password = password;
  }

  @override
  Future<void> verify(String email, String code, String password) async {
    calls.add('verify:$code');
    this.password = password;
  }

  @override
  Future<void> resend(String email) async {
    calls.add('resend:$email');
  }

  @override
  Future<void> forgotPassword(String email) async {
    calls.add('forgot:$email');
  }

  @override
  Future<void> resetPassword(String email, String code, String password) async {
    calls.add('reset:$code');
    this.password = password;
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'registration retains customer role and original password through email OTP',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _Auth();
      final cubit = AuthCubit(repo)..show(AuthStage.register);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: buildCustomerTheme(),
            home: const AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final (key, value) in [
        ('Họ và tên', 'Minh Anh'),
        ('Số điện thoại', '0901234567'),
        ('Email', 'customer@example.com'),
        ('Mật khẩu', 'Password123'),
      ]) {
        await tester.enterText(find.byKey(ValueKey(key)), value);
      }
      await tapVisible(tester, find.text('Tạo tài khoản'));
      expect(repo.role, 'Customer');
      expect(cubit.state.stage, AuthStage.verify);
      expect(find.text('customer@example.com'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('Mã OTP')), '123456');
      await tapVisible(tester, find.text('Xác minh và đăng nhập'));
      expect(repo.calls, [
        'register:customer@example.com',
        'verify:123456',
        'login:customer@example.com',
      ]);
      expect(repo.password, 'Password123');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'auth stages remain usable with narrow screen large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = AuthCubit(_Auth())..show(AuthStage.login);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: buildCustomerTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.4),
                viewInsets: const EdgeInsets.only(bottom: 260),
              ),
              child: child!,
            ),
            home: const AuthScreen(),
          ),
        ),
      );
      for (final stage in [
        AuthStage.login,
        AuthStage.register,
        AuthStage.verify,
        AuthStage.forgot,
        AuthStage.reset,
      ]) {
        cubit.show(stage);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilledButton).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: stage.name);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('delete confirmation cannot be submitted before acknowledging', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCustomerTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await confirmCustomerAction(
                  context,
                  'Xóa tài khoản?',
                  'Tài khoản sẽ ngừng hoạt động.',
                  action: 'Xác nhận xóa',
                  destructive: true,
                  acknowledge: true,
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tapVisible(tester, find.text('Mở'));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tapVisible(tester, find.text('Xác nhận xóa'));
    expect(result, true);
  });

  testWidgets('receipt only reports payment success when order API says Paid', (
    tester,
  ) async {
    var paid = false;
    final api = CustomerTestApi(
      handler: (r) async => r.url.path.endsWith('/orders/1')
          ? jsonResponse(customerOrder(payment: paid ? 'Paid' : 'Unpaid'))
          : null,
    );
    addTearDown(api.close);
    await api.login();
    for (final state in [false, true]) {
      paid = state;
      final order = await api.repository.order(1);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCustomerTheme(),
          home: CustomerPaymentReceipt(order),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Thanh toán thành công'),
        state ? findsOneWidget : findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
