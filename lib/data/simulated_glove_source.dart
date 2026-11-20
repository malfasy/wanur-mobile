import 'dart:async';
import 'dart:math';

import 'glove_data_source.dart';
import 'sim_profile.dart';

/// Sumber data simulasi.
///
/// Dua kegunaan:
/// 1. Aliran gaya "diam" (2 Hz) yang naik saat [hintGripPhase] true, untuk
///    mencoba Tes Genggam tanpa glove.
/// 2. [playSession]: memutar satu sesi dari file profil secara langsung (waktu
///    nyata) di layar latihan, untuk demo. Timestamp event = waktu sekarang.
///
/// Impor profil seketika (memakai timestamp dari file) tidak lewat kelas ini,
/// melainkan lewat `SimImporter` yang memberi event langsung ke mesin sesi.
class SimulatedGloveSource extends GloveDataSource {
  final _keys = StreamController<KeyPress>.broadcast();
  final _force = StreamController<ForceSample>.broadcast();
  final _conn = StreamController<bool>.broadcast();
  final _rng = Random(7);

  Timer? _idleTimer;
  bool _connected = true;
  bool _gripping = false;
  int _gripStartMs = 0;
  double _gripPeakRaw = 9000;
  int _playToken = 0;
  bool _playing = false;

  @override
  String get id => 'sim';

  @override
  Stream<KeyPress> get keyEvents => _keys.stream;

  @override
  Stream<ForceSample> get forceSamples => _force.stream;

  @override
  Stream<bool> get connectionState => _conn.stream;

  @override
  bool get isConnected => _connected;

  bool get isPlaying => _playing;

  void activate() {
    _idleTimer ??= Timer.periodic(const Duration(milliseconds: 500), (_) => _emitIdle());
  }

  void deactivate() {
    _idleTimer?.cancel();
    _idleTimer = null;
    stopPlayback();
  }

  @override
  void hintGripPhase(bool gripping) {
    if (gripping && !_gripping) {
      _gripStartMs = DateTime.now().millisecondsSinceEpoch;
      _gripPeakRaw = 8000 + _rng.nextDouble() * 4000;
    }
    _gripping = gripping;
  }

  void _emitIdle() {
    if (_playing || !_connected) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    var v = 320 + _rng.nextDouble() * 40 - 20;
    if (_gripping) {
      final x = ((now - _gripStartMs) / 5000).clamp(0.0, 1.0).toDouble();
      v += _gripPeakRaw * pow(sin(pi * min(1.0, x * 1.15)), 0.6) + _rng.nextDouble() * 60 - 30;
    }
    _force.add(ForceSample(raw: v.round(), tMs: now));
  }

  /// Simulasikan sambungan terputus / tersambung lagi (untuk demo kualitas data).
  void setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    _conn.add(connected);
  }

  /// Putar satu sesi profil secara langsung. [speed] > 1 mempercepat pemutaran;
  /// karena timestamp memakai waktu sekarang, durasi yang tercatat ikut terpendek.
  Future<void> playSession(SimSession s, {double speed = 1.0, void Function(double)? onProgress}) async {
    final token = ++_playToken;
    _playing = true;
    final timeline = <({int t, void Function() emit})>[];
    for (final k in s.keys) {
      timeline.add((
        t: k.tMs,
        emit: () => _keys.add(KeyPress(
            char: k.char, isDown: k.isDown, tMs: DateTime.now().millisecondsSinceEpoch))
      ));
    }
    for (final f in s.force) {
      timeline.add((
        t: f.tMs,
        emit: () => _force.add(ForceSample(raw: f.raw, tMs: DateTime.now().millisecondsSinceEpoch))
      ));
    }
    for (final b in s.ble) {
      timeline.add((t: b.tMs, emit: () => setConnected(b.connected)));
    }
    timeline.sort((a, b) => a.t.compareTo(b.t));
    if (timeline.isEmpty) {
      _playing = false;
      return;
    }
    final t0 = timeline.first.t;
    final wall0 = DateTime.now().millisecondsSinceEpoch;
    final total = max(1, timeline.last.t - t0);
    for (final item in timeline) {
      if (token != _playToken) break;
      final dueWall = wall0 + ((item.t - t0) / speed).round();
      final wait = dueWall - DateTime.now().millisecondsSinceEpoch;
      if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
      if (token != _playToken) break;
      item.emit();
      onProgress?.call((item.t - t0) / total);
    }
    if (token == _playToken) {
      _playing = false;
      setConnected(true);
    }
  }

  void stopPlayback() {
    _playToken++;
    _playing = false;
    setConnected(true);
  }

  void dispose() {
    deactivate();
    _keys.close();
    _force.close();
    _conn.close();
  }
}
