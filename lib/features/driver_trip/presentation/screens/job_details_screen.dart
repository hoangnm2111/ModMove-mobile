import '../../../../core/widgets/notice_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../bloc/job_offer_bloc.dart';
import '../widgets/trip_components.dart';
import 'driver_simulation_sheet.dart';

class JobDetailsScreen extends StatelessWidget {
  const JobDetailsScreen({super.key, this.onAccepted});
  final VoidCallback? onAccepted;
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<JobOfferBloc, JobOfferState>(
    listenWhen: (a, b) =>
        a.status != b.status && b.status == OfferStatus.accepted,
    listener: (context, state) {
      if (onAccepted != null) {
        onAccepted!();
      } else {
        Navigator.pop(context);
        showNotice(context, 'Đã nhận chuyến thành công.');
      }
    },
    builder: (context, state) {
      final job = state.offer?.job;
      if (job == null) {
        return const Scaffold(
          appBar: AppHeader('Chi tiết đơn'),
          body: Center(child: Text('Đơn không còn khả dụng.')),
        );
      }
      final fix = context.read<DriverTripRepository>().current.fix;
      final expired = state.status == OfferStatus.expired;
      final unavailable = state.status == OfferStatus.unavailable;
      return Scaffold(
        appBar: AppHeader(
          'Chi tiết đơn',
          onHelp: tripSimulationAction(context),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: expired || unavailable
                ? PrimaryButton(
                    'Về danh sách đơn',
                    onPressed: () => Navigator.pop(context),
                  )
                : PrimaryButton(
                    'Nhận chuyến',
                    key: const Key('accept-job'),
                    busy: state.status == OfferStatus.accepting,
                    onPressed: state.canAccept
                        ? () =>
                              context.read<JobOfferBloc>().add(OfferAccepted())
                        : null,
                  ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${job.label}',
                    style: appText(size: 15, weight: FontWeight.w700),
                  ),
                ),
                TripBadge(
                  expired ? 'Hết thời gian' : 'Còn ${state.seconds} giây',
                  icon: 'clock',
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (state.error != null || expired || unavailable)
              TripError(
                state.error ??
                    (expired
                        ? 'Đã hết 30 giây nhận chuyến.'
                        : 'Đơn không còn khả dụng.'),
              ),
            RouteCard(
              job,
              distance: fix == null
                  ? null
                  : km(fix.point.distanceTo(job.pickupPoint)),
            ),
            const SizedBox(height: 12),
            TripMetrics(job, vehicle: false),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon('box', size: 25),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${job.boxes} thùng hàng · ${job.weightKg} kg',
                          style: appText(size: 16, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Thùng xe 3,1 × 1,6 × 1,6 m',
                          style: appText(size: 13, color: AppColors.secondary),
                        ),
                        if (job.fragile) ...[
                          const SizedBox(height: 10),
                          const Notice(
                            'Hàng dễ vỡ, vui lòng xếp nhẹ.',
                            icon: 'warning',
                            peach: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(job.cash ? 'cash' : 'credit-card', size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              job.cash ? 'Tiền mặt' : 'PayOS',
                              style: appText(size: 16, weight: FontWeight.w700),
                            ),
                            TripBadge(
                              job.cash ? 'Chưa thu' : 'Đã thanh toán',
                              color: job.cash
                                  ? AppColors.amber
                                  : AppColors.green,
                              background: job.cash
                                  ? AppColors.amberBg
                                  : AppColors.greenBg,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(switch (job.payment) {
                          PaymentMethod.payos =>
                            'Khách hàng đã thanh toán qua PayOS.',
                          PaymentMethod.cashSender =>
                            'Thu ${vnd(job.fare)} từ người gửi trước khi lấy hàng.',
                          PaymentMethod.cashReceiver =>
                            'Thu ${vnd(job.fare)} từ người nhận khi giao hàng.',
                        }, style: appText(size: 12, color: AppColors.secondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              color: const Color(0xFFF9F9FA),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 4),
                    child: Text(
                      'Chi tiết thu nhập',
                      style: appText(size: 15, weight: FontWeight.w700),
                    ),
                  ),
                  _fare('Cước chuyến', job.fare),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1),
                  ),
                  _fare('Phí nền tảng', job.commission),
                  ColoredBox(
                    color: AppColors.peach,
                    child: _fare('Thực nhận', job.net, total: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _fare(String label, int amount, {bool total = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: appText(
              size: 14,
              weight: total ? FontWeight.w700 : FontWeight.w400,
              color: total ? AppColors.orange : AppColors.ink,
            ),
          ),
        ),
        Text(
          vnd(amount),
          style: appText(
            size: total ? 19 : 14,
            weight: total ? FontWeight.w700 : FontWeight.w500,
            color: total ? AppColors.orange : AppColors.ink,
          ),
        ),
      ],
    ),
  );
}
