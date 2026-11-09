/// Lỗi từ backend (ProblemDetails `{ status, title, detail, code, errors }`).
/// App rẽ nhánh theo [code] ổn định, không theo `detail` tiếng Anh (DECISIONS 9.4).
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.status});
  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => message;

  /// Tạo từ thân lỗi JSON của backend.
  factory ApiException.fromProblem(int status, Map<String, dynamic>? body) {
    final code = body?['code'] as String?;
    final errors = body?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      final text = first is List && first.isNotEmpty ? '${first.first}' : '$first';
      return ApiException(text, code: code ?? 'VALIDATION', status: status);
    }
    final known = code == null ? null : errorMessages[code];
    if (known != null) {
      final detail = body?['detail'] as String?;
      final withDetail = (code == 'FARE_CHANGED' || code == 'REFUND_TOTAL_EXCEEDED') && detail != null;
      return ApiException(withDetail ? '$known ($detail)' : known, code: code, status: status);
    }
    final fallback = (body?['detail'] ?? body?['title']) as String?;
    return ApiException(
      fallback ?? (status == 401 ? errorMessages['UNAUTHORIZED']! : 'Đã có lỗi xảy ra (HTTP $status).'),
      code: code,
      status: status,
    );
  }

  static const network = ApiException(
    'Không kết nối được tới máy chủ. Kiểm tra mạng hoặc địa chỉ API rồi thử lại.',
    code: 'NETWORK',
  );
}

/// Bảng mã lỗi → câu tiếng Việt (ModMove-backend/docs/api/README.md "Mã lỗi").
const errorMessages = <String, String>{
  'VALIDATION': 'Dữ liệu chưa hợp lệ. Vui lòng kiểm tra lại.',
  'UNAUTHORIZED': 'Sai thông tin đăng nhập hoặc phiên đã hết hạn.',
  'FORBIDDEN': 'Bạn không có quyền thực hiện thao tác này.',
  'EMAIL_NOT_VERIFIED': 'Email chưa được xác minh. Vui lòng nhập mã OTP đã gửi tới email.',
  'ACCOUNT_INACTIVE': 'Tài khoản đã bị khoá hoặc vô hiệu hoá. Liên hệ hỗ trợ.',
  'NOT_FOUND': 'Không tìm thấy dữ liệu.',
  'CONFLICT': 'Dữ liệu vừa bị thay đổi hoặc bị trùng. Vui lòng tải lại rồi thử lại.',
  'TOO_MANY_REQUESTS': 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
  'BUSINESS_RULE': 'Thao tác không được phép ở trạng thái hiện tại.',
  'OTP_INVALID': 'Mã OTP sai, hết hạn hoặc đã dùng. Hãy xin mã mới.',
  'VERIFY_PASSWORD_MISMATCH': 'Mã đúng nhưng mật khẩu không khớp với mật khẩu đã đăng ký. Hãy dùng "Quên mật khẩu".',
  'WRONG_PASSWORD': 'Mật khẩu hiện tại không đúng.',
  'ACCOUNT_HAS_OPEN_ORDERS': 'Không thể xoá tài khoản khi còn đơn hàng chưa hoàn tất.',
  'ACCOUNT_HAS_OPEN_REFUNDS': 'Không thể xoá tài khoản khi còn yêu cầu hoàn tiền đang mở.',
  'COMPLAINT_OPEN': 'Đơn đang có khiếu nại mở, chưa thể xác nhận nhận hàng.',
  'ORDER_NOT_CANCELLABLE': 'Đơn không còn huỷ được. Hãy báo sự cố.',
  'ORDER_NOT_YOURS': 'Đơn hàng không thuộc tài khoản của bạn.',
  'ORDER_CANCELLED': 'Đơn hàng đã bị huỷ.',
  'RATING_NOT_ALLOWED': 'Chỉ đánh giá được đơn đã hoàn thành.',
  'RATING_WINDOW_CLOSED': 'Đã quá 1 ngày kể từ khi hoàn thành, không thể đánh giá.',
  'COMPLAINT_WINDOW_CLOSED': 'Chỉ khiếu nại được khi đơn đã giao và trong vòng 24 giờ.',
  'REFUND_AMOUNT_INVALID': 'Số tiền yêu cầu phải lớn hơn 0 và không vượt tổng cước đơn.',
  'REFUND_TOTAL_EXCEEDED': 'Tổng các khoản hoàn của đơn sẽ vượt tổng cước.',
  'INCIDENT_NOT_ALLOWED': 'Chỉ báo sự cố khi đơn đang Đã đến / Đã lấy hàng / Đang giao.',
  'TOO_MANY_PHOTOS': 'Tối đa 5 ảnh bằng chứng.',
  'NO_INFO_REQUEST': 'Chưa có yêu cầu bổ sung thông tin nào để trả lời.',
  'FARE_CHANGED': 'Giá cước vừa thay đổi. Vui lòng xem lại giá mới trước khi đặt.',
  'ADDRESS_NOT_FOUND': 'Không tìm thấy địa chỉ lấy hoặc giao. Hãy nhập cụ thể hơn.',
  'ROUTE_NOT_FOUND': 'Không tìm được tuyến đường bộ giữa hai điểm.',
  'VEHICLE_TOO_SMALL': 'Hàng vượt tải trọng hoặc không lọt thùng của loại xe đã chọn.',
  'COUPON_NOT_FOUND': 'Mã giảm giá không tồn tại.',
  'COUPON_INACTIVE': 'Mã giảm giá đang tắt.',
  'COUPON_EXPIRED': 'Mã giảm giá chưa tới hạn hoặc đã hết hạn.',
  'COUPON_LIMIT_REACHED': 'Mã giảm giá đã hết lượt sử dụng.',
  'COUPON_MIN_ORDER_NOT_MET': 'Đơn chưa đạt giá trị tối thiểu để dùng mã này.',
  'REFUND_NOT_ALLOWED': 'Chỉ hoàn tiền cho đơn PayOS đã thanh toán.',
  'SERVER_ERROR': 'Lỗi máy chủ. Vui lòng thử lại sau.',
};
