import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/account_input.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/customer_visuals.dart';
import 'auth_cubit.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _role = 'Customer';
  bool _showPassword = false;
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
    String label,
    String icon, {
    bool secret = false,
    TextInputType? keyboard,
    String? hint,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: appText(size: 14, weight: FontWeight.w700),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(label),
          controller: c,
          enabled: !context.read<AuthCubit>().state.busy,
          obscureText: secret && !_showPassword,
          keyboardType: keyboard,
          autocorrect: !secret,
          enableSuggestions: !secret,
          textInputAction: TextInputAction.next,
          autofillHints: c == _email
              ? const [AutofillHints.email]
              : c == _password
              ? const [AutofillHints.password]
              : null,
          decoration: InputDecoration(
            hintText: hint ?? label,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(14),
              child: AppIcon(icon, size: 22, color: AppColors.secondary),
            ),
            suffixIcon: secret
                ? IconButton(
                    tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: AppIcon(
                      _showPassword ? 'eye-off' : 'eye',
                      size: 22,
                      color: AppColors.secondary,
                    ),
                  )
                : null,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập $label';
            if (c == _email &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
              return 'Email chưa hợp lệ';
            }
            if (c == _phone && !isVietnamesePhone(v)) {
              return 'Số điện thoại chưa hợp lệ';
            }
            if (c == _otp && !RegExp(r'^[0-9]{6}$').hasMatch(v.trim())) {
              return 'Nhập mã OTP 6 chữ số';
            }
            if (c == _password &&
                [
                  AuthStage.register,
                  AuthStage.reset,
                ].contains(context.read<AuthCubit>().state.stage) &&
                !isValidNewPassword(v)) {
              return 'Mật khẩu 8–100 ký tự, gồm chữ và số';
            }
            return null;
          },
        ),
      ],
    ),
  );

  void _submit(AuthCubit auth, AuthStage stage) {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    switch (stage) {
      case AuthStage.forgot:
        auth.forgot(_email.text);
      case AuthStage.reset:
        auth.reset(_email.text, _otp.text, _password.text);
      case AuthStage.verify:
        auth.verify(_email.text, _otp.text, _password.text);
      case AuthStage.register:
        auth.register(
          _name.text,
          _phone.text,
          _email.text,
          _password.text,
          role: _role,
        );
      default:
        auth.login(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthCubit, AuthState>(
    builder: (context, state) {
      final auth = context.read<AuthCubit>();
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
      final login = state.stage == AuthStage.login,
          register = state.stage == AuthStage.register,
          verify = state.stage == AuthStage.verify,
          forgot = state.stage == AuthStage.forgot,
          reset = state.stage == AuthStage.reset;
      final title = login
          ? 'Chào mừng trở lại'
          : register
          ? 'Tạo tài khoản ModMove'
          : verify
          ? 'Xác minh email'
          : forgot
          ? 'Quên mật khẩu?'
          : 'Tạo mật khẩu mới';
      final subtitle = login
          ? 'Đăng nhập để đặt chuyến và theo dõi đơn hàng.'
          : register
          ? 'Gửi hàng thuận tiện. Kết nối mọi hành trình.'
          : verify
          ? 'Nhập mã OTP được gửi đến email của bạn.'
          : forgot
          ? 'Nhập email đã đăng ký để nhận mã đặt lại mật khẩu.'
          : 'Xác minh mã OTP và thiết lập mật khẩu mới.';
      final action = forgot
          ? 'Gửi mã xác minh'
          : reset
          ? 'Lưu mật khẩu mới'
          : verify
          ? 'Xác minh và đăng nhập'
          : register
          ? 'Tạo tài khoản'
          : 'Đăng nhập';
      return PopScope(
        canPop: login,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !state.busy) auth.show(AuthStage.login);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: login
              ? null
              : AppBar(
                  backgroundColor: Colors.white,
                  leading: IconButton(
                    tooltip: 'Quay lại đăng nhập',
                    onPressed: state.busy
                        ? null
                        : () => auth.show(AuthStage.login),
                    icon: const AppIcon('arrow-left'),
                  ),
                  title: Text(
                    verify
                        ? 'Xác minh email'
                        : forgot
                        ? 'Quên mật khẩu'
                        : reset
                        ? 'Đặt lại mật khẩu'
                        : 'Đăng ký',
                  ),
                ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (login) ...[
                            CustomerBrand(
                              trailing: TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () => auth.show(AuthStage.guest),
                                child: const Text('Khám phá ›'),
                              ),
                            ),
                            const SizedBox(height: 22),
                            const DeliveryBanner(height: 144),
                            const SizedBox(height: 26),
                          ] else ...[
                            if (register)
                              const DeliveryBanner(height: 100)
                            else
                              CustomerIllustration(
                                verify || forgot ? 'email' : 'security',
                                height: 100,
                              ),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            title,
                            style: appText(
                              size: login ? 28 : 25,
                              weight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            style: appText(
                              size: 15,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (register) ...[
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'Customer',
                                  icon: AppIcon('box', size: 19),
                                  label: Text('Khách hàng'),
                                ),
                                ButtonSegment(
                                  value: 'Driver',
                                  icon: AppIcon('van', size: 19),
                                  label: Text('Tài xế'),
                                ),
                              ],
                              selected: {_role},
                              onSelectionChanged: state.busy
                                  ? null
                                  : (v) => setState(() => _role = v.first),
                            ),
                            const SizedBox(height: 22),
                            _field(_name, 'Họ và tên', 'user'),
                            _field(
                              _phone,
                              'Số điện thoại',
                              'phone',
                              keyboard: TextInputType.phone,
                            ),
                          ],
                          _field(
                            _email,
                            'Email',
                            'mail',
                            keyboard: TextInputType.emailAddress,
                            hint: 'Nhập email của bạn',
                          ),
                          if (verify || reset)
                            _field(
                              _otp,
                              'Mã OTP',
                              'shield',
                              keyboard: TextInputType.number,
                              hint: 'Nhập mã OTP 6 số',
                            ),
                          if (!forgot)
                            _field(
                              _password,
                              reset
                                  ? 'Mật khẩu mới'
                                  : verify
                                  ? 'Mật khẩu đã đăng ký'
                                  : 'Mật khẩu',
                              'lock',
                              secret: true,
                              hint: reset
                                  ? 'Nhập mật khẩu mới'
                                  : 'Nhập mật khẩu',
                              trailing: login
                                  ? TextButton(
                                      onPressed: state.busy
                                          ? null
                                          : () => auth.show(AuthStage.forgot),
                                      child: const Text('Quên mật khẩu?'),
                                    )
                                  : null,
                            ),
                          if (register || reset)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                '8–100 ký tự, gồm chữ và số',
                                style: appText(
                                  size: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          if (state.error != null || state.notice != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: state.error != null
                                    ? AppColors.redBg
                                    : AppColors.greenBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                state.error ?? state.notice!,
                                style: appText(
                                  size: 13,
                                  color: state.error != null
                                      ? AppColors.red
                                      : AppColors.green,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          FilledButton(
                            onPressed: state.busy
                                ? null
                                : () => _submit(auth, state.stage),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (state.busy) ...[
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Flexible(
                                  child: Text(
                                    state.busy ? 'Đang xử lý…' : action,
                                  ),
                                ),
                                if (!state.busy && login) ...[
                                  const SizedBox(width: 12),
                                  const AppIcon(
                                    'arrow-right',
                                    color: Colors.white,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (verify || reset)
                            OutlinedButton(
                              onPressed: state.busy
                                  ? null
                                  : () => verify
                                        ? auth.resend(_email.text)
                                        : auth.forgot(_email.text),
                              child: Text(
                                verify
                                    ? 'Gửi lại OTP'
                                    : 'Gửi lại mã đặt mật khẩu',
                              ),
                            ),
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () => auth.show(
                                    login
                                        ? AuthStage.register
                                        : AuthStage.login,
                                  ),
                            child: Text(
                              login
                                  ? 'Chưa có tài khoản? Đăng ký ngay'
                                  : 'Đã có tài khoản? Đăng nhập',
                            ),
                          ),
                          if (login) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () => auth.show(AuthStage.verify),
                              child: const Text(
                                'Chưa xác minh email? Xác minh ngay',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
