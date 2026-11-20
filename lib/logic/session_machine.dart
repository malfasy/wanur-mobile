import '../data/glove_data_source.dart';
import 'indicators.dart';

/// Kejadian koneksi BLE selama sesi.
class BleEvent {
  final int tMs;
  final bool connected;
  const BleEvent(this.tMs, this.connected);
}

/// Data mentah satu sesi yang sudah selesai.
class RawSession {
  final int startMs;
  final int endMs;
  final String keymap;
  final List<KeyPress> keys;
  final List<ForceSample> force;
  final List<BleEvent> ble;

  /// 'closed' (layar ditutup) atau 'timeout' (120 s tanpa event keypad).
  final String endReason;

  const RawSession({
    required this.startMs,
    required this.endMs,
    required this.keymap,
    required this.keys,
    required this.force,
    required this.ble,
    required this.endReason,
  });
}

/// Indikator satu sesi, dihitung sekali saat sesi disimpan.
class SessionIndicators {
  final int startMs;
  final int endMs;
  final String keymap;
  final double activeMin;
  final List<int> pressesPerFinger; // telunjuk, tengah, manis, kelingking
  final int totalPresses;
  final double? pressRate;
  final double? ipiMedianS;
  final double? forceMedian; // kg*
  final int bleDisconnects;
  final bool qualifiesForTarget;
  final int? leastUsedFinger;
  final String endReason;

  const SessionIndicators({
    required this.startMs,
    required this.endMs,
    required this.keymap,
    required this.activeMin,
    required this.pressesPerFinger,
    required this.totalPresses,
    required this.pressRate,
    required this.ipiMedianS,
    required this.forceMedian,
    required this.bleDisconnects,
    required this.qualifiesForTarget,
    required this.leastUsedFinger,
    required this.endReason,
  });

  int get durationMs => endMs - startMs;
}

/// Hitung semua indikator sesi dari data mentah (fungsi murni).
SessionIndicators computeSessionIndicators(RawSession s) {
  final downs = s.keys.where((k) => k.isDown && k.tMs >= s.startMs && k.tMs <= s.endMs).toList();
  final downTimes = [for (final k in downs) k.tMs];
  final perFinger = pressesPerFinger(downs.map((k) => k.char), s.keymap);
  final total = perFinger.fold<int>(0, (a, b) => a + b);
  final activeMs = activeDurationMs(startMs: s.startMs, endMs: s.endMs, downTimesMs: downTimes);
  final activeMin = activeMs / 60000.0;
  final forceKg = [
    for (final f in s.force)
      if (f.tMs >= s.startMs && f.tMs <= s.endMs) f.kg
  ];
  final disconnects =
      s.ble.where((b) => !b.connected && b.tMs >= s.startMs && b.tMs <= s.endMs).length;
  return SessionIndicators(
    startMs: s.startMs,
    endMs: s.endMs,
    keymap: s.keymap,
    activeMin: activeMin,
    pressesPerFinger: perFinger,
    totalPresses: total,
    pressRate: pressRate(total, activeMin),
    ipiMedianS: ipiMedianSeconds(downTimes),
    forceMedian: median(forceKg),
    bleDisconnects: disconnects,
    qualifiesForTarget: activeMin >= kQualifyingActiveMin,
    leastUsedFinger: leastUsedFinger(perFinger),
    endReason: s.endReason,
  );
}

class _Builder {
  final int startMs;
  final String keymap;
  final keys = <KeyPress>[];
  final force = <ForceSample>[];
  final ble = <BleEvent>[];
  int? lastKeyEventMs;
  _Builder(this.startMs, this.keymap);
}

/// Mesin status sesi (tanpa timer, tanpa jam sistem).
///
/// Aturan: sesi mulai saat layar latihan dibuka; berakhir saat layar ditutup
/// (waktu selesai = waktu tutup) atau setelah 120 s tanpa event keypad (waktu
/// selesai = event keypad terakhir; bila belum ada event sama sekali, waktu
/// selesai = waktu mulai). Bila layar masih terbuka setelah timeout, sesi baru
/// dimulai pada event keypad berikutnya.
///
/// Dipakai oleh perekam langsung (dengan Timer) dan oleh impor simulasi (dengan
/// timestamp dari file), sehingga keduanya memakai aturan yang sama persis.
class SessionMachine {
  final int timeoutMs;
  bool _screenOpen = false;
  _Builder? _cur;
  String _keymap = 'fghj';

  SessionMachine({this.timeoutMs = kSessionTimeoutMs});

  bool get screenOpen => _screenOpen;
  bool get hasActiveSession => _cur != null;
  int? get activeStartMs => _cur?.startMs;
  int get activePresses => _cur?.keys.where((k) => k.isDown).length ?? 0;
  int? get lastKeyEventMs => _cur?.lastKeyEventMs;

  void setKeymap(String keymap) => _keymap = keymap;

  /// Layar latihan dibuka.
  void open(int tMs, String keymap) {
    _keymap = keymap;
    _screenOpen = true;
    _cur = _Builder(tMs, keymap);
  }

  /// Cek timeout pada waktu [nowMs]. Mengembalikan sesi yang selesai, bila ada.
  RawSession? tick(int nowMs) {
    final c = _cur;
    if (c == null) return null;
    final last = c.lastKeyEventMs;
    if (last != null) {
      if (nowMs - last > timeoutMs) return _finish(last, 'timeout');
    } else if (nowMs - c.startMs > timeoutMs) {
      return _finish(c.startMs, 'timeout');
    }
    return null;
  }

  /// Event keypad. Mengembalikan sesi sebelumnya bila event ini datang setelah timeout.
  RawSession? key(KeyPress k) {
    final done = tick(k.tMs);
    if (!_screenOpen) return done;
    _cur ??= _Builder(k.tMs, _keymap);
    _cur!.keys.add(k);
    _cur!.lastKeyEventMs = k.tMs;
    return done;
  }

  void force(ForceSample f) => _cur?.force.add(f);

  void ble(BleEvent e) => _cur?.ble.add(e);

  /// Layar latihan ditutup.
  RawSession? close(int tMs) {
    final done = tick(tMs);
    _screenOpen = false;
    if (done != null) return done;
    if (_cur != null) return _finish(tMs, 'closed');
    return null;
  }

  RawSession _finish(int endMs, String reason) {
    final c = _cur!;
    _cur = null;
    return RawSession(
      startMs: c.startMs,
      endMs: endMs < c.startMs ? c.startMs : endMs,
      keymap: c.keymap,
      keys: c.keys.where((k) => k.tMs <= endMs).toList(),
      force: c.force.where((f) => f.tMs >= c.startMs && f.tMs <= endMs).toList(),
      ble: c.ble.where((b) => b.tMs >= c.startMs && b.tMs <= endMs).toList(),
      endReason: reason,
    );
  }
}
