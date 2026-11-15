import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import 'auth_cubit.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _role = 'Customer';
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
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập $label';
        if (c == _email &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
          return 'Email chưa hợp lệ';
        }
        if (c == _phone &&
            !RegExp(r'^(0[0-9]{9}|\+84[0-9]{9})$').hasMatch(v.trim())) {
          return 'Số điện thoại chưa hợp lệ';
        }
        if (c == _otp && !RegExp(r'^[0-9]{6}$').hasMatch(v.trim())) {
          return 'Nhập mã OTP 6 chữ số';
        }
        final stage = context.read<AuthCubit>().state.stage;
        if (c == _password &&
            [AuthStage.register, AuthStage.reset].contains(stage) &&
            (v.length < 8 ||
                v.length > 100 ||
                !RegExp('[a-zA-Z]').hasMatch(v) ||
                !RegExp('[0-9]').hasMatch(v))) {
          return 'Mật khẩu 8–100 ký tự, gồm chữ và số';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) {
      final auth = context.read<AuthCubit>();
      final register = state.stage == AuthStage.register,
          verify = state.stage == AuthStage.verify,
          forgot = state.stage == AuthStage.forgot,
          reset = state.stage == AuthStage.reset;
      if (state.stage == AuthStage.restoring) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo(),
                SizedBox(height: 24),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        );
      }
      final title = forgot
          ? 'Quên mật khẩu'
          : reset
          ? 'Đặt lại mật khẩu'
          : verify
          ? 'Xác minh email'
          : register
          ? 'Tạo tài khoản ModMove'
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
                      const Center(child: AppLogo()),
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
                      const Text(
                        'Giao hàng thuận tiện. Kết nối mọi hành trình.',
                      ),
                      const SizedBox(height: 24),
                      if (register) ...[
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'Customer',
                              label: Text('Khách hàng'),
                              icon: Icon(Icons.inventory_2_outlined),
                            ),
                            ButtonSegment(
                              value: 'Driver',
                              label: Text('Tài xế'),
                              icon: Icon(Icons.local_shipping_outlined),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: state.busy
                              ? null
                              : (v) => setState(() => _role = v.first),
                        ),
                        const SizedBox(height: 20),
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
                      if (!forgot)
                        _field(
                          _password,
                          reset
                              ? 'Mật khẩu mới'
                              : verify
                              ? 'Mật khẩu đã đăng ký'
                              : 'Mật khẩu',
                          secret: true,
                        ),
                      if (register)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Mật khẩu 8–100 ký tự, gồm ít nhất một chữ cái và một chữ số.',
                          ),
                        ),
                      if (verify || reset)
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
                                if (forgot) {
                                  auth.forgot(_email.text);
                                } else if (reset) {
                                  auth.reset(
                                    _email.text,
                                    _otp.text,
                                    _password.text,
                                  );
                                } else if (verify) {
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
                                    role: _role,
                                  );
                                } else {
                                  auth.login(_email.text, _password.text);
                                }
                              },
                        child: Text(
                          state.busy
                              ? 'Đang xử lý…'
                              : forgot
                              ? 'Gửi mã xác minh'
                              : reset
                              ? 'Lưu mật khẩu mới'
                              : verify
                              ? 'Xác minh và đăng nhập'
                              : register
                              ? 'Tạo tài khoản'
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
                      if (reset)
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => auth.forgot(_email.text),
                          child: const Text('Gửi lại mã đặt mật khẩu'),
                        ),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => auth.show(
                                register || verify || forgot || reset
                                    ? AuthStage.login
                                    : AuthStage.register,
                              ),
                        child: Text(
                          register || verify || forgot || reset
                              ? 'Đã có tài khoản? Đăng nhập'
                              : 'Chưa có tài khoản? Đăng ký',
                        ),
                      ),
                      if (state.stage == AuthStage.login) ...[
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => auth.show(AuthStage.verify),
                          child: const Text('Xác minh email đã đăng ký'),
                        ),
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => auth.show(AuthStage.forgot),
                          child: const Text('Quên mật khẩu?'),
                        ),
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () => auth.show(AuthStage.guest),
                          child: const Text('Khám phá dịch vụ'),
                        ),
                      ],
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
