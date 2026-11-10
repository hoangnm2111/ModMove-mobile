# Kiểm thử ví với PayOS local — FE-28, 11/11/2026

## Cấu hình

Theo yêu cầu bổ sung của người dùng, đã cập nhật **chỉ file cấu hình local**
`../ModMove-backend/src/ModMove.WebApi/appsettings.Development.json` với bộ
PayOS được cấp. File này được backend Git ignore. Không đưa key vào Flutter,
source, commit hoặc tài liệu. Người dùng đã khởi động lại backend ở cổng 5133.

- API PayOS: `https://api-merchant.payos.vn`.
- Return App: `modmove://orders/success`.
- Cancel App: `modmove://orders/cancel`.
- Webhook cấu hình: `https://reviving-ambitious-disabled.ngrok-free.dev/api/webhooks/payos`.
- **Firebase tạm tắt**, theo lựa chọn người dùng vì chưa có service account.
  Để trống cả `Firebase:CredentialsPath` khi chưa có file. Đặt đường dẫn tới
  file không tồn tại làm backend hiện tại lỗi lúc khởi động.
- Không thay đổi mã nguồn backend hoặc tạo commit backend.

## Kết quả API thật

| Kiểm tra | Kết quả |
| --- | --- |
| GET ví, giao dịch, yêu cầu rút | Thành công cho `driver` và `driver2` |
| GET thu nhập ngày/tuần/tháng | Thành công cho cả hai tài khoản |
| PUT ngân hàng | Lưu lại nguyên dữ liệu hiện có, GET xác nhận không đổi |
| Nạp 49.999đ | HTTP 400 / VALIDATION |
| Rút 0đ | HTTP 400 / VALIDATION |
| Rút 1đ khi `driver` đã có yêu cầu chờ | HTTP 422 / WITHDRAWAL_ALREADY_PENDING |
| Rút 1đ khi `driver2` thu nhập bằng 0 | HTTP 422 / BUSINESS_RULE |
| Tạo mã nạp 50.000đ qua mobile repository | Backend gọi PayOS thật thành công; có checkout `pay.payos.vn`, QR và hạn dùng |
| Tạo mã nạp 50.000đ từ Android UI | Hiển thị QR thật và đếm ngược khoảng 10 phút |
| Số dư sau các kiểm tra chưa thanh toán | Không đổi: ký quỹ 500.000đ mỗi tài khoản; thu nhập `driver` 89.000đ, `driver2` 0đ |

Một probe Python trực tiếp tới PayOS bị Cloudflare chặn theo chữ ký trình
duyệt (HTTP 403). Kết quả này **không phải lỗi credentials**: sau restart,
đường gọi chính thức mobile → backend .NET → PayOS tạo mã thành công.

## App quay về từ PayOS

Android nhận đúng hai đường dẫn success/cancel. Một MethodChannel chuyển
intent sang `PaymentReturnCubit`; callback được giữ tới khi đăng nhập và tải
profile xong rồi mở ví. Flutter không tự điều hướng URI bên ngoài vào route
chưa tồn tại. Khi quay về từ trình duyệt, màn nạp cũng làm mới ngay.

Callback **chỉ mở ví và đọc API**. Không tin `status=PAID`, `amount`, `orderCode`
hay đường dẫn `success` để cộng tiền. Xác nhận thành công vẫn dựa trên giao
dịch khớp mã và trạng thái Completed từ backend.

Đã dùng ADB trên máy ảo kiểm thử riêng để gửi cả hai intent và xác nhận mở ví,
số dư không đổi. Đây là **kiểm thử callback Android**, không phải bằng chứng
đã thanh toán hoặc hủy giao dịch trên PayOS. Nút mở checkout đã mở Chrome tới
đúng `pay.payos.vn`; chưa xác nhận thao tác trả tiền/hủy trên trang PayOS.

Kiểm thử lại callback khi chạy app debug:

```powershell
adb shell am start -a android.intent.action.VIEW -d "modmove://orders/success?status=PAID" -p vn.modmove.modmove_mobile
adb shell am start -a android.intent.action.VIEW -d "modmove://orders/cancel?status=CANCELLED" -p vn.modmove.modmove_mobile
```

Nếu có nhiều máy ảo, thêm `-s <device-id>` sau `adb`.

## Phần chưa xác minh

- URL ngrok trả `ERR_NGROK_3200` lúc kiểm tra; không có tunnel chạy ở máy local.
  Cần bật tunnel từ URL đã cấu hình về `http://localhost:5133`, sau đó đăng ký/
  xác nhận webhook trong kênh PayOS. Chỉ đặt `WebhookUrl` trong JSON chưa tự
  đăng ký: backend hiện có phương thức confirm nhưng không gọi lúc startup.
- [API PayOS](https://payos.vn/docs/api/) có `POST /confirm-webhook` để kiểm
  tra và đăng ký URL bằng probe có chữ ký. Cần HTTP 2xx từ webhook. Chưa gọi
  đăng ký khi URL còn offline.
- Chưa chuyển tiền thật, chưa test webhook ngân hàng thật cộng ký quỹ, chưa
  test Admin chuyển khoản duyệt rút. Không giả webhook thanh toán thành công
  để làm tăng số dư. Các mã thử không thanh toán sẽ hết hạn.
- Firebase/FCM và upload Cloudinary không thuộc kết quả xác minh lần này.

## Kiểm tra mã nguồn

- `flutter analyze --no-fatal-infos`: không có vấn đề.
- `flutter test --coverage`: **170 tests passed**.
- `flutter build apk --debug`: thành công.
- Ảnh kiểm tra QR trong `test/screenshots/payos-live-qr.png` được Git ignore.
  Không commit ảnh, file service account, cấu hình local hoặc secret.
