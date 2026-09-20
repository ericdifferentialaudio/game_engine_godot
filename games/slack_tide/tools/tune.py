#!/usr/bin/env python3
"""Grid-search the tuning knobs for the target win-rate band.

The objective is NOT maximum chaos. Entropy is maximised by a coin flip, which
is the opposite of what this game wants. The target is a game a competent
player usually wins and a careless one usually loses:

    competent win rate   0.75 - 0.88   (loses sometimes, rarely)
    naive win rate       <= 0.35       (skill has to matter)
    distinct endings     >= 6, none over 40%
    duration             60 - 90 minutes

`fitness` scores a candidate against that band. Runs entirely in Python, so a
full sweep costs nothing but a few seconds of CPU.
"""
from __future__ import annotations

import argparse
import itertools
import json

from model import Model, load_spec, sweep

TARGET_COMP = (0.75, 0.88)
TARGET_NAIVE = 0.35
TARGET_MINUTES = (60.0, 90.0)
MIN_ENDINGS = 6
MAX_TOP_SHARE = 0.40


def band_penalty(value: float, lo: float, hi: float) -> float:
    if value < lo:
        return lo - value
    if value > hi:
        return value - hi
    return 0.0


def fitness(comp: dict, naive: dict) -> tuple[float, dict]:
    """Lower is better. Every term is a distance from the design target."""
    p_win = band_penalty(comp["win_rate"], *TARGET_COMP) * 4.0
    p_naive = max(0.0, naive["win_rate"] - TARGET_NAIVE) * 3.0
    p_mins = band_penalty(comp["avg_minutes"], *TARGET_MINUTES) / 60.0
    p_ends = max(0, MIN_ENDINGS - comp["distinct_outcomes"]) * 0.15
    p_top = max(0.0, comp["top_outcome_share"] - MAX_TOP_SHARE) * 1.5
    total = p_win + p_naive + p_mins + p_ends + p_top
    return total, {"win": round(p_win, 3), "naive": round(p_naive, 3),
                   "mins": round(p_mins, 3), "ends": round(p_ends, 3),
                   "top": round(p_top, 3)}


GRID = {
    "learn_per_slot": [1.8, 2.0],
    "corroborate_chance": [0.85, 1.0],
    "value_gain_per_day": [3.0, 3.6, 4.2],
    "full_slack_low": [15, 16, 17],
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=500)
    ap.add_argument("--top", type=int, default=8)
    args = ap.parse_args()

    spec = load_spec()
    keys = list(GRID)
    rows = []
    for combo in itertools.product(*(GRID[k] for k in keys)):
        tuning = dict(zip(keys, combo))
        if "full_slack_low" in tuning:
            tuning["full_slack_high"] = tuning["full_slack_low"] + 2
        m = Model(spec, tuning)
        comp = sweep(m, args.seeds, "competent")
        naive = sweep(m, args.seeds, "naive")
        score, parts = fitness(comp, naive)
        rows.append((score, tuning, comp, naive, parts))

    rows.sort(key=lambda r: r[0])
    print(f"grid={len(rows)} combos, {args.seeds} seeds each\n")
    print(f"{'fit':>6}  {'comp':>6}{'naive':>7}{'mins':>7}{'ends':>6}{'top':>6}  tuning")
    print("-" * 92)
    for score, tuning, comp, naive, parts in rows[:args.top]:
        t = " ".join(f"{k}={v}" for k, v in tuning.items()
                     if k != "full_slack_high")
        print(f"{score:6.3f}  {comp['win_rate']:6.3f}{naive['win_rate']:7.3f}"
              f"{comp['avg_minutes']:7.1f}{comp['distinct_outcomes']:6d}"
              f"{comp['top_outcome_share']:6.2f}  {t}")
    best = rows[0]
    print("\nbest penalties:", json.dumps(best[4]))
    print("best outcomes:", json.dumps(best[2]["outcomes"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
