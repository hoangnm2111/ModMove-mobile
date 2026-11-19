import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:modmove_mobile/core/maps/mapvina_map.dart';

void main() {
  testWidgets('fast zoom never stretches old tiles while waiting for detail', (
    tester,
  ) async {
    const channel = MethodChannel('vn.modmove/maps_configuration');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'zoom-test-key');
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    PaintingBinding.instance.imageCache.clear();
    final controller = MapController();
    final pending = <Completer<http.Response>>[];
    final requestedZooms = <String>[];
    var delay = false;
    http.Response tile() => http.Response.bytes(
      TileProvider.transparentImage,
      200,
      headers: {'content-type': 'image/png'},
    );
    final client = MockClient((request) async {
      requestedZooms.add(request.url.pathSegments[2]);
      if (!delay) return tile();
      final completion = Completer<http.Response>();
      pending.add(completion);
      return completion.future;
    });
    const center = LatLng(10.7769, 106.7009);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: MapVinaMap(
              center: center,
              zoom: 14,
              controller: controller,
              httpClient: client,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    Future<void> finishImages() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (var i = 0; i < 3; i++) {
      await finishImages();
    }
    Iterable<RawImage> visibleTiles() => tester
        .widgetList<RawImage>(find.byType(RawImage))
        .where((image) => image.image != null);
    expect(visibleTiles(), isNotEmpty);

    delay = true;
    controller.move(center, 15);
    controller.move(center, 16);
    controller.move(center, 17);
    await tester.pump();
    await finishImages();
    expect(requestedZooms, contains('16'));
    expect(pending, isNotEmpty);
    expect(find.text('Đang tải bản đồ…'), findsOneWidget);
    // The low-detail parent images have loaded but must not be painted at z17.
    expect(visibleTiles(), isEmpty);

    delay = false;
    for (final response in pending) {
      response.complete(tile());
    }
    for (var i = 0; i < 3; i++) {
      await finishImages();
    }
    expect(visibleTiles(), isNotEmpty);
    expect(find.text('Đang tải bản đồ…'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
