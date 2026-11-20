import 'package:flutter/material.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/ui_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatTile menampilkan label, nilai, dan satuan', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: StatTile(label: 'Durasi aktif', value: '12,4', unit: 'menit')),
    ));
    expect(find.text('DURASI AKTIF'), findsOneWidget);
    expect(find.text('12,4'), findsOneWidget);
    expect(find.text('menit'), findsOneWidget);
  });
}
