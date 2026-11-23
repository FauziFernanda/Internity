import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

class OtpRequestResult {
  final String message;
  final String email;
  final int expiresIn;
  final String? devOtp;

  OtpRequestResult({
    required this.message,
    required this.email,
    required this.expiresIn,
    this.devOtp,
  });
}

class AuthService {
  static const String _sessionKey = 'sismedika_logged_in_user';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Tahap 1: Cek email terdaftar & kirim kode OTP ke email
  Future<OtpRequestResult> requestOtp(String email) async {
    try {
      final response = await _dio.post(
        '/auth/request_otp.php',
        data: {'email': email.trim().toLowerCase()},
      );

      final body = response.data;
      if (body['status'] == true) {
        final data = body['data'] ?? {};
        return OtpRequestResult(
          message: body['message'] ?? 'Kode OTP telah dikirim.',
          email: data['email'] ?? email.trim().toLowerCase(),
          expiresIn: int.tryParse(data['expires_in'].toString()) ?? 300,
          devOtp: data['dev_otp']?.toString(),
        );
      } else {
        throw Exception(body['message'] ?? 'Email tidak terdaftar dalam sistem.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  /// Tahap 2: Verifikasi 6 digit kode OTP & simpan sesi user
  Future<UserModel> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify_otp.php',
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        },
      );

      final body = response.data;
      if (body['status'] == true && body['data'] != null) {
        final user = UserModel.fromJson(body['data']);
        await saveUserSession(user);
        return user;
      } else {
        throw Exception(body['message'] ?? 'Kode OTP tidak valid.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode({
      'id': user.id,
      'nama_lengkap': user.namaLengkap,
      'email': user.email,
      'role': user.role,
    });
    await prefs.setString(_sessionKey, jsonStr);
  }

  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_sessionKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  String _handleDioError(DioException e) {
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? 'Terjadi kesalahan pada server.';
    }
    return 'Tidak dapat terhubung ke server XAMPP. Pastikan Apache aktif.';
  }
}