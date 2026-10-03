#!/usr/bin/env python3
"""停车场 + 山庄大门 灰盒摆位（01 F 10/3 派；玩家说明 docs/停车场和大门-玩家说明-v0.1.md 第 1、2、3、6 节）。
出 assets/layered/scene_luoman_parking/layout.json（scripts/parking.gd 读它，搭法跟迎宾院一样走 entrance.gd）。
改摆法只改这份的数、重跑，别手改 json；再跑 gen_specs_court.py --scene parking 出尺寸表。

摆法（照 ASSETS §15「人 = 1」：左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素，人 84）：
  画布 1024 × 1088（10/3 从 1152 收：第一屏要看得到整座门楼和「罗曼山庄」牌子）。北边 y 150～252 是山庄门楼，门洞正对路，进门洞就是迎宾院（迎宾院南边的大门）。
  路在中间偏东 x 600～780，从南边（开车进来的地方）一直通到门洞；路东边一条草边（能走），再往东是湖（只露一条当风景，不能走）。
  停车场在路西边：三排，每排四个车位（2.5 米宽、5 米深 = 120 × 160），车头朝北朝南停；排和排之间 4 米宽的车道，东头通到路上。
  四辆点名的车（紫色宝马双门 240、蓝色 BRZ、白色保时捷 911、黑色哈弗 H6）照真车尺寸，停在靠路的两列，第一屏看得见；
  自己的车停在最南一排靠路那个位，人从车东边出生（下车）。其余车位放几辆普通车，留几个空位。
  西北角留一块给小卖部（玩家说明第 5 节，下一件再做）。
10/4 方案 C（阿鱼「行，C」：照阿鱼图只上下翻、左右不变）：停车场在迎宾院东边，翻成路西、车位东——下面的数照翻之前写（路东、车位西），
写文件前整块左右翻一下（layout_io.mirror_x），所以游戏里路在西边、车位在东边、去迎宾院和前门的两个口在西边，自己的车下车站在车的西边。
用法：python3 godot/tools/layout_court/make_parking.py
"""
import json
import os

import layout_io

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_parking", "layout.json")

W, H = 1024, 1240     # 10/4 连图：往南加长 152，放公共洗手间、垃圾杂物处两间小屋
PX_M, PX_M_D = 48.0, 32.0

ROAD = (600, 780)            # 路（左右）
VERGE = (780, 820)           # 路东边的草边，能走
LAKE_X = 820                 # 湖从这往东，不能走
GATE_Y = (150, 252)          # 门楼那一条（墙脚 y 252）
GATE_OPEN = (612, 768)       # 门洞（左右）
LOT_X0 = 100                 # 车位从这往东排
STALL_W, STALL_D = 120, 160  # 一个车位 2.5 米 × 5 米
ROWS = [(290, "A"), (578, "B"), (866, "C")]   # 每排车位的北边 y（排深 160，排间车道 128 = 4 米：收窄一点，从自己车旁第一屏才看得到整座门楼）
SHOP = [52, 270, 300, 330]   # 小卖部留的地方（地上画一块，不挡人；下一件再做）
EAST_EXITS = [(420, "court"), (900, "frontgate")]   # 10/4 连图：路东两个口（y, 通哪）——游戏里各块照阿鱼图转半圈摆，迎宾院、前门在停车场东边

# 车：(名字, 车长 m, 车宽 m, 车高 m, 车顶色, 车身色)。竖着停（车长沿前后、车宽沿左右）
CARS = {
    "bmw240": ("紫色宝马双门 240", 4.45, 1.77, 1.40, "#7a4a9a", "#5a3478"),
    "brz": ("蓝色斯巴鲁 BRZ", 4.26, 1.78, 1.31, "#3f6fc0", "#2b5196"),
    "p911": ("白色保时捷 911", 4.52, 1.85, 1.30, "#f2f0ea", "#cfcbc2"),
    "h6": ("黑色哈弗 H6", 4.65, 1.89, 1.73, "#3a3a40", "#222226"),
    "mine": ("自己的车", 4.60, 1.80, 1.48, "#c0392b", "#8c2a20"),
    "car_a": ("别的客人的车（银）", 4.70, 1.82, 1.46, "#b8bcc4", "#8c9099"),
    "car_b": ("别的客人的车（白）", 4.50, 1.78, 1.50, "#e8e6e0", "#c4c1b8"),
    "car_c": ("别的客人的车（深灰）", 4.80, 1.86, 1.68, "#5a5f68", "#3e424a"),
    "car_d": ("别的客人的车（香槟）", 4.60, 1.80, 1.47, "#d8c8a0", "#b0a07a"),
    "car_e": ("别的客人的车（墨绿）", 4.40, 1.78, 1.55, "#3e6650", "#2a4a38"),
}
# 车停哪：排 -> 第几个位（0 最西、3 靠路）-> 车
PARKED = {
    "A": {0: "car_a", 1: "car_e", 3: "brz"},
    "B": {0: "car_b", 1: "car_c", 2: "h6", 3: "p911"},
    "C": {0: "car_d", 2: "bmw240", 3: "mine"},
}
PART = {"bmw240": "PK-P01", "brz": "PK-P02", "p911": "PK-P03", "h6": "PK-P04", "mine": "PK-P05"}


def box(id_, rect, h, top, front, **kw):
    it = {"type": "box", "id": id_, "rect": [int(v) for v in rect], "h": int(h), "top": top, "front": front}
    it.update(kw)
    return it


def main():
    items, flat, signs = [], [], []
    # ---- 地面
    flat.append({"type": "rect", "rect": [0, 0, W, H], "color": "#8fbf6a"})                 # 草
    flat.append({"type": "rect", "rect": [0, 0, W, GATE_Y[0]], "color": "#5f8f55"})        # 北边院墙外是后花园（10/4 连图）
    flat.append({"type": "rect", "rect": [40, 262, ROAD[0], H], "color": "#6f6a66"})       # 停车场沥青
    flat.append({"type": "rect", "rect": [ROAD[0], GATE_Y[1], ROAD[1], H], "color": "#8a8580"})   # 路
    flat.append({"type": "rect", "rect": [ROAD[0] + 86, GATE_Y[1] + 30, ROAD[0] + 94, H], "color": "#e8dfc4"})  # 路中线（虚线先画成一条）
    flat.append({"type": "rect", "rect": [VERGE[0], GATE_Y[1], VERGE[1], H], "color": "#9cc874"})  # 草边
    # 10/4 连图：路东原来露一条湖、白墙月亮门去湖边，湖边改从后花园、果园进以后拿掉了；路东是草地，东边两个口去迎宾院、前门
    for (y, to) in EAST_EXITS:
        flat.append({"type": "rect", "rect": [VERGE[1], y - 36, W, y + 36], "color": "#c2b393"})
    flat.append({"type": "rect", "rect": SHOP, "color": "#d9c49a"})                         # 小卖部留的地方
    # 车位线：每排四个位，白线
    for (y0, row) in ROWS:
        for k in range(5):
            x = LOT_X0 + k * STALL_W
            flat.append({"type": "rect", "rect": [x - 1, y0, x + 2, y0 + STALL_D], "color": "#e8e4d8"})
        flat.append({"type": "rect", "rect": [LOT_X0, y0 - 1, LOT_X0 + 4 * STALL_W, y0 + 2], "color": "#e8e4d8"})
        flat.append({"type": "rect", "rect": [LOT_X0, y0 + STALL_D - 2, LOT_X0 + 4 * STALL_W, y0 + STALL_D + 1], "color": "#e8e4d8"})
    # ---- 北边院墙，门洞去后花园（10/4 连图：原来的「罗曼山庄」门楼、气球拱门挪到前门那块，make_areas.py）
    wall_t = (GATE_Y[1] - 14, GATE_Y[1])
    items.append(box("wall_w", [0, wall_t[0], GATE_OPEN[0] - 32, wall_t[1]], 58, "#c8b08a", "#a08a68", scale={"h_m": 1.2, "name": "院墙"}, part="PK-W01", inst="PK-W01-01"))
    items.append(box("wall_e", [GATE_OPEN[1] + 32, wall_t[0], W, wall_t[1]], 58, "#c8b08a", "#a08a68", part="PK-W01", inst="PK-W01-02"))
    flat.append({"type": "label", "text": "去后花园", "x": GATE_OPEN[1] + 70, "y": GATE_Y[1] + 30})
    # ---- 公共洗手间、垃圾杂物处：停车场南边两间小屋（01 定：看得见、门口挂牌、走近说一句，不进去）
    for (hid, name, x0, col) in (("toilet", "公共洗手间", 380, ("#d8e4ea", "#a8b8c2")), ("trash", "垃圾杂物处", 120, ("#c8c0b0", "#988e7c"))):
        items.append(box("house_" + hid, [x0, H - 150, x0 + 192, H - 110], 144, col[0], col[1],
                         scale={"w_m": 4.0, "h_m": 3.0, "name": name + "小屋"}, part="PK-P09"))
        signs.append({"text": name, "x": x0 + 96, "y": H - 236, "foot": H - 109})
    # ---- 车
    for (y0, row) in ROWS:
        for slot, cid in PARKED[row].items():
            name, L, Wd, Hh, top, front = CARS[cid]
            w_px, d_px = round(Wd * PX_M), round(L * PX_M_D)
            cx = LOT_X0 + slot * STALL_W + STALL_W // 2
            cy = y0 + STALL_D // 2
            rect = [cx - w_px // 2, cy - d_px // 2, cx - w_px // 2 + w_px, cy - d_px // 2 + d_px]
            it = box("car_" + cid if not cid.startswith("car_") else cid, rect, round(Hh * PX_M), top, front,
                     scale={"w_m": Wd, "d_m": L, "h_m": Hh, "name": name}, part=PART.get(cid, "PK-P07"))
            it["inst"] = it["part"] + "-%02d" % (sum(1 for x in items if x.get("part") == it["part"]) + 1)
            items.append(it)
    for (y, to) in EAST_EXITS:
        # 方案 C：牌子挂在口的正下方（原来在口上方，跟落点上的人叠，被挪到头顶又跟「去后花园」叠；放口里边又压到路）
        flat.append({"type": "label", "text": {"court": "去迎宾院", "frontgate": "去前门"}[to], "x": W - 110, "y": y + 60})
    mine = [it for it in items if it["id"] == "car_mine"][0]["rect"]
    mine_x = mine[2] + 22                         # 自己车的东边（司机下车那边）
    mine_y = (mine[1] + mine[3]) // 2
    d = {
        "scene": "scene_luoman_parking",
        "title": "停车场",
        "note": "罗曼山庄 · 停车场和大门灰盒（01 F 10/3 派；玩家说明 docs/停车场和大门-玩家说明-v0.1.md 第 1、2、3、6 节，阿鱼点头）。"
                "tools/layout_court/make_parking.py 生成，别手改；改数重跑，再跑 gen_specs_court.py --scene parking。"
                "全部代码画的占位：车是色块（照 ASSETS §15 按真车尺寸），门楼、气球拱门、湖都是色块，以后照阿鱼挑好的摆法画图。"
                "spawn 是从自己的车上下来站的地方（开头：开屏、选形象以后，没进过迎宾院的从这里出生）；"
                "to_court 是门楼门洞，走进去到迎宾院（迎宾院南边的大门 gate 走出来回到这里，站 from_court）；"
                "my_car 是自己的车旁边：吃完席（大门开了）出来走到这，接结束那两句。湖只露一条当风景，不能走；小卖部先留 shop_reserved 那块，不做。"
                "10/3 湖边改长湖岸：路东草边外一道白墙，墙上月亮门洞 to_lake 出去是湖边西头（湖边西头月亮门回来站 from_lake）",
        "size": [W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": [mine_x, mine_y],
        "from_court": [W - 110, EAST_EXITS[0][0]],
        "points": [
            {"id": "to_garden", "x": (GATE_OPEN[0] + GATE_OPEN[1]) // 2, "y": GATE_Y[1] + 18, "r": 40, "to": "garden"},
            {"id": "my_car", "x": mine_x, "y": mine_y, "r": 46},
        ] + [{"id": "to_" + to, "x": W - 36, "y": y, "r": 44, "to": to} for (y, to) in EAST_EXITS] + [
            {"id": "toilet", "x": 476, "y": H - 80, "r": 50, "say": "toilet_wip"},     # 方案 C 翻完洗手间在西、杂物处在东（阿鱼图）
            {"id": "trash", "x": 216, "y": H - 80, "r": 50, "say": "trash_wip"},
        ],
        "shop_reserved": {"rect": SHOP, "note": "玩家说明第 5 节小卖部，下一件再做；先在地上留这块，不挡人"},
        "walk": [[[40, GATE_Y[1] + 4], [W - 60, GATE_Y[1] + 4], [W - 60, H - 8], [40, H - 8]],
                 [[GATE_OPEN[0] + 4, 4], [GATE_OPEN[1] - 4, 4], [GATE_OPEN[1] - 4, GATE_Y[1] + 10], [GATE_OPEN[0] + 4, GATE_Y[1] + 10]]]
                + [[[W - 64, y - 32], [W - 4, y - 32], [W - 4, y + 32], [W - 64, y + 32]] for (y, to) in EAST_EXITS],
        "flat": flat,
        "items": items,
        "signs": signs,
        "npcs": [],
    }
    d = layout_io.mirror_x(d)    # 方案 C：整块左右翻（路西、车位东）
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
    print("写了 %s：%d 件、%d 块平铺、%d 辆车" % (OUT, len(items), len(flat), sum(1 for x in items if x["id"].startswith("car_"))))


if __name__ == "__main__":
    main()
