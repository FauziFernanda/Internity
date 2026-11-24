class AttendanceRecord {
  final int id;
  final String attendanceDate;
  final String? clockInTime;
  final String? clockOutTime;
  final String status;
  final bool isOutsideOffice;
  final double? distanceMeters;
  final String? justification;

  AttendanceRecord({
    required this.id,
    required this.attendanceDate,
    this.clockInTime,
    this.clockOutTime,
    required this.status,
    this.isOutsideOffice = false,
    this.distanceMeters,
    this.justification,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: int.tryParse(json['id'].toString()) ?? 0,
      attendanceDate: json['attendance_date']?.toString() ?? '',
      clockInTime: json['clock_in_time']?.toString(),
      clockOutTime: json['clock_out_time']?.toString(),
      status: json['status']?.toString() ?? '',
      isOutsideOffice: json['is_outside_office'].toString() == '1' ||
          json['is_outside_office'] == true,
      distanceMeters: json['distance_meters'] != null
          ? double.tryParse(json['distance_meters'].toString())
          : null,
      justification: json['justification']?.toString(),
    );
  }
}

class TodayAttendanceSummary {
  final AttendanceRecord? today;
  final List<AttendanceRecord> logs;

  TodayAttendanceSummary({
    this.today,
    required this.logs,
  });
}