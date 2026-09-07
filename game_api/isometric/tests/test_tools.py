"""Tests for new_game.py scaffolding, gen_placeholders.py and asset_manifest.py."""
from __future__ import annotations

import json
import shutil
import sys
import unittest
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import asset_manifest  # noqa: E402
import gen_placeholders  # noqa: E402
import new_game  # noqa: E402
import validate_data as vd  # noqa: E402


class NewGameTests(unittest.TestCase):
    def setUp(self):
        self.game_id = "zz_test_" + uuid.uuid4().hex[:8]
        self.pkg = ROOT / "games" / self.game_id

    def tearDown(self):
        shutil.rmtree(self.pkg, ignore_errors=True)

    def test_scaffold_validates_clean(self):
        for topo, turns in (("hex", "sequential"), ("square_iso", "realtime_pause")):
            shutil.rmtree(self.pkg, ignore_errors=True)
            new_game.scaffold(self.game_id, "Test", topo, turns)
            for name in vd.DATA_FILES:
                self.assertTrue((self.pkg / f"{name}.json").exists(), name)
            rep = vd.validate_package(self.pkg)
            self.assertEqual(rep.errors, [], f"{topo}/{turns}: {rep.errors}")
            game = json.loads((self.pkg / "game.json").read_text(encoding="utf-8"))
            self.assertEqual(game["grid"]["topology"], topo)
            self.assertEqual(game["turns"]["mode"], turns)

    def test_rejects_bad_id(self):
        with self.assertRaises(SystemExit):
            new_game.scaffold("Bad-Id", "x")

    def test_rejects_existing(self):
        new_game.scaffold(self.game_id, "x")
        with self.assertRaises(SystemExit):
            new_game.scaffold(self.game_id, "x")


class PlaceholderTests(unittest.TestCase):
    def test_png_writer_produces_valid_header(self):
        import tempfile
        p = Path(tempfile.mkdtemp()) / "t.png"
        gen_placeholders.circle_png(p, 8, (255, 0, 0))
        data = p.read_bytes()
        self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"))
        self.assertIn(b"IHDR", data)
        self.assertIn(b"IEND", data)
        shutil.rmtree(p.parent, ignore_errors=True)

    def test_hex_polygon_has_six_points_inside_bounds(self):
        poly = gen_placeholders.hex_poly(64, 56, True)
        self.assertEqual(len(poly), 6)
        for x, y in poly:
            self.assertTrue(0 <= x <= 64 and 0 <= y <= 56)


class AssetManifestTests(unittest.TestCase):
    def test_reference_audit_runs(self):
        rep = asset_manifest.audit("example_realm_iso")
        self.assertEqual(rep["bad_type"], [])
        self.assertEqual(rep["unmanifested_data_keys"], [])
        # Shaders and placeholder scene must resolve.
        self.assertIn("shader.fog", rep["present"])
        self.assertIn("site.generic", rep["present"])


if __name__ == "__main__":
    unittest.main()
