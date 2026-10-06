#!/usr/bin/env python3
"""化妆间：照 GPT 交的积木拼回游戏（01 H 10/5 派，02 F 写）。
阿鱼 10/5：「让他去拆成零件给你坐标，你拼回去就可以了」「这个坐标不用你量，应该是GPT它自己量」。
任务原文：游戏制作中-gpt 和 claude 合作/claude-任务-拆景台-1005.md（GPT 先做拆景台，阿鱼定颗粒度再拆）；拆景包交到 …/003-后厅/拆景/化妆间-v1-20261005/。

读拆景包里的 placement.json（base.png、blk_*.png、fg_*.png、shadow_*.png，坐标都是原图像素；拆景台 1005 任务原文第 5、6 条），缩到化妆间画布 576×1024（原图 ÷ 原图宽/576），出：
  assets/pixel_art/makeup_room_gpt/room.png、props/*.png、room.json
      entrance.gd 的 _pixel_art() 读：底图铺地上；blk 按 foot_y 跟人排前后；fg 永远在人前面
  assets/layered/scene_luoman_makeup/layout.json（化妆间布局，这份出了就不再用 make_makeup_room.py 的灰盒）
      footprint → 挡人的占地（灰盒色块藏掉，只挡人）；seat → 坐人的点；南门、出口、进门站的地方、屋名、「回后厅」牌照旧；
      第 67 版的人（新娘、化妆师、化妆助理）连同冒泡、点人说话、助理走一圈照旧挂（life: makeup）；别的座位坐替身

用法：python3 godot/tools/import_makeup_blocks.py <拆景包目录> [--check 拼回去对照图.png] [--report 检查.md]
placement.json 的写法以任务原文为准（格式照造景台第六节）；字段名认几种常见写法，认不出就停、说缺什么。
导入前先做两样静态检查（footprint 画没画到 foot_y、图有没有比着地线还往南伸），有问题照样导、全写进 --report；
人在每个能站的格子站一遍找挡错，另跑 tools/check_makeup_occlusion.py。
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

W, H = 576, 1024          # 化妆间画布（--canvas=540x960 改：10/5 照效果图代码画那版用 540×960，手机一屏看完整间）
# 墙、门照效果图（941×1672）的坐标写，按画布宽换算：南墙顶面 1500、正面 1520～1545，门洞两根门柱之间 395～545；北墙脚约 210
REF_W = 941.0
REF = {"floor_top": 210, "floor_bot": 1492, "side": (36, 905), "door": (395, 545), "south_wall": (1520, 1545),
       "exit_y": 1615, "spawn": (470, 1470)}


def set_canvas(w, h):
    """画布多大（墙、门这几样跟着按效果图换算）"""
    global W, H, FLOOR_TOP, FLOOR_BOT, SIDE, DOOR, SOUTH_WALL, EXIT_Y, SPAWN
    W, H = w, h
    k = w / REF_W
    FLOOR_TOP = round(REF["floor_top"] * k)        # 能走的最北一线（北墙脚往南一点）
    FLOOR_BOT = round(REF["floor_bot"] * k)        # 能走的最南一线（南墙顶面往北一点）
    SIDE = tuple(round(v * k) for v in REF["side"])
    DOOR = tuple(round(v * k) for v in REF["door"])
    SOUTH_WALL = tuple(round(v * k) for v in REF["south_wall"])
    EXIT_Y = round(REF["exit_y"] * k)
    SPAWN = tuple(round(v * k) for v in REF["spawn"])


set_canvas(W, H)


# ================================================================== 读拆景包（placement.json）
def _first(d, keys, default=None):
    for k in keys:
        if isinstance(d, dict) and k in d:
            return d[k]
    return default


def _rect(v):
    """[x, y, w, h] / {"rect": [...]} / {"x","y","w","h"} → [x, y, w, h]（原图像素）；认不出回 None"""
    if isinstance(v, dict):
        if "rect" in v:
            v = v["rect"]
        elif all(k in v for k in ("x", "y", "w", "h")):
            v = [v["x"], v["y"], v["w"], v["h"]]
    if isinstance(v, (list, tuple)) and len(v) == 4 and all(isinstance(t, (int, float)) for t in v):
        return [float(t) for t in v]
    return None


def _points(v):
    """seats：[x, y] / [[x, y], …] / [{"at": [x, y]} …] → [(x, y) …]"""
    if not v:
        return []
    if isinstance(v, (list, tuple)) and len(v) == 2 and all(isinstance(t, (int, float)) for t in v):
        return [(float(v[0]), float(v[1]))]
    out = []
    for e in v:
        if isinstance(e, dict):
            e = _first(e, ["at", "foot", "xy", "pos"], e)
            if isinstance(e, dict):
                e = [e.get("x"), e.get("y")]
        out.append((float(e[0]), float(e[1])))
    return out


def load_delivery(folder):
    """读拆景包：placement.json（拆景台 1005 任务原文第 5 条；没有就退回读 交付.json）。字段名认几种写法，认不出就停、说缺什么"""
    for fn in ("placement.json", "交付.json"):
        path = os.path.join(folder, fn)
        if os.path.exists(path):
            break
    else:
        raise SystemExit("%s 里没有 placement.json" % folder)
    d = json.load(open(path, encoding="utf-8"))
    size = _first(d, ["image", "原图", "size", "canvas"])
    sw = _first(size, ["w", "width", "宽"]) if isinstance(size, dict) else (size[0] if isinstance(size, (list, tuple)) else _first(d, ["width", "w", "原图宽"]))
    sh = _first(size, ["h", "height", "高"]) if isinstance(size, dict) else (size[1] if isinstance(size, (list, tuple)) else _first(d, ["height", "h", "原图高"]))
    if not sw or not sh:
        raise SystemExit("%s 里没找到整张图的宽高（image.w / width …）" % fn)
    parts = _first(d, ["items", "parts", "零件", "blocks", "pieces"])
    if parts is None:
        raise SystemExit("%s 里没找到零件清单（items / parts / 零件）" % fn)
    if isinstance(parts, dict):
        parts = [dict(v, id=v.get("id", k), file=v.get("file", k)) for k, v in parts.items()]
    files_info = _first(d, ["files"], {}) or {}
    base = _first(d, ["base", "background", "底图"], "base.png")
    if isinstance(base, dict):
        base = base.get("file", "base.png")
    base = os.path.basename(str(base))
    bad, out, shadows = [], [], []
    for p in parts:
        f = os.path.basename(str(p.get("file", "")))
        if not f or f == base or f.startswith("base"):
            continue
        if str(p.get("kind", "")) == "person":
            continue
        q = dict(files_info.get(f, {}))
        q.update(p)
        q["file"] = f
        if f.startswith("shadow_"):
            shadows.append(q)
            continue
        if "foot_y" not in q:
            ft = _first(q, ["foot", "anchor_xy"])
            if isinstance(ft, (list, tuple)) and len(ft) == 2:
                q["foot_y"] = ft[1]
        fp = _rect(_first(q, ["footprint", "占地"]))
        q["footprint"] = fp
        q["seats"] = _points(_first(q, ["seats", "seat", "座位"]))
        miss = [k for k in ("x", "y", "foot_y") if k not in q]
        if f.startswith("blk_") and fp is None:
            miss.append("footprint")
        if miss:
            bad.append("%s 缺 %s" % (f, "、".join(miss)))
            continue
        if not os.path.exists(os.path.join(folder, f)):
            bad.append("%s 文件不在" % f)
            continue
        out.append(q)
    if not os.path.exists(os.path.join(folder, base)):
        bad.append("底图 %s 不在" % base)
    if bad:
        raise SystemExit("%s 对不上：\n" % fn + "\n".join(bad))
    blocked = []
    bl = _first(d, ["blocked", "挡路"], [])
    if isinstance(bl, dict):
        bl = _first(bl, ["rects", "rect", "polygons", "list"], [])
    for b in bl or []:
        r = _rect(b)
        if r is None and isinstance(b, (list, tuple)) and b and isinstance(b[0], (list, tuple)):   # 多边形 → 外接矩形
            xs, ys = [float(t[0]) for t in b], [float(t[1]) for t in b]
            r = [min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)]
        if r is not None:
            blocked.append(r)
    doors = []
    for dr in _first(d, ["doors", "门"], []) or []:
        r = _rect(dr if not isinstance(dr, dict) or "rect" in dr or "x" in dr else dr.get("at"))
        if r is not None:
            doors.append(r)
    SPOTS.update(_first(d, ["spots", "点"], {}) or {})
    no_stand = [list(map(float, r)) for r in (d.get("no_stand") or [])]   # [x0, y0, x1, y1]：人站进来会被前面的家具盖住头肩（第二轮），只挡这块、不往外让
    return {"w": float(sw), "h": float(sh), "base": base, "parts": out, "shadows": shadows, "blocked": blocked, "doors": doors,
            "no_stand": no_stand, "empty_seat": d.get("empty_seat"), "name": fn, "raw": d}


def static_checks(dl, folder):
    """不进游戏就能查的两样（01 H 10/5）：
    1. footprint 没画到 foot_y（下沿离着地线超过 3 像素）——人能站进家具的「影子」里，会被挡错
    2. 零件的图比 foot_y 还往南伸（不透明像素超过着地线 4 像素以上）——人站在着地线南边会盖住它（比如前帘画进了后屏那张）
    回 [一行一处]（原图像素）"""
    bad = []
    for p in dl["parts"]:
        f = p["file"]
        if f.startswith("fg_"):
            continue
        fy = float(p["foot_y"])
        fp = p["footprint"]
        if fp is not None and abs(fp[1] + fp[3] - fy) > 3:
            bad.append("%s：footprint 下沿 %.0f，着地线 %.0f，差 %.0f（要画到着地线）" % (f, fp[1] + fp[3], fy, fp[1] + fp[3] - fy))
        im = Image.open(os.path.join(folder, f)).convert("RGBA")
        box = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()
        if box is not None:
            sy = float(im.height) / float(p.get("h", im.height))
            lowest = float(p["y"]) + box[3] / sy
            if lowest - fy > 4:
                bad.append("%s：图的最下沿 %.0f 比着地线 %.0f 还往南 %.0f 像素（人站在着地线南边会盖住这截）" % (f, lowest, fy, lowest - fy))
    return bad


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
    return [(round(a * s), round(b * s)) for (a, b) in p.get("seats", [])]


# ================================================================== 布局
def kind_of(name):
    for k in ("stool", "pouf", "sofa", "armchair", "chair"):
        if k in name:
            return k
    return ""


VIEW_H = 0   # --view_h= 给了就写进 layout（一屏看多高；化妆间 1.25 倍写 960，人跟别的屋子一样大）
SPOTS = {}   # 拆景包里写的点（spots：dress 换装点 …），load 时填


LOOKS = ["LM-GUEST-%02d" % i for i in (1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12)]   # 现有的宾客小人（11 种）
_TOP = {}


def top_row(code, frame):
    """这张小人图这一帧从第几行开始有像素（小孩 11、12 号从第 31 行起；大人 0）：坐着截前几行时要加上，不然小孩只露半个头（庄Z3 测 rc-makeup 第 8 节）"""
    key = (code, frame)
    if key not in _TOP:
        im = Image.open(os.path.join(GODOT, "assets", "characters", "lm", "chr_%s.png" % code)).getchannel("A")
        cols = max(1, im.width // 64)
        fx, fy = (frame % cols) * 64, (frame // cols) * 84
        bb = im.crop((fx, fy, fx + 64, fy + 84)).getbbox()
        _TOP[key] = bb[1] if bb else 0
    return _TOP[key]


def build_layout(props, s, blocked=(), no_stand=(), empty_seat=None):
    items, npcs, stands = [], [], []
    for k, r in enumerate(no_stand):   # 第二轮：高家具身后那一溜，人站进去会被盖住头肩，划成走不进（clear 0：只挡这块本身，旁边的路不跟着变窄）
        items.append({"type": "box", "id": "nostand_%d" % k, "rect": [round(r[0] * s), round(r[1] * s), round(r[2] * s), round(r[3] * s)],
                      "h": 1, "clear": 0, "top": "#5a3f30", "front": "#5a3f30", "note": "站进来头肩会被家具盖住"})
    for k, (bx0, by0, bw, bh) in enumerate(blocked):   # 拆景包里写的「人走不过去的地方」（墙、柜子背后）
        items.append({"type": "box", "id": "blocked_%d" % k, "rect": [round(bx0 * s), round(by0 * s), round((bx0 + bw) * s), round((by0 + bh) * s)],
                      "h": 4, "top": "#5a3f30", "front": "#5a3f30", "note": "拆景包 blocked"})
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
    u = W / 540.0   # 站位偏移跟着屋子大小走（化妆间 1.25 倍：675 宽 → ×1.25）；替身贴图的偏移是人的，不乘
    U = lambda v: round(v * u)
    nx = vanity[bk + 1][0] if bk + 1 < len(vanity) else bx + U(60)
    m1x = (bx + nx) // 2
    npcs.append({"id": "bride", "who": "新娘（坐在化妆凳上，背对镜头；替身）", "x": bx, "y": by, "face": "up", "sit": True, "lm": "LM-BRIDE-01",
                 "life": "makeup", "approach": [bx - U(30), by + U(22)], "standin": {"code": "LM-GUEST-02", "frame": 12, "rows": 60, "bottom": by - 17}})
    npcs.append({"id": "makeup_1", "who": "化妆师", "x": m1x, "y": by + U(4), "face": "left", "look": "makeup_1", "lm": "LM-MAKEUP-01",
                 "life": "makeup", "approach": [m1x + U(20), by + U(26)], "standin": {"code": "LM-GUEST-03", "frame": 4}})
    stands.append({"id": "makeup_artist_1", "name": "化妆师 1 站这（给新娘化妆，新娘右手边）", "x": m1x, "y": by + U(4), "r": 14})
    jewel = sorted([p for p in props if "jewel" in p["name"] and not p["fg"]], key=lambda p: p["foot"])
    if jewel:
        j = jewel[0]
        ax, ay = round((j["footprint"][0] + j["footprint"][2]) * s) + 14, round((j["footprint"][1] + j["footprint"][3]) * s) + 8   # 助理站哪不乘（乘了挪 2 像素会把首饰柜东边那条路堵窄）
    else:
        ax, ay = round(W * 0.66), round(H * 0.37)
    npcs.append({"id": "makeup_2", "who": "化妆助理", "x": ax, "y": ay, "face": "left", "look": "makeup_2", "lm": "LM-MAKEUP-02",
                 "life": "makeup", "approach": [ax - U(20), ay + U(22)], "wander": ["stand_mk_gown", "stand_mk_red"],
                 "standin": {"code": "LM-GUEST-06", "frame": 4}})
    stands.append({"id": "makeup_artist_2", "name": "化妆助理站这（第一个首饰柜东南角）", "x": ax, "y": ay, "r": 14})
    # 助理走一圈：婚纱那排跟前、红喜服那排跟前（衣架着地线往南一点，过道里）
    def front_of(key, fallback):
        rk = [p for p in props if key in p["name"] and not p["fg"]]
        if not rk:
            return fallback
        p = rk[0]
        fx, fy, fw, fh = p["footprint"]
        return [round((fx + fw * 0.5) * s), round((fy + fh) * s) + U(26)]
    gx, gy = front_of("rack_e1", [round(W * 0.8), round(H * 0.3)])
    rx, ry = front_of("rack_w1", [round(W * 0.17), round(H * 0.3)])
    stands.append({"id": "stand_mk_gown", "name": "婚纱那排跟前（化妆助理看婚纱）", "x": gx, "y": gy, "r": 14})
    stands.append({"id": "stand_mk_red", "name": "红喜服那排跟前（化妆助理取衣服）", "x": rx, "y": ry, "r": 14})
    # ---- 别的座位坐替身（静静坐着，不冒泡、不能点）：化妆凳、圆墩、试衣间的凳子背对镜头；沙发、单人椅脸朝外、只露到腰
    # 样子（第二轮：原来 13 个替身只用 5 种）：11 种全用上，还没人用的先用；不够了挑「离同样子那位最远」的，重样的一南一北拉开
    worn = [(n["standin"]["code"], n["x"], n["y"]) for n in npcs if "standin" in n]
    player_seats = []
    k = 0
    for (x, y, kind, name) in seats:
        if (x, y) == (bx, by):
            continue
        if empty_seat is not None and abs(x - empty_seat[0]) <= 2 and abs(y - empty_seat[1]) <= 2:
            down0 = kind in ("sofa", "armchair", "chair")
            player_seats.append({"id": "seat_%s_free" % name, "x": x, "y": y, "seat_y": (y - 24) if down0 else (y - 17),
                                 "face": "down" if down0 else "up", "life": "makeup"})
            continue   # 留给玩家坐（第二轮：原来坐满了，玩家坐不下）；lounge_life 认 life: makeup 的座位，走到跟前出「坐下」
        down = kind in ("sofa", "armchair", "chair")

        def score(code):
            same = [((x - wx) ** 2 + (y - wy) ** 2) ** 0.5 for (c, wx, wy) in worn if c == code]
            return (len(same), -min(same) if same else 0.0)
        # 新娘的脸只给新娘本人（庄Z3 测 rc-makeup：扶手椅上那位跟新娘同脸，比真新娘还显眼）
        bride_code = next((n["standin"]["code"] for n in npcs if n["id"] == "bride" and "standin" in n), "")
        look = min([c for c in LOOKS if c != bride_code], key=score)
        worn.append((look, x, y))
        fr = 0 if down else 12
        rows = min(84, (46 if down else 60) + top_row(look, fr))   # 小孩图从第 31 行起：多截这么多行，露出来的身子跟大人一样多
        sd = {"code": look, "frame": fr, "rows": rows, "bottom": (y - 24) if down else (y - 17)}
        npcs.append({"id": "guest_%d" % k, "who": "来化妆的客人（替身，静静坐着；%s）" % name, "x": x, "y": y, "face": "down" if down else "up",
                     "sit": True, "standin": sd})
        k += 1
    # ---- 交互点：南门回后厅；换装点在试衣间（西边那间圆地毯上）
    fit = [p for p in props if "fit" in p["name"] and not p["fg"]]
    if SPOTS.get("dress"):
        dress = [round(SPOTS["dress"][0] * s), round(SPOTS["dress"][1] * s)]
    elif fit:
        f = sorted(fit, key=lambda p: p["footprint"][0])[0]
        fx, fy, fw, fh = f["footprint"]
        dress = [round((fx + fw) * s) + 26, round((fy + fh) * s) - 6]
    else:
        dress = [round(W * 0.26), round(H * 0.7)]
    points = [{"id": "to_backhall", "x": (DOOR[0] + DOOR[1]) // 2, "y": EXIT_Y, "r": 30, "to": "backhall",
               "note": "南门出去回后厅走廊化妆间门口（后厅 to_makeup 那里）"},
              {"id": "dress", "x": dress[0], "y": dress[1], "r": 40,
               "note": "换装点（01 H 10/5：挪到试衣间；以后试衣服做成弹窗，像厨房那样）"}]
    walk = [[[SIDE[0], FLOOR_TOP], [SIDE[1], FLOOR_TOP], [SIDE[1], FLOOR_BOT], [SIDE[0], FLOOR_BOT]],
            [[DOOR[0], FLOOR_BOT - 10], [DOOR[1], FLOOR_BOT - 10], [DOOR[1], H - 6], [DOOR[0], H - 6]]]
    d = {
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
                 {"type": "label", "text": "回后厅", "x": DOOR[1] + 52, "y": EXIT_Y}],   # 南门外的「去…」牌（游戏里的字）
        "items": items,
        "npcs": npcs,
        "stand_points": stands,
        "stand_points_note": "化妆师站哪、化妆助理起身走一圈去站的地方（lounge_life.gd 照 npcs 的 wander 读）",
        "life": {"room": "makeup", "data": "res://assets/backhall/makeup.json"},
        "pixel_art": [RES + "room.json"],
    }
    if player_seats:
        d["seats"] = player_seats
    if VIEW_H:
        d["view_h"] = VIEW_H
    return d


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
    report = sys.argv[sys.argv.index("--report") + 1] if "--report" in sys.argv else None
    global OUT, RES, VIEW_H
    for a in sys.argv:
        if a.startswith("--canvas="):
            cw, ch = a.split("=", 1)[1].split("x")
            set_canvas(int(cw), int(ch))
        if a.startswith("--view_h="):
            VIEW_H = int(a.split("=", 1)[1])
        if a.startswith("--name="):   # 出到 assets/pixel_art/<name>/
            OUT = os.path.join(GODOT, "assets", "pixel_art", a.split("=", 1)[1])
            RES = "res://assets/pixel_art/%s/" % a.split("=", 1)[1]
    dl = load_delivery(folder)
    s = W / dl["w"]
    if abs(dl["h"] * s - H) > 4:
        raise SystemExit("原图 %dx%d 缩到宽 %d 后高 %.0f，跟化妆间画布 %d 对不上" % (dl["w"], dl["h"], W, dl["h"] * s, H))
    bad = static_checks(dl, folder)
    print("静态检查：%s" % ("没有问题" if not bad else "%d 处" % len(bad)))
    for b in bad:
        print("  " + b)
    global DOOR
    if dl["doors"]:   # 拆景包写了门：最南那个当南门
        dx0, dy0, dw, dh = max(dl["doors"], key=lambda r: r[1] + r[3])
        DOOR = (round(dx0 * s), round((dx0 + dw) * s))
        print("南门照 placement.json：x %d～%d" % DOOR)
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    base = Image.open(os.path.join(folder, dl["base"])).convert("RGBA")
    for sh in dl["shadows"]:   # 影子（可以半透明）并进底图，原图像素上贴
        im = Image.open(os.path.join(folder, sh["file"])).convert("RGBA")
        base.alpha_composite(im, (int(round(float(sh["x"]))), int(round(float(sh["y"])))))
    base = base.resize((W, H), Image.LANCZOS)
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
                      "footprint": p["footprint"] or [0.0, 0.0, 0.0, 0.0], "seats": seats_of(p, s), "img": im})
    for f in os.listdir(os.path.join(OUT, "props")):   # 改名、删掉的零件别留旧图
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(OUT, "props", f))
    man = {"note": "tools/import_makeup_blocks.py 照 GPT 交付.json 出，别手改。底图铺地上；每件零件左上角在 x/y，着地线 foot（跟人排前后）；"
                   "fg_ 的 foot 很大（永远在人前面）；hide 藏掉同名的占地灰盒（挡人照旧）",
           "source": os.path.abspath(folder),
           "background": {"png": RES + "room.png", "x": 0, "y": 0}, "room": {"x0": 0, "x1": W},
           "props": [{"id": "px_" + p["name"], "png": RES + "props/" + p["file"], "x": p["x"], "y": p["y"], "foot": p["foot"],
                      "hide": [] if p["fg"] else [p["name"]]} for p in props]}
    lay = build_layout(props, s, dl["blocked"], dl["no_stand"], dl["empty_seat"])
    man["props"][0]["hide"] += ["wall_s_0", "wall_s_1"] + ["blocked_%d" % k for k in range(len(dl["blocked"]))] \
        + ["nostand_%d" % k for k in range(len(dl["no_stand"]))]   # 南墙、挡路的地方都画在底图里；站不了的那几溜只挡人、不画
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    write_layout(lay)
    print("拼了：底图 + %d 件（fg %d）；占地 %d 块，座位 %d 个，人 %d 位 → %s、%s" % (
        len(props), sum(1 for p in props if p["fg"]), sum(1 for p in props if not p["fg"]),
        sum(len(p["seats"]) for p in props), len(lay["npcs"]), OUT, LAYOUT))
    if report:
        with open(report, "w", encoding="utf-8") as fh:
            fh.write("# 化妆间拆景包导入检查\n\n- 拆景包：`%s`（%s）\n- 零件 %d 件，影子 %d 张，挡路 %d 块，门 %d 个\n\n## 静态检查\n\n" % (
                folder, dl["name"], len(props), len(dl["shadows"]), len(dl["blocked"]), len(dl["doors"])))
            fh.write("没有问题。\n" if not bad else "".join("- %s\n" % b for b in bad))
        print("检查写进 %s" % report)
    if check:
        out = base.copy()
        for p in sorted(props, key=lambda p: p["foot"]):
            out.alpha_composite(p["img"], (p["x"], p["y"]))
        out.save(check)
        print("拼回去的整间：%s" % check)


if __name__ == "__main__":
    main()
