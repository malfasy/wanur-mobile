import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'quote_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const QuoteScreen(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Image.asset('assets/logo_aja.png',
                  errorBuilder: (c, o, s) => const Icon(Icons.back_hand, color: Colors.white, size: 48)),
            ),
            const SizedBox(height: 22),
            const Text('wanur',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
            const SizedBox(height: 4),
            const Text('REHABMEDICS',
                style: TextStyle(letterSpacing: 3, color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
