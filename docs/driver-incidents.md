# Driver Incidents — FE-32

Luồng mobile dùng BLoC/Cubit, Clean Architecture và ba API Incidents thật.
Backend quyết định quyền truy cập, trạng thái chuyến và kết quả điều phối.

## Mở và kiểm thử tuần tự

1. Chạy backend tại `http://localhost:5133`, rồi chạy Android Emulator:
   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5133`.
2. Đăng nhập tài xế đã duyệt và có chuyến Accepted/Arrived/PickedUp/InTransit.
   Mở chuyến → **Báo sự cố**. Cũng có thể vào **Tài khoản → Sự cố của tôi**
   hoặc biểu tượng hỗ trợ trên màn **Đơn hàng**.
3. Chọn **Hỏng xe / Hư hỏng hàng / Tai nạn / Khác**, nhập mô tả 1–1.000 ký tự.
   Mã chuyến được giữ cố định khi mở form. Nếu chuyến hoàn tất, hủy hoặc đổi
   tài xế trong lúc nhập, app chặn gửi cho chuyến cũ.
4. Có thể gửi không kèm ảnh. Nếu đính kèm, chụp camera hoặc chọn thư viện:
   tối đa 5 ảnh khác nhau, JPG/PNG, mỗi ảnh ≤5 MB. Đợi upload thành công;
   ảnh lỗi phải **Tải lại** hoặc **Xóa** trước khi gửi. Không dùng ảnh mẫu
   hay URL giả trong chế độ API thật.
5. Bấm **Gửi báo cáo** → app mở **Chi tiết sự cố** bằng mã server trả về.
   Không bấm lại khi đang gửi. Nếu mất phản hồi, app đọc danh sách để xác
   nhận kết quả; **Kiểm tra kết quả gửi** chỉ gọi GET, không tự POST lại.
6. Mở **Sự cố và phản hồi điều phối** trong màn chuyến hoặc **Sự cố của tôi**
   trong hồ sơ. Lọc Tất cả/Mới báo/Đang xử lý/Đã xử lý/Đã đóng; xem thêm nếu
   nhiều hơn 20 bản ghi. Chạm báo cáo để xem nội dung, ảnh phóng to, tọa độ
   ghi nhận nếu có, ghi chú và quyết định của điều phối.
7. Khi điều phối xử lý qua hệ thống của họ, mở chi tiết và bấm làm mới hoặc
   chờ tối đa 15 giây khi màn hình đang hiển thị. App hỗ trợ các quyết định
   Tiếp tục chuyến / Bàn giao tài xế khác / Hủy đơn; không có nút để tài xế
   tự duyệt hoặc đóng sự cố. Sau bàn giao, tài xế cũ vẫn xem được báo cáo
   do chính mình gửi trong danh sách cá nhân theo quyền backend.

Danh sách tự làm mới trang đầu mỗi 15 giây ở foreground. Khi đã tải trang
tiếp theo, dùng làm mới thủ công để không mất vị trí đang đọc. Chi tiết cũng
làm mới khi app quay lại foreground. Không có thông báo nền/FCM mới trong
phạm vi FE-32. Nếu backend thu hồi quyền xem (403/404), dữ liệu chi tiết cũ
được xóa khỏi màn hình. Báo cáo khách hàng chỉ hiện nội dung đã ẩn riêng tư,
không hiển thị ảnh/GPS của khách.

## Hợp đồng API

| API | Cách dùng trong app |
| --- | --- |
| `GET /api/driver/Incidents` | Danh sách, `page`, `pageSize=20`, `status`, `orderId`; kiểm tra kết quả sau mất phản hồi |
| `GET /api/driver/Incidents/{id}` | Chi tiết và phản hồi điều phối |
| `POST /api/driver/Incidents` | `orderId`, `incidentType`, `description`, `photoUrls`, GPS tùy chọn; trả `incidentId` |
| `POST /api/driver/Uploads` | Multipart upload ảnh trước khi gửi URL trong báo cáo |

Gửi GPS thiết bị nếu còn mới (≤30 giây). Khi không có fix mới, mobile bỏ
cả latitude/longitude; backend có thể dùng GPS tài xế đã ghi nhận trước đó.
Ảnh do backend kiểm tra quyền sở hữu. Không có API sửa/xóa báo cáo cho Driver.

Backend hiện lưu sự cố trước khi gửi notification. Vì vậy HTTP 500 cũng có
thể xảy ra sau khi đã lưu. Cubit ghi nhận mã lớn nhất trước POST, rồi tìm
báo cáo mới hơn có cùng tài xế/chuyến/loại/mô tả/ảnh; báo cáo cũ giống nội dung
không được coi là kết quả mới. Nếu chưa tìm thấy, form khóa gửi lại và cho
đọc danh sách. Đây là đối soát trong phiên màn hình, không thay thế idempotency
của backend; dữ liệu nhập/kết quả chưa xác nhận không được lưu qua khởi động
lại app. Sau mất mạng, kiểm tra lịch sử trước khi tạo báo cáo khác.

## Kiểm thử ngày 11/11/2026

- Gọi API local bằng `RemoteDriverIncidentRepository`: đọc cả bốn bộ lọc,
  đọc chi tiết, xử lý 404; tạo **sự cố #6 / chuyến #12** bằng tài khoản demo
  với mô tả đánh dấu `[KIỂM THỬ MOBILE 11/11/2026]`. POST thành công, GET
  chi tiết và danh sách xác nhận đúng nội dung/trạng thái Open. Bản ghi kiểm
  thử này còn trong DB local; không chỉnh DB hay backend.
- 34 kiểm thử riêng cho FE-32: hợp đồng HTTP, upload multipart, quyền riêng
  tư, mất phản hồi, ảnh lỗi/trùng/giới hạn, chuyến thay đổi, race bộ lọc,
  phân trang, phản hồi điều phối và UI 390×844 / 320×640 (cỡ chữ 1.3).
- Đã so sánh ảnh chụp widget với [thiết kế](design/driver-incidents.md).
  Screenshot chỉ nằm tại `test/screenshots/` bị Git ignore.
- **Chưa kiểm thử upload Cloudinary thật hoặc thao tác camera trên thiết bị
  trong đợt này.** Luồng upload và lỗi đã kiểm thử qua HTTP giả lập; báo cáo
  live ở trên không có ảnh. Không thay thế bằng URL giả để báo thành công.
- Phản hồi/giải quyết từ Dispatcher được kiểm tra bằng dữ liệu seed GET và
  widget test; không tự gọi endpoint Dispatcher để thay đổi chuyến demo.

Chạy kiểm tra: `flutter analyze --no-fatal-infos`, `flutter test --coverage`,
`flutter build apk --debug`. APK nằm tại
`build/app/outputs/flutter-apk/app-debug.apk`.
