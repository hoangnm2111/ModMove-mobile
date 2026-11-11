import 'app_notice.dart';

typedef NoticeEntry = ({NoticeKind kind, String title, String body, NoticeTarget target});

const _o = NoticeTarget.order;
const _r = NoticeTarget.refund;
const _n = NoticeTarget.none;

/// Danh mục sự kiện: `type` → mức độ, chữ dự phòng và màn hình đích.
/// Mã giống hệt mã BE gửi (SignalR `NotificationReceived` / FCM `data.type`); chữ của server luôn được ưu tiên,
/// chữ dưới đây chỉ dùng khi server không gửi. Chữ dự phòng có thể chứa `{orderCode}`, `{amount}`, `{reason}`, `{document}`.
const Map<String, NoticeEntry> noticeCatalog = {
  // ---- BE gửi cho khách hàng
  'ORDER_ACCEPTED': (kind: NoticeKind.info, title: 'Đơn đã có tài xế', body: 'Tài xế đã nhận đơn {orderCode} và đang đến điểm lấy hàng.', target: _o),
  'DRIVER_ARRIVED': (kind: NoticeKind.info, title: 'Tài xế đã đến', body: 'Tài xế đã đến điểm lấy hàng của đơn {orderCode}.', target: _o),
  'DRIVER_ARRIVED_DROPOFF': (kind: NoticeKind.info, title: 'Tài xế đã đến điểm giao', body: 'Tài xế đã đến điểm giao hàng của đơn {orderCode}.', target: _o),
  'PICKUP_PHOTOS_TO_REVIEW': (kind: NoticeKind.warning, title: 'Ảnh lấy hàng chờ duyệt', body: 'Ảnh kiểm hàng của đơn {orderCode} đã sẵn sàng. Vui lòng duyệt trước khi xe khởi hành.', target: _o),
  'ORDER_DELIVERED': (kind: NoticeKind.success, title: 'Đơn đã giao', body: 'Đơn {orderCode} đã được giao. Xác nhận nhận hàng hoặc khiếu nại trong 24 giờ.', target: _o),
  'ORDER_COMPLETED': (kind: NoticeKind.success, title: 'Đơn đã hoàn thành', body: 'Đơn {orderCode} đã hoàn thành.', target: _o),
  'ORDER_CANCELLED': (kind: NoticeKind.error, title: 'Đơn đã bị hủy', body: 'Đơn {orderCode} đã bị hủy.', target: _o),
  'INCIDENT_RESOLVED': (kind: NoticeKind.success, title: 'Sự cố đã được xử lý', body: 'Sự cố của đơn {orderCode} đã có kết quả.', target: _o),
  'INCIDENT_IN_PROGRESS': (kind: NoticeKind.info, title: 'Điều phối viên đang xử lý sự cố', body: 'Sự cố của đơn {orderCode} đang được điều phối viên xử lý.', target: _o),
  'INCIDENT_REPORTED': (kind: NoticeKind.warning, title: 'Có sự cố trên đơn hàng', body: 'Đơn {orderCode} có sự cố mới. Điều phối viên đang xử lý.', target: _o),
  'REFUND_DECIDED': (kind: NoticeKind.info, title: 'Kết quả hoàn tiền', body: 'Yêu cầu hoàn tiền của đơn {orderCode} đã có kết quả.', target: _r),
  'REFUND_INFO_REQUESTED': (kind: NoticeKind.warning, title: 'Cần bổ sung thông tin', body: 'Điều phối viên cần thêm thông tin cho yêu cầu của đơn {orderCode}.', target: _r),
  'REFUND_BANK_INFO_REQUIRED': (
    kind: NoticeKind.warning,
    title: 'Cần tài khoản nhận hoàn tiền',
    body: 'Đơn {orderCode} có khoản hoàn tiền. Vui lòng cung cấp tài khoản ngân hàng để nhận tiền.',
    target: _r,
  ),
  'REFUND_PAYOUT_FAILED': (
    kind: NoticeKind.error,
    title: 'Chuyển hoàn tiền thất bại',
    body: 'Chuyển hoàn tiền cho đơn {orderCode} không thành công. Vui lòng kiểm tra lại tài khoản nhận.',
    target: _r,
  ),

  // ---- BE gửi cho tài xế
  'NEW_MATCHING_ORDER': (kind: NoticeKind.info, title: 'Có đơn mới gần bạn', body: 'Đơn {orderCode} đang chờ nhận.', target: NoticeTarget.driverJob),
  'PICKUP_APPROVED': (kind: NoticeKind.success, title: 'Khách đã duyệt ảnh lấy hàng', body: 'Đơn {orderCode}: bạn có thể bắt đầu giao hàng.', target: NoticeTarget.driverTrip),
  'PICKUP_REJECTED': (kind: NoticeKind.warning, title: 'Khách từ chối ảnh lấy hàng', body: 'Đơn {orderCode}: {reason} Hãy chụp lại và gửi ảnh mới.', target: NoticeTarget.driverTrip),
  'INCIDENT_DECIDED': (kind: NoticeKind.info, title: 'Sự cố đã có kết quả', body: 'Điều phối viên đã quyết định sự cố của đơn {orderCode}.', target: NoticeTarget.driverTrip),
  'RATING_RECEIVED': (kind: NoticeKind.info, title: 'Bạn có đánh giá mới', body: 'Khách hàng vừa đánh giá chuyến của bạn.', target: NoticeTarget.driverProfile),
  'DRIVER_APPLICATION_APPROVED': (
    kind: NoticeKind.success,
    title: 'Hồ sơ đã được duyệt',
    body: 'Hồ sơ tài xế của bạn đã được duyệt. Bạn có thể bật hoạt động và nhận đơn.',
    target: NoticeTarget.driverProfile,
  ),
  'DRIVER_APPLICATION_REJECTED': (kind: NoticeKind.error, title: 'Hồ sơ bị từ chối', body: 'Hồ sơ tài xế chưa đạt. {reason} Hãy cập nhật và nộp lại.', target: NoticeTarget.driverProfile),
  'WITHDRAWAL_DECIDED': (kind: NoticeKind.info, title: 'Kết quả rút tiền', body: 'Yêu cầu rút tiền của bạn đã có kết quả.', target: _n),

  // ---- Kết quả thao tác của khách trong app
  'ORDER_CREATED': (kind: NoticeKind.success, title: 'Đã tạo đơn', body: 'Đơn {orderCode} đã được tạo.', target: _o),
  'COMPLAINT_SUBMITTED': (kind: NoticeKind.success, title: 'Đã gửi khiếu nại', body: 'Khiếu nại đơn {orderCode} đã gửi. Điều phối viên sẽ xem xét.', target: _r),
  'INCIDENT_REFUND_REQUESTED': (kind: NoticeKind.success, title: 'Đã gửi yêu cầu hoàn tiền', body: 'Yêu cầu hoàn tiền cho sự cố của đơn {orderCode} đã được gửi.', target: _r),
  'REFUND_INFO_REPLIED': (kind: NoticeKind.success, title: 'Đã gửi thông tin bổ sung', body: 'Thông tin bổ sung cho đơn {orderCode} đã được gửi.', target: _r),
  'REFUND_WITHDRAWN': (kind: NoticeKind.info, title: 'Đã rút yêu cầu', body: 'Bạn đã rút yêu cầu hoàn tiền của đơn {orderCode}.', target: _r),
  'PAYMENT_CONFIRMED': (kind: NoticeKind.success, title: 'Thanh toán thành công', body: 'Đã xác nhận thanh toán {amount} cho đơn {orderCode}.', target: _o),
  'PAYMENT_PENDING': (kind: NoticeKind.info, title: 'Chưa nhận được thanh toán', body: 'Đơn {orderCode} chưa nhận được thanh toán. Hãy hoàn tất rồi kiểm tra lại.', target: _o),
  'PAYMENT_EXPIRED': (kind: NoticeKind.warning, title: 'Mã thanh toán đã hết hạn', body: 'Mã thanh toán của đơn {orderCode} đã hết hạn. Hãy tạo mã mới.', target: _o),
  'PAYMENT_FAILED': (kind: NoticeKind.error, title: 'Thanh toán thất bại', body: 'Thanh toán đơn {orderCode} không thành công. Hãy thử lại.', target: _o),
  'PAYMENT_CANCELLED': (kind: NoticeKind.warning, title: 'Thanh toán đã bị hủy', body: 'Phiên thanh toán của đơn {orderCode} đã bị hủy.', target: _o),
  'RECEIPT_CONFIRMED': (kind: NoticeKind.success, title: 'Đã xác nhận nhận hàng', body: 'Cảm ơn bạn. Đơn {orderCode} đã hoàn tất.', target: _o),
  'RATING_SUBMITTED': (kind: NoticeKind.success, title: 'Đã gửi đánh giá', body: 'Cảm ơn bạn đã đánh giá tài xế.', target: _n),
  'LOGGED_OUT': (kind: NoticeKind.info, title: 'Đã đăng xuất', body: 'Bạn đã đăng xuất khỏi ModMove.', target: _n),
  'NETWORK_ERROR': (kind: NoticeKind.error, title: 'Mất kết nối', body: 'Không kết nối được tới máy chủ. Kiểm tra mạng rồi thử lại.', target: _n),

  // ---- Kết quả thao tác của tài xế trong app (luồng mô phỏng)
  'DRIVER_DRAFT_SAVED': (kind: NoticeKind.success, title: 'Đã lưu bản nháp', body: 'Bản nháp hồ sơ đã được lưu.', target: NoticeTarget.driverProfile),
  'DRIVER_APPLICATION_SUBMITTED': (kind: NoticeKind.success, title: 'Đã gửi hồ sơ', body: 'Hồ sơ tài xế đã gửi, đang chờ xét duyệt.', target: NoticeTarget.driverProfile),
  'DOCUMENT_UPLOADED': (kind: NoticeKind.success, title: 'Đã tải giấy tờ', body: 'Đã tải lên {document}.', target: NoticeTarget.driverProfile),
  'DOCUMENT_UPLOAD_FAILED': (kind: NoticeKind.error, title: 'Tải giấy tờ thất bại', body: 'Chưa tải được {document}. Hãy thử lại.', target: NoticeTarget.driverProfile),
  'CASH_COLLECTED': (kind: NoticeKind.success, title: 'Đã thu tiền mặt', body: 'Đơn {orderCode}: đã xác nhận thu tiền mặt.', target: NoticeTarget.driverTrip),

  // ---- Kết quả thao tác chung: câu thật truyền qua `body:`
  'ACTION_DONE': (kind: NoticeKind.success, title: '', body: 'Đã xong.', target: _n),
  'ACTION_ERROR': (kind: NoticeKind.error, title: '', body: 'Đã có lỗi xảy ra. Vui lòng thử lại.', target: _n),
};

/// Thông báo nhỏ của thao tác trong app: hiện banner nhưng không lưu vào hộp thông báo.
const Set<String> _transientTypes = {'ACTION_DONE', 'ACTION_ERROR', 'RATING_SUBMITTED', 'LOGGED_OUT', 'NETWORK_ERROR', 'DRIVER_DRAFT_SAVED', 'DOCUMENT_UPLOADED', 'DOCUMENT_UPLOAD_FAILED'};

/// Mã được lưu vào hộp thông báo: mọi sự kiện đơn hàng, thanh toán, sự cố, khiếu nại/hoàn tiền, hồ sơ tài xế.
final Set<String> persistedTypes = {
  for (final type in noticeCatalog.keys)
    if (!_transientTypes.contains(type)) type,
};

String _fill(String template, Map<String, String> data) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => data[m[1]] ?? '').replaceAll(RegExp(r'\s{2,}'), ' ').replaceAll(RegExp(r'\s+([.,!?])'), r'$1').trim();

int _noticeSeq = 0;

/// Dựng thông báo từ mã `type`. Chữ của server (`title`/`body`) được dùng nguyên văn; thiếu thì dùng chữ dự phòng
/// của danh mục (điền `{key}` từ [data], khoá thiếu thì bỏ trống). Mã lạ vẫn hiện chữ của server, mức info, không có đích.
AppNotice noticeFor(String type, {Map<String, String> data = const {}, String? title, String? body, DateTime? at}) {
  final entry = noticeCatalog[type];
  final time = at ?? DateTime.now();
  String pick(String? server, String? fallback) => (server != null && server.trim().isNotEmpty) ? server.trim() : _fill(fallback ?? '', data);
  return AppNotice(
    // Số thứ tự tránh trùng id khi hai thông báo cùng loại được dựng trong cùng một micro giây.
    id: '${type}_${time.microsecondsSinceEpoch}_${_noticeSeq++}',
    type: type,
    title: pick(title, entry?.title),
    body: pick(body, entry?.body),
    kind: entry?.kind ?? NoticeKind.info,
    target: entry?.target ?? NoticeTarget.none,
    data: data,
    at: time,
    persist: persistedTypes.contains(type),
  );
}
