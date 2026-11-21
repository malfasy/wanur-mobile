import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_source_controller.dart';
import '../data/glove_data_source.dart';
import '../data/sim_profile.dart';
import '../services/indicator_exporter.dart';
import '../services/sim_importer.dart';
import '../services/training_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Pengaturan Pengembang: sumber data, impor profil simulasi, data beban T3,
/// hapus data, ekspor indikator (T2), dan halaman penghitung tombol (FR6).
/// Terlihat di build debug, atau di build lain setelah sapaan Beranda diketuk 7 kali.
class DevSettingsScreen extends StatefulWidget {
  const DevSettingsScreen({super.key});

  @override
  State<DevSettingsScreen> createState() => _DevSettingsScreenState();
}

class _DevSettingsScreenState extends State<DevSettingsScreen> {
  final List<KeyPress> _recentKeys = [];
  StreamSubscription<KeyPress>? _keySub;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _bindKeys();
  }

  void _bindKeys() {
    _keySub?.cancel();
    _keySub = context.read<DataSourceController>().current.keyEvents.listen((k) {
      if (!mounted) return;
      setState(() {
        _recentKeys.insert(0, k);
        if (_recentKeys.length > 6) _recentKeys.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _keySub?.cancel();
    super.dispose();
  }

  Future<void> _run(String label, Future<String> Function(void Function(String) status) job) async {
    setState(() => _busy = label);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await job((s) {
        if (mounted) setState(() => _busy = s);
      });
      messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
    } catch (e, st) {
      debugPrint('$e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _importProfile(int pid) async {
    final sources = context.read<DataSourceController>();
    if (!await _confirm('Impor profil $pid?',
        'Data simulasi yang ada sekarang akan diganti. Data glove nyata tidak disentuh.')) {
      return;
    }
    await _run('Mengimpor profil $pid…', (status) async {
      final p = await SimProfile.loadAsset(SimProfile.assetName(pid));
      final r = await SimImporter.importProfile(p);
      await sources.setSimProfileId(pid);
      if (!sources.useSim) await sources.setUseSim(true);
      sources.markDataChanged();
      return 'Profil $pid: ${r.sessions} sesi dan ${r.gripTests} tes genggam diimpor '
          'dalam ${r.elapsed.inMilliseconds} ms.';
    });
  }

  Future<void> _importLoad(int months) async {
    final sources = context.read<DataSourceController>();
    if (!await _confirm('Bangkitkan data $months bulan?',
        'Data simulasi yang ada sekarang akan diganti dengan data beban untuk uji waktu muat T3.')) {
      return;
    }
    await _run('Membangkitkan data $months bulan…', (status) async {
      final p = await SimProfile.loadAsset(SimProfile.loadAssetName(months));
      final r = await SimImporter.importProfile(p);
      if (!sources.useSim) await sources.setUseSim(true);
      sources.markDataChanged();
      debugPrint('[T3] dataset=${months}m sessions=${r.sessions} grip_tests=${r.gripTests}');
      return 'Data $months bulan siap: ${r.sessions} sesi. Buka tab Progres untuk mengukur waktu muat.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<DataSourceController>();
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Pengembang'),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(child: RoundIconButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy != null,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (_busy != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Callout(title: _busy!, bg: AppColors.limeSoft, dot: AppColors.ink),
              ),
            const SectionHeader('Sumber data'),
            AppCard(
              child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gunakan data simulasi'),
                  subtitle: Text(s.useSim
                      ? 'Aktif. Layar menampilkan data simulasi (source = sim).'
                      : 'Mati. Layar menampilkan data glove nyata (source = real).'),
                  value: s.useSim,
                  onChanged: (v) async {
                    await s.setUseSim(v);
                    _bindKeys();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Halaman penghitung tombol (FR6)'),
                  subtitle: const Text('Layar latihan membuka key_counter.html, bukan game.'),
                  value: s.useKeyCounter,
                  onChanged: s.setUseKeyCounter,
                ),
                if (!kDebugMode) ...[
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tampilkan menu pengembang'),
                    subtitle: const Text('Matikan untuk menyembunyikan ikon di Beranda.'),
                    value: s.devUnlocked,
                    onChanged: s.setDevUnlocked,
                  ),
                ],
              ]),
            ),
            const SectionHeader('Event keypad terakhir'),
            AppCard(
              child: _recentKeys.isEmpty
                  ? const Text(
                      'Belum ada event. Coba: adb shell input keyevent KEYCODE_F',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.muted),
                    )
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final k in _recentKeys)
                        Text(
                          '${Fmt.time(DateTime.fromMillisecondsSinceEpoch(k.tMs))}  '
                          '${k.char.isEmpty ? '(kode ${k.keyCode})' : k.char}  ${k.action}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                    ]),
            ),
            const SectionHeader('Impor profil simulasi'),
            for (var pid = 1; pid <= 10; pid++) ...[
              MenuRow(
                icon: Icons.person_outline_rounded,
                title: 'Profil $pid',
                subtitle: kSimProfileNames[pid],
                trailing: s.useSim && s.simProfileId == pid ? 'aktif' : null,
                onTap: () => _importProfile(pid),
              ),
              const SizedBox(height: 8),
            ],
            const SectionHeader('Uji waktu muat (T3)'),
            Row(children: [
              for (final m in [1, 3, 6]) ...[
                Expanded(
                  child: PillButton(label: '$m bulan', dark: true, onPressed: () => _importLoad(m)),
                ),
                if (m != 6) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 6),
            const Text('Lalu buka tab Progres. Waktu muat ditulis ke log dengan prefiks [T3].',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SectionHeader('Ekspor indikator (T2)'),
            PillButton(
              label: 'Ekspor semua profil (1–10)',
              icon: Icons.file_download_outlined,
              onPressed: () => _run('Mengekspor…', (status) async {
                final f = await IndicatorExporter.exportAllProfiles(onStatus: status);
                s.markDataChanged();
                if (!s.useSim) await s.setUseSim(true);
                await s.setSimProfileId(10);
                return 'Tersimpan: ${f.path}';
              }),
            ),
            const SizedBox(height: 8),
            PillButton(
              label: 'Ekspor data aktif saja',
              outlined: true,
              onPressed: () => _run('Mengekspor…', (status) async {
                final f = await IndicatorExporter.exportCurrent(s.scope);
                return 'Tersimpan: ${f.path}';
              }),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ambil dengan: adb pull /sdcard/Android/data/com.example.flutter_application_1/files/wanur_export/',
              style: TextStyle(fontSize: 12, color: AppColors.muted, fontFamily: 'monospace'),
            ),
            const SectionHeader('Data'),
            PillButton(
              label: 'Hapus semua data logbook',
              icon: Icons.delete_outline_rounded,
              outlined: true,
              onPressed: () async {
                if (!await _confirm('Hapus semua data?',
                    'Semua sesi, tes genggam, target, dan ringkasan (nyata dan simulasi) akan dihapus. '
                        'Arsip pengukuran lama tidak ikut dihapus.')) {
                  return;
                }
                await _run('Menghapus…', (_) async {
                  await TrainingRepository.instance.clearAll();
                  s.markDataChanged();
                  return 'Semua data logbook dihapus.';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
