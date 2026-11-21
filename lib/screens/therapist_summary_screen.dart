import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

import '../logic/indicators.dart';
import '../services/therapist_pdf.dart';
import '../services/therapist_summary.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// F3 Ringkasan untuk terapis, bisa dibagikan sebagai PDF.
class TherapistSummaryScreen extends StatefulWidget {
  final String scope;
  const TherapistSummaryScreen({super.key, required this.scope});

  @override
  State<TherapistSummaryScreen> createState() => _TherapistSummaryScreenState();
}

class _TherapistSummaryScreenState extends State<TherapistSummaryScreen> {
  int _period = 4;
  late Future<TherapistSummary> _future = TherapistSummary.load(widget.scope, _period);
  bool _sharing = false;

  void _setPeriod(int v) => setState(() {
        _period = v;
        _future = TherapistSummary.load(widget.scope, v);
      });

  Future<void> _share(TherapistSummary s) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await buildTherapistPdf(s);
      final name = 'ringkasan_wanur_${s.from.year}${s.from.month.toString().padLeft(2, '0')}'
          '${s.from.day.toString().padLeft(2, '0')}_${_period}mgg.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Ringkasan untuk terapis'),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(child: RoundIconButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
        ),
      ),
      body: FutureBuilder<TherapistSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          final s = snap.data!;
          return Stack(children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
              children: [
                Segmented<int>(
                  items: const [(4, '4 minggu'), (8, '8 minggu'), (12, '12 minggu')],
                  value: _period,
                  onChanged: _setPeriod,
                ),
                const SizedBox(height: 18),
                MicroLabel('Periode${s.scope == 'sim' ? ' · data simulasi' : ''}'),
                const SizedBox(height: 6),
                Text('${Fmt.date(s.from)} – ${Fmt.date(s.to.subtract(const Duration(days: 1)))}',
                    style: AppText.title.copyWith(fontSize: 20)),
                const SizedBox(height: 14),
                const Callout(title: kNotClinicalDisclaimer),
                const SizedBox(height: 14),
                TileRow(children: [
                  StatTile(
                      label: 'Kepatuhan',
                      value: Fmt.pct(s.periodCompliancePct == null ? null : displayCompliance(s.periodCompliancePct!)),
                      sub: '${s.qualifyingTotal} dari ${s.targetTotal} sesi target',
                      dark: true,
                    ),
                  StatTile(
                    label: 'Latihan',
                    value: Fmt.n0(s.activeMinTotal),
                    unit: 'mnt',
                    sub: '${s.sessionsTotal} sesi',
                  ),
                ]),
                const SectionHeader('Kepatuhan per minggu'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(children: [
                    _row(['Minggu', 'Sesi', '≥5 mnt', 'Kepatuhan'], header: true),
                    for (final w in s.weeks)
                      _row([
                        Fmt.weekRange(w.weekStart),
                        '${w.sessionsCount}',
                        '${w.qualifyingCount}/${w.target}',
                        Fmt.pct(w.compliancePct == null ? null : displayCompliance(w.compliancePct!)),
                      ]),
                  ]),
                ),
                const SectionHeader('Tren tes genggam'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: s.grips.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Tidak ada tes genggam dalam periode ini',
                              style: TextStyle(color: AppColors.muted)),
                        )
                      : Column(children: [
                          _row(['Tanggal', 'Tangan', 'Nilai', 'Dari awal'], header: true),
                          for (final g in s.grips)
                            _row([
                              Fmt.dateShort(g.time),
                              g.handLabel,
                              Fmt.kg(g.value),
                              Fmt.pct(g.changeFromFirstPct, signed: true),
                            ]),
                        ]),
                ),
                const SectionHeader('Sebaran jari'),
                AppCard(
                  child: Builder(builder: (_) {
                    final p = s.pressesTotal;
                    final pct = fingerDistributionPct(p);
                    final least = leastUsedFinger(p);
                    return Column(children: [
                      for (var i = 0; i < 4; i++)
                        PercentBar(
                          label: kFingerNames[i],
                          pct: pct?[i] ?? 0,
                          trailing: Fmt.pct(pct?[i]),
                          color: i == least ? AppColors.dark : AppColors.accent,
                        ),
                    ]);
                  }),
                ),
                const SectionHeader('Kualitas data'),
                Callout(
                  title: 'Terputus ${s.disconnectsTotal} kali di ${s.sessionsWithDisconnect} sesi',
                  body: '${s.emptySessions} sesi tanpa tekanan · ${s.shortSessions} sesi di bawah 5 menit aktif',
                  bg: s.disconnectsTotal == 0 ? AppColors.successSoft : AppColors.warningSoft,
                  dot: s.disconnectsTotal == 0 ? AppColors.success : AppColors.warning,
                ),
                SectionHeader('Sesi (${s.sessionsTotal})'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(children: [
                    _row(['Tanggal', 'Aktif', 'Tekanan', 'Laju'], header: true),
                    for (final x in s.sessions.reversed)
                      _row([
                        '${Fmt.dateShort(x.start)} ${Fmt.time(x.start)}',
                        '${Fmt.n1(x.activeMin)} mnt',
                        Fmt.n0(x.totalPresses),
                        x.pressRate == null ? '–' : '${Fmt.n1(x.pressRate)}/mnt',
                      ]),
                  ]),
                ),
                const ForceFootnote(),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: SafeArea(
                child: PillButton(
                  label: _sharing ? 'Menyiapkan PDF…' : 'Bagikan PDF',
                  icon: Icons.ios_share_rounded,
                  onPressed: _sharing ? null : () => _share(s),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _row(List<String> cells, {bool header = false}) {
    final style = TextStyle(
      fontSize: header ? 11 : 13,
      fontWeight: header ? FontWeight.w600 : FontWeight.w400,
      color: header ? AppColors.muted : AppColors.ink,
      letterSpacing: header ? 0.5 : 0,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: header ? null : const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Text(cells[0], style: style)),
        for (var i = 1; i < cells.length; i++)
          Expanded(flex: 2, child: Text(cells[i], style: style, textAlign: TextAlign.right)),
      ]),
    );
  }
}
