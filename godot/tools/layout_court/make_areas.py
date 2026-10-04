#!/usr/bin/env python3
"""罗曼山庄连图新加的几块灰盒（01 G 10/4 派，godot/回执/派活-连图灰盒-1004.md；蓝图 v0.3 第 1.0 节）：
儿童乐园、小卖部、休息厅 2（放一张台球桌；10/4 阿鱼定叫「休息厅 2」）、西餐厨房、后花园、前门（「罗曼山庄」门楼、气球拱门从停车场挪过来）、后门。
每块出一份 assets/layered/scene_luoman_<名字>/layout.json（scripts/area.gd 读）。改摆法只改这份的数、重跑，别手改 json；再跑 gen_specs_court.py --scene <名字>。

10/4 方案 C（阿鱼「行，C」，godot/回执/方向方案C-上下翻-1004.png）：游戏里各块照阿鱼 10/4 那张图「只上下翻、左右不变」摆——前门在最南、湖和小山在最北、草坪在西；
宴会厅西侧门通后厅、东侧门通后花园，后厅西→东是中餐厨房、麻将室、休息室、化妆间（第 64 版是整张图转半圈，东西跟现在对调）。
每个口「从这边出去、从对面那边进来」都对得上。各口通哪写在点的 to 里（main.gd 照这个切），从对面过来站哪不写，照口往里走 70 像素。
全部色块占位，里面能走，走进去说一句还在布置（话在 assets/areas/lines.json，待校对）。比例照 ASSETS §15：左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素，人 84。
用法：python3 godot/tools/layout_court/make_areas.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
STUB = 36          # 口半宽（路宽 72 ≈ 1.5 米）
EDGE = 60          # 能走的范围离画布边多远（边上一圈墙 / 绿篱）


def box(id_, rect, h, top, front, **kw):
    it = {"type": "box", "id": id_, "rect": [int(v) for v in rect], "h": int(h), "top": top, "front": front}
    it.update(kw)
    return it


def cyl(id_, x, y, rx, ry, h, top, front, **kw):
    it = {"type": "cyl", "id": id_, "x": x, "y": y, "rx": rx, "ry": ry, "h": h, "top": top, "front": front}
    it.update(kw)
    return it


def tree(id_, x, y, **kw):
    it = {"type": "tree", "id": id_, "x": x, "y": y, "trunk": "#6d4a38", "leaf": "#4f7a4a", "leaf2": "#6a9a5c", "h": 264, "w": 180}
    it.update(kw)
    return it


def area(key, title, size, ground, wall, exits, items, extra_points=(), extra_flat=(), signs=(), note=""):
    """一块灰盒：四边一圈墙（wall 颜色），exits 留口：(边 N/S/W/E, 沿边位置, 通哪块, 牌子上的字, via)；
    via 是到了对面站在对面哪个口里边（对面有两个口通这块时才写）"""
    W, H = size
    inner = (EDGE, EDGE, W - EDGE, H - EDGE)
    flat = [{"type": "rect", "rect": [0, 0, W, H], "color": "#5f8f55"},
            {"type": "rect", "rect": list(inner), "color": ground}]
    walk = [[[inner[0], inner[1]], [inner[2], inner[1]], [inner[2], inner[3]], [inner[0], inner[3]]]]
    points, gaps = [], {"N": [], "S": [], "W": [], "E": []}
    for (side, at, to, label, via) in exits:
        if side == "N":
            r, pt, lab = [at - STUB, 0, at + STUB, inner[1]], (at, 36), (at, 128)
        elif side == "S":
            r, pt, lab = [at - STUB, inner[3], at + STUB, H], (at, H - 36), (at + 96, H - 100)
        elif side == "W":
            r, pt, lab = [0, at - STUB, inner[0], at + STUB], (36, at), (110, at - 56)
        else:
            r, pt, lab = [inner[2], at - STUB, W, at + STUB], (W - 36, at), (W - 110, at - 56)
        flat.append({"type": "rect", "rect": r, "color": "#c2b393"})
        walk.append([[r[0] + 2, r[1] + 2], [r[2] - 2, r[1] + 2], [r[2] - 2, r[3] - 2], [r[0] + 2, r[3] - 2]])
        gaps[side].append((at - STUB, at + STUB))
        p = {"id": "to_" + to, "x": pt[0], "y": pt[1], "r": 44, "to": to}
        if side == "N" and abs(at - W // 2) < 40 and any(abs(float(sg["x"]) - at) < 80 for sg in signs):
            # 北口正对着门口名字牌（小卖部、休息厅 2、西餐厨房）：从口进来站到牌子右边一点，别挡住牌子（03 复核第 69 版；地图传送也落在这）
            p["arrive"] = [at + 96, inner[1] + 64]
        if via:
            p["via"] = via     # 对面那块从哪个口过来站（对面有两个口通这块时才写）
        points.append(p)
        if label:
            flat.append({"type": "label", "text": label, "x": lab[0], "y": lab[1]})
    # 四边的墙（留口）
    for side in "NSWE":
        cuts = sorted(gaps[side])
        a, b = (0, W) if side in "NS" else (0, H)
        x = a
        k = 0
        for (g0, g1) in cuts + [(b, b)]:
            if g0 - x > 8:
                if side == "N":
                    r = [x, inner[1] - 14, g0, inner[1]]
                elif side == "S":
                    r = [x, inner[3], g0, inner[3] + 14]
                elif side == "W":
                    r = [inner[0] - 14, x, inner[0], g0]
                else:
                    r = [inner[2], x, inner[2] + 14, g0]
                kw = {"part": "AR-W01"}
                if k == 0 and side == "N":
                    kw["scale"] = {"h_m": 1.2, "name": "围墙 / 绿篱"}
                items.append(box("wall_%s_%d" % (side.lower(), k), r, 58, wall[0], wall[1], **kw))
                k += 1
            x = g1
    flat += list(extra_flat)
    points += list(extra_points)
    cx, cy = W // 2, H // 2
    d = {
        "scene": "scene_luoman_" + key,
        "title": title,
        "note": "罗曼山庄 · %s灰盒（连图，01 G 10/4 派）。tools/layout_court/make_areas.py 生成，别手改；改数重跑，再跑 gen_specs_court.py --scene %s。%s"
                "口写了 to 的走进去就到那块（main.gd），from 那块过来站在口里边 70 像素；写了 say 的走进去说一句。全部色块占位，阿鱼挑过摆法再画" % (title, key, note),
        "size": [W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": [cx, cy + 120],
        "points": points,
        "walk": walk,
        "flat": flat,
        "items": items,
        "npcs": [],
    }
    if signs:
        d["signs"] = list(signs)
    out = os.path.join(GODOT, "assets", "layered", "scene_luoman_" + key, "layout.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
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
        raise SystemExit("%s id 重了：%s" % (key, dup))
    print("写了 %s：%d 件、%d 个口" % (out, len(items), len([p for p in points if p.get("to")])))


def wip(key, x, y, r=120):
    """走进去说一句还在布置的那个点（块正中）"""
    return {"id": "wip", "x": x, "y": y, "r": r, "say": key + "_wip"}


def main():
    HEDGE = ("#5f8f4e", "#3f6a3f")
    WALL = ("#d8cdb8", "#b8ab92")
    S = (1152, 1024)
    # ---- 儿童乐园：北边两个口（东去喷泉广场、西去草坪），东去小卖部（10/4 方案 C：照阿鱼图只上下翻，东西跟第 64 版对调）
    items = [box("slide", [700, 360, 840, 400], 110, "#e8742a", "#c0582a", scale={"h_m": 2.3, "w_m": 2.9, "name": "滑梯"}, part="KD-P01"),
             box("swing_frame", [260, 420, 420, 432], 120, "#4a6fa5", "#2e4a7a", scale={"h_m": 2.5, "name": "秋千架"}, part="KD-P02"),
             cyl("sandpit", 380, 720, 130, 56, 10, "#e6d29a", "#c8b47c", scale={"w_m": 5.4, "name": "沙坑"}, part="KD-P03"),
             cyl("seesaw", 820, 680, 90, 14, 30, "#d9534f", "#b03a37", scale={"w_m": 3.75, "name": "跷跷板"}, part="KD-P04"),
             box("bench_k", [520, 880, 592, 890], 22, "#c19a68", "#8c5f3c", part="KD-P05")]
    area("kids", "儿童乐园", S, "#cfe3a8", HEDGE,
         [("N", 772, "plaza", "去喷泉广场", None), ("N", 292, "lawn", "去草坪", None), ("E", 560, "shop", "去小卖部", None)],
         items, [wip("kids", 576, 600)], note="北边东口去喷泉广场、北边西口去草坪、东口去小卖部；",
         signs=[{"text": "儿童乐园", "x": 576, "y": 96}])
    # ---- 小卖部：北去喷泉广场，东去休息厅 2，西去儿童乐园
    items = [box("counter", [440, 360, 712, 400], 52, "#c19a68", "#8c5f3c", scale={"h_m": 1.1, "w_m": 5.7, "name": "柜台"}, part="SH-P01"),
             box("shelf_1", [300, 220, 520, 236], 96, "#a07850", "#7a5a3a", scale={"h_m": 2.0, "name": "货架"}, part="SH-P02"),
             box("shelf_2", [632, 220, 852, 236], 96, "#a07850", "#7a5a3a", part="SH-P02"),
             box("fridge", [880, 300, 940, 330], 96, "#e8eef2", "#b8c2c8", scale={"h_m": 2.0, "name": "冰柜"}, part="SH-P03")]
    area("shop", "小卖部", S, "#e2d6b8", WALL,
         [("N", 576, "plaza", "去喷泉广场", None), ("E", 560, "rest2", "去休息厅 2", None), ("W", 560, "kids", "去儿童乐园", None)],
         items, [wip("shop", 576, 600)], note="北口去喷泉广场、东口去休息厅 2、西口去儿童乐园；以后接「送人说句话」；",
         signs=[{"text": "小卖部", "x": 576, "y": 96}])
    # ---- 休息厅 2：北去喷泉广场，西去小卖部；一张台球桌（阿鱼：「你可以在这里加一个台球桌吧」）
    items = [box("pool_table", [516, 470, 636, 515], 38, "#2f7a4a", "#6d4a38", scale={"w_m": 2.5, "h_m": 0.8, "name": "台球桌"}, part="R2-P01"),
             box("sofa_r2", [240, 260, 400, 290], 41, "#c8b8a0", "#a89880", scale={"w_m": 3.3, "name": "沙发"}, part="R2-P02"),
             box("tea_r2", [270, 330, 370, 350], 22, "#a07850", "#7a5a3a", part="R2-P03"),
             box("cue_rack", [760, 230, 790, 240], 72, "#8c5f3c", "#6d4a38", scale={"h_m": 1.5, "name": "球杆架"}, part="R2-P04"),
             box("plant_r2", [880, 760, 904, 772], 60, "#5f8f4e", "#3f6a3f", part="R2-P05")]
    area("rest2", "休息厅 2", S, "#e9dcc0", WALL,
         [("N", 576, "plaza", "去喷泉广场", None), ("W", 560, "shop", "去小卖部", None), ("E", 560, "frontgate", "去前门", None)],
         items, [wip("rest2", 576, 640)], note="北口去喷泉广场、西口去小卖部、东口去前门（第 68 版前门挪到喷泉正下方，跟休息厅 2 挨着）；台球桌先摆色块占位置，能不能打以后再说；",
         signs=[{"text": "休息厅 2", "x": 576, "y": 96}])
    # ---- 西餐厨房：北去后厅走廊（中餐厨房那头），东去喷泉广场，西去草坪
    items = [box("island", [420, 460, 732, 520], 44, "#d8dde0", "#a8b0b4", scale={"h_m": 0.9, "w_m": 6.5, "name": "中岛操作台"}, part="WK-P01"),
             box("oven", [220, 220, 330, 240], 72, "#3a3a40", "#26262a", scale={"h_m": 1.5, "name": "烤箱"}, part="WK-P02"),
             box("fridge_w", [820, 220, 900, 240], 96, "#e8eef2", "#b8c2c8", part="WK-P03"),
             box("table_w", [500, 760, 652, 800], 36, "#f4f1ea", "#d8d2c4", scale={"w_m": 3.2, "name": "餐桌"}, part="WK-P04")]
    area("wkitchen", "西餐厨房", S, "#e8e4dc", WALL,
         [("N", 576, "backhall", "去后厅", None), ("E", 560, "plaza", "去喷泉广场", None), ("W", 560, "lawn", "去草坪", None)],
         items, [wip("wkitchen", 576, 640)], note="北口去后厅走廊（中餐厨房那头）、东口去喷泉广场、西口去草坪；做什么用待讨论；",
         signs=[{"text": "西餐厨房", "x": 576, "y": 96}])
    # ---- 后花园：西去宴会厅（东门），北去湖边（东头月亮门），南去停车场
    G = (1536, 1024)
    items = [tree("tree_g%d" % k, x, y, **({"scale": {"h": "tree_h"}} if k == 0 else {})) for k, (x, y) in enumerate([(260, 300), (1276, 300), (260, 820), (1276, 820)])]
    items += [cyl("bed_g%d" % k, x, y, 70, 26, 24, "#e9a6c0", "#7fa85c", part="GD-P02", **({"scale": {"w_m": 2.9, "name": "花坛"}} if k == 0 else {}))
              for k, (x, y) in enumerate([(560, 360), (980, 360), (560, 700), (980, 700)])]
    items += [box("gazebo_post_%d" % k, [x - 5, y - 5, x + 5, y + 5], 110, "#f2efe6", "#d8d4c8", part="GD-P03",
                  **({"scale": {"h_m": 2.3, "name": "白色凉亭柱"}} if k == 0 else {})) for k, (x, y) in enumerate([(700, 500), (836, 500), (700, 600), (836, 600)])]
    area("garden", "后花园", G, "#a9d08a", HEDGE,
         [("W", 512, "banquet", "去宴会厅", None), ("N", 796, "lake", "去湖边", None), ("S", 768, "parking", "去停车场", None)],
         items, [wip("garden", 768, 760, 100)], note="西口去宴会厅（宴会厅东门）、北口去湖边（湖边东头月亮门）、南口去停车场；",
         signs=[{"text": "后花园", "x": 1116, "y": 96}])
    # ---- 前门：门楼「罗曼山庄」、气球拱门从停车场挪过来；南边是山庄外头的路
    # 第 68 版（07，阿鱼：前门「挪到正对着喷泉」）：前门挪到喷泉广场正下方，北口直通广场南边正中（车进门直直往上开就看见喷泉）；
    # 西边挨着休息厅 2、东边挨着停车场（停车场往西放大补上原来前门那块）。原来北口去迎宾院不要了：迎宾院南边的大门改通停车场
    F = (1536, 1024)
    gx0, gx1, gy = 696, 840, 700        # 门洞左右、门楼墙脚
    items = [box("gate_post_w", [gx0 - 32, gy - 20, gx0, gy], 168, "#a83a30", "#8c2f27", scale={"h_m": 3.5, "w_m": 0.67, "name": "门楼门柱"}, part="PK-W02"),
             box("gate_post_e", [gx1, gy - 20, gx1 + 32, gy], 168, "#a83a30", "#8c2f27", part="PK-W02"),
             {"type": "beam", "id": "gate_roof", "x0": gx0 - 56, "x1": gx1 + 56, "top": gy - 238, "thick": 34, "foot": gy + 1, "color": "#6e2420",
              "scale": {"w_m": 5.6, "name": "门楼门头（瓦顶）"}, "part": "PK-W02"},
             {"type": "beam", "id": "gate_lintel", "x0": gx0 - 40, "x1": gx1 + 40, "top": gy - 204, "thick": 24, "foot": gy + 1, "color": "#a83a30", "part": "PK-W02"},
             box("arch_post_w", [gx0 - 10, gy - 140, gx0 + 2, gy - 132], 130, "#f4a6c0", "#e07a9a",
                 scale={"h_m": 3.0, "w_m": 3.5, "group": ["arch_post_e", "arch_top"], "name": "气球拱门"}, part="PK-P06"),
             box("arch_post_e", [gx1 - 2, gy - 140, gx1 + 10, gy - 132], 130, "#f4a6c0", "#e07a9a", part="PK-P06"),
             {"type": "beam", "id": "arch_top", "x0": gx0 - 10, "x1": gx1 + 10, "top": gy - 278, "thick": 22, "foot": gy - 131, "color": "#fbe3ea", "part": "PK-P06"},
             box("guard", [476, 600, 556, 640], 110, "#e8e0d0", "#c8bca8", scale={"h_m": 2.3, "name": "门卫亭"}, part="FG-P01"),
             box("gatewall_w", [EDGE, gy - 14, gx0 - 32, gy], 58, "#c8b08a", "#a08a68", scale={"h_m": 1.2, "name": "院墙"}, part="PK-W01"),
             box("gatewall_e", [gx1 + 32, gy - 14, F[0] - EDGE, gy], 58, "#c8b08a", "#a08a68", part="PK-W01")]
    road = [{"type": "rect", "rect": [gx0, EDGE, gx1, F[1]], "color": "#8a8580"},
            {"type": "rect", "rect": [EDGE, 470, F[0] - EDGE, 600], "color": "#8a8580"}]
    out = {"id": "out", "x": (gx0 + gx1) // 2, "y": F[1] - 40, "r": 50, "say": "frontgate_out"}
    area("frontgate", "前门", F, "#a9c88a", HEDGE,
         [("N", 768, "plaza", "去喷泉广场", None), ("W", 536, "rest2", "去休息厅 2", None), ("E", 536, "parking", "去停车场", None)],
         items, [out], extra_flat=road, note="北口直通喷泉广场南边正中（第 68 版：正对喷泉）、西口去休息厅 2、东口去停车场；南边门楼外头是来山庄的路，开车进来从这进（drive_in.gd 自动开车：直直往上开进广场），走路出不去；",
         signs=[{"text": "罗曼山庄", "x": 768, "y": gy - 214, "foot": gy + 2}])
    # 前门南边门洞要能走到画布外头那条边上（走到头说「去停车场开车出去」）
    _open_south("frontgate", gx0, gx1)
    # ---- 后门：南去果园（果园 B 北口），北边门外是小山（这次不做，走到门口说一句）
    items = [box("backgate_post_w", [500, 220, 532, 240], 140, "#8c5f3c", "#6d4a38", scale={"h_m": 2.9, "name": "后门门柱"}, part="BG-W01"),
             box("backgate_post_e", [620, 220, 652, 240], 140, "#8c5f3c", "#6d4a38", part="BG-W01")]
    hill = [{"type": "rect", "rect": [0, 0, S[0], EDGE], "color": "#7a8a6a"}]
    area("backgate", "后门", S, "#c9c2b0", WALL,
         [("S", 576, "orchard", "去果园", None)],
         items, [{"id": "out", "x": 576, "y": 260, "r": 50, "say": "backgate_out"}], extra_flat=hill,
         note="南口去果园（果园 B 北边那个口）；北边门外是小山，这次不做，走到门口说一句；",
         signs=[{"text": "后门", "x": 576, "y": 120}])


def _open_south(key, x0, x1):
    """前门：门洞往南一直能走到画布底边（门外的路），走到底说一句"""
    out = os.path.join(GODOT, "assets", "layered", "scene_luoman_" + key, "layout.json")
    d = json.load(open(out, encoding="utf-8"))
    W, H = d["size"]
    d["walk"].append([[x0 + 4, H - EDGE - 2], [x1 - 4, H - EDGE - 2], [x1 - 4, H - 6], [x0 + 4, H - 6]])
    d["items"] = [it for it in d["items"] if not (str(it["id"]).startswith("wall_s_") and it["rect"][0] < x1 and it["rect"][2] > x0)]
    # 南墙在门洞那截断开
    rest = []
    for it in d["items"]:
        rest.append(it)
    sw = [it for it in d["items"] if str(it["id"]).startswith("wall_s_")]
    if not sw:
        d["items"].append(box("wall_s_0", [0, H - EDGE, x0, H - EDGE + 14], 58, "#5f8f4e", "#3f6a3f", part="AR-W01"))
        d["items"].append(box("wall_s_1", [x1, H - EDGE, W, H - EDGE + 14], 58, "#5f8f4e", "#3f6a3f", part="AR-W01"))
    with open(out, "w", encoding="utf-8") as f:
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


if __name__ == "__main__":
    main()
