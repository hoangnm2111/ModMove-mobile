import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/driver_account/driver_ratings_screen.dart';
import 'package:modmove_mobile/features/driver_account/driver_trips_screen.dart';
import 'package:modmove_mobile/features/driver_account/driver_wallet_screen.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_api.dart';

import 'driver_backend_test.dart' show FakeBackend;

Widget _host(Widget screen) {
  final backend = FakeBackend();
  final api = DriverApi(
    ApiClient(
      sessions: MemorySessionStore(
        const Session(accessToken: 'a', refreshToken: 'r', userId: 5, fullName: 'T', role: 'Driver'),
      ),
      client: MockClient(backend.handle),
      baseUrl: 'http://test/api',
    ),
  );
  return RepositoryProvider<DriverApi>.value(value: api, child: MaterialApp(home: screen));
}

void main() {
  testWidgets('ví tài xế hiện số dư, ngân hàng, thu nhập và lịch sử giao dịch từ BE', (tester) async {
    await tester.pumpWidget(_host(const DriverWalletScreen()));
    await tester.pumpAndSettle();
    expect(find.text('500.000đ'), findsOneWidget);
    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('Thực nhận'), findsOneWidget);
    expect(find.text('Tổng số dư'), findsOneWidget);
    expect(find.text('620.000đ'), findsWidgets);
    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    expect(find.text('Thu nhập chuyến'), findsOneWidget);
    expect(find.text('+252.000đ'), findsOneWidget);
    expect(find.text('-20.000đ'), findsOneWidget);
    expect(find.text('Tự bù ký quỹ từ thu nhập'), findsOneWidget);
    expect(find.text('30.000đ'), findsOneWidget);
    await tester.tap(find.text('Rút tiền').first);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có yêu cầu rút tiền.'), findsOneWidget);
  });

  testWidgets('danh sách chuyến lấy từ BE', (tester) async {
    await tester.pumpWidget(_host(const DriverTripsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('#MMDEMO010'), findsOneWidget);
    expect(find.text('Thực nhận 189.000đ'), findsOneWidget);
  });

  testWidgets('đánh giá hiện điểm trung bình, phân bố và nhận xét', (tester) async {
    await tester.pumpWidget(_host(const DriverRatingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('3,5'), findsOneWidget);
    expect(find.text('2 đánh giá'), findsOneWidget);
    expect(find.text('Giao nhanh, thân thiện'), findsOneWidget);
  });
}
