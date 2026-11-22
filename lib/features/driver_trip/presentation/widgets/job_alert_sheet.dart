import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../bloc/job_offer_bloc.dart';
import 'trip_components.dart';

class JobAlertSheet extends StatelessWidget {
  const JobAlertSheet({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<JobOfferBloc, JobOfferState>(
    listener: (context, state) {
      if (state.status == OfferStatus.declined) Navigator.pop(context, false);
    },
    builder: (context, state) {
      final job = state.offer?.job;
      if (job == null) return const SizedBox.shrink();
      final fix = context.read<DriverTripRepository>().current.fix;
      final expired = state.status == OfferStatus.expired;
      final unavailable = state.status == OfferStatus.unavailable;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expired
                          ? 'Đã hết thời gian'
                          : unavailable
                          ? 'Đơn không còn khả dụng'
                          : 'Có chuyến mới',
                      style: appText(size: 22, weight: FontWeight.w700),
                    ),
                  ),
                  Semantics(
                    label: 'Còn ${offerTimeLeft(state.seconds)}',
                    child: SizedBox(
                      width: 66,
                      height: 66,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: state.seconds / JobOffer.matchingWindow.inSeconds,
                              strokeWidth: 5,
                              color: AppColors.orange,
                              backgroundColor: AppColors.peach,
                            ),
                          ),
                          Text(
                            offerTimeLeft(state.seconds),
                            style: appText(
                              size: 20,
                              weight: FontWeight.w700,
                              color: AppColors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (state.error != null) TripError(state.error!),
              RouteCard(
                job,
                distance: fix == null
                    ? null
                    : km(fix.point.distanceTo(job.pickupPoint)),
              ),
              const SizedBox(height: 12),
              TripMetrics(job),
              const SizedBox(height: 12),
              AppCard(
                color: AppColors.peach,
                borderColor: AppColors.peach,
                child: Column(
                  children: [
                    Text('Thu nhập dự kiến', style: appText(size: 13)),
                    const SizedBox(height: 4),
                    Text(
                      vnd(job.net),
                      style: appText(
                        size: 29,
                        weight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (expired || unavailable)
                PrimaryButton(
                  'Về danh sách đơn',
                  onPressed: () => Navigator.pop(context, false),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            context.read<JobOfferBloc>().add(OfferDeclined()),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 49),
                          side: const BorderSide(color: AppColors.orange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        'Xem chi tiết',
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
