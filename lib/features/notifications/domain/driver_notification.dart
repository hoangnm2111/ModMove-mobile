enum PushPermission { unavailable, denied, allowed }

/// Payloads only select a screen; its repository re-reads authoritative data.
class DriverNotification {
  const DriverNotification({
    required this.data,
    this.id,
    this.title,
    this.body,
  });
  final Map<String, dynamic> data;
  final String? id, title, body;
  String get type => data['type']?.toString() ?? '';
  String? _positiveId(String key) {
    final value = data[key]?.toString();
    return value != null && RegExp(r'^[1-9][0-9]*$').hasMatch(value)
        ? value
        : null;
  }

  String? get orderId => _positiveId('orderId');
  String? get incidentId => _positiveId('incidentId');
  String? get refundId => _positiveId('refundId');
  String? get customerRoute => switch (type) {
    'REFUND_INFO_REQUESTED' ||
    'REFUND_DECIDED' ||
    'REFUND_BANK_INFO_REQUIRED' ||
    'REFUND_PAYOUT_FAILED' => refundId == null ? '/refunds' : '/refund',
    'INCIDENT_RESOLVED' || 'INCIDENT_IN_PROGRESS' => '/incidents',
    'ORDER_ACCEPTED' ||
    'DRIVER_ARRIVED' ||
    'PICKUP_PHOTOS_TO_REVIEW' ||
    'ORDER_DELIVERED' ||
    'ORDER_COMPLETED' ||
    'ORDER_CANCELLED' => orderId == null ? null : '/order',
    _ => null,
  };
  bool get canOpen => route != null || customerRoute != null;
  String? get route => switch (type) {
    'NEW_MATCHING_ORDER' => orderId == null ? null : '/job-details',
    'PICKUP_APPROVED' || 'PICKUP_REJECTED' => '/active-trip',
    'ORDER_CANCELLED' => '/trips',
    'ORDER_COMPLETED' => orderId == null ? '/trips' : '/trip-earnings',
    'INCIDENT_REPORTED' || 'INCIDENT_DECIDED' =>
      incidentId == null ? '/incidents' : '/incident-detail',
    'DRIVER_APPLICATION_APPROVED' ||
    'DRIVER_APPLICATION_REJECTED' ||
    'RATING_RECEIVED' => '/profile',
    'WITHDRAWAL_DECIDED' => '/wallet',
    _ => null,
  };
  String? get argument => switch (route) {
    '/incident-detail' => incidentId,
    '/trip-earnings' => orderId,
    _ => null,
  };
}
