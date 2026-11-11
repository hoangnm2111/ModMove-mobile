/// Mức độ của một thông báo: quyết định màu banner và thời gian hiện.
enum NoticeKind { success, info, warning, error }

/// Màn hình mở khi chạm vào thông báo.
enum NoticeTarget { none, order, refund, driverJob, driverTrip, driverProfile }

/// Một thông báo trong app: banner trên đỉnh màn và mục trong hộp thông báo.
/// Dart thuần (không import Flutter) theo docs/architecture.md.
class AppNotice {
  const AppNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.kind,
    required this.target,
    required this.data,
    required this.at,
    this.persist = false,
    this.read = false,
  });

  final String id, type, title, body;
  final NoticeKind kind;
  final NoticeTarget target;
  final Map<String, String> data;
  final DateTime at;

  /// `true`: lưu vào hộp thông báo (chỉ trong phiên). Thông báo kết quả thao tác nhỏ thì không lưu.
  final bool persist;
  final bool read;

  AppNotice copyWith({bool? read}) => AppNotice(id: id, type: type, title: title, body: body, kind: kind, target: target, data: data, at: at, persist: persist, read: read ?? this.read);

  /// Mã đơn (số nguyên dương) trong `data.orderId`; thiếu hoặc không hợp lệ thì null.
  int? get orderId {
    final value = int.tryParse(data['orderId'] ?? '');
    return value != null && value > 0 ? value : null;
  }

  /// Thời gian banner: success/info 4 giây, warning 6 giây, error 7 giây.
  Duration get duration => switch (kind) {
    NoticeKind.success || NoticeKind.info => const Duration(seconds: 4),
    NoticeKind.warning => const Duration(seconds: 6),
    NoticeKind.error => const Duration(seconds: 7),
  };
}
