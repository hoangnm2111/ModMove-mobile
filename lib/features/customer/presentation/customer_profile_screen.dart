import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';
import 'customer_cubits.dart';
import 'customer_widgets.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => ResourceCubit<CustomerProfile>(
          context.read<CustomerRepository>().profile,
        )..load(),
      ),
      BlocProvider(create: (_) => ActionCubit()),
    ],
    child: Builder(
      builder: (context) =>
          BlocBuilder<
            ResourceCubit<CustomerProfile>,
            ResourceState<CustomerProfile>
          >(
            builder: (context, s) => RefreshIndicator(
              onRefresh: context.read<ResourceCubit<CustomerProfile>>().load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  sectionTitle('Tài khoản của tôi'),
                  if (s.busy) const LinearProgressIndicator(),
                  if (s.error != null) CustomerNotice(s.error!, error: true),
                  if (s.data != null) ...[
                    CustomerCard(
                      color: AppColors.peach,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.orange,
                            child: Text(
                              s.data!.name.isEmpty
                                  ? 'M'
                                  : s.data!.name.substring(0, 1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.data!.name,
                                  style: appText(
                                    size: 19,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(s.data!.email, style: appText(size: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  s.data!.verified
                                      ? 'Email đã xác minh'
                                      : 'Email chưa xác minh',
                                  style: appText(
                                    size: 12,
                                    color: AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Chỉnh sửa thông tin'),
                      subtitle: Text(s.data!.phone),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => BlocProvider(
                              create: (_) => ActionCubit(),
                              child: _EditProfile(s.data!),
                            ),
                          ),
                        );
                        if (context.mounted) {
                          context.read<ResourceCubit<CustomerProfile>>().load();
                        }
                      },
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider(
                          create: (_) => ActionCubit(),
                          child: const _ChangePassword(),
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Sự cố & hỗ trợ'),
                    onTap: () => Navigator.pushNamed(context, '/incidents'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_return_outlined),
                    title: const Text('Khiếu nại & hoàn tiền'),
                    onTap: () => Navigator.pushNamed(context, '/refunds'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: const Text('Đánh giá của tôi'),
                    onTap: () => Navigator.pushNamed(context, '/ratings'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: const Text('Cài đặt thông báo'),
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Đăng xuất'),
                    onTap: () async {
                      if (await confirmCustomerAction(
                            context,
                            'Đăng xuất?',
                            'Bạn có thể đăng nhập lại để theo dõi đơn hàng.',
                          ) &&
                          context.mounted) {
                        context.read<AuthCubit>().logout();
                      }
                    },
                  ),
                  BlocBuilder<ActionCubit, ActionState>(
                    builder: (context, a) => Column(
                      children: [
                        if (a.error != null)
                          CustomerNotice(a.error!, error: true),
                        TextButton.icon(
                          icon: const Icon(Icons.person_remove_outlined),
                          label: Text(a.busy ? 'Đang xử lý…' : 'Xóa tài khoản'),
                          onPressed: a.busy
                              ? null
                              : () async {
                                  final confirmed = await confirmCustomerAction(
                                    context,
                                    'Xóa tài khoản?',
                                    'Tài khoản sẽ bị ngừng hoạt động. Bạn không thể xóa khi còn đơn đang xử lý. Chỉ xác nhận nếu bạn muốn ngừng sử dụng tài khoản này.',
                                    action: 'Xóa tài khoản',
                                  );
                                  if (!confirmed || !context.mounted) return;
                                  final auth = context.read<AuthCubit>();
                                  final ok = await context
                                      .read<ActionCubit>()
                                      .run(
                                        context
                                            .read<CustomerRepository>()
                                            .deleteAccount,
                                      );
                                  if (ok) await auth.logout();
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    ),
  );
}

class _EditProfile extends StatefulWidget {
  const _EditProfile(this.profile);
  final CustomerProfile profile;
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final name = TextEditingController(text: widget.profile.name),
      phone = TextEditingController(text: widget.profile.phone);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ActionCubit, ActionState>(
    builder: (context, s) => Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: name,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nhập họ tên' : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (v) =>
                    RegExp(
                      r'^(0[0-9]{9}|\+84[0-9]{9})$',
                    ).hasMatch((v ?? '').trim())
                    ? null
                    : 'Số điện thoại chưa hợp lệ',
              ),
              const SizedBox(height: 18),
              detailRow('Email đăng nhập', widget.profile.email),
              const SizedBox(height: 18),
              if (s.error != null) CustomerNotice(s.error!, error: true),
              FilledButton(
                onPressed: s.busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        final ok = await context.read<ActionCubit>().run(
                          () => context
                              .read<CustomerRepository>()
                              .updateProfile(name.text, phone.text),
                        );
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                child: Text(s.busy ? 'Đang lưu…' : 'Lưu thay đổi'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChangePassword extends StatefulWidget {
  const _ChangePassword();
  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ActionCubit, ActionState>(
    builder: (context, s) => Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in [
                (current, 'Mật khẩu hiện tại'),
                (next, 'Mật khẩu mới'),
                (confirm, 'Nhập lại mật khẩu mới'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextFormField(
                    controller: entry.$1,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nhập mật khẩu'
                        : entry.$1 == confirm && v != next.text
                        ? 'Mật khẩu không khớp'
                        : null,
                  ),
                ),
              const CustomerNotice(
                'Mật khẩu mới 8–100 ký tự, có ít nhất một chữ cái và một chữ số. Sau khi đổi, bạn cần đăng nhập lại trên các thiết bị.',
              ),
              if (s.error != null) CustomerNotice(s.error!, error: true),
              FilledButton(
                onPressed: s.busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        final ok = await context.read<ActionCubit>().run(
                          () => context
                              .read<CustomerRepository>()
                              .changePassword(current.text, next.text),
                        );
                        if (ok && context.mounted) {
                          await context.read<AuthCubit>().logout(
                            notice:
                                'Đã đổi mật khẩu. Hãy đăng nhập bằng mật khẩu mới.',
                          );
                        }
                      },
                child: Text(s.busy ? 'Đang lưu…' : 'Đổi mật khẩu'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
