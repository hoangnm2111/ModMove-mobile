import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';

/// Original illustrative map, used temporarily until an Android Maps key exists.
class MockDriverMap extends StatefulWidget {
  const MockDriverMap({
    super.key,
    required this.route,
    required this.searching,
    required this.phase,
    required this.animate,
    required this.searchRadiusMeters,
    this.position,
    this.destination,
  });
  final bool route, searching, animate;
  final double phase, searchRadiusMeters;
  final GeoPoint? position, destination;

  @override
  State<MockDriverMap> createState() => _MockDriverMapState();
}

class _MockDriverMapState extends State<MockDriverMap> {
  final _transform = TransformationController();

  void _zoom(double factor, Size viewport) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 3.0);
    final ratio = next / current;
    final center = viewport.center(Offset.zero);
    _transform.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(ratio, ratio, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1)
      ..multiply(_transform.value);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  key: const Key('mock-driver-map'),
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 3,
                  child: CustomPaint(
                    size: viewport,
                    painter: _StreetPainter(
                      route: widget.route,
                      searching: widget.searching,
                      phase: widget.phase,
                      animate: widget.animate,
                      progress:
                          widget.position == null || widget.destination == null
                          ? 0
                          : (1 -
                                    widget.position!.distanceTo(
                                          widget.destination!,
                                        ) /
                                        1200)
                                .clamp(0, 1),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 12,
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _control(
                          'Phóng to',
                          'plus',
                          () => _zoom(1.35, viewport),
                        ),
                        _control(
                          'Thu nhỏ',
                          'minus',
                          () => _zoom(1 / 1.35, viewport),
                        ),
                        _control(
                          'Về vị trí tài xế',
                          'target',
                          () => _transform.value = Matrix4.identity(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      Container(
        color: Colors.white,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          widget.searching && !widget.route
              ? 'Bản đồ mô phỏng · Tìm đơn ${(widget.searchRadiusMeters / 1000).toStringAsFixed(0)} km'
              : 'Bản đồ mô phỏng',
          style: appText(size: 11, color: AppColors.secondary),
        ),
      ),
    ],
  );

  Widget _control(String label, String icon, VoidCallback onPressed) =>
      IconButton(
        tooltip: label,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        visualDensity: VisualDensity.compact,
        icon: AppIcon(icon, size: 21),
      );
}

class _StreetPainter extends CustomPainter {
  const _StreetPainter({
    required this.route,
    required this.searching,
    required this.phase,
    required this.animate,
    required this.progress,
  });
  final bool route, searching, animate;
  final double phase;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEBEEEC),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(w * .4, h * .4);
    canvas.rotate(-.28);
    for (var x = -12; x < 15; x++) {
      for (var y = -22; y < 25; y++) {
        final rect = Rect.fromLTWH(x * 32.0, y * 22.0, 27, 17);
        canvas.drawRect(
          rect,
          Paint()
            ..color = (x + y) % 9 == 0
                ? const Color(0xFFDCE8D5)
                : const Color(0xFFF4F3EF),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0xFFD6DCD9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6,
        );
      }
    }
    canvas.restore();
    final river = Path()
      ..moveTo(w * .82, -20)
      ..cubicTo(w * .52, h * .3, w * 1.2, h * .42, w * .85, h * .65)
      ..cubicTo(w * .7, h * .8, w * .86, h * .95, w * .75, h + 30);
    canvas.drawPath(
      river,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xFFB5D9ED)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 32,
    );
    final roads = [
      Path()
        ..moveTo(-10, h * .84)
        ..cubicTo(w * .2, h * .56, w * .65, h * .75, w + 10, h * .43),
      Path()
        ..moveTo(w * .15, -10)
        ..lineTo(w * .32, h * .36)
        ..lineTo(w * .28, h * .74)
        ..lineTo(w * .48, h + 10),
      Path()
        ..moveTo(w * .58, -10)
        ..lineTo(w * .50, h * .4)
        ..lineTo(w * .65, h + 10),
    ];
    for (final road in roads) {
      canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFFCCD8DC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11,
      );
      canvas.drawPath(
        road,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFFFFE7AE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    _label(canvas, 'PHÚ MỸ HƯNG', Offset(w * .49, h * .88), 10);
    _label(canvas, 'Tân Phong', Offset(w * .08, h * .4), 11);
    _label(canvas, 'Tân Thuận', Offset(w * .68, h * .2), 11);
    _label(canvas, 'Nguyễn Văn Linh', Offset(w * .32, h * .71), 11);
    final start = Offset(w * .21, h * .82), end = Offset(w * .69, h * .36);
    var vehiclePoint = start;
    if (route) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(w * .27, h * .72)
        ..lineTo(w * .52, h * .64)
        ..lineTo(w * .5, h * .56)
        ..lineTo(w * .63, h * .49)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFF66818)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round,
      );
      _pin(canvas, end);
      final metric = path.computeMetrics().first;
      vehiclePoint = metric
          .getTangentForOffset(metric.length * progress)!
          .position;
    } else if (searching) {
      final radius = math.min(w, h) * .30;
      canvas.drawCircle(
        Offset(w * .51, h * .5),
        radius,
        Paint()..color = AppColors.orange.withValues(alpha: .12),
      );
      canvas.drawCircle(
        Offset(w * .51, h * .5),
        radius,
        Paint()
          ..color = AppColors.orange.withValues(alpha: .3)
          ..style = PaintingStyle.stroke,
      );
    }
    if (searching && !route && animate) {
      final center = Offset(w * .51, h * .5);
      final radius = math.min(w, h) * .30;
      for (var i = 0; i < 2; i++) {
        final wave = (phase + i * .5) % 1;
        canvas.drawCircle(
          center,
          radius * (.08 + .92 * wave),
          Paint()..color = AppColors.orange.withValues(alpha: .10 * (1 - wave)),
        );
        canvas.drawCircle(
          center,
          radius * (.08 + .92 * wave),
          Paint()
            ..color = AppColors.orange.withValues(alpha: .32 * (1 - wave))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    final truck = route ? vehiclePoint : Offset(w * .51, h * .5);
    canvas.save();
    canvas.translate(truck.dx, truck.dy);
    canvas.rotate(.2);
    for (final x in [-13.0, 9.0]) {
      for (final y in [-14.0, 10.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 4, 7),
            const Radius.circular(1.5),
          ),
          Paint()..color = AppColors.ink,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -21, 22, 42),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -19, 18, 38),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.orange,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-6, -15, 12, 23),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-6, 11, 12, 4),
      Paint()..color = AppColors.ink,
    );
    canvas.restore();
  }

  void _pin(Canvas canvas, Offset p) {
    canvas.drawCircle(p, 18, Paint()..color = Colors.white);
    canvas.drawCircle(p, 14, Paint()..color = AppColors.green);
    canvas.drawCircle(p, 5, Paint()..color = Colors.white);
  }

  void _label(Canvas canvas, String text, Offset at, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: appText(size: size, color: const Color(0xFF5D6872)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_StreetPainter old) =>
      old.route != route ||
      old.searching != searching ||
      old.progress != progress ||
      old.phase != phase ||
      old.animate != animate;
}
