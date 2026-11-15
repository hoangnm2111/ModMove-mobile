// Model khớp 1-1 với DTO backend (dịch từ ModMove-web/src/api/types.ts).
// Pure Dart: không phụ thuộc Flutter hay tầng data.

double _d(Object? v) => v == null ? 0 : (v as num).toDouble();
double? _dn(Object? v) => v == null ? null : (v as num).toDouble();
int _i(Object? v) => v == null ? 0 : (v as num).toInt();
int? _in(Object? v) => v == null ? null : (v as num).toInt();
String _s(Object? v) => v as String? ?? '';
DateTime _dt(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dtn(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
List<String> _sl(Object? v) => v == null ? const [] : (v as List).map((e) => '$e').toList();
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) => v == null ? const [] : (v as List).map((e) => f(e as Map<String, dynamic>)).toList();

/// PagedResult `{ items, pageNumber, pageSize, totalCount }`.
class Paged<T> {
  const Paged(this.items, this.pageNumber, this.pageSize, this.totalCount);
  final List<T> items;
  final int pageNumber, pageSize, totalCount;
  bool get hasMore => pageNumber * pageSize < totalCount;

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) f) => Paged(_list(j['items'], f), _i(j['pageNumber']), _i(j['pageSize']), _i(j['totalCount']));
}

/// Các trạng thái đơn (backend enum là chuỗi).
abstract final class OrderStatus {
  static const pending = 'Pending',
      accepted = 'Accepted',
      arrived = 'Arrived',
      pickedUp = 'PickedUp',
      inTransit = 'InTransit',
      delivered = 'Delivered',
      completed = 'Completed',
      cancelled = 'Cancelled';
  static const flow = [pending, accepted, arrived, pickedUp, inTransit, delivered, completed];
  static const trackable = [accepted, arrived, pickedUp, inTransit];
}

/* ------------------------------------------------------------ Public */
class VehicleType {
  const VehicleType({
    required this.id,
    required this.name,
    required this.maxLoadWeightKg,
    required this.bedLengthCm,
    required this.bedWidthCm,
    required this.bedHeightCm,
    required this.baseFare,
    required this.pricePerKm,
    required this.minimumFare,
  });
  final int id, bedLengthCm, bedWidthCm, bedHeightCm;
  final String name;
  final double maxLoadWeightKg, baseFare, pricePerKm, minimumFare;

  factory VehicleType.fromJson(Map<String, dynamic> j) => VehicleType(
    id: _i(j['id']),
    name: _s(j['name']),
    maxLoadWeightKg: _d(j['maxLoadWeightKg']),
    bedLengthCm: _i(j['cargoBedLengthCm']),
    bedWidthCm: _i(j['cargoBedWidthCm']),
    bedHeightCm: _i(j['cargoBedHeightCm']),
    baseFare: _d(j['baseFare']),
    pricePerKm: _d(j['pricePerKm']),
    minimumFare: _d(j['minimumFare']),
  );

  /// GB-10: tổng KL ≤ tải trọng; món lớn nhất lọt thùng khi xoay (so 3 cạnh đã sắp xếp).
  bool canCarry(double weightKg, int l, int w, int h) {
    if (weightKg > maxLoadWeightKg) return false;
    final item = [l, w, h]..sort();
    final bed = [bedLengthCm, bedWidthCm, bedHeightCm]..sort();
    for (var k = 0; k < 3; k++) {
      if (item[k] > bed[k]) return false;
    }
    return true;
  }
}

/// Mục danh mục / nội dung public `{ code, name, description }`.
class LookupItem {
  const LookupItem(this.code, this.name, this.description);
  final String code, name;
  final String? description;
  factory LookupItem.fromJson(Map<String, dynamic> j) => LookupItem(_s(j['code']), _s(j['name']), j['description'] as String?);
}

class FareEstimate {
  const FareEstimate(this.distanceKm, this.durationMinutes, this.distanceFee, this.serviceFee, this.discountAmount, this.totalFee);
  final double distanceKm, distanceFee, serviceFee, discountAmount, totalFee;
  final int durationMinutes;
  factory FareEstimate.fromJson(Map<String, dynamic> j) =>
      FareEstimate(_d(j['distanceKm']), _i(j['durationMinutes']), _d(j['distanceFee']), _d(j['serviceFee']), _d(j['discountAmount']), _d(j['totalFee']));
}

class AvailableCoupon {
  const AvailableCoupon(this.code, this.discountValue, this.minimumOrderValue, this.expiresAt, this.remainingUses);
  final String code;
  final double discountValue, minimumOrderValue;
  final DateTime expiresAt;
  final int? remainingUses;
  factory AvailableCoupon.fromJson(Map<String, dynamic> j) => AvailableCoupon(_s(j['discountCode']), _d(j['discountValue']), _d(j['minimumOrderValue']), _dt(j['expiresAt']), _in(j['remainingUses']));
}

/* ------------------------------------------------------------ Orders */
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.vehicleTypeName,
    required this.totalFee,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    required this.receiverName,
    required this.receiverPhone,
  });
  final int id;
  final String code, status, pickupAddress, dropoffAddress, vehicleTypeName, paymentMethod, paymentStatus, receiverName, receiverPhone;
  final double totalFee;
  final DateTime createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
    id: _i(j['id']),
    code: _s(j['orderCode']),
    status: _s(j['orderStatus']),
    pickupAddress: _s(j['pickupAddress']),
    dropoffAddress: _s(j['dropoffAddress']),
    vehicleTypeName: _s(j['vehicleTypeName']),
    totalFee: _d(j['totalFee']),
    paymentMethod: _s(j['paymentMethod']),
    paymentStatus: _s(j['paymentStatus']),
    createdAt: _dt(j['createdAt']),
    receiverName: _s(j['receiverName']),
    receiverPhone: _s(j['receiverPhone']),
  );
}

class Cargo {
  const Cargo(this.cargoType, this.cargoTypeName, this.quantity, this.weightKg, this.lengthCm, this.widthCm, this.heightCm, this.photoUrls, this.specialNotes);
  final String cargoType;
  final String? cargoTypeName, specialNotes;
  final int quantity, lengthCm, widthCm, heightCm;
  final double weightKg;
  final List<String> photoUrls;
  factory Cargo.fromJson(Map<String, dynamic> j) => Cargo(
    _s(j['cargoType']),
    j['cargoTypeName'] as String?,
    _i(j['quantity']),
    _d(j['weightKg']),
    _i(j['lengthCm']),
    _i(j['widthCm']),
    _i(j['heightCm']),
    _sl(j['photoUrls']),
    j['specialNotes'] as String?,
  );
}

class OrderDriver {
  const OrderDriver(this.fullName, this.phoneNumber, this.licensePlate);
  final String fullName, phoneNumber;
  final String? licensePlate;
  factory OrderDriver.fromJson(Map<String, dynamic> j) => OrderDriver(_s(j['fullName']), _s(j['phoneNumber']), j['licensePlate'] as String?);
}

class OrderProof {
  const OrderProof(this.pickupPhotoUrls, this.proofStatus, this.submissionCount, this.rejectionReason, this.deliveryPhotoUrl, this.deliveredAt);
  final List<String> pickupPhotoUrls;
  final String proofStatus; // Pending | Verified | Rejected
  final int submissionCount;
  final String? rejectionReason, deliveryPhotoUrl;
  final DateTime? deliveredAt;
  factory OrderProof.fromJson(Map<String, dynamic> j) =>
      OrderProof(_sl(j['pickupPhotoUrls']), _s(j['proofStatus']), _i(j['pickupSubmissionCount']), j['rejectionReason'] as String?, j['deliveryPhotoUrl'] as String?, _dtn(j['deliveredAt']));
}

class StatusHistory {
  const StatusHistory(this.fromStatus, this.toStatus, this.changedByRole, this.note, this.changedAt);
  final String? fromStatus, note;
  final String toStatus, changedByRole;
  final DateTime changedAt;
  factory StatusHistory.fromJson(Map<String, dynamic> j) => StatusHistory(j['fromStatus'] as String?, _s(j['toStatus']), _s(j['changedByRole']), j['note'] as String?, _dt(j['changedAt']));
}

class OrderPayment {
  const OrderPayment(this.transactionStatus, this.checkoutUrl, this.expiresAt, this.paidAt, this.isExpired);
  final String transactionStatus;
  final String? checkoutUrl;
  final DateTime? expiresAt, paidAt;
  final bool isExpired;
  factory OrderPayment.fromJson(Map<String, dynamic> j) =>
      OrderPayment(_s(j['transactionStatus']), j['checkoutUrl'] as String?, _dtn(j['expiresAt']), _dtn(j['paidAt']), j['isExpired'] as bool? ?? false);
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.code,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.vehicleTypeName,
    required this.receiverName,
    required this.receiverPhone,
    required this.distanceKm,
    required this.durationMin,
    required this.hasLoadingService,
    required this.distanceFee,
    required this.serviceFee,
    required this.discountAmount,
    required this.totalFee,
    required this.paymentMethod,
    required this.payerRole,
    required this.paymentStatus,
    required this.createdAt,
    required this.cargo,
    required this.driver,
    required this.proof,
    required this.history,
    required this.couponCode,
    required this.payment,
    this.pendingDriverIncidentId,
  });

  /// Sự cố do tài xế báo còn mở: chuyến tạm dừng, khách chưa duyệt được ảnh lấy hàng (null = không chặn).
  final int? pendingDriverIncidentId;
  final int id, durationMin;
  final String code, status, pickupAddress, dropoffAddress, vehicleTypeName, receiverName, receiverPhone, paymentMethod, paymentStatus;
  final String? payerRole, couponCode;
  final double distanceKm, distanceFee, serviceFee, discountAmount, totalFee;
  final bool hasLoadingService;
  final DateTime createdAt;
  final Cargo cargo;
  final OrderDriver? driver;
  final OrderProof? proof;
  final List<StatusHistory> history;
  final OrderPayment? payment;

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
    pendingDriverIncidentId: j['pendingDriverIncidentId'] == null ? null : _i(j['pendingDriverIncidentId']),
    id: _i(j['id']),
    code: _s(j['orderCode']),
    status: _s(j['orderStatus']),
    pickupAddress: _s(j['pickupAddress']),
    dropoffAddress: _s(j['dropoffAddress']),
    vehicleTypeName: _s(j['vehicleTypeName']),
    receiverName: _s(j['receiverName']),
    receiverPhone: _s(j['receiverPhone']),
    distanceKm: _d(j['estimatedDistanceKm']),
    durationMin: _i(j['estimatedDurationMin']),
    hasLoadingService: j['hasLoadingService'] as bool? ?? false,
    distanceFee: _d(j['distanceFee']),
    serviceFee: _d(j['serviceFee']),
    discountAmount: _d(j['discountAmount']),
    totalFee: _d(j['totalFee']),
    paymentMethod: _s(j['paymentMethod']),
    payerRole: j['payerRole'] as String?,
    paymentStatus: _s(j['paymentStatus']),
    createdAt: _dt(j['createdAt']),
    cargo: Cargo.fromJson(j['cargo'] as Map<String, dynamic>),
    driver: j['driver'] == null ? null : OrderDriver.fromJson(j['driver'] as Map<String, dynamic>),
    proof: j['proof'] == null ? null : OrderProof.fromJson(j['proof'] as Map<String, dynamic>),
    history: _list(j['history'], StatusHistory.fromJson),
    couponCode: j['couponCode'] as String?,
    payment: j['payment'] == null ? null : OrderPayment.fromJson(j['payment'] as Map<String, dynamic>),
  );
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;
  factory GeoPoint.fromJson(Map<String, dynamic> j) => GeoPoint(_d(j['latitude']), _d(j['longitude']));
}

class OrderTracking {
  const OrderTracking(this.orderStatus, this.pickup, this.dropoff, this.driver, this.driverAt, this.driverStale, this.etaTarget, this.etaMinutes);
  final String orderStatus;
  final GeoPoint pickup, dropoff;
  final GeoPoint? driver;
  final DateTime? driverAt;
  final bool driverStale;
  final String? etaTarget; // Pickup | Handover | Dropoff
  final int? etaMinutes;

  factory OrderTracking.fromJson(Map<String, dynamic> j) {
    final d = j['driver'] as Map<String, dynamic>?;
    final eta = j['eta'] as Map<String, dynamic>?;
    return OrderTracking(
      _s(j['orderStatus']),
      GeoPoint.fromJson(j['pickup'] as Map<String, dynamic>),
      GeoPoint.fromJson(j['dropoff'] as Map<String, dynamic>),
      d == null ? null : GeoPoint.fromJson(d),
      d == null ? null : _dtn(d['at']),
      d?['isStale'] as bool? ?? false,
      eta?['target'] as String?,
      eta == null ? null : _in(eta['durationMinutes']),
    );
  }
}

class PaymentSession {
  const PaymentSession(this.transactionId, this.checkoutUrl, this.amount, this.expiresAt);
  final int transactionId;
  final String checkoutUrl;
  final double amount;
  final DateTime expiresAt;
  factory PaymentSession.fromJson(Map<String, dynamic> j) => PaymentSession(_i(j['transactionId']), _s(j['checkoutUrl']), _d(j['amount']), _dt(j['expiresAt']));
}

/* ------------------------------------------------------------ Ratings / incidents / refunds */
class MyRating {
  const MyRating(this.id, this.orderId, this.orderCode, this.stars, this.comment, this.driverName, this.createdAt);
  final int id, orderId, stars;
  final String orderCode, driverName;
  final String? comment;
  final DateTime createdAt;
  factory MyRating.fromJson(Map<String, dynamic> j) =>
      MyRating(_i(j['id']), _i(j['orderId']), _s(j['orderCode']), _i(j['ratingStars']), j['reviewComment'] as String?, _s(j['driverName']), _dt(j['createdAt']));
}

class MyIncident {
  const MyIncident({
    required this.id,
    required this.orderId,
    required this.incidentType,
    required this.description,
    required this.photoUrls,
    required this.reportedByYou,
    required this.status,
    required this.decision,
    required this.note,
    required this.createdAt,
    required this.resolvedAt,
  });
  final int id, orderId;
  final String incidentType, description, status;
  final List<String> photoUrls;
  final bool reportedByYou;
  final String? decision, note;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  factory MyIncident.fromJson(Map<String, dynamic> j) => MyIncident(
    id: _i(j['id']),
    orderId: _i(j['orderId']),
    incidentType: _s(j['incidentType']),
    description: _s(j['description']),
    photoUrls: _sl(j['photoUrls']),
    reportedByYou: j['reportedByYou'] as bool? ?? false,
    status: _s(j['resolutionStatus']),
    decision: j['resolutionDecision'] as String?,
    note: j['resolutionNote'] as String?,
    createdAt: _dt(j['createdAt']),
    resolvedAt: _dtn(j['resolvedAt']),
  );
}

/// Tài khoản nhận hoàn tiền như khách nhìn thấy: số tài khoản luôn bị che (BE: PayoutAccountView).
class PayoutAccountView {
  const PayoutAccountView(this.bankName, this.maskedAccountNumber, this.accountHolder);
  final String bankName, maskedAccountNumber, accountHolder;
  static PayoutAccountView? from(Object? json) {
    if (json is! Map) return null;
    final j = json.cast<String, dynamic>();
    return PayoutAccountView(_s(j['bankName']), _s(j['maskedAccountNumber']), _s(j['accountHolder']));
  }
}

/// Tài khoản nhận hoàn tiền khách nhập (BE: PayoutAccountInput). `bankCode` lấy từ lookups/banks.
class PayoutAccountInput {
  const PayoutAccountInput({required this.bankCode, required this.accountNumber, required this.accountHolder}) : useSuggested = false;

  /// FE-07: dùng tài khoản đã thanh toán PayOS cho đơn (BE tự chép, app không gửi lại số tài khoản).
  const PayoutAccountInput.suggested() : bankCode = '', accountNumber = '', accountHolder = '', useSuggested = true;
  final String bankCode, accountNumber, accountHolder;
  final bool useSuggested;

  Map<String, Object?> toJson() => useSuggested
      ? {'useSuggested': true, 'bankCode': null, 'accountNumber': null, 'accountHolder': null}
      : {'useSuggested': false, 'bankCode': bankCode, 'accountNumber': accountNumber, 'accountHolder': accountHolder};

  /// Chữ in hoa không dấu, chỉ A–Z và dấu cách (yêu cầu của ngân hàng).
  static String normalizeHolder(String text) {
    const groups = {'a': 'àáạảãâầấậẩẫăằắặẳẵ', 'e': 'èéẹẻẽêềếệểễ', 'i': 'ìíịỉĩ', 'o': 'òóọỏõôồốộổỗơờớợởỡ', 'u': 'ùúụủũưừứựửữ', 'y': 'ỳýỵỷỹ', 'd': 'đ'};
    final out = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      var mapped = ch;
      groups.forEach((plain, accented) {
        if (accented.contains(ch)) mapped = plain;
      });
      out.write(mapped);
    }
    return out.toString().toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), '');
  }

  /// Câu báo lỗi tiếng Việt hoặc null nếu hợp lệ (khớp validator của BE).
  static String? validate({required String? bankCode, required String number, required String holder}) {
    if (bankCode == null || bankCode.isEmpty) return 'Chọn ngân hàng nhận tiền hoàn.';
    if (!RegExp(r'^\d{6,19}$').hasMatch(number)) return 'Số tài khoản gồm 6 đến 19 chữ số.';
    final h = holder.trim();
    if (h.length < 2 || h.length > 100) return 'Tên chủ tài khoản từ 2 đến 100 ký tự.';
    return null;
  }
}

class MyRefund {
  const MyRefund({
    required this.id,
    required this.orderId,
    required this.sourceType,
    required this.status,
    required this.requestedAmount,
    required this.approvedAmount,
    required this.decisionReason,
    required this.waitingForYourReply,
    required this.createdAt,
    this.reason = '',
    this.evidenceUrls = const [],
    this.infoRequestNote,
    this.customerReply,
    this.processedAt,
    this.needsPayoutAccount = false,
    this.payoutAccount,
    this.payoutFailureReason,
    this.bankReferenceCode,
    this.suggestedPayoutAccount,
    this.incidentId,
  });

  /// Chỉ có ở chi tiết khoản hoàn (GET /customer/Refunds/{id}): sự cố mà khoản hoàn do sự cố thuộc về.
  final int? incidentId;
  final bool needsPayoutAccount;
  final PayoutAccountView? payoutAccount;

  /// Tài khoản đã thanh toán PayOS cho đơn (số đã che), BE gợi ý khi khoản hoàn cần tài khoản nhận.
  final PayoutAccountView? suggestedPayoutAccount;
  final String? payoutFailureReason, bankReferenceCode;
  final int id, orderId;
  final String sourceType, status, reason;
  final double requestedAmount;
  final double? approvedAmount;
  final String? decisionReason, infoRequestNote, customerReply;
  final bool waitingForYourReply;
  final DateTime createdAt;
  final DateTime? processedAt;
  final List<String> evidenceUrls;

  /// Dùng cho cả GET /customer/Refunds (tóm tắt) và /customer/Refunds/{id} (chi tiết).
  factory MyRefund.fromJson(Map<String, dynamic> j) => MyRefund(
    id: _i(j['id']),
    orderId: _i(j['orderId']),
    sourceType: _s(j['sourceType']),
    status: _s(j['refundStatus']),
    requestedAmount: _d(j['requestedAmount']),
    approvedAmount: _dn(j['approvedAmount']),
    decisionReason: j['decisionReason'] as String?,
    waitingForYourReply: j['waitingForYourReply'] as bool? ?? false,
    createdAt: _dt(j['createdAt']),
    reason: _s(j['reason']),
    evidenceUrls: _sl(j['evidenceUrls']),
    infoRequestNote: j['infoRequestNote'] as String?,
    customerReply: j['customerReply'] as String?,
    processedAt: _dtn(j['processedAt']),
    needsPayoutAccount: j['needsPayoutAccount'] as bool? ?? false,
    payoutAccount: PayoutAccountView.from(j['payoutAccount']),
    payoutFailureReason: j['payoutFailureReason'] as String?,
    bankReferenceCode: j['bankReferenceCode'] as String?,
    suggestedPayoutAccount: PayoutAccountView.from(j['suggestedPayoutAccount']),
    incidentId: j['incidentId'] == null ? null : _i(j['incidentId']),
  );

  /// Khoản hoàn còn đang xử lý (BE chỉ cho một yêu cầu mở cho mỗi sự cố).
  bool get isOpen => status == 'Requested' || status == 'Approved' || status == 'Failed';
}

class Profile {
  const Profile(this.id, this.fullName, this.phoneNumber, this.email, this.role);
  final int id;
  final String fullName, phoneNumber, email, role;
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(_i(j['id']), _s(j['fullName']), _s(j['phoneNumber']), _s(j['email']), _s(j['role']));
}
