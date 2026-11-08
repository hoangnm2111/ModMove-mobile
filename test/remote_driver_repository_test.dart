import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/onboarding/data/repositories/remote_driver_repository.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';
import 'support/remote_fixtures.dart';

void main() {
  test(
    'backend form submits numeric vehicle ID and exactly five ordered document URLs',
    () async {
      Map<String, dynamic>? submitted;
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          if (r.url.path == '/api/public/vehicletypes') {
            return jsonResponse([testVehicle]);
          }
          if (r.url.path == '/api/account/profile') {
            return jsonResponse({
              'fullName': 'Tài Xế Test',
              'phoneNumber': '0901234567',
            });
          }
          if (r.url.path == '/api/driver/status') {
            return jsonResponse(driverStatus());
          }
          if (r.url.path == '/api/driver/onboarding/status') {
            return jsonResponse({
              'hasApplication': submitted != null,
              if (submitted != null) ...{
                ...submitted!,
                'profileApprovalStatus': 'Pending',
                'latestVersionNumber': 1,
                'vehicleTypeName': testVehicle['name'],
                'submittedAt': '2026-11-08T00:00:00Z',
              },
            });
          }
          if (r.url.path == '/api/driver/onboarding') {
            submitted = jsonDecode(r.body) as Map<String, dynamic>;
            return jsonResponse({'id': 99}, 201);
          }
          throw StateError('Unexpected route ${r.url.path}');
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final repo = RemoteDriverRepository(api);
      await repo.initialize();
      final app = DriverApplication(
        status: ApprovalStatus.draft,
        fields: {
          ...repo.loadCachedApplication().fields,
          'vehicleType': 'Xe tải 1 tấn',
          'citizenId': '123456789',
          'license': 'ABC123456',
          'plate': '51C-123.45',
          'payload': '1000',
        },
        documents: {
          for (final kind in DocumentKind.values)
            kind: VerificationDocument(
              remoteReference: kind.index >= 2
                  ? 'https://images.test/${kind.name}.png'
                  : null,
            ),
        },
      );
      expect(RemoteDriverRepository.validation.personal(app.fields), isEmpty);
      expect(RemoteDriverRepository.validation.vehicle(app.fields), isEmpty);
      expect(RemoteDriverRepository.validation.missingDocuments(app), isEmpty);
      await repo.submit(app);
      expect(submitted!['vehicleTypeId'], 3);
      expect(submitted!['maxLoadWeightKg'], 1000);
      expect(
        submitted!['documentUrls'],
        [
          'licenseFront',
          'licenseBack',
          'registration',
          'inspection',
          'vehicle',
        ].map((e) => 'https://images.test/$e.png').toList(),
      );
      expect(repo.loadCachedApplication().status, ApprovalStatus.pending);
    },
  );
  test(
    'document upload uses driver multipart endpoint, never customer route',
    () async {
      final api = ApiClient(
        store: MemorySessionStore(),
        client: MockClient((r) async {
          expect(r.url.path, '/api/driver/uploads');
          expect(r.headers['content-type'], startsWith('multipart/form-data'));
          expect(r.body, contains('name="file"; filename="license.png"'));
          expect(r.body, contains('content-type: image/png'));
          return jsonResponse({'url': 'https://images.test/license.png'});
        }),
      );
      addTearDown(api.close);
      await api.saveSession(tokens());
      final photo = await RemoteDriverRepository(api).upload(
        DocumentKind.licenseFront,
        SelectedPhoto('license.png', Uint8List.fromList([1, 2, 3])),
      );
      expect(photo.remoteReference, 'https://images.test/license.png');
    },
  );
}
