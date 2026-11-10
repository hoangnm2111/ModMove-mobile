# Driver mobile: API thật và test tuần tự

Cập nhật 10/11/2026, đối chiếu backend local commit `2cbed81`.
Ứng dụng mặc định gọi API thật; lỗi HTTP không chuyển sang dữ liệu mock.
Backend là nguồn quyết định trạng thái chuyến, số tiền, hồ sơ và quyền nhận đơn.

## Chạy trên Android Emulator

Backend đang chạy ở `http://localhost:5133` trên máy host. Mở máy ảo Android
Studio, chạy từ thư mục `ModMove-mobile`:

```powershell
flutter pub get
flutter run
```

Mobile tự dùng `http://10.0.2.2:5133`, không thêm `/api` vào `API_BASE_URL`.
Nếu có nhiều thiết bị: `flutter devices`, rồi `flutter run -d <device-id>`.
Điện thoại thật cần URL LAN của máy chạy backend:
`flutter run --dart-define=API_BASE_URL=http://<IP-LAN>:5133`.
Debug cho phép HTTP local; release cần HTTPS.

Không cần thay đổi source backend để chạy mobile. Cấu hình database, SMTP,
Cloudinary và PayOS thuộc môi trường backend. Thông tin thiết lập backend xem
README của repo backend.

## Phạm vi đã tích hợp

Các đường dẫn trong bảng có tiền tố `/api`.

| Task | Màn hình và API |
| --- | --- |
| FE-43 | Đăng ký `POST /public/auth/register-driver`, xác minh `/verify-email`, gửi lại `/otp/resend`; upload `POST /driver/uploads`; loại xe `GET /public/vehicletypes`; nộp `POST /driver/onboarding`, trạng thái `GET /driver/onboarding/status` |
| FE-27 | Hồ sơ, xe thực tế, đánh giá và số chuyến từ `GET /driver/profile`; tự tải lại trạng thái khi quay về app và mỗi 15 giây khi đang mở hồ sơ |
| FE-19 | `GET /driver/status`, `PATCH /driver/online-status`; vị trí thiết bị qua SignalR `/hubs/tracking` → `SendLocation` mỗi khoảng 5 giây, REST `POST /driver/location` dự phòng; chỉ số hôm nay từ `GET /driver/wallet/earnings` |
| FE-20 | `GET /driver/matching/orders`; countdown tối đa 30 giây, giới hạn bởi thời hạn ghép đơn của server; không bắt đầu lại khi polling |
| FE-21 | `GET /driver/matching/orders/{id}` cho chi tiết và điều kiện nhận; `POST /driver/matching/orders/{id}/accept`; xử lý 409 và mất response mà không tự gửi POST lặp |
| FE-22 | `GET /driver/trips/{id}` khôi phục chuyến/điểm bàn giao; `POST /driver/trips/{id}/arrive`; gọi khách và mở chỉ đường Google Maps |
| FE-23 | `POST /driver/uploads`, `POST /driver/trips/{id}/pickup` với 2–5 ảnh; tiền mặt người gửi trả qua `POST /driver/trips/{id}/collect-cash`; chờ khách duyệt ảnh |
| FE-25 | `POST /driver/trips/{id}/arrive-dropoff`, upload POD, `POST /driver/trips/{id}/deliver` với ảnh và xác nhận tiền mặt; hiển thị đã giao/chờ khách xác nhận |
| FE-26 | Lịch sử phân trang `GET /driver/trips`; thu nhập mỗi chuyến từ `GET /driver/trips/{id}`: cước, phí, giảm giá, hoa hồng và thực nhận |
| FE-28 | `GET /driver/wallet`, `GET /driver/wallet/transactions`, `GET /driver/wallet/withdrawals`; `PUT /driver/wallet/bank-account`, `POST /driver/wallet/withdrawals`, `POST /driver/wallet/topup` |
| FE-29 | `GET /driver/wallet/earnings` theo ngày/tuần/tháng, giờ Việt Nam; tổng và so sánh kỳ trước từ server; đọc hết các trang để biểu đồ không bỏ sót chuyến |

Đăng nhập/refresh/logout dùng các API auth hiện có; JWT và refresh token được
lưu mã hóa, refresh token được tuần tự hóa. Mobile chỉ chấp nhận role Driver.
Báo sự cố chuyến đang chạy gọi `POST /driver/incidents`.

Hồ sơ nộp đúng 5 URL theo thứ tự: GPLX trước, GPLX sau, đăng ký xe, đăng kiểm,
ảnh xe. CCCD hiện chỉ có trường số, chưa có trường ảnh trong API. Ảnh JPG/PNG
tối đa 5 MB được upload multipart field `file` lên backend. Mobile không chứa
Cloudinary secret. Bản nháp mã hóa trên thiết bị, tách theo tài khoản/server;
backend chưa có API bản nháp/lịch sử hồ sơ cho Driver. Xe đã duyệt hiển thị
thông số xe đăng ký từ hồ sơ, không thay bằng kích thước danh mục.

## Test tuần tự trên giao diện

### 1. Đăng ký → chờ duyệt → được duyệt

1. Mở app → **Đăng ký tài xế**, nhập thông tin và OTP. Nếu SMTP chưa cấu hình,
   backend Development hiện OTP trong terminal theo cấu hình môi trường.
2. Chọn 2 ảnh GPLX, nhập số CCCD/GPLX; chọn loại xe, biển số, tải trọng và 3 ảnh
   xe → gửi hồ sơ. Bước upload cần Cloudinary hoạt động.
3. Hồ sơ chuyển **Chờ duyệt**. Admin duyệt/từ chối trên web hoặc Swagger
   `http://localhost:5133/swagger`: lấy ID từ
   `GET /api/admin/driver-applications/pending`, gọi
   `POST /api/admin/driver-applications/{id}/approve`.
   Đây là thao tác bằng tài khoản Admin; Driver không tự duyệt.
4. Mở lại hồ sơ hoặc bấm **Kiểm tra trạng thái mới nhất**. Nếu bị từ chối,
   chỉnh sửa và gửi lại; nếu được duyệt, chọn **Vào trang chủ tài xế**.

Để kiểm tra ngay các màn sau khi đăng nhập, seed Development có:

| Tài khoản | Mật khẩu demo | Mục đích |
| --- | --- | --- |
| `driver2@modmove.local` | `ModMove@123` | Tài xế đã duyệt, chưa có chuyến tại thời điểm kiểm tra |
| `driver@modmove.local` | `ModMove@123` | Có chuyến đang chạy, lịch sử, doanh thu và yêu cầu rút chờ xử lý |
| `admin@modmove.local` | `ModMove@123` | Duyệt hồ sơ qua web/Swagger |

Đây là tài khoản seed local, dữ liệu có thể thay đổi sau khi thao tác. Dù dữ liệu
được seed, mobile vẫn đọc và ghi qua HTTP/SignalR thật.

### 2. Online → nhận đơn → đến lấy hàng

1. Bật online và cấp quyền vị trí. Emulator → Extended controls → Location:
   đặt `10.7769, 106.7009` nếu thử đơn khu vực Nguyễn Huệ, TP.HCM.
2. Đơn phải còn thời hạn ghép, trong 5 km, đúng loại xe; đơn tiền mặt cần đủ
   cọc theo backend. Tài xế đang có chuyến không nhận thêm đơn.
3. Mở popup/chi tiết đơn, kiểm tra giá và nhận trong thời hạn. Nếu tài xế khác
   đã nhận trước, app báo không còn khả dụng. Tắt/mở app: chuyến được phục hồi
   từ server, gồm trạng thái, liên hệ và bằng chứng.
4. Chọn **Chỉ đường** để mở Google Maps. Đến trong 500 m điểm lấy hàng hoặc
   điểm bàn giao, với GPS mới, mới bật xác nhận đến nơi. Có thể đặt tọa độ máy
   ảo theo địa chỉ đơn để kiểm tra điều kiện này.

### 3. Kiểm hàng → giao hàng → thu nhập chuyến

1. Chụp/chọn 2–5 ảnh khác nhau, chờ upload xong. Đơn tiền mặt người gửi trả
   yêu cầu xác nhận thu tiền trước khi nộp bằng chứng lấy hàng.
2. Gửi kiểm hàng → chờ khách duyệt. Khách của đơn dùng web hoặc
   `POST /api/customer/orders/{id}/pickup-evidence` theo schema Swagger.
   Driver không tự duyệt ảnh. Nếu từ chối, app hiện lý do và số lần gửi còn lại
   theo giới hạn server; thay ảnh rồi gửi lại.
3. Khi backend chuyển **InTransit**, app mở giao hàng. Xem thông tin/gọi người
   nhận, mở chỉ đường và thông báo đã đến điểm giao.
4. Upload một ảnh POD. Nếu còn tiền mặt phải thu, xác nhận đã thu → hoàn tất.
   App hiển thị **Đã giao**, không tự coi tiền đã quyết toán.
5. Khách xác nhận qua `POST /api/customer/orders/{id}/confirm-receipt` hoặc
   cơ chế tự hoàn tất của backend sau thời gian quy định. Khi server chuyển
   **Completed**, thu nhập được ghi nhận trong ví/doanh thu.
6. **Đơn hàng → chuyến → Thu nhập chuyến** để xem cước, hoa hồng, thực nhận,
   thanh toán, POD và sự cố. Lịch sử có lọc và phân trang.

### 4. Ví → nạp/rút → báo cáo doanh thu

1. Mở **Ví**: kiểm tra ví cọc, ví thu nhập, nợ hoa hồng, số có thể rút, trạng
   thái khóa và lịch sử từ server.
2. **Nạp cọc**: tối thiểu 50.000đ; tạo phiên PayOS, xem QR/mở trang thanh toán.
   Phiên có hạn 10 phút. Quay lại app để kiểm tra; chỉ giao dịch server xác
   nhận thành công mới hiện đã nạp. Mở checkout không tự cộng tiền.
3. **Rút thu nhập**: lưu ngân hàng, nhập số tiền nguyên dương, xem xác nhận.
   Không áp đặt mức rút tối thiểu. Backend quyết định số có thể rút sau nợ
   hoa hồng; chỉ một yêu cầu chờ xử lý. Admin xử lý chuyển tiền.
4. Nếu mất mạng lúc gửi yêu cầu rút, tải lại trạng thái trước khi thử lại;
   app không tự gửi lại POST tài chính.
5. **Ví → Báo cáo doanh thu**: đổi Ngày/Tuần/Tháng, kỳ trước hoặc lịch. Kiểm tra tổng cước,
   hoa hồng, thực nhận, biểu đồ và bấm một chuyến để đối chiếu.
   Chỉ chuyến **Completed** được tính, theo múi giờ Việt Nam.

## Phạm vi đã kiểm tra và phần cần cấu hình

### Khi nút rút tiền bị khóa hoặc không tạo được mã PayOS

**Cập nhật 11/11/2026:** đã cấu hình PayOS local theo key người dùng cấp và
tạo được QR 50.000đ bằng API thật trên Android. Firebase tạm tắt ở lần test ví này
(đã bật ở [FE-20](firebase-push.md)); webhook
ngrok còn offline. Xem [kết quả kiểm thử mới](wallet-payos-local-test.md).
Phần chẩn đoán thiếu key bên dưới ghi nhận tình trạng trước lần cấu hình này.

- Rút tiền nhận **số nguyên VND lớn hơn 0**, tức từ **1đ** đến số có thể rút
  do server trả về. Mức **50.000đ áp dụng cho nạp cọc**, không áp dụng cho rút.
- Tại lần kiểm tra này, `driver@modmove.local` có 89.000đ có thể rút nhưng đã
  có yêu cầu rút 100.000đ đang chờ. `hasPendingWithdrawal=true` chặn yêu cầu
  mới dù số tiền nhập hợp lệ. Nhờ Admin xử lý yêu cầu hiện tại qua web hoặc
  `/api/admin/withdrawals`; sau đó bấm **Kiểm tra trạng thái** trong mobile.
  Driver không thể tự duyệt/hủy yêu cầu và mobile không bỏ qua giới hạn này.
- Form ngân hàng mở thành bottom sheet nền trắng, giữ dữ liệu và lỗi khi lưu
  thất bại; chỉ đóng sau khi server xác nhận lưu và tải lại ví thành công.
- Kiểm tra trực tiếp `POST /api/driver/wallet/topup` với 100.000đ và
  `platform: "App"` trả HTTP 500 / `SERVER_ERROR`. File cấu hình Development
  local hiện thiếu `PayOS:ClientId`, `PayOS:ApiKey`, `PayOS:ChecksumKey`.
  Backend có `NotConfiguredPaymentGateway`, ném lỗi khi thiếu cấu hình.
  Nhờ bên backend bổ sung ba giá trị thật và khởi động lại backend; không đặt
  các secret này vào Flutter. URL return/cancel cho App cũng phải hợp lệ.
- Để nhận kết quả thanh toán, backend còn cần webhook PayOS truy cập được từ
  bên ngoài qua HTTPS, trỏ tới `/api/webhooks/payos`. Webhook có chữ ký mới
  xác nhận giao dịch và cập nhật ví. Không chỉ mở checkout rồi tự cộng tiền.
- Mobile hiển thị lỗi dịch vụ nạp tiền cùng **mã hỗ trợ** từ `traceId` để bên
  backend tra log; không suy đoán nguyên nhân mọi HTTP 500 đều là thiếu key.
  Nếu tạo mã mới thất bại, QR cũ được ẩn để tránh thanh toán nhầm phiên/số tiền.
  Lần gọi kiểm tra lỗi không làm thay đổi số dư ví.

### Quy tắc rút thu nhập trên app — đối chiếu 11/11/2026

- **Ví → Rút thu nhập** hiển thị `Tối đa …đ` từ trường
  `maxWithdrawableAmount` của `GET /api/driver/wallet`. Với ví Active, BE tính
  `max(0, earningsBalance - max(0, -depositBalance))`; ví bị khóa có hạn mức 0.
- Chỉ rút thu nhập. **Ký quỹ không thể rút**; nạp PayOS tăng ký quỹ, không
  tăng thu nhập có thể rút. Đơn PayOS hoàn tất ghi nhận thu nhập ròng;
  đơn tiền mặt trừ hoa hồng vào ký quỹ.
- Khi ký quỹ âm, backend trừ toàn bộ nợ hoa hồng từ thu nhập trước, đưa ký quỹ
  về 0 rồi giữ khoản yêu cầu rút. Dialog xác nhận hiển thị riêng số tiền về
  ngân hàng, nợ phải trả và tổng trừ từ thu nhập. Ví dụ: thu nhập 120.000đ,
  ký quỹ −20.000đ → tối đa 100.000đ; yêu cầu 50.000đ sẽ trừ tổng 70.000đ.
- Không áp dụng mức rút tối thiểu 50.000đ; app nhập số nguyên VND lớn hơn 0.
  Cần có ngân hàng, ví hoạt động và không có yêu cầu chờ duyệt. Server được
  đọc lại ngay trước POST; Admin duyệt và chuyển tiền thủ công.
- Kiểm tra GET local: `driver2@modmove.local` có ký quỹ 500.000đ nhưng thu nhập
  **0đ**, nên mức rút tối đa **0đ**. Muốn thử rút cần hoàn tất đơn PayOS để có
  thu nhập; không sửa số dư giả trên app. `driver@modmove.local` có 89.000đ
  có thể rút nhưng vẫn có yêu cầu đang chờ nên chưa được gửi yêu cầu mới.
- Không tạo thêm yêu cầu rút tiền khi kiểm tra live này. Test tự động kiểm
  tra hạn mức 0 dù có ký quỹ, nợ âm làm giảm hạn mức, nợ vượt thu nhập,
  xác nhận tổng khấu trừ, ngân hàng và yêu cầu đang chờ.

### Giới hạn kiểm thử các dịch vụ

- Kiểm tra trực tiếp backend local bằng các repository mobile: hồ sơ, ví,
  giao dịch/rút tiền, doanh thu ngày/tuần/tháng, trạng thái và 11 chi tiết
  chuyến seed ở các trạng thái Accepted/Arrived/PickedUp/InTransit/Delivered/
  Completed.
- Chạy Android Emulator bằng API thật: đăng nhập, trang chủ có chuyến, ví,
  lịch sử, chi tiết thu nhập và đổi kỳ doanh thu; xác nhận màn rút tiền khóa
  nút gửi khi backend đã có yêu cầu đang chờ. Không chỉnh dữ liệu DB để bỏ
  qua quy tắc backend.
- Unit/widget tests kiểm tra hợp đồng HTTP, token refresh, countdown, 409,
  mất response, khôi phục chuyến, quyền GPS, pickup/POD/COD, rút tiền, top-up,
  phân trang, ngày Việt Nam và giao diện 390×844 / 320×640 với cỡ chữ lớn.
- **Cloudinary và PayOS chưa có credentials ở lần kiểm tra ngày 10/11/2026.**
  Chưa xác nhận upload thật, thanh toán thật hoặc toàn bộ một chuyến mới từ
  đăng ký đến quyết toán. Test HTTP giả lập không thay thế kiểm thử này.
- Bản đồ trong app tạm fallback có pan/zoom và vòng phủ sóng nhấp nháy theo
  yêu cầu hiện tại. GPS gửi server vẫn là GPS thiết bị. Khi có Maps SDK key/
  Billing, rebuild để dùng Google Maps thật; xem
  [thiết lập Maps](google-maps-android.md). Chưa có Directions API cho mobile;
  chỉ đường từng chặng mở Google Maps bên ngoài.
- GPS/SignalR hoạt động khi app ở foreground. Chưa có background location
  service; backend coi GPS quá 5 phút là cũ. Push FCM đã được nối riêng ở
  [FE-20](firebase-push.md), không thay thế dịch vụ GPS nền.

Muốn xem bản demo cũ: `flutter run --dart-define=USE_MOCK_API=true`.
`SCREEN=...` chỉ có hiệu lực trong chế độ mock. Quy trình thật ở trên không
có nút mô phỏng duyệt hồ sơ/duyệt ảnh hay nạp/rút tiền giả.

## Kiểm tra và bản build

Luồng **FE-32 Incidents** (tạo báo cáo, lịch sử, ảnh minh chứng và phản hồi
điều phối) có [hướng dẫn riêng](driver-incidents.md), gồm hợp đồng ba API,
kiểm thử live và những phần chưa xác minh với dịch vụ ảnh thật.

```powershell
flutter analyze --no-fatal-infos
flutter test --coverage
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Screenshots kiểm tra nằm trong thư mục bị Git ignore, không đưa vào commit.

Kết quả local ngày 10/11/2026 sau bản sửa phản hồi ví: 128 tests passed,
analyzer không có lỗi. Các test bổ sung kiểm tra
form ngân hàng khi mở bàn phím/cỡ chữ lớn, giữ dữ liệu khi lưu lỗi, giới hạn rút,
khóa/mở lại theo trạng thái server và lỗi PayOS không giữ QR cũ.
Đây là kiểm tra local, không thay thế CI/peer review của PR.

Cập nhật ngày 11/11/2026 sau FE-32 và bổ sung quy tắc ví: **166 tests passed**,
analyzer không có lỗi/cảnh báo và debug APK build thành công. Tham khảo
[kiểm thử Incidents](driver-incidents.md) để phân biệt phần đã gọi API local
với phần upload ảnh chưa kiểm thử dịch vụ thật.
