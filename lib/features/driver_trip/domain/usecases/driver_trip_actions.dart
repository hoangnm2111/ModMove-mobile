import '../entities/trip_models.dart';
import '../repositories/driver_trip_repository.dart';

class DriverTripActions {
  const DriverTripActions(this.repository);
  final DriverTripRepository repository;
  Future<void> setOnline(bool online) => repository.setOnline(online);
  Future<void> accept(String id) => repository.acceptOffer(id);
  Future<void> arrive() => repository.arrive();
  Future<void> submit({
    required List<UploadedEvidence> evidence,
    required List<bool> checklist,
    required String note,
    required bool cashCollected,
  }) {
    if (checklist.length != 4 || checklist.any((item) => !item)) {
      throw const TripFailure('Hoàn tất 4 mục kiểm tra trước khi xác nhận.');
    }
    if (evidence.map((item) => item.kind).toSet().length < 2) {
      throw const TripFailure(
        'Cần ảnh toàn bộ hàng và ảnh hàng đã cố định trên xe.',
      );
    }
    return repository.submitInspection(
      evidence: evidence,
      checklist: checklist,
      note: note.trim(),
      cashCollected: cashCollected,
    );
  }
}
