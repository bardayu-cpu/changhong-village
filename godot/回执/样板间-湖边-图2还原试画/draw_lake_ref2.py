#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""罗曼山庄湖边 · 东头（阿鱼 10/3 效果图 2：月亮门 + 曲桥 + 湖心亭）用代码还原的试画。

照效果图的构图和样子画，改成游戏视角：斜俯视、没有近大远小（左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素），
对岸远景只往上叠、颜色变淡，不缩小；人在哪儿都一样大（定稿宾客 84 像素高当尺子）。
规矩照 docs/罗曼山庄画风.md 第 0 节：1 倍颗粒、硬边、整块 ≤64 色（同名颜色全游戏同值）、光从左上、深褐描边、按着地线分层、图上不写字。

用法：
  python3 draw_lake_ref2.py            出全部（layers/、整块、手机、并排对照）
  python3 draw_lake_ref2.py round3     另外存 round3.png（整块）和 round3_phone.png
坐标全是游戏画布坐标（1536×1280）。
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件"
CHAR_DIR = os.path.join(REPO, "godot", "assets", "characters", "lm")
REF = os.path.join(REPO, "docs", "参考图", "湖边效果图2-月亮门曲桥-阿鱼10-03.png")
LAYER_DIR = os.path.join(HERE, "layers")
W, H = 1536, 1280
PHONE = (512, 120, 1052, 1080)        # 手机取景（540×960）

# ------------------------------------------------------------------ 调色板（62 色，名字和值都照已进游戏的果园、休息间、化妆间、湖边样板）
PAL_HEX = {
    "ol": "#22140f",
    "wd0": "#3a2218", "wd1": "#552f1f", "wd2": "#71402a", "wd3": "#8f5535", "wd4": "#ad6d40", "wd5": "#c98d58",
    "fl0": "#5a3e2e", "fl1": "#765238", "fl2": "#8e6846", "fl3": "#a67c54", "fl4": "#ba8e60", "fl5": "#c89e6c",
    "fl6": "#d6b07e", "fl7": "#e6c696",
    "rd1": "#62181b", "rd2": "#8a2321", "rd3": "#b1332a", "rd4": "#d24f39", "rd5": "#ea8152",
    "gd1": "#87591c", "gd2": "#b8862b", "gd3": "#deb550", "gd4": "#f7e09a",
    "wt": "#fdfbf3",
    "bl0": "#19223d", "bl1": "#243863", "bl2": "#385a90", "bl3": "#6c8fbd", "bl4": "#b0c6de",
    "ik1": "#201c26", "ik2": "#34303d", "ik3": "#554e60",
    "sv0": "#737a8f", "sv1": "#a3abbe", "sv2": "#d3d8e3",
    "gr0": "#1b3022", "gr1": "#284a2c", "gr2": "#3f6935", "gA": "#527d3a", "gr3": "#649340",
    "gB": "#7fa84a", "gr4": "#9cbd5e", "gC": "#c5d888",
    "nl1": "#234536", "nl2": "#31593c", "nl3": "#477a45",
    "lk0": "#22495f", "lk1": "#2d6079", "lk2": "#3d7890",
    "wa0": "#5d8c95", "wa1": "#8fbcc0", "wa2": "#c3e0dc",
    "hz0": "#7e9b78", "hz1": "#a0b693", "hz2": "#c3d1ad",
    "tl": "#2c7a74", "tl2": "#5aaa9b",
    "pk0": "#a8455e", "pk": "#de8399", "pk2": "#f4bfc8",
    "or": "#dd7a2c",
    "wl4": "#efdfc0", "wl5": "#f9efda",
}


def hex2rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


C = {k: hex2rgba(v) for k, v in PAL_HEX.items()}
NAME_OF = {v: k for k, v in C.items()}
PAL_SET = set(C.values())
# 色带（暗 → 亮）；一个颜色在几条色带里时后写的说了算（草最后写）
RAMPS = {
    "lf": ["gr0", "nl1", "nl2", "nl3", "gr3", "gB"],
    "wd": ["wd0", "wd1", "wd2", "wd3", "wd4", "wd5"],
    "fl": ["fl0", "fl1", "fl2", "fl3", "fl4", "fl5", "fl6", "fl7"],
    "rd": ["rd1", "rd2", "rd3", "rd4", "rd5"],
    "gd": ["gd1", "gd2", "gd3", "gd4"],
    "pk": ["pk0", "pk", "pk2"],
    "hz": ["hz0", "hz1", "hz2"],
    "tl": ["tl", "tl2"],
    "lk": ["lk0", "lk1", "lk2", "wa0", "wa1", "wa2"],
    "bl": ["bl0", "bl1", "bl2", "bl3", "bl4"],
    "sv": ["ik1", "ik2", "ik3", "sv0", "sv1", "sv2", "wt"],
    "gr": ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"],
}
RAMP_OF = {}
for _rn, _names in RAMPS.items():
    for _i, _n in enumerate(_names):
        RAMP_OF[C[_n]] = (_rn, _i)


def shift(col, k):
    c = C[col] if isinstance(col, str) else col
    if k == 0 or c not in RAMP_OF:
        return c
    rn, i = RAMP_OF[c]
    names = RAMPS[rn]
    return C[names[max(0, min(len(names) - 1, i + k))]]


def rname(ramp, i):
    names = RAMPS[ramp]
    return names[max(0, min(len(names) - 1, int(i)))]


def is_ramp(col, rn):
    return col[3] and col in RAMP_OF and RAMP_OF[col][0] == rn


_QCACHE = {}


def quant(rgb, cands):
    """最近色（只在 cands 这几个颜色名里挑）"""
    key = (rgb, cands)
    r = _QCACHE.get(key)
    if r is not None:
        return r
    best, bd = None, 1e18
    for n in cands:
        c = C[n]
        dr, dg, db = rgb[0] - c[0], rgb[1] - c[1], rgb[2] - c[2]
        d = 2 * dr * dr + 4 * dg * dg + 3 * db * db
        if d < bd:
            best, bd = c, d
    _QCACHE[key] = best
    return best


def mix(a, b, t):
    return (int(a[0] + (b[0] - a[0]) * t), int(a[1] + (b[1] - a[1]) * t), int(a[2] + (b[2] - a[2]) * t))


# ------------------------------------------------------------------ 噪声（只用来挑色、定疏密，不出半透明）
def h2(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 982451653) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n ^= n >> 16
    return (n & 0xFFFF) / 65535.0


def vnoise(x, y, cell, seed):
    fx, fy = x / cell, y / cell
    ix, iy = math.floor(fx), math.floor(fy)
    tx, ty = fx - ix, fy - iy
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    a = h2(ix, iy, seed)
    b = h2(ix + 1, iy, seed)
    c = h2(ix, iy + 1, seed)
    d = h2(ix + 1, iy + 1, seed)
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty


BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dith(x, y, t):
    return (BAYER4[y & 3][x & 3] + 0.5) / 16.0 < t


def norm3(v):
    n = math.sqrt(sum(a * a for a in v)) or 1.0
    return tuple(a / n for a in v)


LIGHT3 = norm3((-0.62, -0.72, 0.78))     # 屏幕 x 右、y 下、z 朝外：光从左上


# ------------------------------------------------------------------ 画布
class Layer:
    """一层透明画布（画布坐标），每个像素要么全不透明要么全透明"""

    def __init__(self, x0, y0, w, h):
        self.ox, self.oy, self.w, self.h = int(x0), int(y0), int(w), int(h)
        self.im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.px = self.im.load()

    @staticmethod
    def c(col):
        return C[col] if isinstance(col, str) else col

    def p(self, x, y, col):
        x = int(x) - self.ox
        y = int(y) - self.oy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = self.c(col)

    def g(self, x, y):
        x = int(x) - self.ox
        y = int(y) - self.oy
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def has(self, x, y):
        return self.g(x, y)[3] > 0

    def clear(self, x, y):
        x = int(x) - self.ox
        y = int(y) - self.oy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = (0, 0, 0, 0)

    def rect(self, x0, y0, x1, y1, col):
        cc = self.c(col)
        for y in range(max(int(y0), self.oy), min(int(y1), self.oy + self.h)):
            for x in range(max(int(x0), self.ox), min(int(x1), self.ox + self.w)):
                self.px[x - self.ox, y - self.oy] = cc

    def hl(self, x0, x1, y, col):
        self.rect(x0, y, x1, y + 1, col)

    def vl(self, x, y0, y1, col):
        self.rect(x, y0, x + 1, y1, col)

    def ell(self, x0, y0, x1, y1, col, only=None):
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        rx, ry = (x1 - x0) / 2.0, (y1 - y0) / 2.0
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(math.floor(y0)), int(math.ceil(y1))):
            for x in range(int(math.floor(x0)), int(math.ceil(x1))):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0 and (only is None or only(x, y)):
                    self.p(x, y, col)

    def poly(self, pts, col):
        d = ImageDraw.Draw(self.im)
        d.polygon([(x - self.ox, y - self.oy) for x, y in pts], fill=self.c(col))

    def line(self, x0, y0, x1, y1, col):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.p(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def shade_px(self, x, y, k):
        c = self.g(x, y)
        if c[3]:
            self.p(x, y, shift(c, k))

    def outline(self, col="ol", pick=None):
        ring = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[nx, ny][3]:
                        ring.append((x, y, self.px[nx, ny]))
                        break
        for x, y, nb in ring:
            cc = self.c(col)
            if pick:
                r = pick(x + self.ox, y + self.oy, nb)
                if r is None:
                    continue
                cc = self.c(r)
            self.px[x, y] = cc
        return self

    def paste(self, other):
        self.im.alpha_composite(other.im, (other.ox - self.ox, other.oy - self.oy))

    def crop_to_content(self):
        bb = self.im.getbbox()
        if not bb:
            return self
        n = Layer(self.ox + bb[0], self.oy + bb[1], bb[2] - bb[0], bb[3] - bb[1])
        n.im = self.im.crop(bb)
        n.px = n.im.load()
        return n


# ------------------------------------------------------------------ 游戏视角投影（地面坐标：米，x 往东、y 往北，h 往上）
OX, OY = 768, 1040        # 地面 (0, 0) = 月亮门墙脚正中


def scr(gx, gy, h=0.0):
    return (OX + 48.0 * gx, OY - 32.0 * gy - 48.0 * h)


def gnd(sx, sy, h=0.0):
    return ((sx - OX) / 48.0, (OY - sy - 48.0 * h) / 32.0)


# ------------------------------------------------------------------ 场景布局（全在这里，改一处全图跟着走）
WALL_Y, WALL_TOP, WALL_T = 1040, 940, 11          # 墙脚、墙面顶、墙厚（像素）
GATE_C, GATE_R = (768, 990), 58                     # 月亮门洞（直径 116 = 2.4 米）
FAR_Y = 432                                         # 对岸水边
PCX, PCY = 792, 581                                 # 湖心亭中心（台面）
PGX, PGY = gnd(PCX, PCY)
RP, RC, RE, RT = 2.7, 1.8, 2.35, 3.0                # 台子、柱圈、檐口、翼角半径（米）
HC, HR = 2.6, 2.6                                   # 柱高、屋面升起（米；斜俯视下后翼角往上挪 83 像素，升起要够高才压得住）
BRIDGE = [(0.0, 7.5), (0.0, 9.0), (2.4, 10.6), (0.6, 11.9), (0.6, 12.6)]
BW = 1.7                                            # 桥宽（米）
PATH_N = (727, 809, 790, 848)                       # 北段石板路 x0 x1 y0 y1
PLAZA = (560, 1010, 846, 888)
PATH_S = (712, 824, 886, 1290)                      # 南段（穿过月亮门一直到画布底）
LANTERNS = [(682, 840), (858, 840)]
BANYANS = [(540, 912), (1040, 918)]
WILLOWS = [(86, 812), (1458, 818)]
BOAT = (1004, 520)                                  # 船中心线落水处
LOTUS = [(566, 614, 82, 30), (1000, 626, 70, 26), (200, 640, 100, 36), (1300, 646, 100, 36)]


def shore_y(x):
    """近岸水边（北边是水）"""
    return int(round(786 + 7 * math.sin(x / 83.0 + 1.0) + 4 * math.sin(x / 37.0) + 3 * math.sin(x / 13.0 + 2)))


SHORE = [shore_y(x) for x in range(W)]


def is_water(x, y):
    return 0 <= x < W and FAR_Y + 3 <= y < SHORE[x]


# ------------------------------------------------------------------ 小零件
def thick_line(L, x0, y0, x1, y1, w0, w1, ramp, light_bias=0.0):
    """一根枝 / 柱：从粗 w0 到细 w1，横截面左亮右暗（ramp 6 档，0 最暗）"""
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    pts = {}
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        hw = (w0 + (w1 - w0) * t) / 2.0
        for yy in range(int(y - hw) - 1, int(y + hw) + 2):
            for xx in range(int(x - hw) - 1, int(x + hw) + 2):
                d = math.hypot(xx + 0.5 - x, yy + 0.5 - y)
                if d <= hw:
                    s = (xx + 0.5 - x) / max(hw, 0.5)
                    old = pts.get((xx, yy))
                    if old is None or abs(s) < abs(old):
                        pts[(xx, yy)] = s
    for (x, y), s in pts.items():
        s += light_bias
        idx = 5 if s < -0.55 else (4 if s < -0.1 else (3 if s < 0.45 else 2))
        L.p(x, y, ramp[idx])
    return pts


def red_lantern(L, cx, top):
    """小红灯笼（15 宽 19 高 + 穗）：金顶金底、竖棱、中间透亮"""
    L.vl(cx, top - 4, top, "ol")
    L.rect(cx - 3, top, cx + 4, top + 2, "gd2")
    L.hl(cx - 3, cx + 4, top, "gd3")
    L.ell(cx - 7, top + 1, cx + 8, top + 18, "rd3")
    L.ell(cx - 5, top + 3, cx + 5, top + 15, "rd4")
    L.ell(cx - 3, top + 5, cx + 2, top + 12, "rd5")
    L.p(cx - 2, top + 6, "gd4")
    for x in (cx - 4, cx + 3):
        for y in range(top + 3, top + 16):
            L.p(x, y, "rd2")
    L.ell(cx + 2, top + 4, cx + 7, top + 16, "rd2", only=lambda x, y: x >= cx + 4)
    L.rect(cx - 3, top + 17, cx + 4, top + 19, "gd2")
    L.hl(cx - 3, cx + 4, top + 17, "gd3")
    for y in range(top + 19, top + 25):
        L.p(cx, y, "rd3" if y < top + 23 else "rd4")
        if y > top + 20:
            L.p(cx - 1, y, "rd2")
            L.p(cx + 1, y, "rd2")


def small_lantern(L, cx, top):
    """檐角挂的小红灯笼（9 宽 12 高 + 穗）"""
    L.vl(cx, top - 3, top, "ol")
    L.hl(cx - 2, cx + 3, top, "gd2")
    L.ell(cx - 4, top + 1, cx + 5, top + 11, "rd3")
    L.ell(cx - 3, top + 2, cx + 3, top + 9, "rd4")
    L.p(cx - 1, top + 4, "rd5")
    L.p(cx - 1, top + 5, "gd4")
    L.ell(cx + 1, top + 2, cx + 5, top + 10, "rd2", only=lambda x, y: x >= cx + 3)
    L.hl(cx - 2, cx + 3, top + 11, "gd2")
    for y in range(top + 12, top + 16):
        L.p(cx, y, "rd3")


def red_bow(L, cx, cy, tails=9):
    L.ell(cx - 7, cy - 3, cx, cy + 4, "rd3")
    L.ell(cx + 1, cy - 3, cx + 8, cy + 4, "rd3")
    L.ell(cx - 6, cy - 2, cx - 2, cy + 1, "rd4")
    L.ell(cx + 2, cy - 2, cx + 6, cy + 1, "rd4")
    L.p(cx - 5, cy - 2, "rd5")
    L.rect(cx - 1, cy - 2, cx + 2, cy + 3, "rd2")
    L.p(cx, cy - 1, "gd3")
    for j in range(tails):
        L.p(cx - 2 - j // 3, cy + 3 + j, "rd3" if j % 3 else "rd4")
        L.p(cx + 2 + j // 4, cy + 3 + j, "rd2" if j % 3 else "rd3")


def silk_swag(L, xa, ya, xb, yb, sag, thick=3):
    """一弧红绸：上沿亮、下沿暗"""
    n = int(abs(xb - xa)) + 1
    for i in range(n + 1):
        t = i / n
        x = xa + (xb - xa) * t
        y = ya + (yb - ya) * t + sag * math.sin(math.pi * t)
        for k in range(thick):
            col = "rd4" if k == 0 else ("rd2" if k == thick - 1 else "rd3")
            L.p(x, y + k, col)


# ------------------------------------------------------------------ 叶子：一团团的树冠（树、灌木、对岸的树都用）
def leaf_tex(x, y, seed, cw=4, ch=3):
    """小叶纹理：抖动网格上每格一片小叶。返回 -1（叶缝暗）、0、+1（叶尖受光）"""
    gx, gy = x // cw, y // ch
    best = 99.0
    bdx = bdy = 0.0
    for j in (-1, 0, 1):
        for i in (-1, 0, 1):
            ci, cj = gx + i, gy + j
            cx = ci * cw + cw * 0.5 + (h2(ci, cj, seed) - 0.5) * cw * 0.7
            cy = cj * ch + ch * 0.5 + (h2(ci, cj, seed + 7) - 0.5) * ch * 0.7
            dx, dy = x + 0.5 - cx, (y + 0.5 - cy) * 1.2
            d = dx * dx + dy * dy
            if d < best:
                best, bdx, bdy = d, dx, dy
    if best > (cw * 0.6) ** 2:
        return -1
    if bdx + bdy < -0.7:
        return 1
    return 0


def draw_clumps(L, clumps, ramp, seed, tex=True, edge_dark=True, rim=True, lo=-0.3, hi=0.95, cw=4, ch=3, mask=None):
    """clumps：[(cx, cy, r[, 亮度偏移])]，按顺序画（先画后面的）。每团是几个小鼓包拼成的花菜形，
    按球面法线对左上的光算明暗，压到 ramp（暗 → 亮）上，再叠小叶纹理；团的右下沿一圈暗边、左上沿亮一档"""
    n = len(ramp)
    drawn = mask if mask is not None else set()
    for k, cl in enumerate(clumps):
        cx, cy, r = cl[0], cl[1], cl[2]
        bias = cl[3] if len(cl) > 3 else 0.0
        rnd = random.Random(seed * 7919 + k * 31 + int(cx) * 3)
        bumps = [(cx, cy + r * 0.06, r * 0.78)]
        nb = rnd.randint(6, 9)
        a0 = rnd.uniform(0, 6.283)
        for i in range(nb):
            a = a0 + 6.283 * i / nb + rnd.uniform(-0.25, 0.25)
            rr = r * rnd.uniform(0.36, 0.5)
            dd = r - rr
            bumps.append((cx + math.cos(a) * dd, cy + math.sin(a) * dd * 0.86, rr))
        pix = {}
        R1 = r * 1.1
        for y in range(int(cy - r - 2), int(cy + r + 3)):
            for x in range(int(cx - r - 2), int(cx + r + 3)):
                best = None
                for (bx, by, br) in bumps:
                    dx, dy = (x + 0.5 - bx) / br, (y + 0.5 - by) / br
                    d2 = dx * dx + dy * dy
                    if d2 <= 1.0:
                        hh = br * math.sqrt(1 - d2)
                        if best is None or hh > best[0]:
                            best = (hh, dx, dy)
                if best is None:
                    continue
                mx, my = (x + 0.5 - cx) / R1, (y + 0.5 - cy) / R1
                mz = math.sqrt(max(0.0, 1 - mx * mx - my * my))
                _, bx_, by_ = best
                bz = math.sqrt(max(0.0, 1 - bx_ * bx_ - by_ * by_))
                nx, ny, nz = mx * 0.6 + bx_ * 0.4, my * 0.6 + by_ * 0.4, mz * 0.6 + bz * 0.4
                nn = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
                lum = (nx * LIGHT3[0] + ny * LIGHT3[1] + nz * LIGHT3[2]) / nn
                pix[(x, y)] = lum + bias
        for (x, y), lum in pix.items():
            t = (lum - lo) / (hi - lo) * (n - 1)
            t = max(0.0, min(n - 1.0, t))
            idx = int(t)
            if t - idx > 0.5 and (x + y) % 2 == 0:
                idx += 1
            if t - idx > 0.75:
                idx += 1
            if tex:
                idx += leaf_tex(x, y, seed, cw, ch)
            idx = max(1, min(n - 1, idx))
            if rim and ((x - 1, y) not in pix or (x, y - 1) not in pix) and lum > 0.2:
                idx = min(n - 1, idx + 1)
            L.p(x, y, ramp[idx])
            drawn.add((x, y))
        if edge_dark:
            for (x, y) in pix:
                if (x + 1, y) not in pix or (x, y + 1) not in pix or (x + 1, y + 1) not in pix:
                    if pix[(x, y)] < 0.55:
                        L.p(x, y, ramp[0])
    return drawn


def canopy(L, masses, ramp, seed, cr=(7, 10), spacing=1.2, lo=-0.35, hi=1.55, gap=True, speck=True, prio=0.35, spill=0.55):
    """树冠两层画法：masses [(cx, cy, R[, 亮度偏移])] 是几个大团，只管整体明暗（左上亮、右下暗、靠下的团压前面）；
    大团里面撒满小叶簇（半径 cr），每簇是带 5～7 个叶尖的小团：左上一块亮两档（叶尖受光）、右下暗一两档、底沿一道深叶缝。
    边上的叶簇可以冒出大团外面一点（spill），轮廓就不是圆滚滚的。返回画到的像素集合"""
    n = len(ramp)

    def mass_at(x, y):
        best = None
        for m in masses:
            cx, cy, R = m[0], m[1], m[2]
            dx, dy = (x + 0.5 - cx) / R, (y + 0.5 - cy) / (R * 0.9)
            d2 = dx * dx + dy * dy
            if d2 <= 1.0:
                dz = math.sqrt(1 - d2)
                hh = R * dz + prio * cy
                if best is None or hh > best[0]:
                    best = (hh, dx, dy, dz, m[3] if len(m) > 3 else 0.0)
        if best is None:
            return None
        _, dx, dy, dz, b = best
        return dx * LIGHT3[0] + dy * LIGHT3[1] + dz * LIGHT3[2] + b

    def tone(lum):
        t = (lum - lo) / (hi - lo)
        return 1 + max(0.0, min(1.0, t)) * (n - 2)

    xs0 = int(min(m[0] - m[2] for m in masses)) - 2
    xs1 = int(max(m[0] + m[2] for m in masses)) + 3
    ys0 = int(min(m[1] - m[2] for m in masses)) - 2
    ys1 = int(max(m[1] + m[2] for m in masses)) + 3
    lum_map = {}
    for y in range(ys0, ys1):
        for x in range(xs0, xs1):
            l = mass_at(x, y)
            if l is not None:
                lum_map[(x, y)] = l
    # 底色（叶簇之间露出来的缝，暗两档）
    for (x, y), l in lum_map.items():
        t = tone(l) - 2.0
        i = int(t)
        if t - i > 0.5 and (x + y) % 2 == 0:
            i += 1
        L.p(x, y, ramp[max(0, min(n - 1, i))])
    drawn = set(lum_map.keys())
    rnd = random.Random(seed)
    step = (cr[0] + cr[1]) / 2.0 * spacing
    pts = []
    yy = ys0
    row = 0
    while yy < ys1:
        xx = xs0 + (step / 2 if row % 2 else 0)
        while xx < xs1:
            px = xx + rnd.uniform(-step * 0.35, step * 0.35)
            py = yy + rnd.uniform(-step * 0.3, step * 0.3)
            if (int(px), int(py)) in lum_map:
                pts.append((px, py, rnd.uniform(cr[0], cr[1]), rnd.uniform(0, 6.283), rnd.randint(5, 7)))
            xx += step
        yy += step * 0.8
        row += 1
    pts.sort(key=lambda p: p[1])
    for (px, py, r, ph, nl) in pts:
        l0 = lum_map[(int(px), int(py))]
        blob = {}
        for y in range(int(py - r) - 2, int(py + r) + 3):
            for x in range(int(px - r) - 2, int(px + r) + 3):
                inside = (x, y) in lum_map
                dx, dy = x + 0.5 - px, (y + 0.5 - py) * 1.15
                d = math.hypot(dx, dy)
                a = math.atan2(dy, dx)
                rr = r * (0.74 + 0.3 * abs(math.cos(a * nl / 2.0 + ph)))
                if not inside:
                    rr *= spill
                if d <= rr:
                    blob[(x, y)] = (dx / r, dy / r, lum_map.get((x, y), l0 - 0.1))
        for (x, y), (u, v, lm) in blob.items():
            t = tone(lm) - 0.7
            s = -u * 0.7 - v * 0.75
            if s > 0.64:
                t += 2.1 if t > 2.2 else 1.2              # 叶尖一圈细亮边
            elif s > 0.36:
                t += 1.1
            elif s < -0.55:
                t -= 1.0
            if speck and h2(x, y, seed + 3) < 0.05:
                t -= 1
            i = int(t)
            if t - i > 0.5 and (x + y) % 2 == 0:
                i += 1
            if gap and (x, y + 1) not in blob and v > 0.15:
                i = min(i - 2, 1)
            L.p(x, y, ramp[max(0, min(n - 1, i))])
            drawn.add((x, y))
    return drawn


def poisson_in_ellipse(rnd, cx, cy, rx, ry, rmin, rmax, n, tries=4000, spacing=0.8):
    out = []
    t = 0
    while len(out) < n and t < tries:
        t += 1
        a = rnd.uniform(0, 6.283)
        d = math.sqrt(rnd.random())
        x = cx + math.cos(a) * d * rx
        y = cy + math.sin(a) * d * ry
        r = rnd.uniform(rmin, rmax)
        if all((x - p) ** 2 + (y - q) ** 2 > ((r + rr) * spacing) ** 2 for (p, q, rr) in out):
            out.append((x, y, r))
    return out


GR_RAMP = ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"]
TREE_RAMP = ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"]
BUSH_RAMP = ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4"]
BARK = ["ol", "wd0", "wd1", "fl1", "fl2", "fl3"]


# ================================================================== 远景：天、云、远山、对岸（底图的一部分，也拿来做倒影）
def sky(BK):
    for y in range(BK.h):
        for x in range(W):
            if y < 150:
                col = "bl3"
            elif y < 236:
                col = "bl4" if dith(x, y, (y - 150) / 86.0) else "bl3"
            else:
                col = "bl4"
            BK.px[x, y] = C[col]


def cloud(L, cx, cy, w, seed):
    """积云：中间一个大鼓包、两边小的，底平；左上受光白、右下一圈浅灰、底沿一道浅蓝"""
    rnd = random.Random(seed)
    puffs = [(cx + rnd.uniform(-w * 0.08, w * 0.08), cy - w * 0.16, w * 0.24)]
    for s in (-1, 1):
        puffs.append((cx + s * w * 0.27, cy - w * 0.08, w * 0.17 * rnd.uniform(0.85, 1.1)))
        puffs.append((cx + s * w * 0.42, cy - w * 0.02, w * 0.1 * rnd.uniform(0.8, 1.2)))
    puffs.append((cx + rnd.uniform(-w * 0.2, w * 0.2), cy - w * 0.3, w * 0.13))
    for y in range(int(cy - w * 0.6), int(cy + 2)):
        for x in range(int(cx - w * 0.6), int(cx + w * 0.6)):
            best = None
            for (px, py, r) in puffs:
                dx, dy = (x + 0.5 - px) / r, (y + 0.5 - py) / r
                d2 = dx * dx + dy * dy
                if d2 <= 1:
                    z = math.sqrt(1 - d2)
                    if best is None or z * r > best[0]:
                        best = (z * r, dx, dy, z)
            if best is None:
                continue
            _, dx, dy, z = best
            lum = dx * LIGHT3[0] + dy * LIGHT3[1] + z * LIGHT3[2]
            col = "wt"
            if lum < 0.05 or y > cy - 3:
                col = "sv2"
            elif lum < 0.25 and (x + y) % 2 == 0:
                col = "sv2"
            if y >= cy:
                col = "bl4"
            L.p(x, y, col)


def mountain_range(BK, peaks, base_y, light, mid, dark, seed, speck=None):
    for x in range(W):
        best, bi = 0.0, 0
        for i, (px, hh, hw) in enumerate(peaks):
            u = (x - px) / hw
            if abs(u) < 1:
                v = hh * (1 - u * u) ** 1.5
                if v > best:
                    best, bi = v, i
        ridge = base_y - best + (vnoise(x, 0, 23, seed) - 0.5) * 8 + (vnoise(x, 0, 7, seed + 1) - 0.5) * 3
        px, hh, hw = peaks[bi]
        peak_y = base_y - hh
        for y in range(max(0, int(ridge)), BK.h):
            bx = px + (y - peak_y) * 0.25 + (vnoise(x * 0.5, y, 9, seed + 2) - 0.5) * 22
            col = light if x < bx else mid
            # 山脊下一道亮线（朝光的坡）
            if y - ridge < 2 and x < px + 10:
                col = light
            # 树林颗粒
            if speck and vnoise(x, y * 1.6, 4, seed + 3) > 0.66 and (x + y) % 2 == 0:
                col = dark if col == mid else mid
            # 山沟：几道往下的暗线
            BK.p(x, y, col)


def far_tree(BK, fx, fy, hgt, cr, ramp, seed, trunk=("fl2", "fl3")):
    """对岸的树（原大，不缩小，只是淡）：短树干 + 圆树冠"""
    rnd = random.Random(seed)
    cy = fy - hgt + cr
    for y in range(int(cy + cr * 0.55), fy):
        BK.p(fx - 1, y, trunk[0])
        BK.p(fx, y, trunk[0])
        BK.p(fx + 1, y, trunk[1])
    masses = [(fx + rnd.uniform(-3, 3), cy, cr, 0.0),
              (fx - cr * 0.5, cy + cr * 0.3, cr * 0.68, -0.05),
              (fx + cr * 0.5, cy + cr * 0.32, cr * 0.66, -0.12)]
    canopy(BK, masses, ramp, seed, cr=(5, 7), lo=-0.5, hi=1.4, spill=0.5)


def far_willow(BK, fx, fy, hgt, seed):
    rnd = random.Random(seed)
    top = fy - hgt
    for y in range(top + 30, fy):
        BK.p(fx, y, "fl2")
    for i in range(46):
        x0 = fx + rnd.uniform(-20, 20)
        y0 = top + 8 + abs(x0 - fx) * 0.5 + rnd.uniform(-4, 6)
        ln = rnd.uniform(hgt * 0.45, hgt * 0.85)
        tone = rnd.choice(["gB", "gr4", "gr4", "gC", "hz0"])
        for j in range(int(ln)):
            xx = x0 + (x0 - fx) * j / ln * 0.25
            BK.p(xx, y0 + j, tone if j < ln - 6 else "hz0")
    for i in range(4):
        BK.ell(fx - 18 + i * 9, top + 4 + (i % 2) * 4, fx - 4 + i * 9, top + 18, "gr4")


def far_house(BK, x0, x1, base, seed):
    """对岸人家（原大、淡一档）：白墙黛瓦的徽派小楼——两头马头墙一级级跌下来、墙头压一溜深瓦，中间露一点瓦顶，小窗、木门"""
    w = x1 - x0
    wh = 78
    top = base - wh
    # 中间的坡顶（在马头墙后面）
    for y in range(top - 30, top + 2):
        t = (y - (top - 30)) / 32.0
        xa = x0 + 26 - t * 10
        xb = x1 - 26 + t * 10
        for x in range(int(xa), int(xb)):
            col = "sv0" if ((x - x0) // 5) % 2 == 0 else "ik3"
            if y < top - 27:
                col = "ik2"
            BK.p(x, y, col)
    # 墙身
    for y in range(top, base):
        for x in range(x0, x1):
            col = "sv2" if x < x0 + w * 0.7 else "sv1"
            if y < top + 4:
                col = "sv1"
            if y > base - 6:
                col = "sv0" if (x // 9 + y) % 2 else "sv1"
            BK.p(x, y, col)
    # 马头墙：两头各三级台阶，每级墙头一溜深瓦、头上翘一点
    for s in (-1, 1):
        for k in range(3):
            sx0 = x0 if s < 0 else x1 - 30 + k * 0
            gx0 = x0 + k * 12 if s < 0 else x1 - 12 * (k + 1)
            gx1 = gx0 + 12
            gtop = top - 18 - k * 14
            for y in range(gtop, top + 2):
                for x in range(gx0, gx1):
                    BK.p(x, y, "sv2" if s < 0 else "sv1")
            for x in range(gx0 - 2, gx1 + 2):
                BK.p(x, gtop - 1, "ik3")
                BK.p(x, gtop - 2, "sv0")
                BK.p(x, gtop - 3, "ik2")
            tip = gx0 - 3 if s < 0 else gx1 + 2
            BK.p(tip, gtop - 3, "ik2")
            BK.p(tip + (-1 if s < 0 else 1), gtop - 4, "ik2")
            BK.p(tip, gtop, "ik2")
    # 檐下一道瓦檐、小窗、门
    for x in range(x0 + 34, x1 - 34):
        BK.p(x, top + 2, "ik3")
        BK.p(x, top + 3, "sv0")
    for k in (0.24, 0.66):
        wx = int(x0 + w * k)
        BK.rect(wx, top + 18, wx + 12, top + 32, "sv0")
        BK.rect(wx + 1, top + 19, wx + 11, top + 31, "ik3")
        BK.vl(wx + 6, top + 19, top + 31, "sv0")
    dx = int(x0 + w * 0.45)
    BK.rect(dx - 2, base - 42, dx + 20, base - 39, "ik3")
    BK.rect(dx, base - 38, dx + 18, base - 6, "wd2")
    BK.rect(dx + 2, base - 36, dx + 16, base - 6, "wd3")
    BK.vl(dx + 9, base - 36, base - 6, "wd2")
    BK.p(dx + 1, base - 30, "rd3")
    BK.p(dx + 16, base - 30, "rd3")


def build_backdrop():
    BK = Layer(0, 0, W, FAR_Y + 4)
    sky(BK)
    for (cx, cy, w, s) in ((230, 52, 130, 1), (120, 96, 64, 2), (1010, 42, 120, 3), (1370, 66, 110, 4),
                           (860, 108, 74, 5), (640, 160, 86, 6), (960, 150, 70, 7), (1250, 172, 60, 8), (400, 168, 56, 9)):
        cloud(BK, cx, cy, w, s)
    # 远山两层：后面一层淡蓝，前面一层青绿（只往上叠、变淡，没缩小一说——山本来就是背景）
    mountain_range(BK, [(560, 120, 260), (770, 96, 200), (1000, 110, 220), (1200, 70, 160)], 330, "wa1", "wa0", "lk2", 21)
    mountain_range(BK, [(330, 140, 300), (640, 66, 170), (1240, 166, 330), (900, 62, 150)], 352, "hz0", "tl2", "tl", 22, speck=True)
    BK0 = Layer(0, 0, W, FAR_Y + 4)
    BK0.paste(BK)
    # 对岸：后排高树（更淡）、人家、前排树、柳树、草岸和石岸（树是原大，不缩小，只是淡）
    rnd = random.Random(31)
    BACK = ["gr2", "gA", "hz0", "gr3", "gB", "gr4"]
    FRONT = ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4"]
    # 树脚下先铺一道深绿（林子底下），免得树缝里透出山
    for xx in range(W):
        top = FAR_Y - 96 + int(vnoise(xx, 0, 30, 9) * 14)
        for y in range(top, FAR_Y - 8):
            n = vnoise(xx, y, 6, 10)
            BK.p(xx, y, "gr1" if n < 0.45 else ("gr2" if n < 0.75 else "gA"))
    x = -20
    while x < W + 20:
        far_tree(BK, int(x), FAR_Y - 22, rnd.randint(150, 170), rnd.randint(40, 48), BACK, int(x) + 100)
        x += rnd.randint(40, 54)
    far_house(BK, 540, 680, FAR_Y - 14, 1)
    far_house(BK, 902, 1042, FAR_Y - 14, 2)
    x = -10
    while x < W + 20:
        skip = (510 < x < 712 or 872 < x < 1074)
        if not skip:
            far_tree(BK, int(x), FAR_Y - 8, rnd.randint(120, 140), rnd.randint(34, 40), FRONT, int(x) + 300)
        x += rnd.randint(42, 56)
    # 岸边一溜矮灌木（人家门前留空）
    hedge = []
    x = -10
    while x < W + 20:
        if not (526 < x < 694 or 888 < x < 1056):
            hedge.append((x + rnd.uniform(-4, 4), FAR_Y - 30 + rnd.uniform(-3, 3), rnd.uniform(20, 26), -0.05))
        x += rnd.randint(30, 40)
    hedge.sort(key=lambda m: m[1])
    canopy(BK, hedge, FRONT, 77, cr=(5, 7), lo=-0.45, hi=1.5, spill=0.5)
    for (fx, s) in ((350, 5), (1180, 6), (1390, 7), (200, 8)):
        far_willow(BK, fx, FAR_Y - 8, 120, s)
    # 草岸、石岸
    for xx in range(W):
        for y in range(FAR_Y - 12, FAR_Y - 2):
            if not BK.has(xx, y) or is_ramp(BK.g(xx, y), "bl") or y > FAR_Y - 9:
                col = "gr4" if vnoise(xx, y, 9, 3) > 0.45 else "gC"
                if y > FAR_Y - 5:
                    col = "gB" if (xx + y) % 3 else "gr4"
                BK.p(xx, y, col)
        BK.p(xx, FAR_Y - 2, "sv2")
        BK.p(xx, FAR_Y - 1, "sv1" if (xx % 13) else "sv0")
        BK.p(xx, FAR_Y, "sv1" if (xx % 13) else "sv0")
        BK.p(xx, FAR_Y + 1, "sv0")
        BK.p(xx, FAR_Y + 2, "lk1")
        BK.p(xx, FAR_Y + 3, "lk1")
    return BK, BK0


# ================================================================== 水面（倒影：对岸整条翻下来、调成水色、横着一道道断开）
WATER_CANDS = ("bl0", "bl1", "bl2", "bl3", "bl4", "lk0", "lk1", "lk2", "wa0", "wa1", "tl", "tl2", "nl1", "nl2",
               "nl3", "gr2", "gA", "hz0", "sv1", "sv2", "rd1", "rd2", "ik2", "ik3", "sv0", "wd1", "wd2", "fl2", "gd2")
REF_DARK = ("bl1", "bl2", "lk0", "lk1", "lk2", "tl", "nl1", "nl2", "nl3", "gr2", "gA", "hz0", "wa0", "sv0", "sv1", "ik3", "ik2")
DEEP = (40, 82, 140)


def water_base(x, y):
    n = vnoise(x, y * 5.0, 140, 51) * 0.65 + vnoise(x, y * 4.0, 40, 52) * 0.35
    # 湖中间一大片天光：一道道横的亮蓝纹
    band = vnoise(x * 0.25, y * 2.2, 60, 53)
    if FAR_Y + 150 < y < FAR_Y + 330 and band > 0.6 and (n > 0.42 or (x + y) % 2 == 0):
        return C["bl3"]
    if n > 0.7 or (n > 0.67 and (x + y) % 2 == 0):
        return C["bl3"]
    if n < 0.18:
        return C["bl1"]
    return C["bl2"]


ROWSEG = {}


def row_segments(y):
    """每行水面切成一段段：倒影跟着左右错 1～2 像素，有的段是断开的（露出底色、亮一道）"""
    if y in ROWSEG:
        return ROWSEG[y]
    rnd = random.Random(y * 977 + 13)
    dist = max(0.0, (y - FAR_Y) / 360.0)
    pb = 0.05 + 0.3 * min(1.0, dist)
    segs = []
    x = 0
    while x < W:
        ln = rnd.randint(14, 70) if dist < 0.35 else rnd.randint(8, 40)
        kind = "brk" if rnd.random() < pb else "ref"
        xo = rnd.choice([-1, 0, 0, 0, 1]) if dist < 0.3 else rnd.choice([-2, -1, 0, 1, 2])
        segs.append((x, x + ln, kind, xo))
        x += ln
    ROWSEG[y] = segs
    return segs


def paint_water(BG, BK, BK0, refl):
    mirror = FAR_Y + 3
    for y in range(FAR_Y + 3, max(SHORE) + 1):
        segs = row_segments(y)
        dist = (y - FAR_Y) / 360.0
        a = 0.42 + 0.22 * min(1.0, dist)
        for (xa, xb, kind, xo) in segs:
            for x in range(xa, min(W, xb)):
                if y >= SHORE[x]:
                    continue
                base = water_base(x, y)
                col = base
                sy = 2 * mirror - y
                sx = min(W - 1, max(0, x + xo))
                if kind == "ref" and 0 <= sy < BK.h:
                    s = BK.px[sx, sy]
                    s0 = BK0.px[sx, sy]
                    if s != s0:
                        col = quant(mix(s[:3], DEEP, a), REF_DARK)
                    elif s in (C["wt"], C["sv2"]):
                        col = C["bl3"] if (x + y) % 3 else C["bl4"]
                    elif RAMP_OF.get(s, ("", 0))[0] in ("tl", "hz", "lk"):
                        col = quant(mix(s[:3], DEEP, 0.6), ("bl2", "lk2", "lk1", "bl3"))
                elif kind == "brk":
                    if xa + 3 <= x < xb - 3 and (xb - xa) > 12 and h2(xa, y, 5) < 0.4:
                        col = C["bl3"] if base == C["bl2"] else shift(base, 1)
                BG.px[x, y] = col
    # 东西的倒影（亭子、船）：各自按落水线翻下来
    for (L, ym, a) in refl:
        for y in range(L.oy, L.oy + L.h):
            ry = int(2 * ym - y)
            if ry <= ym or ry >= H:
                continue
            segs = row_segments(ry)
            for (xa, xb, kind, xo) in segs:
                if kind == "brk":
                    continue
                for x in range(max(xa, L.ox), min(xb, L.ox + L.w)):
                    s = L.g(x - xo, y)
                    if not s[3] or not is_water(x, ry):
                        continue
                    BG.px[x, ry] = quant(mix(s[:3], DEEP, a), WATER_CANDS)
    # 水面细碎亮纹（越近越多）
    rnd = random.Random(77)
    for _ in range(1800):
        x = rnd.randrange(0, W)
        y = rnd.randrange(FAR_Y + 60, max(SHORE))
        if not is_water(x, y) or BG.g(x, y) != C["bl2"]:
            continue
        ln = rnd.randint(3, 9)
        for i in range(ln):
            if is_water(x + i, y) and BG.g(x + i, y) == C["bl2"]:
                BG.p(x + i, y, "bl3" if rnd.random() < 0.85 else "bl1")
    for _ in range(140):
        x = rnd.randrange(0, W)
        y = rnd.randrange(FAR_Y + 150, max(SHORE))
        if is_water(x, y) and is_water(x + 2, y):
            BG.p(x, y, "bl3")
            BG.p(x + 1, y, "bl4")
            BG.p(x + 2, y, "bl3")


# ================================================================== 地面：草、近岸、石板路
def grass_tone(x, y, bias=0.0):
    n = vnoise(x, y * 1.3, 72, 11) * 0.45 + vnoise(x, y * 1.3, 21, 12) * 0.35 + vnoise(x, y, 5, 13) * 0.20 + bias
    tones = ("gr3", "gB", "gr4")
    th = (0.33, 0.70)
    idx = 0
    for t in th:
        if n >= t:
            idx += 1
    for j, t in enumerate(th):
        if abs(n - t) < 0.018:
            idx = j + 1 if (x + y) % 2 == 0 else j
            break
    return tones[idx]


def tuft(L, x, y, rnd, k=1):
    xs = sorted(rnd.sample([-4, -2, 0, 2, 4], rnd.randint(2, 4)))
    for bx in xs:
        hgt = rnd.randint(2, 3) if k > 0 else rnd.randint(1, 2)
        lean = rnd.choice([0, 0, -1, 1])
        for j in range(hgt):
            px_ = x + bx + (lean if j == hgt - 1 and hgt > 1 else 0)
            kk = k + (1 if (j == hgt - 1 and k > 0 and hgt == 3) else 0)
            L.shade_px(px_, y - j, kk)
        L.shade_px(x + bx, y + 1, -1)


def flower_dot(L, x, y, kind):
    if kind == "daisy":
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            L.p(x + dx, y + dy, "wt")
        L.p(x, y, "gd3")
    elif kind == "yellow":
        L.p(x, y, "gd4")
        L.p(x + 1, y, "gd3")
        L.p(x, y + 1, "gd3")
    elif kind == "pink":
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            L.p(x + dx, y + dy, "pk")
        L.p(x, y, "wt")
    else:
        L.p(x, y, "wt")


def grass_details(L, rnd, area, dens=1.0):
    x0, y0, x1, y1 = area
    for cy in range(y0, y1, 7):
        for cx in range(x0, x1, 9):
            x = cx + rnd.randrange(0, 9)
            y = cy + rnd.randrange(0, 7)
            if not is_ramp(L.g(x, y), "gr"):
                continue
            n = vnoise(x, y, 46, 31)
            p = (0.25 + max(0.0, (n - 0.30) * 1.8)) * dens
            if rnd.random() < p:
                tuft(L, x, y, rnd, 1 if rnd.random() < 0.7 else -1)
    for _ in range(int((x1 - x0) * (y1 - y0) / 7000 * dens)):
        fx = rnd.randrange(x0, x1)
        fy = rnd.randrange(y0, y1)
        if not is_ramp(L.g(fx, fy), "gr"):
            continue
        kind = rnd.choice(["daisy", "daisy", "yellow", "pink", "white"])
        for _ in range(rnd.randint(3, 7)):
            xx = fx + rnd.randint(-9, 9)
            yy = fy + rnd.randint(-6, 6)
            if is_ramp(L.g(xx, yy), "gr") and is_ramp(L.g(xx + 1, yy + 1), "gr"):
                L.shade_px(xx, yy + 1, -1)
                flower_dot(L, xx, yy, kind)


def in_rect(x, y, r):
    return r[0] <= x < r[1] and r[2] <= y < r[3]


def on_path(x, y):
    return in_rect(x, y, PATH_N) or in_rect(x, y, PLAZA) or in_rect(x, y, PATH_S)


def slab(x, y, ox, oy, sw=28, sh=13, seed=5):
    """石板路：一块块长方石板错缝铺（0.6 × 0.4 米），石缝暗、每块左上沿亮"""
    row = (y - oy) // sh
    v = (y - oy) % sh
    off = (row % 2) * (sw // 2) + int(h2(row, 0, seed) * 5)
    col_i = (x - ox + off) // sw
    u = (x - ox + off) % sw
    r = h2(row, col_i, seed + 1)
    if v == sh - 1 or u == sw - 1:
        return "sv0" if h2(x, y, seed + 2) > 0.15 else "ik3"
    if v == 0 or u == 0:
        return "sv2" if r < 0.85 else "sv1"
    base = "sv1"
    if r > 0.82:
        base = "sv2" if (x + y) % 2 else "sv1"
    elif r < 0.12:
        base = "sv0" if (x + y) % 3 == 0 else "sv1"
    n = h2(x, y, seed + 3)
    if n < 0.05:
        return "sv0"
    if n > 0.96:
        return "sv2"
    if v == sh - 2 and u > 2:
        return "sv0" if r < 0.5 and (x % 2) else base
    return base


def paint_ground(BG):
    rnd = random.Random(5)
    y_top = min(SHORE) - 1
    for y in range(y_top, H):
        for x in range(W):
            if y < SHORE[x]:
                continue
            BG.px[x, y] = C[grass_tone(x, y)]
    grass_details(BG, rnd, (0, y_top, W, H), 1.0)
    # 近岸：草边压暗一道、几块岸石；水边一道暗（岸的影子）
    for x in range(W):
        s = SHORE[x]
        BG.p(x, s, "gr1")
        BG.p(x, s + 1, "gr2" if (x % 3) else "gr1")
        if is_water(x, s - 1):
            BG.p(x, s - 1, "bl1")
        if is_water(x, s - 2) and (x % 4):
            BG.shade_px(x, s - 2, -1)
    for _ in range(90):
        x = rnd.randrange(0, W)
        s = SHORE[x]
        w = rnd.randint(5, 10)
        for i in range(w):
            BG.p(x + i, s - 1, "sv1" if i < w - 2 else "sv0")
            BG.p(x + i, s, "sv0" if i else "sv1")
        BG.p(x - 1, s, "ik3")
    # 石板路
    for (x0, x1, y0, y1) in (PATH_N, PLAZA, PATH_S):
        for y in range(y0, min(H, y1)):
            for x in range(x0, x1):
                BG.p(x, y, slab(x, y, PATH_S[0], PLAZA[2]))
    # 路边：草压过来几簇、路沿一道暗
    for (x0, x1, y0, y1) in (PATH_N, PLAZA, PATH_S):
        for y in range(y0, min(H, y1)):
            for x in (x0, x1 - 1):
                if not on_path(x - 1, y) or not on_path(x + 1, y):
                    BG.p(x, y, "sv0")
        for x in range(x0, x1):
            for y in (y0, y1 - 1):
                if y < H and (not on_path(x, y - 1) or not on_path(x, y + 1)):
                    BG.p(x, y, "sv0")
    for _ in range(420):
        r = rnd.choice((PATH_N, PLAZA, PATH_S, PATH_S))
        side = rnd.choice([0, 1, 2, 3])
        if side < 2:
            x = r[0] if side == 0 else r[1] - 1
            y = rnd.randrange(r[2], min(H, r[3]))
            if on_path(x + (-1 if side == 0 else 1), y):
                continue
            for k in range(rnd.randint(1, 3)):
                xx = x + (k if side == 0 else -k)
                BG.p(xx, y, rnd.choice(["gr3", "gB", "gA"]))
                if rnd.random() < 0.5:
                    BG.p(xx, y - 1, "gB")
        else:
            y = r[2] if side == 2 else min(H, r[3]) - 1
            x = rnd.randrange(r[0], r[1])
            if on_path(x, y + (-1 if side == 2 else 1)):
                continue
            for k in range(rnd.randint(1, 3)):
                BG.p(x + k, y + (k % 2 if side == 2 else -(k % 2)), rnd.choice(["gr3", "gB", "gA"]))


# ================================================================== 曲桥（平的桥面画进底图；栏杆是立着的，另出）
def poly_offset(pts, d):
    out = []
    n = len(pts)
    for i in range(n):
        if i == 0:
            a, b = pts[0], pts[1]
        elif i == n - 1:
            a, b = pts[-2], pts[-1]
        if i in (0, n - 1):
            dx, dy = b[0] - a[0], b[1] - a[1]
            l = math.hypot(dx, dy)
            nx, ny = -dy / l, dx / l
            out.append((pts[i][0] + nx * d, pts[i][1] + ny * d))
        else:
            d1 = (pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])
            d2 = (pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
            l1, l2 = math.hypot(*d1), math.hypot(*d2)
            n1 = (-d1[1] / l1, d1[0] / l1)
            n2 = (-d2[1] / l2, d2[0] / l2)
            m = (n1[0] + n2[0], n1[1] + n2[1])
            lm = math.hypot(*m)
            m = (m[0] / lm, m[1] / lm)
            k = d / (m[0] * n1[0] + m[1] * n1[1])
            out.append((pts[i][0] + m[0] * k, pts[i][1] + m[1] * k))
    return out


def pip(x, y, poly):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
            inside = not inside
        j = i
    return inside


BR_L = poly_offset(BRIDGE, BW / 2)
BR_R = poly_offset(BRIDGE, -BW / 2)
BR_POLY = BR_L + BR_R[::-1]


def in_platform(gx, gy, R=RP):
    x, y = abs(gx - PGX), abs(gy - PGY)
    return y <= R * 0.8660254 and 1.7320508 * x + y <= 1.7320508 * R


def seg_coords(gx, gy):
    """离哪段桥最近，沿桥方向的 a、横着的 b、段号"""
    best = None
    for i in range(len(BRIDGE) - 1):
        (x0, y0), (x1, y1) = BRIDGE[i], BRIDGE[i + 1]
        dx, dy = x1 - x0, y1 - y0
        l = math.hypot(dx, dy)
        ux, uy = dx / l, dy / l
        a = (gx - x0) * ux + (gy - y0) * uy
        b = -(gx - x0) * uy + (gy - y0) * ux
        ac = max(0.0, min(l, a))
        d = math.hypot(gx - (x0 + ux * ac), gy - (y0 + uy * ac))
        if best is None or d < best[0]:
            best = (d, a, b, i)
    return best[1], best[2], best[3]


def deck_color(a, b, i, x, y, half, seed=3):
    """木桥面：板子横着桥走向铺，板缝暗，两边一道边梁"""
    if abs(b) > half - 0.11:
        return "wd2" if abs(b) > half - 0.04 else "wd3"
    pitch = 0.2
    k = math.floor(a / pitch + 50)
    f = a / pitch + 50 - k
    if f > 0.8:
        return "fl1"
    r = h2(k, i, seed)
    base = 4 if r < 0.55 else (3 if r < 0.8 else 5)
    if f < 0.18:
        base += 1
    if h2(int(b * 9 + 40), k, seed + 1) < 0.12:
        base -= 1
    if h2(x // 3, y, seed + 2) < 0.04:
        base -= 1
    return rname("fl", base)


def face_band(L, sx0, sy0, sx1, sy1, depth=24, pier_gap=46, seed=1, platform=False):
    """一条朝南的侧面（从桥面边沿往下到水面）：上面木边梁、中间石头一道、下面石墩，墩子之间是桥底的暗水"""
    if sx1 < sx0:
        sx0, sy0, sx1, sy1 = sx1, sy1, sx0, sy0
    span = sx1 - sx0
    for x in range(int(round(sx0)), int(round(sx1)) + 1):
        t = (x - sx0) / span if span else 0
        ty = sy0 + (sy1 - sy0) * t
        top = int(round(ty)) + 1
        u = x - int(sx0)
        for k in range(depth):
            y = top + k
            if k < 3:
                col = ("wd3", "wd2", "wd1")[k]
            elif k < 11:
                col = "sv2" if k == 3 else ("sv0" if k == 10 else "sv1")
                if (u + (k // 4) * 7) % 17 == 0 and 3 < k < 10:
                    col = "sv0"
            else:
                pu = (u + 6) % pier_gap
                if pu < 11:
                    col = "sv2" if pu == 0 else ("sv0" if pu >= 9 else "sv1")
                    if (k - 11) % 6 == 5:
                        col = "sv0"
                else:
                    col = "bl0" if k < 15 else "bl1"
            L.p(x, y, col)


def paint_bridge_and_platform(BG):
    # 侧面先画（桥面后画会压住），亭子台面的三条朝南的边
    for (a0, a1) in ((180, 240), (240, 300), (300, 360)):
        p0 = (PGX + RP * math.cos(math.radians(a0)), PGY + RP * math.sin(math.radians(a0)))
        p1 = (PGX + RP * math.cos(math.radians(a1)), PGY + RP * math.sin(math.radians(a1)))
        s0, s1 = scr(*p0), scr(*p1)
        face_band(BG, s0[0], s0[1], s1[0], s1[1], depth=24, pier_gap=40, platform=True)
    # 桥的朝南侧面
    edges = []
    for i in range(len(BRIDGE) - 2):
        for side, E in ((1, BR_L), (-1, BR_R)):
            p0, p1 = E[i], E[i + 1]
            dx, dy = p1[0] - p0[0], p1[1] - p0[1]
            l = math.hypot(dx, dy)
            nx, ny = (-dy / l, dx / l) if side > 0 else (dy / l, -dx / l)
            if ny < -0.05:
                edges.append((p0, p1))
    for (p0, p1) in edges:
        s0, s1 = scr(*p0), scr(*p1)
        face_band(BG, s0[0], s0[1], s1[0], s1[1], depth=24, pier_gap=44)
    # 台面：木板东西向铺，外圈一道石沿
    x0, y0 = scr(PGX - RP, PGY + RP)
    x1, y1 = scr(PGX + RP, PGY - RP)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            gx, gy = gnd(x, y)
            if not in_platform(gx, gy):
                continue
            if not in_platform(gx, gy, RP - 0.22):
                col = "sv1"
                if not in_platform(gx, gy, RP - 0.06):
                    col = "sv0"
                elif not in_platform(gx, gy, RP - 0.12) and (x + y) % 2 == 0:
                    col = "sv2"
                if (x * 3 + y * 5) % 23 == 0:
                    col = "sv0"
            else:
                a = gy - PGY
                b = gx - PGX
                col = deck_color(a, b, 9, x, y, 99, seed=11)
            BG.p(x, y, col)
    # 瓦顶在台面上的影子（光从左上，影子往右下偏一点），边上棋盘格
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            gx, gy = gnd(x, y)
            if not in_platform(gx, gy, RP - 0.22):
                continue
            if in_platform(gx - 0.3, gy + 0.25, RE - 0.25):
                BG.shade_px(x, y, -2)
            elif in_platform(gx - 0.3, gy + 0.25, RE):
                BG.shade_px(x, y, -1 if (x + y) % 2 else -2)
    # 桥面
    xs = [scr(*p)[0] for p in BR_POLY]
    ys = [scr(*p)[1] for p in BR_POLY]
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            gx, gy = gnd(x, y)
            if not pip(gx, gy, BR_POLY) or in_platform(gx, gy, RP - 0.05):
                continue
            a, b, i = seg_coords(gx, gy)
            BG.p(x, y, deck_color(a, b, i, x, y, BW / 2))


def paint_lotus_pads(BG):
    rnd = random.Random(41)
    for (cx, cy, rx, ry) in LOTUS:
        placed = []
        tries = 0
        while len(placed) < int(rx * ry / 90) and tries < 900:
            tries += 1
            px = cx + rnd.uniform(-rx, rx)
            py = cy + rnd.uniform(-ry, ry)
            if ((px - cx) / rx) ** 2 + ((py - cy) / ry) ** 2 > 1:
                continue
            w = rnd.choice([16, 19, 22, 25, 28, 32])
            if all(math.hypot(px - a, (py - b) * 1.6) > (w + ww) * 0.45 for (a, b, ww) in placed):
                placed.append((px, py, w))
        placed.sort(key=lambda p: p[1])
        for (px, py, w) in placed:
            lotus_pad(BG, px, py, w, rnd.uniform(0, 6.28))


def lotus_pad(L, cx, cy, w, notch):
    rx, ry = w / 2.0, w * 0.3
    pts = []
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d > 1.0 or not is_water(x, y):
                continue
            ang = math.atan2(dy, dx)
            da = (ang - notch + math.pi) % (2 * math.pi) - math.pi
            if abs(da) < 0.18 and d > 0.05:
                continue
            col = "gr3"
            if d > 0.6:
                col = "gr4" if (dx + dy) < -0.3 else ("nl2" if (dx + dy) > 0.25 else "nl3")
            elif (dx + dy) < -0.45:
                col = "gB"
            elif (dx + dy) > 0.35:
                col = "nl3"
            for va in range(7):
                a = va * 0.9 + 0.3
                if abs((ang - a + math.pi) % (2 * math.pi) - math.pi) < 0.08 and 0.1 < d < 0.75:
                    col = "nl3" if (dx + dy) > -0.2 else "gr3"
            pts.append((x, y))
            L.p(x, y, col)
    S = set(pts)
    for (x, y) in pts:
        if (x, y + 1) not in S or (x + 1, y) not in S:
            L.p(x, y, "nl1")
    for (x, y) in pts:
        if (x, y + 1) not in S and is_water(x, y + 1):
            L.p(x, y + 1, "bl1")


# ================================================================== 影子（压到底图上：沿色带挪档，边上棋盘格）
class Shade:
    def __init__(self):
        self.v = {}

    def blob(self, cx, cy, rx, ry, val, seed=0, wob=0.18):
        ph = [h2(seed, i, 77) * 6.28 for i in range(3)]
        for y in range(int(cy - ry * 1.3) - 1, int(cy + ry * 1.3) + 2):
            for x in range(int(cx - rx * 1.3) - 1, int(cx + rx * 1.3) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                th = math.atan2(dy, dx)
                rr = 1 + wob * (0.6 * math.sin(3 * th + ph[0]) + 0.4 * math.sin(5 * th + ph[1]))
                d = math.sqrt(dx * dx + dy * dy) / rr
                if d >= 1.0:
                    continue
                f = 1.0 if d < 0.82 else 0.5
                self.v[(x, y)] = min(self.v.get((x, y), 0.0), val * f) if val < 0 else self.v.get((x, y), 0.0) + val * f

    def apply(self, L):
        for (x, y), s in self.v.items():
            if -0.2 < s < 0.2:
                continue
            s = round(s * 2) / 2.0
            k = math.floor(s)
            if s - k > 0.25 and (x + y) % 2 == 0:
                k += 1
            if k:
                L.shade_px(x, y, int(k))


# ================================================================== 白墙、月亮门、花窗（立着，着地线 = 墙脚 1040）
def wall_top(x):
    u = abs(x - GATE_C[0]) / 132.0
    if u >= 1:
        return WALL_TOP
    hump = 1.0 if u < 0.5 else 0.5 + 0.5 * math.cos(math.pi * (u - 0.5) / 0.5)
    return int(round(WALL_TOP - 40 * hump))


def draw_wall():
    L = Layer(0, 860, W, 200)
    gx, gy = GATE_C
    R = GATE_R
    for x in range(W):
        T = wall_top(x)
        for y in range(T, WALL_Y):
            dfront = math.hypot(x + 0.5 - gx, y + 0.5 - gy)
            dback = math.hypot(x + 0.5 - gx, y + 0.5 - (gy - WALL_T))
            if dfront < R:
                if dback < R:
                    continue                         # 门洞：看得到墙后面
                # 门洞里面一圈（墙的厚度）：底下是门槛石、两边是洞壁
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
                # 石砌门框：一圈深灰，左上半圈受光，一块块石缝
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
            # 墙脚石：12 像素
            if y >= WALL_Y - 12:
                col = "sv1" if y == WALL_Y - 12 else "sv0"
                if (x + (0 if (y - WALL_Y) // 6 % 2 else 15)) % 30 == 0 or y == WALL_Y - 6:
                    col = "ik3"
                if y == WALL_Y - 1:
                    col = "ik3"
                L.p(x, y, col)
                continue
            # 白粉墙（米白，照休息间的墙色 wl5）：顶上压一道瓦影，往下一点点灰，墙根返潮
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
    # 墙顶的瓦（厚一点）：脊 5 行、前坡筒瓦 9 行（8 像素一垄）、檐口一排大瓦当和尖滴水
    for x in range(W):
        T = wall_top(x)
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
        # 瓦当：每垄一个小圆（6 宽 5 高），之间一片尖滴水
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
    # 花窗两扇
    for wx in (578, 958):
        draw_lattice_window(L, wx, 988)
    # 喜事：门洞顶一弧红绸、中间一朵绸花；门两边挂一对红灯笼
    silk_swag(L, gx - 58, 935, gx + 58, 935, 10, 3)
    red_bow(L, gx, 932, 7)
    for s in (-1, 1):
        lx = gx + s * 96
        T = wall_top(lx)
        red_lantern(L, lx, T + 6)
    return L


def draw_lattice_window(L, cx, cy):
    w, h = 52, 30
    x0, y0 = cx - w // 2, cy - h // 2
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            u, v = x - x0, y - y0
            if u < 3 or v < 3 or u >= w - 3 or v >= h - 3:
                col = "sv1" if (u == 0 or v == 0) else ("ik3" if (u == w - 1 or v == h - 1) else "sv0")
                if u in (1, 2) and v > 0 and v < h - 1:
                    col = "sv0"
                L.p(x, y, col)
                continue
            col = "ik2"
            a = (u + v) % 8
            b = (u - v) % 8
            if a in (0, 1) or b in (0, 1):
                col = "sv1" if (a == 0 or b == 0) else "sv0"
            if (u - 3) % 8 == 4 and (v - 3) % 8 == 4:
                col = "sv1"
            L.p(x, y, col)
    L.hl(x0, x0 + w, y0 + h, "sv2")


# ================================================================== 石灯笼（立着）
def draw_stone_lantern(fx, fy):
    L = Layer(fx - 20, fy - 70, 40, 72)

    def box(x0, x1, y0, y1, top_rows=0):
        for y in range(y0, y1):
            for x in range(x0, x1):
                u = (x - x0) / max(1, (x1 - x0 - 1))
                col = "sv2" if u < 0.25 else ("sv1" if u < 0.7 else "sv0")
                if y - y0 < top_rows:
                    col = "sv2" if (y - y0) == 0 else "sv1"
                L.p(x, y, col)

    box(fx - 12, fx + 12, fy - 8, fy, top_rows=3)
    box(fx - 5, fx + 5, fy - 24, fy - 8)
    for y in range(fy - 22, fy - 9, 4):
        L.hl(fx - 5, fx + 5, y, "sv0")
    box(fx - 11, fx + 11, fy - 29, fy - 24, top_rows=2)
    # 灯箱：四角石柱，中间亮着的窗
    box(fx - 8, fx + 8, fy - 45, fy - 29)
    L.rect(fx - 5, fy - 42, fx + 5, fy - 31, "or")
    L.rect(fx - 4, fy - 41, fx + 4, fy - 32, "gd3")
    L.rect(fx - 3, fy - 40, fx + 2, fy - 34, "gd4")
    L.p(fx - 2, fy - 39, "wt")
    L.vl(fx, fy - 42, fy - 31, "gd2")
    # 屋顶：六角攒尖，檐角起翘
    for y in range(fy - 58, fy - 44):
        t = (y - (fy - 58)) / 14.0
        half = 3 + t * 13
        for x in range(int(fx - half), int(fx + half) + 1):
            col = "sv0" if x < fx - 1 else ("ik3" if x < fx + 4 else "ik2")
            if x <= fx - half + 1.5:
                col = "sv1"
            if y >= fy - 46:
                col = "ik2" if y == fy - 45 else "ik3"
            L.p(x, y, col)
    for s in (-1, 1):
        L.p(fx + s * 17, fy - 47, "ik3")
        L.p(fx + s * 18, fy - 48, "ik3")
        L.p(fx + s * 17, fy - 46, "ik2")
    L.line(fx, fy - 58, fx - 15, fy - 46, "sv1")
    L.line(fx + 1, fy - 58, fx + 15, fy - 46, "ik2")
    L.ell(fx - 3, fy - 64, fx + 3, fy - 58, "sv0")
    L.p(fx - 1, fy - 63, "sv1")
    L.vl(fx, fy - 67, fy - 63, "ik3")
    L.outline("ol")
    # 柱腰扎一小朵红绸（喜事）
    L.p(fx - 3, fy - 18, "rd4")
    L.p(fx - 2, fy - 19, "rd4")
    L.p(fx - 2, fy - 18, "rd3")
    L.p(fx - 1, fy - 18, "rd2")
    L.p(fx, fy - 19, "rd3")
    L.p(fx, fy - 18, "rd3")
    L.p(fx + 1, fy - 18, "rd2")
    L.p(fx - 2, fy - 17, "rd3")
    L.p(fx - 2, fy - 16, "rd2")
    L.p(fx, fy - 17, "rd2")
    L.p(fx + 1, fy - 15, "rd2")
    return L


# ================================================================== 太湖石（立着）
def draw_rock(fx, fy, w, h, seed):
    """太湖石：瘦、高、皱、透——几块往上摞的疙瘩，腰细，满身竖皱纹，几个大小不一的洞（有的开在边上成了缺口）"""
    rnd = random.Random(seed)
    L = Layer(fx - w - 4, fy - h - 8, 2 * w + 8, h + 12)
    lumps = []
    n = 4
    for i in range(n):
        t = (i + 0.5) / n
        lw = w * (0.62 if i == 0 else rnd.uniform(0.42, 0.62))
        lumps.append((fx + rnd.uniform(-w * 0.18, w * 0.18), fy - t * h * 0.95, lw, h / n * 0.85))
    holes = []
    for i in range(rnd.randint(2, 4)):
        lx, ly, lw, lh = rnd.choice(lumps[1:])
        holes.append((lx + rnd.uniform(-lw * 0.75, lw * 0.75), ly + rnd.uniform(-lh * 0.4, lh * 0.4),
                      rnd.uniform(1.8, 3.6), rnd.uniform(2.6, 5.5)))

    def field(x, y):
        best = 9.0
        for (cx, cy, rx, ry) in lumps:
            dx, dy = (x - cx) / rx, (y - cy) / ry
            best = min(best, math.sqrt(dx * dx + dy * dy))
        return best + (vnoise(x, y, 7, seed) - 0.5) * 0.5 + (vnoise(x, y, 3, seed + 1) - 0.5) * 0.18

    def in_hole(x, y):
        for (cx, cy, rx, ry) in holes:
            dx, dy = (x - cx) / rx, (y - cy) / ry
            if dx * dx + dy * dy < 1:
                return dx, dy
        return None

    pix = {}
    for y in range(L.oy, fy):
        for x in range(L.ox, L.ox + L.w):
            if field(x + 0.5, y + 0.5) < 1.0:
                pix[(x, y)] = True
    sv = ["ik2", "ik3", "sv0", "sv1", "sv2", "wt"]
    for (x, y) in pix:
        gx = field(x + 1.5, y + 0.5) - field(x - 0.5, y + 0.5)
        gy = field(x + 0.5, y + 1.5) - field(x + 0.5, y - 0.5)
        nx, ny, nz = norm3((gx * 1.6, gy * 1.6, 0.55))
        lum = nx * LIGHT3[0] + ny * LIGHT3[1] + nz * LIGHT3[2]
        t = 1.5 + (lum + 0.15) * 2.5
        g = vnoise(x * 2.4, y * 0.3, 5, seed + 2)
        if g > 0.68:
            t -= 1.5                                   # 竖皱纹
        elif g > 0.6:
            t += 0.8                                   # 皱纹左沿一道亮
        i = int(t)
        if t - i > 0.5 and (x + y) % 2 == 0:
            i += 1
        L.p(x, y, sv[max(0, min(5, i))])
    for (x, y) in pix:
        hh = in_hole(x + 0.5, y + 0.5)
        if hh is not None:
            dx, dy = hh
            col = "ik2" if dx * dx + dy * dy < 0.45 else ("sv0" if dx + dy > 0.55 else "ik3")
            L.p(x, y, col)
    L.outline("ol")
    # 脚下几簇草
    for i in range(5):
        tx = fx + rnd.randint(-w, w)
        for k in range(rnd.randint(2, 4)):
            L.p(tx + k * 2, fy - 1, rnd.choice(["gr2", "gr3", "gA"]))
            L.p(tx + k * 2, fy - 2, rnd.choice(["gr3", "gB"]))
            if rnd.random() < 0.4:
                L.p(tx + k * 2, fy - 3, "gB")
    return L


# ================================================================== 灌木、花丛（立着）
def bush(fx, fy, r, seed, flowers=None, ramp=TREE_RAMP):
    rnd = random.Random(seed)
    L = Layer(fx - r * 2 - 6, fy - r * 2.2 - 6, r * 4 + 12, r * 2.2 + 10)
    cy = fy - r * 0.86
    masses = [(fx + rnd.uniform(-2, 2), cy - r * 0.05, r * 0.95, 0.04)]
    if r > 15:
        masses.append((fx - r * 0.55, cy + r * 0.3, r * 0.66, -0.04))
        masses.append((fx + r * 0.55, cy + r * 0.32, r * 0.64, -0.1))
    canopy(L, masses, ramp, seed, cr=(5, 7) if r < 26 else (6, 8), lo=-0.35, hi=1.55)
    for y in range(int(fy), L.oy + L.h):
        for x in range(L.ox, L.ox + L.w):
            L.clear(x, y)
    L.outline("gr0", pick=lambda x, y, nb: None if y >= fy else "gr0")
    for x in range(L.ox, L.ox + L.w):
        if L.has(x, fy - 1):
            L.p(x, fy - 1, "gr0")
    if flowers:
        for _ in range(int(r * r * 0.26)):
            x = fx + rnd.uniform(-r * 1.05, r * 1.05)
            y = cy + rnd.uniform(-r * 0.95, r * 0.6)
            if not L.has(x, y) or not L.has(x + 2, y + 2) or L.g(x, y) == C["gr0"]:
                continue
            lit = (x - fx) + (y - cy) < r * 0.35
            flower_cluster(L, int(x), int(y), flowers, lit)
    return L


def flower_cluster(L, x, y, kind, lit):
    if kind == "pink":
        a, b, c = ("pk2", "pk", "pk0") if lit else ("pk", "pk0", "pk0")
        for (dx, dy, col) in ((0, -1, a), (-1, 0, a), (0, 0, "wt" if lit else a), (1, 0, b), (0, 1, b), (1, 1, c), (-1, 1, b)):
            L.p(x + dx, y + dy, col)
    else:
        a, b = ("wt", "sv2") if lit else ("sv2", "sv1")
        for (dx, dy, col) in ((0, -1, a), (-1, 0, a), (1, 0, b), (0, 1, b)):
            L.p(x + dx, y + dy, col)
        L.p(x, y, "gd3")


# ================================================================== 榕树（立着；有垂下来的气根）
def draw_banyan(fx, fy, seed, flip=1, crx=172, cry=78, ch=186, roots=40, lean=12):
    rnd = random.Random(seed)
    pad = 70 + abs(lean)
    L = Layer(fx - crx - pad, fy - ch - cry - 50, 2 * crx + 2 * pad, ch + cry + 56)
    T = Layer(L.ox, L.oy, L.w, L.h)
    ccx, ccy = fx + flip * lean, fy - ch
    cbot = ccy + cry * 0.55                     # 树冠下沿大概在这
    # 树干：三根粗的缠在一起往上（气根长成的），根部往外撑
    for (dx, w, lean) in ((-11, 20, -14), (3, 24, 4), (14, 18, 20)):
        thick_line(T, fx + dx, fy, fx + dx + lean, cbot + 6, w, w * 0.75, BARK)
    for (dx, w) in ((-30, 10), (30, 9), (-18, 9), (20, 8), (-40, 6), (42, 5)):
        thick_line(T, fx + dx * 0.35, fy - 18, fx + dx, fy, w, 4, BARK)
    # 大枝：往两边斜着伸进树冠
    for (sx, ang, ln, w) in ((-12, -2.55, 150, 12), (-6, -2.0, 90, 10), (8, -1.15, 100, 10), (16, -0.55, 150, 12), (0, -1.6, 70, 9)):
        x0, y0 = fx + sx + (sx * 0.8), cbot + 10
        ex = x0 + math.cos(ang) * ln * 1.15 + (ccx - fx) * 0.8
        ey = y0 + math.sin(ang) * ln * 0.45
        mx, my = (x0 + ex) / 2, (y0 + ey) / 2 - 8
        thick_line(T, x0, y0, mx, my, w, w * 0.7, BARK)
        thick_line(T, mx, my, ex, ey, w * 0.7, 4, BARK)
    for _ in range(80):
        x = fx + rnd.randint(-34, 34)
        y = rnd.randint(int(cbot), fy - 2)
        for j in range(rnd.randint(3, 10)):
            c = T.g(x, y + j)
            if c in (C["fl1"], C["fl2"], C["fl3"]):
                T.p(x, y + j, "wd1" if c != C["fl3"] else "fl2")
    T.outline("ol")
    L.paste(T)
    # 气根：一部分在树冠后面、一部分垂在前面
    roots_back = Layer(L.ox, L.oy, L.w, L.h)
    roots_front = Layer(L.ox, L.oy, L.w, L.h)
    for i in range(roots):
        u = rnd.uniform(-0.92, 0.92)
        x0 = ccx + u * crx
        y0 = ccy + cry * 0.5 * math.sqrt(max(0.0, 1 - u * u)) + rnd.uniform(-14, 4)
        if rnd.random() < 0.78:
            ln = rnd.uniform(24, 96)
        else:
            ln = fy - y0 - rnd.uniform(0, 6)
        bundle = rnd.choice([1, 1, 2, 3])
        tgt = roots_back if i % 3 else roots_front
        for k in range(bundle):
            aerial_root(tgt, x0 + k * 2, y0 + rnd.uniform(-3, 3), ln * rnd.uniform(0.75, 1.0), rnd)
    L.paste(roots_back)
    # 树冠：一圈大团拼成宽宽的穹顶，下沿一排小一点的团鼓出来
    masses = []
    for k in range(6):
        u = -1 + 2 * k / 5.0
        masses.append((ccx + u * crx * 0.74 + rnd.uniform(-6, 6), ccy - cry * 0.15 + abs(u) * cry * 0.3 + rnd.uniform(-6, 6),
                       cry * rnd.uniform(0.72, 0.86), 0.06 - 0.05 * u * flip))
    for k in range(3):
        u = -0.6 + 0.6 * k
        masses.append((ccx + u * crx * 0.6, ccy - cry * 0.55 + rnd.uniform(-5, 5), cry * rnd.uniform(0.6, 0.7), 0.12))
    for k in range(4):
        u = -0.75 + 0.5 * k
        masses.append((ccx + u * crx * 0.8, ccy + cry * 0.32 + rnd.uniform(-4, 6), cry * rnd.uniform(0.5, 0.6), -0.14))
    C2 = Layer(L.ox, L.oy, L.w, L.h)
    canopy(C2, masses, TREE_RAMP, seed + 1, cr=(7, 10), lo=-0.22, hi=1.72)
    C2.outline("gr0")
    L.paste(C2)
    L.paste(roots_front)
    return L


def aerial_root(L, x0, y0, ln, rnd):
    x = x0
    n = int(ln)
    ph = rnd.uniform(0, 6.28)
    for j in range(n):
        y = y0 + j
        x += math.sin(j * 0.12 + ph) * 0.16
        L.p(x, y, "wd1" if j < n - 2 else "wd0")
        L.p(x + 1, y, "wd0" if j % 6 else "wd1")
        if j % 9 == 4:
            L.p(x - 1, y, "fl2")
        if j < 10 and j % 4 == 1:
            L.p(x - 1, y, "gr1")


# ================================================================== 垂柳（立着）
WI = ["gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"]


def wi(i):
    return WI[max(0, min(len(WI) - 1, int(i)))]


def strand_path(x0, y0, vx, vy, y_end, sway):
    pts = []
    x, y = float(x0), float(y0)
    guard = 0
    while y < y_end and guard < 700:
        guard += 1
        sp = math.hypot(vx, vy) or 1.0
        x += vx / sp
        y += vy / sp
        vy = min(1.0, vy + 0.08)
        if vy > 0:
            vx *= 0.94
            vx += sway * 0.01 * vy
        ip = (int(round(x)), int(round(y)))
        if not pts or ip != pts[-1]:
            pts.append(ip)
    return pts


def draw_strand(L, pts, tone, phase):
    n = len(pts)
    if n < 4:
        return
    for i, (px, py) in enumerate(pts):
        t = i / float(n - 1)
        tt = tone + (1 if t > 0.75 else 0)
        L.p(px, py, wi(tt))
        k = (i + phase) % 3
        if k == 0:
            L.p(px - 1, py, wi(tt + 1))
        elif k == 1:
            L.p(px + 1, py, wi(tt - 1))


def draw_willow(fx, fy, seed, th=290, tw=170):
    rnd = random.Random(seed)
    top = fy - th
    L = Layer(fx - tw // 2 - 20, top - 10, tw + 40, th + 14)
    T = Layer(L.ox, L.oy, L.w, L.h)
    fork_y = fy - rnd.randint(110, 130)
    thick_line(T, fx, fy, fx + rnd.uniform(-6, 6), fork_y, 16, 11, BARK)
    for (dx, w) in ((-8, 6), (8, 6)):
        thick_line(T, fx + dx * 0.3, fy - 8, fx + dx, fy, w, 3, BARK)
    ends = []
    for (tx, ty) in ((fx - 46, top + 46), (fx - 14, top + 16), (fx + 18, top + 20), (fx + 48, top + 52)):
        mx = fx + (tx - fx) * 0.4 + rnd.uniform(-6, 6)
        my = fork_y - 34
        thick_line(T, fx, fork_y + 4, mx, my, 8, 6, BARK)
        thick_line(T, mx, my, tx, ty, 6, 2, BARK)
        ends.append((tx, ty))
    T.outline("ol")
    nb = 26
    bunches = []
    for k in range(nb):
        u = -1 + 2 * (k + rnd.uniform(0.2, 0.8)) / nb
        d = rnd.random()
        bx = fx + u * (tw / 2 - 16)
        by = top + 6 + 26 * u * u + rnd.uniform(0, 16)
        bunches.append((d, u, bx, by))
    for k in range(10):
        u = rnd.uniform(-0.6, 0.6)
        bunches.append((rnd.uniform(0, 0.5), u, fx + u * 50, top + 20 + rnd.uniform(0, 30)))
    bunches.sort(key=lambda b: b[0])

    def put(b):
        d, u, bx, by = b
        n = rnd.randint(5, 8)
        base_len = rnd.uniform(30, 90) + (0 if abs(u) < 0.8 else 20)
        T0 = 1.5 + d * 3.2 - u * 1.0
        vy0 = -rnd.uniform(0.4, 0.9) * (1 - 0.4 * abs(u))
        for j in range(n):
            off = j - (n - 1) / 2.0
            x0 = bx + off * 2.0
            vx = u * 0.7 + off * 0.06
            y_end = fy - base_len - abs(off) * rnd.uniform(3, 10)
            tone = T0 + (0.8 if j == 0 else 0) - (0.8 if j == n - 1 else 0)
            draw_strand(L, strand_path(x0, by, vx, vy0, y_end, 0.5), int(round(tone)), (j * 2 + int(bx)) % 3)

    for b in bunches:
        if b[0] < 0.35:
            put(b)
    L.paste(T)
    for b in bunches:
        if b[0] >= 0.35:
            put(b)
    return L


# ================================================================== 松树（右边墙内，盆景似的一层层平的松针团）
def draw_pine(fx, fy, seed):
    """松：扭着往上的干，几根横枝托着一层层扁平的松针团（盆景似的）"""
    rnd = random.Random(seed)
    L = Layer(fx - 130, fy - 260, 260, 264)
    T = Layer(L.ox, L.oy, L.w, L.h)
    pts = [(fx, fy), (fx - 16, fy - 60), (fx + 12, fy - 118), (fx - 6, fy - 172), (fx + 4, fy - 206)]
    for i in range(len(pts) - 1):
        thick_line(T, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 16 - i * 3, 13 - i * 3, BARK)
    pads = [(fx - 16, fy - 66, -1, 74), (fx + 12, fy - 118, 1, 84), (fx - 6, fy - 166, -1, 64),
            (fx + 4, fy - 204, 1, 40), (fx - 2, fy - 98, 1, 46)]
    for (px, py, side, ln) in pads:
        thick_line(T, px, py, px + side * ln * 0.8, py - 12, 7, 3, BARK)
    T.outline("ol")
    L.paste(T)
    masses = []
    for (px, py, side, ln) in pads:
        cx = px + side * ln * 0.55
        for k in range(4):
            masses.append((cx + (k - 1.5) * ln * 0.24 + rnd.uniform(-3, 3), py - 18 + rnd.uniform(-3, 3), rnd.uniform(14, 18), 0.0))
    masses.sort(key=lambda m: m[1])
    C2 = Layer(L.ox, L.oy, L.w, L.h)
    canopy(C2, masses, ["gr0", "nl1", "nl2", "gr2", "nl3", "gr3", "gB"], seed, cr=(4, 6), lo=-0.3, hi=1.6, prio=0.6)
    C2.outline("gr0")
    L.paste(C2)
    return L


# ================================================================== 湖心亭（六角攒尖：深灰瓦、飞檐翘角、红柱、檐角红灯笼）
def pav(R, ang, h=0.0):
    a = math.radians(ang)
    return scr(PGX + R * math.cos(a), PGY + R * math.sin(a), h)


def red_column(L, ang, R=RC, hc=HC):
    bx, by = pav(R, ang, 0)
    tx, ty = pav(R, ang, hc)
    bx, by, ty = int(round(bx)), int(round(by)), int(round(ty))
    # 柱础
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
    for y in range(ty, by + 1):
        L.p(bx - 5, y, "ol") if y < by - 4 else None
        L.p(bx + 5, y, "ol") if y < by - 4 else None


def railing(L, p0, p1, h_top=0.72, h_low=0.24, post_every=1.05, cap=True, end_posts=(True, True), balusters=True):
    """一段栏杆（地面坐标 p0 → p1，台面高 0）：木柱 + 石头柱头、上下两道扶手、中间小立柱"""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    l = math.hypot(dx, dy)
    n = max(1, int(math.ceil(l / post_every)))
    sp = [scr(p0[0] + dx * i / n, p0[1] + dy * i / n) for i in range(n + 1)]
    s0, s1 = scr(*p0), scr(*p1)
    vertical = abs(s1[0] - s0[0]) < 2
    ht, hl_ = int(48 * h_top), int(48 * h_low)
    # 扶手
    steps = int(max(abs(s1[0] - s0[0]), abs(s1[1] - s0[1]))) + 1
    for k in range(steps + 1):
        t = k / steps
        x = s0[0] + (s1[0] - s0[0]) * t
        y = s0[1] + (s1[1] - s0[1]) * t
        if vertical:
            for (hh, cols) in ((ht, ("wd4", "wd3", "wd2")), (hl_, ("wd3", "wd2", "wd1"))):
                for i, col in enumerate(cols):
                    L.p(x - 1 + i, y - hh, col)
        else:
            for i, col in enumerate(("ol", "wd5", "wd4", "wd3", "wd2", "wd1")):
                L.p(x, y - ht + i - 2, col)
            for i, col in enumerate(("wd3", "wd2", "wd1")):
                L.p(x, y - hl_ + i, col)
            if balusters and int(round(x)) % 7 == 0:
                for yy in range(int(y - ht + 3), int(y - hl_)):
                    L.p(x, yy, "wd2")
                    L.p(x + 1, yy, "wd1")
    if vertical:
        for k in range(steps + 1):
            t = k / steps
            y = s0[1] + (s1[1] - s0[1]) * t
            if int(round(y)) % 5 == 0 and balusters:
                for yy in range(int(y - ht + 2), int(y - hl_)):
                    L.p(s0[0], yy, "wd2")
    # 柱子 + 柱头（木柱 8 像素宽，顶上一颗大石球坐在方座上）
    for i, (x, y) in enumerate(sp):
        if (i == 0 and not end_posts[0]) or (i == n and not end_posts[1]):
            continue
        x, y = int(round(x)), int(round(y))
        top = y - ht - 4
        for yy in range(top, y + 1):
            for k, col in enumerate(("ol", "wd5", "wd4", "wd4", "wd3", "wd2", "wd2", "ol")):
                L.p(x - 4 + k, yy, col)
        L.hl(x - 4, x + 4, y + 1, "ol")
        for yy in (top + 3, y - hl_ + 1):
            L.hl(x - 3, x + 3, yy, "wd1")
        if cap:
            L.hl(x - 5, x + 5, top - 1, "sv0")
            L.hl(x - 5, x + 5, top - 2, "sv1")
            L.hl(x - 5, x + 5, top - 3, "sv2")
            L.ell(x - 5, top - 13, x + 5, top - 3, "sv1")
            L.ell(x - 4, top - 13, x + 1, top - 7, "sv2")
            L.p(x - 2, top - 11, "wt")
            L.p(x - 1, top - 11, "wt")
            L.ell(x, top - 10, x + 5, top - 3, "sv0", only=lambda xx, yy: xx >= x + 1 and yy >= top - 9)
            L.p(x, top - 14, "sv0")
            L.p(x, top - 15, "ol")
            ring = []
            for yy in range(top - 16, top + 1):
                for xx in range(x - 7, x + 8):
                    if not L.has(xx, yy) and any(L.has(xx + a, yy + b) and L.g(xx + a, yy + b) in (C["sv0"], C["sv1"], C["sv2"], C["wt"])
                                                 for (a, b) in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        ring.append((xx, yy))
            for (xx, yy) in ring:
                L.p(xx, yy, "ol")


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
    """一面屋顶：一垄垄筒瓦从檐口通到宝顶（越往上越挤），垄左亮右暗、垄沟深，一行行瓦压一道缝"""
    sv = RAMPS["sv"]
    done = {}
    NS, NT = 560, 460
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
                    idx -= 2 if base_idx > 1 else 1          # 垄沟
                elif fu < 0.34:
                    idx += 1                                 # 筒瓦左边受光
                elif fu > 0.72:
                    idx -= 1                                 # 筒瓦右边背光
                tc = t * 22
                if tc - math.floor(tc) < 0.14 and 0.14 <= fu <= 0.9:
                    idx -= 1                                 # 一节节瓦接缝
            if t > 0.8:
                idx -= 1 if (int(x) + int(y)) % 2 else 0
            done[key] = sv[max(0, min(len(sv) - 1, idx))]
    for (x, y), col in done.items():
        L.p(x, y, col)
    return done


def ridge_pts(ang, extra=0.0):
    tip = (PGX + RT * math.cos(math.radians(ang)), PGY + RT * math.sin(math.radians(ang)))
    th = HC + 0.08 + 0.62
    ha = HC + HR
    pts = []
    N = 160
    for i in range(-14, N + 1):
        t = i / N
        if t < 0:
            # 翼角往外、往上翘出去一截
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
    """戗脊：粗粗一道，上沿亮（白灰），身子深灰，到翼角往外往上挑出去，尖上一个卷"""
    pts = ridge_pts(ang)
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        w = 7 if i < n * 0.8 else (6 if i < n * 0.93 else 5)
        cols = ["ol", "wt", "sv2", "sv1", "sv0", "ik3", "ik2", "ik1", "ol"]
        cols = cols[:w + 1] + ["ol"]
        for k, col in enumerate(cols):
            L.p(x, y - 4 + k, col)
    x, y = pts[0]
    sg = -1 if x < PCX else 1
    for (dx, dy, col) in ((0, -5, "ol"), (sg, -6, "sv2"), (sg, -7, "sv1"), (2 * sg, -8, "sv2"), (2 * sg, -9, "ol"),
                          (sg, -8, "ol"), (3 * sg, -8, "ol"), (0, -6, "ol")):
        L.p(x + dx, y + dy, col)


def draw_pavilion():
    """出两张：pavilion_back（后排柱子、美人靠、后半圈栏杆，着地线 = 后柱脚）
    和 pavilion_front（前四根柱子、额枋挂落、前半圈栏杆、瓦顶、宝顶、檐角灯笼，着地线 = 台子前沿）"""
    B = Layer(620, 300, 344, 400)
    F = Layer(620, 300, 344, 400)
    # ---- 后面
    for ang in (120, 60):
        red_column(B, ang)
    # 美人靠：后三面
    for (a0, a1) in ((180, 120), (120, 60), (60, 0)):
        p0 = (PGX + RC * 0.98 * math.cos(math.radians(a0)), PGY + RC * 0.98 * math.sin(math.radians(a0)))
        p1 = (PGX + RC * 0.98 * math.cos(math.radians(a1)), PGY + RC * 0.98 * math.sin(math.radians(a1)))
        s0, s1 = scr(*p0), scr(*p1)
        steps = int(abs(s1[0] - s0[0])) + 1
        for k in range(steps + 1):
            t = k / steps
            x = s0[0] + (s1[0] - s0[0]) * t
            y = s0[1] + (s1[1] - s0[1]) * t
            for i, col in enumerate(("wd4", "wd3", "wd3", "wd2", "wd1", "wd1", "ol")):
                B.p(x, y - 22 + i, col)
            if int(x) % 4 == 0:
                for yy in range(int(y - 42), int(y - 22)):
                    B.p(x + (yy - (y - 42)) * 0.0, yy, "wd2")
            B.p(x, y - 43, "wd4")
            B.p(x, y - 42, "wd3")
            B.p(x, y - 44, "ol")
    for (a0, a1) in ((180, 120), (120, 60), (60, 0)):
        p0 = (PGX + (RP - 0.12) * math.cos(math.radians(a0)), PGY + (RP - 0.12) * math.sin(math.radians(a0)))
        p1 = (PGX + (RP - 0.12) * math.cos(math.radians(a1)), PGY + (RP - 0.12) * math.sin(math.radians(a1)))
        railing(B, p0, p1, h_top=0.62, h_low=0.2)
    # ---- 前面：先柱子
    for ang in (180, 0, 240, 300):
        red_column(F, ang)
    # 额枋、挂落、雀替：前三面
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
            # 挂落：一溜镂空木格（10 像素）
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
                        F.p(x, y + 5 + j, "rd2" if j < 10 - int(abs(t - 0.5) * 2 * 0) else "rd2")
        # 雀替：两头一小块红金三角
        for (sx, sy, sg) in ((s0[0], s0[1], 1), (s1[0], s1[1], -1)):
            for j in range(8):
                for i in range(8 - j):
                    F.p(sx + sg * (5 + i), sy + 5 + j, "rd3" if i < 2 else "rd2")
            F.p(sx + sg * 6, sy + 6, "gd3")
    # 前额枋挂一弧红绸、正中一朵绸花
    sA = pav(RC, 240, HC - 0.1)
    sB = pav(RC, 300, HC - 0.1)
    silk_swag(F, sA[0] + 6, sA[1] + 5, sB[0] - 6, sB[1] + 5, 7, 3)
    red_bow(F, (sA[0] + sB[0]) / 2, sA[1] + 4, 6)
    # 台子前半圈栏杆（正前面中间留桥口）
    gap0, gap1 = BRIDGE[-1][0] - BW / 2 - 0.05, BRIDGE[-1][0] + BW / 2 + 0.05
    for (a0, a1) in ((180, 240), (240, 300), (300, 360)):
        p0 = (PGX + (RP - 0.12) * math.cos(math.radians(a0)), PGY + (RP - 0.12) * math.sin(math.radians(a0)))
        p1 = (PGX + (RP - 0.12) * math.cos(math.radians(a1)), PGY + (RP - 0.12) * math.sin(math.radians(a1)))
        if (a0, a1) == (240, 300):
            railing(F, p0, (gap0, p0[1]), h_top=0.62, h_low=0.2)
            railing(F, (gap1, p1[1]), p1, h_top=0.62, h_low=0.2)
        else:
            railing(F, p0, p1, h_top=0.62, h_low=0.2)
    # ---- 瓦顶
    R = Layer(F.ox, F.oy, F.w, F.h)
    roof_face(R, 120, 180, 3, 9)           # 西北（左后，亮）
    roof_face(R, 0, 60, 1, 9)              # 东北（右后，暗）
    draw_ridge(R, 120)
    draw_ridge(R, 60)
    roof_face(R, 180, 240, 3, 10)          # 西南（左前，亮）
    roof_face(R, 300, 360, 1, 10)          # 东南（右前，暗）
    roof_face(R, 240, 300, 2, 12)          # 正前
    # 檐口：一排瓦当、滴水，下面一道红封檐板
    for (a0, a1) in ((180, 240), (240, 300), (300, 360)):
        nc = 12 if (a0, a1) == (240, 300) else 10
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
    # 宝顶
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
    # 檐角挂小红灯笼
    for ang in (180, 240, 300, 0):
        x, y, h = eave_pt(ang - 0.001, ang + 60, 0.0) if False else (PGX + RT * 0.93 * math.cos(math.radians(ang)),
                                                                        PGY + RT * 0.93 * math.sin(math.radians(ang)), HC + 0.5)
        sx, sy = scr(x, y, h)
        small_lantern(F, int(sx), int(sy) + 6)
    return B, F


# ================================================================== 桥栏杆（立着，一段一张）
def draw_bridge_rails():
    out = []
    n = len(BRIDGE) - 1
    names = ["A", "B", "C"]
    for i in range(n - 1):
        for side, E in (("L", BR_L), ("R", BR_R)):
            p0, p1 = E[i], E[i + 1]
            # 往桥里缩一点
            q0 = (p0[0] + (BRIDGE[i][0] - p0[0]) * 0.08, p0[1] + (BRIDGE[i][1] - p0[1]) * 0.08)
            q1 = (p1[0] + (BRIDGE[i + 1][0] - p1[0]) * 0.08, p1[1] + (BRIDGE[i + 1][1] - p1[1]) * 0.08)
            s0, s1 = scr(*q0), scr(*q1)
            L = Layer(min(s0[0], s1[0]) - 12, min(s0[1], s1[1]) - 60, abs(s1[0] - s0[0]) + 26, abs(s1[1] - s0[1]) + 66)
            railing(L, q0, q1, h_top=0.78, h_low=0.28, post_every=1.0)
            dx, dy = p1[0] - p0[0], p1[1] - p0[1]
            l = math.hypot(dx, dy)
            nx, ny = (-dy / l, dx / l) if side == "L" else (dy / l, -dx / l)
            front = ny < -0.05 or abs(ny) <= 0.05
            foot = int(max(s0[1], s1[1])) if front else int(min(s0[1], s1[1]))
            dname = {(0, "L"): "w", (0, "R"): "e", (1, "L"): "nw", (1, "R"): "se", (2, "L"): "sw", (2, "R"): "ne"}[(i, side)]
            out.append(("bridge_rail_%s_%s" % (names[i], dname), L.crop_to_content(), foot))
    return out


# ================================================================== 荷花（立着：出水的花、花苞、举起来的荷叶）
def lotus_flower(L, cx, cy):
    for (dx, dy, c) in ((-3, -6, "pk"), (-2, -7, "pk2"), (0, -8, "pk2"), (1, -8, "pk"), (2, -7, "pk2"), (3, -6, "pk"),
                        (-1, -7, "pk2"), (0, -7, "wt"), (1, -7, "pk2")):
        L.p(cx + dx, cy + dy, c)
    L.p(cx, cy - 9, "pk0")
    L.p(cx - 3, cy - 7, "pk0")
    L.p(cx + 3, cy - 7, "pk0")
    L.hl(cx - 2, cx + 3, cy - 5, "gd3")
    L.hl(cx - 2, cx + 3, cy - 4, "gd2")
    L.p(cx - 1, cy - 5, "gd4")
    for side in (-1, 1):
        for (dx, dy, c) in ((3, -5, "pk2"), (4, -5, "pk"), (5, -4, "pk"), (6, -4, "pk0"), (4, -4, "pk2"),
                            (3, -3, "wt"), (5, -3, "pk"), (6, -2, "pk0")):
            L.p(cx + side * dx, cy + dy, c if side < 0 or c != "pk2" else "pk")
    for (dx, dy, c) in ((-2, -3, "pk2"), (-1, -3, "wt"), (0, -3, "wt"), (1, -3, "pk2"), (2, -3, "pk"),
                        (-2, -2, "pk"), (-1, -2, "pk2"), (0, -2, "pk2"), (1, -2, "pk"), (2, -2, "pk0"),
                        (-1, -1, "pk"), (0, -1, "pk"), (1, -1, "pk0"), (0, 0, "pk0"),
                        (-4, -2, "pk"), (-3, -2, "pk2"), (3, -2, "pk"), (4, -2, "pk0"), (-3, -1, "pk0"), (3, -1, "pk0")):
        L.p(cx + dx, cy + dy, c)


def lotus_bud(L, cx, cy):
    for (dx, dy, c) in ((0, -7, "pk0"), (0, -6, "pk"), (-1, -5, "pk2"), (0, -5, "pk"), (1, -5, "pk0"),
                        (-1, -4, "pk2"), (0, -4, "pk"), (1, -4, "pk0"), (-1, -3, "pk"), (0, -3, "pk"), (1, -3, "pk0"),
                        (0, -2, "nl3"), (-1, -2, "nl2"), (1, -2, "nl1")):
        L.p(cx + dx, cy + dy, c)


def draw_lotus_stand(k):
    cx, cy, rx, ry = LOTUS[k]
    rnd = random.Random(cx * 7 + cy)
    L = Layer(cx - rx - 12, cy - ry - 40, 2 * rx + 24, 2 * ry + 50)
    spots = []
    for _ in range(int(rx / 11) + 3):
        spots.append((cx + rnd.uniform(-rx * 0.8, rx * 0.8), cy + rnd.uniform(-ry * 0.7, ry * 0.7)))
    spots.sort(key=lambda p: p[1])
    for j, (x, y) in enumerate(spots):
        x, y = int(x), int(y)
        kind = (0, 0, 1, 2)[j % 4]
        hgt = rnd.randint(8, 18)
        L.vl(x, y - hgt, y, "nl2")
        L.vl(x + 1, y - hgt + 2, y, "nl1")
        if kind == 0:
            lotus_flower(L, x, y - hgt)
        elif kind == 1:
            lotus_bud(L, x, y - hgt)
        else:
            L.ell(x - 8, y - hgt - 3, x + 9, y - hgt + 4, "nl2")
            L.ell(x - 7, y - hgt - 3, x + 4, y - hgt + 2, "nl3")
            L.ell(x - 3, y - hgt - 2, x + 3, y - hgt + 1, "gB")
            L.hl(x - 6, x + 8, y - hgt + 3, "nl1")
    L.outline("ol", pick=lambda x, y, nb: "gr0" if is_ramp(nb, "lf") or is_ramp(nb, "gr") else ("pk0" if nb in (C["pk"], C["pk2"], C["wt"]) else "ol"))
    foot = int(cy + ry * 0.7)
    return L.crop_to_content(), foot


# ================================================================== 篷船（立着）
def draw_boat(cx, wc):
    L = Layer(cx - 80, wc - 80, 160, 100)
    half_len = 62
    hw = 15
    pts_top = {}
    # 船帮（朝南那面）：船沿到水线
    for x in range(cx - half_len, cx + half_len + 1):
        u = (x - cx) / half_len
        w = hw * (1 - u * u) ** 0.55
        sheer = -8 * u ** 4
        rim_f = wc + w - 20 + sheer
        rim_b = wc - w - 20 + sheer
        water_f = wc + w * 0.8
        pts_top[x] = (rim_b, rim_f)
        # 舱里：舱底板
        for y in range(int(rim_b) + 1, int(rim_f)):
            col = "wd1" if (y - int(rim_b)) < 3 else "wd2"
            if x % 9 == 0:
                col = "wd1"
            L.p(x, y, col)
        # 船沿
        L.p(x, int(rim_b), "wd3")
        L.p(x, int(rim_f), "wd5")
        L.p(x, int(rim_f) + 1, "wd4")
        for y in range(int(rim_f) + 2, int(water_f) + 1):
            k = y - int(rim_f)
            col = "wd3" if k < 5 else ("wd2" if k < 11 else "wd1")
            if k in (6, 12):
                col = "wd1"
            L.p(x, y, col)
    # 船篷：中间一段，半圆的竹篷（编的），一道道篾条
    ca, cb = cx - 30, cx + 26
    for x in range(ca, cb):
        u = (x - cx) / half_len
        w = hw * (1 - u * u) ** 0.55
        sheer = -8 * u ** 4
        prev = None
        for it in range(0, 181):
            th = math.radians(it)
            dy = w * math.cos(th)
            hh = 20 + 30 * math.sin(th)
            y = int(round(wc + dy - hh + sheer))
            if prev is not None and y == prev:
                continue
            prev = y
            lit = it > 70
            col = "fl5" if lit else "fl3"
            if it > 110:
                col = "fl6"
            if ((x // 2) + (y // 2)) % 2 == 0:
                col = shift(col, -1)
            if (x - ca) % 8 == 0:
                col = "wd2"
            L.p(x, y, col)
        L.p(x, int(round(wc + w * math.cos(0) - 20 + sheer)), "wd1")
    # 篷两头的边
    for x in (ca, cb - 1):
        u = (x - cx) / half_len
        w = hw * (1 - u * u) ** 0.55
        for it in range(0, 181, 2):
            th = math.radians(it)
            L.p(x, wc + w * math.cos(th) - 20 - 30 * math.sin(th) - 8 * u ** 4, "wd1")
    L.outline("ol")
    # 船头一朵小红绸
    bx = cx - half_len + 6
    L.p(bx, wc - 24, "rd4")
    L.p(bx + 1, wc - 24, "rd3")
    L.p(bx - 1, wc - 23, "rd3")
    L.p(bx + 1, wc - 23, "rd2")
    L.p(bx, wc - 22, "rd2")
    L.p(bx + 2, wc - 21, "rd2")
    return L.crop_to_content()


# ================================================================== 组装
def build_stands():
    """所有立着的东西：[(name, Layer, foot_y)]"""
    out = []
    out.append(("wall_gate", draw_wall(), WALL_Y))
    for i, (x, y) in enumerate(LANTERNS):
        out.append(("lantern_%d" % (i + 1), draw_stone_lantern(x, y), y))
    rocks = [(606, 908, 26, 74, 1), (1004, 922, 24, 66, 2), (590, 1116, 28, 70, 3), (236, 902, 20, 52, 4), (1290, 924, 24, 60, 5)]
    for i, (x, y, w, h, s) in enumerate(rocks):
        out.append(("rock_%d" % (i + 1), draw_rock(x, y, w, h, s * 13), y))
    bushes = [
        # 桥头两边粉花
        (698, 808, 22, "pink"), (842, 808, 24, "pink"),
        # 灯笼后面、北段路两边
        (640, 832, 22, None), (906, 834, 24, None), (598, 814, 20, "white"), (950, 820, 20, None),
        (556, 838, 18, None), (992, 840, 22, "white"),
        # 小广场南边、南段路两边的大圆球、白花
        (662, 940, 30, None), (876, 942, 32, None), (580, 950, 24, "white"), (962, 960, 26, "white"),
        # 墙里贴着墙（从墙头冒出来）
        (618, 1002, 24, None), (922, 1006, 26, "pink"), (520, 992, 22, None), (1022, 998, 22, "white"),
        (700, 1014, 18, None), (842, 1016, 20, None),
        # 左边园子
        (520, 872, 20, None), (300, 962, 26, None), (380, 1002, 22, "white"), (150, 982, 26, None),
        (60, 882, 32, "pink"), (250, 1012, 24, "pink"),
        # 右边园子
        (1042, 888, 20, None), (1240, 988, 26, None), (1180, 1006, 22, None), (1384, 1004, 26, "white"),
        (1490, 902, 32, "pink"), (1330, 1018, 22, "pink"),
        # 墙外（南边）：贴着墙脚一排大花木，压住墙的下半截（参考图那样），往南零散几丛
        (660, 1066, 30, None), (882, 1068, 32, None), (582, 1074, 28, "pink"), (962, 1076, 30, "pink"),
        (502, 1064, 26, None), (1040, 1066, 28, "white"), (420, 1072, 30, None), (1122, 1072, 30, None),
        (340, 1066, 26, "white"), (1202, 1068, 28, "pink"), (1290, 1072, 30, None), (1380, 1078, 30, None),
        (1462, 1068, 26, "white"), (80, 1072, 28, None), (180, 1078, 30, "pink"),
        (1480, 1172, 28, "pink"), (60, 1152, 26, None), (690, 1250, 22, None),
        (850, 1242, 24, "white"), (600, 1200, 24, None), (950, 1212, 26, None), (1100, 1232, 28, None),
        (400, 1242, 30, "pink"), (1210, 1160, 26, None), (500, 1160, 24, "white"),
        (620, 1140, 20, "pink"), (920, 1146, 22, None), (1010, 1180, 18, "white"), (540, 1236, 20, None),
        (1440, 1250, 26, None), (300, 1172, 22, "white"), (130, 1220, 26, "pink"), (980, 1262, 22, "pink"),
        # 广场两头、灯笼脚下一溜矮花丛
        (548, 900, 13, "white"), (1022, 904, 14, "white"), (700, 848, 11, "pink"), (838, 848, 11, "white"),
        (690, 902, 12, None), (846, 904, 12, "pink"), (612, 864, 13, "pink"), (936, 866, 13, None),
        (734, 1022, 12, "white"), (806, 1024, 12, "pink"), (470, 940, 16, None), (1074, 944, 16, None),
        (520, 812, 16, "pink"), (1020, 812, 16, None), (760, 784, 10, None) if False else (990, 800, 14, "pink"),
    ]
    for i, (x, y, r, fl) in enumerate(bushes):
        out.append(("bush_%02d" % (i + 1), bush(x, y, r, 500 + i, fl).crop_to_content(), y))
    for i, (x, y) in enumerate(BANYANS):
        out.append(("banyan_%d" % (i + 1), draw_banyan(x, y, 900 + i, flip=(-1 if i == 0 else 1), crx=158, lean=40).crop_to_content(), y))
    for i, (x, y) in enumerate(WILLOWS):
        out.append(("willow_%d" % (i + 1), draw_willow(x, y, 700 + i).crop_to_content(), y))
    out.append(("tree_fg_w", draw_banyan(250, 1236, 950, flip=1, crx=190, cry=84, ch=220).crop_to_content(), 1236))
    out.append(("pine_e", draw_pine(1330, 990, 960).crop_to_content(), 990))
    out.append(("tree_fg_e", draw_banyan(1290, 1262, 970, flip=1, crx=150, cry=70, ch=196, roots=26, lean=10).crop_to_content(), 1262))
    B, F = draw_pavilion()
    out.append(("pavilion_back", B.crop_to_content(), int(pav(RC, 90)[1])))
    out.append(("pavilion_front", F.crop_to_content(), int(scr(PGX, PGY - RP * 0.866)[1])))
    out.extend(draw_bridge_rails())
    for k in range(len(LOTUS)):
        L, foot = draw_lotus_stand(k)
        out.append(("lotus_%d" % (k + 1), L, foot))
    out.append(("boat", draw_boat(*BOAT), BOAT[1] + 15))
    return out


def build_shade(stands):
    S = Shade()
    for (name, L, foot) in stands:
        if name.startswith("banyan") or name.startswith("tree_fg"):
            fx = L.ox + L.w // 2
            S.blob(fx + 36, foot - 8, L.w * 0.42, 40, -1.5, seed=len(name))
            S.blob(fx + 20, foot - 2, 40, 12, -1.0, seed=3)
        elif name.startswith("willow"):
            fx = L.ox + L.w // 2
            S.blob(fx + 26, foot - 4, 70, 22, -1.5, seed=4)
        elif name.startswith("bush"):
            S.blob(L.ox + L.w * 0.6, foot - 1, L.w * 0.5, 5, -1.5, seed=foot)
        elif name.startswith("lantern") or name.startswith("rock"):
            S.blob(L.ox + L.w * 0.62, foot - 1, L.w * 0.48, 5, -1.5, seed=foot)
        elif name == "pine_e":
            S.blob(L.ox + L.w * 0.6, foot - 6, 70, 18, -1.5, seed=9)
        elif name == "wall_gate":
            for x in range(W):
                for y in range(WALL_Y, WALL_Y + 9):
                    if not (GATE_C[0] - 50 < x < GATE_C[0] + 50) or y > WALL_Y + 4:
                        S.v[(x, y)] = -1.5 if y < WALL_Y + 6 else -0.5
        elif name == "boat":
            S.blob(L.ox + L.w * 0.55, foot + 4, L.w * 0.5, 7, -1.0, seed=2)
    # 亭子、桥在水上的影子（往右下）
    for y in range(int(scr(0, PGY + RP)[1]) + 10, int(scr(0, PGY - RP)[1]) + 34):
        for x in range(int(scr(PGX + RP, 0)[0]) - 30, int(scr(PGX + RP, 0)[0]) + 22):
            gx, gy = gnd(x - 18, y - 30)
            if in_platform(gx, gy):
                S.v[(x, y)] = min(S.v.get((x, y), 0), -1.0)
    return S


def paste_clip(out, im, x, y):
    tmp = Image.new("RGBA", out.size, (0, 0, 0, 0))
    tmp.paste(im, (x, y))
    out.alpha_composite(tmp)


def put_layer(out, L):
    if L.ox >= 0 and L.oy >= 0 and L.ox + L.w <= out.width and L.oy + L.h <= out.height:
        out.alpha_composite(L.im, (L.ox, L.oy))
    else:
        paste_clip(out, L.im, L.ox, L.oy)


def compose(BG, stands, people=()):
    out = BG.im.copy()
    seq = [(foot, 0, L.ox, L) for (name, L, foot) in stands]
    for (im, x, y) in people:
        seq.append((y, 1, x, (im, x, y)))
    seq.sort(key=lambda t: (t[0], t[1], t[2]))
    for (foot, kind, fx, L) in seq:
        if kind == 0:
            put_layer(out, L)
        else:
            im, x, y = L
            paste_clip(out, im, x - 32, y - 84)
    return out


def guest(n, frame=0):
    im = Image.open(os.path.join(CHAR_DIR, "chr_LM-GUEST-%02d.png" % n)).convert("RGBA")
    return im.crop((frame * 64, 0, frame * 64 + 64, 84))


def palette_check(im, name):
    used = set()
    for cnt, c in im.getcolors(1 << 22):
        if c[3] not in (0, 255):
            raise SystemExit("%s 有半透明像素 %s" % (name, c))
        if c[3] == 255:
            if c not in PAL_SET:
                raise SystemExit("%s 有调色板外的颜色 %s" % (name, c))
            used.add(c)
    return used


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else None
    os.makedirs(LAYER_DIR, exist_ok=True)
    stands = build_stands()
    BK, BK0 = build_backdrop()
    BG = Layer(0, 0, W, H)
    BG.paste(BK)
    names = dict((n, (L, f)) for (n, L, f) in stands)
    pf = Layer(0, 0, W, H)
    pf.paste(names["pavilion_back"][0])
    pf.paste(names["pavilion_front"][0])
    refl = [(pf, scr(PGX, PGY)[1] + 24, 0.5), (names["boat"][0], BOAT[1] + 2, 0.5)]
    paint_water(BG, BK, BK0, refl)
    paint_ground(BG)
    paint_lotus_pads(BG)
    paint_bridge_and_platform(BG)
    build_shade(stands).apply(BG)
    # 船边水纹
    for x in range(BOAT[0] - 66, BOAT[0] + 70):
        y = BOAT[1] + 14 + int(2 * math.sin(x * 0.3))
        if is_water(x, y) and (x // 3) % 2 == 0:
            BG.p(x, y, "bl3")
    used = palette_check(BG.im, "bg")
    for (n, L, f) in stands:
        used |= palette_check(L.im, n)
    full = compose(BG, stands)
    used |= palette_check(full, "full")
    # 出图
    BG.im.save(os.path.join(LAYER_DIR, "bg_lake_east.png"))
    meta = {"note": "draw_lake_ref2.py 生成，别手改。底图 bg 先画；其余是立着的，按 foot_y 跟人排前后（同一条着地线照 x 排）。坐标是画布坐标，1 倍不插值。",
            "canvas": [W, H], "base": {"png": "bg_lake_east.png", "x": 0, "y": 0}, "layers": []}
    for (n, L, f) in stands:
        L.im.save(os.path.join(LAYER_DIR, n + ".png"))
        meta["layers"].append({"name": n, "png": n + ".png", "x": L.ox, "y": L.oy, "w": L.w, "h": L.h, "foot_y": f, "kind": "stand"})
    with open(os.path.join(LAYER_DIR, "layers.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=1)
    full.save(os.path.join(HERE, "lake_ref2_full.png"))
    people = [(guest(5, 0), 748, 874), (guest(3, 0), 800, 645)]
    full_p = compose(BG, stands, people)
    phone = full_p.crop(PHONE)
    phone.save(os.path.join(HERE, "lake_ref2_phone.png"))
    ref = Image.open(REF).convert("RGBA")
    rw = int(ref.width * 960 / ref.height)
    ref_s = ref.resize((rw, 960), Image.LANCZOS)
    vs = Image.new("RGBA", (rw + 16 + 540, 960), (34, 20, 15, 255))
    vs.paste(ref_s, (0, 0))
    vs.paste(phone, (rw + 16, 0))
    vs.save(os.path.join(HERE, "lake_ref2_vs.png"))
    if tag:
        full.save(os.path.join(HERE, tag + ".png"))
        phone.save(os.path.join(HERE, tag + "_phone.png"))
        vs.save(os.path.join(HERE, tag + "_vs.png"))
    print("用色 %d / 64" % len(used))


if __name__ == "__main__":
    main()
