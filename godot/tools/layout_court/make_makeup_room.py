#!/usr/bin/env python3
"""化妆间单独成一间屋 · 灰盒三档（01 H 10/4 派；玩家说明 docs/进屋像进宴会厅-玩家说明-v0.1.md v0.2 第 1、4 节，蓝图 1.0「房间放大」）。
阿鱼原话：「没进入一个房间应该是和进入宴会厅一样是一个沉浸式的感觉」「之前的房屋太小了吧是不是得和宴会厅一样叠加更多的同样 d 元素」。
后厅走廊走到化妆间门口，整屏换成这间屋（跟进宴会厅一样）；从南边门口出去回到走廊化妆间门口。

出 assets/layered/scene_luoman_makeup/layout.json（scripts/area.gd 读，跟连图那几块灰盒一个搭法）。全部色块占位，阿鱼挑一档再照灰盒用代码画。
画布 576 × 1024：灰盒画布镜头缩到 0.9375，手机屏正好看一整间（一个手机屏宽，约原来那间 321 宽的 1.8 倍），镜头一次看一间。
家具照阿鱼点过头的第二版（化妆台连拱形镜、中式/西式/日式/民族衣架、首饰中岛、婚纱人台、全身镜、等候沙发……），
像宴会厅摆 55 桌那样同一类多摆几份；三档（少、中、多）每类几件见 TIERS，回执照 --counts 打印的表写。
过道都留 ≥ 72 像素（1.5 米，6 格）：03 报过原来首饰中岛两边只有一格宽、人站进去像站进衣架（回执 测-makeup01-02d.md 第三节）。
人：原来化妆间的新娘、两位化妆师照旧（替身站位跟原来一样的相对位置）；多出来的座位、试衣的人放粉色色块（PERSON），不画新人。
给 07 留的位置（进门招呼、递东西归 07）写在 stand_points：化妆师站哪、递东西在哪。
阿鱼 10/4 在 02 窗口挑了「多」档（「喜欢最多的那个，最右边」），游戏里用「多」。
用法：python3 godot/tools/layout_court/make_makeup_room.py [--tier=少|中|多]（不给是「多」）[--counts]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_makeup", "layout.json")

W, H = 576, 1024
WALL_FOOT = 210          # 北墙脚（靠墙的东西着地在这）
FLOOR = (28, 214, 548, 952)
DOOR = (252, 324)        # 南墙门洞（左右）
SOUTH = 960              # 南边矮墙
AISLE = 72               # 过道至少多宽

# 三档：每类摆几件（同一类多摆几份）
TIERS = {
    "少": {"vanity": 3, "rack": 4, "island": 1, "gown": 1, "mirror": 1, "sofa": 1, "closet": 2, "crown": 1, "person": 1},
    "中": {"vanity": 5, "rack": 6, "island": 2, "gown": 2, "mirror": 2, "sofa": 2, "closet": 2, "crown": 2, "person": 4},
    "多": {"vanity": 6, "rack": 8, "island": 3, "gown": 3, "mirror": 3, "sofa": 2, "closet": 2, "crown": 2, "person": 8},
}
NAMES = {"vanity": "明星化妆台（连墙上拱形灯泡镜、化妆凳）", "rack": "衣架（中式、西式、日式、民族轮着摆）",
         "island": "首饰中岛", "gown": "婚纱人台", "mirror": "落地全身镜", "sofa": "等候沙发", "closet": "开放衣墙（中式、西式各一）",
         "crown": "头冠架（凤冠、苗族银角）", "person": "多出来的人（粉色色块，不画新人）"}
PERSON = ("#f2a7c3", "#d97aa0")   # 「人」的色块


def box(id_, rect, h, top, front, **kw):
    it = {"type": "box", "id": id_, "rect": [int(v) for v in rect], "h": int(h), "top": top, "front": front}
    it.update(kw)
    return it


def person(id_, x, foot, sitting=False):
    """一个人占的地方：色块（站着 84 高、坐着 60 高），不挡路（block=false），只给阿鱼看人多不多"""
    h = 60 if sitting else 84
    return box(id_, [x - 12, foot - 8, x + 12, foot], h, PERSON[0], PERSON[1], block=False, scale={"name": "人（色块占位）"}, part="MK-PERSON")


def build(tier):
    t = TIERS[tier]
    items, flat, npcs, stands = [], [], [], []
    # ---- 地面、墙（灰盒色）
    flat += [{"type": "rect", "rect": [0, 0, W, H], "color": "#2e211b"},
             {"type": "rect", "rect": [0, 0, W, 196], "color": "#e7d9c8"},          # 北墙墙面
             {"type": "rect", "rect": [0, 150, W, 196], "color": "#c9a985"},        # 护墙板
             {"type": "rect", "rect": [24, 196, W - 24, SOUTH], "color": "#e3cfc0"},  # 地板（跟原来化妆室一个色）
             {"type": "rect", "rect": [0, 0, 24, H], "color": "#6b4a36"}, {"type": "rect", "rect": [W - 24, 0, W, H], "color": "#6b4a36"},
             {"type": "rect", "rect": [DOOR[0], SOUTH, DOOR[1], H], "color": "#b39b7c"},   # 门口往外一截（走廊那头）
             {"type": "label", "text": "回后厅", "x": DOOR[1] + 52, "y": 996},                    # 南门外的「去…」牌（地上木牌，游戏里的字）
             ]
    items += [box("wall_s_0", [24, SOUTH, DOOR[0], SOUTH + 14], 40, "#8a6048", "#5a3f30", part="MK-W01", scale={"h_m": 0.8, "name": "前沿矮墙"}),
              box("wall_s_1", [DOOR[1], SOUTH, W - 24, SOUTH + 14], 40, "#8a6048", "#5a3f30", part="MK-W01")]
    # ---- 北墙一排：两头开放衣墙，中间化妆台（每台墙上一面拱形灯泡镜、前面一张化妆凳）
    x = 30
    items.append(box("closet_cn", [x, WALL_FOOT - 14, x + 62, WALL_FOOT], 98, "#b04a3a", "#7a2e24", part="BH-P15", scale={"name": "中式开放衣墙"}))
    items.append(box("closet_west", [W - 30 - 66, WALL_FOOT - 14, W - 30, WALL_FOOT], 98, "#e8e0d4", "#c9bfb0", part="BH-P16", scale={"name": "西式开放衣墙"}))
    n = t["vanity"]
    span0, span1 = 30 + 62 + 8, W - 30 - 66 - 8
    step = (span1 - span0) / n
    vx = []
    for k in range(n):
        cx = int(span0 + step * (k + 0.5))
        vx.append(cx)
        items.append(box("mirror_%d" % k, [cx - 22, 186, cx + 22, 190], 118, "#fff6d8", "#d4af37", part="MK-P01",
                         **({"scale": {"name": "拱形灯泡镜（挂墙上）"}} if k == 0 else {})))
        items.append(box("vanity_%d" % k, [cx - 28, WALL_FOOT - 18, cx + 28, WALL_FOOT], 36, "#f4ead2", "#c9b28f", part="BH-T01",
                         **({"scale": {"name": "明星化妆台"}} if k == 0 else {})))
        items.append(box("stool_%d" % k, [cx - 9, WALL_FOOT + 18, cx + 9, WALL_FOOT + 28], 22, "#f4ead2", "#c9b28f", part="BH-P03",
                         **({"scale": {"name": "化妆凳"}} if k == 0 else {})))
    # 新娘坐中间那台（照原来：新娘坐第 2 台背对镜头、化妆师 1 站她右手边）；别的台前坐人色块（多出来的座位）
    bride_k = n // 2
    bx = vx[bride_k]
    npcs.append({"id": "bride", "who": "新娘（坐在中间化妆台前，背对镜头；替身）", "x": bx, "y": WALL_FOOT + 59, "face": "up", "sit": True, "lm": "LM-BRIDE-01",
                 "standin": {"code": "LM-GUEST-02", "frame": 12, "rows": 60, "bottom": WALL_FOOT + 42}})
    npcs.append({"id": "makeup_1", "who": "化妆师", "x": bx + 26, "y": WALL_FOOT + 63, "face": "left", "look": "makeup_1", "lm": "LM-MAKEUP-01",
                 "standin": {"code": "LM-GUEST-03", "frame": 4}})
    stands.append({"id": "makeup_artist_1", "name": "化妆师 1 站这（给新娘化妆，新娘右手边）", "x": bx + 26, "y": WALL_FOOT + 63, "r": 14})
    persons = 0
    seats = [k for k in range(n) if k != bride_k]
    # ---- 衣架：西边一列、东边一列，从北往南一排一排（排距 120，中间能走）
    racks = [("rack_cn_back", 82, 90, "#b04a3a", "#7a2e24", "BH-P17", "中式后排高架"), ("rack_west_back", 90, 90, "#e8e0d4", "#c9bfb0", "BH-P20", "西式后排高架"),
             ("rack_jp_back", 90, 80, "#3a3540", "#26222b", "BH-P23", "日式黑漆衣架"), ("rack_ethnic", 76, 72, "#4a6fa5", "#2e4a7a", "BH-P27", "民族服装架")]
    # 几排衣架、几个中岛照件数在整间里摊开（不挤在上半间）
    rows_y = {2: [400, 620], 3: [330, 520, 710], 4: [330, 480, 630, 780]}[(t["rack"] + 1) // 2]
    rack_slots = []
    for k, y in enumerate(rows_y):
        rack_slots.append(("w", y))
        rack_slots.append(("e", y))
    for k in range(t["rack"]):
        side, y = rack_slots[k]
        kind = racks[k % len(racks)]
        w = kind[1]
        x0 = 30 if side == "w" else 332   # 从西到东：西列衣架 30～120、过道、中岛 196～256、过道、东列衣架 332～422、过道、贴墙一列 504～544（过道都 76）
        items.append(box("%s_%d" % (kind[0], k), [x0, y - 12, x0 + w, y], kind[2], kind[3], kind[4], part=kind[5], scale={"name": kind[6]}))
    # ---- 首饰中岛：屋子正中一条线（两边过道 ≥ 72）
    isl_y = {1: [560], 2: [440, 660], 3: [420, 580, 740]}[t["island"]]
    flat.append({"type": "rect", "rect": [170, isl_y[0] - 70, 282, isl_y[-1] + 24], "color": "#c96a6a"})   # 中岛那一列脚下一条红地毯
    for k in range(t["island"]):
        y = isl_y[k]
        items.append(box("island_%d" % k, [196, y - 28, 256, y], 40, "#d4af37", "#a8862a", part="BH-T05", **({"scale": {"name": "首饰中岛"}} if k == 0 else {})))
    iy = isl_y[0]
    npcs.append({"id": "makeup_2", "who": "化妆师", "x": 280, "y": iy + 22, "face": "left", "look": "makeup_2", "lm": "LM-MAKEUP-02",
                 "standin": {"code": "LM-GUEST-06", "frame": 8}})
    stands.append({"id": "makeup_artist_2", "name": "化妆师 2 站这（首饰中岛东南角，挑首饰）", "x": 280, "y": iy + 22, "r": 14})
    stands.append({"id": "handoff", "name": "递东西（帮化妆师递一样东西，07 做；玩家站这把东西递给化妆师 2）", "x": 226, "y": iy + 46, "r": 20})
    # ---- 东墙边：婚纱人台、落地全身镜、头冠架（贴墙一列，跟东边衣架隔一条过道）
    for k in range(t["gown"]):
        y = 330 + k * 160
        items.append(box("gown_form_%d" % k, [508, y - 14, 540, y], 82, "#e8e0d4", "#c9bfb0", part="BH-P22", **({"scale": {"name": "婚纱人台"}} if k == 0 else {})))
    for k in range(t["mirror"]):
        y = 410 + k * 160
        items.append(box("full_mirror_%d" % k, [510, y - 8, 538, y], 82, "#a83a30", "#6e2420", part="BH-P04", **({"scale": {"name": "落地全身镜"}} if k == 0 else {})))
    for k in range(t["crown"]):
        kind = [("crown_stand", 20, 74, "#b04a3a", "#7a2e24", "BH-P19", "凤冠架"), ("silver_crown", 28, 72, "#4a6fa5", "#2e4a7a", "BH-P28", "苗族银角头冠架")][k]
        x0, y = [(512, 790), (222, 846)][k]   # 凤冠架贴东墙那列最南；银角头冠架在南边等候区、屏风东边（别挡竖过道）
        items.append(box(kind[0], [x0, y - 10, x0 + kind[1], y], kind[2], kind[3], kind[4], part=kind[5], scale={"name": kind[6]}))
    # ---- 南边门口等候区：沙发、屏风、鞋架、试鞋墩、礼盒、陪嫁箱、门口一对花架
    sofas = [(40, 900), (464, 900)]
    for k in range(t["sofa"]):
        x0, y = sofas[k]
        items.append(box("sofa_%d" % k, [x0, y - 32, x0 + 72, y], 41, "#a83a30", "#6e2420", part="BH-P31", **({"scale": {"name": "等候沙发"}} if k == 0 else {})))
    items += [box("screen", [140, 836, 204, 846], 82, "#c9a46a", "#8a6a44", part="BH-P02", scale={"name": "喜鹊登梅屏风（换衣）"}),
              box("shoes", [372, 836, 414, 850], 43, "#c9a46a", "#8a6a44", part="BH-P34", scale={"name": "鞋架"}),
              box("pouf", [384, 880, 404, 892], 20, "#c9a46a", "#8a6a44", part="BH-P35", scale={"name": "试鞋圆墩"}),
              box("gifts", [140, 920, 196, 936], 36, "#c9a46a", "#8a6a44", part="BH-P36", scale={"name": "礼盒堆"}),
              box("trunk", [380, 920, 426, 936], 26, "#a83a30", "#6e2420", part="BH-P32", scale={"name": "陪嫁红木箱"}),
              box("flowers_w", [DOOR[0] - 24, 940, DOOR[0] - 4, 950], 58, "#a83a30", "#6e2420", part="BH-P33", scale={"name": "门口落地花架"}),
              box("flowers_e", [DOOR[1] + 4, 940, DOOR[1] + 24, 950], 58, "#a83a30", "#6e2420", part="BH-P33")]
    # ---- 多出来的人（色块）：先坐空化妆凳，再站衣架、中岛跟前
    spots = []
    for k in seats:
        spots.append((vx[k], WALL_FOOT + 59, True))
    spots += [(158, 476, False), (294, 600, False), (158, 640, False), (462, 476, False), (462, 700, False), (294, 790, False)]   # 都站在三条竖过道里
    for k in range(t["person"]):
        x, y, sit = spots[k]
        items.append(person("person_%d" % k, x, y, sit))
        persons += 1
    points = [{"id": "to_backhall", "x": (DOOR[0] + DOOR[1]) // 2, "y": 1000, "r": 30, "to": "backhall",
               "note": "南边门口出去回后厅走廊化妆间门口（后厅 to_makeup 那里）"}]
    walk = [[[FLOOR[0], FLOOR[1]], [FLOOR[2], FLOOR[1]], [FLOOR[2], FLOOR[3]], [FLOOR[0], FLOOR[3]]],
            [[DOOR[0] + 2, SOUTH - 10], [DOOR[1] - 2, SOUTH - 10], [DOOR[1] - 2, H - 6], [DOOR[0] + 2, H - 6]]]
    counts = {k: t[k] for k in t}
    d = {
        "scene": "scene_luoman_makeup",
        "title": "化妆间",
        "note": "罗曼山庄 · 化妆间（单独成一间屋，进门整屏换，01 H 10/4 派；玩家说明 docs/进屋像进宴会厅-玩家说明-v0.1.md v0.2）。"
                "tools/layout_court/make_makeup_room.py 生成，别手改（--tier=少/中/多 出三档，这份是「%s」档）。全部色块占位；粉色色块是多出来的人（不画新人）。"
                "原来后厅里那间化妆室还在（后厅 layout 没删），走廊化妆间门口 to_makeup 一进就换到这里。stand_points 是给 07 留的位置（化妆师站哪、递东西在哪），只记点、代码不读" % tier,
        "tier": tier,
        "tier_counts": counts,
        "size": [W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": [(DOOR[0] + DOOR[1]) // 2, 920],
        "points": points,
        "walk": walk,
        "flat": flat,
        "items": items,
        "npcs": npcs,
        "stand_points": stands,
        "stand_points_note": "给 07 留的位置（进门招呼、递东西那件小事、冒泡对话归 07）：化妆师 1、2 站哪，玩家递东西站哪。只记点，代码不读",
        # 10/4 照「多」档灰盒用代码画好的像素成品（tools/pixel_art/room_makeup.py，02 F）：铺上以后灰盒色块藏掉（挡人的占地照旧），粉色「人」色块也藏
        "pixel_art": ["res://assets/pixel_art/makeup_room/room.json"] if tier == "多" else [],
    }
    return d, counts


def main():
    tier = "多"   # 阿鱼 10/4 挑定
    for a in sys.argv[1:]:
        if a.startswith("--tier="):
            tier = a.split("=", 1)[1]
    d, counts = build(tier)
    ids = [i["id"] for i in d["items"]]
    dup = sorted({x for x in ids if ids.count(x) > 1})
    if dup:
        raise SystemExit("id 重了：%s" % dup)
    if "--counts" in sys.argv:
        print("| 类 | " + " | ".join(TIERS) + " |")
        print("| --- | " + " | ".join("---" for _ in TIERS) + " |")
        for k in TIERS["中"]:
            print("| %s | %s |" % (NAMES[k], " | ".join(str(TIERS[tt][k]) for tt in TIERS)))
        return
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
    print("写了 %s：「%s」档 %d 件 %s" % (OUT, tier, len(d["items"]), counts))


if __name__ == "__main__":
    main()
