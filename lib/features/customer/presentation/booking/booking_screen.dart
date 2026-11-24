import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/config/platform_config_cubit.dart';
import '../../../auth/presentation/auth_cubit.dart';
import '../../../../core/session/session_store.dart';
import '../../data/address_search.dart';
import '../../data/booking_draft_store.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';
import '../../domain/order_rules.dart';
import '../labels.dart';
import '../widgets/customer_widgets.dart';
import '../widgets/route_map.dart';
import 'booking_cubit.dart';

/// Đặt xe 4 bước: Lộ trình → Hàng hoá → Loại xe → Thanh toán. Trả về [CreatedOrder] khi tạo đơn thành công.
/// Giống web: khách chưa đăng nhập vẫn lập được đơn nháp; khi thêm ảnh hoặc gửi đơn thì [onSignIn] mở màn đăng nhập.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, this.initial, this.onSignIn});

  /// Bản nháp sẵn ("Đặt lại đơn tương tự"); khi có thì không mở nháp cũ đã lưu.
  final BookingDraft? initial;

  /// Mở màn đăng nhập, trả về phiên mới (null = khách huỷ).
  final Future<Session?> Function()? onSignIn;

  @override
  Widget build(BuildContext context) {
    BookingDraftStore? store;
    try {
      store = context.read<BookingDraftStore>();
    } catch (_) {
      store = null; // màn được dựng riêng (test) không có kho nháp
    }
    return BlocProvider(
      create: (_) {
        final cubit = BookingCubit(
          context.read<CustomerApi>(),
          initial: initial,
          store: initial == null ? store : null,
        );
        // Chưa có số liệu thật từ BE (lần mở app trước lỗi mạng) thì thử lại lúc mở màn đặt xe.
        try {
          context.read<PlatformConfigCubit>().ensureLoaded();
        } catch (_) {}
        cubit.loadLookups().then((_) => initial == null ? cubit.restoreDraft() : null);
        return cubit;
      },
      child: _BookingView(onSignIn: onSignIn),
    );
  }
}

const _steps = ['Lộ trình', 'Hàng hoá', 'Loại xe', 'Thanh toán'];

class _BookingView extends StatelessWidget {
  const _BookingView({this.onSignIn});
  final Future<Session?> Function()? onSignIn;

  Future<void> _next(BuildContext context) async {
    final cubit = context.read<BookingCubit>();
    final s = cubit.state;
    for (var i = 0; i <= s.step; i++) {
      final err = cubit.validate(i);
      if (err != null) {
        if (i != s.step) cubit.goTo(i);
        return showSnack(context, err, error: true);
      }
    }
    if (s.step < 3) return cubit.goTo(s.step + 1);
    // Chỉ khách đã đăng nhập mới gửi được đơn; nháp được giữ nguyên trong lúc đăng nhập.
    if (!await _ensureCustomer(context, onSignIn) || !context.mounted) return;
    try {
      final created = await cubit.submit();
      if (context.mounted) Navigator.pop<CreatedOrder>(context, created);
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<BookingCubit, BookingState>(
    builder: (context, s) {
      final cubit = context.read<BookingCubit>();
      return PopScope(
        canPop: s.step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) cubit.goTo(s.step - 1);
        },
        child: Scaffold(
          appBar: AppHeader(
            'Đặt xe vận chuyển',
            onBack: () => s.step == 0 ? Navigator.pop(context) : cubit.goTo(s.step - 1),
          ),
          bottomNavigationBar: _BottomBar(state: s, signedIn: _isCustomer(context), onNext: () => _next(context)),
          body: s.loadingLookups
              ? const Center(child: CircularProgressIndicator())
              : s.lookupError != null
              ? ErrorView(s.lookupError!, onRetry: cubit.loadLookups)
              : Column(
                  children: [
                    if (s.restored) const _RestoredBanner(),
                    _StepBar(step: s.step, onTap: (i) => i < s.step ? cubit.goTo(i) : null),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                        children: switch (s.step) {
                          0 => [const _RouteStep()],
                          1 => [_CargoStep(onSignIn: onSignIn)],
                          2 => [const _VehicleStep(), const _RouteMapCard()],
                          _ => [const _PaymentStep()],
                        },
                      ),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}

/// Phí bốc xếp thật từ BE (GET /public/Config); null khi chưa tải được: không hiện số tự đoán.
double? _loadingFee(BuildContext context) {
  try {
    return context.watch<PlatformConfigCubit>().state?.loadingFee;
  } catch (_) {
    return null; // màn dựng riêng (test) không có PlatformConfigCubit
  }
}

bool _isCustomer(BuildContext context) {
  try {
    return context.watch<AuthCubit>().state?.isCustomer == true;
  } catch (_) {
    return true; // màn dựng riêng không có AuthCubit: coi như đã đăng nhập
  }
}

/// Đã là khách hàng đăng nhập, hoặc đăng nhập ngay bây giờ. Tài khoản tài xế không đặt được đơn.
Future<bool> _ensureCustomer(BuildContext context, Future<Session?> Function()? onSignIn) async {
  AuthCubit? auth;
  try {
    auth = context.read<AuthCubit>();
  } catch (_) {
    return true;
  }
  const driverMessage = 'Tài khoản tài xế không đặt được đơn. Vui lòng đăng nhập bằng tài khoản khách hàng.';
  if (auth.state?.isCustomer == true) return true;
  if (auth.state != null) {
    showSnack(context, driverMessage, error: true);
    return false;
  }
  if (onSignIn == null) return false;
  showSnack(context, 'Vui lòng đăng nhập để tiếp tục. Đơn nháp của bạn được giữ nguyên.');
  final cubit = context.read<BookingCubit>();
  final session = await onSignIn();
  if (!context.mounted || session == null) return false;
  if (!session.isCustomer) {
    showSnack(context, driverMessage, error: true);
    return false;
  }
  await cubit.loadCoupons();
  return true;
}

/// Có nháp cũ: khách chọn tiếp tục hoặc bắt đầu lại.
class _RestoredBanner extends StatelessWidget {
  const _RestoredBanner();
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn có đơn nháp chưa gửi.', style: appText(size: 13.5, weight: FontWeight.w700)),
          Text(
            'Mã giảm giá và các ô đồng ý chính sách cần chọn lại.',
            style: appText(size: 12, color: AppColors.secondary),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: cubit.restart, child: const Text('Bắt đầu lại')),
              const SizedBox(width: 4),
              FilledButton(onPressed: cubit.keepRestored, child: const Text('Tiếp tục')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bản đồ lộ trình theo hai điểm và đường đi BE trả về trong báo giá (giống web).
class _RouteMapCard extends StatelessWidget {
  const _RouteMapCard();
  @override
  Widget build(BuildContext context) {
    final e = context.select((BookingCubit c) => c.state.estimate);
    final from = e?.pickup, to = e?.dropoff;
    if (e == null || from == null || to == null) return const SizedBox.shrink();
    return SectionCard(
      title: 'Bản đồ lộ trình',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RouteMap(pickup: from, dropoff: to, polyline: e.polyline),
          const SizedBox(height: 8),
          Text(
            'Quãng đường: ${kmCeil(e.distanceKm)} • khoảng ${e.durationMinutes} phút',
            style: appText(size: 12, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.onTap});
  final int step;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
    child: Row(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.orange : AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${i + 1}. ${_steps[i]}',
                    style: appText(
                      size: 11,
                      weight: i == step ? FontWeight.w700 : FontWeight.w500,
                      color: i <= step ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.signedIn, required this.onNext});
  final BookingState state;
  final bool signedIn;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final e = state.estimate;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tạm tính', style: appText(size: 11.5, color: AppColors.secondary)),
                    Text(
                      state.estimating
                          ? 'Đang tính…'
                          : e == null
                          ? '—'
                          : moneyCeil1000(e.totalFee),
                      style: appText(size: 19, weight: FontWeight.w800),
                    ),
                    if (e != null)
                      Text(
                        '${kmCeil(e.distanceKm)} • khoảng ${e.durationMinutes} phút',
                        style: appText(size: 11, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 170,
                child: PrimaryButton(
                  state.step < 3
                      ? 'Tiếp tục'
                      : signedIn
                      ? 'Đặt xe'
                      : 'Đăng nhập để đặt xe',
                  busy: state.submitting || (state.step == 3 && state.estimating),
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- Bước 1 */
class _RouteStep extends StatelessWidget {
  const _RouteStep();
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    final d = context.select((BookingCubit c) => c.state.draft);
    return Column(
      children: [
        SectionCard(
          title: 'Điểm lấy hàng',
          child: Column(
            children: [
              _AddressField(
                label: 'Địa chỉ lấy hàng',
                value: d.pickupAddress,
                onChanged: (v) => cubit.update((x) => x.copyWith(pickupAddress: v)),
              ),
              _Text(
                label: 'Tên người gửi',
                value: d.senderName,
                maxLength: OrderRules.maxContactName,
                onChanged: (v) => cubit.update((x) => x.copyWith(senderName: v)),
              ),
              _Text(
                label: 'Số điện thoại người gửi',
                value: d.senderPhone,
                phone: true,
                onChanged: (v) => cubit.update((x) => x.copyWith(senderPhone: v)),
              ),
              _Text(
                label: 'Ghi chú',
                value: d.pickupNote,
                maxLength: OrderRules.maxNote,
                multiline: true,
                onChanged: (v) => cubit.update((x) => x.copyWith(pickupNote: v)),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Điểm giao hàng',
          child: Column(
            children: [
              _AddressField(
                label: 'Địa chỉ giao hàng',
                value: d.dropoffAddress,
                onChanged: (v) => cubit.update((x) => x.copyWith(dropoffAddress: v)),
              ),
              _Text(
                label: 'Tên người nhận',
                value: d.receiverName,
                maxLength: OrderRules.maxContactName,
                onChanged: (v) => cubit.update((x) => x.copyWith(receiverName: v)),
              ),
              _Text(
                label: 'Số điện thoại người nhận',
                value: d.receiverPhone,
                phone: true,
                onChanged: (v) => cubit.update((x) => x.copyWith(receiverPhone: v)),
              ),
              _Text(
                label: 'Ghi chú',
                value: d.dropoffNote,
                maxLength: OrderRules.maxNote,
                multiline: true,
                onChanged: (v) => cubit.update((x) => x.copyWith(dropoffNote: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ô địa chỉ có gợi ý (Photon) nhưng vẫn cho gõ tự do.
class _AddressField extends StatelessWidget {
  const _AddressField({required this.label, required this.value, required this.onChanged});
  final String label, value;
  final ValueChanged<String> onChanged;
  static final _search = AddressSearch();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Autocomplete<String>(
      key: ValueKey('$label|${context.select((BookingCubit c) => c.state.restored)}'),
      initialValue: TextEditingValue(text: value),
      optionsBuilder: (v) async {
        final q = v.text;
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (q.trim().length < 3) return const [];
        try {
          return await _search.search(q);
        } catch (_) {
          return const [];
        }
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.place_outlined)),
      ),
    ),
  );
}

class _Text extends StatelessWidget {
  const _Text({
    required this.label,
    required this.value,
    required this.onChanged,
    this.phone = false,
    this.number = false,
    this.multiline = false,
    this.maxLength,
  });
  final String label, value;
  final ValueChanged<String> onChanged;
  final bool phone, number, multiline;
  final int? maxLength;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      // Nháp cũ được mở lại sau khi màn dựng xong: đổi key để ô hiện đúng giá trị mới.
      key: ValueKey('$label|${context.select((BookingCubit c) => c.state.restored)}'),
      initialValue: value,
      onChanged: onChanged,
      keyboardType: phone
          ? TextInputType.phone
          : number
          ? const TextInputType.numberWithOptions(decimal: true)
          : multiline
          ? TextInputType.multiline
          : null,
      minLines: multiline ? 1 : null,
      maxLines: multiline ? 4 : 1,
      maxLength: phone ? 20 : maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ .]'))]
          : null,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
}

/* ---------------------------------------------------------------- Bước 2 */
class _CargoStep extends StatelessWidget {
  const _CargoStep({this.onSignIn});
  final Future<Session?> Function()? onSignIn;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    final s = context.watch<BookingCubit>().state;
    final d = s.draft;
    int toInt(String v) => int.tryParse(v) ?? 0;
    return Column(
      children: [
        SectionCard(
          title: 'Loại hàng',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in s.cargoTypes)
                ChoiceChip(
                  label: Text(c.name),
                  selected: d.cargoType == c.code,
                  onSelected: (_) => cubit.update((x) => x.copyWith(cargoType: c.code)),
                ),
            ],
          ),
        ),
        SectionCard(
          title: 'Thông tin hàng hoá',
          child: Column(
            children: [
              _Text(
                label: 'Mô tả hàng hoá',
                value: d.description,
                maxLength: OrderRules.maxSpecialNotes,
                multiline: true,
                onChanged: (v) => cubit.update((x) => x.copyWith(description: v)),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Text(
                      label: 'Số kiện',
                      value: '${d.quantity}',
                      number: true,
                      onChanged: (v) => cubit.update((x) => x.copyWith(quantity: toInt(v))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Text(
                      label: 'Tổng khối lượng',
                      value: d.weightKg == 0 ? '' : '${d.weightKg}',
                      number: true,
                      onChanged: (v) => cubit.update((x) => x.copyWith(weightKg: double.tryParse(v) ?? 0)),
                    ),
                  ),
                ],
              ),
              Text('Kích thước món lớn nhất', style: appText(size: 12, color: AppColors.secondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Text(
                      label: 'Dài',
                      value: d.lengthCm == 0 ? '' : '${d.lengthCm}',
                      number: true,
                      onChanged: (v) => cubit.update((x) => x.copyWith(lengthCm: toInt(v))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Text(
                      label: 'Rộng',
                      value: d.widthCm == 0 ? '' : '${d.widthCm}',
                      number: true,
                      onChanged: (v) => cubit.update((x) => x.copyWith(widthCm: toInt(v))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Text(
                      label: 'Cao',
                      value: d.heightCm == 0 ? '' : '${d.heightCm}',
                      number: true,
                      onChanged: (v) => cubit.update((x) => x.copyWith(heightCm: toInt(v))),
                    ),
                  ),
                ],
              ),
              _Text(
                label: 'Ghi chú bốc xếp',
                value: d.specialNotes,
                maxLength: OrderRules.maxSpecialNotes,
                multiline: true,
                onChanged: (v) => cubit.update((x) => x.copyWith(specialNotes: v)),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Ảnh hàng hoá',
          child: PhotoPicker(
            label: 'Ảnh hàng',
            urls: d.photos,
            // Ảnh được tải lên tài khoản khách: chưa đăng nhập thì đăng nhập trước, nháp giữ nguyên.
            upload: (file) async {
              if (!await _ensureCustomer(context, onSignIn)) throw const _SignInRequired();
              return cubit.api.upload(file);
            },
            onChanged: (p) => cubit.update((x) => x.copyWith(photos: p)),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: d.noProhibitedCargo,
          onChanged: (v) => cubit.update((x) => x.copyWith(noProhibitedCargo: v ?? false)),
          title: Text('Tôi cam kết hàng hoá không thuộc danh mục hàng cấm.', style: appText(size: 13)),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------------- Bước 3 */
class _VehicleStep extends StatelessWidget {
  const _VehicleStep();
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    final s = context.watch<BookingCubit>().state;
    final d = s.draft;
    return Column(
      children: [
        for (final v in s.vehicles)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _VehicleCard(
              vehicle: v,
              selected: d.vehicleTypeId == v.id,
              fits: v.canCarry(d.weightKg, d.lengthCm, d.widthCm, d.heightCm),
              onTap: () => cubit.update((x) => x.copyWith(vehicleTypeId: v.id)),
            ),
          ),
        if (s.estimateError != null) Notice(s.estimateError!, icon: 'warning', peach: true),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.selected, required this.fits, required this.onTap});
  final VehicleType vehicle;
  final bool selected, fits;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final image = v.image;
    return Opacity(
      opacity: fits ? 1 : 0.5,
      child: AppCard(
        onTap: fits ? onTap : null,
        borderColor: selected ? AppColors.orange : AppColors.line,
        color: selected ? AppColors.peach : Colors.white,
        child: Row(
          children: [
            VehicleImage(image, width: 72, height: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(v.name, style: appText(size: 15, weight: FontWeight.w700)),
                      ),
                      if (!fits) ...[const SizedBox(width: 6), const Pill(Tone2.cannot)],
                    ],
                  ),
                  Text(
                    'Tải trọng ${v.maxLoadWeightKg.round()} kg • Thùng ${v.bedLengthCm}×${v.bedWidthCm}×${v.bedHeightCm} cm',
                    style: appText(size: 11.5, color: AppColors.secondary),
                  ),
                  Text(
                    'Mở cửa ${money(v.baseFare)} • ${money(v.pricePerKm)}/km • Tối thiểu ${money(v.minimumFare)}',
                    style: appText(size: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (selected) const AppIcon('check', color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- Bước 4 */
class _PaymentStep extends StatelessWidget {
  const _PaymentStep();
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BookingCubit>();
    final s = context.watch<BookingCubit>().state;
    final d = s.draft;
    final e = s.estimate;
    final loadingFee = _loadingFee(context);
    return Column(
      children: [
        SectionCard(
          title: 'Dịch vụ bốc xếp',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: d.loadingService,
            onChanged: (v) => cubit.update((x) => x.copyWith(loadingService: v)),
            title: Text('Tài xế hỗ trợ bốc xếp 2 đầu', style: appText(size: 14, weight: FontWeight.w600)),
            subtitle: Text(
              loadingFee == null ? 'Khuân vác tại điểm lấy và điểm giao.' : 'Khuân vác tại điểm lấy và điểm giao. Phí ${money(loadingFee)}.',
              style: appText(size: 12, color: AppColors.secondary),
            ),
          ),
        ),
        SectionCard(
          title: 'Mã giảm giá',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: ValueKey(d.couponCode),
                initialValue: d.couponCode,
                textCapitalization: TextCapitalization.characters,
                onFieldSubmitted: (v) => cubit.update((x) => x.copyWith(couponCode: v.toUpperCase())),
                decoration: InputDecoration(
                  labelText: 'Nhập mã giảm giá',
                  errorText: s.couponError,
                  helperText: s.couponError == null && d.couponCode.isNotEmpty && e != null
                      ? 'Đã áp dụng: -${money(e.discountAmount)}'
                      : null,
                  suffixIcon: d.couponCode.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Bỏ mã',
                          icon: const Icon(Icons.close),
                          onPressed: () => cubit.update((x) => x.copyWith(couponCode: '')),
                        ),
                ),
              ),
              if (s.coupons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in s.coupons)
                      ChoiceChip(
                        label: Text('${c.code} -${money(c.discountValue)}'),
                        tooltip: 'Đơn từ ${money(c.minimumOrderValue)} • Hạn dùng ${date(c.expiresAt)}',
                        selected: d.couponCode == c.code,
                        onSelected: (sel) => cubit.update((x) => x.copyWith(couponCode: sel ? c.code : '')),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SectionCard(
          title: 'Phương thức thanh toán',
          child: RadioGroup<String>(
            groupValue: d.paymentMethod,
            onChanged: (v) => cubit.update((x) => x.copyWith(paymentMethod: v)),
            child: Column(
              children: [
                const RadioListTile(
                  contentPadding: EdgeInsets.zero,
                  value: 'PayOS',
                  title: Text('Chuyển khoản PayOS'),
                  subtitle: Text('Thanh toán trước, đơn chỉ gửi tới tài xế sau khi thanh toán.'),
                ),
                const RadioListTile(
                  contentPadding: EdgeInsets.zero,
                  value: 'Cash',
                  title: Text('Tiền mặt'),
                  subtitle: Text('Trả tiền mặt cho tài xế; hệ thống tìm tài xế ngay.'),
                ),
                if (d.paymentMethod == 'Cash')
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Sender', label: Text('Người gửi trả')),
                      ButtonSegment(value: 'Receiver', label: Text('Người nhận trả')),
                    ],
                    selected: {d.payerRole},
                    onSelectionChanged: (v) => cubit.update((x) => x.copyWith(payerRole: v.first)),
                  ),
              ],
            ),
          ),
        ),
        const _RouteMapCard(),
        SectionCard(
          title: 'Chi phí',
          child: e == null
              ? Text(
                  s.estimating ? 'Đang tính giá…' : (s.estimateError ?? 'Chưa có giá.'),
                  style: appText(size: 13, color: AppColors.secondary),
                )
              : Column(
                  children: [
                    KvRow('Cước quãng đường ${kmCeil(e.distanceKm)}', moneyCeil1000(e.distanceFee)),
                    if (e.serviceFee > 0) KvRow('Phí bốc xếp', moneyCeil1000(e.serviceFee)),
                    if (e.discountAmount > 0)
                      KvRow('Giảm giá', '-${moneyCeil1000(e.discountAmount)}', valueColor: AppColors.green),
                    const Divider(),
                    KvRow('Tổng thanh toán', moneyCeil1000(e.totalFee), strong: true),
                  ],
                ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: d.noProhibitedCargo,
          onChanged: (v) => cubit.update((x) => x.copyWith(noProhibitedCargo: v ?? false)),
          title: Text('Tôi cam kết không gửi hàng cấm.', style: appText(size: 13)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: d.agreedWarranty,
          onChanged: (v) => cubit.update((x) => x.copyWith(agreedWarranty: v ?? false)),
          title: Text('Tôi đồng ý với chính sách bảo hành & bồi thường.', style: appText(size: 13)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: () => _showPolicies(context), child: const Text('Xem chính sách')),
        ),
      ],
    );
  }
}

/// Chính sách bảo hành và hoàn tiền do hệ thống cung cấp.
Future<void> _showPolicies(BuildContext context) {
  final api = context.read<CustomerApi>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scroll) => FutureBuilder<List<LookupItem>>(
        future: api.policies(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(errorText(snap.error!), onRetry: () => Navigator.pop(context));
          final items = (snap.data ?? const <LookupItem>[])
              .where((p) => p.code == 'WARRANTY' || p.code == 'REFUND')
              .toList();
          if (items.isEmpty) return const EmptyView('Chưa có nội dung.');
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            children: [
              for (final p in items)
                ExpansionTile(
                  title: Text(p.name, style: appText(weight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p.description ?? '').trim().isEmpty ? 'Nội dung đang được cập nhật.' : p.description!,
                      style: appText(size: 13.5, color: AppColors.secondary),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// Nhãn phụ cho thẻ xe.
abstract final class Tone2 {
  static const cannot = Tone('Không chở được hàng này', AppColors.red, AppColors.redBg);
}

/// Khách huỷ đăng nhập khi đang thêm ảnh: ảnh không được tải lên.
class _SignInRequired extends ApiException {
  const _SignInRequired() : super('Vui lòng đăng nhập để thêm ảnh hàng hoá.');
}
