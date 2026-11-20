import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Latar layar kalibrasi: gradasi gelap (selaras dengan kartu hero) dan
/// ilustrasi tangan di tengah. Posisi tangan tetap sama dengan versi lama
/// supaya badge huruf di atas jari tetap pas.
class CalibrationBaseLayout extends StatelessWidget {
  final Widget child;

  /// Dipertahankan untuk kompatibilitas. Latar robot lama tidak dipakai lagi;
  /// semua layar kalibrasi memakai latar gelap yang sama.
  final bool useRobotBackground;

  const CalibrationBaseLayout({
    super.key,
    required this.child,
    this.useRobotBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.dark, AppColors.dark2, Color(0xFF3A2620)],
                stops: [0, 0.65, 1],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.2),
            child: Image.asset(
              'assets/tangan.png',
              height: 380,
              fit: BoxFit.contain,
              errorBuilder: (c, o, s) => const Icon(Icons.back_hand, size: 200, color: Colors.white24),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
