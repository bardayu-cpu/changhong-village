#!/usr/bin/env python3
"""喷泉雕塑广场 · 灰盒（蓝图 v0.3 第 1.0 节「新总图」第 ② 步，阿鱼 10/4「行」；01 F 派）。
出 assets/layered/scene_luoman_plaza/layout.json（scripts/plaza.gd 读它）。改摆法只改这份的数、重跑，别手改 json；再跑 gen_specs_court.py --scene plaza。
参考图：docs/参考图/罗曼山庄布局参考-阿鱼10-04.png（阿鱼画的相对位置，不是比例图）。

山庄正中一块空地，正中一座喷泉雕塑，四周是通各处的路口（方位照参考图）：
  东口 → 迎宾院（新总图叫迎宾厅/签到处，现在的迎宾院先当迎宾厅用）
  西口 → 草坪（草坪改从这里进）
  南口 → 后厅走廊（中餐厨房、麻将室、休息室、化妆间那一排）
  北边三个口 → 儿童乐园、小卖部、休息区（还没做：路口拦着、挂「待做」牌，走过去说一句还在布置）
画布 1536 × 1024（跟别的画布一样）；比例照 ASSETS §15：左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素，人 84。
全部色块占位，阿鱼挑过摆法、锁了再画。
用法：python3 godot/tools/layout_court/make_plaza.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_plaza", "layout.json")

W, H = 1536, 1024
CX, CY = 768, 540                 # 喷泉中心（脚点）
PAVE = (140, 210, 1396, 890)      # 铺石板的广场（四边一圈矮绿篱，篱里能走）
BAND = (524, 596)                 # 东西主路（东口、西口）
NORTH = [("kids", 420, "儿童乐园"), ("shop", 768, "小卖部"), ("rest", 1116, "休息区")]   # 北边三个口（还没做；两头的口让开四角大树的树冠）
STUB = 36                         # 路口半宽（路宽 72 ≈ 1.5 米）
SOUTH_X = 768

HEDGE = dict(top="#5f8f4e", front="#3f6a3f", part="PZ-P05")


def box(id_, rect, h, top, front, **kw):
    it = {"type": "box", "id": id_, "rect": [int(v) for v in rect], "h": int(h), "top": top, "front": front}
    it.update(kw)
    return it


def hedge_run(prefix, a, b, fixed, horizontal, gaps):
    """一段矮绿篱：在 gaps（[(g0, g1)]）留口；horizontal 是沿 x 走（fixed 是 y 上沿），不然沿 y 走（fixed 是 x 左沿）"""
    out = []
    cuts = sorted(gaps)
    x = a
    k = 0
    for (g0, g1) in cuts + [(b, b)]:
        if g0 - x > 8:
            r = [x, fixed, g0, fixed + 14] if horizontal else [fixed, x, fixed + 14, g0]
            out.append(box("%s_%d" % (prefix, k), r, 36, **HEDGE, **({"scale": {"h_m": 0.75, "name": "矮绿篱"}} if prefix == "hedge_n" and k == 0 else {})))
            k += 1
        x = g1
    return out


def main():
    flat, items = [], []
    # ================= 地面：外面一圈草，里面石板广场，四条路
    flat += [
        {"type": "rect", "rect": [0, 0, W, H], "color": "#8fbf6a"},
        {"type": "rect", "rect": list(PAVE), "color": "#d6c8a6"},
        {"type": "rect", "rect": [0, BAND[0], W, BAND[1]], "color": "#c2b393"},                       # 东西主路
        {"type": "rect", "rect": [SOUTH_X - STUB, PAVE[3], SOUTH_X + STUB, H], "color": "#c2b393"},  # 南口路
    ]
    for (_, x, _) in NORTH:
        flat.append({"type": "rect", "rect": [x - STUB, 0, x + STUB, PAVE[1]], "color": "#c2b393"})   # 北边三个口的路
    # 喷泉那一圈浅色石板（地上的，排在最后面）
    ring = [[CX + 250, CY], [CX + 177, CY + 92], [CX, CY + 130], [CX - 177, CY + 92], [CX - 250, CY], [CX - 177, CY - 92], [CX, CY - 130], [CX + 177, CY - 92]]
    items.append({"type": "poly", "id": "fountain_ring", "pts": ring, "foot": 0, "color": "#e4d9bd", "part": "PZ-P01"})
    # ================= 喷泉雕塑：水池（直径约 6 米）、中间一层小水盘、雕塑（连底座约 3 米）
    items.append({"type": "cyl", "id": "fountain_basin", "x": CX, "y": CY, "rx": 150, "ry": 64, "h": 26, "top": "#6fa8cf", "front": "#b9b2a4",
                  "scale": {"w_m": 6.25, "name": "喷泉水池（直径约 6 米）"}, "part": "PZ-P01"})
    items.append({"type": "cyl", "id": "fountain_tier", "x": CX, "y": CY + 1, "rx": 46, "ry": 20, "h": 66, "top": "#8fc3e2", "front": "#d8d2c4",
                  "part": "PZ-P01"})
    items.append(box("fountain_statue", [CX - 16, CY - 10, CX + 16, CY + 4], 150, "#f2efe6", "#e3ddd0",
                     scale={"h_m": 3.1, "name": "雕塑（连底座约 3 米）"}, part="PZ-P02"))
    # ================= 四周：四棵大树、四个花坛、四盏路灯、两张长椅
    for k, (tx, ty) in enumerate([(260, 330), (1276, 330), (260, 820), (1276, 820)]):
        items.append({"type": "tree", "id": "tree_%d" % k, "x": tx, "y": ty, "trunk": "#6d4a38", "leaf": "#4f7a4a", "leaf2": "#6a9a5c",
                      "h": 264, "w": 180, "part": "PZ-P03", **({"scale": {"h": "tree_h"}} if k == 0 else {})})
    for k, (fx, fy) in enumerate([(500, 390), (1036, 390), (500, 720), (1036, 720)]):
        items.append({"type": "cyl", "id": "flowerbed_%d" % k, "x": fx, "y": fy, "rx": 56, "ry": 22, "h": 24, "top": "#e9a6c0", "front": "#7fa85c",
                      "part": "PZ-P04", **({"scale": {"w_m": 2.3, "h_m": 0.5, "name": "花坛"}} if k == 0 else {})})
    for k, (lx, ly) in enumerate([(560, 508), (976, 508), (560, 618), (976, 618)]):
        items.append(box("lamp_%d" % k, [lx - 5, ly - 6, lx + 5, ly], 150, "#2f2b34", "#3e3946", part="PZ-P06",
                         **({"scale": {"h_m": 3.1, "name": "路灯"}} if k == 0 else {})))
    for k, (bx, by) in enumerate([(640, 680), (896, 680)]):
        items.append(box("bench_%d" % k, [bx - 36, by - 10, bx + 36, by], 22, "#c19a68", "#8c5f3c", part="PZ-P07",
                         **({"scale": {"w_m": 1.5, "name": "长椅"}} if k == 0 else {})))
    # ================= 一圈矮绿篱（留口）
    north_gaps = [(x - STUB, x + STUB) for (_, x, _) in NORTH]
    items += hedge_run("hedge_n", PAVE[0], PAVE[2], PAVE[1] - 14, True, north_gaps)
    items += hedge_run("hedge_s", PAVE[0], PAVE[2], PAVE[3], True, [(SOUTH_X - STUB, SOUTH_X + STUB)])
    items += hedge_run("hedge_w", PAVE[1], PAVE[3], PAVE[0] - 14, False, [BAND])
    items += hedge_run("hedge_e", PAVE[1], PAVE[3], PAVE[2], False, [BAND])
    # ================= 北边三个口：还没做，路口一道拦着的施工栏
    for (key, x, name) in NORTH:
        items.append(box("todo_fence_%s" % key, [x - STUB - 4, 66, x + STUB + 4, 74], 40, "#e8a23a", "#c9822a", part="PZ-P08",
                         **({"scale": {"h_m": 0.83, "name": "施工栏（待做的口拦着）"}} if key == "kids" else {})))
    # ================= 路牌（只有出口牌显示，木牌）
    flat += [{"type": "label", "text": "去迎宾院", "x": 1440, "y": BAND[0] - 46},
             {"type": "label", "text": "去草坪", "x": 96, "y": BAND[0] - 46},
             {"type": "label", "text": "去后厅", "x": SOUTH_X + 96, "y": 950}]
    for (key, x, name) in NORTH:
        flat.append({"type": "label", "text": "去%s（待做）" % name, "x": x, "y": 150})
    mid = (BAND[0] + BAND[1]) // 2
    d = {
        "scene": "scene_luoman_plaza",
        "title": "喷泉广场",
        "note": "罗曼山庄 · 喷泉雕塑广场灰盒（蓝图 v0.3 第 1.0 节新总图第 ② 步，阿鱼 10/4「行」；01 F 派）。tools/layout_court/make_plaza.py 生成，别手改；"
                "改数重跑，再跑 gen_specs_court.py --scene plaza。正中喷泉雕塑，四周一圈矮绿篱、四棵大树、四个花坛、路灯、长椅；"
                "东口去迎宾院（新总图的迎宾厅，现在的迎宾院先当迎宾厅用），西口去草坪，南口去后厅走廊；北边三个口（儿童乐园、小卖部、休息区）还没做："
                "路口拦着、挂「待做」牌，走过去说一句还在布置（话在 assets/plaza/lines.json）。from_* 是从各处过来站的地方。全部色块占位，阿鱼挑过摆法再画",
        "size": [W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": [1430, mid],
        "from_court": [1430, mid],
        "from_lawn": [106, mid],
        "from_backhall": [SOUTH_X, 920],
        "points": [
            {"id": "to_court", "x": 1500, "y": mid, "r": 44},
            {"id": "to_lawn", "x": 36, "y": mid, "r": 44},
            {"id": "to_backhall", "x": SOUTH_X, "y": 990, "r": 44},
        ] + [{"id": "north_%s" % key, "x": x, "y": 110, "r": 44} for (key, x, _) in NORTH],
        "walk": [
            [[PAVE[0], PAVE[1]], [PAVE[2], PAVE[1]], [PAVE[2], PAVE[3]], [PAVE[0], PAVE[3]]],                         # 广场
            [[PAVE[2], BAND[0]], [W - 4, BAND[0]], [W - 4, BAND[1]], [PAVE[2], BAND[1]]],                             # 东口
            [[4, BAND[0]], [PAVE[0], BAND[0]], [PAVE[0], BAND[1]], [4, BAND[1]]],                                     # 西口
            [[SOUTH_X - STUB, PAVE[3]], [SOUTH_X + STUB, PAVE[3]], [SOUTH_X + STUB, H - 8], [SOUTH_X - STUB, H - 8]],  # 南口
        ] + [[[x - STUB, 86], [x + STUB, 86], [x + STUB, PAVE[1]], [x - STUB, PAVE[1]]] for (_, x, _) in NORTH],         # 北边三个口（走到施工栏前）
        "flat": flat,
        "items": items,
        "npcs": [],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("{\n")
        keys = list(d.keys())
        for i, k in enumerate(keys):
            v = d[k]
            comma = "," if i < len(keys) - 1 else ""
            if isinstance(v, list) and v and isinstance(v[0], dict):
                f.write(' "%s": [\n' % k)
                for j, x in enumerate(v):
                    f.write("  " + json.dumps(x, ensure_ascii=False) + ("," if j < len(v) - 1 else "") + "\n")
                f.write(" ]%s\n" % comma)
            else:
                f.write(' "%s": %s%s\n' % (k, json.dumps(v, ensure_ascii=False), comma))
        f.write("}\n")
    ids = [i["id"] for i in items]
    dup = sorted({x for x in ids if ids.count(x) > 1})
    if dup:
        raise SystemExit("id 重了：%s" % dup)
    print("写了 %s：%d 件、%d 块平铺" % (OUT, len(items), len(flat)))


if __name__ == "__main__":
    main()
