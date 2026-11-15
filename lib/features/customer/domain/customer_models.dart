class CustomerFailure implements Exception {
  const CustomerFailure(this.message, {this.code = ''});
  final String message, code;
  @override
  String toString() => message;
}

class PageResult<T> {
  const PageResult(this.items, this.page, this.total, this.hasNext);
  final List<T> items;
  final int page, total;
  final bool hasNext;
}

class Choice {
  const Choice(this.code, this.name, this.description);
  final String code, name, description;
}

class CustomerProfile {
  const CustomerProfile(this.name, this.phone, this.email, this.verified);
  final String name, phone, email;
  final bool verified;
}

class Vehicle {
  const Vehicle(
    this.id,
    this.name,
    this.weight,
    this.length,
    this.width,
    this.height,
  );
  final int id, length, width, height;
  final String name;
  final double weight;
  bool fits(BookingDraft d) {
    final cargo = [d.length, d.width, d.height]..sort();
    final bed = [length, width, height]..sort();
    return d.weight <= weight &&
        List.generate(3, (i) => cargo[i] <= bed[i]).every((v) => v);
  }
}

class BookingCatalog {
  const BookingCatalog(this.vehicles, this.cargoTypes, this.policies);
  final List<Vehicle> vehicles;
  final List<Choice> cargoTypes, policies;
}

class Coupon {
  const Coupon(this.code, this.discount, this.minimum, this.expires);
  final String code;
  final double discount, minimum;
  final DateTime expires;
}

class BookingDraft {
  const BookingDraft({
    this.pickup = '',
    this.dropoff = '',
    this.receiver = '',
    this.phone = '',
    this.cargoType = '',
    this.quantity = 1,
    this.weight = 0,
    this.length = 0,
    this.width = 0,
    this.height = 0,
    this.photos = const [],
    this.notes = '',
    this.vehicleId,
    this.loading = false,
    this.coupon = '',
    this.payment = 'PayOS',
    this.payer = 'Sender',
    this.committed = false,
  });
  final String pickup,
      dropoff,
      receiver,
      phone,
      cargoType,
      notes,
      coupon,
      payment,
      payer;
  final int quantity, length, width, height;
  final int? vehicleId;
  final double weight;
  final List<String> photos;
  final bool loading, committed;
  BookingDraft copyWith({
    String? pickup,
    String? dropoff,
    String? receiver,
    String? phone,
    String? cargoType,
    int? quantity,
    double? weight,
    int? length,
    int? width,
    int? height,
    List<String>? photos,
    String? notes,
    int? vehicleId,
    bool? loading,
    String? coupon,
    String? payment,
    String? payer,
    bool? committed,
  }) => BookingDraft(
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
    receiver: receiver ?? this.receiver,
    phone: phone ?? this.phone,
    cargoType: cargoType ?? this.cargoType,
    quantity: quantity ?? this.quantity,
    weight: weight ?? this.weight,
    length: length ?? this.length,
    width: width ?? this.width,
    height: height ?? this.height,
    photos: photos ?? this.photos,
    notes: notes ?? this.notes,
    vehicleId: vehicleId ?? this.vehicleId,
    loading: loading ?? this.loading,
    coupon: coupon ?? this.coupon,
    payment: payment ?? this.payment,
    payer: payer ?? this.payer,
    committed: committed ?? this.committed,
  );
  String? validate({bool submit = false}) {
    if (pickup.trim().isEmpty || dropoff.trim().isEmpty) {
      return 'Nhập đầy đủ địa chỉ lấy và giao hàng.';
    }
    if (receiver.trim().isEmpty ||
        !RegExp(r'^(0[0-9]{9}|\+84[0-9]{9})$').hasMatch(phone.trim())) {
      return 'Nhập tên và số điện thoại Việt Nam hợp lệ của người nhận.';
    }
    if (cargoType.isEmpty ||
        quantity <= 0 ||
        weight <= 0 ||
        weight > 100000 ||
        [length, width, height].any((n) => n < 1 || n > 2000)) {
      return 'Khai báo loại hàng, số lượng, cân nặng và kích thước hợp lệ.';
    }
    if (photos.isEmpty || photos.length > 5) {
      return 'Tải lên từ 1 đến 5 ảnh hàng hóa.';
    }
    if (vehicleId == null) return 'Chọn loại xe phù hợp.';
    if (submit && !committed) {
      return 'Vui lòng xác nhận cam kết hàng hóa và chính sách.';
    }
    return null;
  }
}

class Fare {
  const Fare(
    this.distance,
    this.minutes,
    this.distanceFee,
    this.serviceFee,
    this.discount,
    this.total,
  );
  final double distance, distanceFee, serviceFee, discount, total;
  final int minutes;
}

class CreatedOrder {
  const CreatedOrder(this.id, this.code, this.total);
  final int id;
  final String code;
  final double total;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.vehicle,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.created,
    required this.receiver,
    required this.phone,
  });
  final int id;
  final String code,
      status,
      pickup,
      dropoff,
      vehicle,
      paymentMethod,
      paymentStatus,
      receiver,
      phone;
  final double total;
  final DateTime created;
  bool get terminal => status == 'Completed' || status == 'Cancelled';
  bool get canCancel => status == 'Pending' || status == 'Accepted';
  bool get canReport => ['Arrived', 'PickedUp', 'InTransit'].contains(status);
  bool get needsPayment =>
      paymentMethod == 'PayOS' &&
      paymentStatus == 'Unpaid' &&
      status == 'Pending';
}

class OrderHistory {
  const OrderHistory(this.status, this.note, this.at);
  final String status, note;
  final DateTime at;
}

class OrderDetail {
  const OrderDetail({
    required this.summary,
    required this.cargoType,
    required this.quantity,
    required this.weight,
    required this.length,
    required this.width,
    required this.height,
    required this.photos,
    required this.notes,
    required this.loading,
    required this.distanceFee,
    required this.serviceFee,
    required this.discount,
    required this.driverName,
    required this.driverPhone,
    required this.plate,
    required this.pickupPhotos,
    required this.proofStatus,
    required this.deliveryPhoto,
    required this.deliveredAt,
    required this.history,
    required this.pendingDriverIncident,
    required this.checkoutUrl,
    required this.paymentExpired,
    required this.paymentExpires,
    this.paymentPaidAt,
    required this.payer,
  });
  final OrderSummary summary;
  final String cargoType,
      notes,
      driverName,
      driverPhone,
      plate,
      proofStatus,
      deliveryPhoto,
      checkoutUrl,
      payer;
  final List<String> photos, pickupPhotos;
  final int quantity, length, width, height;
  final double weight, distanceFee, serviceFee, discount;
  final bool loading, pendingDriverIncident, paymentExpired;
  final DateTime? deliveredAt, paymentExpires, paymentPaidAt;
  final List<OrderHistory> history;
  bool get canReview =>
      summary.status == 'PickedUp' &&
      proofStatus == 'Pending' &&
      !pendingDriverIncident;
  bool get canConfirm => summary.status == 'Delivered';
  bool withinDay(DateTime? start, DateTime now) =>
      start != null &&
      !now.isBefore(start) &&
      now.difference(start) < const Duration(hours: 24);
  bool canComplainAt(DateTime now) =>
      summary.status == 'Delivered' && withinDay(deliveredAt, now);
  bool canRateAt(DateTime now) {
    final completed = history.where((h) => h.status == 'Completed').toList();
    return summary.status == 'Completed' &&
        completed.isNotEmpty &&
        withinDay(completed.last.at, now);
  }

  DateTime? get matchingStarted {
    if (summary.status != 'Pending' || summary.needsPayment) return null;
    return summary.paymentMethod == 'Cash' ? summary.created : paymentPaidAt;
  }
}

class PaymentLink {
  const PaymentLink(this.url, this.qr, this.amount, this.expires);
  final String url, qr;
  final double amount;
  final DateTime expires;
}

class GeoPosition {
  const GeoPosition(this.latitude, this.longitude);
  final double latitude, longitude;
}

class TrackingSnapshot {
  const TrackingSnapshot(
    this.pickup,
    this.dropoff,
    this.driver,
    this.at,
    this.stale,
    this.minutes,
    this.target,
  );
  final GeoPosition pickup, dropoff;
  final GeoPosition? driver;
  final DateTime? at;
  final bool stale;
  final int? minutes;
  final String target;
  TrackingSnapshot withLocation(GeoPosition position, DateTime time) =>
      TrackingSnapshot(pickup, dropoff, position, time, false, null, target);
}

class Incident {
  const Incident(
    this.id,
    this.orderId,
    this.orderCode,
    this.type,
    this.description,
    this.photos,
    this.byYou,
    this.status,
    this.decision,
    this.note,
    this.created,
  );
  final int id, orderId;
  final String orderCode, type, description, status, decision, note;
  final List<String> photos;
  final bool byYou;
  final DateTime created;
}

class PayoutAccount {
  const PayoutAccount({
    this.suggested = false,
    this.bankCode = '',
    this.number = '',
    this.holder = '',
  });
  final bool suggested;
  final String bankCode, number, holder;
}

class Refund {
  const Refund({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.source,
    required this.status,
    required this.amount,
    required this.approved,
    required this.reason,
    required this.decision,
    required this.question,
    required this.reply,
    required this.waitingReply,
    required this.needsBank,
    required this.bank,
    required this.suggestedBank,
    required this.failure,
    required this.reference,
    required this.photos,
    required this.created,
  });
  final int id, orderId;
  final String orderCode,
      source,
      status,
      reason,
      decision,
      question,
      reply,
      bank,
      suggestedBank,
      failure,
      reference;
  final double amount;
  final double? approved;
  final bool waitingReply, needsBank;
  final List<String> photos;
  final DateTime created;
  bool get canWithdraw => source != 'Cancellation' && status == 'Requested';
  bool get canSetBank =>
      !['Processed', 'Rejected', 'Withdrawn'].contains(status);
}

class CustomerRating {
  const CustomerRating(
    this.orderId,
    this.code,
    this.stars,
    this.comment,
    this.driver,
    this.created,
  );
  final int orderId, stars;
  final String code, comment, driver;
  final DateTime created;
}
