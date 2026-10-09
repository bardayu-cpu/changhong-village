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





# ---------------- A04 积木配置（blocks/place）那一路 ----------------
# 用法：python3 tools/build_layered.py <画布文件夹>/scene_pilot.json [检查图.png]
# 和 stand_in 的区别：底图由 base.png 加积木按脚点排序拼出来（拼法和 assemble_layered.py 一致）；
# 遮挡块直接用积木图（occluder 带 image）；人高固定 person_h，不随远近缩

def main_blocks(src_path, check_out):
    folder = os.path.dirname(os.path.abspath(src_path))
    src = json.load(open(src_path, encoding="utf-8"))
    scene = src["scene"]
    w, h = src["canvas"]
    out_dir = os.path.join(GODOT, "assets", "layered", scene)
    os.makedirs(out_dir, exist_ok=True)

    def lossy_import(path):
        imp = path + ".import"
        if not os.path.exists(imp):
            with open(imp, "w", encoding="utf-8") as f:
                f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n')
                f.write("compress/mode=1\ncompress/lossy_quality=0.9\nmipmaps/generate=false\ndetect_3d/compress_to=0\n")

    # 1. 烘底图：base + 积木按 (front, 脚点 y, 顺序) 叠，和拼装脚本同一规则
    base = Image.open(os.path.join(folder, src["base"])).convert("RGBA")
    assert base.size == (w, h), "底图应是 %d×%d" % (w, h)
    sprites = {}
    for name in src["blocks"]:
        sprites[name] = Image.open(os.path.join(folder, name + ".png")).convert("RGBA")
    items = []
    for i, p in enumerate(src["place"]):
        im2 = sprites[p["block"]]
        ax, ay = src["blocks"][p["block"]]["anchor"]
        if p.get("flip"):
            im2 = im2.transpose(Image.FLIP_LEFT_RIGHT)
            ax = im2.width - ax
        items.append((bool(p.get("front")), p["y"], i, p, im2, (p["x"] - ax, p["y"] - ay)))
    baked = base.copy()
    for front, y, i, p, im2, xy in sorted(items, key=lambda t: (t[0], t[1], t[2])):
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        layer.paste(im2, xy)
        baked = Image.alpha_composite(baked, layer)
    base_dst = os.path.join(out_dir, "base.png")
    baked.convert("RGB").save(base_dst)
    lossy_import(base_dst)

    # 2. 遮挡块：每次摆放一个，图用积木（镜像的另存一张），脚点 y 定前后
    occ = []
    saved = {}
    for front, y, i, p, im2, xy in items:
        key = p["block"] + ("_flip" if p.get("flip") else "")
        if key not in saved:
            dst = os.path.join(out_dir, key + ".png")
            im2.save(dst)
            lossy_import(dst)
            saved[key] = "res://assets/layered/%s/%s.png" % (scene, key)
        if front:
            y = h + 1000 + i  # 前景永远画在人前面
        occ.append({"id": "%s_%d" % (p["block"], i), "image": saved[key], "x": xy[0], "y": xy[1], "foot": p["y"]})

    # 3. 能走的格子：walk 多边形里、离占地 12 像素外、从进场点连通
    C = 12
    feet = []
    for _, _, _, p, _, _ in items:
        fp = src["blocks"][p["block"]].get("footprint")
        if fp and not p.get("front"):
            feet.append((p["x"], p["y"], fp))
    cols, rows = math.ceil(w / CELL), math.ceil(h / CELL)

    def foot_block(x, y):
        for fx, fy, fp in feet:
            if "ellipse" in fp:
                rx, ry = fp["ellipse"]
                if ((x - fx) / (rx + C)) ** 2 + ((y - fy) / (ry + C)) ** 2 < 1.0:
                    return True
            elif abs(x - fx) < fp["rect"][0] / 2 + C and abs(y - fy) < fp["rect"][1] / 2 + C:
                return True
        return False

    grid = [[False] * cols for _ in range(rows)]
    for j in range(rows):
        for i in range(cols):
            x, y = (i + 0.5) * CELL, (j + 0.5) * CELL
            if any(in_poly(x, y, poly) for poly in src["walk"]) and not foot_block(x, y):
                grid[j][i] = True
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
    for j in range(rows):
        for i in range(cols):
            grid[j][i] = (i, j) in seen
    for p in src["points"]:
        pi, pj = int(p["x"] // CELL), int(p["y"] // CELL)
        near = any(grid[pj + dj][pi + di] for dj in range(-7, 8) for di in range(-7, 8)
                   if 0 <= pi + di < cols and 0 <= pj + dj < rows and math.hypot(di, dj) * CELL < p["r"])
        assert near, "交互点 %s 周围走不到" % p["id"]

    # 桌子清单：给宴会厅玩法用（座位画在哪）。离舞台近（y 小）优先、再从左到右编 T1、T2……
    # 和服务端 config.js 的 BANQUET_TABLE_IDS 对应：前两桌是离主桌最近的
    tabs = []
    for _f, _y, _i, p2, _im, _xy in items:
        if p2["block"].startswith("blk_table") and not p2.get("front"):
            fp2 = src["blocks"][p2["block"]].get("footprint", {})
            if "ellipse" in fp2:
                trx, try_ = fp2["ellipse"]
            else:
                trx, try_ = fp2.get("rect", [240, 160])[0] / 2, fp2.get("rect", [240, 160])[1] / 2
            tabs.append({"x": p2["x"], "y": p2["y"], "rx": trx, "ry": try_})
    # 同一排里离中线（红毯、主桌所在的 x）近的先编：T1、T2 就是离主桌最近的两桌（9/18 摆满一排四张以后要这样）。
    # 9/18 晚桌子错落着摆以后，一排里的桌子 y 不一样：先按 y 分排（和这排第一张差不到 85 像素算同一排），
    # 排里离中线的距离按 40 像素一档比（差不多远算一样远），一样远的左边先编——编出来的号和错落前同一个位置一样
    mid = w / 2.0
    tabs.sort(key=lambda t: t["y"])
    row, row_y = 0, None
    for t in tabs:
        if row_y is None or t["y"] - row_y > 85:
            row, row_y = row + 1, t["y"]
        t["row"] = row
    tabs.sort(key=lambda t: (t["row"], round(abs(t["x"] - mid) / 40.0), t["x"]))
    for ti, t in enumerate(tabs):
        t["id"] = "T%d" % (ti + 1)
        del t["row"]

    ph = src["person_h"]
    out = {
        "scene": scene,
        "mode": "blocks",
        "revision": src.get("revision", ""),
        "base": "res://assets/layered/%s/base.png" % scene,
        "size": [w, h],
        # 斜俯视正交：人不随远近缩，两行同高
        "person_px": {"near_y": h, "near_h": ph, "far_y": 0, "far_h": ph},
        "spawn": src["spawn"],
        "couple": src["couple"],
        "points": src["points"],
        "walk_grid": {"cell": CELL, "cols": cols, "rows": ["".join("1" if v else "0" for v in r) for r in grid]},
        "occluders": occ,
        "tables": tabs,
    }
    # 可选的几块原样带过去：ambience 是这块画布的氛围摆放文件名（assets/ambience/ 下，hall_life.gd 读）；stage 是婚礼台上的横幅和 LED 屏（stage_signs.gd 读）
    for k in ("ambience", "stage"):
        if k in src:
            out[k] = src[k]
    json.dump(out, open(os.path.join(out_dir, "scene.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print("场景 %s（积木）：格子 %d×%d，能走 %d 格，积木摆放 %d 次，图 %d 张" % (scene, cols, rows, len(seen), len(occ), len(saved)))

    if check_out:
        ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        for j in range(rows):
            for i in range(cols):
                if grid[j][i]:
                    d.rectangle((i * CELL, j * CELL, i * CELL + CELL - 1, j * CELL + CELL - 1), fill=(0, 255, 90, 70))
        for p in src["points"]:
            d.ellipse((p["x"] - p["r"], p["y"] - p["r"], p["x"] + p["r"], p["y"] + p["r"]), outline=(60, 160, 255, 255), width=3)
        Image.alpha_composite(baked, ov).convert("RGB").save(check_out)


if __name__ == "__main__":
    _src = json.load(open(sys.argv[1], encoding="utf-8"))
    if "blocks" in _src:
        main_blocks(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        main()
