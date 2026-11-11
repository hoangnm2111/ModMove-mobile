import '../entities/trip_models.dart';

abstract interface class DriverTripRepository {
  DriverSession get current;
  DateTime get now;
  Stream<DriverSession> get changes;
  Future<void> refresh();
  Future<void> setOnline(bool online);
  void updateAccess(DriverAccess access);
  void setForeground(bool foreground);
  Future<void> openOffer(String jobId);
  Future<void> declineOffer();
  Future<void> acceptOffer(String jobId);
  Future<void> arrive();
  Future<UploadedEvidence> upload(
    CargoPhoto photo,
    void Function(double) progress,
  );
  Future<void> submitInspection({
    required List<UploadedEvidence> evidence,
    required List<bool> checklist,
    required String note,
    required bool cashCollected,
  });
  /// Báo sự cố trên chuyến đang chạy; trả về mã sự cố. Sau khi gửi, sự cố mở do tài xế báo sẽ làm chuyến tạm dừng.
  Future<int> reportIncident(IncidentDraft draft);

  /// Đã hiện kết quả xử lý sự cố cho tài xế (tránh hiện lại).
  void acknowledgeOutcome();

  /// Giai đoạn giao hàng (đơn `InTransit`): báo đến điểm giao, thu COD, ảnh giao hàng (POD).
  Future<void> arriveDropoff();
  Future<void> collectCash();
  Future<void> deliver(CargoPhoto proof);
}

abstract interface class CargoPhotoRepository {
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source);
}

abstract interface class TripContactRepository {
  Future<bool> callCustomer(String phone);
  Future<bool> openNavigation(GeoPoint destination);
}

/// Development controls are injected separately; remote implementations need
/// not expose them. They never represent driver permissions on the real server.
enum TripSimulation {
  newOffer,
  acceptElsewhere,
  cancelOrder,
  gpsLost,
  gpsRestored,
  mapUnavailable,
  mapRestored,
  nearPickup,
  nearDropoff,
  dispatcherStarts,
  dispatcherContinues,
  dispatcherReassigns,
  dispatcherCancelsOrder,
  dispatcherDismisses,
  customerReportsIncident,
  advanceRoute,
  uploadFailure,
  requestFailure,
  customerApproves,
  customerRejects,
  emptyJobs,
  lowDeposit,
}

abstract interface class TripSimulator {
  /// Kịch bản mà repository này hỗ trợ (bản BE thật chỉ giả lập vị trí GPS).
  Set<TripSimulation> get supported;
  Future<void> simulate(TripSimulation action);
}
