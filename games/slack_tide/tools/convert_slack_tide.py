#!/usr/bin/env python3
"""Generate the Slack Tide engine data from the neutral design spec.

    docs/slack_tide_spec.json   (source of truth, hand-authored)
        -> intel.json           (75 tokens, engine schema)
        -> docs/slack_tide_tokens.md

The spec speaks in design terms (reliability 0-100, `src: ["fen:told"]`,
`truth: "culprit=A"`). The engine speaks CoreIntelToken (reliability 0.0-1.0,
`conflicts`, provenance). This script is the only place that mapping lives.

Usage:
    python games/slack_tide/tools/convert_slack_tide.py
    python games/slack_tide/tools/convert_slack_tide.py --check   # non-zero if stale
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
REPO = GAME.parents[1]
SPEC = GAME / "docs" / "slack_tide_spec.json"
INTEL_OUT = GAME / "intel.json"
TOKENS_OUT = GAME / "docs" / "slack_tide_tokens.md"

CATEGORY = {
    "case": "case",
    "evidence": "evidence",
    "tide": "tide",
    "beast": "beast",
    "person": "person",
    "econ": "economy",
    "secret": "secret",
    "route": "route",
}

# Category -> what a buyer pays before reliability/scarcity/inflation.
BASE_PRICE = {
    "case": 14, "evidence": 12, "secret": 10, "route": 8,
    "person": 6, "economy": 5, "beast": 5, "tide": 4,
}


def load_spec() -> dict:
    with SPEC.open(encoding="utf-8") as fh:
        return json.load(fh)


def parse_source(entry: str) -> dict:
    """'fen:told' -> {'source': 'fen', 'method': 'told'}; '*' marks gated."""
    who, _, method = entry.partition(":")
    gated = who.endswith("*")
    return {"source": who.rstrip("*"), "method": method or "told", "gated": gated}


def build_tokens(spec: dict) -> list[dict]:
    methods = spec["method_reliability"]
    rumor_cap = spec["rumor_cap"]
    scale = 100.0

    # group -> ids, so mutually exclusive answers list each other as conflicts.
    groups: dict[str, list[str]] = {}
    for tok in spec["tokens"]:
        grp = tok.get("group")
        if grp:
            groups.setdefault(grp, []).append(tok["id"])

    out = []
    for tok in spec["tokens"]:
        cat = CATEGORY.get(tok["cat"], tok["cat"])
        sources = [parse_source(s) for s in tok.get("src", [])]
        rumors = [parse_source(s) for s in tok.get("rumor", [])]

        # Base reliability is the best method that can teach it.
        best = max((methods.get(s["method"], 30) for s in sources), default=30)

        grp = tok.get("group")
        conflicts = [i for i in groups.get(grp, []) if i != tok["id"]] if grp else []

        entry = {
            "id": tok["id"],
            "title": tok["name"],
            "category": cat,
            "summary": tok["text"],
            "reliability": round(best / scale, 2),
            "tags": [tok["cat"]],
            "truth": tok.get("truth", "always"),
            "sale_value": BASE_PRICE.get(cat, 5),
            "sources": [
                {"source": s["source"], "method": s["method"],
                 "reliability": round(methods.get(s["method"], 30) / scale, 2),
                 **({"gated": True} if s["gated"] else {})}
                for s in sources
            ],
        }
        if grp:
            entry["group"] = grp
        if conflicts:
            entry["conflicts"] = conflicts
        if rumors:
            entry["rumor_sources"] = [
                {"source": s["source"], "method": s["method"],
                 "reliability": round(rumor_cap / scale, 2)}
                for s in rumors
            ]
        if tok.get("unlocks"):
            entry["unlocks"] = tok["unlocks"]
        # Hearsay is perishable; solid facts are not.
        if best < spec.get("decay_below", 50):
            entry["decay_turns"] = 1.0
        out.append(entry)
    return out


def build_intel(spec: dict) -> dict:
    return {
        "_generated": "by games/slack_tide/tools/convert_slack_tide.py "
                      "from docs/slack_tide_spec.json - do not edit by hand",
        "rules": {
            "scale": 100,
            "method_reliability": spec["method_reliability"],
            "corroboration_bonus": 20,
            "corroboration_cap": 95,
            "rumor_cap": spec["rumor_cap"],
            "rumor_mills": spec["rumor_mills"],
            "gated_sources": spec["gated_sources"],
            "decay_below": 50,
            "decay_per_day": 5,
            "decay_floor": 10,
        },
        "groups": sorted({t["group"] for t in spec["tokens"] if t.get("group")}),
        "intel": build_tokens(spec),
    }


def build_tokens_md(intel: dict) -> str:
    rows = ["# Slack Tide - Information Token List", "",
            f"{len(intel['intel'])} tokens. **Generated** from "
            "`slack_tide_spec.json` by `tools/convert_slack_tide.py`; "
            "edit the spec, not this file.", "",
            "`truth` is `always` (true in every seed) or `culprit=A/B/C` "
            "(true only when that culprit is the hidden cause). Members of one "
            "group are mutually exclusive by seed, so exposing a false answer "
            "corroborates the true one.", ""]
    by_cat: dict[str, list[dict]] = {}
    for t in intel["intel"]:
        by_cat.setdefault(t["category"], []).append(t)
    for cat in sorted(by_cat):
        toks = by_cat[cat]
        rows += [f"## {cat} ({len(toks)})", "",
                 "| ID | Name | Journal text | Truth | Group | Base | Sells |",
                 "|---|---|---|---|---|---|---|"]
        for t in toks:
            rows.append(
                f"| `{t['id']}` | {t['title']} | {t['summary']} | "
                f"{t['truth']} | {t.get('group', '')} | "
                f"{int(t['reliability'] * 100)} | {t['sale_value']} |")
        rows.append("")
    return "\n".join(rows) + "\n"


def write(path: Path, text: str, check: bool) -> bool:
    """Returns True when the file is (or was made) up to date."""
    current = path.read_text(encoding="utf-8") if path.exists() else None
    rel = path.relative_to(REPO)
    if current == text:
        print(f"up to date: {rel}")
        return True
    if check:
        print(f"STALE: {rel}", file=sys.stderr)
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"wrote:      {rel}")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true",
                    help="verify without writing; non-zero exit if stale")
    args = ap.parse_args()

    spec = load_spec()
    intel = build_intel(spec)

    ok = write(INTEL_OUT, json.dumps(intel, indent=2) + "\n", args.check)
    ok = write(TOKENS_OUT, build_tokens_md(intel), args.check) and ok

    if not ok:
        print("\nRun: python games/slack_tide/tools/convert_slack_tide.py",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
