import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/customer/domain/customer_models.dart';
import 'package:modmove_mobile/features/customer/domain/customer_places.dart';
import 'package:modmove_mobile/features/customer/presentation/customer_map.dart';

class TestPlaces implements CustomerPlaces {
  Future<List<CustomerPlace>> Function(String)? onSearch;
  @override
  Future<List<CustomerPlace>> search(String query) async => onSearch == null
      ? throw const CustomerFailure('Thiết bị không tìm được địa chỉ.')
      : await onSearch!(query);
  @override
  Future<GeoPosition> locate() async => const GeoPosition(10, 106);
  @override
  Future<CustomerPlace> reverse(GeoPosition position) async =>
      CustomerPlace('Địa chỉ GPS', position);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vn.modmove/maps_configuration');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => '');
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openPicker(
    WidgetTester tester,
    TestPlaces places,
    void Function(BookingAddress?) receive,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                receive(
                  await Navigator.push<BookingAddress>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => PlaceCubit(places),
                        child: const CustomerPlaceScreen(),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'manual address remains usable without Maps and when device search fails',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      BookingAddress? result;
      await openPicker(tester, TestPlaces(), (value) => result = value);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byType(TextField),
        '  12 Nguyễn Huệ, Quận 1, TP Hồ Chí Minh  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Thiết bị không tìm được địa chỉ.'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final button = find.text('Dùng địa chỉ đã nhập');
      await tester.scrollUntilVisible(
        button,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(result!.address, '12 Nguyễn Huệ, Quận 1, TP Hồ Chí Minh');
      expect(result!.position, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chosen search result retains its exact coordinates without map tiles',
    (tester) async {
      final places = TestPlaces()
        ..onSearch = (_) async => [
          const CustomerPlace(
            '12 Nguyễn Huệ, Quận 1',
            GeoPosition(10.775, 106.704),
          ),
        ];
      BookingAddress? result;
      await openPicker(tester, places, (value) => result = value);
      await tester.enterText(find.byType(TextField), 'Nguyễn Huệ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('12 Nguyễn Huệ, Quận 1'));
      await tester.pumpAndSettle();
      final button = find.text('Chọn địa chỉ này');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(result!.position!.latitude, 10.775);
      expect(result!.position!.longitude, 106.704);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'editing an address discards delayed device search results and old selection',
    () async {
      final response = Completer<List<CustomerPlace>>();
      final places = TestPlaces()..onSearch = (_) => response.future;
      final cubit = PlaceCubit(places);
      addTearDown(cubit.close);
      final pending = cubit.search('Địa chỉ cũ');
      cubit.clearSelection();
      response.complete([
        const CustomerPlace('Địa chỉ cũ', GeoPosition(10, 106)),
      ]);
      await pending;
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.selected, isNull);
      expect(cubit.state.busy, isFalse);
    },
  );

  test(
    'manual selection can clear old coordinates even for the same address text',
    () {
      final draft = BookingDraft(
        pickup: 'Địa chỉ A',
        dropoff: 'Địa chỉ B',
        pickupPoint: const GeoPosition(10, 106),
        dropoffPoint: const GeoPosition(11, 107),
      );
      final manual = draft.copyWith(
        pickup: draft.pickup,
        clearPickupPoint: true,
      );
      expect(manual.pickupPoint, isNull);
      expect(manual.dropoffPoint, same(draft.dropoffPoint));
      expect(
        manual
            .copyWith(dropoff: draft.dropoff, clearDropoffPoint: true)
            .dropoffPoint,
        isNull,
      );
    },
  );
}
