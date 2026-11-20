#!/usr/bin/env python3
"""T3: ringkas waktu muat dashboard dari log [T3].

Ambil log dari HP (flutter run --profile menampilkan debugPrint di terminal;
simpan output terminal ke file), lalu:

    python3 tools/summarize_t3.py t3_log.txt [--csv t3_summary.csv]

Baris yang dibaca berbentuk:
    [T3] dashboard_load_ms=184 scope=sim weeks=13 sessions=65 grip_tests=26

Kondisi dikelompokkan berdasarkan jumlah minggu data (5 = 1 bulan, 13 = 3 bulan,
26 = 6 bulan). Keluaran: n, median, Q1, Q3, IQR, min, maks (ms).
"""

from __future__ import annotations

import argparse
import csv
import re
import statistics
import sys
from collections import defaultdict

LINE = re.compile(r"\[T3\]\s+dashboard_load_ms=(\d+).*?weeks=(\d+)\s+sessions=(\d+)")
LABEL = {5: "1 bulan", 13: "3 bulan", 26: "6 bulan"}


def quartiles(xs: list[float]) -> tuple[float, float, float]:
    if len(xs) < 2:
        v = xs[0]
        return v, v, v
    q = statistics.quantiles(xs, n=4, method="inclusive")
    return q[0], statistics.median(xs), q[2]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log")
    ap.add_argument("--csv")
    ap.add_argument("--first", type=int, default=20, help="pakai N pengukuran pertama per kondisi (default 20)")
    a = ap.parse_args(argv)
    groups: dict[tuple[int, int], list[int]] = defaultdict(list)
    with open(a.log, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = LINE.search(line)
            if m:
                ms, weeks, sessions = map(int, m.groups())
                groups[(weeks, sessions)].append(ms)
    if not groups:
        print("Tidak ada baris [T3] di log.", file=sys.stderr)
        return 1
    rows = []
    for (weeks, sessions), vals in sorted(groups.items()):
        vals = vals[: a.first]
        q1, md, q3 = quartiles(vals)
        rows.append((LABEL.get(weeks, f"{weeks} minggu"), weeks, sessions, len(vals), md, q1, q3, q3 - q1,
                     min(vals), max(vals)))
    hdr = ("Kondisi", "Minggu", "Sesi", "n", "Median", "Q1", "Q3", "IQR", "Min", "Maks")
    print("  ".join(f"{h:>8}" for h in hdr))
    for r in rows:
        print("  ".join(f"{(f'{v:.1f}' if isinstance(v, float) else v):>8}" for v in r))
    for r in rows:
        if r[3] < a.first:
            print(f"Catatan: kondisi {r[0]} baru {r[3]} pengukuran (target {a.first}).", file=sys.stderr)
    if a.csv:
        with open(a.csv, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["kondisi", "minggu", "sesi", "n", "median_ms", "q1_ms", "q3_ms", "iqr_ms", "min_ms", "max_ms"])
            w.writerows(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
