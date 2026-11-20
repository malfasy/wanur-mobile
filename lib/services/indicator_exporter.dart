import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/sim_profile.dart';
import '../logic/indicators.dart';
import 'sim_importer.dart';
import 'training_repository.dart';

/// Ekspor indikator tersimpan ke JSON untuk uji kesesuaian T2
/// (`tools/verify_indicators.py`). File ditulis ke folder aplikasi di
/// penyimpanan eksternal sehingga bisa diambil dengan:
///
///   adb pull /sdcard/Android/data/com.example.flutter_application_1/files/wanur_export/
class IndicatorExporter {
  static Future<Directory> exportDir() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/wanur_export');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Semua indikator untuk satu sumber data (per sesi, per minggu, per tes).
  static Future<Map<String, dynamic>> collect(String source, {int? profileId}) async {
    final repo = TrainingRepository.instance;
    final sessions = (await repo.sessions(source)).reversed.toList();
    final weeks = await repo.weeklySummaries(source);
    final tests = await repo.gripTests(source);
    return {
      'profile_id': profileId,
      'source': source,
      'sessions': [
        for (final s in sessions)
          {
            'start_ms': s.startMs,
            'end_ms': s.endMs,
            'keymap': s.keymap,
            'end_reason': s.endReason,
            'active_min': s.activeMin,
            'presses': s.presses,
            'total_presses': s.totalPresses,
            'press_rate': s.pressRate,
            'ipi_median_s': s.ipiMedianS,
            'force_median': s.forceMedian,
            'ble_disconnects': s.bleDisconnects,
            'qualifies_for_target': s.qualifiesForTarget,
            'least_used_finger': s.leastUsedFinger,
            'week_start_ms': s.weekStartMs,
          }
      ],
      'weeks': [
        for (final w in weeks)
          {
            'week_start_ms': w.weekStartMs,
            'sessions': w.sessionsCount,
            'qualifying_sessions': w.qualifyingCount,
            'active_min_total': w.activeMinTotal,
            'presses': w.presses,
            'finger_pct': fingerDistributionPct(w.presses),
            'target': w.target,
            'compliance_pct': w.compliancePct,
          }
      ],
      'grip_tests': [
        for (final g in tests)
          {
            't_ms': g.tMs,
            'hand': g.hand,
            'trials': g.trials,
            'value': g.value,
            'change_from_first_pct': g.changeFromFirstPct,
          }
      ],
    };
  }

  static Map<String, dynamic> _envelope(List<Map<String, dynamic>> profiles) {
    final now = DateTime.now();
    return {
      'format_version': 1,
      'exported_at': now.toIso8601String(),
      'utc_offset_minutes': now.timeZoneOffset.inMinutes,
      'tz_name': now.timeZoneName,
      'profiles': profiles,
    };
  }

  static Future<File> _write(Map<String, dynamic> data, String name) async {
    final dir = await exportDir();
    final f = File('${dir.path}/$name');
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
    return f;
  }

  /// Ekspor data yang ada sekarang untuk [source].
  static Future<File> exportCurrent(String source) async {
    final data = _envelope([await collect(source)]);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return _write(data, 'indicators_${source}_$stamp.json');
  }

  /// Impor profil 1..10 satu per satu, ekspor indikator masing-masing, dan
  /// gabungkan ke satu file. Data simulasi yang tersisa setelahnya = profil 10.
  static Future<File> exportAllProfiles({void Function(String status)? onStatus}) async {
    final out = <Map<String, dynamic>>[];
    for (var pid = 1; pid <= 10; pid++) {
      onStatus?.call('Impor profil $pid dari 10...');
      final p = await SimProfile.loadAsset(SimProfile.assetName(pid));
      await SimImporter.importProfile(p);
      out.add(await collect('sim', profileId: pid));
    }
    onStatus?.call('Menulis file...');
    return _write(_envelope(out), 'indicators_all_profiles.json');
  }
}
