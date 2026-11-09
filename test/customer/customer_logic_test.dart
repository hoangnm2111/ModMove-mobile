import 'package:flutter_test/flutter_test.dart';
import 'package:modmove_mobile/core/format/formatters.dart';
import 'package:modmove_mobile/features/customer/domain/entities/customer_models.dart';
import 'package:modmove_mobile/features/customer/domain/order_rules.dart';

import 'fixtures.dart';

void main() {
  group('format', () {
    test('money dùng dấu chấm phân cách và hậu tố đ', () {
      expect(money(181400), '181.400đ');
      expect(money(0), '0đ');
      expect(money(1000000.4), '1.000.000đ');
      expect(money(-50000), '-50.000đ');
    });
    test('timeLeft', () {
      expect(timeLeft(const Duration(hours: 3, minutes: 12)), '3 giờ 12 phút');
      expect(timeLeft(const Duration(minutes: 8)), '8 phút');
      expect(timeLeft(const Duration(seconds: -1)), 'đã hết hạn');
    });
  });

  group('models', () {
    test('OrderDetail đọc đúng DTO backend', () {
      final o = OrderDetail.fromJson(orderDetailJson(deliveredAt: '2026-11-04T17:00:00Z'));
      expect(o.code, 'MMDEMO008');
      expect(o.driver?.fullName, 'Tài xế Demo');
      expect(o.driver?.licensePlate, '51C-123.45');
      expect(o.cargo.cargoTypeName, 'Đồ gia dụng');
      expect(o.proof?.deliveredAt, DateTime.utc(2026, 11, 4, 17).toLocal());
      expect(o.history.length, 2);
      expect(o.payment, isNull);
    });
    test('Paged.hasMore', () {
      final p = Paged.fromJson({'items': [orderSummaryJson()], 'pageNumber': 1, 'pageSize': 1, 'totalCount': 3}, OrderSummary.fromJson);
      expect(p.items.single.status, 'Delivered');
      expect(p.hasMore, isTrue);
    });
    test('FareEstimate giữ đúng thứ tự trường', () {
      final e = FareEstimate.fromJson({'distanceKm': 13.14, 'durationMinutes': 21, 'distanceFee': 181400, 'serviceFee': 100000, 'discountAmount': 0, 'totalFee': 281400});
      expect(e.distanceKm, 13.14);
      expect(e.durationMinutes, 21);
      expect(e.serviceFee, 100000);
      expect(e.totalFee, 281400);
    });
  });

  group('OrderRules', () {
    test('GB-31: PayOS chưa trả là "chờ thanh toán", tiền mặt thì không', () {
      expect(OrderRules.awaitingPayment('Pending', 'PayOS', 'Unpaid'), isTrue);
      expect(OrderRules.awaitingPayment('Pending', 'Cash', 'Unpaid'), isFalse);
      expect(OrderRules.awaitingPayment('Pending', 'PayOS', 'Paid'), isFalse);
      expect(OrderRules.awaitingPayment('Cancelled', 'PayOS', 'Unpaid'), isFalse);
    });
    test('GB-22: chỉ huỷ khi Pending/Accepted', () {
      expect(OrderRules.canCancel(OrderDetail.fromJson(orderDetailJson(status: 'Pending', driver: false))), isTrue);
      expect(OrderRules.canCancel(OrderDetail.fromJson(orderDetailJson(status: 'Accepted'))), isTrue);
      expect(OrderRules.canCancel(OrderDetail.fromJson(orderDetailJson(status: 'Arrived'))), isFalse);
    });
    test('GB-18: hạn khiếu nại = lúc giao + 24 giờ', () {
      final o = OrderDetail.fromJson(orderDetailJson(deliveredAt: '2026-11-04T17:00:00Z'));
      expect(OrderRules.complaintDeadline(o), DateTime.utc(2026, 11, 5, 17).toLocal());
    });
    test('GB-26: duyệt ảnh khi PickedUp + Pending', () {
      expect(OrderRules.pickupReviewPending(OrderDetail.fromJson(orderDetailJson(status: 'PickedUp', proofStatus: 'Pending'))), isTrue);
      expect(OrderRules.pickupReviewPending(OrderDetail.fromJson(orderDetailJson(status: 'PickedUp', proofStatus: 'Rejected'))), isFalse);
    });
    test('khiếu nại mở và rút yêu cầu', () {
      MyRefund r(String source, String status) => MyRefund(
        id: 1,
        orderId: 8,
        sourceType: source,
        status: status,
        requestedAmount: 1,
        approvedAmount: null,
        decisionReason: null,
        waitingForYourReply: false,
        createdAt: DateTime(2026),
      );
      expect(OrderRules.hasOpenComplaint([r('Complaint', 'Requested')]), isTrue);
      expect(OrderRules.hasOpenComplaint([r('Complaint', 'Processed'), r('Incident', 'Requested')]), isFalse);
      expect(OrderRules.canWithdrawRefund(r('Cancellation', 'Requested')), isFalse);
      expect(OrderRules.canWithdrawRefund(r('Complaint', 'Requested')), isTrue);
    });
  });

  group('GB-10 VehicleType.canCarry', () {
    const van = VehicleType(id: 1, name: 'Xe van', maxLoadWeightKg: 500, bedLengthCm: 170, bedWidthCm: 120, bedHeightCm: 120, baseFare: 50000, pricePerKm: 10000, minimumFare: 80000);
    test('vượt tải trọng thì không chở', () => expect(van.canCarry(600, 50, 50, 50), isFalse));
    test('món lớn nhất được xoay để lọt thùng', () {
      expect(van.canCarry(100, 120, 165, 60), isTrue);
      expect(van.canCarry(100, 180, 60, 50), isFalse);
    });
  });

  group('InputRules', () {
    test('số điện thoại và mật khẩu', () {
      expect(InputRules.phone('0911222333'), isTrue);
      expect(InputRules.phone('+84911222333'), isTrue);
      expect(InputRules.phone('123'), isFalse);
      expect(InputRules.password('1234567'), isFalse);
      expect(InputRules.password('ModMove@123'), isTrue);
    });
  });
}
