import 'dart:convert';
import 'dart:io';

/// Phiên đăng nhập (POST /public/Auth/login → LoginResponse).
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.role,
  });
  final String accessToken, refreshToken, fullName, role;
  final int userId;

  bool get isCustomer => role == 'Customer';
  bool get isDriver => role == 'Driver';

  Session withTokens(String access, String refresh) => Session(
    accessToken: access,
    refreshToken: refresh,
    userId: userId,
    fullName: fullName,
    role: role,
  );

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    userId: (j['userId'] as num).toInt(),
    fullName: j['fullName'] as String? ?? '',
    role: j['role'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'userId': userId,
    'fullName': fullName,
    'role': role,
  };
}

/// Nơi giữ phiên hiện tại. [current] đọc đồng bộ; ghi thì lưu bền nếu có.
abstract class SessionStore {
  Session? get current;
  Future<void> save(Session? session);
}

/// Dùng cho test hoặc khi không lưu được file.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this._session]);
  Session? _session;
  @override
  Session? get current => _session;
  @override
  Future<void> save(Session? session) async => _session = session;
}

/// Lưu phiên vào thư mục riêng của app (Android: bộ nhớ trong, app khác không đọc được).
class FileSessionStore implements SessionStore {
  FileSessionStore._(this._file, this._session);
  final File _file;
  Session? _session;

  static Future<FileSessionStore> open(File file) async {
    Session? session;
    try {
      if (await file.exists()) {
        session = Session.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {
      session = null; // file hỏng → coi như chưa đăng nhập
    }
    return FileSessionStore._(file, session);
  }

  @override
  Session? get current => _session;

  @override
  Future<void> save(Session? session) async {
    _session = session;
    try {
      if (session == null) {
        if (await _file.exists()) await _file.delete();
      } else {
        await _file.parent.create(recursive: true);
        await _file.writeAsString(jsonEncode(session.toJson()));
      }
    } catch (_) {
      // Không lưu được thì vẫn giữ phiên trong bộ nhớ.
    }
  }
}
