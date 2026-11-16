/// Định dạng tiền và thời gian kiểu Việt Nam (không phụ thuộc package intl).
String money(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$bufđ';
}

/// Quãng đường trong ô Ước tính cước phí: làm tròn LÊN (không bao giờ thấp hơn thực tế), không hiện số lẻ.
String kmCeil(num value) => '${value.ceil()} km';

/// Tiền trong ô Ước tính cước phí: làm tròn LÊN bội số 1.000đ cho "chẵn" (chỉ hiển thị ước tính;
/// số tiền thật khi đặt đơn/thanh toán vẫn lấy nguyên giá trị BE trả về, không dùng hàm này).
String moneyCeil1000(num value) => money((value / 1000).ceil() * 1000);

String _two(int v) => v.toString().padLeft(2, '0');

/// Giờ Việt Nam (UTC+7) của một thời điểm, không phụ thuộc múi giờ của máy (DECISIONS 9.5: lưu UTC, hiển thị giờ VN).
DateTime vietnamTime(DateTime d) => d.toUtc().add(const Duration(hours: 7));

String dateTime(DateTime d) {
  final v = vietnamTime(d);
  return '${_two(v.hour)}:${_two(v.minute)} ${_two(v.day)}/${_two(v.month)}/${v.year}';
}

String timeOfDay(DateTime d) {
  final v = vietnamTime(d);
  return '${_two(v.hour)}:${_two(v.minute)}';
}

String date(DateTime d) {
  final v = vietnamTime(d);
  return '${_two(v.day)}/${_two(v.month)}/${v.year}';
}

String timeAgo(DateTime d, [DateTime? now]) {
  final s = (now ?? DateTime.now()).difference(d).inSeconds;
  if (s < 60) return 'vừa xong';
  if (s < 3600) return '${s ~/ 60} phút trước';
  if (s < 86400) return '${s ~/ 3600} giờ trước';
  return '${s ~/ 86400} ngày trước';
}

/// Thời gian còn lại dạng "3 giờ 12 phút" / "8 phút" / "đã hết hạn".
String timeLeft(Duration d) {
  if (d.isNegative || d.inSeconds == 0) return 'đã hết hạn';
  final h = d.inHours, m = d.inMinutes % 60;
  return h > 0 ? '$h giờ $m phút' : '${d.inMinutes < 1 ? 1 : m} phút';
}

/// Đếm ngược mm:ss.
String countdown(Duration d) {
  if (d.isNegative) return '00:00';
  return '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';
}
