#!/usr/bin/env python3
"""Copy C4's approved v2 export exactly; no drawing or layout generation."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "回执/第1轮/设计/村外铺景/v2"
GODOT = ROOT / "godot"
CONTRACT = SOURCE / "C2精确导入-v2.json"
REPORT = ROOT / "回执/第1轮/C2-C4村外v2导入核对.json"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_text())


def encode(data):
    return (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode()


def main():
    contract = read_json(CONTRACT)
    village_path = GODOT / "ayu_home/v4/assets/village.json"
    index_path = GODOT / "ayu_home/v4/assets/rooms.json"
    before = read_json(village_path)
    index = read_json(index_path)
    assert index["rooms"]["village"] == before, "Room index diverged before import"
    assets = [contract["ground"]] + contract["copy_assets"]
    pending = []
    for asset in assets:
        source = (SOURCE / asset["source"]).resolve()
        target = (GODOT / asset["target"].removeprefix("res://")).resolve()
        assert source.is_relative_to(SOURCE) and target.is_relative_to(GODOT)
        data = source.read_bytes()
        assert digest(data) == asset["sha256"], f"Changed source: {source}"
        assert data[:8] == b"\x89PNG\r\n\x1a\n"
        assert list(struct.unpack(">II", data[16:24])) == asset["size"]
        assert data[25] == (2 if asset is assets[0] else 6), "Expected opaque RGB ground / RGBA prop"
        pending.append((source, target, asset["sha256"]))

    prefixes = tuple(contract["remove_props_prefixes"])
    retained = [p for p in before["props"] if not p["id"].startswith(prefixes)]
    assert sorted(p["id"] for p in retained) == sorted(contract["preserve_prop_ids"])
    already_imported = before["background"] == contract["ground"]["target"]
    old_roots = contract["exact_new_root_rects"] if already_imported else contract["remove_old_root_rects"]
    assert before["landscape_obstacles"] == old_roots, "Unexpected landscape collision baseline"
    solids = deepcopy(before["obstacles"])
    for rect in old_roots:
        assert solids.count(rect) == 1, f"Missing or duplicate old root: {rect}"
        solids.remove(rect)
    new_props = contract["exact_new_props"]
    assert len({p["id"] for p in new_props}) == len(new_props) == 23
    assert {p["file"] for p in new_props} == {a["target"] for a in contract["copy_assets"]}

    after = deepcopy(before)
    after["background"] = contract["ground"]["target"]
    after["props"] = retained + deepcopy(new_props)
    after["obstacles"] = solids + deepcopy(contract["exact_new_root_rects"])
    after["landscape_obstacles"] = deepcopy(contract["exact_new_root_rects"])
    changed = [k for k in before if before[k] != after[k]]
    assert set(changed) <= {"background", "props", "obstacles", "landscape_obstacles"}
    after_index = deepcopy(index)
    after_index["rooms"]["village"] = after

    for source, target, expected in pending:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert digest(target.read_bytes()) == expected
    village_before_sha = digest(village_path.read_bytes())
    village_path.write_bytes(encode(after))
    index_path.write_bytes(encode(after_index))
    report = {
        "scope": "Mechanical C4 import only; headless and C3 acceptance recorded separately",
        "contract_sha256": digest(CONTRACT.read_bytes()),
        "village_before_sha256": village_before_sha,
        "village_after_sha256": digest(village_path.read_bytes()),
        "already_imported": already_imported,
        "changed_fields": changed,
        "preserved_prop_ids": [p["id"] for p in retained],
        "preserved_base_solid_count": len(solids),
        "removed_prop_ids": [p["id"] for p in before["props"] if p["id"].startswith(prefixes)],
        "new_prop_count": len(new_props),
        "new_root_count": len(contract["exact_new_root_rects"]),
        "all_other_village_fields_unchanged": True,
        "all_other_room_records_unchanged": True,
        "assets": [{"file": str(t.relative_to(GODOT)), "sha256": h} for _, t, h in pending],
    }
    if not already_imported or not REPORT.exists():
        REPORT.write_bytes(encode(report))
    print(f"C4 IMPORT PASS: {len(assets)} exact PNG copies; {len(retained)} original props + {len(new_props)} C4 props; {len(solids)} base solids + {len(contract['exact_new_root_rects'])} new roots")


if __name__ == "__main__":
    main()
