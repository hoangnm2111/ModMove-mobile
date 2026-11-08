import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:modmove_mobile/core/theme/app_theme.dart';
import 'package:modmove_mobile/core/widgets/app_widgets.dart';
import '../../domain/entities/driver_application.dart';
import '../controllers/driver_controller.dart';
import '../models/document_display.dart';
import '../widgets/document_widgets.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    this.initialStep = 0,
    this.onSubmitted,
    this.onDemo,
  });
  final int initialStep;
  final VoidCallback? onSubmitted;
  final VoidCallback? onDemo;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late int step = widget.initialStep;
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  String? error;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => error = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choose(DocumentKind kind) async {
    final driver = context.read<DriverController>();
    if (driver.busy) return;
    if (!driver.canEditDocument(kind)) {
      await showDocumentPreview(context, kind, driver.documents[kind]!);
      return;
    }
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SectionTitle(kind.label),
            ),
            ListTile(
              leading: const AppIcon('camera'),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const AppIcon('image'),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
            if (driver.demoEnabled)
              ListTile(
                key: const ValueKey('choose-sample-photo'),
                leading: const AppIcon('document'),
                title: const Text('Dùng ảnh mẫu mô phỏng'),
                subtitle: const Text(
                  'Thử luồng tải ảnh, không cần giấy tờ thật',
                ),
                onTap: () => Navigator.pop(context, PhotoSource.sample),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Text('JPG hoặc PNG · Tối đa 5 MB/ảnh'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final message = await driver.pickDocument(kind, source);
    if (!mounted) return;
    if (message != null) {
      _showError(message);
    } else {
      setState(() => error = null);
    }
  }

  Future<void> _continue() async {
    final driver = context.read<DriverController>();
    if (driver.busy) return;
    if (!_form.currentState!.validate()) return;
    final missing = driver.missingDocuments(personalOnly: step == 0);
    if (missing.isNotEmpty) {
      _showError(
        'Vui lòng bổ sung: ${missing.map((kind) => kind.label).join(', ')}.',
      );
      return;
    }
    if (step == 0) {
      if (driver.hasApi) {
        final message = await driver.saveDraft();
        if (!mounted) return;
        if (message != null) {
          _showError(message);
          return;
        }
      }
      setState(() {
        step = 1;
        error = null;
      });
      _scroll.jumpTo(0);
      return;
    }
    final message = await driver.submit();
    if (!mounted) return;
    if (message != null) {
      _showError(message);
      return;
    }
    if (widget.onSubmitted != null) {
      widget.onSubmitted!();
    } else {
      await showInfoSheet(
        context,
        'Đã gửi hồ sơ',
        'Hồ sơ của bạn đang chờ xét duyệt. Bạn có thể theo dõi trạng thái trong hồ sơ tài xế.',
      );
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  Future<bool> _save() async {
    final driver = context.read<DriverController>();
    if (!driver.hasApi || !driver.canEdit) return true;
    final message = await driver.saveDraft();
    if (!mounted) return false;
    if (message != null) {
      _showError(message);
      return false;
    }
    setState(() => error = null);
    return true;
  }

  Future<void> _back() async {
    if (context.read<DriverController>().busy) return;
    if (step == 1) {
      setState(() => step = 0);
      _scroll.jumpTo(0);
    } else if (await _save() && mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _openDemo() async {
    if (await _save() && mounted) widget.onDemo?.call();
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverController>();
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppHeader(
          'Xác minh tài xế',
          onBack: _back,
          onHelp: () => showInfoSheet(
            context,
            'Chuẩn bị hồ sơ',
            'Dùng ảnh JPG hoặc PNG dưới 5 MB, rõ thông tin và đủ 4 góc. Giấy tờ cần còn hiệu lực. Các mục đã đạt được giữ nguyên khi bổ sung hồ sơ.',
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  step == 0 ? 'Tiếp tục' : 'Gửi hồ sơ xét duyệt',
                  busy: driver.submitting || driver.syncing,
                  onPressed: driver.canEdit && !driver.busy ? _continue : null,
                ),
                if (driver.hasApi)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        key: const ValueKey('save-driver-draft'),
                        onPressed: driver.canEdit && !driver.busy
                            ? _save
                            : null,
                        child: Text(
                          driver.remote ? 'Lưu nháp trên máy' : 'Lưu nháp',
                        ),
                      ),
                      if (driver.demoEnabled && widget.onDemo != null)
                        TextButton(
                          onPressed: driver.busy ? null : _openDemo,
                          child: const Text('Mô phỏng'),
                        ),
                    ],
                  ),
                if (step == 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Bước 1/2',
                    style: appText(size: 11, color: AppColors.secondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        body: KeyedSubtree(
          key: ValueKey(driver.formRevision),
          child: Form(
            key: _form,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              children: [
                if (driver.hasApi) ...[
                  Text(
                    driver.savedAt == null
                        ? 'Bản demo • Có thể lưu nháp và tiếp tục sau'
                        : 'Bản nháp đã lưu lúc ${formatStamp(driver.savedAt)}',
                    style: appText(size: 11, color: AppColors.secondary),
                  ),
                  const SizedBox(height: 6),
                ],
                if (driver.picking) ...[
                  const LinearProgressIndicator(),
                  const Text('Đang chọn / tải ảnh…'),
                ],
                VerificationProgress(step),
                const SizedBox(height: 6),
                if (!driver.canEdit) ...[
                  const Notice(
                    'Hồ sơ đang được khóa để xét duyệt.',
                    peach: true,
                  ),
                  const SizedBox(height: 10),
                ],
                if (step == 0) ..._personal(driver) else ..._vehicle(driver),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: appText(size: 12, color: AppColors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    DriverController driver,
    String key,
    String label, {
    String? hint,
    TextInputType? keyboard,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: appText(size: 13)),
      const SizedBox(height: 5),
      TextFormField(
        key: ValueKey('field-$key'),
        initialValue: driver.fields[key],
        readOnly:
            (driver.remote
                ? !driver.canEdit
                : driver.status != ApprovalStatus.draft) ||
            driver.busy,
        keyboardType: keyboard,
        style: appText(size: 14),
        onChanged: (value) => driver.setField(key, value),
        validator: (_) => key == 'citizenId' || key == 'license'
            ? driver.personalErrors()[key]
            : driver.vehicleErrors()[key],
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    ],
  );

  List<Widget> _personal(DriverController driver) => [
    const SectionTitle('Giấy tờ cá nhân', size: 20),
    const SizedBox(height: 5),
    Text(
      'JPG hoặc PNG · Tối đa 5 MB/ảnh',
      style: appText(size: 12, color: AppColors.muted),
    ),
    const SizedBox(height: 10),
    _field(
      driver,
      'citizenId',
      'Số CCCD',
      hint: 'Nhập số CCCD',
      keyboard: TextInputType.number,
    ),
    const SizedBox(height: 10),
    _field(
      driver,
      'license',
      'Số giấy phép lái xe',
      hint: 'Nhập số GPLX',
      keyboard: TextInputType.number,
    ),
    const SizedBox(height: 16),
    if (!driver.remote) ...[
      const SectionTitle('Căn cước công dân', size: 16),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _tile(driver, DocumentKind.citizenFront, 'Mặt trước', 136),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _tile(driver, DocumentKind.citizenBack, 'Mặt sau', 136),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ],
    const SectionTitle('Giấy phép lái xe', size: 16),
    const SizedBox(height: 6),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _tile(driver, DocumentKind.licenseFront, 'Mặt trước', 108),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _tile(driver, DocumentKind.licenseBack, 'Mặt sau', 108),
        ),
      ],
    ),
    const SizedBox(height: 10),
    const Notice(
      'Chụp rõ thông tin và đủ 4 góc giấy tờ.',
      detail: 'Chụp ảnh hoặc chọn từ thư viện',
    ),
  ];

  List<Widget> _vehicle(DriverController driver) => [
    const SectionTitle('Thông tin phương tiện', size: 20),
    const SizedBox(height: 12),
    Text('Loại xe', style: appText(size: 13)),
    const SizedBox(height: 5),
    DropdownButtonFormField<String>(
      initialValue: driver.vehicleTypes.contains(driver.fields['vehicleType'])
          ? driver.fields['vehicleType']
          : null,
      style: appText(size: 14),
      isExpanded: true,
      icon: const AppIcon('chevron-down', size: 17, color: AppColors.secondary),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: driver.vehicleTypes
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged:
          (driver.remote
                  ? driver.canEdit
                  : driver.status == ApprovalStatus.draft) &&
              !driver.busy
          ? (value) => driver.setField('vehicleType', value!)
          : null,
    ),
    const SizedBox(height: 10),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _field(driver, 'plate', 'Biển số xe')),
        const SizedBox(width: 12),
        Expanded(
          child: _field(
            driver,
            'payload',
            'Tải trọng (kg)',
            keyboard: TextInputType.number,
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    if (!driver.remote) ...[
      const SectionTitle('Kích thước thùng xe (m)', size: 14),
      const SizedBox(height: 9),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _field(
              driver,
              'length',
              'Dài',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              driver,
              'width',
              'Rộng',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              driver,
              'height',
              'Cao',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
    ],
    const SectionTitle('Giấy tờ & ảnh xe', size: 18),
    const SizedBox(height: 5),
    Text(
      'JPG hoặc PNG · Tối đa 5 MB/ảnh',
      style: appText(size: 12, color: AppColors.muted),
    ),
    const SizedBox(height: 10),
    for (final kind in [
      DocumentKind.registration,
      DocumentKind.inspection,
      DocumentKind.vehicle,
    ]) ...[_documentRow(driver, kind), const SizedBox(height: 7)],
    const Notice('Hồ sơ chỉ dùng để xác minh tài xế.'),
    const SizedBox(height: 7),
    const Notice(
      'Bạn có thể nhận đơn sau khi hồ sơ được duyệt.',
      icon: 'info',
      peach: true,
    ),
  ];

  Widget _tile(
    DriverController driver,
    DocumentKind kind,
    String side,
    double height,
  ) {
    final document = driver.documents[kind]!;
    final locked = !driver.canEditDocument(kind);
    final needsUpdate = document.rejectionReason != null && !document.replaced;
    return AppCard(
      key: ValueKey('document-${kind.name}'),
      padding: const EdgeInsets.all(11),
      borderColor: needsUpdate ? AppColors.red : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  side,
                  style: appText(size: 12, weight: FontWeight.w600),
                ),
              ),
              if (locked)
                const AppIcon('lock', size: 13, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 7),
          if (document.hasImage) ...[
            GestureDetector(
              onTap: () => showDocumentPreview(context, kind, document),
              child: Stack(
                children: [
                  DocumentImage(
                    kind,
                    document,
                    width: double.infinity,
                    height: height - 62,
                  ),
                  if (!needsUpdate &&
                      (!driver.hasApi || document.remoteReference != null))
                    const Positioned(right: 0, top: 0, child: CheckBadge()),
                ],
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: locked
                  ? () => showDocumentPreview(context, kind, document)
                  : () => _choose(kind),
              child: SizedBox(
                width: double.infinity,
                height: 22,
                child: Center(
                  child: Text(
                    locked
                        ? 'Xem ảnh'
                        : document.replaced
                        ? 'Đã thay ảnh'
                        : 'Xem / Thay ảnh',
                    style: appText(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            InkWell(
              onTap: () => _choose(kind),
              child: DashedBorder(
                child: SizedBox(
                  height: height - 42,
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppIcon(
                        'camera',
                        size: 28,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Tải ảnh lên',
                        style: appText(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (needsUpdate)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                document.rejectionReason!,
                style: appText(size: 10, color: AppColors.red),
              ),
            ),
          _uploadFeedback(driver, kind),
        ],
      ),
    );
  }

  Widget _documentRow(DriverController driver, DocumentKind kind) {
    final document = driver.documents[kind]!;
    final locked = !driver.canEditDocument(kind);
    final needsUpdate = document.rejectionReason != null && !document.replaced;
    return AppCard(
      key: ValueKey('document-${kind.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderColor: needsUpdate ? AppColors.red : AppColors.line,
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => document.hasImage
                    ? showDocumentPreview(context, kind, document)
                    : _choose(kind),
                child: document.hasImage
                    ? DocumentImage(kind, document, width: 64, height: 40)
                    : const SizedBox(
                        width: 64,
                        height: 43,
                        child: AppIcon('camera', color: AppColors.muted),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  kind.label,
                  style: appText(size: 12.5, weight: FontWeight.w600),
                ),
              ),
              if (document.hasImage &&
                  !needsUpdate &&
                  (!driver.hasApi || document.remoteReference != null)) ...[
                const CheckBadge(size: 16),
                const SizedBox(width: 5),
                Text(
                  'Đã tải lên',
                  style: appText(size: 10, color: AppColors.green),
                ),
              ],
              const SizedBox(width: 12),
              InkWell(
                onTap: locked
                    ? () => showDocumentPreview(context, kind, document)
                    : () => _choose(kind),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    locked
                        ? 'Xem ảnh'
                        : document.hasImage
                        ? 'Thay ảnh'
                        : 'Tải ảnh',
                    style: appText(
                      size: 10.5,
                      weight: FontWeight.w600,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AppIcon(
                locked ? 'lock' : 'chevron-right',
                size: 12,
                color: AppColors.secondary,
              ),
            ],
          ),
          if (needsUpdate)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                document.rejectionReason!,
                style: appText(size: 11, color: AppColors.red),
              ),
            ),
          _uploadFeedback(driver, kind),
        ],
      ),
    );
  }

  Widget _uploadFeedback(DriverController driver, DocumentKind kind) {
    if (!driver.hasApi) return const SizedBox.shrink();
    if (driver.uploadingDocument == kind) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Đang tải ảnh…',
          style: appText(size: 11, color: AppColors.orange),
        ),
      );
    }
    final document = driver.documents[kind]!;
    if (document.bytes == null || document.remoteReference != null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chưa tải lên thành công',
          style: appText(size: 11, color: AppColors.red),
        ),
        TextButton(
          key: ValueKey('retry-${kind.name}'),
          onPressed: driver.busy
              ? null
              : () async {
                  final message = await driver.retryUpload(kind);
                  if (!mounted) return;
                  if (message != null) {
                    _showError(message);
                  } else {
                    setState(() => error = null);
                  }
                },
          child: const Text('Thử tải lại'),
        ),
      ],
    );
  }
}
