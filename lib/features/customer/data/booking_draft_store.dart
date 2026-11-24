import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Bản nháp đặt xe đã lưu trong máy (giống web): quá [ttl] thì bỏ, đăng xuất thì xoá.
class SavedBookingDraft {
  const SavedBookingDraft(this.json, this.step, this.savedAt);
  final Map<String, dynamic> json;
  final int step;
  final DateTime savedAt;
}

abstract class BookingDraftStore {
  static const ttl = Duration(hours: 24);

  /// Nháp còn hạn, hoặc null.
  Future<SavedBookingDraft?> load();
  Future<void> save(Map<String, dynamic> draft, int step);
  Future<void> clear();
}

/// Dùng cho test hoặc khi không có thư mục riêng của app.
class MemoryBookingDraftStore implements BookingDraftStore {
  MemoryBookingDraftStore({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  SavedBookingDraft? _saved;

  @override
  Future<SavedBookingDraft?> load() async {
    final s = _saved;
    if (s == null || _now().difference(s.savedAt) > BookingDraftStore.ttl) {
      _saved = null;
      return null;
    }
    return s;
  }

  @override
  Future<void> save(Map<String, dynamic> draft, int step) async => _saved = SavedBookingDraft(draft, step, _now());

  @override
  Future<void> clear() async => _saved = null;
}

/// Lưu nháp vào thư mục riêng của app. Lỗi đọc/ghi thì coi như không có nháp, không chặn việc đặt xe.
class FileBookingDraftStore implements BookingDraftStore {
  FileBookingDraftStore({File? file}) : _fixed = file;
  final File? _fixed;

  Future<File> _file() async =>
      _fixed ?? File('${(await getApplicationSupportDirectory()).path}/booking-draft-v1.json');

  @override
  Future<SavedBookingDraft?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final savedAt = DateTime.parse(j['savedAt'] as String);
      if (DateTime.now().difference(savedAt) > BookingDraftStore.ttl) {
        await f.delete();
        return null;
      }
      return SavedBookingDraft(j['draft'] as Map<String, dynamic>, (j['step'] as num?)?.toInt() ?? 0, savedAt);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> draft, int step) async {
    try {
      final f = await _file();
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode({'draft': draft, 'step': step, 'savedAt': DateTime.now().toUtc().toIso8601String()}),
      );
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
