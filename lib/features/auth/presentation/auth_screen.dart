import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_cubit.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController(),
      _phone = TextEditingController(),
      _otp = TextEditingController();
  @override
  void dispose() {
    for (final c in [_email, _password, _name, _phone, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      obscureText: secret,
      keyboardType: keyboard,
      autocorrect: !secret,
      enableSuggestions: !secret,
      decoration: InputDecoration(labelText: label),
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Vui lòng nhập $label' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) {
      final auth = context.read<AuthCubit>();
      final register = state.stage == AuthStage.register,
          verify = state.stage == AuthStage.verify;
      if (state.stage == AuthStage.restoring) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final title = verify
          ? 'Xác minh email'
          : register
          ? 'Đăng ký tài xế'
          : 'Chào mừng trở lại';
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: AppColors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ModMove',
                        textAlign: TextAlign.center,
                        style: appText(size: 32, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        title,
                        style: appText(size: 24, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text('Đồng hành cùng tài xế trên mỗi chuyến đi'),
                      const SizedBox(height: 24),
                      if (register) ...[
                        _field(_name, 'Họ và tên'),
                        _field(
                          _phone,
                          'Số điện thoại',
                          keyboard: TextInputType.phone,
                        ),
                      ],
                      _field(
                        _email,
                        'Email',
                        keyboard: TextInputType.emailAddress,
                      ),
                      _field(
                        _password,
                        verify ? 'Mật khẩu đã đăng ký' : 'Mật khẩu',
                        secret: true,
                      ),
                      if (register)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                    'Mật khẩu 8–100 ký tự, gồm ít nhất một chữ cái và một chữ số.',
                          ),
                        ),
                      if (verify)
                        _field(_otp, 'Mã OTP', keyboard: TextInputType.number),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            state.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (state.notice != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(state.notice!),
                        ),
                      FilledButton(
                        onPressed: state.busy
                            ? null
                            : () {
                                if (!_form.currentState!.validate()) return;
                                if (verify) {
                                  auth.verify(
                                    _email.text,
                                    _otp.text,
                                    _password.text,
                                  );
                                } else if (register) {
                                  auth.register(
                                    _name.text,
                                    _phone.text,
                                    _email.text,
                                    _password.text,
                                  );
                                } else {
                                  auth.login(_email.text, _password.text);
                                }
                              },
                        child: Text(
                          state.busy
                              ? 'Đang xử lý…'
                              : verify
                              ? 'Xác minh và đăng nhập'
                              : register
                              ? 'Tạo tài khoản tài xế'
                              : 'Đăng nhập',
                        ),
                      ),
                      if (verify)
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => auth.resend(_email.text),
                          child: const Text('Gửi lại OTP'),
                        ),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => auth.show(
                                register || verify
                                    ? AuthStage.login
                                    : AuthStage.register,
                              ),
                        child: Text(
                          register || verify
                              ? 'Đã có tài khoản? Đăng nhập'
                              : 'Chưa có tài khoản? Đăng ký tài xế',
                        ),
                      ),
                      if (!register && !verify)
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => auth.show(AuthStage.verify),
                          child: const Text('Xác minh email đã đăng ký'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
