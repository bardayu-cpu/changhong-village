#!/usr/bin/env python3
"""宴会厅氛围的摆放（阿鱼 9/18 要的「氛围感」）：写 assets/ambience/ambience.json，运行时 scripts/hall_life.gd 读。

- 彩带、彩纸撒在地砖上：避开红毯、桌子（桌子积木会盖住）、灯笼脚、栏杆前景，互相隔开
- 灯笼光：墙上 9 盏（对着 base.png 找的灯笼亮心）+ 四盏落地灯笼（积木着地点往上 40 像素）
- 乐队在舞台右边、贺礼堆在舞台左边，都在地面最上面那一条（y 215～315 不在能走的范围里，不挡人）
- NPC 宾客坐哪几桌、每桌几个：阿鱼 9/18 晚定 12 张桌都坐、每桌 6～9 个（蓝图 3.2 原写 7～12 号桌，等总策划改）
- 服务员几个、从东边侧门进出

重跑：python3 tools/make_ambience_layout.py（结果固定：随机数有种子）
55 桌大厅（01 9/24 派，新场景 scene_roman_banquet_55）：python3 tools/make_ambience_layout.py 55，写 assets/ambience/ambience_55.json。
  底图中间拉长了 1020 像素（tools/layout_55/make_base55.py），下半截（栏杆、东侧门）的坐标都往下挪 1020；
  NPC 每桌 5～7 个（方案：满厅约三百人，帧率等阿鱼真机的数再定），服务员 6 个
"""
import json
import pathlib
import random
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BIG = len(sys.argv) > 1 and sys.argv[1] == "55"
SCENE = ROOT / ("assets/layered/scene_roman_banquet_55/scene.json" if BIG else "assets/layered/scene_roman_banquet/scene.json")
OUT = ROOT / ("assets/ambience/ambience_55.json" if BIG else "assets/ambience/ambience.json")
DY = 1020 if BIG else 0      # 下半截往下挪了多少

scene = json.loads(SCENE.read_text())
tables = scene["tables"]

# 墙上的灯笼亮心（9/18 对着 base.png 量的，A04 整批换底图要重量）
WALL_LANTERNS = [(520, 32), (953, 31), (315, 82), (1157, 81), (98, 124), (1373, 123), (20, 224), (1453, 224), (1485, 289)]
# 落地灯笼、花盆这些站在地上的积木（墙边、红毯两边），从 scene.json 的遮挡块里读着地点
FLOOR_LANTERNS = [(o["x"] + 12, o["foot"]) for o in scene["occluders"] if "blk_lantern_floor" in o["image"]]
FLOOR_PROPS = [(o["x"] + 20, o["foot"]) for o in scene["occluders"]
               if "blk_lantern_floor" in o["image"] or "blk_flower_pot" in o["image"]]


def on_carpet(x, y):
    return abs(x - 768) < 112


def under_table(x, y):
    for t in tables:
        if abs(x - t["x"]) < 96 and t["y"] - 124 < y < t["y"] + 44:
            return True
    return False


def under_rail(x, y):
    return (x < 440 and y > 745 + DY) or (x > 1060 and y > 735 + DY)


def near_lantern(x, y):
    return any(abs(x - lx) < 40 and ly - 80 < y < ly + 24 for lx, ly in FLOOR_PROPS)


def scatter(rng, n, placed, min_d):
    out = []
    tries = 0
    while len(out) < n and tries < 20000:
        tries += 1
        x = rng.uniform(100, 1436)
        y = rng.uniform(330, 850 + DY)
        if on_carpet(x, y) or under_table(x, y) or under_rail(x, y) or near_lantern(x, y):
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < min_d ** 2 for px, py in placed):
            continue
        placed.append((x, y))
        out.append((round(x), round(y)))
    return out


def main():
    rng = random.Random(918)
    placed = []
    decals = []
    k = 3 if BIG else 1
    for x, y in scatter(rng, 26 * k, placed, 64):
        decals.append({"art": "amb_streamer_%d" % rng.randint(1, 6), "x": x, "y": y, "flip": rng.random() < 0.5})
    for x, y in scatter(rng, 18 * k, placed, 48):
        decals.append({"art": "amb_confetti_%d" % rng.randint(1, 3), "x": x, "y": y, "flip": rng.random() < 0.5})

    glows = [[x, y, 64, 0.42] for x, y in WALL_LANTERNS]
    glows += [[x, y - 40, 46, 0.4] for x, y in FLOOR_LANTERNS]

    conf = {
        "note": "宴会厅氛围的摆放，tools/make_ambience_layout.py 生成，别手改",
        "decals": decals,
        "glows": glows,
        "gifts": [625, 210],   # 9/24 晚照 GPT 效果图：舞台左边台面上
        # 舞台右边的乐队：钢琴（琴键在左端，人坐琴凳面朝右）、大提琴坐着、两把小提琴站着，谱架在小提琴左前
        "band": {
            "piano": [1082, 298],
            "bench": [1006, 300],
            "cello": [1178, 300],
            "violin1": [1250, 298],
            "violin2": [1322, 300],
            "stands": [[1230, 306], [1302, 308]],
        },
        # NPC 宾客：桌号 -> 坐几个。阿鱼 9/18 晚：「应该是正在吃席」，12 张桌都坐，每桌 6～9 个；
        # 1、2 号桌（阿鱼、Toretto 那两桌）少坐几个。NPC 坐着的椅子真人照样能坐，坐下时 NPC 让座走掉
        "npc_tables": {"T1": 6, "T2": 6, "T3": 8, "T4": 7, "T5": 8, "T6": 7,
                       "T7": 8, "T8": 9, "T9": 8, "T10": 9, "T11": 7, "T12": 8},
        # 服务员：4 个，1.5 米/秒；一趟只端一盘，放下就回侧门再端
        "waiters": {"count": 4, "door": [1448, 800], "speed_m": 1.5},
        "petals": {"amount": 26},
    }
    if BIG:
        # 55 桌：每桌 5～7 个 NPC；1、2 号桌（阿鱼、Toretto 那两桌）坐 5 个；服务员 6 个，从东侧门（往下挪了 1020）进出
        r2 = random.Random(55)
        conf["npc_tables"] = {t["id"]: (5 if t["id"] in ("T1", "T2") else r2.randint(5, 7)) for t in tables}
        conf["waiters"] = {"count": 6, "door": [1448, 800 + DY], "speed_m": 1.5}
        conf["petals"] = {"amount": 60}
        # 贺礼堆：台面上会挡横幅，挪到台下右前方、第一排空出来的那个位上（新人在左边那个位）
        conf["gifts"] = [960, 362]   # 顶边 256，在 LED 屏（到 y 246）下面
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(conf, ensure_ascii=False, indent=1) + "\n")
    print("写好", OUT.relative_to(ROOT), "彩带彩纸", len(decals), "灯笼光", len(glows))


if __name__ == "__main__":
    main()
