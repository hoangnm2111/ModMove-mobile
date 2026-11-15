import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/notifications/notice_catalog.dart';
import 'package:modmove_mobile/core/notifications/notification_cubit.dart';

void main() {
  late DateTime clock;
  late NotificationCubit c;
  setUp(() {
    clock = DateTime(2026, 11, 11, 10);
    c = NotificationCubit(clock: () => clock);
  });
  tearDown(() => c.close());

  final a = noticeFor('ORDER_ACCEPTED', data: {'orderId': '1'}, at: DateTime(2026, 11, 11, 10, 0, 1));
  final b = noticeFor('ORDER_DELIVERED', data: {'orderId': '2'}, at: DateTime(2026, 11, 11, 10, 0, 2));

  test('thông báo đầu hiện ngay, thông báo sau xếp hàng', () {
    c.push(a);
    c.push(b);
    expect(c.state.showing, a);
    expect(c.state.queue, [b]);
  });

  test('dismissCurrent chuyển sang thông báo kế tiếp', () {
    c.push(a);
    c.push(b);
    c.dismissCurrent();
    expect(c.state.showing, b);
    expect(c.state.queue, isEmpty);
    c.dismissCurrent();
    expect(c.state.showing, isNull);
  });

  test('cùng type và orderId trong 10 giây chỉ đẩy một lần', () {
    c.push(noticeFor('ORDER_CANCELLED', data: {'orderId': '7'}));
    clock = clock.add(const Duration(seconds: 9));
    c.push(noticeFor('ORDER_CANCELLED', data: {'orderId': '7'}));
    expect(c.state.queue, isEmpty);
    clock = clock.add(const Duration(seconds: 2));
    c.push(noticeFor('ORDER_CANCELLED', data: {'orderId': '7'}));
    expect(c.state.queue, hasLength(1));
  });

  test('server dội nhiều lần: chỉ một banner, orderId khác vẫn xếp hàng', () {
    for (var i = 0; i < 5; i++) {
      c.push(noticeFor('ORDER_CANCELLED', data: {'orderId': '7'}));
    }
    c.push(noticeFor('ORDER_CANCELLED', data: {'orderId': '8'}));
    expect(c.state.showing?.orderId, 7);
    expect(c.state.queue, hasLength(1));
    expect(c.state.queue.single.orderId, 8);
  });

  test('chỉ thông báo cần lưu vào hộp thư, mới nhất trước, tối đa 50', () {
    for (var i = 1; i <= 51; i++) {
      clock = clock.add(const Duration(seconds: 20));
      c.push(noticeFor('ORDER_ACCEPTED', data: {'orderId': '$i'}, at: clock));
    }
    c.push(noticeFor('RATING_SUBMITTED'));
    expect(c.state.inbox, hasLength(50));
    expect(c.state.inbox.first.orderId, 51);
    expect(c.state.inbox.last.orderId, 2);
    expect(c.state.inbox.any((n) => n.type == 'RATING_SUBMITTED'), isFalse);
  });

  test('số chưa đọc giảm về 0 sau markAllRead', () {
    c.push(a);
    c.push(b);
    expect(c.state.unread, 2);
    c.markAllRead();
    expect(c.state.unread, 0);
    expect(c.state.inbox, hasLength(2));
  });

  test('clear xoá banner, hàng đợi và hộp thư; chống trùng cũng được đặt lại', () {
    c.push(a);
    c.push(b);
    c.clear();
    expect(c.state.showing, isNull);
    expect(c.state.queue, isEmpty);
    expect(c.state.inbox, isEmpty);
    c.push(a);
    expect(c.state.showing, a);
  });

  test('câu thao tác khác nhau trong 10 giây đều hiện, câu mới thay câu cũ', () {
    c.push(noticeFor('ACTION_ERROR', body: 'Chọn lý do khiếu nại.'));
    clock = clock.add(const Duration(seconds: 2));
    c.push(noticeFor('ACTION_ERROR', body: 'Số tiền yêu cầu chưa hợp lệ.'));
    expect(c.state.showing?.body, 'Số tiền yêu cầu chưa hợp lệ.');
    expect(c.state.queue, isEmpty);
  });

  test('đúng câu thao tác đang hiện thì không đẩy lại; đã đóng thì bấm lại vẫn hiện', () {
    c.push(noticeFor('ACTION_ERROR', body: 'Nhập mô tả sự cố.'));
    final first = c.state.showing;
    c.push(noticeFor('ACTION_ERROR', body: 'Nhập mô tả sự cố.'));
    expect(c.state.showing, same(first));
    c.dismissCurrent();
    clock = clock.add(const Duration(seconds: 3));
    c.push(noticeFor('ACTION_ERROR', body: 'Nhập mô tả sự cố.'));
    expect(c.state.showing?.body, 'Nhập mô tả sự cố.');
  });

  test('câu thao tác không chen ngang thông báo server đang hiện', () {
    c.push(a);
    c.push(b);
    c.push(noticeFor('ACTION_DONE', body: 'Đã lưu.'));
    expect(c.state.showing, a);
    expect(c.state.queue.map((n) => n.type), ['ACTION_DONE', 'ORDER_DELIVERED']);
  });

  test('pushed phát thông báo đã qua chống trùng', () async {
    final seen = <String>[];
    final sub = c.pushed.listen((n) => seen.add(n.type));
    c.push(a);
    c.push(a);
    c.push(b);
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['ORDER_ACCEPTED', 'ORDER_DELIVERED']);
    await sub.cancel();
  });
}
