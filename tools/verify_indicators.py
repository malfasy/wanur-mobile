#!/usr/bin/env python3
"""T2: uji kesesuaian indikator.

Menghitung ulang SEMUA indikator secara independen langsung dari file profil
simulasi (assets/sim_profiles/profile_XX.json.gz), lalu membandingkannya dengan
JSON hasil "Ekspor indikator" di aplikasi.

Aturan pembanding:
  - indikator count (jumlah, tekanan, putus, minggu, dsb.): harus sama persis
  - indikator lain (menit, laju, median, %, kg*): selisih <= 0,01
  - nilai kosong (null) dianggap sesuai hanya bila keduanya null

Pemakaian:
  adb pull /sdcard/Android/data/com.example.flutter_application_1/files/wanur_export/indicators_all_profiles.json
  python3 tools/verify_indicators.py indicators_all_profiles.json [--profiles-dir assets/sim_profiles] [--csv hasil.csv]

Skrip ini sengaja TIDAK memakai kode aplikasi; definisi di bawah ditulis ulang
langsung dari tabel definisi di paper.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import os
import statistics
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

TIMEOUT_MS = 120_000        # sesi berakhir setelah 120 s tanpa event keypad
IDLE_GAP_MS = 10_000        # jeda > 10 s dikurangkan dari durasi aktif
QUALIFY_MIN = 5.0           # sesi dihitung untuk kepatuhan bila durasi aktif >= 5 menit
TOL = 0.01


# --------------------------------------------------------------------------- definisi
def med(xs):
    return statistics.median(xs) if xs else None


def segment_sessions(s: dict) -> list[dict]:
    """Bagi satu sesi file menjadi sesi menurut aturan paper.

    Sesi mulai saat layar dibuka; berakhir saat layar ditutup (selesai = waktu
    tutup) atau setelah 120 s tanpa event keypad (selesai = event keypad
    terakhir, atau waktu mulai bila belum ada event). Tekanan setelah timeout
    saat layar masih terbuka memulai sesi baru.
    """
    open_ms, close_ms = s["open_ms"], s["close_ms"]
    keys = sorted((k for k in s["keys"] if open_ms <= k[0] <= close_ms), key=lambda k: k[0])
    out = []
    start, last, cur_keys = open_ms, None, []
    active = True
    for k in keys:
        t = k[0]
        if active:
            ref = last if last is not None else start
            if t - ref > TIMEOUT_MS:
                out.append((start, last if last is not None else start, cur_keys, "timeout"))
                active = False
        if not active:
            start, last, cur_keys, active = t, None, [], True
        cur_keys.append(k)
        last = t
    if active:
        ref = last if last is not None else start
        if close_ms - ref > TIMEOUT_MS:
            out.append((start, last if last is not None else start, cur_keys, "timeout"))
        else:
            out.append((start, close_ms, cur_keys, "closed"))
    result = []
    for st, en, ks, reason in out:
        result.append({
            "start_ms": st, "end_ms": en, "keymap": s["keymap"], "end_reason": reason,
            "keys": ks,
            "force": [f for f in s["force"] if st <= f[0] <= en],
            "ble": [b for b in s["ble"] if st <= b[0] <= en],
        })
    return result


def session_indicators(seg: dict) -> dict:
    st, en, keymap = seg["start_ms"], seg["end_ms"], seg["keymap"]
    downs = [k for k in seg["keys"] if k[2] == 1]
    times = sorted(k[0] for k in downs)
    # tekanan per jari (keymap saat sesi dimulai)
    presses = [0, 0, 0, 0]
    for k in downs:
        i = keymap.find(k[1].lower())
        if 0 <= i < 4:
            presses[i] += 1
    total = sum(presses)
    # durasi aktif: semua jeda > 10 s (termasuk awal->tekanan pertama dan
    # tekanan terakhir->akhir) dikurangkan; tanpa tekanan = 0
    if not times or en <= st:
        active_ms = 0
    else:
        pts = [st] + times + [en]
        active_ms = (en - st) - sum(b - a for a, b in zip(pts, pts[1:]) if b - a > IDLE_GAP_MS)
        active_ms = max(0, active_ms)
    active_min = active_ms / 60000.0
    ipis = [(b - a) / 1000.0 for a, b in zip(times, times[1:])]
    least = None
    if total > 0:
        least = min(range(4), key=lambda i: (presses[i], i))
    return {
        "start_ms": st,
        "end_ms": en,
        "keymap": keymap,
        "active_min": active_min,
        "presses": presses,
        "total_presses": total,
        "press_rate": (total / active_min) if active_min > 0 else None,
        "ipi_median_s": med(ipis) if len(times) >= 2 else None,
        "force_median": med([f[1] / 1000.0 for f in seg["force"]]),
        "ble_disconnects": sum(1 for b in seg["ble"] if b[1] == 0),
        "qualifies_for_target": active_min >= QUALIFY_MIN,
        "least_used_finger": least,
    }


def week_start_ms(t_ms: int, tz) -> int:
    d = datetime.fromtimestamp(t_ms / 1000, tz)
    monday = (d - timedelta(days=d.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    return int(monday.timestamp() * 1000)


def next_week(ws_ms: int, tz) -> int:
    d = datetime.fromtimestamp(ws_ms / 1000, tz)
    nd = (d + timedelta(days=7)).replace(hour=0, minute=0, second=0, microsecond=0)
    return int(nd.timestamp() * 1000)


def weekly(sessions: list[dict], target: int, tz) -> list[dict]:
    if not sessions:
        return []
    by = defaultdict(list)
    for s in sessions:
        by[week_start_ms(s["start_ms"], tz)].append(s)
    w, last = min(by), max(by)
    out = []
    while w <= last:
        ss = by.get(w, [])
        q = sum(1 for s in ss if s["qualifies_for_target"])
        presses = [sum(s["presses"][i] for s in ss) for i in range(4)]
        tot = sum(presses)
        out.append({
            "week_start_ms": w,
            "sessions": len(ss),
            "qualifying_sessions": q,
            "active_min_total": sum(s["active_min"] for s in ss),
            "presses": presses,
            "finger_pct": [p / tot * 100 for p in presses] if tot else None,
            "target": target,
            "compliance_pct": q / target * 100 if target > 0 else None,
        })
        w = next_week(w, tz)
    return out


def grip_indicators(tests: list[dict]) -> list[dict]:
    out, first = [], {}
    for g in sorted(tests, key=lambda g: g["t_ms"]):
        trials = []
        for tr in g["trials"]:
            rest = [v / 1000.0 for _, v in tr["rest"]]
            grip = [v / 1000.0 for _, v in tr["grip"]]
            trials.append((max(grip) - (sum(rest) / len(rest) if rest else 0.0)) if grip else 0.0)
        value = sum(trials) / len(trials)
        hand = g["hand"]
        if hand not in first:
            first[hand] = value
            change = 0.0
        else:
            change = (value - first[hand]) / first[hand] * 100 if first[hand] > 0 else None
        out.append({"t_ms": g["t_ms"], "hand": hand, "trials": trials, "value": value,
                    "change_from_first_pct": change})
    return out


def expected_for_profile(profile: dict, tz) -> dict:
    sessions = []
    for s in profile["sessions"]:
        for seg in segment_sessions(s):
            ind = session_indicators(seg)
            ind["week_start_ms"] = week_start_ms(ind["start_ms"], tz)
            sessions.append(ind)
    sessions.sort(key=lambda s: s["start_ms"])
    return {
        "sessions": sessions,
        "weeks": weekly(sessions, profile.get("weekly_target", 5), tz),
        "grip_tests": grip_indicators(profile["grip_tests"]),
    }


# --------------------------------------------------------------------------- pembanding
class Tally:
    def __init__(self):
        self.n = defaultdict(int)
        self.ok = defaultdict(int)
        self.examples = defaultdict(list)

    def check(self, name, exp, got, exact, where):
        self.n[name] += 1
        if agree(exp, got, exact):
            self.ok[name] += 1
        elif len(self.examples[name]) < 3:
            self.examples[name].append(f"{where}: diharapkan {exp!r}, ekspor {got!r}")


def agree(a, b, exact) -> bool:
    if a is None or b is None:
        return a is None and b is None
    if isinstance(a, (list, tuple)):
        return isinstance(b, (list, tuple)) and len(a) == len(b) and all(agree(x, y, exact) for x, y in zip(a, b))
    if isinstance(a, bool) or isinstance(b, bool):
        return bool(a) == bool(b)
    if exact:
        return a == b
    return abs(float(a) - float(b)) <= TOL + 1e-12


SESSION_FIELDS = [
    # (nama, kunci, exact)
    ("Jumlah sesi (per profil)", None, True),
    ("Waktu selesai sesi", "end_ms", True),
    ("Durasi aktif (menit)", "active_min", False),
    ("Tekanan per jari", "presses", True),
    ("Total tekanan", "total_presses", True),
    ("Laju tekanan (/menit)", "press_rate", False),
    ("Jeda antar-tekanan median (s)", "ipi_median_s", False),
    ("Gaya genggam sesi median (kg*)", "force_median", False),
    ("BLE terputus (count)", "ble_disconnects", True),
    ("Sesi >= 5 menit aktif", "qualifies_for_target", True),
    ("Jari paling jarang", "least_used_finger", True),
    ("Minggu kalender sesi", "week_start_ms", True),
]
WEEK_FIELDS = [
    ("Jumlah minggu (per profil)", None, True),
    ("Sesi per minggu", "sessions", True),
    ("Sesi memenuhi syarat per minggu", "qualifying_sessions", True),
    ("Menit aktif per minggu", "active_min_total", False),
    ("Sebaran jari (%)", "finger_pct", False),
    ("Kepatuhan (%)", "compliance_pct", False),
]
GRIP_FIELDS = [
    ("Jumlah tes genggam (per profil)", None, True),
    ("Nilai percobaan genggam (kg*)", "trials", False),
    ("Nilai tes genggam (kg*)", "value", False),
    ("Perubahan dari tes pertama (%)", "change_from_first_pct", False),
]


def compare(exp: dict, got: dict, pid, t: Tally):
    # sesi, dipasangkan berdasarkan waktu mulai
    es, gs = exp["sessions"], sorted(got["sessions"], key=lambda s: s["start_ms"])
    t.check(SESSION_FIELDS[0][0], len(es), len(gs), True, f"profil {pid}")
    gmap = {s["start_ms"]: s for s in gs}
    for e in es:
        g = gmap.get(e["start_ms"])
        for name, key, exact in SESSION_FIELDS[1:]:
            t.check(name, e[key], None if g is None else g.get(key), exact, f"profil {pid} sesi {e['start_ms']}")
    ew, gw = exp["weeks"], got["weeks"]
    t.check(WEEK_FIELDS[0][0], len(ew), len(gw), True, f"profil {pid}")
    gwm = {w["week_start_ms"]: w for w in gw}
    for e in ew:
        g = gwm.get(e["week_start_ms"])
        for name, key, exact in WEEK_FIELDS[1:]:
            t.check(name, e[key], None if g is None else g.get(key), exact, f"profil {pid} minggu {e['week_start_ms']}")
    eg, gg = exp["grip_tests"], got["grip_tests"]
    t.check(GRIP_FIELDS[0][0], len(eg), len(gg), True, f"profil {pid}")
    ggm = {(g["t_ms"], g["hand"]): g for g in gg}
    for e in eg:
        g = ggm.get((e["t_ms"], e["hand"]))
        for name, key, exact in GRIP_FIELDS[1:]:
            t.check(name, e[key], None if g is None else g.get(key), exact, f"profil {pid} tes {e['t_ms']} {e['hand']}")


def load_profile(dirpath: str, pid: int) -> dict:
    for name in (f"profile_{pid:02d}.json.gz", f"profile_{pid:02d}.json"):
        p = os.path.join(dirpath, name)
        if os.path.exists(p):
            opener = gzip.open if p.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8") as f:
                return json.load(f)
    raise FileNotFoundError(f"profil {pid} tidak ditemukan di {dirpath}")


def main(argv=None) -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("export_json")
    ap.add_argument("--profiles-dir", default=os.path.join(here, "..", "assets", "sim_profiles"))
    ap.add_argument("--tz", default=None, help="zona waktu IANA; default dari file profil")
    ap.add_argument("--csv", default=None, help="tulis tabel hasil ke CSV")
    args = ap.parse_args(argv)

    with open(args.export_json, encoding="utf-8") as f:
        export = json.load(f)
    tally = Tally()
    checked = []
    for prof in export["profiles"]:
        pid = prof.get("profile_id")
        if pid is None:
            print("Lewati blok tanpa profile_id (data glove nyata).", file=sys.stderr)
            continue
        profile = load_profile(args.profiles_dir, pid)
        tz = ZoneInfo(args.tz or profile.get("tz", "UTC"))
        off = export.get("utc_offset_minutes")
        if off is not None:
            prof_off = int(datetime.fromtimestamp(profile["start_ms"] / 1000, tz).utcoffset().total_seconds() // 60)
            if prof_off != off:
                print(f"PERINGATAN: offset zona waktu HP ({off} mnt) berbeda dari profil ({prof_off} mnt). "
                      "Minggu kalender bisa bergeser. Atur zona waktu HP ke "
                      f"{profile.get('tz')} atau pakai --tz.", file=sys.stderr)
        compare(expected_for_profile(profile, tz), prof, pid, tally)
        checked.append(pid)

    names = [n for n, _, _ in SESSION_FIELDS + WEEK_FIELDS + GRIP_FIELDS]
    rows = []
    for n in names:
        if tally.n[n] == 0:
            continue
        pct = tally.ok[n] / tally.n[n] * 100
        rows.append((n, tally.n[n], tally.ok[n], pct))
    w = max(len(r[0]) for r in rows) if rows else 10
    print(f"Profil diperiksa: {', '.join(map(str, checked))}")
    print(f"{'Indikator'.ljust(w)}  {'Dibandingkan':>12}  {'Sesuai':>8}  {'Kesesuaian':>10}")
    print("-" * (w + 38))
    for n, total, ok, pct in rows:
        print(f"{n.ljust(w)}  {total:>12}  {ok:>8}  {pct:>9.1f}%")
    all_n = sum(r[1] for r in rows)
    all_ok = sum(r[2] for r in rows)
    print("-" * (w + 38))
    print(f"{'TOTAL'.ljust(w)}  {all_n:>12}  {all_ok:>8}  {(all_ok / all_n * 100 if all_n else 0):>9.1f}%")
    bad = [(n, ex) for n, ex in tally.examples.items() if ex]
    if bad:
        print("\nContoh ketidaksesuaian:")
        for n, ex in bad:
            for e in ex:
                print(f"  [{n}] {e}")
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            wr = csv.writer(f)
            wr.writerow(["indikator", "dibandingkan", "sesuai", "kesesuaian_pct"])
            for r in rows:
                wr.writerow([r[0], r[1], r[2], f"{r[3]:.2f}"])
    return 0 if all_ok == all_n else 1


if __name__ == "__main__":
    sys.exit(main())
