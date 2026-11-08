import '../../domain/entities/public_fare.dart';

enum VehicleOption {
  pickup('Bán tải', 'pickup', 'pickup', 'Xe bán tải'),
  van('Xe van', 'van', 'van', 'Xe van 500 kg'),
  truck('Xe tải', 'truck', 'truck-orange', 'Xe tải 1 tấn');

  const VehicleOption(this.label, this.icon, this.asset, this.title);
  final String label, icon, asset, title;
  VehicleType get type => VehicleType.values[index];
}

String formatAmount(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]}.',
);

extension PublicFareDisplay on PublicFare {
  String get capacity => '${formatAmount(capacityKg)} kg';
  String get dimensions {
    final sides = [
      lengthM,
      widthM,
      heightM,
    ].map((value) => value.toString().replaceAll('.', ',')).join(' × ');
    return '$sides m';
  }

  String get baseFareLabel => '${formatAmount(baseFare)}đ';
  String get perKm => '${formatAmount(pricePerKm)}đ';
  String get minimumFareLabel => '${formatAmount(minimumFare)}đ';
}
