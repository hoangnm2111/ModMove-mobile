import 'package:flutter_bloc/flutter_bloc.dart';
import '../controllers/home_controller.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/brand_logo.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import '../models/vehicle_option.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onRegister,
    required this.onAccount,
    this.onDeliver,
  });
  final VoidCallback onRegister, onAccount;

  /// "Giao hàng ngay": đăng nhập khách rồi đặt xe. Không truyền → mở bảng giá như cũ.
  final VoidCallback? onDeliver;

  void _fare(
    BuildContext context, [
    VehicleOption vehicle = VehicleOption.truck,
  ]) => Navigator.pushNamed(context, '/pricing', arguments: vehicle);

  @override
  Widget build(BuildContext context) {
    final truckFare = context.watch<HomeController>().fareFor(
      VehicleOption.truck.type,
    );
    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        selected: 0,
        onSelect: (index) {
          if (index == 1) _fare(context);
          if (index == 2) {
            showInfoSheet(
              context,
              'Hỗ trợ ModMove',
              'Chọn loại xe phù hợp với tải trọng và kích thước hàng hóa. Bạn có thể xem bảng giá trước khi tạo yêu cầu giao hàng.',
            );
          }
          if (index == 3) onAccount();
        },
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const BrandLogo(size: 36),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ModMove',
                        style: appText(
                          size: 28,
                          weight: FontWeight.w800,
                          color: AppColors.orange,
                          spacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange,
                      minimumSize: const Size(110, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      side: const BorderSide(color: AppColors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      'Đăng nhập',
                      style: appText(
                        weight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 158),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/hero-delivery.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 19, 0, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chở hàng lớn,\nthật dễ dàng',
                            style: appText(
                              size: 27,
                              weight: FontWeight.w800,
                              height: 1.17,
                              spacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 178,
                            child: Text(
                              'Đặt xe phù hợp cho mỗi\nchuyến hàng.',
                              style: appText(
                                size: 14.5,
                                color: AppColors.secondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            PrimaryButton(
              'Giao hàng ngay',
              icon: 'box',
              trailing: true,
              onPressed: onDeliver ?? () => _fare(context),
            ),
            const SizedBox(height: 21),
            const SectionTitle('Chọn xe phù hợp'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final vehicle in VehicleOption.values) ...[
                  if (vehicle != VehicleOption.pickup) const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
                      onTap: () => _fare(context, vehicle),
                      child: Column(
                        children: [
                          VehicleImage(vehicle.asset, height: 64),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  vehicle.label,
                                  style: appText(
                                    size: 15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const AppIcon('chevron-right', size: 13),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 13),
            AppCard(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              onTap: () => _fare(context),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: SectionTitle('Bảng giá công khai', size: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          'Giá minh họa',
                          style: appText(
                            size: 10,
                            weight: FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const AppIcon('chevron-right', size: 16),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.pale,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: VehicleImage('truck-orange', height: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Xe tải 1 tấn', style: appText(size: 14)),
                      const Spacer(),
                      Text('Từ ', style: appText(size: 14)),
                      Text(
                        truckFare.baseFareLabel,
                        style: appText(
                          size: 16,
                          weight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Xem bảng giá',
                            style: appText(
                              size: 14,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        const AppIcon(
                          'chevron-right',
                          size: 17,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              color: AppColors.peach,
              borderColor: const Color(0xFFFFD2B7),
              onTap: onRegister,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFDCC3),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: AppIcon('steering', color: AppColors.orange),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trở thành tài xế ModMove',
                          style: appText(size: 13, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Đăng ký và gửi hồ sơ trực tuyến',
                          style: appText(size: 12, color: AppColors.secondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đăng ký tài xế  →',
                          style: appText(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: AppIcon(
                      'chevron-right',
                      size: 16,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              onTap: () => showInfoSheet(
                context,
                'Tin tức & hướng dẫn',
                'Chuẩn bị ảnh giấy tờ rõ nét, còn hiệu lực và đủ 4 góc. Kiểm tra tải trọng và kích thước thùng xe trước khi đăng ký.',
              ),
              child: Row(
                children: [
                  const AppIcon('news', size: 20, color: AppColors.secondary),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Tin tức & hướng dẫn',
                      style: appText(size: 13, weight: FontWeight.w600),
                    ),
                  ),
                  const AppIcon(
                    'chevron-right',
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
