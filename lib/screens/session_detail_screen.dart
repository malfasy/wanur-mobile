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
    return AppScaffold(
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
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: [
        PageHeader(
          eyebrow: 'Sesi · ${Fmt.dayDate(s.start)}${s.source == 'sim' ? ' · simulasi' : ''}',
          title: Fmt.time(s.start),
          highlight: '– ${Fmt.time(s.end)}',
        ),
        Text('Durasi sesi ${Fmt.duration(s.durationMs)} · $endLabel', style: AppText.bodyText),
        const SizedBox(height: 14),
        TileRow(children: [
          StatTile(
              label: 'Durasi aktif',
              value: Fmt.n1(s.activeMin),
              unit: 'menit',
              sub: s.qualifiesForTarget ? 'dihitung untuk target' : 'di bawah 5 menit',
              subColor: s.qualifiesForTarget ? AppColors.lime : null,
              dark: true,
            ),
          StatTile(
            label: 'Laju tekanan',
            value: s.pressRate == null ? '–' : Fmt.n1(s.pressRate),
            unit: '/mnt',
            sub: '${Fmt.n0(s.totalPresses)} tekanan total',
          ),
        ]),
        const SizedBox(height: 10),
        ChartCard(
          title: 'Tekanan per jari',
          trailing: Tag('keymap ${s.keymap}'),
          child: FingerBarChart(presses: s.presses, keymap: s.keymap),
        ),
        const SizedBox(height: 10),
        TileRow(children: [
          StatTile(
            label: 'Jeda tekanan',
            value: s.ipiMedianS == null ? '–' : Fmt.n1(s.ipiMedianS),
            unit: 'detik',
            sub: 'median antar-tekanan',
          ),
          StatTile(
            label: 'Gaya genggam',
            value: Fmt.n1(s.forceMedian),
            unit: 'kg*',
            sub: 'median sesi',
          ),
        ]),
        const SectionHeader('Kualitas data'),
        if (s.bleDisconnects == 0)
          const Callout(
            title: 'Sambungan stabil',
            body: 'Tidak ada sambungan Bluetooth yang terputus selama sesi ini.',
            bg: AppColors.successSoft,
            dot: AppColors.success,
          )
        else
          Callout.warning(
            title: 'Sambungan terputus ${s.bleDisconnects} kali',
            body: 'Tekanan dan gaya selama sambungan terputus tidak tercatat, jadi angka sesi ini bisa lebih rendah.',
          ),
        const ForceFootnote(),
      ],
    );
  }
}

/// Diagram batang horizontal tekanan per jari (Telunjuk, Tengah, Manis,
/// Kelingking), sesuai wireframe Figure 2b. Jari paling jarang ditandai.
class FingerBarChart extends StatelessWidget {
  final List<int> presses;
  final String keymap;
  const FingerBarChart({super.key, required this.presses, required this.keymap});

  @override
  Widget build(BuildContext context) {
    final maxV = presses.fold<int>(0, (a, b) => a > b ? a : b);
    final least = leastUsedFinger(presses);
    return Column(children: [
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
              width: 92,
              child: Row(children: [
                Flexible(
                  child: Text(kFingerNames[i],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, fontWeight: i == least ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (i < keymap.length) ...[
                  const SizedBox(width: 4),
                  Text(keymap[i].toUpperCase(), style: AppText.label.copyWith(fontSize: 10)),
                ],
              ]),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: maxV == 0 ? 0 : presses[i] / maxV,
                  minHeight: 12,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(i == least ? AppColors.dark : AppColors.accent),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(Fmt.n0(presses[i]),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      if (least != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text('Paling jarang dipakai: ${kFingerNames[least]}', style: AppText.small),
          ]),
        ),
    ]);
  }
}
