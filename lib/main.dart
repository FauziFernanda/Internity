import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/admin/management_user_screen.dart';

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
      home: const ManagementUserScreen(),
    );
  }
}