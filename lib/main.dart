import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/user_model.dart';
import 'screens/admin/management_user_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const SismedikaInternApp());
}

class SismedikaInternApp extends StatelessWidget {
  const SismedikaInternApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SISMEDIKA Intern',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A64E8)),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: AuthService().getSavedUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6F8FB),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1A64E8)),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null && user.role == 'Admin') {
          return const ManagementUserScreen();
        }
        return const LoginScreen();
      },
    );
  }
}