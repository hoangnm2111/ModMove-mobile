import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/driver_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/formatting/currency.dart';
import '../domain/driver_wallet_repository.dart';
import 'wallet_cubit.dart';
import 'wallet_transactions_screen.dart';
import 'deposit_screen.dart';
import 'withdrawal_screen.dart';

Future<void> openWalletPage(BuildContext context, Widget page) async {
  final cubit = context.read<WalletCubit>();
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(value: cubit, child: page),
    ),
  );
  if (!cubit.isClosed) await cubit.refresh();
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<WalletCubit>().refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WalletCubit>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<WalletCubit, WalletState>(
    builder: (context, state) {
      final cubit = context.read<WalletCubit>();
      final balance = state.balance;
      return Scaffold(
        appBar: AppHeader(
          'Ví tài xế',
          actions: [
            IconButton(
              tooltip: 'Tải lại ví',
              onPressed: state.busy ? null : cubit.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: const DriverNavigation(2),
        body: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.busy) const LinearProgressIndicator(),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [AppColors.orange, Color(0xFFF47716)],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _balance(
                        'Ví thu nhập',
                        balance?.earnings,
                        'Đơn PayOS đã hoàn tất',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 75,
                      color: Colors.white30,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: _balance(
                        'Ký quỹ',
                        balance?.deposit,
                        'Rút theo hạn mức khả dụng',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (balance != null)
                Notice(
                  !balance.active
                      ? 'Ví đang bị khóa'
                      : balance.canReceiveCash
                      ? 'Đủ ký quỹ tối thiểu để nhận đơn'
                      : 'Cần bổ sung ký quỹ để nhận đơn',
                  detail:
                      'Ký quỹ tối thiểu ${formatVnd(balance.minimumDeposit)}. Hệ thống kiểm tra thêm hoa hồng của từng đơn.',
                  icon: balance.canReceiveCash ? 'check' : 'warning',
                  peach: !balance.canReceiveCash,
                  success: balance.active && balance.canReceiveCash,
                ),
              if (balance != null && balance.debt > 0) ...[
                const SizedBox(height: 8),
                Notice(
                  'Nợ hoa hồng ${formatVnd(balance.debt)}',
                  detail:
                      'Có thể rút ${formatVnd(balance.withdrawable)} sau khi trừ nợ.',
                  peach: true,
                ),
              ],
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _action(
                        'wallet-plus',
                        'Nạp ký quỹ',
                        () => openWalletPage(context, const DepositScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _action(
                        'withdraw',
                        'Rút tiền',
                        () => openWalletPage(context, const WithdrawalScreen()),
                        hint: balance == null
                            ? 'Đang tải hạn mức'
                            : 'Tối đa ${formatVnd(balance.withdrawable)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _action(
                        'receipt',
                        'Báo cáo doanh thu',
                        () => Navigator.pushNamed(context, '/revenue'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Khi không có chuyến đang chạy, có thể rút cả thu nhập và ký quỹ theo hạn mức hệ thống. Khi đang chạy chuyến, chỉ rút phần thu nhập. Rút ký quỹ có thể làm bạn chưa đủ điều kiện nhận đơn mới.',
                style: appText(size: 11, color: AppColors.secondary),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Notice(state.error!, peach: true),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: SectionTitle('Giao dịch gần đây', size: 16),
                  ),
                  TextButton(
                    onPressed: () => openWalletPage(
                      context,
                      const WalletTransactionsScreen(),
                    ),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
              if (state.transactions?.items.isEmpty == true)
                const AppCard(child: Text('Chưa có giao dịch.')),
              for (final tx
                  in state.transactions?.items.take(5) ?? <WalletTransaction>[])
                WalletTransactionTile(tx),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const AppIcon('bank', color: AppColors.orange),
                title: const Text('Tài khoản nhận tiền'),
                subtitle: Text(
                  balance?.bank == null
                      ? 'Chưa liên kết ngân hàng'
                      : '${balance!.bank!.name} · ${balance.bank!.masked}',
                ),
                trailing: const AppIcon('chevron-right'),
                onTap: () => openWalletPage(context, const WithdrawalScreen()),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _balance(String label, int? value, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: appText(size: 12, color: Colors.white, weight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value == null ? '—' : formatVnd(value),
          style: appText(
            size: 25,
            color: Colors.white,
            weight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 7),
      Text(hint, style: appText(size: 10, color: Colors.white)),
    ],
  );
  Widget _action(
    String icon,
    String label,
    VoidCallback onTap, {
    String? hint,
  }) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    child: Column(
      children: [
        AppIcon(icon, size: 30, color: AppColors.orange),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: appText(size: 12, weight: FontWeight.w600),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: appText(size: 11, color: AppColors.secondary),
          ),
        ],
      ],
    ),
  );
}
