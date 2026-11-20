import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/glove_data_source.dart';
import 'session_machine.dart';

typedef SessionSaver = Future<void> Function(RawSession raw, SessionIndicators indicators);

/// Status singkat sesi yang sedang berjalan, untuk ditampilkan di layar latihan.
class LiveSessionStatus {
  final bool active;
  final int? startMs;
  final int presses;
  final int savedCount;
  const LiveSessionStatus({this.active = false, this.startMs, this.presses = 0, this.savedCount = 0});
}

/// Perekam sesi langsung. Menerima key event, sampel gaya, dan status koneksi
/// dari [GloveDataSource], menerapkan aturan sesi lewat [SessionMachine]
/// (timer 1 s untuk timeout 120 s), menghitung indikator dengan fungsi murni,
/// lalu menyimpan lewat [saver].
class SessionRecorder {
  final GloveDataSource source;
  final SessionSaver saver;
  final String Function() keymapProvider;
  final int Function() clock;

  final SessionMachine _machine = SessionMachine();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _ticker;
  int _saved = 0;
  Future<void> _pending = Future.value();

  final ValueNotifier<LiveSessionStatus> status = ValueNotifier(const LiveSessionStatus());

  SessionRecorder({
    required this.source,
    required this.saver,
    required this.keymapProvider,
    int Function()? clock,
  }) : clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Dipanggil saat layar latihan dibuka.
  void start() {
    _machine.open(clock(), keymapProvider());
    _subs.add(source.keyEvents.listen((k) {
      _machine.setKeymap(keymapProvider());
      _handle(_machine.key(k));
      _publish();
    }));
    _subs.add(source.forceSamples.listen(_machine.force));
    _subs.add(source.connectionState.listen((c) => _machine.ble(BleEvent(clock(), c))));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _handle(_machine.tick(clock()));
      _publish();
    });
    _publish();
  }

  /// Dipanggil saat layar latihan ditutup. Menunggu penyimpanan selesai.
  Future<void> stop() async {
    _ticker?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _handle(_machine.close(clock()));
    _publish();
    await _pending;
  }

  void _handle(RawSession? done) {
    if (done == null) return;
    final ind = computeSessionIndicators(done);
    _saved++;
    _pending = _pending.then((_) => saver(done, ind)).catchError((Object e) {
      debugPrint('[SessionRecorder] gagal menyimpan sesi: $e');
    });
  }

  void _publish() {
    status.value = LiveSessionStatus(
      active: _machine.hasActiveSession,
      startMs: _machine.activeStartMs,
      presses: _machine.activePresses,
      savedCount: _saved,
    );
  }

  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    status.dispose();
  }
}
