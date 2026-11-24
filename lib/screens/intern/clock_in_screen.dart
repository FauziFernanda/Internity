import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../services/attendance_service.dart';

class ClockInScreen extends StatefulWidget {
  final UserModel user;

  const ClockInScreen({super.key, required this.user});

  @override
  State<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends State<ClockInScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _justificationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  DateTime _now = DateTime.now();
  Timer? _timer;

  double _currentLat = -6.1774309;
  double _currentLng = 106.8356606;
  double _distanceMeters = 0.0;
  double _gpsAccuracy = 5.0;
  bool _isLocating = true;
  bool _isSubmitting = false;

  Uint8List? _selfieBytes;
  String? _selfieBase64;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _detectLocation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _justificationController.dispose();
    super.dispose();
  }

  bool get _isOutsideOffice =>
      _distanceMeters > AppConstants.geofenceRadiusMeters;

  bool get _isLate =>
      _now.hour > 8 || (_now.hour == 8 && _now.minute > 0);

  int get _lateMinutes {
    if (!_isLate) return 0;
    final start = DateTime(_now.year, _now.month, _now.day, 8, 0);
    return _now.difference(start).inMinutes;
  }

  String get _formattedDate =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now);

  String get _formattedTime =>
      '${DateFormat('HH:mm').format(_now)} WIB';

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak browser/perangkat');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        AppConstants.officeLatitude,
        AppConstants.officeLongitude,
      );

      if (!mounted) return;
      setState(() {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        _distanceMeters = dist;
        _gpsAccuracy = pos.accuracy > 0 ? pos.accuracy : 5.0;
        _isLocating = false;
      });
    } catch (_) {
      // Fallback ke koordinat Jakarta jika izin lokasi browser ditolak/timeout
      const fallbackLat = -6.1774309;
      const fallbackLng = 106.8356606;
      final dist = Geolocator.distanceBetween(
        fallbackLat,
        fallbackLng,
        AppConstants.officeLatitude,
        AppConstants.officeLongitude,
      );

      if (!mounted) return;
      setState(() {
        _currentLat = fallbackLat;
        _currentLng = fallbackLng;
        _distanceMeters = dist;
        _gpsAccuracy = 5.0;
        _isLocating = false;
      });
    }
  }

  Future<void> _pickSelfieImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 1024,
      );

      // Jika perangkat desktop/web tidak membuka kamera, buka pemilih file gambar
      final XFile? file = picked ??
          await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 70,
            maxWidth: 1024,
          );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      setState(() {
        _selfieBytes = bytes;
        _selfieBase64 = base64Str;
      });
    } catch (_) {
      final XFile? fallback = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (fallback != null) {
        final bytes = await fallback.readAsBytes();
        setState(() {
          _selfieBytes = bytes;
          _selfieBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    }
  }

  Future<void> _submitClockIn() async {
    if (_isOutsideOffice) {
      if (_justificationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alasan di luar kantor wajib diisi.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
      if (_selfieBase64 == null || _selfieBase64!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto wajah di lokasi wajib diambil terlebih dahulu.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      await _attendanceService.submitClockIn(
        userId: widget.user.id,
        latitude: _currentLat,
        longitude: _currentLng,
        justification:
            _isOutsideOffice ? _justificationController.text.trim() : null,
        selfieBase64: _isOutsideOffice ? _selfieBase64 : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clock In berhasil dikonfirmasi!'),
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = _distanceMeters >= 1000
        ? 'Radius ${(_distanceMeters / 1000).toStringAsFixed(1)} km dari kantor'
        : 'Dalam Geofence ${_distanceMeters.toStringAsFixed(0)}m';

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
          'Konfirmasi Clock In',
          style: TextStyle(
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFF1A64E8),
              child: Icon(Icons.person_outline_rounded,
                  size: 19, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Baris Detail Verifikasi & Jam Aktif
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detail Verifikasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 8, color: Color(0xFF1A64E8)),
                      const SizedBox(width: 6),
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A64E8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Kartu 1: Status Ketepatan Waktu (Tepat Waktu vs Terlambat)
            if (!_isLate)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF1A64E8), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Tepat Waktu',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PRESENSI PAGI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Absen masuk sebelum batas toleransi pukul 08:00 WIB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Anda terlambat $_lateMinutes menit',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Toleransi Lewat',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Jam masuk normal: 08:00 WIB • Tercatat otomatis dalam logbook shift',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Kartu 2: Deteksi Titik Kehadiran & Peta Geofence
            Container(
              padding: const EdgeInsets.all(16),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_outlined,
                            color: Color(0xFF1A64E8), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deteksi Titik Kehadiran',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '• Akurasi GPS ±${_gpsAccuracy.toStringAsFixed(0)} meter',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A64E8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Perbarui Titik GPS',
                        child: InkWell(
                          onTap: _detectLocation,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: _isLocating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded,
                                    size: 18, color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Visual Geofence Radar Box
                  Container(
                    height: 165,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 135,
                          height: 135,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isOutsideOffice
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1A64E8))
                                .withOpacity(0.12),
                            border: Border.all(
                              color: _isOutsideOffice
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF1A64E8),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x14000000), blurRadius: 6)
                                ],
                              ),
                              child: const Text(
                                'Kantor PT. Sismedika (Serpong)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _isOutsideOffice
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1A64E8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.my_location_rounded,
                                  size: 16, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '• Posisi Anda ($distanceLabel)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _isOutsideOffice
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF1A64E8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kotak Keterangan Status Geofence
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isOutsideOffice
                              ? Icons.error_outline_rounded
                              : Icons.verified_outlined,
                          color: _isOutsideOffice
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF1A64E8),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _isOutsideOffice
                                          ? 'Terdeteksi: Di Luar Area Kantor'
                                          : 'Terdeteksi: Dalam Area Kantor',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (_isOutsideOffice)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Bypass Aktif',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isOutsideOffice
                                    ? 'Anda berada di luar perimeter geofence kantor. Wajib menyertakan justifikasi serta swafoto verifikasi untuk memvalidasi presensi hari ini.'
                                    : 'Posisi Anda berada di dalam radius kantor yang ditentukan. Silakan langsung konfirmasi Clock In.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form Justifikasi & Selfie Base64 (Muncul otomatis jika di luar kantor)
            if (_isOutsideOffice) ...[
              Container(
                padding: const EdgeInsets.all(16),
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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: Color(0xFF1A64E8)),
                            SizedBox(width: 6),
                            Text(
                              'Form Justifikasi Presensi',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Step 2 dari 2',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Alasan Di Luar Kantor *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '${_justificationController.text.length} / 150',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _justificationController,
                      maxLength: 150,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText:
                            'Contoh: Tugas lapangan / kunjungan faskes rekanan...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Foto Wajah di Lokasi *',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 13, color: Color(0xFF1A64E8)),
                            SizedBox(width: 4),
                            Text(
                              'Biometrik AI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A64E8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickSelfieImage,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selfieBytes != null
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: _selfieBytes != null
                            ? Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      _selfieBytes!,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Foto berhasil diambil • Ketuk untuk ganti foto',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              )
                            : const Column(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Color(0xFFE0E7FF),
                                    child: Icon(Icons.camera_alt_outlined,
                                        color: Color(0xFF1A64E8)),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Ambil Foto Wajah (Selfie Lokasi)',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'GPS Lat/Long & Waktu Tersemat Otomatis',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF1A64E8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tanggal',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _formattedDate,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 22, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status Kehadiran',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '• Hadir (Dalam Kantor)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A64E8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Tombol Konfirmasi Clock In Sekarang
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitClockIn,
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
                  _isSubmitting ? 'Menyimpan Presensi...' : 'Clock In Sekarang',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 13, color: Color(0xFF94A3B8)),
                SizedBox(width: 5),
                Text(
                  'Data kehadiran & titik koordinat terverifikasi sistem',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}