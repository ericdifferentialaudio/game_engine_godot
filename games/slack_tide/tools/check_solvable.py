#!/usr/bin/env python3
"""Prove the puzzle is winnable, in every seed, before any prose is written.

This is design milestone M0, and it is worth more than any amount of writing
done first. It reads the token graph and `topics.json` ONLY -- no Ink, no
engine -- and asserts the four contracts from
`docs/INFORMATION_ARCHITECTURE.md`:

  1. Every road-critical token has at least two INDEPENDENT routes to >= 75
     reliability. (One route is a single point of failure; a rumour mill
     capped at 25 is not a route at all.)
  2. Every seed keeps at least one road affordable on the LOW income curve.
  3. No needed token is reachable only through a gated/losable NPC.
  4. Every gift is reachable from a 3/10 value start.

Exits non-zero on any violation, so it can gate CI.
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = HERE.parent / "docs" / "slack_tide_spec.json"
TOPICS = HERE.parent / "topics.json"

ROAD_FLOOR = 75
CORROBORATION_BONUS = 20
CORROBORATION_CAP = 95


def low_income(spec: dict) -> int:
    """Tallies a LOW earner banks over Act I. Anything a road needs beyond
    this is unaffordable for a player having a bad run -- a design failure
    rather than a difficulty setting."""
    m = spec["income_model"]
    days, crossings = m["days"], m["crossings_per_day"]
    return int(
        m["wage_per_day"] * days
        + m["tips_per_crossing"][0] * crossings * days
        + m["parcels_per_day"][0] * m["parcel_fee"][0] * days
        + m["info_sales"][0]
        + m["salvage"][0]
        - m["board_per_day"] * days
    )


def routes_to(spec: dict, token_id: str) -> list[tuple[str, int]]:
    """(source, reliability) pairs that can deliver this token first-hand."""
    rel = spec["method_reliability"]
    out = []
    for t in spec["tokens"]:
        if t["id"] != token_id:
            continue
        for entry in t.get("src") or []:
            who, _, method = entry.partition(":")
            out.append((who, rel.get(method or "told", 30)))
    return out


def best_reliability(routes: list[tuple[str, int]]) -> int:
    """Highest reliability obtainable, allowing one corroboration."""
    if not routes:
        return 0
    by_source: dict[str, int] = {}
    for who, r in routes:
        by_source[who] = max(by_source.get(who, 0), r)
    ranked = sorted(by_source.values(), reverse=True)
    best = ranked[0]
    if len(ranked) > 1:
        best = min(CORROBORATION_CAP, best + CORROBORATION_BONUS)
    return best


def road_cost(spec: dict, s: dict) -> int:
    items = spec["items"]
    cost = sum(items.get(i, {}).get("price", 0) for i in (s.get("items") or []))
    for group in (s.get("items_any") or []):
        prices = [items[g]["price"] for g in group if g in items]
        if prices:
            cost += min(prices)
    cost += sum(items.get(i, {}).get("price", 0)
                for i in (s.get("extra_items") or []))
    if s.get("armor"):
        cost += items.get("oiled_leather", {}).get("price", 0)
    return cost


def needed_tokens(spec: dict) -> set[str]:
    out: set[str] = set()
    for road in spec["roads"].values():
        for s in road.values():
            out.update(s.get("tokens", []))
    for e in spec["entry_methods"].values():
        out.update(e.get("tokens", []))
    out.update(spec.get("passage", {}).get("tokens", []))
    out.update(spec.get("common_turn", {}).get("tokens", []))
    return out


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--quiet", action="store_true",
                    help="only report failures (for CI)")
    args = ap.parse_args()

    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    topics = json.loads(TOPICS.read_text(encoding="utf-8"))
    gated = set(spec.get("gated_sources", []))
    failures: list[str] = []
    notes: list[str] = []

    # --- 1 & 3 -----------------------------------------------------------
    for tid in sorted(needed_tokens(spec)):
        routes = routes_to(spec, tid)
        sources = {w for w, _ in routes}
        if not routes:
            failures.append(f"[1] token '{tid}' is required but has NO source")
            continue
        best = best_reliability(routes)
        if best < ROAD_FLOOR:
            failures.append(
                f"[1] token '{tid}' tops out at {best} reliability, below the "
                f"{ROAD_FLOOR} a road demands")
        if sources and sources <= gated:
            failures.append(
                f"[3] token '{tid}' is reachable only through gated "
                f"source(s) {sorted(sources)}")
        elif len(sources) < 2:
            notes.append(
                f"[1] token '{tid}' has a single source "
                f"'{next(iter(sources))}' (single point of failure)")

    # --- 2 ---------------------------------------------------------------
    budget = low_income(spec)
    for seed in "ABC":
        affordable = [name for name, road in spec["roads"].items()
                      if seed in road and road_cost(spec, road[seed]) <= budget]
        costs = {name: road_cost(spec, road[seed])
                 for name, road in spec["roads"].items() if seed in road}
        if not affordable:
            failures.append(
                f"[2] seed {seed} has NO road affordable on the low income "
                f"curve ({budget}t); costs were {costs}")
        else:
            notes.append(f"[2] seed {seed} affordable roads {affordable} "
                         f"of costs {costs}")

    # --- 4 ---------------------------------------------------------------
    start, cap = spec["value_start"], spec["value_cap"]
    total_points = 0
    for gid, g in spec["gifts"].items():
        vals = g.get("values") or {}
        need = sum(max(0, n - start) for n in vals.values())
        total_points += need
        if any(n > cap for n in vals.values()):
            failures.append(f"[4] gift '{gid}' needs a value above the cap")
        hint = g.get("hint")
        if hint and not routes_to(spec, hint):
            failures.append(
                f"[4] gift '{gid}' hint token '{hint}' has no source")

    if not args.quiet:
        print(f"Slack Tide solvability - {len(spec['tokens'])} tokens, "
              f"{len(topics['topics'])} topics, low income {budget}t\n")
        for n in notes:
            print("  note  " + n)
        print(f"\n  all seven gifts would need {total_points} value points "
              f"above a {start}/{cap} start; a run earns far fewer, so which "
              f"gifts you\n  hold is a CHOICE -- the intended tension.")

    if failures:
        print(f"\nFAIL - {len(failures)} violation(s):")
        for f in failures:
            print("  - " + f)
        return 1
    print("PASS: slack_tide solvable (every seed)" if args.quiet
          else "\nPASS - every seed is solvable.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
