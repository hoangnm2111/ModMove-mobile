import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/result_page.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/trip_history_repository.dart';

class TripHistoryState {
  const TripHistoryState({
    this.data,
    this.view = 'All',
    this.busy = false,
    this.error,
  });
  final ResultPage<TripSummary>? data;
  final String view;
  final bool busy;
  final String? error;
}

class TripHistoryCubit extends Cubit<TripHistoryState> {
  TripHistoryCubit(this.repository) : super(const TripHistoryState());
  final TripHistoryRepository repository;
  int _generation = 0;
  Future<void> load({String? view, bool more = false}) async {
    if (more && (state.busy || state.data?.hasNext != true)) return;
    final generation = ++_generation;
    final previous = state.data;
    final filter = view ?? state.view;
    emit(
      TripHistoryState(
        data: filter == state.view ? previous : null,
        view: filter,
        busy: true,
      ),
    );
    try {
      final data = await repository.history(
        page: more ? (previous?.page ?? 0) + 1 : 1,
        view: filter,
      );
      if (isClosed || generation != _generation) return;
      emit(
        TripHistoryState(
          view: filter,
          data: more
              ? ResultPage(
                  [...previous!.items, ...data.items],
                  data.page,
                  data.total,
                  data.hasNext,
                )
              : data,
        ),
      );
    } catch (e) {
      if (!isClosed && generation == _generation) {
        emit(
          TripHistoryState(
            data: state.data,
            view: filter,
            error: e is TripFailure ? e.message : 'Chưa tải được chuyến đi.',
          ),
        );
      }
    }
  }
}

class TripDetailState {
  const TripDetailState({this.trip, this.busy = false, this.error});
  final ActiveTrip? trip;
  final bool busy;
  final String? error;
}

class TripDetailCubit extends Cubit<TripDetailState> {
  TripDetailCubit(this.repository, this.id) : super(const TripDetailState());
  final TripHistoryRepository repository;
  final String id;
  Future<void> refresh() async {
    if (state.busy) return;
    emit(TripDetailState(trip: state.trip, busy: true));
    try {
      final trip = await repository.detail(id);
      if (!isClosed) emit(TripDetailState(trip: trip));
    } catch (e) {
      if (!isClosed) {
        emit(
          TripDetailState(
            trip: state.trip,
            error: e is TripFailure
                ? e.message
                : 'Chưa tải được chi tiết chuyến.',
          ),
        );
      }
    }
  }
}
