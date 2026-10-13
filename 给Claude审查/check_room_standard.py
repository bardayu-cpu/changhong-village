#!/usr/bin/env python3
"""Check village deep-rooms against Ayu-home occupancy floors.

Usage:
  python3 check_room_standard.py /path/to/裳泓村/godot
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

BANNED_FURNITURE = {
    "furniture_bench.png",
    "furniture_cabinet.png",
    "furniture_kitchen.png",
    "furniture_table.png",
}

# room id -> (min occupancy, min hotspot kinds excluding door, label)
RULES = {
    "v_h3": (0.25, 4, "小涛磨坊一楼"),
    "v_h5": (0.25, 4, "凯凯蜂蜜小院"),
    "v_mayor": (0.25, 4, "村委会一楼"),
    "my_cabin": (0.25, 4, "村民活动中心"),
    "living": (0.22, 3, "阿鱼家客厅（对照，应过）"),
}


def occupancy(room: dict) -> float:
    w, h = room["size"]
    cell = 8
    covered = set()
    for x, y, ww, hh in room.get("obstacles") or []:
        for gx in range(int(x) // cell, int(x + ww) // cell + 1):
            for gy in range(int(y) // cell, int(y + hh) // cell + 1):
                covered.add((gx, gy))
    return len(covered) * cell * cell / (w * h)


def hotspot_kinds(room: dict) -> set[str]:
    kinds = set()
    for spot in room.get("hotspots") or []:
        kind = str(spot.get("kind") or "")
        if kind and kind != "door":
            kinds.add(kind)
    return kinds


def banned_props(room: dict) -> list[str]:
    hits = []
    for prop in room.get("props") or []:
        name = Path(str(prop.get("file") or "")).name
        if name in BANNED_FURNITURE:
            hits.append(name)
    return hits


def load_rooms(godot: Path) -> dict:
    rooms = {}
    main = json.loads((godot / "ayu_home/v4/assets/rooms.json").read_text())["rooms"]
    rooms.update(main)
    assets = godot / "ayu_home/v4/assets"
    for room_id in RULES:
        extra = assets / f"{room_id}.json"
        if extra.exists():
            rooms[room_id] = json.loads(extra.read_text())
    return rooms


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    godot = Path(sys.argv[1])
    rooms = load_rooms(godot)
    failed = 0
    print("房间            占地    下限   种类  下限  禁用家具  结果")
    for room_id, (min_occ, min_kinds, label) in RULES.items():
        room = rooms.get(room_id)
        if not room:
            print(f"{label:16s} 缺配置")
            failed += 1
            continue
        occ = occupancy(room)
        kinds = hotspot_kinds(room)
        banned = banned_props(room) if room_id != "living" else []
        ok = occ >= min_occ and len(kinds) >= min_kinds and not banned
        if not ok:
            failed += 1
        print(
            f"{label:16s} {occ:5.0%}  {min_occ:5.0%}  {len(kinds):2d}    {min_kinds:2d}   "
            f"{','.join(banned) or '无':16s}  {'过' if ok else '没过'}"
        )
        if kinds:
            print(f"  能点种类: {', '.join(sorted(kinds))}")
    print()
    print("过" if failed == 0 else f"没过（{failed} 间）")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
