import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/features/customer/domain/customer_repository.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_cubits.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_booking_screen.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_home_screen.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_order_screen.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_refund_screen.dart';
import 'support/customer_fixtures.dart';
import 'support/remote_fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  CustomerTestApi t,
  Widget screen, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    RepositoryProvider<CustomerRepository>.value(
      value: t.repository,
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'rebook prefills addresses and Android back preserves the booking step',
    (tester) async {
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository, initial: validDraft);
      await c.initialize();
      await mount(
        tester,
        t,
        BlocProvider(
          create: (_) => c,
          child: CustomerBookingScreen(onCreated: (_) {}),
        ),
      );
      expect(find.text(validDraft.pickup), findsOneWidget);
      expect(find.text(validDraft.receiver), findsOneWidget);
      await tapVisible(tester, find.text('Tiếp tục'));
      expect(find.text('Bạn cần gửi gì?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hàng của bạn đi đâu?'), findsOneWidget);
      expect(c.state.draft.photos, validDraft.photos);
      expect(c.state.draft.receiver, validDraft.receiver);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'customer applies completed order and recipient filters then clears search',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      await mount(tester, t, const Scaffold(body: CustomerOrdersScreen()));
      await tapVisible(tester, find.text('Lọc đơn hàng'));
      await tapVisible(tester, find.text('Tất cả trạng thái'));
      await tapVisible(tester, find.text('Hoàn thành').last);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại người nhận'),
        '090',
      );
      await tapVisible(tester, find.text('Áp dụng bộ lọc'));
      expect(t.requests.last.url.queryParameters['status'], 'Completed');
      expect(t.requests.last.url.queryParameters['view'], 'History');
      expect(t.requests.last.url.queryParameters['receiverPhone'], '090');
      final search = find.byType(TextField).first;
      await tester.enterText(search, 'MM-123');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(t.requests.last.url.queryParameters['search'], 'MM-123');
      await tapVisible(tester, find.byTooltip('Xóa tìm kiếm'));
      expect(t.requests.last.url.queryParameters['search'], isEmpty);
      await tapVisible(tester, find.text('Bỏ lọc'));
      expect(t.requests.last.url.queryParameters.containsKey('status'), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'customer can move through booking wizard without losing edits and submits server quote',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final t = CustomerTestApi();
      addTearDown(t.close);
      await t.login();
      final c = BookingCubit(t.repository);
      addTearDown(c.close);
      await c.initialize();
      int? created;
      await mount(
        tester,
        t,
        BlocProvider.value(
          value: c,
          child: CustomerBookingScreen(onCreated: (id) => created = id),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa chỉ lấy hàng'),
        '12 Nguyễn Huệ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa chỉ giao hàng'),
        '24 Võ Văn Ngân',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên người nhận'),
        'Người nhận',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại người nhận'),
        '0901234567',
      );
      await tapVisible(tester, find.text('Tiếp tục'));
      // The upload itself has independent multipart tests; seed only the uploaded
      // URL returned by that boundary, then exercise the remaining real widgets.
      c.edit(
        c.state.draft.copyWith(cargoType: 'OTHER', photos: validDraft.photos),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tổng cân nặng (kg)'),
        '5',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dài (cm)'),
        '20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rộng (cm)'),
        '30',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cao (cm)'),
        '40',
      );
      await tapVisible(tester, find.text('Tiếp tục'));
      await tapVisible(tester, find.text('Xe tải 500 kg'));
      await tapVisible(tester, find.text('Tính giá cước'));
      expect(c.state.fare!.total, 90000);
      await tapVisible(tester, find.text('Tiếp tục'));
      final coupon = find.widgetWithText(TextFormField, 'Mã giảm giá');
      await tester.ensureVisible(coupon);
      await tester.enterText(coupon, 'SAVE');
      await tester.pumpAndSettle();
      expect(find.text('SAVE'), findsOneWidget);
      expect(c.state.fare, isNull);
      await tapVisible(tester, find.text('Áp dụng mã / Cập nhật giá'));
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.text('Xác nhận đặt đơn'));
      expect(created, 99);
      final submitted = t.requests.singleWhere(
        (r) => r.method == 'POST' && r.url.path.endsWith('/orders'),
      );
      expect(requestBody(submitted)['couponCode'], 'SAVE');
      expect(requestBody(submitted)['expectedTotalFee'], 90000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'pickup approval is available only while awaiting customer review and reloads status',
    (tester) async {
      var approved = false;
      final t = CustomerTestApi(
        handler: (r) async {
          if (r.url.path.endsWith('/pickup-evidence')) {
            approved = requestBody(r)['approve'] == true;
            return jsonResponse({}, 200);
          }
          if (r.url.path.endsWith('/orders/1')) {
            final raw = customerOrder(
              status: approved ? 'InTransit' : 'PickedUp',
            );
            (raw['proof'] as Map)['pickupPhotoUrls'] = validDraft.photos;
            return jsonResponse(raw);
          }
          return null;
        },
      );
      addTearDown(t.close);
      await t.login();
      final c = CustomerOrderCubit(t.repository, 1, TestCustomerRealtime());
      await mount(
        tester,
        t,
        BlocProvider(create: (_) => c, child: const CustomerOrderScreen()),
      );
      await c.initialize();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Duyệt ảnh'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.text('Duyệt ảnh'));
      await tapVisible(tester, find.text('Xác nhận'));
      expect(approved, true);
      expect(c.state.order!.summary.status, 'InTransit');
      expect(find.text('Duyệt ảnh'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'customer dashboard and refund detail fit width $width with enlarged text',
      (tester) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final t = CustomerTestApi();
        addTearDown(t.close);
        await t.login();
        await mount(tester, t, const CustomerHomeScreen(), scale: 1.3);
        expect(find.text('Đặt giao hàng'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await mount(tester, t, const CustomerRefundScreen(id: 1), scale: 1.3);
        await tester.scrollUntilVisible(
          find.text('Gửi thông tin bổ sung'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Gửi thông tin bổ sung'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
