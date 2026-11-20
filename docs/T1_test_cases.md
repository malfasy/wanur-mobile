# T1: Test case kebutuhan fungsional (FR1 sampai FR6)

Semua test case bisa dijalankan tanpa glove. Sumber event:

- **adb**: `adb shell input keyevent KEYCODE_F` (juga `KEYCODE_G`, `KEYCODE_H`, `KEYCODE_J`). Event ini masuk lewat `MainActivity.dispatchKeyEvent`, jalur yang sama dengan keypad glove (keyboard Bluetooth HID).
- **Simulasi**: Pengaturan Pengembang → "Gunakan data simulasi", impor profil, atau "Putar sesi simulasi" di layar latihan.

Pengaturan Pengembang terbuka dari ikon di kanan atas Beranda (build debug), atau setelah sapaan Beranda diketuk 7 kali (build profile/release).

Persiapan umum: zona waktu HP = Asia/Jakarta, aplikasi baru dipasang atau data dihapus lewat Pengaturan Pengembang → "Hapus semua data logbook".

Kolom **Hasil** diisi `Lulus` / `Gagal` beserta catatan.

---

## FR1 Perekaman sesi otomatis

| ID | Jenis | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|---|
| FR1-01 | Normal | Mode glove (bukan simulasi). Buka Beranda → "Mulai latihan". Kirim 60 tekanan dengan `for i in $(seq 60); do adb shell input keyevent KEYCODE_F; sleep 1; done`. Tutup layar latihan. | Strip di atas game menampilkan "Merekam" dan jumlah tekanan naik. Setelah layar ditutup muncul 1 sesi baru di Riwayat dengan 60 tekanan, semuanya di jari Telunjuk. Log berisi `[SessionRecorder] sesi tersimpan`. | |
| FR1-02 | Batas (timeout 120 s) | Buka layar latihan, kirim 10 tekanan, lalu diamkan 130 s tanpa tekanan. Kirim 5 tekanan lagi, tutup layar. | Tersimpan 2 sesi. Sesi pertama berakhir di waktu tekanan terakhir (detail sesi: "berakhir otomatis"), berisi 10 tekanan. Sesi kedua mulai saat tekanan ke-11, berisi 5 tekanan, berakhir saat layar ditutup. | |
| FR1-03 | Batas (jeda tepat 10 s dan > 10 s) | Buka layar latihan, kirim tekanan pada t = 0, 10, 20 s, lalu t = 35 s, tutup layar sekitar 1 s kemudian. | Durasi aktif = durasi sesi dikurangi jeda dari awal sesi ke tekanan pertama bila > 10 s dan jeda 20 → 35 s (15 s). Jeda tepat 10 s tidak dikurangkan. (Aturan yang sama diuji otomatis di `test/indicators_test.dart`.) | |
| FR1-04 | Batas (sesi kosong) | Buka layar latihan, jangan tekan apa pun, tutup setelah 30 s. | Tersimpan 1 sesi dengan 0 tekanan, durasi aktif 0 menit, tag "Tanpa tekanan", tidak dihitung untuk target. | |
| FR1-05 | Error (BLE terputus) | Mode simulasi, buka layar latihan → "Putar sesi simulasi" profil 7 (BLE sering putus), kecepatan 20x. Tunggu selesai, tutup layar. | Sesi tersimpan; Detail Sesi menampilkan kotak "Kualitas data: Sambungan terputus N kali" dengan N sesuai file profil. Aplikasi tidak crash. | |

## FR2 Riwayat per minggu dan detail sesi

| ID | Jenis | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|---|
| FR2-01 | Normal | Impor profil 1. Buka tab Riwayat. | Judul kartu "Minggu ini: X dari 5 sesi" dengan X = sesi ≥ 5 menit aktif di minggu terakhir profil. Sesi dikelompokkan per minggu (Senin sampai Minggu), terbaru di atas. Tiap kartu menampilkan hari dan tanggal, durasi aktif, jumlah tekanan, laju tekanan, dan jari paling jarang dipakai. | |
| FR2-02 | Batas (lewat tengah malam) | Impor profil 8. Cari sesi yang mulai sekitar 23.50. | Sesi masuk ke minggu dan hari tanggal mulai, walaupun berakhir setelah 00.00. Sesi yang mulai Minggu 23.5x tetap masuk minggu tersebut, bukan minggu berikutnya. | |
| FR2-03 | Batas (minggu kosong) | Impor profil 5 (jeda 2 minggu). | Minggu tanpa sesi tidak menampilkan kartu sesi; nilai minggu tersebut tetap ada di grafik menit aktif (batang 0) dan kepatuhan 0% di ringkasan terapis. | |
| FR2-04 | Normal (detail) | Dari Riwayat, ketuk satu sesi. | Detail Sesi menampilkan kartu durasi aktif dan laju tekanan, diagram batang tekanan per jari (Telunjuk, Tengah, Manis, Kelingking dengan huruf keymap), jeda antar-tekanan median, gaya genggam median dalam kg*, catatan kaki "* nilai relatif…", dan kotak Kualitas data. | |
| FR2-05 | Error (keymap berubah) | Impor profil 10. Bandingkan detail sesi minggu 1 dan minggu 6. | Sesi minggu 1 memakai keymap `fghj`, sesi minggu 6 memakai `asdl`; tekanan tetap terpetakan ke jari yang benar (tidak ada sesi dengan semua jari 0 padahal ada tekanan). | |

## FR3 Tes genggam 3 percobaan

| ID | Jenis | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|---|
| FR3-01 | Normal | Mode simulasi. Beranda → Tes Genggam → Tangan kanan → Mulai tes. Ikuti 3 percobaan (boleh "Lewati istirahat (simulasi)"). | Tiap percobaan: istirahat 3 s, "Genggam kuat!" 5 s, istirahat 60 s. Nilai tiap percobaan muncul di chip atas. Hasil akhir = rata-rata 3 percobaan dalam kg* dan tersimpan di tabel `grip_tests` beserta sampel mentah (`force_samples.phase` = rest1..3/grip1..3). | |
| FR3-02 | Batas (tes pertama) | Setelah hapus data, lakukan tes tangan kiri pertama kali. | Layar hasil menulis "Ini tes pertama untuk tangan ini"; perubahan dari tes pertama tersimpan 0%. Tes kedua tangan kiri menampilkan perubahan relatif terhadap tes pertama tangan kiri saja. | |
| FR3-03 | Error (dibatalkan) | Mulai tes, batalkan saat percobaan 2 (tombol "Batalkan tes" atau tombol kembali Android → "Batalkan"). | Muncul konfirmasi "Hasil tidak akan disimpan". Setelah dikonfirmasi, tidak ada baris baru di `grip_tests` dan nilai di Beranda tidak berubah. | |
| FR3-04 | Error (glove tidak terhubung) | Mode glove, glove tidak terhubung. Buka Tes Genggam. | Tombol "Mulai tes" nonaktif dan muncul kotak "Glove belum terhubung". | |

## FR4 Dashboard progres

| ID | Jenis | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|---|
| FR4-01 | Normal | Impor profil 1, buka tab Progres. | Kartu Kepatuhan "NN% (q/5) minggu ini" dan kartu Tes genggam "+NN% dari awal". Grafik garis nilai tes genggam (kanan oranye, kiri gelap) dalam kg*, grafik batang menit aktif per minggu (minggu terakhir oranye). Log berisi `[T3] dashboard_load_ms=…`. | |
| FR4-02 | Batas (kepatuhan > 100%) | Impor profil 4, cari minggu dengan 6 sampai 7 sesi ≥ 5 menit (atau set target 3 lalu lihat minggu dengan 5 sesi). | Tampilan kepatuhan maksimal 100%; nilai tersimpan di `weekly_summary.compliance_pct` boleh lebih dari 100 (cek lewat ekspor indikator). | |
| FR4-03 | Batas (tanpa tes genggam) | Hapus data, buat 1 sesi lewat adb, buka Progres. | Judul "Belum ada tes genggam.", kartu tes genggam "–", grafik genggam menampilkan "Belum ada tes di periode ini". Tidak ada error. | |
| FR4-04 | Normal (sebaran jari) | Impor profil 6, Progres → Sebaran jari, pilih 4 mgg lalu Semua. | Kelingking ditandai paling jarang (sekitar 3%). Jumlah persentase keempat jari = 100%. Angka berubah sesuai periode. | |

## FR5 Target mingguan dan ringkasan PDF

| ID | Jenis | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|---|
| FR5-01 | Normal | Mode glove. Progres → Target mingguan → ubah 5 menjadi 3 → Simpan. | Kartu Beranda dan Riwayat menampilkan "… dari 3 sesi" untuk minggu ini. Minggu-minggu lama tetap memakai target lamanya. | |
| FR5-02 | Batas | Turunkan target ke 1, lalu naikkan ke 14. | Tombol minus nonaktif di 1, plus nonaktif di 14. Nilai tersimpan sebagai baris baru di `weekly_target`. | |
| FR5-03 | Normal (PDF) | Impor profil 3. Progres → Ringkasan untuk terapis → periode 4 minggu → Bagikan PDF → pilih aplikasi (mis. Drive atau Gmail). | Menu share Android muncul. PDF berisi kepatuhan, tabel per minggu, tren tes genggam, sebaran jari, kualitas data, daftar sesi, dan kalimat "Indikator ini untuk pemantauan latihan, bukan penilaian klinis". | |
| FR5-04 | Error (periode tanpa data) | Hapus data, buka Ringkasan untuk terapis. | Layar tetap terbuka dengan nilai 0 dan "Tidak ada tes genggam dalam periode ini"; PDF tetap bisa dibuat. | |

## FR6 Event keypad tetap sampai ke game

| ID | Jenis | Langkah | Hasil yang diharapkan | Hasil |
|---|---|---|---|---|
| FR6-01 | Normal | Pengaturan Pengembang → aktifkan "Halaman penghitung tombol (FR6)". Buka layar latihan. Kirim 50 tekanan campuran F/G/H/J lewat adb. | Angka besar di `key_counter.html` = 50, dan jumlah tekanan di strip sesi = 50. Setelah layar ditutup, sesi tersimpan dengan total 50. Selisih = 0. | |
| FR6-02 | Batas (tekan cepat) | Sama seperti FR6-01, kirim 100 tekanan tanpa jeda (`for i in $(seq 100); do adb shell input keyevent KEYCODE_G; done`). | Hitungan halaman = hitungan aplikasi = 100. | |
| FR6-03 | Batas (tombol ditahan) | Tahan satu tombol fisik pada keyboard Bluetooth/USB yang terhubung ke HP selama 2 s. | Halaman menghitung 1 keydown dan menampilkan auto-repeat yang diabaikan; aplikasi mencatat 1 key-down (repeatCount > 0 diabaikan). | |
| FR6-04 | Normal (game asli) | Matikan halaman penghitung. Buka game, mainkan dengan adb atau keyboard. | Game merespons tekanan seperti sebelum fitur logbook ditambahkan; sesi tetap tercatat. | |
| FR6-05 | Normal (kalibrasi jari) | Beranda → Kalibrasi Jari → Mulai kalibrasi. Kirim J, H, G, F berurutan lewat adb. | Layar maju satu jari per tekanan (Kelingking, Manis, Tengah, Telunjuk) dan berakhir di "KALIBRASI BERHASIL". | |

---

## Unit test otomatis

`flutter test` menjalankan:

- `test/indicators_test.dart`: median, durasi aktif (sesi kosong, satu tekanan, jeda tepat 10 s, jeda 10,001 s, lewat tengah malam), tekanan per jari, sebaran, laju, IPI, kepatuhan, tes genggam, minggu kalender.
- `test/session_machine_test.dart`: aturan mulai/selesai sesi, timeout 120 s, sesi kosong, sesi baru setelah timeout, jendela sampel gaya dan BLE, sesi < 5 menit.
- `test/weekly_test.dart`: target yang berlaku per minggu.
- `test/sim_replay_test.dart`: pemutaran file profil dengan timestamp dari file.
- `test/widget_test.dart`: widget dasar UI.
