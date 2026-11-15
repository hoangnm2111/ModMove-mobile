import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import 'package:modmove_mobile/features/auth/data/auth_api.dart';
import 'package:modmove_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:modmove_mobile/features/auth/presentation/login_screen.dart';

void main() {
  late List<http.Request> requests;

  Future<void> pump(WidgetTester tester, {bool driver = false}) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    requests = [];
    final store = MemorySessionStore(null);
    final api = ApiClient(
      sessions: store,
      baseUrl: 'http://api',
      client: MockClient((req) async {
        requests.add(req);
        return http.Response(jsonEncode({'email': 'a@b.vn'}), 200, headers: {'content-type': 'application/json'});
      }),
    );
    final auth = AuthCubit(api: AuthApi(api), sessions: store);
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: BlocProvider.value(value: auth, child: LoginScreen(startAsDriver: driver, startWithRegister: driver)),
      ),
    );
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nguyễn Văn Tài');
    await tester.enterText(fields.at(1), '0901234567');
    await tester.enterText(fields.at(2), 'Tai@Example.com');
    await tester.enterText(fields.at(3), 'ModMove@123');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('đăng ký tài xế gọi register-driver rồi mở bước OTP', (tester) async {
    await pump(tester, driver: true);
    expect(find.text('Đăng ký tài xế'), findsOneWidget);
    await fillAndSubmit(tester);
    expect(requests.single.url.path, '/public/Auth/register-driver');
    expect(jsonDecode(requests.single.body)['email'], 'tai@example.com');
    expect(find.text('Xác minh email'), findsOneWidget);
  });

  testWidgets('chọn Khách hàng thì vẫn gọi register thường', (tester) async {
    await pump(tester, driver: true);
    await tester.tap(find.descendant(of: find.byKey(const Key('register-role')), matching: find.text('Khách hàng')));
    await tester.pump();
    await fillAndSubmit(tester);
    expect(requests.single.url.path, '/public/Auth/register');
  });
}
