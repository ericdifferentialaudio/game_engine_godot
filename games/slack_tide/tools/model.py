#!/usr/bin/env python3
"""Pure-Python paper model of a Slack Tide run.

Why this exists: tuning in Godot costs a process spawn per episode. This model
runs ten thousand seeds in seconds, so the balance questions ("does a competent
player win 80% of the time? is a naive one under 35%?") get answered offline
and for free. Godot then only has to CONFIRM the numbers, not discover them.

It reads `docs/slack_tide_spec.json` -- the same source of truth the engine
data is generated from -- so it cannot silently drift from the real game.

Deliberately NOT modelled: prose, scene layout, Ink. Those do not move the
balance. What IS modelled: the six-slot clock, the wage/board/tip/parcel
economy, Slack inflation, token acquisition and reliability (including
corroboration and hearsay decay), the three roads, the four entry methods,
values and gifts, and the ending selector.

    python model.py --seeds 2000 --policy competent
"""
from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass, field
from pathlib import Path

SPEC = Path(__file__).resolve().parent.parent / "docs" / "slack_tide_spec.json"

SLOTS = ["dawn_crossing", "morning", "midday_crossing",
         "afternoon", "dusk_crossing", "night"]
CROSSINGS = {"dawn_crossing", "midday_crossing", "dusk_crossing"}

# Minutes of real play per slot, measured against the design's 60-90 min target
# for a ~14 day run. A crossing is a scene; a land slot is a conversation.
MINUTES_PER_CROSSING = 0.75
MINUTES_PER_LAND_SLOT = 0.55


def load_spec(path: Path = SPEC) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


@dataclass
class Run:
    """One simulated playthrough."""
    seed: int
    culprit: str
    policy: str
    day: int = 1
    slot: int = 0
    tallies: int = 3
    tokens: dict = field(default_factory=dict)   # id -> reliability 0..100
    sources: dict = field(default_factory=dict)  # id -> set of source ids
    values: dict = field(default_factory=dict)
    items: set = field(default_factory=set)
    gifts: set = field(default_factory=set)
    sold: dict = field(default_factory=dict)
    flags: set = field(default_factory=set)
    minutes: float = 0.0
    events: list = field(default_factory=list)
    outcome: str = "unresolved"
    won: bool = False
    understood: bool = False
    road: str = ""


class Model:
    def __init__(self, spec: dict, tuning: dict | None = None):
        self.spec = spec
        self.tokens = {t["id"]: t for t in spec["tokens"]}
        self.items = spec["items"]
        self.gifts = spec["gifts"]
        self.roads = spec["roads"]
        self.entries = spec["entry_methods"]
        self.method_rel = spec["method_reliability"]
        self.rumor_cap = spec["rumor_cap"]
        self.income = spec["income_model"]
        self.value_names = list(spec["values"].keys())
        self.value_start = spec["value_start"]
        self.value_cap = spec["value_cap"]
        t = tuning or {}
        self.full_slack_low = t.get("full_slack_low", 12)
        self.full_slack_high = t.get("full_slack_high", 14)
        self.learn_per_slot = t.get("learn_per_slot", 1.15)
        self.corroborate_chance = t.get("corroborate_chance", 0.45)
        self.decay_below = t.get("decay_below", 50)
        self.decay_per_day = t.get("decay_per_day", 5)
        self.decay_floor = t.get("decay_floor", 10)
        self.inflation_from = t.get("inflation_from_day", 6)
        self.inflation_per_day = t.get("inflation_per_day", 0.04)
        self.inflation_cap = t.get("inflation_cap", 0.60)
        self.value_gain_per_day = t.get("value_gain_per_day", 1.35)

    # --- economy ---------------------------------------------------------

    def price_multiplier(self, day: int) -> float:
        if day < self.inflation_from:
            return 1.0
        over = day - self.inflation_from + 1
        return 1.0 + min(over * self.inflation_per_day, self.inflation_cap)

    def price(self, item: str, day: int) -> int:
        base = self.items.get(item, {}).get("price", 0)
        import math
        return int(math.ceil(base * self.price_multiplier(day)))

    # --- knowledge -------------------------------------------------------

    def is_true(self, tid: str, culprit: str) -> bool:
        truth = self.tokens[tid].get("truth", "always")
        if truth == "always":
            return True
        if truth.startswith("culprit="):
            return truth[8:] == culprit
        if truth.startswith("culprit!="):
            return truth[9:] != culprit
        return True

    def learn(self, run: Run, tid: str, source: str, method: str) -> None:
        """Acquire or corroborate a token. Mirrors the engine's rules."""
        base = self.method_rel.get(method, 30)
        if method == "overheard":
            base = min(base, self.rumor_cap)
        seen = run.sources.setdefault(tid, set())
        if tid in run.tokens and source not in seen:
            # Independent second source: +20, cap 95.
            run.tokens[tid] = min(95, run.tokens[tid] + 20)
        else:
            run.tokens[tid] = max(run.tokens.get(tid, 0), base)
        seen.add(source)

    def decay(self, run: Run) -> None:
        for tid, rel in list(run.tokens.items()):
            if len(run.sources.get(tid, ())) > 1:
                continue  # corroborated tokens are exempt
            if self.decay_floor < rel < self.decay_below:
                run.tokens[tid] = max(self.decay_floor, rel - self.decay_per_day)

    def reliable(self, run: Run, tid: str, floor: int) -> bool:
        return run.tokens.get(tid, 0) >= floor

    # --- policies --------------------------------------------------------
    # A policy is a competence level, not a script. It decides how well the
    # player targets the tokens that actually matter, how much they earn, and
    # whether they chase corroboration or trust the first thing they hear.

    POLICIES = {
        # Plays well: targets case tokens, corroborates, saves, buys a road.
        "competent": dict(focus=0.82, earn=1.0, corroborate=1.0,
                          sell=0.25, value_focus=0.85),
        # Plays badly: believes rumour mills, sells everything, drifts.
        "naive": dict(focus=0.34, earn=0.72, corroborate=0.35,
                      sell=0.85, value_focus=0.30),
        # Money first, truth later. Rich but wrong.
        "greedy": dict(focus=0.50, earn=1.30, corroborate=0.55,
                       sell=1.00, value_focus=0.40),
        # Never sells, never lies. Poor but righteous.
        "honest": dict(focus=0.74, earn=0.80, corroborate=0.95,
                       sell=0.00, value_focus=1.00),
    }

    def case_tokens(self, culprit: str) -> list[str]:
        """The tokens that matter for this seed's roads, cheapest road first."""
        out: list[str] = []
        for road in ("word", "bargain", "hand"):
            spec = self.roads[road].get(culprit)
            if spec:
                out.extend(spec.get("tokens", []))
        return list(dict.fromkeys(out))

    def needed_tokens(self, culprit: str) -> list[str]:
        """Everything a player actually has to know to finish: the road case
        tokens, plus a way in, plus passage, plus the Turning Words. A
        competent player targets this set; a naive one wanders the other 75."""
        out = list(self.case_tokens(culprit))
        for spec in self.entries.values():
            if culprit in spec.get("seeds", ""):
                out.extend(spec.get("tokens", []))
        out.extend(self.spec.get("passage", {}).get("tokens", []))
        out.extend(self.spec.get("common_turn", {}).get("tokens", []))
        for g in self.gifts.values():
            if g.get("hint"):
                out.append(g["hint"])
        return [t for t in dict.fromkeys(out) if t in self.tokens]

    def try_gifts(self, run: Run) -> None:
        """Seven NPCs give an item when conduct already matches them and the
        player has learned what they prize. Gifts cannot be farmed: by the time
        you know a gift exists, the conduct that earns it is mostly behind you."""
        for gid, g in self.gifts.items():
            if gid in run.gifts:
                continue
            hint = g.get("hint")
            if hint and run.tokens.get(hint, 0) < 40:
                continue
            if any(run.values.get(v, 0) < n
                   for v, n in (g.get("values") or {}).items()):
                continue
            flags = g.get("flags") or {}
            if "seals_broken" in flags and run.flags & {"seal_broken"}:
                continue
            if "left_honorably" in flags and "left_honorably" not in run.flags:
                continue
            run.gifts.add(gid)
            run.items.add(gid)
            run.events.append("gift:" + gid)

    def _plan_values(self, culprit: str, rng, p) -> list[str]:
        """Which values this run will actually cultivate. A player commits to a
        road early and behaves in a way that suits it -- plus the one entry
        method and the gifts that road needs. Eight values cannot all be raised
        (49 points would be needed; a run earns ~16-20), so choosing is the
        game. A naive player picks at random and arrives short of everything."""
        if rng.random() > p["value_focus"]:
            pool = list(self.value_names)
            rng.shuffle(pool)
            return pool[:3]
        road = ("word", "bargain", "hand")[rng.randrange(3)]
        spec = self.roads[road].get(culprit) or {}
        targets = list((spec.get("values") or {}).keys())
        for e in self.entries.values():
            if culprit in e.get("seeds", ""):
                targets.extend((e.get("values") or {}).keys())
        # Gifts that unlock this road's items_any are worth the conduct.
        wants = {g for grp in (spec.get("items_any") or []) for g in grp}
        wants |= set(spec.get("items") or [])
        for gid, g in self.gifts.items():
            if gid in wants:
                targets.extend((g.get("values") or {}).keys())
        return list(dict.fromkeys(targets)) or list(self.value_names)

    # --- simulation ------------------------------------------------------

    def run_one(self, seed: int, policy: str) -> Run:
        rng = random.Random(seed)
        culprit = "ABC"[rng.randrange(3)]
        full_slack = rng.randint(self.full_slack_low, self.full_slack_high)
        p = self.POLICIES[policy]
        run = Run(seed=seed, culprit=culprit, policy=policy)
        run.values = {v: self.value_start for v in self.value_names}

        wanted = self.needed_tokens(culprit)
        # Off-case tokens: the support/place/behaviour knowledge a run needs.
        other = [t for t in self.tokens if t not in wanted]
        run.flags.add("left_honorably")
        run._value_targets = self._plan_values(culprit, rng, p)

        for day in range(1, full_slack + 1):
            run.day = day
            for si, slot in enumerate(SLOTS):
                run.slot = si
                crossing = slot in CROSSINGS
                run.minutes += (MINUTES_PER_CROSSING if crossing
                                else MINUTES_PER_LAND_SLOT)
                self._slot_income(run, rng, p, crossing)
                self._slot_learn(run, rng, p, wanted, other, culprit)
            self._end_of_day(run, rng, p, full_slack)
            if run.outcome != "unresolved":
                break

        if run.outcome == "unresolved":
            self._resolve(run, rng, culprit)
        return run

    def _slot_income(self, run: Run, rng, p, crossing: bool) -> None:
        if crossing:
            lo, mid, hi = self.income["tips_per_crossing"]
            run.tallies += int(round(rng.triangular(lo, hi, mid) * p["earn"]))
            if rng.random() < 0.33 * p["earn"]:
                f_lo, f_mid, f_hi = self.income["parcel_fee"]
                run.tallies += int(round(rng.triangular(f_lo, f_hi, f_mid)))

    def _slot_learn(self, run: Run, rng, p, wanted, other, culprit) -> None:
        """Acquire knowledge. Focus decides case-relevance; corroborate
        decides whether a second independent source is sought."""
        if rng.random() > self.learn_per_slot / 2.0:
            return
        on_case = rng.random() < p["focus"]
        pool = wanted if (on_case and wanted) else other
        if not pool:
            return
        tid = pool[rng.randrange(len(pool))]
        tok = self.tokens[tid]

        # A false token is one whose truth disagrees with this seed. A focused
        # player checks sources; a naive one takes the rumour mill at face value.
        truthful = self.is_true(tid, culprit)
        srcs = tok.get("src") or []
        rumors = tok.get("rumor") or []
        use_real = truthful and srcs and rng.random() < (0.35 + 0.6 * p["focus"])

        if use_real:
            entry = srcs[rng.randrange(len(srcs))]
            source, _, method = entry.partition(":")
            self.learn(run, tid, source, method or "told")
            if rng.random() < self.corroborate_chance * p["corroborate"] and len(srcs) > 1:
                alt = srcs[rng.randrange(len(srcs))]
                s2, _, m2 = alt.partition(":")
                if s2 != source:
                    self.learn(run, tid, s2, m2 or "told")
        elif rumors:
            entry = rumors[rng.randrange(len(rumors))]
            source, _, method = entry.partition(":")
            self.learn(run, tid, source, method or "overheard")
            if not truthful:
                run.flags.add("holds_false:" + tid)

        # Selling: earns now, costs leverage and truth later (the Ledger).
        if rng.random() < p["sell"] * 0.18 and run.tokens.get(tid, 0) >= 40:
            run.sold[tid] = run.sold.get(tid, 0) + 1
            run.tallies += max(1, int(run.tokens[tid] / 12))
            run.events.append("sold:" + tid)

    def _end_of_day(self, run: Run, rng, p, full_slack: int) -> None:
        run.tallies += self.income["wage_per_day"] - self.income["board_per_day"]
        self.decay(run)
        # Conduct. A competent player behaves COHERENTLY -- they work toward the
        # handful of values their chosen road and gifts actually need, rather
        # than drifting across all eight. That coherence, not the raw number of
        # value events, is what separates a finished run from a near miss.
        budget = self.value_gain_per_day
        gained = int(budget) + (1 if rng.random() < budget % 1.0 else 0)
        targets = getattr(run, "_value_targets", None) or self.value_names
        for _ in range(gained):
            if rng.random() < p["value_focus"]:
                pool = [v for v in targets if run.values[v] < self.value_cap]
            else:
                pool = [v for v in self.value_names
                        if run.values[v] < self.value_cap]
            if pool:
                v = pool[rng.randrange(len(pool))]
                run.values[v] = min(self.value_cap, run.values[v] + 1)
        self.try_gifts(run)
        if run.day >= full_slack:
            run.flags.add("full_slack")

    # --- resolution ------------------------------------------------------

    def _afford(self, run: Run, items: list[str]) -> int:
        return sum(self.price(i, run.day) for i in items)

    def _road_ok(self, run: Run, road: str, culprit: str) -> tuple[bool, int]:
        """Can this road be walked? Returns (ok, tally cost)."""
        spec = self.roads[road].get(culprit)
        if not spec:
            return False, 0
        floor = spec.get("min_reliability", 75)
        for tid in spec.get("tokens", []):
            if not self.reliable(run, tid, floor):
                return False, 0
        for vname, need in (spec.get("values") or {}).items():
            if run.values.get(vname, 0) < need:
                return False, 0

        cost = 0
        for group in (spec.get("items") or []):
            cost += self.price(group, run.day)
        for group in (spec.get("items_any") or []):
            if any(g in run.gifts for g in group):
                continue
            cost += min(self.price(g, run.day) for g in group)
        for extra in (spec.get("extra_items") or []):
            cost += self.price(extra, run.day)
        if spec.get("armor"):
            cost += self.price("oiled_leather", run.day)
        return run.tallies >= cost, cost

    def _entry_ok(self, run: Run, culprit: str) -> bool:
        for name, spec in self.entries.items():
            if culprit not in spec.get("seeds", ""):
                continue
            if not all(self.reliable(run, t, 55) for t in spec.get("tokens", [])):
                continue
            if any(run.values.get(v, 0) < n
                   for v, n in (spec.get("values") or {}).items()):
                continue
            cost = spec.get("cost") or 0
            # A gift already held costs nothing; anything else must be bought.
            cost += self._afford(run, [i for i in (spec.get("items") or [])
                                       if i in self.items and i not in run.items])
            if any(i not in self.items and i not in run.items
                   for i in (spec.get("items") or [])):
                continue  # needs a gift this run never earned (e.g. the Seal)
            if run.tallies >= cost:
                return True
        return False

    def _resolve(self, run: Run, rng, culprit: str) -> None:
        """Pick the ending. Two axes: did the tide turn, and did you know why."""
        # Did the player actually understand the cause? That means holding the
        # seed-TRUE case tokens at a reliability they could act on.
        true_case = [t for t in self.case_tokens(culprit)
                     if self.is_true(t, culprit)]
        held = [t for t in true_case if self.reliable(run, t, 75)]
        run.understood = bool(true_case) and len(held) >= max(1, len(true_case) // 2)

        if not self._entry_ok(run, culprit):
            run.outcome = "full_slack_no_entry"
            run.won = False
            return

        for road in ("word", "bargain", "hand"):
            ok, cost = self._road_ok(run, road, culprit)
            if ok:
                run.road = road
                run.tallies -= cost
                run.won = True
                run.outcome = ("long_way_home" if run.understood
                               else "cold_answer")
                run.outcome += ":" + road
                return

        run.outcome = "standing_water" if run.understood else "full_slack"
        run.won = False


# --- the Reckoning ---------------------------------------------------------

def reckoning(model: Model, run: Run) -> dict:
    """End-of-run scorecard. Four axes that cannot all be maxed in one run:
    selling secrets earns Purse and costs Truth. That tension is the replay
    hook, and a far better tuning signal than a win/lose bit."""
    true_case = [t for t in model.case_tokens(run.culprit)
                 if model.is_true(t, run.culprit)]
    if true_case:
        truth = sum(min(100, run.tokens.get(t, 0)) for t in true_case) / len(true_case)
    else:
        truth = 0.0
    conduct = 100.0 * sum(run.values.values()) / (
        model.value_cap * max(1, len(run.values)))
    purse = min(100.0, run.tallies / 3.0)
    mercy = 100.0 * run.values.get("mercy", 0) / model.value_cap
    total = int(round(truth * 7 + conduct * 4 + purse * 2 + mercy * 2))
    if run.won:
        total += 400
    if run.understood:
        total += 250
    return {"truth": round(truth), "conduct": round(conduct),
            "purse": round(purse), "mercy": round(mercy), "total": total}


def sweep(model: Model, seeds: int, policy: str, start: int = 1) -> dict:
    runs = [model.run_one(s, policy) for s in range(start, start + seeds)]
    wins = sum(1 for r in runs if r.won)
    understood = sum(1 for r in runs if r.understood)
    outcomes: dict[str, int] = {}
    for r in runs:
        outcomes[r.outcome] = outcomes.get(r.outcome, 0) + 1
    scores = [reckoning(model, r)["total"] for r in runs]
    n = max(1, len(runs))
    top = max(outcomes.values()) / n if outcomes else 1.0
    return {
        "policy": policy,
        "episodes": len(runs),
        "win_rate": round(wins / n, 3),
        "understood_rate": round(understood / n, 3),
        "distinct_outcomes": len(outcomes),
        "top_outcome_share": round(top, 3),
        "avg_minutes": round(sum(r.minutes for r in runs) / n, 1),
        "avg_tallies": round(sum(r.tallies for r in runs) / n, 1),
        "avg_score": round(sum(scores) / n),
        "outcomes": dict(sorted(outcomes.items(), key=lambda kv: -kv[1])),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Slack Tide paper model")
    ap.add_argument("--seeds", type=int, default=2000)
    ap.add_argument("--policy", default="all")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    model = Model(load_spec())
    names = (list(Model.POLICIES) if args.policy == "all" else [args.policy])
    results = [sweep(model, args.seeds, p) for p in names]

    if args.json:
        print(json.dumps(results, indent=1))
        return 0

    print(f"Slack Tide model - {args.seeds} seeds\n")
    hdr = f"{'policy':<11}{'win':>7}{'under':>8}{'mins':>7}{'tally':>7}{'score':>7}{'ends':>6}{'top':>7}"
    print(hdr)
    print("-" * len(hdr))
    for r in results:
        print(f"{r['policy']:<11}{r['win_rate']:>7.3f}{r['understood_rate']:>8.3f}"
              f"{r['avg_minutes']:>7.1f}{r['avg_tallies']:>7.1f}"
              f"{r['avg_score']:>7}{r['distinct_outcomes']:>6}"
              f"{r['top_outcome_share']:>7.2f}")
    print()
    for r in results:
        print(f"  {r['policy']}: {r['outcomes']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
