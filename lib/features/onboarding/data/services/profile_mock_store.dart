import 'dart:convert';
import 'dart:io';

abstract interface class ProfileMockStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

class FileProfileMockStore implements ProfileMockStore {
  FileProfileMockStore(this.file);
  final File file;
  @override
  Future<Map<String, dynamic>?> read() async {
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }
}
