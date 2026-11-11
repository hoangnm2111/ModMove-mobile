import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/notifications/app_notice.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/driver_trip/presentation/trip_notices.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';
import 'package:modmove_mobile/features/onboarding/presentation/controllers/driver_controller.dart';
import 'package:modmove_mobile/features/onboarding/presentation/controllers/profile_notices.dart';

DeliveryJob job(String id) => DeliveryJob(id: id, pickup: 'A', dropoff: 'B', pickupPoint: const GeoPoint(10, 106), dropoffPoint: const GeoPoint(10.1, 106.1), createdAt: DateTime(2026, 11, 12), code: 'MM$id');
DriverSession session({JobOffer? offer, ActiveTrip? trip}) => DriverSession(offer: offer, trip: trip);
ActiveTrip trip({TripStage stage = TripStage.accepted, EvidenceReview review = EvidenceReview.none, String? reason, bool cash = false}) => ActiveTrip(job: job('J1'), stage: stage, review: review, reason: reason, cashCollected: cash);
List<String> types(List<AppNotice> n) => [for (final x in n) x.type];

DriverPresentationState profile(ApprovalStatus status, {String? reason}) => DriverPresentationState(
  application: DriverApplication(
    status: status,
    fields: const {},
    documents: {DocumentKind.licenseFront: VerificationDocument(rejectionReason: reason)},
  ),
);

void main() {
  test('đơn mới → NEW_MATCHING_ORDER', () => expect(types(tripNotices(session(), session(offer: JobOffer(job('J1'), DateTime(2026, 11, 12))))), ['NEW_MATCHING_ORDER']));
  test('duyệt ảnh → PICKUP_APPROVED', () => expect(types(tripNotices(session(trip: trip(review: EvidenceReview.pending)), session(trip: trip(review: EvidenceReview.approved)))), ['PICKUP_APPROVED']));
  test('từ chối ảnh → PICKUP_REJECTED kèm lý do', () {
    final n = tripNotices(session(trip: trip(review: EvidenceReview.pending)), session(trip: trip(review: EvidenceReview.rejected, reason: 'Ảnh mờ')));
    expect(types(n), ['PICKUP_REJECTED']);
    expect(n.single.body, contains('Ảnh mờ'));
  });
  test('huỷ đơn → ORDER_CANCELLED', () => expect(types(tripNotices(session(trip: trip()), session(trip: trip(stage: TripStage.cancelled)))), ['ORDER_CANCELLED']));
  test('thu tiền mặt → CASH_COLLECTED', () => expect(types(tripNotices(session(trip: trip()), session(trip: trip(cash: true)))), ['CASH_COLLECTED']));
  test('chuyến kết thúc sau khi giao → ORDER_COMPLETED', () => expect(types(tripNotices(session(trip: trip(stage: TripStage.inTransit)), session())), ['ORDER_COMPLETED']));
  test('không đổi → không có thông báo', () => expect(tripNotices(session(trip: trip()), session(trip: trip())), isEmpty));
  test('lần đầu (prev null) không báo', () {
    expect(tripNotices(null, session(trip: trip())), isEmpty);
    expect(profileNotices(null, profile(ApprovalStatus.approved)), isEmpty);
  });
  test('hồ sơ chờ → duyệt', () => expect(types(profileNotices(profile(ApprovalStatus.pending), profile(ApprovalStatus.approved))), ['DRIVER_APPLICATION_APPROVED']));
  test('hồ sơ chờ → từ chối kèm lý do', () {
    final n = profileNotices(profile(ApprovalStatus.pending), profile(ApprovalStatus.rejected, reason: 'GPLX hết hạn'));
    expect(types(n), ['DRIVER_APPLICATION_REJECTED']);
    expect(n.single.body, contains('GPLX hết hạn'));
  });
}
