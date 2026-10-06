#!/usr/bin/env python3
"""娱乐室（原麻将室）接进游戏（庄Z1 10/6 派，庄Z2 写）：只做逻辑，画面先用 GPT 这包占位（阿鱼 10/6 嫌「星露谷味儿不够」，GPT 第 37 件照阿鱼家画风重出整图，布局不改）。
阿鱼：「ok ，选第一张，清空所有人，然后开始拆件吧」「只是画图示意，不可以玩的，只有麻将能玩」；牌面「没事就用 A」。

读共用文件夹 003-后厅/娱乐室-v1/（先读那里的「给Claude-先读我.md」）：
  底图 base_entertainment_room_wide_v2.png（2200×2880 最近邻 ÷2 → 游戏 1100×1440）、拼装表-加宽.json（89 件的 x、y、w、h、foot_y）、
  单件-游戏尺寸/（已经缩好的游戏尺寸，别再 ÷2）
**换图那一步**：GPT 新图到了，把新底图、新单件放进同一个文件夹（文件名不变）再跑一次就换完；这一版不抠画面细节（占位）。
整间一起取 64 色（八叉树、不抖动、透明二值，跟化妆间一样的自动一步）：不取的话占位底图 1.7 MB，超过提交检查「整间底图每屏 300 KB」（这间 3.06 屏，约 917 KB）。
改两处（庄Z4 定）：
  1 第一排四张麻将桌整组（桌 + 四把椅）往下挪 30，让开西北角茶几和东北角小凳、懒人沙发；挪完第一、二排之间过道 ≥ 70（跑的时候打印）
  2 电视 Y07 三帧 90×55，显示区 55×34：从帧中间裁 55×34、不缩放，120ms 一帧循环（room.json 里 frames）
占地按家具种类给（下沿对齐着地线）；座位：12 张麻将桌各 4 把、炸金花和贰柒拾小桌各 3 把、长沙发 3 座、单人沙发 1 座、长椅各 3 座、电视前小凳 1 座。
人：原来后厅麻将室那几位（长辈、宾客、打牌的，连同对话 assets/backhall/mahjong.json）照旧挂 life: mahjong，坐中间几桌；
  其余座位坐替身（现有宾客小人 11 种，没人用的先用，重样的拉开）；**玩家那把：地毯那桌（第二排中间）朝南那把**，空着，坐下开「摸两把」。
高家具身后：人站进去头肩被盖住一半以上的格子划成站不了（跟化妆间第二轮一样）。不写 view_h（铺像素图的屋子镜头本来就取整到 1）。
出 assets/pixel_art/entertainment_room/（room.png、props/、room.json）和 assets/layered/scene_luoman_mahjong/layout.json。

用法：python3 godot/tools/pixel_art/room_entertainment_gpt.py [GPT 文件夹] [--preview 目录]
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import room_makeup_gpt as share   # 只借它找共用文件夹
from room_makeup_125 import _covered, HIDE_OVER

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
GPT_DIR = os.path.join(share.SHARE, "娱乐室-v1")
NAME = "entertainment_room"
OUT = os.path.join(GODOT, "assets", "pixel_art", NAME)
RES = "res://assets/pixel_art/%s/" % NAME
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_mahjong", "layout.json")
W, H = 1100, 1440
ROW1 = ["mahjong_01", "mahjong_02", "mahjong_03", "mahjong_04"]   # 第一排四张（整组往下挪 30）
ROW1_DY = 30
PLAY_SEAT = "mahjong_06_s"                                        # 玩家那把：地毯那桌（第二排中间）朝南那把
# 地板（照底图量的）：北墙下沿 176、左右墙内侧 66～1036、南墙 1246；门洞两扇门开着，中间能走的 512～588
FLOOR = (66, 182, 1036, 1240)
DOOR = (512, 588)
EXIT_Y = 1400
SPAWN = (550, 1330)   # 进门站在门洞里（门正对着第四排中间那桌，站屋里会挡「回后厅」牌子的位置）
GRID = 12
# 占地：零件 → (往上多深, 两边各收多少)；下沿对齐着地线
FP = {"Y01": (34, 8), "Y02": (12, 5), "Y03": (32, 8), "Y04": (32, 8), "Y05-01": (30, 6), "Y05-02": (28, 6), "Y05-03": (22, 6),
      "Y06-01": (30, 6), "Y08-01": (12, 6), "Y08-02": (22, 8), "Y09-01": (34, 0), "Y09-02": (24, 0), "Y10-01": (20, 6),
      "Y11-01": (14, 18), "Y11-02": (10, 6)}
LOOKS = ["LM-GUEST-%02d" % i for i in (1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12)]
MOVERS_FROM = "589aa37"   # 后厅麻将室那 14 位还在后厅布局里的那一版（rc-makeup）
CHAIR = {"Y02-01": "n", "Y02-02": "s", "Y02-03": "w", "Y02-04": "e"}
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
            return [(name, cx, f + 2, "down", 48, f + 2 - 23)]
        if side == "s":
            return [(name, cx, f - 1, "up", 47, f - 1 - 24)]
        return [(name, cx, f + 2, "right" if side == "w" else "left", 47, f + 2 - 24)]
    if part == "Y05-01":   # 长沙发 3 座（脸朝外、只露到腰，跟化妆间沙发一样）
        return [("%s_%d" % (name, i), round(x + w * k), f + 3, "down", 46, f + 3 - 24) for i, k in enumerate((0.22, 0.5, 0.78))]
    if part == "Y05-02":
        return [(name, cx, f + 3, "down", 46, f + 3 - 24)]
    if part == "Y10-01":   # 南墙长椅 3 座：背对镜头、面朝屋里
        return [("%s_%d" % (name, i), round(x + w * k), f + 1, "up", 60, f + 1 - 17) for i, k in enumerate((0.2, 0.5, 0.8))]
    if part == "Y08-01":   # 电视前小凳：背对镜头看电视
        return [(name, cx, f + 1, "up", 60, f + 1 - 17)]
    return []


FRAME = {"down": 0, "left": 4, "right": 8, "up": 12}


def main():
    args = [a for k, a in enumerate(sys.argv[1:]) if not a.startswith("--") and (k == 0 or sys.argv[k] != "--preview")]
    gdir = args[0] if args else GPT_DIR
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    table = json.load(open(os.path.join(gdir, "拼装表-加宽.json"), encoding="utf-8"))
    if table["画布"] != [W, H]:
        raise SystemExit("拼装表画布 %s，应是 %d×%d" % (table["画布"], W, H))
    insts = [dict(it) for it in table["实例"]]
    for it in insts:   # 改 1：第一排整组往下挪
        if any(it["实例"].startswith(r + "_") for r in ROW1):
            it["y"] += ROW1_DY
            it["foot_y"] += ROW1_DY
    # 第一、二排之间过道：第一排南椅着地线 → 第二排北椅占地上沿
    r1 = max(it["foot_y"] for it in insts if it["实例"].startswith(tuple(r + "_s" for r in ROW1)))
    r2 = min(fp_of(it)[1] for it in insts if it["实例"] in ("mahjong_05_n", "mahjong_06_n", "mahjong_07_n"))
    print("第一、二排之间过道（第一排南椅着地线 %d → 第二排北椅占地上沿 %d）：%d 像素（要 ≥ 70）" % (r1, r2, r2 - r1))
    # 底图、零件（占位：不取 64 色）
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
    # 电视：插卡机挂在电视柜前，三帧从中间裁 55×34
    tv = by["tv_cabinet"]
    mounts = {m["实例"]: m for m in table["挂载件"]}
    con = mounts["tv_game_console"]
    con_im = Image.open(os.path.join(one, con["零件"] + ".png")).convert("RGBA")
    scr = mounts["tv_screen_game"]
    frames = []
    for f in scr["零件"]:
        fi = Image.open(os.path.join(one, f + ".png")).convert("RGBA")
        sw, sh = scr["显示宽"], scr["显示高"]
        l, t = (fi.width - sw) // 2, (fi.height - sh) // 2
        frames.append((f, fi.crop((l, t, l + sw, t + sh))))
    # 整间一套 64 色（底图 + 零件 + 插卡机 + 电视三帧一起取，全部重压）
    imgs = [base] + [p["img"] for p in pieces] + [con_im] + [im for (_, im) in frames]
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
    con_im = q(con_im)
    frames = [(f, q(im)) for (f, im) in frames]
    # 写出
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    for fn in os.listdir(os.path.join(OUT, "props")):
        if fn.endswith(".png") or fn.endswith(".png.import"):   # 连导入记录一起清（10/6 文件名改小写，旧的大写导入记录别留）
            os.remove(os.path.join(OUT, "props", fn))
    base.save(os.path.join(OUT, "room.png"))
    parts_done = set()
    props = []
    for p in sorted(pieces, key=lambda p: p["foot"]):
        fn = "blk_%s.png" % p["part"].lower()
        if p["part"] not in parts_done:
            p["img"].save(os.path.join(OUT, "props", fn))
            parts_done.add(p["part"])
        props.append({"id": "px_" + p["id"], "png": RES + "props/" + fn, "x": p["x"], "y": p["y"], "foot": p["foot"], "hide": [p["id"]]})
    con_im.save(os.path.join(OUT, "props", "blk_%s.png" % con["零件"].lower()))
    props.append({"id": "px_tv_game_console", "png": RES + "props/blk_%s.png" % con["零件"].lower(), "x": tv["x"] + con["局部x"], "y": tv["y"] + con["局部y"],
                  "foot": tv["foot"] + 1, "hide": []})
    fpaths = []
    for (f, im) in frames:
        im.save(os.path.join(OUT, "props", "tv_%s.png" % f.lower()))
        fpaths.append(RES + "props/tv_%s.png" % f.lower())
    props.append({"id": "px_tv_screen", "png": fpaths[0], "frames": fpaths, "frame_ms": int(scr["帧间隔毫秒"]),
                  "x": tv["x"] + scr["局部x"], "y": tv["y"] + scr["局部y"], "foot": tv["foot"] + 1, "hide": []})
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
        m = {k: v for k, v in n.items() if k not in ("x", "y", "face", "standin", "approach", "block")}
        m.update({"x": x, "y": y, "face": face, "sit": True, "standin": {"code": code, "frame": FRAME[face], "rows": rows, "bottom": bottom}})
        if "approach" in n:   # 走到哪跟他说话：桌角外边
            m["approach"] = [x + 46, y + (14 if face == "up" else -8)]
        npcs.append(m)
        worn.append((code, x, y))
    taken = {MOVE[n["id"]] for n in npcs}
    k = 0
    for (sname, x, y, face, rows, bottom) in seats:
        if sname == PLAY_SEAT:
            player = {"id": "seat_mahjong_play", "x": x, "y": y, "seat_y": bottom + 0, "face": face, "life": "mahjong", "game": "mahjong_pair",
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
                     "standin": {"code": look, "frame": FRAME[face], "rows": rows, "bottom": bottom}})
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
    hide_extra = ["nostand_%d" % i for i in range(len(no_stand))]
    props[0]["hide"] = props[0]["hide"] + hide_extra
    man = {"note": "tools/pixel_art/room_entertainment_gpt.py 照 GPT 娱乐室包（加宽版）出，别手改；画面是占位（GPT 第 37 件重出整图后再跑一次就换）。"
                   "底图铺地上；每件左上角在 x/y、着地线 foot 跟人排前后；frames 是电视三帧（frame_ms 一帧多久）；hide 藏掉同名的占地灰盒（挡人照旧）",
           "source": os.path.abspath(gdir), "background": {"png": RES + "room.png", "x": 0, "y": 0}, "room": {"x0": 0, "x1": W}, "props": props}
    json.dump(man, open(os.path.join(OUT, "room.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    lay = {
        "scene": "scene_luoman_mahjong", "title": "娱乐室",
        "note": "罗曼山庄 · 娱乐室（原麻将室，单独成一间屋）：tools/pixel_art/room_entertainment_gpt.py 出，别手改。items 是每件的地上占地（挡人，灰盒藏掉），"
                "nostand_* 是人站进去头肩会被家具盖住的地方（clear 0，只挡那块）；seats 里 seat_mahjong_play 是玩家那把（坐下开「摸两把」）",
        "size": [W, H], "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": list(SPAWN),
        "points": [{"id": "to_backhall", "x": (DOOR[0] + DOOR[1]) // 2, "y": EXIT_Y, "r": 30, "to": "backhall",
                    "note": "南门出去回后厅走廊娱乐室门口（后厅 to_mahjong 那里）"}],
        "walk": [[[FLOOR[0], FLOOR[1]], [FLOOR[2], FLOOR[1]], [FLOOR[2], FLOOR[3]], [FLOOR[0], FLOOR[3]]],
                 [[DOOR[0], FLOOR[3] - 10], [DOOR[1], FLOOR[3] - 10], [DOOR[1], H - 6], [DOOR[0], H - 6]]],
        "flat": [{"type": "rect", "rect": [0, 0, W, H], "color": "#2e211b"}, {"type": "label", "text": "回后厅", "x": DOOR[1] + 70, "y": EXIT_Y}],
        "items": items, "npcs": npcs, "seats": [player],
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
        out.alpha_composite(con_im, (tv["x"] + con["局部x"], tv["y"] + con["局部y"]))
        out.alpha_composite(frames[0][1], (tv["x"] + scr["局部x"], tv["y"] + scr["局部y"]))
        out.save(os.path.join(preview, "娱乐室-一比一.png"))


if __name__ == "__main__":
    main()
