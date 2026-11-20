import 'package:flutter/material.dart';

import '../models/session_model.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Arsip pengukuran dari versi aplikasi sebelumnya (tabel `sessions`, skema v1).
/// Hanya dibaca: tidak ada tombol hapus dan tidak ada data baru yang ditulis ke sini.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Future<List<SessionModel>> _historyData = DatabaseHelper.instance.readAllSessions();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arsip pengukuran lama'),
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(child: RoundIconButton(Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
        ),
      ),
      body: FutureBuilder<List<SessionModel>>(
        future: _historyData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (snapshot.hasError) {
            return EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', body: '${snapshot.error}');
          }
          final sessions = snapshot.data ?? const <SessionModel>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              const Callout(
                title: 'Data dari versi sebelumnya',
                body: 'Pengukuran satu nilai ini disimpan sebelum Tes Genggam terpandu tersedia. '
                    'Ditampilkan apa adanya dan tidak dipakai di dashboard progres.',
                bg: AppColors.surfaceMuted,
                dot: AppColors.muted,
              ),
              const SizedBox(height: 14),
              if (sessions.isEmpty)
                const EmptyState(icon: Icons.inventory_2_outlined, title: 'Arsip kosong')
              else
                for (final item in sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildHistoryCard(item),
                  ),
              const ForceFootnote(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(SessionModel item) {
    final date = DateTime.tryParse(item.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        DateTile(date),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${Fmt.date(date)} · ${Fmt.time(date)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text('${Fmt.n1(item.kg)} kg*',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          ]),
        ),
        Tag(item.status),
      ]),
    );
  }
}
