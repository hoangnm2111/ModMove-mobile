import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/booking_draft_store.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';
import '../../domain/order_rules.dart';

/// Bản nháp đặt xe, cùng các ô như web: người gửi, người nhận và ghi chú cho từng điểm.
class BookingDraft {
  const BookingDraft({
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.senderName = '',
    this.senderPhone = '',
    this.pickupNote = '',
    this.receiverName = '',
    this.receiverPhone = '',
    this.dropoffNote = '',
    this.cargoType = '',
    this.description = '',
    this.quantity = 1,
    this.weightKg = 0,
    this.lengthCm = 0,
    this.widthCm = 0,
    this.heightCm = 0,
    this.photos = const [],
    this.specialNotes = '',
    this.noProhibitedCargo = false,
    this.vehicleTypeId,
    this.loadingService = false,
    this.couponCode = '',
    this.paymentMethod = 'PayOS',
    this.payerRole = 'Sender',
    this.agreedWarranty = false,
  });

  final String pickupAddress,
      dropoffAddress,
      senderName,
      senderPhone,
      pickupNote,
      receiverName,
      receiverPhone,
      dropoffNote;
  final String cargoType, description, specialNotes, couponCode, paymentMethod, payerRole;
  final int quantity, lengthCm, widthCm, heightCm;
  final double weightKg;
  final List<String> photos;
  final bool noProhibitedCargo, loadingService, agreedWarranty;
  final int? vehicleTypeId;

  /// Khách đã nhập gì đáng giữ lại chưa (nháp trống thì không lưu).
  bool get hasContent =>
      [
        pickupAddress,
        dropoffAddress,
        senderName,
        senderPhone,
        pickupNote,
        receiverName,
        receiverPhone,
        dropoffNote,
        description,
        specialNotes,
      ].any((s) => s.trim().isNotEmpty) ||
      photos.isNotEmpty ||
      weightKg > 0 ||
      vehicleTypeId != null;

  BookingDraft copyWith({
    String? pickupAddress,
    String? dropoffAddress,
    String? senderName,
    String? senderPhone,
    String? pickupNote,
    String? receiverName,
    String? receiverPhone,
    String? dropoffNote,
    String? cargoType,
    String? description,
    int? quantity,
    double? weightKg,
    int? lengthCm,
    int? widthCm,
    int? heightCm,
    List<String>? photos,
    String? specialNotes,
    bool? noProhibitedCargo,
    int? vehicleTypeId,
    bool clearVehicle = false,
    bool? loadingService,
    String? couponCode,
    String? paymentMethod,
    String? payerRole,
    bool? agreedWarranty,
  }) => BookingDraft(
    pickupAddress: pickupAddress ?? this.pickupAddress,
    dropoffAddress: dropoffAddress ?? this.dropoffAddress,
    senderName: senderName ?? this.senderName,
    senderPhone: senderPhone ?? this.senderPhone,
    pickupNote: pickupNote ?? this.pickupNote,
    receiverName: receiverName ?? this.receiverName,
    receiverPhone: receiverPhone ?? this.receiverPhone,
    dropoffNote: dropoffNote ?? this.dropoffNote,
    cargoType: cargoType ?? this.cargoType,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    weightKg: weightKg ?? this.weightKg,
    lengthCm: lengthCm ?? this.lengthCm,
    widthCm: widthCm ?? this.widthCm,
    heightCm: heightCm ?? this.heightCm,
    photos: photos ?? this.photos,
    specialNotes: specialNotes ?? this.specialNotes,
    noProhibitedCargo: noProhibitedCargo ?? this.noProhibitedCargo,
    vehicleTypeId: clearVehicle ? null : (vehicleTypeId ?? this.vehicleTypeId),
    loadingService: loadingService ?? this.loadingService,
    couponCode: couponCode ?? this.couponCode,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    payerRole: payerRole ?? this.payerRole,
    agreedWarranty: agreedWarranty ?? this.agreedWarranty,
  );

  /// Lưu nháp: không lưu mã giảm giá và các ô đồng ý, để khách xác nhận lại khi mở nháp.
  Map<String, dynamic> toJson() => {
    'pickupAddress': pickupAddress,
    'dropoffAddress': dropoffAddress,
    'senderName': senderName,
    'senderPhone': senderPhone,
    'pickupNote': pickupNote,
    'receiverName': receiverName,
    'receiverPhone': receiverPhone,
    'dropoffNote': dropoffNote,
    'cargoType': cargoType,
    'description': description,
    'quantity': quantity,
    'weightKg': weightKg,
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'photos': photos,
    'specialNotes': specialNotes,
    'vehicleTypeId': vehicleTypeId,
    'loadingService': loadingService,
    'paymentMethod': paymentMethod,
    'payerRole': payerRole,
  };

  factory BookingDraft.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] is String ? j[k] as String : '';
    int i(String k, [int d = 0]) => j[k] is num ? (j[k] as num).toInt() : d;
    return BookingDraft(
      pickupAddress: s('pickupAddress'),
      dropoffAddress: s('dropoffAddress'),
      senderName: s('senderName'),
      senderPhone: s('senderPhone'),
      pickupNote: s('pickupNote'),
      receiverName: s('receiverName'),
      receiverPhone: s('receiverPhone'),
      dropoffNote: s('dropoffNote'),
      cargoType: s('cargoType'),
      description: s('description'),
      quantity: i('quantity', 1),
      weightKg: j['weightKg'] is num ? (j['weightKg'] as num).toDouble() : 0,
      lengthCm: i('lengthCm'),
      widthCm: i('widthCm'),
      heightCm: i('heightCm'),
      photos: j['photos'] is List ? (j['photos'] as List).map((e) => '$e').toList() : const [],
      specialNotes: s('specialNotes'),
      vehicleTypeId: j['vehicleTypeId'] is num ? (j['vehicleTypeId'] as num).toInt() : null,
      loadingService: j['loadingService'] == true,
      paymentMethod: s('paymentMethod').isEmpty ? 'PayOS' : s('paymentMethod'),
      payerRole: s('payerRole').isEmpty ? 'Sender' : s('payerRole'),
    );
  }
}

class BookingState {
  const BookingState({
    this.step = 0,
    this.draft = const BookingDraft(),
    this.restored = false,
    this.vehicles = const [],
    this.cargoTypes = const [],
    this.coupons = const [],
    this.loadingLookups = true,
    this.lookupError,
    this.estimate,
    this.estimating = false,
    this.estimateError,
    this.couponError,
    this.submitting = false,
  });
  final int step;
  final BookingDraft draft;

  /// Có nháp cũ vừa được mở lại: màn đặt xe hỏi "Tiếp tục / Bắt đầu lại".
  final bool restored;
  final List<VehicleType> vehicles;
  final List<LookupItem> cargoTypes;
  final List<AvailableCoupon> coupons;
  final bool loadingLookups, estimating, submitting;
  final String? lookupError, estimateError, couponError;
  final FareEstimate? estimate;

  VehicleType? get vehicle => vehicles.where((v) => v.id == draft.vehicleTypeId).firstOrNull;

  BookingState copyWith({
    int? step,
    BookingDraft? draft,
    bool? restored,
    List<VehicleType>? vehicles,
    List<LookupItem>? cargoTypes,
    List<AvailableCoupon>? coupons,
    bool? loadingLookups,
    String? lookupError,
    FareEstimate? estimate,
    bool clearEstimate = false,
    bool? estimating,
    String? estimateError,
    String? couponError,
    bool clearErrors = false,
    bool? submitting,
  }) => BookingState(
    step: step ?? this.step,
    draft: draft ?? this.draft,
    restored: restored ?? this.restored,
    vehicles: vehicles ?? this.vehicles,
    cargoTypes: cargoTypes ?? this.cargoTypes,
    coupons: coupons ?? this.coupons,
    loadingLookups: loadingLookups ?? this.loadingLookups,
    lookupError: lookupError ?? this.lookupError,
    estimate: clearEstimate ? null : (estimate ?? this.estimate),
    estimating: estimating ?? this.estimating,
    estimateError: clearErrors ? null : (estimateError ?? this.estimateError),
    couponError: clearErrors ? null : (couponError ?? this.couponError),
    submitting: submitting ?? this.submitting,
  );
}

/// Kết quả tạo đơn.
typedef CreatedOrder = ({int id, String code, double total, bool payOs});

/// Giá đổi giữa lúc khách xem và lúc gửi đơn: đơn chưa được tạo, khách xem giá mới rồi bấm đặt lại.
class FareChangedException extends ApiException {
  const FareChangedException(super.message) : super(code: 'FARE_CHANGED');
}

class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this.api, {BookingDraft? initial, this.store})
    : super(BookingState(draft: initial ?? const BookingDraft()));
  final CustomerApi api;

  /// Nơi lưu nháp. Null = không lưu (ví dụ "Đặt lại đơn tương tự" dùng nháp có sẵn).
  final BookingDraftStore? store;
  Timer? _debounce;
  Timer? _saveTimer;
  int _estimateSeq = 0;

  /// Mở nháp cũ còn hạn (nếu có). Chỉ gọi khi màn đặt xe mở mà không có nháp sẵn.
  Future<void> restoreDraft() async {
    final saved = await store?.load();
    if (saved == null || isClosed || state.draft.hasContent) return;
    final draft = BookingDraft.fromJson(saved.json);
    if (!draft.hasContent) return;
    emit(state.copyWith(draft: draft, step: saved.step.clamp(0, 3), restored: true));
    _scheduleEstimate(immediate: true);
  }

  /// Khách chọn tiếp tục nháp cũ.
  void keepRestored() => emit(state.copyWith(restored: false));

  /// Khách chọn bắt đầu lại: bỏ nháp cũ.
  void restart() {
    _debounce?.cancel();
    final cargoType = state.cargoTypes.isNotEmpty ? state.cargoTypes.first.code : '';
    emit(
      state.copyWith(
        step: 0,
        draft: BookingDraft(cargoType: cargoType),
        restored: false,
        clearEstimate: true,
        clearErrors: true,
      ),
    );
    unawaited(store?.clear());
  }

  Future<void> loadLookups() async {
    emit(state.copyWith(loadingLookups: true));
    try {
      final results = await Future.wait([api.vehicleTypes(), api.cargoTypes()]);
      final cargo = results[1] as List<LookupItem>;
      emit(
        state.copyWith(
          vehicles: results[0] as List<VehicleType>,
          cargoTypes: cargo,
          loadingLookups: false,
          draft: state.draft.cargoType.isEmpty && cargo.isNotEmpty
              ? state.draft.copyWith(cargoType: cargo.first.code)
              : null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingLookups: false, lookupError: e is ApiException ? e.message : '$e'));
      return;
    }
    await loadCoupons();
  }

  /// Mã giảm giá dùng được của khách; khách chưa đăng nhập thì để trống.
  Future<void> loadCoupons() async {
    try {
      final coupons = await api.coupons();
      if (!isClosed) emit(state.copyWith(coupons: coupons));
    } catch (_) {}
  }

  void update(BookingDraft Function(BookingDraft d) f) {
    emit(state.copyWith(draft: f(state.draft)));
    _scheduleEstimate();
    _scheduleSave();
  }

  void _scheduleSave() {
    final s = store;
    if (s == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      final d = state.draft;
      unawaited(d.hasContent ? s.save(d.toJson(), state.step) : s.clear());
    });
  }

  /// Lỗi của bước hiện tại (null = hợp lệ).
  String? validate(int step) {
    final d = state.draft;
    switch (step) {
      case 0:
        if (!InputRules.address(d.pickupAddress)) return 'Nhập điểm lấy hàng cụ thể.';
        if (d.senderName.trim().isEmpty) return 'Nhập tên người gửi.';
        if (!InputRules.phone(d.senderPhone)) return 'Nhập số điện thoại người gửi hợp lệ.';
        if (d.pickupNote.trim().length > OrderRules.maxNote) {
          return 'Ghi chú điểm lấy hàng tối đa ${OrderRules.maxNote} ký tự.';
        }
        if (!InputRules.address(d.dropoffAddress)) return 'Nhập điểm giao hàng cụ thể.';
        if (InputRules.sameAddress(d.pickupAddress, d.dropoffAddress)) return 'Điểm giao hàng phải khác điểm lấy hàng.';
        if (d.receiverName.trim().isEmpty) return 'Nhập tên người nhận.';
        if (!InputRules.phone(d.receiverPhone)) return 'Nhập số điện thoại người nhận hợp lệ.';
        if (d.dropoffNote.trim().length > OrderRules.maxNote) {
          return 'Ghi chú điểm giao hàng tối đa ${OrderRules.maxNote} ký tự.';
        }
        return null;
      case 1:
        if (d.cargoType.isEmpty) return 'Chọn loại hàng.';
        if (d.description.trim().isEmpty) return 'Nhập mô tả hàng hoá.';
        if (d.quantity < 1 || d.weightKg <= 0) return 'Nhập số lượng và khối lượng hàng.';
        if (d.lengthCm <= 0 || d.widthCm <= 0 || d.heightCm <= 0) return 'Nhập kích thước món lớn nhất.';
        if ((cargoNotes(d) ?? '').length > OrderRules.maxSpecialNotes) {
          return 'Mô tả và ghi chú bốc xếp tổng cộng tối đa ${OrderRules.maxSpecialNotes} ký tự.';
        }
        if (d.photos.length < OrderRules.minCargoPhotos) return 'Thêm ít nhất 1 ảnh hàng hoá.';
        return null;
      case 2:
        final v = state.vehicle;
        if (v == null) return 'Chọn loại xe.';
        if (!v.canCarry(d.weightKg, d.lengthCm, d.widthCm, d.heightCm)) return 'Xe đã chọn không chở được hàng này.';
        return null;
      case 3:
        if (!d.noProhibitedCargo || !d.agreedWarranty) {
          return 'Vui lòng đồng ý chính sách bảo hành và cam kết không gửi hàng cấm.';
        }
        if (state.couponError != null) return state.couponError;
        if (state.estimate == null) return state.estimateError ?? 'Đang tính giá, vui lòng đợi.';
        return null;
    }
    return null;
  }

  void goTo(int step) {
    emit(state.copyWith(step: step));
    _scheduleSave();
    if (step >= 2) _scheduleEstimate(immediate: true);
  }

  bool get _readyToEstimate {
    final d = state.draft;
    return state.vehicle != null &&
        InputRules.address(d.pickupAddress) &&
        InputRules.address(d.dropoffAddress) &&
        !InputRules.sameAddress(d.pickupAddress, d.dropoffAddress) &&
        d.weightKg > 0 &&
        d.lengthCm > 0 &&
        d.widthCm > 0 &&
        d.heightCm > 0;
  }

  void _scheduleEstimate({bool immediate = false}) {
    _debounce?.cancel();
    if (!_readyToEstimate) {
      emit(state.copyWith(clearEstimate: true, clearErrors: true));
      return;
    }
    _debounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 600), _estimate);
  }

  Future<FareEstimate> _quote(BookingDraft d, String coupon) => api.fareEstimate(
    vehicleTypeId: d.vehicleTypeId!,
    pickupAddress: d.pickupAddress.trim(),
    dropoffAddress: d.dropoffAddress.trim(),
    weightKg: d.weightKg,
    lengthCm: d.lengthCm,
    widthCm: d.widthCm,
    heightCm: d.heightCm,
    hasLoadingService: d.loadingService,
    couponCode: coupon,
  );

  Future<void> _estimate() async {
    final seq = ++_estimateSeq;
    final d = state.draft;
    emit(state.copyWith(estimating: true, clearErrors: true));
    try {
      final e = await _quote(d, d.couponCode.trim());
      if (seq == _estimateSeq && !isClosed) emit(state.copyWith(estimate: e, estimating: false));
    } catch (e) {
      if (seq != _estimateSeq || isClosed) return;
      final code = e is ApiException ? e.code : null;
      final msg = e is ApiException ? e.message : 'Không tính được giá.';
      if (code != null && code.startsWith('COUPON_')) {
        // Mã không dùng được (ví dụ chưa đủ giá trị tối thiểu): vẫn báo giá không có mã để khách thấy số tiền,
        // thay vì hiện 0 ₫. Lỗi mã vẫn chặn nút đặt đơn cho tới khi bỏ hoặc đổi mã.
        FareEstimate? base;
        try {
          base = await _quote(d, '');
        } catch (_) {
          base = null;
        }
        if (seq != _estimateSeq || isClosed) return;
        emit(state.copyWith(estimating: false, estimate: base, clearEstimate: base == null, couponError: msg));
        return;
      }
      emit(state.copyWith(estimating: false, clearEstimate: true, estimateError: msg));
    }
  }

  /// BE chỉ có một ô ghi chú hàng hoá (≤ 500 ký tự): gộp mô tả và ghi chú bốc xếp, giống web; trống thì gửi null.
  static String? cargoNotes(BookingDraft d) {
    final text = [d.description.trim(), d.specialNotes.trim()].where((s) => s.isNotEmpty).join(' • ');
    return text.isEmpty ? null : text;
  }

  static String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();

  /// POST /customer/Orders. Báo giá lại ngay trước khi gửi (giống web): giá khác số đang hiện thì dừng,
  /// cập nhật giá mới và báo [FareChangedException]; BE vẫn kiểm tra lần nữa bằng expectedTotalFee.
  Future<CreatedOrder> submit() async {
    final d = state.draft;
    final shown = state.estimate?.totalFee;
    emit(state.copyWith(submitting: true));
    try {
      final fresh = await _quote(d, d.couponCode.trim());
      if (shown != null && fresh.totalFee != shown) {
        _estimateSeq++; // bỏ mọi lượt báo giá cũ đang chạy
        emit(state.copyWith(submitting: false, estimate: fresh, clearErrors: true));
        throw FareChangedException(
          'Giá cước vừa thay đổi thành ${money(fresh.totalFee)}. Vui lòng xem lại trước khi đặt.',
        );
      }
      final res = await api.createOrder({
        'vehicleTypeId': d.vehicleTypeId,
        'pickupAddress': d.pickupAddress.trim(),
        'dropoffAddress': d.dropoffAddress.trim(),
        'senderName': d.senderName.trim(),
        'senderPhone': InputRules.normalizePhone(d.senderPhone),
        'pickupNote': _orNull(d.pickupNote),
        'receiverName': d.receiverName.trim(),
        'receiverPhone': InputRules.normalizePhone(d.receiverPhone),
        'dropoffNote': _orNull(d.dropoffNote),
        'cargo': {
          'cargoType': d.cargoType,
          'quantity': d.quantity,
          'weightKg': d.weightKg,
          'lengthCm': d.lengthCm,
          'widthCm': d.widthCm,
          'heightCm': d.heightCm,
          'photoUrls': d.photos,
          'specialNotes': cargoNotes(d),
        },
        'hasLoadingService': d.loadingService,
        'couponCode': d.couponCode.trim().isEmpty ? null : d.couponCode.trim(),
        'paymentMethod': d.paymentMethod,
        'payerRole': d.paymentMethod == 'Cash' ? d.payerRole : null,
        'prohibitedGoodsCommitment': d.noProhibitedCargo,
        'expectedTotalFee': fresh.totalFee.round(),
      });
      _saveTimer?.cancel();
      await store?.clear();
      emit(
        const BookingState().copyWith(
          vehicles: state.vehicles,
          cargoTypes: state.cargoTypes,
          coupons: state.coupons,
          loadingLookups: false,
        ),
      );
      return (id: res.id, code: res.code, total: res.total, payOs: d.paymentMethod == 'PayOS');
    } on FareChangedException {
      rethrow;
    } catch (e) {
      emit(state.copyWith(submitting: false));
      if (e is ApiException && e.code == 'FARE_CHANGED') _scheduleEstimate(immediate: true);
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _saveTimer?.cancel();
    return super.close();
  }
}
