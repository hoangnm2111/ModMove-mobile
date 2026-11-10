import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/formatting/vietnam_time.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../../domain/repositories/trip_history_repository.dart';
import '../bloc/active_trip_bloc.dart';
import '../bloc/delivery_cubit.dart';
import '../widgets/driver_map.dart';
import '../widgets/trip_components.dart';
import '../widgets/trip_contact_actions.dart';

class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key, required this.tripState});
  final ActiveTripState tripState;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DeliveryCubit(
      context.read<DriverTripRepository>(),
      context.read<DriverDeliveryRepository>(),
      context.read<CargoPhotoRepository>(),
    ),
    child: _DeliveryBody(tripState),
  );
}

class _DeliveryBody extends StatelessWidget {
  const _DeliveryBody(this.tripState);
  final ActiveTripState tripState;
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DeliveryCubit, DeliveryState>(
    builder: (context, state) {
      final trip = tripState.session.trip!;
      final cubit = context.read<DeliveryCubit>();
      final needsCash =
          trip.job.cash && !trip.cashCollected && trip.job.fare > 0;
      return Scaffold(
        appBar: const AppHeader('Hoàn tất giao hàng'),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              'Xác nhận đã giao hàng',
              key: const Key('confirm-delivery'),
              busy: state.busy,
              onPressed:
                  state.uploaded != null &&
                      (!needsCash || state.cash) &&
                      !state.busy
                  ? cubit.submit
                  : null,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const PickupStepper(3),
            const Notice(
              'Khách đã xác nhận hàng. Chuyến đã bắt đầu giao.',
              icon: 'check',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: DriverMap(
                  liveLocation: true,
                  route: true,
                  position: tripState.session.fix?.point,
                  destination: trip.job.dropoffPoint,
                  available: tripState.session.mapAvailable,
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const AppIcon(
                        'map-pin',
                        color: AppColors.orange,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.job.dropoff,
                              style: appText(size: 15, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${trip.job.receiverName} · ${trip.job.receiverPhone}',
                              style: appText(size: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Gọi người nhận',
                        onPressed: trip.job.receiverPhone.isEmpty
                            ? null
                            : () async {
                                final opened = await context
                                    .read<TripContactRepository>()
                                    .callCustomer(trip.job.receiverPhone);
                                if (!opened && context.mounted) {
                                  showInfoSheet(
                                    context,
                                    'Liên hệ người nhận',
                                    trip.job.receiverPhone,
                                  );
                                }
                              },
                        icon: const AppIcon('phone', color: AppColors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.read<ActiveTripBloc>().add(
                      ExternalNavigationOpened(),
                    ),
                    icon: const AppIcon('navigation', size: 18),
                    label: const Text('Mở chỉ đường giao hàng'),
                  ),
                  if (state.arrivalSent)
                    const Notice(
                      'Đã thông báo đến điểm giao cho khách.',
                      icon: 'check',
                    )
                  else
                    TextButton(
                      onPressed: state.busy ? null : cubit.arrive,
                      child: const Text('Thông báo đã đến điểm giao'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('Ảnh giao hàng', size: 16),
            const SizedBox(height: 8),
            if (state.photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  state.photo!.bytes,
                  height: 195,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 100,
                    child: Center(
                      child: Text('Không đọc được ảnh. Vui lòng chọn lại.'),
                    ),
                  ),
                ),
              )
            else
              AppCard(
                color: AppColors.peach,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const AppIcon(
                        'camera',
                        size: 48,
                        color: AppColors.orange,
                      ),
                      const SizedBox(height: 8),
                      Text('Chụp hàng tại điểm giao', style: appText(size: 13)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => cubit.pick(CargoPhotoSource.camera),
                    icon: const AppIcon('camera', size: 18),
                    label: const Text('Chụp ảnh'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => cubit.pick(CargoPhotoSource.gallery),
                    icon: const AppIcon('image', size: 18),
                    label: const Text('Thư viện'),
                  ),
                ),
              ],
            ),
            if (state.busy) const LinearProgressIndicator(),
            if (state.uploaded != null)
              const Notice('Ảnh đã tải lên', icon: 'check'),
            if (state.photo != null && state.uploaded == null && !state.busy)
              TextButton(
                onPressed: cubit.retryUpload,
                child: const Text('Tải ảnh lại'),
              ),
            const SizedBox(height: 16),
            const SectionTitle('Thanh toán chuyến', size: 16),
            const SizedBox(height: 8),
            AppCard(
              child: needsCash
                  ? CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: state.cash,
                      onChanged: state.busy
                          ? null
                          : (v) => cubit.confirmCash(v ?? false),
                      title: Text(
                        'Đã thu ${vnd(trip.job.fare)}',
                        style: appText(
                          weight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                      subtitle: Text(
                        trip.job.payment == PaymentMethod.cashReceiver
                            ? 'Người nhận thanh toán tiền mặt'
                            : 'Người gửi thanh toán tiền mặt',
                        style: appText(size: 12),
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            trip.job.cash
                                ? 'Đã thu tiền mặt'
                                : 'Đã thanh toán PayOS',
                          ),
                        ),
                        Text(
                          vnd(trip.job.fare),
                          style: appText(weight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 12),
              TripError(state.error!),
            ],
            if (tripState.error != null) TripError(tripState.error!),
            if (tripState.receipt != null)
              Notice(
                'Đã gửi sự cố #${tripState.receipt} đến điều phối.',
                icon: 'check',
              ),
            TextButton(
              onPressed: state.busy ? null : () => showTripIncident(context),
              child: const Text('Báo sự cố'),
            ),
            const TripIncidentHistoryLink(),
          ],
        ),
      );
    },
  );
}

class DeliverySuccessScreen extends StatelessWidget {
  const DeliverySuccessScreen(this.trip, {super.key});
  final ActiveTrip trip;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppHeader('Hoàn tất'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SvgPicture.asset(
          'assets/illustrations/delivery-success.svg',
          height: 180,
        ),
        Text(
          'Giao hàng thành công',
          textAlign: TextAlign.center,
          style: appText(size: 25, weight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          '#${trip.job.displayCode}',
          textAlign: TextAlign.center,
          style: appText(size: 16),
        ),
        const SizedBox(height: 8),
        if (trip.deliveredAt != null)
          Text(
            'Đã giao lúc ${vietnamStamp(trip.deliveredAt!)}',
            textAlign: TextAlign.center,
            style: appText(size: 12, color: AppColors.secondary),
          ),
        const SizedBox(height: 28),
        const ListTile(
          leading: Icon(Icons.check_circle, color: AppColors.green),
          title: Text('Đã tải bằng chứng giao hàng'),
        ),
        ListTile(
          leading: const Icon(Icons.check_circle, color: AppColors.green),
          title: Text(
            '${trip.job.cash ? 'Đã thu' : 'Đã thanh toán'} ${vnd(trip.job.fare)}',
          ),
        ),
        ListTile(
          leading: AppIcon(
            trip.stage == TripStage.completed ? 'check' : 'clock',
            color: AppColors.green,
          ),
          title: Text(
            trip.stage == TripStage.completed
                ? 'Đã tất toán chuyến'
                : 'Chờ khách xác nhận nhận hàng',
          ),
        ),
        const SizedBox(height: 18),
        Notice(
          trip.stage == TripStage.completed ? 'Hoàn thành' : 'Đã giao',
          detail: trip.stage == TripStage.completed
              ? 'Thu nhập chuyến đã được hệ thống ghi nhận.'
              : 'Thu nhập sẽ được ghi nhận khi đơn hoàn thành.',
          icon: 'clipboard-check',
          success: true,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          'Xem thu nhập chuyến',
          onPressed: () => Navigator.pushNamed(
            context,
            '/trip-earnings',
            arguments: trip.job.id,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/driver-home',
            (_) => false,
          ),
          child: const Text('Về trang chủ'),
        ),
      ],
    ),
  );
}
