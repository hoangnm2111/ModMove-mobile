import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/customer_models.dart';
import '../../domain/order_rules.dart';
import '../labels.dart';

/// Câu ngắn của thao tác: hiện banner trên đỉnh màn (xem core/widgets/notice_banner.dart).
void showSnack(BuildContext context, String text, {bool error = false}) =>
    showNotice(context, text, error: error);

String errorText(Object e) =>
    e is ApiException ? e.message : 'Đã có lỗi xảy ra. Vui lòng thử lại.';

/// Chạy thao tác, báo kết quả bằng banner; trả về true nếu thành công.
/// `notice` là mã trong danh mục thông báo ([noticeCatalog]); có thì hiện thông báo đó (kèm `data`, `noticeBody` thay chữ dự phòng),
/// không thì hiện câu `success`. Lỗi mạng hiện NETWORK_ERROR, lỗi khác hiện câu của BE.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
  String? notice,
  Map<String, String> data = const {},
  String? noticeBody,
}) async {
  try {
    await action();
    if (context.mounted) {
      if (notice != null) {
        notify(context, notice, data, noticeBody);
      } else if (success != null) {
        showSnack(context, success);
      }
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      if (e is ApiException && e.code == 'NETWORK') {
        notify(context, 'NETWORK_ERROR');
      } else {
        showSnack(context, errorText(e), error: true);
      }
    }
    return false;
  }
}

class Pill extends StatelessWidget {
  const Pill(this.tone, {super.key});
  final Tone tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: tone.bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      tone.label,
      style: appText(
        size: 11.5,
        weight: FontWeight.w700,
        color: tone.fg,
        spacing: -0.1,
      ),
    ),
  );
}

/// Trạng thái đơn, tự hiện "Chờ thanh toán" cho đơn PayOS chưa trả.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.status, {
    super.key,
    this.paymentMethod = '',
    this.paymentStatus = '',
  });
  final String status, paymentMethod, paymentStatus;
  @override
  Widget build(BuildContext context) => Pill(
    OrderRules.awaitingPayment(status, paymentMethod, paymentStatus)
        ? awaitingPaymentTone
        : toneOf(orderStatusTone, status),
  );
}

class KvRow extends StatelessWidget {
  const KvRow(
    this.label,
    this.value, {
    super.key,
    this.strong = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: appText(size: 13, color: AppColors.secondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: appText(
              size: strong ? 15 : 13,
              weight: strong ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Thẻ có tiêu đề.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionTitle(title, size: 15.5)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

/// Dải ảnh mạng; bấm để phóng to.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip(
    this.urls, {
    super.key,
    this.size = 72,
    this.emptyText = 'Chưa có ảnh',
  });
  final List<String> urls;
  final double size;
  final String emptyText;
  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Text(emptyText, style: appText(size: 12, color: AppColors.muted));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final u in urls)
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                insetPadding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  child: Image.network(u, fit: BoxFit.contain),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                u,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: size,
                  height: size,
                  color: AppColors.pale,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('box', size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: appText(color: AppColors.secondary),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon('warning', size: 36, color: AppColors.red),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: appText(color: AppColors.red),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

/// Chọn ảnh (camera/thư viện) rồi upload; giữ danh sách URL. GB-06: JPG/PNG ≤ 5 MB.
class PhotoPicker extends StatefulWidget {
  const PhotoPicker({
    super.key,
    required this.urls,
    required this.onChanged,
    required this.upload,
    int? max,
    this.label,
  }) : _max = max; // ignore: prefer_initializing_formals (tham số có tên không thể là biến riêng tư)
  final List<String> urls;
  final ValueChanged<List<String>> onChanged;
  final Future<String> Function(File file) upload;
  final int? _max;
  final String? label;

  /// Số ảnh tối đa: do nơi dùng chọn, không thì là giới hạn ảnh hàng hoá của BE.
  int get max => _max ?? OrderRules.maxCargoPhotos;

  @override
  State<PhotoPicker> createState() => _PhotoPickerState();
}

class _PhotoPickerState extends State<PhotoPicker> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 82,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final lower = picked.path.toLowerCase();
    if (!(lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png'))) {
      if (mounted) {
        showSnack(context, 'Chỉ nhận ảnh JPG hoặc PNG.', error: true);
      }
      return;
    }
    if (await file.length() > OrderRules.maxPhotoBytes) {
      if (mounted) showSnack(context, 'Ảnh tối đa ${OrderRules.maxPhotoMb} MB.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final url = await widget.upload(file);
      widget.onChanged([...widget.urls, url]);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon('camera'),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const AppIcon('image'),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.label != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '${widget.label} (${widget.urls.length}/${widget.max})',
            style: appText(size: 13, weight: FontWeight.w600),
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final u in widget.urls)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    u,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: InkWell(
                    onTap: () => widget.onChanged([...widget.urls]..remove(u)),
                    child: const CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.white,
                      child: AppIcon('close', size: 14, color: AppColors.red),
                    ),
                  ),
                ),
              ],
            ),
          if (widget.urls.length < widget.max)
            InkWell(
              onTap: _busy ? null : _choose,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line, width: 1.5),
                  color: AppColors.pale,
                ),
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppIcon('camera', color: AppColors.secondary),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'JPG/PNG, tối đa ${OrderRules.maxPhotoMb} MB mỗi ảnh.',
        style: appText(size: 11, color: AppColors.muted),
      ),
    ],
  );
}

/// Mức trên cùng của cây trạng thái đơn – thanh tiến trình.
class OrderProgress extends StatelessWidget {
  const OrderProgress(this.order, {super.key, this.dropoffArrivedAt});
  final OrderDetail order;

  /// Tài xế đã báo đến điểm giao (đơn đang giao): bước "Đang giao" hiện thành "Đã đến điểm giao".
  final DateTime? dropoffArrivedAt;
  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      final at = OrderRules.reachedAt(order, OrderStatus.cancelled);
      final note = order.history
          .where((h) => h.toStatus == OrderStatus.cancelled)
          .map((h) => h.note)
          .lastOrNull;
      return Notice(
        'Đơn đã huỷ${at == null ? '' : ' lúc ${_hm(at)}'}${note == null ? '' : ' – Lý do: $note'}',
        icon: 'warning',
        peach: true,
      );
    }
    final idx = OrderStatus.flow.indexOf(order.status);
    final awaiting = OrderRules.awaitingPayment(
      order.status,
      order.paymentMethod,
      order.paymentStatus,
    );
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < OrderStatus.flow.length; i++)
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: i <= idx
                        ? AppColors.orange
                        : AppColors.line,
                    child: i < idx
                        ? const AppIcon('check', size: 13, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: appText(
                              size: 10,
                              weight: FontWeight.w700,
                              color: i == idx ? Colors.white : AppColors.muted,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i == 0 && awaiting
                        ? 'Chờ thanh toán'
                        : OrderStatus.flow[i] == OrderStatus.inTransit &&
                              dropoffArrivedAt != null
                        ? 'Đã đến điểm giao'
                        : toneOf(orderStatusTone, OrderStatus.flow[i]).label,
                    textAlign: TextAlign.center,
                    style: appText(
                      size: 9,
                      weight: i <= idx ? FontWeight.w700 : FontWeight.w400,
                      color: i <= idx ? AppColors.ink : AppColors.muted,
                      height: 1.15,
                      spacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.day}/${d.month}';
}
