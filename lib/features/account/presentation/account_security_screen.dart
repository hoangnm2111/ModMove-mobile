import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/domain/account_input.dart';
import '../../auth/presentation/auth_cubit.dart';
import 'account_security_cubit.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});
  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(),
      _next = TextEditingController(),
      _confirm = TextEditingController();
  final _visible = <TextEditingController>{};
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    var acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Xóa tài khoản tài xế?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tài khoản sẽ ngừng hoạt động. Bạn cần hoàn tất chuyến, xử lý các yêu cầu rút tiền và đưa số dư ví về 0 trước khi xóa.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acknowledged,
                  onChanged: (v) => update(() => acknowledged = v == true),
                  title: const Text('Tôi hiểu và muốn xóa tài khoản'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Giữ tài khoản'),
            ),
            FilledButton(
              onPressed: acknowledged
                  ? () => Navigator.pop(dialog, true)
                  : null,
              child: const Text('Xác nhận xóa'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AccountSecurityCubit>().deleteAccount();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<AccountSecurityCubit, AccountSecurityState>(
    listener: (context, state) {
      if (state.completed != null) {
        context.read<AuthCubit>().logout(notice: state.completed);
      }
    },
    builder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Bảo mật và tài khoản')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Đổi mật khẩu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mật khẩu mới gồm 8–100 ký tự, có chữ và số. Sau khi đổi, bạn cần đăng nhập lại.',
            ),
            const SizedBox(height: 20),
            for (final entry in [
              (_current, 'Mật khẩu hiện tại'),
              (_next, 'Mật khẩu mới'),
              (_confirm, 'Nhập lại mật khẩu mới'),
            ]) ...[
              TextFormField(
                controller: entry.$1,
                enabled: !state.busy,
                obscureText: !_visible.contains(entry.$1),
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: entry.$2,
                  suffixIcon: IconButton(
                    tooltip: _visible.contains(entry.$1)
                        ? 'Ẩn mật khẩu'
                        : 'Hiện mật khẩu',
                    onPressed: () => setState(
                      () => _visible.contains(entry.$1)
                          ? _visible.remove(entry.$1)
                          : _visible.add(entry.$1),
                    ),
                    icon: Icon(
                      _visible.contains(entry.$1)
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Nhập mật khẩu'
                    : entry.$1 == _next &&
                          (!isValidNewPassword(v) || v == _current.text)
                    ? 'Mật khẩu mới phải khác mật khẩu cũ, 8–100 ký tự gồm chữ và số'
                    : entry.$1 == _confirm && v != _next.text
                    ? 'Mật khẩu không khớp'
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: state.busy
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        context.read<AccountSecurityCubit>().changePassword(
                          _current.text,
                          _next.text,
                          _confirm.text,
                        );
                      }
                    },
              child: Text(state.busy ? 'Đang xử lý…' : 'Đổi mật khẩu'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Kiểm tra ví và yêu cầu rút tiền'),
              trailing: const Icon(Icons.chevron_right),
              onTap: state.busy
                  ? null
                  : () => Navigator.pushNamed(context, '/wallet'),
            ),
            OutlinedButton.icon(
              onPressed: state.busy ? null : _delete,
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Xóa tài khoản'),
            ),
          ],
        ),
      ),
    ),
  );
}
