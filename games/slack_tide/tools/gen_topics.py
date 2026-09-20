#!/usr/bin/env python3
"""Generate `topics.json` -- the puzzle layer -- from the token graph.

`INFORMATION_ARCHITECTURE.md` splits the game on a real seam:
`topics.json` decides what is POSSIBLE; Ink decides what it SOUNDS LIKE. This
tool derives the former from each token's declared `src`/`rumor` lists, so the
matrix can never contradict the token graph -- there is one source of truth.

A topic is a question the town argues about. Tokens sharing a `conflicts`
group become one topic (the triad answers); ungrouped tokens are grouped by
category so every token has at least one route.

Stances per NPC are chosen from how that NPC knows the thing:
    explain  a real source -- grants the seed-true answer at its method
    rumor    a rumour mill -- grants EVERY answer, capped (this is where
             false belief comes from, and it must stay cheap and plausible)
    price    a buyer -- will pay for it rather than tell you

    python gen_topics.py            # write ../topics.json
    python gen_topics.py --check    # exit 1 if the file is stale
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = HERE.parent / "docs" / "slack_tide_spec.json"
OUT = HERE.parent / "topics.json"

BUYERS = {"ottoline", "wimble"}

CATEGORY_TOPICS = {
    "case": "The stalled tide",
    "place": "Where it is safe to walk",
    "beast": "What lives down there",
    "econ": "Who is paying whom",
    "secret": "What people would rather keep",
    "person": "Who these people are",
    "rite": "How the old work is done",
    "evidence": "What can be proved",
}


def build(spec: dict) -> dict:
    tokens = spec["tokens"]
    mills = set(spec.get("rumor_mills", []))
    rumor_cap = spec.get("rumor_cap", 25)

    groups: dict[str, list[dict]] = {}
    for t in tokens:
        key = t.get("group") or ("cat:" + t.get("cat", "misc"))
        groups.setdefault(key, []).append(t)

    topics = {}
    for key, members in sorted(groups.items()):
        is_triad = not key.startswith("cat:")
        cat = members[0].get("cat", "misc")
        name = (members[0]["name"] if is_triad
                else CATEGORY_TOPICS.get(cat, cat.title()))

        stances: dict[str, dict] = {}
        for t in members:
            for entry in t.get("src") or []:
                who, _, method = entry.partition(":")
                if who in BUYERS:
                    stances.setdefault(who, {"mode": "price", "buys": []})
                    if stances[who]["mode"] == "price":
                        stances[who]["buys"].append(t["id"])
                    continue
                st = stances.setdefault(
                    who, {"mode": "explain", "method": method or "told",
                          "grants": []})
                if st["mode"] == "explain":
                    st["grants"].append(t["id"])
            for entry in t.get("rumor") or []:
                who, _, method = entry.partition(":")
                st = stances.setdefault(
                    who, {"mode": "rumor", "cap": rumor_cap, "grants": []})
                if st["mode"] == "rumor":
                    st["grants"].append(t["id"])

        unlocks = sorted({u for t in members for u in (t.get("unlocks") or [])})
        topics[key if is_triad else cat] = {
            "name": name,
            "kind": "triad" if is_triad else "background",
            "tokens": [t["id"] for t in members],
            "resolves_group": key if is_triad else None,
            "unlocks": unlocks,
            "stances": {k: stances[k] for k in sorted(stances)},
        }

    return {
        "_generated": "by tools/gen_topics.py from docs/slack_tide_spec.json"
                      " - do not hand-edit",
        "_contract": "topics.json decides what is POSSIBLE; Ink decides what"
                     " it sounds like. Checked by tools/check_solvable.py.",
        "rumor_cap": rumor_cap,
        "rumor_mills": sorted(mills),
        "topics": topics,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    data = build(spec)
    text = json.dumps(data, indent=1) + "\n"

    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("topics.json is stale - run tools/gen_topics.py",
                  file=sys.stderr)
            return 1
        print("topics.json up to date")
        return 0

    OUT.write_text(text, encoding="utf-8")
    n_triad = sum(1 for t in data["topics"].values() if t["kind"] == "triad")
    print(f"wrote {OUT.name}: {len(data['topics'])} topics "
          f"({n_triad} triad), {len(spec['tokens'])} tokens")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
