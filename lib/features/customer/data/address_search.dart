import 'dart:convert';

import 'package:http/http.dart' as http;

/// Gợi ý địa chỉ khi gõ (Photon/OpenStreetMap, miễn phí, không cần key) – giống web.
/// Backend chưa có endpoint gợi ý; giá và quãng đường vẫn do backend tính bằng MapVina
/// từ chuỗi địa chỉ, nên nhãn không gồm `locality` (đã đo: làm MapVina khớp lệch).
class AddressSearch {
  AddressSearch({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const _bbox = '102.1,8.2,109.5,23.4'; // lãnh thổ Việt Nam

  Future<List<String>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {'q': q, 'limit': '6', 'bbox': _bbox, 'lang': 'default'});
    final res = await _http.get(uri, headers: {'User-Agent': 'ModMove-mobile'}).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const [];
    final features = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['features'] as List? ?? const [];
    final seen = <String>{};
    final out = <String>[];
    for (final f in features) {
      final label = labelOf((f as Map<String, dynamic>)['properties'] as Map<String, dynamic>);
      if (label.isNotEmpty && seen.add(label)) out.add(label);
    }
    return out;
  }

  static String labelOf(Map<String, dynamic> p) {
    String? s(String k) => p[k] as String?;
    final street = s('housenumber') != null && s('street') != null ? '${s('housenumber')} ${s('street')}' : s('street');
    final parts = <String?>[s('name') != s('street') ? s('name') : null, street, s('district'), s('city') ?? s('county'), s('state')];
    final out = <String>[];
    for (final x in parts) {
      if (x != null && x.isNotEmpty && !out.contains(x)) out.add(x);
    }
    return out.join(', ');
  }
}
