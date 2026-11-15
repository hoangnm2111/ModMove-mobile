import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_notice.dart';

class NotificationState {
  const NotificationState({this.showing, this.queue = const [], this.inbox = const []});

  /// Banner đang hiện (null khi không có).
  final AppNotice? showing;

  /// Banner chờ tới lượt: hiện lần lượt, không đè lên nhau.
  final List<AppNotice> queue;

  /// Hộp thông báo, mới nhất trước, tối đa 50 mục, chỉ trong phiên.
  final List<AppNotice> inbox;
  int get unread => inbox.where((n) => !n.read).length;
}

/// Hàng đợi banner + hộp thông báo + chống trùng. Mọi nguồn (SignalR, kết quả thao tác, luồng tài xế) đều đẩy vào đây.
class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit({DateTime Function()? clock}) : _clock = clock ?? DateTime.now, super(const NotificationState());

  static const inboxLimit = 50;
  static const dedupeWindow = Duration(seconds: 10);

  final DateTime Function() _clock;
  final _recent = <String, DateTime>{};
  final _pushed = StreamController<AppNotice>.broadcast();

  /// Phát mọi thông báo đã qua chống trùng: màn khác nghe để tải lại dữ liệu.
  Stream<AppNotice> get pushed => _pushed.stream;

  /// Cùng `type` và `orderId` trong 10 giây chỉ đẩy một lần (server dội lại, khách vừa tự thao tác xong...).
  ///
  /// Câu ngắn của thao tác (không lưu hộp thư: lỗi nhập liệu, "đã lưu"...) thì khác: mỗi lần bấm phải có phản hồi,
  /// nên không chống trùng theo thời gian. Câu mới thay ngay câu thao tác đang hiện (như SnackBar), chỉ bỏ qua
  /// khi đúng câu đó đang hiện.
  void push(AppNotice notice) {
    if (isClosed) return;
    if (!notice.persist) {
      _pushTransient(notice);
      return;
    }
    final key = '${notice.type}|${notice.orderId ?? ''}';
    final now = _clock();
    _recent.removeWhere((_, at) => now.difference(at) > dedupeWindow);
    final last = _recent[key];
    if (last != null && now.difference(last) <= dedupeWindow) return;
    _recent[key] = now;

    final inbox = notice.persist ? [notice, ...state.inbox].take(inboxLimit).toList() : state.inbox;
    if (state.showing == null) {
      emit(NotificationState(showing: notice, queue: state.queue, inbox: inbox));
    } else {
      emit(NotificationState(showing: state.showing, queue: [...state.queue, notice], inbox: inbox));
    }
    if (!_pushed.isClosed) _pushed.add(notice);
  }

  void _pushTransient(AppNotice notice) {
    bool same(AppNotice n) => !n.persist && n.type == notice.type && n.title == notice.title && n.body == notice.body;
    final showing = state.showing;
    if (showing != null && same(showing)) return;
    final queue = state.queue.where((n) => n.persist).toList();
    if (showing == null || !showing.persist) {
      emit(NotificationState(showing: notice, queue: queue, inbox: state.inbox));
    } else {
      // Đang hiện thông báo từ server: câu thao tác chờ ngay sau nó, trước các thông báo server khác.
      emit(NotificationState(showing: showing, queue: [notice, ...queue], inbox: state.inbox));
    }
    if (!_pushed.isClosed) _pushed.add(notice);
  }

  void dismissCurrent() {
    if (isClosed || state.showing == null) return;
    final queue = state.queue;
    emit(NotificationState(showing: queue.firstOrNull, queue: queue.isEmpty ? const [] : queue.sublist(1), inbox: state.inbox));
  }

  void markAllRead() {
    if (isClosed || state.unread == 0) return;
    emit(NotificationState(showing: state.showing, queue: state.queue, inbox: [for (final n in state.inbox) n.copyWith(read: true)]));
  }

  /// Đăng xuất: xoá banner, hàng đợi, hộp thư và bộ nhớ chống trùng.
  void clear() {
    _recent.clear();
    if (!isClosed) emit(const NotificationState());
  }

  @override
  Future<void> close() async {
    await _pushed.close();
    return super.close();
  }
}
