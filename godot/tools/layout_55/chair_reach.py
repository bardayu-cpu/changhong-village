#!/usr/bin/env python3
"""每把椅子走不走得到——照 test_hall_big.gd「2 每把椅子都走得到」那段的规矩，直接读 scene.json 算（重排时调距离用，快）。
规矩：椅子位置 = 桌心 + seat_geom（从正北起每 36° 一把）；从椅子所在格往外一圈圈找最近能站的格，离椅子 80 以内、
又跟进场点连着才算走得到。能站的格就是 scene.json 的 walk_grid（生成时已经只留跟进场点连着的）。
最后以 Godot 里跑 test_hall_big 为准，这个只是先筛。
用法：python3 godot/tools/layout_55/chair_reach.py [scene.json]
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCENE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "assets", "layered", "scene_roman_banquet_55", "scene.json")


def main():
    s = json.load(open(SCENE, encoding="utf-8"))
    g = s["walk_grid"]
    cell, cols, rows = g["cell"], g["cols"], g["rows"]
    walk = [[ch == "1" for ch in r] for r in rows]
    nr = len(walk)
    bad, n = [], 0
    for t in s["tables"]:
        sg = t.get("seat_geom") or s["seat_geom"]
        cx, cy = t["x"] + sg["dx"], t["y"] + sg["dy"]
        for k in range(10):
            a = -math.pi / 2 + 2 * math.pi * k / 10 + math.radians(sg.get("a0", 0.0))
            px, py = cx + math.cos(a) * sg["rx"], cy + math.sin(a) * sg["ry"]
            n += 1
            ci, cj = int(px // cell), int(py // cell)
            found = None
            for rad in range(1, 40):
                for dj in range(-rad, rad + 1):
                    for di in range(-rad, rad + 1):
                        i, j = ci + di, cj + dj
                        if 0 <= i < cols and 0 <= j < nr and walk[j][i]:
                            found = (i, j)
                            break
                    if found:
                        break
                if found:
                    break
            d = math.hypot((found[0] + 0.5) * cell - px, (found[1] + 0.5) * cell - py) if found else 1e9
            if d > 80:
                bad.append("%s:%d(%.0f)" % (t["id"], k + 1, d))
    print("椅子 %d 把，走不到 %d 把 %s" % (n, len(bad), bad[:20]))
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
