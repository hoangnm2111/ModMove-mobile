import '../../../../core/widgets/notice_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../domain/entities/driver_application.dart';
import '../controllers/driver_controller.dart';

class DriverDemoScreen extends StatelessWidget {
  const DriverDemoScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() action,
    String success,
  ) async {
    final error = await action();
    if (!context.mounted) return;
    showNotice(context, error ?? success, error: error != null);
  }

  Future<void> _reset(
    BuildContext context,
    DriverController driver,
    bool complete,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(complete ? 'Tạo hồ sơ mẫu?' : 'Bắt đầu đăng ký mới?'),
        content: const Text(
          'Hồ sơ, ảnh và lịch sử mô phỏng hiện tại sẽ được thay bằng phiên mới trên thiết bị này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tạo phiên mới'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error = await driver.resetDemo(completeDraft: complete);
    if (!context.mounted) return;
    if (error != null) {
      showNotice(context, error, error: true);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/verification', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverController>();
    return Scaffold(
      appBar: AppHeader(
        'Kịch bản mô phỏng',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Notice(
            'Công cụ trình diễn',
            icon: 'info',
            peach: true,
            detail:
                'Giả lập phản hồi của quản trị viên và lỗi API. Đây không phải quyền xét duyệt của tài xế trên hệ thống thật.',
          ),
          const SizedBox(height: 18),
          const SectionTitle('Kết quả xét duyệt'),
          const SizedBox(height: 8),
          Text(
            'Phiên bản ${driver.version} • ${_status(driver.status)}',
            style: appText(color: AppColors.secondary),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            'Mô phỏng: yêu cầu bổ sung',
            key: const ValueKey('demo-reject'),
            onPressed: driver.status == ApprovalStatus.pending && !driver.busy
                ? () => _run(
                    context,
                    () => driver.simulateReview(ApprovalStatus.rejected),
                    'Đã trả lại mặt sau GPLX và giấy đăng kiểm.',
                  )
                : null,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('demo-approve'),
            onPressed: driver.status == ApprovalStatus.pending && !driver.busy
                ? () => _run(
                    context,
                    () => driver.simulateReview(ApprovalStatus.approved),
                    'Hồ sơ đã được duyệt. Quay lại hồ sơ để bật hoạt động.',
                  )
                : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mô phỏng: duyệt hồ sơ'),
          ),
          if (driver.status != ApprovalStatus.pending)
            Text(
              'Gửi hồ sơ trước để thử quyết định xét duyệt.',
              style: appText(size: 12, color: AppColors.secondary),
            ),
          const SizedBox(height: 20),
          const SectionTitle('Tài khoản'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tài khoản đang hoạt động'),
            subtitle: const Text(
              'Tắt để thử trường hợp hồ sơ đã duyệt nhưng tài khoản bị khóa.',
            ),
            value: driver.accountActive,
            onChanged: driver.busy
                ? null
                : (value) => _run(
                    context,
                    () => driver.simulateAccount(value),
                    'Đã cập nhật trạng thái tài khoản mô phỏng.',
                  ),
          ),
          const Divider(height: 28),
          const SectionTitle('Thử lỗi và tải lại'),
          const SizedBox(height: 5),
          const Text(
            'Chọn một lỗi rồi quay lại thực hiện thao tác. Lỗi chỉ xảy ra một lần; lần thử lại có thể thành công.',
          ),
          const SizedBox(height: 8),
          for (final item in const [
            ('upload', 'Lỗi tải ảnh lần tới'),
            ('submit', 'Lỗi gửi hồ sơ lần tới'),
            ('load', 'Lỗi tải trạng thái lần tới'),
            ('save', 'Lỗi lưu nháp lần tới'),
            ('availability', 'Lỗi bật/tắt hoạt động lần tới'),
          ])
            OutlinedButton(
              key: ValueKey('fail-${item.$1}'),
              onPressed: driver.busy
                  ? null
                  : () => _run(
                      context,
                      () => driver.failNext(item.$1),
                      'Đã đặt ${item.$2.toLowerCase()}.',
                    ),
              child: Text(item.$2),
            ),
          const SizedBox(height: 18),
          const SectionTitle('Chuẩn bị dữ liệu'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: driver.busy
                ? null
                : () => _reset(context, driver, false),
            child: const Text('Bắt đầu đăng ký mới'),
          ),
          OutlinedButton(
            onPressed: driver.busy ? null : () => _reset(context, driver, true),
            child: const Text('Tạo hồ sơ mẫu đầy đủ'),
          ),
          const Text(
            'Dữ liệu mẫu chỉ để demo. Không dùng giấy tờ cá nhân thật khi trình chiếu.',
          ),
          if (driver.busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  String _status(ApprovalStatus status) => switch (status) {
    ApprovalStatus.draft => 'Bản nháp',
    ApprovalStatus.pending => 'Chờ duyệt',
    ApprovalStatus.approved => 'Đã duyệt',
    ApprovalStatus.rejected => 'Cần bổ sung',
  };
}
