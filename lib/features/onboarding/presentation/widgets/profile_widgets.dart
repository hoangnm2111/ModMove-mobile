import 'package:flutter/material.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import '../../domain/entities/driver_application.dart';
import '../controllers/driver_controller.dart';
import '../models/document_display.dart';
import 'document_widgets.dart';

class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity(this.driver, {super.key});
  final DriverController driver;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFEF510C), AppColors.orange],
          ),
        ),
        child: Text(
          'MA',
          style: appText(
            size: 22,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(width: 15),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              driver.fields['fullName']!,
              style: appText(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Tài xế ModMove',
              style: appText(size: 13, color: AppColors.secondary),
            ),
            const SizedBox(height: 2),
            Text(maskPhone(driver.fields['phone']!), style: appText(size: 13)),
          ],
        ),
      ),
    ],
  );
}

class ApprovalBanner extends StatelessWidget {
  const ApprovalBanner(this.driver, {super.key});
  final DriverController driver;
  @override
  Widget build(BuildContext context) {
    final (title, icon, color, background) = switch (driver.status) {
      ApprovalStatus.approved => (
        'Hồ sơ đã duyệt',
        'check',
        AppColors.green,
        AppColors.greenBg,
      ),
      ApprovalStatus.pending => (
        'Hồ sơ đang chờ duyệt',
        'clock',
        AppColors.amber,
        AppColors.amberBg,
      ),
      ApprovalStatus.rejected => (
        'Hồ sơ cần bổ sung',
        'warning',
        AppColors.red,
        AppColors.redBg,
      ),
      ApprovalStatus.draft => (
        'Hoàn thiện hồ sơ tài xế',
        'document',
        AppColors.orange,
        AppColors.peach,
      ),
    };
    return AppCard(
      color: background,
      borderColor: color.withValues(alpha: .18),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        children: [
          if (driver.status == ApprovalStatus.approved)
            const CheckBadge(size: 38)
          else
            AppIcon(icon, size: 38, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: appText(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Color.lerp(color, Colors.black, .45)!,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  driver.status == ApprovalStatus.draft
                      ? 'Bổ sung giấy tờ để đăng ký nhận đơn.'
                      : driver.status == ApprovalStatus.approved
                      ? 'Duyệt lúc ${formatStamp(driver.reviewedAt)}'
                      : 'Gửi lúc ${formatStamp(driver.submittedAt)}',
                  style: appText(size: 12.5, color: AppColors.secondary),
                ),
                if (driver.status == ApprovalStatus.pending ||
                    driver.status == ApprovalStatus.rejected) ...[
                  const SizedBox(height: 3),
                  Text(
                    driver.status == ApprovalStatus.pending
                        ? 'Hồ sơ đang xét duyệt, chưa thể chỉnh sửa.'
                        : 'Xét duyệt lúc ${formatStamp(driver.reviewedAt)}',
                    style: appText(size: 11.5, color: AppColors.secondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriverAvailability extends StatelessWidget {
  const DriverAvailability(this.driver, {super.key});
  final DriverController driver;
  @override
  Widget build(BuildContext context) => AppCard(
    shadow: true,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sẵn sàng nhận đơn',
                style: appText(size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                !driver.accountActive
                    ? 'Tài khoản đang tạm ngưng.'
                    : driver.canGoOnline
                    ? (driver.online
                          ? 'Tài khoản đang hoạt động'
                          : 'Bạn đang ngoại tuyến')
                    : 'Có thể bật sau khi được duyệt.',
                style: appText(
                  size: 12,
                  color: driver.canGoOnline
                      ? AppColors.green
                      : AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (driver.changingAvailability) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        Semantics(
          label: 'Sẵn sàng nhận đơn',
          child: Switch(
            key: const ValueKey('driver-online'),
            value: driver.online,
            onChanged: driver.canGoOnline && !driver.busy
                ? driver.setOnline
                : null,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeTrackColor: AppColors.orange,
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD4D5D9),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.orange
                  : const Color(0xFFD4D5D9),
            ),
          ),
        ),
      ],
    ),
  );
}

class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.vehicle,
    required this.onChanged,
  });
  final bool vehicle;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F3),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        for (var index = 0; index < 2; index++)
          Expanded(
            child: Semantics(
              selected: vehicle == (index == 1),
              button: true,
              child: Material(
                color: vehicle == (index == 1)
                    ? AppColors.orange
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(index == 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Text(
                      index == 0 ? 'Cá nhân' : 'Phương tiện',
                      textAlign: TextAlign.center,
                      style: appText(
                        size: 13,
                        weight: vehicle == (index == 1)
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: vehicle == (index == 1)
                            ? Colors.white
                            : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow(
    this.label,
    this.value, {
    super.key,
    this.divider = true,
  });
  final String label, value;
  final bool divider;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: divider
          ? const Border(bottom: BorderSide(color: AppColors.line))
          : null,
    ),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        if (label.isNotEmpty) ...[
          Expanded(
            child: Text(
              label,
              style: appText(size: 12, color: AppColors.secondary),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Align(
            alignment: label.isEmpty ? Alignment.centerLeft : Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: appText(size: 12),
            ),
          ),
        ),
      ],
    ),
  );
}

String maskPhone(String phone) => phone.length < 5
    ? phone
    : '${phone.substring(0, 2)}•• ••• ${phone.substring(phone.length - 3)}';
String maskDocument(String value) => value.length < 4
    ? 'Chưa bổ sung'
    : '•••• •••• ${value.substring(value.length - 4)}';
