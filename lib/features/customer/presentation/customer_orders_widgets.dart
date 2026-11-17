import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'customer_widgets.dart';

class CustomerOrderTabs extends StatelessWidget {
  const CustomerOrderTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: AppColors.pale,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final (id, label) in [
          ('Active', 'Đang giao'),
          ('History', 'Lịch sử'),
          ('All', 'Tất cả'),
        ])
          Expanded(
            child: Semantics(
              selected: value == id,
              button: true,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: value == id ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: value == id
                      ? [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: .06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 6,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: appText(
                          size: 14,
                          weight: value == id
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: value == id
                              ? AppColors.orange
                              : AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class CustomerOrdersEmpty extends StatelessWidget {
  const CustomerOrdersEmpty({
    super.key,
    required this.view,
    required this.filtered,
    required this.onBook,
    required this.onReset,
    required this.onActive,
  });
  final String view;
  final bool filtered;
  final VoidCallback onBook, onReset, onActive;

  @override
  Widget build(BuildContext context) {
    final history = view == 'History';
    final title = filtered
        ? 'Không tìm thấy đơn phù hợp'
        : history
        ? 'Chưa có lịch sử giao hàng'
        : view == 'Active'
        ? 'Chưa có đơn đang giao'
        : 'Chuyến giao đầu tiên đang chờ bạn';
    final message = filtered
        ? 'Thử tìm bằng mã đơn, địa chỉ khác\nhoặc bỏ bớt bộ lọc nhé.'
        : history
        ? 'Đơn đã hoàn thành hoặc đã hủy\nsẽ được lưu lại tại đây.'
        : 'Gửi món hàng của bạn. ModMove sẽ giúp bạn\ntheo dõi từng chặng đường.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/illustrations/customer-orders-empty.svg',
                width: 190,
                height: 156,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: appText(size: 21, weight: FontWeight.w700, height: 1.3),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: appText(
                  size: 14,
                  color: AppColors.secondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: filtered ? onReset : onBook,
                icon: AppIcon(
                  filtered ? 'refresh' : 'plus',
                  size: 20,
                  color: Colors.white,
                ),
                label: Text(
                  filtered ? 'Xóa tìm kiếm & bộ lọc' : 'Đặt giao hàng',
                ),
              ),
              if (history && !filtered) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onActive,
                  child: const Text('Xem đơn đang giao'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
