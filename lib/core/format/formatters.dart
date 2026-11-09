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

String _two(int v) => v.toString().padLeft(2, '0');

String dateTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)} ${_two(d.day)}/${_two(d.month)}/${d.year}';
String date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

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
