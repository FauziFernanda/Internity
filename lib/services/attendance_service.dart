import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<TodayAttendanceSummary> getTodaySummary(int userId) async {
    try {
      final response = await _dio.get(
        '/attendance/today.php',
        queryParameters: {'user_id': userId},
      );

      final body = response.data;
      if (body['status'] == true) {
        final data = body['data'] ?? {};
        final todayJson = data['today'];
        final logsList = (data['logs'] as List? ?? [])
            .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        return TodayAttendanceSummary(
          today: todayJson != null
              ? AttendanceRecord.fromJson(Map<String, dynamic>.from(todayJson))
              : null,
          logs: logsList,
        );
      } else {
        throw Exception(body['message'] ?? 'Gagal memuat data kehadiran.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> submitClockIn({
    required int userId,
    required double latitude,
    required double longitude,
    String? justification,
    String? selfieBase64,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/clock_in.php',
        data: {
          'user_id': userId,
          'latitude': latitude,
          'longitude': longitude,
          'justification': justification ?? '',
          'selfie_base64': selfieBase64 ?? '',
        },
      );

      final body = response.data;
      if (body['status'] != true) {
        throw Exception(body['message'] ?? 'Gagal melakukan Clock In.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> submitClockOut(int userId) async {
    try {
      final response = await _dio.post(
        '/attendance/clock_out.php',
        data: {'user_id': userId},
      );

      final body = response.data;
      if (body['status'] != true) {
        throw Exception(body['message'] ?? 'Gagal melakukan Clock Out.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> submitLeaveRequest({
    required int userId,
    required String status, // 'Sakit' atau 'Izin'
    required String documentBase64,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/submit_leave.php',
        data: {
          'user_id': userId,
          'status': status,
          'document_base64': documentBase64,
        },
      );

      final body = response.data;
      if (body['status'] != true) {
        throw Exception(body['message'] ?? 'Gagal mengirim pengajuan.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  String _handleDioError(DioException e) {
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? 'Terjadi kesalahan pada server.';
    }
    return 'Koneksi ke server XAMPP gagal. Pastikan Apache berjalan.';
  }
}