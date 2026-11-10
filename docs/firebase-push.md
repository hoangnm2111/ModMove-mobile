# FE-20 — Thông báo tài xế trên Android

Firebase Cloud Messaging đã được nối với tài khoản đăng nhập, dùng API thật
`PUT /api/account/FcmToken` (`{"token":"..."}`). State dùng `PushCubit`; giao
diện, hợp đồng domain và adapter Firebase/API nằm riêng trong feature
`lib/features/notifications/`.

## Cấu hình trên máy

- Firebase project local: `modmove`; Android package: `vn.modmove.modmove_mobile`.
- File client: `android/app/google-services.json`, tải từ Firebase Console →
  Project settings → Your apps → Android. File này đã được tạo trên máy hiện tại
  và được Git ignore. Máy khác cần lấy file đúng project/package trước khi chạy.
- File **service account/private key chỉ nằm ở backend**. Không sao chép vào
  Flutter assets, `google-services.json`, Dart hoặc Git.
- Backend local đọc `Firebase:CredentialsPath` trong cấu hình Development,
  trỏ tới file service account. Khởi động lại backend sau khi đổi cấu hình.
- Cấu hình Firebase không cần ngrok; ngrok vẫn là yêu cầu riêng của webhook PayOS.

```powershell
flutter pub get
flutter run -d <android-device-id>
```

Sau khi đăng nhập, chọn **Allow/Cho phép** trên hộp thoại Android. Vào
**Tài khoản → Thông báo** hoặc bấm chuông trên Trang chủ để xem trạng thái,
thử kết nối hoặc mở cài đặt Android.
Thêm plugin native yêu cầu chạy lại app; hot reload không đủ.

## Hành vi

- Chỉ đăng ký FCM token khi có tài khoản và quyền thông báo. Tự đồng bộ token
  khi SDK đổi token, khi app trở lại foreground và thử lại sau lỗi đăng ký.
- Khi app đang mở, tạo một thông báo Android trên kênh `modmove_driver` có
  âm thanh và mức ưu tiên cao. Khi app chạy nền, để FCM hiển thị notification
  payload, tránh tạo trùng thông báo.
- Xử lý tap từ thông báo foreground, background và khởi động app mới. Đợi
  khôi phục đăng nhập và tải hồ sơ trước khi điều hướng.
- Đăng xuất chờ yêu cầu đăng ký token đang chạy kết thúc, hủy token thiết bị,
  xóa thông báo cũ và gửi `fcmToken` trong `POST /api/account/logout` để backend
  gỡ đúng thiết bị. Lỗi mạng không ngăn xóa phiên đăng nhập local.
- Dữ liệu thông báo chỉ chọn màn hình. Số dư, trạng thái sự cố/hồ sơ/chuyến và
  khả năng nhận đơn đều phải đọc lại từ API; tap không tự nhận đơn hay đổi tiền.

| Loại backend | Màn hình khi chạm |
| --- | --- |
| `NEW_MATCHING_ORDER` | Chi tiết đơn; kiểm tra điều kiện và hạn nhận bằng API |
| `PICKUP_APPROVED`, `PICKUP_REJECTED` | Chuyến đang chạy nếu đúng đơn; nếu không, lịch sử chuyến |
| `ORDER_CANCELLED` | Lịch sử chuyến |
| `ORDER_COMPLETED` | Thu nhập của chuyến |
| `INCIDENT_REPORTED`, `INCIDENT_DECIDED` | Chi tiết sự cố, hoặc danh sách nếu thiếu ID |
| `DRIVER_APPLICATION_APPROVED`, `DRIVER_APPLICATION_REJECTED`, `RATING_RECEIVED` | Hồ sơ tài xế, tải lại trạng thái |
| `WITHDRAWAL_DECIDED` | Ví, tải số dư và giao dịch thật |

Loại không hỗ trợ hoặc ID đơn không hợp lệ không được dùng để điều hướng.
Backend chưa có API hộp thư/lịch sử thông báo; màn hình Thông báo hiện quản lý
quyền và kết nối, không giả lập hộp thư.

## Kiểm thử local ngày 11/11/2026

- 181 unit/widget tests passed; gồm 11 ca mới về quyền, lỗi đăng ký/thử lại,
  token refresh, race logout, cold tap, chống hiển thị trùng và hợp đồng API.
- Analyzer sạch; Android debug APK build thành công cả khi có và khi không có
  file client Firebase. APK cuối trên máy đã được build lại với Firebase bật.
- Máy ảo riêng `ModMoveReview` có Google Play services: cấp quyền Android,
  đăng ký token bằng API thật; UI hiển thị **Đã bật thông báo**.
- Dùng chính `FcmPushNotificationService` hiện có của backend để gửi thông báo
  kiểm thử FCM tới máy ảo; không sửa source backend hoặc trạng thái tài chính.
- Foreground: nhận thông báo và chạm mở Ví; số dư thật 89.000đ/500.000đ.
- Background: nhận thông báo và chạm mở sự cố #6, tải trạng thái thật từ API.
- Cold start: dừng tiến trình app khi ở nền bằng `am kill` (không force stop),
  xác nhận tiến trình đã kết thúc; chạm thông báo khôi phục đăng nhập và mở đúng Ví.
  Không đánh dấu đã kiểm thử live mọi nghiệp vụ phát thông báo; việc duyệt hồ sơ,
  duyệt rút tiền và chốt đơn không bị thay đổi chỉ để tạo thông báo test.

## Giới hạn

- Cần mạng và Google Play services. Android có thể giảm âm lượng/tần suất
  heads-up theo cài đặt hệ thống; app không đảm bảo mọi thông báo đều phát âm.
- Force stop trong cài đặt Android ngăn nhận FCM cho tới khi mở lại app.
- FCM không bổ sung dịch vụ GPS nền. Backend vẫn áp dụng quy tắc GPS hết hạn.
- Backend lưu một token trên mỗi tài khoản: thiết bị đăng nhập/đăng ký token
  sau cùng nhận push. SignalR tiếp tục đồng bộ dữ liệu khi app hoạt động.
- FlutterFire mới có API registration/FID, nhưng backend hiện dùng HTTP v1
  `message.token`; adapter giữ API FCM token tương thích với hợp đồng này.
- CI không có file client vẫn build được; bản build đó không bật push. APK
  phát hành có push phải được build với cấu hình Firebase đúng môi trường.

Tham chiếu: [Firebase Flutter client](https://firebase.google.com/docs/cloud-messaging/flutter/client),
[nhận thông báo và xử lý tap](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
