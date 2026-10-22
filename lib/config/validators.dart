abstract final class Validators {
  static String? requiredText(String? value, {int max = 150}) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập thông tin.';
    }
    if (value.trim().length > max) return 'Tối đa $max ký tự.';
    return null;
  }

  static String? email(String? value) {
    final error = requiredText(value, max: 256);
    if (error != null) return error;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())) {
      return 'Email không hợp lệ.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8 || value.length > 128) {
      return 'Mật khẩu cần 8–128 ký tự.';
    }
    if (!RegExp('[A-Z]').hasMatch(value) ||
        !RegExp('[a-z]').hasMatch(value) ||
        !RegExp('[0-9]').hasMatch(value) ||
        !RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) {
      return 'Cần chữ hoa, chữ thường, chữ số và ký tự đặc biệt.';
    }
    return null;
  }
}
