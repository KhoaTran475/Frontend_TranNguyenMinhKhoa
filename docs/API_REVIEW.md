# Đối chiếu hợp đồng và Swagger — 22/10/2026

Nguồn: `API_CONTRACT.md` và HTTPS Swagger của backend Conveyor đang cấu hình.
Snapshot OpenAPI dùng để đối chiếu nằm trong `build/backend-openapi.json`
(artifact cục bộ, không sửa hợp đồng). Không có source backend trong workspace.

Đã thấy đầy đủ endpoint auth, dashboard, students, lecturers, subjects, rooms,
classes, enrollment, sessions, attendance/changes và users trong Swagger.
`GET /api/auth/me` không token trả HTTP 401 JSON đúng envelope ở lần kiểm tra
trước; cần kiểm tra lại khi backend/tunnel khởi động lại.

## Khác biệt schema tài liệu

Swagger không đánh dấu các request property là required và ghi nhiều chuỗi
`nullable: true`. Hợp đồng yêu cầu tất cả trường request bắt buộc, không null:

| Endpoint | Trường chuỗi nullable trong Swagger nhưng bắt buộc theo hợp đồng |
|---|---|
| POST /api/auth/register | studentCode, fullName, email, username, password |
| POST /api/auth/login | username, password |
| POST /api/auth/verify-email, /verify-login-otp | otp |
| POST/PUT /api/students[/{id}] | studentCode, fullName, email |
| POST/PUT /api/lecturers[/{id}] | lecturerCode, fullName, email |
| POST/PUT /api/subjects[/{id}] | code, name |
| POST/PUT /api/rooms[/{id}] | code, name |
| POST/PUT /api/classes[/{id}] | code, name |
| POST /api/users/lecturer | username, password |
| PUT /api/attendance/{attendanceId} | reason |

Swagger cũng chưa mô tả đầy đủ giới hạn độ dài, miền giá trị số và ràng buộc
thời gian trong bảng Request schema của hợp đồng. Đây là khác biệt ở mô tả
OpenAPI; chưa có cơ sở kết luận backend runtime chấp nhận null hay thiếu trường.
Không gửi các payload cố tình sai tới API auth vì có quota và tác động OTP.

Flutter giữ validation bắt buộc/độ dài/email/password/số/UTC theo hợp đồng.
Backend trả lỗi được giữ nguyên HTTP status, envelope data và errors.

## Giới hạn quyền theo hợp đồng

`GET /api/rooms` chỉ Admin, trong khi Lecturer được tạo/sửa Session có roomId.
Frontend không gọi danh sách phòng dưới quyền Lecturer; dùng ID phòng được
Admin cung cấp. Nếu muốn Lecturer chọn danh sách phòng bằng tên, cần có quyết
định API riêng từ người dùng/backend; lần này không thay đổi endpoint hoặc quyền.
