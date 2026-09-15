#!/usr/bin/env python3
"""Parse Godot/GUT test output into structured regression records.

`run_tests.ps1` prints a great deal of Godot output and then throws it away,
leaving only an exit code. That makes two questions impossible to answer after
the fact, and they are the only two that matter when a suite goes red:

    1. Is this failure NEW, or has it been failing for a while?
    2. Is it a REGRESSION, or a FLAKE that passes on the next run?

So we parse the output into one JSON record per test, append it to a JSONL file
keyed by run id, and maintain an append-only SQLite history that lets the
`regression-analyst` subagent classify every failure without ever reading a
raw Godot log.

Usage:
    python tools/regression_hook.py --log build.log --suite core
    ./tools/run_tests.ps1 | python tools/regression_hook.py --suite all
    python tools/regression_hook.py --report
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import subprocess
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "tools" / "regressions"
DB_PATH = OUT_DIR / "history.sqlite"

# GUT prints a line per test and a summary block. These cover 4.x / GUT 9.x.
RE_SCRIPT = re.compile(r"^\s*[-*]?\s*(res://[\w/\.]+\.gd)")
RE_TEST = re.compile(r"^\s*[*-]\s*(test_\w+)")
RE_FAIL = re.compile(r"\[FAILED\]|^\s*\[Failed\]|failed:", re.IGNORECASE)
RE_PENDING = re.compile(r"\[PENDING\]", re.IGNORECASE)
# Runtime harness lines: "  PASS  thing" / "  FAIL  thing"
RE_HARNESS = re.compile(r"^\s*(PASS|FAIL|ok|FAILED)\s+[-:]?\s*(.+?)\s*$")


def strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)


def git_sha() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=ROOT, capture_output=True, text=True, timeout=10,
        )
        return out.stdout.strip() or "unknown"
    except Exception:
        return "unknown"


def ensure_db() -> sqlite3.Connection:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """CREATE TABLE IF NOT EXISTS results (
            run_id TEXT, ts REAL, git_sha TEXT, suite TEXT, game TEXT,
            engine TEXT, script TEXT, test TEXT, status TEXT,
            message TEXT, seed TEXT
        )"""
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_test ON results(test, script)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_run ON results(run_id)")
    conn.commit()
    return conn


def parse(text: str, suite: str, game: str = "", engine: str = "", seed: str = "") -> list[dict]:
    """Turn raw Godot/GUT output into one record per test."""
    text = strip_ansi(text)
    records: list[dict] = []
    script = ""
    state = {"current": "", "buffer": []}

    def flush() -> None:
        current = state["current"]
        buffer = state["buffer"]
        state["current"] = ""
        state["buffer"] = []
        if not current:
            return
        blob = "\n".join(buffer)
        if RE_FAIL.search(blob):
            status = "fail"
        elif RE_PENDING.search(blob):
            status = "pending"
        else:
            status = "pass"
        msg = ""
        for line in buffer:
            s = line.strip()
            if s and (RE_FAIL.search(s) or s.startswith("Expected")):
                msg = s[:500]
                break
        records.append({
            "suite": suite, "game": game, "engine": engine, "seed": seed,
            "script": script, "test": current, "status": status, "message": msg,
        })

    for raw in text.splitlines():
        line = raw.rstrip()
        m_script = RE_SCRIPT.match(line)
        if m_script:
            flush()
            script = m_script.group(1)
            continue
        m_test = RE_TEST.match(line)
        if m_test:
            flush()
            state["current"] = m_test.group(1)
            continue
        if state["current"]:
            state["buffer"].append(line)
            continue
        # Harness-style lines outside GUT (smoke / boot-check / playtest).
        m_h = RE_HARNESS.match(line)
        if m_h and suite:
            verdict, name = m_h.group(1).lower(), m_h.group(2)
            if len(name) > 3 and not name.startswith("="):
                records.append({
                    "suite": suite, "game": game, "engine": engine, "seed": seed,
                    "script": script or suite, "test": name[:200],
                    "status": "pass" if verdict in ("pass", "ok") else "fail",
                    "message": "" if verdict in ("pass", "ok") else name[:500],
                })
    flush()
    return records


def classify(conn: sqlite3.Connection, rec: dict, run_id: str) -> str:
    """NEW | REGRESSION | FLAKE | KNOWN for a failing test."""
    rows = conn.execute(
        "SELECT status FROM results WHERE test=? AND script=? AND run_id!=? "
        "ORDER BY ts DESC LIMIT 10",
        (rec["test"], rec["script"], run_id),
    ).fetchall()
    if not rows:
        return "NEW"
    history = [r[0] for r in rows]
    if all(h == "fail" for h in history):
        return "KNOWN"
    if history[0] == "pass":
        return "REGRESSION"
    if "pass" in history and "fail" in history:
        return "FLAKE"
    return "REGRESSION"


def write_run(records: list[dict], suite: str) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    run_id = time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6]
    sha = git_sha()
    ts = time.time()
    conn = ensure_db()

    for r in records:
        r["run_id"] = run_id
        r["ts"] = ts
        r["git_sha"] = sha
        if r["status"] == "fail":
            r["classification"] = classify(conn, r, run_id)

    conn.executemany(
        "INSERT INTO results (run_id, ts, git_sha, suite, game, engine, script, "
        "test, status, message, seed) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        [(r["run_id"], r["ts"], r["git_sha"], r["suite"], r.get("game", ""),
          r.get("engine", ""), r["script"], r["test"], r["status"],
          r.get("message", ""), r.get("seed", "")) for r in records],
    )
    conn.commit()
    conn.close()

    path = OUT_DIR / f"{run_id}.jsonl"
    with path.open("w", encoding="utf-8") as fh:
        for r in records:
            fh.write(json.dumps(r) + "\n")

    failures = [r for r in records if r["status"] == "fail"]
    summary = {
        "run_id": run_id, "git_sha": sha, "suite": suite,
        "total": len(records),
        "passed": sum(1 for r in records if r["status"] == "pass"),
        "failed": len(failures),
        "by_classification": {
            c: sum(1 for r in failures if r.get("classification") == c)
            for c in ("NEW", "REGRESSION", "FLAKE", "KNOWN")
        },
        "failures": failures[:50],
        "jsonl": str(path.relative_to(ROOT)),
    }
    (OUT_DIR / "latest.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return path


def report() -> int:
    latest = OUT_DIR / "latest.json"
    if not latest.exists():
        print("no regression runs recorded yet")
        return 0
    data = json.loads(latest.read_text(encoding="utf-8"))
    print(f"run {data['run_id']}  sha {data['git_sha']}  suite {data['suite']}")
    print(f"  {data['passed']}/{data['total']} passed, {data['failed']} failed")
    for cls, n in data["by_classification"].items():
        if n:
            print(f"  {cls:<12} {n}")
    for f in data["failures"]:
        print(f"  [{f.get('classification', '?')}] {f['script']}::{f['test']}")
        if f.get("message"):
            print(f"      {f['message'][:160]}")
    return 1 if data["failed"] else 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--log", help="file to parse; omit to read stdin")
    ap.add_argument("--suite", default="all")
    ap.add_argument("--game", default="")
    ap.add_argument("--engine", default="")
    ap.add_argument("--seed", default="")
    ap.add_argument("--report", action="store_true", help="summarise the last run")
    args = ap.parse_args(argv)

    if args.report:
        return report()

    if args.log:
        text = Path(args.log).read_text(encoding="utf-8", errors="replace")
    else:
        text = sys.stdin.read()

    records = parse(text, args.suite, args.game, args.engine, args.seed)
    if not records:
        print("regression_hook: no test records found in input", file=sys.stderr)
        return 0
    path = write_run(records, args.suite)
    failed = sum(1 for r in records if r["status"] == "fail")
    print(f"regression_hook: {len(records)} records ({failed} failed) -> {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
