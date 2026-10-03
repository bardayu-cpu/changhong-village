#!/usr/bin/env python3
"""湖边 · 长湖岸灰盒（阿鱼 10/3：湖边做成一条往左延伸的长湖岸，东头照效果图 2、西头照左右翻转的效果图 1，从西头月亮门出去进停车场；01 F 派）。
出 assets/layered/scene_luoman_lake/layout.json（scripts/lake.gd 读它）。改摆法只改这份的数、重跑，别手改 json；再跑 gen_specs_court.py --scene lake。
参考图（只学布局和样子，透视、颗粒都跟游戏不一样）：docs/参考图/湖边效果图2-月亮门曲桥-阿鱼10-03.png（东头）、
  docs/参考图/湖边效果图1-左右翻转-湖尽头-阿鱼10-03.png（西头）。

一块画布拉宽成 3072 × 1280（东西两半各 1536，跟原来一块一样宽），一条湖岸从东走到西，中间不切画布：
  北边 y 0～312 是对岸远景（不能走），y 312～784 是湖（不能走），湖岸一道石栏杆，栏杆南边一条石板小路（y 792～850）连着东西两头，
  再往南是园子，最南一道白墙灰瓦（y 1190～1204），墙上两道月亮门。
  东头（x 1536～3072，照图 2）：月亮门在南墙正中（x 2304），从迎宾院西小径过来就从这道门进；一条石板路往北，两边石灯笼、太湖石、花丛、
    大树和柳树；路接一座三折的曲桥通到湖心亭；亭子两边湖里有荷花，亭子东边水上一条小船（船夫 2）。
  西头（x 0～1536，照翻转后的图 1）：湖岸往西一路是石栏杆小路；西边一块伸进水里的小半岛，上面一座小亭子，一段石桥连着岸；
    半岛东边是游船小码头（船夫 1、两条小船、两条天鹅船）；码头东边两处钓鱼的；西南角那道月亮门出去，几步进停车场。
零件形状照 lake_parts.json（第一版湖边灰盒的零件，原样不改大小），这里只把每组搬到新位置；新加的（墙、月亮门、曲桥、半岛、栏杆、
  石灯笼、太湖石、花丛、大树、小亭子）在这里写。比例照 ASSETS §15：左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素，人 84。
10/4 东半边换成代码画的像素成品（01 F 派，阿鱼要先试玩）：东半边（x ≥ 1536）的灰盒全删，换成 lake_east.json
  （tools/pixel_art/lake_east.py 出，每件标了 on_art：游戏只算挡人占地、不画灰盒，图在 assets/pixel_art/lake_east/）；
  灰盒那条整条的 walk 在 x 1536 切开；西半边南墙挪到 y 1040 跟东头对齐（01 F 定），墙里的柳树、花丛跟着挪进来。西半边照旧色块。
10/4 方案 C（阿鱼「行，C」）：东头南墙月亮门（x 2304）去后花园，西头尽头（湖岸小路西端）去果园 A；西头月亮门留着通南墙外。
用法：先 python3 godot/tools/pixel_art/lake_east.py（东半边有改动才要），再 python3 godot/tools/layout_court/make_lake_long.py
"""
import copy
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_lake", "layout.json")
PARTS = json.load(open(os.path.join(HERE, "lake_parts.json"), encoding="utf-8"))
EAST = json.load(open(os.path.join(HERE, "lake_east.json"), encoding="utf-8"))   # 东半边像素成品的摆法（lake_east.py 出）
CUT = 1536                   # 这条往东是像素成品
WEST_OUT = (22, 821)         # 10/4 方案 C：西头尽头（湖岸小路西端）去果园 A 的口；第 64 版在东头尽头 (3050, 955)

W, H = 3072, 1280
SHORE = 784                  # 湖岸线（栏杆在这）
PATH_Y = (792, 850)          # 湖岸石板小路
WALL_Y = (1028, 1040)        # 南墙（10/4 从 1190～1204 挪上来，跟东头像素成品的墙脚 1040 对齐）
GATE_E = (2272, 2336)        # 东头月亮门（迎宾院那边进来）
GATE_W = (708, 772)          # 西头月亮门（出去是停车场）
EX = 2304                    # 东头中轴（图 2 正中那条路）

IT = {i["id"]: i for i in PARTS["items"]}
NPC = {n["id"]: n for n in PARTS["npcs"]}


def moved(it, dx, dy, new_id=None):
    """一件零件整个挪 (dx, dy)：rect、pts、x/y、foot、beam 的 x0/x1/top、deco、puffs、block 都跟着挪"""
    it = copy.deepcopy(it)
    if new_id:
        it["id"] = new_id
    if "rect" in it:
        r = it["rect"]
        it["rect"] = [r[0] + dx, r[1] + dy, r[2] + dx, r[3] + dy]
    if "pts" in it:
        it["pts"] = [[p[0] + dx, p[1] + dy] for p in it["pts"]]
    for k in ("x", "x0", "x1"):
        if isinstance(it.get(k), (int, float)):
            it[k] += dx
    for k in ("y", "top", "foot"):            # box 的 top 是颜色（字符串），不挪
        if isinstance(it.get(k), (int, float)):
            it[k] += dy
    if "deco" in it:
        it["deco"] = [dict(d, rect=[d["rect"][0] + dx, d["rect"][1] + dy, d["rect"][2] + dx, d["rect"][3] + dy]) for d in it["deco"]]
    if "e" in it:
        it["e"] = [[e[0] + dx, e[1] + dy, e[2], e[3]] for e in it["e"]]
    if isinstance(it.get("block"), list):
        b = it["block"]
        it["block"] = [b[0] + dx, b[1] + dy, b[2] + dx, b[3] + dy]
    return it


def group(prefixes, dx, dy):
    return [moved(i, dx, dy) for i in PARTS["items"] if any(i["id"] == p or i["id"].startswith(p + "_") for p in prefixes)]


def npc(id_, dx, dy, **kw):
    n = copy.deepcopy(NPC[id_])
    n["x"] += dx
    n["y"] += dy
    n.update(kw)
    return n


def box(id_, rect, h, top, front, **kw):
    it = {"type": "box", "id": id_, "rect": [int(v) for v in rect], "h": int(h), "top": top, "front": front}
    it.update(kw)
    return it


def main():
    items, flat, npcs = [], [], []
    # ================= 地面
    flat += [
        {"type": "rect", "rect": [0, 0, W, H], "color": "#8fbf6a"},
        {"type": "rect", "rect": [0, 0, W, 96], "color": "#37603f"},          # 对岸远山
        {"type": "rect", "rect": [0, 80, W, 150], "color": "#416d44"},
        {"type": "rect", "rect": [0, 140, W, 210], "color": "#4a7647"},       # 对岸树林
        {"type": "rect", "rect": [0, 196, W, 312], "color": "#4f7a4a"},
        {"type": "rect", "rect": [0, 306, W, 316], "color": "#3f6a44"},
        {"type": "rect", "rect": [0, 312, W, SHORE], "color": "#3f6f8f"},     # 湖
    ]
    for y in range(332, SHORE - 30, 34):                                    # 水纹
        flat.append({"type": "rect", "rect": [0, y, W, y + 4], "color": "#45779a"})
    flat += [
        {"type": "rect", "rect": [0, SHORE - 20, W, SHORE], "color": "#5890ad"},      # 近岸浅水
        {"type": "rect", "rect": [0, SHORE, W, PATH_Y[1]], "color": "#c9c2b0"},        # 湖岸石板小路
        {"type": "rect", "rect": [0, PATH_Y[1], W, PATH_Y[1] + 4], "color": "#a8a090"},
        {"type": "rect", "rect": [0, WALL_Y[1], W, H], "color": "#3f6a44"},            # 南墙外
        {"type": "rect", "rect": [GATE_E[0], PATH_Y[1], GATE_E[1], WALL_Y[1] + 40], "color": "#c9c2b0"},   # 东头月亮门往北的石板路
        {"type": "rect", "rect": [GATE_W[0], PATH_Y[1], GATE_W[1], WALL_Y[1] + 40], "color": "#c9c2b0"},   # 西头往月亮门的石板路
    ]
    # ================= 南墙、两道月亮门（白墙灰瓦，墙高 2.1 米，10/4 跟东头像素成品一样高；门洞 1.3 米宽、上面一道圆拱门头）
    wall = dict(top="#5a5f68", front="#f2efe6", scale={"h_m": 2.1, "name": "白墙灰瓦（西半边灰盒）"}, part="LK-W01")
    items.append(box("wall_s_1", [0, WALL_Y[0], GATE_W[0], WALL_Y[1]], 100, **wall, inst="LK-W01-01"))
    items.append(box("wall_s_2", [GATE_W[1], WALL_Y[0], GATE_E[0], WALL_Y[1]], 100, **dict(wall, scale=None), inst="LK-W01-02"))
    items.append(box("wall_s_3", [GATE_E[1], WALL_Y[0], W, WALL_Y[1]], 72, **dict(wall, scale=None), inst="LK-W01-03"))
    for it in items:
        if it.get("scale") is None:
            it.pop("scale", None)
    for (gid, (a, b)) in (("moongate_w", GATE_W), ("moongate_e", GATE_E)):
        items.append({"type": "beam", "id": gid, "x0": a - 8, "x1": b + 8, "top": WALL_Y[1] - 112, "thick": 30, "foot": WALL_Y[1] + 1,
                      "color": "#f2efe6", "scale": {"w_m": 1.67, "name": "月亮门（门头）"}, "part": "LK-W02",
                      "inst": "LK-W02-%02d" % (1 if gid.endswith("w") else 2)})
        items.append({"type": "beam", "id": gid + "_tile", "x0": a - 12, "x1": b + 12, "top": WALL_Y[1] - 120, "thick": 8, "foot": WALL_Y[1] + 1,
                      "color": "#5a5f68", "part": "LK-W02", "inst": "LK-W02-%02d" % (1 if gid.endswith("w") else 2)})
    # ================= 湖岸石栏杆（只是看的，水本来就不能走）；曲桥口、半岛石桥、码头、两处钓鱼的地方留口
    gaps = [(GATE_E[0] - 8, GATE_E[1] + 8), (492, 572), (838, 982), (1140, 1200), (1410, 1470)]
    x = 0
    k = 0
    for (a, b) in sorted(gaps) + [(W, W)]:
        if a - x > 8:
            items.append({"type": "beam", "id": "rail_%d" % k, "x0": x, "x1": a, "top": SHORE - 14, "thick": 4, "foot": SHORE + 2,
                          "color": "#d8d4c8", "part": "LK-W03", "inst": "LK-W03-%02d" % (k + 1)})
            k += 1
        x = b
    # ================= 东头（图 2）：湖心亭、曲桥、石板路两边
    DX, DY = EX - 768, -80                                  # 第一版亭子（6 米见方，乐手四位）整组搬到湖心
    items += group(["pavilion_roof", "pavilion_roof_edge", "post"], DX, DY)
    for i in range(1, 5):
        npcs.append(npc("music_%d" % i, DX, DY))
    pav = [624 + DX, 428 + DY, 912 + DX, 652 + DY]          # 亭子台面（能走）
    flat += [{"type": "rect", "rect": [pav[0] - 6, pav[1] - 6, pav[2] + 6, pav[3] + 6], "color": "#6d4a38"},
             {"type": "rect", "rect": pav, "color": "#c19a68"}]
    # 曲桥三折：岸边往北 → 往西拐 → 再往北接亭子台面（1.3 米宽）
    bridge = [[EX - 32, 700, EX + 32, SHORE + 12], [EX - 128, 652, EX + 32, 716], [EX - 128, pav[3] - 12, EX - 64, 668]]
    for k, r in enumerate(bridge):
        flat.append({"type": "rect", "rect": [r[0] - 4, r[1] - 4, r[2] + 4, r[3] + 4], "color": "#6d4a38"})
        flat.append({"type": "rect", "rect": r, "color": "#a0714a"})
        items.append({"type": "beam", "id": "bridge_rail_%d" % k, "x0": r[0], "x1": r[2], "top": r[1] - 20, "thick": 4, "foot": r[1] + 1,
                      "color": "#8c5f3c", "scale": {"w_m": 1.3, "name": "曲桥"} if k == 0 else None, "part": "LK-P03", "inst": "LK-P03-01"})
    for it in items:
        if "scale" in it and it["scale"] is None:
            it.pop("scale")
    # 亭子两边的荷花、亭子东边一条小船（船夫 2 坐在船上）
    items += group(["lotus_1", "lotus_flower_1"], EX - 230 - 100, 640 - 730)       # 曲桥西边
    items += group(["lotus_2", "lotus_flower_2"], EX + 250 - 880, 660 - 740)
    items += [moved(IT["lotus_2"], EX + 360 - 880, 560 - 740, "lotus_4"), moved(IT["lotus_flower_2"], EX + 360 - 880, 560 - 740, "lotus_flower_4")]
    items += group(["rowboat_3"], EX + 330 - 1080, 330 - 440)
    npcs.append(npc("boatman_2", EX + 330 - 1080, 330 - 440))
    items += group(["duck"], EX + 520 - 980, 0)
    # 石板路两边：一对石灯笼、太湖石、花丛、大树、柳树
    lantern = dict(top="#b8b4a8", front="#9a968a", part="LK-P04")
    items.append(box("lantern_w", [EX - 72, 896, EX - 52, 906], 58, **lantern, scale={"h_m": 1.2, "w_m": 0.42, "name": "石灯笼"}, inst="LK-P04-01"))
    items.append(box("lantern_e", [EX + 52, 896, EX + 72, 906], 58, **lantern, inst="LK-P04-02"))
    rock = dict(top="#9aa0a8", front="#7a8088", part="LK-P05")
    items.append(box("rock_0", [EX - 200, 1000, EX - 156, 1016], 72, **rock, scale={"h_m": 1.5, "w_m": 0.9, "name": "太湖石"}, inst="LK-P05-01"))
    items.append(box("rock_1", [EX + 180, 1010, EX + 220, 1024], 64, **rock, inst="LK-P05-02"))
    items.append(box("rock_2", [500, 900, 540, 914], 60, **rock, inst="LK-P05-03"))
    flower = dict(top="#e9a6c0", front="#7fa85c", part="LK-P06")
    for k, (cx, cy) in enumerate([(EX - 130, 960), (EX + 120, 950), (EX - 110, 1100), (EX + 140, 1110), (300, 990), (1150, 1000)]):   # 后两丛 10/4 跟着南墙挪进墙里
        items.append({"type": "cyl", "id": "flowers_%d" % k, "x": cx, "y": cy, "rx": 30, "ry": 12, "h": 30, "top": flower["top"],
                      "front": flower["front"], "part": "LK-P06", "inst": "LK-P06-%02d" % (k + 1),
                      **({"scale": {"w_m": 1.25, "h_m": 0.6, "name": "花丛"}} if k == 0 else {})})
    big = dict(trunk="#6d4a38", leaf="#4f7a4a", leaf2="#6a9a5c", h=264, w=180, part="LK-P07")
    for k, (tx, ty) in enumerate([(EX - 330, 1000), (EX + 330, 980), (1700, 1010)]):
        items.append({"type": "tree", "id": "bigtree_%d" % k, "x": tx, "y": ty, **big, "inst": "LK-P07-%02d" % (k + 1),
                      "scale": {"h": "tree_h"}})
    # 柳树：照第一版的柳树，东头两边、西头半岛和湖岸、南墙边
    willow_at = {"willow_0": (EX - 600, 960), "willow_1": (EX + 620, 960), "willow_2": (330, 900),
                 "willow_3": (1250, 960), "willow_4": (1050, 1000), "willow_5": (2650, 1170)}   # willow_4 10/4 南墙挪上来，跟着挪进墙里
    for wid, (tx, ty) in willow_at.items():
        w = copy.deepcopy(IT[wid])
        w["x"], w["y"] = tx, ty
        w.pop("scale_note", None)
        items.append(w)
    # ================= 西头（翻转后的图 1）：半岛小亭、游船码头、钓鱼、长凳
    pen = [400, 440, 660, 700]                               # 伸进水里的小半岛（能走）
    neck = [500, 690, 564, SHORE + 12]                       # 连岸的一段石桥
    flat += [{"type": "rect", "rect": [pen[0] - 8, pen[1] - 8, pen[2] + 8, pen[3] + 8], "color": "#a8a090"},
             {"type": "rect", "rect": pen, "color": "#9cc874"},
             {"type": "rect", "rect": [neck[0] - 4, neck[1], neck[2] + 4, neck[3]], "color": "#a8a090"},
             {"type": "rect", "rect": neck, "color": "#c9c2b0"}]
    wp = dict(top="#a83a30", front="#8c2f27", part="LK-P08")
    for k, (px, py) in enumerate([(450, 480), (610, 480), (450, 600), (610, 600)]):
        items.append(box("wpav_post_%d" % k, [px - 5, py - 5, px + 5, py + 5], 92, **wp, inst="LK-P08-01",
                         **({"scale": {"h_m": 1.9, "name": "半岛小亭柱子"}} if k == 0 else {})))
    items.append({"type": "poly", "id": "wpav_roof", "pts": [[530, 330], [650, 388], [650, 402], [410, 402], [410, 388]], "foot": 606,
                  "color": "#4a4f58", "scale": {"w_m": 5.0, "name": "半岛小亭（顶 5 米宽）"}, "part": "LK-P08", "inst": "LK-P08-01"})
    items.append({"type": "poly", "id": "wpav_roof_edge", "pts": [[410, 398], [650, 398], [650, 410], [410, 410]], "foot": 607,
                  "color": "#8c2f27", "part": "LK-P08", "inst": "LK-P08-01"})
    # 游船小码头（第一版那一组：码头、两条小船、两条天鹅船、船夫 1）搬到半岛东边
    items += group(["dock_deck", "dock_plank", "dock_edge", "dock_post", "rowboat_1", "rowboat_2", "swanboat_1", "swanboat_2"], 520, 0)
    npcs.append(npc("boatman_1", 520, 0))
    # 两处钓鱼的（第一版那两组）：湖岸栏杆留口的地方，坐在小凳上朝湖
    items += group(["fish_stool_1", "fish_rod_1", "fish_bucket_1"], 0, -24)
    npcs.append(npc("fisher_1", 0, -24))
    items += group(["fish_stool_2", "fish_rod_2", "fish_bucket_2"], 0, -24)
    npcs.append(npc("fisher_2", 0, -24))
    items += group(["lotus_3", "lotus_flower_3"], 300 - 1190, 640 - 728)       # 半岛西边
    items += group(["reed_1", "reed_2"], 0, -14)
    items += group(["reed_3"], 1000, -14)
    # 长凳：能坐的那张在湖岸小路南边、朝湖（东西两头中间），另一张在东头园子里
    items += group(["bench"], 1436, -80)
    items += group(["bench2"], 2700 - 1114, -80)
    # ================= 出口牌（只有出口牌显示，木牌）
    flat += [{"type": "label", "text": "去果园", "x": WEST_OUT[0] + 70, "y": WEST_OUT[1] - 60}]
    # ================= 10/4 东半边换成像素成品：灰盒东半边全删（横跨两半的墙、栏杆切到 CUT），拼上 lake_east.json
    def cx(it):
        if "rect" in it:
            return (it["rect"][0] + it["rect"][2]) / 2
        if "x0" in it:
            return (it["x0"] + it["x1"]) / 2
        if "pts" in it:
            return sum(q[0] for q in it["pts"]) / len(it["pts"])
        return it.get("x", 0)
    west = []
    for it in items:
        if "rect" in it and it["rect"][0] < CUT < it["rect"][2]:
            it["rect"][2] = CUT
        elif "x0" in it and it["x0"] < CUT < it["x1"] and it["id"].startswith("rail_"):
            it["x1"] = CUT
        if cx(it) < CUT:
            west.append(it)
    taken = {it["id"] for it in west}
    east = copy.deepcopy(EAST["items"])
    for it in east:                       # 两边各自起的名撞了（柳树、石头、荷花）：东半边的加 _e
        if it["id"] in taken:
            it["id"] += "_e"
    items = west + east
    npcs = [n for n in npcs if n["x"] < CUT] + EAST["npcs"]
    flat = [f for f in flat if not (f["type"] == "label" and f["x"] >= CUT)] + EAST["flat"]
    flat.append({"type": "label", "text": "去后花园", "x": EX, "y": WALL_Y[1] + 52})   # 方案 C：东头南墙月亮门去后花园
    d = {
        "scene": "scene_luoman_lake",
        "title": "湖边",
        "note": "罗曼山庄 · 湖边（长湖岸，阿鱼 10/3：东头照效果图 2、西头照左右翻转的效果图 1，从西头月亮门出去进停车场；01 F 派）。"
                "tools/layout_court/make_lake_long.py 生成，别手改；零件形状照 tools/layout_court/lake_parts.json（第一版湖边灰盒），改数重跑，再跑 gen_specs_court.py --scene lake。"
                "一块画布拉宽成 3072×1280，一条湖岸从东走到西、中间不切画布。湖、对岸不能走；湖岸石板小路连着东西两头；南墙两道月亮门："
                "东头那道（to_entrance）回迎宾院，西头那道（to_parking）出去是停车场。spawn 是从迎宾院过来站的地方（东头月亮门里边），from_parking 是从停车场过来站的地方。"
                "第一版的玩法东西都留着：游船码头（船夫 1、两条小船、两条天鹅船）在西头半岛东边；两处钓鱼的在码头东边湖岸。"
                "10/4 东半边（x ≥ 1536）换成代码画的像素成品（tools/pixel_art/lake_east.py，摆法 lake_east.json，标 on_art 的只算挡人、不画灰盒）："
                "南墙月亮门、石板路、曲桥、湖心亭（人只走亭子前沿，乐手亭子前沿 2 位、桥头小广场 2 位）、篷船船夫 2、能坐的长凳在往西小路北沿朝湖；"
                "西半边照旧色块，南墙挪到 y 1040 跟东头对齐",
        "size": [W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": EAST["spawn"],
        "bench_seat": EAST["bench_seat"],
        "bench_stand": EAST["bench_stand"],
        # 10/4 方案 C（照阿鱼图只上下翻）：东头南墙月亮门去后花园，西头尽头开口去果园 A；
        # 西头月亮门不通哪了，门洞留着通南墙外（第 64 版西头月亮门去后花园、东头尽头去果园）
        "points": [
            {"id": "to_garden", "x": EX, "y": 1066, "r": 36, "to": "garden"},
            {"id": "to_orchard", "x": WEST_OUT[0], "y": WEST_OUT[1], "r": 40, "to": "orchard"},
        ] + [p for p in EAST["points"] if p["id"] != "to_entrance"],
        "walk": [
            [[40, PATH_Y[0]], [CUT, PATH_Y[0]], [CUT, WALL_Y[0] - 4], [40, WALL_Y[0] - 4]],                           # 西半边湖岸小路和园子（东半边接 lake_east 那块）
            [[GATE_W[0], WALL_Y[0] - 10], [GATE_W[1], WALL_Y[0] - 10], [GATE_W[1], WALL_Y[1] + 40], [GATE_W[0], WALL_Y[1] + 40]],   # 西头月亮门
            [[pen[0], pen[1]], [pen[2], pen[1]], [pen[2], pen[3]], [pen[0], pen[3]]],                                  # 半岛
            [[neck[0], neck[1]], [neck[2], neck[1]], [neck[2], neck[3]], [neck[0], neck[3]]],                          # 半岛石桥
            [[842, 566], [978, 566], [978, 798], [842, 798]],                                                          # 游船码头的木台（10/4：看着是地面的都能走；船夫 1 跟前能站，挂台词能走过去说话）
        ] + EAST["walk"] + [
            [[4, WALL_Y[1] + 8], [W - 4, WALL_Y[1] + 8], [W - 4, H - 6], [4, H - 6]],                                 # 南墙外（10/4：看着是草地、石板路的都能走）
            [[4, WEST_OUT[1] - 29], [54, WEST_OUT[1] - 29], [54, WEST_OUT[1] + 29], [4, WEST_OUT[1] + 29]],   # 西头尽头去果园那个口
        ],
        "flat": flat,
        "items": items,
        "npcs": npcs,
        "pixel_art": ["res://assets/pixel_art/lake_east/room.json"],   # 东半边像素成品（entrance.gd _pixel_art 铺）
    }
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
    print("写了 %s：%d 件、%d 块平铺、%d 个人" % (OUT, len(items), len(flat), len(npcs)))


if __name__ == "__main__":
    main()
