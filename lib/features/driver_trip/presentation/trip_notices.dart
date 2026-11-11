import '../../../core/notifications/app_notice.dart';
import '../../../core/notifications/notice_catalog.dart';
import '../domain/entities/trip_models.dart';

/// Chuyển thay đổi trạng thái chuyến (mô phỏng) thành thông báo. Hàm thuần: chỉ so sánh trường.
/// `type` y hệt mã server; khi chạy BE thật thì bỏ listener và để RealtimeBridge đẩy.
List<AppNotice> tripNotices(DriverSession? prev, DriverSession next) {
  if (prev == null) return const [];
  final out = <AppNotice>[];
  Map<String, String> data(DeliveryJob job) => {'orderId': job.id, 'orderCode': job.label};

  final offer = next.offer;
  if (offer != null && offer.job.id != prev.offer?.job.id) {
    out.add(noticeFor('NEW_MATCHING_ORDER', data: data(offer.job)));
  }

  final before = prev.trip, after = next.trip;
  if (before != null && after != null && before.job.id == after.job.id) {
    final d = data(after.job);
    if (before.review == EvidenceReview.pending && after.review == EvidenceReview.approved) {
      out.add(noticeFor('PICKUP_APPROVED', data: d));
    } else if (before.review == EvidenceReview.pending && after.review == EvidenceReview.rejected) {
      out.add(noticeFor('PICKUP_REJECTED', data: {...d, 'reason': _sentence(after.reason)}));
    }
    if (before.stage != TripStage.cancelled && after.stage == TripStage.cancelled) {
      out.add(noticeFor('ORDER_CANCELLED', data: d));
    }
    if (!before.cashCollected && after.cashCollected) {
      out.add(noticeFor('CASH_COLLECTED', data: d));
    }
  } else if (before != null && after == null && before.stage == TripStage.inTransit) {
    out.add(noticeFor('ORDER_COMPLETED', data: data(before.job)));
  }
  return out;
}

String _sentence(String? reason) {
  final text = (reason ?? '').trim();
  if (text.isEmpty) return '';
  return text.endsWith('.') ? text : '$text.';
}
