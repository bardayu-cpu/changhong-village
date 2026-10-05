#!/usr/bin/env python3
"""化妆间 · 照 GPT 效果图用代码画（01 H 10/5 派，02 F 画；跟湖边东头还原一个做法）。
阿鱼 10/5：「还有个办法，像湖边一样，你完全按照他的图来画」。效果图：docs/参考图/化妆间效果图-GPT-阿鱼10-05.png（98f798f，941×1672）。

摆法照效果图（不照 C 档）：每件东西的位置用 02 F 量的坐标（godot/回执/化妆间效果图还原-1005/效果图量的坐标.md，图上像素），
整张等比缩进 540×960 的画布（K = 540/941）：手机竖屏一屏正好看完整间，顶上那行（地名、金币、屋名）只压着帷幔和墙，北墙那排坐着的人露在外面。
画法跟湖边、后厅一家：1 倍像素、硬边、光从左上来、外圈深描边，颜色从效果图取（调色板借后厅那份，加淡紫、薄荷两条色带）。

出一个「拆景包」（底图 base.png、每件家具一张 blk_*.png、placement.json，跟 GPT 拆景台交的一个格式），交给 tools/import_makeup_blocks.py 拼回游戏：
blk 按 foot_y 跟人排前后，footprint 挡人（一直画到 foot_y），seats 坐人；两道检查照跑。
用法：python3 godot/tools/pixel_art/room_makeup_ref.py [--preview 目录]
   出包到临时目录，接着导入到 assets/pixel_art/makeup_room/、化妆间布局；--preview 再出整间 1:1、跟效果图同比例并排
"""
import json
import math
import os
import random
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import backhall_floor
import room_backhall_makeup as mk
from room_backhall_makeup import C, Layer, rname, shift

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
CW, CH = 540, 960
K = CW / 941.0
REF_GIT = "98f798f:docs/参考图/化妆间效果图-GPT-阿鱼10-05.png"


def R(v):
    return int(round(v * K))


# ------------------------------------------------------------------ 调色板：后厅那份 + 淡紫、薄荷
NEW = {"lv0": "#7d68a3", "lv1": "#a690c9", "lv2": "#cdbde6", "mt0": "#4f9a86", "mt1": "#8fcfb8", "mt2": "#c4ead9"}
for k_, v_ in NEW.items():
    mk.PAL_HEX[k_] = v_
    C[k_] = mk.hex2rgba(v_)
mk.RAMPS["lv"] = ["pu", "lv0", "lv1", "lv2", "wt"]
mk.RAMPS["mt"] = ["tl", "mt0", "mt1", "mt2", "wt"]
for rn_ in ("lv", "mt"):
    for i_, n_ in enumerate(mk.RAMPS[rn_]):
        if n_ not in ("pu", "tl", "wt"):
            mk.RAMP_OF[C[n_]] = (rn_, i_)


def frame():
    mk.X0, mk.Y0, mk.W, mk.H = 0, 0, CW, CH
    mk.X1, mk.Y1 = CW, CH


def L0():
    return Layer(x0=0, y0=0, w=CW, h=CH)


PIECES = []


def add(name, L, foot, fp, seats=(), outline=True):
    """一件家具：裁到画了的那块；fp = 占地 [x0, y0, x1, y1]（画布坐标），下沿就是着地线"""
    if outline:
        L.outline()
    box = L.im.getbbox()
    if box is None:
        return
    x0, y0, x1, y1 = fp
    PIECES.append({"id": name, "img": L.im.crop(box), "x": box[0], "y": box[1], "foot": foot,
                   "footprint": [x0, y0, x1 - x0, foot - y0], "seats": [list(s) for s in seats]})


# ================================================================== 小件
def rose(L, cx, cy, col, r=2):
    """一朵玫瑰：外圈暗一档描边，花瓣中间色，左上亮，中心一道卷"""
    ramp = {"rd": ["rd1", "rd3", "rd4"], "pk": ["pk0", "pk", "pk2"], "wt": ["sv1", "sv2", "wt"]}[col]
    L.ell(cx - r, cy - r, cx + r + 1, cy + r + 1, ramp[0])
    L.ell(cx - r + 1, cy - r + 1, cx + r, cy + r, ramp[1])
    L.p(cx - 1, cy - 1, ramp[2])
    L.p(cx - r + 1, cy, ramp[2])
    L.p(cx, cy, ramp[0])
    L.p(cx + 1, cy, ramp[0])


def bouquet(L, cx, cy, rx, ry, seed, n=None):
    """一捧红粉白玫瑰（效果图里每瓶花都是满满一大捧）：深绿叶底只在边上露几片叶尖，花一朵挨一朵挤满，下面的先画"""
    rnd = random.Random(seed)
    L.ell(cx - rx - 1, cy - ry - 1, cx + rx + 2, cy + ry + 2, "gr1")
    for k in range(10):
        a = k * 0.628 + rnd.random() * 0.3
        lx, ly = cx + math.cos(a) * (rx + 1), cy + math.sin(a) * (ry + 1)
        mk.leaf(L, lx, ly, 5, a, 2, 3, vein=False)
    r = 3 if rx >= 9 else 2
    spots = []
    step = r * 2 - 1
    for gy in range(int(cy - ry + r), int(cy + ry - r + 1), step):
        for gx in range(int(cx - rx + r), int(cx + rx - r + 1), step):
            jx, jy = gx + rnd.randint(-1, 1), gy + rnd.randint(-1, 1)
            if ((jx - cx) / float(rx)) ** 2 + ((jy - cy) / float(ry)) ** 2 <= 0.85:
                spots.append((jx, jy))
    spots.sort(key=lambda t: t[1])
    for (x, y) in spots:
        rose(L, x, y, rnd.choice(["rd", "pk", "pk", "wt", "rd", "pk"]), r=r)


def porcelain(L, cx, top, bot, hw):
    """青花瓷瓶：白身、蓝花、瓶口收窄"""
    for y in range(top, bot):
        t = (y - top) / float(max(1, bot - top))
        w = hw * (0.55 + 0.45 * math.sin(math.pi * min(1.0, t * 1.15)))
        if t < 0.12:
            w = hw * 0.6
        L.hl(int(cx - w), int(cx + w) + 1, y, "wt")
        L.p(int(cx - w), y, "sv2")
        L.p(int(cx + w), y, "sv1")
        if (y - top) % 4 in (1, 2) and 0.2 < t < 0.85:
            for x in range(int(cx - w) + 2, int(cx + w) - 1, 3):
                L.p(x + ((y // 4) % 2), y, "bl2")
    L.hl(cx - int(hw * 0.6), cx + int(hw * 0.6) + 1, top, "bl2")


def gold_vase(L, cx, top, bot, hw):
    """金色高脚花瓶（瓶身鼓、细颈、喇叭口、方座）"""
    for y in range(top, bot):
        t = (y - top) / float(max(1, bot - top))
        if t < 0.08:
            w = hw * 0.85
        elif t < 0.5:
            w = hw * (0.45 + 0.55 * math.sin(math.pi * (t - 0.08) / 0.42))
        elif t < 0.82:
            w = hw * 0.32
        else:
            w = hw * (0.5 + (t - 0.82) * 2.2)
        L.hl(int(cx - w), int(cx + w) + 1, y, "gd2")
        L.p(int(cx - w) + 1, y, "gd4")
        L.p(int(cx - w) + 2, y, "gd3")
        L.p(int(cx + w), y, "gd1")


def knob(L, x, y):
    L.p(x, y, "gd3")
    L.p(x - 1, y, "gd2")
    L.p(x, y - 1, "gd4")


def cabinet(L, x0, x1, top, front, foot, ramp="rd", lv=2, doors=2, drawers=0):
    """红木小柜：顶面亮一档，正面门板（凹进去一圈）、金拉手；四只金脚"""
    L.rect(x0, top, x1, front, rname(ramp, lv + 1))
    L.hl(x0, x1, top, rname(ramp, lv + 2))
    L.rect(x0, front, x1, foot - 2, rname(ramp, lv))
    L.hl(x0, x1, front, "gd2")
    n = max(1, doors)
    rows = max(1, drawers) if drawers else 1
    pw = (x1 - x0 - 2) / float(n)
    ph = (foot - 2 - front - 2) / float(rows)
    for i in range(n):
        for j in range(rows):
            a, b = int(x0 + 1 + i * pw) + 1, int(x0 + 1 + (i + 1) * pw) - 1
            c, d = int(front + 2 + j * ph), int(front + 2 + (j + 1) * ph) - 1
            if b - a < 3 or d - c < 3:
                continue
            L.rect(a, c, b, d, rname(ramp, lv - 1))
            L.rect(a + 1, c + 1, b, d, rname(ramp, lv))
            L.hl(a, b, d - 1, rname(ramp, lv + 1))
            knob(L, (a + b) // 2, (c + d) // 2)
    L.vl(x0, top, foot - 2, rname(ramp, lv + 1))
    L.vl(x1 - 1, front, foot - 2, rname(ramp, lv - 1))
    for lx in (x0 + 1, x1 - 3):
        L.rect(lx, foot - 2, lx + 2, foot, "gd1")


# ================================================================== 底图：墙、地、地毯、墙上挂的
def draw_wall(L):
    x0, x1 = R(27), R(913)
    top, foot = R(25), R(205)
    L.rect(x0, top, x1, foot, "wl3")
    for x in range(x0, x1):
        if x % 6 == 0:
            L.vl(x, top, foot, "wl2")
        elif x % 6 in (2, 3):
            L.vl(x, top, foot, "wl4")
    L.rect(x0, foot - 6, x1, foot, "wd2")
    L.hl(x0, x1, foot - 6, "wd4")
    L.hl(x0, x1, foot - 1, "wd0")
    # 墙顶剖面、两边墙顶
    L.rect(0, 0, CW, top, "void")
    L.rect(x0 - 8, top - 6, x1 + 8, top, "wl4")
    L.hl(x0 - 8, x1 + 8, top - 6, "ol")
    L.hl(x0 - 8, x1 + 8, top - 1, "ol")
    for (a, b) in ((x0 - 8, x0), (x1, x1 + 8)):
        L.rect(a, top - 6, b, R(1500), "wl4")
        L.vl(a, top - 6, R(1500), "ol")
        L.vl(b - 1, top - 6, R(1500), "ol")
        L.vl(a + 1, top - 5, R(1500), "wl5")
    L.rect(0, 0, x0 - 8, CH, "void")
    L.rect(x1 + 8, 0, CW, CH, "void")


def draw_curtain(L):
    draw_curtain_layer(L, R(25) + 2, 46, 15, 0, back=True)
    draw_curtain_layer(L, R(25), 34, 11, 17, back=False)


def draw_curtain_layer(L, y0, span, depth, off, back):
    x0, x1 = R(27), R(913)
    for a in range(x0 - off, x1, span):
        b = min(a + span, x1)
        for x in range(max(a, x0), b):
            t = (x - a + 0.5) / float(span)
            sag = math.sin(math.pi * t)
            yb = y0 + 5 + depth * sag
            for y in range(y0 + 5, int(yb) + 1):
                band = (y - y0 - 5 - 3 * sag)
                lv = 2 if back else 3
                if 0 <= band < 1 or 4 <= band < 5 or 8 <= band < 9:
                    lv -= 1
                if 1 <= band < 2 and 0.2 < t < 0.8:
                    lv += 1
                L.p(x, y, rname("rd", lv))
            L.p(x, int(yb) + 1, "rd1" if not back else "rd0")
        if not back and x0 <= a < x1:
            L.ell(a - 2, y0 + 3, a + 3, y0 + 8, "gd3")
            L.p(a, y0 + 4, "gd4")
            for y in range(y0 + 8, y0 + 16):
                L.p(a, y, "gd2")
                L.p(a + (1 if y > y0 + 12 else 0), y, "gd3")
    L.rect(x0, y0 - 2 if not back else y0, x1, y0 + 5, "rd2")
    L.hl(x0, x1, y0 + 4, "gd3")
    L.hl(x0, x1, y0 + 2, "gd2")


def draw_curtain_old(L):
    """北墙上沿红帷幔：一道横楣（金边）+ 一排垂弧，每个弧里几道褶"""
    x0, x1 = R(27), R(913)
    y0 = R(25)
    L.rect(x0, y0, x1, y0 + 5, "rd2")
    L.hl(x0, x1, y0 + 4, "gd2")
    span = 34
    for a in range(x0, x1, span):
        b = min(a + span, x1)
        for x in range(a, b):
            t = (x - a + 0.5) / float(span)
            sag = math.sin(math.pi * t)
            yb = y0 + 5 + 11 * sag
            for y in range(y0 + 5, int(yb) + 1):
                band = (y - y0 - 5 - 3 * sag)
                lv = 3
                if 0 <= band < 1 or 4 <= band < 5:
                    lv = 2
                if 1 <= band < 2 and 0.2 < t < 0.8:
                    lv = 4
                L.p(x, y, rname("rd", lv))
            L.p(x, int(yb) + 1, "rd1")
        L.ell(a - 2, y0 + 3, a + 3, y0 + 8, "gd3")


def lantern(L, cx, top, big):
    """挂着的红灯笼：金顶、红肚子竖棱、金底、红穗"""
    rx, h = (6, 16) if big else (4, 11)
    L.vl(cx, R(25), top, "gd1")
    L.rect(cx - 2, top, cx + 3, top + 2, "gd2")
    y0, y1 = top + 2, top + 2 + h
    L.ell(cx - rx, y0, cx + rx + 1, y1, "rd3")
    L.ell(cx - rx + 2, y0 + 2, cx + rx - 1, y1 - 2, "rd4")
    L.ell(cx - 1, y0 + 3, cx + 2, y1 - 3, "rd5")
    for d in (-rx + 2, rx - 2):
        L.vl(cx + d, y0 + 2, y1 - 2, "rd2")
    L.rect(cx - 2, y1, cx + 3, y1 + 2, "gd2")
    for y in range(y1 + 2, y1 + 2 + (8 if big else 5)):
        L.p(cx, y, "rd3")
    L.p(cx - 1, y1 + 2, "gd3")


def palace_lamp(L, cx, top, h):
    """宫灯（黄）：六角、金框、里面暖黄亮"""
    L.rect(cx - 5, top, cx + 6, top + h, "gd1")
    L.rect(cx - 4, top + 2, cx + 5, top + h - 2, "gd4")
    L.rect(cx - 2, top + 3, cx + 3, top + h - 3, "wt")
    L.vl(cx - 4, top + 2, top + h - 2, "gd2")
    L.vl(cx + 4, top + 2, top + h - 2, "gd3")
    L.hl(cx - 6, cx + 7, top, "rd2")
    L.hl(cx - 6, cx + 7, top + h - 1, "rd2")
    L.vl(cx, top + h, top + h + 4, "rd3")


def arch_mirror(L, cx, top, bot, hw):
    """拱形灯泡镜（墙上）：金框一圈灯泡，镜面浅蓝两道斜反光"""
    cy = top + hw
    def dist(x, y):
        if y + 0.5 >= cy:
            return abs(x + 0.5 - cx)
        return math.hypot(x + 0.5 - cx, y + 0.5 - cy)
    band = 5
    for y in range(top, bot):
        for x in range(cx - hw - 1, cx + hw + 2):
            d = dist(x, y)
            if d > hw:
                continue
            if hw - d < band:
                ring = hw - d
                L.p(x, y, "gd4" if ring < 1 and (x < cx and y < cy + 4) else ("gd1" if ring < 1 else ("gd3" if ring < 2.5 else "gd2")))
            else:
                g = hw - band
                u = (x - (cx - g)) / float(2 * g)
                t = (y - (cy - g)) / float(bot - (cy - g))
                c = "bl4" if u + t < 0.7 else "bl3"
                if t > 0.85:
                    c = "bl2"
                L.p(x, y, c)
    g = hw - band
    for (o, wdt) in ((6, 3), (12, 1)):
        for y in range(cy - g + 3, bot - 2):
            xx = cx - g + o + (bot - y) // 2 - 10
            for kx in range(wdt):
                if dist(xx + kx, y) < g - 1:
                    L.p(xx + kx, y, "wt")
    rc = hw - band / 2.0
    pts = [(cx - 0.5 + rc * math.cos(math.pi - k * math.pi / 6), cy - 0.5 - rc * math.sin(math.pi - k * math.pi / 6)) for k in range(7)]
    for k in range(1, 4):
        pts += [(cx - 0.5 - rc, cy - 0.5 + k * 8), (cx - 0.5 + rc, cy - 0.5 + k * 8)]
    for (bx, by) in pts:
        bx, by = int(round(bx)), int(round(by))
        if by < bot - 1:
            L.ell(bx - 2, by - 2, bx + 3, by + 3, "gd4")
            L.rect(bx - 1, by - 1, bx + 2, by + 2, "wt")
            L.p(bx + 1, by + 1, "gd4")


def rug(L, x0, y0, x1, y1, ellipse=False, seed=1):
    """红底金花地毯：一圈金边（回纹），里面撒金色团花"""
    rnd = random.Random(seed)
    if ellipse:
        L.ell(x0, y0, x1, y1, "rd2")
        L.ell(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "gd2")
        L.ell(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "rd3")
        L.ring(x0 + 6, y0 + 5, x1 - 6, y1 - 5, "gd2")
    else:
        L.rect(x0, y0, x1, y1, "rd2")
        L.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "gd2")
        L.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "rd3")
        for x in range(x0 + 5, x1 - 5, 4):
            L.p(x, y0 + 5, "gd2")
            L.p(x + 2, y1 - 6, "gd2")
        for y in range(y0 + 5, y1 - 5, 4):
            L.p(x0 + 5, y, "gd2")
            L.p(x1 - 6, y + 2, "gd2")
    cx0, cy0 = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    for _ in range(int((x1 - x0) * (y1 - y0) / 260)):
        x = rnd.randrange(x0 + 8, x1 - 8)
        y = rnd.randrange(y0 + 7, y1 - 7)
        if ellipse and ((x - cx0) / ((x1 - x0) / 2.0 - 8)) ** 2 + ((y - cy0) / ((y1 - y0) / 2.0 - 7)) ** 2 > 1:
            continue
        for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            L.p(x + dx, y + dy, "gd2")
        L.p(x, y, "gd3")


def runner(L, x0, y0, x1, y1):
    """正中长红毯：回纹金边 + 中间一列大金团花"""
    L.rect(x0, y0, x1, y1, "rd2")
    bw = 9
    L.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "rd3")
    KEY = mk.KEY
    for (by, flip) in ((y0 + 2, False), (y1 - 9, True)):
        for x in range(x0 + 2, x1 - 2):
            for r in range(7):
                row = KEY[6 - r] if flip else KEY[r]
                if row[(x - x0) % 8] == "1":
                    L.p(x, by + r, "gd3")
    for (bx, flip) in ((x0 + 2, False), (x1 - 9, True)):
        for y in range(y0 + 9, y1 - 9):
            for c in range(7):
                row = KEY[6 - c] if flip else KEY[c]
                if row[(y - y0) % 8] == "1":
                    L.p(bx + c, y, "gd3")
    L.rect(x0 + bw + 1, y0 + bw + 1, x1 - bw - 1, y1 - bw - 1, "rd3")
    L.ring(x0 + bw, y0 + bw, x1 - bw, y1 - bw, "rd2") if False else None
    for x in range(x0 + bw, x1 - bw):
        L.p(x, y0 + bw, "rd1")
        L.p(x, y1 - bw - 1, "rd1")
    for y in range(y0 + bw, y1 - bw):
        L.p(x0 + bw, y, "rd1")
        L.p(x1 - bw - 1, y, "rd1")
    cx = (x0 + x1) // 2
    for y in range(y0 + 40, y1 - 24, 92):
        # 一朵大金团花：八片花瓣、花心红、四角卷草
        for k in range(8):
            a = k * math.pi / 4
            px_, py_ = cx + math.cos(a) * 9, y + math.sin(a) * 9
            L.ell(px_ - 4, py_ - 4, px_ + 5, py_ + 5, "gd2")
            L.ell(px_ - 2, py_ - 2, px_ + 3, py_ + 3, "gd3")
            L.p(int(px_), int(py_), "gd4")
        L.ell(cx - 6, y - 6, cx + 7, y + 7, "gd2")
        L.ell(cx - 4, y - 4, cx + 5, y + 5, "rd3")
        L.ell(cx - 2, y - 2, cx + 3, y + 3, "gd4")
        for (dx, dy) in ((-22, -18), (22, -18), (-22, 18), (22, 18), (0, -26), (0, 26)):
            L.ell(cx + dx - 2, y + dy - 2, cx + dx + 3, y + dy + 3, "gd2")
            L.p(cx + dx - 3, y + dy, "gd2")
            L.p(cx + dx + 3, y + dy, "gd2")
            L.p(cx + dx, y + dy, "gd4")
    for y in range(y0 + 16, y1 - 12, 31):
        for x in (x0 + 20, x1 - 21):
            L.p(x, y, "gd2")
            L.p(x - 1, y + 1, "gd2")
            L.p(x + 1, y + 1, "gd2")


def corridor(L, y0):
    rnd = random.Random(5)
    L.rect(0, y0, CW, CH, "wl2")
    for row, y in enumerate(range(y0, CH, 11)):
        off = 0 if row % 2 == 0 else 22
        for x in range(-44 + off, CW, 44):
            tone = rnd.choice(["wl2", "wl3", "wl2", "wl3", "wl1"])
            L.rect(x + 1, y + 1, x + 44, y + 11, tone)
            L.hl(x + 1, x + 44, y + 1, shift(tone, 1))
            L.vl(x, y, y + 11, "wl0")
        L.hl(0, CW, y, "wl0")


def RAMP_WALL(c):
    return mk.RAMP_OF.get(c, ("",))[0] == "wl"


def background():
    frame()
    L = L0()
    L.rect(0, 0, CW, CH, "void")
    backhall_floor.FLOOR_Y0 = R(205)
    backhall_floor.draw_floor_v3(L, R(27), R(913), R(1500), seed=11)
    draw_wall(L)
    draw_curtain(L)
    glow = mk.ShadeMap()
    for cx in (226, 388, 551, 715):   # 镜子一圈灯泡把墙照亮（暖光，挪档）
        glow.ellipse(R(cx), R(122), R(80), R(72), 1.0, edge=3)
        glow.ellipse(R(cx), R(122), R(62), R(58), 1.0, edge=3)
    for cx in (280, 452, 488, 660, 150, 790):          # 灯笼、宫灯照墙
        glow.ellipse(R(cx), R(80), R(26), R(30), 1.0, edge=2)
    glow.apply(L, clip=lambda x, y: R(25) < y < R(205) - 6 and RAMP_WALL(L.g(x, y)))
    for cx in (226, 388, 551, 715):
        arch_mirror(L, R(cx), R(75), R(170), R(46))
    for x, big in ((280, True), (452, True), (488, True), (660, True), (172, False), (325, False), (615, False), (772, False)):
        lantern(L, R(x), R(42) if big else R(58), big)
    palace_lamp(L, R(150), R(85), 14)
    palace_lamp(L, R(790), R(85), 14)
    runner(L, R(362), R(300), R(578), R(1430))
    rug(L, R(90), R(1090), R(330), R(1240), ellipse=True, seed=3)
    rug(L, R(610), R(1090), R(860), R(1240), ellipse=True, seed=4)
    rug(L, R(40), R(1355), R(300), R(1480), seed=5)
    rug(L, R(640), R(1395), R(900), R(1480), seed=6)
    rug(L, R(400), R(1465), R(540), R(1545), seed=7)
    # 南墙：顶面米白、正面木护墙板；门洞两根门柱、柱头小灯
    y_top, y_face, y_bot = R(1500), R(1520), R(1545)
    corridor(L, y_bot)
    for (a, b) in ((R(27) - 8, R(395)), (R(545), R(913) + 8)):
        L.rect(a, y_top, b, y_face, "wl4")
        L.hl(a, b, y_top, "ol")
        L.hl(a, b, y_top + 1, "wl5")
        L.rect(a, y_face, b, y_bot, "wd3")
        L.hl(a, b, y_face, "ol")
        for x in range(a + 3, b - 10, 14):
            L.rect(x, y_face + 3, x + 11, y_bot - 3, "wd2")
            L.rect(x + 1, y_face + 4, x + 10, y_bot - 4, "wd3")
            L.hl(x + 1, x + 10, y_bot - 4, "wd4")
        L.hl(a, b, y_bot - 1, "wd0")
    for px in (R(372), R(560)):
        L.rect(px - 5, y_top - 10, px + 6, y_bot, "wd1")
        L.vl(px - 5, y_top - 10, y_bot, "wd3")
        L.rect(px - 3, y_top - 18, px + 4, y_top - 10, "gd4")
        L.rect(px - 2, y_top - 16, px + 3, y_top - 12, "wt")
        L.hl(px - 4, px + 5, y_top - 19, "gd1")
    # 影子：北墙脚、两边墙根
    S = mk.ShadeMap()
    S.rect(R(27), R(205), R(913), R(205) + 3, -1.5)
    S.rect(R(27), R(205), R(27) + 5, R(1500), -1.0)
    S.rect(R(913) - 3, R(205), R(913), R(1500), -0.5)
    S.apply(L, clip=lambda x, y: R(205) <= y < R(1500))
    return L


# ================================================================== 北墙一排
def corner_cabinet(name, x0, x1, top, foot, seed):
    L = L0()
    sh = top + R(55)   # 柜身从这起（上面摆花）
    L.rect(x0, sh, x1, foot - 2, "rd1")
    L.rect(x0 + 2, sh + 2, x1 - 2, foot - 16, "rd1")
    L.vl(x0, sh, foot - 2, "rd3")
    L.vl(x1 - 1, sh, foot - 2, "rd0")
    L.rect(x0 - 1, sh - 3, x1 + 1, sh + 1, "gd2")
    L.hl(x0 - 1, x1 + 1, sh - 3, "gd4")
    rows = [sh + 4, sh + 22, sh + 40, sh + 58]
    for y in rows[1:]:
        L.rect(x0 + 2, y - 2, x1 - 2, y, "rd2")
        L.hl(x0 + 2, x1 - 2, y - 2, "gd2")
    rnd = random.Random(seed)
    # 第一层：头冠、簪花
    y = rows[1] - 3
    crown_big(L, (x0 + x1) // 2, y, (x1 - x0) // 2)
    hairpin(L, x0 + 7, y, "rd")
    hairpin(L, x1 - 8, y, "wt")
    # 第二层：三个包
    y = rows[2] - 3
    for k, col in enumerate(("pk", "wl4", "wl5")):
        cx = x0 + 8 + k * ((x1 - x0 - 16) // 2)
        L.rect(cx - 4, y - 7, cx + 5, y, mk.rname("pk", 1) if col == "pk" else col)
        L.hl(cx - 4, cx + 5, y - 7, "gd3")
        L.ring(cx - 2, y - 11, cx + 3, y - 5, "gd2", only=lambda xx, yy, y=y: yy < y - 7)
        L.p(cx, y - 4, "gd3")
    # 第三层：两个红箱
    y = rows[3] - 3
    for k in range(2):
        cx = x0 + 12 + k * (x1 - x0 - 24)
        L.rect(cx - 7, y - 9, cx + 8, y, "rd3")
        L.hl(cx - 7, cx + 8, y - 9, "rd4")
        L.hl(cx - 7, cx + 8, y - 6, "gd2")
        L.rect(cx - 1, y - 6, cx + 2, y - 3, "gd3")
    # 下面两扇门
    cabinet(L, x0, x1, foot - 16, foot - 14, foot, ramp="rd", lv=2, doors=2)
    # 顶上一盆花
    bouquet(L, (x0 + x1) // 2, sh - 9, (x1 - x0) // 2 - 4, 7, seed)
    S = mk.ShadeMap()
    S.rect(x0 + 2, sh + 2, x1 - 2, sh + 6, -1.0)
    S.apply(L)
    add(name, L, foot, [x0, foot - 10, x1, foot])


def dresser(name, x0, x1, top, front, foot, i):
    """化妆台：奶白台面金边、正面左右各两个抽屉、中间放腿；台面摆满化妆品"""
    L = L0()
    L.rect(x0, top, x1, front, "wl5")
    L.hl(x0, x1, top, "wl3")
    L.vl(x1 - 1, top, front, "wl3")
    L.rect(x0, front, x1, front + 3, "gd2")
    L.hl(x0, x1, front, "gd4")
    fy = front + 3
    L.rect(x0, fy, x1, foot - 2, "wl3")
    pw = (x1 - x0) // 3
    for (a, b) in ((x0 + 2, x0 + pw), (x1 - pw, x1 - 2)):
        for (c, d) in ((fy + 1, fy + (foot - fy) // 2), (fy + (foot - fy) // 2 + 1, foot - 3)):
            L.rect(a, c, b, d, "wl2")
            L.rect(a + 1, c + 1, b - 1, d - 1, "wl4")
            knob(L, (a + b) // 2, (c + d) // 2)
    L.rect(x0 + pw + 2, fy + 2, x1 - pw - 2, foot - 2, "wd1")
    L.rect(x0 + pw + 2, fy + 2, x1 - pw - 2, fy + 5, "wl2")
    for lx in (x0 + 1, x1 - 3):
        L.rect(lx, foot - 2, lx + 2, foot, "gd1")
    # 台面上的化妆品（照效果图：粉瓶、刷筒、眼影盘、口红一排、粉饼、一盒纸巾、小镜子）
    b = top + 9                      # 后排（贴镜子）的底线
    f = top + 18                     # 前排
    rnd = random.Random(i * 7 + 3)
    # 后排：一排瓶瓶罐罐（高矮、颜色不一），左右各一个刷筒
    x = x0 + 4
    while x < x1 - 5:
        k = rnd.randrange(5)
        col = rnd.choice(["pk", "pk2", "wt", "rd4", "gd3", "pk0", "lv1"])
        if k <= 2:   # 瓶子
            h = rnd.randrange(6, 11)
            L.rect(x, b - h, x + 4, b, col)
            L.vl(x, b - h, b, shift(col, 1))
            L.vl(x + 3, b - h, b, shift(col, -1))
            L.rect(x + 1, b - h - 2, x + 3, b - h, rnd.choice(["gd3", "ik1", "wt"]))
            x += 5
        elif k == 3:   # 刷筒
            L.rect(x, b - 6, x + 5, b, "ik1")
            for j in range(4):
                L.vl(x + j + 1, b - 11 + (j % 2), b - 6, rnd.choice(["ik2", "wd3", "pk"]))
            x += 6
        else:   # 纸巾盒
            L.rect(x, b - 5, x + 8, b, "wt")
            L.hl(x, x + 8, b - 5, "sv2")
            L.p(x + 4, b - 7, "wt")
            x += 9
    # 前排：眼影盘、口红一排、粉饼、化妆包
    x = x0 + 5
    while x < x1 - 10:
        k = rnd.randrange(4)
        if k == 0:
            L.rect(x, f - 4, x + 11, f, "ik1")
            for j in range(4):
                L.rect(x + 1 + j * 2 + (j // 2), f - 3, x + 3 + j * 2 + (j // 2), f - 1, rnd.choice(["pk", "rd4", "gd3", "bl3", "or", "lv1"]))
            x += 13
        elif k == 1:
            for j in range(4):
                L.rect(x + j * 2, f - 5, x + j * 2 + 1, f, rnd.choice(["rd4", "pk", "rd3", "pk0"]))
                L.p(x + j * 2, f - 6, "gd3")
            x += 10
        elif k == 2:
            L.ell(x, f - 4, x + 7, f + 1, rnd.choice(["pk2", "gd3", "pk"]))
            L.p(x + 2, f - 3, "wt")
            x += 9
        else:
            L.rect(x, f - 5, x + 9, f, rnd.choice(["pk0", "rd3", "ik2"]))
            L.hl(x, x + 9, f - 5, "gd3")
            x += 11
    S = mk.ShadeMap()
    S.rect(x0 + 2, top + 1, x1 - 2, top + 4, 0.5)
    S.apply(L)
    add(name, L, foot, [x0, foot - R(30), x1, foot])


def stool(name, cx, top, foot):
    """红圆凳：红丝绒鼓面、金边、一圈金流苏、四条金腿"""
    L = L0()
    rx = R(25)
    sy = top + 5
    L.ell(cx - rx, sy - 5, cx + rx + 1, sy + 6, "rd3")
    L.ell(cx - rx + 2, sy - 4, cx + rx - 1, sy + 4, "rd4")
    L.p(cx - 3, sy - 2, "rd5")
    L.rect(cx - rx, sy, cx + rx + 1, sy + 8, "rd2")
    L.ell(cx - rx, sy + 4, cx + rx + 1, sy + 12, "rd2")
    L.hl(cx - rx, cx + rx + 1, sy + 1, "gd3")
    for x in range(cx - rx + 1, cx + rx, 2):
        L.vl(x, sy + 8, sy + 12, "gd2")
        L.p(x, sy + 12, "rd3")
    for lx in (cx - rx + 3, cx + rx - 3):
        L.vl(lx, sy + 12, foot, "gd1")
        L.p(lx, foot - 1, "gd3")
    L.vl(cx, sy + 12, foot - 1, "gd1")
    add(name, L, foot, [cx - rx, foot - 7, cx + rx + 1, foot], seats=[(cx, foot + 1)])


def vase_stand(name, cx, top, foot):
    """化妆台之间的高脚花：金色细高脚架上一个青花瓶插一捧玫瑰"""
    L = L0()
    L.rect(cx - 2, top + 26, cx + 3, foot - 2, "gd2")
    L.vl(cx - 2, top + 26, foot - 2, "gd4")
    L.rect(cx - 4, foot - 3, cx + 5, foot, "gd1")
    L.rect(cx - 4, top + 24, cx + 5, top + 27, "gd3")
    porcelain(L, cx, top + 12, top + 24, 5)
    bouquet(L, cx, top + 5, 11, 9, cx)
    add(name, L, foot, [cx - 4, foot - 4, cx + 5, foot])


# ================================================================== 衣架
def rack(name, x0, x1, top, foot, garments, seed, shoes=False):
    """一排衣架：深红木背板（金框线）、两头金柱（圆球头）、金横杆、底下一排红木抽屉；衣服挂满"""
    L = L0()
    base_h = 11
    bar = top + 9
    # 背板
    L.rect(x0 + 3, top + 4, x1 - 3, foot - base_h, "rd0")
    L.rect(x0 + 5, top + 6, x1 - 5, foot - base_h, "rd1")
    L.hl(x0 + 5, x1 - 5, top + 6, "rd2")
    for x in range(x0 + 8, x1 - 6, 6):
        L.vl(x, top + 7, foot - base_h, "rd0")
    # 衣服
    n = len(garments)
    step = (x1 - x0 - 22) / float(max(1, n - 1))
    ln_max = foot - base_h - bar - 6 - (8 if shoes else 0)
    for i, g in enumerate(garments):
        cx = int(round(x0 + 11 + i * step))
        s = mk.sub(cx - 18, bar - 6, cx + 19, foot)
        g = dict(g)
        g["ln"] = min(g["ln"], ln_max - (g.get("pants", 0) if g["kind"] == "suit" else 0))
        if callable(g.get("fn")):
            g["fn"](s, cx, bar + 2, g["ln"])
        else:
            mk.garment(s, g, cx, bar + 2, seed=seed + i * 5)
        mk.paste_ol(L, s)
    if shoes:
        rnd = random.Random(seed)
        y = foot - base_h - 3
        for x in range(x0 + 8, x1 - 8, 9):
            col = rnd.choice(["wt", "pk", "rd4", "ik1", "wd3", "pk2"])
            L.rect(x, y - 2, x + 3, y + 1, col)
            L.rect(x + 4, y - 2, x + 7, y + 1, col)
            L.p(x, y - 2, shift(col, 1))
    # 架子：横杆、两根金柱
    L.rect(x0 + 2, bar - 1, x1 - 2, bar + 1, "gd2")
    L.hl(x0 + 2, x1 - 2, bar - 1, "gd4")
    for x in range(x0 + 6, x1 - 4, 11):
        L.p(x, bar - 1, "wt")
    for px in (x0 + 1, x1 - 4):
        L.rect(px, top + 4, px + 3, foot - 1, "gd2")
        L.vl(px, top + 4, foot - 1, "gd4")
        L.vl(px + 2, top + 4, foot - 1, "gd1")
        for y in range(top + 12, foot - 6, 14):   # 金柱上一道道箍
            L.hl(px - 1, px + 4, y, "gd3")
            L.p(px, y, "wt")
        L.ell(px - 2, top - 2, px + 5, top + 5, "gd3")
        L.p(px, top - 1, "wt")
        L.p(px + 1, top, "gd4")
    # 底座抽屉
    cabinet(L, x0 + 1, x1 - 1, foot - base_h - 2, foot - base_h, foot, ramp="rd", lv=2, doors=max(2, (x1 - x0) // 34))
    add(name, L, foot, [x0, foot - base_h, x1, foot])


def xiuhe(gold=False, white=False):
    def fn(L, cx, ty, ln):
        if white:
            mk.garment(L, mk.G("set", "wh", 3, ln, hw=7, jl=int(ln * 0.38), ramp2="wh", lv2=2, trim="rd3", panel="rd3", pat="flower", pc="rd4"), cx, ty)
        else:
            mk.garment_xiuhe(L, cx, ty, length=ln, gold=gold)
    return {"kind": "fn", "ln": 90, "fn": fn}


def qipao(ramp, lv, motif):
    return {"kind": "fn", "ln": 84, "fn": lambda L, cx, ty, ln: mk.garment_qipao(L, cx, ty, ramp, lv, length=ln, motif=motif)}


G = mk.G


def _motif(L, x, y, col, hi):
    """一朵小金绣（十字五格 + 中心亮）"""
    for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        L.p(x + dx, y + dy, col)
    L.p(x, y, hi)


def _fill(L, pts, base, ramp_l, ramp_r, cx, hw):
    """一块布：左边亮、右边暗（光从左上），中间本色"""
    for (x, y) in pts:
        u = (x - cx) / float(max(1, hw))
        L.p(x, y, ramp_l if u < -0.55 else (ramp_r if u > 0.5 else base))


def xiuhe2(white=False, seed=0):
    """喜服（秀禾 / 龙凤褂，女）：上褂（宽袖、对襟金边）+ 下面长裙；大块金绣：褂子两襟各一团、裙中间一竖排、下摆一圈金。
    白的那款是白底红绣"""
    def fn(L, cx, ty, ln):
        rnd = random.Random(seed * 13 + cx)
        mk.hanger(L, cx, ty)
        base, lit, dark = ("wt", "wt", "sv1") if white else ("rd3", "rd4", "rd2")
        gold, gold_hi = ("rd3", "rd4") if white else ("gd3", "gd4")
        jl = int(ln * 0.42)
        hw = 9
        # 下裙（先画，褂子压在上面）
        sk = mk.poly_px([(cx - 7, ty + jl - 4), (cx + 7, ty + jl - 4), (cx + hw, ty + ln), (cx - hw, ty + ln)])
        _fill(L, sk, base, lit, dark, cx, hw)
        # 裙：中间一竖条满金绣（棋盘点 + 一朵朵）、两边各一竖金边、下摆一道宽金边，两角一团金
        for y in range(ty + jl, ty + ln - 3):
            for x in range(cx - 3, cx + 4):
                if (x + y) % 2 == 0:
                    L.p(x, y, gold)
            if (y - ty) % 7 == 0:
                _motif(L, cx, y, gold, gold_hi)
        L.vl(cx - 4, ty + jl, ty + ln - 3, gold_hi if not white else gold)
        L.vl(cx + 4, ty + jl, ty + ln - 3, gold)
        L.rect(cx - hw, ty + ln - 4, cx + hw + 1, ty + ln, gold)
        L.hl(cx - hw, cx + hw + 1, ty + ln - 4, gold_hi)
        for d in (-1, 1):
            _motif(L, cx + d * (hw - 3), ty + ln - 8, gold, gold_hi)
        # 上褂：宽袖
        jk = mk.poly_px([(cx - 4, ty), (cx + 4, ty), (cx + hw + 4, ty + 4), (cx + hw + 5, ty + jl - 6), (cx + hw, ty + jl - 6),
                         (cx + hw - 1, ty + jl), (cx - hw + 1, ty + jl), (cx - hw, ty + jl - 6), (cx - hw - 5, ty + jl - 6), (cx - hw - 4, ty + 4)])
        _fill(L, jk, base, lit, dark, cx, hw + 4)
        # 金边：对襟、下摆、袖口
        L.vl(cx, ty + 2, ty + jl, gold)
        L.line(cx - 3, ty, cx, ty + 6, gold)
        L.line(cx + 3, ty, cx, ty + 6, gold)
        L.hl(cx - hw + 1, cx + hw, ty + jl - 1, gold)
        for d in (-1, 1):
            L.rect(cx + d * (hw + 4) - (1 if d > 0 else 0), ty + 6, cx + d * (hw + 4) + (1 if d < 0 else 0) + 1, ty + jl - 6, gold)
            # 两襟各一大块金绣（棋盘金点铺满，中间一朵亮的）
            for y in range(ty + 7, ty + jl - 2):
                for x in range(cx + d * 2, cx + d * 7, d):
                    if (x + y) % 2 == 0:
                        L.p(x, y, gold)
            mx, my = cx + d * 5, ty + jl // 2
            _motif(L, mx, my, gold_hi, "wt" if not white else gold_hi)
    return {"kind": "fn", "ln": 90, "fn": fn}


def ball_gown2(ramp="wh", lv=2, hw=12, sleeve=False, sash=None, lace=True):
    """婚纱、纱裙：蕾丝贴身上衣（心形领、细带）、收腰、裙摆撑开；裙上竖褶（暗一档）、下面 40% 一层蕾丝（暗点）、下摆一圈花边"""
    def fn(L, cx, ty, ln):
        mk.hanger(L, cx, ty)
        lo, mid, hi = mk.rn(ramp, lv - 1), mk.rn(ramp, lv), mk.rn(ramp, lv + 1)
        bl = int(ln * 0.28)
        wy = ty + bl
        pts = [(cx - 4, wy)]
        for k in range(1, 11):
            t = k / 10.0
            pts.append((cx - 4 - (hw - 4) * (1 - (1 - t) ** 2.4), wy + (ln - bl) * t))
        pts += [(2 * cx - x_, y_) for (x_, y_) in reversed(pts)]
        S = mk.poly_px(pts)
        rows = mk.rows_of(S)
        for (x, y) in S:
            a, b = rows[y]
            w = max(1, b - a)
            u = (x - a) / float(w)
            c = hi if u < 0.3 else (lo if u > 0.78 else mid)
            # 竖褶：裙下面三分之二，几道竖的暗线（跟着裙摆往外散一点）
            sx = cx + (x - cx) * 8.0 / max(8.0, (y - wy) * 0.5 + 8)
            if y > wy + (ln - bl) * 0.3 and int(round(sx)) % 4 == 0:
                c = lo
            # 蕾丝：下摆一圈宽带，暗点花纹
            if lace and y > ty + ln - (ln - bl) * 0.28 and ((x + y) % 3 == 0 or (x - y) % 5 == 0):
                c = lo if c != lo else mid
            L.p(x, y, c)
        for x in range(int(cx - hw), int(cx + hw) + 1):   # 下摆花边：一排小扇贝
            if x % 3 == 1:
                L.p(x, ty + ln, mid)
        # 上衣
        bod = mk.poly_px([(cx - 4, ty + 3), (cx - 1, ty + 5), (cx, ty + 4), (cx + 1, ty + 5), (cx + 4, ty + 3), (cx + 4, wy), (cx - 4, wy)])
        for (x, y) in bod:
            L.p(x, y, hi if x < cx - 1 else (lo if x > cx + 2 else mid))
            if (x + y) % 3 == 0 and lace:
                L.p(x, y, lo)
        for d in (-1, 1):
            L.vl(cx + d * 3, ty, ty + 3, lo)
            if sleeve:
                L.rect(cx + d * 4 - (1 if d < 0 else 0), ty + 3, cx + d * 4 + (2 if d > 0 else 1), ty + 7, hi)
        L.hl(cx - 4, cx + 5, wy, sash or lo)
        if sash:
            L.p(cx + 2, wy + 1, sash)
            L.p(cx + 3, wy + 2, sash)
    return {"kind": "fn", "ln": 96, "fn": fn}


def dragon_robe(ramp, lv, seed=0, gold_ramp=("gd3", "gd4"), white=False):
    """男式龙凤褂 / 唐装：立领长袍、宽袖；身上一条金龙（S 形一道粗金线、龙头一团、几朵祥云）"""
    def fn(L, cx, ty, ln):
        mk.hanger(L, cx, ty)
        hw = 9
        lo, mid, hi = mk.rn(ramp, lv - 1), mk.rn(ramp, lv), mk.rn(ramp, lv + 1)
        S = mk.poly_px([(cx - 4, ty), (cx + 4, ty), (cx + hw + 4, ty + 4), (cx + hw + 5, ty + 28), (cx + hw, ty + 28),
                        (cx + hw, ty + ln), (cx - hw, ty + ln), (cx - hw, ty + 28), (cx - hw - 5, ty + 28), (cx - hw - 4, ty + 4)])
        _fill(L, S, mid, hi, lo, cx, hw + 4)
        g, gh = gold_ramp
        L.rect(cx - 2, ty, cx + 3, ty + 3, g)            # 立领
        L.vl(cx + 1, ty + 3, ty + ln, lo)
        L.hl(cx - hw, cx + hw + 1, ty + ln - 2, g)
        for d in (-1, 1):
            L.vl(cx + d * (hw + 4), ty + 6, ty + 28, g)   # 袖口
        # 金龙：S 形
        pts = []
        for k in range(28):
            t = k / 27.0
            pts.append((cx + math.sin(t * 5.2 + seed) * (hw - 3), ty + 12 + t * (ln - 22)))
        for (x, y) in pts:
            L.rect(int(x), int(y), int(x) + 2, int(y) + 2, g)
            L.p(int(x), int(y), gh)
        hx, hy = pts[0]
        L.ell(int(hx) - 3, int(hy) - 3, int(hx) + 4, int(hy) + 3, g)
        L.p(int(hx), int(hy) - 1, gh)
        L.p(int(hx) + 2, int(hy) - 1, "rd4")
        rnd = random.Random(seed)
        for _ in range(3):
            _motif(L, cx + rnd.randint(-hw + 2, hw - 2), ty + rnd.randint(12, ln - 6), g, gh)
    return {"kind": "fn", "ln": 90, "fn": fn}


def qipao2(ramp, lv, motif, seed=0):
    """旗袍：照后厅那款画，再点一身小花（几格）"""
    def fn(L, cx, ty, ln):
        mk.garment_qipao(L, cx, ty, ramp, lv, length=ln, motif=motif)
        rnd = random.Random(seed + cx)
        for _ in range(7):
            x, y = cx + rnd.randint(-5, 5), ty + rnd.randint(10, ln - 6)
            if L.g(x, y)[3] and L.g(x, y) != C["ol"]:
                _motif(L, x, y, motif, "wt")
    return {"kind": "fn", "ln": 84, "fn": fn}


def ball_gown(ramp, lv, hw=12, lace=True, sleeve=False, sash=None):
    """蓬蓬裙（婚纱、纱裙）：贴身上衣（心形领口、两根细带）、收腰、裙摆一下撑开到 hw，竖褶、下摆一圈蕾丝花边"""
    def fn(L, cx, ty, ln):
        mk.hanger(L, cx, ty)
        bl = int(ln * 0.3)                       # 上衣多长
        wy = ty + bl
        # 裙
        pts = [(cx - 4, wy)]
        for k in range(1, 11):
            t = k / 10.0
            pts.append((cx - 4 - (hw - 4) * (1 - (1 - t) ** 2.2), wy + (ln - bl) * t))
        pts += [(cx + x_ - cx if False else 2 * cx - x_, y_) for (x_, y_) in reversed(pts)]
        S = mk.poly_px(pts)
        mk.cloth(L, S, ramp, lv, folds=4, top=wy + 2, seed=cx)
        rows = mk.rows_of(S)
        for (x, y) in S:
            a, b = rows[y]
            if lace and y > wy + (ln - bl) * 0.55 and (x * 3 + y * 5) % 11 == 0:
                L.p(x, y, mk.rn(ramp, lv + 1))
            if y >= ty + ln - 2 and (x % 3 == 0):
                L.p(x, y + 1, mk.rn(ramp, lv + 1))     # 下摆一圈花边
        # 上衣
        bod = mk.poly_px([(cx - 4, ty + 3), (cx - 1, ty + 5), (cx, ty + 4), (cx + 1, ty + 5), (cx + 4, ty + 3), (cx + 4, wy), (cx - 4, wy)])
        mk.cloth(L, bod, ramp, lv, folds=0)
        for d in (-1, 1):
            L.vl(cx + d * 3, ty, ty + 3, mk.rn(ramp, lv - 1))
            if sleeve:
                L.rect(cx + d * 4 - (1 if d < 0 else 0), ty + 3, cx + d * 4 + (2 if d > 0 else 1), ty + 7, mk.rn(ramp, lv + 1))
        L.hl(cx - 4, cx + 5, wy, sash or mk.rn(ramp, lv - 1))
        if sash:
            L.p(cx + 2, wy + 1, sash)
            L.p(cx + 3, wy + 2, sash)
    return {"kind": "fn", "ln": 96, "fn": fn}


# ================================================================== 中间、两边的小件
def cab_vase(name, x0, x1, top, foot, seed, flowers=True):
    """小柜（红木两层抽屉）上一个青花瓶插一捧玫瑰"""
    L = L0()
    ctop = foot - max(18, (foot - top) // 2)
    cabinet(L, x0, x1, ctop, ctop + 3, foot, ramp="rd", lv=1, doors=1, drawers=2)
    cx = (x0 + x1) // 2
    hw = max(4, (x1 - x0) // 5)
    porcelain(L, cx, ctop - 12, ctop, hw)
    if flowers:
        bouquet(L, cx, ctop - 19, max(10, (x1 - x0) // 2 + 2), 11, seed)
    add(name, L, foot, [x0, foot - 8, x1, foot])


def stand_mirror(name, x0, x1, top, foot):
    """落地镜：金框（上沿圆拱、雕花）、蓝镜面两道斜反光、一对金脚"""
    L = L0()
    cx = (x0 + x1) // 2
    hw = (x1 - x0) // 2 - 2
    bot = foot - 6
    L.ell(cx - hw, top, cx + hw + 1, top + 2 * hw, "gd2")
    L.rect(cx - hw, top + hw, cx + hw + 1, bot, "gd2")
    L.ell(cx - hw + 3, top + 3, cx + hw - 2, top + 2 * hw - 2, "bl3")
    L.rect(cx - hw + 3, top + hw, cx + hw - 2, bot - 3, "bl3")
    for (o, w) in ((4, 2), (8, 1)):
        for y in range(top + 6, bot - 4):
            xx = cx - hw + o + (bot - y) // 3 - 8
            for k in range(w):
                if cx - hw + 3 <= xx + k < cx + hw - 2:
                    L.p(xx + k, y, "bl4")
    L.vl(cx - hw, top + hw, bot, "gd4")
    L.vl(cx + hw, top + hw, bot, "gd1")
    L.rect(cx - 3, top - 3, cx + 4, top + 1, "gd3")
    for lx in (cx - hw, cx + hw - 3):
        L.rect(lx, bot, lx + 4, foot, "gd1")
    add(name, L, foot, [x0, foot - 5, x1, foot])


def flower_pot(name, cx, foot, r, seed):
    L = L0()
    bouquet(L, cx, foot - r - 2, r, r - 1, seed)
    add(name, L, foot, [cx - r, foot - 3, cx + r, foot])


def shoe_cabinet(name, x0, x1, top, foot, seed, men=False):
    """鞋柜：三层（皮鞋 / 高跟鞋），顶上一个包"""
    L = L0()
    ctop = top + 12
    L.rect(x0, ctop, x1, foot - 2, "rd1")
    L.rect(x0 + 2, ctop + 2, x1 - 2, foot - 10, "wd0")
    rnd = random.Random(seed)
    for k, y in enumerate((ctop + 12, ctop + 25, ctop + 38)):
        if y > foot - 12:
            break
        L.rect(x0 + 2, y, x1 - 2, y + 2, "rd2")
        L.hl(x0 + 2, x1 - 2, y, "gd2")
        for x in range(x0 + 4, x1 - 6, 8):
            col = rnd.choice(["ik1", "wd2", "wd3"] if men else ["wt", "rd4", "pk", "ik1"])
            L.rect(x, y - 4, x + 3, y, col)
            L.rect(x + 3, y - 3, x + 6, y, col)
            L.p(x, y - 4, shift(col, 1))
    cabinet(L, x0, x1, foot - 10, foot - 9, foot, ramp="rd", lv=2, doors=1)
    cx = (x0 + x1) // 2
    col = "pk" if not men else "rd3"
    L.rect(cx - 5, ctop - 9, cx + 5, ctop, col)
    L.hl(cx - 5, cx + 5, ctop - 9, shift(col, 1))
    L.ring(cx - 3, ctop - 14, cx + 4, ctop - 7, "gd2", only=lambda xx, yy, c=ctop: yy < c - 9)
    L.p(cx, ctop - 5, "gd3")
    add(name, L, foot, [x0, foot - 8, x1, foot])


def crown_big(L, cx, yb, w):
    """大头冠：一圈金、五个尖、中间红宝石，几格白亮点"""
    hw = w // 2
    pts = [(cx - hw, yb)]
    for k in range(5):
        x = cx - hw + (k + 0.5) * w / 5.0
        h = [6, 9, 12, 9, 6][k]
        pts += [(x - w / 10.0, yb - h * 0.45), (x, yb - h)]
    pts += [(cx + hw, yb - 3), (cx + hw, yb)]
    L.poly(pts, "gd3")
    L.rect(cx - hw, yb - 3, cx + hw + 1, yb, "gd2")
    L.hl(cx - hw, cx + hw + 1, yb - 3, "gd4")
    L.ell(cx - 2, yb - 9, cx + 3, yb - 4, "rd3")
    L.p(cx - 1, yb - 8, "rd5")
    for d in (-hw + 3, hw - 3):
        L.ell(cx + d - 1, yb - 6, cx + d + 2, yb - 3, "rd4")
    for (dx, dy) in ((-hw // 2, -6), (hw // 2, -6), (0, -12)):
        L.p(cx + dx, yb + dy, "wt")
    for x in range(cx - hw + 1, cx + hw, 3):
        L.p(x, yb - 2, "pk2")


def hairpin(L, cx, yb, col):
    """簪花：一朵圆花（红 / 白 / 粉）、金心，下面一根金簪、一串金穗"""
    ramp = {"rd": ("rd2", "rd3", "rd4"), "wt": ("sv1", "sv2", "wt"), "pk": ("pk0", "pk", "pk2")}[col]
    fy = yb - 13
    L.ell(cx - 4, fy - 4, cx + 5, fy + 5, ramp[0])
    L.ell(cx - 3, fy - 3, cx + 4, fy + 4, ramp[1])
    for (dx, dy) in ((-2, -2), (2, -2), (-2, 2), (2, 2)):
        L.p(cx + dx, fy + dy, ramp[2])
    L.p(cx - 1, fy - 2, "wt")
    L.ell(cx - 1, fy - 1, cx + 2, fy + 2, "gd4")
    L.vl(cx, fy + 3, yb, "gd2")
    L.vl(cx + 2, fy + 3, yb - 2, "gd3")
    L.p(cx + 2, yb - 2, "rd4")


def jewel_case(name, x0, x1, top, foot, contents):
    """玻璃首饰柜：金框、深红木里衬、三层玻璃格摆头冠首饰包鞋；底下一层抽屉"""
    L = L0()
    base = foot - 13
    L.rect(x0, top, x1, base, "gd2")
    L.rect(x0 + 3, top + 3, x1 - 3, base - 2, "rd1")
    L.rect(x0 + 3, top + 3, x1 - 3, top + 5, "rd0")
    glow = mk.ShadeMap()
    glow.ellipse((x0 + x1) // 2, (top + base) // 2, (x1 - x0) // 2 - 4, (base - top) // 2 - 2, 1.0, edge=3)
    glow.apply(L, clip=lambda x, y: x0 + 3 <= x < x1 - 3 and top + 3 <= y < base - 2)
    L.hl(x0, x1, top, "gd4")
    L.vl(x0, top, base, "gd4")
    L.vl(x1 - 1, top, base, "gd1")
    h = (base - 2 - top - 3) / 3.0
    for r in range(3):
        y1 = int(top + 3 + (r + 1) * h)
        if r < 2:
            L.rect(x0 + 3, y1 - 2, x1 - 3, y1, "gd1")
            L.hl(x0 + 3, x1 - 3, y1 - 2, "gd4")
            for x in range(x0 + 6, x1 - 4, 9):
                L.p(x, y1 - 2, "wt")
        items = contents[r]
        wts = [2.2 if it == "crown" else 1.0 for it in items]
        tot = sum(wts)
        acc = 0.0
        for k, it in enumerate(items):
            cx = int(x0 + 3 + (acc + wts[k] / 2.0) * (x1 - x0 - 6) / tot)
            acc += wts[k]
            yb = y1 - 3
            if it == "crown":
                crown_big(L, cx, yb, int(wts[k] * (x1 - x0 - 6) / tot) - 4)
                continue
            if it in ("pin", "pinw", "pinp"):
                for j, dx in enumerate((-4, 3)):
                    hairpin(L, cx + dx, yb - (j % 2) * 2, {"pin": "rd", "pinw": "wt", "pinp": "pk"}[it] if j == 0 else "rd")
                continue
            if it == "crown_old":
                L.poly([(cx - 9, yb), (cx - 8, yb - 8), (cx - 4, yb - 4), (cx, yb - 12), (cx + 4, yb - 4), (cx + 8, yb - 8), (cx + 9, yb)], "gd3")
                L.poly([(cx - 6, yb - 2), (cx, yb - 8), (cx + 6, yb - 2)], "gd4")
                L.hl(cx - 9, cx + 10, yb - 1, "gd1")
                L.hl(cx - 9, cx + 10, yb - 2, "gd2")
                L.ell(cx - 2, yb - 8, cx + 3, yb - 3, "rd4")
                for d in (-6, 6):
                    L.p(cx + d, yb - 5, "pk2")
                    L.p(cx + d, yb - 4, "rd4")
                L.p(cx, yb - 12, "wt")
            elif it == "pin":
                L.vl(cx, yb - 10, yb, "gd2")
                L.ell(cx - 3, yb - 15, cx + 4, yb - 8, "rd3")
                L.ell(cx - 2, yb - 14, cx + 3, yb - 9, "rd4")
                L.p(cx, yb - 12, "gd4")
                for d in (-3, 3):
                    L.vl(cx + d, yb - 8, yb - 2, "gd3")
                    L.p(cx + d, yb - 2, "pk2")
            elif it == "ear":
                L.rect(cx - 6, yb - 12, cx + 7, yb, "ik1")
                L.hl(cx - 6, cx + 7, yb - 12, "gd2")
                for d in (-3, 3):
                    L.vl(cx + d, yb - 10, yb - 4, "gd3")
                    L.ell(cx + d - 1, yb - 5, cx + d + 2, yb - 1, "rd4")
                    L.p(cx + d, yb - 4, "wt")
            elif it == "box":
                L.rect(cx - 5, yb - 6, cx + 6, yb, "rd3")
                L.hl(cx - 5, cx + 6, yb - 6, "rd4")
                L.rect(cx - 1, yb - 4, cx + 2, yb - 2, "gd3")
            elif it == "bag":
                L.rect(cx - 5, yb - 7, cx + 6, yb, "pk0")
                L.hl(cx - 5, cx + 6, yb - 7, "pk")
                L.ring(cx - 3, yb - 11, cx + 4, yb - 5, "gd2", only=lambda xx, yy, b=yb: yy < b - 7)
            elif it == "shoes":
                for d, col in ((-4, "rd4"), (1, "rd4")):
                    L.rect(cx + d, yb - 3, cx + d + 3, yb, col)
                    L.p(cx + d + 2, yb - 4, col)
            elif it == "wshoes":
                for d in (-4, 1):
                    L.rect(cx + d, yb - 3, cx + d + 3, yb, "wt")
                    L.p(cx + d + 2, yb - 4, "sv2")
        # 玻璃反光：每格左上一道斜亮
        for y in range(int(top + 4 + r * h), int(top + 4 + r * h) + 8):
            L.p(x0 + 5 + (y - int(top + 4 + r * h)), y, "wt")
            L.p(x0 + 6 + (y - int(top + 4 + r * h)), y, "bl4")
    cabinet(L, x0 + 2, x1 - 2, base, base + 1, foot, ramp="wd", lv=2, doors=2)
    add(name, L, foot, [x0, foot - R(22), x1, foot])


def gold_flower_stand(name, cx, top, foot, seed):
    L = L0()
    gold_vase(L, cx, top + 20, foot, 8)
    for y in range(top + 22, foot - 2, 4):    # 金瓶高光一道
        L.p(cx - 3, y, "wt")
    bouquet(L, cx, top + 11, 16, 13, seed)
    add(name, L, foot, [cx - 6, foot - 5, cx + 7, foot])


def fitting_room(name, x0, x1, top, foot, curtain, opening, hang, flip):
    """试衣间：一排折叠屏风（米白屏面、红边、金柱、上沿红檐），帘子在 curtain 那段系起来，opening 那段开口挂一件衣服。
    人进不去（占地画到屏风后面的衣架），所以整张一层"""
    L = L0()
    panels = []
    x = x0
    w = (x1 - x0) / 5.0
    for k in range(5):
        panels.append((int(x0 + k * w), int(x0 + (k + 1) * w)))
    for k, (a, b) in enumerate(panels):
        zig = 4 if k % 2 else 0
        t = top + 6 + zig
        if opening[0] <= (a + b) // 2 <= opening[1]:
            # 开口：里面暗红，挂一件衣服
            L.rect(a, t, b, foot - 2, "rd1")
            L.rect(a + 1, t + 2, b - 1, foot - 2, "wd0")
            s = mk.sub((a + b) // 2 - 18, t, (a + b) // 2 + 19, foot)
            hang(s, (a + b) // 2, t + 6)
            mk.paste_ol(L, s)
            continue
        L.rect(a, t, b, foot - 3, "rd3")                    # 红框
        L.rect(a + 3, t + 7, b - 3, foot - 7, "gd2")         # 金线
        L.rect(a + 4, t + 8, b - 4, foot - 8, "wl5")         # 米白屏面
        for xx in range(a + 6, b - 5, 3):
            L.vl(xx, t + 10, foot - 10, "wl4")
        for yy in range(t + 14, foot - 12, 12):                # 屏面上一朵朵暗花
            L.p((a + b) // 2, yy, "wl3")
            L.p((a + b) // 2 - 1, yy + 1, "wl3")
            L.p((a + b) // 2 + 1, yy + 1, "wl3")
        L.hl(a, b, t, "rd4")
        L.vl(a, t, foot - 3, "rd4")
        L.vl(b - 1, t, foot - 3, "rd2")
        L.hl(a, b, foot - 4, "rd2")
    # 帘子（米白，系起来、红穗）
    ca, cb = curtain
    for x in range(ca, cb):
        u = (x - ca) / float(max(1, cb - ca))
        pinch = 0.5 + 0.5 * math.cos((u - 0.5) * 3.1)
        for y in range(top + 10, foot - 2):
            t = (y - top - 10) / float(foot - top - 12)
            half = (cb - ca) / 2.0 * (1.0 - 0.6 * math.exp(-((t - 0.55) ** 2) / 0.02))
            if abs(x + 0.5 - (ca + cb) / 2.0) <= half:
                L.p(x, y, "wl5" if (x - ca) % 4 else "wl3")
    tie_y = top + int((foot - top) * 0.55)
    L.rect((ca + cb) // 2 - 2, tie_y - 1, (ca + cb) // 2 + 3, tie_y + 2, "rd3")
    L.vl((ca + cb) // 2, tie_y + 2, tie_y + 10, "rd4")
    L.p((ca + cb) // 2, tie_y + 10, "gd3")
    # 金柱
    for (a, b) in panels + [(x1, x1)]:
        L.rect(a - 1, top + 2, a + 2, foot, "gd2")
        L.vl(a - 1, top + 2, foot, "gd4")
        L.ell(a - 2, top - 1, a + 3, top + 4, "gd3")
    add(name, L, foot, [x0, foot - R(110), x1, foot])


def sofa(name, x0, x1, top, foot, cream, seeds):
    """沙发：金色雕花框、靠背一格格拉扣、三个靠垫（团花、喜、团花——图上不写字，喜字画成金色团花）、扶手卷边、金脚"""
    L = L0()
    body = "wl" if cream else "rd"
    lv = 4 if cream else 3
    bt = top + 8
    seat_y = top + (foot - top) * 0.62
    L.ell(x0 + 4, top, x1 - 4, bt + 18, "gd2")
    L.ell(x0 + 6, top + 3, x1 - 6, bt + 18, rname(body, lv))
    L.rect(x0 + 6, bt + 6, x1 - 6, int(seat_y), rname(body, lv))
    for x in range(x0 + 14, x1 - 12, 14):
        for y in range(bt + 4, int(seat_y) - 4, 8):
            L.p(x, y, rname(body, lv - 1))
            L.p(x + 1, y + 1, rname(body, lv + 1))
    # 坐垫
    L.rect(x0 + 8, int(seat_y), x1 - 8, foot - 7, rname(body, lv))
    L.hl(x0 + 8, x1 - 8, int(seat_y), rname(body, lv + 1))
    L.rect(x0 + 8, foot - 9, x1 - 8, foot - 5, rname(body, lv - 1))
    L.hl(x0 + 6, x1 - 6, foot - 5, "gd2")
    # 扶手
    for (a, b, d) in ((x0, x0 + 12, -1), (x1 - 12, x1, 1)):
        L.rect(a, bt + 10, b, foot - 6, rname(body, lv - (1 if d > 0 else 0)))
        L.ell(a - 1, bt + 6, b + 1, bt + 16, rname(body, lv + 1))
        L.ring(a - 1, bt + 6, b + 1, bt + 16, "gd2")
        L.vl(a if d < 0 else b - 1, bt + 10, foot - 6, "gd2")
    # 靠垫
    cw = (x1 - x0 - 30) // 3
    for k in range(3):
        a = x0 + 15 + k * cw
        mid = k == 1
        col = ("wl5" if mid else "rd3") if True else "rd3"
        L.rect(a + 1, int(seat_y) - 15, a + cw - 1, int(seat_y) + 1, col)
        L.hl(a + 1, a + cw - 1, int(seat_y) - 15, shift(col, 1))
        L.vl(a + cw - 2, int(seat_y) - 15, int(seat_y) + 1, shift(col, -1))
        cx, cy = a + cw // 2, int(seat_y) - 7
        mot = "rd3" if mid else "gd3"
        for (dx, dy) in ((0, -3), (-3, 0), (3, 0), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)):
            L.p(cx + dx, cy + dy, mot)
        L.p(cx, cy, "gd4" if not mid else "rd4")
    # 顶上金冠饰
    L.poly([((x0 + x1) // 2 - 7, top + 2), ((x0 + x1) // 2, top - 4), ((x0 + x1) // 2 + 7, top + 2)], "gd3")
    for lx in (x0 + 3, x1 - 6):
        L.rect(lx, foot - 5, lx + 3, foot, "gd1")
    n = 3
    seats = [(int(x0 + (x1 - x0) * (k + 1) / (n + 1.0)), foot + 2) for k in range(n)]
    add(name, L, foot, [x0, foot - R(40), x1, foot], seats=seats)


def coffee_table(name, x0, x1, top, foot, white, seed):
    L = L0()
    cx = (x0 + x1) // 2
    tt = top + 10
    rx = (x1 - x0) // 2
    L.ell(x0, tt, x1, tt + 14, "gd2")
    L.ell(x0 + 2, tt + 1, x1 - 2, tt + 12, "wl5" if white else "gd3")
    L.rect(x0 + 4, tt + 10, x1 - 4, tt + 16, "gd1")
    for lx in (x0 + 5, x1 - 7, cx - 1):
        L.rect(lx, tt + 14, lx + 2, foot, "gd2")
    bouquet(L, cx, tt + 2, 8, 6, seed)
    L.ell(cx - rx + 6, tt + 6, cx - rx + 13, tt + 10, "rd3")
    L.ell(cx + rx - 13, tt + 6, cx + rx - 6, tt + 10, "wt")
    add(name, L, foot, [x0, foot - 10, x1, foot])


def pouf(name, cx, top, foot):
    L = L0()
    rx = (foot - top) // 2 + 2
    L.ell(cx - rx, top, cx + rx + 1, top + 10, "rd3")
    L.ell(cx - rx + 2, top + 1, cx + rx - 1, top + 8, "rd4")
    L.rect(cx - rx, top + 5, cx + rx + 1, foot - 4, "rd2")
    L.ell(cx - rx, foot - 9, cx + rx + 1, foot, "rd2")
    L.hl(cx - rx, cx + rx + 1, top + 6, "gd3")
    L.hl(cx - rx, cx + rx + 1, foot - 5, "gd2")
    add(name, L, foot, [cx - rx, foot - 8, cx + rx + 1, foot], seats=[(cx, foot + 1)])


def armchair(name, x0, x1, top, foot):
    L = L0()
    L.ell(x0 + 4, top, x1 - 2, top + 32, "gd2")
    L.ell(x0 + 6, top + 2, x1 - 4, top + 32, "rd3")
    L.rect(x0 + 6, top + 18, x1 - 4, foot - 8, "rd3")
    L.rect(x0 + 8, top + 30, x1 - 6, foot - 9, "rd4")
    L.hl(x0 + 8, x1 - 6, top + 30, "rd5")
    for (a, b) in ((x0, x0 + 9), (x1 - 9, x1)):
        L.rect(a, top + 20, b, foot - 6, "rd2")
        L.ell(a - 1, top + 16, b + 1, top + 24, "rd3")
        L.ring(a - 1, top + 16, b + 1, top + 24, "gd2")
    L.hl(x0 + 2, x1 - 2, foot - 6, "gd2")
    for lx in (x0 + 2, x1 - 5):
        L.rect(lx, foot - 6, lx + 3, foot, "gd1")
    add(name, L, foot, [x0, foot - 14, x1, foot], seats=[((x0 + x1) // 2, foot + 2)])


def floor_lamp(name, cx, top, foot):
    L = L0()
    palace_lamp(L, cx, top, 20)
    L.rect(cx - 1, top + 24, cx + 2, foot - 4, "gd2")
    L.vl(cx - 1, top + 24, foot - 4, "gd4")
    L.ell(cx - 6, foot - 5, cx + 7, foot, "gd1")
    L.hl(cx - 5, cx + 6, foot - 5, "gd3")
    add(name, L, foot, [cx - 6, foot - 4, cx + 7, foot])


def chest(name, x0, x1, top, foot):
    L = L0()
    L.rect(x0, top, x1, foot, "rd3")
    L.rect(x0, top, x1, top + 4, "rd4")
    L.hl(x0, x1, top + 4, "gd2")
    cx = (x0 + x1) // 2
    L.rect(cx - 2, top + 6, cx + 3, top + 11, "gd3")
    for (dx, dy) in ((0, -3), (-3, 0), (3, 0), (0, 3)):
        L.p(cx + dx, top + 2 + dy if dy < 0 else top + 2, "gd3")
    add(name, L, foot, [x0, foot - 8, x1, foot])


def door_flower(name, x0, x1, top, foot, seed):
    L = L0()
    cx = (x0 + x1) // 2
    cabinet(L, x0 + 2, x1 - 2, foot - 16, foot - 14, foot, ramp="ik", lv=1, doors=1)
    gold_vase(L, cx, foot - 26, foot - 16, 6)
    bouquet(L, cx, foot - 35, (x1 - x0) // 2 + 3, 12, seed)
    add(name, L, foot, [x0 + 2, foot - 8, x1 - 2, foot])


# ================================================================== 摆
def build_all():
    frame()
    # 北墙一排
    corner_cabinet("corner_w", R(30), R(130), R(30), R(250), 1)
    corner_cabinet("corner_e", R(810), R(912), R(45), R(250), 2)
    for i, (a, b) in enumerate(((145, 297), (317, 462), (480, 622), (642, 795))):
        dresser("dresser_%d" % (i + 1), R(a), R(b), R(160), R(200), R(245), i)
    for k, cx in enumerate((307, 471, 632)):
        vase_stand("vase_stand_%d" % (k + 1), R(cx), R(115), R(245))
    for i, cx in enumerate((222, 388, 551, 716)):
        stool("stool_%d" % (i + 1), R(cx), R(212), R(272))
    # 西边四排
    red = [xiuhe2(seed=k, white=(k in (5,))) for k in range(7)]
    rack("rack_w1", R(30), R(275), R(268), R(470), red, 10)
    rack("rack_w2", R(30), R(250), R(480), R(650),
         [qipao2("pk", 1, "pk2", 1), qipao2("pk", 2, "rd4", 2), qipao2("mt", 2, "pk", 3), qipao2("pk", 2, "pk0", 4), qipao2("bl", 1, "gd3", 5), qipao2("lv", 2, "lv0", 6)], 20)
    rack("rack_w3", R(30), R(250), R(655), R(835),  # 中式彩褂
         [G("set", "rd", 3, 84, hw=7, jl=30, ramp2="rd", lv2=2, trim="gd3", panel="gd3"),
          G("robe", "bl", 1, 86, hw=7, sl=24, trim="gd3", collar="gd3", pat="flower", pc="gd3", pc2="gd4"),
          G("set", "rd", 3, 84, hw=7, jl=28, ramp2="ik", lv2=1, trim="gd3", pat="flower", pc="gd3"),
          G("set", "wh", 3, 84, hw=7, jl=30, ramp2="wh", lv2=2, trim="rd3", pat="flower", pc="rd4", pc2="bl3"),
          G("robe", "bl", 2, 86, hw=7, sl=24, trim="wt", collar="wt", pat="flower", pc="gd3"),
          G("set", "wh", 3, 84, hw=7, jl=28, ramp2="wh", lv2=2, trim="rd3", panel="rd3", pat="flower", pc="pk"),
          G("set", "rd", 3, 84, hw=7, jl=30, ramp2="rd", lv2=3, trim="gd3", pat="dots", pc="gd3")], 30)
    rack("rack_w4", R(30), R(232), R(845), R(1025),
         [ball_gown2("pk", 1, 10, sleeve=True, sash="pk0"), ball_gown2("wl", 4, 10, sleeve=True, sash="pk"), ball_gown2("wh", 1, 10, sash="pk"),
          ball_gown2("bl", 3, 10, sleeve=True, sash="bl2"), ball_gown2("mt", 2, 10, sleeve=True, sash="mt0"),
          ball_gown2("lv", 2, 10, sleeve=True, sash="lv0"), ball_gown2("pk", 1, 9, sash="pk0")], 40, shoes=True)
    # 东边四排
    rack("rack_e1", R(660), R(885), R(268), R(470),
         [ball_gown2("wh", 1, 13), ball_gown2("wh", 2, 16), ball_gown2("wh", 1, 12, sleeve=True), ball_gown2("wh", 2, 16),
          ball_gown2("wl", 4, 14), ball_gown2("wh", 1, 12, sleeve=True)], 50)
    rack("rack_e2", R(690), R(885), R(480), R(650),
         [G("suit", "ik", 1, 40, hw=8, pants=38, trim="ik0"), G("suit", "ik", 1, 40, hw=8, pants=38, trim="ik0"),
          G("suit", "bl", 1, 40, hw=8, pants=38, trim="ik0"), G("suit", "bl", 1, 40, hw=8, pants=38, trim="ik0"),
          G("suit", "wl", 2, 40, hw=8, pants=38, trim="ik0"), G("suit", "ik", 1, 40, hw=8, pants=38, trim="ik0"),
          G("suit", "wl", 4, 40, hw=8, pants=38, trim="ik0"), G("suit", "bl", 1, 40, hw=8, pants=38, trim="ik0")], 60)
    rack("rack_e3", R(690), R(865), R(655), R(840),
         [dragon_robe("ik", 1, 1), dragon_robe("rd", 3, 2), dragon_robe("rd", 3, 3), dragon_robe("bl", 1, 4),
          dragon_robe("wh", 2, 5, ("rd3", "rd4")), dragon_robe("rd", 1, 6), dragon_robe("wh", 2, 7)], 70)
    rack("rack_e4", R(710), R(885), R(845), R(1030),
         [G("suit", "sv", 1, 40, hw=8, pants=36, trim="rd3"), G("suit", "bl", 1, 40, hw=8, pants=36, trim="rd3"),
          G("suit", "wd", 3, 40, hw=8, pants=36, trim="ik0"), G("suit", "gr", 1, 40, hw=8, pants=36, trim="ik0"),
          G("suit", "wl", 3, 40, hw=8, pants=36, trim="ik0")], 80, shoes=True)
    # 两边的小件
    cab_vase("cab_w1", R(280), R(322), R(290), R(462), 101)
    stand_mirror("mirror_w", R(262), R(330), R(500), R(676))
    flower_pot("mirror_w_flowers", R(296), R(692), 10, 102)
    shoe_cabinet("shoes_w", R(256), R(318), R(700), R(842), 103)
    cab_vase("cab_w4", R(232), R(312), R(875), R(1012), 104)
    cab_vase("cab_e1", R(615), R(662), R(285), R(467), 105)
    stand_mirror("mirror_e", R(625), R(690), R(495), R(668))
    flower_pot("mirror_e_flowers", R(657), R(683), 10, 106)
    shoe_cabinet("shoes_e", R(622), R(692), R(688), R(842), 107, men=True)
    cab_vase("cab_e4", R(642), R(712), R(855), R(1012), 108)
    # 正中三个首饰柜、两边金瓶
    jewel_case("jewel_1", R(400), R(540), R(418), R(590), [["pinw", "crown", "pin"], ["crown", "pin", "pinw"], ["pin", "ear", "pinp"]])
    jewel_case("jewel_2", R(400), R(540), R(710), R(900), [["pin", "crown", "pinw"], ["crown", "pinp", "pin"], ["ear", "box", "pin"]])
    jewel_case("jewel_3", R(400), R(540), R(1020), R(1200), [["pinw", "crown", "pin"], ["bag", "bag", "box"], ["shoes", "wshoes", "shoes"]])
    for k, (yt, yf) in enumerate(((455, 555), (745, 850), (1060, 1160))):
        gold_flower_stand("gold_vase_w%d" % (k + 1), R(376), R(yt), R(yf), 200 + k)
        gold_flower_stand("gold_vase_e%d" % (k + 1), R(564), R(yt), R(yf), 210 + k)
    # 试衣间
    def white_dress(s, cx, ty):
        mk.garment(s, G("gown", "wh", 2, 58, hw=9, trim="wt", pat="dots", pc="wt"), cx, ty)

    def white_suit(s, cx, ty):
        mk.garment(s, G("suit", "wl", 4, 30, hw=7, pants=28, trim="ik0"), cx, ty)
    fitting_room("fit_w", R(35), R(270), R(1030), R(1215), (R(160), R(215)), (R(215), R(268)), white_dress, False)
    fitting_room("fit_e", R(670), R(890), R(1030), R(1215), (R(745), R(800)), (R(672), R(745)), white_suit, True)
    stool("fit_stool_w", R(112), R(1175), R(1228))
    stool("fit_stool_e", R(830), R(1182), R(1238))
    cab_vase("cab_fit_w", R(28), R(78), R(1105), R(1218), 301)
    cab_vase("cab_fit_e", R(862), R(912), R(1115), R(1228), 302)
    # 沙发区
    floor_lamp("lamp_w", R(43), R(1232), R(1342))
    floor_lamp("lamp_e", R(900), R(1228), R(1338))
    sofa("sofa_red", R(60), R(268), R(1262), R(1388), False, 1)
    sofa("sofa_cream", R(668), R(888), R(1268), R(1388), True, 2)
    cab_vase("cab_sofa_w", R(268), R(322), R(1255), R(1392), 401)
    cab_vase("cab_sofa_e", R(618), R(672), R(1255), R(1392), 402)
    coffee_table("table_w", R(105), R(218), R(1362), R(1448), False, 501)
    coffee_table("table_e", R(708), R(802), R(1392), R(1462), True, 502)
    pouf("pouf_w", R(78), R(1392), R(1458))
    armchair("armchair_e", R(822), R(912), R(1362), R(1468))
    chest("chest_w", R(253), R(317), R(1468), R(1497))
    chest("chest_e", R(622), R(687), R(1468), R(1497))
    door_flower("door_flower_w", R(343), R(397), R(1402), R(1482), 601)
    door_flower("door_flower_e", R(543), R(597), R(1402), R(1482), 602)


def write_package(out, bg):
    os.makedirs(out, exist_ok=True)
    bg.im.save(os.path.join(out, "base.png"))
    items = []
    for p in PIECES:
        f = "blk_%s.png" % p["id"]
        p["img"].save(os.path.join(out, f))
        it = {"id": p["id"], "file": f, "x": p["x"], "y": p["y"], "w": p["img"].width, "h": p["img"].height,
              "foot_y": p["foot"], "footprint": p["footprint"]}
        if p["seats"]:
            it["seats"] = p["seats"]
        items.append(it)
    d = {"说明": "tools/pixel_art/room_makeup_ref.py 照 GPT 效果图代码画的化妆间（02 F）", "image": {"w": CW, "h": CH}, "base": "base.png",
         "doors": [{"id": "south", "rect": [R(395), R(1500), R(545) - R(395), R(50)]}],
         "spots": {"dress": [R(240), R(1238)]}, "blocked": [], "items": items}
    json.dump(d, open(os.path.join(out, "placement.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def compose(bg):
    out = bg.im.copy()
    for p in sorted(PIECES, key=lambda p: p["foot"]):
        out.alpha_composite(p["img"], (p["x"], p["y"]))
    return out


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    bg = background()
    build_all()
    room = compose(bg)
    cols = mk.palette_count(room)
    print("整间 %s，%d 件，颜色 %d 种" % (room.size, len(PIECES), len(cols)))
    if len(cols) > 64:
        print("  颜色超过 64 种（%d），第一稿先不拦" % len(cols))
    pkg = tempfile.mkdtemp(prefix="makeup_ref_")
    write_package(pkg, bg)
    subprocess.run([sys.executable, os.path.join(GODOT, "tools", "import_makeup_blocks.py"), pkg, "--canvas=%dx%d" % (CW, CH),
                    "--name=makeup_room"], check=True)
    if preview:
        os.makedirs(preview, exist_ok=True)
        room.save(os.path.join(preview, "化妆间-一比一.png"))
        raw = subprocess.run(["git", "show", REF_GIT], capture_output=True, check=True).stdout
        from io import BytesIO
        ref = Image.open(BytesIO(raw)).convert("RGBA").resize((CW, CH), Image.LANCZOS)
        both = Image.new("RGBA", (CW * 2 + 16, CH), (43, 30, 24, 255))
        both.alpha_composite(ref, (0, 0))
        both.alpha_composite(room, (CW + 16, 0))
        both.save(os.path.join(preview, "并排-效果图左-代码画右.png"))
        print("预览 → %s" % preview)


if __name__ == "__main__":
    main()
