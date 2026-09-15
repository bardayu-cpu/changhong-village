#!/usr/bin/env python3
"""分层场景（ASSETS.md 第 14 节）：把场景描述转成游戏里用的 scene.json。

用法：python3 tools/build_layered.py tools/stand_in_banquet.json [检查图输出路径.png]

做的事：
- 底图拷进 godot/assets/layered/<场景>/base.png，写好导入设置（大图用有损压缩，不然包太大）
- 能走的格子提前算好（一格 10 像素）：在能走的范围里、离障碍够远、从进场点走得到，写进 scene.json，
  手机上不用现算，也不用读图片像素（微信里读显卡会崩）
- 遮挡块：椭圆、矩形转成多边形（一块可以由几个形状拼成）；游戏里用底图把这一块重画一遍，盖在人前面
- 可选：出一张检查图，底图上画出能走的格子（绿）、遮挡块（黄框）、交互点（蓝圈）

现在只支持临时版（stand_in：底图是效果图原图，形状是 Claude 标的）。GPT 的分层积木到了，再加读 base.png、blk_*.png、walk.png 的那一路。
"""
import json
import math
import os
import shutil
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
# 9/15 晚起交付在共用文件夹，按地图、场景、画布分（ASSETS.md v0.9 第 1 节）；旧「素材交付」只作存档。环境变量 SUQI_DELIVERY 可指到别的画布文件夹
DELIVERY = os.environ.get("SUQI_DELIVERY") or os.path.join(os.path.dirname(os.path.dirname(GODOT)), "游戏制作中-gpt 和 claude 合作", "地图一-苏七镇", "罗曼山庄", "001-宴会厅")
CELL = 10


def ellipse_pts(cx, cy, rx, ry, n=28):
    return [[round(cx + rx * math.cos(2 * math.pi * i / n), 1), round(cy + ry * math.sin(2 * math.pi * i / n), 1)] for i in range(n)]


def shape_pts(o):
    if "ellipse" in o:
        return ellipse_pts(*o["ellipse"])
    if "rect" in o:
        x0, y0, x1, y1 = o["rect"]
        return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
    if "circle" in o:
        x, y, r = o["circle"]
        return ellipse_pts(x, y, r, r, 16)
    return o["poly"]


def in_poly(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def blocked(x, y, o, c):
    """点 (x,y) 离障碍 o 不到 c 像素就算挡住"""
    if "ellipse" in o:
        cx, cy, rx, ry = o["ellipse"]
        return ((x - cx) / (rx + c)) ** 2 + ((y - cy) / (ry + c)) ** 2 < 1.0
    if "rect" in o:
        x0, y0, x1, y1 = o["rect"]
        return x0 - c <= x <= x1 + c and y0 - c <= y <= y1 + c
    if "circle" in o:
        cx, cy, r = o["circle"]
        return math.hypot(x - cx, y - cy) < r + c
    pts = o["poly"]
    return any(in_poly(x + dx, y + dy, pts) for dx, dy in ((0, 0), (c, 0), (-c, 0), (0, c), (0, -c)))


def main():
    src = json.load(open(sys.argv[1], encoding="utf-8"))
    check_out = sys.argv[2] if len(sys.argv) > 2 else None
    scene = src["scene"]
    out_dir = os.path.join(GODOT, "assets", "layered", scene)
    os.makedirs(out_dir, exist_ok=True)
    base_src = os.path.join(DELIVERY, src["base_from"])
    base_dst = os.path.join(out_dir, "base.png")
    shutil.copyfile(base_src, base_dst)
    imp = base_dst + ".import"
    if not os.path.exists(imp):
        with open(imp, "w", encoding="utf-8") as f:
            # 底图是一整张细节很多的画（三十多万种颜色），无损压缩要好几 MB，用有损压缩，质量 0.9
            f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n')
            f.write("compress/mode=1\ncompress/lossy_quality=0.9\nmipmaps/generate=false\ndetect_3d/compress_to=0\n")

    w, h = src["size"]
    cols, rows = math.ceil(w / CELL), math.ceil(h / CELL)
    c = src.get("clearance", 12)
    grid = [[False] * cols for _ in range(rows)]
    for j in range(rows):
        for i in range(cols):
            x, y = (i + 0.5) * CELL, (j + 0.5) * CELL
            if in_poly(x, y, src["walk_poly"]) and not any(blocked(x, y, o, c) for o in src["obstacles"]):
                grid[j][i] = True
    # 从进场点走不到的格子也算不能走（被围死的小角落）
    sx, sy = int(src["spawn"][0] // CELL), int(src["spawn"][1] // CELL)
    assert grid[sy][sx], "进场点不在能走的地方"
    seen = {(sx, sy)}
    stack = [(sx, sy)]
    while stack:
        i, j = stack.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ni, nj = i + di, j + dj
            if 0 <= ni < cols and 0 <= nj < rows and grid[nj][ni] and (ni, nj) not in seen:
                seen.add((ni, nj))
                stack.append((ni, nj))
    free_before = sum(map(sum, grid))
    for j in range(rows):
        for i in range(cols):
            grid[j][i] = (i, j) in seen
    for p in src["points"]:
        pi, pj = int(p["x"] // CELL), int(p["y"] // CELL)
        near = any(grid[pj + dj][pi + di] for dj in range(-7, 8) for di in range(-7, 8)
                   if 0 <= pi + di < cols and 0 <= pj + dj < rows and math.hypot(di, dj) * CELL < p["r"])
        assert near, "交互点 %s 周围走不到" % p["id"]

    occ = [{"id": o["id"], "polys": [shape_pts(x) for x in o.get("shapes", [o])], "foot": o["foot"]} for o in src["occluders"]]
    out = {
        "scene": scene,
        "mode": src["mode"],
        "base": "res://assets/layered/%s/base.png" % scene,
        "size": src["size"],
        "person_px": src["person_px"],
        "spawn": src["spawn"],
        "couple": src["couple"],
        "points": src["points"],
        "walk_grid": {"cell": CELL, "cols": cols, "rows": ["".join("1" if v else "0" for v in r) for r in grid]},
        "occluders": occ,
    }
    json.dump(out, open(os.path.join(out_dir, "scene.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print("场景 %s：格子 %d×%d，能走 %d 格（去掉围死的 %d 格），遮挡块 %d 个" % (
        scene, cols, rows, len(seen), free_before - len(seen), len(occ)))

    if check_out:
        im = Image.open(base_src).convert("RGBA")
        ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        for j in range(rows):
            for i in range(cols):
                if grid[j][i]:
                    d.rectangle((i * CELL, j * CELL, i * CELL + CELL - 1, j * CELL + CELL - 1), fill=(0, 255, 90, 70))
        for o in occ:
            for poly in o["polys"]:
                d.polygon([tuple(p) for p in poly], outline=(255, 230, 0, 255))
            xs = [p[0] for poly in o["polys"] for p in poly]
            d.line((min(xs), o["foot"], max(xs), o["foot"]), fill=(255, 80, 0, 255), width=2)
        for p in src["points"]:
            d.ellipse((p["x"] - p["r"], p["y"] - p["r"], p["x"] + p["r"], p["y"] + p["r"]), outline=(60, 160, 255, 255), width=3)
        d.ellipse((src["spawn"][0] - 6, src["spawn"][1] - 6, src["spawn"][0] + 6, src["spawn"][1] + 6), fill=(60, 160, 255, 255))
        Image.alpha_composite(im, ov).convert("RGB").save(check_out)


if __name__ == "__main__":
    main()
