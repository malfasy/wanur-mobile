import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../logic/indicators.dart';
import '../theme/app_theme.dart';
import 'therapist_summary.dart';

/// Font standar PDF (Helvetica) hanya mendukung Latin-1, jadi beberapa karakter
/// diganti dengan padanan ASCII.
String _t(String s) => s
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('≥', '>=')
    .replaceAll('…', '...')
    .replaceAll('“', '"')
    .replaceAll('”', '"');

/// Bangun PDF ringkasan terapis.
Future<Uint8List> buildTherapistPdf(TherapistSummary s) async {
  final doc = pw.Document(title: 'Ringkasan latihan Wanur Glove', author: 'Wanur Glove');
  const accent = PdfColor.fromInt(0xFFE4572E);
  const ink = PdfColor.fromInt(0xFF17191E);
  const muted = PdfColor.fromInt(0xFF8F949D);
  const soft = PdfColor.fromInt(0xFFF3F1ED);

  pw.Widget h(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(_t(text), style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
        headers: headers.map(_t).toList(),
        data: rows.map((r) => r.map(_t).toList()).toList(),
        headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: ink),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: soft),
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE4E0D9), width: 0.5),
        ),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      );

  final period = '${Fmt.date(s.from)} - ${Fmt.date(s.to.subtract(const Duration(days: 1)))}';
  final presses = s.pressesTotal;
  final pct = fingerDistributionPct(presses);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      footer: (ctx) => pw.Row(children: [
        pw.Expanded(
          child: pw.Text(_t('$kNotClinicalDisclaimer. * nilai relatif, belum dikalibrasi dengan dinamometer.'),
              style: const pw.TextStyle(fontSize: 8, color: muted)),
        ),
        pw.Text('${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: muted)),
      ]),
      build: (ctx) => [
        pw.Text('RINGKASAN LATIHAN · WANUR GLOVE${s.scope == 'sim' ? ' · DATA SIMULASI' : ''}',
            style: const pw.TextStyle(fontSize: 9, color: muted, letterSpacing: 1)),
        pw.SizedBox(height: 4),
        pw.Text(_t(period), style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.SizedBox(height: 4),
        pw.Text(_t('Dibuat ${Fmt.date(DateTime.now())} ${Fmt.time(DateTime.now())}'),
            style: const pw.TextStyle(fontSize: 9, color: muted)),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFBE5DC)),
          child: pw.Text(_t('$kNotClinicalDisclaimer.'),
              style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accent)),
        ),
        h('Kepatuhan'),
        pw.Text(
          _t('${Fmt.pct(s.periodCompliancePct == null ? null : displayCompliance(s.periodCompliancePct!))} '
              '(${s.qualifyingTotal} dari ${s.targetTotal} sesi target; sesi dihitung bila durasi aktif >= 5 menit). '
              '${s.sessionsTotal} sesi, ${Fmt.n0(s.activeMinTotal)} menit aktif.'),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        table(
          ['Minggu', 'Sesi', 'Sesi >= 5 mnt', 'Target', 'Kepatuhan', 'Menit aktif'],
          [
            for (final w in s.weeks)
              [
                Fmt.weekRange(w.weekStart),
                '${w.sessionsCount}',
                '${w.qualifyingCount}',
                '${w.target}',
                Fmt.pct(w.compliancePct == null ? null : displayCompliance(w.compliancePct!)),
                Fmt.n0(w.activeMinTotal),
              ]
          ],
        ),
        h('Tren tes genggam (kg*)'),
        if (s.grips.isEmpty)
          pw.Text('Tidak ada tes genggam dalam periode ini.', style: const pw.TextStyle(fontSize: 10))
        else
          table(
            ['Tanggal', 'Tangan', 'Percobaan 1/2/3', 'Nilai tes', 'Dari tes pertama'],
            [
              for (final g in s.grips)
                [
                  '${Fmt.date(g.time)} ${Fmt.time(g.time)}',
                  g.handLabel,
                  g.trials.map(Fmt.n1).join(' / '),
                  Fmt.n1(g.value),
                  Fmt.pct(g.changeFromFirstPct, signed: true),
                ]
            ],
          ),
        h('Sebaran jari'),
        table(
          ['Jari', 'Tekanan', 'Persentase'],
          [
            for (var i = 0; i < 4; i++) [kFingerNames[i], Fmt.n0(presses[i]), Fmt.pct(pct?[i])],
          ],
        ),
        h('Kualitas data'),
        pw.Text(
          _t('Sambungan Bluetooth terputus ${s.disconnectsTotal} kali di ${s.sessionsWithDisconnect} sesi. '
              '${s.emptySessions} sesi tanpa tekanan, ${s.shortSessions} sesi di bawah 5 menit aktif.'),
          style: const pw.TextStyle(fontSize: 10),
        ),
        h('Daftar sesi'),
        table(
          ['Tanggal', 'Mulai', 'Durasi aktif (mnt)', 'Tekanan', 'Laju (/mnt)', 'Jeda med. (dtk)', 'Gaya med. (kg*)', 'Putus'],
          [
            for (final x in s.sessions)
              [
                Fmt.date(x.start),
                Fmt.time(x.start),
                Fmt.n1(x.activeMin),
                Fmt.n0(x.totalPresses),
                Fmt.n1(x.pressRate),
                Fmt.n1(x.ipiMedianS),
                Fmt.n1(x.forceMedian),
                '${x.bleDisconnects}',
              ]
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
