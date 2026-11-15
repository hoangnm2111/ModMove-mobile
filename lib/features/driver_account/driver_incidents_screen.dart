import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../driver_trip/data/driver_api.dart';
import '../driver_trip/domain/entities/trip_models.dart';
import 'load_view.dart';

Color _statusColor(IncidentStatus status) => switch (status) {
  IncidentStatus.open => AppColors.red,
  IncidentStatus.inProgress => AppColors.orange,
  IncidentStatus.resolved => AppColors.green,
  IncidentStatus.cancelled => AppColors.muted,
};

/// Sự cố của tôi (api/driver/incidents): sự cố tôi báo và sự cố khách báo trên đơn của tôi.
class DriverIncidentsScreen extends StatefulWidget {
  const DriverIncidentsScreen({super.key});
  @override
  State<DriverIncidentsScreen> createState() => _DriverIncidentsScreenState();
}

class _DriverIncidentsScreenState extends State<DriverIncidentsScreen> {
  IncidentStatus? _filter;
  static const _apiStatus = {
    IncidentStatus.open: 'Open',
    IncidentStatus.inProgress: 'InProgress',
    IncidentStatus.resolved: 'Resolved',
    IncidentStatus.cancelled: 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverApi>();
    return Scaffold(
      appBar: const AppHeader('Sự cố của tôi'),
      body: PagedListView<TripIncident>(
        key: ValueKey(_filter),
        emptyText: 'Chưa có sự cố nào.',
        header: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final status in IncidentStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: _filter == status,
                  onSelected: (_) => setState(() => _filter = status),
                ),
            ],
          ),
        ),
        fetch: (page) async {
          final j = await api.incidents(
            status: _filter == null ? null : _apiStatus[_filter],
            page: page,
          );
          final items = [
            for (final e in (j['items'] as List? ?? const []))
              TripIncident.fromJson((e as Map).cast<String, dynamic>()),
          ];
          return PageResult(items, j['hasNextPage'] == true);
        },
        itemBuilder: (context, incident) => AppCard(
          onTap: () => Navigator.pushNamed(
            context,
            '/driver-incident',
            arguments: incident.id,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${incident.id} · ${incident.orderCode}',
                      style: appText(size: 14, weight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    incident.status.label,
                    style: appText(
                      size: 12,
                      weight: FontWeight.w700,
                      color: _statusColor(incident.status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${incident.type.label} · ${incident.reportedByYou ? 'Bạn báo' : 'Khách báo'}${incident.blocksTrip ? ' · Chặn chuyến' : ''}',
                style: appText(size: 12.5, color: AppColors.secondary),
              ),
              const SizedBox(height: 2),
              Text(
                dateTime(incident.createdAt),
                style: appText(size: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chi tiết một sự cố: mô tả, ảnh, vị trí, trạng thái, quyết định và ghi chú của điều phối viên.
class DriverIncidentDetailScreen extends StatelessWidget {
  const DriverIncidentDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverApi>();
    return Scaffold(
      appBar: const AppHeader('Chi tiết sự cố'),
      body: LoadView<TripIncident>(
        load: () async => TripIncident.fromJson(await api.incident(id)),
        builder: (context, i, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sự cố #${i.id}',
                    style: appText(size: 20, weight: FontWeight.w800),
                  ),
                ),
                Text(
                  i.status.label,
                  style: appText(
                    size: 13,
                    weight: FontWeight.w700,
                    color: _statusColor(i.status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _row(
                    'Đơn hàng',
                    '${i.orderCode}${i.orderStatus == null ? '' : ' · ${i.orderStatus}'}',
                  ),
                  _row('Loại sự cố', i.type.label),
                  _row(
                    'Ai báo',
                    i.reportedByYou
                        ? 'Bạn báo'
                        : 'Khách báo (bạn chỉ thấy câu chung)',
                  ),
                  _row('Báo lúc', dateTime(i.createdAt)),
                  _row(
                    'Vị trí',
                    i.latitude == null || i.longitude == null
                        ? '—'
                        : '${i.latitude!.toStringAsFixed(5)}, ${i.longitude!.toStringAsFixed(5)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionTitle('Mô tả', size: 15),
            const SizedBox(height: 6),
            Text(i.description, style: appText(size: 13.5)),
            if (i.reportedByYou && i.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final url in i.photoUrls)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 84,
                              height: 84,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const SectionTitle('Xử lý của điều phối viên', size: 15),
            const SizedBox(height: 6),
            switch (i.status) {
              IncidentStatus.open => const Text(
                'Đang chờ điều phối viên nhận xử lý.',
              ),
              IncidentStatus.inProgress => const Text(
                'Điều phối viên đang xử lý sự cố này.',
              ),
              IncidentStatus.resolved => AppCard(
                child: Column(
                  children: [
                    _row('Quyết định', i.decisionLabel ?? '—'),
                    _row('Ghi chú', i.note ?? '—'),
                    _row(
                      'Xử lý lúc',
                      i.resolvedAt == null ? '—' : dateTime(i.resolvedAt!),
                    ),
                  ],
                ),
              ),
              IncidentStatus.cancelled => Text(
                'Báo cáo đã bị hủy${i.note == null ? '.' : ': ${i.note}'}',
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: appText(size: 12, color: AppColors.secondary),
          ),
        ),
        Expanded(
          child: Text(value, style: appText(size: 13, weight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
