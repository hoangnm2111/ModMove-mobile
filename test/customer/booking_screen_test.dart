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
import 'package:modmove_mobile/features/customer/data/booking_draft_store.dart';
import 'package:modmove_mobile/features/customer/data/customer_api.dart';
import 'package:modmove_mobile/features/customer/presentation/booking/booking_cubit.dart';
import 'package:modmove_mobile/features/customer/presentation/booking/booking_screen.dart';

import 'fixtures.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

const _saved = BookingDraft(
  pickupAddress: '12 Nguyễn Huệ, Hoàn Kiếm',
  senderName: 'Chị Hoa',
  senderPhone: '0987654321',
  pickupNote: 'Cửa hầm B1',
  dropoffAddress: '45 Cầu Giấy, Hà Nội',
  receiverName: 'Anh Nam',
  receiverPhone: '0912345678',
);

Widget _app({
  required BookingDraftStore store,
  Session? session,
  Future<Session?> Function()? onSignIn,
  BookingDraft? initial,
}) {
  final api = ApiClient(
    sessions: MemorySessionStore(session),
    baseUrl: 'http://api',
    client: MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('/public/VehicleTypes')) return _json([]);
      if (p.endsWith('/public/Lookups/cargo-types')) {
        return _json([
          {'code': 'GOODS', 'name': 'Hàng hoá', 'description': null},
        ]);
      }
      if (p.endsWith('/customer/Coupons')) return _json(paged([]));
      return _json({'code': 'NOT_FOUND'}, 404);
    }),
  );
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: api),
      RepositoryProvider(create: (_) => CustomerApi(api)),
      RepositoryProvider<BookingDraftStore>.value(value: store),
    ],
    child: BlocProvider(
      create: (_) => AuthCubit(api: AuthApi(api), sessions: api.sessions),
      child: MaterialApp(
        theme: buildAppTheme(),
        home: BookingScreen(initial: initial, onSignIn: onSignIn),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

TextFormField _field(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(find.widgetWithText(TextFormField, label));

void main() {
  testWidgets('màn lộ trình có người gửi, ghi chú điểm lấy và ghi chú điểm giao như web', (tester) async {
    await _open(tester, _app(store: MemoryBookingDraftStore()));

    expect(find.text('Tên người gửi'), findsOneWidget);
    expect(find.text('Số điện thoại người gửi'), findsOneWidget);
    expect(find.text('Tên người nhận'), findsOneWidget);
    expect(find.text('Số điện thoại người nhận'), findsOneWidget);
    expect(find.text('Ghi chú'), findsNWidgets(2)); // điểm lấy và điểm giao
    expect(find.text('Bạn có đơn nháp chưa gửi.'), findsNothing);
  });

  testWidgets('có nháp cũ: hiện banner và điền lại các ô; Tiếp tục giữ nguyên nội dung', (tester) async {
    final store = MemoryBookingDraftStore();
    await store.save(_saved.toJson(), 0);

    await _open(tester, _app(store: store));

    expect(find.text('Bạn có đơn nháp chưa gửi.'), findsOneWidget);
    expect(find.text('Mã giảm giá và các ô đồng ý chính sách cần chọn lại.'), findsOneWidget);
    expect(_field(tester, 'Tên người gửi').initialValue, 'Chị Hoa');
    expect(_field(tester, 'Số điện thoại người nhận').initialValue, '0912345678');

    await tester.tap(find.text('Tiếp tục').first);
    await tester.pumpAndSettle();
    expect(find.text('Bạn có đơn nháp chưa gửi.'), findsNothing);
    expect(_field(tester, 'Tên người gửi').initialValue, 'Chị Hoa');
  });

  testWidgets('có nháp cũ: Bắt đầu lại xoá các ô và xoá nháp trong máy', (tester) async {
    final store = MemoryBookingDraftStore();
    await store.save(_saved.toJson(), 0);

    await _open(tester, _app(store: store));
    await tester.tap(find.text('Bắt đầu lại'));
    await tester.pumpAndSettle();

    expect(find.text('Bạn có đơn nháp chưa gửi.'), findsNothing);
    expect(_field(tester, 'Tên người gửi').initialValue, '');
    expect(_field(tester, 'Số điện thoại người nhận').initialValue, '');
    expect(await store.load(), isNull);
  });

  testWidgets('đặt lại đơn cũ (có nháp sẵn) thì không mở nháp đã lưu', (tester) async {
    final store = MemoryBookingDraftStore();
    await store.save(_saved.toJson(), 0);

    await _open(
      tester,
      _app(
        store: store,
        initial: const BookingDraft(senderName: 'Người khác'),
      ),
    );

    expect(find.text('Bạn có đơn nháp chưa gửi.'), findsNothing);
    expect(_field(tester, 'Tên người gửi').initialValue, 'Người khác');
  });

  testWidgets('bấm Tiếp tục khi thiếu người gửi hoặc số điện thoại sai thì báo đúng chỗ và ở lại bước 1', (
    tester,
  ) async {
    await _open(
      tester,
      _app(
        store: MemoryBookingDraftStore(),
        initial: _saved.copyWith(senderName: ''),
      ),
    );

    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    expect(find.text('Nhập tên người gửi.'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 6));
    await tester.enterText(find.widgetWithText(TextFormField, 'Tên người gửi'), 'Chị Hoa');
    await tester.enterText(find.widgetWithText(TextFormField, 'Số điện thoại người gửi'), '0212345678');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump(const Duration(milliseconds: 600)); // thông báo cũ đóng
    await tester.pump(const Duration(milliseconds: 600)); // thông báo mới hiện
    expect(find.text('Nhập số điện thoại người gửi hợp lệ.'), findsOneWidget);
    expect(find.text('Loại hàng'), findsNothing); // chưa sang bước hàng hoá
  });

  testWidgets('ô số điện thoại nhận số gõ kiểu +84 có khoảng trắng, không bị cắt cụt', (tester) async {
    await _open(tester, _app(store: MemoryBookingDraftStore()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Số điện thoại người nhận'), '+84 912 345 678');
    await tester.pump();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Số điện thoại người nhận'),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '+84 912 345 678');
  });

  testWidgets('điểm giao trùng điểm lấy bị chặn ở bước 1', (tester) async {
    await _open(
      tester,
      _app(
        store: MemoryBookingDraftStore(),
        initial: _saved.copyWith(dropoffAddress: ' 12 NGUYỄN HUỆ, HOÀN KIẾM'),
      ),
    );

    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();

    expect(find.text('Điểm giao hàng phải khác điểm lấy hàng.'), findsOneWidget);
  });

  testWidgets('lộ trình hợp lệ thì sang bước hàng hoá', (tester) async {
    await _open(tester, _app(store: MemoryBookingDraftStore(), initial: _saved));

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Loại hàng'), findsOneWidget);
    expect(find.text('Mô tả hàng hoá'), findsOneWidget);
  });
}
