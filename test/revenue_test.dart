import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:modmove_mobile/core/network/api_client.dart';
import 'package:modmove_mobile/features/earnings/data/remote_earnings_repository.dart';
import 'package:modmove_mobile/features/earnings/domain/driver_earnings_repository.dart';
import 'package:modmove_mobile/features/earnings/presentation/revenue_cubit.dart';
import 'support/remote_fixtures.dart';

void main() {
  test(
    'Vietnam reporting dates handle UTC boundary, Monday and leap month',
    () {
      final cubit = RevenueCubit(
        DeferredEarnings(),
        now: DateTime.utc(2026, 11, 9, 18),
      );
      addTearDown(cubit.close);
      expect(RevenueRange.dateParameter(cubit.state.range.start), '2026-11-10');
      final week = RevenueRange(RevenuePeriod.week, DateTime.utc(2026, 11, 1));
      expect(RevenueRange.dateParameter(week.start), '2026-10-26');
      expect(RevenueRange.dateParameter(week.end), '2026-11-01');
      final month = RevenueRange(
        RevenuePeriod.month,
        DateTime.utc(2024, 3, 31),
      ).move(-1);
      expect(RevenueRange.dateParameter(month.end), '2024-02-29');
    },
  );
  test('revenue fetches all pages for charts and uses server totals', () async {
    final queries = <Map<String, String>>[];
    final api = ApiClient(
      store: MemorySessionStore(),
      client: MockClient((r) async {
        expect(r.url.path, '/api/driver/wallet/earnings');
        queries.add(r.url.queryParameters);
        final previous = r.url.queryParameters['fromDate'] == '2026-11-09';
        final page = int.parse(r.url.queryParameters['page']!);
        return jsonResponse({
          'completedTrips': previous ? 0 : 2,
          'grossFares': 500000,
          'totalCommission': 70000,
          'netEarnings': previous ? 0 : 430000,
          'orders': pageFixture(
            previous
                ? []
                : [
                    {
                      'orderId': page,
                      'orderCode': 'MM$page',
                      'driverEarning': page == 1 ? 230000 : 200000,
                      'completedAt': '2026-11-10T02:00:00Z',
                    },
                  ],
            page: page,
            total: previous ? 0 : 2,
            more: !previous && page == 1,
          ),
        });
      }),
    );
    addTearDown(api.close);
    await api.saveSession(tokens());
    final report = await RemoteEarningsRepository(
      api,
    ).report(RevenueRange(RevenuePeriod.day, DateTime.utc(2026, 11, 10)));
    expect(report.orders.length, 2);
    expect(report.net, 430000);
    expect(report.commission, 70000);
    expect(queries.map((q) => q['page']).toList(), ['1', '2', '1']);
    expect(queries.first['toDate'], '2026-11-10');
  });
  test(
    'fast filter changes cannot overwrite a newer report with a stale response',
    () async {
      final repo = DeferredEarnings();
      final cubit = RevenueCubit(repo);
      addTearDown(cubit.close);
      final first = cubit.load(
        RevenueRange(RevenuePeriod.day, DateTime.utc(2026, 11, 10)),
      );
      final second = cubit.load(
        RevenueRange(RevenuePeriod.month, DateTime.utc(2026, 11, 10)),
      );
      repo.calls[1].complete(
        const EarningsReport(
          completed: 2,
          gross: 200,
          commission: 20,
          net: 180,
          orders: [],
          previousNet: 0,
        ),
      );
      await second;
      repo.calls[0].complete(
        const EarningsReport(
          completed: 1,
          gross: 100,
          commission: 10,
          net: 90,
          orders: [],
          previousNet: 0,
        ),
      );
      await first;
      expect(cubit.state.range.period, RevenuePeriod.month);
      expect(cubit.state.report!.net, 180);
    },
  );
}

class DeferredEarnings implements DriverEarningsRepository {
  final calls = <Completer<EarningsReport>>[];
  @override
  Future<EarningsReport> report(RevenueRange range) {
    final c = Completer<EarningsReport>();
    calls.add(c);
    return c.future;
  }
}
