import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/data_source_controller.dart';
import '../logic/indicators.dart';
import '../models/training_models.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'finger_distribution_screen.dart';
import 'therapist_summary_screen.dart';

class ProgressData {
  final String scope;
  final DateTime refNow;
  final List<WeeklySummaryRow> weeks;
  final List<GripTestRow> grips;
  final int currentTarget;
  const ProgressData(this.scope, this.refNow, this.weeks, this.grips, this.currentTarget);

  WeeklySummaryRow? get thisWeek {
    final ws = weekStartMs(refNow.millisecondsSinceEpoch);
    for (final w in weeks.reversed) {
      if (w.weekStartMs == ws) return w;
    }
    return null;
  }

  GripTestRow? get lastGrip => grips.isEmpty ? null : grips.last;
}

Future<ProgressData> loadProgressData(String scope) async {
  final repo = TrainingRepository.instance;
  final ref = DateTime.fromMillisecondsSinceEpoch(await repo.referenceNowMs(scope));
  return ProgressData(
    scope,
    ref,
    await repo.weeklySummaries(scope),
    await repo.gripTests(scope),
    await repo.currentTarget(),
  );
}

/// F3 Progres Pemulihan.
class ProgressScreen extends StatefulWidget {
  /// Stopwatch yang dimulai saat pengguna mengetuk tab/menu, untuk uji T3.
  final Stopwatch? openStopwatch;
  const ProgressScreen({super.key, this.openStopwatch});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Future<ProgressData>? _future;
  int _version = -1;
  String _scope = '';
  late Stopwatch _sw;
  bool _logged = false;
  int _periodWeeks = 8;

  @override
  void initState() {
    super.initState();
    _sw = widget.openStopwatch ?? (Stopwatch()..start());
  }

  @override
  void didUpdateWidget(covariant ProgressScreen old) {
    super.didUpdateWidget(old);
    if (widget.openStopwatch != null && widget.openStopwatch != old.openStopwatch) {
      _sw = widget.openStopwatch!;
      _logged = false;
      _future = loadProgressData(_scope);
    }
  }

  /// Muat ulang bila data logbook berubah atau sumber data diganti.
  /// Dipanggil di awal build (bukan didChangeDependencies) karena memakai context.watch.
  void _syncWith(DataSourceController s) {
    if (s.dataVersion != _version || s.scope != _scope) {
      _version = s.dataVersion;
      _scope = s.scope;
      _future = loadProgressData(s.scope);
    }
  }

  void _logT3(ProgressData d) {
    if (_logged) return;
    _logged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sw.stop();
      final sessions = d.weeks.fold<int>(0, (a, w) => a + w.sessionsCount);
      debugPrint('[T3] dashboard_load_ms=${_sw.elapsedMilliseconds} '
          'scope=${d.scope} weeks=${d.weeks.length} sessions=$sessions grip_tests=${d.grips.length}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final sources = context.watch<DataSourceController>();
    _syncWith(sources);
    return SafeArea(
      bottom: false,
      child: FutureBuilder<ProgressData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (snap.connectionState == ConnectionState.done) _logT3(d);
          final skip = _periodWeeks == 0 || d.weeks.length <= _periodWeeks ? 0 : d.weeks.length - _periodWeeks;
          final periodWeeks = d.weeks.skip(skip).toList();
          final periodStart = periodWeeks.isEmpty ? null : periodWeeks.first.weekStartMs;
          final periodGrips =
              periodStart == null ? d.grips : d.grips.where((g) => g.tMs >= periodStart).toList();
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              setState(() => _future = loadProgressData(sources.scope));
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
              children: [
                const PageHeader(eyebrow: 'Progres pemulihan', title: 'Pemulihan,', highlight: 'dalam angka'),
                if (sources.useSim) SimBanner('Mode simulasi · data s.d. ${Fmt.date(d.refNow)}'),
                TileRow(children: [_complianceTile(d), _gripTile(d)]),
                const SectionHeader('Periode grafik'),
                Segmented<int>(
                  items: const [(4, '4 mgg'), (8, '8 mgg'), (12, '12 mgg'), (0, 'Semua')],
                  value: _periodWeeks,
                  onChanged: (v) => setState(() => _periodWeeks = v),
                ),
                const SizedBox(height: 10),
                _GripTrendCard(grips: periodGrips),
                const SizedBox(height: 10),
                _ActiveMinutesCard(weeks: periodWeeks, currentWeekMs: weekStartMs(d.refNow.millisecondsSinceEpoch)),
                const SectionHeader('Lainnya'),
                MenuRow(
                  icon: Icons.pan_tool_outlined,
                  title: 'Sebaran jari',
                  subtitle: 'Persentase tekanan tiap jari',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => FingerDistributionScreen(scope: d.scope))),
                ),
                const SizedBox(height: 10),
                _TargetCard(
                  current: d.currentTarget,
                  onSave: (v) async {
                    await TrainingRepository.instance.setWeeklyTarget(v);
                    sources.markDataChanged();
                  },
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Ringkasan untuk terapis',
                  icon: Icons.description_outlined,
                  dark: true,
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => TherapistSummaryScreen(scope: d.scope))),
                ),
                const ForceFootnote(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _headline(ProgressData d) {
    final g = d.lastGrip;
    if (g == null) return '';
    final c = g.changeFromFirstPct;
    if (c == null) return '';
    if (c >= 5) return 'Naik ·';
    if (c <= -5) return 'Turun ·';
    return 'Stabil ·';
  }

  Widget _complianceTile(ProgressData d) {
    final w = d.thisWeek;
    final pct = w?.compliancePct;
    return StatTile(
      label: 'Kepatuhan',
      icon: Icons.verified_outlined,
      value: pct == null ? '0%' : Fmt.pct(displayCompliance(pct)),
      sub: '(${w?.qualifyingCount ?? 0}/${w?.target ?? d.currentTarget}) minggu ini',
      dark: true,
    );
  }

  Widget _gripTile(ProgressData d) {
    final g = d.lastGrip;
    final c = g?.changeFromFirstPct;
    return StatTile(
      label: 'Tes genggam',
      icon: Icons.back_hand_outlined,
      value: c == null ? '–' : Fmt.pct(c, signed: true),
      sub: g == null ? 'belum ada tes' : '${_headline(d)} ${Fmt.kg(g.value)} · ${g.handLabel.toLowerCase()}',
      subColor: (c ?? 0) > 0 ? AppColors.success : null,
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
      ]);
}

class _GripTrendCard extends StatelessWidget {
  final List<GripTestRow> grips;
  const _GripTrendCard({required this.grips});

  @override
  Widget build(BuildContext context) {
    final right = grips.where((g) => g.hand == 'right').toList();
    final left = grips.where((g) => g.hand == 'left').toList();
    return ChartCard(
      title: 'Tes genggam (kg*)',
      trailing: const Wrap(spacing: 10, children: [
        _Legend(AppColors.accent, 'Kanan'),
        _Legend(AppColors.dark, 'Kiri'),
      ]),
      child: grips.isEmpty
          ? const SizedBox(
              height: 90,
              child: Center(child: Text('Belum ada tes di periode ini', style: AppText.small)),
            )
          : SizedBox(height: 170, child: GripLineChart(right: right, left: left)),
    );
  }
}

/// Grafik garis nilai tes genggam per tangan.
class GripLineChart extends StatelessWidget {
  final List<GripTestRow> right;
  final List<GripTestRow> left;
  const GripLineChart({super.key, required this.right, required this.left});

  @override
  Widget build(BuildContext context) {
    final all = [...right, ...left];
    final t0 = all.map((g) => g.tMs).reduce((a, b) => a < b ? a : b);
    final t1 = all.map((g) => g.tMs).reduce((a, b) => a > b ? a : b);
    double x(GripTestRow g) => (g.tMs - t0) / 86400000.0;
    final maxX = (t1 - t0) / 86400000.0;
    final vals = all.map((g) => g.value);
    final lo = vals.reduce((a, b) => a < b ? a : b);
    final hi = vals.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) < 1 ? 1.0 : (hi - lo) * 0.2;
    final minY = (lo - pad) < 0 ? 0.0 : (lo - pad).floorToDouble();
    final maxY = (hi + pad).ceilToDouble();
    final spanX = maxX <= 0 ? 1.0 : maxX;

    LineChartBarData line(List<GripTestRow> rows, Color c) => LineChartBarData(
          spots: [for (final g in rows) FlSpot(x(g), g.value)],
          color: c,
          barWidth: 3,
          isCurved: false,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, i) =>
                FlDotCirclePainter(radius: 4, color: c, strokeWidth: 2, strokeColor: Colors.white),
          ),
          belowBarData: BarAreaData(show: c == AppColors.accent, color: AppColors.accent.withValues(alpha: 0.10)),
        );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spanX,
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(color: AppColors.line, strokeWidth: 1, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) =>
                  Text(Fmt.n0(v), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: spanX / 3 < 1 ? 1 : spanX / 3,
              getTitlesWidget: (v, meta) {
                final d = DateTime.fromMillisecondsSinceEpoch(t0 + (v * 86400000).round());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(Fmt.dateShort(d), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          if (left.isNotEmpty) line(left, AppColors.dark),
          if (right.isNotEmpty) line(right, AppColors.accent),
        ],
      ),
    );
  }
}

class _ActiveMinutesCard extends StatelessWidget {
  final List<WeeklySummaryRow> weeks;
  final int currentWeekMs;
  const _ActiveMinutesCard({required this.weeks, required this.currentWeekMs});

  @override
  Widget build(BuildContext context) {
    final maxV = weeks.fold<double>(0, (a, w) => w.activeMinTotal > a ? w.activeMinTotal : a);
    final total = weeks.fold<double>(0, (a, w) => a + w.activeMinTotal);
    return ChartCard(
      title: 'Menit aktif per minggu',
      trailing: Text('${Fmt.n0(total)} mnt', style: AppText.label.copyWith(color: AppColors.accentDeep)),
      child: total <= 0
          ? const SizedBox(
              height: 90,
              child: Center(child: Text('Belum ada menit aktif di periode ini', style: AppText.small)))
          : SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxV <= 0 ? 10 : maxV * 1.2,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      const FlLine(color: AppColors.line, strokeWidth: 1, dashArray: [4, 4]),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (v, meta) =>
                          Text(Fmt.n0(v), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                        final step = weeks.length <= 8 ? 1 : (weeks.length / 6).ceil();
                        if (i % step != 0 && i != weeks.length - 1) return const SizedBox.shrink();
                        final d = weeks[i].weekStart;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${d.day}/${d.month}',
                              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < weeks.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: weeks[i].activeMinTotal,
                        width: weeks.length > 16 ? 6 : (weeks.length > 8 ? 12 : 22),
                        color: weeks[i].weekStartMs == currentWeekMs
                            ? AppColors.accentDeep
                            : AppColors.accentBright,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ]),
                ],
              ),
            ),
          ),
    );
  }
}

class _TargetCard extends StatefulWidget {
  final int current;
  final Future<void> Function(int) onSave;
  const _TargetCard({required this.current, required this.onSave});

  @override
  State<_TargetCard> createState() => _TargetCardState();
}

class _TargetCardState extends State<_TargetCard> {
  late int _v = widget.current;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _TargetCard old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) _v = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final changed = _v != widget.current;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(Icons.flag_outlined),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Target mingguan', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              Text('Sesi ≥ 5 menit aktif · mulai minggu ini', style: AppText.small),
            ]),
          ),
          RoundIconButton(Icons.remove_rounded,
              size: 34, bg: AppColors.surfaceMuted, onTap: _v > 1 ? () => setState(() => _v--) : null),
          SizedBox(
            width: 34,
            child: Text('$_v',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          RoundIconButton(Icons.add_rounded,
              size: 34, bg: AppColors.surfaceMuted, onTap: _v < 14 ? () => setState(() => _v++) : null),
        ]),
        if (changed) ...[
          const SizedBox(height: 12),
          PillButton(
            label: _saving ? 'Menyimpan…' : 'Simpan target',
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(_v);
                    if (mounted) setState(() => _saving = false);
                  },
          ),
        ],
      ]),
    );
  }
}
