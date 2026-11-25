class DailyTaskModel {
  final int id;
  final int userId;
  final int? attendanceId;
  final String taskDate;
  final String title;
  final String description;
  final String? attachmentName;
  final String? attachmentBase64;
  final String createdAt;

  DailyTaskModel({
    required this.id,
    required this.userId,
    this.attendanceId,
    required this.taskDate,
    required this.title,
    required this.description,
    this.attachmentName,
    this.attachmentBase64,
    required this.createdAt,
  });

  factory DailyTaskModel.fromJson(Map<String, dynamic> json) {
    return DailyTaskModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      attendanceId: json['attendance_id'] != null
          ? int.tryParse(json['attendance_id'].toString())
          : null,
      taskDate: json['task_date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      attachmentName: json['attachment_name']?.toString(),
      attachmentBase64: json['attachment_base64']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}