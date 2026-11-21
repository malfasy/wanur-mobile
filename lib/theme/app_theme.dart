import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

/// Palet dan tipografi Wanur. Arah visual: latar biru muda bergradasi, kartu
/// putih semi-transparan (kesan kaca), aksen cyan, kartu sorotan biru tua ke
/// cyan, label kecil monospace huruf kapital, navigasi bawah kaca.
class AppColors {
  // Latar
  static const bg = Color(0xFFEAF2F6);
  static const bgTop = Color(0xFFE4F3F9);
  static const bgBottom = Color(0xFFDCE9F1);
  // Permukaan
  static const surface = Color(0xFFFFFFFF);
  static const glass = Color(0xD9FFFFFF); // putih 85%
  static const surfaceMuted = Color(0xFFEAF1F5);
  static const line = Color(0xFFDDE7ED);
  // Teks
  static const ink = Color(0xFF0F1D26);
  static const inkSoft = Color(0xFF4B5D69);
  static const muted = Color(0xFF8798A4);
  // Biru tua (kartu sorotan, teks di atas cyan)
  static const dark = Color(0xFF0C3A52);
  static const dark2 = Color(0xFF1C5877);
  // Aksen cyan Wanur
  static const accent = Color(0xFF1AB3DD);
  static const accentBright = Color(0xFF4CD3F2);
  static const accentDeep = Color(0xFF0B7FA6);
  static const accentSoft = Color(0xFFDDF3FA);
  // Status
  static const lime = Color(0xFF7FE0C4);
  static const limeSoft = Color(0xFFE1F6EF);
  static const success = Color(0xFF16996B);
  static const successSoft = Color(0xFFDDF3EA);
  static const warning = Color(0xFFDB8A12);
  static const warningSoft = Color(0xFFFCF0DA);
  static const danger = Color(0xFFDF3B57);

  /// Warna per jari: telunjuk, tengah, manis, kelingking.
  static const fingers = [Color(0xFF1AB3DD), Color(0xFF0C3A52), Color(0xFF6E8FA2), Color(0xFFA9CFDF)];

  /// Gradasi kartu sorotan (hero, statistik utama).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C3A52), Color(0xFF12698F), Color(0xFF1FB4DC)],
    stops: [0, 0.55, 1],
  );
}

/// Gaya teks bersama.
class AppText {
  static const body = 'PlusJakartaSans';
  static const display = 'SpaceGrotesk';
  static const mono = 'SpaceMono';
  static const label = TextStyle(
      fontFamily: mono, fontSize: 10.5, letterSpacing: 0.9, fontWeight: FontWeight.w400, color: AppColors.muted);
  static const title = TextStyle(
      fontFamily: display, fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.9, height: 1.12);
  static const cardTitle =
      TextStyle(fontFamily: display, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static const bodyText = TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.35);
  static const small = TextStyle(fontSize: 12, color: AppColors.muted);
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
      fontFamily: AppText.body,
    );
    final t = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    return base.copyWith(
      textTheme: t.copyWith(
        displayLarge: t.displayLarge
            ?.copyWith(fontFamily: AppText.display, fontWeight: FontWeight.w700, letterSpacing: -2),
        headlineLarge: t.headlineLarge
            ?.copyWith(fontFamily: AppText.display, fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineMedium: t.headlineMedium
            ?.copyWith(fontFamily: AppText.display, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        titleLarge: t.titleLarge?.copyWith(fontFamily: AppText.display, fontWeight: FontWeight.w700),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
            color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: AppText.display),
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
            (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surfaceMuted),
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
