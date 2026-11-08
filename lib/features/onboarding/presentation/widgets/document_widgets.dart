import 'package:flutter/material.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import '../../domain/entities/driver_application.dart';
import '../models/document_display.dart';

class DocumentImage extends StatelessWidget {
  const DocumentImage(
    this.kind,
    this.document, {
    super.key,
    this.width = 64,
    this.height = 44,
  });
  final DocumentKind kind;
  final VerificationDocument document;
  final double width, height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(5),
    child: SizedBox(
      width: width,
      height: height,
      child: document.bytes != null
          ? Image.memory(document.bytes!, fit: BoxFit.cover)
          : kind == DocumentKind.vehicle
          ? VehicleImage('truck-white', height: height, width: width)
          : DocumentThumbnail(kind.preview, width: width, height: height),
    ),
  );
}

class CheckBadge extends StatelessWidget {
  const CheckBadge({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.green,
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: EdgeInsets.all(size * .18),
      child: const AppIcon('check', color: Colors.white),
    ),
  );
}

class VerificationProgress extends StatelessWidget {
  const VerificationProgress(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: Row(
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (i == 0)
                  Positioned(
                    top: 14,
                    left: 100,
                    right: 0,
                    child: Container(
                      height: 1.5,
                      color: step == 1 ? AppColors.green : AppColors.line,
                    ),
                  ),
                if (i == 1)
                  Positioned(
                    top: 14,
                    left: 0,
                    right: 100,
                    child: Container(
                      height: 1.5,
                      color: step == 1 ? AppColors.green : AppColors.line,
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < step
                            ? AppColors.green
                            : i == step
                            ? AppColors.orange
                            : AppColors.line,
                      ),
                      alignment: Alignment.center,
                      child: i < step
                          ? const AppIcon(
                              'check',
                              size: 19,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: appText(
                                weight: FontWeight.w600,
                                color: i == step
                                    ? Colors.white
                                    : AppColors.secondary,
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i == 0 ? '1. Cá nhân' : '2. Phương tiện',
                      style: appText(
                        size: 12,
                        weight: FontWeight.w500,
                        color: i < step
                            ? AppColors.green
                            : i == step
                            ? AppColors.orange
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class DashedBorder extends StatelessWidget {
  const DashedBorder({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashPainter(), child: child);
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      );
    final pen = Paint()
      ..color = const Color(0xFFCCD1DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 8) {
        canvas.drawPath(metric.extractPath(start, start + 4), pen);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) => false;
}

Future<void> showDocumentPreview(
  BuildContext context,
  DocumentKind kind,
  VerificationDocument document,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: SectionTitle(kind.label, size: 16)),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const AppIcon('close'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InteractiveViewer(
            child: DocumentImage(kind, document, width: 300, height: 210),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  ),
);
