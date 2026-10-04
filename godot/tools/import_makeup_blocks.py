#!/usr/bin/env python3
"""化妆间：照 GPT 交的积木拼回游戏（01 H 10/5 派，02 F 写）。
阿鱼 10/5：「让他去拆成零件给你坐标，你拼回去就可以了」「这个坐标不用你量，应该是GPT它自己量」。
任务原文：游戏制作中-gpt 和 claude 合作/claude-任务-化妆间拆件-1005.md；GPT 交到 …/003-后厅/化妆间-积木-v1/。

读交付目录里的 交付.json（base.png、blk_*.png、fg_*.png，坐标都是原图像素），缩到化妆间画布 576×1024（原图 ÷ 原图宽/576），出：
  assets/pixel_art/makeup_room_gpt/room.png、props/*.png、room.json
      entrance.gd 的 _pixel_art() 读：底图铺地上；blk 按 foot_y 跟人排前后；fg 永远在人前面
  assets/layered/scene_luoman_makeup/layout.json（化妆间布局，这份出了就不再用 make_makeup_room.py 的灰盒）
      footprint → 挡人的占地（灰盒色块藏掉，只挡人）；seat → 坐人的点；南门、出口、进门站的地方、屋名、「回后厅」牌照旧；
      第 67 版的人（新娘、化妆师、化妆助理）连同冒泡、点人说话、助理走一圈照旧挂（life: makeup）；别的座位坐替身

用法：python3 godot/tools/import_makeup_blocks.py <交付目录> [--check 拼回去对照图.png]
交付.json 的写法以任务原文为准；字段名认几种常见写法（零件 / parts / blocks / items，原图宽高 / width height），认不出就停、说缺什么。
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
OUT = os.path.join(GODOT, "assets", "pixel_art", "makeup_room_gpt")
RES = "res://assets/pixel_art/makeup_room_gpt/"
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_makeup", "layout.json")

W, H = 576, 1024
# 墙、门（画布坐标，照效果图：南墙顶面 918～930、正面 930～946，门洞两根门柱之间 242～334；北墙脚约 125）
FLOOR_TOP = 128          # 能走的最北一线（北墙脚往南一点）
FLOOR_BOT = 914          # 能走的最南一线（南墙顶面往北一点）
SIDE = (22, 554)         # 能走的东西两边
DOOR = (244, 332)        # 门洞
SOUTH_WALL = (930, 946)  # 南墙挡人的那一条
EXIT_Y = 990             # 出口点（回后厅）
SPAWN = (288, 900)       # 从后厅走进来站的地方


# ================================================================== 读交付.json
def _first(d, keys, default=None):
    for k in keys:
        if k in d:
            return d[k]
    return default


def load_delivery(folder):
    path = os.path.join(folder, "交付.json")
    d = json.load(open(path, encoding="utf-8"))
    size = _first(d, ["原图", "原图宽高", "image", "size", "canvas"])
    if isinstance(size, dict):
        sw, sh = _first(size, ["w", "width", "宽"]), _first(size, ["h", "height", "高"])
    elif isinstance(size, (list, tuple)):
        sw, sh = size[0], size[1]
    else:
        sw, sh = _first(d, ["width", "原图宽", "w"]), _first(d, ["height", "原图高", "h"])
    if not sw or not sh:
        raise SystemExit("交付.json 里没找到原图宽高（原图 / width、height）")
    parts = _first(d, ["零件", "parts", "blocks", "items", "pieces"])
    if parts is None:
        raise SystemExit("交付.json 里没找到零件清单（零件 / parts / blocks / items）")
    if isinstance(parts, dict):
        parts = [dict(v, file=v.get("file", k)) for k, v in parts.items()]
    base = _first(d, ["base", "底图"], "base.png")
    if isinstance(base, dict):
        base = base.get("file", "base.png")
    bad, out = [], []
    for p in parts:
        f = str(p.get("file", ""))
        if f == base or f.startswith("base"):
            continue
        miss = [k for k in ("file", "x", "y", "foot_y") if k not in p]
        if f.startswith("blk_") and "footprint" not in p:
            miss.append("footprint")
        if miss:
            bad.append("%s 缺 %s" % (f or p, "、".join(miss)))
            continue
        if not os.path.exists(os.path.join(folder, f)):
            bad.append("%s 文件不在" % f)
            continue
        out.append(p)
    if not os.path.exists(os.path.join(folder, base)):
        bad.append("底图 %s 不在" % base)
    if bad:
        raise SystemExit("交付.json 对不上：\n" + "\n".join(bad))
    return {"w": float(sw), "h": float(sh), "base": base, "parts": out, "raw": d}


# ================================================================== 缩到画布
def hard_alpha(im):
    """半透明一律取整（≥128 不透明，<128 全透明）：边缘硬、不带一圈半透明的底色"""
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    im.putalpha(a)
    return im


def scaled_box(p, s):
    """零件放回画布的左上角和大小：左上、右下各自取整，相邻零件不留缝"""
    x0, y0 = round(float(p["x"]) * s), round(float(p["y"]) * s)
    im_w, im_h = p["_size"]
    x1, y1 = round((float(p["x"]) + im_w) * s), round((float(p["y"]) + im_h) * s)
    return x0, y0, max(1, x1 - x0), max(1, y1 - y0)


def seats_of(p, s):
    st = p.get("seat")
    if not st:
        return []
    if isinstance(st[0], (int, float)):
        st = [st]
    return [(round(float(a) * s), round(float(b) * s)) for a, b in st]


# ================================================================== 布局
def kind_of(name):
    for k in ("stool", "pouf", "sofa", "armchair", "chair"):
        if k in name:
            return k
    return ""


def build_layout(props, s):
    items, npcs, stands = [], [], []
    seats = []   # (x, y, kind, name)
    for p in props:
        if p["fg"]:
            continue
        fx, fy, fw, fh = p["footprint"]
        r = [round(fx * s), round(fy * s), round((fx + fw) * s), round((fy + fh) * s)]
        h = max(4, r[1] - p["y"])          # 灰盒高：从占地上沿到图顶（只给比例工具、灰盒用；游戏里藏掉）
        items.append({"type": "box", "id": p["name"], "rect": r, "h": h, "top": "#c9a985", "front": "#8a6a48",
                      "part": "MK-GPT", "scale": {"name": p["name"]}})
        for (x, y) in p["seats"]:
            seats.append((x, y, kind_of(p["name"]), p["name"]))
    # 南墙两段（门洞两边）
    items.append({"type": "box", "id": "wall_s_0", "rect": [0, SOUTH_WALL[0], DOOR[0], SOUTH_WALL[1]], "h": 16, "top": "#8a6048", "front": "#5a3f30"})
    items.append({"type": "box", "id": "wall_s_1", "rect": [DOOR[1], SOUTH_WALL[0], W, SOUTH_WALL[1]], "h": 16, "top": "#8a6048", "front": "#5a3f30"})
    # ---- 人：新娘坐北墙化妆凳里偏中间那张（离门洞正中最近的），化妆师 1 站她右手边那道缝里，化妆助理在第一个首饰柜东边
    vanity = sorted([t for t in seats if t[2] == "stool" and t[1] < 300], key=lambda t: t[0])
    if not vanity:
        raise SystemExit("北墙化妆凳没有 seat（新娘坐哪）")
    mid_x = (DOOR[0] + DOOR[1]) / 2.0
    bk = min(range(len(vanity)), key=lambda k: (abs(vanity[k][0] - mid_x), vanity[k][0]))
    if bk + 1 < len(vanity) and vanity[bk][0] > mid_x:
        bk = max(0, bk - 1)   # 新娘坐门洞正中左边那张，化妆师站她右手边（正对红毯）
    bx, by = vanity[bk][0], vanity[bk][1]
    nx = vanity[bk + 1][0] if bk + 1 < len(vanity) else bx + 60
    m1x = (bx + nx) // 2
    npcs.append({"id": "bride", "who": "新娘（坐在化妆凳上，背对镜头；替身）", "x": bx, "y": by, "face": "up", "sit": True, "lm": "LM-BRIDE-01",
                 "life": "makeup", "approach": [bx - 30, by + 22], "standin": {"code": "LM-GUEST-02", "frame": 12, "rows": 60, "bottom": by - 17}})
    npcs.append({"id": "makeup_1", "who": "化妆师", "x": m1x, "y": by + 4, "face": "left", "look": "makeup_1", "lm": "LM-MAKEUP-01",
                 "life": "makeup", "approach": [m1x + 20, by + 26], "standin": {"code": "LM-GUEST-03", "frame": 4}})
    stands.append({"id": "makeup_artist_1", "name": "化妆师 1 站这（给新娘化妆，新娘右手边）", "x": m1x, "y": by + 4, "r": 14})
    jewel = sorted([p for p in props if "jewel" in p["name"] and not p["fg"]], key=lambda p: p["foot"])
    if jewel:
        j = jewel[0]
        jr = [round(v * s) for v in j["footprint"]]
        ax, ay = round((j["footprint"][0] + j["footprint"][2]) * s) + 14, round((j["footprint"][1] + j["footprint"][3]) * s) + 8
    else:
        ax, ay = 380, 380
    npcs.append({"id": "makeup_2", "who": "化妆助理", "x": ax, "y": ay, "face": "left", "look": "makeup_2", "lm": "LM-MAKEUP-02",
                 "life": "makeup", "approach": [ax - 20, ay + 22], "wander": ["stand_mk_gown", "stand_mk_red"],
                 "standin": {"code": "LM-GUEST-06", "frame": 4}})
    stands.append({"id": "makeup_artist_2", "name": "化妆助理站这（第一个首饰柜东南角）", "x": ax, "y": ay, "r": 14})
    # 助理走一圈：婚纱那排跟前、红喜服那排跟前（衣架着地线往南一点，过道里）
    def front_of(key, fallback):
        rk = [p for p in props if key in p["name"] and not p["fg"]]
        if not rk:
            return fallback
        p = rk[0]
        fx, fy, fw, fh = p["footprint"]
        return [round((fx + fw * 0.5) * s), round((fy + fh) * s) + 16]
    gx, gy = front_of("rack_e1", [470, 300])
    rx, ry = front_of("rack_w1", [100, 300])
    stands.append({"id": "stand_mk_gown", "name": "婚纱那排跟前（化妆助理看婚纱）", "x": gx, "y": gy, "r": 14})
    stands.append({"id": "stand_mk_red", "name": "红喜服那排跟前（化妆助理取衣服）", "x": rx, "y": ry, "r": 14})
    # ---- 别的座位坐替身（静静坐着，不冒泡、不能点）：化妆凳、圆墩、试衣间的凳子背对镜头；沙发、单人椅脸朝外、只露到腰
    looks = ["LM-GUEST-04", "LM-GUEST-05", "LM-GUEST-08", "LM-GUEST-10", "LM-GUEST-11"]
    k = 0
    for (x, y, kind, name) in seats:
        if (x, y) == (bx, by):
            continue
        down = kind in ("sofa", "armchair", "chair")
        sd = {"code": looks[k % len(looks)], "frame": 0 if down else 12, "rows": 46 if down else 60, "bottom": (y - 24) if down else (y - 17)}
        npcs.append({"id": "guest_%d" % k, "who": "来化妆的客人（替身，静静坐着；%s）" % name, "x": x, "y": y, "face": "down" if down else "up",
                     "sit": True, "standin": sd})
        k += 1
    # ---- 交互点：南门回后厅；换装点在试衣间（西边那间圆地毯上）
    fit = [p for p in props if "fit" in p["name"] and not p["fg"]]
    if fit:
        f = sorted(fit, key=lambda p: p["footprint"][0])[0]
        fx, fy, fw, fh = f["footprint"]
        dress = [round((fx + fw) * s) + 26, round((fy + fh) * s) - 6]
    else:
        dress = [150, 720]
    points = [{"id": "to_backhall", "x": (DOOR[0] + DOOR[1]) // 2, "y": EXIT_Y, "r": 30, "to": "backhall",
               "note": "南门出去回后厅走廊化妆间门口（后厅 to_makeup 那里）"},
              {"id": "dress", "x": dress[0], "y": dress[1], "r": 40,
               "note": "换装点（01 H 10/5：挪到试衣间；以后试衣服做成弹窗，像厨房那样）"}]
    walk = [[[SIDE[0], FLOOR_TOP], [SIDE[1], FLOOR_TOP], [SIDE[1], FLOOR_BOT], [SIDE[0], FLOOR_BOT]],
            [[DOOR[0], FLOOR_BOT - 10], [DOOR[1], FLOOR_BOT - 10], [DOOR[1], 1018], [DOOR[0], 1018]]]
    return {
        "scene": "scene_luoman_makeup",
        "title": "化妆间",
        "note": "罗曼山庄 · 化妆间（单独成一间屋）：照 GPT 效果图拆的积木拼回来（阿鱼 10/5「让他去拆成零件给你坐标，你拼回去就可以了」）。"
                "tools/import_makeup_blocks.py 照交付.json 出，别手改；items 是每件的地上占地（挡人，灰盒色块藏掉），seat 的地方坐人。",
        "size": [W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": list(SPAWN),
        "points": points,
        "walk": walk,
        "flat": [{"type": "rect", "rect": [0, 0, W, H], "color": "#2e211b"},
                 {"type": "label", "text": "回后厅", "x": DOOR[1] + 52, "y": 996}],   # 南门外的「去…」牌（游戏里的字）
        "items": items,
        "npcs": npcs,
        "stand_points": stands,
        "stand_points_note": "化妆师站哪、化妆助理起身走一圈去站的地方（lounge_life.gd 照 npcs 的 wander 读）",
        "life": {"room": "makeup", "data": "res://assets/backhall/makeup.json"},
        "pixel_art": [RES + "room.json"],
    }


def write_layout(d):
    with open(LAYOUT, "w", encoding="utf-8") as f:
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


# ================================================================== 主流程
def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    folder = args[0]
    check = sys.argv[sys.argv.index("--check") + 1] if "--check" in sys.argv else None
    dl = load_delivery(folder)
    s = W / dl["w"]
    if abs(dl["h"] * s - H) > 4:
        raise SystemExit("原图 %dx%d 缩到宽 576 后高 %.0f，跟化妆间画布 1024 对不上" % (dl["w"], dl["h"], dl["h"] * s))
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    base = Image.open(os.path.join(folder, dl["base"])).convert("RGBA").resize((W, H), Image.LANCZOS)
    base.putalpha(255)
    base.save(os.path.join(OUT, "room.png"))
    props, names = [], set()
    for p in dl["parts"]:
        f = str(p["file"])
        im = Image.open(os.path.join(folder, f)).convert("RGBA")
        p["_size"] = (float(p.get("w", im.width)), float(p.get("h", im.height)))
        x, y, w, h = scaled_box(p, s)
        im = hard_alpha(im.resize((w, h), Image.LANCZOS))
        name = os.path.splitext(f)[0]
        fg = name.startswith("fg_")
        name = name[4:] if name.startswith("blk_") else (name[3:] if fg else name)
        im.save(os.path.join(OUT, "props", f))
        names.add(f)
        props.append({"name": name, "file": f, "x": x, "y": y, "w": w, "h": h, "fg": fg,
                      "foot": 4000 if fg else round(float(p["foot_y"]) * s),   # fg 永远在人前面
                      "footprint": [float(v) for v in p.get("footprint", [0, 0, 0, 0])], "seats": seats_of(p, s), "img": im})
    for f in os.listdir(os.path.join(OUT, "props")):   # 改名、删掉的零件别留旧图
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(OUT, "props", f))
    man = {"note": "tools/import_makeup_blocks.py 照 GPT 交付.json 出，别手改。底图铺地上；每件零件左上角在 x/y，着地线 foot（跟人排前后）；"
                   "fg_ 的 foot 很大（永远在人前面）；hide 藏掉同名的占地灰盒（挡人照旧）",
           "source": os.path.abspath(folder),
           "background": {"png": RES + "room.png", "x": 0, "y": 0}, "room": {"x0": 0, "x1": W},
           "props": [{"id": "px_" + p["name"], "png": RES + "props/" + p["file"], "x": p["x"], "y": p["y"], "foot": p["foot"],
                      "hide": [] if p["fg"] else [p["name"]]} for p in props]}
    lay = build_layout(props, s)
    man["props"][0]["hide"] += ["wall_s_0", "wall_s_1"]   # 南墙画在底图里
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    write_layout(lay)
    print("拼了：底图 + %d 件（fg %d）；占地 %d 块，座位 %d 个，人 %d 位 → %s、%s" % (
        len(props), sum(1 for p in props if p["fg"]), sum(1 for p in props if not p["fg"]),
        sum(len(p["seats"]) for p in props), len(lay["npcs"]), OUT, LAYOUT))
    if check:
        out = base.copy()
        for p in sorted(props, key=lambda p: p["foot"]):
            out.alpha_composite(p["img"], (p["x"], p["y"]))
        out.save(check)
        print("拼回去的整间：%s" % check)


if __name__ == "__main__":
    main()
