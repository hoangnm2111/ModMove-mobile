import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modmove_mobile/app/app.dart';

/// Giống `GET /public/VehicleTypes` của BE (database/modmove-full.sql).
const _vehicleTypes = [
  {'id': 1, 'name': 'Xe van 500kg', 'maxLoadWeightKg': 500.0, 'cargoBedLengthCm': 170, 'cargoBedWidthCm': 120, 'cargoBedHeightCm': 120, 'baseFare': 50000.0, 'pricePerKm': 10000.0, 'minimumFare': 80000.0},
  {'id': 2, 'name': 'Xe tải 1 tấn', 'maxLoadWeightKg': 1000.0, 'cargoBedLengthCm': 300, 'cargoBedWidthCm': 160, 'cargoBedHeightCm': 160, 'baseFare': 80000.0, 'pricePerKm': 14000.0, 'minimumFare': 150000.0},
];

void main() {
  testWidgets('bảng giá lấy từ BE: chọn xe ở trang chủ mở đúng giá, đổi tab cập nhật giá', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((r) async {
      expect(r.url.path, endsWith('/public/VehicleTypes'));
      return http.Response(jsonEncode(_vehicleTypes), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(ModMoveApp(httpClient: client));
    await tester.pumpAndSettle();
    expect(find.text('Từ '), findsOneWidget);
    expect(find.text('50.000đ'), findsOneWidget); // loại rẻ nhất
    await tester.tap(find.text('Xe tải 1 tấn'));
    await tester.pumpAndSettle();
    expect(find.text('Xe tải 1 tấn'), findsNWidgets(2)); // tab đang chọn + tiêu đề thẻ
    expect(find.text('80.000đ'), findsOneWidget);
    expect(find.text('14.000đ'), findsOneWidget);
    expect(find.text('Thùng xe: 3 × 1,6 × 1,6 m'), findsOneWidget);
    await tester.tap(find.text('Xe van 500kg'));
    await tester.pumpAndSettle();
    expect(find.text('50.000đ'), findsOneWidget);
    expect(find.text('Tải trọng tối đa: 500 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chở hàng lớn,\nthật dễ dàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BE lỗi: trang chủ báo chưa tải được bảng giá và thử lại được', (tester) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return calls == 1 ? http.Response('', 503) : http.Response(jsonEncode(_vehicleTypes), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpWidget(ModMoveApp(httpClient: client));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được bảng giá.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Xe van 500kg'), findsWidgets);
  });
}
