#!/usr/bin/env python3
"""把 layout_east.json 画到整块图上核对：绿 = 能走的 walk，红 = 挡路的占地，黄圈 = 玩法点，蓝点 = 人（乐手、船夫），白点 = spawn / 长凳坐站点"""
import json, os
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(HERE, "layout_east.json"), encoding="utf-8"))
X = d["covers"][0]
base = Image.open(os.path.join(HERE, "lake_ref2b_full.png")).convert("RGBA")
ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
g = ImageDraw.Draw(ov)
for poly in d["walk"]:
    g.polygon([(x - X, y) for x, y in poly], fill=(60, 220, 90, 70), outline=(40, 255, 80, 255))
for it in d["items"]:
    t = it["type"]
    if t == "box" and it.get("block", True):
        r = it["rect"]
        g.rectangle([r[0] - X, r[1], r[2] - X, r[3]], outline=(255, 40, 40, 255), fill=(255, 40, 40, 90))
    elif t == "cyl":
        g.ellipse([it["x"] - X - it["rx"], it["y"] - it["ry"], it["x"] - X + it["rx"], it["y"] + it["ry"]], outline=(255, 60, 60, 255))
    elif t == "tree":
        g.ellipse([it["x"] - X - 14, it["y"] - 8, it["x"] - X + 14, it["y"] + 8], outline=(255, 60, 60, 255), fill=(255, 40, 40, 90))
    elif t == "poly" and isinstance(it.get("block"), list):
        b = it["block"]
        g.rectangle([b[0] - X, b[1], b[2] - X, b[3]], outline=(255, 40, 40, 255), fill=(255, 40, 40, 90))
for p in d["points"]:
    g.ellipse([p["x"] - X - p["r"], p["y"] - p["r"], p["x"] - X + p["r"], p["y"] + p["r"]], outline=(255, 230, 0, 255), width=2)
for n in d["npcs"]:
    g.ellipse([n["x"] - X - 4, n["y"] - 4, n["x"] - X + 4, n["y"] + 4], fill=(40, 120, 255, 255))
for k in ("spawn", "bench_seat", "bench_stand"):
    x, y = d[k]
    g.ellipse([x - X - 3, y - 3, x - X + 3, y + 3], fill=(255, 255, 255, 255))
base.alpha_composite(ov)
base.save(os.path.join(HERE, "layout_east_check.png"))
print("ok")
