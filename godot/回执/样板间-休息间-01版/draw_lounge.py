#!/usr/bin/env python3
"""lounge01：用代码画后厅休息间（像素硬边、1 倍颗粒、≤64 色）。

只读：layout.json（位置）、人物图（当尺子）、02 的整块截图（对照用）。
只写：本脚本所在目录。
用法：python3 draw_lounge.py [roundN]   → 出 lounge01_room*.png / compare / phone，给了 roundN 就再存一张 roundN.png（放大 2 倍）

坐标全用游戏画布坐标（1536×1024 那块画布），1 个美术像素 = 1 个画布像素。
斜俯视、没有透视：地面前后 1 米 = 32 像素，左右和高 1 米 = 48 像素。
一件东西 = 占地（x0..x1, yf0..yf1）+ 高 z；顶面画在 y = yf - z，正面从 yf1 - z1 到 yf1 - z0。
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件"
LAYOUT = REPO + "/.claude/worktrees/guests-main/godot/assets/layered/scene_luoman_backhall/layout.json"
CHAR_DIR = REPO + "/godot/assets/characters/lm/"
FULL_02 = REPO + "/.claude/worktrees/guests-main/godot/回执/样板间-休息间/后厅-整块-连厨房.png"

# 整间出图的范围（画布坐标）
X0, Y0, X1, Y1 = 328, 100, 680, 700
W, H = X1 - X0, Y1 - Y0

# ------------------------------------------------------------------ 调色板
# 每种材料一条色带（暗 → 亮），暗部往红紫偏、亮部往黄偏
PAL_HEX = {
    "ol": "#22140f", "void": "#2b1e18",
    "wd0": "#3a2218", "wd1": "#552f1f", "wd2": "#71402a", "wd3": "#8f5535", "wd4": "#ad6d40", "wd5": "#c98d58",
    "fl0": "#5a3e2e", "fl1": "#765238", "fl2": "#8e6846", "fl3": "#a67c54", "fl4": "#ba8e60", "fl5": "#c89e6c",
    "fl6": "#d6b07e", "fl7": "#e6c696",
    "wl0": "#977a60", "wl1": "#b69a79", "wl2": "#d0b892", "wl3": "#e2cca6", "wl4": "#efdfc0", "wl5": "#f9efda",
    "rd0": "#3d0e13", "rd1": "#62181b", "rd2": "#8a2321", "rd3": "#b1332a", "rd4": "#d24f39", "rd5": "#ea8152",
    "gd0": "#563610", "gd1": "#87591c", "gd2": "#b8862b", "gd3": "#deb550", "gd4": "#f7e09a",
    "gr0": "#1b3022", "gr1": "#284a2c", "gr2": "#3f6935", "gr3": "#649340", "gr4": "#9cbd5e",
    "bl0": "#19223d", "bl1": "#243863", "bl2": "#385a90", "bl3": "#6c8fbd", "bl4": "#b0c6de",
    "wt": "#fdfbf3",
    "ik0": "#110f15", "ik1": "#201c26", "ik2": "#34303d", "ik3": "#554e60",
    "pk": "#de8399", "tl": "#2c7a74", "tl2": "#5aaa9b", "pu": "#5a3c7a", "or": "#dd7a2c",
    "cl0": "#682d1e", "cl1": "#97472b", "cl2": "#bf653d", "cl3": "#db8d5f",
}


def hex2rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


C = {k: hex2rgba(v) for k, v in PAL_HEX.items()}
RAMPS = {
    "wd": ["wd0", "wd1", "wd2", "wd3", "wd4", "wd5"],
    "fl": ["fl0", "fl1", "fl2", "fl3", "fl4", "fl5", "fl6", "fl7"],
    "wl": ["wl0", "wl1", "wl2", "wl3", "wl4", "wl5"],
    "rd": ["rd0", "rd1", "rd2", "rd3", "rd4", "rd5"],
    "gd": ["gd0", "gd1", "gd2", "gd3", "gd4"],
    "gr": ["gr0", "gr1", "gr2", "gr3", "gr4"],
    "bl": ["bl0", "bl1", "bl2", "bl3", "bl4", "wt"],
    "ik": ["ik0", "ik1", "ik2", "ik3"],
    "cl": ["cl0", "cl1", "cl2", "cl3"],
    "tl": ["tl", "tl2"],
}
RAMP_OF = {}
for rn, names in RAMPS.items():
    for i, n in enumerate(names):
        RAMP_OF[C[n]] = (rn, i)


def shift(col, k):
    """颜色沿自己的色带挪 k 档（负数变暗），不在色带里的不动"""
    c = C[col] if isinstance(col, str) else col
    if k == 0 or c not in RAMP_OF:
        return c
    rn, i = RAMP_OF[c]
    names = RAMPS[rn]
    return C[names[max(0, min(len(names) - 1, i + k))]]


def rname(ramp, i):
    names = RAMPS[ramp]
    return names[max(0, min(len(names) - 1, i))]


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


# ------------------------------------------------------------------ 画布
class Layer:
    """一层透明画布，用画布坐标画；每个像素要么全不透明要么全透明"""

    def __init__(self, x0=X0, y0=Y0, w=W, h=H):
        self.ox, self.oy, self.w, self.h = x0, y0, w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
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
        """实心椭圆，外接框 x0..x1、y0..y1（不含右下）；only(x, y) 可以再挑一部分"""
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        rx, ry = (x1 - x0) / 2.0, (y1 - y0) / 2.0
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0 and (only is None or only(x, y)):
                    self.p(x, y, col)

    def ring(self, x0, y0, x1, y1, col, only=None):
        """椭圆的一圈边（1 像素）"""
        tmp = set()
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        rx, ry = (x1 - x0) / 2.0, (y1 - y0) / 2.0
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    tmp.add((x, y))
        for (x, y) in tmp:
            if ((x + 1, y) not in tmp or (x - 1, y) not in tmp or (x, y + 1) not in tmp or (x, y - 1) not in tmp) \
                    and (only is None or only(x, y)):
                self.p(x, y, col)

    def poly(self, pts, col):
        d = ImageDraw.Draw(self.im)
        d.polygon([(x - self.ox, y - self.oy) for x, y in pts], fill=self.c(col))

    def line(self, x0, y0, x1, y1, col):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
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

    def shade_rect(self, x0, y0, x1, y1, k):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.shade_px(x, y, k)

    def outline(self, col="ol", skip=None):
        """不透明区外面一圈 1 像素描边"""
        ring = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[nx, ny][3]:
                        ring.append((x, y))
                        break
        cc = self.c(col)
        for x, y in ring:
            if skip and skip(x + self.ox, y + self.oy):
                continue
            self.px[x, y] = cc
        return self

    def paste(self, other):
        self.im.alpha_composite(other.im, (other.ox - self.ox, other.oy - self.oy))


class ShadeMap:
    """明暗图：每个像素一个数（负 = 暗、正 = 亮），最后按 4×4 点阵取整、沿色带挪档"""

    def __init__(self):
        self.v = [[0.0] * W for _ in range(H)]

    def add(self, x, y, val):
        x -= X0
        y -= Y0
        if 0 <= x < W and 0 <= y < H:
            self.v[y][x] += val

    def rect(self, x0, y0, x1, y1, val, feather=0):
        """矩形，feather 是往外渐淡几像素"""
        for y in range(int(y0) - feather, int(y1) + feather):
            for x in range(int(x0) - feather, int(x1) + feather):
                dx = max(x0 - x - 0.5, x + 0.5 - x1, 0)
                dy = max(y0 - y - 0.5, y + 0.5 - y1, 0)
                d = max(dx, dy)
                if feather == 0:
                    f = 1.0 if d == 0 else 0.0
                else:
                    f = max(0.0, 1.0 - d / (feather + 0.5))
                if f > 0:
                    self.add(x, y, val * f)

    def ellipse(self, cx, cy, rx, ry, val, edge=1.5):
        """椭圆：里面整档，最外 edge 像素那一圈只给一半（取整后是一圈棋盘点），边干净不发毛"""
        rm = (rx + ry) / 2.0
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                d = math.sqrt(dx * dx + dy * dy)
                if d >= 1.0:
                    continue
                f = 1.0 if (1.0 - d) * rm > edge else 0.5
                self.add(x, y, val * f)

    def apply(self, layer, step=0.5, clip=None):
        """取整到半档：整档直接挪，半档用棋盘格（只有 0 / 50% / 100% 三种，点阵干净）"""
        for y in range(H):
            row = self.v[y]
            for x in range(W):
                s = row[x]
                if abs(s) < 0.2:
                    continue
                wx, wy = x + X0, y + Y0
                if clip and not clip(wx, wy):
                    continue
                s = round(s / step) * step
                k = math.floor(s)
                if s - k > 0.25 and (wx + wy) % 2 == 0:
                    k += 1
                if k:
                    layer.shade_px(wx, wy, k)


# ------------------------------------------------------------------ 布局
def load_items():
    d = json.load(open(LAYOUT, encoding="utf-8"))
    return {it["id"]: it for it in d["items"] if "id" in it}


IT = load_items()


# 这版用到的灰盒位置（画布坐标 rect + 高 h）。家具是一件件手画的，位置照这张表；
# 跑的时候先跟 layout.json 对一遍，摆法改了就停下来报哪件变了，不会悄悄画歪
USED = {
    "vinyl_wall": ([352, 226, 496, 232], 115), "record_player": ([396, 258, 452, 284], 28),
    "luggage_1": ([356, 280, 380, 290], 36), "luggage_2": ([636, 640, 655, 648], 26),
    "sofa_back": ([516, 236, 617, 244], 41), "sofa": ([516, 244, 617, 268], 20),
    "tea_table": ([538, 296, 596, 314], 22), "armchair_w": ([480, 292, 523, 320], 41),
    "armchair_e": ([604, 292, 647, 320], 41), "tv_unit": ([636, 360, 660, 418], 24),
    "floor_lamp": ([624, 252, 634, 260], 77), "plant": ([350, 656, 370, 668], 16),
    "wall_1": ([331, 226, 341, 684], 44), "wall_2": ([667, 226, 677, 684], 44),
    "front_2": ([208, 684, 464, 696], 22), "front_3": ([544, 684, 800, 696], 22),
}


def check_layout():
    bad = []
    for iid, (rect, h) in USED.items():
        it = IT.get(iid)
        if it is None or list(it.get("rect", [])) != rect or it.get("h") != h:
            bad.append("%s：脚本 %s h%s，布局 %s h%s" % (iid, rect, h, it and it.get("rect"), it and it.get("h")))
    if bad:
        raise SystemExit("layout.json 跟这版画的位置对不上：\n" + "\n".join(bad))


# 墙（画布坐标）
CAP_Y0, CAP_Y1 = 104, 114          # 北墙墙顶（剖开的厚度）
FLOOR_Y = 226                      # 北墙脚 = 地板开始
WALL_W = (331, 341)                # 西隔墙
WALL_E = (667, 677)                # 东隔墙
FRONT_TOP, FRONT_FACE, FRONT_BOT = 662, 674, 696   # 前沿矮墙：顶面 662..674，正面 674..696
DOOR = (464, 544)                  # 门洞


# ================================================================== 背景：墙、地板、地毯
def draw_north_wall(L):
    x0, x1 = WALL_W[0], WALL_E[1]
    # 墙面：墙纸
    L.rect(x0, CAP_Y1, x1, FLOOR_Y, "wl3")
    for y in range(CAP_Y1 + 5, 176):
        for x in range(x0, x1):
            # 墙纸暗花：半错位的空心小菱形（一行 12 像素、一列 12 像素），不用十字（像字）
            gy = (y - 119) % 12
            gx = ((x - x0) + (6 if ((y - 119) // 12) % 2 else 0)) % 12
            d = abs(gx - 6) + abs(gy - 6)
            if d == 2:
                L.p(x, y, "wl2")
    # 细竖条：每 20 像素一条更浅的
    for x in range(x0 + 7, x1, 20):
        for y in range(CAP_Y1 + 5, 176):
            if L.g(x, y) == C["wl3"]:
                L.p(x, y, "wl4")
    # 顶线脚（木）
    L.hl(x0, x1, 114, "wd1")
    L.hl(x0, x1, 115, "wd4")
    L.hl(x0, x1, 116, "wd3")
    L.hl(x0, x1, 117, "wd3")
    L.hl(x0, x1, 118, "wd1")
    L.hl(x0, x1, 119, "wl1")                 # 线脚底下一条影
    L.hl(x0, x1, 120, "wl2")
    # 腰线
    L.hl(x0, x1, 176, "wl1")
    L.hl(x0, x1, 177, "wd4")
    L.hl(x0, x1, 178, "wd3")
    L.hl(x0, x1, 179, "wd2")
    L.hl(x0, x1, 180, "wd1")
    # 护墙板：一格一格凸起的板
    L.rect(x0, 181, x1, 218, "wd2")
    px0 = x0 + 4
    while px0 < x1 - 4:
        pw = 22
        a, b = px0, min(px0 + pw, x1 - 3)
        L.rect(a, 184, b, 215, "wd3")
        L.hl(a, b, 184, "wd4")
        L.vl(a, 184, 215, "wd4")
        L.hl(a, b, 214, "wd1")
        L.vl(b - 1, 185, 215, "wd1")
        # 板心再凸一层
        L.rect(a + 3, 187, b - 3, 212, "wd3")
        L.hl(a + 3, b - 3, 187, "wd1")
        L.vl(a + 3, 187, 212, "wd1")
        L.hl(a + 3, b - 3, 211, "wd4")
        L.vl(b - 4, 188, 212, "wd4")
        px0 += pw + 4
    L.hl(x0, x1, 181, "wd1")                 # 腰线下的影
    # 踢脚线
    L.hl(x0, x1, 218, "wd4")
    L.rect(x0, 219, x1, 225, "wd1")
    L.hl(x0, x1, 219, "wd2")
    L.hl(x0, x1, 225, "wd0")
    # 墙顶：剖开的厚度（浅色一条，上下描边）
    L.rect(x0, CAP_Y0, x1, CAP_Y1, "wl4")
    L.hl(x0, x1, CAP_Y0, "ol")
    L.hl(x0, x1, CAP_Y0 + 1, "wl5")
    L.hl(x0, x1, CAP_Y1 - 1, "ol")


def draw_floor(L):
    """横铺木地板：一排 7 像素（1 行缝 + 6 行板），板长 1～2 米错缝；
    颜色两档为主、偶尔一块浅的或深的；木纹是顺着板的细暗线，少量节疤；只有一部分板头有一小段倒角高光"""
    rnd = random.Random(20261003)
    x0, x1 = WALL_W[0], WALL_E[1]
    y = FLOOR_Y
    prev_joints = []
    while y < Y1:
        L.hl(x0, x1, y, "fl2")                       # 板缝
        x = x0 - rnd.randrange(0, 70)
        joints = []
        last_tone = None
        while x < x1:
            ln = rnd.randrange(52, 112)
            # 接缝别跟上一排太近（错缝）
            for j in prev_joints:
                if abs(x + ln - j) < 10:
                    ln += 14
            tone = rnd.choice([4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 6])
            if tone == last_tone:
                tone = 5 if tone == 4 else 4
            last_tone = tone
            base = "fl%d" % tone
            a, b = max(x, x0), min(x + ln, x1)
            if b > a:
                L.rect(a, y + 1, b, y + 7, base)
                # 倒角高光：约四成的板，板头往后一小段
                if rnd.random() < 0.4:
                    L.hl(a + 1, min(b, a + rnd.randrange(8, 30)), y + 1, "fl%d" % min(7, tone + 1))
                # 木纹：1～2 条细长暗线，偶尔拐一格
                for _ in range(rnd.randrange(1, 3)):
                    gy = y + rnd.randrange(2, 6)
                    gx = a + rnd.randrange(0, max(1, b - a - 8))
                    gl = rnd.randrange(8, 30)
                    for k in range(gl):
                        xx = gx + k
                        if xx >= b - 1:
                            break
                        if rnd.random() < 0.85:
                            L.p(xx, gy, "fl%d" % (tone - 1))
                        if rnd.random() < 0.07:
                            gy = max(y + 2, min(y + 6, gy + rnd.choice([-1, 1])))
                # 节疤
                if rnd.random() < 0.07 and b - a > 14:
                    kx = rnd.randrange(a + 4, b - 5)
                    ky = y + rnd.randrange(3, 5)
                    L.p(kx, ky, "fl%d" % (tone - 2))
                    L.p(kx + 1, ky, "fl%d" % (tone - 2))
                    for (dx, dy) in ((-1, 0), (2, 0), (0, -1), (1, 1)):
                        L.p(kx + dx, ky + dy, "fl%d" % (tone - 1))
                # 板头接缝（左边一列暗、右边一列亮一点 = 有缝有倒角）
                if x >= x0:
                    L.vl(x, y + 1, y + 7, "fl2")
                    joints.append(x)
            x += ln
        prev_joints = joints
        y += 7


# 回纹：一个单元 8×7，1 = 画纹的颜色
KEY = [
    "11111110",
    "10000010",
    "10111010",
    "10101010",
    "10100010",
    "10111110",
    "10000000",
]


def draw_rug(L):
    rx0, ry0, rx1, ry1 = 470, 250, 658, 342
    # 底：红
    L.rect(rx0, ry0, rx1, ry1, "rd3")
    # 地毯纹：菱形格
    for y in range(ry0 + 13, ry1 - 13):
        for x in range(rx0 + 13, rx1 - 13):
            u = (x - rx0) % 12
            v = ((y - ry0) * 3 // 2) % 12
            if u == v or u == 11 - v:
                L.p(x, y, "rd2")
            if (u, v) in ((0, 0), (6, 6)):
                L.p(x, y, "gd2")
    # 中心团花（大半被茶几挡住，露边）
    cx, cy = (rx0 + rx1) // 2, (ry0 + ry1) // 2
    L.ell(cx - 34, cy - 20, cx + 34, cy + 20, "rd2")
    L.ell(cx - 30, cy - 17, cx + 30, cy + 17, "rd4")
    L.ring(cx - 30, cy - 17, cx + 30, cy + 17, "gd3")
    L.ell(cx - 18, cy - 10, cx + 18, cy + 10, "rd3")
    L.ring(cx - 18, cy - 10, cx + 18, cy + 10, "gd2")
    # 边：外线、米色带、回纹带、里线
    L.rect(rx0, ry0, rx1, ry0 + 12, "gd3")
    L.rect(rx0, ry1 - 12, rx1, ry1, "gd3")
    L.rect(rx0, ry0, rx0 + 12, ry1, "gd3")
    L.rect(rx1 - 12, ry0, rx1, ry1, "gd3")
    # 横边回纹
    for (by, flip) in ((ry0 + 3, False), (ry1 - 10, True)):
        for x in range(rx0 + 3, rx1 - 3):
            for r in range(7):
                row = KEY[6 - r] if flip else KEY[r]
                if row[(x - rx0 - 3) % 8] == "1":
                    L.p(x, by + r, "rd2")
    # 竖边回纹（转 90 度）
    for (bx, flip) in ((rx0 + 3, False), (rx1 - 10, True)):
        for y in range(ry0 + 10, ry1 - 10):
            for c in range(7):
                row = KEY[6 - c] if flip else KEY[c]
                if row[(y - ry0) % 8] == "1":
                    L.p(bx + c, y, "rd2")
    for (a, b) in ((0, 1), (11, 12)):
        L.rect(rx0 + a, ry0 + a, rx1 - a, ry0 + b, "rd1")
        L.rect(rx0 + a, ry1 - b, rx1 - a, ry1 - a, "rd1")
        L.rect(rx0 + a, ry0 + a, rx0 + b, ry1 - a, "rd1")
        L.rect(rx1 - b, ry0 + a, rx1 - a, ry1 - a, "rd1")
    # 两头流苏
    for y in range(ry0 + 1, ry1 - 1):
        if y % 2 == 0:
            L.p(rx0 - 1, y, "wl4")
            L.p(rx0 - 2, y, "wl3")
            L.p(rx1, y, "wl4")
            L.p(rx1 + 1, y, "wl3")


def draw_painting(L):
    """沙发上方一幅山水：金框、米色衬纸、远山近山、一轮红日"""
    x0, y0, x1, y1 = 541, 128, 591, 164
    L.rect(x0, y0, x1, y1, "gd2")
    L.hl(x0, x1, y0, "gd4")
    L.vl(x0, y0, y1, "gd3")
    L.hl(x0, x1, y1 - 1, "gd0")
    L.vl(x1 - 1, y0, y1, "gd1")
    L.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "gd1")
    L.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "wl4")
    ix0, iy0, ix1, iy1 = x0 + 5, y0 + 5, x1 - 5, y1 - 5
    L.rect(ix0, iy0, ix1, iy1, "wl5")
    # 天：上面一点点暖
    for y in range(iy0, iy0 + 6):
        for x in range(ix0, ix1):
            if (x + y) % 2 == 0 and y < iy0 + 3:
                L.p(x, y, "gd4")
    # 红日
    L.ell(ix1 - 12, iy0 + 3, ix1 - 5, iy0 + 10, "rd4")
    # 远山
    pts = [(ix0, iy1 - 9), (ix0 + 8, iy0 + 9), (ix0 + 13, iy0 + 12), (ix0 + 19, iy0 + 6), (ix0 + 27, iy0 + 13),
           (ix1, iy0 + 11), (ix1, iy1), (ix0, iy1)]
    L.poly(pts, "bl3")
    # 近山
    pts2 = [(ix0, iy1 - 4), (ix0 + 6, iy1 - 11), (ix0 + 12, iy1 - 7), (ix0 + 22, iy1 - 14), (ix0 + 32, iy1 - 6),
            (ix1, iy1 - 9), (ix1, iy1), (ix0, iy1)]
    L.poly(pts2, "gr2")
    for x in range(ix0, ix1):          # 山脊受光
        for y in range(iy0, iy1):
            if L.g(x, y) == C["gr2"] and L.g(x, y - 1) != C["gr2"]:
                L.p(x, y, "gr3")
            if L.g(x, y) == C["bl3"] and L.g(x, y - 1) not in (C["bl3"], C["gr2"]):
                L.p(x, y, "bl4")
    # 雾
    L.hl(ix0, ix1, iy1 - 8, "wl5")
    for x in range(ix0, ix1, 3):
        L.p(x, iy1 - 7, "wl5")
    # 墙上的影（右、下）
    L.vl(x1, y0 + 2, y1 + 1, "wl1")
    L.hl(x0 + 2, x1 + 1, y1, "wl1")


def draw_clock(L):
    """东北角一只挂钟：圆钟面 + 下面一个钟摆小窗（不画数字）"""
    cx = 651
    x0, x1 = cx - 7, cx + 8
    # 钟身
    L.rect(x0 + 1, 133, x1 - 1, 160, "wd3")
    L.vl(x0 + 1, 133, 160, "wd4")
    L.vl(x1 - 2, 133, 160, "wd1")
    L.hl(x0 + 1, x1 - 1, 159, "wd1")
    L.rect(x0, 158, x1, 161, "wd2")
    L.hl(x0, x1, 158, "wd4")
    # 钟摆窗
    L.rect(cx - 3, 145, cx + 4, 156, "ik1")
    L.vl(cx - 3, 145, 156, "ik2")
    L.vl(cx, 145, 152, "gd2")
    L.ell(cx - 2, 151, cx + 3, 155, "gd3")
    L.p(cx - 1, 152, "gd4")
    # 圆钟面
    L.ell(x0, 120, x1, 135, "wd2")
    L.ell(x0 + 1, 121, x1 - 1, 134, "gd2")
    L.ell(x0 + 2, 122, x1 - 2, 133, "wl5")
    L.ring(x0 + 2, 122, x1 - 2, 133, "wl3")
    # 刻度（点）
    for (dx, dy) in ((0, -5), (0, 5), (-5, 0), (5, 0)):
        L.p(cx + dx, 127 + dy, "wd1")
    # 指针：十点十分
    L.line(cx, 127, cx - 3, 125, "ol")
    L.line(cx, 127, cx + 3, 123, "ol")
    L.p(cx, 127, "rd3")
    # 顶上的小冠
    L.rect(cx - 2, 118, cx + 3, 120, "wd3")
    L.hl(cx - 2, cx + 3, 118, "wd4")
    # 墙上的影
    L.vl(x1, 122, 162, "wl1")


def draw_papercut(L, cx, cy):
    """红色团花剪纸（不画字）：外圈八瓣、每瓣一个镂空小孔，里面一圈断开的镂空环，花心一点金"""
    n, rd, pr, inner = 8, 6.0, 2.6, 4.2
    petals = [(cx + math.cos(-math.pi / 2 + k * 2 * math.pi / n) * rd,
               cy + math.sin(-math.pi / 2 + k * 2 * math.pi / n) * rd) for k in range(n)]
    for y in range(int(cy) - 10, int(cy) + 11):
        for x in range(int(cx) - 10, int(cx) + 11):
            px_, py_ = x + 0.5, y + 0.5
            d = math.hypot(px_ - cx, py_ - cy)
            ins = d <= inner + 0.8
            for (qx, qy) in petals:
                if math.hypot(px_ - qx, py_ - qy) <= pr:
                    ins = True
            if ins:
                L.p(x, y, "rd3")
            if inner - 0.2 < d < inner + 0.8 and (math.atan2(py_ - cy, px_ - cx) * n / (2 * math.pi)) % 1 < 0.5:
                L.p(x, y, "wl3")
    for (qx, qy) in petals:
        L.p(qx + 0.4 * (qx - cx) / rd - 0.5, qy + 0.4 * (qy - cy) / rd - 0.5, "wl3")
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        L.p(cx + math.cos(a) * 1.6 - 0.5, cy + math.sin(a) * 1.6 - 0.5, "wl3")
    L.p(cx - 0.5, cy - 0.5, "gd3")
    # 右下一圈影（剪纸贴在墙上，薄薄一层）
    for y in range(int(cy) - 10, int(cy) + 12):
        for x in range(int(cx) - 10, int(cx) + 12):
            if L.g(x, y) in (C["wl3"], C["wl2"]) and L.g(x - 1, y - 1) == C["rd3"] and math.hypot(x - cx, y - cy) > 5:
                L.p(x, y, "wl1")


def draw_doormat(L):
    """门里一块小地垫（平的，不挡路）：深红底、金边、中间一排小菱形"""
    x0, y0, x1, y1 = 480, 644, 528, 660
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
    """门口地上几片花瓣（客人从宴会厅带进来的），稀稀拉拉，不成堆"""
    rnd = random.Random(15)
    spots = [(470, 628), (486, 618), (521, 624), (538, 636), (455, 652), (548, 610), (503, 600), (512, 670),
             (530, 664), (476, 667), (563, 648), (494, 637)]
    for (x, y) in spots:
        c1, c2 = rnd.choice([("rd4", "rd5"), ("rd3", "rd4"), ("pk", "wt"), ("rd4", "pk")])
        if rnd.random() < 0.5:
            L.p(x, y, c1)
            L.p(x + 1, y, c1)
            L.p(x + 1, y - 1, c2)
        else:
            L.p(x, y, c1)
            L.p(x, y + 1, c1)
            L.p(x + 1, y, c2)


def background():
    L = Layer()
    L.rect(X0, Y0, X1, Y1, "void")
    draw_floor(L)
    draw_rug(L)
    draw_doormat(L)
    draw_petals(L)
    draw_north_wall(L)
    draw_painting(L)
    draw_clock(L)
    draw_papercut(L, 527, 146)
    draw_papercut(L, 606, 146)
    # 门槛：一条浅木，前沿一道槽
    L.rect(DOOR[0], 684, DOOR[1], 696, "wd4")
    L.hl(DOOR[0], DOOR[1], 684, "wd2")
    L.hl(DOOR[0], DOOR[1], 685, "wd5")
    L.hl(DOOR[0], DOOR[1], 690, "wd3")
    L.hl(DOOR[0], DOOR[1], 691, "wd5")
    L.hl(DOOR[0], DOOR[1], 695, "wd2")
    # 走廊（整间图里只露一条）
    L.rect(X0, 696, X1, Y1, "wl2")
    return L


# ================================================================== 家具（每件一层）
def sleeve_art(L, x, y, i):
    """唱片封套 18×18：先画在一张 18×18 的小图上（超出去的自动裁掉），再贴上去"""
    T = Layer(x0=x, y0=y, w=18, h=18)
    _sleeve_art(T, x, y, i)
    L.paste(T)


def _sleeve_art(L, x, y, i):
    """抽象图案（不画字），i = 0..23 每张不一样"""
    S = 18
    x1, y1 = x + S, y + S
    cx, cy = x + 9, y + 9

    def bg(c):
        L.rect(x, y, x1, y1, c)

    if i == 0:      # 红底、米色太阳落在三道横条上
        bg("rd3")
        L.ell(x + 3, y + 3, x + 12, y + 12, "wl4")
        for k, c in enumerate(("gd3", "or", "rd1")):
            L.rect(x, y + 11 + k * 2, x1, y + 12 + k * 2, c)
    elif i == 1:    # 深蓝底、同心圆靶
        bg("bl1")
        L.ell(x + 2, y + 2, x1 - 2, y1 - 2, "gd3")
        L.ell(x + 4, y + 4, x1 - 4, y1 - 4, "bl1")
        L.ell(x + 6, y + 6, x1 - 6, y1 - 6, "rd4")
        L.ell(x + 8, y + 8, x1 - 8, y1 - 8, "wt")
    elif i == 2:    # 芥末黄、黑色斜三角
        bg("gd3")
        L.poly([(x, y1), (x1, y + 3), (x1, y1)], "ik1")
        L.ell(x + 3, y + 3, x + 8, y + 8, "rd3")
    elif i == 3:    # 青绿底、三道波浪
        bg("tl")
        for k in range(3):
            for xx in range(x, x1):
                yy = y + 4 + k * 5 + (1 if (xx // 3) % 2 else 0)
                L.p(xx, yy, "tl2")
                L.p(xx, yy + 1, "wl5" if k == 1 else "tl2")
    elif i == 4:    # 粉底、紫圆叠红圆
        bg("pk")
        L.ell(x + 2, y + 4, x + 12, y + 14, "pu")
        L.ell(x + 7, y + 4, x + 17, y + 14, "rd3")
        L.ell(x + 7, y + 5, x + 11, y + 13, "rd1")
    elif i == 5:    # 米色底、方块构成（黑线 + 红蓝黄）
        bg("wl5")
        L.rect(x, y + 7, x1, y + 8, "ik1")
        L.rect(x + 6, y, x + 7, y1, "ik1")
        L.rect(x + 12, y + 7, x + 13, y1, "ik1")
        L.rect(x, y, x + 6, y + 7, "rd3")
        L.rect(x + 13, y + 8, x1, y1, "bl2")
        L.rect(x + 7, y + 13, x + 12, y1, "gd3")
        L.rect(x + 12, y + 13, x + 13, y1, "ik1")
    elif i == 6:    # 紫底、弯月和星点
        bg("pu")
        L.ell(x + 4, y + 3, x + 14, y + 13, "gd4")
        L.ell(x + 7, y + 2, x + 16, y + 11, "pu")
        for (a, b) in ((3, 14), (14, 13), (12, 4), (5, 9)):
            L.p(x + a, y + b, "wl5")
    elif i == 7:    # 黑底、彩虹拱
        bg("ik1")
        for k, c in enumerate(("rd4", "or", "gd3", "tl2", "bl3")):
            L.ell(x + 1 + k, y + 4 + k, x1 - 1 - k, y + 30 - k, c)
        L.ell(x + 6, y + 9, x1 - 6, y + 25, "ik1")
        L.rect(x, y + 15, x1, y1, "ik1")
    elif i == 8:    # 橙底、中间一条黑白棋格
        bg("or")
        for yy in range(y + 6, y + 12):
            for xx in range(x, x1):
                L.p(xx, yy, "ik1" if ((xx - x) // 2 + (yy - y) // 2) % 2 else "wt")
    elif i == 9:    # 绿底、一片大叶子
        bg("gr2")
        L.ell(x + 3, y + 4, x + 15, y + 14, "gr4")
        L.line(x + 4, y + 13, x + 14, y + 5, "gr1")
        L.p(x + 3, y + 14, "gr1")
        L.p(x + 2, y + 15, "gr1")
    elif i == 10:   # 天蓝、几朵云
        bg("bl3")
        L.ell(x + 2, y + 8, x + 10, y + 13, "wt")
        L.ell(x + 6, y + 5, x + 13, y + 12, "wt")
        L.ell(x + 10, y + 9, x + 17, y + 14, "bl4")
        L.rect(x, y + 15, x1, y1, "bl2")
    elif i == 11:   # 红底、金菱形
        bg("rd2")
        L.poly([(cx, y + 2), (x1 - 3, cy), (cx, y1 - 3), (x + 2, cy)], "gd3")
        L.poly([(cx, y + 6), (x1 - 7, cy), (cx, y1 - 7), (x + 6, cy)], "rd3")
        L.p(cx - 1, cy - 1, "gd4")
    elif i == 12:   # 米色底、一大片黑盘偏到右下
        bg("wl4")
        L.ell(x + 5, y + 5, x + 25, y + 25, "ik1")
        L.ell(x + 12, y + 12, x + 18, y + 18, "rd3")
        L.rect(x1, y, x1 + 10, y1 + 10, (0, 0, 0, 0))
    elif i == 13:   # 藏青底、金点阵
        bg("bl0")
        for a in range(4):
            for b in range(4):
                L.p(x + 3 + a * 4, y + 3 + b * 4, "gd3")
                if (a + b) % 3 == 0:
                    L.p(x + 4 + a * 4, y + 3 + b * 4, "gd4")
    elif i == 14:   # 朱红底、一朵白花
        bg("rd4")
        for (a, b) in ((0, -4), (4, 0), (0, 4), (-4, 0), (3, -3), (-3, 3), (3, 3), (-3, -3)):
            L.ell(cx + a - 2, cy + b - 2, cx + a + 3, cy + b + 3, "wl5")
        L.ell(cx - 2, cy - 2, cx + 3, cy + 3, "gd3")
    elif i == 15:   # 青底、四个角四分之一圆
        bg("tl")
        L.ell(x - 9, y - 9, x + 9, y + 9, "gd3")
        L.ell(x1 - 9, y1 - 9, x1 + 9, y1 + 9, "rd3")
        L.ell(x1 - 7, y - 7, x1 + 7, y + 7, "wl5")
        L.rect(x - 9, y - 9, x, y1 + 9, (0, 0, 0, 0))
        L.rect(x1, y - 9, x1 + 9, y1 + 9, (0, 0, 0, 0))
        L.rect(x, y - 9, x1, y, (0, 0, 0, 0))
        L.rect(x, y1, x1, y1 + 9, (0, 0, 0, 0))
    elif i == 16:   # 金底、红心
        bg("gd3")
        L.ell(x + 3, y + 4, x + 10, y + 11, "rd3")
        L.ell(x + 8, y + 4, x + 15, y + 11, "rd3")
        L.poly([(x + 3, y + 8), (x + 14, y + 8), (x + 9, y + 15), (x + 8, y + 15)], "rd3")
        L.p(x + 5, y + 6, "rd5")
    elif i == 17:   # 深灰底、金折线
        bg("ik2")
        for xx in range(x, x1):
            t = (xx - x) % 6
            yy = y + 5 + (t if t < 3 else 6 - t)
            L.p(xx, yy, "gd3")
            L.p(xx, yy + 6, "rd4")
    elif i == 18:   # 粉底、两座山一轮日
        bg("pk")
        L.ell(x + 10, y + 3, x + 16, y + 9, "wl5")
        L.poly([(x, y1), (x + 7, y + 7), (x + 13, y1)], "pu")
        L.poly([(x + 6, y1), (x + 13, y + 10), (x1, y + 15), (x1, y1)], "bl2")
    elif i == 19:   # 米底、红蓝金竖条
        bg("wl4")
        for k, c in enumerate(("rd3", "bl2", "gd2", "rd3")):
            L.rect(x + 2 + k * 4, y, x + 4 + k * 4, y1, c)
    elif i == 20:   # 紫到橙的点状渐变
        bg("pu")
        for yy in range(y, y1):
            for xx in range(x, x1):
                t = (yy - y) / 17.0
                if t > 0.66 or (t > 0.33 and bayer(xx, yy) < (t - 0.33) * 3):
                    L.p(xx, yy, "or")
                elif t > 0.33 or bayer(xx, yy) < t * 3:
                    L.p(xx, yy, "rd3")
        L.ell(x + 6, y + 6, x + 12, y + 12, "gd4")
    elif i == 21:   # 橙底、半个太阳和光芒
        bg("or")
        L.ell(x + 3, y + 10, x + 15, y + 22, "gd4")
        for (a, b) in ((-7, -2), (7, -2), (0, -7), (-5, -6), (5, -6)):
            L.line(cx, y + 15, cx + a, y + 15 + b, "gd4")
        L.rect(x, y + 15, x1, y1, "rd2")
    elif i == 22:   # 蓝底、白斜条
        bg("bl2")
        for yy in range(y, y1):
            for xx in range(x, x1):
                if (xx - x + yy - y) % 6 < 2:
                    L.p(xx, yy, "bl4")
    else:           # 绿底、红点花布
        bg("gr1")
        for a in range(3):
            for b in range(3):
                L.ell(x + 2 + a * 5 + (b % 2) * 2, y + 2 + b * 5, x + 5 + a * 5 + (b % 2) * 2, y + 5 + b * 5, "rd4")


def record_disc(L, cx, cy, r, label):
    L.ell(cx - r, cy - r, cx + r, cy + r, "ik0")
    L.ring(cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2, "ik1")
    L.ring(cx - r + 4, cy - r + 4, cx + r - 4, cy + r - 4, "ik1")
    L.ring(cx - r, cy - r, cx + r, cy + r, "ik2", only=lambda x, y: x < cx and y < cy)
    L.ell(cx - 3, cy - 3, cx + 3, cy + 3, label)
    L.p(cx - 1, cy - 1, "ik0")


def prop_vinyl_wall():
    L = Layer()
    x0, x1 = 352, 496
    top_y, face_y, foot = 117 - 6 + 4, 121, 232     # 比灰盒矮 4 像素（2.31 米），顶面不压到墙顶
    # 顶面
    L.rect(x0, top_y, x1, face_y, "wd4")
    L.hl(x0, x1, top_y, "wd5")
    L.hl(x0, x1, face_y - 1, "wd3")
    # 正面：框
    L.rect(x0, face_y, x1, foot, "wd2")
    L.vl(x0, face_y, foot, "wd3")
    L.vl(x1 - 1, face_y, foot, "wd1")
    L.hl(x0, x1, face_y, "wd3")
    # 格子里的背板
    L.rect(x0 + 4, face_y + 4, x1 - 4, foot - 3, "wd0")
    lips = [149, 176, 203, 229]
    tops = [face_y + 4, 152, 179, 206]
    for r in range(4):
        ly = lips[r]
        # 背板上沿一条更暗（上一层板压下来的影）
        L.hl(x0 + 4, x1 - 4, tops[r], "ol")
        L.hl(x0 + 4, x1 - 4, tops[r] + 1, "ol")
        for c in range(6):
            sx = 360 + 22 * c
            sy = ly + 1 - 18
            i = r * 6 + c
            # 露出一截唱片：往上抽（上），或往右滑（右）
            if i in (1, 9, 14, 20):
                record_disc(L, sx + 9, sy - 1, 7, ["rd3", "gd3", "bl3", "pk"][(i // 5) % 4])
            if i in (4, 17, 22):
                record_disc(L, sx + 15, sy + 9, 8, ["gd3", "rd4", "tl2"][i % 3])
            sleeve_art(L, sx, sy, i)
            # 封套右、下压暗，左、上一条亮边
            L.vl(sx + 18, sy, sy + 18, "ol")
            L.hl(sx + 1, sx + 19, sy + 18, "ol")
            for yy in range(sy, sy + 18):
                L.p(sx, yy, shift(L.g(sx, yy), 1))
            for xx in range(sx, sx + 18):
                L.p(xx, sy, shift(L.g(xx, sy), 1))
        # 搁板（前沿一条）
        L.rect(x0 + 4, ly, x1 - 4, ly + 3, "wd3")
        L.hl(x0 + 4, x1 - 4, ly, "wd5")
        L.hl(x0 + 4, x1 - 4, ly + 2, "wd1")
    # 底座
    L.rect(x0, 229, x1, foot, "wd2")
    L.hl(x0, x1, 229, "wd4")
    L.hl(x0, x1, foot - 1, "wd1")
    L.outline()
    return L, foot


def prop_record_player():
    L = Layer()
    x0, x1, yf0, yf1, h = 396, 452, 258, 284, 28
    ty0, ty1 = yf0 - h, yf1 - h          # 230..256
    # 腿
    for lx in (399, 446):
        L.rect(lx, 279, lx + 3, 284, "wd1")
        L.vl(lx, 279, 284, "wd2")
    # 柜身正面
    L.rect(x0, ty1, x1, 280, "wd3")
    L.hl(x0, x1, ty1, "wd5")
    L.hl(x0, x1, ty1 + 1, "wd4")
    L.vl(x1 - 1, ty1, 280, "wd2")
    L.hl(x0, x1, 279, "wd1")
    # 喇叭布 + 竖木条
    L.rect(x0 + 5, ty1 + 5, x0 + 38, 276, "gd1")
    for yy in range(ty1 + 5, 276):
        for xx in range(x0 + 5, x0 + 38):
            if (xx + yy) % 2 == 0:
                L.p(xx, yy, "gd2")
    for xx in range(x0 + 8, x0 + 38, 5):
        L.vl(xx, ty1 + 5, 276, "wd2")
        L.vl(xx + 1, ty1 + 5, 276, "wd4")
    L.hl(x0 + 5, x0 + 38, ty1 + 5, "wd1")
    L.vl(x0 + 5, ty1 + 5, 276, "wd1")
    # 右边控制面板：两个铜旋钮
    L.rect(x0 + 41, ty1 + 5, x1 - 4, 276, "wd2")
    L.hl(x0 + 41, x1 - 4, 275, "wd4")
    for ky in (ty1 + 9, ty1 + 16):
        L.ell(x0 + 44, ky, x0 + 49, ky + 5, "gd2")
        L.p(x0 + 45, ky + 1, "gd4")
        L.p(x0 + 47, ky + 3, "gd1")
    # 顶面
    L.rect(x0, ty0, x1, ty1, "wd4")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x0, ty0, ty1, "wd5")
    L.vl(x1 - 1, ty0, ty1, "wd3")
    # 转盘
    L.ell(x0 + 4, ty0 + 3, x0 + 34, ty0 + 23, "wd2")
    L.ell(x0 + 5, ty0 + 3, x0 + 33, ty0 + 22, "ik2")
    L.ell(x0 + 6, ty0 + 4, x0 + 32, ty0 + 21, "ik0")
    for k in (2, 4, 6):
        L.ring(x0 + 6 + k, ty0 + 4 + k * 0.6, x0 + 32 - k, ty0 + 21 - k * 0.6, "ik1")
    L.ring(x0 + 7, ty0 + 5, x0 + 31, ty0 + 20, "ik3", only=lambda x, y: x < x0 + 15 and y < ty0 + 10)
    L.ell(x0 + 15, ty0 + 10, x0 + 23, ty0 + 15, "rd3")
    L.p(x0 + 16, ty0 + 11, "rd4")
    L.p(x0 + 19, ty0 + 12, "gd4")
    # 唱臂
    L.ell(x0 + 38, ty0 + 4, x0 + 44, ty0 + 9, "ik3")
    L.p(x0 + 40, ty0 + 5, "wt")
    L.line(x0 + 40, ty0 + 7, x0 + 30, ty0 + 15, "wl4")
    L.line(x0 + 41, ty0 + 7, x0 + 31, ty0 + 15, "wl2")
    L.rect(x0 + 28, ty0 + 14, x0 + 31, ty0 + 17, "wl4")
    # 金色大喇叭：从柜子后右角伸出、往上弯、喇叭口朝前
    # 喇叭颈：从柜面后右角（一个铜座）往上弯进喇叭背后，一根连着的管子
    L.ell(x0 + 42, ty0, x0 + 51, ty0 + 5, "gd1")
    L.ell(x0 + 43, ty0, x0 + 50, ty0 + 4, "gd2")
    L.p(x0 + 44, ty0 + 1, "gd4")
    path = []
    for k in range(41):
        t = k / 40.0
        # 二次贝塞尔：(446,232) → (449,218) → (440,210)
        px_ = (1 - t) ** 2 * (x0 + 50) + 2 * (1 - t) * t * (x0 + 53) + t * t * (x0 + 44)
        py_ = (1 - t) ** 2 * (ty0 + 2) + 2 * (1 - t) * t * (ty0 - 12) + t * t * (ty0 - 20)
        path.append((px_, py_, 1.3 + 0.9 * t))
    for (px_, py_, r) in path:
        L.ell(px_ - r, py_ - r, px_ + r + 1, py_ + r + 1, "gd2")
    for (px_, py_, r) in path:
        L.p(px_ - r + 0.5, py_, "gd4")
        L.p(px_ + r - 0.5, py_ + 0.5, "gd1")
    hx, hy = 432, 203               # 喇叭口中心
    # 喇叭外壁（口沿后面露一点）
    L.ell(hx - 13, hy - 9, hx + 22, hy + 21, "gd1")
    L.ell(hx - 17, hy - 15, hx + 17, hy + 15, "gd3")       # 口沿
    L.ell(hx - 15, hy - 13, hx + 15, hy + 13, "gd2")       # 喇叭里面
    L.ell(hx - 11, hy - 9, hx + 11, hy + 9, "gd1")
    L.ell(hx - 7, hy - 6, hx + 7, hy + 6, "gd0")
    L.ell(hx - 3, hy - 3, hx + 3, hy + 3, "ik1")
    # 花瓣棱线
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        for t in range(4, 15):
            L.p(hx + math.cos(a) * t * 1.0, hy + math.sin(a) * t * 0.88, "gd1" if t > 6 else "gd0")
    # 口沿高光（左上）、暗（右下）
    L.ring(hx - 17, hy - 15, hx + 17, hy + 15, "gd4", only=lambda x, y: (x - hx) + (y - hy) < -6)
    L.ring(hx - 17, hy - 15, hx + 17, hy + 15, "gd1", only=lambda x, y: (x - hx) + (y - hy) > 10)
    L.outline()
    return L, yf1


def prop_luggage_blue():
    L = Layer()
    x0, x1, yf0, yf1, h = 356, 380, 280, 290, 36
    ty0, ty1 = yf0 - h, yf1 - h          # 244..254
    # 拉杆
    for rx in (360, 375):
        L.vl(rx, 226, ty0 + 2, "ik2")
        L.vl(rx + 1, 226, ty0 + 2, "ik1")
    L.rect(359, 224, 377, 228, "ik2")
    L.hl(359, 377, 224, "ik3")
    # 红丝带系在把手上（认箱子用）
    L.rect(361, 226, 365, 229, "rd3")
    L.p(361, 226, "rd5")
    L.line(362, 229, 360, 235, "rd3")
    L.line(364, 229, 366, 236, "rd4")
    # 顶面
    L.rect(x0 + 1, ty0, x1 - 1, ty1, "bl3")
    L.hl(x0 + 2, x1 - 2, ty0, "bl4")
    L.vl(x1 - 2, ty0 + 1, ty1, "bl2")
    # 提手
    L.rect(364, ty0 + 3, 372, ty0 + 6, "ik2")
    L.hl(364, 372, ty0 + 3, "ik3")
    # 正面
    L.rect(x0, ty1, x1, yf1 - 2, "bl2")
    L.hl(x0 + 1, x1 - 1, ty1, "bl4")
    for k, rx in enumerate(range(x0 + 4, x1 - 2, 5)):
        L.vl(rx, ty1 + 3, yf1 - 5, "bl1")
        L.vl(rx + 1, ty1 + 3, yf1 - 5, "bl3")
    L.vl(x1 - 1, ty1, yf1 - 2, "bl1")
    L.hl(x0, x1, yf1 - 3, "bl1")
    L.vl(x0, ty1 + 1, yf1 - 2, "bl3")
    # 护角
    for (a, b) in ((x0, ty1), (x1 - 2, ty1), (x0, yf1 - 5), (x1 - 2, yf1 - 5)):
        L.rect(a, b, a + 2, b + 2, "ik2")
    # 轮子
    for wx in (x0 + 2, x1 - 4):
        L.rect(wx, yf1 - 2, wx + 3, yf1, "ik0")
        L.p(wx + 1, yf1 - 2, "ik3")
    L.p(x0, ty0, (0, 0, 0, 0))
    L.outline()
    return L, yf1


def prop_luggage_brown():
    L = Layer()
    x0, x1, yf0, yf1, h = 636, 655, 640, 648, 26
    ty0, ty1 = yf0 - h, yf1 - h          # 614..622
    L.rect(x0, ty0, x1, ty1, "wd5")
    L.hl(x0, x1, ty0, "wl3")
    L.vl(x1 - 1, ty0, ty1, "wd4")
    L.rect(x0, ty1, x1, yf1, "wd4")
    L.hl(x0, x1, ty1, "wd5")
    L.vl(x1 - 1, ty1, yf1, "wd3")
    L.hl(x0, x1, yf1 - 1, "wd3")
    # 提手
    L.rect(642, ty0 - 3, 649, ty0 + 1, "wd1")
    L.rect(643, ty0 - 2, 648, ty0, (0, 0, 0, 0))
    L.p(643, ty0 - 3, "wd2")
    # 两条皮带 + 铜扣
    for sx in (640, 650):
        L.vl(sx, ty0, yf1, "wd2")
        L.vl(sx + 1, ty0, yf1, "wd1")
        L.rect(sx - 1, ty1 + 4, sx + 3, ty1 + 7, "gd3")
        L.p(sx, ty1 + 5, "gd1")
    # 包角
    for (a, b) in ((x0, ty1), (x1 - 2, ty1), (x0, yf1 - 2), (x1 - 2, yf1 - 2)):
        L.rect(a, b, a + 2, b + 2, "wd1")
    # 缝线
    for xx in range(x0 + 2, x1 - 2, 2):
        L.p(xx, ty1 + 2, "wd3")
    L.p(x0, ty0, (0, 0, 0, 0))
    L.p(x1 - 1, ty0, (0, 0, 0, 0))
    L.outline()
    return L, yf1


def puff_level(u, v):
    """鼓包的明暗：左上亮、右下暗、四边往下掉；u, v 在 -1..1"""
    return -(u + v) * 0.35 + (1.0 - (u * u + v * v) * 0.5) * 0.7


def puff(L, x0, y0, x1, y1, ramp, lv, cuts=(0.62, 0.25, -0.15)):
    """一块软垫的面：按鼓包明暗分 4 档（lv+1 / lv / lv-1 / lv-2）"""
    w, h = x1 - x0, y1 - y0
    for y in range(y0, y1):
        for x in range(x0, x1):
            u = (x + 0.5 - x0) / w * 2 - 1
            v = (y + 0.5 - y0) / h * 2 - 1
            b = puff_level(u, v)
            k = 1 if b > cuts[0] else (0 if b > cuts[1] else (-1 if b > cuts[2] else -2))
            L.p(x, y, rname(ramp, lv + k))


def pillow(L, x0, y0, w, h, ramp, pattern=None, edge="ol"):
    """抱枕：四角尖、四边往里收一点的鼓包（自带一圈深边，放在家具中间也分得开）"""
    x1, y1 = x0 + w, y0 + h
    pts = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            u = (x + 0.5 - x0) / w * 2 - 1
            v = (y + 0.5 - y0) / h * 2 - 1
            # 边往里收：离角越远收得越多
            inset = 0.13 * (1 - abs(v) ** 2)
            insety = 0.13 * (1 - abs(u) ** 2)
            if abs(u) <= 1 - inset and abs(v) <= 1 - insety:
                pts.add((x, y))
    for (x, y) in pts:
        u = (x + 0.5 - x0) / w * 2 - 1
        v = (y + 0.5 - y0) / h * 2 - 1
        b = puff_level(u, v)
        lv = 4 if b > 0.68 else (3 if b > 0.3 else (2 if b > -0.1 else 1))
        L.p(x, y, rname(ramp, lv))
    for (x, y) in pts:
        if any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            L.p(x, y, edge if (x - x0) / w + (y - y0) / h > 0.85 else rname(ramp, 1))
    cx, cy = x0 + w // 2, y0 + h // 2
    if pattern == "dot":                      # 中间一朵金色小花
        L.p(cx, cy, "gd4")
        for (dx, dy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            L.p(cx + dx, cy + dy, "gd2")
    elif pattern == "stripe":                 # 两道金线
        L.hl(x0 + 2, x1 - 2, cy - 2, "gd2")
        L.hl(x0 + 2, x1 - 2, cy + 2, "gd2")
    elif pattern == "knot":                   # 金色盘扣（中式）
        L.p(cx, cy, "rd2")
        L.p(cx - 1, cy, "rd3")
        L.p(cx + 1, cy, "rd3")


def prop_sofa():
    """三人沙发（朝南）：卷边扶手、三块拉扣靠垫、三块坐垫、布裙、木脚线；红金两只抱枕、东扶手搭一条红毯。
    顶面（坐垫面、扶手面、靠背顶）用亮的两档，朝南的竖面用中间一档，折缝和坐垫底下用暗档"""
    L = Layer()
    x0, x1 = 516, 617
    ia, ib = 528, 605                   # 两扶手之间
    # 靠背顶（圆的一条）195..202
    L.rect(x0 + 1, 195, x1 - 1, 203, "wl4")
    L.hl(x0 + 2, x1 - 2, 195, "wl5")
    L.hl(x0 + 1, x1 - 1, 196, "wl5")
    L.hl(x0 + 1, x1 - 1, 200, "wl3")
    L.hl(x0 + 1, x1 - 1, 201, "wl2")
    L.hl(x0 + 1, x1 - 1, 202, "wl2")
    L.vl(x1 - 2, 197, 200, "wl3")
    # 靠背正面（扶手上方露出来的一截）
    L.rect(x0, 203, x1, 228, "wl2")
    # 三块靠垫：鼓起来、拉扣、相邻有缝
    edges = [ia, 554, 579, ib]
    for k in range(3):
        a, b = edges[k], edges[k + 1]
        puff(L, a, 203, b, 229, "wl", 2)
        L.hl(a + 1, b - 1, 203, "wl3")
        L.vl(b - 1, 204, 229, "wl1")
        L.hl(a, b, 228, "wl1")
        for (bx, by) in ((a + 6, 210), (a + 13, 210), (a + 20, 210), (a + 9, 218), (a + 17, 218)):
            if bx < b - 2:
                L.p(bx, by, "wl0")
                L.p(bx - 1, by - 1, "wl4")
    # 扶手：顶面 209..238（从后往前一长条），正面 238..261（卷边）
    for (a, b, side) in ((x0, ia, "w"), (ib, x1, "e")):
        L.rect(a, 209, b, 238, "wl4")
        L.vl(a, 210, 238, "wl5")
        L.vl(a + 1, 210, 238, "wl5")
        L.vl(b - 1, 210, 238, "wl2")
        L.vl(b - 2, 211, 238, "wl3")
        L.hl(a + 1, b - 1, 209, "wl5")
        L.p(a, 209, "wl3")
        L.p(b - 1, 209, "wl2")
        # 卷边正面
        L.rect(a, 238, b, 261, "wl2")
        L.hl(a, b, 237, "wl3")
        L.hl(a, b, 238, "wl4")
        L.ring(a + 1, 239, b - 1, 251, "wl1")
        L.ell(a + 3, 241, b - 3, 249, "wl3")
        L.p(a + 5, 243, "wl4")
        L.vl(b - 1, 239, 261, "wl1")
        L.hl(a, b, 260, "wl1")
    # 扶手跟坐垫之间的缝
    L.vl(ia, 209, 252, "wl0")
    L.vl(ib - 1, 209, 252, "wl1")
    # 坐垫三块：顶面 229..243，前沿滚边 244，正面 245..252
    for k in range(3):
        a, b = edges[k], edges[k + 1]
        L.rect(a, 229, b, 244, "wl4")
        L.hl(a, b, 229, "wl1")                 # 靠背压出来的折痕
        L.hl(a + 1, b - 1, 230, "wl3")
        L.vl(a + 1, 231, 243, "wl5")
        L.vl(b - 1, 230, 244, "wl3")
        L.hl(a + 1, b - 1, 242, "wl5")
        L.hl(a, b, 243, "wl5")
        L.hl(a, b, 244, "wt")
        L.rect(a, 245, b, 252, "wl2")
        L.hl(a, b, 245, "wl3")
        L.hl(a, b, 251, "wl1")
        L.vl(b - 1, 245, 252, "wl1")
        if k > 0:
            L.vl(a, 229, 252, "wl1")
    # 坐垫下：布裙（在坐垫阴影里）
    L.rect(ia, 252, ib, 261, "wl1")
    L.hl(ia, ib, 252, "wl0")
    for xx in range(ia + 3, ib - 2, 6):       # 布裙褶
        L.vl(xx, 255, 261, "wl0")
        L.vl(xx + 1, 256, 261, "wl2")
    # 木脚线 + 脚
    L.rect(x0, 261, x1, 265, "wd3")
    L.hl(x0, x1, 261, "wd5")
    L.hl(x0, x1, 264, "wd1")
    for lx in (x0 + 2, 565, x1 - 5):
        L.rect(lx, 265, lx + 3, 268, "wd1")
        L.p(lx, 265, "wd3")
    # 抱枕（压在靠垫前、坐在坐垫上），底下一点影
    for (px_, py_) in ((532, 231), (586, 231)):
        L.hl(px_ + 2, px_ + 18, py_ + 1, "wl2")
        L.hl(px_ + 4, px_ + 17, py_ + 2, "wl3")
    pillow(L, 531, 211, 18, 21, "rd", "dot")
    pillow(L, 585, 212, 17, 20, "gd", "knot")
    # 东扶手上搭一条红毯：盖住扶手前半截、垂到正面，下摆金穗
    bx0, bx1 = ib - 1, x1
    L.rect(bx0, 221, bx1, 238, "rd3")
    L.vl(bx0, 221, 238, "rd4")
    L.vl(bx1 - 1, 221, 238, "rd2")
    L.hl(bx0, bx1, 221, "rd4")
    L.rect(bx0, 238, bx1, 255, "rd2")
    L.vl(bx0, 238, 255, "rd3")
    L.hl(bx0, bx1, 238, "rd4")
    for yy in (226, 232, 243, 249):
        L.hl(bx0 + 1, bx1 - 1, yy, "gd2" if yy < 238 else "gd1")
    for xx in range(bx0, bx1, 2):
        L.p(xx, 255, "gd3")
        L.p(xx + 1, 256, "gd3")
    L.outline()
    return L, 268


def prop_armchair(side):
    """单人沙发，侧着朝茶几（west 靠背在西、朝东；east 靠背在东、朝西）。
    从南边看是它的侧面：高靠背、低扶手（扶手头卷一道）、扶手中间露坐垫和抱枕、木底座四只脚。
    光照不跟着左右翻：两张都是左边亮、右边暗"""
    L = Layer()
    w = side == "w"
    x0, x1 = (480, 523) if w else (604, 647)
    if w:
        bx0, bx1 = 480, 491
        ax0, ax1 = 489, 523
        sx0, sx1 = 491, 521
    else:
        bx0, bx1 = 636, 647
        ax0, ax1 = 604, 638
        sx0, sx1 = 606, 636
    # 1) 北扶手：顶面 263..269，朝南的内侧面 269..277（阴影里）
    L.rect(ax0, 263, ax1, 269, "wl4")
    L.hl(ax0 + 1, ax1 - 1, 263, "wl5")
    L.vl(ax0, 264, 269, "wl5")
    L.rect(ax0, 269, ax1, 277, "wl1")
    L.hl(ax0, ax1, 269, "wl2")
    L.hl(ax0, ax1, 276, "wl0")
    # 2) 坐垫顶面 277..288
    L.rect(sx0, 277, sx1, 288, "wl4")
    L.hl(sx0, sx1, 277, "wl3")
    L.hl(sx0 + 1, sx1 - 1, 278, "wl5")
    L.vl(sx0 if w else sx1 - 1, 277, 288, "wl2")           # 跟靠背接的折痕
    # 3) 靠背：顶面 250..280（窄长条、两头圆），南面 280..313
    L.rect(bx0, 251, bx1, 280, "wl4")
    L.hl(bx0 + 1, bx1 - 1, 250, "wl5")
    L.vl(bx0, 252, 280, "wl5")
    L.vl(bx0 + 1, 251, 280, "wl5")
    L.vl(bx1 - 1, 252, 280, "wl2")
    L.vl(bx1 - 2, 252, 280, "wl3")
    L.p(bx0, 250, "wl3")
    L.p(bx1 - 1, 250, "wl2")
    puff(L, bx0, 280, bx1, 313, "wl", 2)
    L.hl(bx0, bx1, 280, "wl4")
    L.hl(bx0, bx1, 281, "wl3")
    L.vl(bx1 - 1, 281, 313, "wl1")
    # 靠背跟扶手中间一道缝
    L.vl(bx1 if w else bx0 - 1, 264, 313, "wl0")
    # 4) 抱枕（侧面看是一只鼓鼓的枕头）
    if w:
        pillow(L, 492, 266, 10, 16, "rd", "dot")
    else:
        pillow(L, 624, 266, 10, 16, "gd", "knot")
    # 5) 南扶手：顶面 287..293，外侧大板 293..313
    L.rect(ax0, 287, ax1, 293, "wl4")
    L.hl(ax0 + 1, ax1 - 1, 287, "wl5")
    L.vl(ax0, 288, 293, "wl5")
    L.hl(ax0, ax1, 292, "wl3")
    puff(L, ax0, 293, ax1, 313, "wl", 2)
    L.hl(ax0, ax1, 293, "wl4")
    L.hl(ax0, ax1, 294, "wl3")
    L.hl(ax0, ax1, 312, "wl1")
    L.vl(ax1 - 1, 293, 313, "wl1")
    # 侧板一道竖向滚边
    for yy in range(296, 311):
        L.p((ax0 + ax1) // 2 + (2 if w else -2), yy, "wl1")
    # 扶手头：卷边的侧影（朝茶几那头）——一道往里卷的弧线
    scx = ax1 - 6 if w else ax0 + 6
    L.ell(scx - 6, 287, scx + 6, 299, "wl4")
    L.hl(scx - 4, scx + 4, 287, "wl5")
    L.ring(scx - 6, 287, scx + 6, 299, "wl1", only=lambda x, y: y > 293)
    L.ring(scx - 3, 290, scx + 3, 296, "wl1", only=lambda x, y: (x < scx + 1 if w else x > scx - 1) or y > 293)
    L.p(scx, 293, "wl2")
    # 6) 木底座、四只脚（前两只看得见）
    L.rect(x0, 313, x1, 316, "wd3")
    L.hl(x0, x1, 313, "wd5")
    L.hl(x0, x1, 315, "wd1")
    for lx in (x0 + 1, x1 - 4):
        L.rect(lx, 316, lx + 3, 320, "wd1")
        L.p(lx, 316, "wd3")
    L.outline()
    return L, 320


def gaiwan(L, x, y):
    """盖碗：托、碗、盖（青花），x,y 是托的左上"""
    L.ell(x, y + 4, x + 9, y + 7, "bl4")
    L.hl(x + 1, x + 8, y + 5, "wt")
    L.rect(x + 2, y + 1, x + 7, y + 5, "wt")
    L.hl(x + 2, x + 7, y + 3, "bl2")
    L.vl(x + 6, y + 1, y + 5, "bl4")
    L.ell(x + 2, y - 1, x + 7, y + 2, "wt")
    L.p(x + 4, y - 1, "bl2")
    L.p(x + 5, y, "bl4")


def prop_tea_table():
    L = Layer()
    x0, x1, yf0, yf1, h = 538, 596, 296, 314, 22
    ty0, ty1 = yf0 - h, yf1 - h          # 274..292
    # 桌面
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    for k in range(6):     # 一道斜着的反光
        L.hl(x0 + 30 + k * 2, x0 + 36 + k * 2, ty0 + 2 + k * 2, "wd4")
    # 桌沿（厚 4）
    L.rect(x0, ty1, x1, ty1 + 4, "wd2")
    L.hl(x0, x1, ty1, "wd5")
    L.hl(x0, x1, ty1 + 3, "wd1")
    # 牙板 + 中间一朵卷云
    L.rect(x0 + 3, ty1 + 4, x1 - 3, ty1 + 9, "wd2")
    L.hl(x0 + 3, x1 - 3, ty1 + 8, "wd1")
    mx = (x0 + x1) // 2
    L.rect(mx - 5, ty1 + 6, mx + 5, ty1 + 10, "wd2")
    L.p(mx - 3, ty1 + 6, "wd4")
    L.p(mx + 2, ty1 + 6, "wd4")
    L.hl(mx - 4, mx + 4, ty1 + 9, "wd1")
    # 桌下的空（看得见后面地毯在阴影里）由背景负责，这里只画腿
    for lx in (x0, x1 - 4):
        L.rect(lx, ty1 + 4, lx + 4, yf1 - 2, "wd2")
        L.vl(lx, ty1 + 4, yf1 - 2, "wd3")
        L.vl(lx + 3, ty1 + 4, yf1 - 2, "wd1")
    # 马蹄足（往里勾）
    L.rect(x0, yf1 - 2, x0 + 6, yf1, "wd2")
    L.hl(x0, x0 + 6, yf1 - 2, "wd3")
    L.rect(x1 - 6, yf1 - 2, x1, yf1, "wd2")
    L.hl(x1 - 6, x1, yf1 - 2, "wd3")
    # 茶盘（竹）
    L.rect(543, 279, 577, 289, "wd5")
    L.hl(543, 577, 279, "wl3")
    L.hl(543, 577, 288, "wd3")
    for xx in range(546, 576, 3):
        L.vl(xx, 280, 288, "wd4")
    # 青花茶壶：圆肚子、壶盖和钮、左边壶嘴、右边壶把；右下背光一圈淡蓝，肚子上一圈青花
    L.hl(546, 558, 285, "wd3")                       # 茶壶落在茶盘上的影
    L.ell(546, 274, 558, 285, "bl4")
    L.ell(546, 274, 557, 284, "wt")
    L.ring(546, 274, 558, 285, "bl3", only=lambda x, y: x > 553 or y > 282)
    L.hl(548, 556, 279, "bl2")
    L.p(549, 278, "bl1")
    L.p(552, 280, "bl1")
    L.p(555, 278, "bl1")
    L.p(548, 276, "wt")
    L.p(549, 275, "wt")
    L.ell(549, 271, 555, 275, "wt")                  # 壶盖
    L.hl(550, 554, 274, "bl3")
    L.rect(551, 269, 553, 271, "bl2")                # 盖钮
    L.p(551, 269, "bl3")
    L.line(546, 279, 543, 275, "wt")                 # 壶嘴
    L.line(546, 280, 543, 276, "bl4")
    L.p(542, 274, "wt")
    L.vl(558, 276, 282, "bl3")                       # 壶把
    L.p(559, 277, "bl3")
    L.p(559, 281, "bl3")
    L.vl(560, 278, 281, "bl3")
    # 盖碗两只（落在茶盘上一条影）
    for gx, gy in ((559, 279), (568, 280)):
        L.hl(gx + 1, gx + 10, gy + 7, "wd3")
    gaiwan(L, 559, 279)
    gaiwan(L, 568, 280)
    # 喜糖盘：红漆小盘、几颗糖
    L.ell(579, 280, 593, 289, "rd2")
    L.ell(580, 280, 592, 287, "rd3")
    for (a, b, c) in ((582, 282, "rd5"), (584, 283, "gd3"), (587, 282, "pk"), (589, 284, "gd4"), (585, 285, "rd4"),
                      (583, 284, "wt"), (588, 285, "rd5")):
        L.p(a, b, c)
        L.p(a + 1, b, c)
    L.outline()
    return L, yf1


def prop_tv():
    """电视柜连电视（东隔墙边）：矮木柜顺着墙放；电视侧着朝西、往屋里转一点，
    看到的是一个略斜的屏幕面（黑、有一道反光）+ 右边一条机身厚度 + 底座"""
    L = Layer()
    x0, x1, yf0, yf1, h = 636, 660, 360, 418, 24
    ty0, ty1 = yf0 - h, yf1 - h          # 336..394
    # 柜子顶面：木纹顺着长边
    L.rect(x0, ty0, x1, ty1, "wd4")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x0, ty0, ty1, "wd5")
    L.vl(x1 - 1, ty0 + 1, ty1, "wd3")
    for gx, gy0, gy1 in ((641, 340, 352), (647, 356, 372), (652, 342, 349), (644, 378, 390), (655, 377, 386)):
        L.vl(gx, gy0, gy1, "wd3")
    L.hl(x0, x1, ty1 - 1, "wd3")
    # 柜子南面：上面一个抽屉、下面两扇小门，铜拉手，底下一条踢脚
    L.rect(x0, ty1, x1, yf1 - 3, "wd3")
    L.hl(x0, x1, ty1, "wd5")
    L.vl(x0, ty1, yf1 - 3, "wd4")
    L.vl(x1 - 1, ty1, yf1 - 3, "wd2")
    L.rect(x0 + 2, ty1 + 3, x1 - 2, ty1 + 9, "wd2")
    L.rect(x0 + 3, ty1 + 4, x1 - 3, ty1 + 8, "wd3")
    L.hl(x0 + 3, x1 - 3, ty1 + 4, "wd4")
    L.rect((x0 + x1) // 2 - 2, ty1 + 5, (x0 + x1) // 2 + 2, ty1 + 7, "gd3")
    L.p((x0 + x1) // 2 - 2, ty1 + 5, "gd4")
    for (a, b) in ((x0 + 2, (x0 + x1) // 2), ((x0 + x1) // 2 + 1, x1 - 2)):
        L.rect(a, ty1 + 11, b, yf1 - 5, "wd2")
        L.rect(a + 1, ty1 + 12, b - 1, yf1 - 6, "wd3")
        L.hl(a + 1, b - 1, ty1 + 12, "wd4")
    L.p((x0 + x1) // 2 - 2, ty1 + 15, "gd3")
    L.p((x0 + x1) // 2 + 2, ty1 + 15, "gd3")
    L.rect(x0, yf1 - 3, x1, yf1, "wd1")
    L.rect(x0 + 2, yf1 - 3, x1 - 2, yf1 - 1, "wd2")
    # 柜上南头一盆小多肉（白瓷小盆），在电视底座南边
    L.rect(646, 386, 653, 392, "wt")
    L.vl(652, 387, 392, "bl4")
    L.hl(646, 653, 391, "bl4")
    L.hl(646, 653, 388, "bl3")
    for (a, b, c) in ((646, 383, "gr2"), (648, 381, "gr3"), (650, 382, "gr4"), (651, 384, "gr2"), (647, 384, "gr3"),
                      (649, 383, "gr3")):
        L.rect(a, b, a + 2, b + 2, c)
    # 电视：外框（黑）、屏幕（深）、一道斜反光、右边机身厚度、底座
    L.poly([(634, 318), (653, 324), (653, 370), (634, 364)], "ik0")
    L.line(634, 318, 653, 324, "ik3")                # 外框上沿受光
    L.vl(634, 318, 365, "ik2")                       # 外框左沿
    L.poly([(636, 321), (651, 326), (651, 367), (636, 362)], "ik1")
    L.poly([(636, 331), (651, 336), (651, 343), (636, 338)], "ik2")
    L.line(636, 329, 651, 334, "ik3")
    L.line(636, 345, 642, 347, "ik2")
    L.line(635, 364, 652, 369, "ik2")                # 下边框受光（顺着斜边）
    L.poly([(653, 324), (657, 322), (657, 368), (653, 370)], "ik2")
    L.vl(654, 324, 369, "ik3")
    L.vl(656, 323, 368, "ik1")
    # 底座
    L.rect(643, 369, 646, 375, "ik2")
    L.vl(643, 369, 375, "ik3")
    L.rect(638, 374, 652, 377, "ik2")
    L.hl(638, 652, 374, "ik3")
    L.hl(638, 652, 376, "ik1")
    L.outline()
    return L, yf1


def prop_floor_lamp():
    L = Layer()
    # 底座
    L.ell(622, 255, 637, 262, "gd1")
    L.ell(622, 254, 637, 260, "gd2")
    L.ell(624, 255, 631, 258, "gd3")
    # 杆
    L.rect(628, 200, 631, 257, "gd2")
    L.vl(628, 200, 257, "gd4")
    L.vl(630, 200, 257, "gd1")
    # 灯罩：上窄下宽的布罩，里面亮
    L.poly([(621, 183), (637, 183), (641, 200), (617, 200)], "wl4")
    for y in range(184, 200):
        t = (y - 183) / 17.0
        xa = 621 - 4 * t
        xb = 637 + 4 * t
        L.p(int(xb) - 1, y, "wl3")
        L.p(int(xb) - 2, y, "wl3" if y > 190 else "wl4")
        L.p(int(xa), y, "wl5")
        L.p(int(xa) + 1, y, "wl5")
    for y in range(186, 199, 3):
        L.hl(624, 634, y, "wl5")
    L.hl(621, 637, 183, "gd3")
    L.hl(617, 641, 200, "gd3")
    L.hl(618, 640, 201, "gd4")
    # 罩口下面的灯泡光
    L.ell(624, 200, 634, 205, "gd4")
    L.ell(626, 201, 632, 204, "wt")
    L.outline()
    return L, 260


def leaf(L, cx, cy, ln, ang, wid, ramp_i, vein=True):
    """一片尖叶子：中心 cx,cy，长 ln、朝 ang 方向，宽 wid；ramp_i 是这片叶子的中间档。
    朝光那半边亮一档、背光那半边的边缘一圈深绿（叠在一起也分得开），中间一条叶脉"""
    ca, sa = math.cos(ang), math.sin(ang)
    pts = {}
    for y in range(int(cy - ln) - 1, int(cy + ln) + 2):
        for x in range(int(cx - ln) - 1, int(cx + ln) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = dx * ca + dy * sa          # 沿叶子
            v = -dx * sa + dy * ca         # 横着
            if -ln / 2 <= u <= ln / 2:
                half = wid / 2 * math.sin(math.pi * (u + ln / 2) / ln) ** 0.75
                if abs(v) <= half:
                    pts[(x, y)] = (u, v, half)
    # 光从左上来：叶面法线朝左上那半边亮
    light_side = 1 if (-sa * -1 + ca * -1) < 0 else -1
    for (x, y), (u, v, half) in pts.items():
        lv = ramp_i
        if v * light_side > 0.15 * half:
            lv = ramp_i + 1
        L.p(x, y, rname("gr", lv))
    for (x, y), (u, v, half) in pts.items():
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge and (x - cx) + (y - cy) > -1:
            L.p(x, y, rname("gr", ramp_i - 2))
    if vein:
        for t in range(-int(ln / 2) + 2, int(ln / 2) - 1):
            L.p(cx + ca * t, cy + sa * t, rname("gr", ramp_i - 1))


def prop_plant_sw():
    """西南角绿植（布局里那盆）：青花瓷盆 + 一丛橡皮树似的阔叶"""
    L = Layer()
    yf1 = 668
    # 叶子：后面的、暗的先画，前面的、亮的后画
    leaves = [
        (350, 624, 15, -2.35, 8, 2), (370, 622, 15, -0.75, 8, 2), (361, 612, 16, -1.55, 9, 2),
        (346, 636, 14, -2.85, 8, 2), (375, 634, 14, -0.25, 8, 2), (355, 621, 14, -1.95, 8, 3),
        (366, 620, 14, -1.15, 8, 3), (353, 633, 13, -2.6, 8, 3), (369, 632, 13, -0.55, 8, 3),
        (360, 627, 13, -1.6, 8, 3), (348, 644, 11, 2.9, 7, 3), (372, 643, 11, 0.25, 7, 3),
        (357, 637, 10, -2.2, 7, 3), (364, 637, 10, -0.95, 7, 3),
    ]
    for (cx, cy, ln, ang, wid, lv) in leaves:
        leaf(L, cx, cy, ln, ang, wid, lv)
    # 新叶的嫩尖
    for (a, b) in ((361, 604), (362, 603), (360, 605)):
        L.p(a, b, "gr4")
    # 盆：口沿、盆身微鼓、青花纹
    prof = {}
    for y in range(648, 668):
        t = (y - 648) / 19.0
        half = 10.6 + 0.9 * math.sin(math.pi * min(1.0, t * 1.6)) - 3.2 * t * t
        prof[y] = half
        for x in range(349, 373):
            if abs(x + 0.5 - 361) <= half:
                L.p(x, y, "wt")
    for y, half in prof.items():
        xa, xb = int(361 - half + 0.5), int(361 + half - 0.5)
        L.p(xb, y, "bl3")
        L.p(xb - 1, y, "bl4")
        L.p(xb - 2, y, "bl4")
        L.p(xa, y, "bl4")
    # 口沿 + 盆土
    L.ell(349, 643, 373, 651, "wt")
    L.ring(349, 643, 373, 651, "bl4", only=lambda x, y: y > 646)
    L.ell(352, 644, 370, 649, "wd1")
    L.ell(354, 645, 368, 648, "wd0")
    # 青花：口沿下两道、腰上一圈缠枝小花、脚上一道
    for y, c in ((651, "bl2"), (653, "bl2"), (664, "bl2"), (666, "bl1")):
        half = prof[y]
        L.hl(int(361 - half + 1), int(361 + half), y, c)
    # 缠枝：一条起伏的藤，上下交替长小叶
    for x in range(352, 371):
        yy = 658 + round(1.5 * math.sin((x - 352) * 0.7))
        L.p(x, yy, "bl2")
        if (x - 352) % 5 == 1:
            up = ((x - 352) // 5) % 2 == 0
            L.p(x, yy + (-1 if up else 1), "bl2")
            L.p(x + 1, yy + (-2 if up else 2), "bl1")
            L.p(x - 1, yy + (-2 if up else 2), "bl3")
    # 两片叶子搭在盆沿上（压在盆前面）
    leaf(L, 351, 647, 9, 2.55, 5, 3)
    leaf(L, 371, 646, 9, 0.55, 5, 3)
    L.outline()
    return L, yf1


def prop_plant_n():
    """北墙唱片墙和沙发之间那盆高的（新加）：陶盆 + 琴叶榕"""
    L = Layer()
    cx, foot = 506, 242

    def sy(y):                     # 整棵往下压一点：连盆约 82 像素（1.7 米），不超比例尺
        return foot - (foot - y) * 0.84

    # 树干
    L.vl(cx, int(sy(170)), 230, "wd2")
    L.vl(cx + 1, int(sy(176)), 230, "wd1")
    L.line(cx, sy(196), cx - 6, sy(186), "wd2")
    L.line(cx + 1, sy(190), cx + 7, sy(180), "wd2")
    # 大叶子（琴叶）：一片一片，上面的亮
    leaves = [(cx - 9, 182, 14, -2.4, 9, 2), (cx + 9, 178, 14, -0.6, 9, 2), (cx - 2, 168, 15, -1.7, 10, 3),
              (cx + 5, 160, 13, -1.2, 9, 3), (cx - 8, 165, 13, -2.1, 9, 3), (cx + 11, 192, 13, -0.2, 8, 2),
              (cx - 11, 196, 13, -2.9, 8, 2), (cx + 2, 184, 13, -1.4, 9, 3), (cx - 4, 203, 11, 2.6, 7, 2),
              (cx + 7, 206, 11, 0.5, 7, 2), (cx - 1, 152, 11, -1.6, 8, 3)]
    for (lx, ly, ln, ang, wid, lv) in leaves:
        leaf(L, lx, sy(ly), ln * 0.92, ang, wid, lv)
    # 陶盆：口沿一圈、盆身往下收，左边受光、右边背光，腰上一道线
    for y in range(229, foot):
        t = (y - 229) / float(foot - 229)
        half = 8.4 - 2.6 * t
        xa, xb = int(cx + 0.5 - half + 0.5), int(cx + 0.5 + half - 0.5)
        L.hl(xa, xb + 1, y, "cl2")
        L.p(xa, y, "cl3")
        L.p(xa + 1, y, "cl3")
        L.p(xb, y, "cl0")
        L.p(xb - 1, y, "cl1")
        L.p(xb - 2, y, "cl1")
    L.hl(cx - 6, cx + 7, 235, "cl1")
    L.hl(cx - 6, cx + 7, 236, "cl3")
    L.ell(cx - 9, 224, cx + 11, 231, "cl2")         # 口沿
    L.ring(cx - 9, 224, cx + 11, 231, "cl3", only=lambda x, y: y < 227 or x < cx - 4)
    L.ring(cx - 9, 224, cx + 11, 231, "cl1", only=lambda x, y: y >= 229 and x > cx + 2)
    L.ell(cx - 7, 225, cx + 9, 229, "wd1")           # 盆土
    L.hl(cx - 5, cx + 7, 226, "wd0")
    L.hl(cx - 5, cx + 7, foot - 1, "cl0")
    L.outline()
    return L, foot


def prop_coat_rack():
    """衣帽架（新加，东南角，行李箱后面靠东墙）：车木立杆、三只脚、顶上圆球、四只挂钩；
    左钩挂一件藏青呢子大衣（领子、翻领、一排金扣、垂下的袖子），右钩搭一条红围巾"""
    L = Layer()
    cx, foot = 657, 606
    top = foot - 84
    # 三只脚（左右两只往外撇，中间一只朝后）
    L.line(cx - 1, foot - 9, cx - 8, foot - 1, "wd2")
    L.line(cx - 1, foot - 8, cx - 8, foot, "wd1")
    L.line(cx + 1, foot - 9, cx + 8, foot - 1, "wd2")
    L.line(cx + 1, foot - 8, cx + 8, foot, "wd1")
    L.rect(cx - 1, foot - 10, cx + 2, foot - 2, "wd2")
    L.p(cx - 9, foot, "gd2")
    L.p(cx + 9, foot, "gd2")
    # 立杆：三像素宽，左亮右暗，中段一圈车木纹
    L.rect(cx - 1, top + 5, cx + 2, foot - 8, "wd3")
    L.vl(cx - 1, top + 5, foot - 8, "wd5")
    L.vl(cx + 1, top + 5, foot - 8, "wd1")
    for ry in (top + 40, foot - 14):
        L.rect(cx - 2, ry, cx + 3, ry + 3, "wd3")
        L.hl(cx - 2, cx + 3, ry, "wd5")
        L.hl(cx - 2, cx + 3, ry + 2, "wd1")
    # 顶球
    L.ell(cx - 3, top, cx + 4, top + 6, "wd3")
    L.p(cx - 1, top + 1, "wd5")
    L.p(cx - 2, top + 2, "wd4")
    L.hl(cx - 1, cx + 3, top + 5, "wd1")
    # 挂钩（往上翘，钩头一点铜）
    for (dx, dy) in ((-6, 8), (7, 8), (-5, 14), (6, 14)):
        sx = cx if dx < 0 else cx + 1
        L.line(sx, top + dy + 2, cx + dx, top + dy - 1, "wd2")
        L.p(cx + dx, top + dy - 2, "gd3")
    # 红围巾：搭在右上钩，一长一短两头垂下，下摆金穗
    sx0 = cx + 4
    L.rect(sx0, top + 6, sx0 + 4, top + 38, "rd3")
    L.vl(sx0, top + 6, top + 38, "rd4")
    L.vl(sx0 + 3, top + 8, top + 38, "rd2")
    L.rect(sx0 + 4, top + 7, sx0 + 7, top + 27, "rd2")
    L.vl(sx0 + 6, top + 8, top + 27, "rd1")
    for yy in range(top + 12, top + 38, 6):
        L.hl(sx0, sx0 + 4, yy, "rd2")
    L.hl(sx0, sx0 + 4, top + 6, "rd5")
    for xx in range(sx0, sx0 + 4):
        L.p(xx, top + 38 + (xx % 2), "gd3")
    for xx in range(sx0 + 4, sx0 + 7):
        L.p(xx, top + 27 + (xx % 2), "gd3")
    # 大衣：挂在左上钩。肩膀被挂钩提起来、往下慢慢放宽到下摆
    hx, hy = cx - 6, top + 7              # 挂钩
    body = [(hx - 1, hy + 1), (hx + 3, hy + 2), (hx + 5, hy + 8), (hx + 6, hy + 52), (hx - 13, hy + 54),
            (hx - 12, hy + 12), (hx - 8, hy + 4)]
    L.poly(body, "bl1")
    # 受光的左半边
    L.poly([(hx - 1, hy + 2), (hx - 8, hy + 5), (hx - 11, hy + 12), (hx - 11, hy + 52), (hx - 5, hy + 52),
            (hx - 4, hy + 10)], "bl2")
    L.line(hx - 8, hy + 6, hx - 11, hy + 14, "bl3")
    # 领子、翻领（V 形）
    L.poly([(hx - 1, hy + 1), (hx + 3, hy + 2), (hx + 1, hy + 9), (hx - 2, hy + 6)], "bl0")
    L.line(hx - 2, hy + 3, hx - 6, hy + 20, "bl3")
    L.line(hx - 1, hy + 4, hx - 4, hy + 21, "bl0")
    L.line(hx + 2, hy + 4, hx - 1, hy + 21, "bl0")
    # 一排金扣
    for k in range(4):
        L.p(hx - 3, hy + 24 + k * 7, "gd3")
        L.p(hx - 3, hy + 25 + k * 7, "gd1")
    # 前襟一道暗缝
    L.vl(hx - 2, hy + 21, hy + 53, "bl0")
    # 口袋盖
    L.hl(hx - 10, hx - 5, hy + 38, "bl0")
    L.hl(hx - 10, hx - 5, hy + 37, "bl3")
    # 垂下来的袖子（左侧，袖口露一截）
    L.poly([(hx - 12, hy + 12), (hx - 9, hy + 13), (hx - 9, hy + 44), (hx - 13, hy + 45)], "bl1")
    L.vl(hx - 12, hy + 13, hy + 45, "bl2")
    L.vl(hx - 9, hy + 14, hy + 44, "bl0")
    L.rect(hx - 13, hy + 42, hx - 8, hy + 46, "bl0")
    L.hl(hx - 13, hx - 8, hy + 42, "bl2")
    # 下摆
    L.hl(hx - 13, hx + 6, hy + 53, "bl0")
    L.outline()
    return L, foot


def prop_side_walls():
    """东西两道隔墙：只看得见墙顶（剖开的那一条），从北墙顶一直连到前沿矮墙"""
    L = Layer()
    for (a, b) in (WALL_W, WALL_E):
        L.rect(a, CAP_Y0, b, FRONT_FACE, "wl4")
        L.vl(a + 1, CAP_Y0 + 1, FRONT_FACE, "wl5")
        L.vl(a, CAP_Y0, FRONT_FACE, "ol")
        L.vl(b - 1, CAP_Y0, FRONT_FACE, "ol")
    # 跟北墙顶接上（北墙顶是背景里画的，这里只补拐角的描边）
    L.hl(WALL_W[0], WALL_W[1], CAP_Y0, "ol")
    L.hl(WALL_E[0], WALL_E[1], CAP_Y0, "ol")
    # 西墙里侧跟北墙墙面接的那一格，北墙顶下沿的描边要断开
    for (a, b) in (WALL_W, WALL_E):
        for y in range(CAP_Y0 + 1, CAP_Y1 - 1):
            L.p(a + 1 if a == WALL_W[0] else b - 2, y, "wl5")
    return L, 684


def front_wall_face(L, a, b):
    """前沿矮墙朝走廊的那一面：木护墙板一格一格（封闭的凸板，左上亮右下暗）+ 踢脚"""
    L.rect(a, FRONT_FACE, b, FRONT_BOT, "wd3")
    L.hl(a, b, FRONT_FACE, "ol")
    L.hl(a, b, FRONT_FACE + 1, "wd4")
    L.hl(a, b, FRONT_FACE + 2, "wd2")
    px0 = a + 3
    while px0 + 15 <= b - 2:
        L.rect(px0, FRONT_FACE + 5, px0 + 15, FRONT_BOT - 6, "wd3")
        L.hl(px0, px0 + 15, FRONT_FACE + 5, "wd2")
        L.vl(px0, FRONT_FACE + 5, FRONT_BOT - 6, "wd2")
        L.hl(px0 + 1, px0 + 15, FRONT_BOT - 7, "wd4")
        L.vl(px0 + 14, FRONT_FACE + 6, FRONT_BOT - 6, "wd4")
        L.rect(px0 + 3, FRONT_FACE + 8, px0 + 12, FRONT_BOT - 9, "wd3")
        L.hl(px0 + 3, px0 + 12, FRONT_FACE + 8, "wd4")
        L.vl(px0 + 3, FRONT_FACE + 8, FRONT_BOT - 9, "wd4")
        L.hl(px0 + 3, px0 + 12, FRONT_BOT - 10, "wd2")
        L.vl(px0 + 11, FRONT_FACE + 9, FRONT_BOT - 9, "wd2")
        px0 += 18
    L.rect(a, FRONT_BOT - 4, b, FRONT_BOT, "wd1")
    L.hl(a, b, FRONT_BOT - 4, "wd2")
    L.hl(a, b, FRONT_BOT - 1, "wd0")


def prop_front_walls():
    """前沿矮墙：顶面（剖开的一条）+ 朝走廊的正面（木护墙板）；门洞两边一对门套"""
    L = Layer()
    for (a, b) in ((X0, DOOR[0]), (DOOR[1], X1)):
        # 顶面
        L.rect(a, FRONT_TOP, b, FRONT_FACE, "wl4")
        L.hl(a, b, FRONT_TOP, "ol")
        L.hl(a, b, FRONT_TOP + 1, "wl5")
        L.hl(a, b, FRONT_FACE - 1, "wl3")
        front_wall_face(L, a, b)
        # 门洞那头的端面
        if b == DOOR[0]:
            L.vl(b - 1, FRONT_TOP, FRONT_BOT, "ol")
        if a == DOOR[1]:
            L.vl(a, FRONT_TOP, FRONT_BOT, "ol")
    # 门套：门洞两边各一条深木框，比墙顶高出一点，脚下一块座
    for (a, b) in ((DOOR[0] - 6, DOOR[0]), (DOOR[1], DOOR[1] + 6)):
        L.rect(a, FRONT_TOP - 4, b, FRONT_BOT, "wd2")
        L.vl(a, FRONT_TOP - 4, FRONT_BOT, "wd4")
        L.vl(a + 1, FRONT_TOP - 3, FRONT_BOT, "wd3")
        L.vl(b - 1, FRONT_TOP - 4, FRONT_BOT, "wd1")
        L.hl(a, b, FRONT_TOP - 4, "wd5")
        L.hl(a, b, FRONT_TOP - 3, "wd4")
        L.rect(a, FRONT_BOT - 6, b, FRONT_BOT, "wd1")
        L.hl(a, b, FRONT_BOT - 6, "wd3")
    # 隔墙顶在这里拐进前沿墙顶：把隔墙里侧那条描边断开
    for (a, b) in (WALL_W, WALL_E):
        L.rect(a + 1, FRONT_TOP, b - 1, FRONT_FACE - 1, "wl4")
    L.outline(skip=lambda x, y: y >= FRONT_FACE or x < WALL_W[0] or x >= WALL_E[1])
    return L, 696


# ================================================================== 影子、暖光
def floor_shading(props_info):
    S = ShadeMap()
    # 北墙脚一条暗
    S.rect(WALL_W[1], FLOOR_Y, WALL_E[0], FLOOR_Y + 2, -1.5)
    S.rect(WALL_W[1], FLOOR_Y + 2, WALL_E[0], FLOOR_Y + 5, -0.5)
    # 西墙往东投一条影（光从左上来）
    S.rect(WALL_W[1], FLOOR_Y, WALL_W[1] + 6, 662, -1.0)
    S.rect(WALL_W[1] + 6, FLOOR_Y, WALL_W[1] + 9, 662, -0.5)
    # 东墙根一点点暗
    S.rect(WALL_E[0] - 2, FLOOR_Y, WALL_E[0], 662, -0.5)
    # 前沿矮墙里侧
    S.rect(WALL_W[1], 659, WALL_E[0], 662, -0.5)
    # 家具底下：贴地一圈深、往右下拖一点
    for (x0, y0, x1, y1, k) in props_info:
        S.rect(x0 + 1, y0 + 1, x1 + 2, y1 + 2, k, feather=1)
    # 茶几底下（桌腿之间看得见的地毯）
    S.rect(541, 296, 593, 314, -1.5)
    # 落地灯：两圈暖光（外圈亮一档、里圈再亮一档，边上各一圈棋盘点）
    S.ellipse(630, 266, 46, 30, 1.0, edge=1.5)
    S.ellipse(630, 263, 24, 15, 1.0, edge=1.5)
    # 门口走廊透进来一点光：一个往里张开的梯形，整档 + 边上一像素棋盘点
    cone(S, 504, 683, 618, 40, 0.30, 1.0, edge=1.5)
    return S


def cone(S, cx, y_from, y_to, half0, spread, val, edge=1):
    """灯罩上下照出来的一束光：从 y_from 往 y_to 越来越宽，两条斜边各一像素棋盘点"""
    step = 1 if y_to > y_from else -1
    for y in range(y_from, y_to, step):
        d = abs(y - y_from)
        half = half0 + d * spread
        for x in range(int(cx - half) - 1, int(cx + half) + 2):
            dx = abs(x + 0.5 - cx)
            if dx <= half - edge:
                S.add(x, y, val)
            elif dx <= half:
                S.add(x, y, val * 0.5)


def wall_light(L):
    """落地灯照到墙上：灯罩口往上一束、往下一束，越远越淡"""
    S = ShadeMap()
    cone(S, 629, 182, 162, 9, 0.75, 1.0)             # 往上：近处整档
    cone(S, 629, 162, 146, 24, 0.75, 0.5)            # 再往上：一半（棋盘点）
    cone(S, 629, 202, 226, 13, 0.55, 1.0)            # 往下照到护墙板
    for y in range(184, 202):                         # 灯罩两边贴着的一小圈
        S.add(619 - (y - 184) // 5, y, 0.5)
        S.add(639 + (y - 184) // 5, y, 0.5)
    S.apply(L, clip=lambda x, y: y < FLOOR_Y and y > CAP_Y1 and x > WALL_W[1] and x < WALL_E[0])


# ================================================================== 组装
def build():
    bg = background()
    props = [
        ("vinyl_wall",) + prop_vinyl_wall(),
        ("plant_n",) + prop_plant_n(),
        ("floor_lamp",) + prop_floor_lamp(),
        ("sofa",) + prop_sofa(),
        ("record_player",) + prop_record_player(),
        ("luggage_1",) + prop_luggage_blue(),
        ("tea_table",) + prop_tea_table(),
        ("armchair_w",) + prop_armchair("w"),
        ("armchair_e",) + prop_armchair("e"),
        ("tv",) + prop_tv(),
        ("coat_rack",) + prop_coat_rack(),
        ("luggage_2",) + prop_luggage_brown(),
        ("plant_sw",) + prop_plant_sw(),
        ("side_walls",) + prop_side_walls(),
        ("front_walls",) + prop_front_walls(),
    ]
    shadows = [
        (352, 226, 496, 234, -1.0),     # 唱片墙
        (396, 258, 452, 284, -2.0),     # 唱片机
        (356, 280, 380, 290, -2.0),     # 蓝箱子
        (516, 236, 617, 268, -2.0),     # 沙发
        (480, 292, 523, 320, -2.0),
        (604, 292, 647, 320, -2.0),
        (538, 308, 596, 314, -1.0),     # 茶几脚
        (636, 360, 660, 418, -1.5),     # 电视柜
        (623, 255, 636, 261, -1.5),     # 落地灯座
        (636, 640, 655, 648, -2.0),     # 棕箱子
        (649, 600, 664, 606, -1.0),     # 衣帽架脚
        (350, 656, 370, 668, -2.0),     # 绿植
        (498, 234, 514, 242, -2.0),     # 北绿植
    ]
    S = floor_shading(shadows)
    S.apply(bg, clip=lambda x, y: y >= FLOOR_Y)
    wall_light(bg)
    # 落地灯照到旁边家具：沙发东头、东边单人沙发朝上的面亮一档
    for name, layer, foot in props:
        if name in ("sofa", "armchair_e"):
            P = ShadeMap()
            P.ellipse(632, 236, 30, 30, 1.0, edge=1)
            P.apply(layer)
    return bg, props


def compose(bg, props, people=()):
    out = bg.im.copy()
    items = [(foot, 0, name, layer) for (name, layer, foot) in props]
    for k, (img, fx, fy) in enumerate(people):
        items.append((fy, 1, "person%d" % k, (img, fx, fy)))
    items.sort(key=lambda t: (t[0], t[1]))
    for foot, kind, name, obj in items:
        if kind == 0:
            out.alpha_composite(obj.im, (obj.ox - X0, obj.oy - Y0))
        else:
            img, fx, fy = obj
            out.alpha_composite(img, (fx - img.width // 2 - X0, fy - img.height - Y0))
    return out


def guest(n, frame=0):
    im = Image.open(CHAR_DIR + "chr_LM-GUEST-%s.png" % n).convert("RGBA")
    return im.crop((frame * 64, 0, frame * 64 + 64, 84))


def palette_count(im):
    cols = set()
    for c in im.getdata():
        if c[3] == 255:
            cols.add(c[:3])
        elif c[3] != 0:
            raise SystemExit("有半透明像素：%s" % (c,))
    return cols


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else None
    check_layout()
    bg, props = build()
    room = compose(bg, props)
    cols = palette_count(room)
    print("整间 %s，颜色 %d 种" % (room.size, len(cols)))
    room.save(os.path.join(HERE, "lounge01_room.png"))
    room.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(HERE, "lounge01_room_x2.png"))
    if tag:
        room.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(HERE, tag + ".png"))
    # 三联对照：02 | 这版 | 厨房（同一比例，都是游戏画布 1:1 截的）
    full = Image.open(FULL_02).convert("RGBA")
    p02 = full.crop((X0, Y0, X1, Y1))
    kit = full.crop((1012, Y0, 1012 + W, Y1))
    gap = 8
    cmp_ = Image.new("RGBA", (W * 3 + gap * 4, H + gap * 2), C["void"])
    for k, im in enumerate((p02, room, kit)):
        cmp_.alpha_composite(im, (gap + k * (W + gap), gap))
    cmp_.save(os.path.join(HERE, "lounge01_compare.png"))
    # 手机竖屏 540×960
    phone(bg, props)


def phone(bg, props):
    SW, SH = 540, 960
    ox, oy = 94 - X0, 80 - Y0            # 画布 → 屏幕
    scr = Image.new("RGBA", (SW, SH), C["void"])
    # 走廊：画布 y 696..884，整屏宽
    cor = Layer(x0=-ox, y0=696, w=SW, h=200)
    draw_corridor(cor)
    scr.alpha_composite(cor.im, (0, 696 + oy))
    people = [(guest("03"), 424, 326), (guest("09"), 506, 478)]
    bgp = Layer()
    bgp.im = bg.im.copy()
    bgp.px = bgp.im.load()
    S = ShadeMap()
    for (img, fx, fy) in people:
        S.ellipse(fx + 1, fy - 1, 12, 4, -1.5, edge=1.5)
    S.apply(bgp)
    room = compose(bgp, props, people)
    room = room.crop((0, 0, W, FRONT_BOT - Y0))       # 走廊那一条由走廊图负责
    scr.alpha_composite(room, (X0 + ox, Y0 + oy))
    # 前沿矮墙往两边接出去（隔壁房间的前墙，护墙板接着排）
    fw = Layer(x0=-ox, y0=FRONT_TOP, w=SW, h=FRONT_BOT - FRONT_TOP)
    for (a, b) in ((-ox, X0), (X1, -ox + SW)):
        fw.rect(a, FRONT_TOP, b, FRONT_FACE, "wl4")
        fw.hl(a, b, FRONT_TOP, "ol")
        fw.hl(a, b, FRONT_TOP + 1, "wl5")
        fw.hl(a, b, FRONT_FACE - 1, "wl3")
        front_wall_face(fw, a, b)
    scr.alpha_composite(fw.im, (0, FRONT_TOP + oy))
    scr.save(os.path.join(HERE, "lounge01_phone.png"))


def draw_corridor(L):
    """手机图底下那条走廊：米色石砖错缝（每块深浅不一）、中间一条红地毯（金边、回纹带）、南边墙顶"""
    x0, x1 = L.ox, L.ox + L.w
    rnd = random.Random(7)
    L.rect(x0, 696, x1, 884, "wl2")
    for row, y in enumerate(range(696, 884, 12)):
        off = 0 if row % 2 == 0 else 24
        for x in range(x0 - 48 + off, x1, 48):
            tone = rnd.choice(["wl2", "wl2", "wl3", "wl2", "wl1"])
            L.rect(x + 1, y + 1, x + 48, y + 12, tone)
            L.hl(x + 1, x + 48, y + 1, shift(tone, 1))
            L.vl(x + 1, y + 1, y + 12, shift(tone, 1))
            if rnd.random() < 0.3:                   # 石头上一两点斑
                L.p(x + rnd.randrange(4, 44), y + rnd.randrange(3, 10), shift(tone, -1))
            L.vl(x, y, y + 12, "wl0")
        L.hl(x0, x1, y, "wl0")
    # 红地毯：金边 + 两条回纹带
    L.rect(x0, 764, x1, 800, "rd3")
    L.hl(x0, x1, 764, "gd2")
    L.hl(x0, x1, 765, "gd3")
    L.hl(x0, x1, 798, "gd3")
    L.hl(x0, x1, 799, "gd1")
    for (by, flip) in ((768, False), (789, True)):
        for x in range(x0, x1):
            for r in range(7):
                row = KEY[6 - r] if flip else KEY[r]
                if row[(x - x0) % 8] == "1":
                    L.p(x, by + r, "rd2")
    for x in range(x0 + 6, x1, 16):
        L.poly([(x, 779), (x + 3, 782), (x, 785), (x - 3, 782)], "gd2")
        L.p(x, 782, "gd4")
    # 南边墙顶
    L.rect(x0, 884, x1, 896, "wl4")
    L.hl(x0, x1, 884, "ol")
    L.hl(x0, x1, 885, "wl5")
    L.hl(x0, x1, 895, "ol")
    # 墙脚影
    for x in range(x0, x1):
        L.shade_px(x, 697, -1)
        if x % 2 == 0:
            L.shade_px(x, 698, -1)
        L.shade_px(x, 883, -1)
        if x % 2:
            L.shade_px(x, 882, -1)


if __name__ == "__main__":
    main()
