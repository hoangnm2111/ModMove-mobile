import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/logout_button.dart';
import '../data/customer_api.dart';
import '../domain/entities/customer_models.dart';
import '../domain/order_rules.dart';
import 'widgets/customer_widgets.dart';

/// Hồ sơ & bảo mật (UC-CUS-04..07), chính sách (UC-GST-04), hỗ trợ (UC-GST-05), đăng xuất.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Profile> _profile = context.read<CustomerApi>().profile();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tài khoản'), automaticallyImplyLeading: false),
    body: FutureBuilder<Profile>(
      future: _profile,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return ErrorView(
            errorText(snap.error!),
            onRetry: () => setState(() {
              _profile = context.read<CustomerApi>().profile();
            }),
          );
        }
        final p = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.orange,
                    child: Text(
                      p.fullName.isEmpty ? 'K' : p.fullName[0],
                      style: appText(size: 20, weight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.fullName, style: appText(size: 16, weight: FontWeight.w800)),
                        Text(p.email, style: appText(size: 12.5, color: AppColors.secondary)),
                        Text(p.phoneNumber, style: appText(size: 12.5, color: AppColors.secondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _tile('user', 'Sửa hồ sơ', () async {
              if (await _sheet(context, _EditProfile(profile: p)) && mounted) {
                setState(() {
                  _profile = context.read<CustomerApi>().profile();
                });
              }
            }),
            _tile('lock', 'Đổi mật khẩu', () => _sheet(context, const _ChangePassword())),
            _tile('bell', 'Thông báo', () => Navigator.pushNamed(context, '/notifications')),
            _tile('shield', 'Chính sách & điều khoản', () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _PoliciesScreen()))),
            _tile('headphones', 'Gửi yêu cầu hỗ trợ', () => showSupportSheet(context, name: p.fullName, contact: p.email)),
            _tile('warning', 'Xoá tài khoản', () => _deleteAccount(context), color: AppColors.red),
            const SizedBox(height: 16),
            const LogoutButton(),
          ],
        );
      },
    ),
  );

  Widget _tile(String icon, String label, VoidCallback onTap, {Color color = AppColors.ink}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AppIcon(icon, color: color == AppColors.ink ? AppColors.secondary : color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: appText(weight: FontWeight.w600, color: color),
            ),
          ),
          const AppIcon('chevron-right', color: AppColors.muted, size: 20),
        ],
      ),
    ),
  );

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xoá tài khoản'),
        content: const Text('Tài khoản sẽ bị vô hiệu hoá, lịch sử đơn được giữ lại. Không xoá được khi còn đơn hoặc yêu cầu hoàn tiền đang mở.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xoá tài khoản'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final auth = context.read<AuthCubit>();
    if (await runAction(context, () => context.read<CustomerApi>().deleteAccount(), success: 'Tài khoản đã được xoá.')) await auth.expire();
  }
}

Future<bool> _sheet(BuildContext context, Widget child) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(child: child),
      ),
    ) ??
    false;

class _EditProfile extends StatefulWidget {
  const _EditProfile({required this.profile});
  final Profile profile;
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phoneNumber);
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Sửa hồ sơ'),
      const SizedBox(height: 12),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Họ và tên'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Số điện thoại'),
      ),
      const SizedBox(height: 16),
      PrimaryButton(
        'Lưu',
        busy: _busy,
        onPressed: () async {
          if (_name.text.trim().isEmpty || !InputRules.phone(_phone.text)) return showSnack(context, 'Nhập họ tên và số điện thoại hợp lệ.', error: true);
          setState(() => _busy = true);
          final ok = await runAction(context, () => context.read<CustomerApi>().updateProfile(_name.text.trim(), _phone.text.trim()), success: 'Đã lưu hồ sơ.');
          if (!context.mounted) return;
          setState(() => _busy = false);
          if (ok) Navigator.pop(context, true);
        },
      ),
    ],
  );
}

class _ChangePassword extends StatefulWidget {
  const _ChangePassword();
  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Đổi mật khẩu'),
      const SizedBox(height: 6),
      Text('Sau khi đổi, mọi thiết bị sẽ phải đăng nhập lại.', style: appText(size: 12, color: AppColors.secondary)),
      const SizedBox(height: 12),
      TextField(
        controller: _current,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _next,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Mật khẩu mới (8–100 ký tự)'),
      ),
      const SizedBox(height: 16),
      PrimaryButton(
        'Đổi mật khẩu',
        busy: _busy,
        onPressed: () async {
          if (!InputRules.password(_next.text)) return showSnack(context, 'Mật khẩu mới từ 8 đến 100 ký tự.', error: true);
          setState(() => _busy = true);
          final auth = context.read<AuthCubit>();
          final ok = await runAction(context, () => context.read<CustomerApi>().changePassword(_current.text, _next.text), success: 'Đã đổi mật khẩu. Vui lòng đăng nhập lại.');
          if (!context.mounted) return;
          setState(() => _busy = false);
          if (ok) {
            Navigator.pop(context, true);
            await auth.expire(); // server đã thu hồi mọi phiên
          }
        },
      ),
    ],
  );
}

class _PoliciesScreen extends StatelessWidget {
  const _PoliciesScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader('Chính sách & điều khoản'),
    body: FutureBuilder<List<LookupItem>>(
      future: context.read<CustomerApi>().policies(),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(errorText(snap.error!)));
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            for (final p in snap.data!)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: ExpansionTile(
                  title: Text(p.name, style: appText(weight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [Text(p.description ?? 'Chưa có nội dung.', style: appText(size: 13.5, color: AppColors.secondary))],
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// UC-GST-05 – POST /public/SupportRequests.
Future<void> showSupportSheet(BuildContext context, {String name = '', String contact = ''}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (c) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
    child: _SupportForm(name: name, contact: contact, api: context.read<CustomerApi>()),
  ),
);

class _SupportForm extends StatefulWidget {
  const _SupportForm({required this.name, required this.contact, required this.api});
  final String name, contact;
  final CustomerApi api;
  @override
  State<_SupportForm> createState() => _SupportFormState();
}

class _SupportFormState extends State<_SupportForm> {
  late final _name = TextEditingController(text: widget.name);
  late final _contact = TextEditingController(text: widget.contact);
  final _content = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    for (final c in [_name, _contact, _content]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Gửi yêu cầu hỗ trợ'),
      const SizedBox(height: 12),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Họ và tên'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _contact,
        decoration: const InputDecoration(labelText: 'Email hoặc số điện thoại'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _content,
        maxLines: 4,
        maxLength: 2000,
        decoration: const InputDecoration(labelText: 'Nội dung cần hỗ trợ'),
      ),
      const SizedBox(height: 8),
      PrimaryButton(
        'Gửi',
        busy: _busy,
        onPressed: () async {
          if ([_name, _contact, _content].any((c) => c.text.trim().isEmpty)) return showSnack(context, 'Nhập đủ họ tên, liên hệ và nội dung.', error: true);
          setState(() => _busy = true);
          final ok = await runAction(context, () => widget.api.supportRequest(_name.text.trim(), _contact.text.trim(), _content.text.trim()), success: 'Đã gửi yêu cầu. ModMove sẽ liên hệ lại.');
          if (!context.mounted) return;
          setState(() => _busy = false);
          if (ok) Navigator.pop(context);
        },
      ),
    ],
  );
}
