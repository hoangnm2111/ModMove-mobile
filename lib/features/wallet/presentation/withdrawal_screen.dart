import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/driver_wallet_repository.dart';
import 'wallet_cubit.dart';
import 'wallet_screen.dart';
import 'wallet_transactions_screen.dart';
import 'bank_account_sheet.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});
  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<WalletCubit, WalletState>(
    builder: (context, state) {
      final balance = state.balance;
      final cubit = context.read<WalletCubit>();
      final block = _withdrawalBlock(state);
      return Scaffold(
        appBar: AppHeader(
          'Rút tiền',
          actions: [
            IconButton(
              tooltip: 'Tải lại trạng thái rút tiền',
              onPressed: state.busy ? null : cubit.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                color: AppColors.peach,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Có thể rút'),
                    const SizedBox(height: 8),
                    Text(
                      balance == null ? '—' : formatVnd(balance.withdrawable),
                      style: appText(
                        size: 32,
                        weight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Khi không có chuyến đang chạy, có thể rút cả thu nhập và ký quỹ. Khi đang chạy chuyến, chỉ rút thu nhập theo hạn mức khả dụng.',
                      style: appText(size: 12, color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              if (balance != null && balance.debt > 0) ...[
                const SizedBox(height: 10),
                Notice(
                  'Nợ hoa hồng: ${formatVnd(balance.debt)}',
                  detail:
                      'Ký quỹ đang âm. Toàn bộ khoản nợ được trừ từ thu nhập trước khi giữ số tiền bạn yêu cầu rút.',
                  peach: true,
                ),
              ],
              const SizedBox(height: 20),
              const SectionTitle('Số tiền cần rút', size: 16),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Form(
                      key: _form,
                      child: TextFormField(
                        key: const Key('withdraw-amount'),
                        controller: _amount,
                        enabled: !state.busy,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          final amount = int.tryParse(value ?? '') ?? 0;
                          if (amount < 1) return 'Nhập số tiền từ 1đ.';
                          if (balance != null &&
                              amount > balance.withdrawable) {
                            return 'Tối đa ${formatVnd(balance.withdrawable)}.';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Nhập số tiền',
                          suffixText: 'đ',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed:
                        balance == null ||
                            state.busy ||
                            balance.withdrawable < 1
                        ? null
                        : () => _amount.text = '${balance.withdrawable}',
                    child: const Text('Toàn bộ'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                balance == null
                    ? 'Rút từ 1đ. Số tiền phải là số nguyên VND.'
                    : balance.withdrawable > 0
                    ? 'Rút từ 1đ đến ${formatVnd(balance.withdrawable)}.'
                    : 'Rút từ 1đ. Hiện chưa có số dư khả dụng để rút.',
                style: appText(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Nhận tiền về tài khoản', size: 16),
              const SizedBox(height: 10),
              AppCard(
                onTap: state.busy ? null : () => showBankAccountSheet(context),
                child: Row(
                  children: [
                    const AppIcon('bank', size: 30, color: AppColors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            balance?.bank == null
                                ? 'Thêm tài khoản ngân hàng'
                                : '${balance!.bank!.name} · ${balance.bank!.masked}',
                            style: appText(size: 13, weight: FontWeight.w700),
                          ),
                          if (balance?.bank != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              balance!.bank!.holder,
                              style: appText(
                                size: 11,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const AppIcon('chevron-right', size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (block == null)
                const Notice(
                  'Yêu cầu được quản trị viên xử lý',
                  detail:
                      'Tiền được chuyển thủ công vào tài khoản ngân hàng sau khi yêu cầu được duyệt. Chỉ có một yêu cầu đang chờ.',
                  peach: true,
                ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Notice(state.error!, peach: true),
              ],
              if (state.notice != null) ...[
                const SizedBox(height: 12),
                Notice(state.notice!, icon: 'check', success: true),
              ],
              if (block != null) ...[
                const SizedBox(height: 12),
                Notice(
                  block.title,
                  detail: block.detail,
                  icon: balance?.pendingWithdrawal == true ? 'clock' : 'info',
                  peach: true,
                ),
                TextButton(
                  onPressed: state.busy ? null : cubit.refresh,
                  child: const Text('Kiểm tra trạng thái'),
                ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                'Gửi yêu cầu rút tiền',
                key: const Key('request-withdrawal'),
                busy: state.busy,
                onPressed: state.busy || block != null
                    ? null
                    : () async {
                        final amount = int.tryParse(_amount.text) ?? 0;
                        _form.currentState?.validate();
                        if (amount < 1 || amount > balance!.withdrawable) {
                          return;
                        }
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Xác nhận rút tiền'),
                            content: Text(
                              'Rút ${formatVnd(amount)} về ${balance.bank!.name} ${balance.bank!.masked}?'
                              '${balance.debt > 0 ? '\n\nTrả nợ hoa hồng: ${formatVnd(balance.debt)}. Tổng trừ từ ví thu nhập: ${formatVnd(amount + balance.debt)}.' : ''}'
                              '\n\nQuản trị viên duyệt và chuyển khoản thủ công.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Quay lại'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Gửi yêu cầu'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await cubit.withdraw(amount);
                        }
                      },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: SectionTitle('Yêu cầu gần nhất', size: 16),
                  ),
                  TextButton(
                    onPressed: () => openWalletPage(
                      context,
                      const WalletTransactionsScreen(withdrawals: true),
                    ),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
              if (balance?.pendingWithdrawal == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Notice(
                    'Đang chờ xử lý ${formatVnd(balance!.pendingAmount)}',
                    icon: 'clock',
                    peach: true,
                  ),
                ),
              if (state.withdrawals?.items.isEmpty == true)
                const Text('Chưa có yêu cầu rút tiền.'),
              for (final tx
                  in state.withdrawals?.items.take(3) ?? <WalletTransaction>[])
                WalletTransactionTile(tx),
            ],
          ),
        ),
      );
    },
  );
}

({String title, String detail})? _withdrawalBlock(WalletState state) {
  final balance = state.balance;
  if (balance == null) {
    return (
      title: 'Chưa tải được số dư',
      detail: 'Tải lại ví để kiểm tra điều kiện rút tiền.',
    );
  }
  if (state.withdrawalUncertain) {
    return (
      title: 'Cần kiểm tra kết quả yêu cầu trước',
      detail: 'Tải lại trạng thái trước khi gửi thêm yêu cầu.',
    );
  }
  if (!balance.active) {
    return (
      title: 'Ví đang bị khóa',
      detail: 'Liên hệ hỗ trợ để kiểm tra trạng thái ví.',
    );
  }
  if (balance.pendingWithdrawal) {
    return (
      title: 'Đang chờ xử lý ${formatVnd(balance.pendingAmount)}',
      detail:
          'Bạn chỉ có thể gửi yêu cầu mới sau khi quản trị viên duyệt hoặc từ chối yêu cầu hiện tại.',
    );
  }
  if (balance.bank == null) {
    return (
      title: 'Chưa có tài khoản nhận tiền',
      detail: 'Thêm tài khoản ngân hàng ở trên để gửi yêu cầu rút.',
    );
  }
  if (balance.withdrawable < 1) {
    return (
      title: 'Chưa đủ số dư để rút',
      detail:
          'Hệ thống tính hạn mức từ số dư, nợ hoa hồng, yêu cầu đang chờ và chuyến đang chạy. Khi đang chạy chuyến, ký quỹ chưa thể rút.',
    );
  }
  return null;
}
