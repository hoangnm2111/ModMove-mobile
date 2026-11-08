import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Iteration 2 SVG and raster assets decode successfully', (
    tester,
  ) async {
    const icons = [
      'bell',
      'map-pin',
      'route',
      'navigation',
      'target',
      'speaker',
      'phone',
      'turn-right',
      'fragile',
      'clipboard-check',
      'cash',
      'coins',
      'credit-card',
      'chart-bar',
      'trend-up',
      'calendar',
      'qr-code',
      'copy',
      'bank',
      'wallet-plus',
      'withdraw',
      'receipt',
      'refresh',
      'location-off',
      'map',
    ];
    const illustrations = [
      'waiting-customer',
      'delivery-success',
      'empty-jobs',
      'empty-revenue',
    ];
    const photos = [
      'mock-cargo-overall',
      'mock-cargo-secured',
      'mock-delivery-proof',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                Wrap(
                  children: [
                    for (final icon in icons)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: SvgPicture.asset('assets/icons/$icon.svg'),
                      ),
                  ],
                ),
                for (final illustration in illustrations)
                  SvgPicture.asset(
                    'assets/illustrations/$illustration.svg',
                    width: 280,
                    height: 180,
                  ),
                for (final photo in photos)
                  Image.asset(
                    'assets/images/$photo.png',
                    width: 320,
                    height: 240,
                    fit: BoxFit.cover,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byType(SvgPicture),
      findsNWidgets(icons.length + illustrations.length),
    );
    expect(find.byType(Image), findsNWidgets(photos.length));
  });
}
