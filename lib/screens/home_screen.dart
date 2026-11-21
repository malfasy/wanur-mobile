import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/data_source_controller.dart';
import '../logic/indicators.dart';
import '../models/training_models.dart';
import '../providers/glove_provider.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'dev_settings_screen.dart';
import 'device_screen.dart';
import 'nav.dart';
import 'grip_test_screen.dart';
import 'progress_screen.dart';
import 'touch_menu_screen.dart';
import 'training_log_screen.dart';

/// Kerangka utama aplikasi: 4 tab dengan navigasi bawah berbentuk pil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  Stopwatch? _progressStopwatch;
  bool _autoConnectTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoConnect());
  }

  Future<void> _tryAutoConnect() async {
    if (_autoConnectTried) return;
    _autoConnectTried = true;
    final glove = context.read<GloveProvider>();
    final sources = context.read<DataSourceController>();
    if (glove.isConnected || sources.useSim) return;
    try {
      await glove.autoConnectBondedDevice();
    } catch (e) {
      debugPrint('Auto-connect gagal: $e');
    }
  }

  void select(int i) {
    setState(() {
      if (i == 2) _progressStopwatch = Stopwatch()..start();
      _tab = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => BerandaTab(onSelectTab: select),
      1 => const TrainingLogScreen(),
      2 => ProgressScreen(openStopwatch: _progressStopwatch),
      _ => const DeviceScreen(),
    };
    return AppScaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: _GlassNavBar(index: _tab, onTap: select),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _GlassNavBar({required this.index, required this.onTap});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.event_note_outlined, Icons.event_note_rounded, 'Riwayat'),
    (Icons.insights_outlined, Icons.insights_rounded, 'Progres'),
    (Icons.back_hand_outlined, Icons.back_hand_rounded, 'Glove'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GlassPanel(
        radius: 26,
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == index ? AppColors.accentBright : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: i == index
                            ? [
                                BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(i == index ? _items[i].$2 : _items[i].$1,
                              size: 21, color: i == index ? AppColors.dark : AppColors.muted),
                          const SizedBox(height: 2),
                          Text(_items[i].$3.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: AppText.label.copyWith(
                                fontSize: 9,
                                letterSpacing: 0.8,
                                color: i == index ? AppColors.dark : AppColors.muted,
                                fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data ringkas untuk Beranda (dibaca dari nilai tersimpan).
class _HomeData {
  final DateTime refNow;
  final WeeklySummaryRow? week;
  final int target;
  final Set<int> trainedWeekdays; // 1..7, hari dengan sesi >= 5 menit
  final GripTestRow? lastGrip;
  const _HomeData(this.refNow, this.week, this.target, this.trainedWeekdays, this.lastGrip);
}

class BerandaTab extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  const BerandaTab({super.key, required this.onSelectTab});

  @override
  State<BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<BerandaTab> {
  Future<_HomeData>? _future;
  int _version = -1;
  String _scope = '';
  int _devTaps = 0;

  /// Muat ulang bila data logbook berubah atau sumber data diganti.
  /// Dipanggil di awal build (bukan didChangeDependencies) karena memakai context.watch.
  void _syncWith(DataSourceController s) {
    if (s.dataVersion != _version || s.scope != _scope) {
      _version = s.dataVersion;
      _scope = s.scope;
      _future = _load(s.scope);
    }
  }

  Future<_HomeData> _load(String scope) async {
    final repo = TrainingRepository.instance;
    final ref = DateTime.fromMillisecondsSinceEpoch(await repo.referenceNowMs(scope));
    final ws = weekStartLocal(ref);
    final week = await repo.weekSummary(scope, ws.millisecondsSinceEpoch);
    final target = week?.target ?? await repo.currentTarget();
    final sessions = await repo.sessions(scope,
        fromMs: ws.millisecondsSinceEpoch, toMs: nextWeekStart(ws).millisecondsSinceEpoch);
    final days = {for (final s in sessions) if (s.qualifiesForTarget) s.start.weekday};
    final grips = await repo.gripTests(scope);
    return _HomeData(ref, week, target, days, grips.isEmpty ? null : grips.last);
  }

  (String, String) _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return ('Selamat', 'pagi.');
    if (h < 15) return ('Selamat', 'siang.');
    if (h < 19) return ('Selamat', 'sore.');
    return ('Selamat', 'malam.');
  }

  void _onTitleTap(DataSourceController s) {
    // Toggle tersembunyi: ketuk sapaan 7 kali untuk membuka menu pengembang.
    if (s.devUnlocked) return;
    _devTaps++;
    if (_devTaps >= 7) {
      s.setDevUnlocked(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Menu pengembang aktif')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = context.watch<DataSourceController>();
    _syncWith(sources);
    final glove = context.watch<GloveProvider>();
    final connected = sources.useSim || glove.isConnected;
    final (greet, greetAccent) = _greeting();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          setState(() => _future = _load(sources.scope));
          await _future;
        },
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snap) {
            final d = snap.data;
            final grip = d?.lastGrip;
            final gripChange = grip?.changeFromFirstPct;
            void go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
              children: [
                PageHeader(
                  eyebrow: '${Fmt.dayDate(d?.refNow ?? DateTime.now())}${sources.useSim ? ' · simulasi' : ''}',
                  title: greet,
                  highlight: greetAccent,
                  onTitleTap: () => _onTitleTap(sources),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (sources.devUnlocked) ...[
                      RoundIconButton(Icons.tune_rounded,
                          size: 36,
                          tooltip: 'Pengaturan Pengembang',
                          onTap: () => go(const DevSettingsScreen())),
                      const SizedBox(width: 6),
                    ],
                    _ConnectionChip(connected: connected, sim: sources.useSim, onTap: () => widget.onSelectTab(3)),
                  ]),
                ),
                if (sources.useSim && d != null) SimBanner('Mode simulasi · data s.d. ${Fmt.date(d.refNow)}'),
                _WeekHero(data: d),
                const SectionHeader('Ringkasan'),
                TileRow(children: [
                  StatTile(
                    label: 'Tes genggam',
                    icon: Icons.back_hand_outlined,
                    value: grip == null ? '–' : Fmt.n1(grip.value),
                    unit: grip == null ? null : 'kg*',
                    sub: grip == null
                        ? 'Belum ada tes'
                        : '${Fmt.pct(gripChange, signed: true)} dari awal · ${grip.handLabel.toLowerCase()}',
                    subColor: (gripChange ?? 0) > 0 ? AppColors.success : null,
                    onTap: () => go(const GripTestScreen()),
                  ),
                  StatTile(
                    label: 'Menit aktif',
                    icon: Icons.timer_outlined,
                    value: Fmt.n0(d?.week?.activeMinTotal ?? 0),
                    unit: 'mnt',
                    sub: 'minggu ini',
                    onTap: () => widget.onSelectTab(2),
                  ),
                ]),
                const ForceFootnote(),
                const SectionHeader('Menu'),
                TileRow(children: [
                  QuickTile(
                    icon: Icons.event_note_outlined,
                    title: 'Riwayat Latihan',
                    subtitle: 'Sesi per minggu',
                    onTap: () => widget.onSelectTab(1),
                  ),
                  QuickTile(
                    icon: Icons.insights_outlined,
                    title: 'Progres',
                    subtitle: 'Kepatuhan & tren',
                    onTap: () => widget.onSelectTab(2),
                  ),
                ]),
                const SizedBox(height: 10),
                TileRow(children: [
                  QuickTile(
                    icon: Icons.back_hand_outlined,
                    title: 'Tes Genggam',
                    subtitle: '3 percobaan',
                    onTap: () => go(const GripTestScreen()),
                  ),
                  QuickTile(
                    icon: Icons.touch_app_outlined,
                    title: 'Kalibrasi Jari',
                    subtitle: 'Cek tombol',
                    onTap: () => go(const TouchMenuScreen()),
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  final bool connected;
  final bool sim;
  final VoidCallback onTap;
  const _ConnectionChip({required this.connected, required this.sim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = sim ? 'Simulasi' : (connected ? 'Terhubung' : 'Offline');
    final color = sim ? AppColors.success : (connected ? AppColors.success : AppColors.warning);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _WeekHero extends StatelessWidget {
  final _HomeData? data;
  const _WeekHero({required this.data});

  @override
  Widget build(BuildContext context) {
    final d = data;
    final q = d?.week?.qualifyingCount ?? 0;
    final target = d?.target ?? kDefaultWeeklyTarget;
    final ws = weekStartLocal(d?.refNow ?? DateTime.now());
    final today = (d?.refNow ?? DateTime.now()).weekday;
    const dayLetters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
    return HeroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MicroLabel('Minggu ini · target $target sesi', color: Colors.white70),
              const SizedBox(height: 8),
              Text(Fmt.weekRange(ws),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
              const SizedBox(height: 4),
              Text(
                '${d?.week?.sessionsCount ?? 0} sesi · ${Fmt.n0(d?.week?.activeMinTotal ?? 0)} menit aktif',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ]),
          ),
          RingProgress(
            value: target == 0 ? 0 : q / target,
            size: 74,
            stroke: 7,
            center: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$q/$target',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
              Text('SESI', style: AppText.label.copyWith(color: Colors.white70, fontSize: 8.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 1; i <= 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: (d?.trainedWeekdays.contains(i) ?? false)
                          ? Colors.white
                          : Colors.white.withValues(alpha: i == today ? 0.40 : 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(dayLetters[i - 1],
                      style: AppText.label.copyWith(
                          color: i == today ? Colors.white : Colors.white54, fontSize: 9.5)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        PillButton(
            label: 'Mulai latihan',
            icon: Icons.play_arrow_rounded,
            light: true,
            onPressed: () => openTraining(context)),
      ]),
    );
  }
}
