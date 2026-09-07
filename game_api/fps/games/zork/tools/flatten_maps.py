"""One-off: Zork rooms form a graph, not a tree, so every room is a root map."""
import json
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "maps.json"
data = json.loads(p.read_text(encoding="utf-8"))
n = 0
for m in data["maps"]:
    if "parent" in m:
        del m["parent"]
        n += 1
p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"removed {n} parent links")
