import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/features/onboarding/domain/entities/driver_application.dart';
import 'package:modmove_mobile/features/onboarding/domain/rejection_mapper.dart';

void main() {
  test('lý do Admin gắn đúng giấy tờ bị từ chối, phần còn lại giữ nguyên chữ', () {
    final r = summarizeRejection([
      'Bằng lái – mặt trước: ảnh mờ',
      'CCCD – mặt sau: không hợp lệ, cần bổ sung',
      'Số CCCD: sai số',
      'Hồ sơ thiếu thông tin xe',
    ]);
    expect(r.documents, {
      DocumentKind.licenseFront: 'ảnh mờ',
      DocumentKind.citizenIdBack: 'không hợp lệ, cần bổ sung',
    });
    expect(r.others, ['Số CCCD: sai số', 'Hồ sơ thiếu thông tin xe']);
  });

  test('không có lý do thì không giấy tờ nào bị đánh dấu', () {
    expect(summarizeRejection(const []).documents, isEmpty);
  });
}
