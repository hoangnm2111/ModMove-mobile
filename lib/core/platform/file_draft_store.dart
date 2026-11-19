import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../domain/draft_store.dart';

/// App-private, account AND API scoped drafts. Android backup is disabled.
/// Writes are serialized and replaced only after the temporary file is flushed.
class FileDraftStore implements DraftStore {
  FileDraftStore(String server, String account, {this.directory})
    : _scope = base64Url.encode(utf8.encode('$server|$account'));
  final String _scope;
  final Directory? directory;
  Future<void> _queue = Future.value();
  bool _cleaned = false;

  Future<File> _file(String key) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key');
    }
    final root = directory ?? await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/drafts_v1/$_scope');
    await folder.create(recursive: true);
    if (!_cleaned) {
      _cleaned = true;
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      await for (final entry in folder.list(followLinks: false)) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        if ((await entry.lastModified()).isAfter(cutoff)) continue;
        // Never expire an ambiguous booking and lose its idempotency key.
        if (entry.uri.pathSegments.last == 'booking.json') {
          try {
            final saved = jsonDecode(await entry.readAsString()) as Map;
            if ((saved['value'] as Map)['pending'] == true) continue;
          } catch (_) {
            continue;
          }
        }
        await entry.delete();
      }
    }
    return File('${folder.path}/$key.json');
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<Map<String, dynamic>?> read(String key) => _serial(() async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    try {
      final envelope = jsonDecode(await file.readAsString()) as Map;
      final saved = DateTime.parse(envelope['savedAt'] as String);
      final value = Map<String, dynamic>.from(envelope['value'] as Map);
      // An unresolved booking must keep its request key until reconciled.
      if (value['pending'] != true &&
          DateTime.now().difference(saved) > const Duration(days: 7)) {
        await file.delete();
        return null;
      }
      return value;
    } on FormatException {
      // Do not silently discard a possibly unresolved booking.
      throw const FileSystemException('Draft data could not be read.');
    }
  });

  @override
  Future<void> write(String key, Map<String, dynamic> value) =>
      _serial(() async {
        final file = await _file(key);
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(
          jsonEncode({
            'savedAt': DateTime.now().toUtc().toIso8601String(),
            'value': value,
          }),
          flush: true,
        );
        await temp.rename(file.path);
      });

  @override
  Future<void> remove(String key) => _serial(() async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  });
}
