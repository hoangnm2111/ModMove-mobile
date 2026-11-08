# Mobile kết nối backend thật

Ứng dụng mặc định dùng API thật. Android Emulator kết nối máy host qua `http://10.0.2.2:5133`; không thêm `/api` vào `API_BASE_URL`.

```powershell
# Terminal backend, từ ModMove-backend
docker start modmove-mobile-mysql
dotnet run --project src/ModMove.WebApi --launch-profile http

# Terminal mobile, từ ModMove-mobile
flutter run
```

MySQL local được tạo trong container riêng `modmove-mobile-mysql`, volume `modmove-mobile-mysql-data`, chỉ bind `127.0.0.1:3306`. Cấu hình DB/JWT đã đặt trong file **không commit** `ModMove-backend/src/ModMove.WebApi/appsettings.Development.json`. Máy khác cần tự tạo MySQL và cấu hình theo README backend. Không dùng cấu hình này cho production.

Server khác: `flutter run --dart-define=API_BASE_URL=https://api.example.com`. Debug cho phép HTTP để chạy local; release cần HTTPS. Điện thoại thật cần địa chỉ LAN phù hợp, không dùng `10.0.2.2`.

Muốn mở lại toàn bộ bản mock: `flutter run --dart-define=USE_MOCK_API=true`. Các fixture `SCREEN=...` chỉ dùng trong chế độ mock. Lỗi server ở chế độ API thật **không** chuyển thành dữ liệu/thao tác mock. Bản đồ mô phỏng vẫn được giữ khi chưa cấu hình Google Maps; GPS gửi server là vị trí thiết bị, độc lập với hình bản đồ.

## Những API đã nối

| Chức năng | API và hành vi |
| --- | --- |
| Đăng ký tài xế | `POST /api/public/auth/register-driver`; xác minh `/verify-email` kèm email, OTP và mật khẩu đã đăng ký; gửi lại `/otp/resend` |
| Đăng nhập/phiên | `/login`, `/refresh`, `/api/account/logout`; chỉ role Driver; JWT/refresh token lưu mã hóa; refresh xoay token được tuần tự hóa |
| Thông tin tài khoản | `GET /api/account/profile` |
| Loại xe | `GET /api/public/vehicletypes`; hiển thị tên server, gửi ID số, kiểm tra tải trọng tối đa |
| Upload hồ sơ | `POST /api/driver/uploads`, multipart field `file`, JPG/PNG ≤5 MB; endpoint bổ sung trong backend cùng đợt này |
| Nộp/trạng thái | `POST /api/driver/onboarding`, `GET /api/driver/onboarding/status`; hiển thị Pending/Rejected/Approved và lý do từ chối thực tế |
| Online và ví | `GET /api/driver/status`, `PATCH /api/driver/online-status` với `{isOnline}` |
| GPS | Xin quyền vị trí thiết bị; SignalR `/hubs/tracking` → `SendLocation(lat,lng)` mỗi khoảng 5 giây; dùng `POST /api/driver/location` khi WebSocket chưa kết nối |
| Đồng bộ | Nghe `OrderStatusChanged`/`NotificationReceived`, tải lại trạng thái; polling 5 giây để tìm đơn và khôi phục khi mất realtime |
| Đơn gần tài xế | `GET /api/driver/matching/orders`; backend lọc khoảng cách, loại xe, GPS, ví cọc và đơn đang chạy |
| Nhận đơn | `POST /api/driver/matching/orders/{orderId}/accept`; giữ countdown tuyệt đối 30 giây; 409 không tạo chuyến giả; mất response thì đọc trạng thái trước, không gửi POST lặp |
| Ví/nạp cọc | Số dư từ `/api/driver/status`; `POST /api/driver/wallet/topup` với `{amount,platform:"App"}`; mở checkout PayOS; chỉ số dư server xác nhận mới được hiển thị |

Hồ sơ backend nhận **5 URL theo thứ tự**: GPLX trước, GPLX sau, đăng ký xe, đăng kiểm, ảnh xe. CCCD hiện chỉ gửi số, không có trường ảnh CCCD. Kích thước thùng xe lấy từ danh mục loại xe. Bản nháp chỉ lưu trên thiết bị, mã hóa và tách theo tài khoản/server; backend chưa có endpoint lưu nháp/lịch sử dành cho Driver. Khi bị từ chối, tài xế được sửa thông tin và gửi phiên bản mới. Quyết định duyệt luôn thực hiện ở Admin, không có nút tự duyệt trong chế độ thật.

## Test tuần tự trên giao diện

1. Chạy backend, mở app → **Đăng ký tài xế** → nhập thông tin → OTP. Chưa cấu hình SMTP thì backend Development ghi OTP trong terminal dạng `[DEV] Register OTP ... To: ...`.
2. Xác minh → chọn 2 ảnh GPLX, nhập CCCD/GPLX → chọn loại xe, biển số, tải trọng và 3 ảnh xe → gửi hồ sơ. **Bước upload cần cấu hình Cloudinary thật.**
3. App hiện chờ duyệt. Admin duyệt/từ chối bằng web hoặc Swagger `http://localhost:5133/swagger`; demo Admin: `admin@modmove.local` / `ModMove@123`. Driver không dùng token Admin.
4. Bấm **Kiểm tra trạng thái mới nhất**; nếu từ chối, sửa và gửi lại; nếu được duyệt, bấm **Vào trang chủ tài xế**.
5. Bật online, cấp quyền vị trí. Trong emulator: Extended controls → Location → đặt vị trí gần đơn, ví dụ `10.7769, 106.7009` cho dữ liệu seed TP.HCM. Đơn phải còn thời hạn ghép, đúng loại xe; tiền mặt cần đủ ví cọc. Danh sách rỗng có thể là kết quả đúng từ server.
6. Chọn đơn → nhận trong 30 giây. Kiểm tra `activeOrderId` trên backend; khởi động lại app vẫn nhận biết đơn đang chạy. App giữ chi tiết đã nhận ở bộ nhớ mã hóa và đối chiếu với server; nếu chưa có cache thì chỉ hiện mã đơn vì backend chưa có GET chi tiết đơn dành cho Driver.
7. Tab **Ví** → nạp ít nhất 50.000đ → mở PayOS → trở lại app/tải lại số dư. Không tự cộng tiền khi mở trang hoặc khi quay lại.

Đăng nhập nhanh với driver được duyệt, chưa có chuyến: `driver2@modmove.local` / `ModMove@123` (dữ liệu seed Development). `driver@modmove.local` đã có chuyến seed, nên không thấy đơn mới. Dữ liệu seed được backend tạo để kiểm thử; các thao tác của mobile vẫn đi qua HTTP/SignalR thật.

## Giới hạn xác nhận từ source backend

- Chưa có API Driver cho đến nơi, kiểm hàng/POD, báo sự cố, rút tiền và thống kê doanh thu. App không tự chuyển trạng thái các bước đó; giữ trạng thái server và thông báo chức năng đang chờ API.
- API đơn gần tài xế chưa trả tên/số điện thoại khách. App không dùng thông tin mẫu và không bật nút gọi khách khi thiếu số.
- Chưa có API route Directions cho mobile; nút chỉ đường mở Google Maps ngoài app. Bản đồ trong app hiện fallback mô phỏng theo yêu cầu; khi có Maps SDK key sẽ dùng Google Maps thật.
- GPS hoạt động khi app ở foreground; khi xuống nền ngừng gửi, backend tự coi GPS cũ sau 5 phút. Chưa triển khai background location service/FCM.
- **Cloudinary và PayOS chưa có credentials trên máy này theo xác nhận của người dùng.** Đã kiểm tra request/response và lỗi bằng tests, chưa kiểm thử upload ảnh hay giao dịch PayOS thật. Không bỏ qua kiểm tra này bằng URL/tiền giả trong app.

## Kết quả kiểm tra

- Test hợp đồng mobile: token refresh đồng thời, sai role, phiên hết hạn, 5 ảnh đúng thứ tự, upload multipart, countdown, 409, mất response nhận đơn, phục hồi đơn, quyền GPS và nạp tiền không tự cộng số dư.
- Kiểm tra HTTP trực tiếp trên backend local + MySQL riêng: đăng ký → OTP → Pending → từ chối → gửi lại → Approved v2 → online → GPS → tìm đơn → nhận đơn → xác nhận active order và không nhận thêm đơn.
- Kiểm tra HTTP này dùng URL ảnh fixture và dữ liệu đơn/ví được seed **trong DB local riêng**, không xác nhận upload Cloudinary hay thanh toán PayOS thật.
