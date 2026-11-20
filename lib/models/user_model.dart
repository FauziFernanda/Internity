class UserModel {
  final int id;
  final String namaLengkap;
  final String email;
  final String role;

  UserModel({
    required this.id,
    required this.namaLengkap,
    required this.email,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.parse(json['id'].toString()),
      namaLengkap: json['nama_lengkap'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'Intern',
    );
  }

  /// Mengambil 2 huruf inisial dari nama lengkap (contoh: "Admin Sistem" -> "AS")
  String get initials {
    final parts = namaLengkap.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}