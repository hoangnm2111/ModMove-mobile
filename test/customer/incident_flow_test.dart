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

class _Backend {
  _Backend({this.pendingId, this.incidents = const []});
  int? pendingId;
  List<Map<String, dynamic>> incidents;
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
    if (p.endsWith('/customer/Refunds') || p.endsWith('/customer/Ratings')) return _json(paged([]));
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

  testWidgets('form báo sự cố: lý do nhanh chọn đúng loại và điền câu mở đầu rồi gửi lên BE', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _Backend();
    final order = OrderDetail.fromJson(orderDetailJson(status: 'InTransit'));
    await tester.pumpWidget(_app(backend, (api) => Scaffold(body: SingleChildScrollView(child: IncidentSheet(api: api, order: order)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tài xế chỉ nhận thông báo chung'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('incident-reason-Hàng hư hỏng')));
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('customer-incident-description')));
    expect(field.controller!.text, startsWith('Hàng bị hư hỏng'));

    await tester.enterText(find.byKey(const Key('customer-incident-description')), 'Hàng bị hư hỏng: thùng số 2 bị móp');
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pumpAndSettle();
    final body = backend.bodies['POST /customer/Incidents'] as Map?;
    expect(body?['incidentType'], 'DamagedCargo');
    expect(body?['description'], 'Hàng bị hư hỏng: thùng số 2 bị móp');
  });
}
