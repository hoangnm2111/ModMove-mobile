# Thông báo đẩy trên mobile (Firebase Cloud Messaging)

Áp dụng cho **Khách hàng** và **Tài xế** (BE gửi FCM cho cả hai vai trò, bảng 8.3 trong `ModMove-backend/docs/api/README.md`).
Web không dùng Firebase mà nhận thông báo qua SignalR (`NotificationReceived`).

## Luồng hoạt động

1. Mở app → `PushCubit.initialize()` khởi tạo Firebase. Thiếu cấu hình hoặc không phải Android thì trả về "không khả dụng" và app vẫn dùng bình thường.
2. Đăng nhập hoặc khôi phục phiên → `PushCubit.attach(userId)`: xin quyền thông báo Android, lấy token FCM, `PUT /api/account/fcmtoken` `{ token }` → 204.
3. App quay lại màn hình, token FCM đổi, hoặc lần đăng ký trước lỗi → đồng bộ lại (thử lại mỗi 30 giây).
4. Đăng xuất (`AuthCubit.logout`) → `PushCubit.detach()` chờ yêu cầu đăng ký đang chạy xong, huỷ token trên máy, rồi `POST /api/account/logout` `{ fcmToken }` để BE chỉ xoá đúng thiết bị này. Phiên hết hạn (`expire`) cũng huỷ token.
5. Chạm thông báo (đang mở app, chạy nền hoặc mở lạnh) → `PushHost` điều hướng theo vai trò.

Mỗi tài khoản chỉ có một token trên BE: máy đăng ký sau cùng nhận thông báo.

## Cấu hình trên máy

- Dự án Firebase: `modmove`; Android package: `vn.modmove.modmove_mobile`.
- Tải `google-services.json` từ Firebase Console (Project settings → Your apps → Android) và đặt tại `android/app/google-services.json`. File này nằm trong `.gitignore`, **không commit**. Máy khác cần tự tải.
- Khoá service account chỉ để ở **backend** (`Firebase:CredentialsPath` trong cấu hình Development), tuyệt đối không đưa vào Flutter hay Git.
- Không có `google-services.json` thì build vẫn chạy nhưng không bật push (màn Thông báo báo "chưa kết nối Firebase").
- Thêm plugin native nên phải chạy lại hoàn toàn (`flutter run`), hot reload không đủ. Cần máy ảo hoặc máy có Google Play Services.

```
flutter pub get
flutter run -d <android-device-id>
```

## Màn hình khi chạm thông báo

| Vai trò | Loại thông báo | Mở |
|---|---|---|
| Khách hàng | `ORDER_ACCEPTED`, `DRIVER_ARRIVED`, `DRIVER_ARRIVED_DROPOFF`, `PICKUP_PHOTOS_TO_REVIEW`, `ORDER_DELIVERED`, `ORDER_COMPLETED`, `ORDER_CANCELLED`, `INCIDENT_RESOLVED`, `REFUND_*` | Chi tiết đơn (`data.orderId`) |
| Tài xế | `NEW_MATCHING_ORDER` | Chi tiết đơn đang chờ (kiểm tra lại điều kiện bằng API) |
| Tài xế | `PICKUP_APPROVED`, `PICKUP_REJECTED`, `INCIDENT_REPORTED`, `INCIDENT_DECIDED` | Chuyến đang chạy; không có chuyến thì danh sách chuyến |
| Tài xế | `ORDER_CANCELLED`, `ORDER_COMPLETED` | Chuyến của tôi |
| Tài xế | `RATING_RECEIVED` | Đánh giá |
| Tài xế | `WITHDRAWAL_DECIDED` | Ví |
| Tài xế | `DRIVER_APPLICATION_APPROVED`, `DRIVER_APPLICATION_REJECTED` | Hồ sơ (tải lại trạng thái) |

Dữ liệu thông báo chỉ chọn màn hình; ID phải là số nguyên dương, loại lạ bị bỏ qua. Số dư, trạng thái đơn, sự cố… luôn đọc lại từ API.

Cài đặt: **Tài khoản → Thông báo** (khách) hoặc **Hồ sơ → Cài đặt thông báo** (tài xế): xem trạng thái, bật lại, mở cài đặt Android.

## Kiểm thử

- Test tự động: `flutter test test/push_notifications_test.dart` (quyền, lỗi đăng ký và thử lại, token đổi, đăng xuất, mở lạnh, chống hiện trùng, hợp đồng API).
- Thủ công: đăng nhập, cho phép thông báo → BE nhận `PUT /api/account/fcmtoken` (204); tạo sự kiện (nhận đơn, duyệt ảnh…) → thông báo hiện và chạm mở đúng màn; đăng xuất → máy không nhận nữa.

## Giới hạn

- Cần mạng và Google Play Services. Force stop trong cài đặt Android chặn FCM cho tới khi mở lại app.
- BE chưa có API hộp thư thông báo; màn Thông báo chỉ quản lý quyền và kết nối.
- FCM không thay dịch vụ GPS nền: tài xế vẫn chỉ gửi vị trí khi app đang mở.
