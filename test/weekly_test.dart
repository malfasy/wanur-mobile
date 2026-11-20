import 'package:flutter_application_1/logic/weekly.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final w1 = DateTime(2026, 11, 2).millisecondsSinceEpoch; // Senin
  final w2 = DateTime(2026, 11, 9).millisecondsSinceEpoch;
  final w3 = DateTime(2026, 11, 16).millisecondsSinceEpoch;

  test('tanpa target -> default 5', () => expect(targetForWeek([], w1), 5));

  test('target yang berlaku adalah yang terakhir diset sebelum minggu berakhir', () {
    final targets = [
      (setAtMs: 0, sessionsPerWeek: 5),
      (setAtMs: DateTime(2026, 11, 11).millisecondsSinceEpoch, sessionsPerWeek: 3),
    ];
    expect(targetForWeek(targets, w1), 5);
    expect(targetForWeek(targets, w2), 3); // diubah di tengah minggu 2
    expect(targetForWeek(targets, w3), 3);
  });

  test('weekRange inklusif', () {
    expect(weekRange(w1, w3), [w1, w2, w3]);
    expect(weekRange(w3, w3), [w3]);
  });
}
