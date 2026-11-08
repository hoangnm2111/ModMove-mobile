import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/driver_application.dart';
import '../controllers/driver_controller.dart';
import '../models/document_display.dart';
import '../widgets/document_widgets.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});
  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DriverController>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverController>();
    return Scaffold(
      appBar: AppHeader(
        'Lịch sử hồ sơ',
        actions: [
          IconButton(
            tooltip: 'Tải lại lịch sử',
            onPressed: driver.busy ? null : driver.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (driver.syncing) const LinearProgressIndicator(),
          if (driver.lastError != null)
            Notice(driver.lastError!, icon: 'warning', peach: true),
          if (driver.versions.isEmpty && !driver.syncing)
            const Notice('Chưa có lần gửi hồ sơ nào.', icon: 'document'),
          for (final application in driver.versions) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('Phiên bản ${application.version}', size: 17),
                  const SizedBox(height: 8),
                  Text(
                    switch (application.status) {
                      ApprovalStatus.draft => 'Bản nháp',
                      ApprovalStatus.pending => 'Chờ duyệt',
                      ApprovalStatus.approved => 'Đã duyệt',
                      ApprovalStatus.rejected => 'Cần bổ sung',
                    },
                    style: appText(
                      weight: FontWeight.w700,
                      color: application.status == ApprovalStatus.approved
                          ? AppColors.green
                          : AppColors.orange,
                    ),
                  ),
                  Text('Gửi: ${formatStamp(application.submittedAt)}'),
                  if (application.reviewedAt != null)
                    Text('Xét duyệt: ${formatStamp(application.reviewedAt)}'),
                  const Divider(height: 20),
                  for (final entry in application.documents.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(entry.key.label),
                      subtitle: entry.value.rejectionReason == null
                          ? null
                          : Text(entry.value.rejectionReason!),
                      trailing: const AppIcon('eye', size: 20),
                      onTap: () =>
                          showDocumentPreview(context, entry.key, entry.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
