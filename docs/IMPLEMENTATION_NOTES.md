# Catatan implementasi: logbook latihan dan dashboard progres

Branch: `feature/logbook-dashboard`. Hardware glove, firmware ESP32, dan game web tidak diubah.

## Paket yang ditambahkan

| Paket | Batasan versi di `pubspec.yaml` | Kegunaan |
|---|---|---|
| `fl_chart` | `^0.70.2` | grafik garis tes genggam, grafik batang menit aktif dan tekanan per jari |
| `pdf` | `^3.11.3` | membuat PDF ringkasan terapis |
| `printing` | `^5.14.2` | membuka menu share Android untuk PDF (`Printing.sharePdf`) |
| `path_provider` | `^2.1.5` | folder ekspor indikator yang bisa diambil dengan `adb pull` |

Paket lama yang dipakai lebih banyak: `sqflite` (skema v2), `intl` (format tanggal dan angka bahasa Indonesia), `shared_preferences` (sumber data dan opsi pengembang), `webview_flutter` (`loadFlutterAsset` untuk halaman uji FR6).

Untuk Methods, tulis **versi yang benar-benar terpasang** dari `pubspec.lock` setelah `flutter pub get`:

```bash
grep -A3 -E "^  (fl_chart|pdf|printing|path_provider|sqflite|webview_flutter|flutter_blue_plus):" pubspec.lock | grep -E "^  [a-z_]+:|version"
flutter --version
```

Alat bantu Python (Python 3.9+ standar, tanpa paket tambahan): `tools/generate_profiles.py`, `tools/verify_indicators.py`, `tools/summarize_t3.py`.

## Perangkat uji

| Item | Nilai |
|---|---|
| Model HP | _(isi)_ |
| Versi Android | _(isi)_ |
| Versi Flutter / Dart | _(isi dari `flutter --version`)_ |
| Zona waktu HP | Asia/Jakarta (UTC+7), sama dengan profil simulasi |

## Struktur kode baru

- `android/.../MainActivity.kt`: `dispatchKeyEvent` menyalin setiap key event ke `EventChannel` `wanur/key_events` lalu selalu memanggil `super.dispatchKeyEvent`.
- `lib/data/`: `GloveDataSource` (abstrak), `RealGloveSource`, `SimulatedGloveSource`, `SimProfile` (pembaca file profil), `DataSourceController` (sumber aktif dan opsi pengembang).
- `lib/logic/` (fungsi murni, diuji di `test/`): `indicators.dart`, `session_machine.dart`, `session_recorder.dart`, `sim_replay.dart`, `weekly.dart`.
- `lib/services/`: `database_helper.dart` (skema v2), `training_repository.dart`, `sim_importer.dart`, `indicator_exporter.dart`, `therapist_summary.dart`, `therapist_pdf.dart`.
- `lib/screens/`: Beranda + navigasi bawah (`home_screen.dart`), `training_log_screen.dart`, `session_detail_screen.dart`, `grip_test_screen.dart`, `progress_screen.dart`, `finger_distribution_screen.dart`, `therapist_summary_screen.dart`, `device_screen.dart`, `dev_settings_screen.dart`.
- `lib/theme/app_theme.dart`, `lib/widgets/ui_kit.dart`: tema dan komponen UI bersama.

## Perbedaan dari desain di prompt, dan alasannya

### Definisi indikator (interpretasi)

1. **Durasi aktif.** Definisi: durasi sesi dikurangi semua jeda antar-tekanan > 10 s. Jeda dari awal sesi ke tekanan pertama dan dari tekanan terakhir ke akhir sesi juga diperlakukan sebagai jeda. Alasan: tanpa ini, layar yang dibiarkan terbuka (mis. 2 menit sebelum mulai bermain, atau 100 s sebelum layar ditutup) ikut dihitung aktif. Sesi tanpa tekanan selalu 0 menit. Jeda tepat 10 s tidak dikurangkan ("lebih dari").
2. **Akhir sesi.** Saat layar ditutup: waktu selesai = waktu tutup. Saat timeout: waktu selesai = event keypad terakhir (key-down atau key-up); bila belum ada event sama sekali, waktu selesai = waktu mulai (durasi 0). Bila layar masih terbuka setelah timeout, sesi baru dimulai pada event keypad berikutnya. Terputusnya BLE tidak mengakhiri sesi.
3. **Total tekanan** hanya menghitung key-down yang hurufnya ada di keymap saat sesi dimulai (4 jari). Laju tekanan = total / durasi aktif; bernilai kosong (null) bila durasi aktif 0. Jeda antar-tekanan median kosong bila tekanan < 2. Gaya genggam sesi kosong bila tidak ada sampel.
4. **Sampel gaya per sesi** = sampel dengan timestamp di antara mulai dan selesai sesi. Sampel yang datang saat menunggu sesi baru (setelah timeout) tidak masuk sesi mana pun.
5. **Jari paling jarang dipakai** (kartu Riwayat): jari dengan tekanan paling sedikit; bila seri, jari dengan indeks terkecil (Telunjuk < Tengah < Manis < Kelingking). Kosong bila tidak ada tekanan.
6. **Kepatuhan per minggu** memakai target yang berlaku pada minggu itu (target terakhir yang diset sebelum minggu berakhir). Saat aplikasi pertama dibuka, target default 5 ditulis dengan `set_at_ms = 0` supaya minggu lama dan data simulasi punya target yang jelas. Mengubah target hanya menghitung ulang minggu ini dan sesudahnya.
7. **Kepatuhan periode** (ringkasan terapis) = jumlah sesi memenuhi syarat / jumlah target mingguan di periode × 100, hanya untuk minggu yang punya baris ringkasan (sejak sesi pertama).
8. **Perubahan dari tes pertama** dihitung per tangan dan per sumber data (nyata/simulasi). Tes pertama disimpan 0%. Kosong bila nilai tes pertama ≤ 0.
9. **Nilai percobaan genggam**: bila tidak ada sampel istirahat, rata-rata istirahat dianggap 0; bila tidak ada sampel genggam, nilai percobaan disimpan 0.
10. **Timestamp key event.** `KeyEvent.eventTime` memakai jam `uptimeMillis` (sejak HP dinyalakan), bukan waktu dinding. `MainActivity` mengirim `eventTime` mentah (sesuai prompt) dan juga `wallTimeMs = currentTimeMillis − (uptimeMillis − eventTime)`; yang disimpan adalah `wallTimeMs`.

### Skema database

11. Kolom tambahan di luar daftar prompt: `training_sessions.total_presses`, `least_used_finger`, `end_reason`, `week_start_ms`; `grip_tests.change_from_first_pct`, `source`, `profile_id`; `force_samples.phase` (`rest1..3` / `grip1..3`, untuk menyimpan sampel mentah tes per percobaan). Alasan: aturan "indikator dihitung sekali saat disimpan, layar hanya membaca nilai tersimpan".
12. Tabel tambahan `weekly_summary` (per sumber data dan minggu: jumlah sesi, sesi memenuhi syarat, menit aktif, tekanan per jari, BLE terputus, target, kepatuhan). Diperbarui setiap kali sesi disimpan atau target diubah. Sebaran jari untuk periode dihitung dengan menjumlahkan baris mingguan tersimpan (periode = kelipatan minggu kalender).
13. Tabel lama `sessions` tidak diubah. Data lama tampil di "Arsip pengukuran lama" (read-only; tombol hapus lama dihilangkan).

### Simulasi

14. **File profil disimpan sebagai JSON yang dikompresi gzip** (`profile_XX.json.gz`, total sekitar 7 MB untuk 10 profil + 3 dataset beban; tanpa kompresi sekitar 30 MB). Isinya tetap JSON; `verify_indicators.py` membaca `.json.gz` maupun `.json`.
15. Data simulasi disimpan dengan `source = 'sim'` dan dipisah dari data glove nyata (`source = 'real'`). Semua layar memakai sumber yang aktif. Impor profil mengganti data simulasi lama; data nyata tidak disentuh. Satu profil aktif dalam satu waktu; "Ekspor semua profil" mengimpor profil 1 sampai 10 bergiliran lalu menggabungkan hasilnya.
16. Di mode simulasi, "hari ini" = timestamp data terakhir, supaya kartu "minggu ini" menampilkan minggu terakhir profil (profil berisi 7 Sep sampai 1 Nov 2026). Ringkasan mingguan simulasi berhenti di minggu sesi terakhir.
17. "Putar sesi simulasi" di layar latihan memakai waktu sekarang sebagai timestamp. Kecepatan 5x/20x ikut memendekkan durasi yang tercatat; untuk data dengan timestamp asli dipakai impor.
18. Sesi lewat tengah malam pertama di profil 8 sengaja dimulai Minggu 23.5x supaya kasus "berakhir di minggu berikutnya" teruji.

### Layar dan UI

19. `measurement_screen.dart` diganti `grip_test_screen.dart` (kartu Tes Genggam diarahkan ke layar baru), jadi nilai "Left Hand" `38.0` dan durasi `"5.0s"` hilang. `loading_screen.dart` (progress bar palsu 2,5 s) dihapus; intro sekarang Splash 1,4 s → kutipan 3 s (ketuk untuk lewati) → Beranda.
20. Redesign UI mengikuti inspirasi aplikasi rehabilitasi bernuansa biru: latar biru muda bergradasi, kartu putih semi-transparan, kartu sorotan biru tua ke cyan, aksen cyan, label kecil monospace huruf kapital, judul dua warna, dan navigasi bawah kaca (blur latar, hanya di navigasi supaya scroll tetap ringan). Layar kalibrasi memakai latar biru tua dengan ilustrasi tangan lama (posisi badge huruf tidak berubah). Teks layar lama ikut diterjemahkan ke bahasa Indonesia.
21. Perbaikan kecil di kalibrasi jari: satu tekanan bisa memajukan lebih dari satu jari karena `build` terpanggil berkali-kali dalam 300 ms (notifikasi gaya 2 Hz). Ditambah guard dan `resetLastKey()` setelah tiap langkah dan saat layar dibuka.
22. PDF memakai font standar (Helvetica, Latin-1), jadi beberapa karakter diganti di PDF saja (`≥` → `>=`, tanda pisah → `-`). `share_plus` tidak ditambahkan karena `printing` sudah menyediakan share sheet.
23. Pengaturan Pengembang terlihat otomatis di build debug; di build profile/release dibuka dengan mengetuk sapaan Beranda 7 kali, dan bisa disembunyikan lagi dari layar itu.

### Build Android

25. Flutter versi terbaru di laptop pengujian mewajibkan Gradle ≥ 9.3.1, jadi konfigurasi Android disamakan dengan template `flutter create` dari SDK yang sama: Gradle 9.5.0, Android Gradle Plugin 9.3.1, Kotlin 2.4.20, Java 17 untuk kompilasi, `ndkVersion` dari Flutter (NDK 28.2.13676358), dan `compileSdk = 37` karena `permission_handler_android` membutuhkan SDK 37. Build dijalankan dengan JDK 21 (`flutter config --jdk-dir`), karena Gradle 8.12 lama tidak mendukung Java 25 bawaan Android Studio.
26. `flutter_blue_plus` yang ter-resolve (1.36.x) mewajibkan parameter `license` pada `connect()`; dipakai `License.free`.

### Verifikasi saat pengembangan

24. Kode ditulis di lingkungan tanpa akses Flutter SDK dan pub.dev, jadi `flutter analyze` dan `flutter test` **belum dijalankan oleh penulis kode**. Yang sudah dicek: sintaks semua file Dart (parser tree-sitter, 0 error), dan `verify_indicators.py` dibandingkan dengan port Python dari logika Dart (mesin sesi, durasi aktif, ringkasan mingguan, tes genggam) pada 10 profil: 4.559 perbandingan, 100% sesuai. Jalankan `flutter pub get && flutter analyze && flutter test` sebelum uji di HP.
