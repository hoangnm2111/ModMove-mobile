import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';

Future<void> showTripSimulation(BuildContext context) async {
  final repository = context.read<DriverTripRepository>();
  if (repository is! TripSimulator) return;
  final action = await showModalBottomSheet<TripSimulation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .8,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              'Kịch bản mô phỏng',
              style: appText(size: 20, weight: FontWeight.w700),
            ),
            const Text(
              'Dùng để thử dữ liệu từ hệ thống, GPS và phản hồi của khách.',
            ),
            const SizedBox(height: 12),
            ...const <TripSimulation, String>{
              TripSimulation.newOffer: 'Phát một đơn mới',
              TripSimulation.acceptElsewhere: 'Tài xế khác nhận đơn trước',
              TripSimulation.cancelOrder: 'Khách hủy chuyến',
              TripSimulation.nearPickup: 'GPS: đã ở điểm lấy hàng',
              TripSimulation.advanceRoute: 'GPS: di chuyển 300 m theo tuyến',
              TripSimulation.gpsLost: 'GPS: mất quyền vị trí',
              TripSimulation.gpsRestored: 'GPS: khôi phục vị trí',
              TripSimulation.mapUnavailable: 'Bản đồ: không tải được',
              TripSimulation.mapRestored: 'Bản đồ: khôi phục',
              TripSimulation.uploadFailure: 'Lần tải ảnh tiếp theo thất bại',
              TripSimulation.requestFailure: 'Yêu cầu tiếp theo lỗi mạng',
              TripSimulation.customerApproves: 'Khách xác nhận hàng',
              TripSimulation.customerRejects: 'Khách yêu cầu chụp lại',
              TripSimulation.emptyJobs: 'Không có đơn phù hợp',
              TripSimulation.lowDeposit: 'Ký quỹ còn 100.000đ',
            }.entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, e.key),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null) return;
  try {
    await (repository as TripSimulator).simulate(action);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is TripFailure ? e.message : 'Chưa thực hiện được kịch bản.',
          ),
        ),
      );
    }
  }
}
