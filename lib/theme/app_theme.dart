import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

/// Palet dan tipografi Wanur. Arah visual: latar krem hangat, kartu putih
/// lembut, kartu "hero" gelap, aksen oranye-merah, angka besar sebagai fokus,
/// label kecil huruf kapital, navigasi bawah berbentuk pil.
class AppColors {
  static const bg = Color(0xFFF3F1ED);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFECE9E3);
  static const line = Color(0xFFE4E0D9);
  static const ink = Color(0xFF17191E);
  static const inkSoft = Color(0xFF545A64);
  static const muted = Color(0xFF8F949D);
  static const dark = Color(0xFF1C2026);
  static const dark2 = Color(0xFF2C3139);
  static const accent = Color(0xFFE4572E);
  static const accentDeep = Color(0xFFC9431D);
  static const accentSoft = Color(0xFFFBE5DC);
  static const lime = Color(0xFFDDEB5C);
  static const limeSoft = Color(0xFFF2F7C9);
  static const success = Color(0xFF2F7D5B);
  static const successSoft = Color(0xFFDDEFE6);
  static const warning = Color(0xFFD9821E);

  /// Warna per jari: telunjuk, tengah, manis, kelingking.
  static const fingers = [Color(0xFFE4572E), Color(0xFF2C3139), Color(0xFF8F949D), Color(0xFFC7B9A6)];
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.dark,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
    );
    final t = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    return base.copyWith(
      textTheme: t.copyWith(
        displayLarge: t.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -2),
        headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
            color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.dark,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.surfaceMuted),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

/// Format angka dan tanggal bahasa Indonesia.
class Fmt {
  static final _d1 = NumberFormat('#,##0.0', 'id');
  static final _d0 = NumberFormat('#,##0', 'id');

  static String n1(num? v) => v == null ? '–' : _d1.format(v);
  static String n0(num? v) => v == null ? '–' : _d0.format(v);

  static String pct(num? v, {bool signed = false}) {
    if (v == null) return '–';
    final s = _d0.format(v.round());
    return signed && v > 0 ? '+$s%' : '$s%';
  }

  static String kg(num? v) => v == null ? '–' : '${_d1.format(v)} kg*';

  static String dayShort(DateTime d) => DateFormat('EEE', 'id').format(d).toUpperCase();
  static String date(DateTime d) => DateFormat('d MMM yyyy', 'id').format(d);
  static String dateShort(DateTime d) => DateFormat('d MMM', 'id').format(d);
  static String dayDate(DateTime d) => DateFormat('EEEE, d MMM', 'id').format(d);
  static String time(DateTime d) => DateFormat('HH.mm', 'id').format(d);

  static String weekRange(DateTime weekStart) {
    final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    if (weekStart.month == end.month) {
      return '${weekStart.day}–${DateFormat('d MMM', 'id').format(end)}';
    }
    return '${dateShort(weekStart)} – ${dateShort(end)}';
  }

  static String duration(int ms) {
    final totalS = (ms / 1000).round();
    final h = totalS ~/ 3600;
    final m = (totalS % 3600) ~/ 60;
    final s = totalS % 60;
    if (h > 0) return '$h j $m mnt';
    if (m > 0) return '$m mnt ${s.toString().padLeft(2, '0')} dtk';
    return '$s dtk';
  }

  static String clock(int ms) {
    final totalS = (ms / 1000).floor();
    final m = totalS ~/ 60;
    final s = totalS % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
