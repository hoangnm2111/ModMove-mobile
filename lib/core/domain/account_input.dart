// Shared API input rules. Keep this file independent of Flutter and transport.
String normalizeVietnamesePhone(String value) {
  final phone = value.trim();
  return RegExp(r'^\+84[0-9]{9}$').hasMatch(phone)
      ? '0${phone.substring(3)}'
      : phone;
}

bool isVietnamesePhone(String value) =>
    RegExp(r'^0[0-9]{9}$').hasMatch(normalizeVietnamesePhone(value));

bool isValidNewPassword(String value) =>
    value.length >= 8 &&
    value.length <= 100 &&
    RegExp('[A-Za-z]').hasMatch(value) &&
    RegExp('[0-9]').hasMatch(value);
