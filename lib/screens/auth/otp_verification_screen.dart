import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/sismedika_logo.dart';
import '../admin/management_user_screen.dart';
import 'login_screen.dart';
import '../intern/absensi_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final int expiresInSeconds;
  final String? devOtp;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.expiresInSeconds = 300,
    this.devOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final AuthService _authService = AuthService();

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _countdownTimer;
  late int _remainingSeconds;
  String? _currentDevOtp;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.expiresInSeconds;
    _currentDevOtp = widget.devOtp;
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remainingSeconds = 0);
      } else {
        if (mounted) setState(() => _remainingSeconds--);
      }
    });
  }

  String get _formattedTimer {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _fillOtp(String code) {
    final clean = code.replaceAll(RegExp(r'\D'), '');
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = i < clean.length ? clean[i] : '';
    }
    if (clean.length >= 6) {
      _focusNodes[5].unfocus();
      _verifyOtp();
    } else if (clean.isNotEmpty) {
      _focusNodes[clean.length].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Masukkan 6 digit kode OTP secara lengkap.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final UserModel user = await _authService.verifyOtp(
        email: widget.email,
        otp: code,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang, ${user.namaLengkap} (${user.role})!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      // Arahkan halaman berdasarkan role pengguna
      Widget destination;
      if (user.role == 'Admin') {
        destination = const ManagementUserScreen();
      } else if (user.role == 'Intern') {
        destination = AbsensiScreen(user: user);
      } else {
        destination = _RoleHomePlaceholderScreen(user: user);
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final isCancelled = msg.contains('dibatalkan') || msg.contains('terlampaui');

      if (isCancelled) {
        _countdownTimer?.cancel();
        for (final c in _controllers) {
          c.clear();
        }
      }

      setState(() {
        _errorMessage = msg;
        if (isCancelled) {
          _remainingSeconds = 0;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.requestOtp(widget.email);
      if (!mounted) return;

      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      setState(() {
        _remainingSeconds = result.expiresIn;
        _currentDevOtp = result.devOtp;
      });
      _startTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode OTP baru telah dikirim ke email Anda.'),
          backgroundColor: Color(0xFF1A64E8),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // Logo Box
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x100F172A),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(child: SismedikaLogo(size: 42)),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Verifikasi Kode OTP',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Masukkan 6 digit kode verifikasi yang telah dikirim ke\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Banner Mode Pengujian (Muncul hanya jika SMTP_ENABLED = false di PHP)
                  if (_currentDevOtp != null && _currentDevOtp!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.developer_mode_rounded,
                              size: 18, color: Color(0xFF1A64E8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mode Dev OTP: $_currentDevOtp',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _fillOtp(_currentDevOtp!),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Isi Otomatis',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A64E8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Kartu 6 Kotak OTP
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 44,
                              height: 54,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1A64E8),
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val.length > 1) {
                                    _fillOtp(val);
                                    return;
                                  }
                                  if (val.isNotEmpty && index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else if (val.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                  if (_otpCode.length == 6) {
                                    _verifyOtp();
                                  }
                                  setState(() {});
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),

                        // Timer Masa Berlaku OTP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: _remainingSeconds > 0
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _remainingSeconds > 0
                                  ? 'Kode berlaku selama $_formattedTimer'
                                  : 'Kode OTP telah kedaluwarsa',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _remainingSeconds > 0
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Tombol Verifikasi
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isVerifying ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A64E8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: _isVerifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.verified_rounded, size: 20),
                            label: Text(
                              _isVerifying ? 'Memverifikasi...' : 'Verifikasi & Masuk',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        // Error Alert Box
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_rounded,
                                    color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tombol Kirim Ulang OTP
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Tidak menerima kode? ',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isResending ? 'Mengirim...' : 'Kirim Ulang OTP',
                          style: const TextStyle(
                            fontSize: 13,
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
          ),
        ),
      ),
    );
  }
}

/// Layar sementara untuk Role Intern & HRD sebelum modul Absensi & Laporan dibuat
class _RoleHomePlaceholderScreen extends StatelessWidget {
  final UserModel user;

  const _RoleHomePlaceholderScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Beranda ${user.role}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 56),
              const SizedBox(height: 12),
              Text(
                'Login Berhasil sebagai ${user.role}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${user.namaLengkap} (${user.email})',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Halaman utama untuk role ini akan dibuat pada modul berikutnya.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}