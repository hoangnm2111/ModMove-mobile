import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/app/app.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/domain/repositories/driver_trip_repository.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('test/screenshots/iteration2/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class AssetCargoPhotos implements CargoPhotoRepository {
  @override
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source) async {
    final name = kind == CargoPhotoKind.overall
        ? 'mock-cargo-overall.png'
        : 'mock-cargo-secured.png';
    return CargoPhoto(
      kind: kind,
      name: name,
      bytes: File('assets/images/$name').readAsBytesSync(),
    );
  }
}

Future<void> clickTrip(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chooseCargo(WidgetTester tester, CargoPhotoKind kind) async {
  await clickTrip(tester, find.byKey(Key('photo-${kind.name}')));
  await clickTrip(tester, find.text('Dùng ảnh mẫu mô phỏng'));
}

void main() {
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(360, 800), 1.3),
    (const Size(390, 844), 1.0),
  ]) {
    testWidgets('complete pickup at $size and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.reset);
      final repo = MockDriverTripRepository(
        delay: Duration.zero,
        autoOffer: false,
      );
      await tester.runAsync(() => repo.setOnline(true));
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ModMoveApp(
            screen: 'driver-home',
            tripRepository: repo,
            cargoPhotos: AssetCargoPhotos(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('12 Nguyễn Văn Linh, Quận 7'));
      await tester.pumpAndSettle();
      await clickTrip(tester, find.text('Xem chi tiết'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết đơn'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'job-details');
      await tester.tap(find.byKey(const Key('accept-job')));
      await tester.pumpAndSettle();
      expect(repo.current.trip!.stage, TripStage.accepted);
      expect(find.text('Đến điểm lấy hàng'), findsOneWidget);
      await capture(tester, key, 'pickup-navigation');
      await clickTrip(tester, find.byKey(const Key('arrive-pickup')));
      await tester.pumpAndSettle();
      expect(repo.current.trip!.stage, TripStage.accepted);
      await tester.runAsync(() => repo.simulate(TripSimulation.nearPickup));
      await tester.pumpAndSettle();
      await clickTrip(tester, find.byKey(const Key('arrive-pickup')));
      await tester.pumpAndSettle();
      expect(repo.current.trip!.stage, TripStage.arrived);
      expect(find.text('Kiểm tra hàng'), findsWidgets);
      for (var i = 0; i < 4; i++) {
        await clickTrip(tester, find.byKey(Key('cargo-check-$i')));
      }
      await tester.runAsync(() => repo.simulate(TripSimulation.uploadFailure));
      await chooseCargo(tester, CargoPhotoKind.overall);
      expect(find.text('Tải lại ảnh'), findsOneWidget);
      await clickTrip(tester, find.byKey(const Key('retry-overall')));
      await chooseCargo(tester, CargoPhotoKind.secured);
      expect(find.text('Ảnh bằng chứng (2/2)'), findsOneWidget);
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold).last);
        for (final asset in ['mock-cargo-overall', 'mock-cargo-secured']) {
          await precacheImage(AssetImage('assets/images/$asset.png'), context);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'cargo-inspection');
      await clickTrip(tester, find.byKey(const Key('submit-inspection')));
      expect(repo.current.trip!.stage, TripStage.pickedUp);
      expect(find.text('Đang chờ khách xác nhận'), findsOneWidget);
      await capture(tester, key, 'pickup-waiting');
      await clickTrip(tester, find.text('Bắt đầu giao hàng'));
      await tester.pumpAndSettle();
      expect(repo.current.trip!.stage, TripStage.pickedUp);
      await tester.runAsync(
        () => repo.simulate(TripSimulation.customerRejects),
      );
      await tester.pumpAndSettle();
      if (find.text('Chụp lại ảnh').evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('photo-overall')),
          150,
          scrollable: find.byType(Scrollable).last,
        );
      }
      expect(find.text('Chụp lại ảnh'), findsNWidgets(2));
      for (final kind in CargoPhotoKind.values) {
        await chooseCargo(tester, kind);
      }
      await clickTrip(tester, find.byKey(const Key('submit-inspection')));
      expect(repo.current.trip!.attempts, 2);
      await tester.runAsync(
        () => repo.simulate(TripSimulation.customerApproves),
      );
      await tester.pumpAndSettle();
      expect(repo.current.trip!.stage, TripStage.inTransit);
      expect(find.text('Đang giao hàng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.close();
    });
  }
  for (final width in [390.0, 320.0]) {
    testWidgets('driver home online/offline at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = MockDriverTripRepository(
        delay: Duration.zero,
        autoOffer: false,
      );
      await tester.runAsync(() => repo.setOnline(true));
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ModMoveApp(screen: 'driver-home', tripRepository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bạn đang trực tuyến'), findsOneWidget);
      expect(find.text('12 Nguyễn Văn Linh, Quận 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'driver-home-$width');
      await tester.tap(find.text('12 Nguyễn Văn Linh, Quận 7'));
      await tester.pumpAndSettle();
      expect(find.text('Có chuyến mới'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'job-alert-$width');
      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();
      expect(find.text('Có chuyến mới'), findsNothing);
      await tester.tap(find.byKey(const Key('driver-online')));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.close();
    });
  }
}
