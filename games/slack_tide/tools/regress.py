#!/usr/bin/env python3
"""Balance regression gate for Slack Tide.

Runs the committed tuning from `docs/BALANCE.json` over HELD-OUT seeds (a
different range from the one tuned on, so a pass means the balance generalises
rather than that it was fitted). Fails non-zero if the game has drifted out of
its design band.

The band matters more than any single number: a change that raises the
competent win rate to 0.95 is a REGRESSION, not an improvement, because the
player stops being able to lose.

    python regress.py              # gate, exits non-zero on drift
    python regress.py --update     # accept current numbers as the new baseline
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from model import Model, load_spec, sweep

BALANCE = Path(__file__).resolve().parent.parent / "docs" / "BALANCE.json"
HELD_OUT_START = 900_001

TOL_WIN = 0.06
TOL_MINUTES = 8.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=2000)
    ap.add_argument("--update", action="store_true")
    ap.add_argument("--quiet", action="store_true",
                    help="one-line result (for CI)")
    args = ap.parse_args()

    cfg = json.loads(BALANCE.read_text(encoding="utf-8"))
    tuning, targets = cfg["tuning"], cfg["targets"]
    model = Model(load_spec(), tuning)

    comp = sweep(model, args.seeds, "competent", start=HELD_OUT_START)
    naive = sweep(model, args.seeds, "naive", start=HELD_OUT_START)

    failures: list[str] = []

    lo, hi = targets["competent_win_rate"]
    if not lo <= comp["win_rate"] <= hi:
        failures.append(
            f"competent win rate {comp['win_rate']:.3f} outside band [{lo}, {hi}]"
            + ("  (too easy - the player can no longer lose)"
               if comp["win_rate"] > hi else "  (too punishing)"))

    if naive["win_rate"] > targets["naive_win_rate_max"]:
        failures.append(
            f"naive win rate {naive['win_rate']:.3f} > "
            f"{targets['naive_win_rate_max']} - skill does not matter enough")

    mlo, mhi = targets["minutes"]
    if not mlo <= comp["avg_minutes"] <= mhi:
        failures.append(
            f"duration {comp['avg_minutes']:.1f} min outside [{mlo}, {mhi}]")

    if comp["distinct_outcomes"] < targets["min_distinct_endings"]:
        failures.append(
            f"only {comp['distinct_outcomes']} distinct endings, want "
            f">= {targets['min_distinct_endings']}")

    if comp["top_outcome_share"] > targets["max_top_outcome_share"]:
        failures.append(
            f"top ending is {comp['top_outcome_share']:.0%} of runs, want "
            f"<= {targets['max_top_outcome_share']:.0%}")

    base = cfg.get("baseline", {})
    if base and not args.update:
        bc = base.get("competent", {})
        if abs(comp["win_rate"] - bc.get("win_rate", comp["win_rate"])) > TOL_WIN:
            failures.append(
                f"competent win rate moved {bc['win_rate']:.3f} -> "
                f"{comp['win_rate']:.3f} (tolerance {TOL_WIN})")
        if abs(comp["avg_minutes"] - bc.get("avg_minutes", comp["avg_minutes"])) > TOL_MINUTES:
            failures.append(
                f"duration moved {bc['avg_minutes']:.1f} -> "
                f"{comp['avg_minutes']:.1f} min (tolerance {TOL_MINUTES})")

    if not args.quiet:
        print(f"Slack Tide balance - {args.seeds} held-out seeds "
              f"(from {HELD_OUT_START})\n")
        print(f"  competent   win {comp['win_rate']:.3f}   understood "
              f"{comp['understood_rate']:.3f}   {comp['avg_minutes']:.1f} min  "
              f" {comp['distinct_outcomes']} endings   "
              f"top {comp['top_outcome_share']:.2f}")
        print(f"  naive       win {naive['win_rate']:.3f}")
        print(f"  skill gap   {comp['win_rate'] - naive['win_rate']:.3f}")
        print(f"\n  endings: {json.dumps(comp['outcomes'])}")

    if args.update:
        cfg["baseline"] = {
            "_note": cfg.get("baseline", {}).get("_note", ""),
            "competent": {k: comp[k] for k in
                          ("win_rate", "understood_rate", "avg_minutes",
                           "distinct_outcomes", "top_outcome_share")},
            "naive": {"win_rate": naive["win_rate"]},
        }
        BALANCE.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
        print("\nbaseline updated.")
        return 0

    if failures:
        print("FAIL: slack_tide balance out of band")
        for f in failures:
            print("  - " + f)
        return 1
    if args.quiet:
        print(f"PASS: slack_tide balance (competent {comp['win_rate']:.3f}, "
              f"naive {naive['win_rate']:.3f}, {comp['avg_minutes']:.0f} min, "
              f"{comp['distinct_outcomes']} endings)")
    else:
        print("\nPASS - balance is inside the design band.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
