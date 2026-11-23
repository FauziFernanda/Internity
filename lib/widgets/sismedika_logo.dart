import 'package:flutter/material.dart';

class SismedikaLogo extends StatelessWidget {
  final double size;

  const SismedikaLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_sismedika.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return CustomPaint(
          size: Size(size, size),
          painter: _SismedikaLogoPainter(),
        );
      },
    );
  }
}

class _SismedikaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0044A9)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // 1. Lengkungan sabit di bagian atas logo
    final arcPath = Path()
      ..moveTo(w * 0.14, h * 0.50)
      ..cubicTo(
        w * 0.16, h * 0.16,
        w * 0.54, h * 0.04,
        w * 0.78, h * 0.19,
      )
      ..quadraticBezierTo(w * 0.81, h * 0.22, w * 0.77, h * 0.23)
      ..cubicTo(
        w * 0.54, h * 0.11,
        w * 0.23, h * 0.22,
        w * 0.15, h * 0.51,
      )
      ..close();
    canvas.drawPath(arcPath, paint);

    // 2. Titik bulat huruf "i"
    canvas.drawCircle(
      Offset(w * 0.51, h * 0.36),
      w * 0.115,
      paint,
    );

    // 3. Batang vertikal huruf "i" dengan potongan melengkung di atas
    final stemPath = Path()
      ..moveTo(w * 0.43, h * 0.53)
      ..quadraticBezierTo(w * 0.51, h * 0.54, w * 0.59, h * 0.51)
      ..lineTo(w * 0.59, h * 0.81)
      ..arcToPoint(
        Offset(w * 0.43, h * 0.81),
        radius: Radius.circular(w * 0.08),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(stemPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}