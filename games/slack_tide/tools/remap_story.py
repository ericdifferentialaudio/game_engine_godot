#!/usr/bin/env python3
"""Apply the STORY_BIBLE re-map to `docs/slack_tide_spec.json`.

One idempotent, reviewable edit rather than hand-editing a 50KB file:

  * Lisle Harrow, the courier who dies on your deck on day 2, IS the husband
    Doon lost at the Weir. The gated mercy-5 endgame source becomes the widow
    of the man whose satchel you did or did not open.
  * Seed A is reframed: the Choir sings with his voice; she knows it is not
    him and holds the gate anyway.
  * Seed B is reframed: no villain, a clerk who moved a date.
  * Seed C is reframed: the culprit rumours are people the town needed to
    blame, and the Name is Harrow's last work.

Structure -- ids, groups, truth, sources, reliability -- is untouched, so the
solvability proof and the balance baseline still hold. Only MEANING changes.

    python remap_story.py           # apply
    python remap_story.py --check   # exit 1 if not yet applied
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SPEC = Path(__file__).resolve().parent.parent / "docs" / "slack_tide_spec.json"

MARKER = "harrow_widow_v1"

TOKEN_TEXT = {
    "s_doon_husband": (
        "Doon's husband drowned in the Weir's first flood. His name was Lisle "
        "Harrow. She has not left the gatehouse since, and she has never been "
        "given a body to bury."),
    "p_doon": (
        "Ilsabet Doon has kept the Weir since her husband died there. She "
        "answers to her oath before anyone, and she answers to him before "
        "the oath."),
    "c5a": (
        "Only the Wardens' Assize can release Doon from her oath. Then she "
        "will open the gate - and the voice in the Underworks will stop."),
    "ev_a_lantern": (
        "A lantern log in Doon's hand: a trimmed wick and a mark at every "
        "third bell of the night. Eleven months of them, without a gap."),
    "c3a": (
        "The satchel holds Doon's own letter to the Wardens, begging for "
        "bell-founders before the Weir fails. It is dated three weeks ago."),
    "c3b": (
        "The satchel holds a page of the night-sluice log naming a paid crew, "
        "and one clerk's initials against a moved date."),
    "c3c": (
        "The satchel holds a chart of hum-marks along the causeway, drawn in "
        "Harrow's hand. The last mark is not a place. It is a name."),
    "c1c": (
        "No hand touches the night sluice. It closes on its own, humming, and "
        "it has been listening to us say its name for four hundred years."),
    "c4c": (
        "The Long Slack begins in the Underworks under the Salt Steps, where "
        "the water hums in a voice people keep saying they recognise."),
    "c5c": (
        "Ring the Bell of Turning at the third bell of Full Slack and the "
        "Choir will sleep. Harrow's chart says it would rather be asked."),
    "ev_c_hum": (
        "Stand on the Salt Steps at slack and the stone hums up through your "
        "boots. Everyone who hears it names someone different."),
}

NPC_ROLE = {
    "doon": "Weirkeeper, and Lisle Harrow's widow. Culprit A: she holds the "
            "gate because the Choir sings with his voice. Gated source "
            "(mercy 5) - the moral centre of seed A.",
    "harrow": "Warden-Courier Lisle Harrow. Doon's husband. Dies on your deck "
              "on Day 2 leaving a sealed satchel that would have stopped this "
              "had it arrived. You are always already too late.",
    "corvin": "Corvin Ashe, Tally House clerk. Culprit B is not a villain: he "
              "moved a date two weeks and the sluice silted. He is bailing "
              "out his own cellar and has not slept.",
}


def apply(spec: dict) -> int:
    changed = 0
    for t in spec["tokens"]:
        new = TOKEN_TEXT.get(t["id"])
        if new and t.get("text") != new:
            t["text"] = new
            changed += 1
    for nid, role in NPC_ROLE.items():
        if nid in spec["npcs"] and spec["npcs"][nid].get("role") != role:
            spec["npcs"][nid]["role"] = role
            changed += 1
    if spec.get("story_remap") != MARKER:
        spec["story_remap"] = MARKER
        changed += 1
    return changed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    changed = apply(spec)

    if args.check:
        if changed:
            print(f"story re-map NOT applied ({changed} pending)",
                  file=sys.stderr)
            return 1
        print("story re-map applied")
        return 0

    if changed:
        SPEC.write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n",
                        encoding="utf-8")
    print(f"story re-map: {changed} field(s) updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
