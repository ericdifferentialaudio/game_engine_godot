"""Inspect a compiled .ink.json — engine-agnostic, game-agnostic.

`CoreInkValidator` (GDScript) does the deep work: static structure plus
context simulation, inside Godot. This is the cheap Python counterpart for
build scripts and CI, answering two questions without starting an engine:

  * which EXTERNAL functions does this story actually call, and are they all
    bound by `CoreInkBindings`? An unbound EXTERNAL is a guaranteed runtime
    failure the moment that line is reached.
  * which knowledge ids does it reference, and do they all exist in the
    package's intel? A typo'd token id is a gate no player can ever satisfy.

Both are the same checks for every game, which is why they live here.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

## inklecate embeds external calls as {"x()": "name"} in the compiled JSON.
_EXTERNAL_CALL = re.compile(r'"x\(\)":"(\w+)"')

## String literals appear as "^text". Token ids are a subset of these.
_STRING_LITERAL = re.compile(r'"\^([A-Za-z][\w.]*)"')

## CoreInkBindings names each bound function `_ink_<name>`.
_BINDING = re.compile(r"func\s+_ink_(\w+)\s*\(")


def read_compiled(path: Path) -> str:
    """inklecate writes a UTF-8 BOM; json.loads will not accept one."""
    return path.read_text(encoding="utf-8-sig")


def externals_called(compiled_source: str) -> set[str]:
    """Every EXTERNAL function the compiled story invokes."""
    return set(_EXTERNAL_CALL.findall(compiled_source))


def string_literals(compiled_source: str) -> set[str]:
    """Every bare string literal in the story — a superset of token ids."""
    return set(_STRING_LITERAL.findall(compiled_source))


def bound_functions(bindings_gd: Path) -> set[str]:
    """Function names `CoreInkBindings` can bind, read from the source."""
    return set(_BINDING.findall(bindings_gd.read_text(encoding="utf-8")))


def unbound_externals(compiled_source: str, bindings_gd: Path) -> set[str]:
    """EXTERNALs the story calls that nothing will bind. Always an error."""
    return externals_called(compiled_source) - bound_functions(bindings_gd)


def referenced_ids(compiled_source: str, known_ids: set[str]) -> set[str]:
    """String literals that match a known knowledge id.

    Intersecting with the real id set is what keeps this game-agnostic: no
    prefix conventions, no per-game regex, just "which of these strings is
    actually a token this package defines".
    """
    return string_literals(compiled_source) & known_ids


def story_ink_version(compiled_source: str) -> int:
    return int(json.loads(compiled_source).get("inkVersion", 0))


def describe(path: Path, bindings_gd: Path | None = None,
             known_ids: set[str] | None = None) -> dict:
    """Everything the build scripts want to know about one compiled story."""
    source = read_compiled(path)
    out: dict = {
        "name": path.name,
        "ink_version": story_ink_version(source),
        "externals": sorted(externals_called(source)),
    }
    if bindings_gd and bindings_gd.exists():
        out["unbound"] = sorted(unbound_externals(source, bindings_gd))
    if known_ids is not None:
        out["tokens"] = sorted(referenced_ids(source, known_ids))
    return out
