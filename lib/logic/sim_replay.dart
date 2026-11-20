import '../data/glove_data_source.dart';
import '../data/sim_profile.dart';
import 'session_machine.dart';

/// Proses satu sesi file profil lewat [SessionMachine] memakai timestamp dari
/// file (bukan waktu nyata). Sebelum setiap event, mesin diberi `tick` pada
/// waktu event itu, sama seperti timer 1 s pada perekam langsung.
List<RawSession> replaySimSession(SimSession s, {int timeoutMs = 120000}) {
  final m = SessionMachine(timeoutMs: timeoutMs);
  final out = <RawSession>[];
  void add(RawSession? r) {
    if (r != null) out.add(r);
  }

  // urutan: 0 = ble, 1 = force, 2 = key (stabil untuk timestamp yang sama)
  final timeline = <({int t, int kind, int i})>[
    for (var i = 0; i < s.ble.length; i++) (t: s.ble[i].tMs, kind: 0, i: i),
    for (var i = 0; i < s.force.length; i++) (t: s.force[i].tMs, kind: 1, i: i),
    for (var i = 0; i < s.keys.length; i++) (t: s.keys[i].tMs, kind: 2, i: i),
  ]..sort((a, b) {
      final c = a.t.compareTo(b.t);
      if (c != 0) return c;
      final k = a.kind.compareTo(b.kind);
      return k != 0 ? k : a.i.compareTo(b.i);
    });

  m.open(s.openMs, s.keymap);
  for (final e in timeline) {
    if (e.t < s.openMs || e.t > s.closeMs) continue;
    add(m.tick(e.t));
    switch (e.kind) {
      case 0:
        m.ble(BleEvent(e.t, s.ble[e.i].connected));
      case 1:
        m.force(ForceSample(raw: s.force[e.i].raw, tMs: e.t));
      default:
        final k = s.keys[e.i];
        add(m.key(KeyPress(char: k.char, isDown: k.isDown, tMs: k.tMs)));
    }
  }
  add(m.close(s.closeMs));
  return out;
}
