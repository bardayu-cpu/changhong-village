#!/usr/bin/env python3
"""55 桌大厅灰盒（01 D 9/29 派：不等 GPT 的图，照摆位底图 v3.2 的摆位表做进游戏）。
摆位全从 make_board55.py 的 build() 拿（和摆位表、摆位图同一份数），这里只把它变成游戏的场景：
  assets/layered/scene_roman_banquet_55/base.png   底图：地面、墙、墙上的花拱囍、婚礼台、台阶、乐队地台和乐队、红毯、东侧门
                                                    （这些人都走不到后面去，烘在底图里）
  assets/layered/scene_roman_banquet_55/gb_*.png  色块图块：桌（连椅子）、主桌、宫灯、灯柱、花盆、礼物堆、长凳、栏杆、大门
                                                    按落地排前后（遮挡块），图就是摆位图那套颜色和框（画出来占的框，下沿落地）
  assets/layered/scene_roman_banquet_55/scene.json  桌（主桌 MAIN + T1～T54，桌心、占地半径）、能走的格子、遮挡块、交互点、长凳、座位圈
  assets/ambience/ambience_55.json                  厅里的热闹：每桌 NPC 9～10 个（阿鱼定）、服务员 6 个、彩带彩纸
  回执/55桌灰盒-拼回整厅.png                         自查：底图 + 全部色块按落地线叠回一张，和摆位底图逐像素比（03 拿它跑 board_check）
桌下不铺地毯（阿鱼 9/28），没有横幅、LED（阿鱼 9/28）
用法：python3 tools/layout_55/build_graybox55.py
"""
import importlib.util
import json
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55")
AMB = os.path.join(GODOT, "assets", "ambience", "ambience_55.json")
RES = "res://assets/layered/scene_roman_banquet_55/"
CELL = 10
C = 12                    # 走路离占地留的边（和 build_layered.py 一样）

spec = importlib.util.spec_from_file_location("board", os.path.join(HERE, "make_board55.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)


# 主桌坐谁（阿鱼 9/29 定，以 01 D 最后那条更正为准）：主桌就是普通 10 座。8 位 NPC：爸爸、妈妈、外公、外婆、爷爷、奶奶、弟弟、弟妹；
# 1、2 号空着留给阿鱼、Toretto 本人（服务端进厅分主桌取最小的空号，正好是这两把；上线就坐这儿）。
# 椅子从正北（背对婚礼台、面朝大门那把）起顺时针数；谁坐哪把是 02 排的，【待阿鱼定】，改这张表重跑就行。
# 别的亲友（大爸一家、周叔他们、四孃、小舅……）这一版不做：阿鱼要他们开席前走动、开席后敬酒打牌，玩法 01 先写说明给阿鱼过目
FAMILY = {"table": "MAIN", "reserved": {"1": "阿鱼", "2": "Toretto"}, "seats": [
    {"chair": 3, "title": "爷爷"}, {"chair": 4, "title": "奶奶"}, {"chair": 5, "title": "爸爸"}, {"chair": 6, "title": "妈妈"},
    {"chair": 7, "title": "弟弟"}, {"chair": 8, "title": "弟妹"}, {"chair": 9, "title": "外公"}, {"chair": 10, "title": "外婆"}]}


def block_image(it):
    """一件东西画成一张透明底的小图，和摆位图同一套画法"""
    x, y, w, h = it["box"]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g = ImageDraw.Draw(im)
    if it["kind"] == "table":
        fx, fy, fw, fh = it["foot"]
        fx, fy = fx - x, fy - y
        g.ellipse([fx + 10, 0, fx + fw - 10, fh], fill=(90, 50, 25, 255))
        g.ellipse([fx, fy, fx + fw - 1, fy + fh - 1], fill=(90, 50, 25, 255))
        g.ellipse([fx + 27, fy + 17, fx + fw - 27, fy + fh - 17], fill=tuple(it["color"]) + (255,))
    else:
        g.rectangle([0, 0, w - 1, h - 1], fill=tuple(it["color"]) + (255,))
    return im


def main():
    items, tid, door, stand_top, rail_foot = B.build()
    W, H = B.W, B.H
    os.makedirs(OUT, exist_ok=True)

    occ_kinds = ("table", "prop")
    front_names = ("南边西段栏杆", "南边东段栏杆", "大门（双开门门洞）")
    base_items = [it for it in items if it["kind"] not in occ_kinds + ("mark", "ruler", "zone") and it["name"] not in front_names]
    base = B.draw(base_items, False, tid, door, stand_top, rail_foot)
    base.save(os.path.join(OUT, "base.png"))

    # 遮挡块：同样大小同样颜色的只存一张图
    imgs = {}
    occ = []
    for it in items:
        if not (it["kind"] in occ_kinds or it["name"] in front_names):
            continue
        x, y, w, h = it["box"]
        key = "%s_%dx%d_%02x%02x%02x" % (it["kind"], w, h, *it["color"])
        if key not in imgs:
            name = "gb_%d.png" % len(imgs)
            block_image(it).save(os.path.join(OUT, name))
            imgs[key] = RES + name
        fx, fy, fw, fh = it["foot"]
        foot = fy + fh // 2
        if it["name"] in front_names:
            foot = rail_foot + 1000 + len(occ)   # 栏杆、大门永远画在人前面（和 12 桌厅的栏杆一样）
        occ.append({"id": it["name"], "image": imgs[key], "x": x, "y": y, "foot": foot})

    # 桌：主桌 MAIN + T1～T54；x、y 是占地中心（和 12 桌厅一样的规矩），rx、ry 是占地半径
    tables = []
    for it in items:
        if it["kind"] != "table":
            continue
        fx, fy, fw, fh = it["foot"]
        t = {"id": "MAIN" if it["name"] == "主桌" else it["name"], "x": fx + fw // 2, "y": fy + fh // 2, "rx": fw // 2, "ry": fh // 2}
        if it["name"] == "主桌":
            t["main"] = True
        tables.append(t)
    tables.sort(key=lambda t: (t["id"] != "MAIN", int(t["id"][1:]) if t["id"] != "MAIN" else 0))

    # 能走的格子：厅里（两边墙之间、北墙脚到南边栏杆）减掉挡路东西的占地（外放 12）；东侧门门洞能站；从大门那块空地连通
    cols, rows = math.ceil(W / CELL), math.ceil(H / CELL)
    d0, d1 = door
    blockers = []
    for it in items:
        if it["kind"] in ("mark", "ruler", "zone", "floor", "decor") or it["name"] in ("大门（双开门门洞）", "东侧门（门洞）"):
            continue
        if it["group"] in ("top_decor", "wall_decor", "stage_decor"):
            continue
        blockers.append(it)

    def blocked(px, py):
        for it in blockers:
            fx, fy, fw, fh = it["foot"]
            if it["kind"] == "table":
                cx, cy, rx, ry = fx + fw / 2, fy + fh / 2, fw / 2, fh / 2
                if ((px - cx) / (rx + C)) ** 2 + ((py - cy) / (ry + C)) ** 2 < 1.0:
                    return True
            elif fx - C < px < fx + fw + C and fy - C < py < fy + fh + C:
                return True
        return False

    grid = [[False] * cols for _ in range(rows)]
    for j in range(rows):
        py = (j + 0.5) * CELL
        for i in range(cols):
            px = (i + 0.5) * CELL
            inside = 40 < px < W - 40 and B.WALL_N < py < rail_foot - 8
            in_side_door = W - 40 <= px < W and d0 < py < d1
            if (inside and not blocked(px, py)) or in_side_door:
                grid[j][i] = True
    spawn = [B.CX, stand_top + 48]
    sx, sy = int(spawn[0] // CELL), int(spawn[1] // CELL)
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

    bench = [it for it in items if it["name"] == "长凳"][0]
    bx, by, bw, bh = bench["foot"]
    steps_bottom = B.STEPS_FOOT[1] + B.STEPS_FOOT[3]
    points = [
        # 主桌悄悄话：红毯上、台阶正前方（新人站在台上）
        {"id": "couple_table", "x": B.CX, "y": steps_bottom + 45, "r": 60, "kind": "talk", "line": "table"},
        {"id": "door", "x": B.CX, "y": rail_foot - 145 - 20, "r": 50, "kind": "door", "line": "leave"},
        {"id": "side_door", "x": W - 20, "y": (d0 + d1) // 2, "r": 30, "kind": "door", "line": "backhall"},
    ]
    scene = {
        "scene": "scene_roman_banquet_55", "mode": "blocks", "revision": "graybox-v3.2",
        "note": "55 桌大厅灰盒（01 D 9/29）：照摆位底图 v3.2（455d828）的摆位表，tools/layout_55/build_graybox55.py 生成，别手改",
        "base": RES + "base.png", "size": [W, H],
        "person_px": {"near_y": H, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": spawn,
        "couple": [B.COUPLE_FEET[0][0] + 16, B.COUPLE_FEET[0][1]],
        "points": points,
        "walk_grid": {"cell": CELL, "cols": cols, "rows": ["".join("1" if v else "0" for v in r) for r in grid]},
        "occluders": occ,
        "tables": tables,
        "ambience": "ambience_55.json",
        # 座位圈：灰盒的桌是占地 140×92 的一圈，椅子就在这圈上（12 桌厅是 GPT 那张桌子图，圈心往上挪 0.85 个半径）
        "seat_geom": {"dy": 0.0, "rx": -12.0, "ry": -8.0},
        # 长凳：第 1 排最西那个空位，灰盒色块画了凳子，代码不另画；坐的人排在凳面上
        "bench": {"x0": bx + 12, "x1": bx + bw - 12, "y": by + 2, "draw": False},
        "rugs": False,        # 桌下不铺地毯（阿鱼 9/28）
        "band_art": False,    # 乐队是底图里的色块，不叠第 44 版那块乐队图
        "sign_mode": "near",  # 认桌（01 定）：自己那桌一直挂牌，走近哪桌亮哪桌，其余不挂
    }
    json.dump(scene, open(os.path.join(OUT, "scene.json"), "w", encoding="utf-8"), ensure_ascii=False)
    # 这回没生成的图（第 47 版留下的拉长底图、GPT 桌子，或者色块少了一种）连同 .import 一起清掉；
    # 生成了的图留着 .import，重跑不换 uid
    keep = {"base.png"} | {v.replace(RES, "") for v in imgs.values()}
    for f in os.listdir(OUT):
        png = f[:-len(".import")] if f.endswith(".png.import") else f
        if png.endswith(".png") and png not in keep:
            os.remove(os.path.join(OUT, f))

    # 厅里的热闹
    rng = random.Random(55)
    npc = {}
    for t in tables:
        if t["id"] != "MAIN":
            npc[t["id"]] = rng.randint(9, 10)   # 每桌 9～10（阿鱼定）；主桌不放随机宾客，坐阿鱼家里人（family）
    decals = []
    placed = []
    carpet = [it for it in items if it["name"] == "红毯"][0]["box"]
    tries = 0
    while len(decals) < 110 and tries < 40000:
        tries += 1
        x, y = rng.uniform(60, W - 60), rng.uniform(B.WALL_N + 40, rail_foot - 60)
        if carpet[0] - 10 < x < carpet[0] + carpet[2] + 10:
            continue
        if not grid[int(y // CELL)][int(x // CELL)]:
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < 60 ** 2 for px, py in placed):
            continue
        placed.append((x, y))
        art = "amb_streamer_%d" % rng.randint(1, 6) if len(decals) % 3 else "amb_confetti_%d" % rng.randint(1, 3)
        decals.append({"art": art, "x": round(x), "y": round(y), "flip": rng.random() < 0.5})
    amb = {
        "note": "55 桌大厅灰盒的热闹摆放，tools/layout_55/build_graybox55.py 生成，别手改",
        "decals": decals, "glows": [],
        "npc_tables": npc,
        "family": FAMILY,
        "waiters": {"count": 6, "door": [W - 70, (d0 + d1) // 2], "speed_m": 1.5},
        "petals": {"amount": 60},
    }
    json.dump(amb, open(AMB, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # 自查：叠回一张整厅，和摆位底图比。只该差比例尺那个小人（人=1 的量尺，不进游戏）
    flat = base.convert("RGBA")
    cache = {}
    for o in sorted(occ, key=lambda o: o["foot"]):
        f = o["image"].replace(RES, "")
        if f not in cache:
            cache[f] = Image.open(os.path.join(OUT, f)).convert("RGBA")
        flat.alpha_composite(cache[f], (int(o["x"]), int(o["y"])))
    flat = flat.convert("RGB")
    flat.save(os.path.join(GODOT, "回执", "55桌灰盒-拼回整厅.png"))
    ref = os.path.join(GODOT, "回执", "宴会厅55桌-摆位底图.png")
    if os.path.exists(ref):
        d = ImageChops.difference(flat, Image.open(ref).convert("RGB"))
        ruler = [it["box"] for it in items if it["kind"] == "ruler"]
        n = n_out = 0
        for j in range(H):
            for i in range(W):
                if d.getpixel((i, j)) != (0, 0, 0):
                    n += 1
                    if not any(x <= i < x + w and y <= j < y + h for x, y, w, h in ruler):
                        n_out += 1
        print("拼回整厅和摆位底图：差 %d 像素，比例尺小人以外差 %d 像素" % (n, n_out))
    walk_n = sum(1 for r in grid for v in r if v)
    print("灰盒：画布 %d×%d，桌 %d（主桌 + T1～T%d），遮挡块 %d（图 %d 张），能走 %d 格，NPC %d 个" % (
        W, H, len(tables), len(tables) - 1, len(occ), len(imgs), walk_n, sum(npc.values())))


if __name__ == "__main__":
    main()
