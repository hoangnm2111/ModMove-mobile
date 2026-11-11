import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/auth/data/auth_api.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:modmove_mobile/features/auth/presentation/logout_button.dart';

const _session = Session(accessToken: 'a', refreshToken: 'r', userId: 5, fullName: 'Tài xế', role: 'Driver');

void main() {
  Future<(AuthCubit, List<String>)> pump(WidgetTester tester, {bool offline = false}) async {
    final calls = <String>[];
    final store = MemorySessionStore(_session);
    final api = ApiClient(
      sessions: store,
      baseUrl: 'http://api',
      client: MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (offline) throw http.ClientException('offline');
        return http.Response(jsonEncode({}), 204);
      }),
    );
    final auth = AuthCubit(api: AuthApi(api), sessions: store);
    addTearDown(auth.close);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BlocProvider.value(value: auth, child: const LogoutButton()))));
    return (auth, calls);
  }

  testWidgets('hỏi lại rồi gọi POST /account/Logout và xoá phiên', (tester) async {
    final (auth, calls) = await pump(tester);
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-confirm')));
    await tester.pumpAndSettle();
    expect(calls, ['POST /account/Logout']);
    expect(auth.state, isNull);
  });

  testWidgets('bấm "Ở lại" thì không đăng xuất', (tester) async {
    final (auth, calls) = await pump(tester);
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-cancel')));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(auth.state, isNotNull);
  });

  testWidgets('mất mạng vẫn đăng xuất được trên máy này', (tester) async {
    final (auth, _) = await pump(tester, offline: true);
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-confirm')));
    await tester.pumpAndSettle();
    expect(auth.state, isNull);
  });

  testWidgets('không có AuthCubit thì nút ẩn', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LogoutButton())));
    expect(find.byKey(const Key('logout-button')), findsNothing);
  });
}
