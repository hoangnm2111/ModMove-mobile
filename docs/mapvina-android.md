# Bản đồ MapVina (Android)

App tài xế dùng bản đồ thật của MapVina qua package `mapvina_gl` và style gốc
`https://maps.mapvina.com/styles/v2/streets.json`. Không còn Google Maps hay bản đồ mô phỏng.

## Chạy với key

Lấy key ở [account.mapvina.com](https://account.mapvina.com). Không commit key vào repo.

```powershell
flutter run --dart-define=MAPVINA_KEY=<key của nhóm>
```

- Không truyền `MAPVINA_KEY` thì app dùng `public_key` (hạn mức thấp, chỉ để thử).
- Emulator mặc định ở Mỹ, ngoài vùng dữ liệu nên bản đồ trắng và ngoài bán kính ghép đơn: đặt vị trí ở TP.HCM bằng
  Extended Controls → Location (chọn điểm rồi Set location, hoặc Routes → Play route để xe chạy theo tuyến).
  App không còn toạ độ cố định `DRIVER_FAKE_LAT/LNG`.
- Build release cũng truyền `--dart-define=MAPVINA_KEY=...`.

## Đường tới điểm lấy hàng

App gọi `GET api/driver/route` của backend (BE gọi MapVina Directions, có cache) và vẽ polyline thật.
Backend lỗi hoặc hết hạn mức thì app vẽ đường thẳng mờ giữa hai điểm; luồng chuyến không bị chặn.
App chỉ hỏi lại đường khi tài xế đi quá 150 m so với lần hỏi trước, vì gói Free chỉ có 200 lượt route/ngày.

## Lưu ý kỹ thuật

- `mapvina_gl` 1.0.1 xoá API key native mỗi lần tạo bản đồ (lỗi `You must provide API key for tile sources`).
  App mở map bằng style rỗng, rồi `MainActivity` (channel `vn.modmove/mapvina`) đặt lại key trước khi tải style MapVina.
  Khi package sửa lỗi này thì bỏ channel, dependency `android-sdk-opengl` trong `android/app/build.gradle.kts`
  và bước style rỗng trong `driver_map.dart`.
- Plugin không có callback báo lỗi tải style: sau 12 giây chưa tải xong, app hiện "Chưa tải được bản đồ" kèm nút thử lại.
- Polyline của MapVina có 5 chữ số thập phân (giống Google), giải mã ở `data/polyline.dart`.
- Widget test thay platform view bằng ô trống ở `test/flutter_test_config.dart`; map thật chỉ kiểm được trên máy/emulator.
