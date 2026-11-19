import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/formatting/vietnam_time.dart';
import '../domain/driver_earnings_repository.dart';

class RevenueState {
  const RevenueState(
    this.range, {
    this.report,
    this.busy = false,
    this.error,
    this.visibleOrders = 20,
  });
  final RevenueRange range;
  final EarningsReport? report;
  final bool busy;
  final String? error;
  final int visibleOrders;
}

class RevenueCubit extends Cubit<RevenueState> {
  RevenueCubit(this.repository, {DateTime? now})
    : super(
        RevenueState(
          RevenueRange(RevenuePeriod.day, vietnamTime(now ?? DateTime.now())),
        ),
      );
  final DriverEarningsRepository repository;
  int _generation = 0;
  Future<void> load([RevenueRange? range]) async {
    final next = range ?? state.range;
    final generation = ++_generation;
    emit(RevenueState(next, busy: true));
    try {
      final report = await repository.report(next);
      if (!isClosed && generation == _generation) {
        emit(RevenueState(next, report: report));
      }
    } catch (e) {
      if (!isClosed && generation == _generation) {
        emit(
          RevenueState(
            next,
            error: e is EarningsFailure
                ? e.message
                : 'Chưa tải được doanh thu. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  void more() => emit(
    RevenueState(
      state.range,
      report: state.report,
      visibleOrders: state.visibleOrders + 20,
    ),
  );
}
