DateTime vietnamTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 7));
String vietnamDate(DateTime value) {
  final d = vietnamTime(value);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String vietnamStamp(DateTime value) {
  final d = vietnamTime(value);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} · ${vietnamDate(value)}';
}
