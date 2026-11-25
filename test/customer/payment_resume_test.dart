import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/auth/data/auth_api.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/presentation/order_detail/order_detail_screen.dart';

import 'fixtures.dart';

const _session = Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'Khách', role: 'Customer');

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

/// Khách chuyển khoản ở app ngân hàng rồi quay lại ModMove: BE phải được nhờ hỏi PayOS, vì webhook có thể chưa tới.
void main() {
  late List<String> calls;
  late String paymentStatus;

  Widget app() {
    calls = [];
    final api = ApiClient(
      sessions: MemorySessionStore(_session),
      baseUrl: 'http://api',
      client: MockClient((req) async {
        final p = req.url.path;
        calls.add('${req.method} $p');
        if (p.endsWith('/payment/sync')) {
          paymentStatus = 'Paid'; // PayOS đã báo tiền vào: BE ghi nhận
          return http.Response('', 204);
        }
        if (p.endsWith('/customer/Orders/8')) {
          return _json(orderDetailJson(status: 'Pending', method: 'PayOS', payment: paymentStatus));
        }
        return _json(paged([]));
      }),
    );
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: api),
        RepositoryProvider(create: (_) => CustomerApi(api)),
      ],
      child: BlocProvider(
        create: (_) => AuthCubit(api: AuthApi(api), sessions: api.sessions),
        child: MaterialApp(theme: buildAppTheme(), home: const OrderDetailScreen(orderId: 8)),
      ),
    );
  }

  Future<void> resume(WidgetTester tester) async {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  setUp(() => paymentStatus = 'Unpaid');

  testWidgets('quay lại app khi đơn PayOS còn chờ thanh toán: gọi đồng bộ với BE trước rồi tải lại đơn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 500));
    calls.clear();

    await resume(tester);

    final sync = calls.indexWhere((c) => c.endsWith('/customer/Orders/8/payment/sync'));
    final reload = calls.lastIndexWhere((c) => c == 'GET /customer/Orders/8');
    expect(sync, isNonNegative, reason: calls.join('\n'));
    expect(reload, greaterThan(sync), reason: 'phải tải lại đơn SAU khi BE đã hỏi PayOS');
  });

  testWidgets('đơn đã trả hoặc tiền mặt thì quay lại app chỉ tải lại, không gọi đồng bộ', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    paymentStatus = 'Paid';
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 500));
    calls.clear();

    await resume(tester);

    expect(calls.where((c) => c.contains('/payment/sync')), isEmpty);
    expect(calls, contains('GET /customer/Orders/8'));
  });
}
