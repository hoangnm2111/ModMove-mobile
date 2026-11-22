import 'entities/customer_models.dart';

/// Luật nghiệp vụ phía khách (dịch từ ModMove-web, DECISIONS/GB trong SRS).
abstract final class OrderRules {
  static const complaintWindow = Duration(hours: 24); // GB-18
  static const autoCompleteAfter = Duration(hours: 24); // GB-23
  static const ratingWindow = Duration(days: 1); // GB-20
  static const unpaidCancelAfter = Duration(minutes: 30); // GB-13
  static const maxCargoPhotos = 5, minCargoPhotos = 1; // GB-06
  static const maxEvidencePhotos = 5; // GB-43
  static const maxPhotoBytes = 5 * 1024 * 1024;
  static const maxSpecialNotes = 500; // validator tạo đơn của BE

  /// GB-31: đơn PayOS chưa thanh toán vẫn ở Pending nhưng CHƯA gửi tới tài xế.
  static bool awaitingPayment(String status, String paymentMethod, String paymentStatus) => status == OrderStatus.pending && paymentMethod == 'PayOS' && paymentStatus == 'Unpaid';

  /// GB-22: khách tự huỷ miễn phí khi Pending/Accepted.
  static bool canCancel(OrderDetail o) => o.status == OrderStatus.pending || o.status == OrderStatus.accepted;

  /// Khách báo sự cố khi Arrived/PickedUp/InTransit (2.2).
  static bool canReportIncident(OrderDetail o) => [OrderStatus.arrived, OrderStatus.pickedUp, OrderStatus.inTransit].contains(o.status);

  /// GB-26: duyệt ảnh lấy hàng khi PickedUp và ảnh đang chờ duyệt.
  static bool pickupReviewPending(OrderDetail o) => o.status == OrderStatus.pickedUp && o.proof?.proofStatus == 'Pending';

  /// Tài xế đang có sự cố mở: BE từ chối duyệt ảnh lấy hàng (INCIDENT_PENDING); từ chối ảnh thì vẫn được.
  static bool canApprovePickup(OrderDetail o) => o.pendingDriverIncidentId == null;

  static DateTime? reachedAt(OrderDetail o, String status) {
    for (final h in o.history.reversed) {
      if (h.toStatus == status) return h.changedAt;
    }
    return status == OrderStatus.pending ? o.createdAt : null;
  }

  static DateTime? deliveredAt(OrderDetail o) => o.proof?.deliveredAt ?? reachedAt(o, OrderStatus.delivered);

  /// Hạn khiếu nại / tự hoàn tất (Delivered + 24h).
  static DateTime? complaintDeadline(OrderDetail o) => deliveredAt(o)?.add(complaintWindow);

  static DateTime? ratingDeadline(OrderDetail o) => reachedAt(o, OrderStatus.completed)?.add(ratingWindow);

  /// Đơn PayOS chưa trả bị huỷ sau 30 phút kể từ lúc tạo.
  static DateTime unpaidDeadline(OrderDetail o) => o.createdAt.add(unpaidCancelAfter);

  /// Hoàn tiền sự cố chỉ cho đơn PayOS đã thanh toán (REFUND_NOT_ALLOWED).
  static bool canRequestIncidentRefund(OrderDetail o) => o.paymentMethod == 'PayOS' && o.paymentStatus == 'Paid';

  /// Khiếu nại đang mở = Requested hoặc Approved (7.3).
  static bool hasOpenComplaint(Iterable<MyRefund> refunds) => refunds.any((r) => r.sourceType == 'Complaint' && (r.status == 'Requested' || r.status == 'Approved'));

  /// Rút được khi còn Requested và không phải hoàn do huỷ.
  static bool canWithdrawRefund(MyRefund r) => r.status == 'Requested' && r.sourceType != 'Cancellation';
}

/// Kiểm tra dữ liệu nhập (dịch từ bookingValidation.ts / domain/validators).
abstract final class InputRules {
  static final _phone = RegExp(r'^(0|\+84)[0-9]{9,10}$');
  static bool phone(String v) => _phone.hasMatch(v.replaceAll(' ', ''));
  /// BE chỉ nhận email gồm ký tự ASCII in được (không dấu tiếng Việt).
  static bool email(String v) => RegExp(r'^[\x21-\x3F\x41-\x7E]+@[\x21-\x3F\x41-\x7E]+\.[\x21-\x3F\x41-\x7E]+$').hasMatch(v.trim());

  /// Địa chỉ: backend tự geocode bằng MapVina, chỉ cần đủ cụ thể.
  static bool address(String v) => v.trim().length >= 5;

  /// GB-53
  /// GB-53 (K-13): mật khẩu mới 8–20 ký tự.
  static bool password(String v) => v.length >= 8 && v.length <= 20;

  /// Ô đăng nhập vẫn nhận tới 100 ký tự để tài khoản cũ không bị chặn (BE A-04).
  static bool loginPassword(String v) => v.length >= 8 && v.length <= 100;
}
