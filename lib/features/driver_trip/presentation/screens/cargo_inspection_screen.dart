import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../bloc/active_trip_bloc.dart';
import '../bloc/evidence_cubit.dart';
import '../widgets/cargo_photo_tile.dart';
import '../widgets/trip_components.dart';
import '../widgets/trip_contact_actions.dart';
import 'driver_simulation_sheet.dart';

class CargoInspectionScreen extends StatelessWidget {
  const CargoInspectionScreen({super.key, required this.tripState});
  final ActiveTripState tripState;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<EvidenceCubit, EvidenceState>(
    builder: (context, state) {
      final trip = tripState.session.trip!;
      final job = trip.job;
      final needsCash =
          job.payment == PaymentMethod.cashSender && !trip.cashCollected;
      return Scaffold(
        appBar: AppHeader(
          'Kiểm tra hàng',
          onHelp: context.read<DriverTripRepository>() is TripSimulator
              ? () => showTripSimulation(context)
              : null,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: PrimaryButton(
              'Xác nhận đã lấy hàng',
              key: const Key('submit-inspection'),
              busy: state.busy,
              onPressed: state.ready && (!needsCash || state.cashCollected)
                  ? context.read<EvidenceCubit>().submit
                  : null,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          children: [
            const PickupStepper(1),
            if (trip.review == EvidenceReview.rejected)
              TripError(
                '${trip.reason}\nLần gửi ${trip.attempts}/5. Chụp lại 2 ảnh trước khi gửi.',
              ),
            if (state.error != null) TripError(state.error!),
            if (tripState.error != null) TripError(tripState.error!),
            if (tripState.receipt != null)
              Notice(
                'Đã gửi yêu cầu ${tripState.receipt}. Điều phối sẽ liên hệ.',
                icon: 'check',
              ),
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(
                      color: AppColors.peach,
                      shape: BoxShape.circle,
                    ),
                    child: const AppIcon('box', color: AppColors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${job.boxes} thùng hàng · ${job.weightKg} kg',
                          style: appText(size: 15, weight: FontWeight.w700),
                        ),
                        Text(
                          job.cargoDescription.isEmpty
                              ? 'Hàng hóa'
                              : job.cargoDescription,
                          style: appText(size: 12, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                  if (job.fragile)
                    const TripBadge('Hàng dễ vỡ', icon: 'fragile'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionTitle('Danh sách kiểm tra', size: 15),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: List.generate(
                  4,
                  (i) => Column(
                    children: [
                      if (i > 0) const Divider(height: 1, indent: 36),
                      InkWell(
                        key: Key('cargo-check-$i'),
                        onTap: state.busy
                            ? null
                            : () => context.read<EvidenceCubit>().check(
                                i,
                                !state.checklist[i],
                              ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Semantics(
                                checked: state.checklist[i],
                                label: _labels[i],
                                child: Container(
                                  width: 25,
                                  height: 25,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: state.checklist[i]
                                        ? AppColors.green
                                        : Colors.white,
                                    border: Border.all(
                                      color: state.checklist[i]
                                          ? AppColors.green
                                          : AppColors.line,
                                    ),
                                  ),
                                  child: state.checklist[i]
                                      ? const AppIcon(
                                          'check',
                                          color: Colors.white,
                                          size: 17,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _labels[i],
                                      style: appText(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        'Đồ gia dụng theo đơn hàng',
                                        '${job.boxes} / ${job.boxes} thùng hàng',
                                        'Tổng ${job.weightKg} kg · Phù hợp xe 1 tấn',
                                        'Không móp méo, không hư hỏng',
                                      ][i],
                                      style: appText(
                                        size: 11,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const AppIcon('chevron-right', size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle('Ảnh bằng chứng (${state.uploadedCount}/2)', size: 15),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CargoPhotoTile(
                    kind: CargoPhotoKind.overall,
                    state: state,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CargoPhotoTile(
                    kind: CargoPhotoKind.secured,
                    state: state,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (needsCash) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Đã thu ${vnd(job.fare)} từ người gửi',
                  style: appText(size: 13, weight: FontWeight.w600),
                ),
                subtitle: const Text('Thu tiền trước khi xếp hàng lên xe.'),
                value: state.cashCollected,
                onChanged: state.busy
                    ? null
                    : (v) => context.read<EvidenceCubit>().setCashCollected(v!),
              ),
              const SizedBox(height: 8),
            ],
            const SectionTitle('Ghi chú chênh lệch (nếu có)', size: 13),
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey('note-${job.id}'),
              initialValue: state.note,
              enabled: !state.busy,
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
              onChanged: context.read<EvidenceCubit>().setNote,
              decoration: const InputDecoration(
                hintText: 'Nhập ghi chú…',
                counterText: '',
              ),
            ),
            const SizedBox(height: 9),
            AppCard(
              color: AppColors.pale,
              onTap: state.busy ? null : () => showTripIncident(context),
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  const AppIcon(
                    'warning',
                    size: 20,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Hàng không khớp? Báo sự cố',
                      style: appText(size: 12),
                    ),
                  ),
                  const AppIcon('chevron-right', size: 17),
                ],
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      );
    },
  );
  static const _labels = [
    'Đúng loại hàng',
    'Đủ số lượng',
    'Đúng tải trọng & kích thước',
    'Bao bì nguyên vẹn',
  ];
}
