#!/usr/bin/env python3
"""55 桌大厅的摆位（01 9/24 派，方案 回执/宴会厅55桌-方案.md）：写 tools/layout_55/scene_55.json，再用 build_layered.py 生成场景

排法：红毯（中线 x 748）两边各 3 列、10 排 = 60 个位，空 5 个：第 1 排中间 2 个（婚礼台正前方，新人下台敬酒）、
第 10 排中间 2 个（大门进来）、第 10 排最东 1 个（东侧门进出）。
GPT 的桌子积木连椅子 144 宽，比方案里算的 140 大一点；1536 宽的底图里左右各 3 列：列心 x 182、385、588 | 908、1111、1314，
桌与桌之间留 3 格走得过去；排距 148（后一排人头不压前一排），第 1 排着地点 y 370（和 12 桌厅顶上一排一样高）
走路判定的占地椭圆用 70×52（桌子积木自己写的 80×52 在 6 列里走不开，70 是椅子外沿）
用法：python3 tools/layout_55/make_layout55.py && python3 tools/build_layered.py tools/layout_55/scene_55.json [检查图.png]
"""
import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
M = 1020                   # 底图中间拉长了多少（make_base55.py）
COLS = [182, 385, 588, 908, 1111, 1314]
ROW0, PITCH = 370, 148
SKIP = {(0, 2), (0, 3), (9, 2), (9, 3), (9, 5)}

place = []
for r in range(10):
    for c, x in enumerate(COLS):
        if (r, c) in SKIP:
            continue
        p = {"block": "blk_table_round", "x": x, "y": ROW0 + r * PITCH}
        if x > 748:
            p["flip"] = True
        place.append(p)
assert len(place) == 55, len(place)
place.append({"block": "fg_rail_left", "x": 0, "y": 1013 + M, "front": True})
place.append({"block": "fg_rail_right", "x": 1066, "y": 1012 + M, "front": True})
src = {
    "scene": "scene_roman_banquet_55", "revision": "v1-55tables",
    "note": "55 桌大厅（新场景，和 12 桌厅并存，开关切）。底图是 GPT 21:30 空地面底图上下拉长的占位（make_base55.py），桌子是 GPT 21:30 的 A04 积木摆 55 遍",
    "canvas": [1536, 1024 + M], "person_h": 84, "base": "base.png",
    "blocks": {
        "blk_table_round": {"anchor": [82, 124], "footprint": {"ellipse": [70, 52]}},
        "fg_rail_left": {"anchor": [0, 261]}, "fg_rail_right": {"anchor": [0, 272]},
    },
    "place": place,
    # 顶上一排后排椅子到 y 280 上下：能走的往北到 270；婚礼台正前方从 320 起（新人站那儿），乐队底下从 300 起（乐队开场时会挖格子）
    "walk": [[[80, 270], [505, 270], [505, 320], [985, 320], [985, 300], [1400, 300], [1400, 270], [1456, 270], [1456, 860 + M], [80, 860 + M]],
             [[1450, 596 + M], [1500, 596 + M], [1500, 646 + M], [1450, 646 + M]]],
    "spawn": [768, 840 + M],
    # 新人站在婚礼台左前方、第一排空出来的那个位上（方案：第一排中间两个位留给新人下台敬酒），不挡横幅和 LED 屏
    "couple": [600, 330],
    "ambience": "ambience_55.json",
    # 婚礼台上的字（stage_signs.gd）：横幅挂在喜字下面（盖住花拱下沿和台面后半截，喜字整个露出来；
    # 画布最上面 130 像素在手机上是微信胶囊和左上角牌子那一条，挂那儿看不见）；LED 屏贴在台子正面台沿（y 216～246）
    "stage": {
        "banner": {"rect": [576, 140, 344, 50], "font_size": 18,
                   "lines": ["开席时间：2026 年 06 月 15 日", "爱女：阿鱼 & 贤婿：Toretto"]},
        "led": {"rect": [556, 216, 384, 30], "font_size": 18, "speed": 40},
    },
    "points": [
        {"id": "couple_table", "x": 620, "y": 420, "r": 70, "kind": "talk", "line": "table"},
        {"id": "door", "x": 768, "y": 840 + M, "r": 60, "kind": "door", "line": "leave"},
        {"id": "side_door", "x": 1500, "y": 600 + M, "r": 50, "kind": "door", "line": "backhall"},
    ],
}
json.dump(src, open(HERE / "scene_55.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("写好 scene_55.json，桌", len(place) - 2)
