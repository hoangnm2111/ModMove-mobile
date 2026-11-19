import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/vietnam_time.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/driver_wallet_repository.dart';
import 'wallet_cubit.dart';

String walletStatus(String status) => switch (status) {
  'Completed' => 'Hoàn thành',
  'Pending' => 'Đang xử lý',
  'Failed' => 'Thất bại',
  'Rejected' => 'Bị từ chối',
  _ => status,
};
String transactionLabel(String type) => switch (type) {
  'TopUpDeposit' => 'Nạp ký quỹ',
  'TripEarning' => 'Thu nhập chuyến',
  'CommissionDeduction' => 'Phí nền tảng',
  'WithdrawEarnings' => 'Rút thu nhập',
  'Withdrawal' => 'Rút tiền',
  'DepositRefill' => 'Bổ sung ký quỹ từ thu nhập',
  'CommissionDebtPaid' => 'Trả nợ phí nền tảng',
  _ => type,
};

class WalletTransactionTile extends StatelessWidget {
  const WalletTransactionTile(this.tx, {super.key});
  final WalletTransaction tx;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      onTap: tx.orderId == null
          ? null
          : () => Navigator.pushNamed(
              context,
              '/trip-earnings',
              arguments: tx.orderId,
            ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tx.credit ? AppColors.greenBg : AppColors.peach,
            child: Icon(
              tx.credit ? Icons.arrow_upward : Icons.arrow_downward,
              color: tx.credit ? AppColors.green : AppColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transactionLabel(tx.type)}${tx.orderCode == null ? '' : ' #${tx.orderCode}'}',
                  style: appText(size: 12, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${walletStatus(tx.status)} · ${vietnamStamp(tx.createdAt)}',
                  style: appText(size: 10, color: AppColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${tx.credit ? '+' : '−'}${formatVnd(tx.amount)}',
            style: appText(
              size: 13,
              weight: FontWeight.w700,
              color: tx.status != 'Completed'
                  ? AppColors.secondary
                  : tx.credit
                  ? AppColors.green
                  : AppColors.red,
            ),
          ),
        ],
      ),
    ),
  );
}

class WalletTransactionsScreen extends StatelessWidget {
  const WalletTransactionsScreen({super.key, this.withdrawals = false});
  final bool withdrawals;
  @override
  Widget build(BuildContext context) => BlocBuilder<WalletCubit, WalletState>(
    builder: (context, state) {
      final data = withdrawals ? state.withdrawals : state.transactions;
      final cubit = context.read<WalletCubit>();
      return Scaffold(
        appBar: AppHeader(
          withdrawals ? 'Yêu cầu rút tiền' : 'Lịch sử giao dịch',
        ),
        body: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.busy) const LinearProgressIndicator(),
              if (state.error != null) Notice(state.error!, peach: true),
              if (data?.items.isEmpty == true)
                const Notice('Chưa có giao dịch.'),
              for (final tx in data?.items ?? <WalletTransaction>[])
                WalletTransactionTile(tx),
              if (data?.hasNext == true)
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => cubit.loadMore(withdrawals: withdrawals),
                  child: const Text('Tải thêm'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
