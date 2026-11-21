import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Scaffold dengan latar biru muda bergradasi. Dipakai semua layar utama
/// supaya kartu semi-transparan dan navigasi kaca punya warna di belakangnya.
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final bool extendBody;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.extendBody = false,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AppBackdrop()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        extendBody: extendBody,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      ),
    ]);
  }
}

/// Gradasi latar dan dua bercak cahaya cyan.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bg, AppColors.bgBottom],
            ),
          ),
        ),
      ),
      Positioned(top: -120, right: -100, child: _blob(320, AppColors.accentBright, 0.30)),
      Positioned(bottom: 80, left: -140, child: _blob(300, const Color(0xFF8FD8F0), 0.22)),
    ]);
  }

  Widget _blob(double size, Color c, double a) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withValues(alpha: a), c.withValues(alpha: 0)]),
        ),
      );
}

/// Panel kaca dengan blur latar (dipakai hemat: navigasi bawah dan elemen
/// melayang, karena blur di banyak kartu memberatkan scroll).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color tint;
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.blur = 22,
    this.tint = const Color(0xB3FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(color: AppColors.dark.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: r,
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.15)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Label kecil monospace huruf kapital, misalnya "PROGRES · TANGAN KANAN".
class MicroLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final int? maxLines;
  const MicroLabel(this.text, {super.key, this.color, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: AppText.label.copyWith(color: color),
      );
}

/// Judul halaman: label kecil + judul dua warna ("Riwayat latihan").
class PageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? highlight;
  final Widget? trailing;
  final VoidCallback? onTitleTap;
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.highlight,
    this.trailing,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: MicroLabel(eyebrow)),
          if (trailing != null) trailing!,
        ]),
        SizedBox(height: trailing == null ? 6 : 2),
        GestureDetector(
          onTap: onTitleTap,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: title, style: const TextStyle(color: AppColors.ink)),
              if (highlight != null)
                TextSpan(text: ' $highlight', style: const TextStyle(color: AppColors.accentDeep)),
            ]),
            style: AppText.title,
          ),
        ),
      ]),
    );
  }
}

/// Kartu putih semi-transparan standar.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color = AppColors.glass,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: r,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(color: AppColors.dark.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Kartu sorotan bergradasi biru tua ke cyan.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: AppColors.heroGradient,
        boxShadow: [
          BoxShadow(color: AppColors.accentDeep.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(children: [
          // kilau kaca di pojok kanan atas
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)]),
              ),
            ),
          ),
          Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: child,
          ),
        ]),
      ),
    );
  }
}

/// Satu angka utama dengan label dan keterangan kecil.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Color? subColor;
  final bool dark;
  final VoidCallback? onTap;
  final IconData? icon;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.subColor,
    this.dark = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(child: MicroLabel(label, color: dark ? Colors.white70 : null)),
          if (icon != null) Icon(icon, size: 16, color: dark ? Colors.white70 : AppColors.accent),
        ]),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: fg)),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: dark ? Colors.white70 : AppColors.inkSoft)),
              ),
            ],
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 3),
          Text(sub!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: subColor ?? (dark ? Colors.white70 : AppColors.muted))),
        ],
      ],
    );
    if (dark) {
      return GestureDetector(
        onTap: onTap,
        child: HeroCard(padding: const EdgeInsets.all(14), radius: 18, child: content),
      );
    }
    return AppCard(onTap: onTap, child: content);
  }
}

/// Dua kartu sejajar dengan tinggi sama.
class TileRow extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const TileRow({super.key, required this.children, this.gap = 10});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ],
        ]),
      );
}

/// Cincin progres dengan teks di tengah (mis. "3/5").
class RingProgress extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? center;
  const RingProgress({
    super.key,
    required this.value,
    this.size = 84,
    this.stroke = 8,
    this.color = Colors.white,
    this.track = const Color(0x33FFFFFF),
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0.0, 1.0).toDouble(), stroke, color, track),
        child: Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color color;
  final Color track;
  _RingPainter(this.v, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, bg);
    if (v <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.v != v || old.color != color || old.track != track;
}

/// Tombol utama. Varian: cyan (default), [dark] biru tua, [light] putih
/// (untuk di atas kartu sorotan), [outlined] kaca bergaris.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dark;
  final bool outlined;
  final bool light;
  final bool expand;
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dark = false,
    this.outlined = false,
    this.light = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (outlined) {
      bg = AppColors.glass;
      fg = AppColors.ink;
    } else if (light) {
      bg = Colors.white;
      fg = AppColors.accentDeep;
    } else if (dark) {
      bg = AppColors.dark;
      fg = Colors.white;
    } else {
      bg = AppColors.accent;
      fg = Colors.white;
    }
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14.5)),
        ),
      ],
    );
    return SizedBox(
      height: 46,
      width: expand ? double.infinity : null,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: AppColors.surfaceMuted,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: outlined ? const BorderSide(color: AppColors.line, width: 1.2) : BorderSide.none,
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

/// Chip kecil.
class Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const Tag(this.text, {super.key, this.bg = AppColors.surfaceMuted, this.fg = AppColors.inkSoft, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );
}

/// Kotak catatan berwarna lembut dengan titik penanda. [Callout.warning] untuk
/// peringatan (kuning), selain itu info (cyan).
class Callout extends StatelessWidget {
  final String title;
  final String? body;
  final Color bg;
  final Color dot;
  const Callout({
    super.key,
    required this.title,
    this.body,
    this.bg = AppColors.accentSoft,
    this.dot = AppColors.accent,
  });

  const Callout.warning({super.key, required this.title, this.body})
      : bg = AppColors.warningSoft,
        dot = AppColors.warning;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
                width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              if (body != null) ...[
                const SizedBox(height: 3),
                Text(body!, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.35)),
              ],
            ]),
          ),
        ]),
      );
}

/// Label bagian (monospace huruf kapital) dengan aksi opsional di kanan.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Row(children: [
          Expanded(child: MicroLabel(title)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
            ),
        ]),
      );
}

/// Kotak tanggal kecil ("SEN / 13").
class DateTile extends StatelessWidget {
  final DateTime date;
  final bool highlight;
  const DateTile(this.date, {super.key, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: highlight ? AppColors.accentSoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(Fmt.dayShort(date),
              style: AppText.label.copyWith(
                  fontSize: 9.5, letterSpacing: 1, color: highlight ? AppColors.accentDeep : AppColors.muted)),
          const SizedBox(height: 1),
          Text('${date.day}', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Catatan kaki wajib untuk setiap nilai gaya.
class ForceFootnote extends StatelessWidget {
  final Color color;
  const ForceFootnote({super.key, this.color = AppColors.muted});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Text('* nilai relatif, belum dikalibrasi dengan dinamometer',
            style: TextStyle(fontSize: 10.5, color: color, fontStyle: FontStyle.italic)),
      );
}

/// Pilihan segmen (mis. periode 4 / 8 minggu / semua). Mengisi lebar penuh.
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white),
        ),
        child: Row(children: [
          for (final (v, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: v == value ? Colors.white : AppColors.inkSoft)),
                ),
              ),
            ),
        ]),
      );
}

/// Tampilan kosong.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.accentDeep, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(body!, textAlign: TextAlign.center, style: AppText.small.copyWith(height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Tombol ikon bulat.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color bg;
  final Color fg;
  final double size;
  const RoundIconButton(this.icon,
      {super.key,
      this.onTap,
      this.tooltip,
      this.bg = AppColors.glass,
      this.fg = AppColors.ink,
      this.size = 40});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: bg,
          shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.9))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Icon(icon, size: 19, color: fg)),
          ),
        ),
      );
}

/// Ikon di kotak cyan muda.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;
  const IconBadge(this.icon,
      {super.key, this.size = 36, this.bg = AppColors.accentSoft, this.fg = AppColors.accentDeep});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: fg, size: size * 0.52),
      );
}

/// Baris menu (ikon, judul, keterangan, panah).
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final Color iconBg;
  final Color iconFg;
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconBg = AppColors.accentSoft,
    this.iconFg = AppColors.accentDeep,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          IconBadge(icon, bg: iconBg, fg: iconFg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
                ),
            ]),
          ),
          if (trailing != null) Text(trailing!, style: AppText.small),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
        ]),
      );
}

/// Ubin menu kecil untuk grid 2 kolom (ikon, judul, keterangan monospace).
class QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const QuickTile({super.key, required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(height: 14),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          const SizedBox(height: 3),
          MicroLabel(subtitle),
        ]),
      );
}

/// Batang horizontal sederhana untuk persentase.
class PercentBar extends StatelessWidget {
  final String label;
  final double pct; // 0..100
  final String trailing;
  final Color color;
  final bool emphasize;
  const PercentBar({
    super.key,
    required this.label,
    required this.pct,
    required this.trailing,
    this.color = AppColors.accent,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 13.5, fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500))),
            Text(trailing,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                    color: emphasize ? AppColors.accentDeep : AppColors.inkSoft)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      );
}

/// Pita "Mode simulasi" supaya data simulasi tidak tertukar dengan data nyata.
class SimBanner extends StatelessWidget {
  final String text;
  const SimBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.limeSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.science_outlined, size: 14, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: AppColors.success, fontSize: 10))),
        ]),
      );
}

/// Kartu grafik: judul monospace + isi.
class ChartCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const ChartCard({super.key, required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: MicroLabel(title, color: AppColors.inkSoft)),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}
