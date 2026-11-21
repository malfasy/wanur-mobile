import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Label kecil huruf kapital, misalnya "PROGRES · TANGAN KANAN".
class MicroLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const MicroLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
          color: color ?? AppColors.muted,
        ),
      );
}

/// Kartu putih standar.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = AppColors.surface,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Kartu gelap dengan gradasi, untuk ringkasan utama.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(22)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.dark, AppColors.dark2, Color(0xFF4A2A22)],
          stops: [0, 0.6, 1],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.dark.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
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
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.subColor,
    this.dark = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return AppCard(
      color: dark ? AppColors.dark : AppColors.surface,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MicroLabel(label, color: dark ? Colors.white54 : null),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: fg)),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!,
                    style: TextStyle(fontSize: 13, color: dark ? Colors.white60 : AppColors.inkSoft)),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subColor ?? (dark ? Colors.white54 : AppColors.muted))),
          ],
        ],
      ),
    );
  }
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
    this.size = 108,
    this.stroke = 9,
    this.color = AppColors.accent,
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

/// Tombol utama berbentuk pil.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dark;
  final bool outlined;
  final bool expand;
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dark = false,
    this.outlined = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.transparent : (dark ? AppColors.ink : AppColors.accent);
    final fg = outlined ? AppColors.ink : Colors.white;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
    return SizedBox(
      height: 54,
      width: expand ? double.infinity : null,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: AppColors.surfaceMuted,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: StadiumBorder(
              side: outlined ? const BorderSide(color: AppColors.line, width: 1.5) : BorderSide.none),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );
}

/// Kotak catatan berwarna lembut dengan titik penanda.
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

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
                width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (body != null) ...[
                const SizedBox(height: 4),
                Text(body!, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4)),
              ],
            ]),
          ),
        ]),
      );
}

/// Judul bagian dengan aksi opsional di kanan.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Row(children: [
          Expanded(
              child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
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
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? AppColors.accentSoft : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(Fmt.dayShort(date),
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: highlight ? AppColors.accentDeep : AppColors.muted)),
          const SizedBox(height: 2),
          Text('${date.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Catatan kaki wajib untuk setiap nilai gaya.
class ForceFootnote extends StatelessWidget {
  final Color color;
  const ForceFootnote({super.key, this.color = AppColors.muted});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text('* nilai relatif, belum dikalibrasi dengan dinamometer',
            style: TextStyle(fontSize: 11, color: color, fontStyle: FontStyle.italic)),
      );
}

/// Pilihan segmen (mis. periode 4 / 8 minggu / semua).
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (v, label) in items)
            GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: v == value ? AppColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: v == value ? Colors.white : AppColors.inkSoft)),
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
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.muted, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      );
}

/// Tombol ikon bulat di AppBar.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color bg;
  final Color fg;
  const RoundIconButton(this.icon,
      {super.key, this.onTap, this.tooltip, this.bg = AppColors.surface, this.fg = AppColors.ink});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: fg)),
          ),
        ),
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
    this.iconBg = AppColors.bg,
    this.iconFg = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconFg, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ),
            ]),
          ),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
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
    this.color = AppColors.ink,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14, fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500))),
            Text(trailing, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.limeSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.science_outlined, size: 16, color: AppColors.ink),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.ink))),
        ]),
      );
}
