import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../logic/indicators.dart';
import '../models/training_models.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// F1 Detail Sesi. Semua angka dibaca dari kolom tersimpan di `training_sessions`.
class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final Future<TrainingSessionRow?> _future = TrainingRepository.instance.sessionById(widget.sessionId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail sesi'),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(child: RoundIconButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
        ),
      ),
      body: FutureBuilder<TrainingSessionRow?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          final s = snap.data;
          if (s == null) {
            return const EmptyState(icon: Icons.error_outline, title: 'Sesi tidak ditemukan');
          }
          return _DetailBody(s: s);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final TrainingSessionRow s;
  const _DetailBody({required this.s});

  @override
  Widget build(BuildContext context) {
    final endLabel = s.endReason == 'timeout' ? 'berakhir otomatis (2 menit tanpa tekanan)' : 'layar latihan ditutup';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        MicroLabel('Sesi · ${Fmt.dayDate(s.start)}${s.source == 'sim' ? ' · simulasi' : ''}'),
        const SizedBox(height: 8),
        Text('${Fmt.time(s.start)} – ${Fmt.time(s.end)}',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.4)),
        const SizedBox(height: 4),
        Text('Durasi sesi ${Fmt.duration(s.durationMs)} · $endLabel',
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: StatTile(
              label: 'Durasi aktif',
              value: Fmt.n1(s.activeMin),
              unit: 'menit',
              sub: s.qualifiesForTarget ? 'dihitung untuk target' : 'di bawah 5 menit',
              subColor: s.qualifiesForTarget ? AppColors.success : AppColors.muted,
              dark: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'Laju tekanan',
              value: s.pressRate == null ? '–' : Fmt.n1(s.pressRate),
              unit: 'tekanan/mnt',
              sub: '${Fmt.n0(s.totalPresses)} tekanan total',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Tekanan per jari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Tag('keymap ${s.keymap}'),
            ]),
            const SizedBox(height: 18),
            SizedBox(height: 190, child: FingerBarChart(presses: s.presses, keymap: s.keymap)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: StatTile(
              label: 'Jeda antar-tekanan',
              value: s.ipiMedianS == null ? '–' : Fmt.n1(s.ipiMedianS),
              unit: 'detik',
              sub: 'median',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'Gaya genggam',
              value: Fmt.n1(s.forceMedian),
              unit: 'kg*',
              sub: 'median sesi',
            ),
          ),
        ]),
        const SizedBox(height: 12),
        const MicroLabel('Kualitas data'),
        const SizedBox(height: 8),
        if (s.bleDisconnects == 0)
          const Callout(
            title: 'Sambungan stabil',
            body: 'Tidak ada sambungan Bluetooth yang terputus selama sesi ini.',
            bg: AppColors.successSoft,
            dot: AppColors.success,
          )
        else
          Callout(
            title: 'Sambungan terputus ${s.bleDisconnects} kali',
            body: 'Tekanan dan gaya selama sambungan terputus tidak tercatat, jadi angka sesi ini bisa lebih rendah.',
          ),
        const ForceFootnote(),
      ],
    );
  }
}

/// Diagram batang tekanan per jari (Telunjuk, Tengah, Manis, Kelingking).
class FingerBarChart extends StatelessWidget {
  final List<int> presses;
  final String keymap;
  const FingerBarChart({super.key, required this.presses, required this.keymap});

  @override
  Widget build(BuildContext context) {
    final maxV = presses.fold<int>(0, (a, b) => a > b ? a : b);
    final least = leastUsedFinger(presses);
    return BarChart(
      BarChartData(
        maxY: maxV == 0 ? 1 : maxV * 1.25,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= presses.length) return const SizedBox.shrink();
                return Text(Fmt.n0(presses[i]),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= kFingerNames.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(children: [
                    Text(kFingerNames[i], style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                    if (i < keymap.length)
                      Text(keymap[i].toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: AppColors.muted, fontFamily: 'monospace')),
                  ]),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < 4; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: presses[i].toDouble(),
                width: 34,
                color: i == least ? AppColors.accent : AppColors.dark2,
                borderRadius: BorderRadius.circular(10),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxV == 0 ? 1 : maxV * 1.25,
                  color: AppColors.bg,
                ),
              ),
            ]),
        ],
      ),
    );
  }
}
