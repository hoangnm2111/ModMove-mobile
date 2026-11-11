import '../../../../core/notifications/app_notice.dart';
import '../../../../core/notifications/notice_catalog.dart';
import '../../domain/entities/driver_application.dart';
import 'driver_controller.dart';

/// Hồ sơ tài xế được duyệt/từ chối (mô phỏng) → thông báo. Lần đầu (prev == null) không báo.
/// Lý do từ chối lấy từ giấy tờ đầu tiên bị từ chối.
List<AppNotice> profileNotices(DriverPresentationState? prev, DriverPresentationState next) {
  final before = prev?.application?.status, application = next.application;
  if (prev == null || application == null || before == application.status) return const [];
  if (before != ApprovalStatus.pending) return const [];
  switch (application.status) {
    case ApprovalStatus.approved:
      return [noticeFor('DRIVER_APPLICATION_APPROVED')];
    case ApprovalStatus.rejected:
      final reason = application.documents.values.map((d) => d.rejectionReason).whereType<String>().where((r) => r.trim().isNotEmpty).firstOrNull ?? '';
      return [noticeFor('DRIVER_APPLICATION_REJECTED', data: {'reason': reason.endsWith('.') || reason.isEmpty ? reason : '$reason.'})];
    case ApprovalStatus.draft || ApprovalStatus.pending:
      return const [];
  }
}
