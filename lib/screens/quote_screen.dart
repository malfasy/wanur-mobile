import 'dart:async';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';

class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _next);
  }

  void _next() {
    if (_left || !mounted) return;
    _left = true;
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: Scaffold(
        backgroundColor: AppColors.dark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text('“', style: TextStyle(fontSize: 80, height: 0.8, color: AppColors.accent)),
                const Text(
                  'Kesehatan adalah harmoni sempurna antara tubuh dan jiwa.',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.8),
                ),
                const SizedBox(height: 20),
                const Text('ARISTOTELES',
                    style: TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(seconds: 3),
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('Ketuk untuk lanjut', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
