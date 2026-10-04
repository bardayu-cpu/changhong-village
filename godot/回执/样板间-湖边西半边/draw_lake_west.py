#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""罗曼山庄湖边 · 西半边（x 0～1536）用代码画：照左右翻转的效果图 1（小半岛亭子、游船码头、湖尽头），
画法跟东半边一套（lake_engine.py = 东半边 draw_lake_ref2.py 原样拷贝，调色板同名同值）。

坐标：画的时候全用「东半边自己的坐标」x_e（西半边是 -1536～0），这样噪声、石板缝、瓦垄、草色、远山、水纹在 x 1536 那条缝上
自己就连着；出图时整体加 1536 = 游戏画布坐标（西半边就是 0～1536）。下面布局常数用游戏坐标写、G() 换算。
规矩照 docs/罗曼山庄画风.md 第 0 节：1 倍颗粒、硬边、整块 ≤64 色、光从左上、深褐描边、按着地线分层、图上不写字。

用法：
  python3 draw_lake_west.py           出西半边（layers/、layout_west.json）+ 整块拼图、手机图、对照、核对图
  python3 draw_lake_west.py --east    先重出东半边（lake_engine.py → east/），再出上面这些
  python3 draw_lake_west.py r3        另外把整块、半尺寸存成 rounds/r3_*.png（每轮存档）
"""
import json
import math
import os
import random
import subprocess
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lake_engine as E  # noqa: E402
from lake_engine import C, Layer, scr, gnd, shift, is_ramp, h2, vnoise, dith, quant, mix, canopy, LIGHT3, norm3  # noqa: E402

REPO = E.REPO
REF1 = os.path.join(REPO, "docs", "参考图", "湖边效果图1-左右翻转-湖尽头-阿鱼10-03.png")
LAYER_DIR = os.path.join(HERE, "layers")
EAST_DIR = os.path.join(HERE, "east")
ROUND_DIR = os.path.join(HERE, "rounds")
XO = 1536                         # 游戏 x = x_e + 1536
X0, X1 = -1536, 0                 # 西半边在 x_e 里的范围
W, H = 1536, 1280
FAR_Y = E.FAR_Y
WALL_Y, WALL_TOP, WALL_T = E.WALL_Y, E.WALL_TOP, E.WALL_T


def G(gx):
    """游戏坐标 → x_e"""
    return gx - XO


def GM(xe):
    """x_e → 游戏坐标（整数）"""
    return int(round(xe)) + XO


# ================================================================== 布局（游戏坐标；改一处全图跟着走）
GATE_C, GATE_R = (G(768), 990), 58        # 西头月亮门（跟东头 2304 对着 1536 镜像，灰盒原来 740）
PLAZA = (G(540), G(1000), 846, 888)        # 门里小广场（x0 x1 y0 y1）
PATH_S = (G(712), G(824), 886, 1290)       # 门里门外那段石板路（穿过月亮门一直到画布底，往南以后通果园 A）
LANDING = (G(852), G(964), 788, 848)       # 广场到栈桥那一截石板
PIER = (G(864), G(952), 616, 798)          # 栈桥（蜜色木，2 米宽）
HEAD = (G(800), G(1016), 558, 618)         # 码头平台（栈桥头上横着一块，南边两段侧面看得到）
PAV = dict(gx=556, gy=548, RP=2.3, RC=1.6, RE=2.12, RT=2.66, HC=2.5, HR=2.35)   # 半岛亭子（中心游戏坐标、半径米）
BENCH_W = (G(1300), G(1372), 812)          # 长凳（往东小路北沿、面朝湖，跟东头那张对着）
FISH = [(G(1150), 800), (G(1462), 800)]    # 两个钓鱼的位置（灰盒 1170 / 1440，小凳在这）
TERRACE = (G(62), 500, 40)                 # 湖尽头看湖的小石台（圆心、半径）

# 往东接东半边的湖边小路：中线照东头 west_yc 同一条式子（x_e=0 那里 y 838、斜率一样）
PATH_HW = 21


def lake_yc(xe):
    y0 = 838 + 6 * math.sin(xe / 90.0)
    if xe >= -520:
        return y0
    t = min(1.0, (-520 - xe) / 80.0)
    t = t * t * (3 - 2 * t)
    return (838 + 6 * math.sin(-520 / 90.0)) * (1 - t) + 867 * t


# 上半岛的石板路、往湖尽头的石板路（游戏坐标折线，画成圆头粗线）
PEN_PATH = [(606, 852), (614, 800), (612, 752), (601, 706), (586, 664), (570, 634), (558, 612)]
PEN_HW = 23
WEST_PATH = [(560, 868), (470, 868), (396, 862), (326, 846), (262, 818), (210, 782), (170, 738), (138, 690),
             (112, 640), (92, 592), (76, 546), (66, 506)]
WEST_HW = 21


def catmull(pts, n=10):
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(0, i - 1)]
        p1 = pts[i]
        p2 = pts[i + 1]
        p3 = pts[min(len(pts) - 1, i + 2)]
        for k in range(n):
            t = k / float(n)
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(pts[-1])
    return out


# ---- 亭子（六角，平台跟地面一样高；北半边伸到水上）
PGX, PGY = gnd(G(PAV["gx"]), PAV["gy"])
RP, RC, RE, RT, HC, HR = PAV["RP"], PAV["RC"], PAV["RE"], PAV["RT"], PAV["HC"], PAV["HR"]
PCX = G(PAV["gx"])


def hex_v(ang, R=None):
    R = RP if R is None else R
    a = math.radians(ang)
    return scr(PGX + R * math.cos(a), PGY + R * math.sin(a))


FRONT_Y = scr(PGX, PGY - RP * 0.8660254)[1]     # 台子正南那条边（六角的边，不是顶点）= 亭子前片的着地线


def in_hex(gx, gy, R=None):
    R = RP if R is None else R
    x, y = abs(gx - PGX), abs(gy - PGY)
    return y <= R * 0.8660254 and 1.7320508 * x + y <= 1.7320508 * R


# ---- 岸线：一条折线从缝（x 1536）往西，绕过半岛（亭子平台在它东北角）、湖湾，再顺着西岸往北一直接到对岸（湖收住）
def coast_game():
    pts = [(gx, E.shore_y(G(gx))) for gx in range(1538, 747, -2)]
    flank = catmull([(748, E.shore_y(G(748))), (736, 778), (716, 758), (694, 734), (674, 710), (656, 686), (642, 662),
                     (630, 640), (620, 624), (613, 617)], 8)
    pts += flank[1:]
    for ang in (300, 0, 60, 120, 180):
        x, y = hex_v(ang)
        pts.append((GM(x), y))
    lobe = catmull([(446, 552), (428, 553), (404, 549), (380, 549), (358, 555), (342, 571), (334, 597), (332, 629),
                    (336, 663), (342, 699), (344, 734), (336, 760), (318, 774), (298, 778)], 8)
    pts += lobe[1:]
    west = catmull([(298, 778), (270, 769), (240, 749), (214, 721), (194, 689), (176, 651), (160, 609), (146, 563),
                    (132, 515), (118, 467), (104, 419), (92, 371), (80, 327), (74, 303)], 8)
    pts += west[1:]
    return pts


COAST = coast_game()
_wm = Image.new("L", (W, H), 0)
ImageDraw.Draw(_wm).polygon([(1540, FAR_Y + 3)] + [(x, y) for x, y in COAST] + [(74, FAR_Y + 3)], fill=255)
WMASK = _wm.load()


def WM(xe, y):
    gx = int(xe) + XO
    y = int(y)
    return 0 <= gx < W and FAR_Y + 3 <= y < H and WMASK[gx, y] > 0


def WMg(gx, y):
    return 0 <= gx < W and FAR_Y + 3 <= y < H and WMASK[gx, y] > 0


# ---- 路面（石板）蒙版：游戏坐标
def _thick(d, pts, hw, fill=255):
    dense = []
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        n = int(max(abs(x1 - x0), abs(y1 - y0)) / 2) + 1
        for k in range(n):
            t = k / float(n)
            dense.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    dense.append(pts[-1])
    for (x, y) in dense:
        d.ellipse([x - hw, y - hw * 0.92, x + hw, y + hw * 0.92], fill=fill)


_pm = Image.new("L", (W, H), 0)
_pd = ImageDraw.Draw(_pm)
for _gx in range(0, W):
    _xe = G(_gx)
    if _xe >= -620:
        yc = lake_yc(_xe)
        _pd.line([(_gx, int(math.ceil(yc - PATH_HW))), (_gx, int(math.floor(yc + PATH_HW)))], fill=255)
_pd.rectangle([GM(PLAZA[0]), PLAZA[2], GM(PLAZA[1]) - 1, PLAZA[3] - 1], fill=255)
_pd.rectangle([GM(PATH_S[0]), PATH_S[2], GM(PATH_S[1]) - 1, H - 1], fill=255)
_pd.rectangle([GM(LANDING[0]), LANDING[2], GM(LANDING[1]) - 1, LANDING[3] - 1], fill=255)
_thick(_pd, catmull(PEN_PATH, 6), PEN_HW)
_thick(_pd, catmull(WEST_PATH, 6), WEST_HW)
_pd.ellipse([GM(TERRACE[0]) - TERRACE[2], TERRACE[1] - TERRACE[2] * 0.8, GM(TERRACE[0]) + TERRACE[2], TERRACE[1] + TERRACE[2] * 0.8], fill=255)
PMASK = _pm.load()


def on_path(xe, y):
    gx = int(xe) + XO
    y = int(y)
    if not (0 <= gx < W and 0 <= y < H) or PMASK[gx, y] == 0:
        return False
    if WMg(gx, y):
        return False
    gxx, gyy = gnd(xe, y)
    if in_hex(gxx, gyy):
        return False
    return True


def on_deck(xe, y):
    return (PIER[0] <= xe < PIER[1] and PIER[2] <= y < PIER[3]) or (HEAD[0] <= xe < HEAD[1] and HEAD[2] <= y < HEAD[3])


def is_water(xe, y):
    """真正露出来的水面（码头木台、亭子平台不算）"""
    if not WM(xe, y):
        return False
    if on_deck(xe, y):
        return False
    gx, gy = gnd(xe, y)
    return not in_hex(gx, gy)


# ================================================================== 远景（天、云、远山、对岸树带）——接着东半边往西续
def far_peaks_w(BK, peaks, base_y, lit, shade, fog, seed, ridge_col=None, fog_h=26):
    """照抄 E.far_peaks，只把 x 的范围换成西半边（式子一字不改，缝上自己连着）"""
    prof = {}
    for x in range(X0, X1):
        best, bi = -1.0, -1
        for i, (px, hh, hw) in enumerate(peaks):
            u = abs(x - px) / hw
            if u < 1:
                v = hh * (1 - u * u) ** 1.6 * (1 - 0.18 * u)
                if v > best:
                    best, bi = v, i
        n = (vnoise(x, 0, 23, seed) - 0.5) * 9 + (vnoise(x, 0, 7, seed + 1) - 0.5) * 3
        prof[x] = (base_y - max(0.0, best) + n, bi)
    for x in range(X0, X1):
        ry, bi = prof[x]
        if bi < 0:
            continue
        px, hh, hw = peaks[bi]
        top = base_y - hh
        for y in range(max(0, int(ry)), base_y + 2):
            bx = px + (y - top) * 0.5 + (vnoise(x * 0.5, y, 11, seed + 2) - 0.5) * 18
            col = lit if x < bx else shade
            if abs(x - bx) < 2 and (x + y) % 2 == 0:
                col = lit if col == shade else shade
            if col == shade and ridge_col:
                k = (x - px) - (y - (base_y - hh)) * 0.9
                if abs(k % 37 - 18) < 0.8 and y - ry > 4:
                    col = ridge_col
            f = (y - (base_y - fog_h)) / float(fog_h)
            if f > 0 and dith(x, y, min(1.0, f * 1.1)):
                col = fog
            BK.p(x, y, col)


EAST_PEAKS1 = [(130, 48, 190), (380, 74, 230), (580, 52, 170), (790, 64, 210), (1010, 48, 170), (1190, 78, 240), (1400, 58, 200), (1530, 46, 160)]
EAST_PEAKS2 = [(60, 26, 150), (270, 36, 190), (480, 22, 140), (700, 30, 170), (910, 24, 150), (1110, 34, 180), (1330, 38, 200), (1500, 26, 140)]
# 西半边加的山头：px + hw ≤ 0，碰不到东半边（东半边那张不重出也连得上）
WEST_PEAKS1 = [(-160, 62, 160), (-400, 76, 220), (-640, 50, 180), (-860, 70, 220), (-1090, 56, 190), (-1300, 80, 240), (-1520, 54, 190), (-1700, 64, 200)]
WEST_PEAKS2 = [(-130, 30, 130), (-350, 24, 170), (-580, 36, 190), (-800, 22, 150), (-1010, 32, 200), (-1240, 28, 170), (-1450, 38, 200), (-1640, 26, 150)]


def build_backdrop_w():
    BK = Layer(X0, 0, W, FAR_Y + 4)
    for y in range(BK.h):
        for x in range(X0, X1):
            if y < 150:
                col = "bl3"
            elif y < 236:
                col = "bl4" if dith(x, y, (y - 150) / 86.0) else "bl3"
            else:
                col = "bl4"
            BK.px[x - X0, y] = C[col]
    for (cx, cy, w, s) in ((-1390, 58, 124, 21), (-1190, 108, 66, 22), (-940, 44, 128, 23), (-650, 76, 104, 24),
                           (-430, 146, 70, 25), (-820, 150, 62, 26), (-1480, 156, 54, 27), (-250, 50, 88, 28), (-1080, 160, 58, 29)):
        E.cloud(BK, cx, cy, w, s)
    far_peaks_w(BK, EAST_PEAKS1 + WEST_PEAKS1, FAR_Y - 22, "wa2", "wa1", "bl4", 21, fog_h=30)
    far_peaks_w(BK, EAST_PEAKS2 + WEST_PEAKS2, FAR_Y - 12, "hz1", "hz0", "hz2", 22, fog_h=18)
    BK0 = Layer(X0, 0, W, FAR_Y + 4)
    BK0.paste(BK)
    E.misty_hamlet(BK, -760, 4, FAR_Y - 22, 13)
    E.misty_hamlet(BK, -1290, 3, FAR_Y - 21, 14)
    # 对岸淡树带：东半边那一串（同一个种子，原样算出来）里靠缝的几团 + 西半边自己一串
    rnd = random.Random(31)
    tl_e = []
    x = -10
    while x < 1536 + 14:
        tl_e.append((x + rnd.uniform(-3, 3), FAR_Y - 17 + rnd.uniform(-4, 3), rnd.uniform(9, 14), 0.0))
        x += rnd.randint(13, 20)
    rnd = random.Random(131)
    tl_w = []
    x = -1550
    while x < -18:
        tl_w.append((x + rnd.uniform(-3, 3), FAR_Y - 17 + rnd.uniform(-4, 3), rnd.uniform(9, 14), 0.0))
        x += rnd.randint(13, 20)
    tl = tl_w + [m for m in tl_e if m[0] < 40]
    tl.sort(key=lambda m: m[1])
    canopy(BK, tl, ["hz0", "hz1", "gr4", "hz2"], 55, cr=(3, 4), lo=-0.5, hi=1.4, spill=0.5, gap=False, speck=False)
    for (fx, s) in ((-210, 15), (-560, 16), (-930, 17), (-1260, 18), (-1470, 19)):
        r2 = random.Random(s)
        for i in range(16):
            xx = fx + r2.uniform(-7, 7)
            y0 = FAR_Y - 40 + abs(xx - fx) * 0.6
            for j in range(int(r2.uniform(18, 30))):
                BK.p(xx + (xx - fx) * j / 60.0, y0 + j, r2.choice(["gr4", "hz1", "gC"]))
    for xx in range(X0, X1):
        for y in range(FAR_Y - 7, FAR_Y - 2):
            if not BK.has(xx, y) or y > FAR_Y - 5 or is_ramp(BK.g(xx, y), "bl"):
                BK.p(xx, y, "gr4" if (xx + y) % 3 else "hz1")
        BK.p(xx, FAR_Y - 2, "hz2")
        BK.p(xx, FAR_Y - 1, "sv2" if (xx % 11) else "sv1")
        BK.p(xx, FAR_Y, "sv1")
        BK.p(xx, FAR_Y + 1, "sv1" if (xx % 11) else "sv0")
        BK.p(xx, FAR_Y + 2, "bl3")
        BK.p(xx, FAR_Y + 3, "bl3")
    return BK, BK0


# ================================================================== 水面（照 E.paint_water：对岸翻下来、横纹断开；东西各自按落水线翻）
ROWSEG = {}


def row_segments_w(y):
    if y in ROWSEG:
        return ROWSEG[y]
    rnd = random.Random(y * 977 + 13 + 50021)
    dist = max(0.0, (y - FAR_Y) / 360.0)
    pb = 0.03 + 0.24 * min(1.0, dist)
    segs = []
    x = X0
    while x < X1:
        ln = rnd.randint(20, 96) if dist < 0.6 else rnd.randint(10, 48)
        kind = "brk" if rnd.random() < pb else "ref"
        xo = rnd.choice([-1, 0, 0, 0, 1]) if dist < 0.3 else rnd.choice([-2, -1, 0, 1, 2])
        segs.append((x, min(X1, x + ln), kind, xo))
        x += ln
    ROWSEG[y] = segs
    return segs


def paint_water_w(BG, BK, BK0, refl):
    mirror = FAR_Y + 3
    ymax = max(y for _, y in COAST) + 2
    for y in range(FAR_Y + 3, int(ymax) + 1):
        for (xa, xb, kind, xo) in row_segments_w(y):
            for x in range(xa, xb):
                if not WM(x, y):
                    continue
                base = E.water_base(x, y)
                col = base
                sy = 2 * mirror - y
                sx = min(X1 - 1, max(X0, x + xo))
                fade = sy < 70 and not dith(x, y, sy / 70.0)
                if kind == "ref" and 0 <= sy < BK.h and not fade:
                    s = BK.g(sx, sy)
                    s0 = BK0.g(sx, sy)
                    if s in E.REF_MAP:
                        col = C[E.REF_MAP[s]]
                    elif s != s0:
                        col = quant(mix(s[:3], E.LIGHT_REF, 0.42), E.SKY_REF + ("nl3", "gA"))
                    else:
                        col = C["bl3"]
                elif kind == "brk":
                    if xa + 3 <= x < xb - 3 and (xb - xa) > 12 and h2(xa, y, 5) < 0.4:
                        col = C["bl3"] if base == C["bl2"] else C["bl2"]
                BG.px[x - X0, y] = col
    for (L, ym, a) in refl:
        for y in range(L.oy, L.oy + L.h):
            ry = int(2 * ym - y)
            if ry <= ym or ry >= H:
                continue
            for (xa, xb, kind, xo) in row_segments_w(ry) if ry > FAR_Y else []:
                if kind == "brk":
                    continue
                for x in range(max(xa, L.ox), min(xb, L.ox + L.w)):
                    s = L.g(x - xo, y)
                    if not s[3] or not is_water(x, ry):
                        continue
                    BG.p(x, ry, quant(mix(s[:3], E.DEEP, a), E.WATER_CANDS))
    rnd = random.Random(177)
    for _ in range(1500):
        x = rnd.randrange(X0, X1)
        y = rnd.randrange(FAR_Y + 300, int(ymax))
        if not is_water(x, y) or BG.g(x, y) != C["bl2"]:
            continue
        ln = rnd.randint(3, 9)
        for i in range(ln):
            if is_water(x + i, y) and BG.g(x + i, y) == C["bl2"]:
                BG.p(x + i, y, "bl3" if rnd.random() < 0.85 else "bl1")
    for _ in range(120):
        x = rnd.randrange(X0, X1)
        y = rnd.randrange(FAR_Y + 150, int(ymax))
        if is_water(x, y) and is_water(x + 2, y):
            BG.p(x, y, "bl3")
            BG.p(x + 1, y, "bl4")
            BG.p(x + 2, y, "bl3")


# ================================================================== 地面：草、岸、石板路
def paint_ground_w(BG):
    rnd = random.Random(15)
    for y in range(FAR_Y + 3, H):
        for x in range(X0, X1):
            if WM(x, y):
                continue
            BG.px[x - X0, y] = C[E.grass_tone(x, y)]
    E.grass_details(BG, rnd, (X0, FAR_Y + 3, X1, H), 1.0)
    # 岸：北边是水（近岸、半岛北沿）——草边压暗、水边一道暗；南边是水（湖湾西岸那种朝南的岸）——露一截石头岸壁
    edge_n = []
    for y in range(FAR_Y + 4, H - 1):
        for x in range(X0, X1):
            if WM(x, y):
                continue
            if WM(x, y - 1):
                edge_n.append((x, y))
    for (x, y) in edge_n:
        BG.p(x, y, "gr1")
        if not WM(x, y + 1):
            BG.p(x, y + 1, "gr2" if (x % 3) else "gr1")
        BG.p(x, y - 1, "bl1")
        if WM(x, y - 2) and (x % 4):
            BG.shade_px(x, y - 2, -1)
    for y in range(FAR_Y + 3, H - 1):
        for x in range(X0, X1):
            if WM(x, y) or not WM(x, y + 1):
                continue
            # 朝南的岸壁：草沿 + 几行石头 + 水线
            for k in range(1, 9):
                if not WM(x, y + k):
                    break
                if k == 1:
                    col = "gr1"
                elif k == 8:
                    col = "bl1"
                elif k == 7:
                    col = "ik3"
                else:
                    r = h2((x + (k // 3) * 5) // 6, (y + k) // 3, 71)
                    col = "sv1" if r > 0.45 else "sv0"
                    if (x + (k // 3) * 5) % 6 == 0:
                        col = "ik3"
                    if k == 2:
                        col = "sv2" if r > 0.3 else "sv1"
                BG.p(x, y + k, col)
            BG.p(x, y, "gr2")
    for y in range(FAR_Y + 3, H):
        for x in range(X0, X1):
            if WM(x, y):
                continue
            if WM(x + 1, y) and BG.g(x + 1, y) not in (C["gr1"], C["sv1"], C["sv0"], C["ik3"], C["sv2"]):
                BG.p(x + 1, y, "bl1")
                BG.p(x, y, "gr2")
            if WM(x - 1, y) and BG.g(x - 1, y) not in (C["gr1"], C["sv1"], C["sv0"], C["ik3"], C["sv2"]):
                BG.p(x - 1, y, "bl1")
                BG.p(x, y, "gr1")
    for _ in range(80):
        x, y = edge_n[rnd.randrange(len(edge_n))]
        w = rnd.randint(5, 10)
        for i in range(w):
            if not WM(x + i, y - 1) and not WM(x + i, y):
                continue
            BG.p(x + i, y - 1, "sv1" if i < w - 2 else "sv0")
            BG.p(x + i, y, "sv0" if i else "sv1")
        BG.p(x - 1, y, "ik3")
    # 石板路（同一张错缝网格：原点照东半边 712 / 846，缝上自己对齐）
    for y in range(FAR_Y + 3, H):
        for x in range(X0, X1):
            if on_path(x, y):
                BG.px[x - X0, y] = C[E.slab(x, y, 712, 846)]
    for y in range(FAR_Y + 3, H):
        for x in range(X0, X1):
            if on_path(x, y) and (not on_path(x - 1, y) or not on_path(x + 1, y) or not on_path(x, y - 1) or not on_path(x, y + 1)):
                if x < X1 - 1:
                    BG.p(x, y, "sv0")
    # 路边草一簇簇压过来
    edges = []
    for y in range(FAR_Y + 3, H, 2):
        for x in range(X0, X1 - 2, 2):
            if on_path(x, y) and not (on_path(x - 2, y) and on_path(x + 2, y) and on_path(x, y - 2) and on_path(x, y + 2)):
                edges.append((x, y))
    for _ in range(min(900, len(edges))):
        x, y = edges[rnd.randrange(len(edges))]
        for k in range(rnd.randint(1, 3)):
            xx, yy = x + rnd.randint(-1, 1), y + rnd.randint(-1, 1)
            if on_path(xx, yy) and xx < X1 - 1:
                BG.p(xx, yy, rnd.choice(["gr3", "gB", "gA"]))


# ================================================================== 亭子平台（石台，平的画进底图）、码头（蜜色木台）
def face_band_stone(L, sx0, sy0, sx1, sy1, depth=24):
    """朝南的石台侧面（台面边 → 水面）：一道压顶石、几层错缝条石、水线暗"""
    if sx1 < sx0:
        sx0, sy0, sx1, sy1 = sx1, sy1, sx0, sy0
    span = sx1 - sx0
    for x in range(int(round(sx0)), int(round(sx1)) + 1):
        t = (x - sx0) / span if span else 0
        top = int(round(sy0 + (sy1 - sy0) * t)) + 1
        u = x - int(sx0)
        for k in range(depth):
            y = top + k
            if not WM(x, y):
                continue
            if k < 3:
                col = ("sv2", "sv1", "sv0")[k]
            elif k >= depth - 3:
                col = "bl0" if k == depth - 3 else "bl1"
            else:
                course = (k - 3) // 6
                v = (k - 3) % 6
                off = (course % 2) * 11
                if v == 5 or (u + off) % 22 == 0:
                    col = "ik3"
                elif v == 0:
                    col = "sv2" if (u + off) % 22 < 16 else "sv1"
                else:
                    col = "sv1" if h2((u + off) // 22, course, 9) > 0.35 else "sv0"
                    if v == 4 and (u % 3 == 0):
                        col = "sv0"
            L.p(x, y, col)


def face_band_wood(L, sx0, sx1, sy, depth=20, pile_gap=38):
    """码头平台朝南的侧面：蜜色木边梁三行、下面木桩，桩子之间是台子底下的暗水"""
    for x in range(int(sx0), int(sx1)):
        u = x - int(sx0)
        for k in range(depth):
            y = sy + k
            if not is_water(x, y) and k > 0:
                continue
            if k < 4:
                col = ("hw4", "hw3", "hw2", "hw1")[k]
            else:
                pu = (u + 4) % pile_gap
                if pu < 7:
                    col = "hw3" if pu == 0 else ("hw1" if pu >= 5 else "hw2")
                    if k == depth - 1:
                        col = "hw0"
                else:
                    col = "bl0" if k < 10 else "bl1"
            L.p(x, y, col)


def deck_plank(x, y, along_y=True, seed=21):
    """码头木板（蜜色 hw）：栈桥上横铺（一块 0.28 米 = 9 像素），板缝暗两档"""
    pitch = 9
    v = y if along_y else x
    k = v // pitch
    f = v % pitch
    if f == pitch - 1:
        return "hw2"
    r = h2(k, 3, seed)
    base = 4 if r < 0.6 else (3 if r < 0.78 else 5)
    if f == 0:
        base += 1
    u = x if along_y else y
    if h2(u // 24 + k * 3, k, seed + 1) < 0.08 and (u % 24) == 0:
        return "hw2"
    if h2(u // 4, v, seed + 2) < 0.03:
        base -= 1
    return E.rname("hw", base)


def paint_platform_and_dock(BG):
    # 亭子石台：东南那面在水上，露石台侧面
    for (a0, a1) in ((300, 360),):
        p0 = hex_v(a0)
        p1 = hex_v(a1)
        face_band_stone(BG, p0[0], p0[1], p1[0], p1[1], depth=24)
    # 南边那条边（西南角 → 东南角）在水上的那一截也露
    s0, s1 = hex_v(240), hex_v(300)
    face_band_stone(BG, s0[0], s0[1], s1[0], s1[1], depth=24)
    s0, s1 = hex_v(180), hex_v(240)
    face_band_stone(BG, s0[0], s0[1], s1[0], s1[1], depth=24)
    x0, y0 = scr(PGX - RP, PGY + RP)
    x1, y1 = scr(PGX + RP, PGY - RP)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            gx, gy = gnd(x, y)
            if not in_hex(gx, gy):
                continue
            if not in_hex(gx, gy, RP - 0.24):
                col = "sv1"
                if not in_hex(gx, gy, RP - 0.07):
                    col = "sv0" if gy < PGY else "sv2"
                elif not in_hex(gx, gy, RP - 0.13) and (x + y) % 2 == 0:
                    col = "sv2"
                if (x * 3 + y * 5) % 23 == 0:
                    col = "sv0"
            else:
                col = E.deck_color(gy - PGY, gx - PGX, 9, x, y, 99, seed=11)
            BG.p(x, y, col)
    # 瓦顶在台面上的影子（往右下偏一点，边上棋盘格）
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            gx, gy = gnd(x, y)
            if not in_hex(gx, gy, RP - 0.24):
                continue
            if in_hex(gx - 0.3, gy + 0.25, RE - 0.25):
                BG.shade_px(x, y, -2)
            elif in_hex(gx - 0.3, gy + 0.25, RE):
                BG.shade_px(x, y, -1 if (x + y) % 2 else -2)
    # 码头：平台南边两截侧面（栈桥两边在水上的那段）
    face_band_wood(BG, HEAD[0], PIER[0], HEAD[3], depth=20)
    face_band_wood(BG, PIER[1], HEAD[1], HEAD[3], depth=20)
    for y in range(HEAD[2], PIER[3]):
        for x in range(HEAD[0], HEAD[1]):
            if not on_deck(x, y):
                continue
            in_head = HEAD[2] <= y < HEAD[3]
            if in_head:
                # 平台：板子南北向铺（跟栈桥错开），外圈一道边梁
                if x - HEAD[0] < 3 or HEAD[1] - x <= 3 or y - HEAD[2] < 3:
                    col = "hw2" if (x - HEAD[0] < 1 or HEAD[1] - x <= 1 or y - HEAD[2] < 1) else "hw3"
                else:
                    col = deck_plank(x, y, along_y=True, seed=23)
            else:
                if x - PIER[0] < 3 or PIER[1] - x <= 3:
                    col = "hw2" if (x - PIER[0] < 1 or PIER[1] - x <= 1) else "hw3"
                else:
                    col = deck_plank(x, y, along_y=True, seed=21)
            BG.p(x, y, col)
    # 栈桥伸上岸那一头压一道石沿
    for x in range(PIER[0] - 2, PIER[1] + 2):
        BG.p(x, PIER[3] - 1, "sv0")
        BG.p(x, PIER[3], "sv1")


# ================================================================== 立着的：白墙月亮门（照 E.draw_wall，门洞换到西头）
def wall_top_w(x):
    u = abs(x - GATE_C[0]) / 132.0
    if u >= 1:
        return WALL_TOP
    hump = 1.0 if u < 0.5 else 0.5 + 0.5 * math.cos(math.pi * (u - 0.5) / 0.5)
    return int(round(WALL_TOP - 40 * hump))


def draw_wall_w():
    L = Layer(X0, 860, W, 200)
    gx, gy = GATE_C
    R = GATE_R
    for x in range(X0, X1):
        T = wall_top_w(x)
        for y in range(T, WALL_Y):
            dfront = math.hypot(x + 0.5 - gx, y + 0.5 - gy)
            dback = math.hypot(x + 0.5 - gx, y + 0.5 - (gy - WALL_T))
            if dfront < R:
                if dback < R:
                    continue
                if y >= WALL_Y - WALL_T - 1:
                    col = "sv2" if (x + y) % 5 else "sv1"
                    if y == WALL_Y - 1:
                        col = "sv0"
                else:
                    col = "sv1" if x > gx else "sv0"
                    if abs(dfront - R) < 1.2:
                        col = "ik3"
                L.p(x, y, col)
                continue
            if dfront < R + 8:
                ang = math.atan2(y + 0.5 - gy, x + 0.5 - gx)
                lit = math.cos(ang - math.radians(-135))
                col = "sv0" if lit > 0.35 else ("ik3" if lit > -0.5 else "ik2")
                if dfront > R + 6.8:
                    col = "ik2"
                elif dfront < R + 1.2:
                    col = "ik2" if lit < 0.3 else "ik3"
                elif dfront < R + 2.5 and lit > 0.5:
                    col = "sv1"
                seg = (ang + math.pi) / (2 * math.pi) * 22
                if abs(seg - round(seg)) < 0.06 * (R + 4) / dfront * 1.8 and R + 1 < dfront < R + 7:
                    col = "ik2"
                if y >= WALL_Y - 2:
                    col = "ik2"
                L.p(x, y, col)
                continue
            if y >= WALL_Y - 12:
                col = "sv1" if y == WALL_Y - 12 else "sv0"
                if (x + (0 if (y - WALL_Y) // 6 % 2 else 15)) % 30 == 0 or y == WALL_Y - 6:
                    col = "ik3"
                if y == WALL_Y - 1:
                    col = "ik3"
                L.p(x, y, col)
                continue
            dy = y - T
            col = "wl5"
            if dy < 5:
                col = "sv1" if dy < 3 else "sv2"
            elif dy < 9 and (x + y) % 2 == 0:
                col = "sv2"
            elif vnoise(x, y, 26, 61) > 0.68 and (x + y) % 2 == 0:
                col = "wl4"
            if y > WALL_Y - 40 and (x + y) % 2 == 0:
                col = "wl4"
            if y > WALL_Y - 26 and (x + 2 * y) % 4 != 0:
                col = "sv2"
            if y > WALL_Y - 18:
                col = "sv2" if (x + y) % 5 else "sv1"
            L.p(x, y, col)
    for x in range(X0, X1):
        T = wall_top_w(x)
        for col, dy in (("ol", -21), ("sv1", -20), ("sv0", -19), ("sv0", -18), ("ik3", -17), ("ik2", -16), ("ik1", -15)):
            L.p(x, T + dy, col)
        cpos = x % 8
        for dy in range(-14, -4):
            if cpos in (0, 1, 2):
                col = ("ik1", "ik2", "ik2")[cpos]
            elif cpos == 3:
                col = "sv1" if dy < -9 else "sv0"
            elif cpos in (4, 5):
                col = "sv0" if dy < -10 else "ik3"
            else:
                col = "ik3" if cpos == 6 else "ik2"
            if (dy + 14) % 5 == 4 and cpos >= 3:
                col = "ik2"
            L.p(x, T + dy, col)
        disc = {3: ("ik2", "sv0", "sv1", "sv0", "ik2"), 4: ("sv0", "sv1", "sv0", "ik3", "ik2"),
                5: ("sv0", "ik3", "sv0", "ik3", "ik2"), 6: ("ik2", "ik3", "ik3", "ik2", "ik1")}
        if cpos in disc:
            for k, col in enumerate(disc[cpos]):
                L.p(x, T - 4 + k, col)
        else:
            for k, col in enumerate(("ik1", "ik2", "ik2", "ik1")):
                if cpos == 1 or k < 3:
                    L.p(x, T - 4 + k, col)
            if cpos == 1:
                L.p(x, T, "ik2")
                L.p(x, T + 1, "ik1")
    for wx in (GATE_C[0] - 190, GATE_C[0] + 190):
        E.draw_lattice_window(L, wx, 988)
    E.silk_swag(L, gx - 58, 935, gx + 58, 935, 10, 3)
    E.red_bow(L, gx, 932, 7)
    for s in (-1, 1):
        lx = gx + s * 96
        E.red_lantern(L, lx, wall_top_w(lx) + 6)
    return L


# ================================================================== 半岛亭子（照东头湖心亭的画法，缩小一号；台子在地上，正南留口进人）
def pav(R, ang, h=0.0):
    a = math.radians(ang)
    return scr(PGX + R * math.cos(a), PGY + R * math.sin(a), h)


def red_column(L, ang, R=None, hc=None):
    R = RC if R is None else R
    hc = HC if hc is None else hc
    bx, by = pav(R, ang, 0)
    tx, ty = pav(R, ang, hc)
    bx, by, ty = int(round(bx)), int(round(by)), int(round(ty))
    L.rect(bx - 6, by - 4, bx + 7, by + 1, "sv1")
    L.hl(bx - 6, bx + 7, by - 4, "sv2")
    L.vl(bx + 6, by - 3, by + 1, "sv0")
    L.hl(bx - 6, bx + 7, by, "sv0")
    for y in range(ty, by - 4):
        for i, col in enumerate(("rd4", "rd4", "rd3", "rd3", "rd3", "rd3", "rd2", "rd2", "rd1")):
            L.p(bx - 4 + i, y, col)
    for y in (by - 6, by - 5):
        L.hl(bx - 4, bx + 5, y, "rd1")
    L.hl(bx - 5, bx + 6, ty, "gd2")
    L.hl(bx - 5, bx + 6, ty + 1, "gd1")
    for y in range(ty, by - 4):
        L.p(bx - 5, y, "ol")
        L.p(bx + 5, y, "ol")


def eave_pt(a0, a1, s):
    p0 = (PGX + RE * math.cos(math.radians(a0)), PGY + RE * math.sin(math.radians(a0)))
    p1 = (PGX + RE * math.cos(math.radians(a1)), PGY + RE * math.sin(math.radians(a1)))
    x = p0[0] + (p1[0] - p0[0]) * s
    y = p0[1] + (p1[1] - p0[1]) * s
    e = abs(2 * s - 1)
    k = e ** 4
    sc = 1 + (RT / RE - 1) * k
    x = PGX + (x - PGX) * sc
    y = PGY + (y - PGY) * sc
    h = HC + 0.08 + 0.62 * e ** 3.0
    return x, y, h


def roof_pt(a0, a1, s, t):
    ex, ey, eh = eave_pt(a0, a1, s)
    x = ex + (PGX - ex) * t
    y = ey + (PGY - ey) * t
    ha = HC + HR
    h = eh + (ha - eh) * (t ** 1.75)
    return scr(x, y, h)


def roof_face(L, a0, a1, base_idx, ncol):
    sv = E.RAMPS["sv"]
    done = {}
    NS, NT = 480, 400
    for it in range(NT + 1):
        t = it / NT
        for js in range(NS + 1):
            s = js / NS
            x, y = roof_pt(a0, a1, s, t)
            key = (int(x), int(y))
            u = s * ncol
            fu = u - math.floor(u)
            idx = base_idx
            if t < 0.93:
                if fu < 0.14 or fu > 0.9:
                    idx -= 2 if base_idx > 1 else 1
                elif fu < 0.34:
                    idx += 1
                elif fu > 0.72:
                    idx -= 1
                tc = t * 20
                if tc - math.floor(tc) < 0.14 and 0.14 <= fu <= 0.9:
                    idx -= 1
            if t > 0.8:
                idx -= 1 if (int(x) + int(y)) % 2 else 0
            done[key] = sv[max(0, min(len(sv) - 1, idx))]
    for (x, y), col in done.items():
        L.p(x, y, col)
    return done


def ridge_pts(ang):
    tip = (PGX + RT * math.cos(math.radians(ang)), PGY + RT * math.sin(math.radians(ang)))
    th = HC + 0.08 + 0.62
    ha = HC + HR
    pts = []
    N = 150
    for i in range(-13, N + 1):
        t = i / N
        if t < 0:
            x = tip[0] + (tip[0] - PGX) * (-t) * 0.9
            y = tip[1] + (tip[1] - PGY) * (-t) * 0.9
            h = th + (-t) * 3.4
        else:
            x = tip[0] + (PGX - tip[0]) * t
            y = tip[1] + (PGY - tip[1]) * t
            h = th + (ha - th) * (t ** 1.75)
        pts.append(scr(x, y, h + 0.12))
    return pts


def draw_ridge(L, ang):
    pts = ridge_pts(ang)
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        w = 6 if i < n * 0.8 else (5 if i < n * 0.93 else 4)
        cols = ["ol", "wt", "sv2", "sv1", "sv0", "ik3", "ik2", "ik1", "ol"]
        cols = cols[:w + 1] + ["ol"]
        for k, col in enumerate(cols):
            L.p(x, y - 4 + k, col)
    x, y = pts[0]
    sg = -1 if x < PCX else 1
    for (dx, dy, col) in ((0, -5, "ol"), (sg, -6, "sv2"), (sg, -7, "sv1"), (2 * sg, -8, "sv2"), (2 * sg, -9, "ol"),
                          (sg, -8, "ol"), (3 * sg, -8, "ol"), (0, -6, "ol")):
        L.p(x + dx, y + dy, col)


def draw_pavilion_w():
    bx0 = int(PCX - 190)
    by0 = int(PAV["gy"] - 290)
    B = Layer(bx0, by0, 380, 380)
    F = Layer(bx0, by0, 380, 380)
    for ang in (120, 60):
        red_column(B, ang)
    for (a0, a1) in ((180, 120), (120, 60), (60, 0)):
        p0 = (PGX + RC * 0.98 * math.cos(math.radians(a0)), PGY + RC * 0.98 * math.sin(math.radians(a0)))
        p1 = (PGX + RC * 0.98 * math.cos(math.radians(a1)), PGY + RC * 0.98 * math.sin(math.radians(a1)))
        s0, s1 = scr(*p0), scr(*p1)
        steps = int(abs(s1[0] - s0[0])) + 1
        for k in range(steps + 1):
            t = k / steps
            x = s0[0] + (s1[0] - s0[0]) * t
            y = s0[1] + (s1[1] - s0[1]) * t
            for i, col in enumerate(("hw5", "hw4", "hw4", "hw3", "hw2", "hw1", "ol")):
                B.p(x, y - 22 + i, col)
            if int(x) % 4 == 0:
                for yy in range(int(y - 42), int(y - 22)):
                    B.p(x, yy, "hw3")
            B.p(x, y - 43, "hw5")
            B.p(x, y - 42, "hw4")
            B.p(x, y - 44, "ol")
    for (a0, a1) in ((180, 120), (120, 60), (60, 0)):
        p0 = (PGX + (RP - 0.12) * math.cos(math.radians(a0)), PGY + (RP - 0.12) * math.sin(math.radians(a0)))
        p1 = (PGX + (RP - 0.12) * math.cos(math.radians(a1)), PGY + (RP - 0.12) * math.sin(math.radians(a1)))
        E.railing(B, p0, p1, h_top=0.62, h_low=0.2)
    for ang in (180, 0, 240, 300):
        red_column(F, ang)
    for (a0, a1) in ((180, 240), (240, 300), (300, 360)):
        s0 = pav(RC, a0, HC - 0.1)
        s1 = pav(RC, a1, HC - 0.1)
        steps = int(abs(s1[0] - s0[0])) + 1
        for k in range(steps + 1):
            t = k / steps
            x = s0[0] + (s1[0] - s0[0]) * t
            y = s0[1] + (s1[1] - s0[1]) * t
            for i, col in enumerate(("ol", "rd3", "rd3", "rd2", "rd2", "rd1", "ol")):
                F.p(x, y - 2 + i, col)
            if int(x) % 9 == 0:
                F.p(x, y + 1, "gd3")
            if 0.08 < t < 0.92:
                for j in range(10):
                    u = int(x) % 6
                    col = None
                    if j in (0, 9):
                        col = "wd2" if j == 0 else "wd1"
                    elif u == 0:
                        col = "wd2"
                    elif (j == 4 or j == 5) and u in (2, 3, 4):
                        col = "wd3"
                    if j == 9 and u in (2, 3):
                        col = None
                    if col:
                        F.p(x, y + 5 + j, col)
                if t < 0.15 or t > 0.85:
                    for j in range(10):
                        F.p(x, y + 5 + j, "rd2")
        for (sx, sy, sg) in ((s0[0], s0[1], 1), (s1[0], s1[1], -1)):
            for j in range(8):
                for i in range(8 - j):
                    F.p(sx + sg * (5 + i), sy + 5 + j, "rd3" if i < 2 else "rd2")
            F.p(sx + sg * 6, sy + 6, "gd3")
    sA = pav(RC, 240, HC - 0.1)
    sB = pav(RC, 300, HC - 0.1)
    E.silk_swag(F, sA[0] + 6, sA[1] + 5, sB[0] - 6, sB[1] + 5, 6, 3)
    E.red_bow(F, (sA[0] + sB[0]) / 2, sA[1] + 4, 6)
    gap0, gap1 = PGX - 0.62, PGX + 0.62            # 正南留口进人（石板路从这儿上台子）
    for (a0, a1) in ((180, 240), (240, 300), (300, 360)):
        p0 = (PGX + (RP - 0.12) * math.cos(math.radians(a0)), PGY + (RP - 0.12) * math.sin(math.radians(a0)))
        p1 = (PGX + (RP - 0.12) * math.cos(math.radians(a1)), PGY + (RP - 0.12) * math.sin(math.radians(a1)))
        if (a0, a1) == (240, 300):
            E.railing(F, p0, (gap0, p0[1]), h_top=0.62, h_low=0.2)
            E.railing(F, (gap1, p1[1]), p1, h_top=0.62, h_low=0.2)
        else:
            E.railing(F, p0, p1, h_top=0.62, h_low=0.2)
    R = Layer(F.ox, F.oy, F.w, F.h)
    roof_face(R, 120, 180, 3, 8)
    roof_face(R, 0, 60, 1, 8)
    draw_ridge(R, 120)
    draw_ridge(R, 60)
    roof_face(R, 180, 240, 3, 9)
    roof_face(R, 300, 360, 1, 9)
    roof_face(R, 240, 300, 2, 11)
    for (a0, a1) in ((180, 240), (240, 300), (300, 360)):
        nc = 11 if (a0, a1) == (240, 300) else 9
        last = None
        for js in range(0, 401):
            s = js / 400
            x, y, h = eave_pt(a0, a1, s)
            sx, sy = scr(x, y, h)
            ix, iy = int(sx), int(sy)
            if (ix, iy) == last:
                continue
            last = (ix, iy)
            for k, col in enumerate(("rd3", "rd2", "rd1", "ol")):
                R.p(ix, iy + 2 + k, col)
            R.p(ix, iy + 1, "ik2")
        for c in range(nc):
            s = (c + 0.55) / nc
            x, y, h = eave_pt(a0, a1, s)
            sx, sy = scr(x, y, h)
            sx, sy = int(sx), int(sy)
            R.ell(sx - 3, sy - 2, sx + 3, sy + 4, "ik2")
            R.ell(sx - 2, sy - 1, sx + 2, sy + 3, "sv0")
            R.p(sx - 1, sy, "sv1")
            R.p(sx + 1, sy + 2, "ik3")
    for ang in (180, 240, 300, 0):
        draw_ridge(R, ang)
    ax, ay = pav(0, 0, HC + HR)
    ax, ay = int(ax), int(ay)
    R.ell(ax - 6, ay - 4, ax + 7, ay + 2, "ik3")
    R.ell(ax - 5, ay - 4, ax + 2, ay, "sv0")
    R.ell(ax - 4, ay - 14, ax + 5, ay - 3, "ik3")
    R.ell(ax - 3, ay - 13, ax + 2, ay - 6, "sv0")
    R.p(ax - 2, ay - 11, "sv1")
    R.rect(ax - 1, ay - 18, ax + 2, ay - 14, "ik2")
    R.ell(ax - 3, ay - 25, ax + 4, ay - 18, "ik3")
    R.ell(ax - 2, ay - 24, ax + 1, ay - 20, "sv0")
    R.p(ax - 1, ay - 23, "sv1")
    R.vl(ax, ay - 29, ay - 25, "ik2")
    R.outline("ol")
    F.paste(R)
    for ang in (180, 240, 300, 0):
        x, y, h = (PGX + RT * 0.93 * math.cos(math.radians(ang)), PGY + RT * 0.93 * math.sin(math.radians(ang)), HC + 0.5)
        sx, sy = scr(x, y, h)
        E.small_lantern(F, int(sx), int(sy) + 6)
    return B, F


# ================================================================== 石栏杆（湖岸、半岛边：石柱 + 压顶 + 栏板，照效果图 1）
def stone_rail(p0, p1, post_every=1.3, ht=0.74, end_posts=(True, True)):
    """p0、p1 是地面坐标（米）。一段栏板一张图层：石柱 8 像素宽、柱头一颗宝珠；两柱之间一块栏板（压顶一道、中间凹进去一块、下面地栿）"""
    s0, s1 = scr(*p0), scr(*p1)
    xa, xb = min(s0[0], s1[0]), max(s0[0], s1[0])
    ya, yb = min(s0[1], s1[1]), max(s0[1], s1[1])
    L = Layer(xa - 10, ya - 60, xb - xa + 22, yb - ya + 66)
    l = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    n = max(1, int(math.ceil(l / post_every)))
    HT = int(48 * ht)
    steps = int(max(abs(s1[0] - s0[0]), abs(s1[1] - s0[1]))) + 1
    for k in range(steps + 1):
        t = k / steps
        x = s0[0] + (s1[0] - s0[0]) * t
        y = s0[1] + (s1[1] - s0[1]) * t
        xi, yi = int(round(x)), int(round(y))
        bay = t * n
        u = bay - math.floor(bay)
        upx = u * steps / n                  # 这块栏板里走了几像素
        upx2 = (1 - u) * steps / n
        top = yi - HT + 6
        for j in range(HT - 5):
            yy = top + j
            v = j
            if v <= 1:
                col = "sv2"
            elif v == 2:
                col = "sv1"
            elif v == 3:
                col = "sv0"
            elif v >= HT - 9:
                col = ("sv1", "sv1", "sv0", "sv0")[min(3, v - (HT - 9))]
            else:
                col = "sv1"
                inset = 5 < upx and 5 < upx2 and 6 <= v <= HT - 12
                if inset:
                    col = "sv1" if (xi + yy) % 7 else "sv2"
                    if v == 6 or upx < 6.5:
                        col = "sv0"
                    elif v == HT - 12 or upx2 < 6.5:
                        col = "sv2"
                    else:
                        col = "sv1"
                elif v == 4:
                    col = "sv2"
            L.p(xi, yy, col)
    for i in range(n + 1):
        if (i == 0 and not end_posts[0]) or (i == n and not end_posts[1]):
            continue
        t = i / n
        x = int(round(s0[0] + (s1[0] - s0[0]) * t))
        y = int(round(s0[1] + (s1[1] - s0[1]) * t))
        ptop = y - HT - 2
        for yy in range(ptop, y + 1):
            for kk, col in enumerate(("wt", "sv2", "sv2", "sv1", "sv1", "sv0", "sv0")):
                L.p(x - 3 + kk, yy, col)
        L.hl(x - 4, x + 5, ptop, "sv2")
        L.hl(x - 4, x + 5, ptop + 1, "sv1")
        L.hl(x - 3, x + 4, y - 3, "sv0")
        L.ell(x - 4, ptop - 9, x + 5, ptop + 1, "sv1")
        L.ell(x - 3, ptop - 8, x + 1, ptop - 3, "sv2")
        L.p(x - 2, ptop - 7, "wt")
        L.ell(x + 1, ptop - 6, x + 5, ptop + 1, "sv0", only=lambda xx, yy, x=x: xx >= x + 2)
        L.p(x, ptop - 10, "sv0")
    L.outline("ol")
    return L.crop_to_content()


# ================================================================== 小船、天鹅船、码头桩、芦苇、钓鱼的家什
def draw_rowboat(cx, wc, half_len=66, hw=15, flip=1, seed=1):
    """手划小木船（东西向、2.8 米）：船头尖、船尾方一点；舱里深（hw0～hw1，一根根肋条），船沿亮（hw5～hw6），
    船帮朝南那面一道道船板往下暗，水线一道深；两道坐板、一支桨搁在船里，船头一圈缆绳"""
    L = Layer(cx - half_len - 12, wc - 46, 2 * half_len + 24, 64)
    for x in range(cx - half_len, cx + half_len + 1):
        u = (x - cx) / half_len
        # 船头（u<0 那头）尖，船尾钝一点
        w = hw * ((1 - u * u) ** 0.5 if u < 0 else (1 - u ** 4) ** 0.5)
        sheer = -9 * (u ** 4 if u < 0 else u ** 6)
        rim_f = wc + w - 13 + sheer
        rim_b = wc - w - 13 + sheer
        water_f = wc + w * 0.7
        for y in range(int(rim_b) + 1, int(rim_f)):
            d = (y - int(rim_b))
            col = "hw0" if d < 3 else "hw1"
            if (x - cx) % 9 == 0 and d > 1:
                col = "hw2"
            L.p(x, y, col)
        L.p(x, int(rim_b), "hw5")
        L.p(x, int(rim_b) + 1, "hw3")
        L.p(x, int(rim_f), "hw6")
        L.p(x, int(rim_f) + 1, "hw5")
        for y in range(int(rim_f) + 2, int(water_f) + 1):
            k = y - int(rim_f)
            col = "hw4" if k < 4 else ("hw3" if k < 7 else "hw2")
            if k in (4, 8):
                col = "hw1"
            if y == int(water_f):
                col = "hw0"
            L.p(x, y, col)
    for sx in (cx - 22, cx + 18):
        for x in range(sx, sx + 7):
            u = (x - cx) / half_len
            w = hw * ((1 - u * u) ** 0.5 if u < 0 else (1 - u ** 4) ** 0.5)
            sheer = -9 * (u ** 4 if u < 0 else u ** 6)
            for y in range(int(wc - w - 13 + sheer) + 2, int(wc + w - 13 + sheer)):
                L.p(x, y, "hw5" if x < sx + 2 else ("hw4" if x < sx + 5 else "hw2"))
    for i in range(74):
        x = cx - 36 + i
        y = wc - 17 + i * 0.07
        L.p(x, y, "hw6" if i % 7 else "hw5")
        L.p(x, y + 1, "hw3")
    L.ell(cx + 32, wc - 20, cx + 46, wc - 13, "hw4")
    L.p(cx + 35, wc - 18, "hw6")
    # 船头一圈缆绳
    bx = cx - half_len + 10
    for (dx, dy) in ((0, 0), (1, -1), (2, -1), (3, 0), (3, 1), (2, 2), (1, 2), (0, 1)):
        L.p(bx + dx, wc - 16 + dy, "hw6")
    L.outline("ol")
    if flip < 0:
        L.im = L.im.transpose(Image.FLIP_LEFT_RIGHT)
        L.px = L.im.load()
    return L.crop_to_content()


def draw_lantern_pole(x, foot, side=1):
    """码头上挂红灯笼的木杆（2.2 米）：蜜色方杆、顶上一根横担往外挑，挂一只小红灯笼（喜事）"""
    L = Layer(x - 26, foot - 112, 52, 116)
    top = foot - 104
    for y in range(top, foot + 1):
        for i, col in enumerate(("hw5", "hw4", "hw3", "hw2")):
            L.p(x - 2 + i, y, col)
    L.rect(x - 4, foot - 6, x + 5, foot + 1, "hw2")
    L.hl(x - 4, x + 5, foot - 6, "hw4")
    for i in range(18):
        L.p(x + side * i, top + 4, "hw4")
        L.p(x + side * i, top + 5, "hw2")
    L.p(x - side, top - 1, "hw5")
    L.outline("ol")
    E.red_lantern(L, x + side * 14, top + 10)
    return L.crop_to_content()


def draw_swanboat(cx, wc, head=1, seed=1):
    """天鹅脚踏船（2.3 米）：白身子，靠南那边一整片翅膀从脖子根鼓到船尾、羽尖往上翘，船尾一小撮尾羽；
    船头一根粗粗的 S 形脖子（1.2 米高）、橙嘴黑嘴根、黑眼；翅膀后面露一点红坐背"""
    half_len, hw = 50, 18
    L = Layer(cx - half_len - 20, wc - 100, 2 * half_len + 40, 118)
    hs = head
    for x in range(cx - half_len, cx + half_len + 1):
        u = (x - cx) / half_len
        w = hw * (1 - u * u) ** 0.4
        rim_f = wc + w - 15
        rim_b = wc - w - 15
        water_f = wc + w * 0.7
        for y in range(int(rim_b) + 1, int(rim_f)):
            L.p(x, y, "sv1" if (y - int(rim_b)) > 2 else "sv0")
        L.p(x, int(rim_b), "sv2")
        L.p(x, int(rim_f), "wt")
        for y in range(int(rim_f) + 1, int(water_f) + 1):
            k = y - int(rim_f)
            L.p(x, y, "wt" if k < 5 else ("sv2" if k < 11 else "sv1"))
    # 红坐背（一排两座，在船身中间偏后）
    sx = cx - hs * 10
    for yy in range(wc - 40, wc - 24):
        for xx in range(sx - 14, sx + 15):
            col = "rd3"
            if yy == wc - 40:
                col = "rd4"
            elif xx == sx or xx == sx + 14:
                col = "rd2"
            L.p(xx, yy, col)
    L.hl(sx - 14, sx + 15, wc - 24, "rd1")
    # 翅膀：从脖子根往船尾一片，上沿一路往上翘，几道羽毛
    wx0 = cx + hs * (half_len - 14)
    wx1 = cx - hs * (half_len + 4)
    xa, xb = min(wx0, wx1), max(wx0, wx1)
    for x in range(xa, xb + 1):
        t = abs(x - wx0) / float(abs(wx1 - wx0))
        u = (x - cx) / half_len
        w = hw * max(0.0, 1 - u * u) ** 0.4
        base = int(wc + w * 0.55 - 6)
        top = int(wc - 22 - 18 * t ** 1.6 + 3 * math.sin(t * 9))
        for y in range(top, base + 1):
            v = (y - top) / max(1.0, base - top)
            col = "wt"
            if v > 0.62:
                col = "sv2"
            if v > 0.86:
                col = "sv1"
            # 羽毛：几道往后斜的线
            k = (x - wx0) * hs * -1 + (y - top) * 1.4
            if v > 0.18 and int(k) % 13 == 0:
                col = "sv1" if v < 0.7 else "sv0"
            L.p(x, y, col)
        L.p(x, top, "wt")
    # 尾羽：船尾翘起来一小撮
    tx = cx - hs * (half_len + 2)
    for j in range(16):
        for i in range(6 - j // 3):
            L.p(tx - hs * (i + j // 4), wc - 40 - j, "wt" if i < 3 else "sv2")
    # 脖子：粗 S 形，从船头往上，头朝前
    nb = cx + hs * (half_len - 10)
    pts = []
    for i in range(60):
        t = i / 59.0
        x = nb + hs * (-9 * math.sin(t * math.pi) + 5 * t)
        y = wc - 18 - t * 60
        pts.append((x, y, 6.2 - 2.2 * t))
    for (x, y, r) in pts:
        for yy in range(int(y - 1), int(y + 2)):
            for xx in range(int(x - r), int(x + r) + 1):
                lit = (xx - x) * hs < r * 0.25
                L.p(xx, yy, "wt" if lit else "sv2")
    hx, hy, _ = pts[-1]
    hx, hy = int(hx), int(hy)
    L.ell(hx - 7, hy - 6, hx + 8, hy + 5, "wt")
    L.ell(hx - 7, hy - 1, hx + 8, hy + 5, "sv2", only=lambda xx, yy: yy > hy + 1)
    L.p(hx - hs * 3, hy - 4, "wt")
    # 黑嘴根 + 橙嘴（往前伸、往下勾一点）
    bx = hx + hs * 7
    for k in range(3):
        L.p(bx - hs * 1 + hs * k, hy - 2, "ik1")
        L.p(bx - hs * 1 + hs * k, hy - 1, "ik1")
    for k in range(9):
        yy = hy - 1 + (1 if k > 5 else 0)
        L.p(bx + hs * (2 + k), yy, "or")
        L.p(bx + hs * (2 + k), yy + 1, "or" if k < 6 else "rd3")
    L.p(hx + hs * 3, hy - 2, "ik1")
    L.p(hx + hs * 3, hy - 3, "ik1")
    L.outline("ol")
    return L.crop_to_content()


def draw_post(x, foot, h=30):
    """码头系船木桩（0.6 米）：蜜色圆桩，顶上一圈暗、腰上缠一道绳"""
    L = Layer(x - 6, foot - h - 4, 13, h + 6)
    for y in range(foot - h, foot + 1):
        for i, col in enumerate(("hw5", "hw4", "hw4", "hw3", "hw2", "hw1")):
            L.p(x - 3 + i, y, col)
    L.ell(x - 3, foot - h - 2, x + 3, foot - h + 2, "hw3")
    L.p(x - 1, foot - h - 1, "hw5")
    for (dy, col) in ((10, "hw6"), (11, "hw4"), (13, "hw6"), (14, "hw4")):
        L.hl(x - 3, x + 3, foot - h + dy, col)
    L.outline("ol")
    return L.crop_to_content()


def draw_reeds(cx, foot, w, seed, dense=1.0):
    """芦苇一丛：细长的秆子、几片斜叶，秆顶蜜色的穗子"""
    rnd = random.Random(seed)
    L = Layer(cx - w - 14, foot - 80, 2 * w + 28, 84)
    n = int(w * 0.9 * dense)
    for i in range(n):
        x0 = cx + rnd.uniform(-w, w)
        hgt = rnd.uniform(34, 70) * (1 - 0.3 * abs(x0 - cx) / w)
        lean = rnd.uniform(-0.18, 0.18)
        tone = rnd.choice(["gA", "gr3", "gB", "gB", "gr4"])
        for j in range(int(hgt)):
            x = x0 + lean * j * j / hgt
            L.p(x, foot - j, tone if j > 6 else "gr2")
        tx = x0 + lean * hgt
        ty = foot - hgt
        if rnd.random() < 0.55:
            for j in range(9):
                L.p(tx + lean * j, ty - j, "hw5" if j % 3 else "hw4")
                L.p(tx + lean * j + 1, ty - j, "hw3")
            L.p(tx, ty - 9, "hw6")
        if rnd.random() < 0.45:
            sgn = rnd.choice([-1, 1])
            ly = foot - rnd.uniform(10, hgt * 0.7)
            for j in range(rnd.randint(10, 18)):
                L.p(x0 + sgn * j, ly - j * 0.5 + j * j * 0.02, "gB" if j < 8 else "gr4")
    L.outline("gr0", pick=lambda x, y, nb: None if y >= foot - 1 else "gr0")
    return L.crop_to_content()


def draw_fishing(x, foot, side=1, seed=1):
    """钓鱼的位子：一张蜜色小方凳、一只木桶，鱼竿架在一根丫杈上伸到水上，钓线垂下去一颗红白浮漂（人是 NPC，另画）"""
    L = Layer(x - 60, foot - 130, 120, 136)
    # 小凳 0.4 米
    for y in range(foot - 19, foot - 15):
        L.hl(x - 10, x + 10, y, "hw5" if y == foot - 19 else "hw4")
    L.hl(x - 10, x + 10, foot - 15, "hw2")
    for lx in (x - 9, x + 7):
        for y in range(foot - 14, foot):
            L.p(lx, y, "hw3")
            L.p(lx + 1, y, "hw1")
    # 木桶
    bx = x + side * 20
    for y in range(foot - 13, foot):
        for i, col in enumerate(("hw5", "hw4", "hw4", "hw3", "hw3", "hw2", "hw1")):
            L.p(bx - 3 + i, y, col)
    for yy in (foot - 11, foot - 4):
        L.hl(bx - 3, bx + 4, yy, "ik2")
    L.hl(bx - 3, bx + 4, foot - 13, "bl2")
    # 丫杈 + 鱼竿
    fx = x - side * 4
    for y in range(foot - 26, foot):
        L.p(fx, y, "wd2")
    L.p(fx - 1, foot - 27, "wd2")
    L.p(fx + 1, foot - 27, "wd2")
    tipx, tipy = x - side * 26, foot - 118
    E.Layer.line(L, x + side * 8, foot - 18, tipx, tipy, "wd1")
    E.Layer.line(L, x + side * 8 + 1, foot - 18, tipx + 1, tipy, "wd2")
    L.outline("ol")
    # 钓线 + 浮漂（不描边）
    for y in range(tipy + 1, foot - 92):
        L.p(tipx, y, "sv2")
    L.p(tipx, foot - 92, "rd4")
    L.p(tipx, foot - 91, "wt")
    return L.crop_to_content()


# ================================================================== 组装
META = {}
LOTUS_W = [(G(732), 606, 40, 16), (G(244), 650, 54, 22), (G(1262), 686, 104, 34), (G(236), 522, 40, 16), (G(1060), 520, 66, 24)]
RAIL_SHORE = [(G(1028), G(1112)), (G(1244), G(1426)), (G(738), G(846))]


def rail_ground(xe0, xe1):
    """沿近岸的一段石栏杆：两头的地面坐标（离水边 5 像素）"""
    y0 = E.shore_y(xe0) + 5
    y1 = E.shore_y(xe1) + 5
    ym = max(y0, y1)
    return gnd(xe0, ym), gnd(xe1, ym), ym


def build_stands():
    out = []
    out.append(("wall_gate_w", draw_wall_w(), WALL_Y))
    META["wall_gate_w"] = {"kind": "wall"}
    lanterns = [(G(836), 842), (G(980), 842), (G(650), 778), (G(470), 900), (G(150), 808), (G(76), 690), (G(38), 596), (G(1236), 808), (G(1432), 808)]
    for i, (x, y) in enumerate(lanterns):
        n = "lantern_w%d" % (i + 1)
        out.append((n, E.draw_stone_lantern(x, y), y))
        META[n] = {"kind": "box", "rect": [x - 11, y - 8, x + 11, y], "h": 70, "name": "石灯笼"}
    rocks = [(G(668), 822, 22, 62, 21), (G(420), 694, 26, 70, 22), (G(1180), 914, 24, 64, 23), (G(206), 944, 20, 54, 24),
             (G(560), 1128, 28, 70, 25), (G(1390), 1132, 22, 58, 26),
             (G(338), 566, 16, 42, 28), (G(282), 782, 14, 36, 29), (G(160), 654, 15, 40, 30), (G(1452), 950, 18, 48, 31)]
    for i, (x, y, w, h, s) in enumerate(rocks):
        n = "rock_w%d" % (i + 1)
        out.append((n, E.draw_rock(x, y, w, h, s * 13), y))
        META[n] = {"kind": "box", "rect": [x - int(w * 0.75), y - 10, x + int(w * 0.75), y], "h": h, "name": "太湖石"}
    # 灌木、花丛（游戏坐标写）
    bushes_g = [
        # 码头石板两边、广场边
        (826, 812, 18, "pink"), (990, 812, 18, "white"), (1036, 900, 20, None), (990, 962, 24, None), (690, 902, 14, "white"),
        (846, 906, 14, "pink"), (612, 930, 24, None), (540, 960, 22, "pink"), (920, 960, 22, "white"),
        # 墙里贴墙
        (618, 1002, 24, None), (918, 1006, 26, "pink"), (520, 994, 22, "white"), (1022, 998, 22, None),
        (700, 1014, 18, None), (842, 1016, 20, None), (1268, 990, 22, None), (1420, 1006, 24, "pink"),
        (400, 1000, 24, None), (300, 1008, 26, "white"), (190, 998, 22, "pink"), (80, 1004, 26, None),
        # 东边园子（往东小路南边）
        (1100, 880, 16, "pink"), (1350, 900, 20, None), (1460, 892, 18, "white"), (1230, 956, 20, None), (1482, 962, 15, None),
        (1290, 934, 16, "pink"), (1318, 954, 13, "white"), (1408, 946, 22, None), (1166, 942, 14, "white"),
        # 半岛上
        (452, 610, 16, None), (500, 704, 18, "pink"), (468, 752, 20, None), (656, 740, 14, "white"), (364, 642, 16, "white"),
        (394, 760, 20, "pink"),
        # 西岸
        (40, 690, 24, None), (30, 780, 22, "pink"), (190, 860, 22, None), (110, 900, 24, "white"), (260, 900, 20, None),
        (60, 560, 16, "white"), (122, 764, 14, "pink"), (58, 640, 14, "white"), (236, 872, 14, "pink"), (424, 902, 16, "white"),
        (30, 520, 14, None), (100, 830, 16, None), (330, 900, 13, "white"), (44, 322, 22, None), (12, 338, 18, "white"),
        # 墙外
        (660, 1068, 30, None), (880, 1068, 30, "pink"), (582, 1074, 26, "white"), (962, 1076, 28, None),
        (500, 1064, 26, None), (1040, 1066, 28, "pink"), (1130, 1150, 22, "white"), (1340, 1180, 24, None), (420, 1072, 30, "white"), (1120, 1072, 30, None),
        (340, 1066, 26, None), (1200, 1068, 28, "white"), (1290, 1072, 30, "pink"), (1380, 1076, 26, None),
        (250, 1074, 28, None), (160, 1068, 26, "pink"), (70, 1076, 30, None), (1454, 1072, 22, None),
        (620, 1150, 22, "pink"), (920, 1160, 24, None), (660, 1240, 22, None), (880, 1250, 24, "white"),
        (1050, 1200, 26, None), (470, 1190, 24, "white"), (1220, 1240, 22, None),
    ]
    bx0, bx1, bfoot = BENCH_W
    keep = []
    for (gx, y, r, fl) in bushes_g:
        x = G(gx)
        fp = [(x + dx * r * 0.7, y - dy * r * 0.35) for dx in (-1, 0, 1) for dy in (0, 1)]
        if any(on_path(int(a), int(b)) or WM(int(a), int(b)) for (a, b) in fp):
            continue
        if bx0 - r * 0.6 < x < bx1 + r * 0.6 and bfoot - 40 < y < bfoot + 10:
            continue
        keep.append((x, y, r, fl))
    for i, (x, y, r, fl) in enumerate(keep):
        n = "bush_w%02d" % (i + 1)
        out.append((n, E.bush(x, y, r, 1500 + i, fl).crop_to_content(), y))
        META[n] = {"kind": "cyl", "x": x, "y": int(y - r * 0.2), "rx": int(r * 0.8), "ry": max(4, int(r * 0.24)), "h": int(r * 1.8),
                   "name": "花丛" if fl else "灌木"}
    out.append(("bench_w", E.draw_bench(*BENCH_W).crop_to_content(), BENCH_W[2]))
    META["bench_w"] = {"kind": "bench"}
    # 树
    trees = [
        ("banyan_w1", "banyan", G(392), 600, dict(flip=-1, crx=150, lean=36, seed=1910)),      # 半岛上亭子西边（在亭子后面）
        ("banyan_w2", "banyan", G(34), 438, dict(flip=1, crx=170, lean=20, seed=1920)),         # 湖尽头西北角那片树
        ("willow_w1", "willow", G(342), 724, dict(seed=1710)),                                    # 半岛西沿
        ("willow_w2", "willow", G(116), 478, dict(seed=1720)),                                    # 西岸水边
        ("willow_w4", "willow", G(432), 566, dict(seed=1740)),                                    # 半岛北沿、亭子左后（照效果图 1 亭子背后一圈树）
        ("willow_w3", "willow", G(1196), 808, dict(seed=1730)),                                   # 钓鱼那儿（钓鱼的坐柳树底下）
        ("tree_fg_w1", "banyan_fg", G(300), 1240, dict(flip=-1, crx=180, cry=80, ch=210, seed=1950)),
        ("willow_fg_w2", "willow_out", G(1236), 1246, dict(seed=1970)),
        ("pine_w", "pine", G(330), 976, dict(seed=1960)),
        ("pine_w2", "pine", G(1100), 1006, dict(seed=1980)),
    ]
    for (n, kind, x, y, kw) in trees:
        if kind == "banyan":
            L = E.draw_banyan(x, y, kw["seed"], flip=kw["flip"], crx=kw["crx"], lean=kw["lean"]).crop_to_content()
            META[n] = {"kind": "tree", "x": x, "y": y, "h": 290, "w": 2 * kw["crx"] + 20, "name": "榕树"}
        elif kind == "banyan_fg":
            L = E.draw_banyan(x, y, kw["seed"], flip=kw["flip"], crx=kw["crx"], cry=kw["cry"], ch=kw["ch"],
                              roots=kw.get("roots", 40), lean=kw.get("lean", 12)).crop_to_content()
            META[n] = {"kind": "tree", "x": x, "y": y, "h": 300, "w": 2 * kw["crx"] + 20, "name": "墙外榕树", "outside": True}
        elif kind in ("willow", "willow_out"):
            L = E.draw_willow(x, y, kw["seed"]).crop_to_content()
            META[n] = {"kind": "tree", "x": x, "y": y, "h": 290, "w": 170, "droop": True, "name": "垂柳"}
            if kind == "willow_out":
                META[n]["outside"] = True
                META[n]["name"] = "墙外垂柳"
        else:
            L = E.draw_pine(x, y, kw["seed"]).crop_to_content()
            META[n] = {"kind": "tree", "x": x, "y": y, "h": 246, "w": 200, "name": "松"}
        out.append((n, L, y))
    # 亭子
    B, F = draw_pavilion_w()
    out.append(("pavilion_w_back", B.crop_to_content(), int(pav(RC, 90)[1])))
    out.append(("pavilion_w_front", F.crop_to_content(), int(FRONT_Y)))
    META["pavilion_w_back"] = {"kind": "art"}
    META["pavilion_w_front"] = {"kind": "art"}
    # 石栏杆：近岸几段
    for i, (xa, xb) in enumerate(RAIL_SHORE):
        p0, p1, ym = rail_ground(xa, xb)
        n = "rail_shore_%d" % (i + 1)
        out.append((n, stone_rail(p0, p1), ym))
        META[n] = {"kind": "rail", "x0": xa, "x1": xb, "y": ym, "name": "湖岸石栏杆"}
    # 半岛东沿（石板路靠水那边）一段石栏杆
    flank = [(G(624), 650), (G(650), 690), (G(690), 736), (G(728), 774)]
    for i in range(len(flank) - 1):
        a, b = flank[i], flank[i + 1]
        n = "rail_pen_%d" % (i + 1)
        L = stone_rail(gnd(*a), gnd(*b), end_posts=(True, i == len(flank) - 2))
        out.append((n, L, min(a[1], b[1])))
        META[n] = {"kind": "rail_seg", "a": a, "b": b, "name": "半岛石栏杆"}
    # 码头：系船桩、小船、天鹅船
    for i, (x, y, sd) in enumerate(((HEAD[0] + 6, HEAD[2] + 7, -1), (HEAD[1] - 7, HEAD[2] + 7, 1))):
        n = "dock_lamp_%d" % (i + 1)
        out.append((n, draw_lantern_pole(x, y, sd), y))
        META[n] = {"kind": "box", "rect": [x - 4, y - 5, x + 5, y], "h": 104, "name": "挂红灯笼的木杆"}
    posts = [(HEAD[0] + 5, HEAD[3] - 2), (HEAD[1] - 6, HEAD[3] - 2),
             (PIER[0] + 3, 700), (PIER[1] - 4, 700), (PIER[0] + 3, 760), (PIER[1] - 4, 760)]
    for i, (x, y) in enumerate(posts):
        n = "dock_post_%d" % (i + 1)
        out.append((n, draw_post(x, y), y))
        META[n] = {"kind": "box", "rect": [x - 4, y - 5, x + 4, y], "h": 30, "name": "系船桩"}
    boats = [("rowboat_1", draw_rowboat(G(792), 690, seed=1), 690 + 12, G(792)), ("rowboat_2", draw_rowboat(G(780), 744, flip=-1, seed=2), 744 + 12, G(780)),
             ("swanboat_1", draw_swanboat(G(1008), 690, head=1), 690 + 12, G(1008)), ("swanboat_2", draw_swanboat(G(1024), 750, head=1), 750 + 12, G(1024))]
    for (n, L, foot, cx) in boats:
        out.append((n, L, foot))
        META[n] = {"kind": "box", "rect": [L.ox, foot - 24, L.ox + L.w, foot], "h": 40, "block": False,
                   "name": "手划小木船" if n.startswith("row") else "天鹅脚踏船", "boat": True}
    # 荷花
    E.LOTUS = LOTUS_W
    for k in range(len(LOTUS_W)):
        L, foot = E.draw_lotus_stand(k)
        n = "lotus_w%d" % (k + 1)
        out.append((n, L, foot))
        cx, cy, rx, ry = LOTUS_W[k]
        META[n] = {"kind": "cyl", "x": cx, "y": cy, "rx": rx, "ry": ry, "h": 2, "name": "荷叶荷花", "water": True}
    # 芦苇（水边）
    reeds = [(G(312), 774, 22, 1), (G(262), 762, 16, 2), (G(136), 520, 18, 3), (G(98), 410, 16, 4), (G(712), 768, 14, 5), (G(1490), 790, 14, 6)]
    for i, (x, y, w, s) in enumerate(reeds):
        n = "reeds_w%d" % (i + 1)
        out.append((n, draw_reeds(x, y, w, 300 + s), y))
        META[n] = {"kind": "art", "name": "芦苇"}
    # 钓鱼的位子
    for i, (x, y) in enumerate(FISH):
        n = "fishing_%d" % (i + 1)
        out.append((n, draw_fishing(x, y, side=(1 if i == 0 else -1), seed=i), y))
        META[n] = {"kind": "box", "rect": [x - 11, y - 6, x + 11, y], "h": 19, "name": "钓鱼小凳（鱼竿、木桶）"}
    return out


def build_shade(stands):
    S = E.Shade()
    for (name, L, foot) in stands:
        if name.startswith("banyan") or name.startswith("tree_fg"):
            fx = L.ox + L.w // 2
            S.blob(fx + 36, foot - 8, L.w * 0.42, 40, -1.5, seed=len(name))
            S.blob(fx + 20, foot - 2, 40, 12, -1.0, seed=3)
        elif name.startswith("willow"):
            fx = L.ox + L.w // 2
            S.blob(fx + 26, foot - 4, 70, 22, -1.5, seed=4)
        elif name == "bench_w":
            S.blob(L.ox + L.w * 0.6, foot - 1, L.w * 0.5, 5, -1.5, seed=7)
        elif name.startswith("bush"):
            S.blob(L.ox + L.w * 0.6, foot - 1, L.w * 0.5, 5, -1.5, seed=foot)
        elif name.startswith("lantern") or name.startswith("rock") or name.startswith("dock_post") or name.startswith("dock_lamp") or name.startswith("fishing"):
            S.blob(L.ox + L.w * 0.62, foot - 1, L.w * 0.48, 5, -1.5, seed=foot)
        elif name.startswith("pine_w"):
            S.blob(L.ox + L.w * 0.6, foot - 6, 70, 18, -1.5, seed=9)
        elif name == "wall_gate_w":
            for x in range(X0, X1):
                for y in range(WALL_Y, WALL_Y + 9):
                    if not (GATE_C[0] - 50 < x < GATE_C[0] + 50) or y > WALL_Y + 4:
                        S.v[(x, y)] = -1.5 if y < WALL_Y + 6 else -0.5
        elif name.startswith("rowboat") or name.startswith("swanboat"):
            S.blob(L.ox + L.w * 0.55, foot + 3, L.w * 0.5, 6, -1.0, seed=2)
        elif name.startswith("rail_shore"):
            for x in range(L.ox + 2, L.ox + L.w - 2):
                for y in range(foot, foot + 4):
                    S.v[(x + 3, y)] = min(S.v.get((x + 3, y), 0), -1.0)
    # 亭子平台、码头在水上的影子（往右下）
    for y in range(int(hex_v(60)[1]), int(FRONT_Y) + 34):
        for x in range(int(hex_v(0)[0]) - 40, int(hex_v(0)[0]) + 24):
            gx, gy = gnd(x - 18, y - 30)
            if in_hex(gx, gy) and is_water(x, y):
                S.v[(x, y)] = min(S.v.get((x, y), 0), -1.0)
    for y in range(HEAD[2], PIER[3] + 30):
        for x in range(HEAD[0], HEAD[1] + 20):
            if on_deck(x - 12, y - 22) and is_water(x, y):
                S.v[(x, y)] = min(S.v.get((x, y), 0), -1.0)
    return S


# ================================================================== 出图
def load_east():
    meta = json.load(open(os.path.join(EAST_DIR, "layers", "layers.json"), encoding="utf-8"))
    bg = Image.open(os.path.join(EAST_DIR, "layers", meta["base"]["png"])).convert("RGBA")
    stands = []
    for l in meta["layers"]:
        im = Image.open(os.path.join(EAST_DIR, "layers", l["png"])).convert("RGBA")
        L = Layer(l["x"], l["y"], l["w"], l["h"])
        L.im = im
        L.px = im.load()
        stands.append((l["name"], L, l["foot_y"]))
    return bg, stands


def compose_full(bg_w, stands_w, bg_e, stands_e, people=()):
    """整块 3072×1280：西底图 + 东底图，再把两边立着的东西（都按 x_e + 1536 放）跟人一起按着地线排"""
    out = Image.new("RGBA", (2 * W, H), (0, 0, 0, 0))
    out.paste(bg_w, (0, 0))
    out.paste(bg_e, (W, 0))
    seq = []
    for (n, L, f) in stands_w + stands_e:
        seq.append((f, 0, L.ox, L))
    for (im, x, y) in people:
        seq.append((y, 1, x, (im, x, y)))
    seq.sort(key=lambda t: (t[0], t[1], t[2]))
    for (f, kind, fx, obj) in seq:
        if kind == 0:
            E.paste_clip(out, obj.im, obj.ox + XO, obj.oy)
        else:
            im, x, y = obj
            E.paste_clip(out, im, x - 32, y - 84)
    return out


def palette_check(im, name):
    return E.palette_check(im, name)


def main():
    # west_layout 里 import draw_lake_west 要拿到正在跑的这一份（不然 META 是空的，挡路的东西全丢）
    sys.modules["draw_lake_west"] = sys.modules[__name__]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    tag = args[0] if args else None
    if "--east" in sys.argv or not os.path.exists(os.path.join(EAST_DIR, "layers", "layers.json")):
        subprocess.check_call([sys.executable, os.path.join(HERE, "lake_engine.py")])
    os.makedirs(LAYER_DIR, exist_ok=True)
    E.is_water = is_water          # 引擎里的荷叶等按西半边的水面判断
    stands = build_stands()
    BK, BK0 = build_backdrop_w()
    BG = Layer(X0, 0, W, H)
    BG.paste(BK)
    names = dict((n, (L, f)) for (n, L, f) in stands)
    pf = Layer(X0, 0, W, H)
    pf.paste(names["pavilion_w_back"][0])
    pf.paste(names["pavilion_w_front"][0])
    refl = [(pf, FRONT_Y + 20, 0.45)]
    for n in ("rowboat_1", "rowboat_2", "swanboat_1", "swanboat_2"):
        L, f = names[n]
        refl.append((L, f - 10, 0.45))
    for n, (L, f) in names.items():
        if n.startswith("dock_post") or n.startswith("dock_lamp") or n.startswith("reeds"):
            refl.append((L, f + 2, 0.5))
    paint_water_w(BG, BK, BK0, refl)
    paint_ground_w(BG)
    E.LOTUS = LOTUS_W
    E.paint_lotus_pads(BG)
    paint_platform_and_dock(BG)
    build_shade(stands).apply(BG)
    for (n, cx) in (("rowboat_1", G(792)), ("rowboat_2", G(780)), ("swanboat_1", G(1008)), ("swanboat_2", G(1024))):
        L, f = names[n]
        for x in range(L.ox - 4, L.ox + L.w + 6):
            y = f - 10 + 2 + int(2 * math.sin(x * 0.3))
            if is_water(x, y) and (x // 3) % 2 == 0:
                BG.p(x, y, "bl4")
    used = palette_check(BG.im, "bg_w")
    for (n, L, f) in stands:
        used |= palette_check(L.im, n)
    bg_e, stands_e = load_east()
    full = compose_full(BG.im, stands, bg_e, stands_e)
    used_full = palette_check(full, "full")
    used_e = palette_check(bg_e, "bg_e")
    for (n, L, f) in stands_e:
        used_e |= palette_check(L.im, n)
    allc = used | used_e | used_full
    print("西半边用色 %d，东半边 %d，两半合起来 %d / 64" % (len(used), len(used_e), len(allc)))
    if len(allc) > 64:
        raise SystemExit("超过 64 色")
    # ---- 存图层
    for fn in os.listdir(LAYER_DIR):
        if fn.endswith(".png"):
            os.remove(os.path.join(LAYER_DIR, fn))
    BG.im.save(os.path.join(LAYER_DIR, "bg_lake_west.png"))
    meta = {"note": "draw_lake_west.py 生成，别手改。湖边长湖岸的西半边（x 0～1536）。底图 bg 先画；其余是立着的，按 foot_y 跟人排前后（同一条着地线照 x 排）。"
                    "坐标就是游戏画布坐标（西半边不用加偏移）；有几张（树冠、柳条）伸出 0～1536 一点，照着放就行。1 倍不插值。",
            "canvas": [W, H], "x_offset_in_game": 0, "base": {"png": "bg_lake_west.png", "x": 0, "y": 0}, "layers": []}
    for (n, L, f) in stands:
        L.im.save(os.path.join(LAYER_DIR, n + ".png"))
        meta["layers"].append({"name": n, "png": n + ".png", "x": L.ox + XO, "y": L.oy, "w": L.w, "h": L.h, "foot_y": f, "kind": "stand"})
    with open(os.path.join(LAYER_DIR, "layers.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=1)
    import west_layout
    lay = west_layout.export(stands, BG)
    full.save(os.path.join(HERE, "lake_full.png"))
    full.resize((W, H // 2), Image.NEAREST).save(os.path.join(HERE, "lake_full_half.png"))
    west_layout.make_views(BG, stands, bg_e, stands_e, full, lay, compose_full)
    if tag:
        os.makedirs(ROUND_DIR, exist_ok=True)
        full.resize((W, H // 2), Image.NEAREST).save(os.path.join(ROUND_DIR, tag + "_half.png"))
        full.crop((0, 0, W, H)).save(os.path.join(ROUND_DIR, tag + "_west.png"))
        for fn in os.listdir(HERE):
            if fn.startswith("lake_west_phone") or fn == "lake_vs.png":
                Image.open(os.path.join(HERE, fn)).save(os.path.join(ROUND_DIR, tag + "_" + fn))


if __name__ == "__main__":
    main()
