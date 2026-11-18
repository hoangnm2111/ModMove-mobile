# Driver pickup — FE-19 to FE-23

## Chạy ngay trên máy ảo Android

Mở máy ảo trong Android Studio, tại `ModMove-mobile` chạy:

Bản đồ MapVina cấu hình theo [hướng dẫn bản đồ Android](mapvina-android.md)
để xem và thao tác trên đường phố thật.

```powershell
flutter pub get
flutter run
```

Chạy trên nhánh đã có FE-19–FE-23 (`feature/tunm`, hoặc `develop` đã pull sau khi
PR được merge). Không cần đổi `SCREEN` giữa các bước.

## Luồng liên kết đăng ký và nhận đơn

FE-43 và FE-27 đều dành cho **tài xế**, dùng chung hồ sơ với FE-19–FE-23:

1. **Home → Đăng ký tài xế** mở FE-43: nhập thông tin, tải giấy tờ cá nhân và xe.
2. **Gửi hồ sơ xét duyệt** chuyển đến FE-27: hồ sơ, phương tiện, trạng thái duyệt.
   Khi chờ duyệt hoặc bị từ chối, tài xế chưa thể bật nhận đơn.
3. Vì chưa có backend, tại hồ sơ chọn **Mô phỏng → Mô phỏng: duyệt hồ sơ**, rồi
   quay lại. Đây là giả lập kết quả của quản trị viên, không phải quyền của tài xế.
4. Bấm **Vào trang chủ tài xế** để mở FE-19, bật công tắc nhận đơn và tiếp tục
   FE-20 → FE-21 → FE-22 → FE-23 theo hướng dẫn dưới.
5. Từ trang chủ tài xế, **Tài khoản** luôn mở lại FE-27 của cùng tài xế. Tại hồ sơ,
   **Đơn hàng** mở chuyến đang thực hiện, hoặc về trang chủ nhận đơn nếu chưa có chuyến.

Hồ sơ mock được lưu trên máy. Lần sau chạy `flutter run`, vào **Tài khoản →
Vào trang chủ tài xế** nếu hồ sơ đã duyệt. Có thể dùng ảnh mẫu trong mỗi ô tải ảnh,
hoặc **Mô phỏng → Tạo hồ sơ mẫu đầy đủ** để điền nhanh trước khi gửi xét duyệt.

Nếu chỉ muốn thử riêng nhận đơn với hồ sơ đã duyệt và đang online có sẵn:

```powershell
flutter run --dart-define=SCREEN=driver-home
```

Lệnh tắt này bỏ qua đăng ký/xét duyệt, không dùng hồ sơ đã lưu của luồng mặc định.

## Luồng thử

1. Bật trực tuyến ở trang chủ tài xế, có hai đơn phù hợp. Chọn một đơn để mở popup.
   Có thể tắt rồi bật công tắc để thử trạng thái hoạt động; 6 giây sau khi bật lại
   sẽ có popup đơn mới.
2. Bấm **Xem chi tiết → Nhận chuyến** trong 30 giây. Có thể bấm một đơn ở danh sách
   để mở popup. Đổi màn hình hay đổi qua lại giữa các đơn không gia hạn thời hạn.
3. Ở màn đến điểm lấy hàng, nút **? → Kịch bản mô phỏng** có các tình huống GPS.
   Chọn **GPS: di chuyển 300 m theo tuyến** hoặc **GPS: đã ở điểm lấy hàng**.
   Nút **Đã đến điểm lấy hàng** chỉ mở trong 500 m với GPS mới không quá 30 giây.
4. Tích đủ 4 mục kiểm tra. Thêm ảnh **Toàn bộ hàng** và **Hàng đã cố định trên xe**.
   Mỗi ô hỗ trợ camera, thư viện hoặc **Dùng ảnh mẫu mô phỏng**. JPG/PNG ≤ 5 MB.
   Ảnh mẫu chỉ phục vụ demo, không phải bằng chứng của một chuyến thật.
5. Với đơn tiền mặt trả bởi người gửi, xác nhận đã thu đúng số tiền trước khi gửi.
   Bấm **Xác nhận đã lấy hàng**: trạng thái `Arrived → PickedUp`, bằng chứng Pending.
6. App chờ khách. Không thể tự bắt đầu giao. Vào **? → Khách xác nhận hàng** để mô
   phỏng phản hồi backend: trạng thái tự chuyển `InTransit`.
7. Thử **Khách yêu cầu chụp lại**: ảnh cũ còn trên máy nhưng phải chụp/tải lại.
   Sau lần gửi thứ 5 bị từ chối, app khóa gửi tiếp và hướng dẫn liên hệ điều phối.

Ở Home, **Kịch bản thử** và ở các màn chuyến, nút **?**, cùng mở bảng mô phỏng.
Các kịch bản gồm tài xế khác nhận trước, khách hủy, mất GPS, lỗi bản đồ, lỗi yêu cầu,
lỗi tải ảnh một lần, ký quỹ thấp, danh sách rỗng và phản hồi của khách. Các thao tác
này mô phỏng hệ thống bên ngoài, không phải quyền của tài xế trên backend thật.

## Source và trách nhiệm

`lib/features/driver_trip` là một feature gồm các phần dùng chung vòng đời chuyến:

| Lớp | Trách nhiệm |
| --- | --- |
| `domain/entities` | Job, offer có deadline, GPS fix, chuyến và bằng chứng bất biến |
| `domain/repositories` | Hợp đồng trip API, picker, liên hệ và điều khiển mô phỏng |
| `domain/usecases` | Hành động chuyến, kiểm tra checklist/ảnh trước khi gửi |
| `data/repositories/mock_driver_trip_repository.dart` | Mock API trong process, độ trễ, GPS timer, kiểm tra nghiệp vụ và chuyển trạng thái nguyên tử |
| `data/repositories/device_cargo_photo_repository.dart` | Camera/thư viện qua image_picker, kiểm tra giải mã ảnh; ảnh mẫu từ bundle |
| `data/repositories/platform_trip_contact_repository.dart` | Mở trình gọi điện và Google Maps bằng URL |
| `presentation/bloc` | DriverHomeBloc, JobOfferBloc, ActiveTripBloc, EvidenceCubit |
| `presentation/screens`, `widgets` | Render theo state; không khởi tạo mock repository |
| `lib/app/driver_trip_scope.dart` | Composition, đồng bộ hồ sơ, lifecycle và hủy timer/subscription |

Home và hồ sơ cũ dùng Cubit qua `flutter_bloc`; tên `HomeController` và
`DriverController` được giữ để không làm đổi call sites. Source không còn
ChangeNotifier hoặc import Provider. Provider có thể vẫn xuất hiện trong lockfile
vì là dependency gián tiếp của flutter_bloc.

Các quy tắc được kiểm tra lại ở mock API, không chỉ khóa nút: hồ sơ Approved/Active,
bán kính tìm đơn 5 km, đúng loại xe/tải trọng, PayOS đã thanh toán, ký quỹ tiền mặt
≥ max(200.000đ, phí nền tảng), một chuyến hoạt động, nhận đơn đầu tiên thắng, hạn
30 giây và timeout ghép đơn 10 phút, đến trong 500 m, đủ hai loại ảnh đã tải lên,
thu tiền người gửi, tối đa 5 lần gửi và chờ khách duyệt trước khi giao.

## Ranh giới mock và tích hợp thật

- Trip API chạy trong process, chưa dùng HTTP/WebSocket/SignalR, FCM hoặc Cloudinary.
  Các tham chiếu `mock://pickup/...` không phải URL tải ảnh từ server.
- Chuyến, ảnh bằng chứng và các tình huống mock được giữ trong phiên app; khởi động
  lại tạo phiên chuyến mới. Hồ sơ onboarding vẫn dùng kho lưu riêng như trước.
- GPS phát tọa độ mô phỏng mỗi 5 giây khi app ở foreground và tài xế online.
  Ra nền thì dừng stream, trở lại thì lấy fix mới. Chưa có dịch vụ GPS chạy nền.
- Bản đồ dùng MapVina (`mapvina_gl`), kéo/zoom trực tiếp. Vùng nhận đơn 5 km có vòng
  sóng khi online, cùng bán kính với mock matching; dừng khi offline hoặc có chuyến.
  Key truyền bằng `--dart-define=MAPVINA_KEY=...`. Xem [cấu hình](mapvina-android.md).
- Đường đến điểm lấy là đường thật từ backend (`GET api/driver/route`); lỗi thì vẽ đường thẳng.
  Tọa độ tài xế và điểm lấy vẫn là dữ liệu mô phỏng. Nhấn thẻ ETA để mở Google Maps ngoài app.
- Nút gọi khách mở dialer, không tự gọi điện. Yêu cầu sự cố chỉ tạo biên nhận mock,
  chưa triển khai toàn bộ UC báo sự cố có ảnh và quy trình điều phối.
- FE-25/26/28/29 nằm ngoài đợt này. Các số tổng hợp/ví ở Home là dữ liệu mock.

## Kiểm tra

```powershell
flutter analyze --no-pub
flutter test --no-pub --coverage
flutter build apk --debug --no-pub
```

Tests bao gồm tranh nhận đơn/đơn hết hạn, GPS và arrival, upload lỗi/retry, trả lại
ảnh, giới hạn 5 lần, COD người gửi, toàn bộ luồng UI ở 390×844, 320×640 và 360×800
với text scale 130%. Để xuất ảnh đối chiếu cục bộ:

```powershell
flutter test --dart-define=CAPTURE_SCREENSHOTS=true test/driver_trip_ui_test.dart
```

Ảnh ở `test/screenshots/iteration2/` được Git bỏ qua. Không commit screenshots,
file nén screenshots, APK, coverage hoặc cấu hình agent.

Kết quả xác minh ngày 2026-11-08: analyzer không có vấn đề, toàn bộ **77 tests**
qua với coverage; build debug APK thành công. Trên AVD Android 36 đã kiểm tra
gửi hồ sơ mẫu → chờ duyệt → đóng/mở lại app vẫn chờ duyệt → mô phỏng duyệt →
trang chủ tài xế → online → popup tự phát → chi tiết → nhận chuyến → đến điểm lấy.
Theo yêu cầu dùng tạm khi chưa có Billing, bản mới fallback sang map mô phỏng
khi chưa có key; vẫn test được cùng luồng nhận đơn.

Tests mới còn kiểm tra hồ sơ đã duyệt sau restart, camera commands/gestures gửi
đến SDK, circle theo tọa độ/mét, pulse/lifecycle/reduced motion. Google Maps tiles
và thao tác native trên bản đồ với key thật chưa được xác minh vì chưa có key.
Luồng hai ảnh, retry, khách từ chối/duyệt và responsive được kiểm tra tự động.
Kiểm tra Android trước đó đã xác minh camera → quay về app → upload mock (`1/2`).

## GPS khi chạy backend thật

Phần trên là bản mock (`USE_MOCK_DRIVER=true`, không gọi backend). Với backend thật:

- Không còn menu mô phỏng GPS và tọa độ cố định `DRIVER_FAKE_LAT/LNG`. Test trên máy ảo bằng
  Extended Controls → Location: đặt một điểm, hoặc Routes → Play route để xe chạy theo tuyến.
- Online: app nghe luồng GPS mỗi 5 giây (không dùng `distanceFilter`, xe đứng yên vẫn có điểm mới)
  và gửi lên `POST api/driver/location` kèm `accuracy`, `isMocked`, `recordedAt`.
- Mất mạng: điểm được giữ trong bộ nhớ (tối đa 120 điểm, bỏ điểm cũ hơn 10 phút) và gửi bù theo thứ tự
  khi có mạng. Tắt app thì mất hàng đợi.
- Backend trả 422 `MOCK_LOCATION` thì app tắt Online và báo "Tắt ứng dụng giả lập vị trí để nhận đơn".
