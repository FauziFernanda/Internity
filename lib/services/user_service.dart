import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/user_model.dart';

class UserService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<List<UserModel>> getUsers({String search = ''}) async {
    try {
      final response = await _dio.get(
        '/users/index.php',
        queryParameters: search.isNotEmpty ? {'search': search} : null,
      );

      final body = response.data;
      if (body['status'] == true) {
        final List list = body['data'] ?? [];
        return list.map((item) => UserModel.fromJson(item)).toList();
      } else {
        throw Exception(body['message'] ?? 'Gagal mengambil data user.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<String> createUser({
    required String namaLengkap,
    required String email,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        '/users/create.php',
        data: {
          'nama_lengkap': namaLengkap,
          'email': email,
          'role': role,
        },
      );

      final body = response.data;
      if (body['status'] == true) {
        return body['message'] ?? 'User berhasil ditambahkan.';
      } else {
        throw Exception(body['message'] ?? 'Gagal menambahkan user.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<String> updateUser({
    required int id,
    required String namaLengkap,
    required String email,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        '/users/update.php',
        data: {
          'id': id,
          'nama_lengkap': namaLengkap,
          'email': email,
          'role': role,
        },
      );

      final body = response.data;
      if (body['status'] == true) {
        return body['message'] ?? 'User berhasil diperbarui.';
      } else {
        throw Exception(body['message'] ?? 'Gagal memperbarui user.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<String> deleteUser(int id) async {
    try {
      final response = await _dio.post(
        '/users/delete.php',
        data: {'id': id},
      );

      final body = response.data;
      if (body['status'] == true) {
        return body['message'] ?? 'User berhasil dihapus.';
      } else {
        throw Exception(body['message'] ?? 'Gagal menghapus user.');
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  String _handleDioError(DioException e) {
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? 'Terjadi kesalahan pada server.';
    }
    return 'Tidak dapat terhubung ke server XAMPP. Pastikan Apache aktif.';
  }
}