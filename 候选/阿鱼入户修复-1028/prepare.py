"""Apply only the C1/C3-approved Ayu doorway candidate; never edit source art."""
import argparse
import copy
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OVERLAY = ROOT / "候选/整村95-G0-1026/overlay"
ASSETS = OVERLAY / "ayu_home/v4/assets"
QA = ROOT / "测试数据/本轮C2专用目录/1028阿鱼入户修复"
PROJECT = QA / "工程"
OLD = [1868, 2170, 764, 590]
APPROVED_SOLIDS = [[1868, 2170, 764, 438], [1868, 2608, 515, 60], [2453, 2608, 179, 60]]
# Live surface clipping grows solids by 3, then navigation samples another 8.
# Extend this doorway alone 4 upward so its approved inner goal remains reachable.
SOLIDS = [[1868, 2170, 764, 434], [1868, 2604, 515, 64], [2453, 2604, 179, 64]]
PATH = [[2418, 2689], [2352, 2712], [2280, 2752], [2200, 2776]]
WALK = [[2358, 2600], [2482, 2600], [2482, 2717], [2358, 2717]]


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    assert path.resolve().is_relative_to(OVERLAY.resolve()), path
    assert not path.is_symlink(), path
    temporary = path.with_suffix(path.suffix + ".ayu-tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def replace_solid(values):
    if OLD not in values:
        if all(s in values for s in APPROVED_SOLIDS):
            values = [s for s in values if s not in APPROVED_SOLIDS]
            values.extend(copy.deepcopy(SOLIDS))
        assert all(s in values for s in SOLIDS)
        return values
    result = []
    for value in values:
        result.extend(copy.deepcopy(SOLIDS) if value == OLD else [value])
    return result


def sync_project():
    assert PROJECT.resolve().is_relative_to(QA.resolve())
    for source in OVERLAY.rglob("*"):
        if source.is_file():
            if source.relative_to(OVERLAY).as_posix() in ["project.godot", "export_presets.cfg"]:
                continue
            target = PROJECT / source.relative_to(OVERLAY)
            assert target.resolve().is_relative_to(PROJECT.resolve()), target
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for name in ["project.godot", "export_presets.cfg"]:
        shutil.copy2(Path(__file__).parent / name, PROJECT / name)


def source():
    cfg = read(ASSETS / "village.json")
    door = next(d for d in cfg["doors"] if d["id"] == "visit_ayu")
    assert door["target"] == "exterior"
    door.update(pos=[2418, 2625], approach=[2424, 2616], arrival=[2418, 2689],
                span=[2418, 2625, 64], width=64)
    # Sorting pivot only: World compensates the sprite offset, preserving PNG position.
    next(p for p in cfg["props"] if p["id"] == "ayu")["foot"] = 2625
    cfg["obstacles"] = replace_solid(cfg["obstacles"])
    cfg["rebuild_navigation"] = True
    layout_path = ASSETS / "village/g0-1026/layout.json"
    layout = read(layout_path)
    layout["surface_obstacles"] = replace_solid(layout["surface_obstacles"])
    if WALK not in layout.setdefault("yards", []):
        layout["yards"].append(WALK)
    entry = next(p for p in layout["entry_paths"] if p["id"] == "ayu")
    entry.update(points=PATH, width=56)
    house = next(h for h in layout["houses"] if h["id"] == "ayu")
    assert house["pos"] == [1850, 2150] and house["bounds_size"] == [800, 600]
    house.update(door_at=[2418, 2689], door_offset=[568, 539])
    houses_path = ASSETS / "village/houses.json"
    houses = read(houses_path)
    next(h for h in houses if h["id"] == "ayu")["at"] = [2418, 2689]
    rooms = read(ASSETS / "rooms.json")
    rooms["rooms"]["village"] = copy.deepcopy(cfg)
    for path, value in [(ASSETS / "village.json", cfg), (layout_path, layout),
                        (houses_path, houses), (ASSETS / "rooms.json", rooms)]:
        write(path, value)
    home = OVERLAY / "ayu_home/v4/home.gd"
    home.write_text(home.read_text().replace('DisplayServer.window_set_title("裳泓村候选1028 · "+',
        'DisplayServer.window_set_title(str(ProjectSettings.get_setting("application/config/name","裳泓村候选"))+" · "+'))
    sync_project()


def surfaces(path):
    generated = read(path)
    cfg = read(ASSETS / "village.json")
    cfg["field_navigation"]["walk_surfaces"] = generated
    rooms = read(ASSETS / "rooms.json")
    rooms["rooms"]["village"] = copy.deepcopy(cfg)
    write(ASSETS / "village.json", cfg)
    write(ASSETS / "rooms.json", rooms)
    sync_project()
    print("same-source regenerated walk surfaces:", len(generated))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", action="store_true")
    parser.add_argument("--surfaces", type=Path)
    args = parser.parse_args()
    if args.source:
        source()
    if args.surfaces:
        surfaces(args.surfaces)
