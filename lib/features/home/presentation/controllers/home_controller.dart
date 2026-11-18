import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../customer/data/customer_api.dart';
import '../../../customer/domain/entities/customer_models.dart';

/// Bảng giá công khai lấy từ BE (GET /public/VehicleTypes), nên Admin đổi giá là app thấy.
/// `null` = đang tải; rỗng = chưa tải được (màn hình có nút thử lại).
class HomeController extends Cubit<List<VehicleType>?> {
  HomeController(this._api) : super(null) {
    unawaited(load());
  }
  final CustomerApi _api;

  Future<void> load() async {
    if (state != null) emit(null);
    try {
      final types = await _api.vehicleTypes();
      if (!isClosed) emit(List.unmodifiable(types));
    } catch (_) {
      if (!isClosed) emit(const []);
    }
  }
}
