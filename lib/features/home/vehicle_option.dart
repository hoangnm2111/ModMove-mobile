enum VehicleOption {
  pickup(
    'Bán tải',
    'pickup',
    'pickup',
    'Xe bán tải',
    '750 kg',
    '1,5 × 1,5 × 0,5 m',
    '100.000đ',
    '10.000đ',
  ),
  van(
    'Xe van',
    'van',
    'van',
    'Xe van 500 kg',
    '500 kg',
    '1,7 × 1,2 × 1,2 m',
    '120.000đ',
    '12.000đ',
  ),
  truck(
    'Xe tải',
    'truck',
    'truck-orange',
    'Xe tải 1 tấn',
    '1.000 kg',
    '3,1 × 1,6 × 1,6 m',
    '180.000đ',
    '15.000đ',
  );

  const VehicleOption(
    this.label,
    this.icon,
    this.asset,
    this.title,
    this.capacity,
    this.dimensions,
    this.baseFare,
    this.perKm,
  );
  final String label, icon, asset, title, capacity, dimensions, baseFare, perKm;
}
