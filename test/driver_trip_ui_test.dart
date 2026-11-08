import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/app/app.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/mock_driver_trip_repository.dart';

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

void main() {
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
      await tester.tap(find.byKey(const Key('driver-online')));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.close();
    });
  }
}
