import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/data_source_controller.dart';
import '../data/glove_data_source.dart';
import '../logic/indicators.dart';
import '../models/training_models.dart';
import '../providers/glove_provider.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

enum _Phase { choose, restRef, grip, restBetween, saving, done }

/// F2 Tes Genggam terpandu: 3 percobaan. Tiap percobaan: istirahat 3 s (nol
/// referensi), "Genggam kuat" 5 s, lalu istirahat 60 s sebelum percobaan
/// berikutnya. Hasil disimpan hanya bila ketiga percobaan selesai.
class GripTestScreen extends StatefulWidget {
  const GripTestScreen({super.key});

  static const restRefMs = 3000;
  static const gripMs = 5000;
  static const restBetweenMs = 60000;

  @override
  State<GripTestScreen> createState() => _GripTestScreenState();
}

class _GripTestScreenState extends State<GripTestScreen> {
  _Phase _phase = _Phase.choose;
  String _hand = 'right';
  int _trial = 0;
  int _phaseStartMs = 0;
  int _testStartMs = 0;
  double? _liveKg;
  final List<GripTrialRaw> _trials = [];
  List<({int tMs, double kg})> _rest = [];
  List<({int tMs, double kg})> _grip = [];
  final List<double> _trialValues = [];
  GripTestRow? _result;
  Map<String, GripTestRow> _lastByHand = {};
  StreamSubscription<ForceSample>? _sub;
  Timer? _ticker;
  late final DataSourceController _sources;

  @override
  void initState() {
    super.initState();
    _sources = context.read<DataSourceController>();
    _sub = _sources.current.forceSamples.listen(_onSample);
    _loadLast();
  }

  Future<void> _loadLast() async {
    final tests = await TrainingRepository.instance.gripTests(_sources.scope);
    if (!mounted) return;
    setState(() => _lastByHand = {for (final t in tests) t.hand: t});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    _sources.current.hintGripPhase(false);
    super.dispose();
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  int get _phaseDurationMs => switch (_phase) {
        _Phase.restRef => GripTestScreen.restRefMs,
        _Phase.grip => GripTestScreen.gripMs,
        _Phase.restBetween => GripTestScreen.restBetweenMs,
        _ => 0,
      };

  void _onSample(ForceSample f) {
    final s = (tMs: f.tMs, kg: f.kg);
    if (_phase == _Phase.restRef) _rest.add(s);
    if (_phase == _Phase.grip) _grip.add(s);
    if (mounted) setState(() => _liveKg = f.kg);
  }

  void _start() {
    _trials.clear();
    _trialValues.clear();
    _trial = 0;
    _testStartMs = _now;
    _beginTrial();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _beginTrial() {
    _rest = [];
    _grip = [];
    _setPhase(_Phase.restRef);
  }

  void _setPhase(_Phase p) {
    _phase = p;
    _phaseStartMs = _now;
    _sources.current.hintGripPhase(p == _Phase.grip);
    if (mounted) setState(() {});
  }

  void _tick() {
    if (!mounted) return;
    final elapsed = _now - _phaseStartMs;
    if (_phaseDurationMs > 0 && elapsed >= _phaseDurationMs) {
      _advance();
    } else {
      setState(() {});
    }
  }

  void _advance() {
    switch (_phase) {
      case _Phase.restRef:
        _setPhase(_Phase.grip);
      case _Phase.grip:
        _trials.add(GripTrialRaw(rest: _rest, grip: _grip));
        _trialValues.add(gripTrialValue([for (final s in _rest) s.kg], [for (final s in _grip) s.kg]) ?? 0);
        if (_trials.length < 3) {
          _setPhase(_Phase.restBetween);
        } else {
          _save();
        }
      case _Phase.restBetween:
        _trial++;
        _beginTrial();
      default:
        break;
    }
  }

  Future<void> _save() async {
    _ticker?.cancel();
    _setPhase(_Phase.saving);
    final row = await TrainingRepository.instance.saveGripTest(
      hand: _hand,
      tMs: _testStartMs,
      trials: List.of(_trials),
      source: _sources.scope,
      profileId: _sources.useSim ? _sources.simProfileId : null,
    );
    _sources.markDataChanged();
    if (!mounted) return;
    setState(() {
      _result = row;
      _phase = _Phase.done;
    });
  }

  bool get _running => _phase == _Phase.restRef || _phase == _Phase.grip || _phase == _Phase.restBetween;

  Future<bool> _confirmCancel() async {
    if (!_running) return true;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Batalkan tes?'),
            content: const Text('Tes belum selesai 3 percobaan, jadi hasilnya tidak akan disimpan.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Lanjutkan tes')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan')),
            ],
          ),
        ) ??
        false;
    if (ok) {
      _ticker?.cancel();
      _sources.current.hintGripPhase(false);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_running,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmCancel()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tes genggam'),
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: RoundIconButton(Icons.close_rounded, onTap: () async {
                final nav = Navigator.of(context);
                if (await _confirmCancel()) nav.pop();
              }),
            ),
          ),
        ),
        body: SafeArea(
          child: switch (_phase) {
            _Phase.choose => _buildChoose(),
            _Phase.done => _buildResult(),
            _ => _buildRunning(),
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- pilih tangan
  Widget _buildChoose() {
    final glove = context.watch<GloveProvider>();
    final ready = _sources.useSim || glove.isConnected;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const MicroLabel('Tes terpandu · 3 percobaan'),
        const SizedBox(height: 8),
        const Text('Pilih tangan',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.2)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _handCard('right', 'Tangan kanan')),
          const SizedBox(width: 12),
          Expanded(child: _handCard('left', 'Tangan kiri')),
        ]),
        const SizedBox(height: 18),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Alur tiap percobaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _step('1', 'Istirahat 3 detik', 'Lepaskan genggaman. Dipakai sebagai nol referensi.'),
            _step('2', 'Genggam kuat 5 detik', 'Genggam sekuat mungkin sampai hitungan habis.'),
            _step('3', 'Istirahat 60 detik', 'Otot pulih sebelum percobaan berikutnya.'),
            const SizedBox(height: 6),
            const Text('Hasil = rata-rata 3 percobaan. Total sekitar 2,5 menit.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(height: 14),
        if (!ready)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Callout(
              title: 'Glove belum terhubung',
              body: 'Hubungkan glove dari tab Glove sebelum memulai tes.',
            ),
          ),
        PillButton(label: 'Mulai tes', icon: Icons.play_arrow_rounded, onPressed: ready ? _start : null),
        const ForceFootnote(),
      ],
    );
  }

  Widget _handCard(String hand, String label) {
    final selected = _hand == hand;
    final last = _lastByHand[hand];
    return GestureDetector(
      onTap: () => setState(() => _hand = hand),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Transform.flip(
            flipX: hand == 'left',
            child: Icon(Icons.back_hand_rounded, color: selected ? AppColors.accent : AppColors.muted, size: 30),
          ),
          const SizedBox(height: 18),
          Text(label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
          const SizedBox(height: 4),
          Text(
            last == null ? 'Belum pernah dites' : 'Terakhir ${Fmt.kg(last.value)}',
            style: TextStyle(fontSize: 12, color: selected ? Colors.white60 : AppColors.muted),
          ),
        ]),
      ),
    );
  }

  Widget _step(String n, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
            child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(body, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
        ]),
      );

  // ---------------------------------------------------------------- berjalan
  Widget _buildRunning() {
    final dur = _phaseDurationMs;
    final rawElapsed = _now - _phaseStartMs;
    final cap = dur == 0 ? 1 : dur;
    final elapsed = rawElapsed < 0 ? 0 : (rawElapsed > cap ? cap : rawElapsed);
    final remainS = dur == 0 ? 0 : ((dur - elapsed) / 1000).ceil();
    final isGrip = _phase == _Phase.grip;
    final (title, hint) = switch (_phase) {
      _Phase.restRef => ('Lepaskan genggaman', 'Mengukur nol referensi'),
      _Phase.grip => ('Genggam kuat!', 'Tahan sampai hitungan habis'),
      _Phase.restBetween => ('Istirahat', 'Percobaan berikutnya segera'),
      _ => ('Menyimpan…', ''),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(children: [
        Row(children: [
          MicroLabel('Percobaan ${_trial + 1} dari 3 · ${_hand == 'left' ? 'kiri' : 'kanan'}'),
          const Spacer(),
          for (var i = 0; i < 3; i++) ...[
            _TrialChip(index: i, value: i < _trialValues.length ? _trialValues[i] : null, current: i == _trial),
            if (i < 2) const SizedBox(width: 6),
          ],
        ]),
        const Spacer(),
        RingProgress(
          value: dur == 0 ? 1 : elapsed / dur,
          size: 250,
          stroke: 14,
          color: isGrip ? AppColors.accent : AppColors.ink,
          track: AppColors.surfaceMuted,
          center: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$remainS',
                style: TextStyle(
                    fontSize: 84,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -3,
                    color: isGrip ? AppColors.accent : AppColors.ink)),
            const Text('detik', style: TextStyle(color: AppColors.muted)),
          ]),
        ),
        const SizedBox(height: 28),
        Text(title,
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: isGrip ? AppColors.accent : AppColors.ink)),
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(color: AppColors.inkSoft)),
        const Spacer(),
        AppCard(
          child: Row(children: [
            const MicroLabel('Gaya sekarang'),
            const Spacer(),
            Text(_liveKg == null ? '–' : Fmt.n1(_liveKg),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
            const Text(' kg*', style: TextStyle(color: AppColors.inkSoft)),
          ]),
        ),
        const SizedBox(height: 12),
        if (_phase == _Phase.restBetween && _sources.useSim)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PillButton(label: 'Lewati istirahat (simulasi)', dark: true, onPressed: _advance),
          ),
        PillButton(
          label: 'Batalkan tes',
          outlined: true,
          onPressed: () async {
            final nav = Navigator.of(context);
            if (await _confirmCancel()) nav.pop();
          },
        ),
        const ForceFootnote(),
      ]),
    );
  }

  // ---------------------------------------------------------------- hasil
  Widget _buildResult() {
    final r = _result!;
    final change = r.changeFromFirstPct;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        MicroLabel('Hasil · tangan ${r.hand == 'left' ? 'kiri' : 'kanan'} · ${Fmt.dayDate(r.time)}'),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(Fmt.n1(r.value),
              style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w700, letterSpacing: -3, height: 1)),
          const Text(' kg*', style: TextStyle(fontSize: 20, color: AppColors.inkSoft)),
        ]),
        const SizedBox(height: 6),
        Text(
          change == null
              ? 'Rata-rata 3 percobaan.'
              : (_lastByHand[r.hand] == null
                  ? 'Rata-rata 3 percobaan. Ini tes pertama untuk tangan ini.'
                  : 'Rata-rata 3 percobaan · ${Fmt.pct(change, signed: true)} dari tes pertama'),
          style: TextStyle(
              fontSize: 14, color: (change ?? 0) > 0 ? AppColors.success : AppColors.inkSoft, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20),
        Row(children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: StatTile(label: 'Percobaan ${i + 1}', value: Fmt.n1(r.trials[i]), unit: 'kg*')),
            if (i < 2) const SizedBox(width: 10),
          ],
        ]),
        const ForceFootnote(),
        const SizedBox(height: 12),
        PillButton(label: 'Selesai', onPressed: () => Navigator.pop(context)),
        const SizedBox(height: 10),
        PillButton(
          label: 'Tes tangan ${r.hand == 'left' ? 'kanan' : 'kiri'}',
          outlined: true,
          onPressed: () => setState(() {
            _hand = r.hand == 'left' ? 'right' : 'left';
            _phase = _Phase.choose;
            _loadLast();
          }),
        ),
      ],
    );
  }
}

class _TrialChip extends StatelessWidget {
  final int index;
  final double? value;
  final bool current;
  const _TrialChip({required this.index, required this.value, required this.current});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value != null ? AppColors.dark : (current ? AppColors.accentSoft : AppColors.surface),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          value != null ? Fmt.n1(value) : '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: value != null ? Colors.white : (current ? AppColors.accentDeep : AppColors.muted),
          ),
        ),
      );
}
