import '../../../core/config/platform_config.dart';
import 'entities/customer_models.dart';

/// Luật nghiệp vụ phía khách. Các giới hạn và thời hạn lấy từ BE (`AppRules`, `GET /public/Config`), không giữ bản sao ở đây.
abstract final class OrderRules {
  static PlatformRules get _r => AppRules.rules;

  static Duration get complaintWindow => Duration(hours: _r.complaintWindowHours); // GB-18
  static Duration get autoCompleteAfter => Duration(hours: _r.autoCompleteHours); // GB-23
  static Duration get ratingWindow => Duration(hours: _r.ratingWindowHours); // GB-20
  static Duration get unpaidCancelAfter => Duration(minutes: _r.unpaidPaymentMinutes); // GB-13
  static int get maxCargoPhotos => _r.maxCargoPhotos; // GB-06
  static int get maxEvidencePhotos => _r.maxEvidencePhotos; // GB-43
  static int get maxPhotoBytes => _r.maxPhotoSizeMb * 1024 * 1024;
  static int get maxPhotoMb => _r.maxPhotoSizeMb;

  /// BE bắt buộc ít nhất 1 ảnh hàng hoá (validator tạo đơn).
  static const minCargoPhotos = 1;

  /// Ghi chú hàng hoá (mô tả + ghi chú bốc xếp) và ghi chú từng điểm: BE cũng kiểm tra lại.
  static int get maxSpecialNotes => _r.maxOrderNoteLength;
  static int get maxNote => _r.maxOrderNoteLength;

  /// Độ dài tên liên hệ: BE giới hạn 100 ký tự (cột `varchar(100)`), không đổi theo cấu hình.
  static const maxContactName = 100;

  /// GB-31: đơn PayOS chưa thanh toán vẫn ở Pending nhưng CHƯA gửi tới tài xế.
  static bool awaitingPayment(String status, String paymentMethod, String paymentStatus) =>
      status == OrderStatus.pending && paymentMethod == 'PayOS' && paymentStatus == 'Unpaid';

  /// GB-22: khách tự huỷ miễn phí khi Pending/Accepted.
  static bool canCancel(OrderDetail o) => o.status == OrderStatus.pending || o.status == OrderStatus.accepted;

  /// Khách báo sự cố khi Arrived/PickedUp/InTransit (2.2).
  static bool canReportIncident(OrderDetail o) =>
      [OrderStatus.arrived, OrderStatus.pickedUp, OrderStatus.inTransit].contains(o.status);

  /// GB-26: duyệt ảnh lấy hàng khi PickedUp và ảnh đang chờ duyệt.
  static bool pickupReviewPending(OrderDetail o) =>
      o.status == OrderStatus.pickedUp && o.proof?.proofStatus == 'Pending';

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
  static bool hasOpenComplaint(Iterable<MyRefund> refunds) =>
      refunds.any((r) => r.sourceType == 'Complaint' && (r.status == 'Requested' || r.status == 'Approved'));

  /// Rút được khi còn Requested và không phải hoàn do huỷ.
  static bool canWithdrawRefund(MyRefund r) => r.status == 'Requested' && r.sourceType != 'Cancellation';
}

/// Kiểm tra dữ liệu nhập (dịch từ bookingValidation.ts / domain/validators).
abstract final class InputRules {
  /// Số di động Việt Nam: 0 hoặc +84, rồi đầu số 3, 5, 7, 8, 9 và 8 chữ số (giống web).
  static final _phone = RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$');
  static bool phone(String v) => _phone.hasMatch(v.replaceAll(RegExp(r'[\s.]'), ''));

  /// BE nhận dạng 0xxxxxxxxx: bỏ khoảng trắng, dấu chấm, đổi +84 thành 0.
  static String normalizePhone(String v) => v.replaceAll(RegExp(r'[\s.]'), '').replaceFirst(RegExp(r'^\+84'), '0');

  /// Hai địa chỉ giống nhau (không phân biệt hoa thường, bỏ khoảng trắng hai đầu).
  static bool sameAddress(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

  /// BE chỉ nhận email gồm ký tự ASCII in được (không dấu tiếng Việt).
  static bool email(String v) =>
      RegExp(r'^[\x21-\x3F\x41-\x7E]+@[\x21-\x3F\x41-\x7E]+\.[\x21-\x3F\x41-\x7E]+$').hasMatch(v.trim());

  /// Địa chỉ: backend tự geocode bằng MapVina, chỉ cần đủ cụ thể.
  static bool address(String v) => v.trim().length >= 5;

  /// GB-53
  /// GB-53 (K-13): mật khẩu mới 8–20 ký tự.
  static bool password(String v) => v.length >= AppRules.rules.passwordMinLength && v.length <= AppRules.rules.passwordMaxLength;

  /// Câu nhắc độ dài mật khẩu, theo số thật của BE.
  static String get passwordHint => 'từ ${AppRules.rules.passwordMinLength} đến ${AppRules.rules.passwordMaxLength} ký tự';

  /// Ô đăng nhập vẫn nhận tới 100 ký tự để tài khoản cũ không bị chặn (BE A-04).
  static bool loginPassword(String v) => v.length >= AppRules.rules.passwordMinLength && v.length <= 100;
}
