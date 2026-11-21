# T2: Prosedur uji kesesuaian indikator

Tujuan: membuktikan bahwa indikator yang dihitung dan disimpan aplikasi sama dengan perhitungan independen dari file profil yang sama. Kriteria: indikator count sama persis, indikator lain selisih ≤ 0,01.

## Langkah

1. HP terhubung ke laptop, aplikasi berjalan (`flutter run`, build debug sudah cukup). Zona waktu HP = Asia/Jakarta.
2. Buka Pengaturan Pengembang (ikon pengaturan di kanan atas Beranda).
3. Di bagian **Ekspor indikator (T2)**, ketuk **Ekspor semua profil (1–10)**. Aplikasi mengimpor profil 1 sampai 10 satu per satu, menyimpan indikatornya, lalu menulis satu file. Tunggu pesan "Tersimpan: …".
4. Ambil file ke laptop (dari folder `wanur-mobile`):
   ```powershell
   & "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" pull /sdcard/Android/data/com.example.flutter_application_1/files/wanur_export/indicators_all_profiles.json .
   ```
   Kalau muncul "Permission denied", salin file lewat kabel USB (mode Transfer file) dari folder `Android/data/com.example.flutter_application_1/files/wanur_export/` di File Explorer Windows.
5. Jalankan verifikasi:
   ```powershell
   python tools/verify_indicators.py indicators_all_profiles.json --csv t2_hasil.csv
   ```
6. Skrip mencetak tabel per indikator: jumlah yang dibandingkan, jumlah yang sesuai, dan persentase kesesuaian. `t2_hasil.csv` bisa langsung dijadikan tabel Results. Bila ada yang tidak sesuai, skrip menampilkan contoh sesi/minggu yang berbeda.

## Yang dibandingkan

Per sesi: waktu selesai, durasi aktif, tekanan per jari, total tekanan, laju tekanan, jeda antar-tekanan median, gaya genggam median, BLE terputus, sesi ≥ 5 menit, jari paling jarang, minggu kalender.
Per minggu: jumlah sesi, sesi memenuhi syarat, menit aktif, sebaran jari, kepatuhan.
Per tes genggam: nilai tiap percobaan, nilai tes, perubahan dari tes pertama.
