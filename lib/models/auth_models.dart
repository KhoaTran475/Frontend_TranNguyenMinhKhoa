enum UserRole {
  admin('Admin', 'Quản trị viên'),
  lecturer('Lecturer', 'Giảng viên'),
  student('Student', 'Sinh viên');

  const UserRole(this.value, this.label);
  final String value;
  final String label;
}

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Dữ liệu API không đúng định dạng.');
  }
  return value;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
  });
  final String id, username, fullName, email;
  final UserRole role;

  factory AppUser.fromJson(Object? value) {
    final json = jsonObject(value);
    final role = UserRole.values
        .where((role) => role.value == json['role'])
        .firstOrNull;
    if (role == null ||
        [
          'id',
          'username',
          'fullName',
          'email',
        ].any((key) => json[key] is! String || (json[key] as String).isEmpty)) {
      throw const FormatException(
        'Thông tin người dùng hoặc vai trò không hợp lệ.',
      );
    }
    return AppUser(
      id: json['id'],
      username: json['username'],
      fullName: json['fullName'],
      email: json['email'],
      role: role,
    );
  }
}

class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.purpose,
    required this.email,
    required this.expiresAt,
    required this.resendAt,
  });
  final String id, purpose, email;
  final DateTime expiresAt, resendAt;
  bool get verifiesEmail => purpose == 'VerifyEmail';

  factory OtpChallenge.fromJson(Object? value) {
    final json = jsonObject(value);
    if (json['challengeId'] is! String ||
        json['maskedEmail'] is! String ||
        !['VerifyEmail', 'Login'].contains(json['purpose'])) {
      throw const FormatException('Phiên OTP không hợp lệ.');
    }
    return OtpChallenge(
      id: json['challengeId'],
      purpose: json['purpose'],
      email: json['maskedEmail'],
      expiresAt: DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
      resendAt: DateTime.parse(json['resendAvailableAtUtc'] as String).toUtc(),
    );
  }
}
