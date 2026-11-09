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
import 'package:modmove_mobile/features/customer/presentation/customer_shell.dart';

import 'fixtures.dart';

const _session = Session(accessToken: 'a', refreshToken: 'r', userId: 3, fullName: 'Khách hàng Demo', role: 'Customer');

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

/// Backend giả: đơn 8 đã giao 1 giờ trước (còn hạn khiếu nại), chưa có khiếu nại.
class _FakeBackend {
  final calls = <String>[];
  late final deliveredAt = DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();

  Future<http.Response> handle(http.Request req) async {
    calls.add('${req.method} ${req.url.path}');
    final p = req.url.path;
    if (p.endsWith('/customer/Orders') && req.method == 'GET') return _json(paged([orderSummaryJson()]));
    if (p.endsWith('/customer/Orders/8')) return _json(orderDetailJson(deliveredAt: deliveredAt));
    if (p.endsWith('/customer/Orders/8/confirm-receipt')) return http.Response('', 204);
    if (p.endsWith('/customer/Incidents') || p.endsWith('/customer/Refunds') || p.endsWith('/customer/Ratings')) return _json(paged([]));
    if (p.endsWith('/account/Profile')) {
      return _json({'id': 3, 'fullName': 'Khách hàng Demo', 'phoneNumber': '0900000003', 'email': 'customer@modmove.local', 'role': 'Customer', 'emailVerified': true});
    }
    return _json({'code': 'NOT_FOUND'}, 404);
  }
}

Widget _app(_FakeBackend backend) {
  final api = ApiClient(sessions: MemorySessionStore(_session), baseUrl: 'http://api', client: MockClient(backend.handle));
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: api),
      RepositoryProvider(create: (_) => CustomerApi(api)),
    ],
    child: BlocProvider(
      create: (_) => AuthCubit(api: AuthApi(api), sessions: api.sessions),
      child: MaterialApp(theme: buildAppTheme(), home: const CustomerShell()),
    ),
  );
}

void main() {
  testWidgets('khách thấy đơn, mở chi tiết có tài xế, đơn đã giao cho xác nhận hoặc khiếu nại', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = _FakeBackend();

    await tester.pumpWidget(_app(backend));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, Khách hàng Demo'), findsOneWidget);
    expect(find.text('MMDEMO008'), findsOneWidget);

    await tester.tap(find.text('MMDEMO008'));
    await tester.pumpAndSettle();

    // Thông tin tài xế (trước đây web thiếu) + 2 lựa chọn khi đã giao (GB-18)
    expect(find.text('Tài xế Demo'), findsOneWidget);
    expect(find.text('Xác nhận đã nhận hàng'), findsOneWidget);
    expect(find.text('Khiếu nại'), findsOneWidget);

    await tester.tap(find.text('Xác nhận đã nhận hàng'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Đồng ý'));
    await tester.pumpAndSettle();

    expect(backend.calls, contains('POST /customer/Orders/8/confirm-receipt'));
    expect(tester.takeException(), isNull);
  });
}
