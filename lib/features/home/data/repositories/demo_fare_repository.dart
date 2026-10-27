import '../../domain/entities/public_fare.dart';
import '../../domain/repositories/fare_repository.dart';

/// Illustrative public fares from the UI reference; no production prices.
class DemoFareRepository implements FareRepository {
  const DemoFareRepository();
  @override
  List<PublicFare> getPublicFares() => const [
    PublicFare(
      type: VehicleType.pickup,
      capacityKg: 750,
      lengthM: 1.5,
      widthM: 1.5,
      heightM: 0.5,
      baseFare: 100000,
      pricePerKm: 10000,
      minimumFare: 100000,
    ),
    PublicFare(
      type: VehicleType.van,
      capacityKg: 500,
      lengthM: 1.7,
      widthM: 1.2,
      heightM: 1.2,
      baseFare: 120000,
      pricePerKm: 12000,
      minimumFare: 120000,
    ),
    PublicFare(
      type: VehicleType.truck,
      capacityKg: 1000,
      lengthM: 3.1,
      widthM: 1.6,
      heightM: 1.6,
      baseFare: 180000,
      pricePerKm: 15000,
      minimumFare: 180000,
    ),
  ];
}
