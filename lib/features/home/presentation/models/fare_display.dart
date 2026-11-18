import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customer/domain/entities/customer_models.dart';

/// Cách hiện một loại xe của BE trong bảng giá công khai.
extension FareDisplay on VehicleType {
  String get icon => image == 'truck-orange' ? 'truck' : image;
  String get capacity => '${money(maxLoadWeightKg).replaceFirst('đ', '')} kg';
  String get dimensions =>
      '${[bedLengthCm, bedWidthCm, bedHeightCm].map((cm) => cm % 100 == 0 ? '${cm ~/ 100}' : '${cm / 100}'.replaceAll('.', ',')).join(' × ')} m';
  String get baseFareLabel => money(baseFare);
  String get perKm => money(pricePerKm);
  String get minimumFareLabel => money(minimumFare);
}

/// Chưa tải được bảng giá (mất mạng, BE lỗi): báo và cho thử lại.
class FaresUnavailable extends StatelessWidget {
  const FaresUnavailable({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Chưa tải được bảng giá.',
          style: appText(size: 13, color: AppColors.secondary),
        ),
      ),
      TextButton(onPressed: onRetry, child: const Text('Thử lại')),
    ],
  );
}
