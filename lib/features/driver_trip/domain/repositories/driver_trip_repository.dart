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
  Future<String> reportIncident(String message);
}

abstract interface class CargoPhotoRepository {
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source);
}

abstract interface class DriverLocationRecovery {
  Future<void> recoverLocation();
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
  advanceRoute,
  uploadFailure,
  requestFailure,
  customerApproves,
  customerRejects,
  emptyJobs,
  lowDeposit,
}

abstract interface class TripSimulator {
  Future<void> simulate(TripSimulation action);
}
