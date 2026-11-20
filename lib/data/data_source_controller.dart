import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/glove_provider.dart';
import 'glove_data_source.dart';
import 'real_glove_source.dart';
import 'simulated_glove_source.dart';

/// Memilih sumber data aktif (glove nyata atau simulasi) dan menyimpan opsi
/// Pengaturan Pengembang. Layar membaca data dengan `scope` yang sama dengan
/// sumber aktif, jadi data simulasi tidak tercampur dengan data glove nyata.
class DataSourceController extends ChangeNotifier {
  static const _kMode = 'wanur_data_source';
  static const _kDevUnlocked = 'wanur_dev_unlocked';
  static const _kKeyCounter = 'wanur_use_key_counter';
  static const _kSimProfile = 'wanur_sim_profile';

  final GloveProvider glove;
  late final RealGloveSource real = RealGloveSource(glove);
  final SimulatedGloveSource sim = SimulatedGloveSource();

  bool _useSim = false;
  bool _devUnlocked = false;
  bool _useKeyCounter = false;
  int _simProfileId = 1;

  /// Naik setiap kali data logbook berubah (sesi/tes disimpan, impor, hapus),
  /// supaya layar yang terbuka memuat ulang.
  int dataVersion = 0;

  DataSourceController(this.glove) {
    glove.bindKeyStream(real.keyEvents);
  }

  bool get useSim => _useSim;
  bool get devUnlocked => kDebugMode || _devUnlocked;
  bool get useKeyCounter => _useKeyCounter;
  int get simProfileId => _simProfileId;
  GloveDataSource get current => _useSim ? sim : real;

  /// Nilai kolom `source` di database untuk sumber aktif.
  String get scope => _useSim ? 'sim' : 'real';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _useSim = p.getBool(_kMode) ?? false;
    _devUnlocked = p.getBool(_kDevUnlocked) ?? false;
    _useKeyCounter = p.getBool(_kKeyCounter) ?? false;
    _simProfileId = p.getInt(_kSimProfile) ?? 1;
    _apply();
    notifyListeners();
  }

  void _apply() {
    if (_useSim) {
      sim.activate();
    } else {
      sim.deactivate();
    }
    glove.bindKeyStream(current.keyEvents);
  }

  Future<void> setUseSim(bool v) async {
    _useSim = v;
    _apply();
    dataVersion++;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kMode, v);
  }

  Future<void> setDevUnlocked(bool v) async {
    _devUnlocked = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kDevUnlocked, v);
  }

  Future<void> setUseKeyCounter(bool v) async {
    _useKeyCounter = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kKeyCounter, v);
  }

  Future<void> setSimProfileId(int id) async {
    _simProfileId = id;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kSimProfile, id);
  }

  void markDataChanged() {
    dataVersion++;
    notifyListeners();
  }

  @override
  void dispose() {
    sim.dispose();
    super.dispose();
  }
}
