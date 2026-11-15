/// Model khớp DTO api/driver/{Wallet,Trips,Ratings} (ModMove-backend/docs/api/README.md).
library;

num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;
int _i(Object? v) => _n(v).round();
String _s(Object? v) => v == null ? '' : '$v';
DateTime? _d(Object? v) =>
    v == null ? null : DateTime.tryParse('$v')?.toLocal();

class PageOf<T> {
  const PageOf(this.items, this.page, this.hasNext);
  final List<T> items;
  final int page;
  final bool hasNext;

  factory PageOf.fromJson(Object? json, T Function(Map<String, dynamic>) map) {
    final j = (json as Map).cast<String, dynamic>();
    return PageOf(
      [
        for (final e in (j['items'] as List? ?? const []))
          map((e as Map).cast<String, dynamic>()),
      ],
      _i(j['pageNumber']),
      j['hasNextPage'] == true,
    );
  }
}

class BankAccount {
  const BankAccount(this.bankName, this.number, this.holder);
  final String bankName, number, holder;

  static BankAccount? from(Object? json) {
    if (json is! Map) return null;
    final j = json.cast<String, dynamic>();
    final b = BankAccount(
      _s(j['bankName']),
      _s(j['bankAccountNumber']),
      _s(j['bankAccountHolder']),
    );
    return b.number.isEmpty ? null : b;
  }
}

class DriverWallet {
  const DriverWallet({
    required this.status,
    required this.deposit,
    required this.earnings,
    required this.total,
    required this.missingDeposit,
    required this.maxWithdrawable,
    required this.requiredDeposit,
    required this.canReceiveOrders,
    required this.hasActiveOrder,
    required this.pendingWithdrawal,
    required this.bank,
  });
  final String status;

  /// Ví tiền cọc, ví thu nhập và tổng (BE: GB-32: rút được cả hai ví khi không có đơn đang chạy).
  final int deposit,
      earnings,
      total,
      missingDeposit,
      maxWithdrawable,
      requiredDeposit,
      pendingWithdrawal;
  final bool canReceiveOrders, hasActiveOrder;
  final BankAccount? bank;

  factory DriverWallet.fromJson(Map<String, dynamic> j) => DriverWallet(
    status: _s(j['walletStatus']),
    deposit: _i(j['depositBalance']),
    earnings: _i(j['earningsBalance']),
    total: _i(j['walletTotal']),
    missingDeposit: _i(j['missingDepositAmount']),
    maxWithdrawable: _i(j['maxWithdrawableAmount']),
    requiredDeposit: _i(j['requiredDeposit']),
    canReceiveOrders: j['canReceiveOrders'] == true,
    hasActiveOrder: j['hasActiveOrder'] == true,
    pendingWithdrawal: j['hasPendingWithdrawal'] == true
        ? _i(j['pendingWithdrawalAmount'])
        : 0,
    bank: BankAccount.from(j['bankAccount']),
  );
}

class WalletTx {
  const WalletTx(
    this.type,
    this.amount,
    this.earningsAmount,
    this.depositAmount,
    this.balanceAfter,
    this.status,
    this.orderCode,
    this.createdAt,
  );
  final String type, status;
  final String? orderCode;
  final int amount, earningsAmount, depositAmount, balanceAfter;
  final DateTime? createdAt;

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
    _s(j['transactionType']),
    _i(j['amount']),
    _i(j['earningsAmount']),
    _i(j['depositAmount']),
    _i(j['balanceAfter']),
    _s(j['transactionStatus']),
    j['orderCode'] as String?,
    _d(j['createdAt']),
  );

  static const labels = {
    'TopUpDeposit': 'Nạp tiền cọc',
    'TripEarning': 'Thu nhập chuyến',
    'CommissionDeduction': 'Trừ hoa hồng đơn tiền mặt',
    'DepositRefill': 'Tự bù tiền cọc từ thu nhập',
    'Withdrawal': 'Rút tiền',
  };
  String get label => labels[type] ?? type;

  /// Khoản trừ ví (hoa hồng, rút tiền) hiển thị dấu trừ.
  bool get debit => type == 'CommissionDeduction' || type == 'Withdrawal';

  /// Chuyển nội bộ từ thu nhập sang tiền cọc: tổng ví không đổi nên không có dấu.
  bool get transfer => type == 'DepositRefill';
}

class Withdrawal {
  const Withdrawal(
    this.amount,
    this.earningsAmount,
    this.depositAmount,
    this.status,
    this.bank,
    this.reference,
    this.createdAt,
  );
  final int amount, earningsAmount, depositAmount;
  final String status;
  final BankAccount? bank;
  final String? reference;
  final DateTime? createdAt;

  factory Withdrawal.fromJson(Map<String, dynamic> j) => Withdrawal(
    _i(j['amount']),
    _i(j['earningsAmount']),
    _i(j['depositAmount']),
    _s(j['transactionStatus']),
    BankAccount.from(j),
    j['referenceCode'] as String?,
    _d(j['createdAt']),
  );
}

class EarningsSummary {
  const EarningsSummary(
    this.completedTrips,
    this.gross,
    this.commission,
    this.net,
  );
  final int completedTrips, gross, commission, net;

  factory EarningsSummary.fromJson(Map<String, dynamic> j) => EarningsSummary(
    _i(j['completedTrips']),
    _i(j['grossFares']),
    _i(j['totalCommission']),
    _i(j['netEarnings']),
  );
}

class DriverTripSummary {
  const DriverTripSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.totalFee,
    required this.commission,
    required this.earning,
    required this.cash,
    required this.customerName,
    required this.at,
  });
  final int id;
  final String code, status, pickup, dropoff, customerName;
  final int totalFee, commission, earning;
  final bool cash;
  final DateTime? at;

  factory DriverTripSummary.fromJson(Map<String, dynamic> j) =>
      DriverTripSummary(
        id: _i(j['id']),
        code: _s(j['orderCode']),
        status: _s(j['orderStatus']),
        pickup: _s(j['pickupAddress']),
        dropoff: _s(j['dropoffAddress']),
        totalFee: _i(j['totalFee']),
        commission: _i(j['commissionAmount']),
        earning: _i(j['driverEarning']),
        cash: j['paymentMethod'] == 'Cash',
        customerName: _s(j['customerName']),
        at: _d(j['completedAt']) ?? _d(j['deliveredAt']) ?? _d(j['createdAt']),
      );

  static const statusLabels = {
    'Pending': 'Chờ nhận',
    'Accepted': 'Đã nhận',
    'Arrived': 'Đã đến điểm lấy',
    'PickedUp': 'Đã lấy hàng',
    'InTransit': 'Đang giao',
    'Delivered': 'Đã giao',
    'Completed': 'Hoàn thành',
    'Cancelled': 'Đã hủy',
  };
  String get statusLabel => statusLabels[status] ?? status;
}

class Review {
  const Review(
    this.stars,
    this.comment,
    this.customer,
    this.orderCode,
    this.createdAt,
  );
  final int stars;
  final String? comment;
  final String customer, orderCode;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    _i(j['ratingStars']),
    j['reviewComment'] as String?,
    _s(j['customerName']),
    _s(j['orderCode']),
    _d(j['createdAt']),
  );
}

class RatingsSummary {
  const RatingsSummary(
    this.average,
    this.total,
    this.distribution,
    this.reviews,
  );
  final double? average;
  final int total;

  /// distribution[0] = số đánh giá 5 sao … distribution[4] = 1 sao.
  final List<int> distribution;
  final PageOf<Review> reviews;

  factory RatingsSummary.fromJson(Map<String, dynamic> j) => RatingsSummary(
    j['averageStars'] == null ? null : _n(j['averageStars']).toDouble(),
    _i(j['totalRatings']),
    [
      _i(j['fiveStarCount']),
      _i(j['fourStarCount']),
      _i(j['threeStarCount']),
      _i(j['twoStarCount']),
      _i(j['oneStarCount']),
    ],
    PageOf.fromJson(j['reviews'], Review.fromJson),
  );
}
