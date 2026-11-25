import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/task_model.dart';

class TaskService {
  Future<List<DailyTaskModel>> getTasks(int userId) async {
    final uri = Uri.parse(
        '${AppConstants.baseUrl}/tasks/list_tasks.php?user_id=$userId');
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final isSuccess = body['status'] == true || body['success'] == true;
    if (response.statusCode == 200 && isSuccess) {
      final list = (body['data']['tasks'] as List<dynamic>? ?? []);
      return list
          .map((e) => DailyTaskModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(body['message'] ?? 'Gagal memuat daftar tugas.');
    }
  }

  Future<void> submitTask({
    required int userId,
    required String title,
    required String description,
    String? attachmentName,
    String? attachmentBase64,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/tasks/submit_task.php');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'title': title,
        'description': description,
        'attachment_name': attachmentName ?? '',
        'attachment_base64': attachmentBase64 ?? '',
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final isSuccess = body['status'] == true || body['success'] == true;
    final isHttpOk = response.statusCode == 200 || response.statusCode == 201;

    if (!isHttpOk || !isSuccess) {
      throw Exception(body['message'] ?? 'Gagal menyimpan tugas.');
    }
  }
}