import '../../../core/network/api_client.dart';

/// Một hàm cho mỗi endpoint `api/driver/*` mà app tài xế dùng.
/// Path và body lấy từ ModMove-backend/docs/api/README.md (BE là nguồn chuẩn).
class DriverApi {
  DriverApi(this._api);
  final ApiClient _api;

  Map<String, dynamic> _map(Object? data) =>
      (data as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> _list(Object? data) => (data as List? ?? const [])
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList();

  /* ------------------------------------------------------ hồ sơ */

  /// Màn hình chính tài xế: duyệt hồ sơ, online, ví, GPS, đơn đang chạy.
  Future<Map<String, dynamic>> status() async =>
      _map(await _api.get('/driver/status'));

  /// Hồ sơ tài xế & phương tiện (có `hasProfile=false` khi chưa nộp hồ sơ).
  Future<Map<String, dynamic>> profile() async =>
      _map(await _api.get('/driver/profile'));

  /// Phiên bản hồ sơ mới nhất + lý do từ chối.
  Future<Map<String, dynamic>> onboardingStatus() async =>
      _map(await _api.get('/driver/onboarding/status'));

  /// Đúng 7 URL theo thứ tự: GPLX trước, GPLX sau, đăng ký xe, đăng kiểm, ảnh xe, CCCD trước, CCCD sau.
  Future<int> submitOnboarding({
    required int vehicleTypeId,
    required String licensePlate,
    required num maxLoadWeightKg,
    required List<String> documentUrls,
  }) async {
    final j = _map(
      await _api.post('/driver/onboarding', {
        'vehicleTypeId': vehicleTypeId,
        'licensePlate': licensePlate,
        'maxLoadWeightKg': maxLoadWeightKg,
        'documentUrls': documentUrls,
      }),
    );
    return (j['id'] as num).toInt();
  }

  /// Nộp lại chỉ phần bị từ chối: `items` = [{key, url}], `vehicle` khi mục VehicleInfo bị từ chối.
  Future<int> resubmitOnboarding({
    required List<Map<String, String>> items,
    Map<String, Object?>? vehicle,
  }) async {
    final j = _map(
      await _api.post('/driver/onboarding/resubmit', {
        if (items.isNotEmpty) 'items': items,
        'vehicle': ?vehicle,
      }),
    );
    return (j['id'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> vehicleTypes() async =>
      _list(await _api.get('/public/VehicleTypes'));

  /// Upload một ảnh JPG/PNG ≤ 5 MB → URL Cloudinary.
  Future<String> upload(String fileName, List<int> bytes) async =>
      _map(await _api.uploadBytes('/driver/Uploads', fileName, bytes))['url']
          as String;

  /* ------------------------------------------------------ trạng thái + GPS */

  Future<void> setOnline(bool online) =>
      _api.patch('/driver/online-status', {'isOnline': online});

  /// Q12: xoá (vô hiệu hoá) tài khoản tài xế → 204; BE chặn khi còn đơn chạy, rút tiền chờ hoặc ví khác 0.
  Future<void> deleteAccount() => _api.delete('/driver/account');

  Future<void> sendLocation(double latitude, double longitude) => _api.post(
    '/driver/location',
    {'latitude': latitude, 'longitude': longitude},
  );

  /* ------------------------------------------------------ ghép đơn */

  Future<List<Map<String, dynamic>>> matchingOrders() async =>
      _list(await _api.get('/driver/Matching/orders'));

  Future<Map<String, dynamic>> matchingOrder(String id) async =>
      _map(await _api.get('/driver/Matching/orders/$id'));

  Future<void> acceptOrder(String id) =>
      _api.post('/driver/Matching/orders/$id/accept');

  /* ------------------------------------------------------ chuyến */

  /// 204 (đang rảnh) → `null`.
  Future<Map<String, dynamic>?> activeTrip() async {
    final data = await _api.get('/driver/Trips/active');
    return data == null ? null : _map(data);
  }

  Future<Map<String, dynamic>> trip(String id) async =>
      _map(await _api.get('/driver/Trips/$id'));

  Future<void> arrive(String id) => _api.post('/driver/Trips/$id/arrive');

  /// 2–5 URL ảnh lấy hàng; gửi lại được sau khi khách từ chối (tối đa 5 lần gửi).
  Future<void> pickup(String id, List<String> photoUrls) =>
      _api.post('/driver/Trips/$id/pickup', {'photoUrls': photoUrls});

  Future<void> arriveDropoff(String id) =>
      _api.post('/driver/Trips/$id/arrive-dropoff');

  /// Thu tiền mặt: BE kiểm tra bước và bán kính 500 m quanh điểm lấy hoặc điểm giao theo toạ độ gửi lên.
  Future<void> collectCash(String id, double latitude, double longitude) =>
      _api.post('/driver/Trips/$id/collect-cash', {
        'latitude': latitude,
        'longitude': longitude,
      });

  Future<void> deliver(
    String id,
    String deliveryPhotoUrl, {
    bool cashCollected = false,
    double? latitude,
    double? longitude,
  }) => _api.post('/driver/Trips/$id/deliver', {
    'deliveryPhotoUrl': deliveryPhotoUrl,
    'cashCollected': cashCollected,
    'latitude': ?latitude,
    'longitude': ?longitude,
  });

  /* ------------------------------------------------------ ví */

  /// Tổng kết thu nhập hôm nay (giờ Việt Nam): `completedTrips`, `netEarnings`…
  Future<Map<String, dynamic>> todayEarnings() async => _map(
    await _api.get(
      '/driver/Wallet/earnings',
      query: {'period': 'Today', 'pageSize': 1},
    ),
  );

  Future<Map<String, dynamic>> wallet() async =>
      _map(await _api.get('/driver/Wallet'));

  Future<Map<String, dynamic>> walletTransactions({
    int page = 1,
    int pageSize = 20,
  }) async => _map(
    await _api.get(
      '/driver/Wallet/transactions',
      query: {'page': page, 'pageSize': pageSize},
    ),
  );

  Future<Map<String, dynamic>> withdrawals({
    int page = 1,
    int pageSize = 20,
  }) async => _map(
    await _api.get(
      '/driver/Wallet/withdrawals',
      query: {'page': page, 'pageSize': pageSize},
    ),
  );

  /// period: All | Today | Week | Month.
  Future<Map<String, dynamic>> earnings(
    String period, {
    int page = 1,
    int pageSize = 20,
  }) async => _map(
    await _api.get(
      '/driver/Wallet/earnings',
      query: {'period': period, 'page': page, 'pageSize': pageSize},
    ),
  );

  /// Danh sách ngân hàng (cùng nguồn với form hoàn tiền của khách).
  Future<List<String>> bankNames() async => [
    for (final b
        in (await _api.get('/public/Lookups/banks')) as List? ?? const [])
      if (b is Map && b['name'] != null) b['name'].toString(),
  ];

  Future<void> saveBankAccount({
    required String bankName,
    required String number,
    required String holder,
  }) => _api.put('/driver/Wallet/bank-account', {
    'bankName': bankName,
    'bankAccountNumber': number,
    'bankAccountHolder': holder,
  });

  Future<Map<String, dynamic>> withdraw(num amount) async =>
      _map(await _api.post('/driver/Wallet/withdrawals', {'amount': amount}));

  /// Link PayOS nạp tiền cọc (tối thiểu 50.000đ). Trả `checkoutUrl`.
  Future<Map<String, dynamic>> topUp(num amount) async => _map(
    await _api.post('/driver/Wallet/topup', {
      'amount': amount,
      'platform': 'App',
    }),
  );

  /* ------------------------------------------------------ lịch sử + đánh giá */

  /// view: All | Active | History | Completed | Cancelled.
  Future<Map<String, dynamic>> trips({
    String view = 'All',
    int page = 1,
    int pageSize = 20,
  }) async => _map(
    await _api.get(
      '/driver/Trips',
      query: {'view': view, 'page': page, 'pageSize': pageSize},
    ),
  );

  Future<Map<String, dynamic>> ratings({
    int page = 1,
    int pageSize = 20,
  }) async => _map(
    await _api.get(
      '/driver/Ratings',
      query: {'page': page, 'pageSize': pageSize},
    ),
  );

  /* ------------------------------------------------------ sự cố */

  /// Sự cố tôi báo hoặc nằm trên đơn đang giao cho tôi. status: Open | InProgress | Resolved | Cancelled.
  Future<Map<String, dynamic>> incidents({
    int? orderId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async => _map(
    await _api.get(
      '/driver/Incidents',
      query: {
        'orderId': orderId,
        'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    ),
  );

  Future<Map<String, dynamic>> incident(int id) async =>
      _map(await _api.get('/driver/Incidents/$id'));

  /// incidentType: VehicleBreakdown | DamagedCargo | Accident | Other. Trả về incidentId.
  Future<int> reportIncident({
    required String orderId,
    required String incidentType,
    required String description,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
  }) async {
    final j = _map(
      await _api.post('/driver/Incidents', {
        'orderId': int.parse(orderId),
        'incidentType': incidentType,
        'description': description,
        if (photoUrls != null && photoUrls.isNotEmpty) 'photoUrls': photoUrls,
        'latitude': ?latitude,
        'longitude': ?longitude,
      }),
    );
    return (j['incidentId'] as num).toInt();
  }
}
