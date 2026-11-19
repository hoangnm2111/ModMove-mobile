import 'package:http/http.dart' as http;

enum MapVinaTileIssue {
  noData,
  accessDenied,
  rateLimited,
  serviceUnavailable,
  connection;

  String get message => switch (this) {
    noData => 'Chưa có dữ liệu bản đồ cho khu vực đang xem.',
    accessDenied => 'Chưa xác thực được dịch vụ bản đồ. Vui lòng thử lại sau.',
    rateLimited =>
      'Dịch vụ bản đồ đang giới hạn lượt tải. Vui lòng thử lại sau.',
    serviceUnavailable => 'Dịch vụ bản đồ tạm gián đoạn. Vui lòng thử lại.',
    connection =>
      'Chưa tải được bản đồ. Kiểm tra kết nối Internet rồi thử lại.',
  };
}

/// Reports safe error categories, never keyed URLs or provider response bodies.
class MapVinaTileClient extends http.BaseClient {
  MapVinaTileClient(this.onStatus, {http.Client? client, this.onLoadingChanged})
    : _inner = client ?? http.Client();

  final void Function(MapVinaTileIssue?) onStatus;
  final void Function(bool)? onLoadingChanged;
  final http.Client _inner;
  bool _closed = false;
  int _pending = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _pending++;
    if (!_closed) onLoadingChanged?.call(true);
    var completed = false;
    void finish() {
      if (completed) return;
      completed = true;
      _pending--;
      if (!_closed) onLoadingChanged?.call(_pending > 0);
    }

    try {
      final response = await _inner
          .send(request)
          .timeout(const Duration(seconds: 20));
      return http.StreamedResponse(
        _readBody(response, finish),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on http.RequestAbortedException {
      // Panning and zooming intentionally cancel obsolete tiles.
      finish();
      rethrow;
    } catch (_) {
      finish();
      if (!_closed) onStatus(MapVinaTileIssue.connection);
      throw http.ClientException('Map tile unavailable');
    }
  }

  Stream<List<int>> _readBody(
    http.StreamedResponse response,
    void Function() finish,
  ) async* {
    try {
      // Receiving headers is not enough: keep the loading indication until
      // the complete image has arrived, and report failures while reading it.
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        yield chunk;
      }
      if (!_closed) {
        onStatus(switch (response.statusCode) {
          >= 200 && < 300 => null,
          404 => MapVinaTileIssue.noData,
          401 || 403 => MapVinaTileIssue.accessDenied,
          429 => MapVinaTileIssue.rateLimited,
          _ => MapVinaTileIssue.serviceUnavailable,
        });
      }
    } on http.RequestAbortedException {
      rethrow;
    } catch (_) {
      if (!_closed) onStatus(MapVinaTileIssue.connection);
      throw http.ClientException('Map tile unavailable');
    } finally {
      finish();
    }
  }

  @override
  void close() {
    _closed = true;
    _inner.close();
  }
}
