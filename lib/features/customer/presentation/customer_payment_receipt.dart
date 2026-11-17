import 'package:flutter/material.dart';
import '../domain/customer_models.dart';
import 'customer_widgets.dart';

/// Only presents the payment state returned by the order API.
class CustomerPaymentReceipt extends StatelessWidget {
  const CustomerPaymentReceipt(this.order, {super.key});
  final OrderDetail order;
  @override
  Widget build(BuildContext context) {
    final paid = order.summary.paymentStatus == 'Paid';
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả thanh toán')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CustomerBrand(compact: true),
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: paid ? AppColors.greenBg : AppColors.amberBg,
              ),
              child: AppIcon(
                paid ? 'check' : 'clock',
                size: 50,
                color: paid ? AppColors.green : AppColors.amber,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            paid
                ? 'Thanh toán thành công'
                : statusLabel(order.summary.paymentStatus),
            textAlign: TextAlign.center,
            style: appText(size: 25, weight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            money(order.summary.total),
            textAlign: TextAlign.center,
            style: appText(
              size: 38,
              weight: FontWeight.w800,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 28),
          CustomerCard(
            child: Column(
              children: [
                detailRow('Mã đơn', order.summary.code),
                detailRow(
                  'Phương thức',
                  statusLabel(order.summary.paymentMethod),
                ),
                if (order.paymentPaidAt != null)
                  detailRow('Thời gian', dateLabel(order.paymentPaidAt!)),
                const Divider(height: 26),
                CustomerRouteSummary(
                  pickup: order.summary.pickup,
                  dropoff: order.summary.dropoff,
                ),
                const Divider(height: 26),
                priceBreakdown(
                  order.distanceFee,
                  order.serviceFee,
                  order.discount,
                  order.summary.total,
                ),
              ],
            ),
          ),
          if (paid && order.summary.status == 'Pending')
            const CustomerNotice(
              'Đang tìm tài xế phù hợp. Bạn sẽ nhận thông báo khi có tài xế nhận đơn.',
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Theo dõi đơn hàng'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Về trang chủ'),
          ),
        ],
      ),
    );
  }
}
