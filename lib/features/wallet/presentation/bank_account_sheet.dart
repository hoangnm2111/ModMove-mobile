import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/driver_wallet_repository.dart';
import 'wallet_cubit.dart';

Future<void> showBankAccountSheet(BuildContext context) {
  final cubit = context.read<WalletCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: BankAccountSheet(initial: cubit.state.balance?.bank),
    ),
  );
}

class BankAccountSheet extends StatefulWidget {
  const BankAccountSheet({super.key, this.initial});
  final DriverBankAccount? initial;
  @override
  State<BankAccountSheet> createState() => _BankAccountSheetState();
}

class _BankAccountSheetState extends State<BankAccountSheet> {
  final _form = GlobalKey<FormState>();
  late final _bank = TextEditingController(text: widget.initial?.name);
  late final _number = TextEditingController(text: widget.initial?.number);
  late final _holder = TextEditingController(text: widget.initial?.holder);
  bool _submitted = false;

  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitted = true);
    final saved = await context.read<WalletCubit>().saveBank(
      DriverBankAccount(
        _bank.text.trim(),
        _number.text.trim(),
        _holder.text.trim(),
      ),
    );
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<WalletCubit, WalletState>(
    builder: (context, state) {
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return PopScope(
        canPop: !state.busy,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .92 - keyboard,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.peach,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const AppIcon('bank', color: AppColors.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tài khoản ngân hàng',
                            style: appText(size: 18, weight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          onPressed: state.busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 22),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tiền rút sẽ được chuyển vào tài khoản này.',
                              style: appText(
                                size: 13,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _label('Ngân hàng'),
                            TextFormField(
                              key: const Key('bank-name'),
                              controller: _bank,
                              enabled: !state.busy,
                              maxLength: 100,
                              textInputAction: TextInputAction.next,
                              decoration: _input('Ví dụ: Vietcombank'),
                              validator: (v) => v?.trim().isNotEmpty == true
                                  ? null
                                  : 'Nhập tên ngân hàng.',
                            ),
                            const SizedBox(height: 18),
                            _label('Số tài khoản'),
                            TextFormField(
                              key: const Key('bank-number'),
                              controller: _number,
                              enabled: !state.busy,
                              maxLength: 30,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp('[0-9A-Za-z]'),
                                ),
                              ],
                              decoration: _input('Nhập số tài khoản ngân hàng'),
                              validator: (v) =>
                                  RegExp(
                                    r'^[0-9A-Za-z]{6,30}$',
                                  ).hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Số tài khoản cần 6–30 chữ hoặc số.',
                            ),
                            const SizedBox(height: 18),
                            _label('Tên chủ tài khoản'),
                            TextFormField(
                              key: const Key('bank-holder'),
                              controller: _holder,
                              enabled: !state.busy,
                              maxLength: 100,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!state.busy) _save();
                              },
                              decoration: _input(
                                'Nhập tên như đăng ký tại ngân hàng',
                              ),
                              validator: (v) => v?.trim().isNotEmpty == true
                                  ? null
                                  : 'Nhập tên chủ tài khoản.',
                            ),
                            const SizedBox(height: 18),
                            const Notice(
                              'Kiểm tra thông tin trước khi lưu',
                              detail:
                                  'Số tài khoản và tên chủ tài khoản cần khớp thông tin ngân hàng.',
                              icon: 'shield',
                            ),
                            if (_submitted && state.error != null) ...[
                              const SizedBox(height: 12),
                              Notice(state.error!, peach: true),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: PrimaryButton(
                      'Lưu tài khoản',
                      key: const Key('save-bank-account'),
                      busy: state.busy,
                      onPressed: state.busy ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _label(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(value, style: appText(size: 13, weight: FontWeight.w600)),
  );
  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: appText(size: 12, color: AppColors.secondary),
    counterText: '',
    filled: true,
    fillColor: const Color(0xFFF7F8FA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );
}
