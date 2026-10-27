import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import '../../domain/entities/driver_application.dart';
import '../controllers/driver_controller.dart';
import '../models/document_display.dart';
import '../widgets/document_widgets.dart';
import '../widgets/profile_widgets.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({
    super.key,
    required this.onHome,
    required this.onUpdate,
  });
  final VoidCallback onHome;
  final ValueChanged<int> onUpdate;
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  bool? _vehicle;

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverController>();
    final vehicle = _vehicle ?? driver.status == ApprovalStatus.pending;
    return Scaffold(
      appBar: AppHeader('Hồ sơ tài xế', onBack: widget.onHome),
      bottomNavigationBar: AppBottomNav(
        driver: true,
        selected: 3,
        onSelect: (index) {
          if (index == 0) widget.onHome();
          if (index == 1 || index == 2) {
            showInfoSheet(
              context,
              index == 1 ? 'Đơn hàng' : 'Ví tài xế',
              index == 1
                  ? 'Các chuyến giao hàng sẽ hiển thị tại đây khi bạn bắt đầu nhận đơn.'
                  : 'Theo dõi thu nhập và số dư từ những chuyến giao hàng của bạn.',
            );
          }
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          ProfileIdentity(driver),
          const SizedBox(height: 14),
          ApprovalBanner(driver),
          const SizedBox(height: 10),
          DriverAvailability(driver),
          const SizedBox(height: 12),
          if (driver.status == ApprovalStatus.rejected)
            ..._corrections(driver)
          else if (driver.status == ApprovalStatus.draft) ...[
            const Notice(
              'Chuẩn bị CCCD, giấy phép lái xe, đăng ký xe và giấy đăng kiểm còn hiệu lực.',
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              'Hoàn thiện hồ sơ',
              onPressed: () => widget.onUpdate(0),
            ),
          ] else ...[
            ProfileTabs(
              vehicle: vehicle,
              onChanged: (value) => setState(() => _vehicle = value),
            ),
            const SizedBox(height: 12),
            if (vehicle)
              ..._vehicleDetails(driver)
            else
              ..._personalDetails(driver),
          ],
        ],
      ),
    );
  }

  List<Widget> _personalDetails(DriverController driver) => [
    AppCard(
      shadow: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Thông tin cá nhân', size: 15),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ProfileDetailRow('Họ tên', driver.fields['fullName']!),
          ProfileDetailRow('Số điện thoại', maskPhone(driver.fields['phone']!)),
          ProfileDetailRow(
            'Số CCCD',
            maskDocument(driver.fields['citizenId']!),
          ),
          ProfileDetailRow(
            'Số GPLX',
            maskDocument(driver.fields['license']!),
            divider: false,
          ),
        ],
      ),
    ),
    const SizedBox(height: 10),
    AppCard(
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      onTap: () => setState(() => _vehicle = true),
      child: Row(
        children: [
          const VehicleImage('truck-white', width: 105, height: 70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.fields['vehicleType']!,
                  style: appText(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(driver.fields['plate']!, style: appText(size: 12.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Xem phương tiện',
                      style: appText(size: 12, color: AppColors.orange),
                    ),
                    const SizedBox(width: 6),
                    const AppIcon(
                      'arrow-right',
                      size: 16,
                      color: AppColors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const AppIcon('chevron-right', size: 16),
        ],
      ),
    ),
    const SizedBox(height: 10),
    AppCard(
      shadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: () => _showPersonalDocuments(driver),
      child: Row(
        children: [
          if (driver.status == ApprovalStatus.approved)
            const CheckBadge(size: 26)
          else
            const AppIcon('clock', size: 26, color: AppColors.amber),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              driver.status == ApprovalStatus.approved
                  ? 'Giấy tờ đã xác minh'
                  : 'Giấy tờ đang xét duyệt',
              style: appText(size: 12.5),
            ),
          ),
          const AppIcon('chevron-right', size: 16),
        ],
      ),
    ),
  ];

  List<Widget> _vehicleDetails(DriverController driver) => [
    AppCard(
      shadow: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Thông tin phương tiện', size: 15),
          const SizedBox(height: 12),
          Row(
            children: [
              const VehicleImage('truck-white', width: 120, height: 60),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  driver.fields['vehicleType']!,
                  style: appText(size: 16, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ProfileDetailRow('Biển số', driver.fields['plate']!),
          ProfileDetailRow(
            'Tải trọng',
            '${_formatWeight(driver.fields['payload']!)} kg',
          ),
          ProfileDetailRow(
            'Thùng xe (D × R × C)',
            '${driver.fields['length']} × ${driver.fields['width']} × ${driver.fields['height']} m',
            divider: false,
          ),
        ],
      ),
    ),
    const SizedBox(height: 10),
    AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (final kind in [
            DocumentKind.registration,
            DocumentKind.inspection,
            DocumentKind.vehicle,
          ]) ...[
            InkWell(
              onTap: () =>
                  showDocumentPreview(context, kind, driver.documents[kind]!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    AppIcon(
                      kind == DocumentKind.vehicle ? 'image' : 'document',
                      size: 24,
                      color: kind == DocumentKind.registration
                          ? const Color(0xFF2463E8)
                          : kind == DocumentKind.inspection
                          ? AppColors.green
                          : const Color(0xFF9044DA),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(kind.label, style: appText(size: 12.5)),
                    ),
                    const AppIcon('eye', size: 18),
                  ],
                ),
              ),
            ),
            if (kind != DocumentKind.vehicle) const Divider(height: 1),
          ],
        ],
      ),
    ),
  ];

  List<Widget> _corrections(DriverController driver) => [
    const SectionTitle('Mục cần cập nhật', size: 15),
    const SizedBox(height: 8),
    for (final entry in driver.documents.entries.where(
      (entry) => entry.value.rejectionReason != null,
    )) ...[
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: entry.value.replaced
            ? AppColors.greenBg
            : const Color(0xFFFFF5F5),
        borderColor: entry.value.replaced ? AppColors.green : AppColors.red,
        radius: 6,
        onTap: () =>
            widget.onUpdate(entry.key == DocumentKind.inspection ? 1 : 0),
        child: Row(
          children: [
            AppIcon(
              entry.value.replaced ? 'check' : 'document',
              size: 28,
              color: entry.value.replaced ? AppColors.green : AppColors.red,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.label,
                    style: appText(size: 13, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.value.replaced
                        ? 'Đã thay ảnh, sẵn sàng gửi lại.'
                        : entry.value.rejectionReason!,
                    style: appText(
                      size: 11,
                      color: entry.value.replaced
                          ? AppColors.green
                          : AppColors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const AppIcon('chevron-right', size: 15),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ],
    const SizedBox(height: 8),
    const SectionTitle('Mục đã đạt', size: 15),
    const SizedBox(height: 8),
    AppCard(
      radius: 5,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final kind in [
            DocumentKind.citizenFront,
            DocumentKind.licenseFront,
            DocumentKind.registration,
            DocumentKind.vehicle,
          ]) ...[
            InkWell(
              onTap: () =>
                  showDocumentPreview(context, kind, driver.documents[kind]!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    const CheckBadge(size: 21),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        kind == DocumentKind.citizenFront ? 'CCCD' : kind.label,
                        style: appText(size: 12.5),
                      ),
                    ),
                    const AppIcon('lock', size: 16, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            if (kind != DocumentKind.vehicle) const Divider(height: 1),
          ],
        ],
      ),
    ),
    const SizedBox(height: 6),
    Text(
      'Các mục đã đạt được giữ nguyên.',
      style: appText(size: 11, color: AppColors.muted),
    ),
    const SizedBox(height: 9),
    PrimaryButton('Cập nhật giấy tờ', onPressed: () => widget.onUpdate(0)),
  ];

  Future<void> _showPersonalDocuments(DriverController driver) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SectionTitle('Giấy tờ cá nhân'),
              const SizedBox(height: 12),
              for (final kind in DocumentKind.values.take(4))
                ListTile(
                  leading: const AppIcon('document'),
                  title: Text(kind.label),
                  trailing: const AppIcon('eye', size: 20),
                  onTap: () => showDocumentPreview(
                    sheetContext,
                    kind,
                    driver.documents[kind]!,
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );

  String _formatWeight(String value) => value.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]}.',
  );
}
