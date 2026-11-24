import 'package:flutter_bloc/flutter_bloc.dart';

import 'platform_config.dart';

/// Tải số liệu thật từ BE (`GET /public/Config`) và cập nhật [AppRules]. Trạng thái null = chưa tải được:
/// giao diện không hiện số tiền thay vì hiện một số tự đoán.
class PlatformConfigCubit extends Cubit<PlatformConfig?> {
  PlatformConfigCubit(this._fetch) : super(AppRules.config);
  final Future<PlatformConfig> Function() _fetch;
  bool _loading = false;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final config = await _fetch();
      AppRules.apply(config);
      if (!isClosed) emit(config);
    } catch (_) {
      // Giữ số dự phòng cho các giới hạn; thử lại ở lần mở màn sau.
    } finally {
      _loading = false;
    }
  }

  /// Gọi khi một màn cần số liệu: tải nếu chưa có.
  Future<void> ensureLoaded() => state == null ? load() : Future.value();
}
