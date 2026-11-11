enum PushPermission { unavailable, denied, allowed }

/// Thông báo đẩy từ BE (FCM `data` giống payload SignalR NotificationReceived). Dữ liệu chỉ để chọn màn hình:
/// số dư, trạng thái đơn, sự cố… luôn được đọc lại từ API sau khi chạm.
class PushMessage {
  const PushMessage({required this.data, this.id, this.title, this.body});
  final Map<String, dynamic> data;
  final String? id, title, body;

  String get type => data['type']?.toString() ?? '';

  String? _positiveId(String key) {
    final value = data[key]?.toString();
    return value != null && RegExp(r'^[1-9][0-9]*$').hasMatch(value) ? value : null;
  }

  /// Chỉ nhận số nguyên dương, từ chối mọi chuỗi lạ (không bao giờ dùng làm đường dẫn).
  String? get orderId => _positiveId('orderId');
  String? get incidentId => _positiveId('incidentId');

  /// Có loại thông báo để điều hướng (loại lạ thì bỏ qua, không mở màn nào).
  bool get actionable => type.isNotEmpty;
}
