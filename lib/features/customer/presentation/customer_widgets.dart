import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/formatting/currency.dart';
export '../../../core/formatting/currency.dart';
export '../../../core/theme/app_theme.dart';
export '../../../core/widgets/app_widgets.dart' show AppIcon;
export '../../../core/widgets/customer_visuals.dart';

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
  Widget build(BuildContext context) {
    final good = [
      'InTransit',
      'Delivered',
      'Completed',
      'Paid',
      'Approved',
      'Resolved',
      'Processed',
      'Verified',
    ].contains(status);
    final bad = ['Cancelled', 'Rejected', 'Failed'].contains(status);
    final color = good
        ? AppColors.green
        : bad
        ? AppColors.red
        : AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: good
            ? AppColors.greenBg
            : bad
            ? AppColors.redBg
            : AppColors.amberBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            good
                ? 'check'
                : bad
                ? 'close'
                : 'clock',
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              statusLabel(status),
              style: appText(size: 11, weight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoStrip extends StatelessWidget {
  const PhotoStrip(this.urls, {super.key, this.remove, this.large = false});
  final bool large;
  final List<String> urls;
  final void Function(String)? remove;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: urls
        .map(
          (url) => SizedBox(
            width: large
                ? (MediaQuery.sizeOf(context).width - 80) /
                      (urls.length == 1 ? 1 : 2)
                : 96,
            height: large ? (urls.length == 1 ? 236 : 188) : 108,
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
                        errorBuilder: (_, _, _) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.muted,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Ảnh chưa tải được',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
  bool destructive = false,
  bool acknowledge = false,
}) async {
  var checked = false;
  return await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => StatefulBuilder(
          builder: (c, update) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: destructive ? AppColors.redBg : AppColors.peach,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: AppIcon(
                        destructive ? 'trash' : 'shield',
                        size: 34,
                        color: destructive ? AppColors.red : AppColors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: appText(size: 23, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: appText(color: AppColors.secondary),
                  ),
                  if (acknowledge) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: checked,
                      onChanged: (v) => update(() => checked = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Tôi hiểu và muốn xóa tài khoản'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(acknowledge ? 'Giữ tài khoản' : 'Quay lại'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: destructive
                        ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                        : null,
                    onPressed: acknowledge && !checked
                        ? null
                        : () => Navigator.pop(c, true),
                    child: Text(action),
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}

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
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tổng thanh toán',
              style: appText(weight: FontWeight.w700),
            ),
          ),
          Text(
            money(total),
            style: appText(
              size: 23,
              weight: FontWeight.w800,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    ),
  ],
);

class CustomerTimelineStep extends StatelessWidget {
  const CustomerTimelineStep({
    super.key,
    required this.title,
    required this.subtitle,
    this.done = false,
    this.current = false,
    this.last = false,
  });
  final String title, subtitle;
  final bool done, current, last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? AppColors.green : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done
                      ? AppColors.green
                      : current
                      ? AppColors.orange
                      : AppColors.line,
                  width: 2,
                ),
              ),
              child: done
                  ? const AppIcon('check', size: 16, color: Colors.white)
                  : current
                  ? const Icon(Icons.circle, size: 12, color: AppColors.orange)
                  : null,
            ),
            if (!last)
              Container(
                width: 2,
                height: 30,
                margin: const EdgeInsets.only(top: 5),
                color: done ? AppColors.green : AppColors.line,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: appText(
                  size: 16,
                  weight: FontWeight.w700,
                  color: current ? AppColors.orange : AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: appText(size: 13, color: AppColors.secondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
