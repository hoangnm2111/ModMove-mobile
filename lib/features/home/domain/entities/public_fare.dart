enum VehicleType { pickup, van, truck }

class PublicFare {
  const PublicFare({
    required this.type,
    required this.capacityKg,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    required this.baseFare,
    required this.pricePerKm,
    required this.minimumFare,
  });
  final VehicleType type;
  final int capacityKg, baseFare, pricePerKm, minimumFare;
  final double lengthM, widthM, heightM;
}
