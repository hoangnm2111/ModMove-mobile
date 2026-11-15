import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/formatting/currency.dart';
export '../../../core/formatting/currency.dart';
export '../../../core/theme/app_theme.dart';

String money(num value) => formatVnd(value.round());

String statusLabel(String status) =>
    const {
      'Pending': 'Đang tìm tài xế',
      'AwaitingPayment': 'Chờ thanh toán',
      'Accepted': 'Tài xế đang đến',
      'Arrived': 'Đã đến điểm lấy',
      'PickedUp': 'Chờ duyệt ảnh lấy hàng',
      'InTransit': 'Đang giao hàng',
      'Delivered': 'Chờ xác nhận nhận hàng',
      'Completed': 'Hoàn thành',
      'Cancelled': 'Đã hủy',
      'Unpaid': 'Chưa thanh toán',
      'Paid': 'Đã thanh toán',
      'Refunded': 'Đã hoàn tiền',
      'Open': 'Đã tiếp nhận',
      'InProgress': 'Đang xử lý',
      'Resolved': 'Đã giải quyết',
      'Requested': 'Đang xét duyệt',
      'Approved': 'Đã phê duyệt',
      'Rejected': 'Đã từ chối',
      'Withdrawn': 'Đã rút yêu cầu',
      'Failed': 'Chuyển tiền thất bại',
      'Processing': 'Đang chuyển tiền',
      'Processed': 'Đã hoàn tiền',
      'Verified': 'Đã duyệt ảnh',
      'Complaint': 'Khiếu nại',
      'Incident': 'Sự cố',
      'Cancellation': 'Hủy đơn',
      'VehicleBreakdown': 'Hỏng xe',
      'DamagedCargo': 'Hư hỏng hàng',
      'Accident': 'Tai nạn',
      'Other': 'Khác',
      'Cash': 'Tiền mặt',
      'PayOS': 'PayOS / VietQR',
    }[status] ??
    status;

String dateLabel(DateTime date) {
  final d = date.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)} · ${two(d.day)}/${two(d.month)}/${d.year}';
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 18,
  });
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class CustomerNotice extends StatelessWidget {
  const CustomerNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => CustomerCard(
    color: error ? AppColors.redBg : AppColors.peach,
    padding: 14,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.info_outline,
          size: 20,
          color: error ? AppColors.red : AppColors.orange,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: appText(size: 13))),
      ],
    ),
  );
}

Widget sectionTitle(String title) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 12),
  child: Text(title, style: appText(size: 18, weight: FontWeight.w700)),
);
Widget detailRow(String label, String value, {bool strong = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: appText(color: AppColors.secondary)),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: appText(weight: strong ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    ],
  ),
);

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: ['Completed', 'Paid', 'Approved'].contains(status)
          ? AppColors.greenBg
          : AppColors.peach,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      statusLabel(status),
      style: appText(
        size: 12,
        weight: FontWeight.w600,
        color: AppColors.orange,
      ),
    ),
  );
}

class PhotoStrip extends StatelessWidget {
  const PhotoStrip(this.urls, {super.key, this.remove});
  final List<String> urls;
  final void Function(String)? remove;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: urls
        .map(
          (url) => SizedBox(
            width: 96,
            height: 108,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Ảnh minh chứng')),
                          body: InteractiveViewer(
                            maxScale: 5,
                            child: Center(
                              child: Image.network(
                                url,
                                errorBuilder: (_, _, _) =>
                                    const Text('Không tải được ảnh.'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.pale,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                if (remove != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      tooltip: 'Xóa ảnh',
                      onPressed: () => remove!(url),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

Future<XFile?> pickCustomerPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  return ImagePicker().pickImage(
    source: source,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 88,
  );
}

Future<void> openExternal(BuildContext context, Uri uri) async {
  try {
    if (!['https', 'tel'].contains(uri.scheme)) throw StateError('unsupported');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('not launched');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được ứng dụng liên kết.')),
      );
    }
  }
}

Future<bool> confirmCustomerAction(
  BuildContext context,
  String title,
  String message, {
  String action = 'Xác nhận',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
Widget priceBreakdown(
  double distance,
  double service,
  double discount,
  double total,
) => Column(
  children: [
    detailRow('Cước vận chuyển', money(distance)),
    detailRow('Bốc xếp', money(service)),
    detailRow('Giảm giá', '−${money(discount)}'),
    const Divider(),
    detailRow('Tổng thanh toán', money(total), strong: true),
  ],
);
