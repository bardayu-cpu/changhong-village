#!/usr/bin/env python3
"""喷泉雕塑广场 · 灰盒（蓝图 v0.3 第 1.0 节「新总图」第 ② 步，阿鱼 10/4「行」；01 F 派）。
出 assets/layered/scene_luoman_plaza/layout.json（scripts/plaza.gd 读它）。改摆法只改这份的数、重跑，别手改 json；再跑 gen_specs_court.py --scene plaza。
参考图：docs/参考图/罗曼山庄布局参考-阿鱼10-04.png（阿鱼画的相对位置，不是比例图）。

山庄正中一块空地，正中一座喷泉雕塑，四周是通各处的路口（方位照参考图）：
  东口 → 迎宾院（新总图叫迎宾厅/签到处，现在的迎宾院先当迎宾厅用）、前门
  西口 → 草坪、西餐厨房
  北口 → 后厅走廊（中餐厨房、麻将室、休息室、化妆间那一排）
  南边三个口 → 儿童乐园、小卖部、休息厅 2（灰盒，走进去说一句还在布置）
  （10/4 方案 C：照阿鱼图只上下翻、左右不变）
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
STUB = 36                         # 路口半宽（路宽 72 ≈ 1.5 米）
# 10/4 方案 C（阿鱼「行，C」）：游戏里各块照阿鱼图「只上下翻、左右不变」摆，广场的口跟着改（第 64 版东西对调）：
#   北：后厅走廊；南：儿童乐园、小卖部、休息厅 2（西→东）；东：迎宾院、前门；西：草坪、西餐厨房（边, 沿边位置, 通哪, 牌子）
# 10/4 第 68 版（07，阿鱼：「进山庄如果是这样的话那你的前门就要挪到正对着喷泉了，不然没有人会去故意绕一下」「中国是绕右开」）：
#   前门挪到南边正中（x 768，正对喷泉），进门的路宽一倍（车开得进来）；车进门直直往上开 → 喷泉跟前靠右、右拐 → 东边下面那个口出去直接进停车场。
#   南边原来三个口（儿童乐园、小卖部、休息厅 2）往西挪，给前门让出正中；东边下面原来「去前门」的口改成「去停车场」，挪到 y 780 跟车道一条线
EXITS = [("N", 768, "backhall", "去后厅"),
         ("S", 330, "kids", "去儿童乐园"), ("S", 470, "shop", "去小卖部"), ("S", 610, "rest2", "去休息厅 2"), ("S", 768, "frontgate", "去前门"),
         ("E", 400, "court", "去迎宾院"), ("E", 780, "parking", "去停车场"),
         ("W", 400, "lawn", "去草坪"), ("W", 720, "wkitchen", "去西餐厨房")]
WIDE = {"frontgate": 72}          # 车走的口半宽（路宽 144 = 3 米）
DRIVE_Y = 780                     # 车道：前门进来往上开到喷泉跟前，靠右拐，沿这条往东出

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
    # ================= 地面：外面一圈草，里面石板广场，每个口一条路
    flat += [
        {"type": "rect", "rect": [0, 0, W, H], "color": "#8fbf6a"},
        {"type": "rect", "rect": list(PAVE), "color": "#d6c8a6"},
    ]
    walk = [[[PAVE[0], PAVE[1]], [PAVE[2], PAVE[1]], [PAVE[2], PAVE[3]], [PAVE[0], PAVE[3]]]]    # 广场
    points, gaps = [], {"N": [], "S": [], "W": [], "E": []}
    # 车道（第 68 版）：南边正中进门往上到喷泉跟前、右拐往东出，地上铺一条深一点的石板（不挡人，只是看得出车走哪）
    flat.append({"type": "rect", "rect": [768 - 72, CY + 140, 768 + 72, PAVE[3]], "color": "#b9ab8c"})
    flat.append({"type": "rect", "rect": [768 - 72, DRIVE_Y - 36, PAVE[2], DRIVE_Y + 36], "color": "#b9ab8c"})
    for (side, at, to, label) in EXITS:
        half = WIDE.get(to, STUB)
        if side == "N":
            r, pt, lab = [at - STUB, 0, at + STUB, PAVE[1]], (at, 36), (at + 100, 150)
        elif side == "S":
            # 南边口挨得近：牌子挂在口的正上方（广场里边），不往右偏，免得跟隔壁口的牌子叠
            # 四个口挨得近、牌子又加了箭头：错成两行（儿童乐园、休息厅 2 高一行，小卖部、前门低一行），都在进来站的人头顶上面（不被 entrance 挪）
            r, pt, lab = [at - half, PAVE[3], at + half, H], (at, H - 36), (at, 762 if to in ("kids", "rest2") else 798)
            if to == "frontgate":
                lab = (at + half + 70, 812)   # 前门那个口是车道：牌子挂到口右边，别压在车开进来的路上
        elif side == "W":
            r, pt, lab = [0, at - STUB, PAVE[0], at + STUB], (36, at), (96, at - 56)
        else:
            r, pt, lab = [PAVE[2], at - STUB, W, at + STUB], (W - 36, at), (W - 110, at - 56)
        flat.append({"type": "rect", "rect": r, "color": "#c2b393"})
        # 路口那条能走的范围往广场里多伸 4 像素，跟广场接上（原来从广场边往外 2 像素才开始，中间一条 2 像素的缝；第 68 版车走南口时测出来）
        wr = [r[0] + 2, r[1] + 2, r[2] - 2, r[3] - 2]
        if side == "S":
            wr[1] = r[1] - 4
        elif side == "N":
            wr[3] = r[3] + 4
        elif side == "W":
            wr[2] = r[2] + 4
        else:
            wr[0] = r[0] - 4
        walk.append([[wr[0], wr[1]], [wr[2], wr[1]], [wr[2], wr[3]], [wr[0], wr[3]]])
        gaps[side].append((at - half, at + half))
        points.append({"id": "to_" + to, "x": pt[0], "y": pt[1], "r": 44, "to": to})
        flat.append({"type": "label", "text": label, "x": lab[0], "y": lab[1]})
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
    for k, (tx, ty) in enumerate([(260, 300), (1276, 300), (260, 860), (1276, 860)]):
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
    items += hedge_run("hedge_n", PAVE[0], PAVE[2], PAVE[1] - 14, True, gaps["N"])
    items += hedge_run("hedge_s", PAVE[0], PAVE[2], PAVE[3], True, gaps["S"])
    items += hedge_run("hedge_w", PAVE[1], PAVE[3], PAVE[0] - 14, False, gaps["W"])
    items += hedge_run("hedge_e", PAVE[1], PAVE[3], PAVE[2], False, gaps["E"])
    d = {
        "scene": "scene_luoman_plaza",
        "title": "喷泉广场",
        "note": "罗曼山庄 · 喷泉雕塑广场灰盒（蓝图 v0.3 第 1.0 节新总图；10/4 连图 01 G 派改口）。tools/layout_court/make_plaza.py 生成，别手改；"
                "改数重跑，再跑 gen_specs_court.py --scene plaza。正中喷泉雕塑，四周一圈矮绿篱、四棵大树、四个花坛、路灯、长椅；"
                "方案 C 照阿鱼图只上下翻：北口后厅走廊，南边儿童乐园、小卖部、休息厅 2、前门（第 68 版挪到正中，正对喷泉），东边迎宾院、停车场（第 68 版：原来去前门），西边草坪、西餐厨房。"
                "口写了 to 的走进去就到那块（main.gd），从那块过来站在口里边 70 像素。全部色块占位，阿鱼挑过摆法再画",
        "size": [W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": [W - 110, 400],      # 从迎宾院过来站的地方（东口里边）
        "points": points,
        "walk": walk,
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
