# Customer app (mobile)

Luồng khách hàng trên app, nối **backend thật** (ModMove.WebApi). Dịch từ ModMove-web
(`src/api/types.ts`, `endpoints.ts`, `errors.ts`, `labels.ts`, các trang customer).

## Chạy

```bash
flutter pub get
flutter run                                   # emulator: API = http://10.0.2.2:5133/api
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5133/api   # điện thoại thật (IP LAN)
```

- Cần Flutter **≥ 3.44** (pubspec yêu cầu Dart ≥ 3.12.2).
- Backend chạy ở port 5133. Bản debug được gọi `http://` (`android/app/src/debug/AndroidManifest.xml`); bản release bắt buộc `https`.
- Tài khoản demo: `customer@modmove.local` / `ModMove@123`.

## Cấu trúc

```text
lib/core/
  config/app_config.dart        API_BASE_URL (--dart-define)
  network/api_client.dart       Bearer token, tự refresh khi 401 (single-flight), lỗi → ApiException
  network/api_exception.dart    code backend → câu tiếng Việt
  session/session_store.dart    phiên đăng nhập (file trong thư mục riêng của app)
  format/formatters.dart        tiền, ngày giờ, đếm ngược
lib/features/auth/              đăng nhập, đăng ký + OTP, quên mật khẩu (AuthCubit)
lib/features/customer/
  domain/entities/              model khớp 1-1 DTO backend
  domain/order_rules.dart       luật GB: chờ thanh toán, huỷ, khiếu nại 24h, đánh giá 1 ngày…
  data/customer_api.dart        một hàm cho mỗi endpoint
  data/address_search.dart      gợi ý địa chỉ (Photon/OSM, chỉ để gợi ý)
  presentation/                 CustomerShell, đặt xe 4 bước, đơn hàng, chi tiết đơn, đánh giá, tài khoản
```

`app/app.dart` cung cấp `ApiClient`, `AuthApi`, `CustomerApi`, `AuthCubit`. Màn gốc: khách đã đăng nhập →
`CustomerShell`; chưa đăng nhập → trang chủ công khai. Tài xế đăng nhập → luồng hồ sơ/nhận đơn hiện có.

## Luồng nghiệp vụ

| Màn | API | Luật |
|---|---|---|
| Đăng nhập / đăng ký / OTP / quên mật khẩu | `public/Auth/*` | GB-02, GB-25, GB-44, GB-53 |
| Đặt xe 4 bước: lộ trình → hàng hoá (ảnh) → loại xe → thanh toán | `public/FareEstimate`, `customer/Uploads`, `customer/Coupons`, `customer/Orders` | GB-05, GB-06, GB-07, GB-10, GB-21, GB-29; `expectedTotalFee` → `FARE_CHANGED` |
| Thanh toán PayOS | `customer/Orders/{id}/payment` (`platform=App`) | GB-13, GB-31; chỉ tin webhook, quay về app qua `modmove://` |
| Đơn hàng (lọc, tìm, phân trang) | `customer/Orders` | |
| Chi tiết đơn + "việc cần làm tiếp" | `customer/Orders/{id}`, `/tracking`, `/cancel`, `/pickup-evidence`, `/confirm-receipt` | GB-22, GB-26, GB-18, GB-23 |
| Sự cố, hoàn tiền, khiếu nại, trả lời Dispatcher, rút yêu cầu | `customer/Incidents`, `customer/Refunds/*` | GB-42, GB-43 |
| Đánh giá | `customer/Ratings` | GB-20 |
| Tài khoản: hồ sơ, đổi mật khẩu, chính sách, hỗ trợ, xoá tài khoản | `account/*`, `public/Policies`, `public/SupportRequests`, `customer/Account` | GB-47, B8 |

## Chưa làm

- Thông báo đẩy FCM (`PUT account/fcmtoken`) – cần cấu hình Firebase.
- ~~Cập nhật tức thời qua SignalR~~ – đã có: `NotificationReceived` → banner trên đỉnh màn + hộp thông báo (chuông); chi tiết đơn tải lại ngay khi có thông báo của đơn đó. Vẫn giữ tải định kỳ (đơn 20 giây, vị trí tài xế 60 giây) làm dự phòng. Chưa có: FCM đẩy khi app đóng (xem docs/firebase-push.md).
- Bản đồ trong app – hiện mở Google Maps ngoài app để chỉ đường (không cần API key).

## Test

`test/customer/`: logic + model (JSON thật), `ApiClient` (refresh, lỗi, mất mạng), widget luồng đơn đã giao.
