import 'package:flutter_application_1/data/sim_profile.dart';
import 'package:flutter_application_1/logic/sim_replay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('satu sesi file timeout -> satu sesi, selesai di event terakhir', () {
    final s = SimSession(
      openMs: 0,
      closeMs: 400000,
      keymap: 'fghj',
      keys: const [SimKey(5000, 'f', true), SimKey(5100, 'f', false), SimKey(9000, 'j', true)],
      force: const [SimForce(1000, 400), SimForce(6000, 800), SimForce(300000, 900)],
      ble: const [],
      tags: const [],
    );
    final out = replaySimSession(s);
    expect(out.length, 1);
    expect(out.single.endMs, 9000);
    expect(out.single.endReason, 'timeout');
    expect(out.single.force.length, 2);
  });

  test('sesi kosong yang ditutup sebelum timeout tetap tercatat', () {
    final s = SimSession(
        openMs: 0, closeMs: 60000, keymap: 'fghj', keys: const [], force: const [], ble: const [], tags: const []);
    final out = replaySimSession(s);
    expect(out.length, 1);
    expect(out.single.endMs, 60000);
  });
}
