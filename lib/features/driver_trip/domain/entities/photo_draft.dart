import 'dart:convert';
import 'trip_models.dart';

Map<String, dynamic> photoDraft(CargoPhoto photo, UploadedEvidence? uploaded) =>
    {
      'kind': photo.kind.name,
      'name': photo.name,
      'bytes': base64Encode(photo.bytes),
      'url': uploaded?.reference,
    };

CargoPhoto readPhotoDraft(Map<String, dynamic> value) => CargoPhoto(
  kind: CargoPhotoKind.values.byName(value['kind'] as String),
  name: value['name'] as String,
  bytes: base64Decode(value['bytes'] as String),
);

UploadedEvidence? readUploadDraft(Map<String, dynamic> value) {
  final url = value['url'] as String?;
  if (url == null || Uri.tryParse(url)?.scheme != 'https') return null;
  return UploadedEvidence(
    CargoPhotoKind.values.byName(value['kind'] as String),
    url,
  );
}
