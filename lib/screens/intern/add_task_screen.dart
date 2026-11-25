import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/task_service.dart';

class AddTaskScreen extends StatefulWidget {
  final UserModel user;

  const AddTaskScreen({super.key, required this.user});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TaskService _taskService = TaskService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late final DateTime _openedDate;
  late final String _initialDateIso;
  bool _isSubmitting = false;

  String? _attachmentName;
  String? _attachmentBase64;
  int? _attachmentSizeBytes;

  @override
  void initState() {
    super.initState();
    _openedDate = DateTime.now();
    _initialDateIso = DateFormat('yyyy-MM-dd').format(_openedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _formattedTodayDate =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_openedDate);

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickDocumentAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final lowerName = picked.name.toLowerCase();
    if (!lowerName.endsWith('.pdf') &&
        !lowerName.endsWith('.doc') &&
        !lowerName.endsWith('.docx')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format lampiran harus berupa PDF atau Word (.doc, .docx).'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final Uint8List? bytes = picked.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membaca file dokumen. Silakan pilih ulang.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    const int maxBytes = 2 * 1024 * 1024; // 2 MB
    if (bytes.lengthInBytes > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ukuran file lampiran maksimal 2 MB.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    String mime = 'application/pdf';
    if (lowerName.endsWith('.doc')) {
      mime = 'application/msword';
    } else if (lowerName.endsWith('.docx')) {
      mime =
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    final base64Str = 'data:$mime;base64,${base64Encode(bytes)}';

    setState(() {
      _attachmentName = picked.name;
      _attachmentBase64 = base64Str;
      _attachmentSizeBytes = bytes.lengthInBytes;
    });
  }

  Future<void> _submitTask() async {
    if (_isSubmitting) return;

    final currentDateIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (currentDateIso != _initialDateIso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Batas pengisian tugas pukul 23:59 WIB telah lewat. Presensi hari ini telah di-reset.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      Navigator.pop(context, false);
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul pekerjaan wajib diisi.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keterangan pekerjaan wajib diisi.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _taskService.submitTask(
        userId: widget.user.id,
        title: title,
        description: description,
        attachmentName: _attachmentName,
        attachmentBase64: _attachmentBase64,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas hari ini berhasil disimpan!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPdf =
        (_attachmentName ?? '').toLowerCase().endsWith('.pdf');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tambah Tugas Hari Ini',
          style: TextStyle(
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF1A64E8), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Batas pengisian laporan tugas harian maksimal pukul 23:59 WIB hari ini.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Judul Pekerjaan
                  const Row(
                    children: [
                      Text(
                        'Judul Pekerjaan ',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '*',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Testing Modul Inform Consent',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1A64E8), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Tanggal (Otomatis hari ini & Disabled)
                  const Text(
                    'Tanggal',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    enabled: false,
                    controller: TextEditingController(text: _formattedTodayDate),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today_rounded,
                          size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Keterangan (Teks Area)
                  const Row(
                    children: [
                      Text(
                        'Keterangan ',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '*',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Tuliskan detail aktivitas atau hasil pekerjaan yang diselesaikan hari ini...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1A64E8), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. Lampiran Dokumen PDF / Word (Opsional, Maks. 2 MB)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lampiran Dokumen (Opsional)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Maks. 2 MB',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unggah laporan atau dokumentasi pekerjaan dalam format PDF atau Word (tidak wajib)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),

                  InkWell(
                    onTap: _pickDocumentAttachment,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _attachmentBase64 != null
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: _attachmentBase64 != null
                          ? Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isPdf
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isPdf
                                        ? Icons.picture_as_pdf_rounded
                                        : Icons.description_rounded,
                                    color: isPdf
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF1D4ED8),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _attachmentName ?? 'lampiran_tugas.pdf',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (_attachmentSizeBytes != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatFileSize(_attachmentSizeBytes!),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Ketuk untuk ganti file',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF1A64E8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _attachmentName = null;
                                          _attachmentBase64 = null;
                                          _attachmentSizeBytes = null;
                                        });
                                      },
                                      child: const Text(
                                        'Hapus File',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE0E7FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.upload_file_rounded,
                                      color: Color(0xFF1A64E8), size: 22),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Pilih File Dokumen',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Format: PDF, DOC, DOCX • Maksimal 2 MB',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 5. Tombol Submit Tugas
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A64E8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _isSubmitting ? 'Menyimpan Tugas...' : 'Simpan Tugas',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}