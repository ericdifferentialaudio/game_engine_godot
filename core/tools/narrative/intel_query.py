"""Offline validation of CoreIntelQuery objects — one grammar, both engines.

`core/addons/game_core/gameplay/core_intel_query.gd` is the authority. It is
side-effect free precisely so that offline validators can check the same
shapes, and this module is that check.

Why this exists: the two engine layers each grew their own copy of this
grammar in `tools/validate_data.py`, and both drifted from core in *different
directions*. The isometric copy invented `era`, `turn` and `faction_flag`
(none of which core evaluates, so a query using them silently fails at
runtime); the FPS copy knew only 8 of core's 19 keys, so it rejected valid
authored data. A package accepted by one engine could be rejected by the
other, which defeats the point of a shared data contract.

KEYS below is kept in lockstep with `CoreIntelQuery.KEYS`, and
`check_keys_match_core()` proves it rather than trusting a comment.
"""
from __future__ import annotations

import re
from pathlib import Path

## Must mirror CoreIntelQuery.KEYS exactly. Verified by check_keys_match_core().
KEYS = {
    "has", "subject", "tag", "scope", "category", "fact", "provenance",
    "source", "contradicted", "flag", "holder_flag", "resource", "time", "era",
    "owns_site", "unit_count", "stance", "all", "any", "not",
}

## Keys whose value is a plain token id.
TOKEN_KEYS = {"has", "contradicted"}

## Keys counting tokens by attribute; all accept `count` and `min_reliability`.
COUNTING_KEYS = {"subject", "tag", "scope", "category"}

## Keys whose value is a fixed-length list, mapped to that length.
TUPLE_KEYS = {
    "fact": 3,          # [token_id, key, value]
    "provenance": 2,    # [token_id, channel]
    "source": 2,        # [token_id, source_id]
    "resource": 3,      # [resource_id, op, amount]
    "time": 2,          # [op, value]
    "unit_count": 3,    # [unit_def_id, op, amount]
    "stance": 2,        # [faction_id, stance]
}

## Tuple keys whose first element is a token id.
TUPLE_TOKEN_KEYS = {"fact", "provenance", "source"}

## Comparison operators CoreDataLoader.compare() accepts.
COMPARE_OPS = {">=", ">", "<=", "<", "==", "=", "!="}

## Position of the operator within each comparison tuple.
COMPARE_OP_INDEX = {"resource": 1, "time": 0, "unit_count": 1}

COMBINATORS = {"all", "any", "not"}

## Legacy spellings from the isometric engine's older `IntelQuery`, now
## resolved by `CoreIntelQuery.ALIASES` so both evaluators accept either form.
## Authored data (19 occurrences of `faction_flag` across aevum, paragon and
## example_realm_iso) therefore keeps working unchanged, in either engine.
##
## These are ACCEPTED, not errors. They are reported only by
## `deprecated_keys_in()`, which callers may surface as a style note to steer
## new content toward the canonical spelling. See docs/CORE_REQUESTS.md CR-001.
ALIASES = {
    "faction_flag": "holder_flag",
    "turn": "time",
}


def core_keys(repo_root: Path) -> set[str]:
    """Read CoreIntelQuery.KEYS straight from the GDScript source."""
    gd = repo_root / "core/addons/game_core/gameplay/core_intel_query.gd"
    block = gd.read_text(encoding="utf-8").split("const KEYS")[1].split("]")[0]
    return set(re.findall(r'"(\w+)"', block))


def core_aliases(repo_root: Path) -> dict[str, str]:
    """Read CoreIntelQuery.ALIASES straight from the GDScript source."""
    gd = repo_root / "core/addons/game_core/gameplay/core_intel_query.gd"
    src = gd.read_text(encoding="utf-8")
    if "const ALIASES" not in src:
        return {}
    block = src.split("const ALIASES")[1].split("}")[0]
    return dict(re.findall(r'"(\w+)"\s*:\s*"(\w+)"', block))


def check_keys_match_core(repo_root: Path) -> list[str]:
    """Fail loudly if this module and core have drifted apart."""
    actual = core_keys(repo_root)
    problems = []
    for missing in sorted(actual - KEYS):
        problems.append(
            f"intel_query.py is missing key '{missing}' that CoreIntelQuery "
            f"supports - authored data using it would be wrongly rejected")
    for extra in sorted(KEYS - actual):
        problems.append(
            f"intel_query.py accepts key '{extra}' that CoreIntelQuery does "
            f"not evaluate - such a query would silently fail at runtime")

    # Aliases must match too, or a legacy spelling accepted here would be
    # rejected at runtime, or vice versa.
    actual_aliases = core_aliases(repo_root)
    if actual_aliases != ALIASES:
        for legacy in sorted(set(actual_aliases) - set(ALIASES)):
            problems.append(
                f"intel_query.py is missing alias "
                f"'{legacy}' -> '{actual_aliases[legacy]}' from CoreIntelQuery")
        for legacy in sorted(set(ALIASES) - set(actual_aliases)):
            problems.append(
                f"intel_query.py accepts alias '{legacy}' that CoreIntelQuery "
                f"does not resolve")
        for legacy in sorted(set(ALIASES) & set(actual_aliases)):
            if ALIASES[legacy] != actual_aliases[legacy]:
                problems.append(
                    f"alias '{legacy}' maps to '{ALIASES[legacy]}' here but "
                    f"'{actual_aliases[legacy]}' in CoreIntelQuery")
    return problems


def deprecated_keys_in(node: object) -> list[tuple[str, str]]:
    """Every legacy spelling used anywhere in a nested structure.

    Returns (legacy, canonical) pairs. These still work; this is for reporting
    a migration backlog, not for failing a build.
    """
    found: list[tuple[str, str]] = []
    if isinstance(node, dict):
        for key, val in node.items():
            if key in ALIASES:
                found.append((key, ALIASES[key]))
            found.extend(deprecated_keys_in(val))
    elif isinstance(node, list):
        for item in node:
            found.extend(deprecated_keys_in(item))
    return found


def _num_in_range(val, lo: float, hi: float) -> bool:
    try:
        return lo <= float(val) <= hi
    except (TypeError, ValueError):
        return False


def validate_query(query, ctx: str, f, tokens: set[str],
                   flags: set[str] | None = None) -> None:
    """Check one query object; record every token id it references.

    `f` is a `dialogue_graph.Findings`. Token ids are collected into `tokens`
    rather than checked here, so the caller can resolve them against whatever
    it considers the set of known tokens.
    """
    if not isinstance(query, dict):
        f.err(f"{ctx}: query must be an object")
        return
    if not query:
        return  # an empty query is legal and means "always true"

    # Resolve legacy spellings to their canonical key before checking, so
    # `faction_flag` validates exactly as `holder_flag` does.
    present = {ALIASES.get(k, k) for k in query} & KEYS
    if len(present) != 1:
        f.err(f"{ctx}: query needs exactly one of {sorted(KEYS)}, "
              f"got {sorted(query)}")
        return

    key = present.pop()
    val = query[key] if key in query else next(
        query[legacy] for legacy, canon in ALIASES.items()
        if canon == key and legacy in query)

    # --- combinators ------------------------------------------------------
    if key in ("all", "any"):
        if not isinstance(val, list):
            f.err(f"{ctx}: '{key}' must be a list of queries")
            return
        for i, sub in enumerate(val):
            validate_query(sub, f"{ctx}.{key}[{i}]", f, tokens, flags)
        return
    if key == "not":
        validate_query(val, f"{ctx}.not", f, tokens, flags)
        return

    # --- leaves -----------------------------------------------------------
    if key in TOKEN_KEYS:
        if not isinstance(val, str):
            f.err(f"{ctx}: '{key}' must be a token id")
        else:
            tokens.add(val)

    if key in COUNTING_KEYS and int(query.get("count", 1)) < 1:
        f.err(f"{ctx}: count must be >= 1")

    if "min_reliability" in query and not _num_in_range(
            query["min_reliability"], 0.0, 1.0):
        f.err(f"{ctx}: min_reliability must be between 0 and 1")

    if key == "flag" or key == "holder_flag":
        if not isinstance(val, str):
            f.err(f"{ctx}: '{key}' must be a flag name")
        elif flags is not None:
            flags.add(val)

    if key in TUPLE_KEYS:
        want = TUPLE_KEYS[key]
        if not isinstance(val, list) or len(val) != want:
            f.err(f"{ctx}: '{key}' must be a list of {want} elements")
            return
        if key in TUPLE_TOKEN_KEYS and isinstance(val[0], str):
            tokens.add(val[0])
        if key in COMPARE_OP_INDEX:
            op = val[COMPARE_OP_INDEX[key]]
            if op not in COMPARE_OPS:
                f.err(f"{ctx}: '{op}' is not a comparison operator "
                      f"{sorted(COMPARE_OPS)}")
