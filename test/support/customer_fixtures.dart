import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/customer/data/remote_customer_repository.dart';
import 'package:modmove_mobile/features/customer/domain/customer_models.dart';
import 'package:modmove_mobile/features/customer/domain/customer_repository.dart';
import 'remote_fixtures.dart';

Map<String, dynamic> customerOrder({
  int id = 1,
  String status = 'PickedUp',
  String method = 'PayOS',
  String payment = 'Paid',
  DateTime? at,
  int? pendingIncident,
}) => {
  'id': id,
  'orderCode': 'MM-TEST-$id',
  'orderStatus': status,
  'pickupAddress': '12 Nguyễn Huệ, Quận 1',
  'dropoffAddress': '24 Võ Văn Ngân, Thủ Đức',
  'vehicleTypeName': 'Xe tải 500 kg',
  'receiverName': 'Người nhận kiểm thử',
  'receiverPhone': '0901234567',
  'estimatedDistanceKm': 10,
  'estimatedDurationMin': 25,
  'hasLoadingService': false,
  'distanceFee': 100000,
  'serviceFee': 0,
  'discountAmount': 10000,
  'totalFee': 90000,
  'paymentMethod': method,
  'payerRole': method == 'Cash' ? 'Sender' : null,
  'paymentStatus': payment,
  'createdAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
  'cargo': {
    'cargoType': 'OTHER',
    'cargoTypeName': 'Hàng khác',
    'quantity': 2,
    'weightKg': 5,
    'lengthCm': 20,
    'widthCm': 30,
    'heightCm': 40,
    'photoUrls': <String>[],
    'specialNotes': 'Hàng dễ vỡ',
  },
  'driver': {
    'fullName': 'Tài xế kiểm thử',
    'phoneNumber': '0909999999',
    'licensePlate': '59A-12345',
  },
  'proof': {
    'pickupPhotoUrls': <String>[],
    'proofStatus': 'Pending',
    'pickupSubmissionCount': 1,
    'rejectionReason': null,
    'deliveryPhotoUrl': null,
    'deliveredAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
  },
  'history': [
    {
      'fromStatus': null,
      'toStatus': status,
      'changedByRole': 'Customer',
      'note': '',
      'changedAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
    },
  ],
  'couponCode': null,
  'payment': {
    'transactionStatus': 'Paid',
    'checkoutUrl': null,
    'expiresAt': null,
    'paidAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
    'isExpired': false,
  },
  'pendingDriverIncidentId': pendingIncident,
};
Map<String, dynamic> customerRefund({
  String status = 'Requested',
  String source = 'Complaint',
}) => {
  'id': 1,
  'orderId': 1,
  'orderCode': 'MM-TEST-1',
  'sourceType': source,
  'refundStatus': status,
  'requestedAmount': 10000,
  'approvedAmount': null,
  'reason': 'Hàng bị hư',
  'decisionReason': null,
  'infoRequestNote': 'Chụp thêm mặt bên',
  'customerReply': null,
  'waitingForYourReply': true,
  'needsPayoutAccount': false,
  'payoutAccount': {
    'bankCode': '970436',
    'bankName': 'Vietcombank',
    'maskedAccountNumber': '******6789',
    'accountHolder': 'NGUYEN VAN A',
  },
  'suggestedPayoutAccount': null,
  'payoutFailureReason': null,
  'bankReferenceCode': null,
  'evidenceUrls': <String>[],
  'createdAt': DateTime.now().toUtc().toIso8601String(),
};
const validDraft = BookingDraft(
  pickup: '12 Nguyễn Huệ',
  dropoff: '24 Võ Văn Ngân',
  receiver: 'Người nhận',
  phone: '0901234567',
  cargoType: 'OTHER',
  quantity: 2,
  weight: 5,
  length: 20,
  width: 30,
  height: 40,
  photos: ['https://res.cloudinary.com/test/cargo.jpg'],
  vehicleId: 1,
  committed: true,
);
const fare = Fare(10, 25, 100000, 0, 10000, 90000);
Map<String, dynamic> pageJson(
  List<dynamic> items, {
  int page = 1,
  bool next = false,
}) => {
  'items': items,
  'pageNumber': page,
  'pageSize': 20,
  'totalCount': items.length,
  'hasNextPage': next,
};

class CustomerTestApi {
  CustomerTestApi({this.handler}) {
    api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient((r) async {
        requests.add(r);
        final custom = await handler?.call(r);
        return custom ?? respond(r);
      }),
    );
    repository = RemoteCustomerRepository(api);
  }
  final Future<http.Response?> Function(http.Request)? handler;
  final requests = <http.Request>[];
  late final ApiClient api;
  late final RemoteCustomerRepository repository;
  Future<void> login() => api.saveSession(tokens('access', 'Customer'));
  Future<void> close() => api.close();
  http.Response respond(http.Request r) {
    final path = r.url.path.toLowerCase();
    if (path.endsWith('/vehicletypes')) {
      return jsonResponse([
        {
          'id': 1,
          'name': 'Xe tải 500 kg',
          'maxLoadWeightKg': 500,
          'cargoBedLengthCm': 200,
          'cargoBedWidthCm': 150,
          'cargoBedHeightCm': 150,
        },
      ]);
    }
    if (path.contains('/lookups/')) {
      return jsonResponse([
        {'code': 'OTHER', 'name': 'Khác', 'description': 'Mô tả'},
        if (path.endsWith('/banks'))
          {'code': '970436', 'name': 'Vietcombank', 'description': ''},
      ]);
    }
    if (path.endsWith('/policies')) {
      return jsonResponse([
        {
          'code': 'WARRANTY',
          'name': 'Bảo đảm hàng hóa',
          'description': 'Chính sách từ server',
        },
      ]);
    }
    if (path.endsWith('/fareestimate')) {
      return jsonResponse({
        'distanceKm': 10,
        'durationMinutes': 25,
        'distanceFee': 100000,
        'serviceFee': 0,
        'discountAmount': 10000,
        'totalFee': 90000,
      });
    }
    if (path.endsWith('/profile')) {
      return jsonResponse({
        'fullName': 'Khách hàng',
        'phoneNumber': '0901234567',
        'email': 'customer@test.local',
        'role': 'Customer',
        'emailVerified': true,
      });
    }
    if (path.endsWith('/orders') && r.method == 'GET') {
      return jsonResponse(pageJson([customerOrder()]));
    }
    if (path.endsWith('/tracking')) {
      return jsonResponse({
        'orderId': 1,
        'orderStatus': 'InTransit',
        'pickup': {'latitude': 10.7, 'longitude': 106.7},
        'dropoff': {'latitude': 10.8, 'longitude': 106.8},
        'driver': {
          'latitude': 10.75,
          'longitude': 106.75,
          'at': DateTime.now().toUtc().toIso8601String(),
          'isStale': false,
        },
        'eta': {'target': 'Dropoff', 'durationMinutes': 10},
      });
    }
    if (RegExp(r'/orders/[0-9]+$').hasMatch(path)) {
      return jsonResponse(customerOrder());
    }
    if (path.endsWith('/orders') && r.method == 'POST') {
      return jsonResponse({
        'orderId': 99,
        'orderCode': 'MM-99',
        'totalFee': 90000,
      }, 201);
    }
    if (path.endsWith('/ratings') ||
        path.endsWith('/refunds') ||
        path.endsWith('/incidents') ||
        path.endsWith('/coupons')) {
      return jsonResponse(pageJson([]));
    }
    if (RegExp(r'/refunds/[0-9]+$').hasMatch(path)) {
      return jsonResponse(customerRefund());
    }
    if (path.endsWith('/uploads')) {
      return jsonResponse({
        'url': 'https://res.cloudinary.com/test/upload.png',
      });
    }
    return http.Response('', 204);
  }
}

class TestCustomerRealtime implements CustomerRealtime {
  final controller = StreamController<CustomerRealtimeEvent>.broadcast();
  int starts = 0, stops = 0;
  @override
  Stream<CustomerRealtimeEvent> get events => controller.stream;
  @override
  Future<void> start(int orderId) async {
    starts++;
  }

  @override
  Future<void> stop() async {
    if (stops++ == 0) await controller.close();
  }
}

Map<String, dynamic> requestBody(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;
