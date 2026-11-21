import 'package:material_ui/material_ui.dart';

import '../logic/indicators.dart';
import '../models/training_models.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Jumlah tekanan per jari dalam periode = jumlah dari ringkasan mingguan tersimpan.
List<int> sumPresses(Iterable<WeeklySummaryRow> weeks) {
  final out = [0, 0, 0, 0];
  for (final w in weeks) {
    for (var i = 0; i < 4; i++) {
      out[i] += w.presses[i];
    }
  }
  return out;
}

/// Minggu-minggu dalam [periodWeeks] terakhir (0 = semua).
List<WeeklySummaryRow> lastWeeks(List<WeeklySummaryRow> weeks, int periodWeeks) {
  if (periodWeeks == 0 || weeks.length <= periodWeeks) return weeks;
  return weeks.sublist(weeks.length - periodWeeks);
}

/// F3 Sebaran jari: persentase tekanan tiap jari untuk periode terpilih.
class FingerDistributionScreen extends StatefulWidget {
  final String scope;
  const FingerDistributionScreen({super.key, required this.scope});

  @override
  State<FingerDistributionScreen> createState() => _FingerDistributionScreenState();
}

class _FingerDistributionScreenState extends State<FingerDistributionScreen> {
  late final Future<List<WeeklySummaryRow>> _future = TrainingRepository.instance.weeklySummaries(widget.scope);
  int _period = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sebaran jari'),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(child: RoundIconButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
        ),
      ),
      body: FutureBuilder<List<WeeklySummaryRow>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          final weeks = lastWeeks(snap.data!, _period);
          final counts = sumPresses(weeks);
          final pct = fingerDistributionPct(counts);
          final least = leastUsedFinger(counts);
          final total = counts.fold<int>(0, (a, b) => a + b);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Segmented<int>(
                items: const [(4, '4 mgg'), (8, '8 mgg'), (12, '12 mgg'), (0, 'Semua')],
                value: _period,
                onChanged: (v) => setState(() => _period = v),
              ),
              const SizedBox(height: 18),
              if (weeks.isNotEmpty)
                MicroLabel('${Fmt.date(weeks.first.weekStart)} – '
                    '${Fmt.date(nextWeekStart(weeks.last.weekStart).subtract(const Duration(days: 1)))}'),
              const SizedBox(height: 8),
              Text(
                least == null || pct == null
                    ? 'Belum ada tekanan.'
                    : '${kFingerNames[least]} paling jarang dipakai.',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1.1, height: 1.1),
              ),
              const SizedBox(height: 6),
              Text('${Fmt.n0(total)} tekanan dalam periode ini',
                  style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 18),
              AppCard(
                child: Column(children: [
                  for (var i = 0; i < 4; i++)
                    PercentBar(
                      label: kFingerNames[i],
                      pct: pct?[i] ?? 0,
                      trailing: '${Fmt.pct(pct?[i])} · ${Fmt.n0(counts[i])}',
                      color: i == least ? AppColors.accent : AppColors.dark2,
                      emphasize: i == least,
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              if (least != null && pct != null && pct[least] < 10)
                Callout(
                  title: '${kFingerNames[least]} hanya ${Fmt.pct(pct[least])} dari tekanan',
                  body: 'Catatan ini untuk pemantauan latihan dan bisa dibahas bersama terapis.',
                ),
              const SizedBox(height: 8),
              const Text(
                'Tekanan dipetakan ke jari memakai keymap yang berlaku saat tiap sesi dimulai.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}
