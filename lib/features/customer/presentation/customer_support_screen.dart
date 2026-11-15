import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';
import '../domain/customer_places.dart';
import 'customer_cubits.dart';
import 'customer_widgets.dart';

class CustomerSupportList extends StatelessWidget {
  const CustomerSupportList({super.key, required this.refunds, this.orderId});
  final bool refunds;
  final int? orderId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(refunds ? 'Khiếu nại & hoàn tiền' : 'Sự cố & hỗ trợ'),
    ),
    body: refunds
        ? BlocProvider(
            create: (_) =>
                PagedCubit<Refund>(context.read<CustomerRepository>().refunds)
                  ..load(),
            child: BlocBuilder<PagedCubit<Refund>, ListState<Refund>>(
              builder: (context, s) => _supportList(
                context,
                s,
                context.read<PagedCubit<Refund>>(),
                s.items
                    .map(
                      (r) => CustomerCard(
                        padding: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const Icon(
                            Icons.assignment_return_outlined,
                            color: AppColors.orange,
                          ),
                          title: Text(
                            '${r.orderCode} · ${statusLabel(r.source)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              StatusPill(r.status),
                              const SizedBox(height: 8),
                              Text('Yêu cầu ${money(r.amount)}'),
                              if (r.waitingReply)
                                const Text(
                                  'Cần bạn bổ sung thông tin',
                                  style: TextStyle(color: AppColors.orange),
                                ),
                              if (r.needsBank)
                                const Text(
                                  'Cần tài khoản nhận tiền',
                                  style: TextStyle(color: AppColors.orange),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              '/refund',
                              arguments: r.id,
                            );
                            if (context.mounted) {
                              context.read<PagedCubit<Refund>>().load();
                            }
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          )
        : BlocProvider(
            create: (_) => PagedCubit<Incident>(
              (p) => context.read<CustomerRepository>().incidents(
                page: p,
                orderId: orderId,
              ),
            )..load(),
            child: BlocBuilder<PagedCubit<Incident>, ListState<Incident>>(
              builder: (context, s) => _supportList(
                context,
                s,
                context.read<PagedCubit<Incident>>(),
                s.items
                    .map(
                      (i) => CustomerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    i.orderCode,
                                    style: appText(weight: FontWeight.w700),
                                  ),
                                ),
                                StatusPill(i.status),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              statusLabel(i.type),
                              style: appText(weight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(i.description),
                            const SizedBox(height: 8),
                            Text(
                              '${i.byYou ? 'Bạn báo cáo' : 'Tài xế / điều phối báo cáo'} · ${dateLabel(i.created)}',
                              style: appText(
                                size: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                            if (i.photos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              PhotoStrip(i.photos),
                            ],
                            if (i.note.isNotEmpty) ...[
                              const Divider(),
                              Text('Phản hồi: ${i.note}'),
                            ],
                            if (i.decision.isNotEmpty)
                              Text('Hướng xử lý: ${_decision(i.decision)}'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/order',
                                    arguments: i.orderId,
                                  ),
                                  child: const Text('Xem đơn hàng'),
                                ),
                                OutlinedButton(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/incident-refund',
                                    arguments: i,
                                  ),
                                  child: const Text('Yêu cầu hoàn tiền'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
  );
  Widget _supportList<T>(
    BuildContext context,
    ListState<T> s,
    PagedCubit<T> cubit,
    List<Widget> items,
  ) => RefreshIndicator(
    onRefresh: () => cubit.load(),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CustomerNotice(
          refunds
              ? 'Theo dõi kết quả xét duyệt và khoản hoàn tiền của bạn.'
              : 'Mở một đơn đang giao để báo sự cố. Các phản hồi từ điều phối được hiển thị tại đây.',
        ),
        if (s.busy) const LinearProgressIndicator(),
        if (s.error != null) ...[
          CustomerNotice(s.error!, error: true),
          TextButton(
            onPressed: () => cubit.load(),
            child: const Text('Thử lại'),
          ),
        ],
        if (!s.busy && s.items.isEmpty)
          const CustomerCard(child: Text('Chưa có yêu cầu nào.')),
        ...items,
        if (s.hasNext)
          OutlinedButton(
            onPressed: s.busy ? null : () => cubit.load(more: true),
            child: const Text('Xem thêm'),
          ),
      ],
    ),
  );
  String _decision(String code) =>
      const {
        'ContinueTrip': 'Tiếp tục chuyến',
        'ReassignDriver': 'Đổi tài xế',
        'CancelOrder': 'Hủy đơn',
      }[code] ??
      code;
}

enum CustomerSupportKind { incident, complaint, refund }

class SupportFormData {
  const SupportFormData(this.order, this.reasons, this.banks);
  final OrderDetail order;
  final List<Choice> reasons, banks;
}

class CustomerSupportForm extends StatefulWidget {
  const CustomerSupportForm({
    super.key,
    required this.kind,
    required this.orderId,
    this.incidentId,
  });
  final CustomerSupportKind kind;
  final int orderId;
  final int? incidentId;
  @override
  State<CustomerSupportForm> createState() => _CustomerSupportFormState();
}

class _CustomerSupportFormState extends State<CustomerSupportForm> {
  late final ResourceCubit<SupportFormData> data;
  late final CustomerEvidenceCubit evidence;
  final action = ActionCubit();
  final form = GlobalKey<FormState>();
  final description = TextEditingController(), amount = TextEditingController();
  final account = TextEditingController(), holder = TextEditingController();
  late final ResourceCubit<GeoPosition> location;
  String type = 'Other';
  String? reason, bank;
  bool get incident => widget.kind == CustomerSupportKind.incident;
  @override
  void initState() {
    super.initState();
    final repo = context.read<CustomerRepository>();
    evidence = CustomerEvidenceCubit(repo);
    location = ResourceCubit(context.read<CustomerPlaces>().locate);
    data = ResourceCubit(() async {
      final order = await repo.order(widget.orderId);
      final reasons = widget.kind == CustomerSupportKind.complaint
          ? await repo.choices('complaint-reasons')
          : <Choice>[];
      final banks = incident ? <Choice>[] : await repo.choices('banks');
      return SupportFormData(order, reasons, banks);
    })..load();
  }

  @override
  void dispose() {
    data.close();
    evidence.close();
    action.close();
    location.close();
    for (final c in [description, amount, account, holder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> addPhoto() async {
    try {
      final photo = await pickCustomerPhoto(context);
      if (photo != null && mounted) {
        await evidence.add(photo.name, await photo.readAsBytes());
      }
    } catch (_) {
      action.error('Không mở được ảnh. Kiểm tra quyền camera/thư viện.');
    }
  }

  Future<void> submit(SupportFormData d) async {
    if (!form.currentState!.validate() || evidence.state.busy) return;
    final repo = context.read<CustomerRepository>();
    int? created;
    final ok = await action.run(() async {
      if (incident) {
        await repo.report(
          widget.orderId,
          type,
          description.text,
          evidence.state.photos,
          location.state.data,
        );
      } else {
        final payout = PayoutAccount(
          bankCode: bank!,
          number: account.text,
          holder: holder.text,
        );
        created = widget.kind == CustomerSupportKind.complaint
            ? await repo.complain(
                widget.orderId,
                reason!,
                description.text,
                evidence.state.photos,
                double.parse(amount.text),
                payout,
              )
            : await repo.requestRefund(
                widget.incidentId!,
                description.text,
                evidence.state.photos,
                double.parse(amount.text),
                payout,
              );
      }
    });
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi yêu cầu đến hệ thống.')),
    );
    if (created != null) {
      Navigator.pushReplacementNamed(context, '/refund', arguments: created);
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: data),
      BlocProvider.value(value: evidence),
      BlocProvider.value(value: action),
      BlocProvider.value(value: location),
    ],
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          incident
              ? 'Báo sự cố'
              : widget.kind == CustomerSupportKind.complaint
              ? 'Khiếu nại giao hàng'
              : 'Yêu cầu hoàn tiền',
        ),
      ),
      body: BlocBuilder<ResourceCubit<SupportFormData>, ResourceState<SupportFormData>>(
        builder: (context, ds) => BlocBuilder<ActionCubit, ActionState>(
          builder: (context, a) => BlocBuilder<CustomerEvidenceCubit, EvidenceState>(
            builder: (context, e) =>
                BlocBuilder<
                  ResourceCubit<GeoPosition>,
                  ResourceState<GeoPosition>
                >(
                  builder: (context, gpsState) {
                    final gps = gpsState.data, gpsError = gpsState.error;
                    final locating = gpsState.busy;
                    final d = ds.data;
                    final eligible =
                        d != null &&
                        (incident
                            ? d.order.summary.canReport
                            : widget.kind == CustomerSupportKind.complaint
                            ? d.order.canComplainAt(DateTime.now())
                            : d.order.summary.paymentMethod == 'PayOS' &&
                                  d.order.summary.paymentStatus == 'Paid');
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (ds.busy) const LinearProgressIndicator(),
                            if (ds.error != null) ...[
                              CustomerNotice(ds.error!, error: true),
                              TextButton(
                                onPressed: data.load,
                                child: const Text('Thử lại'),
                              ),
                            ],
                            if (d != null) ...[
                              CustomerCard(
                                color: AppColors.peach,
                                child: Column(
                                  children: [
                                    detailRow('Đơn hàng', d.order.summary.code),
                                    detailRow(
                                      'Tổng cước',
                                      money(d.order.summary.total),
                                    ),
                                    detailRow(
                                      'Trạng thái',
                                      statusLabel(d.order.summary.status),
                                    ),
                                  ],
                                ),
                              ),
                              if (!eligible)
                                CustomerNotice(
                                  incident
                                      ? 'Chỉ báo sự cố từ lúc tài xế đến lấy hàng đến trước khi giao xong.'
                                      : widget.kind ==
                                            CustomerSupportKind.complaint
                                      ? 'Chỉ khiếu nại trong 24 giờ sau giao hàng và trước khi xác nhận hoàn thành.'
                                      : 'Hoàn tiền do sự cố chỉ áp dụng cho đơn PayOS đã thanh toán.',
                                ),
                              if (eligible)
                                AbsorbPointer(
                                  absorbing: a.busy || e.busy,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (incident)
                                        DropdownButtonFormField<String>(
                                          initialValue: type,
                                          decoration: const InputDecoration(
                                            labelText: 'Loại sự cố',
                                          ),
                                          items:
                                              [
                                                    'DamagedCargo',
                                                    'Accident',
                                                    'VehicleBreakdown',
                                                    'Other',
                                                  ]
                                                  .map(
                                                    (v) => DropdownMenuItem(
                                                      value: v,
                                                      child: Text(
                                                        statusLabel(v),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged: (v) =>
                                              setState(() => type = v!),
                                        ),
                                      if (widget.kind ==
                                          CustomerSupportKind.complaint)
                                        DropdownButtonFormField<String>(
                                          initialValue: reason,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Lý do khiếu nại',
                                          ),
                                          items: d.reasons
                                              .map(
                                                (v) => DropdownMenuItem(
                                                  value: v.code,
                                                  child: Text(v.name),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) =>
                                              setState(() => reason = v),
                                          validator: (v) => v == null
                                              ? 'Chọn lý do khiếu nại'
                                              : null,
                                        ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: description,
                                        maxLines: 4,
                                        maxLength: 1000,
                                        decoration: const InputDecoration(
                                          labelText: 'Mô tả chi tiết',
                                        ),
                                        validator: (v) =>
                                            (v ?? '').trim().isEmpty
                                            ? 'Nhập nội dung cần hỗ trợ'
                                            : null,
                                      ),
                                      sectionTitle(
                                        'Ảnh minh chứng · ${e.photos.length}/5',
                                      ),
                                      PhotoStrip(
                                        e.photos,
                                        remove: evidence.remove,
                                      ),
                                      if (e.photos.length < 5)
                                        OutlinedButton.icon(
                                          onPressed: addPhoto,
                                          icon: const Icon(
                                            Icons.add_a_photo_outlined,
                                          ),
                                          label: Text(
                                            e.busy
                                                ? 'Đang tải ảnh…'
                                                : 'Thêm ảnh minh chứng',
                                          ),
                                        ),
                                      if (e.error != null)
                                        CustomerNotice(e.error!, error: true),
                                      if (incident) ...[
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          onPressed: locating
                                              ? null
                                              : location.load,
                                          icon: const Icon(Icons.my_location),
                                          label: Text(
                                            locating
                                                ? 'Đang lấy vị trí…'
                                                : gps == null
                                                ? 'Đính kèm vị trí hiện tại'
                                                : 'Cập nhật GPS đã đính kèm',
                                          ),
                                        ),
                                        if (gps != null)
                                          detailRow(
                                            'GPS',
                                            '${gps.latitude.toStringAsFixed(5)}, ${gps.longitude.toStringAsFixed(5)}',
                                          ),
                                        if (gpsError != null)
                                          CustomerNotice(gpsError, error: true),
                                      ],
                                      if (!incident) ...[
                                        sectionTitle('Số tiền yêu cầu'),
                                        TextFormField(
                                          controller: amount,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Số tiền (VND)',
                                            helperText:
                                                'Lớn hơn 0 và không vượt ${money(d.order.summary.total)}',
                                          ),
                                          validator: (v) {
                                            final n = int.tryParse(v ?? '');
                                            return n == null ||
                                                    n <= 0 ||
                                                    n > d.order.summary.total
                                                ? 'Số tiền chưa hợp lệ'
                                                : null;
                                          },
                                        ),
                                        sectionTitle(
                                          'Tài khoản nhận hoàn tiền',
                                        ),
                                        BankAccountFields(
                                          banks: d.banks,
                                          selected: bank,
                                          onBank: (v) =>
                                              setState(() => bank = v),
                                          number: account,
                                          holder: holder,
                                        ),
                                        const CustomerNotice(
                                          'Số tiền được hoàn phụ thuộc kết quả xét duyệt và tổng các khoản hoàn của đơn. Gửi yêu cầu chưa có nghĩa là đã được hoàn tiền.',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (a.error != null)
                                CustomerNotice(a.error!, error: true),
                              FilledButton(
                                onPressed:
                                    !eligible || a.busy || e.busy || locating
                                    ? null
                                    : () => submit(d),
                                child: Text(
                                  a.busy ? 'Đang gửi…' : 'Gửi yêu cầu',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ),
      ),
    ),
  );
}

class BankAccountFields extends StatelessWidget {
  const BankAccountFields({
    super.key,
    required this.banks,
    required this.selected,
    required this.onBank,
    required this.number,
    required this.holder,
  });
  final List<Choice> banks;
  final String? selected;
  final ValueChanged<String?> onBank;
  final TextEditingController number, holder;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Ngân hàng'),
        items: banks
            .map(
              (v) => DropdownMenuItem(
                value: v.code,
                child: Text(v.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onBank,
        validator: (v) => v == null ? 'Chọn ngân hàng' : null,
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: number,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Số tài khoản'),
        validator: (v) => RegExp(r'^[0-9]{6,19}$').hasMatch((v ?? '').trim())
            ? null
            : 'Nhập 6–19 chữ số',
      ),
      const SizedBox(height: 18),
      TextFormField(
        controller: holder,
        textCapitalization: TextCapitalization.characters,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'Tên chủ tài khoản không dấu',
        ),
        validator: (v) =>
            RegExp(r'^[A-Za-z ]{2,100}$').hasMatch((v ?? '').trim())
            ? null
            : 'Nhập tên không dấu, 2–100 ký tự',
      ),
      const SizedBox(height: 14),
    ],
  );
}
