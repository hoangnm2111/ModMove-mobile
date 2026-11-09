import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';
import '../../domain/order_rules.dart';

/// Bản nháp đặt xe (UC-GST-06 → UC-GST-17).
class BookingDraft {
  const BookingDraft({
    this.pickupAddress = '',
    this.senderName = '',
    this.senderPhone = '',
    this.dropoffAddress = '',
    this.receiverName = '',
    this.receiverPhone = '',
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

  final String pickupAddress, senderName, senderPhone, dropoffAddress, receiverName, receiverPhone;
  final String cargoType, description, specialNotes, couponCode, paymentMethod, payerRole;
  final int quantity, lengthCm, widthCm, heightCm;
  final double weightKg;
  final List<String> photos;
  final bool noProhibitedCargo, loadingService, agreedWarranty;
  final int? vehicleTypeId;

  BookingDraft copyWith({
    String? pickupAddress,
    String? senderName,
    String? senderPhone,
    String? dropoffAddress,
    String? receiverName,
    String? receiverPhone,
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
    senderName: senderName ?? this.senderName,
    senderPhone: senderPhone ?? this.senderPhone,
    dropoffAddress: dropoffAddress ?? this.dropoffAddress,
    receiverName: receiverName ?? this.receiverName,
    receiverPhone: receiverPhone ?? this.receiverPhone,
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
}

class BookingState {
  const BookingState({
    this.step = 0,
    this.draft = const BookingDraft(),
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

class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this.api, {BookingDraft? initial}) : super(BookingState(draft: initial ?? const BookingDraft()));
  final CustomerApi api;
  Timer? _debounce;
  int _estimateSeq = 0;

  Future<void> loadLookups() async {
    emit(state.copyWith(loadingLookups: true));
    try {
      final results = await Future.wait([api.vehicleTypes(), api.cargoTypes()]);
      var coupons = const <AvailableCoupon>[];
      try {
        coupons = await api.coupons();
      } catch (_) {}
      final cargo = results[1] as List<LookupItem>;
      emit(state.copyWith(
        vehicles: results[0] as List<VehicleType>,
        cargoTypes: cargo,
        coupons: coupons,
        loadingLookups: false,
        draft: state.draft.cargoType.isEmpty && cargo.isNotEmpty ? state.draft.copyWith(cargoType: cargo.first.code) : null,
      ));
    } catch (e) {
      emit(state.copyWith(loadingLookups: false, lookupError: e is ApiException ? e.message : '$e'));
    }
  }

  void update(BookingDraft Function(BookingDraft d) f) {
    emit(state.copyWith(draft: f(state.draft)));
    _scheduleEstimate();
  }

  /// Lỗi của bước hiện tại (null = hợp lệ).
  String? validate(int step) {
    final d = state.draft;
    switch (step) {
      case 0:
        if (!InputRules.address(d.pickupAddress)) return 'Nhập điểm lấy hàng cụ thể.';
        if (d.senderName.trim().isEmpty || !InputRules.phone(d.senderPhone)) return 'Nhập tên và số điện thoại người gửi hợp lệ.';
        if (!InputRules.address(d.dropoffAddress)) return 'Nhập điểm giao hàng cụ thể.';
        if (d.receiverName.trim().isEmpty || !InputRules.phone(d.receiverPhone)) return 'Nhập tên và số điện thoại người nhận hợp lệ.';
        return null;
      case 1:
        if (d.cargoType.isEmpty) return 'Chọn loại hàng.';
        if (d.quantity < 1 || d.weightKg <= 0) return 'Nhập số lượng và khối lượng hàng.';
        if (d.lengthCm <= 0 || d.widthCm <= 0 || d.heightCm <= 0) return 'Nhập kích thước món lớn nhất.';
        if (d.photos.length < OrderRules.minCargoPhotos) return 'Thêm ít nhất 1 ảnh hàng hoá.';
        if (!d.noProhibitedCargo) return 'Vui lòng cam kết không gửi hàng cấm.';
        return null;
      case 2:
        final v = state.vehicle;
        if (v == null) return 'Chọn loại xe.';
        if (!v.canCarry(d.weightKg, d.lengthCm, d.widthCm, d.heightCm)) return 'Xe đã chọn không chở được hàng này.';
        return null;
      case 3:
        if (!d.agreedWarranty) return 'Vui lòng đồng ý chính sách bảo hành.';
        if (state.couponError != null) return state.couponError;
        if (state.estimate == null) return state.estimateError ?? 'Đang tính giá, vui lòng đợi.';
        return null;
    }
    return null;
  }

  void goTo(int step) {
    emit(state.copyWith(step: step));
    if (step >= 2) _scheduleEstimate(immediate: true);
  }

  void _scheduleEstimate({bool immediate = false}) {
    _debounce?.cancel();
    final d = state.draft;
    final ready = state.vehicle != null &&
        InputRules.address(d.pickupAddress) &&
        InputRules.address(d.dropoffAddress) &&
        d.weightKg > 0 &&
        d.lengthCm > 0 &&
        d.widthCm > 0 &&
        d.heightCm > 0;
    if (!ready) {
      emit(state.copyWith(clearEstimate: true, clearErrors: true));
      return;
    }
    _debounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 600), _estimate);
  }

  Future<void> _estimate() async {
    final seq = ++_estimateSeq;
    final d = state.draft;
    emit(state.copyWith(estimating: true, clearErrors: true));
    try {
      final e = await api.fareEstimate(
        vehicleTypeId: d.vehicleTypeId!,
        pickupAddress: d.pickupAddress.trim(),
        dropoffAddress: d.dropoffAddress.trim(),
        weightKg: d.weightKg,
        lengthCm: d.lengthCm,
        widthCm: d.widthCm,
        heightCm: d.heightCm,
        hasLoadingService: d.loadingService,
        couponCode: d.couponCode.trim(),
      );
      if (seq == _estimateSeq && !isClosed) emit(state.copyWith(estimate: e, estimating: false));
    } catch (e) {
      if (seq != _estimateSeq || isClosed) return;
      final code = e is ApiException ? e.code : null;
      final msg = e is ApiException ? e.message : 'Không tính được giá.';
      emit(state.copyWith(
        estimating: false,
        clearEstimate: true,
        couponError: code != null && code.startsWith('COUPON_') ? msg : null,
        estimateError: code != null && code.startsWith('COUPON_') ? null : msg,
      ));
    }
  }

  /// UC-GST-17: POST /customer/Orders kèm expectedTotalFee (FARE_CHANGED nếu giá đổi).
  Future<CreatedOrder> submit() async {
    final d = state.draft;
    emit(state.copyWith(submitting: true));
    try {
      final res = await api.createOrder({
        'vehicleTypeId': d.vehicleTypeId,
        'pickupAddress': d.pickupAddress.trim(),
        'dropoffAddress': d.dropoffAddress.trim(),
        'receiverName': d.receiverName.trim(),
        'receiverPhone': d.receiverPhone.trim(),
        'cargo': {
          'cargoType': d.cargoType,
          'quantity': d.quantity,
          'weightKg': d.weightKg,
          'lengthCm': d.lengthCm,
          'widthCm': d.widthCm,
          'heightCm': d.heightCm,
          'photoUrls': d.photos,
          'specialNotes': [d.description.trim(), d.specialNotes.trim()].where((s) => s.isNotEmpty).join(' • ').isEmpty
              ? null
              : [d.description.trim(), d.specialNotes.trim()].where((s) => s.isNotEmpty).join(' • '),
        },
        'hasLoadingService': d.loadingService,
        'couponCode': d.couponCode.trim().isEmpty ? null : d.couponCode.trim(),
        'paymentMethod': d.paymentMethod,
        'payerRole': d.paymentMethod == 'Cash' ? d.payerRole : null,
        'prohibitedGoodsCommitment': d.noProhibitedCargo,
        'expectedTotalFee': state.estimate?.totalFee.round(),
      });
      emit(const BookingState().copyWith(vehicles: state.vehicles, cargoTypes: state.cargoTypes, coupons: state.coupons, loadingLookups: false));
      return (id: res.id, code: res.code, total: res.total, payOs: d.paymentMethod == 'PayOS');
    } catch (e) {
      emit(state.copyWith(submitting: false));
      if (e is ApiException && e.code == 'FARE_CHANGED') _scheduleEstimate(immediate: true);
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
