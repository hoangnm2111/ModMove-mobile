import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/customer_models.dart';
import '../domain/customer_repository.dart';
import 'customer_cubits.dart';
import 'customer_widgets.dart';

class CustomerIncidentScreen extends StatelessWidget {
  const CustomerIncidentScreen(this.incident, {super.key});
  final Incident incident;
  Future<Incident> _reload(CustomerRepository repository) async {
    var page = 1;
    while (true) {
      final result = await repository.incidents(
        page: page++,
        orderId: incident.orderId,
      );
      for (final item in result.items) {
        if (item.id == incident.id) return item;
      }
      if (!result.hasNext) {
        throw const CustomerFailure(
          'Không tìm thấy sự cố. Hãy tải lại danh sách.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ResourceCubit<Incident>(
      () => _reload(context.read<CustomerRepository>()),
    )..load(),
    child: Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sự cố')),
      body: BlocBuilder<ResourceCubit<Incident>, ResourceState<Incident>>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: context.read<ResourceCubit<Incident>>().load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (state.busy) const LinearProgressIndicator(),
              if (state.error != null) ...[
                CustomerNotice(state.error!, error: true),
                OutlinedButton(
                  onPressed: context.read<ResourceCubit<Incident>>().load,
                  child: const Text('Thử lại'),
                ),
              ],
              if (state.data case final i?) ...[
                CustomerBrand(compact: true, trailing: StatusPill(i.status)),
                CustomerPageHeading(
                  statusLabel(i.type),
                  subtitle: '${i.orderCode} · ${dateLabel(i.created)}',
                ),
                CustomerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mô tả sự cố',
                        style: appText(size: 17, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(i.description),
                      if (i.photos.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        PhotoStrip(i.photos, large: true),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CustomerTimelineStep(
                  title: 'Đã tiếp nhận',
                  subtitle: dateLabel(i.created),
                  done: true,
                ),
                CustomerTimelineStep(
                  title: 'Điều phối xử lý',
                  subtitle: i.note.isNotEmpty ? i.note : statusLabel(i.status),
                  done: i.status == 'Resolved',
                  current: i.status == 'InProgress',
                ),
                CustomerTimelineStep(
                  title: 'Kết quả xử lý',
                  subtitle: i.decision.isEmpty
                      ? 'Chờ kết quả kiểm tra và phương án xử lý.'
                      : switch (i.decision) {
                          'ContinueTrip' => 'Tiếp tục chuyến',
                          'ReassignDriver' => 'Đổi tài xế',
                          'CancelOrder' => 'Hủy đơn',
                          _ => i.decision,
                        },
                  done: i.status == 'Resolved',
                  last: true,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/incident-refund',
                    arguments: i,
                  ),
                  icon: const AppIcon('credit-card', color: AppColors.orange),
                  label: const Text('Yêu cầu hoàn tiền'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/order',
                    arguments: i.orderId,
                  ),
                  child: const Text('Xem đơn hàng'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
