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

void main() {
  late int orderLoads;
  late NotificationCubit notices;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    orderLoads = 0;
    notices = NotificationCubit();
    addTearDown(notices.close);
    final api = ApiClient(
      sessions: MemorySessionStore(_session),
      baseUrl: 'http://api',
      client: MockClient((req) async {
        final p = req.url.path;
        if (p.endsWith('/customer/Orders/8')) {
          orderLoads++;
          return _json(orderDetailJson(status: 'PickedUp'));
        }
        if (p.endsWith('/customer/Incidents') || p.endsWith('/customer/Refunds') || p.endsWith('/customer/Ratings')) return _json(paged([]));
        return _json({'code': 'NOT_FOUND'});
      }),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [RepositoryProvider.value(value: api), RepositoryProvider.value(value: CustomerApi(api))],
        child: BlocProvider.value(
          value: notices,
          child: MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => NoticeHost(onOpen: (_) {}, child: child!),
            home: const OrderDetailScreen(orderId: 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('thông báo của đúng đơn đang mở thì tải lại đơn và đánh dấu đơn đang mở', (tester) async {
    await pumpScreen(tester);
    expect(openOrderId.value, 8);
    final before = orderLoads;
    notices.push(noticeFor('DRIVER_ARRIVED', data: {'orderId': '8', 'orderCode': 'MM1'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(orderLoads, greaterThan(before));
  });

  testWidgets('thông báo của đơn khác không tải lại; rời màn thì bỏ đánh dấu', (tester) async {
    await pumpScreen(tester);
    final before = orderLoads;
    notices.push(noticeFor('DRIVER_ARRIVED', data: {'orderId': '99', 'orderCode': 'MM99'}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(orderLoads, before);

    await tester.pumpWidget(const SizedBox());
    expect(openOrderId.value, isNull);
  });
}
