import '../../domain/entities/driver_application.dart';
import '../../domain/repositories/driver_repository.dart';

class DemoDriverRepository implements DriverRepository {
  DemoDriverRepository({
    ApprovalStatus status = ApprovalStatus.draft,
    bool completeDraft = false,
    bool accountActive = true,
    this.delay = const Duration(milliseconds: 350),
  }) {
    final complete = status != ApprovalStatus.draft || completeDraft;
    _cached = DriverApplication(
      status: status,
      accountActive: accountActive,
      version: status == ApprovalStatus.draft ? 0 : 1,
      submittedAt: status == ApprovalStatus.draft
          ? null
          : (status == ApprovalStatus.rejected ||
                    status == ApprovalStatus.approved
                ? DateTime(2026, 10, 26, 9)
                : DateTime(2026, 10, 27, 9, 15)),
      reviewedAt:
          status == ApprovalStatus.approved || status == ApprovalStatus.rejected
          ? DateTime(2026, 10, 27, 8, 30)
          : null,
      fields: {
        'fullName': 'Nguyễn Minh Anh',
        'phone': '0901234678',
        'citizenId': complete ? '001201000123' : '',
        'license': complete ? '790123456789' : '',
        'vehicleType': 'Xe tải 1 tấn',
        'plate': '29C-123.45',
        'payload': '1000',
        'length': '3,1',
        'width': '1,6',
        'height': '1,6',
      },
      documents: {
        for (final kind in DocumentKind.values)
          kind: VerificationDocument(
            remoteReference:
                complete || kind == DocumentKind.citizenFront || kind.index >= 4
                ? 'demo://${kind.name}'
                : null,
            accepted:
                status == ApprovalStatus.approved ||
                (status == ApprovalStatus.rejected &&
                    kind != DocumentKind.licenseBack &&
                    kind != DocumentKind.inspection),
            rejectionReason: status == ApprovalStatus.rejected
                ? switch (kind) {
                    DocumentKind.licenseBack => 'Ảnh bị mờ, vui lòng chụp lại.',
                    DocumentKind.inspection =>
                      'Giấy tờ hết hạn, vui lòng cập nhật.',
                    _ => null,
                  }
                : null,
          ),
      },
    );
  }
  final Duration delay;
  late DriverApplication _cached;
  final List<DriverApplication> submissions = [];
  @override
  DriverApplication loadCachedApplication() => _cached;
  @override
  Future<ApplicationReceipt> submit(DriverApplication application) async {
    await Future<void>.delayed(delay);
    final receipt = ApplicationReceipt(application.version + 1, DateTime.now());
    submissions.add(application);
    _cached = DriverApplication(
      status: ApprovalStatus.pending,
      fields: application.fields,
      documents: application.documents,
      version: receipt.version,
      submittedAt: receipt.submittedAt,
      accountActive: application.accountActive,
    );
    return receipt;
  }
}
