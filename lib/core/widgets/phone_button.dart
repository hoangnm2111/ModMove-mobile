import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'app_widgets.dart';
import 'notice_banner.dart';

/// Mở ứng dụng gọi điện của máy với số đã cho (liên kết `tel:`).
Future<void> dialPhone(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (number.isEmpty) return;
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showNotice(context, 'Không mở được ứng dụng gọi điện. Số: $phone', error: true);
  }
}

/// Nút tròn biểu tượng điện thoại: bấm để gọi [phone].
class PhoneCallButton extends StatelessWidget {
  const PhoneCallButton(this.phone, {super.key, this.size = 34});
  final String phone;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Gọi $phone',
    child: Material(
      color: AppColors.greenBg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => dialPhone(context, phone),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: AppIcon('phone', size: size * .5, color: AppColors.green),
          ),
        ),
      ),
    ),
  );
}

/// Số điện thoại kèm nút gọi; trống thì hiện dấu gạch.
class PhoneText extends StatelessWidget {
  const PhoneText(this.phone, {super.key, this.style});
  final String? phone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final value = (phone ?? '').trim();
    if (value.isEmpty) return Text('—', style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(value, style: style)),
        const SizedBox(width: 8),
        PhoneCallButton(value, size: 30),
      ],
    );
  }
}
