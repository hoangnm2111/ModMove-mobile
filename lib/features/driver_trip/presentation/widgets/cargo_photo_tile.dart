import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../bloc/evidence_cubit.dart';

class CargoPhotoTile extends StatelessWidget {
  const CargoPhotoTile({super.key, required this.kind, required this.state});
  final CargoPhotoKind kind;
  final EvidenceState state;
  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<CargoPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon('camera'),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, CargoPhotoSource.camera),
            ),
            ListTile(
              leading: const AppIcon('image'),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, CargoPhotoSource.gallery),
            ),
            if (context.read<DriverTripRepository>() is TripSimulator)
              ListTile(
                leading: const AppIcon('box'),
                title: const Text('Dùng ảnh mẫu mô phỏng'),
                onTap: () => Navigator.pop(context, CargoPhotoSource.sample),
              ),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) {
      await context.read<EvidenceCubit>().pick(kind, source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = state.items[kind];
    final label = kind == CargoPhotoKind.overall
        ? 'Toàn bộ hàng'
        : 'Hàng đã cố định trên xe';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: Material(
            color: AppColors.pale,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(
                color: item?.error == null ? AppColors.line : AppColors.red,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('photo-${kind.name}'),
              onTap: state.busy ? null : () => _pick(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item == null)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppIcon(
                          'camera',
                          size: 28,
                          color: AppColors.orange,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Thêm ảnh',
                          style: appText(
                            size: 12,
                            color: AppColors.orange,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Image.memory(
                      item.photo.bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      semanticLabel: label,
                    ),
                  if (item != null && !state.busy)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          tooltip: 'Xóa ảnh $label',
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: .75,
                            ),
                          ),
                          onPressed: () =>
                              context.read<EvidenceCubit>().remove(kind),
                          icon: const AppIcon(
                            'close',
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  if (item != null &&
                      item.uploaded == null &&
                      !item.needsRetake &&
                      item.error == null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(value: item.progress),
                    ),
                  if (item?.uploaded != null)
                    const Positioned(
                      left: 6,
                      bottom: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.green,
                        child: AppIcon('check', color: Colors.white, size: 14),
                      ),
                    ),
                  if (item?.needsRetake ?? false)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        color: AppColors.red,
                        padding: const EdgeInsets.all(4),
                        width: double.infinity,
                        child: Text(
                          'Chụp lại ảnh',
                          textAlign: TextAlign.center,
                          style: appText(size: 11, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: appText(size: 11, color: AppColors.secondary)),
        if (item?.error != null) ...[
          const SizedBox(height: 3),
          Text(item!.error!, style: appText(size: 10, color: AppColors.red)),
          if (!item.needsRetake)
            TextButton(
              key: Key('retry-${kind.name}'),
              onPressed: state.busy
                  ? null
                  : () => context.read<EvidenceCubit>().retry(kind),
              child: const Text('Tải lại ảnh'),
            ),
        ],
      ],
    );
  }
}
