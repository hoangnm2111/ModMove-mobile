import '../../../core/network/api_client.dart';
import '../domain/driver_earnings_repository.dart';

class RemoteEarningsRepository implements DriverEarningsRepository {
  const RemoteEarningsRepository(this.api);
  final ApiClient api;
  Future<Map> _page(RevenueRange range, int page) async =>
      await api.request(
            'GET',
            '/api/driver/wallet/earnings?fromDate=${RevenueRange.dateParameter(range.start)}&toDate=${RevenueRange.dateParameter(range.end)}&page=$page&pageSize=50',
          )
          as Map;
  @override
  Future<EarningsReport> report(RevenueRange range) async {
    try {
      final first = await _page(range, 1);
      var data = first;
      var page = 1;
      final orders = <OrderEarning>[];
      // Charts use every page; a partial first page would under-report revenue.
      while (true) {
        final rows = data['orders'] as Map;
        for (final row in rows['items'] as List) {
          orders.add(
            OrderEarning(
              '${row['orderId']}',
              '${row['orderCode']}',
              (row['driverEarning'] as num).round(),
              DateTime.parse('${row['completedAt']}'),
            ),
          );
        }
        if (rows['hasNextPage'] != true) break;
        if ((rows['items'] as List).isEmpty) {
          throw const EarningsFailure(
            'Dữ liệu phân trang chưa đầy đủ. Vui lòng tải lại.',
          );
        }
        data = await _page(range, ++page);
      }
      final previous = await _page(range.move(-1), 1);
      return EarningsReport(
        completed: (first['completedTrips'] as num).toInt(),
        gross: (first['grossFares'] as num).round(),
        commission: (first['totalCommission'] as num).round(),
        net: (first['netEarnings'] as num).round(),
        orders: List.unmodifiable(orders),
        previousNet: (previous['netEarnings'] as num).round(),
      );
    } on ApiFailure catch (e) {
      throw EarningsFailure(e.message);
    }
  }
}
