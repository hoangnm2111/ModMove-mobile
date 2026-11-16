import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../customer/domain/order_rules.dart';
import '../../customer/presentation/widgets/customer_widgets.dart';
import 'auth_cubit.dart';

/// SCR-02/03/04 – Đăng nhập, đăng ký khách (UC-GST-01), quên mật khẩu (UC-CUS-02).
/// Trả về [Session] khi đăng nhập thành công (Navigator.pop).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.startWithRegister = false, this.startAsDriver = false});
  final bool startWithRegister;

  /// Mở sẵn tab đăng ký với vai trò tài xế (từ mục "Trở thành tài xế" ở trang chủ).
  final bool startAsDriver;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _register = widget.startWithRegister || widget.startAsDriver;
  late bool _asDriver = widget.startAsDriver;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false, _hide = true;

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    if (!InputRules.email(_email.text) || _password.text.isEmpty) {
      return showSnack(context, 'Nhập email và mật khẩu.', error: true);
    }
    setState(() => _busy = true);
    try {
      final session = await context.read<AuthCubit>().login(_email.text, _password.text);
      if (mounted) Navigator.pop<Session>(context, session);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e), error: true);
      // Tài khoản cũ chưa xác minh email → mở bước OTP luôn (rẽ nhánh theo mã lỗi, không theo câu chữ).
      if (e is ApiException && e.code == 'EMAIL_NOT_VERIFIED') {
        await _otp(purpose: 'Register');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kiểm tra form đăng ký; trả về false và báo lỗi nếu còn thiếu.
  bool _registerFormValid() {
    final error = _name.text.trim().isEmpty
        ? 'Nhập họ tên.'
        : !InputRules.phone(_phone.text)
        ? 'Số điện thoại không hợp lệ.'
        : !InputRules.email(_email.text)
        ? 'Email không hợp lệ.'
        : !InputRules.password(_password.text)
        ? 'Mật khẩu từ 8 đến 100 ký tự.'
        : null;
    if (error != null) showSnack(context, error, error: true);
    return error == null;
  }

  Future<void> _doRegister() async {
    if (!_registerFormValid()) return;
    setState(() => _busy = true);
    // BE chỉ gửi OTP ở bước này; tài khoản được tạo khi xác minh thành công.
    final ok = await runAction(
      context,
      () => context.read<AuthCubit>().api.register(fullName: _name.text, phone: _phone.text, email: _email.text, password: _password.text, asDriver: _asDriver),
      success: 'Đã gửi mã OTP tới email. Nhập mã để hoàn tất đăng ký.',
    );
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) await _otp(purpose: 'Register');
  }

  /// Đã đăng ký và có mã nhưng lỡ đóng bước OTP: mở lại mà không gửi thêm mã (BE giới hạn số lần gửi).
  Future<void> _haveCode() async {
    if (!InputRules.email(_email.text) || !InputRules.password(_password.text)) {
      return showSnack(context, 'Nhập email và mật khẩu đã dùng khi đăng ký.', error: true);
    }
    await _otp(purpose: 'Register');
  }

  /// Nhập OTP 6 số (GB-25): xác minh email rồi tự đăng nhập.
  Future<void> _otp({required String purpose}) async {
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OtpSheet(email: _email.text, password: _password.text, purpose: purpose, api: context.read<AuthCubit>()),
    );
    if (verified == true && mounted) await _login();
  }

  Future<void> _forgot() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ForgotSheet(initialEmail: _email.text, auth: context.read<AuthCubit>()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppHeader(_register ? (_asDriver ? 'Đăng ký tài xế' : 'Đăng ký khách hàng') : 'Đăng nhập'),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              const BrandLogo(size: 40),
              const SizedBox(width: 10),
              Text('ModMove', style: appText(size: 30, weight: FontWeight.w800, color: AppColors.orange, spacing: -1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _register ? (_asDriver ? 'Tạo tài khoản tài xế, sau đó nộp hồ sơ để được duyệt.' : 'Tạo tài khoản để đặt xe và theo dõi đơn hàng.') : 'Dùng chung cho khách hàng và tài xế.',
            style: appText(color: AppColors.secondary),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Đăng nhập')),
              ButtonSegment(value: true, label: Text('Đăng ký')),
            ],
            selected: {_register},
            onSelectionChanged: (s) => setState(() => _register = s.first),
          ),
          if (_register) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('register-role'),
              segments: const [
                ButtonSegment(value: false, label: Text('Khách hàng'), icon: Icon(Icons.person_outline)),
                ButtonSegment(value: true, label: Text('Tài xế'), icon: Icon(Icons.local_shipping_outlined)),
              ],
              selected: {_asDriver},
              onSelectionChanged: (s) => setState(() => _asDriver = s.first),
            ),
          ],
          const SizedBox(height: 18),
          if (_register) ...[
            _field(_name, 'Họ và tên', icon: Icons.person_outline),
            _field(_phone, 'Số điện thoại', icon: Icons.phone_outlined, type: TextInputType.phone),
          ],
          _field(_email, 'Email', icon: Icons.mail_outline, type: TextInputType.emailAddress),
          TextField(
            controller: _password,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hide ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            onSubmitted: (_) => _register ? _doRegister() : _login(),
          ),
          if (!_register)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _forgot, child: const Text('Quên mật khẩu?')),
            )
          else
            const SizedBox(height: 16),
          PrimaryButton(_register ? 'Đăng ký' : 'Đăng nhập', busy: _busy, onPressed: _register ? _doRegister : _login),
          if (_register)
            Align(
              child: TextButton(key: const Key('register-have-code'), onPressed: _busy ? null : _haveCode, child: const Text('Tôi đã có mã OTP')),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );

  Widget _field(TextEditingController c, String label, {IconData? icon, TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
    ),
  );
}

class _OtpSheet extends StatefulWidget {
  const _OtpSheet({required this.email, required this.password, required this.purpose, required this.api});
  final String email, password, purpose;
  final AuthCubit api;
  @override
  State<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends State<_OtpSheet> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) return showSnack(context, 'Mã OTP gồm 6 chữ số.', error: true);
    setState(() => _busy = true);
    final ok = await runAction(context, () => widget.api.api.verifyEmail(widget.email, _code.text, widget.password), success: 'Đã xác minh email.');
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Xác minh email'),
        const SizedBox(height: 6),
        Text('Nhập mã 6 số đã gửi tới ${widget.email}.', style: appText(color: AppColors.secondary)),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: appText(size: 22, weight: FontWeight.w700, spacing: 6),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
        ),
        const SizedBox(height: 12),
        PrimaryButton('Xác minh', busy: _busy, onPressed: _verify),
        TextButton(
          onPressed: () => runAction(context, () => widget.api.api.resendOtp(widget.email, widget.purpose), success: 'Nếu email hợp lệ, mã mới đã được gửi.'),
          child: const Text('Gửi lại mã'),
        ),
      ],
    ),
  );
}

class _ForgotSheet extends StatefulWidget {
  const _ForgotSheet({required this.initialEmail, required this.auth});
  final String initialEmail;
  final AuthCubit auth;
  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false, _busy = false;

  @override
  void dispose() {
    for (final c in [_email, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!InputRules.email(_email.text)) return showSnack(context, 'Email không hợp lệ.', error: true);
    setState(() => _busy = true);
    final ok = await runAction(context, () => widget.auth.api.forgotPassword(_email.text), success: 'Nếu email tồn tại, mã OTP đã được gửi.');
    if (mounted) setState(() => (_busy = false, _sent = ok || _sent));
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 6) return showSnack(context, 'Mã OTP gồm 6 chữ số.', error: true);
    if (!InputRules.password(_password.text)) return showSnack(context, 'Mật khẩu từ 8 đến 100 ký tự.', error: true);
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => widget.auth.api.resetPassword(_email.text, _code.text, _password.text),
      success: 'Đã đặt lại mật khẩu. Hãy đăng nhập.',
    );
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Quên mật khẩu'),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        if (_sent) ...[
          const SizedBox(height: 12),
          TextField(controller: _code, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLength: 6, decoration: const InputDecoration(labelText: 'Mã OTP', counterText: '')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới')),
        ],
        const SizedBox(height: 14),
        PrimaryButton(_sent ? 'Đặt lại mật khẩu' : 'Gửi mã OTP', busy: _busy, onPressed: _sent ? _reset : _send),
        if (_sent) TextButton(onPressed: _send, child: const Text('Gửi lại mã')),
      ],
    ),
  );
}
