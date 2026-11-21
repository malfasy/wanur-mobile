import 'package:material_ui/material_ui.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../data/data_source_controller.dart';
import '../data/glove_data_source.dart';
import '../logic/indicators.dart';
import '../providers/glove_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'touch_calibration_screen.dart';
import 'touch_edit_screen.dart';

/// Tab "Glove": koneksi BLE, bacaan langsung, keymap, dan kalibrasi jari.
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _connecting = false;

  Future<void> _autoConnect() async {
    final glove = context.read<GloveProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _connecting = true);
    try {
      final ok = await glove.autoConnectBondedDevice();
      messenger.showSnackBar(SnackBar(
          content: Text(ok ? 'Terhubung ke glove' : 'Glove yang sudah di-pair tidak ditemukan')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal menghubungkan: $e')));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glove = context.watch<GloveProvider>();
    final sources = context.watch<DataSourceController>();
    final connected = glove.isConnected;
    final keymap = glove.keymapString;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          const PageHeader(eyebrow: 'Perangkat', title: 'Wanur', highlight: 'Glove'),
          if (sources.useSim) const SimBanner('Mode simulasi · bacaan dari data simulasi'),
          HeroCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.lime : AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                MicroLabel(connected ? 'Terhubung' : 'Belum terhubung', color: Colors.white70),
              ]),
              const SizedBox(height: 12),
              Text(
                connected
                    ? (glove.connectedDevice?.platformName.isNotEmpty == true
                        ? glove.connectedDevice!.platformName
                        : 'MediGrip-Controller')
                    : 'Glove tidak terhubung',
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                connected
                    ? (glove.connectedDevice?.remoteId.toString() ?? '')
                    : 'Pastikan glove menyala dan sudah di-pair di Pengaturan Bluetooth.',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: PillButton(
                    label: _connecting ? 'Menghubungkan…' : (connected ? 'Hubungkan ulang' : 'Hubungkan'),
                    icon: Icons.bluetooth_rounded,
                    light: true,
                    onPressed: _connecting ? null : _autoConnect,
                  ),
                ),
                const SizedBox(width: 10),
                RoundIconButton(Icons.bluetooth_searching_rounded,
                    tooltip: 'Pindai perangkat',
                    size: 46,
                    bg: Colors.white.withValues(alpha: 0.18),
                    fg: Colors.white,
                    onTap: () => showScanDialog(context)),
              ]),
            ]),
          ),
          const SectionHeader('Bacaan langsung'),
          TileRow(children: [
            StreamBuilder<ForceSample>(
                stream: sources.current.forceSamples,
                builder: (context, snap) {
                  final kg = snap.data?.kg ?? (sources.useSim ? null : glove.data.hxValue / 1000.0);
                  return StatTile(
                      label: 'Gaya', icon: Icons.speed_rounded, value: Fmt.n1(kg), unit: 'kg*', sub: 'loadcell');
                },
              ),
            StatTile(
              label: 'Tombol',
              icon: Icons.keyboard_outlined,
              value: glove.data.lastKey == 'N/A' ? '–' : glove.data.lastKey.toUpperCase(),
              sub: _fingerFor(glove.data.lastKey, keymap) ?? 'terakhir ditekan',
            ),
          ]),
          const ForceFootnote(),
          const SectionHeader('Keymap'),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Column(children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: glove.data.lastKey == keymap[i] ? AppColors.accent : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(keymap[i].toUpperCase(),
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: glove.data.lastKey == keymap[i] ? Colors.white : AppColors.ink)),
                      ),
                      const SizedBox(height: 6),
                      Text(kFingerNames[i], style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 12),
              const Text(
                'Keypad terhubung sebagai keyboard Bluetooth. Setiap tekanan dicatat tanpa mengubah '
                'yang diterima game.',
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          MenuRow(
            icon: Icons.touch_app_outlined,
            title: 'Kalibrasi jari',
            subtitle: 'Tekan tiap jari secara berurutan',
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TouchCalibrationScreen())),
          ),
          const SizedBox(height: 10),
          MenuRow(
            icon: Icons.keyboard_alt_outlined,
            title: 'Ubah keymap',
            subtitle: 'Kirim huruf baru ke glove',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TouchEditScreen())),
          ),
        ],
      ),
    );
  }

  String? _fingerFor(String key, String keymap) {
    final i = keymap.indexOf(key);
    return i >= 0 && i < 4 ? kFingerNames[i] : null;
  }
}

/// Dialog pindai BLE (dipindah dari HomeScreen lama, alur pairing tetap sama).
void showScanDialog(BuildContext context) {
  final glove = context.read<GloveProvider>();
  glove.startScan();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetCtx) => SizedBox(
      height: MediaQuery.of(sheetCtx).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration:
                    BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(99))),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(
                child: Text('Pindai perangkat',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            Consumer<GloveProvider>(
              builder: (_, g, __) => TextButton(
                onPressed: g.isScanning ? null : g.startScan,
                child: Text(g.isScanning ? 'Memindai…' : 'Pindai ulang'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer<GloveProvider>(builder: (context, g, _) {
              if (g.scanResults.isEmpty) {
                return Center(
                  child: g.isScanning
                      ? const CircularProgressIndicator(color: AppColors.accent)
                      : const Text('Tidak ada perangkat ditemukan',
                          style: TextStyle(color: AppColors.muted)),
                );
              }
              return ListView.separated(
                itemCount: g.scanResults.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final r = g.scanResults[i];
                  final wanur = r.advertisementData.serviceUuids.any(
                      (u) => u.toString().toLowerCase() == GloveProvider.serviceUUID.toLowerCase());
                  final name = r.device.platformName.isEmpty
                      ? (wanur ? 'MediGrip Device' : 'Perangkat tanpa nama')
                      : r.device.platformName;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: wanur ? AppColors.accentSoft : AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(wanur ? Icons.back_hand_rounded : Icons.bluetooth,
                          color: wanur ? AppColors.accentDeep : AppColors.inkSoft, size: 20),
                    ),
                    title: Text(name,
                        style: TextStyle(fontWeight: wanur ? FontWeight.w700 : FontWeight.w500)),
                    subtitle: Text('${r.device.remoteId}${wanur ? ' · layanan Wanur terdeteksi' : ''}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Text('${r.rssi} dBm', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _connectWithPairingCheck(context, glove, r.device);
                    },
                  );
                },
              );
            }),
          ),
        ]),
      ),
    ),
  );
}

Future<void> _connectWithPairingCheck(BuildContext context, GloveProvider glove, BluetoothDevice device) async {
  final messenger = ScaffoldMessenger.of(context);
  final bonded = await glove.isDeviceBonded(device);
  if (!bonded) {
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Perlu pairing dulu'),
            content: const Text(
              'Perangkat ini belum di-pair. Keypad glove memakai mode keyboard Bluetooth, jadi perlu di-pair:\n\n'
              '1. Buka Pengaturan → Bluetooth\n'
              '2. Pilih "MediGrip-Controller"\n'
              '3. Ketuk untuk pair\n'
              '4. Kembali ke aplikasi ini dan pilih Lanjutkan',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sudah di-pair, lanjutkan')),
            ],
          ),
        ) ??
        false;
    if (!proceed) return;
  }
  try {
    await glove.connectToDevice(device);
    messenger.showSnackBar(const SnackBar(content: Text('Terhubung ke glove')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Gagal menghubungkan: $e')));
  }
}
