import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/formatting/vietnam_time.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../driver_trip/domain/repositories/driver_trip_repository.dart';
import '../domain/driver_incident_repository.dart';
import 'incident_cubits.dart';
import 'incident_widgets.dart';

class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        IncidentDetailCubit(context.read<DriverIncidentRepository>(), id)
          ..refresh(),
    child: const _DetailBody(),
  );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<IncidentDetailCubit, IncidentDetailState>(
    builder: (context, state) {
      final cubit = context.read<IncidentDetailCubit>();
      final item = state.item;
      return IncidentRefresh(
        refresh: cubit.refresh,
        child: Scaffold(
          appBar: AppHeader(
            'Chi tiết sự cố',
            actions: [
              IconButton(
                tooltip: 'Kiểm tra phản hồi',
                onPressed: state.busy ? null : cubit.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (state.busy) const LinearProgressIndicator(),
                if (state.error != null) ...[
                  Notice(state.error!, peach: true),
                  TextButton(
                    onPressed: state.busy ? null : cubit.refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (item != null) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Sự cố #${item.id}',
                              style: appText(size: 20, weight: FontWeight.w800),
                            ),
                            IncidentStatusBadge(item.status),
                          ],
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            const AppIcon('truck'),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đơn hàng liên quan',
                                    style: appText(
                                      size: 11,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  Text(
                                    '#${item.orderCode}',
                                    style: appText(weight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _step('Đã gửi báo cáo', vietnamStamp(item.createdAt), true),
                  _step(
                    'Điều phối xử lý',
                    item.status == 'Open'
                        ? 'Đang chờ tiếp nhận'
                        : 'Điều phối đã tiếp nhận sự cố',
                    item.status != 'Open',
                  ),
                  _step(
                    item.status == 'Cancelled'
                        ? 'Sự cố đã đóng'
                        : 'Kết quả xử lý',
                    item.resolvedAt == null
                        ? 'Cập nhật khi có kết quả'
                        : vietnamStamp(item.resolvedAt!),
                    item.closed,
                    last: true,
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Nội dung báo cáo', size: 16),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              incidentTypeIcon(item.type),
                              color: AppColors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                incidentTypeLabel(item.type),
                                style: appText(weight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(item.description, style: appText(size: 13)),
                        if (!item.reportedByYou) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Báo cáo từ khách hàng. Chi tiết riêng tư được điều phối xử lý.',
                            style: appText(
                              size: 11,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                        if (item.photos.isNotEmpty) ...[
                          const Divider(height: 28),
                          const SectionTitle('Ảnh minh chứng', size: 14),
                          const SizedBox(height: 10),
                          IncidentPhotos(item.photos),
                        ],
                        if (item.location != null) ...[
                          const Divider(height: 28),
                          Text(
                            'Vị trí ghi nhận',
                            style: appText(size: 12, weight: FontWeight.w600),
                          ),
                          SelectableText(
                            '${item.location!.latitude.toStringAsFixed(6)}, ${item.location!.longitude.toStringAsFixed(6)}',
                            style: appText(
                              size: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Phản hồi từ điều phối', size: 16),
                        const SizedBox(height: 12),
                        Notice(
                          item.status == 'Cancelled'
                              ? 'Báo cáo đã được đóng'
                              : item.decision == null
                              ? item.status == 'Open'
                                    ? 'Chờ điều phối tiếp nhận'
                                    : 'Điều phối đang xử lý'
                              : incidentDecisionLabel(item.decision),
                          detail: item.note?.trim().isNotEmpty == true
                              ? item.note
                              : item.closed
                              ? 'Chưa có ghi chú bổ sung từ điều phối.'
                              : 'Phản hồi sẽ cập nhật khi điều phối xử lý sự cố.',
                          icon: item.closed ? 'clipboard-check' : 'clock',
                          success: item.status == 'Resolved',
                          peach: !item.closed,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    icon: const AppIcon('truck', color: AppColors.orange),
                    label: const Text('Xem chuyến đi'),
                    onPressed: () {
                      final active = context
                          .read<DriverTripRepository>()
                          .current
                          .trip;
                      Navigator.pushNamed(
                        context,
                        active?.job.id == item.orderId &&
                                active?.ongoing == true
                            ? '/active-trip'
                            : '/trip-earnings',
                        arguments: item.orderId,
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/incidents',
                      arguments: item.orderId,
                    ),
                    child: const Text('Tất cả sự cố của chuyến'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _step(
    String title,
    String description,
    bool active, {
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          active ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 22,
          color: active ? AppColors.orange : AppColors.secondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: appText(size: 13, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                description,
                style: appText(size: 11, color: AppColors.secondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
