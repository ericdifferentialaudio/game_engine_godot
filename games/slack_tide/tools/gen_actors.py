#!/usr/bin/env python3
"""Fill the actor gap in `actors.json` from the design spec.

`topics.json` names 26 speaking sources. `actors.json` had **6** actors, so
most of the cast -- including **Doon and Brack, who are the endgame** -- did
not exist as far as the engine was concerned. They were always in
`slack_tide_spec.json`; `convert_slack_tide.py` simply never emitted them.

This tool MERGES rather than regenerates:

  * Hand-authored actors are preserved **verbatim**. `actors.json` contains
    real writing (Hesper's hiring scene, Corvin's flinch) and a generator must
    never eat it.
  * Missing NPCs are appended, each marked `"_generated": true`.
  * Re-running replaces only `_generated` entries. Delete that key from an
    entry and it becomes hand-authored and is left alone forever after.

Not every source in `topics.json` is a person: locations (`salt_steps`),
objects (`satchel`, `tide_almanac`) and passenger archetypes (`pax_gossip`)
grant tokens without being actors. Those are reported, not invented.

    python gen_actors.py           # merge missing actors
    python gen_actors.py --check   # exit 1 if any are missing
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

GAME = Path(__file__).resolve().parents[1]
SPEC = GAME / "docs" / "slack_tide_spec.json"
ACTORS = GAME / "actors.json"
TOPICS = GAME / "topics.json"

# Faction by role, so standing and reactions have something to hang on.
FACTION = {
    "hesper": "ferry", "doss": "ferry", "goldie": "sorrel", "cobb": "sorrel",
    "fen": "salvage", "ottoline": "tally", "corvin": "tally",
    "wimble": "customs", "vosk": "customs", "croy": "far_wend",
    "yarrow": "far_wend", "brack": "wardens", "toma": "marsh",
    "wenna": "bell", "doon": "wardens", "collector": "drowned",
    "harrow": "wardens", "gatehouse_guard": "wardens",
}


def stance_summary(topics: dict, npc: str) -> list[dict]:
    """What this NPC can actually talk about, straight from the matrix."""
    out = []
    for tid, topic in topics.get("topics", {}).items():
        st = topic.get("stances", {}).get(npc)
        if st:
            out.append({"topic": tid, "mode": st.get("mode", "explain"),
                        "grants": st.get("grants", st.get("buys", []))})
    return out


def build_actor(npc_id: str, npc: dict, topics: dict) -> dict:
    """A functional actor: correct id, place, faction and topic surface.

    Dialogue is deliberately minimal -- prose is the conversation generator's
    job (see CONVERSATION_GENERATOR.md). What matters is that the actor
    EXISTS, stands in the right place, and declares what it knows, so the
    validator and the session driver can both see it.
    """
    stances = stance_summary(topics, npc_id)
    role_line = str(npc.get("role", ""))
    return {
        "id": npc_id,
        "_generated": True,
        "display_name": npc.get("name", npc_id.title()),
        "role": "npc",
        "faction": FACTION.get(npc_id, "neutral"),
        "location": npc.get("location", ""),
        "portrait": "portrait." + npc_id,
        "description": role_line,
        "topics": [s["topic"] for s in stances],
        "interactions": [
            {
                "kind": "dialogue",
                "start": "greet",
                "speaker": npc.get("name", npc_id.title()),
                "nodes": {
                    "greet": {
                        # NEEDS_HUMAN_WRITING - placeholder until the
                        # conversation generator or a human replaces it.
                        "text": role_line or "They look up as you approach.",
                        "choices": [
                            {"text": "(ask what they know)", "next": None},
                            {"text": "(leave it)", "next": None},
                        ],
                    }
                },
            }
        ],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    doc = json.loads(ACTORS.read_text(encoding="utf-8"))
    topics = json.loads(TOPICS.read_text(encoding="utf-8"))

    existing = doc.get("actors", [])
    by_id = {a["id"]: a for a in existing}
    hand_written = {a["id"] for a in existing if not a.get("_generated")}

    spec_npcs = spec.get("npcs", {})
    missing = [n for n in spec_npcs if n not in by_id]
    regen = [a["id"] for a in existing if a.get("_generated")]

    # Sources in the matrix that are not people at all.
    non_actor = set(spec.get("other_sources", {}))
    all_sources: set[str] = set()
    for topic in topics.get("topics", {}).values():
        all_sources.update(topic.get("stances", {}))
    places = {s for s in all_sources
              if s not in spec_npcs and s not in non_actor}

    if args.check:
        if missing:
            print(f"actors.json missing {len(missing)} NPC(s): "
                  f"{', '.join(sorted(missing))}", file=sys.stderr)
            print("Run: python games/slack_tide/tools/gen_actors.py",
                  file=sys.stderr)
            return 1
        print(f"actors.json complete ({len(existing)} actors)")
        return 0

    rebuilt = []
    for a in existing:
        if a.get("_generated") and a["id"] in spec_npcs:
            rebuilt.append(build_actor(a["id"], spec_npcs[a["id"]], topics))
        else:
            rebuilt.append(a)          # hand-authored: untouched
    for npc_id in missing:
        rebuilt.append(build_actor(npc_id, spec_npcs[npc_id], topics))

    doc["actors"] = rebuilt
    ACTORS.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")

    print(f"actors.json: {len(hand_written)} hand-authored preserved, "
          f"{len(regen)} regenerated, {len(missing)} added "
          f"-> {len(rebuilt)} total")
    if missing:
        print("  added: " + ", ".join(sorted(missing)))
    print(f"  non-actor sources (objects/places/archetypes, not invented): "
          f"{len(non_actor | places)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
