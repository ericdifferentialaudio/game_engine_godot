"""Tests for tools/validate_data.py and the reference package."""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import validate_data as vd  # noqa: E402

REFERENCE = ROOT / "games" / "example_realm_iso"


class QueryGrammarTests(unittest.TestCase):
    def _run(self, q):
        rep, refs = vd.Report(), vd.Refs()
        vd.collect_query_refs(q, "q", rep, refs)
        return rep, refs

    def test_has_collects_token(self):
        rep, refs = self._run({"has": "tok", "min_reliability": 0.5})
        self.assertTrue(rep.ok)
        self.assertIn("tok", refs.req_tokens)

    def test_min_reliability_out_of_range(self):
        rep, _ = self._run({"has": "tok", "min_reliability": 1.5})
        self.assertFalse(rep.ok)

    def test_nested_all_any_not(self):
        rep, refs = self._run({"all": [{"any": [{"has": "a"}, {"tag": "t"}]}, {"not": {"flag": "f"}}]})
        self.assertTrue(rep.ok)
        self.assertEqual(refs.req_tokens, {"a"})
        self.assertEqual(refs.flags, {"f"})

    def test_multiple_keys_rejected(self):
        rep, _ = self._run({"has": "a", "tag": "b"})
        self.assertFalse(rep.ok)

    def test_new_predicates(self):
        for q in ({"provenance": ["a", "told"]}, {"source": ["a", "npc"]}, {"contradicted": "a"},
                  {"resource": ["gold", ">=", 10]}, {"turn": [">", 3]}, {"era": "x"},
                  {"owns_site": "s"}, {"unit_count": ["scout", ">=", 1]}, {"stance": ["f", "war"]},
                  {"scope": "site", "count": 2}, {"category": "military"}):
            rep, _ = self._run(q)
            self.assertTrue(rep.ok, f"{q}: {rep.errors}")

    def test_bad_channel_and_ops(self):
        self.assertFalse(self._run({"provenance": ["a", "gossip"]})[0].ok)
        self.assertFalse(self._run({"resource": ["gold", "~", 1]})[0].ok)
        self.assertFalse(self._run({"stance": ["f", "besties"]})[0].ok)


class ReferencePackageTests(unittest.TestCase):
    def test_reference_package_is_clean(self):
        rep = vd.validate_package(REFERENCE)
        self.assertEqual(rep.errors, [])
        self.assertEqual(rep.warnings, [])

    def test_all_data_files_present(self):
        for name in vd.DATA_FILES:
            self.assertTrue((REFERENCE / f"{name}.json").exists(), name)


class MutationTests(unittest.TestCase):
    """Copy the reference package, break one thing, expect one specific error."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.pkg = self.tmp / "mut"
        shutil.copytree(REFERENCE, self.pkg)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _edit(self, name, fn):
        p = self.pkg / f"{name}.json"
        doc = json.loads(p.read_text(encoding="utf-8"))
        fn(doc)
        p.write_text(json.dumps(doc), encoding="utf-8")

    def _errors(self):
        return vd.validate_package(self.pkg).errors

    def test_unknown_intel_token(self):
        self._edit("sites", lambda d: d["sites"][1]["interactions"][0]["tokens"].append("nope"))
        self.assertTrue(any("nope" in e for e in self._errors()))

    def test_map_cycle(self):
        self._edit("maps", lambda d: d["maps"][0].__setitem__("parent", "sunken_crypt_2"))
        self.assertTrue(any("cycle" in e or "root map" in e for e in self._errors()))

    def test_depth_limit(self):
        self._edit("game", lambda d: d.__setitem__("max_map_depth", 1))
        self.assertTrue(any("exceeds max_map_depth" in e for e in self._errors()))

    def test_unknown_glyph(self):
        self._edit("maps", lambda d: d["maps"][1]["layout"].__setitem__(1, "#..X.#....#"))
        self.assertTrue(any("glyph 'X'" in e for e in self._errors()))

    def test_unknown_unit_reference(self):
        self._edit("factions", lambda d: d["factions"][0]["starting_units"].append("dragon"))
        self.assertTrue(any("unit 'dragon'" in e for e in self._errors()))

    def test_unknown_item_reference(self):
        self._edit("units", lambda d: d["units"][4]["loot"].append({"item": "unicorn_horn"}))
        self.assertTrue(any("item 'unicorn_horn'" in e for e in self._errors()))

    def test_bad_topology_and_turn_mode(self):
        self._edit("game", lambda d: d["grid"].__setitem__("topology", "octagon"))
        self._edit("game", lambda d: d["turns"].__setitem__("mode", "chaos"))
        errs = self._errors()
        self.assertTrue(any("topology" in e for e in errs))
        self.assertTrue(any("turns.mode" in e for e in errs))

    def test_portal_to_unknown_map(self):
        self._edit("sites", lambda d: d["sites"][4]["interactions"][0].__setitem__("target_map", "atlantis"))
        self.assertTrue(any("atlantis" in e for e in self._errors()))

    def test_bad_spread_filter(self):
        self._edit("intel_rules", lambda d: d["spread"][0].__setitem__("between", "frenemies"))
        self.assertTrue(any("frenemies" in e for e in self._errors()))

    def test_missing_optional_files_ok(self):
        (self.pkg / "intel_rules.json").unlink()
        (self.pkg / "ai_profiles.json").unlink()
        rep = vd.validate_package(self.pkg)
        self.assertFalse(any("missing file" in e for e in rep.errors))


if __name__ == "__main__":
    unittest.main()
