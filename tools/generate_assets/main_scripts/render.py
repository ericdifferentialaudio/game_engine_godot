"""
scripts/render.py

Plain-Python wrapper around the Blender batch-render pipeline. Run this with
a normal `python` interpreter — it locates Blender itself and re-invokes it
with the right `--background --python render_cli.py --` incantation, so you
don't have to type the full Blender path/flags every time.

Usage (identical flags to utils/render_cli.py — everything is forwarded
as-is). Run from inside scripts/ itself (cd there first -- see
scripts/README.md's top-level note):

    python render.py --category clans --clan fighter --unit-type common
    python render.py --category clans --clan fighter --unit-type common --execute
    python render.py --category clans --clan fighter --unit-type common --execute --force
    python render.py --category dragons --color red --stage adult
    python render.py --category monsters --tier t1
    python render.py --category npc --name shopkeep_1

(Or from the repo root: python assets/graphics/scripts/render.py ...;
or from assets/graphics/: python scripts/render.py ...)

Safe by default: no `--execute` means plan-only, nothing rendered (see
render_cli.py's docstring / scripts/README.md for the full plan-output
format and what RENDER / SKIP / NO-MESH mean).

Blender discovery order:
    1. `--blender <path>` explicit override on this wrapper's own command line
    2. `AEVUM_BLENDER` environment variable, if set
    3. `blender`/`blender.exe` already on PATH (shutil.which)
    4. Well-known Windows install locations under
       "C:\\Program Files\\Blender Foundation\\Blender <version>\\blender.exe"
       (highest version number wins if more than one is installed)

If none of those find a Blender executable, this prints a clear error
explaining how to point it at one instead of failing with a cryptic
FileNotFoundError from subprocess.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent            # scripts/main_scripts/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                         # scripts/
_RENDER_CLI = _SCRIPTS_DIR / "utils" / "render_cli.py"

_WELL_KNOWN_WINDOWS_ROOTS = [
    Path(r"C:\Program Files\Blender Foundation"),
    Path(r"C:\Program Files (x86)\Blender Foundation"),
]


def _candidate_versions(root: Path) -> list[Path]:
    """Find blender.exe under Blender Foundation-style version subfolders,
    sorted so the highest version number is tried first."""
    if not root.is_dir():
        return []
    candidates = []
    for child in root.iterdir():
        exe = child / "blender.exe"
        if exe.is_file():
            m = re.search(r"(\d+(?:\.\d+)*)", child.name)
            version = tuple(int(x) for x in m.group(1).split(".")) if m else (0,)
            candidates.append((version, exe))
    candidates.sort(key=lambda t: t[0], reverse=True)
    return [exe for _, exe in candidates]


def find_blender(explicit: str | None = None) -> Path:
    if explicit:
        p = Path(explicit)
        if p.is_file():
            return p
        raise FileNotFoundError(f"--blender path does not exist: {explicit}")

    env_path = os.environ.get("AEVUM_BLENDER")
    if env_path:
        p = Path(env_path)
        if p.is_file():
            return p
        print(f"WARNING: AEVUM_BLENDER is set to '{env_path}' but that file "
              f"doesn't exist - falling back to auto-discovery.", file=sys.stderr)

    on_path = shutil.which("blender") or shutil.which("blender.exe")
    if on_path:
        return Path(on_path)

    for root in _WELL_KNOWN_WINDOWS_ROOTS:
        found = _candidate_versions(root)
        if found:
            return found[0]

    raise FileNotFoundError(
        "Could not find a Blender executable. Fix this by either:\n"
        "  - passing --blender \"C:\\path\\to\\blender.exe\" to this script, or\n"
        "  - setting the AEVUM_BLENDER environment variable to that path, or\n"
        "  - adding blender.exe's folder to your PATH."
    )


# Blender's own startup/shutdown boilerplate — not our script's output, adds
# no information for the user, filtered out of the streamed output below.
# Matched by exact-equality after stripping whitespace, so this can't
# accidentally eat a real render_cli.py line.
_BLENDER_NOISE_LINES = {
    "Blender quit",
}


def _is_blender_noise(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return False
    if stripped in _BLENDER_NOISE_LINES:
        return True
    # Version/build banner, e.g. "Blender 5.2.1 LTS (hash 9e2066aef7ef built ...)"
    if re.match(r"^Blender \d+(\.\d+)* .*\(hash .* built .*\)$", stripped):
        return True
    return False


def _run_filtered(cmd: list[str]) -> int:
    """
    Run `cmd`, streaming its combined stdout/stderr live (so output still
    appears incrementally, not buffered until the process exits), dropping
    lines that are Blender's own startup/shutdown boilerplate rather than
    anything render_cli.py printed. Returns the subprocess's exit code.

    Explicitly decodes the child's output as UTF-8 (rather than relying on
    `text=True`'s locale-default decoding, which on Windows is typically
    cp1252 and mangles any non-ASCII character render_cli.py prints into
    garbled multi-byte sequences). PYTHONIOENCODING=utf-8 is also set on the
    child's environment so Blender's embedded Python *writes* UTF-8 in the
    first place, regardless of the host console's active code page.
    """
    child_env = os.environ.copy()
    child_env["PYTHONIOENCODING"] = "utf-8"

    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        encoding="utf-8", errors="replace", bufsize=1,
        env=child_env,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        if not _is_blender_noise(line):
            print(line, end="", flush=True)
    proc.wait()
    return proc.returncode


def main() -> int:
    # This wrapper only needs to intercept --blender; everything else is
    # forwarded verbatim to render_cli.py's own argparse inside Blender.
    parser = argparse.ArgumentParser(
        add_help=False,  # let render_cli.py's --help (via -h passthrough) work instead
        description="Wrapper: finds Blender and runs render_cli.py inside it. "
                    "All other flags are forwarded as-is — see render_cli.py --help.",
    )
    parser.add_argument("--blender", default=None,
                         help="Explicit path to blender.exe, overriding auto-discovery.")
    known, forwarded = parser.parse_known_args()

    try:
        blender_exe = find_blender(known.blender)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    cmd = [
        str(blender_exe),
        "--background",
        "--python", str(_RENDER_CLI),
        "--",
        *forwarded,
    ]

    print(f"[render.py] using Blender: {blender_exe}", flush=True)
    return _run_filtered(cmd)


if __name__ == "__main__":
    sys.exit(main())
