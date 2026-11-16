import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/phone_button.dart';
import '../driver_trip/data/driver_api.dart';
import '../driver_trip/presentation/widgets/trip_components.dart';
import 'driver_account_models.dart';
import 'load_view.dart';

/// Các chuyến được gán cho tài xế (api/driver/trips) kèm hoa hồng và thực nhận.
class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});
  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  String _view = 'All';
  static const _views = {
    'All': 'Tất cả',
    'Active': 'Đang chạy',
    'Completed': 'Hoàn thành',
    'Cancelled': 'Đã hủy',
  };

  @override
  Widget build(BuildContext context) {
    final api = context.read<DriverApi>();
    return Scaffold(
      appBar: const AppHeader('Chuyến của tôi'),
      body: PagedListView<DriverTripSummary>(
        key: ValueKey(_view),
        emptyText: 'Chưa có chuyến nào.',
        header: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            children: [
              for (final entry in _views.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _view == entry.key,
                  onSelected: (_) => setState(() => _view = entry.key),
                ),
            ],
          ),
        ),
        fetch: (page) async {
          final p = PageOf.fromJson(
            await api.trips(view: _view, page: page),
            DriverTripSummary.fromJson,
          );
          return PageResult(p.items, p.hasNext);
        },
        itemBuilder: (context, trip) => AppCard(
          onTap: () => _detail(context, api, trip),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${trip.code}',
                      style: appText(size: 14, weight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    trip.statusLabel,
                    style: appText(
                      size: 12,
                      weight: FontWeight.w700,
                      color: trip.status == 'Cancelled'
                          ? AppColors.red
                          : (trip.status == 'Completed'
                                ? AppColors.green
                                : AppColors.orange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${trip.pickup}\n→ ${trip.dropoff}',
                style: appText(size: 12, color: AppColors.secondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trip.at == null ? '' : dateTime(trip.at!),
                      style: appText(size: 11, color: AppColors.muted),
                    ),
                  ),
                  Text(
                    'Thực nhận ${vnd(trip.earning)}',
                    style: appText(size: 13, weight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _detail(
    BuildContext context,
    DriverApi api,
    DriverTripSummary trip,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * .75,
      child: FutureBuilder<Map<String, dynamic>>(
        future: api.trip('${trip.id}'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: TripError(errorText(snapshot.error!)),
            );
          }
          final j = snapshot.data;
          if (j == null) {
            return const Center(child: CircularProgressIndicator());
          }
          int money(String key) => ((j[key] as num?) ?? 0).round();
          final histories = ((j['statusHistories'] as List?) ?? const [])
              .cast<Map>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                '#${j['orderCode']} · ${DriverTripSummary.statusLabels[j['orderStatus']] ?? j['orderStatus']}',
                style: appText(size: 18, weight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _line('Điểm lấy', '${j['pickupAddress']}'),
              _line('Điểm giao', '${j['dropoffAddress']}'),
              _line('Khách hàng', '${j['customerName'] ?? ''}'),
              _phone(j['customerPhone'] as String?),
              _line('Người nhận', '${j['receiverName'] ?? ''}'),
              _phone(j['receiverPhone'] as String?),
              _line(
                'Quãng đường',
                '${j['estimatedDistanceKm']} km · ${j['estimatedDurationMin']} phút',
              ),
              const Divider(),
              _line('Tổng cước', vnd(money('totalFee'))),
              _line('Hoa hồng', '-${vnd(money('commissionAmount'))}'),
              _line('Thực nhận', vnd(money('driverEarning')), bold: true),
              _line(
                'Thanh toán',
                '${j['paymentMethod'] == 'Cash' ? 'Tiền mặt' : 'PayOS'} · ${j['paymentStatus']}',
              ),
              if (histories.isNotEmpty) ...[
                const Divider(),
                const SectionTitle('Lịch sử trạng thái', size: 14),
                const SizedBox(height: 6),
                for (final h in histories)
                  _line(
                    DriverTripSummary.statusLabels[h['toStatus']] ??
                        '${h['toStatus']}',
                    DateTime.tryParse('${h['changedAt']}') == null
                        ? ''
                        : dateTime(
                            DateTime.parse('${h['changedAt']}').toLocal(),
                          ),
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );

  Widget _phone(String? phone) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: PhoneText(
              phone,
              style: appText(size: 13, weight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _line(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: appText(size: 12, color: AppColors.secondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: appText(
              size: 13,
              weight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
