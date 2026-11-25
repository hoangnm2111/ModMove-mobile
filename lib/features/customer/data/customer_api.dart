import 'dart:io';

import '../../../core/network/api_client.dart';
import '../domain/entities/customer_models.dart';
import '../../../core/config/platform_config.dart';

/// Một hàm cho mỗi endpoint backend mà khách dùng (dịch từ ModMove-web/src/api/endpoints.ts).
/// Path theo RoleConvention: api/{role}/{Controller}.
class CustomerApi {
  CustomerApi(this._api);
  final ApiClient _api;

  List<T> _items<T>(Object? data, T Function(Map<String, dynamic>) f) => (data as List).map((e) => f(e as Map<String, dynamic>)).toList();

  /* -------------------------------------------------------- public */
  Future<List<VehicleType>> vehicleTypes() async => _items(await _api.get('/public/VehicleTypes'), VehicleType.fromJson);
  Future<List<LookupItem>> cargoTypes() async => _items(await _api.get('/public/Lookups/cargo-types'), LookupItem.fromJson);
  Future<List<LookupItem>> cancellationReasons() async => _items(await _api.get('/public/Lookups/cancellation-reasons'), LookupItem.fromJson);

  /// Ngân hàng nhận hoàn tiền: `code` là mã BIN 6 số, gửi làm payoutAccount.bankCode.
  /// Phí bốc xếp, tiền cọc, bán kính ghép đơn và các giới hạn nghiệp vụ do BE giữ (không cần đăng nhập).
  Future<PlatformConfig> publicConfig() async => PlatformConfig.fromJson(await _api.get('/public/Config') as Map<String, dynamic>);

  Future<List<LookupItem>> banks() async => _items(await _api.get('/public/Lookups/banks'), LookupItem.fromJson);
  Future<List<LookupItem>> complaintReasons() async => _items(await _api.get('/public/Lookups/complaint-reasons'), LookupItem.fromJson);
  Future<List<LookupItem>> policies() async => _items(await _api.get('/public/Policies'), LookupItem.fromJson);

  /// Giới thiệu, khu vực phục vụ, lợi ích (Admin nhập ở master data SERVICE_INFO).
  Future<List<LookupItem>> serviceInfo() async => _items(await _api.get('/public/ServiceInfo'), LookupItem.fromJson);


  Future<FareEstimate> fareEstimate({
    required int vehicleTypeId,
    required String pickupAddress,
    required String dropoffAddress,
    required double weightKg,
    required int lengthCm,
    required int widthCm,
    required int heightCm,
    required bool hasLoadingService,
    String? couponCode,
  }) async => FareEstimate.fromJson(
    await _api.post('/public/FareEstimate', {
          'vehicleTypeId': vehicleTypeId,
          'pickupAddress': pickupAddress,
          'dropoffAddress': dropoffAddress,
          'weightKg': weightKg,
          'lengthCm': lengthCm,
          'widthCm': widthCm,
          'heightCm': heightCm,
          'hasLoadingService': hasLoadingService,
          'couponCode': (couponCode == null || couponCode.isEmpty) ? null : couponCode,
        })
        as Map<String, dynamic>,
  );

  /* -------------------------------------------------------- orders */
  Future<String> upload(File file) async => (await _api.upload('/customer/Uploads', file) as Map<String, dynamic>)['url'] as String;

  /// Trả về (orderId, orderCode, totalFee).
  Future<({int id, String code, double total})> createOrder(Map<String, Object?> body) async {
    final j = await _api.post('/customer/Orders', body) as Map<String, dynamic>;
    return (id: (j['orderId'] as num).toInt(), code: j['orderCode'] as String, total: (j['totalFee'] as num).toDouble());
  }

  Future<Paged<OrderSummary>> orders({int page = 1, int pageSize = 15, String view = 'All', String? search, String? status}) async =>
      Paged.fromJson(await _api.get('/customer/Orders', query: {'page': page, 'pageSize': pageSize, 'view': view, 'search': search, 'status': status}) as Map<String, dynamic>, OrderSummary.fromJson);

  Future<OrderDetail> order(int id) async => OrderDetail.fromJson(await _api.get('/customer/Orders/$id') as Map<String, dynamic>);
  Future<OrderTracking> tracking(int id) async => OrderTracking.fromJson(await _api.get('/customer/Orders/$id/tracking') as Map<String, dynamic>);

  Future<void> cancelOrder(int id, String reasonCode, String? reason) =>
      _api.post('/customer/Orders/$id/cancel', {'reasonCode': reasonCode, 'reason': (reason == null || reason.isEmpty) ? null : reason});

  /// App gửi platform=App: server chọn returnUrl là deep link modmove://orders/... (DECISIONS 3.1).
  Future<PaymentSession> createPayment(int id) async => PaymentSession.fromJson(await _api.post('/customer/Orders/$id/payment', {'platform': 'App'}) as Map<String, dynamic>);
  /// UC-CUS-27 4a (K-28): khách đóng màn thanh toán → huỷ mã PayOS đang chờ; đơn vẫn chờ thanh toán.
  Future<void> cancelPayment(int id) => _api.post('/customer/Orders/$id/payment/cancel', null);

  /// Webhook PayOS chưa tới (tunnel, chưa đăng ký URL…): BE tự hỏi PayOS đơn đã trả chưa. Không có gì mới thì vẫn 204.
  Future<void> syncPayment(int id) => _api.post('/customer/Orders/$id/payment/sync', null);

  Future<void> reviewPickup(int id, {required bool approve, String? reason}) => _api.post('/customer/Orders/$id/pickup-evidence', {'approve': approve, 'reason': approve ? null : reason});

  Future<void> confirmReceipt(int id) => _api.post('/customer/Orders/$id/confirm-receipt');

  Future<List<AvailableCoupon>> coupons() async => Paged.fromJson(await _api.get('/customer/Coupons', query: {'page': 1, 'pageSize': 50}) as Map<String, dynamic>, AvailableCoupon.fromJson).items;

  /* -------------------------------------------------------- ratings / incidents / refunds */
  Future<void> rate(int orderId, int stars, String? comment) => _api.post('/customer/Ratings', {'orderId': orderId, 'stars': stars, 'comment': (comment == null || comment.isEmpty) ? null : comment});

  Future<Paged<MyRating>> ratings({int page = 1, int pageSize = 20}) async =>
      Paged.fromJson(await _api.get('/customer/Ratings', query: {'page': page, 'pageSize': pageSize}) as Map<String, dynamic>, MyRating.fromJson);

  /// Sự cố của khách; `orderId` để BE lọc theo đơn (app vẫn lọc lại phía máy để an toàn).
  Future<List<MyIncident>> incidents({int? orderId, String? status, int page = 1, int pageSize = 50}) async =>
      Paged.fromJson(await _api.get('/customer/Incidents', query: {'orderId': orderId, 'status': status, 'page': page, 'pageSize': pageSize}) as Map<String, dynamic>, MyIncident.fromJson).items;

  Future<void> reportIncident({required int orderId, required String type, required String description, List<String> photoUrls = const [], double? latitude, double? longitude}) =>
      _api.post('/customer/Incidents', {
        'orderId': orderId,
        'incidentType': type,
        'description': description,
        'photoUrls': photoUrls,
        // BE: gửi cả hai toạ độ hoặc không gửi
        'latitude': (latitude != null && longitude != null) ? latitude : null,
        'longitude': (latitude != null && longitude != null) ? longitude : null,
      });

  Future<List<MyRefund>> refunds() async => Paged.fromJson(await _api.get('/customer/Refunds', query: {'page': 1, 'pageSize': 50}) as Map<String, dynamic>, MyRefund.fromJson).items;
  Future<MyRefund> refund(int id) async => MyRefund.fromJson(await _api.get('/customer/Refunds/$id') as Map<String, dynamic>);

  Future<void> submitComplaint({
    required int orderId,
    required String reasonCode,
    String? reason,
    List<String> evidenceUrls = const [],
    required int requestedAmount,
    required PayoutAccountInput payoutAccount,
  }) => _api.post('/customer/Refunds/complaints', {
    'orderId': orderId,
    'reasonCode': reasonCode,
    'reason': (reason == null || reason.isEmpty) ? null : reason,
    'evidenceUrls': evidenceUrls,
    'requestedAmount': requestedAmount,
    'payoutAccount': payoutAccount.toJson(),
  });

  Future<void> requestIncidentRefund({
    required int incidentId,
    required String reason,
    List<String> evidenceUrls = const [],
    required int requestedAmount,
    required PayoutAccountInput payoutAccount,
  }) =>
      _api.post('/customer/Refunds/incidents', {'incidentId': incidentId, 'reason': reason, 'evidenceUrls': evidenceUrls, 'requestedAmount': requestedAmount, 'payoutAccount': payoutAccount.toJson()});

  /// Khai hoặc sửa tài khoản nhận hoàn tiền khi khoản hoàn còn Requested/Approved/Failed.
  Future<void> setRefundPayoutAccount(int id, PayoutAccountInput account) => _api.put('/customer/Refunds/$id/payout-account', account.toJson());

  Future<void> replyRefund(int id, String reply, List<String> photoUrls) => _api.post('/customer/Refunds/$id/reply', {'reply': reply, 'photoUrls': photoUrls});
  Future<void> withdrawRefund(int id) => _api.post('/customer/Refunds/$id/withdraw');

  /* -------------------------------------------------------- account */
  Future<Profile> profile() async => Profile.fromJson(await _api.get('/account/Profile') as Map<String, dynamic>);
  Future<void> updateProfile(String fullName, String phone) => _api.put('/account/Profile', {'fullName': fullName, 'phoneNumber': phone});
  Future<void> changePassword(String current, String next) => _api.post('/account/Password', {'currentPassword': current, 'newPassword': next});
  Future<void> deleteAccount() => _api.delete('/customer/Account');
}
