import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/bloc/active_trip_bloc.dart';

// GB-52 (D-02): chỉ cho hoàn tất giao hàng khi GPS mới (≤ 30 giây) và cách điểm giao ≤ 500 m. BE không kiểm tra.
void main() {
  final now = DateTime(2026, 11, 13, 10);
  const dropoff = GeoPoint(10.8015, 106.7105);
  final job = DeliveryJob(
    id: '7',
    pickup: 'A',
    dropoff: 'B',
    pickupPoint: const GeoPoint(10.7653, 106.6997),
    dropoffPoint: dropoff,
    createdAt: now,
  );

  ActiveTripState stateAt(GeoPoint? point, {DateTime? fixAt, bool gps = true}) => ActiveTripState(
    DriverSession(
      gpsEnabled: gps,
      fix: point == null ? null : GpsFix(point, fixAt ?? now),
      trip: ActiveTrip(job: job, stage: TripStage.inTransit),
    ),
    now,
  );

  test('đứng ở điểm giao, GPS mới thì được hoàn tất', () {
    expect(stateAt(dropoff).atDropoff, isTrue);
  });

  test('cách điểm giao khoảng 600 m thì bị khóa', () {
    expect(stateAt(const GeoPoint(10.8069, 106.7105)).atDropoff, isFalse);
  });

  test('GPS cũ hơn 30 giây thì bị khóa', () {
    expect(stateAt(dropoff, fixAt: now.subtract(const Duration(seconds: 31))).atDropoff, isFalse);
  });

  test('tắt GPS hoặc chưa có vị trí thì bị khóa', () {
    expect(stateAt(dropoff, gps: false).atDropoff, isFalse);
    expect(stateAt(null).atDropoff, isFalse);
  });
}
