"""后厅三间整间平移（10/4 方案 C，阿鱼「行，C」：照阿鱼图只上下翻、左右不变，godot/回执/方向方案C-上下翻-1004.png）。
后厅西→东从「化妆间、休息室、麻将室、后厨」改成「后厨、麻将室、休息室、化妆间」（化妆间挨宴会厅）。这次只平移，不放大、不重摆。

三间的脚本（room_backhall_*.py）照旧按平移前的坐标画——画一笔不改；这里管两头：
  读 layout.json 时，把整份挪回这间平移前的坐标（shift_layout(d, -DX[间])），PLAN、墙、门口照原来那样核；
  出 room.json 时，背景、每件家具的 x 加上 DX[间]。
平移量（画布 x）照「自己画的墙正好落在跟邻居共用的那道墙上」定，隔墙不用另画：
  化妆间 +1195：原来的西外墙（0～10）落到 1195～1205，跟休息室东墙重合；出图范围往东多裁 10 像素，
                本来就画了、一直被裁掉的东墙（331～341）带出来，当最东边外墙（1526～1536）
  休息室 +528：两道墙落在 859～869、1195～1205
  麻将室 −144：东墙（1003～1013）落到 859～869，跟休息室西墙重合；西墙（667～677）自己画，落到 523～533，挨后厨
  后厨（GPT 图，不在这里画）−1008：占 0～528，scripts/backhall.gd 里摆
新 layout.json 的墙：wall_1 523～533（后厨|麻将室）、wall_2 859～869（麻将室|休息室）、wall_3 1195～1205（休息室|化妆间）。
"""
import copy

DX = {"makeup": 1195, "lounge": 528, "mahjong": -144, "kitchen": -1008}


def shift_layout(d, dx):
    """整份布局左右挪 dx（家具 rect / x / x0 / x1 / pts、点、人、座位、站位、门牌、地上的块和字、走的范围）"""
    d = copy.deepcopy(d)

    def mv(o):
        if "rect" in o and isinstance(o["rect"], list) and len(o["rect"]) == 4:
            r = o["rect"]
            o["rect"] = [r[0] + dx, r[1], r[2] + dx, r[3]]
        for k in ("x", "x0", "x1"):
            if isinstance(o.get(k), (int, float)):
                o[k] += dx
        if isinstance(o.get("pts"), list):
            o["pts"] = [[p[0] + dx, p[1]] for p in o["pts"]]
        for sub in o.get("deco", []):
            mv(sub)

    for key in ("items", "points", "npcs", "seats", "stand_points", "signs", "flat"):
        for o in d.get(key, []):
            mv(o)
    if "walk" in d:
        d["walk"] = [[[p[0] + dx, p[1]] for p in poly] for poly in d["walk"]]
    return d


def shift_room_json(man, dx):
    """room.json 里背景、范围、每件家具的 x 加 dx"""
    man["background"]["x"] += dx
    if "room" in man:
        man["room"]["x0"] += dx
        man["room"]["x1"] += dx
    for p in man["props"]:
        p["x"] += dx
    return man
