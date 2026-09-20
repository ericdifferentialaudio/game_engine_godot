"""Engine-agnostic checks for knowledge-gated dialogue.

Shared by every game package under `games/`. Nothing in this module knows
about Slack Tide, or tides, or any particular token id — it only knows the
*shapes* the platform defines:

  * a dialogue interaction is `{start, nodes: {knot: {text, next, choices}}}`
  * a choice routes via `next`, or via `next_pass`/`next_fail` when it carries
    a `check`
  * a `check` / `requires` names knowledge the journal must hold

Dialogue can be perfectly valid JSON and still be broken *content*: a choice
routing to a knot nobody wrote, a check against a token that does not exist,
an NPC placed in a location that is not a map. Those are the bugs this finds,
and they are the same bugs in every game.

Used by `core/tools/validate_narrative.py`. A game adds its own rules on top
by importing `Findings` and appending to it.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Findings:
    """Collected problems. `errors` should fail a build; `warnings` should not."""
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def err(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def ok(self) -> bool:
        return not self.errors

    def report(self, summary: str = "") -> int:
        """Print findings; return a process exit code."""
        import sys
        for w in self.warnings:
            print(f"WARN  {w}")
        for e in self.errors:
            print(f"ERROR {e}", file=sys.stderr)
        if summary:
            print(f"\n{summary}")
        print(f"{len(self.errors)} errors, {len(self.warnings)} warnings")
        return 1 if self.errors else 0


def load_json(path: Path, required: bool = True) -> dict:
    """Read a package JSON file. Missing optional files yield {}."""
    if not path.exists():
        if required:
            raise FileNotFoundError(path)
        return {}
    # Some tools emit a BOM; json.loads will not accept one.
    return json.loads(path.read_text(encoding="utf-8-sig"))


# --- Reference collection -----------------------------------------------------

## Keys whose string value names a piece of knowledge.
KNOWLEDGE_KEYS = ("has", "token", "knows", "requires_intel")

## Keys whose value is a list of knowledge ids.
KNOWLEDGE_LISTS = ("debunk", "grant_intel", "requires_all", "requires_any")


def collect_knowledge_refs(node: object, out: set[str]) -> None:
    """Every knowledge id mentioned anywhere in a nested structure.

    Deliberately permissive about shape, because authored data is lenient:
    `grant_intel` may hold bare strings or `{token, reliability}` dicts.
    """
    if isinstance(node, dict):
        for key, val in node.items():
            if key in KNOWLEDGE_KEYS and isinstance(val, str):
                out.add(val)
            elif key in KNOWLEDGE_LISTS and isinstance(val, list):
                for entry in val:
                    if isinstance(entry, str):
                        out.add(entry)
                    elif isinstance(entry, dict) and "token" in entry:
                        out.add(str(entry["token"]))
            else:
                collect_knowledge_refs(val, out)
    elif isinstance(node, list):
        for item in node:
            collect_knowledge_refs(item, out)


def choice_targets(node: dict) -> list[str]:
    """Every knot this node can route to, by any mechanism."""
    targets: list[str] = []
    if node.get("next"):
        targets.append(str(node["next"]))
    for choice in node.get("choices", []) or []:
        for key in ("next", "next_pass", "next_fail"):
            if choice.get(key):
                targets.append(str(choice[key]))
    return targets


# --- The checks ---------------------------------------------------------------

def check_dialogue_graph(speaker: str, interaction: dict, f: Findings) -> None:
    """Every route lands on a knot that exists; report unreachable knots.

    Unreachable is a WARNING, not an error: a knot may be legitimately staged
    for content not yet wired up. A dangling route is an ERROR, because it is
    a guaranteed dead end at runtime.
    """
    nodes = interaction.get("nodes", {}) or {}
    knots = set(nodes)
    start = interaction.get("start")

    if start not in knots:
        f.err(f"{speaker}: start knot '{start}' does not exist")
        return

    reachable: set[str] = set()
    frontier = [start]
    while frontier:
        current = frontier.pop()
        if current in reachable:
            continue
        reachable.add(current)
        for target in choice_targets(nodes.get(current, {})):
            if target not in knots:
                f.err(f"{speaker}.{current}: routes to missing knot '{target}'")
            else:
                frontier.append(target)

    for orphan in sorted(knots - reachable):
        f.warn(f"{speaker}: knot '{orphan}' is unreachable")


def check_knowledge_refs(speaker: str, interaction: dict,
                         known_ids: set[str], f: Findings,
                         extra_valid: set[str] | None = None) -> None:
    """Every knowledge id referenced in dialogue must actually be defined.

    `extra_valid` lets a game accept non-token identifiers in the same slots
    (Slack Tide passes its conflict-group names, for instance).
    """
    refs: set[str] = set()
    collect_knowledge_refs(interaction.get("nodes", {}), refs)
    valid = known_ids | (extra_valid or set())
    for ref in sorted(refs):
        if ref not in valid:
            f.err(f"{speaker}: references unknown knowledge '{ref}'")


def check_actor_placement(actors: list[dict], place_ids: set[str],
                          f: Findings) -> None:
    """An actor's location must be a real place."""
    for actor in actors:
        location = actor.get("location")
        if location and location not in place_ids:
            f.err(f"actor {actor.get('id')}: "
                  f"location '{location}' is not a known place")


def check_place_links(places: list[dict], f: Findings,
                      id_key: str = "id", links_key: str = "links") -> None:
    """Every link points at a place that exists."""
    place_ids = {p[id_key] for p in places if id_key in p}
    for place in places:
        for link in place.get(links_key, []) or []:
            target = link.get("to") if isinstance(link, dict) else link
            if target and target not in place_ids:
                f.err(f"place {place.get(id_key)}: "
                      f"link to missing place '{target}'")


## Keys whose value is a CoreIntelQuery object rather than a plain id.
QUERY_KEYS = ("requires", "check", "condition", "unlocked_by")


def _walk_queries(node: object, ctx: str, f: Findings, tokens: set[str]) -> None:
    """Validate every CoreIntelQuery found anywhere in a nested structure."""
    from . import intel_query

    if isinstance(node, dict):
        for key, val in node.items():
            if key in QUERY_KEYS and isinstance(val, dict):
                intel_query.validate_query(val, f"{ctx}.{key}", f, tokens)
            else:
                _walk_queries(val, ctx, f, tokens)
    elif isinstance(node, list):
        for item in node:
            _walk_queries(item, ctx, f, tokens)


def check_queries(speaker: str, interaction: dict, known_ids: set[str],
                  f: Findings, extra_valid: set[str] | None = None) -> None:
    """Every embedded query is well-formed and names tokens that exist."""
    tokens: set[str] = set()
    _walk_queries(interaction.get("nodes", {}), speaker, f, tokens)
    valid = known_ids | (extra_valid or set())
    for token in sorted(tokens):
        if token not in valid:
            f.err(f"{speaker}: query references unknown token '{token}'")


def check_package(actors: list[dict], known_ids: set[str],
                  place_ids: set[str], f: Findings,
                  extra_valid: set[str] | None = None) -> None:
    """Run every generic dialogue check over a package's actors."""
    for actor in actors:
        speaker = str(actor.get("id", "?"))
        for interaction in actor.get("interactions", []) or []:
            if interaction.get("kind") != "dialogue":
                continue
            check_dialogue_graph(speaker, interaction, f)
            check_knowledge_refs(speaker, interaction, known_ids, f, extra_valid)
            check_queries(speaker, interaction, known_ids, f, extra_valid)
    check_actor_placement(actors, place_ids, f)
