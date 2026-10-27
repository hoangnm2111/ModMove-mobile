# ModMove mobile UI review

## Run the app

Use Flutter stable with Dart 3.12.2 or later. This implementation was checked with
Flutter 3.44.9 / Dart 3.12.2. Configure an Android SDK and a compatible JDK before
running the commands from the repository root.

```sh
flutter pub get
flutter run
```

The default entry is the guest Home screen. Tap a vehicle or **Bảng giá công khai**
for fares; **Đăng ký tài xế** opens verification. **Tài khoản** opens the current
driver profile. A successful submission opens the pending profile.

The seven design states can also be opened directly without adding debug controls
to the product UI:

| Reference screen | Run command |
| --- | --- |
| Home | `flutter run --dart-define=SCREEN=home` |
| Public fares | `flutter run --dart-define=SCREEN=pricing` |
| Verification: personal | `flutter run --dart-define=SCREEN=verification-personal` |
| Verification: vehicle | `flutter run --dart-define=SCREEN=verification-vehicle` |
| Approved profile | `flutter run --dart-define=SCREEN=profile-approved` |
| Pending profile | `flutter run --dart-define=SCREEN=profile-pending` |
| Correction required | `flutter run --dart-define=SCREEN=profile-rejected` |

Stop the app and run it again when changing a compile-time `SCREEN` value.
The vehicle fixture includes completed personal information so its submission
flow can be reviewed directly. The rejected fixture has two documents requiring
replacement: the back of the driving licence and the inspection certificate.

## Implementation and behavior

Source follows feature-first [Clean Architecture](architecture.md), with pure
Dart domain entities, repository interfaces and use cases. Provider controllers
hold presentation state. `lib/app/app.dart` composes repositories and routes.

Flutter Material is the base UI kit. Inter fonts are bundled for offline use;
the app includes original SVG icons, generated delivery/vehicle artwork and
abstract document previews. Asset provenance is in [assets/README.md](../assets/README.md).
The [design plan](design/implementation-plan.md) records layout analysis and
the commit-sized implementation stages.

- Vehicle tabs update specifications and illustrative fares.
- Personal and vehicle forms retain values while moving between steps.
- Camera/gallery selection validates JPG/PNG content and the 5 MB size limit.
  Selected images can be previewed and replaced.
- Submission validates required fields and documents, shows a busy state, and
  moves the application to pending. Pending documents are read-only.
- Only an approved driver with an active account can toggle availability.
- Rejected documents show individual reasons. Accepted documents stay locked;
  both rejected items must be replaced before resubmission.

## Validation and screenshots

```sh
flutter analyze
flutter test --coverage
flutter build apk --debug
```

The render tests write seven PNGs to `test/screenshots/` at 390 × 844 logical
pixels (2× output). This folder is ignored by Git. Screenshot files, local agent
instructions and build outputs must not be staged or force-added.

Layout tests also cover 320 × 640 at standard text size and 360 × 800 at 130%
text size, including scrolling. Functional tests cover navigation, form
retention, file validation, status gates, corrections and pending transitions.

The debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`.
Local checks do not replace the required Mobile CI result and peer approval
before merging into `develop`.

Validation on 27 October 2026: static analysis passed, all 38 tests passed with
coverage enabled, and the debug APK built successfully. The APK was installed
and launched on an isolated Android 36 emulator. Home → verification navigation
and selecting a PNG through the native Android photo picker were smoke-tested;
the selected image appeared in its document slot. Native camera capture has not
been smoke-tested. All review captures remain in ignored `test/screenshots/`.

## Chạy bằng Android Studio trên máy hiện tại

1. Mở thư mục `C:\Users\MSI\Desktop\project-FPT\source\ModMove-mobile`
   trong Android Studio. Mở thư mục gốc có `pubspec.yaml`.
2. Trong **Settings → Plugins**, bật/cài plugin **Flutter** và **Dart** nếu
   chưa có. Đường dẫn Flutter SDK là `C:\Users\MSI\develop\flutter`.
3. Mở **Tools → Device Manager**, tạo hoặc khởi động một thiết bị Android.
   Máy ảo `Pixel_9_Pro` đã có chỉ còn khoảng 311 MB trống lúc kiểm tra; hãy tạo
   một máy mới nếu gặp lỗi `not enough space`. Chọn ảnh hệ thống Android 14
   (API 34) trở lên, dung lượng trong khoảng 8 GB và RAM 2 GB hoặc hơn.
4. Trong Terminal của Android Studio, tại thư mục gốc dự án, chạy:

   ```powershell
   & "C:\Users\MSI\develop\flutter\bin\flutter.bat" pub get
   & "C:\Users\MSI\develop\flutter\bin\flutter.bat" devices
   & "C:\Users\MSI\develop\flutter\bin\flutter.bat" run
   ```

   Nếu có nhiều thiết bị, dùng `run -d <device-id>` với ID từ lệnh `devices`.
   Hoặc chọn máy ảo ở thanh công cụ, chọn cấu hình `main.dart` rồi bấm **Run ▶**.
5. Để xem riêng trạng thái hồ sơ, dừng app rồi chạy ví dụ:

   ```powershell
   & "C:\Users\MSI\develop\flutter\bin\flutter.bat" run --dart-define=SCREEN=profile-approved
   ```

   Các giá trị `SCREEN` khác được liệt kê ở đầu tài liệu. Khi chạy từ Terminal,
   nhấn `r` để hot reload, `R` để hot restart, `q` để dừng.

## Current boundaries

Fares and driver applications use in-memory demo repositories. Selected photos
remain in memory for the current session; restarting the app restores the
fixture. No documents are uploaded to Cloudinary and no backend review occurs.
Process-death recovery for a camera session is not implemented in this UI slice.

Authentication, booking, real trip offers, wallet, maps, GPS streaming, push
notifications and payments are outside these three tickets. Related entry points
currently open explanatory sheets or the demo profile; they do not perform those
operations. Replace the demo repository implementations and add persistence when
the backend contracts are available.

The seven screens were reconstructed from raster mockups. Inter is a visual font
match; font metadata is unavailable in the reference PNGs. Artwork and document
previews are recreated assets, so they differ in detail. Native Android status
and navigation bars vary by device. This implementation should not be described
as a verified 100% pixel match.
