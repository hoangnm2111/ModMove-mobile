import 'package:flutter_bloc/flutter_bloc.dart';
import '../controllers/home_controller.dart';
import 'package:flutter/material.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import '../models/vehicle_option.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key, this.initialVehicle = VehicleOption.truck});
  final VehicleOption initialVehicle;
  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late VehicleOption selected = widget.initialVehicle;
  @override
  Widget build(BuildContext context) {
    final fare = context.watch<HomeController>().fareFor(selected.type);
    return Scaffold(
      appBar: const AppHeader('Bảng giá dịch vụ'),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: PrimaryButton(
              'Tạo yêu cầu giao hàng',
              trailing: true,
              onPressed: () => showInfoSheet(
                context,
                'Giao hàng với ${selected.title}',
                'Xe có tải trọng tối đa ${fare.capacity}, thùng xe ${fare.dimensions}. Cước được xác định theo điểm lấy, điểm giao và dịch vụ bốc xếp.',
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        children: [
          const SectionTitle('Chọn xe cho nhu cầu của bạn', size: 17),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final vehicle in VehicleOption.values) ...[
                if (vehicle != VehicleOption.pickup) const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    onTap: () => setState(() => selected = vehicle),
                    color: vehicle == selected ? AppColors.peach : Colors.white,
                    borderColor: vehicle == selected
                        ? AppColors.orange
                        : AppColors.line,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          vehicle.icon,
                          size: 28,
                          color: vehicle == selected
                              ? AppColors.orange
                              : AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            vehicle.label,
                            style: appText(
                              size: 12,
                              weight: vehicle == selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: vehicle == selected
                                  ? AppColors.orange
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 19),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: VehicleImage(selected.asset, height: 82),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(selected.title, size: 17),
                      const SizedBox(height: 10),
                      Text(
                        'Tải trọng tối đa: ${fare.capacity}',
                        style: appText(size: 12.5, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thùng xe: ${fare.dimensions}',
                        style: appText(size: 12.5, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.peach,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'GIÁ MINH HỌA',
                    textAlign: TextAlign.center,
                    style: appText(
                      size: 17,
                      weight: FontWeight.w800,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _price('Giá cơ bản', fare.baseFareLabel),
                      const Divider(height: 1),
                      _price('Mỗi km', fare.perKm),
                      const Divider(height: 1),
                      _price('Cước tối thiểu', fare.minimumFareLabel),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.pale,
            borderColor: AppColors.pale,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  'Cước chuyến đi được tính thế nào?',
                  size: 16,
                ),
                const SizedBox(height: 7),
                Text(
                  'Giá cơ bản + cước theo km\n+ bốc xếp và phụ phí (nếu có).',
                  style: appText(
                    size: 14,
                    color: AppColors.secondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Giá chính thức hiển thị khi tạo đơn.',
                  style: appText(size: 13, color: AppColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            onTap: () => showInfoSheet(
              context,
              'Hỗ trợ bốc xếp',
              'Chọn dịch vụ bốc xếp khi tạo yêu cầu giao hàng. Phí dịch vụ được hiển thị trong tổng cước trước khi xác nhận.',
            ),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
            child: Row(
              children: [
                const AppIcon('box', size: 31),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Hỗ trợ bốc xếp', size: 17),
                      const SizedBox(height: 2),
                      Text(
                        'Chọn thêm khi đặt xe',
                        style: appText(size: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const AppIcon(
                  'chevron-right',
                  size: 20,
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _price(String label, String price) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label, style: appText(size: 16))),
        Text(
          price,
          style: appText(
            size: 18,
            weight: FontWeight.w700,
            color: AppColors.orange,
          ),
        ),
      ],
    ),
  );
}
