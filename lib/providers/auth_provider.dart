import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_exception.dart';
import '../models/auth_models.dart';
import '../services/api_client.dart';
import '../services/token_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required Uri baseUri, TokenStore? store, http.Client? client})
    : _store = store ?? const SecureTokenStore() {
    api = ApiClient(
      baseUri: baseUri,
      client: client,
      tokenProvider: () async => _token,
      onUnauthorized: expireSession,
    );
  }
  final TokenStore _store;
  late final ApiClient api;
  String? _token;
  AppUser? user;
  OtpChallenge? challenge;
  bool booting = true, busy = false;
  String? message, bootError;
  bool messageIsError = true;
  String lastUsername = '';
  Timer? _expiryTimer;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    booting = true;
    bootError = null;
    _notify();
    try {
      _token = await _store.read();
      if (_token != null && _token!.isNotEmpty) {
        user = AppUser.fromJson((await api.get('auth/me')).data);
      }
    } catch (error) {
      if (error is! ApiException || error.statusCode != 401) {
        bootError = describeError(error);
      }
    } finally {
      booting = false;
      _notify();
    }
  }

  Future<void> expireSession() async {
    _expiryTimer?.cancel();
    _token = null;
    user = null;
    challenge = null;
    message = 'Phiên đăng nhập đã hết hiệu lực. Vui lòng đăng nhập lại.';
    try {
      await _store.delete();
    } catch (_) {
      message = 'Phiên đã kết thúc. Không xóa được token trên thiết bị; hãy thử đăng xuất lại.';
    }
    _notify();
  }

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _store.delete();
    } catch (error) {
      message = 'Không xóa được phiên trên thiết bị. Hãy thử lại.';
      busy = false;
      _notify();
      return;
    }
    _expiryTimer?.cancel();
    _token = null;
    user = null;
    challenge = null;
    bootError = null;
    message = null;
    messageIsError = true;
    busy = false;
    _notify();
  }

  Future<bool> _run(
    Future<void> Function() action, {
    bool acceptChallenge = false,
  }) async {
    if (busy) return false;
    busy = true;
    message = null;
    messageIsError = true;
    _notify();
    try {
      await action();
      return true;
    } catch (error) {
      if (acceptChallenge &&
          error is ApiException &&
          [403, 429, 503].contains(error.statusCode) &&
          error.response?.data != null) {
        try {
          challenge = OtpChallenge.fromJson(error.response!.data);
        } catch (_) {
          message =
              'Backend trả phiên OTP không hợp lệ. Hãy kiểm tra hợp đồng API.';
        }
      }
      message ??= describeError(error);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> login(String username, String password) => _run(() async {
    lastUsername = username;
    final response = await api.post(
      'auth/login',
      authenticated: false,
      body: {'username': username, 'password': password},
    );
    challenge = OtpChallenge.fromJson(response.data);
  }, acceptChallenge: true);

  Future<bool> register(Map<String, Object?> body) => _run(() async {
    lastUsername = body['username'] as String;
    challenge = OtpChallenge.fromJson(
      (await api.post('auth/register', authenticated: false, body: body)).data,
    );
  }, acceptChallenge: true);

  Future<bool> resend() => _run(() async {
    final current = challenge;
    if (current == null) throw const FormatException('Không còn phiên OTP.');
    if (DateTime.now().toUtc().isBefore(current.resendAt)) {
      throw const FormatException('Chưa đến thời gian gửi lại mã.');
    }
    challenge = OtpChallenge.fromJson(
      (await api.post(
        'auth/resend-otp',
        authenticated: false,
        body: {'challengeId': current.id},
      )).data,
    );
    message = 'Đã gửi mã mới. Mã cũ không còn hiệu lực.';
    messageIsError = false;
  }, acceptChallenge: true);

  Future<bool> verify(String otp) => _run(() async {
    final current = challenge;
    if (current == null) throw const FormatException('Không còn phiên OTP.');
    if (!DateTime.now().toUtc().isBefore(current.expiresAt)) {
      throw const FormatException('OTP đã hết hạn. Hãy gửi lại mã.');
    }
    final response = await api.post(
      current.verifiesEmail ? 'auth/verify-email' : 'auth/verify-login-otp',
      authenticated: false,
      body: {'challengeId': current.id, 'otp': otp},
    );
    if (current.verifiesEmail) {
      if (jsonObject(response.data)['emailVerified'] != true) {
        throw const FormatException('Backend chưa xác nhận email.');
      }
      challenge = null;
      message = 'Email đã được xác minh. Đăng nhập để nhận OTP đăng nhập.';
      messageIsError = false;
    } else {
      final data = jsonObject(response.data);
      final verifiedUser = AppUser.fromJson(data['user']);
      final token = data['accessToken'];
      final expiry = DateTime.tryParse(data['expiresAtUtc']?.toString() ?? '');
      if (token is! String ||
          token.isEmpty ||
          expiry == null ||
          !expiry.isAfter(DateTime.now())) {
        throw const FormatException(
          'Token hoặc thời hạn đăng nhập không hợp lệ.',
        );
      }
      await _store.write(token);
      _token = token;
      user = verifiedUser;
      challenge = null;
      _expiryTimer?.cancel();
      _expiryTimer = Timer(expiry.difference(DateTime.now()), expireSession);
    }
  });

  void cancelChallenge() {
    if (busy) return;
    challenge = null;
    message = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiryTimer?.cancel();
    api.close();
    super.dispose();
  }
}

String describeError(Object error) {
  if (error is ApiException) {
    final details = error.response?.errors;
    final messages = <String>[];
    if (details is Map) {
      for (final value in details.values) {
        if (value is List) messages.addAll(value.cast<String>());
      }
    } else if (details is List) {
      for (final value in details) {
        if (value is Map && value['description'] is String) {
          messages.add(value['description']);
        }
      }
    }
    return [error.message, ...messages].join('\n');
  }
  if (error is FormatException) return error.message;
  return 'Không thể hoàn tất thao tác. Kiểm tra kết nối và thử lại.';
}
