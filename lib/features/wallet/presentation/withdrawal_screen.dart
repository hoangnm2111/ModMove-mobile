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

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});
  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amount = TextEditingController();
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
      return Scaffold(
        appBar: const AppHeader('Rút thu nhập'),
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
                      'Số tiền khả dụng sau khi trừ nợ phí nền tảng.',
                      style: appText(size: 12, color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              if (balance != null && balance.debt > 0) ...[
                const SizedBox(height: 10),
                Notice(
                  'Nợ phí nền tảng: ${formatVnd(balance.debt)}',
                  detail:
                      'Khoản nợ được trừ từ thu nhập khi gửi yêu cầu rút thành công.',
                  peach: true,
                ),
              ],
              const SizedBox(height: 20),
              const SectionTitle('Số tiền cần rút', size: 16),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('withdraw-amount'),
                      controller: _amount,
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
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: balance == null
                        ? null
                        : () => _amount.text = '${balance.withdrawable}',
                    child: const Text('Toàn bộ'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Không có mức rút tối thiểu. Không vượt số tiền có thể rút.',
                style: appText(size: 11, color: AppColors.secondary),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Nhận tiền về tài khoản', size: 16),
              const SizedBox(height: 10),
              AppCard(
                onTap: state.busy
                    ? null
                    : () async {
                        final bank = await showDialog<DriverBankAccount>(
                          context: context,
                          builder: (_) => _BankDialog(balance?.bank),
                        );
                        if (bank != null && context.mounted) {
                          await cubit.saveBank(bank);
                        }
                      },
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
                Notice(state.notice!, icon: 'check'),
              ],
              if (state.withdrawalUncertain) ...[
                const SizedBox(height: 12),
                const Notice(
                  'Cần kiểm tra lại kết quả',
                  detail: 'Tải lại ví trước khi gửi thêm yêu cầu.',
                  peach: true,
                ),
                TextButton(
                  onPressed: state.busy ? null : cubit.refresh,
                  child: const Text('Tải lại ví'),
                ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                'Gửi yêu cầu rút tiền',
                key: const Key('request-withdrawal'),
                busy: state.busy,
                onPressed:
                    state.busy ||
                        state.withdrawalUncertain ||
                        balance == null ||
                        !balance.active ||
                        balance.pendingWithdrawal
                    ? null
                    : () async {
                        final amount = int.tryParse(_amount.text) ?? 0;
                        if (amount <= 0 || amount > balance.withdrawable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nhập số tiền hợp lệ, không vượt số tiền có thể rút.',
                              ),
                            ),
                          );
                          return;
                        }
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Xác nhận rút thu nhập'),
                            content: Text(
                              'Rút ${formatVnd(amount)} về ${balance.bank?.name ?? 'tài khoản ngân hàng'} ${balance.bank?.masked ?? ''}?',
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

class _BankDialog extends StatefulWidget {
  const _BankDialog(this.bank);
  final DriverBankAccount? bank;
  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bank?.name);
  late final _number = TextEditingController(text: widget.bank?.number);
  late final _holder = TextEditingController(text: widget.bank?.holder);
  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tài khoản ngân hàng'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Tên ngân hàng'),
              validator: (v) =>
                  v?.trim().isNotEmpty == true ? null : 'Nhập tên ngân hàng',
            ),
            TextFormField(
              controller: _number,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Số tài khoản'),
              validator: (v) =>
                  RegExp(r'^[0-9A-Za-z]{6,30}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Nhập 6–30 chữ hoặc số',
            ),
            TextFormField(
              controller: _holder,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Tên chủ tài khoản'),
              validator: (v) => v?.trim().isNotEmpty == true
                  ? null
                  : 'Nhập tên chủ tài khoản',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              DriverBankAccount(
                _name.text.trim(),
                _number.text.trim(),
                _holder.text.trim(),
              ),
            );
          }
        },
        child: const Text('Lưu tài khoản'),
      ),
    ],
  );
}
