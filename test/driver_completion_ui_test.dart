import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/domain/result_page.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import 'package:modmove_mobile/features/driver_trip/data/models/driver_trip_dto.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/trip_history_repository.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/active_trip_bloc.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/screens/delivery_screen.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/screens/trip_earnings_screen.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/screens/trip_history_screen.dart';
import 'package:modmove_mobile/features/wallet/domain/driver_wallet_repository.dart';
import 'package:modmove_mobile/features/wallet/presentation/wallet_cubit.dart';
import 'package:modmove_mobile/features/wallet/presentation/wallet_screen.dart';
import 'package:modmove_mobile/features/wallet/presentation/deposit_screen.dart';
import 'package:modmove_mobile/features/wallet/presentation/withdrawal_screen.dart';
import 'package:modmove_mobile/features/earnings/domain/driver_earnings_repository.dart';
import 'package:modmove_mobile/features/earnings/presentation/revenue_cubit.dart';
import 'package:modmove_mobile/features/earnings/presentation/revenue_screen.dart';
import 'support/remote_fixtures.dart';

final fixtureTime = DateTime.utc(2026, 11, 10, 3, 42);
ActiveTrip _trip(String stage) => DriverTripDto.parse(
  tripDetail(
    fixtureTime,
    stage: stage,
    attempts: 1,
    proofStatus: 'Verified',
    paid: stage != 'InTransit',
  ),
);

void main() {
  for (final size in [const Size(390, 844), const Size(320, 640)]) {
    for (final screen in [
      'delivery',
      'success',
      'trip-earnings',
      'trip-history',
      'wallet',
      'deposit',
      'withdraw',
      'revenue',
    ]) {
      testWidgets('$screen fits $size and supports scrolling', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final wallet = WalletCubit(UiWallet());
        await wallet.refresh();
        if (screen == 'deposit') await wallet.topUp(200000);
        final revenue = RevenueCubit(UiEarnings(), now: fixtureTime);
        final trips = UiTrips();
        final boundary = GlobalKey();
        final page = switch (screen) {
          'delivery' => DeliveryScreen(
            tripState: ActiveTripState(trips.current, fixtureTime),
          ),
          'success' => DeliverySuccessScreen(_trip('Delivered')),
          'trip-earnings' => const TripEarningsScreen(id: '42'),
          'trip-history' => const TripHistoryScreen(),
          'wallet' => const WalletScreen(),
          'deposit' => const DepositScreen(),
          'withdraw' => const WithdrawalScreen(),
          _ => const RevenueScreen(),
        };
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MultiRepositoryProvider(
              providers: [
                RepositoryProvider<DriverTripRepository>.value(value: trips),
                RepositoryProvider<DriverDeliveryRepository>.value(
                  value: trips,
                ),
                RepositoryProvider<TripHistoryRepository>.value(
                  value: UiHistory(),
                ),
                RepositoryProvider<CargoPhotoRepository>.value(
                  value: UiPhotos(),
                ),
              ],
              child: MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: wallet),
                  BlocProvider.value(value: revenue),
                ],
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        size.width == 320 ? 1.3 : 1,
                      ),
                    ),
                    child: child!,
                  ),
                  home: page,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width == 390) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('test/screenshots/driver-$screen.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Scroll every new screen so off-screen form rows are also laid out.
        final scroll = find.byType(Scrollable).first;
        await tester.drag(scroll, const Offset(0, -800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await wallet.close();
        await revenue.close();
      });
    }
  }

  testWidgets('POD submit stays disabled until upload and cash confirmation', (
    tester,
  ) async {
    final trips = UiTrips();
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<DriverTripRepository>.value(value: trips),
          RepositoryProvider<DriverDeliveryRepository>.value(value: trips),
          RepositoryProvider<CargoPhotoRepository>.value(value: UiPhotos()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: DeliveryScreen(
            tripState: ActiveTripState(trips.current, fixtureTime),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    PrimaryButton submit() =>
        tester.widget<PrimaryButton>(find.byKey(const Key('confirm-delivery')));
    expect(submit().onPressed, isNull);
    await tester.scrollUntilVisible(
      find.text('Chụp ảnh'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(trips.uploads, 1);
    expect(submit().onPressed, isNull);
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNotNull);
    await tester.tap(find.text('Xác nhận đã giao hàng'));
    await tester.pumpAndSettle();
    expect(trips.deliveries, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class UiWallet implements DriverWalletRepository {
  @override
  Future<WalletBalance> balance() async => const WalletBalance(
    318000,
    1280000,
    withdrawable: 1280000,
    canReceiveCash: true,
    bank: DriverBankAccount('Vietcombank', '1234566789', 'NGUYEN MINH ANH'),
  );
  @override
  Future<DepositPayment> topUp(int amount) async => DepositPayment(
    Uri.parse('https://pay.payos.vn/test'),
    DateTime.now().add(const Duration(minutes: 10)),
    amount,
    id: '7',
    qrCode: '000201010212-test-only',
  );
  @override
  Future<ResultPage<WalletTransaction>> transactions({int page = 1}) async =>
      ResultPage(
        [
          WalletTransaction(
            id: '1',
            type: 'TripEarning',
            amount: 288000,
            balanceAfter: 1280000,
            status: 'Completed',
            createdAt: fixtureTime,
            orderId: '42',
            orderCode: 'MM0042',
          ),
          WalletTransaction(
            id: '2',
            type: 'CommissionDeduction',
            amount: 32000,
            balanceAfter: 318000,
            status: 'Completed',
            createdAt: fixtureTime,
          ),
          WalletTransaction(
            id: '3',
            type: 'TopUpDeposit',
            amount: 200000,
            balanceAfter: 350000,
            status: 'Completed',
            createdAt: fixtureTime,
          ),
        ],
        1,
        3,
        false,
      );
  @override
  Future<ResultPage<WalletTransaction>> withdrawals({int page = 1}) async =>
      const ResultPage([], 1, 0, false);
  @override
  Future<void> saveBank(DriverBankAccount bank) async {}
  @override
  Future<WithdrawalReceipt> withdraw(int amount) async =>
      WithdrawalReceipt('2', amount, 0);
}

class UiEarnings implements DriverEarningsRepository {
  @override
  Future<EarningsReport> report(RevenueRange range) async => EarningsReport(
    completed: 3,
    gross: 540000,
    commission: 54000,
    net: 486000,
    previousNet: 434000,
    orders: [
      OrderEarning('42', 'MM0042', 288000, fixtureTime),
      OrderEarning(
        '41',
        'MM0041',
        198000,
        fixtureTime.subtract(const Duration(hours: 2)),
      ),
    ],
  );
}

class UiHistory implements TripHistoryRepository {
  @override
  Future<ActiveTrip> detail(String id) async => _trip('Completed');
  @override
  Future<ResultPage<TripSummary>> history({
    int page = 1,
    String view = 'All',
  }) async => ResultPage(
    [
      TripSummary(
        id: '42',
        code: 'MM0042',
        status: 'Completed',
        pickup: '12 Nguyễn Văn Linh, Quận 7',
        dropoff: '85 Điện Biên Phủ, Bình Thạnh',
        fare: 240000,
        earning: 204000,
        createdAt: fixtureTime,
      ),
    ],
    1,
    1,
    false,
  );
}

class UiPhotos implements CargoPhotoRepository {
  @override
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source) async {
    final data = await rootBundle.load('assets/images/mock-delivery-proof.png');
    return CargoPhoto(
      kind: kind,
      name: 'photo.png',
      bytes: data.buffer.asUint8List(),
    );
  }
}

class UiTrips implements DriverTripRepository, DriverDeliveryRepository {
  int uploads = 0, deliveries = 0;
  @override
  DriverSession get current => DriverSession(trip: _trip('InTransit'));
  @override
  Future<UploadedEvidence> upload(
    CargoPhoto photo,
    void Function(double) progress,
  ) async {
    uploads++;
    return UploadedEvidence(photo.kind, 'https://images.test/pod.png');
  }

  @override
  Future<void> arriveDropoff() async {}
  @override
  Future<void> deliver({
    required String photoUrl,
    required bool cashCollected,
  }) async {
    deliveries++;
    expect(cashCollected, true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
