# Google Maps thật và vùng nhận đơn

App dùng `google_maps_flutter` / Maps SDK for Android khi đã có key. Trong lúc
chưa cấu hình key/Billing, app tự dùng lại bản đồ mô phỏng cũ, có kéo/zoom, nút
trở về xe và vòng sóng tìm đơn. Nhãn **Bản đồ mô phỏng** phân biệt chế độ này;
hình đường phố và vòng vùng chỉ minh họa, không theo tỷ lệ địa lý thật.
Tọa độ tài xế, dữ liệu đơn và xét duyệt vẫn là mock để test khi backend chưa có.

Hiện tại có thể chạy `flutter run` để test toàn bộ luồng với map cũ. Khi đã bật
Billing và thêm key vào file bên dưới, dừng app rồi chạy lại `flutter run` để
build cấu hình Android và tự chuyển sang Google Maps. Không cần sửa source.

## Cấu hình một lần

1. Trong [Google Cloud Console](https://console.cloud.google.com/), chọn/tạo project,
   liên kết billing và bật **Maps SDK for Android**.
2. Tạo API key. Trong **Application restrictions**, chọn **Android apps**, thêm:
   - Package: `vn.modmove.modmove_mobile`.
   - SHA-1 của debug certificate trên máy đang build.
3. Trong **API restrictions**, giới hạn key vào **Maps SDK for Android**.
4. Copy `android/secrets.properties.example` thành `android/secrets.properties`
   nếu file chưa có. Thay giá trị mẫu bằng key thật, không thêm dấu nháy:

   ```properties
   MAPS_API_KEY=YOUR_GOOGLE_MAPS_ANDROID_API_KEY
   ```

   File `secrets.properties` đã bị Git ignore. Không gửi key vào chat hoặc commit.
   Biến môi trường `MAPS_API_KEY` có giá trị sẽ ghi đè key trong file.

Lấy SHA-1 trên Windows với Android Studio cài ở vị trí mặc định:

```powershell
& 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Hướng dẫn chính thức: [Google Maps for Flutter](https://developers.google.com/maps/flutter-package/config),
[tạo và giới hạn key Android](https://developers.google.com/maps/documentation/android-sdk/get-api-key).

## Chạy app

Mở AVD có Google APIs hoặc Google Play và kết nối Internet. Trong `ModMove-mobile`:

```powershell
flutter pub get
flutter run
```

Nếu có nhiều máy ảo, chọn thiết bị trong danh sách hoặc dùng
`flutter run -d <device-id>` với ID từ `flutter devices`.
Sau khi thêm/đổi key, dừng app và chạy lại lệnh để rebuild Android manifest;
hot reload/hot restart không cập nhật key native.
Không cần `GOOGLE_MAPS_ENABLED` hoặc đổi `SCREEN`.

## Test tuần tự trên cùng hồ sơ

| Bước | Thao tác | Kết quả cần thấy |
| --- | --- | --- |
| 1. Đăng ký FE-43 | Home → **Đăng ký tài xế**, điền thông tin và tải đủ giấy tờ; mỗi ô có lựa chọn ảnh mẫu | Hai bước thông tin cá nhân và phương tiện; dữ liệu đã nhập được giữ |
| 2. Chờ duyệt FE-27 | **Gửi hồ sơ xét duyệt** | Hiện **Hồ sơ đang chờ duyệt**; công tắc nhận đơn bị khóa |
| 3. Kiểm tra lưu trạng thái | Dừng/mở lại app → **Tài khoản** | Vẫn chờ duyệt, cùng hồ sơ/phiên bản |
| 4. Giả lập quản trị viên | **Mô phỏng → Mô phỏng: duyệt hồ sơ → Quay lại** | Hiện **Hồ sơ đã duyệt** và nút **Vào trang chủ tài xế** |
| 5. Trang chủ FE-19 | **Vào trang chủ tài xế**, bật online | Có key: Google Maps; chưa có key: map mô phỏng. Hai chế độ đều có vòng sóng cam tìm đơn |
| 6. Nhận đơn FE-20/21 | Chờ khoảng 6 giây hoặc chạm đơn trong danh sách → **Xem chi tiết → Nhận chuyến** trước 30 giây | Chuyển đến **Đến điểm lấy hàng**, vùng tìm đơn ngừng nhấp nháy |
| 7. FE-22/23 | **? → GPS: đã ở điểm lấy hàng → Đã đến điểm lấy hàng**, kiểm tra hàng và tải hai ảnh | Tiếp tục luồng lấy hàng trong [hướng dẫn pickup](driver-pickup-mock.md) |

Muốn test lại từ đầu: **Tài khoản → Mô phỏng → Bắt đầu đăng ký mới**, xác nhận tạo
phiên mới. Đây là thao tác chủ động thay hồ sơ mock trên thiết bị. Không cần xóa
app. **Tạo hồ sơ mẫu đầy đủ** là lựa chọn điền nhanh, vẫn cần gửi và duyệt hồ sơ.
Màn mô phỏng chỉ giả lập quản trị viên/backend, không phải quyền duyệt của tài xế.

## Test Google Maps và animation sau khi thêm key

- Kéo một ngón trong bản đồ: bản đồ di chuyển, danh sách bên ngoài không giành thao tác.
- Chụm/mở hai ngón hoặc nút **+ / −**: thay đổi mức zoom. Có thể xoay bằng hai ngón.
- **Về vị trí tài xế**: đưa camera về tài xế, vừa vùng nhận đơn hoặc hai đầu chuyến.
- Vòng biên giữ bán kính **5.000 m** theo tọa độ, hai vòng sóng lan dần và mờ đi
  bên trong. Zoom/kéo bản đồ không làm vòng tròn tách khỏi vị trí tài xế.
- Online + có GPS + chưa nhận chuyến: có vùng nhận đơn. Offline, mất GPS hoặc đã
  nhận chuyến: không còn sóng tìm đơn. Ra nền dừng animation; trở lại tiếp tục.
- Thiết bị bật giảm chuyển động: chỉ giữ vòng biên tĩnh, không nhấp nháy.
- Vị trí mới cập nhật marker/vùng nhận đơn nhưng không tự kéo camera khi người dùng
  đang xem khu vực khác. Nhấn nút trở về để xem vị trí mới.
- Bán kính thể hiện phạm vi tìm đơn; đơn còn phải đáp ứng điều kiện xe, thanh toán,
  ký quỹ và trạng thái. Nó không bảo đảm luôn có đơn trong khu vực.

## Nếu chưa thấy đường phố

- **Bản đồ mô phỏng**: app chưa có key hợp lệ trong cấu hình build. Thêm key vào
  file, bật Billing/SDK rồi dừng app và chạy lại để chuyển sang Google Maps.
- Thấy Google logo nhưng nền trống: kiểm tra Maps SDK for Android, billing,
  package/SHA-1, API restrictions và Internet của máy ảo. Có key trong file
  không đồng nghĩa key đã được Google cho phép sử dụng.
- Fallback dựa vào việc có key trong build, không tự phát hiện Billing/key bị
  Google từ chối. Nếu đã có key nhưng Billing chưa sẵn sàng, xóa giá trị key tạm
  khỏi file (và biến `MAPS_API_KEY` nếu có), rồi rebuild để dùng map mô phỏng.

Đường nét đứt đến điểm lấy chỉ là hướng minh họa giữa hai tọa độ mock, không phải
tuyến đường do Google Directions/Routes tính. Nhấn thẻ khoảng cách ở màn lấy hàng
để mở Google Maps ngoài app và tìm đường thật. GPS thiết bị, Directions/Routes,
dịch vụ vị trí chạy nền và backend chuyến chưa được tích hợp trong đợt này.

Widget tests kiểm tra lệnh gửi đến SDK (camera, markers, circles, animation,
lifecycle), không chứng minh tiles tải thành công. Cần key hợp lệ để xác minh
đường phố và thao tác trên bản đồ native bằng máy ảo/thiết bị.
