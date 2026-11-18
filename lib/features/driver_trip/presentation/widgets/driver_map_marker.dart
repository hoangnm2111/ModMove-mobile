import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/app_theme.dart';

/// A crisp top-down vehicle marker, rendered once (144 px) for the native map.
abstract final class DriverMapMarker {
  static Future<Uint8List>? _cached;
  static Future<Uint8List> load() => _cached ??= _draw();

  static Future<Uint8List> _draw() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(3);
    final paint = Paint();
    canvas.drawCircle(
      const Offset(24, 24),
      21,
      paint..color = Colors.white.withValues(alpha: .95),
    );
    for (final x in [11.0, 33.0]) {
      for (final y in [12.0, 29.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 4, 8),
            const Radius.circular(1.5),
          ),
          paint..color = AppColors.ink,
        );
      }
    }
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 6, 20, 36),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, paint..color = AppColors.orange);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 19, 14, 20),
        const Radius.circular(2),
      ),
      paint..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 9, 14, 7),
        const Radius.circular(2),
      ),
      paint..color = AppColors.ink,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(144, 144);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return bytes!.buffer.asUint8List();
  }
}
