import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/services.dart' show rootBundle;

/// Nama singkat 10 profil simulasi (sama dengan tools/generate_profiles.py).
const Map<int, String> kSimProfileNames = {
  1: 'Teratur, genggam naik',
  2: 'Stabil',
  3: 'Menurun',
  4: 'Tidak teratur',
  5: 'Jeda 2 minggu',
  6: 'Kelingking jarang dipakai',
  7: 'Tes terlewat dan BLE sering putus',
  8: 'Latihan malam (lewat tengah malam)',
  9: 'Sesi kosong, pendek, dan timeout',
  10: 'Keymap berubah di tengah periode',
};

/// Satu sesi dalam file profil simulasi.
class SimSession {
  final int openMs;
  final int closeMs;
  final String keymap; // telunjuk, tengah, manis, kelingking
  final List<SimKey> keys;
  final List<SimForce> force;
  final List<SimBle> ble;
  final List<String> tags;

  SimSession({
    required this.openMs,
    required this.closeMs,
    required this.keymap,
    required this.keys,
    required this.force,
    required this.ble,
    required this.tags,
  });

  factory SimSession.fromJson(Map<String, dynamic> j) => SimSession(
        openMs: (j['open_ms'] as num).toInt(),
        closeMs: (j['close_ms'] as num).toInt(),
        keymap: j['keymap'] as String,
        keys: [
          for (final k in j['keys'] as List)
            SimKey((k[0] as num).toInt(), k[1] as String, (k[2] as num) == 1)
        ],
        force: [
          for (final f in j['force'] as List)
            SimForce((f[0] as num).toInt(), (f[1] as num).toInt())
        ],
        ble: [
          for (final b in j['ble'] as List)
            SimBle((b[0] as num).toInt(), (b[1] as num) == 1)
        ],
        tags: [for (final t in (j['tags'] as List? ?? const [])) t as String],
      );
}

class SimKey {
  final int tMs;
  final String char;
  final bool isDown;
  const SimKey(this.tMs, this.char, this.isDown);
}

class SimForce {
  final int tMs;
  final int raw;
  const SimForce(this.tMs, this.raw);
}

class SimBle {
  final int tMs;
  final bool connected;
  const SimBle(this.tMs, this.connected);
}

class SimGripTrial {
  final List<SimForce> rest;
  final List<SimForce> grip;
  const SimGripTrial(this.rest, this.grip);
}

class SimGripTest {
  final int tMs;
  final String hand; // 'right' / 'left'
  final List<SimGripTrial> trials;
  const SimGripTest(this.tMs, this.hand, this.trials);

  factory SimGripTest.fromJson(Map<String, dynamic> j) {
    List<SimForce> pts(List l) =>
        [for (final p in l) SimForce((p[0] as num).toInt(), (p[1] as num).toInt())];
    return SimGripTest(
      (j['t_ms'] as num).toInt(),
      j['hand'] as String,
      [
        for (final t in j['trials'] as List)
          SimGripTrial(pts(t['rest'] as List), pts(t['grip'] as List))
      ],
    );
  }
}

class SimProfile {
  final int profileId;
  final String name;
  final String description;
  final int weeklyTarget;
  final List<SimSession> sessions;
  final List<SimGripTest> gripTests;

  SimProfile({
    required this.profileId,
    required this.name,
    required this.description,
    required this.weeklyTarget,
    required this.sessions,
    required this.gripTests,
  });

  factory SimProfile.fromJson(Map<String, dynamic> j) => SimProfile(
        profileId: (j['profile_id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        weeklyTarget: (j['weekly_target'] as num?)?.toInt() ?? 5,
        sessions: [
          for (final s in j['sessions'] as List)
            SimSession.fromJson(s as Map<String, dynamic>)
        ],
        gripTests: [
          for (final g in j['grip_tests'] as List)
            SimGripTest.fromJson(g as Map<String, dynamic>)
        ],
      );

  static String assetName(int profileId) =>
      'assets/sim_profiles/profile_${profileId.toString().padLeft(2, '0')}.json.gz';

  static String loadAssetName(int months) => 'assets/sim_profiles/load_${months}m.json.gz';

  /// Muat profil dari aset. File disimpan sebagai JSON yang dikompresi gzip.
  static Future<SimProfile> loadAsset(String asset) async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final text = asset.endsWith('.gz') ? utf8.decode(gzip.decode(bytes)) : utf8.decode(bytes);
    return SimProfile.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }
}
