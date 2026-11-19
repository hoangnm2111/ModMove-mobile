import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../driver_trip/domain/entities/trip_models.dart';
import '../../driver_trip/domain/repositories/driver_trip_repository.dart';
import '../domain/driver_incident_repository.dart';
import 'incident_cubits.dart';
import 'incident_widgets.dart';

class IncidentReportScreen extends StatelessWidget {
  const IncidentReportScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => IncidentReportCubit(
      context.read<DriverIncidentRepository>(),
      context.read<DriverTripRepository>(),
      context.read<CargoPhotoRepository>(),
      orderId,
    ),
    child: const _ReportBody(),
  );
}

class _ReportBody extends StatefulWidget {
  const _ReportBody();
  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  final _description = TextEditingController();
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<IncidentReportCubit, IncidentReportState>(
    listenWhen: (old, next) =>
        old.createdId != next.createdId && next.createdId != null,
    listener: (context, state) => Navigator.pushReplacementNamed(
      context,
      '/incident-detail',
      arguments: state.createdId,
    ),
    builder: (context, state) {
      final cubit = context.read<IncidentReportCubit>();
      final trip = cubit.trips.current.trip;
      return PopScope(
        canPop: !state.busy,
        child: Scaffold(
          appBar: const AppHeader('Báo sự cố'),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: PrimaryButton(
                'Gửi báo cáo',
                key: const Key('submit-incident'),
                busy: state.busy,
                onPressed: state.ready ? cubit.submit : null,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(
                  children: [
                    const AppIcon('truck'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${trip?.job.id == cubit.orderId ? trip!.job.displayCode : cubit.orderId}',
                            style: appText(weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Báo cáo gắn với chuyến đi này',
                            style: appText(
                              size: 11,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!state.canReport) ...[
                const SizedBox(height: 12),
                const Notice(
                  'Chuyến không còn cho phép báo sự cố',
                  detail:
                      'Chỉ báo sự cố cho chuyến đang được giao cho bạn, trước khi hoàn tất giao hàng.',
                  peach: true,
                ),
              ],
              const SizedBox(height: 22),
              const SectionTitle('Loại sự cố', size: 16),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final type in IncidentType.values)
                      SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: Semantics(
                          selected: state.type == type,
                          button: true,
                          child: AppCard(
                            onTap: state.locked
                                ? null
                                : () => cubit.selectType(type),
                            color: state.type == type
                                ? AppColors.peach
                                : Colors.white,
                            borderColor: state.type == type
                                ? AppColors.orange
                                : AppColors.line,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      incidentTypeIcon(type.api),
                                      color: state.type == type
                                          ? AppColors.orange
                                          : AppColors.ink,
                                      size: 26,
                                    ),
                                    const Spacer(),
                                    Icon(
                                      state.type == type
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: state.type == type
                                          ? AppColors.orange
                                          : AppColors.secondary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  incidentTypeLabel(type.api),
                                  style: appText(
                                    size: 13,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('Mô tả sự cố', size: 16),
              const SizedBox(height: 10),
              TextField(
                key: const Key('incident-description'),
                controller: _description,
                enabled: !state.locked,
                maxLines: 5,
                minLines: 4,
                maxLength: 1000,
                onChanged: cubit.describe,
                decoration: const InputDecoration(
                  hintText: 'Mô tả tình huống và hỗ trợ bạn cần từ điều phối…',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ảnh minh chứng · Không bắt buộc',
                style: appText(size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < state.photos.length; i++)
                    SizedBox(
                      width: 100,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  state.photos[i].photo.bytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Icon(Icons.image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton.filledTonal(
                                  tooltip: 'Xóa ảnh ${i + 1}',
                                  onPressed: state.locked
                                      ? null
                                      : () => cubit.remove(i),
                                  icon: const Icon(Icons.close, size: 17),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (state.photos[i].error != null) ...[
                            Text(
                              state.photos[i].error!,
                              style: appText(size: 10, color: AppColors.red),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            TextButton(
                              onPressed: state.locked
                                  ? null
                                  : () => cubit.retry(i),
                              child: const Text('Tải lại'),
                            ),
                          ] else
                            Text(
                              state.photos[i].url == null
                                  ? 'Đang tải ảnh…'
                                  : 'Đã tải lên',
                              style: appText(
                                size: 10,
                                color: state.photos[i].url == null
                                    ? AppColors.secondary
                                    : AppColors.green,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (state.photos.length < 5)
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: AppCard(
                        onTap: state.locked
                            ? null
                            : () => _pick(context, cubit),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.orange,
                            ),
                            SizedBox(height: 8),
                            Text('Thêm ảnh', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tối đa 5 ảnh · JPG/PNG · 5 MB mỗi ảnh',
                style: appText(size: 11, color: AppColors.secondary),
              ),
              const SizedBox(height: 18),
              const Notice(
                'Điều phối viên sẽ tiếp nhận và hỗ trợ chuyến đi.',
                icon: 'info',
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Notice(state.error!, peach: true),
              ],
              if (state.uncertain) ...[
                TextButton(
                  onPressed: state.busy ? null : cubit.reconcile,
                  child: const Text('Kiểm tra kết quả gửi'),
                ),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => Navigator.pushNamed(
                          context,
                          '/incidents',
                          arguments: cubit.orderId,
                        ),
                  child: const Text('Xem sự cố của chuyến'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
  Future<void> _pick(BuildContext context, IncidentReportCubit cubit) async {
    final source = await showModalBottomSheet<CargoPhotoSource>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, CargoPhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, CargoPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) await cubit.add(source);
  }
}
