import 'package:flutter_application_1/data/glove_data_source.dart';
import 'package:flutter_application_1/logic/session_machine.dart';
import 'package:flutter_test/flutter_test.dart';

KeyPress down(String c, int t) => KeyPress(char: c, isDown: true, tMs: t);
KeyPress up(String c, int t) => KeyPress(char: c, isDown: false, tMs: t);

void main() {
  test('sesi ditutup: waktu selesai = waktu tutup', () {
    final m = SessionMachine();
    m.open(0, 'fghj');
    expect(m.key(down('f', 1000)), isNull);
    m.key(up('f', 1100));
    final s = m.close(5000)!;
    expect(s.startMs, 0);
    expect(s.endMs, 5000);
    expect(s.endReason, 'closed');
    expect(s.keys.length, 2);
  });

  test('timeout 120 s: waktu selesai = event terakhir', () {
    final m = SessionMachine();
    m.open(0, 'fghj');
    m.key(down('f', 1000));
    m.key(up('f', 1200));
    expect(m.tick(1200 + 120000), isNull); // tepat 120 s belum timeout
    final s = m.tick(1200 + 120001)!;
    expect(s.endMs, 1200);
    expect(s.endReason, 'timeout');
    expect(m.close(400000), isNull); // tidak ada sesi aktif lagi
  });

  test('sesi kosong yang timeout: waktu selesai = waktu mulai', () {
    final m = SessionMachine();
    m.open(10000, 'fghj');
    final s = m.tick(10000 + 120001)!;
    expect(s.startMs, 10000);
    expect(s.endMs, 10000);
    expect(computeSessionIndicators(s).activeMin, 0);
  });

  test('tekanan setelah timeout memulai sesi baru (layar masih terbuka)', () {
    final m = SessionMachine();
    m.open(0, 'fghj');
    m.key(down('f', 1000));
    final first = m.key(down('g', 200000));
    expect(first, isNotNull);
    expect(first!.endMs, 1000);
    final second = m.close(205000)!;
    expect(second.startMs, 200000);
    expect(second.keys.single.char, 'g');
  });

  test('sampel gaya dan BLE hanya dalam jendela sesi', () {
    final m = SessionMachine();
    m.open(0, 'fghj');
    m.force(const ForceSample(raw: 1000, tMs: 500));
    m.key(down('f', 1000));
    m.ble(const BleEvent(2000, false));
    m.ble(const BleEvent(3000, true));
    m.force(const ForceSample(raw: 3000, tMs: 100000)); // setelah event terakhir
    final s = m.tick(1000 + 120001)!;
    final ind = computeSessionIndicators(s);
    expect(ind.forceMedian, 1.0);
    expect(ind.bleDisconnects, 1);
  });

  test('indikator sesi lengkap', () {
    final m = SessionMachine();
    m.open(0, 'fghj');
    // 6 menit, tekanan tiap 2 s: f g h f g h ...
    const chars = ['f', 'g', 'h'];
    for (var i = 0; i < 180; i++) {
      m.key(down(chars[i % 3], 2000 + i * 2000));
    }
    final s = m.close(2000 + 179 * 2000 + 1000)!;
    final ind = computeSessionIndicators(s);
    expect(ind.totalPresses, 180);
    expect(ind.pressesPerFinger, [60, 60, 60, 0]);
    expect(ind.leastUsedFinger, 3);
    expect(ind.ipiMedianS, 2.0);
    expect(ind.activeMin, closeTo(s.endMs / 60000.0, 1e-9));
    expect(ind.qualifiesForTarget, isTrue);
    expect(ind.pressRate, closeTo(180 / ind.activeMin, 1e-9));
  });

  test('sesi < 5 menit tidak dihitung untuk kepatuhan', () {
    final m = SessionMachine();
    m.open(0, 'fghj');
    for (var i = 0; i < 100; i++) {
      m.key(down('f', i * 2000));
    }
    final ind = computeSessionIndicators(m.close(200000)!);
    expect(ind.activeMin, lessThan(5));
    expect(ind.qualifiesForTarget, isFalse);
  });
}
