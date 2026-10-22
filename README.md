# Ứng dụng Android điểm danh sinh viên

Flutter Material 3, xanh dương/trắng, tiếng Việt; backend ASP.NET Core .NET 8,
SQL Server qua HTTPS Conveyor. Giữ project Android và ApiClient từ giai đoạn 1.

## Chạy ứng dụng

1. Khởi động SQL Server và chạy backend trong Visual Studio. Bật Conveyor.
2. Trong thư mục project:

   ```powershell
   flutter pub get
   # Chỉ sao chép khi chưa có file cấu hình:
   Copy-Item .env.example assets/config/.env
   ```

3. Đặt HTTPS URL Conveyor thực tế vào `assets/config/.env`:

   ```dotenv
   BASE_URL=https://largegoldhouse26.conveyor.cloud/api/
   ```

   Không thêm `swagger/index.html`. Khi Conveyor đổi URL, cập nhật file này.
   Sau khi sửa `.env`, dừng app và chạy lại; APK đã cài cần build/cài lại.

4. Mở máy ảo Android trong Android Studio Device Manager và chạy:

   ```powershell
   flutter devices
   flutter run -d <device-id>
   ```

SDK đã kiểm tra: Flutter 3.47.4, Dart 3.13.3. Android Studio cung cấp JDK.
`pubspec.yaml` khai báo thư mục `assets/config/` để app vẫn build và hiện hướng
dẫn khi thiếu `.env`. Giữ file `assets/config/README.txt` trong thư mục đó.
Không có URL mặc định khi cấu hình thiếu hoặc sai. `.env` được bỏ qua bởi Git.

Không đặt SMTP password, JWT secret hoặc SQL connection string trong Flutter.
App không kết nối trực tiếp SQL Server và không bỏ kiểm tra chứng chỉ HTTPS.

## Chức năng đã triển khai

| Yêu cầu | Phần Flutter |
|---|---|
| Đăng ký qua email | Form Student: mã SV, họ tên, email, username, password; xác minh OTP email |
| Đăng nhập | Username + password → Challenge → OTP email → JWT; gửi lại OTP theo cooldown; giữ Challenge trên lỗi 403/429/503 |
| Phân quyền | Admin: trang quản trị; Lecturer: dashboard giảng viên; Student: dashboard sinh viên; quyền lấy từ response server |
| CRUD | Admin thêm/xem/sửa/xóa sinh viên, giảng viên, môn học, phòng học, lớp học phần; tìm kiếm, phân trang, xác nhận xóa |
| Giao diện | Material 3 xanh/trắng, tiếng Việt, cuộn trên màn hình nhỏ, validation, loading, empty, error và retry, chặn gửi lặp |

Chức năng theo hợp đồng đi kèm: Admin quản lý enrollment, tạo tài khoản giảng
viên và khóa/mở tài khoản; Admin/Lecturer tạo/sửa/xóa buổi Scheduled, mở/đóng
điểm danh, xem kết quả và điều chỉnh trạng thái kèm lý do/lịch sử; Student xem
lớp, lịch và kết quả của mình. Các thao tác bị khóa do lịch sử/trạng thái trả
lỗi 409 từ backend và được hiển thị rõ, không tự xóa dữ liệu liên quan.

JWT chỉ lưu bằng flutter_secure_storage, không lưu password/OTP. Mở lại app gọi
`auth/me` trước khi vào dashboard. Lỗi mạng lúc khôi phục phiên có retry và giữ
token; 401 trên request bảo vệ xóa phiên và đưa về đăng nhập. Đăng xuất loại bỏ
cả các màn hình bảo vệ đang mở. Không có refresh token.

Thời gian API được gửi UTC, form chọn và màn hình hiển thị giờ địa phương.
Present/Late/Absent/Excused có nhãn Có mặt/Đi trễ/Vắng mặt/Có phép và màu riêng.

Ứng dụng đã được bổ sung QR điểm danh và GPS theo yêu cầu tiếp theo (xem phần
bên dưới). Cảm biến chuyển động chưa thuộc lần bổ sung này.

## Tài khoản và quy trình kiểm thử thật

- **Admin:** dùng tài khoản đã cấu hình/seed trên backend; app không tự tạo
  Admin và không có mật khẩu mặc định. Admin cũng cần OTP email thật.
- **Student:** Admin tạo hồ sơ sinh viên trước, với mã SV và email thật. Sinh
  viên đăng ký bằng đúng mã/email đó, xác minh email, rồi đăng nhập bằng
  password và OTP Login. Không được tự chọn role khi đăng ký.
- **Lecturer:** Admin tạo hồ sơ giảng viên, sau đó vào Tài khoản người dùng →
  Tạo tài khoản giảng viên. Giảng viên đăng nhập lần đầu, xác minh email nếu
  backend trả Challenge VerifyEmail, rồi đăng nhập lại và nhập OTP Login.
- SMTP phải hoạt động trên backend. Nếu trả 503 kèm Challenge, ở lại màn hình
  OTP, cấu hình SMTP phía backend rồi dùng Gửi lại OTP; không đăng ký lại.
- Lecturer chỉ làm việc với lớp được giao. `GET /rooms` chỉ dành cho Admin theo
  hợp đồng nên giảng viên nhập **ID phòng do Admin cung cấp** khi tạo buổi học;
  app không tự nới quyền hoặc thay endpoint.

Để thử CRUD, Admin tạo môn, hồ sơ giảng viên, phòng, rồi lớp và enrollment.
Thử sửa/xóa dữ liệu chưa dùng; dữ liệu đã liên kết hoặc có lịch sử có thể trả
409 đúng nghiệp vụ. Với buổi học, tạo khung giờ hiện hành hợp lệ, mở rồi đóng;
đóng phiên sinh Absent cho SV chưa có kết quả và không thể mở lại.

## Hợp đồng API và cấu trúc

`API_CONTRACT.md` giữ nguyên bản người dùng cung cấp. Swagger được đọc từ
`https://largegoldhouse26.conveyor.cloud/swagger/v1/swagger.json`.
Các endpoint sử dụng đã có trong Swagger. Điểm khác biệt schema được ghi ở
`docs/API_REVIEW.md`; Flutter vẫn validate theo hợp đồng, không sửa backend.

```text
lib/
  main.dart, app.dart       # Bootstrap .env, Provider và route
  config/                  # Theme, cấu hình, validation
  models/                  # Envelope, lỗi, user/role/challenge, mô tả form CRUD
  services/                # ApiClient, secure token store, đọc phân trang
  providers/               # Auth/phiên và kiểm tra kết nối
  screens/auth/            # Đăng ký, đăng nhập, OTP và cổng phiên
  screens/admin/           # Quản lý tài khoản
  screens/shared/          # Dashboard theo role, CRUD, lớp/buổi/kết quả
  screens/lecturer/        # Dành cho phần riêng giảng viên về sau
  screens/student/         # Dành cho phần riêng sinh viên về sau
  widgets/                 # Bố cục, feedback, nhãn điểm danh
```

Dashboard/CRUD dùng lại widget giữa các role, nhưng chỉ hiển thị hành động đúng
quyền; backend vẫn là nơi kiểm tra role, quyền sở hữu và quy tắc nghiệp vụ.
Màn hình kiểm tra kết nối giai đoạn 1 vẫn mở được từ biểu tượng mạng trên app.
Chỉ 401 JSON đúng envelope hoặc 200 schema User đúng được coi là phản hồi API.

## Kiểm tra tự động và bàn giao

```powershell
dart format lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

Test dùng dữ liệu kiểm soát trong `test/`, không có dữ liệu giả trong ứng dụng.
Chúng không chứng minh SMTP, SQL Server và CRUD thật đã chạy thành công.
Test bao gồm bảo toàn 31 test nền tảng, auth hai bước cả 3 role, Challenge lỗi,
cooldown/resend, 401, lưu token an toàn, dashboard theo role và CRUD môn học.

APK nằm ở `build/app/outputs/flutter-apk/app-debug.apk`.
Chưa có thông tin đăng nhập/OTP thật để kiểm thử auth và CRUD trên backend;
cần dùng các tài khoản/email thật của bạn theo quy trình trên.

## Checklist nghiệm thu

| Thao tác | Mong đợi |
|---|---|
| Thiếu .env/BASE_URL sai, chạy lại | Hướng dẫn cấu hình, không crash |
| URL đúng → kiểm tra kết nối | 401 JSON hợp lệ → đã kết nối, chưa đăng nhập |
| URL sai/mạng lỗi/HTML → thử lại | Báo lỗi, nút hoạt động lại, không báo thành công giả |
| Student đăng ký hồ sơ hợp lệ | Nhận OTP VerifyEmail; xác minh xong quay về đăng nhập |
| Login đúng password | Màn hình OTP, chưa có JWT/dashboard trước khi xác minh |
| OTP sai/hết hạn/gửi lại | Báo lỗi; tuân cooldown; gửi lại thay challengeId và mã cũ |
| Login Admin/Lecturer/Student | Đúng trang, đúng chức năng từng role |
| Admin CRUD 5 nhóm dữ liệu | Tạo, xem chi tiết, tìm, sửa, xóa đúng endpoint |
| Xóa dữ liệu đã dùng | Hiển thị 409, dữ liệu lịch sử được giữ |
| Lecturer vào lớp/buổi | Chỉ lớp được phân công, không có menu quản trị |
| Student xem lịch/kết quả | Chỉ dữ liệu của mình, không có nút sửa/xóa |
| Khóa tài khoản/token hết hiệu lực | 401 xóa phiên, bỏ route bảo vệ, yêu cầu login lại |
| Mở lại app với token còn hạn | Gọi auth/me rồi vào dashboard |

## Kết quả bàn giao thực tế — 22/10/2026

- `dart format lib test`: thành công.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub`: **45 test passed**. Các test auth/CRUD dùng response
  kiểm soát, bao gồm Back Android và bỏ route bảo vệ khi đăng xuất.
- `flutter build apk --debug --no-pub`: thành công; APK đầu ra đã cài được.
- Đã chạy APK trên máy ảo **Pixel 7** ở chế độ ẩn cửa sổ, kiểm tra mở app,
  secure storage đọc phiên ban đầu, validation đăng nhập trống và mở đăng ký.
- Đã nhấn kiểm tra kết nối ngay trên Android; màn hình nhận kết quả thực tế
  **“Đã kết nối backend, chưa đăng nhập”** từ HTTPS Conveyor đang cấu hình.
- Ảnh kiểm tra cục bộ: `build/android-login.png`, `build/android-register.png`,
  `build/android-connection.png`. Máy ảo kiểm thử được tắt sau khi hoàn tất.
- **Chưa kiểm thử email/OTP thật, đăng nhập thật cả 3 role hoặc CRUD thật** do
  chưa có thông tin tài khoản/OTP. Không thay đổi backend hoặc tạo dữ liệu thử
  trên SQL Server. Không có mật khẩu Admin mặc định được thêm vào app.

## Bổ sung: QR điểm danh và chia sẻ vị trí

Các phần mới nằm riêng trong `screens/lecturer/`, `screens/student/`, model
`attendance_check_in.dart`, `AttendanceService`, `AttendanceLocationService`
và `CheckInProvider`. Chỉ bổ sung nút vào Dashboard/lịch học và hiển thị vị trí
trong kết quả; giữ nguyên code bootstrap, đăng nhập/OTP, secure storage,
ApiClient, form CRUD, theme và cấu hình render.

Package được bổ sung: qr_flutter 4.1.0, mobile_scanner 7.4.2, geolocator 14.1.2.
Android có quyền camera, vị trí chính xác và vị trí gần đúng; không xin vị trí
nền. Sau khi thêm plugin, cần **dừng app và chạy/build lại**, hot reload không
đăng ký được plugin native mới.

### Giảng viên

1. Đăng nhập Lecturer, vào lớp được phân công → Buổi học (hoặc Lịch học của tôi).
2. Mở điểm danh khi buổi Scheduled nằm trong khung giờ hợp lệ.
3. Tại buổi **Đang điểm danh**, nhấn menu ⋮ → **Hiện QR điểm danh**.
4. Màn hình gọi GET `sessions/{id}` và GET `sessions/{id}/qr`, dựng QR từ nguyên
   chuỗi `data.qrPayload`, hiển thị đếm ngược và giờ hết hạn địa phương.
5. Hết hạn thì tự tải QR mới; rời app thì ẩn QR, quay lại kiểm tra lại.
   Màn hình kiểm tra trạng thái phiên mỗi 10 giây để ẩn QR khi phiên đóng.
   Backend từ chối ngay tại thời điểm đóng, không chờ màn hình cập nhật.
6. Vào kết quả buổi để xem trạng thái, thời gian, khoảng cách, tọa độ và độ
   chính xác GPS đã được ghi nhận. Admin cũng được xem QR theo hợp đồng.

### Sinh viên

1. Chọn **Quét QR điểm danh** trên dashboard, hoặc chạm buổi Open trong lịch.
2. Nhấn **Quét mã QR**, cấp quyền camera khi dùng ứng dụng, quét mã giảng viên.
   Chọn từ lịch thì QR phải thuộc đúng buổi đã chọn.
3. Nhấn **Chia sẻ vị trí và điểm danh**. Bật GPS và cho phép vị trí chính xác
   khi dùng ứng dụng. Không có ô nhập tọa độ và không dùng vị trí lưu sẵn.
4. App lấy vị trí mới, yêu cầu sai số 0.01–50 m; vị trí quá cũ hoặc sai số cao
   sẽ không gửi. Nếu chưa lấy được GPS sau 20 giây thì có thông báo thử lại.
5. Chỉ gửi `sessionId`, `qrToken`, `latitude`, `longitude`, `accuracyMeters` tới
   POST `attendance/check-in`. Không gửi studentId, thời gian client hoặc JWT
   trong QR. Token đăng nhập được ApiClient gắn qua Authorization như cũ.
6. Server kiểm tra enrollment, phiên Open, hạn QR, thời gian và khoảng cách
   Haversine với phòng; trả 201 Attendance mới hiển thị thành công. Nhãn Có mặt/
   Đi trễ lấy từ kết quả server. Sau lỗi mạng khi gửi, kiểm tra lịch sử trước khi
   gửi lại vì request trước có thể đã được ghi nhận.

Vị trí được chia sẻ **tại thời điểm điểm danh**, không theo dõi liên tục. Giảng
viên/Admin chỉ nhận dữ liệu của lớp theo quyền server. QR+GPS giúp hạn chế gian
lận, không bảo đảm ngăn mọi trường hợp giả mạo GPS hoặc chia sẻ QR.

### Checklist QR/GPS trên thiết bị thật

| Kiểm tra | Mong đợi |
|---|---|
| Giảng viên mở QR của phiên Open | Hiện QR thật từ API, có hạn dùng |
| QR hết hạn/phiên đóng | Tải lại hoặc ẩn mã; server không chấp nhận QR cũ |
| Quét QR không phải attendance/sai buổi | Thông báo rõ, không lấy GPS hoặc gửi check-in |
| Student thuộc lớp, GPS đúng phòng | 201; hiển thị Có mặt/Đi trễ theo server |
| Không thuộc lớp/ngoài bán kính/QR sai | Hiển thị 403/400, không báo thành công |
| Gửi lần hai/buổi chưa mở hoặc đã đóng | Hiển thị 409 từ server |
| Từ chối camera/GPS hoặc tắt GPS | Hướng dẫn cấp quyền/bật vị trí; không crash |
| Chỉ cấp vị trí gần đúng, sai số >50 m | Yêu cầu vị trí chính xác và lấy lại |
| Nhấn gửi nhiều lần | Chỉ một lần lấy GPS/gửi; sau thành công khóa gửi lại |
| Quay nền/rời màn hình quét | Dừng camera; quay lại có thể tiếp tục quét |
| Luồng cũ | Đăng nhập/OTP, dashboard, CRUD, đăng xuất vẫn như trước |

Đã chạy 57 unit/widget test, gồm 45 test cũ và 12 test QR/GPS; analyze sạch.
Test mới sử dụng response và bộ đọc GPS kiểm soát trong `test/`; không phải
bằng chứng camera/GPS hoặc điểm danh backend thật đã hoạt động. Lần đối chiếu
Swagger mới bị timeout; endpoint/body giữ đúng `API_CONTRACT.md` đã có.

`flutter build apk --debug --no-pub` đã thành công với cả 3 plugin native mới.
APK cập nhật: `build/app/outputs/flutter-apk/app-debug.apk`. Chưa chạy thử QR
qua camera/GPS thật hoặc check-in backend thật; cần tài khoản Lecturer/Student
đã enrollment và phiên Open với phòng có tọa độ/bán kính đúng. Không tự tạo dữ
liệu hay gửi điểm danh thay sinh viên. Không thay cấu hình render đã dùng để
xử lý màn hình đen trên máy ảo; dùng lại cách chạy đang hoạt động của bạn.
