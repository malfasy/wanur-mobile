import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/data_source_controller.dart';
import '../data/sim_profile.dart';
import '../logic/session_recorder.dart';
import '../providers/glove_provider.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Layar latihan. Membuka game di WebView dan merekam sesi otomatis:
/// sesi mulai saat layar dibuka dan berakhir saat layar ditutup atau setelah
/// 120 s tanpa tekanan. Key event tetap diteruskan ke game tanpa perubahan
/// (lihat MainActivity.dispatchKeyEvent).
class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({super.key});

  static const gameUrl = 'https://www.onlinegames.io/magic-tiles-3/';
  static const keyCounterAsset = 'assets/test/key_counter.html';

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  late final WebViewController controller;
  late final SessionRecorder _recorder;
  late final DataSourceController _sources;
  late final bool _keyCounter;
  bool isLoading = true;
  String? _simKeymap;
  double? _simProgress;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _sources = context.read<DataSourceController>();
    final glove = context.read<GloveProvider>();
    final scope = _sources.scope;
    final profileId = _sources.useSim ? _sources.simProfileId : null;
    _keyCounter = _sources.useKeyCounter;

    _recorder = SessionRecorder(
      source: _sources.current,
      keymapProvider: () => _simKeymap ?? glove.keymapString,
      saver: (raw, ind) async {
        await TrainingRepository.instance.saveSession(raw, ind, source: scope, profileId: profileId);
        _sources.markDataChanged();
        debugPrint('[SessionRecorder] sesi tersimpan: ${ind.totalPresses} tekanan, '
            '${ind.activeMin.toStringAsFixed(2)} menit aktif, berakhir: ${ind.endReason}');
      },
    )..start();
    // Perbarui jam sesi di layar tiap detik.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal memuat game: ${error.description}')),
            );
          },
        ),
      );
    if (_keyCounter) {
      controller.loadFlutterAsset(GameWebViewScreen.keyCounterAsset);
    } else {
      controller.loadRequest(Uri.parse(GameWebViewScreen.gameUrl));
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (_sources.useSim) _sources.sim.stopPlayback();
    // Sesi berakhir saat layar ditutup. Penyimpanan berjalan di latar.
    _recorder.stop().whenComplete(_recorder.dispose);
    super.dispose();
  }

  Future<void> _playSim() async {
    final choice = await showModalBottomSheet<(int, double)>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _SimPlaySheet(profileId: _sources.simProfileId),
    );
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final profile = await SimProfile.loadAsset(SimProfile.assetName(_sources.simProfileId));
    final candidates = profile.sessions.where((s) => s.keys.isNotEmpty).toList();
    if (candidates.isEmpty) return;
    final s = candidates[choice.$1 < candidates.length ? choice.$1 : candidates.length - 1];
    _simKeymap = s.keymap;
    setState(() => _simProgress = 0);
    messenger.showSnackBar(SnackBar(
        content: Text('Memutar sesi ${Fmt.dayDate(DateTime.fromMillisecondsSinceEpoch(s.openMs))} '
            'dengan kecepatan ${choice.$2.toStringAsFixed(0)}x')));
    await _sources.sim.playSession(s, speed: choice.$2, onProgress: (p) {
      if (mounted && (p - (_simProgress ?? 0)).abs() > 0.01) setState(() => _simProgress = p);
    });
    if (mounted) setState(() => _simProgress = null);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: RoundIconButton(Icons.close_rounded,
                tooltip: 'Selesai latihan', onTap: () => Navigator.pop(context)),
          ),
        ),
        title: Column(children: [
          Text(_keyCounter ? 'Penghitung tombol (uji FR6)' : 'Latihan jari'),
          const Text('Sesi direkam otomatis',
              style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: RoundIconButton(Icons.refresh_rounded, tooltip: 'Muat ulang', onTap: controller.reload),
          ),
        ],
      ),
      body: Column(children: [
        ValueListenableBuilder<LiveSessionStatus>(
          valueListenable: _recorder.status,
          builder: (context, st, _) => _SessionStrip(status: st, simProgress: _simProgress),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(children: [
              WebViewWidget(controller: controller),
              if (isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ]),
          ),
        ),
      ]),
      floatingActionButton: _sources.useSim && _simProgress == null
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.dark,
              foregroundColor: Colors.white,
              onPressed: _playSim,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Putar sesi simulasi'),
            )
          : null,
    );
  }
}

class _SessionStrip extends StatelessWidget {
  final LiveSessionStatus status;
  final double? simProgress;
  const _SessionStrip({required this.status, this.simProgress});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = status.startMs == null ? 0 : now - status.startMs!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: status.active ? AppColors.accent : Colors.white24,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            status.active
                ? 'Merekam · ${Fmt.clock(elapsed)} · ${status.presses} tekanan'
                : 'Menunggu tekanan · sesi baru dimulai saat tombol ditekan',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (simProgress != null)
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              value: simProgress,
              strokeWidth: 3,
              color: AppColors.lime,
              backgroundColor: Colors.white12,
            ),
          )
        else if (status.savedCount > 0)
          Tag('${status.savedCount} tersimpan', bg: Colors.white12, fg: Colors.white70),
      ]),
    );
  }
}

class _SimPlaySheet extends StatefulWidget {
  final int profileId;
  const _SimPlaySheet({required this.profileId});

  @override
  State<_SimPlaySheet> createState() => _SimPlaySheetState();
}

class _SimPlaySheetState extends State<_SimPlaySheet> {
  double _speed = 1;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Putar sesi simulasi', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Profil ${widget.profileId} · ${kSimProfileNames[widget.profileId] ?? ''}',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          const MicroLabel('Sesi ke-'),
          const SizedBox(height: 8),
          Segmented<int>(
            items: const [(0, '1'), (1, '2'), (2, '3'), (3, '4')],
            value: _index,
            onChanged: (v) => setState(() => _index = v),
          ),
          const SizedBox(height: 16),
          const MicroLabel('Kecepatan'),
          const SizedBox(height: 8),
          Segmented<double>(
            items: const [(1.0, '1x (waktu nyata)'), (5.0, '5x'), (20.0, '20x')],
            value: _speed,
            onChanged: (v) => setState(() => _speed = v),
          ),
          const SizedBox(height: 10),
          const Text(
            'Event diberi timestamp waktu sekarang, jadi pada kecepatan > 1x durasi yang tercatat ikut lebih pendek. '
            'Untuk impor data dengan timestamp asli, pakai Pengaturan Pengembang.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          PillButton(label: 'Putar', onPressed: () => Navigator.pop(context, (_index, _speed))),
        ]),
      ),
    );
  }
}
