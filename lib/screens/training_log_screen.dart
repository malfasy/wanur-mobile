import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_source_controller.dart';
import '../logic/indicators.dart';
import '../models/training_models.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'history_screen.dart';
import 'nav.dart';
import 'session_detail_screen.dart';

class _LogData {
  final DateTime refNow;
  final int target;
  final WeeklySummaryRow? thisWeek;
  final List<(int weekStartMs, WeeklySummaryRow? summary, List<TrainingSessionRow> sessions)> weeks;
  const _LogData(this.refNow, this.target, this.thisWeek, this.weeks);
}

/// F1 Riwayat Latihan: sesi dikelompokkan per minggu kalender.
class TrainingLogScreen extends StatefulWidget {
  const TrainingLogScreen({super.key});

  @override
  State<TrainingLogScreen> createState() => _TrainingLogScreenState();
}

class _TrainingLogScreenState extends State<TrainingLogScreen> {
  Future<_LogData>? _future;
  int _version = -1;
  String _scope = '';

  /// Muat ulang bila data logbook berubah atau sumber data diganti.
  /// Dipanggil di awal build (bukan didChangeDependencies) karena memakai context.watch.
  void _syncWith(DataSourceController s) {
    if (s.dataVersion != _version || s.scope != _scope) {
      _version = s.dataVersion;
      _scope = s.scope;
      _future = _load(s.scope);
    }
  }

  Future<_LogData> _load(String scope) async {
    final repo = TrainingRepository.instance;
    final ref = DateTime.fromMillisecondsSinceEpoch(await repo.referenceNowMs(scope));
    final ws = weekStartLocal(ref).millisecondsSinceEpoch;
    final sessions = await repo.sessions(scope);
    final summaries = {for (final w in await repo.weeklySummaries(scope)) w.weekStartMs: w};
    final grouped = <int, List<TrainingSessionRow>>{};
    for (final s in sessions) {
      grouped.putIfAbsent(s.weekStartMs, () => []).add(s);
    }
    final weeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return _LogData(
      ref,
      summaries[ws]?.target ?? await repo.currentTarget(),
      summaries[ws],
      [for (final w in weeks) (w, summaries[w], grouped[w]!)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = context.watch<DataSourceController>();
    _syncWith(sources);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          setState(() => _future = _load(sources.scope));
          await _future;
        },
        child: FutureBuilder<_LogData>(
          future: _future,
          builder: (context, snap) {
            final d = snap.data;
            final children = <Widget>[
              const MicroLabel('Logbook'),
              const SizedBox(height: 8),
              const Text('Riwayat Latihan',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.2)),
              const SizedBox(height: 16),
              if (sources.useSim && d != null) SimBanner('MODE SIMULASI · data s.d. ${Fmt.date(d.refNow)}'),
              _ThisWeekCard(data: d),
              const SizedBox(height: 12),
              PillButton(
                  label: 'Mulai latihan', icon: Icons.add_rounded, dark: true, onPressed: () => openTraining(context)),
              const SizedBox(height: 8),
            ];
            if (snap.connectionState == ConnectionState.waiting && d == null) {
              children.add(const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ));
            } else if (d == null || d.weeks.isEmpty) {
              children.add(const EmptyState(
                icon: Icons.event_note_rounded,
                title: 'Belum ada sesi latihan',
                body: 'Sesi tercatat otomatis setiap kali layar latihan dibuka dan tombol glove ditekan.',
              ));
            } else {
              for (final (w, summary, sessions) in d.weeks) {
                children.add(_WeekHeader(weekStartMs: w, summary: summary, count: sessions.length));
                for (final s in sessions) {
                  children.add(Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SessionCard(
                      s: s,
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: s.id))),
                    ),
                  ));
                }
              }
            }
            children.add(const SizedBox(height: 8));
            children.add(MenuRow(
              icon: Icons.inventory_2_outlined,
              title: 'Arsip pengukuran lama',
              subtitle: 'Data dari versi sebelumnya (hanya dibaca)',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ));
            return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: children);
          },
        ),
      ),
    );
  }
}

class _ThisWeekCard extends StatelessWidget {
  final _LogData? data;
  const _ThisWeekCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final q = data?.thisWeek?.qualifyingCount ?? 0;
    final y = data?.target ?? kDefaultWeeklyTarget;
    final segments = y < 1 ? 1 : (y > 14 ? 14 : y);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          const Text('Minggu ini: ', style: TextStyle(fontSize: 16, color: AppColors.inkSoft)),
          Text('$q dari $y sesi',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < segments; i++)
            Expanded(
              child: Container(
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < q ? AppColors.accent : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          'Sesi dihitung untuk target bila durasi aktif ≥ ${kQualifyingActiveMin.toStringAsFixed(0)} menit.'
          '${q > y ? ' Target sudah terlampaui.' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ]),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  final int weekStartMs;
  final WeeklySummaryRow? summary;
  final int count;
  const _WeekHeader({required this.weekStartMs, required this.summary, required this.count});

  @override
  Widget build(BuildContext context) {
    final ws = DateTime.fromMillisecondsSinceEpoch(weekStartMs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(children: [
        Expanded(
          child: Text(Fmt.weekRange(ws),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        Text(
          '$count sesi · ${Fmt.n0(summary?.activeMinTotal ?? 0)} mnt aktif',
          style: const TextStyle(fontSize: 12, color: AppColors.muted, fontFamily: 'monospace'),
        ),
      ]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final TrainingSessionRow s;
  final VoidCallback onTap;
  const _SessionCard({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final least = s.leastUsedFinger;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DateTile(s.start, highlight: s.qualifiesForTarget),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${Fmt.dayDate(s.start)} · ${Fmt.time(s.start)}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 2),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(Fmt.n1(s.activeMin),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const Text(' mnt aktif', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 4),
            Text(
              '${Fmt.n0(s.totalPresses)} tekanan · ${s.pressRate == null ? '–' : Fmt.n1(s.pressRate)} /mnt',
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (least != null)
                Tag('Jarang: ${kFingerNames[least]}', bg: AppColors.accentSoft, fg: AppColors.accentDeep),
              if (s.totalPresses == 0) const Tag('Tanpa tekanan'),
              if (!s.qualifiesForTarget && s.totalPresses > 0) const Tag('< 5 mnt'),
              if (s.bleDisconnects > 0)
                Tag('${s.bleDisconnects}x terputus', icon: Icons.bluetooth_disabled_rounded),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ]),
    );
  }
}
