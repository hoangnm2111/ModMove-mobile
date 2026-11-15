import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';
import 'customer_cubits.dart';
import 'customer_support_screen.dart';
import 'customer_widgets.dart';

class CustomerRefundScreen extends StatefulWidget {
  const CustomerRefundScreen({super.key, required this.id});
  final int id;
  @override
  State<CustomerRefundScreen> createState() => _CustomerRefundScreenState();
}

class _CustomerRefundScreenState extends State<CustomerRefundScreen> {
  late final ResourceCubit<Refund> data;
  final action = ActionCubit();
  @override
  void initState() {
    super.initState();
    data = ResourceCubit(
      () => context.read<CustomerRepository>().refund(widget.id),
    )..load();
  }

  @override
  void dispose() {
    data.close();
    action.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: data),
      BlocProvider.value(value: action),
    ],
    child: Scaffold(
      appBar: AppBar(title: const Text('Chi tiết yêu cầu')),
      body: BlocBuilder<ResourceCubit<Refund>, ResourceState<Refund>>(
        builder: (context, s) => BlocBuilder<ActionCubit, ActionState>(
          builder: (context, a) => RefreshIndicator(
            onRefresh: data.load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (s.busy || a.busy) const LinearProgressIndicator(),
                if (s.error != null) ...[
                  CustomerNotice(s.error!, error: true),
                  TextButton(
                    onPressed: data.load,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (a.error != null) CustomerNotice(a.error!, error: true),
                if (s.data case final r?) ...[
                  CustomerCard(
                    color: AppColors.peach,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(r.status),
                        const SizedBox(height: 14),
                        Text(
                          r.orderCode,
                          style: appText(size: 22, weight: FontWeight.w700),
                        ),
                        detailRow('Loại yêu cầu', statusLabel(r.source)),
                        detailRow('Ngày gửi', dateLabel(r.created)),
                        detailRow('Số tiền yêu cầu', money(r.amount)),
                        if (r.approved != null)
                          detailRow(
                            'Được duyệt',
                            money(r.approved!),
                            strong: true,
                          ),
                      ],
                    ),
                  ),
                  sectionTitle('Nội dung yêu cầu'),
                  Text(r.reason),
                  const SizedBox(height: 14),
                  PhotoStrip(r.photos),
                  if (r.decision.isNotEmpty) ...[
                    sectionTitle('Kết quả xử lý'),
                    CustomerNotice(r.decision),
                  ],
                  if (r.failure.isNotEmpty)
                    CustomerNotice(
                      'Chuyển tiền chưa thành công: ${r.failure}',
                      error: true,
                    ),
                  if (r.reference.isNotEmpty)
                    detailRow('Mã giao dịch ngân hàng', r.reference),
                  if (r.bank.isNotEmpty) ...[
                    sectionTitle('Tài khoản nhận tiền'),
                    CustomerCard(child: Text(r.bank)),
                  ],
                  if (r.needsBank)
                    const CustomerNotice(
                      'Bổ sung tài khoản ngân hàng để nhận khoản hoàn tiền.',
                    ),
                  if (r.question.isNotEmpty) ...[
                    sectionTitle('Yêu cầu bổ sung'),
                    CustomerNotice(r.question),
                    if (r.reply.isNotEmpty)
                      CustomerCard(child: Text('Bạn đã trả lời: ${r.reply}')),
                  ],
                  if (r.waitingReply)
                    FilledButton(
                      onPressed: a.busy
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CustomerRefundReply(r),
                                ),
                              );
                              if (mounted) data.load();
                            },
                      child: const Text('Gửi thông tin bổ sung'),
                    ),
                  if (r.canSetBank)
                    OutlinedButton.icon(
                      onPressed: a.busy
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CustomerRefundBank(r),
                                ),
                              );
                              if (mounted) data.load();
                            },
                      icon: const Icon(Icons.account_balance_outlined),
                      label: Text(
                        r.needsBank
                            ? 'Bổ sung tài khoản nhận tiền'
                            : 'Cập nhật tài khoản nhận tiền',
                      ),
                    ),
                  if (r.canWithdraw)
                    TextButton(
                      onPressed: a.busy
                          ? null
                          : () async {
                              if (!await confirmCustomerAction(
                                    context,
                                    'Rút yêu cầu?',
                                    'Yêu cầu đang xét duyệt sẽ được rút lại.',
                                    action: 'Rút yêu cầu',
                                  ) ||
                                  !context.mounted) {
                                return;
                              }
                              final repo = context.read<CustomerRepository>();
                              if (await action.run(
                                () => repo.withdrawRefund(r.id),
                              )) {
                                await data.load();
                              }
                            },
                      child: const Text('Rút yêu cầu đang xét duyệt'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/order',
                      arguments: r.orderId,
                    ),
                    child: const Text('Xem đơn hàng'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class CustomerRefundReply extends StatefulWidget {
  const CustomerRefundReply(this.refund, {super.key});
  final Refund refund;
  @override
  State<CustomerRefundReply> createState() => _CustomerRefundReplyState();
}

class _CustomerRefundReplyState extends State<CustomerRefundReply> {
  final text = TextEditingController(),
      form = GlobalKey<FormState>(),
      action = ActionCubit();
  late final CustomerEvidenceCubit evidence;
  @override
  void initState() {
    super.initState();
    evidence = CustomerEvidenceCubit(context.read<CustomerRepository>());
  }

  @override
  void dispose() {
    text.dispose();
    action.close();
    evidence.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: action),
      BlocProvider.value(value: evidence),
    ],
    child: Scaffold(
      appBar: AppBar(title: const Text('Bổ sung thông tin')),
      body: BlocBuilder<ActionCubit, ActionState>(
        builder: (context, a) => BlocBuilder<CustomerEvidenceCubit, EvidenceState>(
          builder: (context, e) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomerNotice(widget.refund.question),
                  TextFormField(
                    controller: text,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung phản hồi',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Nhập phản hồi' : null,
                  ),
                  PhotoStrip(
                    e.photos,
                    remove: a.busy || e.busy ? null : evidence.remove,
                  ),
                  if (e.photos.length + widget.refund.photos.length < 5)
                    OutlinedButton.icon(
                      onPressed: a.busy || e.busy
                          ? null
                          : () async {
                              try {
                                final p = await pickCustomerPhoto(context);
                                if (p != null) {
                                  await evidence.add(
                                    p.name,
                                    await p.readAsBytes(),
                                  );
                                }
                              } catch (_) {
                                action.error(
                                  'Không chọn được ảnh. Vui lòng thử lại.',
                                );
                              }
                            },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Bổ sung ảnh'),
                    ),
                  Text(
                    'Tổng tối đa 5 ảnh cho yêu cầu này; hiện đã có ${widget.refund.photos.length} ảnh.',
                  ),
                  if (e.error != null) CustomerNotice(e.error!, error: true),
                  if (a.error != null) CustomerNotice(a.error!, error: true),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: a.busy || e.busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            final ok = await action.run(
                              () => context
                                  .read<CustomerRepository>()
                                  .replyRefund(
                                    widget.refund.id,
                                    text.text,
                                    e.photos,
                                  ),
                            );
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                    child: Text(a.busy ? 'Đang gửi…' : 'Gửi bổ sung'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CustomerRefundBank extends StatefulWidget {
  const CustomerRefundBank(this.refund, {super.key});
  final Refund refund;
  @override
  State<CustomerRefundBank> createState() => _CustomerRefundBankState();
}

class _CustomerRefundBankState extends State<CustomerRefundBank> {
  final number = TextEditingController(),
      holder = TextEditingController(),
      form = GlobalKey<FormState>(),
      action = ActionCubit();
  late final ResourceCubit<List<Choice>> banks;
  String? bank;
  bool suggested = false;
  @override
  void initState() {
    super.initState();
    banks = ResourceCubit(
      () => context.read<CustomerRepository>().choices('banks'),
    )..load();
  }

  @override
  void dispose() {
    number.dispose();
    holder.dispose();
    action.close();
    banks.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: action),
      BlocProvider.value(value: banks),
    ],
    child: Scaffold(
      appBar: AppBar(title: const Text('Tài khoản nhận hoàn tiền')),
      body: BlocBuilder<ResourceCubit<List<Choice>>, ResourceState<List<Choice>>>(
        builder: (context, b) => BlocBuilder<ActionCubit, ActionState>(
          builder: (context, a) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CustomerNotice(
                    'Kiểm tra ngân hàng, số tài khoản và tên chủ tài khoản trước khi lưu.',
                  ),
                  if (widget.refund.suggestedBank.isNotEmpty)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: suggested,
                      onChanged: a.busy
                          ? null
                          : (v) => setState(() => suggested = v),
                      title: const Text('Dùng tài khoản đã thanh toán PayOS'),
                      subtitle: Text(widget.refund.suggestedBank),
                    ),
                  if (b.busy) const LinearProgressIndicator(),
                  if (b.error != null) ...[
                    CustomerNotice(b.error!, error: true),
                    TextButton(
                      onPressed: banks.load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                  if (!suggested && b.data != null)
                    BankAccountFields(
                      banks: b.data!,
                      selected: bank,
                      onBank: (v) => setState(() => bank = v),
                      number: number,
                      holder: holder,
                    ),
                  if (a.error != null) CustomerNotice(a.error!, error: true),
                  FilledButton(
                    onPressed: a.busy || (!suggested && b.data == null)
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            final payout = PayoutAccount(
                              suggested: suggested,
                              bankCode: bank ?? '',
                              number: number.text,
                              holder: holder.text,
                            );
                            final ok = await action.run(
                              () => context
                                  .read<CustomerRepository>()
                                  .setPayout(widget.refund.id, payout),
                            );
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                    child: Text(a.busy ? 'Đang lưu…' : 'Lưu tài khoản'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
