import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/repositories/device_cargo_photo_repository.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../bloc/active_trip_bloc.dart';

/// Mở form báo sự cố; gửi xong, bloc tải lại chuyến để banner hiện ngay.
/// [photos] cho test chèn nguồn ảnh; mặc định dùng camera/thư viện của máy.
Future<void> showTripIncident(
  BuildContext context, {
  CargoPhotoRepository? photos,
}) async {
  final bloc = context.read<ActiveTripBloc>();
  final fix = bloc.state.session.fix?.point;
  final draft = await showModalBottomSheet<IncidentDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => IncidentFormSheet(
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      photos: photos ?? DeviceCargoPhotoRepository(),
    ),
  );
  if (draft != null && context.mounted) bloc.add(IncidentReported(draft));
}

class IncidentFormSheet extends StatefulWidget {
  const IncidentFormSheet({
    super.key,
    required this.photos,
    this.latitude,
    this.longitude,
  });
  final CargoPhotoRepository photos;
  final double? latitude, longitude;
  @override
  State<IncidentFormSheet> createState() => _IncidentFormSheetState();
}

class _IncidentFormSheetState extends State<IncidentFormSheet> {
  final _text = TextEditingController();
  final _photos = <CargoPhoto>[];
  IncidentType _type = IncidentType.other;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _chooseType(IncidentType type) => setState(() => _type = type);

  Future<void> _addPhoto() async {
    if (_photos.length >= 5) return;
    final source = await showModalBottomSheet<CargoPhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
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
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final photo = await widget.photos.pick(CargoPhotoKind.overall, source);
      if (photo != null && mounted) {
        setState(() {
          _photos.add(photo);
          _error = null;
        });
      }
    } on TripFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Nhập mô tả sự cố.');
      return;
    }
    Navigator.pop(
      context,
      IncidentDraft(
        type: _type,
        description: text,
        photos: List.of(_photos),
        latitude: widget.latitude,
        longitude: widget.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Báo sự cố', style: appText(size: 20, weight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('Loại sự cố', style: appText(size: 13, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in IncidentType.values)
                  ChoiceChip(
                    key: ValueKey('incident-type-${type.apiValue}'),
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => _chooseType(type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('incident-description'),
              controller: _text,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Mô tả *',
                hintText: 'Mô tả vấn đề để điều phối viên hỗ trợ…',
              ),
            ),
            Text('Ảnh (tùy chọn, tối đa 5, JPG/PNG ≤ 5 MB)', style: appText(size: 12, color: AppColors.secondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in _photos)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(photo.bytes, width: 64, height: 64, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          tooltip: 'Bỏ ảnh',
                          onPressed: () => setState(() => _photos.remove(photo)),
                          icon: const Icon(Icons.cancel, color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
                if (_photos.length < 5)
                  InkWell(
                    key: const Key('incident-add-photo'),
                    onTap: _addPhoto,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: AppIcon('camera', color: AppColors.orange)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Notice(
              'Sau khi gửi, chuyến sẽ tạm dừng đến khi điều phối viên xử lý.',
              icon: 'warning',
              peach: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: appText(size: 12, color: AppColors.red)),
            ],
            const SizedBox(height: 12),
            PrimaryButton('Gửi sự cố', onPressed: _submit),
          ],
        ),
      ),
    ),
  );
}
