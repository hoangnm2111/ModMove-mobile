import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/formatting/vietnam_time.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/driver_navigation.dart';
import '../../driver_trip/presentation/bloc/active_trip_bloc.dart';
import '../domain/driver_incident_repository.dart';
import 'incident_cubits.dart';
import 'incident_widgets.dart';

class IncidentListScreen extends StatelessWidget {
  const IncidentListScreen({super.key, this.orderId});
  final String? orderId;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => IncidentListCubit(
      context.read<DriverIncidentRepository>(),
      orderId: orderId,
    )..refresh(),
    child: const _ListBody(),
  );
}

class _ListBody extends StatelessWidget {
  const _ListBody();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<IncidentListCubit, IncidentListState>(
    builder: (context, state) {
      final cubit = context.read<IncidentListCubit>();
      return IncidentRefresh(
        refresh: () async {
          // Do not collapse already loaded pages while the driver reads history.
          if (!cubit.state.busy && (cubit.state.data?.page ?? 1) == 1) {
            await cubit.refresh();
          }
        },
        child: Scaffold(
          appBar: AppHeader(
            'Sự cố của tôi',
            actions: [
              IconButton(
                tooltip: 'Tải lại sự cố',
                onPressed: state.busy ? null : cubit.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          bottomNavigationBar: const DriverNavigation(3),
          body: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (cubit.orderId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Notice(
                      'Sự cố của chuyến #${cubit.orderId}',
                      icon: 'truck',
                    ),
                  ),
                Text(
                  '${state.data?.total ?? '—'} sự cố',
                  style: appText(size: 13, color: AppColors.secondary),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final status in <String?>[
                        null,
                        'Open',
                        'InProgress',
                        'Resolved',
                        'Cancelled',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              status == null
                                  ? 'Tất cả'
                                  : incidentStatusLabel(status),
                            ),
                            selected: state.status == status,
                            showCheckmark: false,
                            onSelected: (_) => cubit.filter(status),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<ActiveTripBloc, ActiveTripState>(
                  builder: (context, tripState) {
                    final trip = tripState.session.trip;
                    if (trip?.ongoing != true ||
                        cubit.orderId != null &&
                            cubit.orderId != trip!.job.id) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AppCard(
                        color: AppColors.peach,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chuyến đang thực hiện · #${trip!.job.displayCode}',
                              style: appText(weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                              ),
                              label: const Text('Báo sự cố'),
                              onPressed: () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/incident-report',
                                  arguments: trip.job.id,
                                );
                                if (context.mounted) await cubit.refresh();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (state.busy) const LinearProgressIndicator(),
                if (state.error != null) ...[
                  Notice(state.error!, peach: true),
                  TextButton(
                    onPressed: state.busy ? null : cubit.refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (!state.busy && state.data?.items.isEmpty == true)
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.support_agent_outlined,
                            size: 56,
                            color: AppColors.orange,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            state.status == null
                                ? 'Chưa có báo cáo sự cố'
                                : 'Chưa có sự cố ở trạng thái này',
                            style: appText(weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Các báo cáo và phản hồi từ điều phối sẽ hiển thị tại đây.',
                            textAlign: TextAlign.center,
                            style: appText(
                              size: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final item in state.data?.items ?? <DriverIncident>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      onTap: () async {
                        await Navigator.pushNamed(
                          context,
                          '/incident-detail',
                          arguments: item.id,
                        );
                        if (context.mounted) await cubit.refresh();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.peach,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  incidentTypeIcon(item.type),
                                  color: AppColors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  incidentTypeLabel(item.type),
                                  style: appText(
                                    size: 15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Sự cố #${item.id} · #${item.orderCode}',
                                style: appText(
                                  size: 11,
                                  color: AppColors.secondary,
                                ),
                              ),
                              IncidentStatusBadge(item.status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: appText(size: 13),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  vietnamStamp(item.createdAt),
                                  style: appText(
                                    size: 11,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: AppColors.secondary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (state.data?.hasNext == true)
                  TextButton(
                    onPressed: state.busy ? null : cubit.more,
                    child: const Text('Xem thêm sự cố'),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
