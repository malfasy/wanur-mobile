#!/usr/bin/env python3
"""Generator profil pasien simulasi untuk aplikasi Wanur Glove.

Menghasilkan 10 profil x 8 minggu (assets/sim_profiles/profile_01..10.json.gz)
dan 3 dataset beban untuk uji waktu muat T3 (load_1m, load_3m, load_6m).

Seed tetap, jadi hasilnya selalu sama. Jalankan dari root repo:

    python3 tools/generate_profiles.py

Format file (JSON, dikompresi gzip supaya ukuran APK tetap kecil):

{
  "format_version": 1,
  "profile_id": 1,
  "name": "...", "description": "...",
  "tz": "Asia/Jakarta",
  "weekly_target": 5,
  "sessions": [
    {
      "open_ms": <epoch ms, layar latihan dibuka>,
      "close_ms": <epoch ms, layar latihan ditutup>,
      "keymap": "fghj",              # urutan: telunjuk, tengah, manis, kelingking
      "keys": [[t_ms, "f", 1], ...], # 1 = down, 0 = up, timestamp absolut
      "force": [[t_ms, raw], ...],   # raw = nilai HX711 seperti dikirim firmware (~gram)
      "ble": [[t_ms, 0], [t_ms, 1]], # 0 = terputus, 1 = tersambung lagi
      "tags": ["timeout", ...]       # penanda skenario, hanya untuk dokumentasi
    }
  ],
  "grip_tests": [
    {"t_ms": ..., "hand": "right"|"left",
     "trials": [{"rest": [[t_ms, raw], ...], "grip": [[t_ms, raw], ...]}, x3]}
  ]
}

Satu entri "sessions" dirancang agar menghasilkan tepat satu sesi tercatat
menurut aturan sesi di paper (timeout 120 s hanya terjadi setelah event terakhir).
"""

from __future__ import annotations

import gzip
import json
import math
import os
import random
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

SEED = 20261120
TZ_NAME = "Asia/Jakarta"
TZ = ZoneInfo(TZ_NAME)
START_MONDAY = datetime(2026, 9, 7, 0, 0, tzinfo=TZ)  # Senin
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sim_profiles")

KEYMAP_DEFAULT = "fghj"
FORCE_PERIOD_MS = 500


def ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


@dataclass
class ProfileSpec:
    pid: int
    name: str
    description: str
    weeks: int = 8
    sessions_per_week: list[int] | None = None  # jumlah sesi per minggu
    finger_weights: tuple[float, float, float, float] = (0.30, 0.28, 0.24, 0.18)
    rate_range: tuple[float, float] = (18.0, 32.0)  # tekanan per menit saat bermain
    active_min_range: tuple[float, float] = (6.0, 16.0)
    grip_right: tuple[float, float] = (8.0, 10.0)  # kg awal -> kg akhir
    grip_left: tuple[float, float] = (14.0, 14.5)
    grip_test_weeks: list[int] | None = None  # minggu dengan tes genggam
    hours: tuple[int, ...] = (8, 10, 16, 19)
    ble_drop_prob: float = 0.08
    short_session_prob: float = 0.05
    empty_session_prob: float = 0.0
    timeout_prob: float = 0.25
    midnight_sessions: int = 0
    keymap_change_week: int | None = None
    keymap_after: str = "asdl"
    extra: dict = field(default_factory=dict)


class Gen:
    def __init__(self, spec: ProfileSpec, rng: random.Random):
        self.s = spec
        self.r = rng

    # ---------------- sesi latihan ----------------
    def session(self, open_dt: datetime, keymap: str, kind: str = "normal") -> dict:
        r = self.r
        s = self.s
        open_ms = ms(open_dt)
        keys: list[list] = []
        tags: list[str] = []
        ble: list[list[int]] = []
        gaps: list[tuple[int, int]] = []  # jendela BLE terputus

        t = open_ms + r.randint(3000, 15000)
        if kind == "empty":
            tags.append("empty")
            if r.random() < 0.5:
                close_ms = open_ms + r.randint(20_000, 100_000)  # ditutup sebelum timeout
            else:
                close_ms = open_ms + r.randint(150_000, 260_000)  # timeout tanpa event
                tags.append("timeout_no_event")
            force = self.force_stream(open_ms, close_ms, base=r.randint(250, 500), gaps=[])
            return {"open_ms": open_ms, "close_ms": close_ms, "keymap": keymap,
                    "keys": [], "force": force, "ble": [], "tags": tags}

        if kind == "short":
            target_active_s = r.uniform(1.5, 4.2) * 60
            tags.append("short")
        else:
            target_active_s = r.uniform(*s.active_min_range) * 60
        rate = r.uniform(*s.rate_range)
        mean_ipi = 60.0 / rate
        played = 0.0
        drop_planned = r.random() < s.ble_drop_prob
        drop_done = False
        while played < target_active_s:
            song = min(r.uniform(60, 150), target_active_s - played + 5)
            song_end = t + int(song * 1000)
            while t < song_end:
                finger = r.choices(range(4), weights=s.finger_weights)[0]
                ch = keymap[finger]
                hold = r.randint(80, 260)
                keys.append([t, ch, 1])
                keys.append([t + hold, ch, 0])
                ipi = max(0.25, r.gammavariate(4.0, mean_ipi / 4.0))
                t = t + max(hold + 40, int(ipi * 1000))
            played += song
            if played >= target_active_s:
                break
            # jeda antar lagu (sebagian > 10 s, jadi dikurangkan dari durasi aktif)
            pause = r.choice([r.uniform(3, 9), r.uniform(12, 45), r.uniform(5, 25)])
            if drop_planned and not drop_done and played > target_active_s * 0.3:
                # BLE terputus di tengah sesi: tidak ada tekanan maupun sampel gaya
                drop_start = t + 500
                drop_len = r.randint(4000, 25000)
                ble.append([drop_start, 0])
                ble.append([drop_start + drop_len, 1])
                gaps.append((drop_start, drop_start + drop_len))
                pause = max(pause, (drop_len + 2000) / 1000)
                drop_done = True
                tags.append("ble_drop")
                if r.random() < 0.4:  # kadang putus dua kali
                    d2 = drop_start + drop_len + r.randint(30_000, 60_000)
                    # dicatat nanti hanya bila masih di dalam sesi
                    self._pending_second = (d2, r.randint(3000, 9000))
            t += int(pause * 1000)

        last_event = keys[-1][0]
        pend = getattr(self, "_pending_second", None)
        if pend and pend[0] + pend[1] < last_event:
            # hapus tekanan di jendela putus kedua
            a, b = pend[0], pend[0] + pend[1]
            keys = [k for k in keys if not (a <= k[0] <= b + 300)]
            ble.append([a, 0])
            ble.append([b, 1])
            gaps.append((a, b))
            tags.append("ble_drop_2x")
        self._pending_second = None
        # pastikan key-down dan key-up tetap berpasangan setelah penghapusan
        keys = self._fix_pairs(keys)
        last_event = keys[-1][0]

        if r.random() < s.timeout_prob:
            close_ms = last_event + r.randint(125_000, 400_000)
            tags.append("timeout")
        else:
            close_ms = last_event + r.randint(2_000, 40_000)
        force = self.force_stream(open_ms, close_ms, base=r.randint(250, 500), gaps=gaps,
                                  active_peak=self.session_force_peak(open_ms))
        return {"open_ms": open_ms, "close_ms": close_ms, "keymap": keymap,
                "keys": keys, "force": force, "ble": ble, "tags": tags}

    @staticmethod
    def _fix_pairs(keys: list[list]) -> list[list]:
        keys.sort(key=lambda k: (k[0], -k[2]))
        out, open_down = [], None
        for k in keys:
            if k[2] == 1:
                if open_down is not None:
                    out.append([max(open_down[0] + 1, k[0] - 1), open_down[1], 0])
                out.append(k)
                open_down = k
            else:
                if open_down is not None and open_down[1] == k[1]:
                    out.append(k)
                    open_down = None
        if open_down is not None:
            out.append([open_down[0] + 120, open_down[1], 0])
        out.sort(key=lambda k: (k[0], -k[2]))
        return out

    def session_force_peak(self, t_ms: int) -> float:
        # gaya saat bermain: sebagian kecil dari gaya genggam maksimum hari itu
        return self.grip_at(t_ms, "right") * 1000 * self.r.uniform(0.12, 0.22)

    def force_stream(self, a: int, b: int, base: int, gaps, active_peak: float = 0.0):
        r = self.r
        out = []
        t = a + r.randint(0, FORCE_PERIOD_MS)
        while t <= b:
            if not any(g0 <= t <= g1 for g0, g1 in gaps):
                v = base + r.gauss(0, 25)
                if active_peak and r.random() < 0.55:
                    v += active_peak * r.uniform(0.4, 1.1)
                out.append([t, int(round(max(0, v)))])
            t += FORCE_PERIOD_MS + r.randint(-20, 20)
        return out

    # ---------------- tes genggam ----------------
    def grip_at(self, t_ms: int, hand: str) -> float:
        s = self.s
        a, b = s.grip_right if hand == "right" else s.grip_left
        total = s.weeks * 7 * 86400_000
        frac = min(1.0, max(0.0, (t_ms - ms(START_MONDAY)) / total))
        return a + (b - a) * frac

    def grip_test(self, t_dt: datetime, hand: str) -> dict:
        r = self.r
        t0 = ms(t_dt)
        true_kg = self.grip_at(t0, hand)
        trials = []
        baseline = r.randint(200, 450)
        for i in range(3):
            ts = t0 + i * (3000 + 5000 + 60000)
            rest, grip = [], []
            t = ts + r.randint(0, 120)
            while t < ts + 3000:
                rest.append([t, int(round(baseline + r.gauss(0, 15)))])
                t += FORCE_PERIOD_MS + r.randint(-15, 15)
            peak = true_kg * 1000 * r.uniform(0.9, 1.06) * (0.97 ** i)
            gstart = ts + 3000
            t = gstart + r.randint(0, 120)
            while t < gstart + 5000:
                x = (t - gstart) / 5000
                shape = math.sin(math.pi * min(1.0, x * 1.15)) ** 0.6
                grip.append([t, int(round(baseline + peak * shape + r.gauss(0, 30)))])
                t += FORCE_PERIOD_MS + r.randint(-15, 15)
            trials.append({"rest": rest, "grip": grip})
            baseline += r.randint(-20, 20)  # drift kecil antar percobaan
        return {"t_ms": t0, "hand": hand, "trials": trials}

    # ---------------- profil lengkap ----------------
    def build(self) -> dict:
        s, r = self.s, self.r
        sessions, tests = [], []
        per_week = s.sessions_per_week or [5] * s.weeks
        midnight_left = s.midnight_sessions
        for w in range(s.weeks):
            week_start = START_MONDAY + timedelta(weeks=w)
            keymap = (s.keymap_after if s.keymap_change_week is not None
                      and w >= s.keymap_change_week else KEYMAP_DEFAULT)
            n = per_week[w]
            days = sorted(r.sample(range(7), k=min(7, n))) if n <= 7 else list(range(7))
            for i, d in enumerate(days):
                if midnight_left > 0 and i == len(days) - 1:
                    # sesi lewat tengah malam pertama sengaja dimulai Minggu malam supaya
                    # berakhir di minggu kalender berikutnya (Senin)
                    dd = 6 if midnight_left == s.midnight_sessions else d
                    open_dt = week_start + timedelta(days=dd, hours=23, minutes=r.randint(48, 56))
                    midnight_left -= 1
                    kind = "normal"
                    sess = self.session(open_dt, keymap, kind)
                    sess["tags"].append("cross_midnight")
                    sessions.append(sess)
                    continue
                h = r.choice(s.hours)
                open_dt = week_start + timedelta(days=d, hours=h, minutes=r.randint(0, 50))
                roll = r.random()
                if roll < s.empty_session_prob:
                    kind = "empty"
                elif roll < s.empty_session_prob + s.short_session_prob:
                    kind = "short"
                else:
                    kind = "normal"
                sessions.append(self.session(open_dt, keymap, kind))
            test_weeks = s.grip_test_weeks if s.grip_test_weeks is not None else list(range(s.weeks))
            if w in test_weeks:
                tday = week_start + timedelta(days=5, hours=9, minutes=r.randint(0, 40))
                tests.append(self.grip_test(tday, "right"))
                tests.append(self.grip_test(tday + timedelta(minutes=12), "left"))
        sessions.sort(key=lambda x: x["open_ms"])
        # sesi tidak boleh bertumpuk: geser bila perlu (secara praktis tidak terjadi)
        for a, b in zip(sessions, sessions[1:]):
            assert a["close_ms"] < b["open_ms"], (s.pid, a["open_ms"], b["open_ms"])
        return {
            "format_version": 1,
            "profile_id": s.pid,
            "name": s.name,
            "description": s.description,
            "tz": TZ_NAME,
            "weekly_target": 5,
            "start_ms": ms(START_MONDAY),
            "weeks": s.weeks,
            "sessions": sessions,
            "grip_tests": tests,
        }


def specs() -> list[ProfileSpec]:
    return [
        ProfileSpec(1, "Teratur, genggam naik",
                    "5 sesi/minggu konsisten; genggam kanan naik dari 8 ke 12 kg*.",
                    sessions_per_week=[5] * 8, grip_right=(8.0, 12.0), grip_left=(15.0, 16.0)),
        ProfileSpec(2, "Stabil",
                    "4 sesi/minggu; genggam relatif tetap.",
                    sessions_per_week=[4] * 8, grip_right=(10.0, 10.3), grip_left=(13.0, 13.1)),
        ProfileSpec(3, "Menurun",
                    "Kepatuhan menurun dari 5 ke 1 sesi/minggu; genggam turun.",
                    sessions_per_week=[5, 5, 4, 4, 3, 2, 2, 1], grip_right=(11.0, 8.5),
                    grip_left=(14.0, 13.0)),
        ProfileSpec(4, "Tidak teratur",
                    "Jumlah sesi per minggu acak 0 sampai 7; beberapa sesi < 5 menit.",
                    sessions_per_week=[6, 1, 0, 7, 2, 5, 0, 3], short_session_prob=0.2,
                    grip_right=(9.0, 10.5)),
        ProfileSpec(5, "Jeda 2 minggu",
                    "Tidak ada latihan dan tes genggam di minggu 4 dan 5.",
                    sessions_per_week=[5, 5, 4, 0, 0, 3, 4, 5],
                    grip_test_weeks=[0, 1, 2, 5, 6, 7], grip_right=(7.0, 9.0)),
        ProfileSpec(6, "Kelingking jarang dipakai",
                    "Jari kelingking hanya ~3% dari tekanan.",
                    sessions_per_week=[5, 4, 5, 5, 4, 5, 5, 4],
                    finger_weights=(0.40, 0.33, 0.24, 0.03), grip_right=(9.0, 11.0)),
        ProfileSpec(7, "Tes terlewat dan BLE sering putus",
                    "Tes genggam hanya 4 kali; BLE terputus di banyak sesi.",
                    sessions_per_week=[4, 5, 4, 5, 4, 5, 4, 5], grip_test_weeks=[0, 3, 4, 7],
                    ble_drop_prob=0.55, grip_right=(8.5, 10.0)),
        ProfileSpec(8, "Latihan malam",
                    "Beberapa sesi dimulai mendekati tengah malam dan melewatinya.",
                    sessions_per_week=[4, 4, 5, 4, 4, 5, 4, 4], hours=(20, 21, 22),
                    midnight_sessions=4, short_session_prob=0.15, grip_right=(10.0, 12.0)),
        ProfileSpec(9, "Sesi kosong, pendek, dan timeout",
                    "Ada sesi tanpa tekanan, sesi < 5 menit, dan sesi yang berakhir karena timeout 120 s.",
                    sessions_per_week=[5, 6, 5, 6, 5, 6, 5, 6], empty_session_prob=0.15,
                    short_session_prob=0.2, timeout_prob=0.5, grip_right=(9.0, 9.8)),
        ProfileSpec(10, "Keymap berubah",
                     "Keymap diganti dari fghj ke asdl mulai minggu 5.",
                     sessions_per_week=[5, 4, 5, 4, 5, 4, 5, 4], keymap_change_week=4,
                     grip_right=(6.0, 8.0), grip_left=(12.0, 12.5)),
    ]


def load_spec(months: int) -> ProfileSpec:
    weeks = {1: 5, 3: 13, 6: 26}[months]
    return ProfileSpec(100 + months, f"Beban T3 {months} bulan",
                       f"Data simulasi {weeks} minggu untuk uji waktu muat dashboard.",
                       weeks=weeks, sessions_per_week=[5] * weeks, grip_right=(8.0, 12.0),
                       timeout_prob=0.2, short_session_prob=0.05)


def write(obj: dict, name: str) -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    raw = json.dumps(obj, separators=(",", ":")).encode()
    with gzip.GzipFile(path, "wb", mtime=0) as f:  # mtime=0 supaya output deterministik
        f.write(raw)
    return os.path.getsize(path)


def main() -> None:
    rng = random.Random(SEED)
    for spec in specs():
        g = Gen(spec, random.Random(rng.randint(0, 2**31)))
        prof = g.build()
        size = write(prof, f"profile_{spec.pid:02d}.json.gz")
        n_keys = sum(len(s["keys"]) for s in prof["sessions"])
        print(f"profile_{spec.pid:02d}: {len(prof['sessions'])} sesi, "
              f"{len(prof['grip_tests'])} tes, {n_keys} key event, {size/1024:.0f} KB")
    for m in (1, 3, 6):
        g = Gen(load_spec(m), random.Random(rng.randint(0, 2**31)))
        prof = g.build()
        size = write(prof, f"load_{m}m.json.gz")
        print(f"load_{m}m: {len(prof['sessions'])} sesi, {size/1024:.0f} KB")


if __name__ == "__main__":
    main()
