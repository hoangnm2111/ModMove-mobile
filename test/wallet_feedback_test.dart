import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/domain/result_page.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import 'package:modmove_mobile/features/wallet/domain/driver_wallet_repository.dart';
import 'package:modmove_mobile/features/wallet/presentation/bank_account_sheet.dart';
import 'package:modmove_mobile/features/wallet/presentation/deposit_screen.dart';
import 'package:modmove_mobile/features/wallet/presentation/wallet_cubit.dart';
import 'package:modmove_mobile/features/wallet/presentation/wallet_screen.dart';
import 'package:modmove_mobile/features/wallet/presentation/withdrawal_screen.dart';

Future<void> mountWallet(
  WidgetTester tester,
  WalletCubit cubit, {
  Widget page = const WithdrawalScreen(),
  double scale = 1,
  GlobalKey? boundary,
}) async {
  await cubit.refresh();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> snapshot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('test/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final rule in [
    (deposit: 500000, earnings: 0, debt: 0, maximum: 0, label: 'Tối đa 0đ'),
    (
      deposit: -20000,
      earnings: 120000,
      debt: 20000,
      maximum: 100000,
      label: 'Tối đa 100.000đ',
    ),
    (
      deposit: -20000,
      earnings: 10000,
      debt: 20000,
      maximum: 0,
      label: 'Tối đa 0đ',
    ),
  ]) {
    testWidgets(
      'wallet overview uses server withdrawal limit with deposit ${rule.deposit} and income ${rule.earnings}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = RuleWallet(
          WalletBalance(
            rule.deposit,
            rule.earnings,
            debt: rule.debt,
            withdrawable: rule.maximum,
            bank: const DriverBankAccount(
              'Vietcombank',
              '0123456789',
              'TAI XE DEMO',
            ),
          ),
        );
        final cubit = WalletCubit(repo);
        addTearDown(cubit.close);
        await mountWallet(
          tester,
          cubit,
          page: const WalletScreen(),
          scale: 1.3,
        );
        await tester.scrollUntilVisible(
          find.text('Rút tiền'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(rule.label), findsOneWidget);
        expect(find.text('Rút theo hạn mức khả dụng'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Rút tiền'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('request-withdrawal')),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        final submit = tester.widget<PrimaryButton>(
          find.byKey(const Key('request-withdrawal')),
        );
        expect(submit.onPressed != null, rule.maximum > 0);
        expect(repo.withdrawn, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('debt is disclosed separately from the requested bank payout', (
    tester,
  ) async {
    final repo = RuleWallet(
      const WalletBalance(
        -20000,
        120000,
        debt: 20000,
        withdrawable: 100000,
        bank: DriverBankAccount('Vietcombank', '0123456789', 'TAI XE DEMO'),
      ),
    );
    final cubit = WalletCubit(repo);
    addTearDown(cubit.close);
    await mountWallet(tester, cubit);
    await tester.enterText(find.byKey(const Key('withdraw-amount')), '50000');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.scrollUntilVisible(
      find.byKey(const Key('request-withdrawal')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('request-withdrawal')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trả nợ hoa hồng: 20.000đ'), findsOneWidget);
    expect(
      find.textContaining('Tổng trừ từ ví thu nhập: 70.000đ'),
      findsOneWidget,
    );
    expect(repo.withdrawn, isNull);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(repo.withdrawn, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [390.0, 320.0]) {
    testWidgets('bank sheet fits $width with keyboard and large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 390 ? 844 : 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = WalletCubit(FeedbackWallet());
      addTearDown(cubit.close);
      final key = GlobalKey();
      await mountWallet(
        tester,
        cubit,
        scale: width == 320 ? 1.3 : 1,
        boundary: key,
      );
      await tester.tap(find.textContaining('Vietcombank ·'));
      await tester.pumpAndSettle();
      expect(find.byType(BankAccountSheet), findsOneWidget);
      expect(find.text('10/30'), findsNothing);
      expect(tester.takeException(), isNull);
      if (width == 390) await snapshot(tester, key, 'bank-account-v2');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.tap(find.byKey(const Key('bank-name')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('bank-holder')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.byKey(const Key('save-bank-account'))).dy,
        lessThanOrEqualTo(tester.view.physicalSize.height - 280),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'bank save failure retains entries; retry closes only after success',
    (tester) async {
      final repo = FeedbackWallet()..failBank = true;
      final cubit = WalletCubit(repo);
      addTearDown(cubit.close);
      await mountWallet(tester, cubit);
      await tester.tap(find.textContaining('Vietcombank ·'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('bank-name')), 'ACB');
      await tester.enterText(find.byKey(const Key('bank-number')), '987654321');
      await tester.tap(find.byKey(const Key('save-bank-account')));
      await tester.pumpAndSettle();
      expect(find.byType(BankAccountSheet), findsOneWidget);
      expect(find.text('987654321'), findsOneWidget);
      expect(find.text('Chưa lưu được ngân hàng. Hãy thử lại.'), findsWidgets);
      expect(repo.bankSaves, 1);
      repo.failBank = false;
      await tester.tap(find.byKey(const Key('save-bank-account')));
      await tester.pumpAndSettle();
      expect(find.byType(BankAccountSheet), findsNothing);
      expect(cubit.state.balance!.bank!.name, 'ACB');
      expect(repo.bankSaves, 2);
    },
  );

  testWidgets(
    'pending request explains disabled withdrawal and refresh enables a 1 VND request',
    (tester) async {
      final repo = FeedbackWallet()..pending = true;
      final cubit = WalletCubit(repo);
      addTearDown(cubit.close);
      await mountWallet(tester, cubit);
      expect(find.text('Rút từ 1đ đến 89.000đ.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('request-withdrawal')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<PrimaryButton>(find.byKey(const Key('request-withdrawal')))
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining('sau khi quản trị viên duyệt hoặc từ chối'),
        findsOneWidget,
      );
      repo.pending =
          false; // Simulate the admin changing server state, never a driver-side override.
      await tester.ensureVisible(find.text('Kiểm tra trạng thái'));
      await tester.tap(find.text('Kiểm tra trạng thái'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PrimaryButton>(find.byKey(const Key('request-withdrawal')))
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.byKey(const Key('withdraw-amount')));
      await tester.enterText(find.byKey(const Key('withdraw-amount')), '1');
      await tester.ensureVisible(find.byKey(const Key('request-withdrawal')));
      await tester.tap(find.byKey(const Key('request-withdrawal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi yêu cầu'));
      await tester.pumpAndSettle();
      expect(repo.withdrawn, 1);
      expect(cubit.state.balance!.pendingWithdrawal, true);
    },
  );

  testWidgets('withdrawal validates zero and over-balance amounts inline', (
    tester,
  ) async {
    final repo = FeedbackWallet();
    final cubit = WalletCubit(repo);
    addTearDown(cubit.close);
    await mountWallet(tester, cubit);
    await tester.enterText(find.byKey(const Key('withdraw-amount')), '0');
    await tester.ensureVisible(find.byKey(const Key('request-withdrawal')));
    await tester.tap(find.byKey(const Key('request-withdrawal')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số tiền từ 1đ.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('withdraw-amount')));
    await tester.enterText(find.byKey(const Key('withdraw-amount')), '90000');
    await tester.pumpAndSettle();
    expect(find.text('Tối đa 89.000đ.'), findsOneWidget);
    expect(repo.withdrawn, isNull);
  });

  testWidgets('payment failure shows useful support reference without a QR', (
    tester,
  ) async {
    final repo = FeedbackWallet();
    final cubit = WalletCubit(repo);
    addTearDown(cubit.close);
    await mountWallet(tester, cubit, page: const DepositScreen());
    await tester.tap(find.text('Tạo mã thanh toán PayOS'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa xử lý được thanh toán'), findsOneWidget);
    expect(find.textContaining('Mã hỗ trợ: test-request-42'), findsOneWidget);
    expect(find.text('Mở thanh toán PayOS'), findsNothing);
    expect(cubit.state.payment, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class FeedbackWallet implements DriverWalletRepository {
  bool pending = false, failBank = false;
  int bankSaves = 0;
  int? withdrawn;
  DriverBankAccount bank = const DriverBankAccount(
    'Vietcombank',
    '0123456789',
    'TAI XE DEMO',
  );
  @override
  Future<WalletBalance> balance() async => WalletBalance(
    500000,
    89000,
    withdrawable: 89000,
    pendingWithdrawal: pending,
    pendingAmount: 100000,
    bank: bank,
  );
  @override
  Future<void> saveBank(DriverBankAccount next) async {
    bankSaves++;
    if (failBank) {
      throw const WalletFailure('Chưa lưu được ngân hàng. Hãy thử lại.');
    }
    bank = next;
  }

  @override
  Future<WithdrawalReceipt> withdraw(int amount) async {
    withdrawn = amount;
    pending = true;
    return WithdrawalReceipt('42', amount, 0);
  }

  @override
  Future<DepositPayment> topUp(int amount) async => throw const WalletFailure(
    'Dịch vụ nạp tiền hiện không khả dụng. Vui lòng thử lại sau hoặc liên hệ hỗ trợ.',
    reference: 'test-request-42',
  );
  @override
  Future<ResultPage<WalletTransaction>> transactions({int page = 1}) async =>
      const ResultPage([], 1, 0, false);
  @override
  Future<ResultPage<WalletTransaction>> withdrawals({int page = 1}) async =>
      const ResultPage([], 1, 0, false);
}

class RuleWallet extends FeedbackWallet {
  RuleWallet(this.serverBalance);
  final WalletBalance serverBalance;
  @override
  Future<WalletBalance> balance() async => serverBalance;
}
