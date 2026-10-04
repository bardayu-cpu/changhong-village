#!/usr/bin/env python3
"""化妆间（单独成一间屋）：照 room01「多」档灰盒用代码画的像素成品（01 H 10/4 派，02 F 画）。
阿鱼 10/4：「没进入一个房间应该是和进入宴会厅一样是一个沉浸式的感觉」「喜欢最多的那个，最右边」；不走 GPT 效果图。

画法照 docs/罗曼山庄画风.md 第 0 节、后厅三间第三版：1 倍颗粒、硬边、光从左上来、按着地线分层；蜜色宽木地板、拱形灯泡镜。
家具一件不新画：全部借后厅那间化妆室（room_backhall_makeup.py，06 第二版 + 第三版拱形镜，阿鱼点过头）的画法，
同一类多摆几份。灰盒里每件的占地、高跟那间的画一样大，这里只是把画好的那件挪到灰盒的位置（着地线对齐）。
墙、地板、红绸、灯笼、镜子也借那份的画法，按这间的宽、门、镜子位置重画一遍。

位置只从 assets/layered/scene_luoman_makeup/layout.json 取（tools/layout_court/make_makeup_room.py 出，摆法锁死）：
开头先核每件在不在、多大，对不上就停。粉色「人」色块不进图（room.json 里藏掉）；stand_points 照旧留在布局里给 07。
新娘、两位化妆师不画进图（游戏里照旧是 layout npcs 的替身）。

出 assets/pixel_art/makeup_room/：
  room.png        背景：整块画布 576×1024（北墙、镜子、红绸、灯笼、地板、红地毯、门里地垫、门外走廊一截、影子灯光）
  props/*.png     每件家具一张（裁到画了的那块），按着地线跟人排前后
  room.json       entrance.gd 的 _pixel_art() 读：背景左上角、每件左上角和着地线、要藏掉的灰盒 id
用法：python3 godot/tools/pixel_art/room_makeup.py [--preview 目录]（--preview 再出整间 1:1 干净图、放大 2 倍图）
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import backhall_floor
import room_backhall_makeup as mk   # 家具、墙、镜子的画法都在这份（按旧屋坐标画，画完挪过来）

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_makeup", "layout.json")
OUT = os.path.join(GODOT, "assets", "pixel_art", "makeup_room")
RES = "res://assets/pixel_art/makeup_room/"

W, H = 576, 1024
FLOOR_Y = 190                      # 北墙脚（化妆台占地 192 起，跟旧屋一样离墙 2 像素）
DY_WALL = FLOOR_Y - mk.FLOOR_Y     # 北墙整条照旧屋画，往上挪多少（-36）
CAP_Y0 = mk.CAP_Y0 + DY_WALL       # 墙顶剖面 68～78
SIDE_W, SIDE_E = (14, 24), (552, 562)   # 东西两道墙（只看得见墙顶那一条）；灰盒地板 24～552
DOOR = (252, 324)                  # 南墙门洞
WALL_RECT_Y = (960, 974)           # 南边矮墙占地（灰盒 wall_s_0/1，h 40）
FRONT_BOT = 974
FRONT_FACE = FRONT_BOT - 22        # 矮墙正面 952～974：画得跟后厅走廊那排矮墙一样高（22）；照灰盒 h 40 画，
FRONT_TOP = FRONT_FACE - 14        # 门口的礼盒、陪嫁箱下半截会被墙顶挡住。墙顶 938～952（占地前后 14）；挡人的占地照旧
DOORMAT = (264, 902, 312, 918)     # 门里地垫（进门站的地方 288,920 就在上面）

# 灰盒 id 前缀 → 旧屋里哪一件（PLAN 的 id）、怎么画
KINDS = [
    ("closet_cn", "mk_closet_cn", lambda: mk.prop_closet("mk_closet_cn", "cn")),
    ("closet_west", "mk_closet_west", lambda: mk.prop_closet("mk_closet_west", "west")),
    ("rack_cn_back_", "mk_rack_cn_back", mk.prop_rack_cn_back),
    ("rack_west_back_", "mk_rack_west_back", mk.prop_rack_west_back),
    ("rack_jp_back_", "mk_rack_jp_back", mk.prop_rack_jp_back),
    ("rack_ethnic_", "mk_rack_ethnic", mk.prop_rack_ethnic),
    ("island_", "mk_island", mk.prop_island),
    ("gown_form_", "mk_gown_form", mk.prop_gown_form),
    ("full_mirror_", "mk_full_mirror", mk.prop_full_mirror),
    ("crown_stand", "mk_crown_stand", mk.prop_crown_stand),
    ("silver_crown", "mk_silver_crown", mk.prop_silver_crown),
    ("sofa_", "mk_sofa", mk.prop_sofa),
    ("screen", "mk_screen", mk.prop_screen),
    ("shoes", "mk_shoes", mk.prop_shoes),
    ("pouf", "mk_pouf", mk.prop_pouf),
    ("gifts", "mk_gifts", mk.prop_gifts),
    ("trunk", "mk_trunk", mk.prop_trunk),
    ("flowers_w", "mk_flowers", lambda: mk.prop_flowers("mk_flowers")),
    ("flowers_e", "mk_flowers_e", lambda: mk.prop_flowers("mk_flowers_e")),
]


def frame(x0, y0, w, h):
    """换 mk 里明暗图、出图用的画布范围（ShadeMap 照这几个全局变量开）"""
    mk.X0, mk.Y0, mk.W, mk.H = x0, y0, w, h
    mk.X1, mk.Y1 = x0 + w, y0 + h


OLD_FRAME = (mk.X0, mk.Y0, mk.W, mk.H)


# ================================================================== 读布局、核对
def load_layout():
    d = json.load(open(LAYOUT, encoding="utf-8"))
    if d.get("size") != [W, H]:
        raise SystemExit("化妆间画布不是 %dx%d：%s" % (W, H, d.get("size")))
    items = [it for it in d["items"] if it.get("type") == "box"]
    by = {it["id"]: it for it in items}
    bad = []
    for wid in ("wall_s_0", "wall_s_1"):
        it = by.get(wid)
        if it is None or it["rect"][1] != WALL_RECT_Y[0] or it["rect"][3] != WALL_RECT_Y[1] or it["h"] != 40:
            bad.append("%s 变了：%s" % (wid, it and (it["rect"], it["h"])))
    if by["wall_s_0"]["rect"][2] != DOOR[0] or by["wall_s_1"]["rect"][0] != DOOR[1]:
        bad.append("门洞变了")
    if bad:
        raise SystemExit("化妆间布局跟这版画的对不上：\n" + "\n".join(bad))
    return d, items


def plan(items):
    """每件灰盒配上旧屋里的哪件画法；回 [(灰盒 id, 种类, 旧占地, 新占地, h)]，大小对不上就停"""
    out, bad = [], []
    for it in items:
        iid = it["id"]
        r, h = it["rect"], it["h"]
        if iid.startswith(("wall_s_", "person_", "mirror_")):
            continue
        if iid.startswith("vanity_") or iid.startswith("stool_"):
            k = int(iid.split("_")[1])
            i = k % 3                                     # 旧屋三台台面摆的东西各不一样，轮着用
            if iid.startswith("vanity_"):
                old = [mk.VANITY_X[i], 228, mk.VANITY_X[i] + mk.VW, 246]
                kind, oh = "vanity_%d" % i, 36
            else:
                old = [mk.STOOL_X[i] - 9, 258, mk.STOOL_X[i] + 9, 268]
                kind, oh = "stool_%d" % i, 22
        else:
            hit = [k for k in KINDS if iid == k[0] or (k[0].endswith("_") and iid.startswith(k[0]))]
            if not hit:
                bad.append("%s：旧屋里没有这种东西的画法" % iid)
                continue
            kind = hit[0][0]
            old, oh = mk.PLAN_BY_ID[hit[0][1]][3], mk.PLAN_BY_ID[hit[0][1]][4]
        if (old[2] - old[0], old[3] - old[1], oh) != (r[2] - r[0], r[3] - r[1], h):
            bad.append("%s：灰盒 %s h%s，画的那件 %s h%s" % (iid, r, h, old, oh))
            continue
        out.append((iid, kind, old, r, h))
    if bad:
        raise SystemExit("灰盒跟画法对不上：\n" + "\n".join(bad))
    return out


# ================================================================== 家具：照旧屋画一遍，挪到灰盒的位置
def draw_kinds(kinds):
    """每种画一遍（同一种多摆几份就用同一张）：回 {种类: (图, 左上角 x, y, 着地线)}，坐标是旧屋的"""
    frame(*OLD_FRAME)
    got = {}
    makers = {k[0]: k[2] for k in KINDS}
    for kind in sorted(kinds):
        if kind.startswith("vanity_"):
            i = int(kind[-1])
            L, foot = mk.prop_vanity(i)
            P = mk.ShadeMap()                           # 灯泡镜照亮台面（照旧屋 build 那样）
            a = mk.VANITY_X[i]
            P.rect(a + 2, 192, a + mk.VW - 2, 200, 0.5)
            P.apply(L)
        elif kind.startswith("stool_"):
            L, foot = mk.prop_stool(int(kind[-1]))
        else:
            L, foot = makers[kind]()
        box = L.im.getbbox()
        got[kind] = (L.im.crop(box), L.ox + box[0], L.oy + box[1], foot)
    return got


# ================================================================== 背景
def draw_runner(L, rect, bw=10):
    """中岛那一列脚下的长红地毯（照麻将室第三版门口那条：正红、回纹金边、中间一列金菱形）"""
    rx0, ry0, rx1, ry1 = rect
    KEY = mk.KEY
    L.rect(rx0, ry0, rx1, ry1, "rd3")
    cx = (rx0 + rx1) // 2
    for y in range(ry0 + bw + 8, ry1 - bw - 4, 18):
        L.poly([(cx, y - 3), (cx + 3, y), (cx, y + 3), (cx - 3, y)], "gd2")
        L.p(cx, y, "gd4")
        L.p(cx - 1, y - 1, "gd3")
    for (a, b) in ((rx0 + bw + 2, rx0 + bw + 3), (rx1 - bw - 3, rx1 - bw - 2)):
        L.rect(a, ry0 + bw + 2, b, ry1 - bw - 2, "rd2")
    L.rect(rx0 + bw + 2, ry0 + bw + 2, rx1 - bw - 2, ry0 + bw + 3, "rd2")
    L.rect(rx0 + bw + 2, ry1 - bw - 3, rx1 - bw - 2, ry1 - bw - 2, "rd2")
    L.rect(rx0, ry0, rx1, ry0 + bw, "gd3")
    L.rect(rx0, ry1 - bw, rx1, ry1, "gd3")
    L.rect(rx0, ry0, rx0 + bw, ry1, "gd3")
    L.rect(rx1 - bw, ry0, rx1, ry1, "gd3")
    off = (bw - 6) // 2
    for (by, flip) in ((ry0 + off, False), (ry1 - off - 7, True)):
        for x in range(rx0 + off, rx1 - off):
            for r in range(7):
                row = KEY[6 - r] if flip else KEY[r]
                if row[(x - rx0 - off) % 8] == "1":
                    L.p(x, by + r, "rd2")
    for (bx, flip) in ((rx0 + off, False), (rx1 - off - 7, True)):
        for y in range(ry0 + off + 7, ry1 - off - 7):
            for c in range(7):
                row = KEY[6 - c] if flip else KEY[c]
                if row[(y - ry0) % 8] == "1":
                    L.p(bx + c, y, "rd2")
    for (a, b) in ((0, 1), (bw - 1, bw)):
        L.rect(rx0 + a, ry0 + a, rx1 - a, ry0 + b, "rd1")
        L.rect(rx0 + a, ry1 - b, rx1 - a, ry1 - a, "rd1")
        L.rect(rx0 + a, ry0 + a, rx0 + b, ry1 - a, "rd1")
        L.rect(rx1 - b, ry0 + a, rx1 - a, ry1 - a, "rd1")
    for y in range(ry0 + 1, ry1 - 1):
        if y % 2 == 0:
            L.p(rx0 - 1, y, "hw5")
            L.p(rx1, y, "hw5")


RUG_OF = {"rack_cn_back": "cn", "rack_west_back": "west", "rack_jp_back": "tatami", "rack_ethnic": "ethnic"}


def zone_rugs(items):
    """每排衣架脚下一块分区地毯（照旧屋：中式红毯、西式白毯、日式榻榻米、民族彩织毯），东墙那列婚纱人台、全身镜脚下一条白毯；
    只是平铺在地上的，不挡人、不改摆法"""
    out = []
    for it in items:
        kind = next((v for k, v in RUG_OF.items() if it["id"].startswith(k + "_")), None)
        if kind:
            x0, y0, x1, y1 = it["rect"]
            out.append((kind, [max(SIDE_W[1], x0 - 6), y1 - 30, min(SIDE_E[0], x1 + 6), y1 + 16]))
    east = [it["rect"] for it in items if it["id"].startswith(("gown_form_", "full_mirror_"))]
    if east:
        out.append(("west", [min(r[0] for r in east) - 6, min(r[1] for r in east) - 18, SIDE_E[0], max(r[3] for r in east) + 14]))
    return out


def draw_zone_rug(L, kind, rect):
    x0, y0, x1, y1 = rect
    KEY = mk.KEY
    if kind == "cn":                                      # 深红底、金线、回纹边
        L.rect(x0, y0, x1, y1, "rd2")
        L.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, "gd2")
        L.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "rd3")
        for (by, flip) in ((y0 + 3, False), (y1 - 10, True)):
            for x in range(x0 + 3, x1 - 3):
                for r in range(7):
                    row = KEY[6 - r] if flip else KEY[r]
                    if row[(x - x0 - 3) % 8] == "1":
                        L.p(x, by + r, "gd2")
        L.rect(x0 + 3, y0 + 11, x1 - 3, y1 - 11, "rd2")
        for x in range(x0 + 6, x1 - 5, 8):
            L.p(x, (y0 + y1) // 2, "gd3")
    elif kind == "west":                                  # 米白底、粉边、四角蕾丝花
        L.rect(x0, y0, x1, y1, "pk")
        L.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "wl5")
        L.rect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, "wl4")
        for x in range(x0 + 4, x1 - 4):
            for y in range(y0 + 4, y1 - 4):
                if (x + y) % 6 == 0 and (x - y) % 6 == 0:
                    L.p(x, y, "pk2")
        for (cx, cy) in ((x0 + 8, y0 + 8), (x1 - 9, y0 + 8), (x0 + 8, y1 - 9), (x1 - 9, y1 - 9)):
            for (dx, dy) in ((0, -2), (0, 2), (-2, 0), (2, 0)):
                L.p(cx + dx, cy + dy, "pk")
            L.p(cx, cy, "pk0")
        for x in range(x0, x1, 2):
            L.p(x, y0, "wl5")
            L.p(x + 1, y1 - 1, "wl5")
    elif kind == "tatami":                                # 两张榻榻米（草绿黄、细纹、黑布边）
        mid = (x0 + x1) // 2
        for (a, b) in ((x0, mid), (mid, x1)):
            L.rect(a, y0, b, y1, "ik1")
            L.rect(a + 1, y0 + 3, b - 1, y1 - 3, "gd3")
            for y in range(y0 + 3, y1 - 3):
                if y % 3 == 0:
                    L.hl(a + 1, b - 1, y, "gr4")
                elif y % 3 == 1 and (a // 2 + y) % 2 == 0:
                    L.hl(a + 1, b - 1, y, "gd4")
            L.hl(a, b, y0 + 1, "ik2")
            L.hl(a, b, y1 - 2, "ik2")
            for x in range(a + 2, b - 1, 6):
                L.p(x, y0 + 1, "wl3")
                L.p(x, y1 - 2, "wl3")
    else:                                                 # 民族：彩条织毯 + 两头流苏
        cols = ["rd3", "gd3", "rd2", "gr3", "bl2", "rd4", "or", "ik1", "pk", "tl"]
        for y in range(y0, y1):
            c = cols[((y - y0) // 3) % len(cols)]
            for x in range(x0 + 2, x1 - 2):
                cc = c
                if (y - y0) % 3 == 1 and (x // 3) % 2 == 0:
                    cc = "wt" if c in ("ik1", "bl2", "rd2") else mk.shift(c, -1)
                L.p(x, y, cc)
        for y in range(y0 + 1, y1 - 1, 2):
            L.p(x0, y, "wl4")
            L.p(x0 + 1, y, "wl3")
            L.p(x1 - 2, y, "wl3")
            L.p(x1 - 1, y, "wl4")


def draw_doormat(L):
    x0, y0, x1, y1 = DOORMAT
    L.rect(x0, y0, x1, y1, "rd2")
    L.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "gd2")
    L.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "rd2")
    for k in range(5):
        cx = x0 + 8 + k * 8
        cy = (y0 + y1) // 2
        L.poly([(cx, cy - 2), (cx + 3, cy), (cx, cy + 2), (cx - 3, cy)], "rd4")
        L.p(cx, cy, "gd3")
    L.hl(x0, x1, y0, "rd3")
    L.hl(x0, x1, y1 - 1, "rd1")


def draw_petals(L):
    """门口到红地毯这一路撒几片花瓣（跟旧屋一样，两三个像素一片）"""
    import random
    rnd = random.Random(1004)
    for _ in range(26):
        x = rnd.randrange(214, 362)
        y = rnd.randrange(770, 896)
        c1, c2 = rnd.choice([("rd4", "rd5"), ("pk", "pk2"), ("pk", "wt"), ("rd4", "pk")])
        L.p(x, y, c1)
        if rnd.random() < 0.5:
            L.p(x + 1, y, c1)
            L.p(x + 1, y - 1, c2)
        else:
            L.p(x, y + 1, c1)
            L.p(x + 1, y, c2)


def north_wall(vanity_x):
    """北墙整条照旧屋画（墙纸、护墙板、红绸金结、小红灯笼、拱形灯泡镜、镜子照墙的光），画在旧屋坐标，回那一层"""
    frame(0, 100, W, 130)
    mk.WALL_W, mk.WALL_E = SIDE_W, SIDE_E
    mk.X1 = SIDE_E[1]
    mk.VANITY_X = tuple(vanity_x)
    # 红绸的结落在衣墙、化妆台之间的缝里（两头在墙上）
    gaps = [SIDE_W[1]]
    xs = sorted(vanity_x)
    gaps.append((92 + xs[0]) // 2)
    for a, b in zip(xs, xs[1:]):
        gaps.append((a + mk.VW + b) // 2)
    gaps.append((xs[-1] + mk.VW + 480) // 2)
    gaps.append(SIDE_E[0])
    mk.KNOTS = gaps
    L = mk.Layer(x0=0, y0=100, w=W, h=130)
    mk.draw_north_wall(L)
    for a in vanity_x:
        mk.draw_star_mirror(L, a)
    mk.draw_swag(L)
    for kx in mk.KNOTS[1:-1]:
        mk.draw_lantern(L, kx, 131)
    mk.wall_light(L)
    return L


def draw_corridor_strip(L):
    """南墙外面露出的一截走廊（米色石砖错缝，跟后厅走廊一家）"""
    import random
    rnd = random.Random(11)
    y0 = FRONT_BOT
    L.rect(0, y0, W, H, "wl2")
    for row, y in enumerate(range(y0, H, 12)):
        off = 0 if row % 2 == 0 else 24
        for x in range(-48 + off, W, 48):
            tone = rnd.choice(["wl2", "wl2", "wl3", "wl2", "wl1"])
            L.rect(x + 1, y + 1, x + 48, y + 12, tone)
            L.hl(x + 1, x + 48, y + 1, mk.shift(tone, 1))
            L.vl(x + 1, y + 1, y + 12, mk.shift(tone, 1))
            if rnd.random() < 0.3:
                L.p(x + rnd.randrange(4, 44), y + rnd.randrange(3, 10), mk.shift(tone, -1))
            L.vl(x, y, y + 12, "wl0")
        L.hl(0, W, y, "wl0")
    for x in range(W):                                   # 矮墙根一线影
        L.shade_px(x, y0, -1)
        if x % 2 == 0:
            L.shade_px(x, y0 + 1, -1)


def background(vanity_x, runner, rugs):
    frame(0, 0, W, H)
    L = mk.Layer(x0=0, y0=0, w=W, h=H)
    L.rect(0, 0, W, H, "void")
    backhall_floor.FLOOR_Y0 = FLOOR_Y
    backhall_floor.draw_floor_v3(L, SIDE_W[1], SIDE_E[0], FRONT_BOT, seed=7)
    for kind, rect in rugs:
        draw_zone_rug(L, kind, rect)
    draw_runner(L, runner)
    draw_doormat(L)
    draw_petals(L)
    wall = north_wall(vanity_x)
    frame(0, 0, W, H)
    L.im.alpha_composite(wall.im, (0, 100 + DY_WALL))
    # 门槛（矮墙占地那一条）
    a, b = DOOR
    y0, y1 = WALL_RECT_Y
    L.rect(a, y0, b, y1, "wd4")
    L.hl(a, b, y0, "wd2")
    L.hl(a, b, y0 + 1, "wd5")
    L.hl(a, b, y0 + 6, "wd3")
    L.hl(a, b, y0 + 7, "wd5")
    L.hl(a, b, y1 - 1, "wd2")
    draw_corridor_strip(L)
    L.rect(0, 0, SIDE_W[0], H, "void")
    L.rect(SIDE_E[1], 0, W, H, "void")
    return L


def floor_shading(L, placed, vanity_x):
    S = mk.ShadeMap()
    a, b = SIDE_W[1], SIDE_E[0]
    S.rect(a, FLOOR_Y, b, FLOOR_Y + 2, -1.5)              # 北墙脚
    S.rect(a, FLOOR_Y + 2, b, FLOOR_Y + 5, -0.5)
    S.rect(a, FLOOR_Y, a + 6, FRONT_TOP, -1.0)            # 西墙根（光从左上来，西墙投下一道）
    S.rect(a + 6, FLOOR_Y, a + 9, FRONT_TOP, -0.5)
    S.rect(b - 2, FLOOR_Y, b, FRONT_TOP, -0.5)
    S.rect(a, FRONT_TOP - 3, DOOR[0], FRONT_TOP, -0.5)    # 南边矮墙根（门洞那截不画）
    S.rect(DOOR[1], FRONT_TOP - 3, b, FRONT_TOP, -0.5)
    for (iid, kind, old, r, h) in placed:
        x0, y0, x1, y1 = r
        S.rect(x0 + 1, y0 + 1, x1 + 2, y1 + 2, -2.0 if h < 60 else -1.5, feather=1)
    for a0 in vanity_x:                                   # 化妆镜的灯照到台前地上
        S.ellipse(a0 + mk.VW // 2, FLOOR_Y + 30, 32, 12, 1.0, edge=1.5)
    mk.cone(S, (DOOR[0] + DOOR[1]) // 2, FRONT_TOP - 1, FRONT_TOP - 70, 40, 0.30, 1.0, edge=1.5)   # 门外走廊透进来一点光
    S.apply(L, clip=lambda x, y: FLOOR_Y <= y < FRONT_TOP and SIDE_W[1] <= x < SIDE_E[0])


# ================================================================== 墙（跟人排前后的那几道）
def prop_walls():
    """南边矮墙（顶面 + 朝走廊的木护墙板，门洞两边一对门套）和东西两道墙顶，一张图，着地线 974"""
    frame(0, 0, W, H)
    mk.FRONT_TOP, mk.FRONT_FACE, mk.FRONT_BOT = FRONT_TOP, FRONT_FACE, FRONT_BOT
    L = mk.Layer(x0=0, y0=0, w=W, h=H)
    for (a, b) in (SIDE_W, SIDE_E):                       # 东西墙：只看得见墙顶（剖开的一条），从北墙顶连到矮墙
        L.rect(a, CAP_Y0, b, FRONT_FACE, "wl4")
        L.vl(a + 1, CAP_Y0 + 1, FRONT_FACE, "wl5")
        L.vl(a, CAP_Y0, FRONT_FACE, "ol")
        L.vl(b - 1, CAP_Y0, FRONT_FACE, "ol")
        L.hl(a, b, CAP_Y0, "ol")
    for (a, b) in ((SIDE_W[0], DOOR[0]), (DOOR[1], SIDE_E[1])):
        L.rect(a, FRONT_TOP, b, FRONT_FACE, "wl4")
        L.hl(a, b, FRONT_TOP, "ol")
        L.hl(a, b, FRONT_TOP + 1, "wl5")
        L.hl(a, b, FRONT_FACE - 1, "wl3")
        mk.front_wall_face(L, a, b)
        if b == DOOR[0]:
            L.vl(b - 1, FRONT_TOP, FRONT_BOT, "ol")
        if a == DOOR[1]:
            L.vl(a, FRONT_TOP, FRONT_BOT, "ol")
    for (a, b) in ((DOOR[0] - 6, DOOR[0]), (DOOR[1], DOOR[1] + 6)):   # 门套
        L.rect(a, FRONT_TOP - 4, b, FRONT_BOT, "wd2")
        L.vl(a, FRONT_TOP - 4, FRONT_BOT, "wd4")
        L.vl(a + 1, FRONT_TOP - 3, FRONT_BOT, "wd3")
        L.vl(b - 1, FRONT_TOP - 4, FRONT_BOT, "wd1")
        L.hl(a, b, FRONT_TOP - 4, "wd5")
        L.hl(a, b, FRONT_TOP - 3, "wd4")
        L.rect(a, FRONT_BOT - 6, b, FRONT_BOT, "wd1")
        L.hl(a, b, FRONT_BOT - 6, "wd3")
    for (a, b) in (SIDE_W, SIDE_E):
        L.rect(a + 1, FRONT_TOP, b - 1, FRONT_FACE - 1, "wl4")
    L.outline(skip=lambda x, y: y >= FRONT_FACE or x < SIDE_W[0] or x >= SIDE_E[1])
    return L, FRONT_BOT


# ================================================================== 组装、出图
def build():
    d, items = load_layout()
    placed = plan(items)
    drawn = draw_kinds({p[1] for p in placed})
    by = {it["id"]: it for it in items}
    vanity_x = sorted(by[p[0]]["rect"][0] for p in placed if p[1].startswith("vanity_"))
    for it in items:                                      # 墙上的镜子跟化妆台对齐
        if it["id"].startswith("mirror_"):
            cx = (it["rect"][0] + it["rect"][2]) // 2
            if cx - mk.VW // 2 not in vanity_x:
                raise SystemExit("%s 没对着化妆台" % it["id"])
    runner = [f for f in d["flat"] if f.get("type") == "rect" and f.get("color") == "#c96a6a"]
    if len(runner) != 1:
        raise SystemExit("灰盒里中岛那条红地毯找不到")
    bg = background(vanity_x, runner[0]["rect"], zone_rugs(items))
    floor_shading(bg, placed, vanity_x)
    props = []
    for (iid, kind, old, r, h) in placed:
        im, x, y, foot = drawn[kind]
        dx, dy = r[0] - old[0], r[3] - old[3]
        hide = [iid]
        if iid.startswith("vanity_"):
            hide.append("mirror_" + iid.split("_")[1])    # 墙上的镜子画在背景里
        props.append({"id": "px_" + iid, "img": im, "x": x + dx, "y": y + dy, "foot": foot + dy, "hide": hide})
    walls, foot = prop_walls()
    box = walls.im.getbbox()
    hide = [it["id"] for it in items if it["id"].startswith(("wall_s_", "person_"))]   # 粉色「人」色块不进成品
    props.append({"id": "px_walls", "img": walls.im.crop(box), "x": box[0], "y": box[1], "foot": foot, "hide": hide})
    left = [it["id"] for it in items if not any(it["id"] in p["hide"] for p in props)]
    if left:
        raise SystemExit("这几件灰盒没画也没藏：%s" % left)
    return d, bg, props


def compose(bg, props):
    out = bg.im.copy()
    for p in sorted(props, key=lambda p: p["foot"]):
        out.alpha_composite(p["img"], (p["x"], p["y"]))
    return out


def name_of(p):
    return p["id"][3:]


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    d, bg, props = build()
    room = compose(bg, props)
    cols = mk.palette_count(room)
    print("整间 %s，颜色 %d 种" % (room.size, len(cols)))
    if len(cols) > 64:
        raise SystemExit("颜色超过 64 种（%d）" % len(cols))
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    mk.palette_count(bg.im)
    bg.im.save(os.path.join(OUT, "room.png"))
    man = {"note": "tools/pixel_art/room_makeup.py 生成，别手改。化妆间（单独成一间屋）照「多」档灰盒画的像素成品；背景左上角放在 background.x/y，"
                   "1 倍、不插值；每件家具左上角在 x/y，着地线 foot（跟人排前后用）；hide 是要藏掉的灰盒（挡人的占地照旧，粉色「人」色块也藏）",
           "background": {"png": RES + "room.png", "x": 0, "y": 0}, "room": {"x0": 0, "x1": W}, "props": []}
    names = set()
    for p in props:
        n = name_of(p)
        mk.palette_count(p["img"])
        p["img"].save(os.path.join(OUT, "props", n + ".png"))
        names.add(n + ".png")
        man["props"].append({"id": p["id"], "png": RES + "props/%s.png" % n, "x": p["x"], "y": p["y"], "foot": p["foot"], "hide": p["hide"]})
    for f in os.listdir(os.path.join(OUT, "props")):   # 改名、删掉的家具别留旧图
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(OUT, "props", f))
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print("背景 %s，家具 %d 件 → %s" % (bg.im.size, len(man["props"]), OUT))
    if preview:
        os.makedirs(preview, exist_ok=True)
        room.save(os.path.join(preview, "化妆间-一比一.png"))
        room.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(preview, "化妆间-放大2倍.png"))


if __name__ == "__main__":
    main()
