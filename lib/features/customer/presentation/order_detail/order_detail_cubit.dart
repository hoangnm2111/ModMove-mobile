import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/customer_api.dart';
import '../../domain/entities/customer_models.dart';

class OrderDetailState {
  const OrderDetailState({this.order, this.incidents = const [], this.refunds = const [], this.rating, this.tracking, this.trackingError, this.loading = true, this.error});
  final OrderDetail? order;
  final List<MyIncident> incidents;
  final List<MyRefund> refunds;
  final MyRating? rating;
  final OrderTracking? tracking;
  final String? trackingError, error;
  final bool loading;
}

/// Chi tiết đơn: GET /customer/Orders/{id} + sự cố + hoàn tiền + đánh giá + tracking.
class OrderDetailCubit extends Cubit<OrderDetailState> {
  OrderDetailCubit(this.api, this.orderId) : super(const OrderDetailState());
  final CustomerApi api;
  final int orderId;

  Future<void> load({bool withTracking = true}) async {
    try {
      final order = await api.order(orderId);
      final extras = await Future.wait<Object?>([
        api.incidents(orderId: orderId).catchError((_) => <MyIncident>[]),
        api.refunds().catchError((_) => <MyRefund>[]),
        api.ratings(pageSize: 50).then<Object?>((r) => r.items).catchError((_) => <MyRating>[]),
      ]);
      final summaries = (extras[1] as List<MyRefund>).where((r) => r.orderId == orderId).toList();
      // Chi tiết từng khoản hoàn (câu hỏi của Dispatcher, ảnh, câu trả lời)
      final refunds = await Future.wait(summaries.map((r) => api.refund(r.id).catchError((_) => r)));
      final rating = (extras[2] as List<MyRating>).where((r) => r.orderId == orderId).firstOrNull;
      if (isClosed) return;
      emit(
        OrderDetailState(
          order: order,
          incidents: (extras[0] as List<MyIncident>).where((i) => i.orderId == orderId).toList(),
          refunds: refunds,
          rating: rating,
          tracking: state.tracking,
          loading: false,
        ),
      );
      if (withTracking) await loadTracking();
    } catch (e) {
      if (!isClosed) {
        emit(
          OrderDetailState(
            order: state.order,
            incidents: state.incidents,
            refunds: state.refunds,
            rating: state.rating,
            tracking: state.tracking,
            loading: false,
            error: e is ApiException ? e.message : '$e',
          ),
        );
      }
    }
  }

  /// BE: mỗi lần gọi tốn 1 lượt MapVina, giới hạn 10 lần/phút → chỉ gọi khi mở/làm mới.
  Future<void> loadTracking() async {
    final o = state.order;
    if (o == null || !OrderStatus.trackable.contains(o.status)) return;
    try {
      final t = await api.tracking(orderId);
      if (!isClosed) _emitWith(tracking: t);
    } catch (e) {
      if (!isClosed) _emitWith(trackingError: e is ApiException ? e.message : '$e');
    }
  }

  void _emitWith({OrderTracking? tracking, String? trackingError}) => emit(
    OrderDetailState(order: state.order, incidents: state.incidents, refunds: state.refunds, rating: state.rating, tracking: tracking ?? state.tracking, trackingError: trackingError, loading: false),
  );
}
