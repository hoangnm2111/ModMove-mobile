import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import 'wallet_cubit.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen>
    with WidgetsBindingObserver {
  final _amount = TextEditingController(text: '200000');
  Timer? _poll;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !_foreground ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      final cubit = context.read<WalletCubit>();
      if (cubit.state.payment != null && !cubit.state.paymentConfirmed) {
        cubit.refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) context.read<WalletCubit>().refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _amount.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<WalletCubit, WalletState>(
    builder: (context, state) {
      final cubit = context.read<WalletCubit>();
      final payment = state.payment;
      return Scaffold(
        appBar: const AppHeader('Nạp ký quỹ'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('Chọn số tiền nạp', size: 16),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final amount in [50000, 100000, 200000, 500000])
                  ActionChip(
                    label: Text(formatVnd(amount)),
                    onPressed: state.busy
                        ? null
                        : () => _amount.text = '$amount',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('deposit-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: const InputDecoration(
                labelText: 'Số tiền (VND)',
                helperText: 'Nạp tối thiểu 50.000đ',
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              payment == null
                  ? 'Tạo mã thanh toán PayOS'
                  : 'Tạo mã thanh toán mới',
              busy: state.busy,
              onPressed: state.busy
                  ? null
                  : () => cubit.topUp(int.tryParse(_amount.text) ?? 0),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Notice(
                'Chưa xử lý được thanh toán',
                detail: state.error!,
                icon: 'warning',
                peach: true,
              ),
              if (state.errorReference != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'Mã hỗ trợ: ${state.errorReference}',
                  style: appText(size: 11, color: AppColors.secondary),
                ),
              ],
            ],
            if (payment != null) ...[
              const SizedBox(height: 18),
              BlocProvider(
                key: ValueKey('${payment.id}:${payment.expiresAt}'),
                create: (_) => PaymentCountdownCubit(payment.expiresAt),
                child: BlocBuilder<PaymentCountdownCubit, int>(
                  builder: (context, seconds) => AppCard(
                    color: AppColors.peach,
                    child: Column(
                      children: [
                        const SectionTitle('Thanh toán qua PayOS', size: 16),
                        const SizedBox(height: 12),
                        Text(
                          formatVnd(payment.amount),
                          style: appText(
                            size: 30,
                            color: AppColors.orange,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (state.paymentConfirmed)
                          const Notice(
                            'Nạp ký quỹ thành công',
                            detail: 'Giao dịch đã được hệ thống xác nhận.',
                            icon: 'check',
                          )
                        else if (seconds == 0)
                          const Notice(
                            'Mã thanh toán đã hết hạn',
                            detail:
                                'Tạo mã mới nếu bạn chưa chuyển tiền. Nếu đã chuyển, hãy kiểm tra giao dịch.',
                            peach: true,
                          )
                        else ...[
                          if (payment.qrCode?.isNotEmpty == true)
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(8),
                              child: QrImageView(
                                data: payment.qrCode!,
                                size: 220,
                                backgroundColor: Colors.white,
                                semanticsLabel: 'Mã QR PayOS nạp ký quỹ',
                                errorStateBuilder: (_, _) => const Text(
                                  'Không hiển thị được QR. Hãy mở trang PayOS bên dưới.',
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            'Còn ${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                            style: appText(
                              color: AppColors.orange,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              // Check again on tap; never open an expired checkout.
                              if (!DateTime.now().isBefore(payment.expiresAt)) {
                                return;
                              }
                              try {
                                if (!await launchUrl(
                                  payment.checkoutUrl,
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  throw StateError('launch');
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Chưa mở được PayOS. Hãy thử lại.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const AppIcon('qr-code', size: 20),
                            label: const Text('Mở thanh toán PayOS'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Notice(
                'Số dư chỉ cập nhật sau khi PayOS xác nhận.',
                detail:
                    'Mở trang thanh toán hoặc bấm kiểm tra không tự cộng tiền vào ví.',
                icon: 'info',
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                'Kiểm tra thanh toán',
                onPressed: state.busy ? null : cubit.refresh,
              ),
            ],
          ],
        ),
      );
    },
  );
}

class PaymentCountdownCubit extends Cubit<int> {
  PaymentCountdownCubit(this.expiresAt) : super(_remaining(expiresAt)) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _remaining(expiresAt);
      if (next != state) emit(next);
    });
  }
  final DateTime expiresAt;
  late final Timer _timer;
  static int _remaining(DateTime expiry) =>
      ((expiry.difference(DateTime.now()).inMilliseconds / 1000).ceil()).clamp(
        0,
        86400,
      );
  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }
}
