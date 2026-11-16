import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/domain/entities/customer_models.dart';
import 'package:modmove_mobile/features/customer/domain/order_rules.dart';
import 'package:modmove_mobile/features/customer/presentation/order_detail/order_detail_screen.dart';
import 'package:modmove_mobile/features/customer/presentation/order_detail/order_sheets.dart';

import 'fixtures.dart';

const _session = Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'Khách hàng Demo', role: 'Customer');

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _incident(int id, {required bool byYou, String status = 'Open', String? decision, String? note, List<String> photos = const []}) => {
  'id': id,
  'orderId': 8,
  'orderCode': 'MM20261104008',
  'incidentType': 'VehicleBreakdown',
  'description': byYou ? 'Tài xế đến trễ quá lâu' : 'Xe hỏng giữa đường, đang chờ hỗ trợ',
  'photoUrls': photos,
  'reportedByYou': byYou,
  'resolutionStatus': status,
  'resolutionDecision': decision,
  'resolutionNote': note,
  'createdAt': '2026-11-11T14:00:00Z',
  'resolvedAt': null,
};

Map<String, dynamic> _refund(int id, String source, {int? incidentId, String status = 'Requested', String reason = 'Lý do hoàn tiền'}) => {
  'id': id,
  'orderId': 8,
  'orderCode': 'MM20261104008',
  'incidentId': incidentId,
  'sourceType': source,
  'refundStatus': status,
  'reason': reason,
  'requestedAmount': 100000,
  'approvedAmount': null,
  'decisionReason': null,
  'waitingForYourReply': false,
  'needsPayoutAccount': true,
  'evidenceUrls': <String>[],
  'createdAt': '2026-11-11T14:00:00Z',
};

class _Backend {
  _Backend({this.pendingId, this.incidents = const [], this.refunds = const []});
  int? pendingId;
  List<Map<String, dynamic>> incidents;
  List<Map<String, dynamic>> refunds;
  final calls = <String>[];
  final bodies = <String, Object?>{};
  bool approveFails = false;

  Future<http.Response> handle(http.Request req) async {
    final key = '${req.method} ${req.url.path}';
    calls.add(key);
    if (req.body.isNotEmpty) bodies[key] = jsonDecode(req.body);
    final p = req.url.path;
    if (p.endsWith('/customer/Orders/8/pickup-evidence')) {
      return approveFails ? _json({'status': 422, 'title': 'x', 'code': 'INCIDENT_PENDING'}, 422) : http.Response('', 204);
    }
    if (p.endsWith('/customer/Orders/8')) {
      return _json({
        ...orderDetailJson(status: 'PickedUp', proofStatus: 'Pending'),
        'pendingDriverIncidentId': pendingId,
      });
    }
    if (p.endsWith('/customer/Incidents') && req.method == 'GET') return _json(paged(incidents));
    if (p.endsWith('/customer/Incidents') && req.method == 'POST') return _json({'incidentId': 99}, 201);
    if (p.endsWith('/customer/Refunds') && req.method == 'GET') return _json(paged(refunds));
    final detail = RegExp(r'/customer/Refunds/(\d+)$').firstMatch(p);
    if (detail != null) return _json(refunds.firstWhere((r) => r['id'] == int.parse(detail.group(1)!)));
    if (p.endsWith('/customer/Ratings')) return _json(paged([]));
    return _json({'code': 'NOT_FOUND'}, 404);
  }
}

Widget _app(_Backend backend, Widget Function(CustomerApi api) home) {
  final api = ApiClient(sessions: MemorySessionStore(_session), baseUrl: 'http://api', client: MockClient(backend.handle));
  final customer = CustomerApi(api);
  return MultiRepositoryProvider(
    providers: [RepositoryProvider.value(value: api), RepositoryProvider.value(value: customer)],
    child: MaterialApp(theme: buildAppTheme(), home: home(customer)),
  );
}

FilledButton _approve(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('approve-pickup')));

void main() {
  test('đơn có sự cố tài xế mở thì không duyệt được ảnh lấy hàng', () {
    final blocked = OrderDetail.fromJson({...orderDetailJson(status: 'PickedUp', proofStatus: 'Pending'), 'pendingDriverIncidentId': 21});
    final free = OrderDetail.fromJson(orderDetailJson(status: 'PickedUp', proofStatus: 'Pending'));
    expect(blocked.pendingDriverIncidentId, 21);
    expect(OrderRules.canApprovePickup(blocked), isFalse);
    expect(free.pendingDriverIncidentId, isNull);
    expect(OrderRules.canApprovePickup(free), isTrue);
  });

  testWidgets('tài xế báo sự cố: banner hiện, nút duyệt tắt, từ chối vẫn bấm được; thẻ sự cố tách hai nhóm', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend(
      pendingId: 21,
      incidents: [
        _incident(21, byYou: false, status: 'InProgress', photos: ['https://x/1.jpg']),
        _incident(22, byYou: true),
        _incident(23, byYou: true, status: 'Resolved', decision: 'ContinueTrip', note: 'Đã kiểm tra'),
        _incident(24, byYou: true, status: 'Cancelled', note: 'Trùng báo cáo'),
      ],
    );
    await tester.pumpWidget(_app(backend, (_) => const OrderDetailScreen(orderId: 8)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('driver-incident-banner')), findsOneWidget);
    expect(find.textContaining('Tài xế đã báo sự cố #21'), findsOneWidget);
    expect(_approve(tester).onPressed, isNull);
    expect(find.text('Từ chối, chụp lại'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Từ chối, chụp lại')).onPressed, isNotNull);
    expect(find.textContaining('Chưa duyệt được khi tài xế đang có sự cố'), findsOneWidget);

    // Gọi API theo đơn (BE lọc), thẻ sự cố tách "Tài xế báo" và "Bạn báo".
    expect(backend.calls.any((c) => c.startsWith('GET ') && c.endsWith('/customer/Incidents')), isTrue);
    await tester.scrollUntilVisible(find.text('TÀI XẾ BÁO'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('TÀI XẾ BÁO'), findsOneWidget);
    expect(find.text('BẠN BÁO'), findsOneWidget);
    expect(find.text('Xe hỏng giữa đường, đang chờ hỗ trợ'), findsOneWidget);
    expect(find.text('Điều phối viên đang xử lý'), findsWidgets);
    expect(find.textContaining('Kết quả: Tiếp tục chuyến – Đã kiểm tra'), findsOneWidget);
    expect(find.textContaining('Báo cáo đã bị hủy: Trùng báo cáo'), findsOneWidget);
  });

  testWidgets('khoản hoàn của sự cố nằm trong thẻ sự cố; chỉ khiếu nại / hoàn huỷ đơn ở thẻ Hoàn tiền; còn khoản mở thì ẩn nút gửi thêm', (tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend(
      incidents: [
        _incident(22, byYou: true),
        _incident(23, byYou: true, status: 'Resolved', decision: 'ContinueTrip', note: 'Đã kiểm tra'),
      ],
      refunds: [
        _refund(5, 'Incident', incidentId: 22, reason: 'Bồi thường vỏ thùng móp'),
        _refund(6, 'Complaint', reason: 'Giao trễ 2 giờ'),
      ],
    );
    await tester.pumpWidget(_app(backend, (_) => const OrderDetailScreen(orderId: 8)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('BẠN BÁO'), 300, scrollable: find.byType(Scrollable).first);

    // Thẻ sự cố #22 chứa khoản hoàn #5; thẻ riêng chỉ còn khiếu nại #6.
    expect(find.text('Hoàn do sự cố #5'), findsOneWidget);
    expect(find.text('Bồi thường vỏ thùng móp'), findsOneWidget);
    expect(find.text('Sự cố 2'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hoàn tiền và khiếu nại 1'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Hoàn tiền và khiếu nại 1'), findsOneWidget);
    expect(find.text('Khiếu nại #6'), findsOneWidget);
    expect(find.text('Giao trễ 2 giờ'), findsOneWidget);

    // Sự cố #22 đang có khoản hoàn mở nên không có nút gửi thêm; sự cố #23 chưa có thì còn nút.
    expect(find.text('Yêu cầu hoàn tiền cho sự cố này'), findsOneWidget);
  });

  testWidgets('Dispatcher huỷ đơn vì sự cố: khoản hoàn (Cancellation + incidentId) nằm trong thẻ sự cố, không lặp ở thẻ Hoàn tiền', (tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend(
      incidents: [_incident(22, byYou: true, status: 'Resolved', decision: 'CancelOrder', note: 'Chấp nhận')],
      refunds: [_refund(7, 'Cancellation', incidentId: 22, reason: 'Chấp Nhận')],
    );
    await tester.pumpWidget(_app(backend, (_) => const OrderDetailScreen(orderId: 8)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('BẠN BÁO'), 300, scrollable: find.byType(Scrollable).first);

    expect(find.text('Hoàn do huỷ đơn #7'), findsOneWidget);
    expect(find.textContaining('Hoàn tiền & khiếu nại'), findsNothing);
    expect(find.text('Yêu cầu hoàn tiền cho sự cố này'), findsNothing);
  });

  testWidgets('không có sự cố chặn: nút duyệt bấm được', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_Backend(), (_) => const OrderDetailScreen(orderId: 8)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver-incident-banner')), findsNothing);
    expect(_approve(tester).onPressed, isNotNull);
  });

  testWidgets('BE trả INCIDENT_PENDING khi duyệt: tải lại chi tiết đơn và hiện banner', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend()..approveFails = true;
    await tester.pumpWidget(_app(backend, (_) => const OrderDetailScreen(orderId: 8)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('driver-incident-banner')), findsNothing);

    // Tài xế vừa báo sự cố sau lần tải đầu: BE từ chối, app tải lại và khoá nút.
    backend.pendingId = 21;
    await tester.tap(find.byKey(const Key('approve-pickup')));
    await tester.pumpAndSettle();
    expect(find.textContaining('chuyến đang tạm dừng'), findsWidgets);
    expect(find.byKey(const Key('driver-incident-banner')), findsOneWidget);
    expect(_approve(tester).onPressed, isNull);
  });

  testWidgets('form báo sự cố của khách: chỉ điền mô tả, loại luôn là Other, gửi đúng chữ khách nhập', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend();
    final order = OrderDetail.fromJson(orderDetailJson(status: 'InTransit'));
    await tester.pumpWidget(_app(backend, (api) => Scaffold(body: SingleChildScrollView(child: IncidentSheet(api: api, order: order)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tài xế chỉ nhận thông báo chung'), findsNothing);

    // Không có nút "Lý do nhanh" và không có ô chọn loại; mô tả để trống.
    expect(find.text('Lý do nhanh'), findsNothing);
    expect(find.text('Loại sự cố'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    final field = tester.widget<TextField>(find.byKey(const Key('customer-incident-description')));
    expect(field.controller!.text, isEmpty);

    // Gửi trống bị chặn, không gọi BE.
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pumpAndSettle();
    expect(backend.bodies['POST /customer/Incidents'], isNull);

    await tester.enterText(find.byKey(const Key('customer-incident-description')), 'Thùng số 2 bị móp khi bốc lên xe');
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pumpAndSettle();
    final body = backend.bodies['POST /customer/Incidents'] as Map?;
    expect(body?['incidentType'], 'Other');
    expect(body?['description'], 'Thùng số 2 bị móp khi bốc lên xe');
  });
}
