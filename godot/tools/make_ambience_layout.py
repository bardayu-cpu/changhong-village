#!/usr/bin/env python3
"""宴会厅氛围的摆放（阿鱼 9/18 要的「氛围感」）：写 assets/ambience/ambience.json，运行时 scripts/hall_life.gd 读。

- 彩带、彩纸撒在地砖上：避开红毯、桌子（桌子积木会盖住）、灯笼脚、栏杆前景，互相隔开
- 灯笼光：墙上 9 盏（对着 base.png 找的灯笼亮心）+ 四盏落地灯笼（积木着地点往上 40 像素）
- 乐队在舞台右边、贺礼堆在舞台左边，都在地面最上面那一条（y 215～315 不在能走的范围里，不挡人）
- NPC 宾客坐哪几桌、每桌几个：助理 01 的建议，阿鱼 9/18 晚定留（蓝图 3.2 原文「坐着的人是真实住民」，等总策划改）
- 服务员几个、从东边侧门进出

重跑：python3 tools/make_ambience_layout.py（结果固定：随机数有种子）
"""
import json
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCENE = ROOT / "assets/layered/scene_roman_banquet/scene.json"
OUT = ROOT / "assets/ambience/ambience.json"

scene = json.loads(SCENE.read_text())
tables = scene["tables"]

# 墙上的灯笼亮心（9/18 对着 base.png 量的，A04 整批换底图要重量）
WALL_LANTERNS = [(520, 32), (953, 31), (315, 82), (1157, 81), (98, 124), (1373, 123), (20, 224), (1453, 224), (1485, 289)]
FLOOR_LANTERNS = [(90, 470), (90, 650), (1446, 470), (1446, 650)]


def on_carpet(x, y):
    return abs(x - 768) < 112


def under_table(x, y):
    for t in tables:
        if abs(x - t["x"]) < 96 and t["y"] - 124 < y < t["y"] + 44:
            return True
    return False


def under_rail(x, y):
    return (x < 440 and y > 745) or (x > 1060 and y > 735)


def near_lantern(x, y):
    return any(abs(x - lx) < 40 and ly - 70 < y < ly + 24 for lx, ly in FLOOR_LANTERNS)


def scatter(rng, n, placed, min_d):
    out = []
    tries = 0
    while len(out) < n and tries < 20000:
        tries += 1
        x = rng.uniform(100, 1436)
        y = rng.uniform(330, 850)
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
    for x, y in scatter(rng, 26, placed, 64):
        decals.append({"art": "amb_streamer_%d" % rng.randint(1, 6), "x": x, "y": y, "flip": rng.random() < 0.5})
    for x, y in scatter(rng, 18, placed, 48):
        decals.append({"art": "amb_confetti_%d" % rng.randint(1, 3), "x": x, "y": y, "flip": rng.random() < 0.5})

    glows = [[x, y, 64, 0.42] for x, y in WALL_LANTERNS]
    glows += [[x, y - 40, 46, 0.4] for x, y in FLOOR_LANTERNS]

    conf = {
        "note": "宴会厅氛围的摆放，tools/make_ambience_layout.py 生成，别手改",
        "decals": decals,
        "glows": glows,
        "gifts": [410, 302],
        # 舞台右边的乐队：钢琴（琴键在左端，人坐琴凳面朝右）、大提琴坐着、两把小提琴站着，谱架在小提琴左前
        "band": {
            "piano": [1082, 298],
            "bench": [1006, 300],
            "cello": [1178, 300],
            "violin1": [1250, 298],
            "violin2": [1322, 300],
            "stands": [[1230, 306], [1302, 308]],
        },
        # NPC 宾客（阿鱼 9/18 定留）：桌号 -> 坐几个。T1～T6 离主桌近、先分给真人的桌全空着；
        # 每桌留几把空椅子，玩家也能坐进去。真人坐到哪把，那把的 NPC 就不画
        "npc_tables": {"T7": 6, "T8": 5, "T9": 7, "T10": 6, "T11": 5, "T12": 6},
        "waiters": {"count": 3, "door": [1448, 800], "speed_m": 1.3},
        "petals": {"amount": 26},
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(conf, ensure_ascii=False, indent=1) + "\n")
    print("写好", OUT.relative_to(ROOT), "彩带彩纸", len(decals), "灯笼光", len(glows))


if __name__ == "__main__":
    main()
