#!/usr/bin/env python3
"""Generate blockout .tscn files for the Zork package (props + room maps).

Rooms are simple box interiors / fenced outdoor plots with a MapRoot script.
Props are coloured primitives so every POI/portal is visible and readable
before real art exists. Re-run after editing the tables below:

    python games/zork/tools/gen_scenes.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

ZORK = Path(__file__).resolve().parents[1]
PROPS = ZORK / "props"
MAPS = ZORK / "maps"
MAP_ROOT = "res://framework/map/map_root.gd"

# name -> list of (mesh, params, rgb, y_offset, emissive)
# mesh: box (sx,sy,sz) | cyl (r, h) | sphere (r,)
PROPS_DEF = {
    "prop_none": [],
    "prop_note": [("box", (0.35, 0.45, 0.02), (0.92, 0.88, 0.7), 0.0, 0.15)],
    "prop_mailbox": [("cyl", (0.06, 1.0), (0.3, 0.3, 0.3), 0.5, 0), ("box", (0.35, 0.3, 0.6), (0.2, 0.25, 0.6), 1.15, 0.1)],
    "prop_door_boarded": [("box", (1.1, 2.2, 0.15), (0.35, 0.22, 0.12), 1.1, 0), ("box", (1.3, 0.15, 0.2), (0.5, 0.35, 0.2), 1.5, 0), ("box", (1.3, 0.15, 0.2), (0.5, 0.35, 0.2), 0.8, 0)],
    "prop_sack": [("box", (0.5, 0.3, 0.25), (0.45, 0.3, 0.15), 0.15, 0)],
    "prop_bottle": [("cyl", (0.06, 0.3), (0.5, 0.8, 0.9), 0.15, 0.2)],
    "prop_rope": [("cyl", (0.35, 0.15), (0.6, 0.5, 0.3), 0.08, 0)],
    "prop_knife": [("box", (0.05, 0.02, 0.4), (0.7, 0.7, 0.75), 0.02, 0.2)],
    "prop_rug": [("box", (4.0, 0.03, 3.0), (0.55, 0.15, 0.15), 0.015, 0)],
    "prop_trophy_case": [("box", (0.6, 1.2, 1.6), (0.3, 0.2, 0.1), 0.6, 0), ("box", (0.05, 0.9, 1.4), (0.6, 0.8, 0.9), 0.75, 0.3)],
    "prop_lantern": [("cyl", (0.1, 0.3), (0.8, 0.65, 0.2), 0.15, 0.5)],
    "prop_sword": [("box", (0.06, 0.06, 1.1), (0.55, 0.7, 1.0), 0.0, 0.6)],
    "prop_nest": [("cyl", (0.3, 0.15), (0.4, 0.3, 0.15), 0.07, 0), ("sphere", (0.14,), (0.9, 0.75, 0.2), 0.25, 0.5)],
    "prop_leaves": [("cyl", (1.2, 0.25), (0.5, 0.35, 0.1), 0.12, 0)],
    "prop_flagstone": [("box", (0.8, 0.08, 0.8), (0.35, 0.35, 0.33), 0.04, 0)],
    "prop_skeleton": [("box", (0.5, 0.35, 1.6), (0.85, 0.82, 0.7), 0.17, 0), ("sphere", (0.18,), (0.85, 0.82, 0.7), 0.4, 0)],
    "prop_painting": [("box", (1.2, 0.9, 0.05), (0.6, 0.45, 0.15), 0.0, 0), ("box", (1.0, 0.7, 0.06), (0.2, 0.35, 0.6), 0.0, 0.35)],
    "prop_loot": [("box", (0.5, 0.3, 0.5), (0.9, 0.75, 0.2), 0.15, 0.4)],
    "actor_troll": [("box", (1.0, 2.2, 0.7), (0.35, 0.45, 0.25), 1.1, 0), ("sphere", (0.4,), (0.4, 0.5, 0.3), 2.5, 0), ("box", (0.15, 1.2, 0.15), (0.6, 0.15, 0.1), 1.3, 0.2)],
    "actor_thief": [("box", (0.55, 1.6, 0.4), (0.15, 0.15, 0.2), 0.8, 0), ("sphere", (0.22,), (0.85, 0.7, 0.6), 1.8, 0), ("box", (0.5, 0.5, 0.4), (0.4, 0.3, 0.15), 1.0, 0)],
    "portal_path": [("box", (1.4, 0.05, 1.4), (0.75, 0.65, 0.4), 0.02, 0.3), ("cyl", (0.05, 1.5), (0.5, 0.35, 0.2), 0.75, 0), ("box", (0.7, 0.25, 0.05), (0.9, 0.85, 0.6), 1.4, 0.4)],
    "portal_doorway": [("box", (0.25, 2.6, 0.25), (0.35, 0.3, 0.28), 1.3, 0), ("box", (1.9, 0.25, 0.25), (0.35, 0.3, 0.28), 2.6, 0), ("box", (1.4, 2.4, 0.05), (0.02, 0.02, 0.04), 1.2, 0)],
    "portal_window": [("box", (0.12, 1.0, 1.0), (0.5, 0.35, 0.2), 1.3, 0), ("box", (0.05, 0.85, 0.85), (0.6, 0.75, 0.9), 1.3, 0.4)],
    "portal_stairs": [("box", (1.2, 0.2, 0.4), (0.4, 0.3, 0.2), 0.1, 0), ("box", (1.2, 0.2, 0.4), (0.4, 0.3, 0.2), 0.3, 0), ("box", (1.2, 0.2, 0.4), (0.4, 0.3, 0.2), 0.5, 0), ("box", (1.2, 0.2, 0.4), (0.4, 0.3, 0.2), 0.7, 0)],
    "portal_trapdoor": [("box", (1.2, 0.06, 1.2), (0.3, 0.2, 0.1), 0.03, 0), ("box", (1.0, 0.02, 1.0), (0.0, 0.0, 0.0), 0.07, 0)],
    "portal_tree": [("cyl", (0.6, 4.0), (0.35, 0.22, 0.1), 2.0, 0), ("sphere", (2.2,), (0.15, 0.4, 0.15), 4.5, 0), ("box", (1.6, 0.15, 0.3), (0.35, 0.22, 0.1), 1.4, 0)],
}

# Rooms: id -> size=(w, d), kind=interior|outdoor|forest|tree, colours, height, optional house/table
ROOMS = {
    "west_of_house":  dict(size=(24, 20), kind="outdoor", floor=(0.35, 0.5, 0.25), house=(14, 0, 0, 12, 4.5, 20)),
    "north_of_house": dict(size=(22, 20), kind="outdoor", floor=(0.35, 0.5, 0.25), house=(0, 0, 9, 20, 4.5, 12)),
    "south_of_house": dict(size=(22, 20), kind="outdoor", floor=(0.35, 0.5, 0.25), house=(0, 0, -9, 20, 4.5, 12)),
    "behind_house":   dict(size=(22, 22), kind="outdoor", floor=(0.35, 0.5, 0.25), house=(-14, 0, 0, 12, 4.5, 20)),
    "kitchen":        dict(size=(11, 11), kind="interior", wall=(0.6, 0.55, 0.45), floor=(0.4, 0.3, 0.2), height=3.2, table=(0, 0, 0)),
    "attic":          dict(size=(9, 9), kind="interior", wall=(0.35, 0.3, 0.25), floor=(0.3, 0.25, 0.2), height=2.6, table=(-2.5, 0, -2)),
    "living_room":    dict(size=(13, 11), kind="interior", wall=(0.5, 0.4, 0.3), floor=(0.35, 0.25, 0.18), height=3.4),
    "forest_path":    dict(size=(22, 22), kind="forest", floor=(0.25, 0.4, 0.2)),
    "up_a_tree":      dict(size=(6, 8), kind="tree", floor=(0.3, 0.2, 0.1)),
    "clearing":       dict(size=(18, 18), kind="forest", floor=(0.3, 0.45, 0.22)),
    "cellar":         dict(size=(13, 15), kind="interior", wall=(0.25, 0.25, 0.28), floor=(0.2, 0.2, 0.22), height=3.0),
    "troll_room":     dict(size=(15, 15), kind="interior", wall=(0.28, 0.24, 0.22), floor=(0.22, 0.18, 0.16), height=3.6),
    "ew_passage":     dict(size=(15, 6), kind="interior", wall=(0.25, 0.25, 0.28), floor=(0.2, 0.2, 0.22), height=2.8),
    "round_room":     dict(size=(15, 15), kind="interior", wall=(0.3, 0.3, 0.32), floor=(0.25, 0.25, 0.27), height=4.0),
    "gallery":        dict(size=(13, 15), kind="interior", wall=(0.45, 0.35, 0.3), floor=(0.3, 0.22, 0.18), height=4.0),
}


def color(c, a=1.0):
    return f"Color({c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f}, {a})"


def xf(pos, rot_y_deg=0.0):
    c = math.cos(math.radians(rot_y_deg))
    s = math.sin(math.radians(rot_y_deg))
    return f"Transform3D({c:.4f}, 0, {s:.4f}, 0, 1, 0, {-s:.4f}, 0, {c:.4f}, {pos[0]}, {pos[1]}, {pos[2]})"


class Scene:
    def __init__(self, root_name, script=None):
        self.ext = []
        self.sub = []
        self.nodes = []
        self.root_name = root_name
        self.script = script
        self._sid = 0

    def sub_resource(self, kind, **props):
        self._sid += 1
        sid = f"s{self._sid}"
        body = "\n".join(f"{k} = {v}" for k, v in props.items())
        self.sub.append(f'[sub_resource type="{kind}" id="{sid}"]\n{body}\n')
        return sid

    def material(self, rgb, emissive=0.0):
        props = {"albedo_color": color(rgb)}
        if emissive:
            props.update(emission_enabled="true", emission=color(rgb), emission_energy_multiplier=str(emissive))
        return self.sub_resource("StandardMaterial3D", **props)

    def mesh(self, kind, params, mat):
        m = f'SubResource("{mat}")'
        if kind == "box":
            return self.sub_resource("BoxMesh", size=f"Vector3({params[0]}, {params[1]}, {params[2]})", material=m)
        if kind == "cyl":
            return self.sub_resource("CylinderMesh", top_radius=str(params[0]), bottom_radius=str(params[0]), height=str(params[1]), material=m)
        if kind == "sphere":
            return self.sub_resource("SphereMesh", radius=str(params[0]), height=str(params[0] * 2), material=m)
        raise ValueError(kind)

    def node(self, name, ntype, parent=".", transform=None, **props):
        lines = [f'[node name="{name}" type="{ntype}" parent="{parent}"]']
        if transform:
            lines.append(f"transform = {transform}")
        for k, v in props.items():
            lines.append(f"{k} = {v}")
        self.nodes.append("\n".join(lines) + "\n")

    def mesh_node(self, name, kind, params, rgb, pos, emissive=0.0, parent="."):
        m = self.mesh(kind, params, self.material(rgb, emissive))
        self.node(name, "MeshInstance3D", parent, xf(pos), mesh=f'SubResource("{m}")')

    def static_box(self, name, size, pos, rgb):
        """StaticBody3D on the World layer with a box collider and a matching mesh."""
        self.node(name, "StaticBody3D", ".", xf(pos), collision_layer="1", collision_mask="0")
        shape = self.sub_resource("BoxShape3D", size=f"Vector3({size[0]}, {size[1]}, {size[2]})")
        self.node("Shape", "CollisionShape3D", name, shape=f'SubResource("{shape}")')
        m = self.mesh("box", size, self.material(rgb))
        self.node("Mesh", "MeshInstance3D", name, mesh=f'SubResource("{m}")')

    def render(self):
        steps = len(self.ext) + len(self.sub) + 1
        out = [f"[gd_scene load_steps={steps} format=3]\n"]
        out += [e + "\n" for e in self.ext]
        out += self.sub
        root = [f'[node name="{self.root_name}" type="Node3D"]']
        if self.script:
            root.append(f'script = ExtResource("{self.script}")')
        out.append("\n".join(root) + "\n")
        out += self.nodes
        return "\n".join(out)


def gen_prop(name, parts):
    sc = Scene(name.replace("_", " ").title().replace(" ", ""))
    for i, (kind, params, rgb, y, em) in enumerate(parts):
        sc.mesh_node(f"Part{i}", kind, params, rgb, (0, y, 0), em)
    if any(p[4] for p in parts):
        sc.node("Glow", "OmniLight3D", ".", xf((0, 1.2, 0)), light_color=color(parts[0][2]), light_energy="0.6", omni_range="3.0")
    (PROPS / f"{name}.tscn").write_text(sc.render(), encoding="utf-8")



def gen_room(rid, spec):
    w, d = spec["size"]
    kind = spec["kind"]
    sc = Scene(rid.title().replace("_", ""), script="1_root")
    sc.ext.append(f'[ext_resource type="Script" path="{MAP_ROOT}" id="1_root"]')
    sc.static_box("Floor", (w, 0.5, d), (0, -0.25, 0), spec["floor"])
    if kind == "interior":
        h = spec["height"]
        wall = spec["wall"]
        t = 0.4
        sc.static_box("WallN", (w + 2 * t, h, t), (0, h / 2, -d / 2 - t / 2), wall)
        sc.static_box("WallS", (w + 2 * t, h, t), (0, h / 2, d / 2 + t / 2), wall)
        sc.static_box("WallE", (t, h, d), (w / 2 + t / 2, h / 2, 0), wall)
        sc.static_box("WallW", (t, h, d), (-w / 2 - t / 2, h / 2, 0), wall)
        sc.static_box("Ceiling", (w + 2 * t, t, d + 2 * t), (0, h + t / 2, 0), tuple(x * 0.7 for x in wall))
        if "table" in spec:
            tx, _, tz = spec["table"]
            sc.static_box("Table", (2.2, 0.1, 1.2), (tx, 0.85, tz), (0.45, 0.3, 0.15))
            sc.static_box("TableLegs", (1.8, 0.8, 0.8), (tx, 0.4, tz), (0.4, 0.27, 0.13))
        sc.node("Lamp", "OmniLight3D", ".", xf((0, h - 0.4, 0)), light_color="Color(1, 0.85, 0.6, 1)",
                light_energy="1.6", omni_range=str(max(w, d) * 0.9), shadow_enabled="true")
        sc.node("Lamp2", "OmniLight3D", ".", xf((w * 0.3, 1.5, d * 0.3)), light_color="Color(1, 0.8, 0.55, 1)",
                light_energy="0.7", omni_range=str(max(w, d) * 0.6))
    else:
        edge = (0.3, 0.25, 0.15)
        sc.static_box("BoundN", (w + 1, 1.2, 0.5), (0, 0.6, -d / 2 - 0.25), edge)
        sc.static_box("BoundS", (w + 1, 1.2, 0.5), (0, 0.6, d / 2 + 0.25), edge)
        sc.static_box("BoundE", (0.5, 1.2, d + 1), (w / 2 + 0.25, 0.6, 0), edge)
        sc.static_box("BoundW", (0.5, 1.2, d + 1), (-w / 2 - 0.25, 0.6, 0), edge)
        sc.node("Sun", "DirectionalLight3D", ".",
                "Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, -0.5, -0.612, 0.612, 0, 20, 0)",
                light_energy="1.1", shadow_enabled="true")
        house = spec.get("house")
        if house:
            hx, _, hz, hw, hh, hd = house
            sc.static_box("House", (hw, hh, hd), (hx, hh / 2, hz), (0.92, 0.92, 0.88))
            sc.static_box("Roof", (hw + 1, 0.6, hd + 1), (hx, hh + 0.3, hz), (0.4, 0.2, 0.15))
        if kind in ("forest", "outdoor"):
            rnd = random.Random(sum(ord(c) for c in rid))
            for i in range(14 if kind == "forest" else 6):
                tx = tz = 0.0
                for _ in range(30):
                    tx = rnd.uniform(-w / 2 + 1.5, w / 2 - 1.5)
                    tz = rnd.uniform(-d / 2 + 1.5, d / 2 - 1.5)
                    if house and abs(tx - house[0]) < house[3] / 2 + 2.5 and abs(tz - house[2]) < house[5] / 2 + 2.5:
                        continue
                    if abs(tx) < 3.5 and abs(tz) < 3.5:
                        continue
                    if max(abs(tx), abs(tz)) > min(w, d) / 2 - 2.5:
                        break  # near the edge: fine
                    break
                sc.static_box(f"Trunk{i}", (0.7, 5.0, 0.7), (tx, 2.5, tz), (0.35, 0.22, 0.1))
                sc.mesh_node(f"Canopy{i}", "sphere", (2.4,), (0.12, 0.35 + rnd.uniform(0, 0.15), 0.12), (tx, 5.6, tz))
        if kind == "tree":
            sc.static_box("Trunk", (1.2, 8, 1.2), (0, -4, -4.5), (0.35, 0.22, 0.1))
            sc.mesh_node("Canopy", "sphere", (5.0,), (0.12, 0.4, 0.12), (0, 5, -2))
    sc.node("POIs", "Node3D", ".")
    sc.node("Portals", "Node3D", ".")
    sc.node("Actors", "Node3D", ".")
    (MAPS / f"{rid}.tscn").write_text(sc.render(), encoding="utf-8")


def main():
    PROPS.mkdir(exist_ok=True)
    MAPS.mkdir(exist_ok=True)
    for name, parts in PROPS_DEF.items():
        gen_prop(name, parts)
    for rid, spec in ROOMS.items():
        gen_room(rid, spec)
    print(f"generated {len(PROPS_DEF)} props, {len(ROOMS)} rooms")


if __name__ == "__main__":
    main()

