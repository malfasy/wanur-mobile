# T3: Prosedur uji waktu muat dashboard

Tujuan: mengukur waktu dari tap ke tab **Progres** sampai frame pertama setelah data tampil, pada tiga ukuran data (1, 3, dan 6 bulan), 20 kali per kondisi.

## Yang diukur

`ProgressScreen` menjalankan `Stopwatch` saat tab Progres diketuk (di `HomeScreen.select`), memuat data dari database, lalu setelah data tampil memanggil `addPostFrameCallback` dan menulis satu baris log:

```
[T3] dashboard_load_ms=184 scope=sim weeks=13 sessions=65 grip_tests=26
```

`weeks` dipakai untuk mengenali kondisi: 5 minggu = 1 bulan, 13 minggu = 3 bulan, 26 minggu = 6 bulan.

## Data uji

Dataset beban dibuat oleh `tools/generate_profiles.py` (seed tetap) dan ikut di aset:

| Kondisi | File | Minggu | Sesi | Tes genggam |
|---|---|---|---|---|
| 1 bulan | `assets/sim_profiles/load_1m.json.gz` | 5 | 25 | 10 |
| 3 bulan | `assets/sim_profiles/load_3m.json.gz` | 13 | 65 | 26 |
| 6 bulan | `assets/sim_profiles/load_6m.json.gz` | 26 | 130 | 52 |

## Langkah

1. Siapkan HP: matikan mode hemat baterai, tutup aplikasi lain, layar selalu menyala selama tes. Catat model HP dan versi Android di `docs/IMPLEMENTATION_NOTES.md`.
2. Jalankan aplikasi dalam mode profile (bukan debug, karena mode debug jauh lebih lambat) dan simpan output terminal:
   ```bash
   flutter run --profile 2>&1 | tee t3_log.txt
   ```
3. Buka Pengaturan Pengembang (di build profile: ketuk sapaan "Selamat …" di Beranda 7 kali, lalu ikon pengaturan di kanan atas).
4. Pada bagian **Uji waktu muat (T3)**, ketuk **1 bulan**. Tunggu pesan "Data 1 bulan siap".
5. Kembali ke Beranda. Ulangi 20 kali:
   - ketuk tab **Progres**, tunggu grafik tampil,
   - ketuk tab **Beranda** (supaya layar Progres dibuat ulang pada pengukuran berikutnya).
6. Ulangi langkah 4 sampai 5 untuk **3 bulan** dan **6 bulan**.
7. Hentikan `flutter run` (tekan `q`), lalu ringkas:
   ```bash
   python3 tools/summarize_t3.py t3_log.txt --csv t3_summary.csv
   ```
   Keluaran per kondisi: n, median, Q1, Q3, IQR, minimum, maksimum (ms). Skrip memakai 20 pengukuran pertama per kondisi (ubah dengan `--first`).

## Catatan

- Pengukuran pertama setelah impor bisa lebih lambat karena cache SQLite masih dingin. Laporkan apa adanya, atau buang 1 pengukuran pemanasan dan sebutkan di Methods.
- Jangan ganti sumber data atau impor profil lain di tengah satu kondisi.
- Dataset beban dimulai 7 September 2026, jadi dataset 6 bulan berisi tanggal di masa depan; ini tidak memengaruhi waktu muat karena mode simulasi memakai data terakhir sebagai "hari ini".
