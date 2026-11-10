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
