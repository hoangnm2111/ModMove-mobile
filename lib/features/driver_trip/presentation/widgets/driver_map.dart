import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Key-free map for the mock environment; never presented as live map tiles.
class DriverMap extends StatefulWidget {
  const DriverMap({
    super.key,
    this.route = false,
    this.near = false,
    this.available = true,
  });
  final bool route, near, available;
  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  final _transform = TransformationController();
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.available) {
      return const ColoredBox(
        color: AppColors.pale,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon('location-off', size: 36, color: AppColors.muted),
                SizedBox(height: 10),
                Text('Chưa tải được bản đồ', textAlign: TextAlign.center),
                Text(
                  'Địa chỉ và liên hệ vẫn có bên dưới.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 3,
          child: LayoutBuilder(
            builder: (_, constraints) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _StreetPainter(route: widget.route, near: widget.near),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            color: Colors.white.withValues(alpha: .9),
            child: Text(
              'Bản đồ mô phỏng',
              style: appText(size: 9, color: AppColors.secondary),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 14,
          child: Material(
            color: Colors.white,
            elevation: 2,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Về vị trí hiện tại',
              onPressed: () => _transform.value = Matrix4.identity(),
              icon: const AppIcon('target'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StreetPainter extends CustomPainter {
  const _StreetPainter({required this.route, required this.near});
  final bool route, near;
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
    } else {
      canvas.drawCircle(
        Offset(w * .51, h * .5),
        48,
        Paint()..color = AppColors.orange.withValues(alpha: .12),
      );
      canvas.drawCircle(
        Offset(w * .51, h * .5),
        48,
        Paint()
          ..color = AppColors.orange.withValues(alpha: .3)
          ..style = PaintingStyle.stroke,
      );
    }
    final truck = route
        ? (near ? end + const Offset(-12, 20) : start)
        : Offset(w * .51, h * .5);
    canvas.save();
    canvas.translate(truck.dx, truck.dy);
    canvas.rotate(.2);
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
      old.route != route || old.near != near;
}
