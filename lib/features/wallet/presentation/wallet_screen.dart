import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/formatting/currency.dart';
import 'wallet_cubit.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with WidgetsBindingObserver {
  final _amount = TextEditingController(text: '50000');
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
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<WalletCubit, WalletState>(
    builder: (context, state) {
      final cubit = context.read<WalletCubit>();
      return Scaffold(
        appBar: AppHeader(
          'Ví tài xế',
          actions: [
            IconButton(
              onPressed: state.busy ? null : cubit.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                color: AppColors.peach,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Số dư ký quỹ'),
                    const SizedBox(height: 8),
                    Text(
                      state.balance == null
                          ? '—'
                          : formatVnd(state.balance!.deposit),
                      style: appText(size: 30, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ví thu nhập: ${state.balance == null ? '—' : formatVnd(state.balance!.earnings)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle('Nạp tiền ký quỹ'),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VND)',
                  helperText: 'Tối thiểu 50.000đ',
                ),
              ),
              const SizedBox(height: 16),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Notice(state.error!, peach: true),
                ),
              PrimaryButton(
                'Tạo thanh toán PayOS',
                busy: state.busy,
                onPressed: state.busy
                    ? null
                    : () => cubit.topUp(int.tryParse(_amount.text.trim()) ?? 0),
              ),
              if (state.payment != null) ...[
                const SizedBox(height: 16),
                Notice(
                  'Đang chờ thanh toán ${formatVnd(state.payment!.amount)}',
                  detail:
                      'Liên kết hết hạn lúc ${state.payment!.expiresAt.toLocal().toString().substring(0, 16)}. Số dư chỉ cập nhật sau xác nhận từ PayOS.',
                ),
                TextButton(
                  onPressed: () async {
                    if (!DateTime.now().isBefore(state.payment!.expiresAt)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Liên kết đã hết hạn. Hãy tạo thanh toán mới.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      if (!await launchUrl(
                        state.payment!.checkoutUrl,
                        mode: LaunchMode.externalApplication,
                      )) {
                        throw StateError('launch');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chưa mở được trang thanh toán. Vui lòng thử lại.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Mở thanh toán PayOS'),
                ),
              ],
              const SizedBox(height: 24),
              const Notice(
                'Rút tiền và thống kê thu nhập đang chờ API.',
                icon: 'info',
              ),
            ],
          ),
        ),
      );
    },
  );
}
