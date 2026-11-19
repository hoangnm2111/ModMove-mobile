enum RevenuePeriod { day, week, month }

/// Calendar dates in Vietnam, independent of the device time zone.
class RevenueRange {
  RevenueRange(this.period, DateTime day)
    : anchor = DateTime.utc(day.year, day.month, day.day);
  final RevenuePeriod period;
  final DateTime anchor;
  DateTime get start => switch (period) {
    RevenuePeriod.day => anchor,
    RevenuePeriod.week => anchor.subtract(Duration(days: anchor.weekday - 1)),
    RevenuePeriod.month => DateTime.utc(anchor.year, anchor.month),
  };
  DateTime get end => switch (period) {
    RevenuePeriod.day => start,
    RevenuePeriod.week => start.add(const Duration(days: 6)),
    RevenuePeriod.month => DateTime.utc(anchor.year, anchor.month + 1, 0),
  };
  RevenueRange move(int direction) => RevenueRange(period, switch (period) {
    RevenuePeriod.day => anchor.add(Duration(days: direction)),
    RevenuePeriod.week => anchor.add(Duration(days: direction * 7)),
    RevenuePeriod.month => DateTime.utc(anchor.year, anchor.month + direction),
  });
  static String dateParameter(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class OrderEarning {
  const OrderEarning(this.id, this.code, this.net, this.completedAt);
  final String id, code;
  final int net;
  final DateTime completedAt;
}

class EarningsReport {
  const EarningsReport({
    required this.completed,
    required this.gross,
    required this.commission,
    required this.net,
    required this.orders,
    required this.previousNet,
  });
  final int completed, gross, commission, net, previousNet;
  final List<OrderEarning> orders;
}

class EarningsFailure implements Exception {
  const EarningsFailure(this.message);
  final String message;
}

abstract interface class DriverEarningsRepository {
  Future<EarningsReport> report(RevenueRange range);
}
