import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../bloc/active_trip_bloc.dart';
import '../widgets/trip_components.dart';
import '../widgets/trip_contact_actions.dart';
import 'driver_simulation_sheet.dart';

class PickupApprovalScreen extends StatelessWidget {
  const PickupApprovalScreen({super.key, required this.state});
  final ActiveTripState state;
  @override
  Widget build(BuildContext context) {
    final trip = state.session.trip!;
    final rejected = trip.review == EvidenceReview.rejected;
    final submitted = trip.submittedAt;
    final time = submitted == null
        ? '--:--'
        : '${submitted.hour.toString().padLeft(2, '0')}:${submitted.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppHeader(
        'Xác nhận hàng',
        onHelp: () => showTripSimulation(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const PickupStepper(2),
          const SizedBox(height: 8),
          AppCard(
            color: AppColors.peach,
            borderColor: const Color(0xFFFFE5D5),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SvgPicture.asset(
                  'assets/illustrations/waiting-customer.svg',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
                Text(
                  rejected ? 'Cần điều phối hỗ trợ' : 'Đang chờ khách xác nhận',
                  textAlign: TextAlign.center,
                  style: appText(
                    size: 22,
                    weight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ảnh đã gửi lúc $time · Lần ${trip.attempts}/5',
                  style: appText(size: 12, color: AppColors.secondary),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      _step(
                        'Đã tải ${trip.evidence.length} ảnh',
                        'Ảnh bằng chứng đã được gửi cho khách',
                        AppColors.green,
                        'check',
                        time,
                      ),
                      const Divider(height: 1, indent: 36),
                      _step(
                        rejected ? 'Khách yêu cầu chụp lại' : 'Khách đang xem',
                        rejected
                            ? trip.reason!
                            : 'Vui lòng chờ khách xác nhận hàng',
                        AppColors.orange,
                        'clock',
                        '•••',
                      ),
                      const Divider(height: 1, indent: 36),
                      _step(
                        'Bắt đầu chuyến',
                        'Sau khi khách xác nhận, chuyến sẽ chuyển sang giao hàng',
                        AppColors.muted,
                        'navigation',
                        '',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Notice(
            rejected
                ? 'Đã dùng hết 5 lần gửi. Liên hệ điều phối để được hỗ trợ.'
                : 'Bạn chưa thể rời điểm lấy hàng.',
            detail: rejected
                ? trip.reason
                : 'Vui lòng đợi khách xác nhận hàng. Bạn có thể gọi khách hoặc báo sự cố.',
            icon: 'warning',
            peach: true,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 10),
            TripError(state.error!),
          ],
          if (state.receipt != null) ...[
            const SizedBox(height: 10),
            Notice(
              'Yêu cầu ${state.receipt} đã gửi đến điều phối.',
              icon: 'check',
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.busy
                ? null
                : () => context.read<ActiveTripBloc>().add(CustomerCalled()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.orange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const AppIcon('phone', color: AppColors.orange),
            label: const Text('Gọi khách'),
          ),
          const SizedBox(height: 9),
          const PrimaryButton(
            'Bắt đầu giao hàng',
            onPressed: null,
            icon: 'navigation',
          ),
          TextButton(
            onPressed: state.busy ? null : () => showTripIncident(context),
            child: const Text('Báo sự cố'),
          ),
        ],
      ),
    );
  }

  Widget _step(
    String title,
    String subtitle,
    Color color,
    String icon,
    String trailing,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AppIcon(icon, color: Colors.white, size: 15),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: appText(
                        size: 13,
                        weight: FontWeight.w700,
                        color: color == AppColors.orange
                            ? color
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    trailing,
                    style: appText(size: 10, color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: appText(size: 11, color: AppColors.secondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
