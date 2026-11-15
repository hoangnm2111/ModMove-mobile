import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/notifications/notice_catalog.dart';
import 'package:modmove_mobile/core/notifications/notification_cubit.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/notice_banner.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/presentation/order_detail/order_detail_screen.dart';

import '../customer/fixtures.dart';

const _session = Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'Khách hàng Demo', role: 'Customer');

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

/// BE không lưu bước "tài xế đã đến điểm giao" (chỉ gửi thông báo DRIVER_ARRIVED_DROPOFF, không đổi trạng thái đơn),
/// nên khách phải thấy nó trên chi tiết đơn từ thông báo của phiên.
void main() {
  Future<NotificationCubit> pumpScreen(WidgetTester tester, {String status = 'InTransit', NotificationCubit? notices}) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = notices ?? NotificationCubit();
    addTearDown(cubit.close);
    final api = ApiClient(
      sessions: MemorySessionStore(_session),
      baseUrl: 'http://api',
      client: MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/customer/Orders/8')) return _json({...orderDetailJson(status: status, method: 'Cash', payment: 'Unpaid'), 'payerRole': 'Receiver'});
        if (p.endsWith('/customer/Incidents') || p.endsWith('/customer/Refunds') || p.endsWith('/customer/Ratings')) return _json(paged([]));
        return _json({'code': 'NOT_FOUND'});
      }),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [RepositoryProvider.value(value: api), RepositoryProvider.value(value: CustomerApi(api))],
        child: BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => NoticeHost(onOpen: (_) {}, child: child!),
            home: const OrderDetailScreen(orderId: 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('đơn đang giao: chưa có thông báo thì hiện "Hàng đang được vận chuyển"', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Hàng đang được vận chuyển'), findsOneWidget);
    expect(find.text('Tài xế đã đến điểm giao'), findsNothing);
  });

  testWidgets('thông báo tới khi đang xem: thẻ xanh, bước tiến trình đổi, nhắc tiền mặt người nhận trả', (tester) async {
    final notices = await pumpScreen(tester);
    notices.push(noticeFor('DRIVER_ARRIVED_DROPOFF', data: {'orderId': '8', 'orderCode': 'MM8'}, at: DateTime(2026, 11, 15, 16, 51)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Thẻ hành động + nhãn bước trong thanh tiến trình (cả hai cùng dòng chữ).
    expect(find.text('Tài xế đã đến điểm giao'), findsWidgets);
    expect(find.text('Hàng đang được vận chuyển'), findsNothing);
    expect(find.textContaining('lúc 16:51'), findsOneWidget);
    expect(find.textContaining('Người nhận thanh toán'), findsOneWidget);
  });

  testWidgets('mở màn sau khi thông báo đã tới (có trong hộp thông báo của phiên): vẫn hiện', (tester) async {
    final notices = NotificationCubit();
    notices.push(noticeFor('DRIVER_ARRIVED_DROPOFF', data: {'orderId': '8', 'orderCode': 'MM8'}, at: DateTime(2026, 11, 15, 16, 51)));
    await pumpScreen(tester, notices: notices);
    expect(find.textContaining('lúc 16:51'), findsOneWidget);
  });

  testWidgets('thông báo của đơn khác thì không ảnh hưởng', (tester) async {
    final notices = await pumpScreen(tester);
    notices.push(noticeFor('DRIVER_ARRIVED_DROPOFF', data: {'orderId': '99', 'orderCode': 'MM99'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hàng đang được vận chuyển'), findsOneWidget);
  });

  testWidgets('đơn đã giao: không còn hiện "đã đến điểm giao" dù có thông báo cũ', (tester) async {
    final notices = NotificationCubit();
    notices.push(noticeFor('DRIVER_ARRIVED_DROPOFF', data: {'orderId': '8', 'orderCode': 'MM8'}));
    await pumpScreen(tester, status: 'Delivered', notices: notices);
    expect(find.textContaining('Tài xế báo đã tới điểm giao'), findsNothing);
  });
}
