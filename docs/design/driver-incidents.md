# FE-32 — thiết kế sự cố tài xế

Thiết kế tạo trước khi triển khai bằng **built-in image_gen** (không dùng
CLI/API key), lưu ngoài repo tại
`../../../output/mobile-design-v2/09-driver-incidents.png`.

## Prompt/brief thiết kế

Create a polished ModMove driver mobile UI presentation board with three
Android screens: “Báo sự cố”, “Sự cố của tôi”, and “Chi tiết sự cố”. Match
the existing ModMove design system: Inter-like typography, orange #D94B18,
dark ink text, white cards, fine gray borders, rounded corners, restrained
peach status surfaces. Vietnamese copy, readable Flutter-implementable
layouts, native safe areas, no unrelated logos or watermarks.

Report screen: a card identifying the current delivery; a two-column grid of
Vehicle breakdown / Damaged cargo / Accident / Other with line icons and
selection indicators; a multiline description; optional photo evidence with
thumbnail/remove/add controls; maximum five JPG/PNG images, 5 MB each; a short
dispatcher-help notice and orange submit CTA. List screen: status filter pills,
current-trip reporting entry, incident cards containing type, order code,
status, short description and date, plus the existing driver navigation.
Detail screen: incident/order identifiers, resolution status, a three-step
timeline, full report and photo thumbnails, dispatcher response, and a route
back to the associated trip. Keep controls consistent with the existing app.

## Áp dụng

- Dùng Inter có sẵn trong repo, Material line icons và các widget chung
  `AppCard`, `Notice`, `PrimaryButton`, `AppHeader`. Không đưa ảnh thiết kế
  thành nền hay dùng ảnh hàng hóa minh họa làm minh chứng thật.
- Mã sự cố, mã chuyến, nội dung, ngày giờ và phản hồi lấy từ backend.
  Danh sách ít bản ghi sẽ có khoảng trống tự nhiên; không thêm báo cáo giả.
- Giới hạn mô tả thật là **1.000 ký tự**, theo validator backend. Số 500
  trong board là lỗi chữ của ảnh sinh; UI triển khai dùng giới hạn đúng.
- Ảnh camera/thư viện mới là minh chứng gửi lên server. Không cần tạo thêm
  bitmap assets cho ba màn hình này; icon lấy từ bộ Material đang dùng.
- Màn hình hỗ trợ cuộn và chữ lớn. Snapshot kiểm tra ở
  `test/screenshots/incidents-{report,list,detail}.png` được Git ignore.
