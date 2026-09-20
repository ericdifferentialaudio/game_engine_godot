#!/usr/bin/env python3
"""Why did runs fail? Attributes each failure to the specific requirement that
blocked it, so tuning targets the real constraint instead of guessing."""
from __future__ import annotations

import collections
from model import Model, load_spec


def blockers(m: Model, run, culprit: str) -> list[str]:
    out = []
    for name, spec in m.entries.items():
        if culprit not in spec.get("seeds", ""):
            continue
        miss = [t for t in spec.get("tokens", []) if not m.reliable(run, t, 55)]
        if miss:
            out.append(f"entry:{name}:tokens:{','.join(miss)}")
        vmiss = [v for v, n in (spec.get("values") or {}).items()
                 if run.values.get(v, 0) < n]
        if vmiss:
            out.append(f"entry:{name}:values:{','.join(vmiss)}")
        gmiss = [i for i in (spec.get("items") or [])
                 if i not in m.items and i not in run.items]
        if gmiss:
            out.append(f"entry:{name}:gift:{','.join(gmiss)}")
    for road in ("word", "bargain", "hand"):
        spec = m.roads[road].get(culprit)
        if not spec:
            continue
        floor = spec.get("min_reliability", 75)
        miss = [t for t in spec.get("tokens", []) if not m.reliable(run, t, floor)]
        if miss:
            out.append(f"{road}:tokens:{','.join(miss)}")
        vmiss = [f"{v}<{n}" for v, n in (spec.get("values") or {}).items()
                 if run.values.get(v, 0) < n]
        if vmiss:
            out.append(f"{road}:values:{','.join(vmiss)}")
        ok, cost = m._road_ok(run, road, culprit)
        if not ok and not miss and not vmiss:
            out.append(f"{road}:money:need{cost}:have{run.tallies}")
    return out


BEST = {"learn_per_slot": 2.2, "corroborate_chance": 0.65,
        "value_gain_per_day": 1.8, "full_slack_low": 14, "full_slack_high": 16}


def main() -> None:
    m = Model(load_spec(), BEST)
    counts = collections.Counter()
    rel = collections.defaultdict(list)
    n = 600
    for s in range(1, n + 1):
        r = m.run_one(s, "competent")
        if not r.won:
            for b in blockers(m, r, r.culprit):
                counts[b] += 1
        for t in m.needed_tokens(r.culprit):
            rel[t].append(r.tokens.get(t, 0))

    print(f"competent, {n} seeds - top blockers:\n")
    for b, c in counts.most_common(22):
        print(f"{c:5d}  {b}")
    print("\nlowest average reliability among needed tokens:")
    avg = sorted(((sum(v) / len(v), k) for k, v in rel.items() if v))
    for a, k in avg[:14]:
        print(f"  {a:6.1f}  {k}")


if __name__ == "__main__":
    main()
