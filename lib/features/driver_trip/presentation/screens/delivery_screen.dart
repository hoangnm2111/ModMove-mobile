import '../../../../core/widgets/notice_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/repositories/device_cargo_photo_repository.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';
import '../bloc/active_trip_bloc.dart';
import '../widgets/trip_components.dart';
import '../widgets/trip_contact_actions.dart';
import 'driver_simulation_sheet.dart';

/// Đơn đã `InTransit` (khách xác nhận hàng): đến điểm giao → thu COD (nếu có) → ảnh giao hàng (POD).
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key, required this.state, this.photos});
  final ActiveTripState state;

  /// Cho test chèn nguồn ảnh; mặc định dùng camera/thư viện của máy.
  final CargoPhotoRepository? photos;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  CargoPhoto? _proof;
  String? _pickError;

  Future<void> _pick() async {
    final source = await showModalBottomSheet<CargoPhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon('camera'),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, CargoPhotoSource.camera),
            ),
            ListTile(
              leading: const AppIcon('image'),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, CargoPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final photo = await (widget.photos ?? DeviceCargoPhotoRepository()).pick(
        CargoPhotoKind.overall,
        source,
      );
      if (photo != null && mounted) {
        setState(() {
          _proof = photo;
          _pickError = null;
        });
      }
    } on TripFailure catch (e) {
      if (mounted) setState(() => _pickError = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final trip = state.session.trip!;
    final job = trip.job;
    final needCash = job.cash && !trip.cashCollected;
    final paused = state.paused;
    final canFinish = _proof != null && !needCash && !state.busy && !paused && state.atDropoff;
    return BlocListener<ActiveTripBloc, ActiveTripState>(
      listenWhen: (previous, next) => next.delivered && !previous.delivered,
      listener: (context, _) {
        showNotice(context, 'Đã giao hàng thành công.');
        Navigator.pushNamedAndRemoveUntil(context, '/driver-home', (_) => false);
      },
      child: Scaffold(
        appBar: AppHeader(
          'Đang giao hàng',
          onHelp: () => showTripSimulation(context),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PickupStepper(3),
              IncidentBanner(trip),
              RouteCard(job),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.busy
                    ? null
                    : () => context.read<ActiveTripBloc>().add(
                        ExternalNavigationOpened(),
                      ),
                style: _outlined,
                icon: const AppIcon('navigation', color: AppColors.orange),
                label: const Text('Mở chỉ đường giao hàng'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('arrive-dropoff'),
                onPressed: state.busy || paused
                    ? null
                    : () => context.read<ActiveTripBloc>().add(DropoffArrived()),
                style: _outlined,
                icon: const AppIcon('map-pin', color: AppColors.orange),
                label: const Text('Báo đã đến điểm giao'),
              ),
              if (state.session.notice != null) ...[
                const SizedBox(height: 10),
                Notice(state.session.notice!, icon: 'info'),
              ],
              const SizedBox(height: 16),
              if (job.cash) ...[
                const SectionTitle('Thu tiền mặt', size: 16),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      const AppIcon('cash', color: AppColors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          needCash
                              ? 'Thu ${vnd(job.fare)} từ ${job.payment == PaymentMethod.cashReceiver ? 'người nhận' : 'người gửi'}'
                              : 'Đã thu ${vnd(job.fare)}',
                          style: appText(size: 14, weight: FontWeight.w700),
                        ),
                      ),
                      if (needCash)
                        TextButton(
                          key: const Key('collect-cash'),
                          onPressed: state.busy || paused
                              ? null
                              : () => context.read<ActiveTripBloc>().add(
                                  CashCollected(),
                                ),
                          child: const Text('Đã thu tiền'),
                        )
                      else
                        const AppIcon('check', color: AppColors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SectionTitle('Ảnh giao hàng', size: 16),
              const SizedBox(height: 8),
              AppCard(
                onTap: state.busy ? null : _pick,
                child: _proof == null
                    ? SizedBox(
                        height: 120,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppIcon('camera', size: 30, color: AppColors.orange),
                              const SizedBox(height: 6),
                              Text(
                                'Chụp ảnh hàng đã giao',
                                style: appText(size: 13, color: AppColors.secondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          _proof!.bytes,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              if (_pickError != null) ...[
                const SizedBox(height: 8),
                TripError(_pickError!),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 10),
                TripError(state.error!),
              ],
              if (state.receipt != null) ...[
                const SizedBox(height: 10),
                Notice(state.receipt!, icon: 'check'),
              ],
              const SizedBox(height: 10),
              if (!state.fresh)
                const TripError(
                  'Vị trí không khả dụng hoặc quá 30 giây. Bật lại GPS để hoàn tất giao hàng.',
                ),
              const Notice(
                'Chỉ hoàn tất khi cách điểm giao không quá 500 m.',
                icon: 'warning',
                peach: true,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                'Hoàn tất giao hàng',
                key: const Key('finish-delivery'),
                icon: 'check',
                busy: state.busy,
                onPressed: canFinish
                    ? () => context.read<ActiveTripBloc>().add(
                        DeliveryCompleted(_proof!),
                      )
                    : null,
              ),
              if (needCash)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Cần xác nhận đã thu tiền trước khi hoàn tất.',
                    style: appText(size: 11, color: AppColors.muted),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => context.read<ActiveTripBloc>().add(CustomerCalled()),
                    child: const Text('Gọi khách'),
                  ),
                  TextButton(
                    onPressed: state.busy ? null : () => showTripIncident(context),
                    child: const Text('Báo sự cố'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _outlined = OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, 48),
    side: const BorderSide(color: AppColors.orange),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
