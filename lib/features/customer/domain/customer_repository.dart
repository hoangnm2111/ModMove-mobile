import 'dart:typed_data';
import 'customer_models.dart';

abstract interface class CustomerBookingRecovery {
  Future<CreatedOrder?> findBooking(String requestKey);
}

abstract interface class CustomerRepository {
  Future<BookingCatalog> catalog();
  Future<List<Choice>> choices(String kind);
  Future<PageResult<Coupon>> coupons(int page);
  Future<Fare> estimate(BookingDraft draft);
  Future<CreatedOrder> book(BookingDraft draft, Fare fare);
  Future<String> upload(String filename, Uint8List bytes);
  Future<CustomerProfile> profile();
  Future<void> updateProfile(String name, String phone);
  Future<void> changePassword(String current, String next);
  Future<void> deleteAccount();
  Future<PageResult<OrderSummary>> orders({
    int page = 1,
    String view = 'All',
    String search = '',
    CustomerOrderFilter filter = const CustomerOrderFilter(),
  });
  Future<OrderDetail> order(int id);
  Future<void> cancel(int id, String code, String reason);
  Future<PaymentLink> payment(int id);
  Future<void> reviewPickup(int id, bool approve, String reason);
  Future<void> confirmReceipt(int id);
  Future<TrackingSnapshot> tracking(int id);
  Future<PageResult<CustomerRating>> ratings(int page);
  Future<void> rate(int id, int stars, String comment);
  Future<PageResult<Incident>> incidents({int page = 1, int? orderId});
  Future<void> report(
    int orderId,
    String type,
    String description,
    List<String> photos,
    GeoPosition? gps,
  );
  Future<PageResult<Refund>> refunds(int page);
  Future<Refund> refund(int id);
  Future<int> complain(
    int orderId,
    String code,
    String reason,
    List<String> photos,
    double amount,
    PayoutAccount bank,
  );
  Future<int> requestRefund(
    int incidentId,
    String reason,
    List<String> photos,
    double amount,
    PayoutAccount bank,
  );
  Future<void> replyRefund(int id, String reply, List<String> photos);
  Future<void> withdrawRefund(int id);
  Future<void> setPayout(int id, PayoutAccount bank);
}

class CustomerRealtimeEvent {
  const CustomerRealtimeEvent({
    this.position,
    this.at,
    this.reconnected = false,
  });
  final GeoPosition? position;
  final DateTime? at;
  final bool reconnected;
}

abstract interface class CustomerRealtime {
  Stream<CustomerRealtimeEvent> get events;
  Future<void> start(int orderId);
  Future<void> stop();
}
