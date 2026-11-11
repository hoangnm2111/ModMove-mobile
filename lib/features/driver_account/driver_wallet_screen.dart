import '../../core/widgets/notice_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../driver_trip/data/driver_api.dart';
import '../driver_trip/presentation/widgets/trip_components.dart';
import 'driver_account_models.dart';
import 'load_view.dart';

/// Ví tài xế: ký quỹ, thu nhập, tài khoản ngân hàng, nạp tiền (PayOS), rút tiền, lịch sử.
class DriverWalletScreen extends StatelessWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: const AppHeader('Ví tài xế'),
      body: Column(
        children: [
          const TabBar(
            labelColor: AppColors.orange,
            indicatorColor: AppColors.orange,
            tabs: [Tab(text: 'Tổng quan'), Tab(text: 'Giao dịch'), Tab(text: 'Rút tiền')],
          ),
          const Expanded(
            child: TabBarView(children: [_Overview(), _Transactions(), _Withdrawals()]),
          ),
        ],
      ),
    ),
  );
}

void _snack(BuildContext context, String text) => showNotice(context, text);

class _Overview extends StatefulWidget {
  const _Overview();
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  String _period = 'Today';
  int _epoch = 0;

  static const _periods = {'Today': 'Hôm nay', 'Week': 'Tuần', 'Month': 'Tháng', 'All': 'Tất cả'};

  Future<int?> _askAmount(String title, String hint, {String? note}) => showDialog<int>(
    context: context,
    builder: (_) => _AmountDialog(title: title, hint: hint, note: note),
  );

  Future<void> _topUp(DriverWallet wallet) async {
    final api = context.read<DriverApi>();
    // BE: khi ký quỹ thấp hơn mức tối thiểu phải nạp ít nhất phần thiếu.
    final least = wallet.missingDeposit > 0 ? wallet.missingDeposit : 1;
    final amount = await _askAmount(
      'Nạp ký quỹ',
      wallet.missingDeposit > 0 ? 'Số tiền (tối thiểu ${vnd(least)})' : 'Số tiền nạp',
      note: 'Thanh toán qua PayOS, ký quỹ được cộng sau khi thanh toán thành công.',
    );
    if (amount == null || !mounted) return;
    if (amount < least) return _snack(context, 'Nạp tối thiểu ${vnd(least)}.');
    try {
      final j = await api.topUp(amount);
      final uri = Uri.parse(j['checkoutUrl'] as String);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
        _snack(context, 'Không mở được trang thanh toán.');
      }
    } catch (e) {
      if (mounted) _snack(context, errorText(e));
    }
  }

  Future<void> _withdraw(DriverWallet wallet) async {
    final api = context.read<DriverApi>();
    if (wallet.bank == null) return _snack(context, 'Hãy thêm tài khoản ngân hàng trước khi rút tiền.');
    final amount = await _askAmount(
      'Rút tiền từ ví',
      'Tối đa ${vnd(wallet.maxWithdrawable)}',
      note: wallet.hasActiveOrder
          ? 'Đang có đơn chạy: chỉ rút được phần thu nhập. Quản trị viên chuyển khoản thủ công.'
          : 'Trừ ví thu nhập trước, thiếu thì trừ tiếp ví ký quỹ. Quản trị viên chuyển khoản thủ công.',
    );
    if (amount == null || !mounted) return;
    if (amount <= 0 || amount > wallet.maxWithdrawable) return _snack(context, 'Số tiền rút phải từ 1đ đến ${vnd(wallet.maxWithdrawable)}.');
    try {
      await api.withdraw(amount);
      if (!mounted) return;
      _snack(context, 'Đã gửi yêu cầu rút ${vnd(amount)}. Chờ Admin xử lý.');
      setState(() => _epoch++);
    } catch (e) {
      if (mounted) _snack(context, errorText(e));
    }
  }

  Future<void> _editBank(DriverWallet wallet) async {
    final api = context.read<DriverApi>();
    final bank = await showDialog<BankAccount>(
      context: context,
      builder: (_) => _BankDialog(initial: wallet.bank),
    );
    if (bank == null || !mounted) return;
    try {
      await api.saveBankAccount(bankName: bank.bankName, number: bank.number, holder: bank.holder);
      if (!mounted) return;
      _snack(context, 'Đã lưu tài khoản ngân hàng.');
      setState(() => _epoch++);
    } catch (e) {
      if (mounted) _snack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverApi>();
    return LoadView<DriverWallet>(
      key: ValueKey('wallet-$_epoch'),
      load: () async => DriverWallet.fromJson(await api.wallet()),
      builder: (context, wallet, reload) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _balance('shield', 'Ký quỹ', wallet.deposit),
              const SizedBox(width: 8),
              _balance('wallet', 'Thu nhập', wallet.earnings),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _balance('coins', 'Tổng số dư', wallet.total),
              const SizedBox(width: 8),
              _balance('withdraw', 'Rút tối đa', wallet.maxWithdrawable),
            ],
          ),
          if (wallet.missingDeposit > 0) ...[
            const SizedBox(height: 8),
            Notice(
              'Ký quỹ thiếu ${vnd(wallet.missingDeposit)} so với mức tối thiểu ${vnd(wallet.requiredDeposit)}: bạn chưa nhận được đơn mới. Hãy nạp ít nhất phần thiếu.',
              icon: 'warning',
              peach: true,
            ),
          ],
          if (wallet.pendingWithdrawal > 0) ...[
            const SizedBox(height: 8),
            Notice('Đang chờ duyệt rút ${vnd(wallet.pendingWithdrawal)}.', icon: 'clock'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton('Nạp ký quỹ', icon: 'wallet-plus', onPressed: wallet.status == 'Active' ? () => _topUp(wallet) : null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: wallet.status == 'Active' && wallet.pendingWithdrawal == 0 ? () => _withdraw(wallet) : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  icon: const AppIcon('withdraw', color: AppColors.orange),
                  label: const Text('Rút tiền'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            onTap: () => _editBank(wallet),
            child: Row(
              children: [
                const AppIcon('bank', color: AppColors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: wallet.bank == null
                      ? Text('Thêm tài khoản ngân hàng nhận tiền', style: appText(size: 13))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(wallet.bank!.bankName, style: appText(size: 14, weight: FontWeight.w700)),
                            Text('${wallet.bank!.number} · ${wallet.bank!.holder}', style: appText(size: 12, color: AppColors.secondary)),
                          ],
                        ),
                ),
                const AppIcon('chevron-right', size: 16),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Thu nhập', size: 16),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _periods.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _period == entry.key,
                  onSelected: (_) => setState(() => _period = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<EarningsSummary>(
            key: ValueKey('earn-$_period-$_epoch'),
            future: api.earnings(_period, pageSize: 1).then(EarningsSummary.fromJson),
            builder: (context, snapshot) {
              if (snapshot.hasError) return TripError(errorText(snapshot.error!));
              final e = snapshot.data;
              if (e == null) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
              return AppCard(
                child: Column(
                  children: [
                    _row('Số chuyến hoàn thành', '${e.completedTrips}'),
                    _row('Tổng cước', vnd(e.gross)),
                    _row('Hoa hồng nền tảng', '-${vnd(e.commission)}'),
                    const Divider(),
                    _row('Thực nhận', vnd(e.net), bold: true),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _balance(String icon, String label, int amount) => Expanded(
    child: AppCard(
      child: Row(
        children: [
          AppIcon(icon, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: appText(size: 11, color: AppColors.secondary)),
                Text(vnd(amount), style: appText(size: 15, weight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: appText(size: 13, color: AppColors.secondary))),
        Text(value, style: appText(size: 13, weight: bold ? FontWeight.w800 : FontWeight.w600)),
      ],
    ),
  );
}

class _Transactions extends StatelessWidget {
  const _Transactions();
  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverApi>();
    return PagedListView<WalletTx>(
      emptyText: 'Chưa có giao dịch nào.',
      fetch: (page) async {
        final p = PageOf.fromJson(await api.walletTransactions(page: page), WalletTx.fromJson);
        return PageResult(p.items, p.hasNext);
      },
      itemBuilder: (_, tx) => AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.label, style: appText(size: 14, weight: FontWeight.w700)),
                  Text(
                    [if (tx.orderCode != null) '#${tx.orderCode}', if (tx.createdAt != null) dateTime(tx.createdAt!)].join(' · '),
                    style: appText(size: 11, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.transfer ? '' : (tx.debit ? '-' : '+')}${vnd(tx.amount)}',
                  style: appText(size: 14, weight: FontWeight.w800, color: tx.transfer ? AppColors.secondary : (tx.debit ? AppColors.red : AppColors.green)),
                ),
                Text('Số dư ${vnd(tx.balanceAfter)}', style: appText(size: 10, color: AppColors.muted)),
                if (tx.earningsAmount != 0 || tx.depositAmount != 0)
                  Text('Thu nhập ${vnd(tx.earningsAmount)} • Ký quỹ ${vnd(tx.depositAmount)}', style: appText(size: 10, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Withdrawals extends StatelessWidget {
  const _Withdrawals();
  static const _status = {'Pending': 'Chờ duyệt', 'Completed': 'Đã chuyển', 'Rejected': 'Từ chối', 'Failed': 'Thất bại'};
  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverApi>();
    return PagedListView<Withdrawal>(
      emptyText: 'Chưa có yêu cầu rút tiền.',
      fetch: (page) async {
        final p = PageOf.fromJson(await api.withdrawals(page: page), Withdrawal.fromJson);
        return PageResult(p.items, p.hasNext);
      },
      itemBuilder: (_, w) => AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vnd(w.amount), style: appText(size: 15, weight: FontWeight.w800)),
                  Text('Từ thu nhập ${vnd(w.earningsAmount)} • Từ ký quỹ ${vnd(w.depositAmount)}', style: appText(size: 11, color: AppColors.secondary)),
                  Text(
                    [if (w.bank != null) '${w.bank!.bankName} ${w.bank!.number}', if (w.createdAt != null) dateTime(w.createdAt!)].join(' · '),
                    style: appText(size: 11, color: AppColors.secondary),
                  ),
                  if (w.reference != null) Text('Mã tham chiếu: ${w.reference}', style: appText(size: 11, color: AppColors.secondary)),
                ],
              ),
            ),
            Text(_status[w.status] ?? w.status, style: appText(size: 12, weight: FontWeight.w700, color: w.status == 'Completed' ? AppColors.green : AppColors.orange)),
          ],
        ),
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, required this.hint, this.note});
  final String title, hint;
  final String? note;
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: widget.hint, suffixText: 'đ'),
        ),
        if (widget.note != null) ...[
          const SizedBox(height: 8),
          Text(widget.note!, style: appText(size: 11, color: AppColors.secondary)),
        ],
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      TextButton(
        onPressed: () => Navigator.pop(context, int.tryParse(_text.text.replaceAll(RegExp(r'[^0-9]'), ''))),
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

class _BankDialog extends StatefulWidget {
  const _BankDialog({this.initial});
  final BankAccount? initial;
  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  late final _bank = TextEditingController(text: widget.initial?.bankName);
  late final _number = TextEditingController(text: widget.initial?.number);
  late final _holder = TextEditingController(text: widget.initial?.holder);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Không được để trống.' : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tài khoản ngân hàng'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(controller: _bank, decoration: const InputDecoration(labelText: 'Ngân hàng'), validator: _required),
          TextFormField(controller: _number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tài khoản'), validator: _required),
          TextFormField(controller: _holder, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Chủ tài khoản'), validator: _required),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, BankAccount(_bank.text.trim(), _number.text.trim(), _holder.text.trim()));
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
