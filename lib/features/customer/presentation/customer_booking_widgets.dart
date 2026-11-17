import 'package:flutter/material.dart';
import '../domain/customer_models.dart';
import 'customer_widgets.dart';

class BookingProgress extends StatelessWidget {
  const BookingProgress(this.step, {super.key});
  final int step;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: List.generate(
      4,
      (i) => Expanded(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: i == 0
                        ? Colors.transparent
                        : i <= step
                        ? AppColors.orange
                        : AppColors.line,
                  ),
                ),
                Semantics(
                  label: 'Bước ${i + 1}${i == step ? ', hiện tại' : ''}',
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= step ? AppColors.orange : Colors.white,
                      border: Border.all(
                        color: i <= step ? AppColors.orange : AppColors.line,
                      ),
                    ),
                    child: i < step
                        ? const AppIcon('check', size: 18, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: appText(
                              weight: FontWeight.w700,
                              color: i <= step ? Colors.white : AppColors.muted,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: i == 3
                        ? Colors.transparent
                        : i < step
                        ? AppColors.orange
                        : AppColors.line,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              ['Địa chỉ', 'Hàng hóa', 'Chọn xe', 'Thanh toán'][i],
              textAlign: TextAlign.center,
              style: appText(
                size: 11,
                weight: i == step ? FontWeight.w700 : FontWeight.w500,
                color: i == step ? AppColors.orange : AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BookingVehicleCard extends StatelessWidget {
  const BookingVehicleCard({
    super.key,
    required this.vehicle,
    required this.draft,
    required this.onTap,
  });
  final Vehicle vehicle;
  final BookingDraft draft;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final selected = draft.vehicleId == vehicle.id, fits = vehicle.fits(draft);
    final name = vehicle.name.toLowerCase();
    final asset = name.contains('van')
        ? 'vehicle-van'
        : name.contains('bán tải') || name.contains('pickup')
        ? 'vehicle-pickup'
        : vehicle.weight <= 1000
        ? 'vehicle-truck-orange'
        : 'vehicle-truck-white';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: selected ? AppColors.peach : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.orange : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: fits ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12, top: 16),
                        child: Image.asset(
                          'assets/images/$asset.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.name,
                            style: appText(size: 17, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tải trọng: ${vehicle.weight.toStringAsFixed(0)} kg',
                            style: appText(size: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kích thước thùng:\n${vehicle.length} × ${vehicle.width} × ${vehicle.height} cm',
                            style: appText(
                              size: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 22,
                      color: selected ? AppColors.orange : AppColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    AppIcon(
                      fits ? 'check' : 'warning',
                      size: 16,
                      color: fits ? AppColors.green : AppColors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fits
                            ? 'Phù hợp với hàng của bạn'
                            : 'Hàng vượt sức chứa của xe',
                        style: appText(
                          size: 12,
                          color: fits ? AppColors.green : AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookingPaymentChoice extends StatelessWidget {
  const BookingPaymentChoice({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.subtitle,
  });
  final String value, selected, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: value == selected ? AppColors.peach : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: value == selected ? AppColors.orange : AppColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppIcon(
                value == 'PayOS' ? 'qr-code' : 'cash',
                size: 30,
                color: value == selected
                    ? AppColors.orange
                    : AppColors.secondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value == 'PayOS' ? 'PayOS / VietQR' : 'Tiền mặt',
                      style: appText(size: 17, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: appText(size: 12, color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                value == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: value == selected ? AppColors.orange : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
