import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

String incidentTypeLabel(String type) => switch (type) {
  'VehicleBreakdown' => 'Hỏng xe',
  'DamagedCargo' => 'Hư hỏng hàng',
  'Accident' => 'Tai nạn',
  'Other' => 'Khác',
  _ => type,
};
IconData incidentTypeIcon(String type) => switch (type) {
  'VehicleBreakdown' => Icons.car_repair_outlined,
  'DamagedCargo' => Icons.inventory_2_outlined,
  'Accident' => Icons.car_crash_outlined,
  _ => Icons.more_horiz,
};
String incidentStatusLabel(String status) => switch (status) {
  'Open' => 'Mới báo',
  'InProgress' => 'Đang xử lý',
  'Resolved' => 'Đã xử lý',
  'Cancelled' => 'Đã đóng',
  _ => status,
};
String incidentDecisionLabel(String? decision) => switch (decision) {
  'ContinueTrip' => 'Tiếp tục chuyến đi',
  'ReassignDriver' => 'Bàn giao cho tài xế khác',
  'CancelOrder' => 'Hủy đơn hàng',
  _ => decision ?? 'Chưa có quyết định',
};

class IncidentStatusBadge extends StatelessWidget {
  const IncidentStatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Resolved' => AppColors.green,
      'InProgress' => const Color(0xFF9B6205),
      'Open' => const Color(0xFF2563A5),
      _ => AppColors.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        incidentStatusLabel(status),
        style: appText(size: 11, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

class IncidentRefresh extends StatefulWidget {
  const IncidentRefresh({
    super.key,
    required this.refresh,
    required this.child,
  });
  final Future<void> Function() refresh;
  final Widget child;
  @override
  State<IncidentRefresh> createState() => _IncidentRefreshState();
}

class _IncidentRefreshState extends State<IncidentRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  void _refresh() {
    if (mounted &&
        _foreground &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      widget.refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class IncidentPhotos extends StatelessWidget {
  const IncidentPhotos(this.urls, {super.key});
  final List<String> urls;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (var i = 0; i < urls.length; i++)
        Semantics(
          label: 'Ảnh minh chứng ${i + 1}',
          button: true,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppHeader('Ảnh minh chứng ${i + 1}'),
                  body: Center(
                    child: InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Image.network(
                        urls[i],
                        errorBuilder: (_, _, _) =>
                            const Text('Chưa tải được ảnh. Vui lòng thử lại.'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                urls[i],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 100,
                  height: 100,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
