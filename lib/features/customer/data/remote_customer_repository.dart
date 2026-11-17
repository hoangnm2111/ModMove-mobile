import 'dart:typed_data';
import '../../../core/network/api_client.dart';
import '../../../core/domain/account_input.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';

typedef Json = Map<String, dynamic>;
Json obj(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : {};
String txt(Json j, String k) => j[k]?.toString() ?? '';
double numValue(Json j, String k) => (j[k] as num?)?.toDouble() ?? 0;
int integer(Json j, String k) => (j[k] as num?)?.toInt() ?? 0;
DateTime time(Json j, String k) => DateTime.parse(j[k] as String);
DateTime? optionalTime(Json j, String k) => DateTime.tryParse(txt(j, k));
List<String> strings(dynamic v) =>
    (v as List? ?? []).map((e) => e.toString()).toList(growable: false);
List<T> array<T>(dynamic v, T Function(Json) map) =>
    (v as List? ?? []).map((e) => map(obj(e))).toList(growable: false);
Choice choice(Json j) =>
    Choice(txt(j, 'code'), txt(j, 'name'), txt(j, 'description'));

class RemoteCustomerRepository implements CustomerRepository {
  RemoteCustomerRepository(this.api);
  final ApiClient api;
  static const root = '/api/customer';
  Future<T> guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiFailure catch (e) {
      throw CustomerFailure(_message(e), code: e.code);
    }
  }

  static String _message(ApiFailure e) => switch (e.code) {
    'FARE_CHANGED' =>
      'Giá cước đã thay đổi. Hãy tính lại giá rồi xác nhận đặt đơn.',
    'VEHICLE_TOO_SMALL' =>
      'Hàng vượt tải trọng hoặc kích thước xe. Vui lòng chọn xe lớn hơn.',
    'COUPON_INVALID' ||
    'COUPON_NOT_FOUND' ||
    'COUPON_EXPIRED' ||
    'COUPON_NOT_APPLICABLE' => 'Mã giảm giá không áp dụng được cho đơn này.',
    'ACCOUNT_HAS_OPEN_ORDERS' =>
      'Bạn còn đơn đang xử lý. Hoàn tất hoặc hủy đơn trước khi xóa tài khoản.',
    'WRONG_PASSWORD' => 'Mật khẩu hiện tại chưa đúng.',
    'COMPLAINT_WINDOW_CLOSED' =>
      'Đã hết thời hạn khiếu nại 24 giờ sau giao hàng.',
    'RATING_WINDOW_CLOSED' => 'Đã hết thời hạn đánh giá 24 giờ sau hoàn thành.',
    'RATING_NOT_ALLOWED' =>
      'Chỉ đánh giá chuyến đã hoàn thành, mỗi chuyến một lần.',
    'REFUND_ALREADY_EXISTS' ||
    'COMPLAINT_ALREADY_EXISTS' => 'Đã có yêu cầu đang được xử lý cho mục này.',
    'INCIDENT_PENDING' => 'Chuyến đang tạm dừng để xử lý sự cố tài xế.',
    'ADDRESS_NOT_FOUND' =>
      'Không tìm thấy địa chỉ. Nhập rõ số nhà, đường, phường và thành phố.',
    'ROUTE_NOT_FOUND' => 'Chưa tìm được tuyến đường giữa hai địa chỉ này.',
    'COMPLAINT_OPEN' =>
      'Đơn đang có khiếu nại chưa xử lý xong nên chưa thể xác nhận hoàn thành.',
    'REFUND_NOT_ALLOWED' =>
      'Chỉ yêu cầu hoàn tiền sự cố cho đơn PayOS đã thanh toán.',
    'REFUND_AMOUNT_INVALID' || 'REFUND_TOTAL_EXCEEDED' =>
      'Số tiền vượt mức có thể hoàn của đơn, sau khi tính các yêu cầu hoàn trước đó.',
    'REFUND_PAYOUT_LOCKED' =>
      'Yêu cầu đã đóng; không thể đổi tài khoản nhận tiền.',
    'INCIDENT_NOT_ALLOWED' =>
      'Trạng thái đơn đã thay đổi. Tải lại đơn để kiểm tra thao tác phù hợp.',
    _ => e.message,
  };
  Future<dynamic> get(String path, {bool public = false}) =>
      api.request('GET', path, authenticated: !public);
  Future<void> command(String method, String path, [Json? body]) =>
      guard(() async {
        await api.request(method, path, body: body);
      });
  PageResult<T> page<T>(dynamic v, T Function(Json) mapper) {
    final j = obj(v);
    return PageResult(
      array(j['items'], mapper),
      integer(j, 'pageNumber'),
      integer(j, 'totalCount'),
      j['hasNextPage'] == true,
    );
  }

  @override
  Future<BookingCatalog> catalog() => guard(() async {
    final values = await Future.wait([
      get('/api/public/VehicleTypes', public: true),
      get('/api/public/Lookups/cargo-types', public: true),
      get('/api/public/Policies', public: true),
    ]);
    return BookingCatalog(
      array(
        values[0],
        (j) => Vehicle(
          integer(j, 'id'),
          txt(j, 'name'),
          numValue(j, 'maxLoadWeightKg'),
          integer(j, 'cargoBedLengthCm'),
          integer(j, 'cargoBedWidthCm'),
          integer(j, 'cargoBedHeightCm'),
        ),
      ),
      array(values[1], choice),
      array(values[2], choice),
    );
  });
  @override
  Future<List<Choice>> choices(String kind) => guard(
    () async =>
        array(await get('/api/public/Lookups/$kind', public: true), choice),
  );
  @override
  Future<PageResult<Coupon>> coupons(int p) => guard(
    () async => page(
      await get('$root/Coupons?page=$p'),
      (j) => Coupon(
        txt(j, 'discountCode'),
        numValue(j, 'discountValue'),
        numValue(j, 'minimumOrderValue'),
        time(j, 'expiresAt'),
      ),
    ),
  );
  Json fareBody(BookingDraft d) => {
    'vehicleTypeId': d.vehicleId,
    'pickupAddress': d.pickup.trim(),
    'dropoffAddress': d.dropoff.trim(),
    'weightKg': d.weight,
    'lengthCm': d.length,
    'widthCm': d.width,
    'heightCm': d.height,
    'hasLoadingService': d.loading,
    'couponCode': d.coupon.trim().isEmpty ? null : d.coupon.trim(),
  };
  @override
  Future<Fare> estimate(BookingDraft d) => guard(() async {
    final j = obj(
      await api.request(
        'POST',
        '/api/public/FareEstimate',
        body: fareBody(d),
        authenticated: false,
      ),
    );
    return Fare(
      numValue(j, 'distanceKm'),
      integer(j, 'durationMinutes'),
      numValue(j, 'distanceFee'),
      numValue(j, 'serviceFee'),
      numValue(j, 'discountAmount'),
      numValue(j, 'totalFee'),
    );
  });
  @override
  Future<CreatedOrder> book(BookingDraft d, Fare f) => guard(() async {
    final validation = d.validate(submit: true);
    if (validation != null) throw CustomerFailure(validation);
    final body = fareBody(d)
      ..removeWhere(
        (key, _) =>
            ['weightKg', 'lengthCm', 'widthCm', 'heightCm'].contains(key),
      );
    body.addAll({
      'receiverName': d.receiver.trim(),
      'receiverPhone': normalizeVietnamesePhone(d.phone),
      'cargo': {
        'cargoType': d.cargoType,
        'quantity': d.quantity,
        'weightKg': d.weight,
        'lengthCm': d.length,
        'widthCm': d.width,
        'heightCm': d.height,
        'photoUrls': d.photos,
        'specialNotes': d.notes.trim(),
      },
      'paymentMethod': d.payment,
      'payerRole': d.payment == 'Cash' ? d.payer : null,
      'prohibitedGoodsCommitment': d.committed,
      'expectedTotalFee': f.total,
    });
    Json j;
    try {
      j = obj(await api.request('POST', '$root/orders', body: body));
    } on ApiFailure catch (e) {
      if (e.status == 0 || e.status >= 500) {
        throw const CustomerFailure(
          'Chưa xác định được kết quả tạo đơn. Hãy kiểm tra danh sách đơn trước khi gửi lại để tránh đặt trùng.',
          code: 'ORDER_RESULT_UNKNOWN',
        );
      }
      rethrow;
    }
    return CreatedOrder(
      integer(j, 'orderId'),
      txt(j, 'orderCode'),
      numValue(j, 'totalFee'),
    );
  });
  @override
  Future<String> upload(String filename, Uint8List bytes) => guard(() async {
    if (bytes.length > 5 * 1024 * 1024) {
      throw const CustomerFailure('Ảnh tối đa 5 MB.');
    }
    if (!RegExp(
      r'\.(jpg|jpeg|png)$',
      caseSensitive: false,
    ).hasMatch(filename)) {
      throw const CustomerFailure('Vui lòng chọn ảnh JPG hoặc PNG.');
    }
    final j = obj(await api.upload('$root/Uploads', filename, bytes));
    final url = txt(j, 'url');
    if (Uri.tryParse(url)?.scheme != 'https') {
      throw const CustomerFailure('Server chưa trả về URL ảnh hợp lệ.');
    }
    return url;
  });
  @override
  Future<CustomerProfile> profile() => guard(() async {
    final j = obj(await get('/api/account/Profile'));
    return CustomerProfile(
      txt(j, 'fullName'),
      txt(j, 'phoneNumber'),
      txt(j, 'email'),
      j['emailVerified'] == true,
    );
  });
  @override
  Future<void> updateProfile(String name, String phone) => command(
    'PUT',
    '/api/account/Profile',
    {'fullName': name.trim(), 'phoneNumber': normalizeVietnamesePhone(phone)},
  );
  @override
  Future<void> changePassword(String current, String next) => command(
    'POST',
    '/api/account/Password',
    {'currentPassword': current, 'newPassword': next},
  );
  @override
  Future<void> deleteAccount() => command('DELETE', '$root/Account');
  static OrderSummary summary(Json j) => OrderSummary(
    id: integer(j, 'id'),
    code: txt(j, 'orderCode'),
    status: txt(j, 'orderStatus'),
    pickup: txt(j, 'pickupAddress'),
    dropoff: txt(j, 'dropoffAddress'),
    vehicle: txt(j, 'vehicleTypeName'),
    total: numValue(j, 'totalFee'),
    paymentMethod: txt(j, 'paymentMethod'),
    paymentStatus: txt(j, 'paymentStatus'),
    created: time(j, 'createdAt'),
    receiver: txt(j, 'receiverName'),
    phone: txt(j, 'receiverPhone'),
  );
  @override
  Future<PageResult<OrderSummary>> orders({
    int page = 1,
    String view = 'All',
    String search = '',
    CustomerOrderFilter filter = const CustomerOrderFilter(),
  }) => guard(
    () async => this.page(
      await get(
        '$root/orders?${Uri(queryParameters: {'page': '$page', 'view': view, 'search': search, if (filter.status != null) 'status': filter.status!, if (filter.from != null) 'fromDate': _calendarDate(filter.from!), if (filter.to != null) 'toDate': _calendarDate(filter.to!), if (filter.phone.trim().isNotEmpty) 'receiverPhone': filter.phone.trim()}).query}',
      ),
      summary,
    ),
  );
  static String _calendarDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  @override
  Future<OrderDetail> order(int id) => guard(() async {
    final j = obj(await get('$root/orders/$id'));
    final c = obj(j['cargo']),
        p = obj(j['proof']),
        d = obj(j['driver']),
        pay = obj(j['payment']);
    return OrderDetail(
      summary: summary(j),
      cargoType: txt(c, 'cargoTypeName').isEmpty
          ? txt(c, 'cargoType')
          : txt(c, 'cargoTypeName'),
      cargoCode: txt(c, 'cargoType'),
      pickupRejection: txt(p, 'rejectionReason'),
      pickupSubmissionCount: integer(p, 'pickupSubmissionCount'),
      couponCode: txt(j, 'couponCode'),
      quantity: integer(c, 'quantity'),
      weight: numValue(c, 'weightKg'),
      length: integer(c, 'lengthCm'),
      width: integer(c, 'widthCm'),
      height: integer(c, 'heightCm'),
      photos: strings(c['photoUrls']),
      notes: txt(c, 'specialNotes'),
      loading: j['hasLoadingService'] == true,
      distanceFee: numValue(j, 'distanceFee'),
      serviceFee: numValue(j, 'serviceFee'),
      discount: numValue(j, 'discountAmount'),
      driverName: txt(d, 'fullName'),
      driverPhone: txt(d, 'phoneNumber'),
      plate: txt(d, 'licensePlate'),
      pickupPhotos: strings(p['pickupPhotoUrls']),
      proofStatus: txt(p, 'proofStatus'),
      deliveryPhoto: txt(p, 'deliveryPhotoUrl'),
      deliveredAt: optionalTime(p, 'deliveredAt'),
      history: array(
        j['history'],
        (h) => OrderHistory(
          txt(h, 'toStatus'),
          txt(h, 'note'),
          time(h, 'changedAt'),
        ),
      ),
      pendingDriverIncident: j['pendingDriverIncidentId'] != null,
      checkoutUrl: txt(pay, 'checkoutUrl'),
      paymentExpired: pay['isExpired'] == true,
      paymentExpires: optionalTime(pay, 'expiresAt'),
      paymentPaidAt: optionalTime(pay, 'paidAt'),
      payer: txt(j, 'payerRole'),
    );
  });
  @override
  Future<void> cancel(int id, String code, String reason) => command(
    'POST',
    '$root/orders/$id/cancel',
    {'reasonCode': code, 'reason': reason.trim()},
  );
  @override
  Future<PaymentLink> payment(int id) => guard(() async {
    final j = obj(
      await api.request(
        'POST',
        '$root/orders/$id/payment',
        body: {'platform': 'App'},
      ),
    );
    return PaymentLink(
      txt(j, 'checkoutUrl'),
      txt(j, 'qrCode'),
      numValue(j, 'amount'),
      time(j, 'expiresAt'),
    );
  });
  @override
  Future<void> reviewPickup(int id, bool approve, String reason) => command(
    'POST',
    '$root/orders/$id/pickup-evidence',
    {'approve': approve, 'reason': reason.trim()},
  );
  @override
  Future<void> confirmReceipt(int id) =>
      command('POST', '$root/orders/$id/confirm-receipt');
  @override
  Future<TrackingSnapshot> tracking(int id) => guard(() async {
    final j = obj(await get('$root/orders/$id/tracking'));
    GeoPosition geo(Json p) =>
        GeoPosition(numValue(p, 'latitude'), numValue(p, 'longitude'));
    final d = obj(j['driver']), eta = obj(j['eta']);
    return TrackingSnapshot(
      geo(obj(j['pickup'])),
      geo(obj(j['dropoff'])),
      d.isEmpty ? null : geo(d),
      optionalTime(d, 'at'),
      d['isStale'] == true,
      eta['durationMinutes'] as int?,
      txt(eta, 'target'),
    );
  });
  @override
  Future<PageResult<CustomerRating>> ratings(int p) => guard(
    () async => page(
      await get('$root/Ratings?page=$p'),
      (j) => CustomerRating(
        integer(j, 'orderId'),
        txt(j, 'orderCode'),
        integer(j, 'ratingStars'),
        txt(j, 'reviewComment'),
        txt(j, 'driverName'),
        time(j, 'createdAt'),
      ),
    ),
  );
  @override
  Future<void> rate(int id, int stars, String comment) => command(
    'POST',
    '$root/Ratings',
    {'orderId': id, 'stars': stars, 'comment': comment.trim()},
  );
  @override
  Future<PageResult<Incident>> incidents({int page = 1, int? orderId}) => guard(
    () async => this.page(
      await get(
        '$root/Incidents?page=$page${orderId == null ? '' : '&orderId=$orderId'}',
      ),
      (j) => Incident(
        integer(j, 'id'),
        integer(j, 'orderId'),
        txt(j, 'orderCode'),
        txt(j, 'incidentType'),
        txt(j, 'description'),
        strings(j['photoUrls']),
        j['reportedByYou'] == true,
        txt(j, 'resolutionStatus'),
        txt(j, 'resolutionDecision'),
        txt(j, 'resolutionNote'),
        time(j, 'createdAt'),
      ),
    ),
  );
  @override
  Future<void> report(
    int orderId,
    String type,
    String description,
    List<String> photos,
    GeoPosition? gps,
  ) => command('POST', '$root/Incidents', {
    'orderId': orderId,
    'incidentType': type,
    'description': description.trim(),
    'photoUrls': photos,
    'latitude': gps?.latitude,
    'longitude': gps?.longitude,
  });
  static String bankLabel(dynamic bank) {
    final b = obj(bank);
    return [
      txt(b, 'bankName'),
      txt(b, 'bankCode'),
      txt(b, 'maskedAccountNumber'),
      txt(b, 'accountHolder'),
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  static Refund refundModel(Json j) => Refund(
    id: integer(j, 'id'),
    orderId: integer(j, 'orderId'),
    orderCode: txt(j, 'orderCode'),
    source: txt(j, 'sourceType'),
    status: txt(j, 'refundStatus'),
    amount: numValue(j, 'requestedAmount'),
    approved: (j['approvedAmount'] as num?)?.toDouble(),
    reason: txt(j, 'reason'),
    decision: txt(j, 'decisionReason'),
    question: txt(j, 'infoRequestNote'),
    reply: txt(j, 'customerReply'),
    waitingReply: j['waitingForYourReply'] == true,
    needsBank: j['needsPayoutAccount'] == true,
    bank: bankLabel(j['payoutAccount']),
    suggestedBank: bankLabel(j['suggestedPayoutAccount']),
    failure: txt(j, 'payoutFailureReason'),
    reference: txt(j, 'bankReferenceCode'),
    photos: strings(j['evidenceUrls']),
    created: time(j, 'createdAt'),
    decidedAt: optionalTime(j, 'decidedAt'),
    processedAt: optionalTime(j, 'processedAt'),
  );
  @override
  Future<PageResult<Refund>> refunds(int p) =>
      guard(() async => page(await get('$root/Refunds?page=$p'), refundModel));
  @override
  Future<Refund> refund(int id) =>
      guard(() async => refundModel(obj(await get('$root/Refunds/$id'))));
  Json bankBody(PayoutAccount b) => {
    'useSuggested': b.suggested,
    'bankCode': b.suggested ? null : b.bankCode,
    'accountNumber': b.suggested ? null : b.number.trim(),
    'accountHolder': b.suggested ? null : b.holder.trim(),
  };
  @override
  Future<int> complain(
    int orderId,
    String code,
    String reason,
    List<String> photos,
    double amount,
    PayoutAccount bank,
  ) => guard(() async {
    final j = obj(
      await api.request(
        'POST',
        '$root/Refunds/complaints',
        body: {
          'orderId': orderId,
          'reasonCode': code,
          'reason': reason.trim(),
          'evidenceUrls': photos,
          'requestedAmount': amount,
          'payoutAccount': bankBody(bank),
        },
      ),
    );
    return integer(j, 'refundId');
  });
  @override
  Future<int> requestRefund(
    int incidentId,
    String reason,
    List<String> photos,
    double amount,
    PayoutAccount bank,
  ) => guard(() async {
    final j = obj(
      await api.request(
        'POST',
        '$root/Refunds/incidents',
        body: {
          'incidentId': incidentId,
          'reason': reason.trim(),
          'evidenceUrls': photos,
          'requestedAmount': amount,
          'payoutAccount': bankBody(bank),
        },
      ),
    );
    return integer(j, 'refundId');
  });
  @override
  Future<void> replyRefund(int id, String reply, List<String> photos) =>
      command('POST', '$root/Refunds/$id/reply', {
        'reply': reply.trim(),
        'photoUrls': photos,
      });
  @override
  Future<void> withdrawRefund(int id) =>
      command('POST', '$root/Refunds/$id/withdraw');
  @override
  Future<void> setPayout(int id, PayoutAccount bank) =>
      command('PUT', '$root/Refunds/$id/payout-account', bankBody(bank));
}
