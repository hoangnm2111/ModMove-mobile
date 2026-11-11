import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/notifications/app_notice.dart';
import 'package:modmove_mobile/core/notifications/notice_catalog.dart';

void main() {
  test('chữ của server được ưu tiên hơn chữ dự phòng', () {
    final n = noticeFor('ORDER_ACCEPTED', title: 'Đơn đã có tài xế', body: 'Tài xế đã nhận đơn MM01.', data: {'orderId': '7'});
    expect(n.kind, NoticeKind.info);
    expect(n.body, 'Tài xế đã nhận đơn MM01.');
    expect(n.target, NoticeTarget.order);
    expect(n.orderId, 7);
    expect(n.persist, isTrue);
  });

  test('chữ dự phòng điền {orderCode}', () {
    final n = noticeFor('PICKUP_PHOTOS_TO_REVIEW', data: {'orderId': '7', 'orderCode': 'MM01'});
    expect(n.kind, NoticeKind.warning);
    expect(n.body, 'Ảnh kiểm hàng của đơn MM01 đã sẵn sàng. Vui lòng duyệt trước khi xe khởi hành.');
    expect(n.duration, const Duration(seconds: 6));
  });

  test('mã lạ giữ chữ của server, mức info, không có đích', () {
    final n = noticeFor('SOMETHING_NEW', title: 'T', body: 'B');
    expect((n.kind, n.target, n.title, n.body, n.orderId), (NoticeKind.info, NoticeTarget.none, 'T', 'B', null));
    expect(n.persist, isFalse);
  });

  test('thông báo thao tác trong app không lưu vào hộp thư', () {
    expect(noticeFor('RATING_SUBMITTED').persist, isFalse);
    expect(noticeFor('ACTION_ERROR', body: 'x').duration, const Duration(seconds: 7));
    expect(noticeFor('ACTION_DONE', body: 'Đã lưu.').body, 'Đã lưu.');
    expect(noticeFor('ACTION_DONE').body, 'Đã xong.');
  });

  test('khoá thiếu thì bỏ trống và gọn khoảng trắng; orderId lạ bị bỏ qua', () {
    final n = noticeFor('ORDER_ACCEPTED');
    expect(n.body, 'Tài xế đã nhận đơn và đang đến điểm lấy hàng.');
    for (final bad in ['../1', '0', '-3', 'abc', '']) {
      expect(noticeFor('ORDER_ACCEPTED', data: {'orderId': bad}).orderId, isNull, reason: bad);
    }
  });

  test('thời gian banner theo mức độ', () {
    expect(noticeFor('ORDER_COMPLETED').duration, const Duration(seconds: 4));
    expect(noticeFor('NEW_MATCHING_ORDER').duration, const Duration(seconds: 4));
    expect(noticeFor('ORDER_CANCELLED').duration, const Duration(seconds: 7));
  });

  test('mọi mã trong danh mục đều có chữ dự phòng', () {
    for (final t in noticeCatalog.keys) {
      expect(noticeFor(t).body, isNotEmpty, reason: t);
    }
  });

  test('sự kiện đơn hàng, thanh toán, hoàn tiền, hồ sơ được lưu; kết quả thao tác nhỏ thì không', () {
    for (final t in ['ORDER_ACCEPTED', 'PAYMENT_CONFIRMED', 'REFUND_DECIDED', 'DRIVER_APPLICATION_APPROVED', 'INCIDENT_RESOLVED']) {
      expect(persistedTypes, contains(t));
    }
    for (final t in ['ACTION_DONE', 'ACTION_ERROR', 'RATING_SUBMITTED', 'LOGGED_OUT']) {
      expect(persistedTypes, isNot(contains(t)));
    }
  });
}
