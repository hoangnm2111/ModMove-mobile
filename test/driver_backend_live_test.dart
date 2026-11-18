// Kiểm tra trực tiếp với BE đang chạy (dữ liệu thật từ DB). Mặc định bị bỏ qua:
//   flutter test --dart-define=LIVE_API=http://localhost:5133/api test/driver_backend_live_test.dart
// Chỉ đọc + gửi GPS (như app thật); không tạo / nhận / huỷ đơn.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/core/session/session_store.dart';
import 'package:modmove_mobile/features/auth/data/auth_api.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_api.dart';
import 'package:modmove_mobile/features/driver_trip/data/driver_location_source.dart';
import 'package:modmove_mobile/features/driver_trip/data/repositories/api_driver_trip_repository.dart';
import 'package:modmove_mobile/features/driver_trip/domain/entities/trip_models.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/backend_driver_repository.dart';

const _live = String.fromEnvironment('LIVE_API');

class _Hcm implements DriverLocationSource {
  GpsSample get _sample => GpsSample(const GeoPoint(10.7769, 106.7009), at: DateTime.now());
  @override
  Future<GpsSample?> current() async => _sample;
  @override
  Stream<GpsSample> watch() => Stream.value(_sample);
}

Future<ApiClient> _login(String email) async {
  final sessions = MemorySessionStore();
  final api = ApiClient(sessions: sessions, baseUrl: _live);
  await sessions.save(await AuthApi(api).login(email, 'ModMove@123'));
  return api;
}

void main() {
  // flutter_test chặn mọi HTTP (trả 400); bỏ chặn để gọi BE thật.
  setUpAll(() => HttpOverrides.global = null);
  test('tài xế đã duyệt (driver2): hồ sơ + trạng thái + đơn lân cận từ DB', () async {
    final api = await _login('driver2@modmove.local');
    final profile = await BackendDriverRepository(api: DriverApi(api)).refresh();
    // ignore: avoid_print
    print('PROFILE ${profile.status} online=${profile.online} plate=${profile.fields['plate']} '
        'type=${profile.fields['vehicleType']} docs=${profile.documents.values.where((d) => d.hasImage).length}/5');
    expect(profile.documents.length, 5);

    final repo = ApiDriverTripRepository(api: DriverApi(api), location: _Hcm(), pollInterval: const Duration(hours: 1));
    addTearDown(repo.close);
    repo.onSessionChanged(isDriver: true);
    await repo.refresh();
    final s = repo.current;
    // ignore: avoid_print
    print('TRIP online=${s.online} deposit=${s.deposit} earnings=${s.earnings} jobs=${s.jobs.length} '
        'trip=${s.trip?.job.label} shift=${s.shift.completed}/${s.shift.income}');
    expect(s.deposit, greaterThan(0));
  }, skip: _live.isEmpty ? 'cần --dart-define=LIVE_API' : false);

  test('tài xế driver1 có chuyến đang chạy (đơn MMDEMO012) hiện đúng trạng thái', () async {
    final api = await _login('driver@modmove.local');
    final repo = ApiDriverTripRepository(api: DriverApi(api), location: _Hcm(), pollInterval: const Duration(hours: 1));
    addTearDown(repo.close);
    repo.onSessionChanged(isDriver: true);
    await repo.refresh();
    final trip = repo.current.trip;
    // ignore: avoid_print
    print('ACTIVE ${trip?.job.label} stage=${trip?.stage} ${trip?.job.pickup} -> ${trip?.job.dropoff} '
        'fare=${trip?.job.fare} net=${trip?.job.net} customer=${trip?.job.customerName}');
    expect(trip, isNotNull);
    expect(trip!.stage, TripStage.accepted);
  }, skip: _live.isEmpty ? 'cần --dart-define=LIVE_API' : false);
}
