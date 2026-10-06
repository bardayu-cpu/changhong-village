#!/usr/bin/env python3
"""娱乐室 v3：采用阿鱼 10/6 确认的右侧尺寸（1152×960），源件存于回执/娱乐室-v3-源件。
15 张麻将桌、两张长牌桌、沙发和闲坐椅；原后厅 14 位与对话迁移，地毯桌南椅留给玩家。
透明拆件按着地线排序；电视三帧挂在柜子层；占地与高家具遮头格生成可通行范围。
用法：python3 godot/tools/pixel_art/room_entertainment_v3.py [源件目录] [--preview 目录]
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from room_makeup_125 import _covered, HIDE_OVER

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
GPT_DIR = os.path.join(GODOT, "回执", "娱乐室-v3-源件")
NAME = "entertainment_room"
OUT = os.path.join(GODOT, "assets", "pixel_art", NAME)
RES = "res://assets/pixel_art/%s/" % NAME
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_mahjong", "layout.json")
W, H = 1152, 960
PLAY_SEAT = "mahjong_06_s"                                        # 玩家那把：地毯那桌（第二排中间）朝南那把
# v3 地板与南门可走边界，门旁盆栽另列占地。
FLOOR = (94, 172, 1084, 888)
DOOR = (516, 638)
EXIT_Y = 942
SPAWN = (576, 872)   # 进门后站在南侧门内
GRID = 12
# 占地：零件 → (往上多深, 两边各收多少)；下沿对齐着地线
FP = {"V3-MJ": (28, 6), "V3-CN": (10, 4), "V3-CS": (10, 4), "V3-CW": (24, 5), "V3-CE": (24, 5),
      "V3-RN": (10, 4), "V3-RS": (10, 4), "V3-RW": (24, 5), "V3-RE": (24, 5),
      "V3-PK": (28, 6), "V3-LC": (28, 6), "V3-SL": (24, 6), "V3-SS": (22, 5), "V3-CT": (20, 5),
      "V3-SRED": (10, 4), "V3-STV": (10, 4), "V3-WC": (22, 5), "V3-TV": (28, 6),
      "V3-LR": (10, 4), "V3-LN": (8, 4), "V3-LCAGE": (8, 6), "V3-LSIDE": (16, 5), "V3-LENTRY": (10, 4)}
LOOKS = ["LM-GUEST-%02d" % i for i in (1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12)]
# 打牌的妹妹（card_e）原来在后厅起身去糖果桌、茶几站一会：搬来以后换成北墙茶台前（倒杯茶）、东边柜子前（拿糖），站点在家具着地线往下 22
STAND_POINTS = [{"id": "stand_er_tea", "name": "茶台前（倒杯茶再回去）", "x": 790, "y": 204, "r": 14},
                {"id": "stand_er_candy", "name": "东边柜子前（拿糖）", "x": 736, "y": 200, "r": 14}]
WANDER = {"stand_mj_candy": "stand_er_candy", "stand_mj_tea": "stand_er_tea"}
MOVERS_FROM = "589aa37"   # 后厅麻将室那 14 位还在后厅布局里的那一版（rc-makeup）
CHAIR = {"V3-" + prefix + side: facing for prefix in ("C", "R") for side, facing in (("N", "n"), ("S", "s"), ("W", "w"), ("E", "e"))}
CHAIR["V3-WC"] = "e"


def semantic_name(it):
    import re
    name = it["实例"]
    match = re.fullmatch(r"麻将桌(\d+)([北南西东]椅)?", name)
    if match:
        return "mahjong_%02d" % int(match[1]) + ("_" + {"北椅": "n", "南椅": "s", "西椅": "w", "东椅": "e"}[match[2]] if match[2] else "_table")
    names = {"左下炸金花桌": "poker_table", "右下贰柒拾桌": "letters_table", "长沙发": "sofa_long", "单人沙发": "sofa_single",
             "沙发主茶几": "coffee", "沙发红方凳": "red_stool", "电视前小凳": "tv_stool", "东墙闲坐椅": "idle_chair", "电视柜和黑屏电视": "tv_cabinet"}
    if name in names:
        return names[name]
    for prefix, out in (("炸金花", "poker"), ("贰柒拾", "letters")):
        if name.startswith(prefix):
            return out + "_" + name[len(prefix):].replace("北左椅", "n_left").replace("北右椅", "n_right").replace("北椅", "n").replace("南椅", "s").replace("西椅", "w").replace("东椅", "e")
    return "lamp_" + it["零件"].lower() + "_" + str(it["x"])

# 原来后厅麻将室那几位（id、坐哪把）：长辈四位坐地毯那桌的北西东（南那把留玩家），其余坐地毯两边那两桌
MOVE = {"elder_n": "mahjong_06_n", "elder_w": "mahjong_06_w", "elder_e": "mahjong_06_e", "elder_s": "mahjong_05_s",
        "elder_5": "mahjong_05_n", "elder_6": "mahjong_05_w", "mj_guest_1": "mahjong_05_e", "mj_guest_2": "mahjong_07_s",
        "mj3_n": "mahjong_07_n", "mj3_w": "mahjong_07_w", "mj3_e": "mahjong_07_e",
        "card_n": "poker_n", "card_w": "poker_w", "card_e": "poker_e"}


def fp_of(it):
    for k in sorted(FP, key=len, reverse=True):
        if it["零件"].startswith(k):
            d, inset = FP[k]
            return [it["x"] + inset, it["foot_y"] - d, it["x"] + it["w"] - inset, it["foot_y"]]
    raise SystemExit("%s（%s）没给占地" % (it["实例"], it["零件"]))


def seats_of(it):
    """一件家具上能坐的地方：[(座位名, x, y, 朝哪, 截几行, 截图下沿)]（照后厅原来长辈坐椅子的样子，椅子 ×1.25 那几个数跟着放大）"""
    x, w, f, part, name = it["x"], it["w"], it["foot_y"], it["零件"], it["实例"]
    cx = round(x + w / 2)
    if part in CHAIR:
        side = CHAIR[part]
        if side == "n":
            return [(name, cx, f + 2, "down", 48, f + 2 - 35)]
        if side == "s":
            return [(name, cx, f - 1, "up", 47, f - 1 - 24)]
        return [(name, cx, f + 2, "right" if side == "w" else "left", 47, f + 2 - 24)]
    if part == "V3-SL":   # 长沙发 3 座（脸朝外、只露到腰，跟化妆间沙发一样）
        return [("%s_%d" % (name, i), round(x + w * k), f + 3, "down", 46, f + 3 - 24) for i, k in enumerate((0.22, 0.5, 0.78))]
    if part == "V3-SS":
        return [(name, cx, f + 3, "down", 46, f + 3 - 24)]
    if part in ("V3-STV", "V3-SRED"):   # 电视前小凳：背对镜头看电视
        return [(name, cx, f + 1, "up", 60, f + 1 - 17)]
    return []


FRAME = {"down": 0, "left": 4, "right": 8, "up": 12}


def main():
    args = [a for k, a in enumerate(sys.argv[1:]) if not a.startswith("--") and (k == 0 or sys.argv[k] != "--preview")]
    gdir = args[0] if args else GPT_DIR
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    table = json.load(open(os.path.join(gdir, "拼回表-游戏尺寸.json"), encoding="utf-8"))
    if table["画布"] != [W, H]:
        raise SystemExit("拼装表画布 %s，应是 %d×%d" % (table["画布"], W, H))
    insts = [dict(it) for it in table["实例"] if it["类别"] != "屏幕帧"]
    for it in insts:
        it["实例"] = semantic_name(it)
    # 底图与透明拆件：尺寸已经由 Z4 按阿鱼确认方案定好。
    base = Image.open(os.path.join(gdir, table["底图"])).convert("RGBA").resize((W, H), Image.NEAREST)
    base.putalpha(255)
    one = os.path.join(gdir, "单件-游戏尺寸")
    pieces = []
    for it in insts:
        im = Image.open(os.path.join(one, it["零件"] + ".png")).convert("RGBA")
        if im.size != (it["w"], it["h"]):
            raise SystemExit("%s：单件 %s，拼装表 %d×%d" % (it["实例"], im.size, it["w"], it["h"]))
        im.putalpha(im.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
        pieces.append({"id": it["实例"], "part": it["零件"], "img": im, "x": it["x"], "y": it["y"], "foot": it["foot_y"], "fp": fp_of(it), "it": it})
    by = {p["id"]: p for p in pieces}
    # 电视三帧：使用 v3 原屏幕尺寸与位置，不裁剪、不缩放。
    tv = by["tv_cabinet"]
    scr = next(it for it in table["实例"] if it["零件"] == "V3-G01")
    frames = [("V3-G0%d" % i, Image.open(os.path.join(one, "V3-G0%d.png" % i)).convert("RGBA")) for i in (1, 2, 3)]
    # 整间一套 64 色（底图、零件、电视三帧一起取，不抖动）
    imgs = [base] + [p["img"] for p in pieces] + [im for (_, im) in frames]
    sheet = Image.new("RGB", (max(i.width for i in imgs), sum(i.height for i in imgs)))
    yy = 0
    for i in imgs:
        sheet.paste(Image.composite(i.convert("RGB"), Image.new("RGB", i.size), i.getchannel("A")), (0, yy))
        yy += i.height
    pal = sheet.quantize(colors=64, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)

    def q(i):
        a = i.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
        t = i.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
        t.putalpha(a)
        return t
    base = q(base)
    for p in pieces:
        p["img"] = q(p["img"])
    frames = [(f, q(im)) for (f, im) in frames]
    # 写出
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    base.save(os.path.join(OUT, "room.png"))
    parts_done = set()
    props = []
    for p in sorted(pieces, key=lambda p: p["foot"]):
        fn = "blk_%s.png" % p["part"].lower()
        if p["part"] not in parts_done:
            p["img"].save(os.path.join(OUT, "props", fn))
            parts_done.add(p["part"])
        props.append({"id": "px_" + p["id"], "png": RES + "props/" + fn, "x": p["x"], "y": p["y"], "foot": p["foot"], "hide": [p["id"]]})
    fpaths = []
    for (f, im) in frames:
        im.save(os.path.join(OUT, "props", "tv_%s.png" % f.lower()))
        fpaths.append(RES + "props/tv_%s.png" % f.lower())
    props.append({"id": "px_tv_screen", "png": fpaths[0], "frames": fpaths, "frame_ms": 140,
                  "x": scr["x"], "y": scr["y"], "foot": tv["foot"] + 1, "hide": []})
    # 站不了：头肩被盖住一半以上（占地 + 一格里 5×5 个点）
    alphas = [({"x": p["x"], "y": p["y"], "foot": p["foot"]}, p["img"].getchannel("A")) for p in pieces]
    sub = (-6, -3, 0, 3, 5)
    no_stand, n_hid = [], 0
    for j in range(H // GRID):
        cy = j * GRID + GRID // 2
        if not (FLOOR[1] <= cy <= FLOOR[3]):
            continue
        run = None
        for i in range(W // GRID + 1):
            cx = i * GRID + GRID // 2
            hid = FLOOR[0] <= cx <= FLOOR[2] and any(_covered(alphas, cx + dx, cy + dy) > HIDE_OVER for dy in sub for dx in sub)
            if hid:
                n_hid += 1
                run = [cx, cx] if run is None else [run[0], cx]
            elif run is not None:
                no_stand.append([run[0] - 5, cy - 5, run[1] + 5, cy + 5])
                run = None
        if run is not None:
            no_stand.append([run[0] - 5, cy - 5, run[1] + 5, cy + 5])
    print("站进去头肩会被盖住一半以上的格子：%d 个（%d 溜）" % (n_hid, len(no_stand)))
    # 座位、人
    seats = []
    for p in pieces:
        seats.extend(seats_of(p["it"]))
    # 原来那 14 位从后厅布局搬走以前那一版读（backhall_mahjong_door.py 已经把他们从后厅删了）
    import subprocess
    old = json.loads(subprocess.run(["git", "show", "%s:godot/assets/layered/scene_luoman_backhall/layout.json" % MOVERS_FROM],
                                    cwd=GODOT, capture_output=True, check=True).stdout.decode("utf-8"))
    movers = {n["id"]: n for n in old["npcs"] if str(n.get("life", "")) == "mahjong"}
    seat_at = {s[0]: s for s in seats}
    npcs, worn, player = [], [], None
    for nid, seat in MOVE.items():   # 原来那几位（带对话）先坐
        n = movers.get(nid)
        if n is None or seat not in seat_at:
            continue
        _, x, y, face, rows, bottom = seat_at[seat]
        code = n["standin"]["code"]
        m = {k: v for k, v in n.items() if k not in ("x", "y", "face", "standin", "approach", "block", "stand")}   # stand 是后厅的坐标，这里按座位重算
        if "wander" in m:   # 起身走动去的站点换成这间屋里的
            m["wander"] = [WANDER[w] for w in m["wander"] if w in WANDER]
        m.update({"x": x, "y": y, "face": face, "sit": True, "standin": {"code": code, "frame": FRAME[face], "rows": 77 if code in ("LM-GUEST-11", "LM-GUEST-12") else rows, "bottom": bottom}})
        if "approach" in n:   # 走到哪跟他说话：桌角外边
            m["approach"] = [x + 46, y + (14 if face == "up" else -8)]
        npcs.append(m)
        worn.append((code, x, y))
    taken = {MOVE[n["id"]] for n in npcs}
    k = 0
    for (sname, x, y, face, rows, bottom) in seats:
        if sname == PLAY_SEAT:
            player = {"id": "seat_mahjong_play", "x": x, "y": y, "seat_y": bottom + 0, "face": face, "life": "mahjong", "game": "mahjong_pair", "stand": [x + 54, y + 34],
                      "note": "玩家那把：地毯那桌朝南那把（庄Z1 10/6）；坐下开「摸两把」（minigames.json 的 mahjong_pair）"}
            continue
        if sname in taken:
            continue

        def score(code):
            same = [((x - wx) ** 2 + (y - wy) ** 2) ** 0.5 for (c, wx, wy) in worn if c == code]
            return (len(same), -min(same) if same else 0.0)
        look = min(LOOKS, key=score)
        worn.append((look, x, y))
        npcs.append({"id": "eg_%d" % k, "who": "来玩的客人（替身，静静坐着；%s）" % sname, "x": x, "y": y, "face": face, "sit": True,
                     "standin": {"code": look, "frame": FRAME[face], "rows": 77 if look in ("LM-GUEST-11", "LM-GUEST-12") else rows, "bottom": bottom}})
        k += 1
    if player is None:
        raise SystemExit("没找到玩家那把 %s" % PLAY_SEAT)
    # 布局
    items = []
    for p in pieces:
        r = p["fp"]
        items.append({"type": "box", "id": p["id"], "rect": r, "h": max(4, r[1] - p["y"]), "top": "#c9a985", "front": "#8a6a48",
                      "part": "ER-GPT", "scale": {"name": p["part"]}})
    for i, r in enumerate(no_stand):
        items.append({"type": "box", "id": "nostand_%d" % i, "rect": r, "h": 1, "clear": 0, "top": "#5a3f30", "front": "#5a3f30",
                      "note": "站进来头肩会被家具盖住"})
    for name, rect in (("door_plant_left", [442, 850, 489, 894]), ("door_plant_right", [666, 850, 716, 894]), ("poker_wall_gap", [96, 876, 108, 888])):
        items.append({"type": "box", "id": name, "rect": rect, "h": 1, "clear": 4, "top": "#5a3f30", "front": "#5a3f30", "on_art": True})
    hide_extra = ["nostand_%d" % i for i in range(len(no_stand))]
    props[0]["hide"] = props[0]["hide"] + hide_extra
    man = {"note": "tools/pixel_art/room_entertainment_v3.py 生成；采用阿鱼确认的娱乐室 v3 游戏尺寸。"
                   "底图铺地上；每件左上角在 x/y、着地线 foot 跟人排前后；frames 是电视三帧（frame_ms 一帧多久）；hide 藏掉同名的占地灰盒（挡人照旧）",
           "source": os.path.abspath(gdir), "background": {"png": RES + "room.png", "x": 0, "y": 0}, "room": {"x0": 0, "x1": W}, "props": props}
    json.dump(man, open(os.path.join(OUT, "room.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    lay = {
        "scene": "scene_luoman_mahjong", "title": "娱乐室",
        "note": "罗曼山庄 · 娱乐室（原麻将室，单独成一间屋）：tools/pixel_art/room_entertainment_v3.py 出，别手改。items 是每件的地上占地（挡人，灰盒藏掉），"
                "nostand_* 是人站进去头肩会被家具盖住的地方（clear 0，只挡那块）；seats 里 seat_mahjong_play 是玩家那把（坐下开「摸两把」）",
        "size": [W, H], "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": list(SPAWN),
        "points": [{"id": "to_backhall", "x": (DOOR[0] + DOOR[1]) // 2, "y": EXIT_Y, "r": 30, "to": "backhall",
                    "note": "南门出去回后厅走廊娱乐室门口（后厅 to_mahjong 那里）"}],
        "walk": [[[FLOOR[0], FLOOR[1]], [FLOOR[2], FLOOR[1]], [FLOOR[2], FLOOR[3]], [FLOOR[0], FLOOR[3]]],
                 [[DOOR[0], FLOOR[3] - 10], [DOOR[1], FLOOR[3] - 10], [DOOR[1], H - 6], [DOOR[0], H - 6]]],
        "flat": [{"type": "rect", "rect": [0, 0, W, H], "color": "#2e211b"}, {"type": "label", "text": "回后厅", "x": DOOR[1] + 70, "y": EXIT_Y}],
        "items": items, "npcs": npcs, "seats": [player],
        "stand_points": STAND_POINTS,
        "stand_points_note": "站人的地方：NPC 起身走动去站一会（lounge_life.gd 照 npcs 的 wander 读）；打牌的妹妹原来在后厅去糖果桌、茶几，搬来以后去茶台、东边柜子",
        "life": {"room": "mahjong", "data": "res://assets/backhall/mahjong.json"},
        "pixel_art": [RES + "room.json"],
    }
    os.makedirs(os.path.dirname(LAYOUT), exist_ok=True)
    with open(LAYOUT, "w", encoding="utf-8") as fh:
        fh.write("{\n")
        keys = list(lay.keys())
        for i, kk in enumerate(keys):
            v = lay[kk]
            comma = "," if i < len(keys) - 1 else ""
            if isinstance(v, list) and v and isinstance(v[0], dict):
                fh.write(' "%s": [\n' % kk)
                for jj, x in enumerate(v):
                    fh.write("  " + json.dumps(x, ensure_ascii=False) + ("," if jj < len(v) - 1 else "") + "\n")
                fh.write(" ]%s\n" % comma)
            else:
                fh.write(' "%s": %s%s\n' % (kk, json.dumps(v, ensure_ascii=False), comma))
        fh.write("}\n")
    print("娱乐室：%d×%d，家具 %d 件，座位 %d 个（玩家 1、人 %d：搬来的 %d、替身 %d），电视 %d 帧 → %s、%s" % (
        W, H, len(pieces), len(seats), len(npcs), len(taken), k, len(frames), OUT, LAYOUT))
    if preview:
        os.makedirs(preview, exist_ok=True)
        out = base.copy()
        for p in sorted(pieces, key=lambda p: p["foot"]):
            out.alpha_composite(p["img"], (p["x"], p["y"]))
        out.alpha_composite(frames[0][1], (scr["x"], scr["y"]))
        out.save(os.path.join(preview, "娱乐室-一比一.png"))


if __name__ == "__main__":
    main()
