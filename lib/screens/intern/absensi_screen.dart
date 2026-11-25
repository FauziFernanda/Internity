import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../auth/login_screen.dart';
import 'add_task_screen.dart';
import 'clock_in_screen.dart';
import 'izin_cuti_screen.dart';

class AbsensiScreen extends StatefulWidget {
  final UserModel user;

  const AbsensiScreen({super.key, required this.user});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final TaskService _taskService = TaskService();

  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  int _selectedNavIndex = 0;

  bool _isLoading = true;
  bool _isClockingOut = false;
  AttendanceRecord? _todayRecord;
  List<AttendanceRecord> _logs = [];

  bool _isLoadingTasks = false;
  List<DailyTaskModel> _tasks = [];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = DateTime.now();
      final isNewDay = current.day != _now.day ||
          current.month != _now.month ||
          current.year != _now.year;
      setState(() => _now = current);
      if (isNewDay) {
        _loadAttendance();
        _loadTasks();
      }
    });
    _loadAttendance();
    _loadTasks();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  bool get _hasClockedOutToday {
    if (_todayRecord == null) return false;
    final todayIso = DateFormat('yyyy-MM-dd').format(_now);
    final isTodayRecord = _todayRecord!.attendanceDate == todayIso;
    final hasClockedOut = _todayRecord!.clockOutTime != null &&
        _todayRecord!.clockOutTime!.trim().isNotEmpty;
    return isTodayRecord && hasClockedOut;
  }

  bool get _hasSubmittedTaskToday {
    final todayIso = DateFormat('yyyy-MM-dd').format(_now);
    return _tasks.any((t) => t.taskDate == todayIso);
  }

  bool get _canAddTaskToday => _hasClockedOutToday && !_hasSubmittedTaskToday;

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _attendanceService.getTodaySummary(widget.user.id);
      if (!mounted) return;
      setState(() {
        _todayRecord = summary.today;
        _logs = summary.logs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      final items = await _taskService.getTasks(widget.user.id);
      if (!mounted) return;
      setState(() => _tasks = items);
    } catch (_) {
      // Abaikan sementara jika gagal memuat
    } finally {
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  String get _formattedIndonesianDate =>
      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now);

  String get _formattedDigitalClock =>
      DateFormat('HH:mm:ss').format(_now);

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Logout',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari aplikasi?',
          style: TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Ya, Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddTaskForm() async {
    if (!_canAddTaskToday) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(user: widget.user),
      ),
    );

    if (!mounted) return;
    await _loadTasks();
    if (saved == true) {
      setState(() {
        _selectedNavIndex = 1; // Alihkan langsung ke menu List Task
      });
    } else {
      _loadAttendance();
    }
  }

  Future<void> _handleMainAbsenButton() async {
    if (_todayRecord != null &&
        (_todayRecord!.status == 'Izin' ||
            _todayRecord!.status == 'Sakit' ||
            _todayRecord!.status == 'Alfa')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Status kehadiran Anda hari ini sudah tercatat: ${_todayRecord!.status}.'),
          backgroundColor: _todayRecord!.status == 'Alfa'
              ? const Color(0xFFDC2626)
              : const Color(0xFF1A64E8),
        ),
      );
      return;
    }

    if (_todayRecord == null || _todayRecord!.clockInTime == null) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClockInScreen(user: widget.user),
        ),
      );
      if (result == true) {
        _loadAttendance();
      }
      return;
    }

    if (_todayRecord!.clockOutTime == null) {
      final currentMinute = DateFormat('HH:mm').format(_now);

      if (_now.hour < 17) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time_filled_rounded,
                color: Color(0xFFD97706),
                size: 28,
              ),
            ),
            title: const Text(
              'Belum Jam Pulang',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            content: Text(
              'Saat ini masih pukul $currentMinute WIB.\nClock Out hanya dapat dilakukan setelah jam kerja berakhir pada pukul 17:00 WIB.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A64E8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Clock Out',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('Catat jam pulang sekarang ($currentMinute WIB)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A64E8),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Clock Out'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isClockingOut = true);
        try {
          await _attendanceService.submitClockOut(widget.user.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Clock Out berhasil dicatat! Tombol + Tugas Hari Ini kini aktif.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          await _loadAttendance();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        } finally {
          if (mounted) setState(() => _isClockingOut = false);
        }
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Presensi masuk dan pulang hari ini sudah lengkap.'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  void _showDailyLogsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Log Kehadiran Harian',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Riwayat presensi masuk, pulang, dan pengajuan izin',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada riwayat kehadiran.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            controller: controller,
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, idx) {
                              final item = _logs[idx];
                              final isNoClockIn = item.status == 'Izin' ||
                                  item.status == 'Sakit' ||
                                  item.status == 'Alfa';

                              final Color badgeColor;
                              if (item.status == 'Tepat Waktu') {
                                badgeColor = const Color(0xFF16A34A);
                              } else if (item.status == 'Terlambat') {
                                badgeColor = const Color(0xFFD97706);
                              } else if (item.status == 'Alfa') {
                                badgeColor = const Color(0xFFDC2626);
                              } else {
                                badgeColor = const Color(0xFF1A64E8);
                              }

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.attendanceDate,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.status == 'Alfa'
                                              ? 'Tidak hadir tanpa keterangan'
                                              : isNoClockIn
                                                  ? 'Pengajuan ${item.status}'
                                                  : 'Masuk: ${item.clockInTime?.substring(0, 5) ?? '--:--'} • Pulang: ${item.clockOutTime?.substring(0, 5) ?? '--:--'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        item.status,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasClockedIn = _todayRecord?.clockInTime != null;
    final bool hasClockedOut = _todayRecord?.clockOutTime != null;
    final bool isLeaveOrAlfaToday = _todayRecord?.status == 'Izin' ||
        _todayRecord?.status == 'Sakit' ||
        _todayRecord?.status == 'Alfa';

    String buttonTitle = 'Absen';
    String buttonHint = 'Klik tombol untuk verifikasi lokasi & Clock In';
    if (isLeaveOrAlfaToday) {
      buttonTitle = _todayRecord!.status;
      buttonHint = _todayRecord!.status == 'Alfa'
          ? 'Tercatat tidak hadir tanpa keterangan hari ini'
          : 'Status ketidakhadiran hari ini telah tercatat';
    } else if (hasClockedIn && !hasClockedOut) {
      buttonTitle = 'Pulang';
      buttonHint = 'Klik tombol untuk mencatat jam pulang (Clock Out)';
    } else if (hasClockedIn && hasClockedOut) {
      buttonTitle = 'Selesai';
      buttonHint = 'Presensi masuk & pulang hari ini telah lengkap';
    }

    final Color jamMasukBadgeBg;
    final Color jamMasukBadgeFg;
    if (_todayRecord == null || _todayRecord!.status == 'Alfa') {
      jamMasukBadgeBg = const Color(0xFFFEE2E2);
      jamMasukBadgeFg = const Color(0xFFDC2626);
    } else if (_todayRecord!.status == 'Tepat Waktu') {
      jamMasukBadgeBg = const Color(0xFFDCFCE7);
      jamMasukBadgeFg = const Color(0xFF16A34A);
    } else if (_todayRecord!.status == 'Terlambat') {
      jamMasukBadgeBg = const Color(0xFFFEF3C7);
      jamMasukBadgeFg = const Color(0xFFD97706);
    } else {
      jamMasukBadgeBg = const Color(0xFFE0E7FF);
      jamMasukBadgeFg = const Color(0xFF1A64E8);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: _selectedNavIndex == 1
            ? _buildListTaskTab()
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadAttendance();
                  await _loadTasks();
                },
                color: const Color(0xFF1A64E8),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(
                    children: [
                      // Header: Nama User + Badge Intern + Tombol Logout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      'Halo, ${widget.user.namaLengkap}',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        widget.user.role,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A64E8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Clinical Informatics • RS SISMEDIKA',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showLogoutDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.logout_rounded,
                                      size: 16, color: Color(0xFFDC2626)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Kartu Tanggal & Jam Digital Realtime
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A0F172A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 15, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  _formattedIndonesianDate,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  _formattedDigitalClock,
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'WIB',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 14, color: Color(0xFF1A64E8)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Jam Kerja: 08:00 – 17:00 WIB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Tombol Bulat Utama "Absen" / "Pulang"
                      GestureDetector(
                        onTap: (_isLoading || _isClockingOut)
                            ? null
                            : _handleMainAbsenButton,
                        child: Container(
                          width: 205,
                          height: 205,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_todayRecord?.status == 'Alfa'
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF1A64E8))
                                .withOpacity(0.08),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_todayRecord?.status == 'Alfa'
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF1A64E8))
                                  .withOpacity(0.14),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _todayRecord?.status == 'Alfa'
                                      ? [
                                          const Color(0xFFEF4444),
                                          const Color(0xFFB91C1C)
                                        ]
                                      : hasClockedIn && hasClockedOut
                                          ? [
                                              const Color(0xFF16A34A),
                                              const Color(0xFF15803D)
                                            ]
                                          : [
                                              const Color(0xFF3B82F6),
                                              const Color(0xFF1D4ED8)
                                            ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_todayRecord?.status == 'Alfa'
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF1A64E8))
                                        .withOpacity(0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: _isClockingOut
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _todayRecord?.status == 'Alfa'
                                              ? Icons.event_busy_rounded
                                              : Icons.fingerprint_rounded,
                                          size: 54,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          buttonTitle,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app_outlined,
                              size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              buttonHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tombol "Izin Cuti"
                      SizedBox(
                        width: 240,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final submitted = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IzinCutiScreen(user: widget.user),
                              ),
                            );
                            if (submitted == true) {
                              _loadAttendance();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.event_busy_outlined,
                              size: 19, color: Color(0xFF334155)),
                          label: const Text(
                            'Izin Cuti',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Kartu Ringkasan Kehadiran Hari Ini
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A0F172A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'RINGKASAN KEHADIRAN HARI INI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                InkWell(
                                  onTap: _showDailyLogsSheet,
                                  child: const Row(
                                    children: [
                                      Icon(Icons.history_rounded,
                                          size: 15, color: Color(0xFF1A64E8)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Log Harian',
                                        style: TextStyle(
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
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryBox(
                                    icon: Icons.login_rounded,
                                    iconColor: const Color(0xFF1A64E8),
                                    label: 'Jam Masuk',
                                    timeText: isLeaveOrAlfaToday
                                        ? _todayRecord!.status
                                        : (_todayRecord?.clockInTime != null
                                            ? _todayRecord!.clockInTime!
                                                .substring(0, 5)
                                            : '-- : --'),
                                    badgeText: _todayRecord == null
                                        ? 'Belum Absen'
                                        : _todayRecord!.status,
                                    badgeBg: jamMasukBadgeBg,
                                    badgeFg: jamMasukBadgeFg,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSummaryBox(
                                    icon: Icons.logout_rounded,
                                    iconColor: const Color(0xFF64748B),
                                    label: 'Jam Pulang',
                                    timeText: _todayRecord?.clockOutTime != null
                                        ? _todayRecord!.clockOutTime!
                                            .substring(0, 5)
                                        : '-- : --',
                                    badgeText: _todayRecord?.clockOutTime != null
                                        ? 'Selesai'
                                        : (isLeaveOrAlfaToday
                                            ? '-'
                                            : 'Menunggu'),
                                    badgeBg: _todayRecord?.clockOutTime != null
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFE2E8F0),
                                    badgeFg: _todayRecord?.clockOutTime != null
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tombol "+ Tugas Hari Ini" (3 Status: Nonaktif -> Aktif -> Selesai)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _canAddTaskToday ? _openAddTaskForm : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A64E8),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _hasSubmittedTaskToday
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFE2E8F0),
                            disabledForegroundColor: _hasSubmittedTaskToday
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: Icon(
                            _hasSubmittedTaskToday
                                ? Icons.check_circle_rounded
                                : Icons.add_rounded,
                            size: 22,
                          ),
                          label: Text(
                            _hasSubmittedTaskToday
                                ? 'Tugas Hari Ini Selesai'
                                : '+ Tugas Hari Ini',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hasSubmittedTaskToday
                            ? 'Laporan tugas hari ini telah tersimpan (reset pukul 00:00 WIB)'
                            : _canAddTaskToday
                                ? 'Batas pengisian tugas hingga pukul 23:59 WIB hari ini'
                                : 'Tombol aktif setelah Anda melakukan Clock Out',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: _hasSubmittedTaskToday
                              ? const Color(0xFF16A34A)
                              : _canAddTaskToday
                                  ? const Color(0xFF1A64E8)
                                  : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() => _selectedNavIndex = index);
          if (index == 1) {
            _loadTasks();
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1A64E8),
        unselectedItemColor: const Color(0xFF64748B),
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_rounded),
            label: 'Absensi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_rounded),
            label: 'List Task',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String timeText,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timeText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTaskTab() {
    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: const Color(0xFF1A64E8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'List Task Harian',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Catatan pekerjaan harian rotasi intern',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (_canAddTaskToday)
                  ElevatedButton.icon(
                    onPressed: _openAddTaskForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A64E8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Tugas',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingTasks
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A64E8)),
                  )
                : _tasks.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32),
                        children: const [
                          SizedBox(height: 60),
                          Icon(Icons.checklist_rounded,
                              size: 56, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 12),
                          Text(
                            'Belum Ada Tugas Tercatat',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tombol "+ Tugas Hari Ini" di halaman Absensi akan aktif setelah Anda melakukan Clock Out.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, idx) {
                          final task = _tasks[idx];
                          return _buildTaskCard(task);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DailyTaskModel task) {
    final bool hasDoc =
        task.attachmentName != null && task.attachmentName!.isNotEmpty;
    final bool isPdf =
        (task.attachmentName ?? '').toLowerCase().endsWith('.pdf');

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: Color(0xFF1A64E8)),
                    const SizedBox(width: 5),
                    Text(
                      task.taskDate,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A64E8),
                      ),
                    ),
                  ],
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 15, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text(
                    'Tersimpan',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            task.description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
          if (hasDoc) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.description_rounded,
                    size: 20,
                    color: isPdf
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.attachmentName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}