// JSON mẫu theo đúng DTO backend (lấy từ phản hồi thật của API ModMove).

Map<String, dynamic> orderSummaryJson({int id = 8, String status = 'Delivered', String method = 'PayOS', String payment = 'Paid'}) => {
  'id': id,
  'orderCode': 'MMDEMO00$id',
  'orderStatus': status,
  'pickupAddress': '12 Nguyễn Huệ, Quận 1, TP.HCM',
  'dropoffAddress': '45 Lê Văn Việt, TP. Thủ Đức, TP.HCM',
  'vehicleTypeName': 'Xe van 500kg',
  'totalFee': 280000.0,
  'paymentMethod': method,
  'paymentStatus': payment,
  'createdAt': '2026-11-04T16:05:00Z',
  'receiverName': 'Nguyễn Văn Nhận',
  'receiverPhone': '0911000001',
};

Map<String, dynamic> orderDetailJson({
  int id = 8,
  String status = 'Delivered',
  String method = 'PayOS',
  String payment = 'Paid',
  String? deliveredAt,
  String proofStatus = 'Verified',
  bool driver = true,
}) => {
  ...orderSummaryJson(id: id, status: status, method: method, payment: payment),
  'estimatedDistanceKm': 12.4,
  'estimatedDurationMin': 35,
  'hasLoadingService': false,
  'distanceFee': 280000.0,
  'serviceFee': 0.0,
  'discountAmount': 0.0,
  'payerRole': method == 'Cash' ? 'Sender' : null,
  'cargo': {
    'cargoType': 'APPLIANCE',
    'quantity': 3,
    'weightKg': 120.0,
    'lengthCm': 100,
    'widthCm': 60,
    'heightCm': 50,
    'photoUrls': <String>[],
    'specialNotes': null,
    'cargoTypeName': 'Đồ gia dụng',
  },
  'driver': driver ? {'fullName': 'Tài xế Demo', 'phoneNumber': '0900000004', 'licensePlate': '51C-123.45'} : null,
  'proof': status == 'Pending' || status == 'Accepted' || status == 'Arrived'
      ? null
      : {
          'pickupPhotoUrls': <String>[],
          'proofStatus': proofStatus,
          'pickupSubmissionCount': 1,
          'rejectionReason': null,
          'deliveryPhotoUrl': null,
          'deliveredAt': deliveredAt,
        },
  'history': [
    {'fromStatus': null, 'toStatus': 'Pending', 'changedByRole': 'Customer', 'note': null, 'changedAt': '2026-11-04T16:05:00Z'},
    {'fromStatus': 'Pending', 'toStatus': status, 'changedByRole': 'Driver', 'note': null, 'changedAt': deliveredAt ?? '2026-11-04T16:30:00Z'},
  ],
  'couponCode': null,
  'payment': null,
};

Map<String, dynamic> paged(List<Map<String, dynamic>> items) => {'items': items, 'pageNumber': 1, 'pageSize': 50, 'totalCount': items.length};
