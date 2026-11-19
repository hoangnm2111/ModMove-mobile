import '../../../../core/domain/result_page.dart';
import '../entities/trip_models.dart';

class TripSummary {
  const TripSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.earning,
    required this.createdAt,
  });
  final String id, code, status, pickup, dropoff;
  final int fare, earning;
  final DateTime createdAt;
}

abstract interface class TripHistoryRepository {
  Future<ResultPage<TripSummary>> history({int page = 1, String view = 'All'});
  Future<ActiveTrip> detail(String id);
}

abstract interface class DriverDeliveryRepository {
  Future<void> arriveDropoff();
  Future<void> deliver({required String photoUrl, required bool cashCollected});
}
