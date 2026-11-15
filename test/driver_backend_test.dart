import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_api.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_location_source.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/api_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/backend_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';

/// Máy chủ giả trả đúng hình dạng JSON của ModMove.WebApi (docs/api/README.md),
/// để kiểm tra phần ánh xạ + quy trình mà không cần BE chạy.
class FakeBackend {
  FakeBackend({this.profileApproval = 'Approved'});
  final String profileApproval;
  final requests = <String>[];
  final bodies = <String, Object?>{};
  String orderStatus = 'Pending';
  String proofStatus = 'Pending';
  int pickupSubmissions = 0;
  bool online = true;
  bool paid = false;
  bool activeGone = false;
  final incidents = <Map<String, Object?>>[];

  static const _trip = {
    'id': 7,
    'orderCode': 'MM20261110007',
    'pickupAddress': '12 Nguyễn Huệ, Quận 1',
    'pickupLatitude': 10.7769,
    'pickupLongitude': 106.7009,
    'dropoffAddress': '45 Lê Văn Việt, Thủ Đức',
    'dropoffLatitude': 10.8473,
    'dropoffLongitude': 106.7819,
    'vehicleTypeName': 'Xe van 500kg',
    'estimatedDistanceKm': 12.4,
    'estimatedDurationMin': 35,
    'customerName': 'Khách hàng Demo',
    'customerPhone': '0900000003',
    'totalFee': 195000.0,
    'commissionAmount': 19500,
    'paymentMethod': 'Cash',
    'payerRole': 'Sender',
    'createdAt': '2026-11-10T13:00:00+00:00',
    'cargo': {'quantity': 3, 'weightKg': 120.0},
  };

  Map<String, Object?> get tripJson => {
    ..._trip,
    'orderStatus': orderStatus,
    'incidents': incidents,
    'paymentStatus': paid ? 'Paid' : 'Pending',
    'proof': orderStatus == 'Pending' || orderStatus == 'Accepted' || orderStatus == 'Arrived'
        ? null
        : {
            'pickupPhotoUrls': ['https://x/1.jpg', 'https://x/2.jpg'],
            'proofStatus': proofStatus,
            'pickupSubmissionCount': pickupSubmissions,
            'remainingPickupSubmissions': 5 - pickupSubmissions,
            'rejectionReason': proofStatus == 'Rejected' ? 'Ảnh chưa rõ dây chằng.' : null,
          },
    'statusHistories': [
      {'fromStatus': 'Pending', 'toStatus': 'Accepted', 'changedAt': '2026-11-10T13:05:00+00:00'},
    ],
  };

  Future<http.Response> handle(http.Request request) async {
    final key = '${request.method} ${request.url.path.replaceFirst('/api', '')}'.toLowerCase();
    requests.add(key);
    if ((request.headers['content-type'] ?? '').contains('json') && request.body.isNotEmpty) bodies[key] = jsonDecode(request.body);
    http.Response json(Object body, [int code = 200]) =>
        http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});
    switch (key) {
      case 'get /driver/status':
        return json({
          'hasProfile': true,
          'approvalStatus': profileApproval,
          'isOnline': online,
          'vehicleTypeId': 1,
          'licensePlate': '51C-222.22',
          'depositBalance': 500000.0,
          'earningsBalance': 120000.0,
          'activeOrderId': orderStatus == 'Pending' ? null : 7,
        });
      case 'get /driver/profile':
        return json({
          'fullName': 'Tài xế Thay thế',
          'phoneNumber': '0900000005',
          'hasProfile': true,
          'citizenIdNumber': '079090000002',
          'driverLicenseNumber': '790000000002',
          'vehicle': {
            'vehicleTypeName': 'Xe van 500kg',
            'licensePlate': '51C-222.22',
            'maxLoadWeightKg': 500.0,
            'cargoBedLengthCm': 170,
            'cargoBedWidthCm': 120,
            'cargoBedHeightCm': 120,
          },
        });
      case 'get /driver/onboarding/status':
        return json({
          'hasApplication': true,
          'canSubmit': false,
          'profileApprovalStatus': 'Approved',
          'latestVersionNumber': 1,
          'submittedAt': '2026-11-04T16:05:39+07:00',
          'reviewedAt': '2026-11-09T15:45:32+07:00',
          'vehicleTypeId': 1,
          'vehicleTypeName': 'Xe van 500kg',
          'licensePlate': '51C-222.22',
          'maxLoadWeightKg': 500.0,
          'citizenIdNumber': '079090000002',
          'driverLicenseNumber': '790000000002',
          'documentUrls': [for (var i = 1; i <= 5; i++) 'https://res.cloudinary.com/demo/image/upload/$i.jpg'],
          'rejectionReasons': null,
        });
      case 'patch /driver/online-status':
        online = (bodies[key] as Map)['isOnline'] == true;
        return http.Response('', 204);
      case 'post /driver/onboarding':
        return json({'id': 99}, 201);
      case 'delete /driver/account':
        return http.Response('', 204);
      case 'post /driver/location':
        return http.Response('', 204);
      case 'get /driver/wallet/earnings':
        return json({'completedTrips': 2, 'netEarnings': 351000});
      case 'get /driver/matching/orders':
        return json(
          orderStatus != 'Pending'
              ? []
              : [
                  {
                    'orderId': 7,
                    'orderCode': 'MM20261110007',
                    'pickupAddress': '12 Nguyễn Huệ, Quận 1',
                    'pickupLatitude': 10.7769,
                    'pickupLongitude': 106.7009,
                    'dropoffAddress': '45 Lê Văn Việt, Thủ Đức',
                    'dropoffLatitude': 10.8473,
                    'dropoffLongitude': 106.7819,
                    'distanceToPickupKm': 0.4,
                    'estimatedDistanceKm': 12.4,
                    'estimatedDurationMin': 35,
                    'totalFee': 195000.0,
                    'commissionAmount': 19500,
                    'driverEarning': 175500.0,
                    'paymentMethod': 'Cash',
                    'payerRole': 'Sender',
                    'cargoQuantity': 3,
                    'cargoWeightKg': 120.0,
                    'createdAt': '2026-11-10T13:00:00+00:00',
                  },
                ],
        );
      case 'get /driver/matching/orders/7':
        return json({
          'orderId': 7,
          'orderCode': 'MM20261110007',
          'pickupAddress': '12 Nguyễn Huệ, Quận 1',
          'pickupLatitude': 10.7769,
          'pickupLongitude': 106.7009,
          'dropoffAddress': '45 Lê Văn Việt, Thủ Đức',
          'dropoffLatitude': 10.8473,
          'dropoffLongitude': 106.7819,
          'totalFee': 195000.0,
          'commissionAmount': 19500,
          'paymentMethod': 'Cash',
          'payerRole': 'Sender',
          'cargo': {'quantity': 3, 'weightKg': 120.0},
          'canAccept': true,
          'ineligibleReason': null,
          'matchingExpiresAt': DateTime.now().add(const Duration(minutes: 9)).toUtc().toIso8601String(),
        });
      case 'post /driver/matching/orders/7/accept':
        orderStatus = 'Accepted';
        return http.Response('', 204);
      case 'get /driver/trips/active':
        return orderStatus == 'Pending' || activeGone ? http.Response('', 204) : json(tripJson);
      case 'get /driver/trips/7':
        return json(tripJson);
      case 'post /driver/incidents':
        final body = bodies[key] as Map;
        incidents.add({
          'id': 21,
          'incidentType': body['incidentType'],
          'description': body['description'],
          'photoUrls': body['photoUrls'] ?? [],
          'reportedByYou': true,
          'resolutionStatus': 'Open',
          'resolutionDecision': null,
          'resolutionNote': null,
          'createdAt': '2026-11-11T14:00:00+00:00',
          'resolvedAt': null,
        });
        return json({'incidentId': 21}, 201);
      case 'get /driver/incidents':
        return json({
          'items': [for (final i in incidents) {...i, 'orderId': 7, 'orderCode': 'MM20261110007'}],
          'pageNumber': 1,
          'hasNextPage': false,
        });
      case 'post /driver/trips/7/arrive':
        if (incidents.any((i) => i['reportedByYou'] == true && (i['resolutionStatus'] == 'Open' || i['resolutionStatus'] == 'InProgress'))) {
          return json({'status': 422, 'title': 'Unprocessable', 'code': 'INCIDENT_PENDING'}, 422);
        }
        orderStatus = 'Arrived';
        return http.Response('', 204);
      case 'post /driver/trips/7/collect-cash':
        paid = true;
        return http.Response('', 204);
      case 'post /driver/trips/7/arrive-dropoff':
        return http.Response('', 204);
      case 'post /driver/trips/7/deliver':
        orderStatus = 'Delivered';
        return http.Response('', 204);
      case 'post /driver/uploads':
        return json({'url': 'https://res.cloudinary.com/demo/image/upload/pod.jpg'});
      case 'get /driver/wallet':
        return json({
          'walletStatus': 'Active',
          'depositBalance': 500000.0,
          'earningsBalance': 120000.0,
          'walletTotal': 620000.0,
          'missingDepositAmount': 0,
          'maxWithdrawableAmount': 620000.0,
          'requiredDeposit': 200000,
          'canReceiveOrders': true,
          'hasActiveOrder': false,
          'hasPendingWithdrawal': false,
          'pendingWithdrawalAmount': 0.0,
          'bankAccount': {'bankName': 'Vietcombank', 'bankAccountNumber': '0900000005', 'bankAccountHolder': 'TÀI XẾ THAY THẾ'},
        });
      case 'get /driver/wallet/transactions':
        return json({
          'items': [
            {'id': 9, 'transactionType': 'TripEarning', 'amount': 252000.0, 'balanceAfter': 845000.0, 'transactionStatus': 'Completed', 'orderCode': 'MMDEMO008', 'createdAt': '2026-11-09T15:55:48+00:00'},
            {'id': 8, 'transactionType': 'CommissionDeduction', 'amount': 20000.0, 'earningsAmount': 0, 'depositAmount': 20000, 'balanceAfter': 480000.0, 'transactionStatus': 'Completed', 'orderCode': 'MMDEMO007', 'createdAt': '2026-11-09T15:39:27+00:00'},
            {'id': 7, 'transactionType': 'DepositRefill', 'amount': 30000.0, 'earningsAmount': 30000, 'depositAmount': 30000, 'balanceAfter': 500000.0, 'transactionStatus': 'Completed', 'orderCode': null, 'createdAt': '2026-11-09T15:30:00+00:00'},
          ],
          'pageNumber': 1,
          'hasNextPage': false,
        });
      case 'get /driver/wallet/withdrawals':
        return json({'items': [], 'pageNumber': 1, 'hasNextPage': false});
      case 'get /driver/trips':
        return json({
          'items': [
            {'id': 10, 'orderCode': 'MMDEMO010', 'orderStatus': 'Completed', 'pickupAddress': '12 Nguyễn Huệ', 'dropoffAddress': '45 Lê Văn Việt', 'totalFee': 210000.0, 'commissionAmount': 21000.0, 'driverEarning': 189000.0, 'paymentMethod': 'PayOS', 'customerName': 'Khách hàng Demo', 'completedAt': '2026-11-04T15:05:39+00:00'},
          ],
          'pageNumber': 1,
          'hasNextPage': false,
        });
      case 'get /driver/ratings':
        return json({
          'averageStars': 3.5,
          'totalRatings': 2,
          'fiveStarCount': 1,
          'fourStarCount': 0,
          'threeStarCount': 0,
          'twoStarCount': 1,
          'oneStarCount': 0,
          'reviews': {
            'items': [
              {'id': 2, 'orderId': 7, 'orderCode': 'MMDEMO007', 'ratingStars': 5, 'reviewComment': 'Giao nhanh, thân thiện', 'customerName': 'Khách hàng Demo', 'createdAt': '2026-11-09T15:39:43+00:00'},
            ],
            'pageNumber': 1,
            'hasNextPage': false,
          },
        });
      case 'post /driver/trips/7/pickup':
        orderStatus = 'PickedUp';
        proofStatus = 'Pending';
        pickupSubmissions++;
        return http.Response('', 204);
    }
    return json({'status': 404, 'title': 'Not found', 'code': 'NOT_FOUND'}, 404);
  }
}

final _png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0]);

class _FixedLocation implements DriverLocationSource {
  const _FixedLocation([this.point = const GeoPoint(10.7769, 106.7009)]);
  final GeoPoint point;
  @override
  Future<GeoPoint?> current() async => point;
}

({DriverApi api, FakeBackend backend}) _setup({String profileApproval = 'Approved'}) {
  final backend = FakeBackend(profileApproval: profileApproval);
  final client = MockClient(backend.handle);
  final sessions = MemorySessionStore(
    const Session(accessToken: 'a', refreshToken: 'r', userId: 5, fullName: 'Tài xế', role: 'Driver'),
  );
  return (api: DriverApi(ApiClient(sessions: sessions, client: client, baseUrl: 'http://test/api')), backend: backend);
}

void main() {
  test('hồ sơ tài xế được đọc từ BE: duyệt, xe, 7 loại ảnh (hồ sơ cũ 5 ảnh thì thiếu CCCD), kích thước thùng', () async {
    final env = _setup();
    final repository = BackendDriverRepository(api: env.api);
    final app = await repository.refresh();
    expect(app.status, ApprovalStatus.approved);
    expect(app.canGoOnline, isTrue);
    expect(app.online, isTrue);
    expect(app.fields['plate'], '51C-222.22');
    expect(app.fields['payload'], '500');
    expect(app.fields['length'], '1,7');
    expect(app.fields['vehicleTypeId'], '1');
    expect(app.documents.length, 7);
    expect(app.documents[DocumentKind.vehicle]!.remoteReference, startsWith('https://'));
    expect(app.documents[DocumentKind.citizenIdFront]!.hasImage, isFalse);
    expect(app.documents[DocumentKind.licenseFront]!.remoteReference, startsWith('https://'));
    expect(app.version, 1);
  });

  test('hồ sơ tài xế bị từ chối ở BE thì app không cho online', () async {
    final env = _setup(profileApproval: 'Rejected');
    final app = await BackendDriverRepository(api: env.api).refresh();
    expect(app.status, ApprovalStatus.rejected);
    expect(app.canGoOnline, isFalse);
  });

  test('ghép đơn → nhận đơn → đến nơi → gửi ảnh lấy hàng qua đúng endpoint BE', () async {
    final env = _setup();
    final repository = ApiDriverTripRepository(
      api: env.api,
      location: _FixedLocation(),
      access: const DriverAccess(approved: true, active: true),
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(repository.close);

    repository.onSessionChanged(isDriver: true);
    await repository.refresh();
    var session = repository.current;
    expect(session.online, isTrue);
    expect(session.deposit, 500000);
    expect(session.earnings, 120000);
    expect(session.shift.completed, 2);
    expect(session.jobs, hasLength(1));
    final job = session.jobs.single;
    expect(job.id, '7');
    expect(job.label, 'MM20261110007');
    expect(job.payment, PaymentMethod.cashSender);
    expect(job.weightKg, 120);
    expect(job.net, 175500);
    expect(env.backend.requests, contains('post /driver/location'));

    await repository.openOffer('7');
    expect(repository.current.offer!.remainingAt(repository.now), inInclusiveRange(29, 30));
    await repository.acceptOffer('7');
    session = repository.current;
    expect(session.trip!.stage, TripStage.accepted);
    expect(session.jobs, isEmpty);

    await repository.arrive();
    expect(repository.current.trip!.stage, TripStage.arrived);
    expect(repository.current.trip!.editable, isTrue);

    await repository.submitInspection(
      evidence: const [
        UploadedEvidence(CargoPhotoKind.overall, 'https://x/1.jpg'),
        UploadedEvidence(CargoPhotoKind.secured, 'https://x/2.jpg'),
      ],
      checklist: const [true, true, true, true],
      note: '',
      cashCollected: true,
    );
    // Đơn tiền mặt do người gửi trả: thu tiền trước khi gửi ảnh.
    expect(env.backend.requests, containsAllInOrder(['post /driver/trips/7/collect-cash', 'post /driver/trips/7/pickup']));
    expect((env.backend.bodies['post /driver/trips/7/pickup'] as Map)['photoUrls'], ['https://x/1.jpg', 'https://x/2.jpg']);
    final trip = repository.current.trip!;
    expect(trip.stage, TripStage.pickedUp);
    expect(trip.review, EvidenceReview.pending);
    expect(trip.attempts, 1);

    // Khách từ chối ảnh → tài xế được gửi lại.
    env.backend.proofStatus = 'Rejected';
    await repository.refresh();
    expect(repository.current.trip!.review, EvidenceReview.rejected);
    expect(repository.current.trip!.reason, 'Ảnh chưa rõ dây chằng.');
    expect(repository.current.trip!.editable, isTrue);

    // Khách duyệt → bắt đầu giao.
    env.backend.orderStatus = 'InTransit';
    await repository.refresh();
    expect(repository.current.trip!.stage, TripStage.inTransit);
    expect(repository.current.trip!.review, EvidenceReview.approved);

    // Giai đoạn giao hàng: báo đến điểm giao -> ảnh POD -> hoàn tất (tiền mặt đã thu lúc lấy hàng).
    await repository.arriveDropoff();
    expect(env.backend.requests, contains('post /driver/trips/7/arrive-dropoff'));
    await repository.deliver(CargoPhoto(kind: CargoPhotoKind.overall, name: 'pod.png', bytes: _png));
    expect(env.backend.requests, containsAllInOrder(['post /driver/uploads', 'post /driver/trips/7/deliver']));
    expect((env.backend.bodies['post /driver/trips/7/deliver'] as Map)['deliveryPhotoUrl'], contains('pod.jpg'));
    expect(repository.current.trip, isNull);
    expect(repository.current.notice, contains('MM20261110007'));
  });

  // Lỗi cũ: kịch bản giả lập "gần điểm lấy" giữ vị trí giả mãi sau khi chuyến kết thúc, nên đơn kế tiếp ở cùng
  // khu vực hiện "Cách bạn 0,0 km" dù tài xế ở xa.
  test('kết thúc chuyến thì bỏ vị trí giả lập, quay về vị trí thật', () async {
    final env = _setup();
    // Tài xế ở xa điểm lấy hàng (khác 10.7769, 106.7009 của dữ liệu giả).
    const home = GeoPoint(10.9000, 106.8000);
    final repository = ApiDriverTripRepository(
      api: env.api,
      location: const _FixedLocation(home),
      access: const DriverAccess(approved: true, active: true),
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(repository.close);
    repository.onSessionChanged(isDriver: true);
    await repository.refresh();
    await repository.setOnline(true);
    await repository.openOffer('7');
    await repository.acceptOffer('7');
    await repository.simulate(TripSimulation.nearPickup);
    final pickup = repository.current.trip!.job.pickupPoint;
    expect(repository.current.fix!.point.latitude, pickup.latitude);

    env.backend.orderStatus = 'InTransit';
    await repository.refresh();
    await repository.collectCash();
    await repository.deliver(CargoPhoto(kind: CargoPhotoKind.overall, name: 'pod.png', bytes: _png));
    await repository.refresh();
    // Về vị trí của nguồn GPS (_FixedLocation), không còn dính điểm lấy hàng của chuyến cũ.
    expect(repository.current.fix!.point.latitude, home.latitude);
    expect(repository.current.fix!.point.longitude, home.longitude);
  });

  test('đơn bị tài xế khác nhận trước (409) được bỏ khỏi danh sách và báo lỗi tiếng Việt', () async {
    final backend = FakeBackend();
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/accept')) {
        return http.Response(
          jsonEncode({'status': 409, 'title': 'Conflict', 'code': 'CONFLICT'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }
      return backend.handle(request);
    });
    final sessions = MemorySessionStore(
      const Session(accessToken: 'a', refreshToken: 'r', userId: 5, fullName: 'T', role: 'Driver'),
    );
    final repository = ApiDriverTripRepository(
      api: DriverApi(ApiClient(sessions: sessions, client: client, baseUrl: 'http://test/api')),
      location: _FixedLocation(),
      access: const DriverAccess(approved: true, active: true),
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(repository.close);
    repository.onSessionChanged(isDriver: true);
    await repository.refresh();
    await repository.openOffer('7');
    await expectLater(
      repository.acceptOffer('7'),
      throwsA(isA<TripFailure>().having((e) => e.message, 'message', 'Đơn đã có tài xế khác nhận trước.')),
    );
    expect(repository.current.jobs, isEmpty);
  });

  test('giả lập GPS trên máy ảo: đến điểm lấy hàng / đi 300 m / mất GPS gửi vị trí lên BE', () async {
    final env = _setup();
    final repository = ApiDriverTripRepository(
      api: env.api,
      location: _FixedLocation(),
      access: const DriverAccess(approved: true, active: true),
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(repository.close);
    repository.onSessionChanged(isDriver: true);
    await repository.refresh();
    await repository.openOffer('7');
    await repository.acceptOffer('7');
    expect(repository.supported, contains(TripSimulation.nearPickup));

    // Đang cách điểm lấy hàng ~100 m rồi đi tiếp: tối đa 300 m mỗi lần.
    await repository.simulate(TripSimulation.advanceRoute);
    final pickup = repository.current.trip!.job.pickupPoint;
    expect(repository.current.fix!.point.distanceTo(pickup), lessThanOrEqualTo(1));

    await repository.simulate(TripSimulation.nearDropoff);
    final dropoff = repository.current.trip!.job.dropoffPoint;
    final sent = env.backend.bodies['post /driver/location'] as Map;
    expect(sent['latitude'], dropoff.latitude);
    expect(sent['longitude'], dropoff.longitude);

    await repository.simulate(TripSimulation.gpsLost);
    expect(repository.current.gpsEnabled, isFalse);
    expect(repository.current.fix, isNull);
    await repository.simulate(TripSimulation.gpsRestored);
    expect(repository.current.gpsEnabled, isTrue);
    await expectLater(repository.simulate(TripSimulation.cancelOrder), throwsA(isA<TripFailure>()));
  });

  test('nộp hồ sơ gửi đúng 7 ảnh theo thứ tự BE (D2): GPLX, đăng ký, đăng kiểm, ảnh xe, CCCD trước, CCCD sau', () async {
    final env = _setup();
    final docs = {for (final kind in DocumentKind.values) kind: VerificationDocument(remoteReference: 'https://res.cloudinary.com/demo/${kind.name}.jpg')};
    final draft = DriverApplication(
      status: ApprovalStatus.draft,
      fields: const {'vehicleTypeId': '1', 'citizenId': '079090000002', 'license': '790000000002', 'plate': '51c-222.22', 'payload': '500'},
      documents: docs,
    );
    await BackendDriverRepository(api: env.api, cached: draft).submit(draft);
    final body = env.backend.bodies['post /driver/onboarding'] as Map;
    expect(body['documentUrls'], [
      for (final name in ['licenseFront', 'licenseBack', 'registration', 'inspection', 'vehicle', 'citizenIdFront', 'citizenIdBack']) 'https://res.cloudinary.com/demo/$name.jpg',
    ]);
    expect(body['licensePlate'], '51C-222.22');
  });

  test('thiếu ảnh CCCD thì không gửi hồ sơ lên BE', () async {
    final env = _setup();
    final docs = {for (final kind in DocumentKind.values) kind: VerificationDocument(remoteReference: kind.isPersonal && kind.name.startsWith('citizen') ? null : 'https://res.cloudinary.com/demo/${kind.name}.jpg')};
    final draft = DriverApplication(status: ApprovalStatus.draft, fields: const {'vehicleTypeId': '1', 'payload': '500'}, documents: docs);
    await expectLater(BackendDriverRepository(api: env.api, cached: draft).submit(draft), throwsA(isA<ApplicationFailure>()));
    expect(env.backend.requests, isNot(contains('post /driver/onboarding')));
  });

  test('xoá tài khoản tài xế gọi DELETE /driver/account (Q12)', () async {
    final env = _setup();
    await env.api.deleteAccount();
    expect(env.backend.requests, contains('delete /driver/account'));
  });
}
