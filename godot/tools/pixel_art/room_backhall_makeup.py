#!/usr/bin/env python3
"""【10/4 起这份不再出游戏用的图（02 F，01 H 定）】化妆间单独成了一间屋（room_makeup.py），后厅长条里原来那间封起来（backhall_makeup_door.py），
assets/pixel_art/backhall_makeup/ 删了。这份留着当画法库：那两份 import 它借家具、墙、镜子、红绸的画法。直接跑它会把旧图再出一遍，别跑。

后厅化妆间：用代码画的像素成品（06 画、第二版，阿鱼 10/3「我觉得你画的可以了，就这样」；标准见 docs/罗曼山庄画风.md 第 0 节）。
1 倍颗粒、62 色调色板（休息间 57 色 + 银三档、粉两档）、硬边、光从左上来、按着地线分层；墙、地板跟休息间同一套，接得上。

出游戏用的图（assets/pixel_art/backhall_makeup/）：
  room.png        背景：北墙（剖开的墙顶、墙纸、护墙板）、三面明星镜、红绸金结、小红灯笼、地板、分区地毯、换装小圆毯、门口地垫、影子和灯光
  props/*.png     每件家具一张（裁到画了的那块、只留这间那半：x 0～331），按着地线跟人排前后
  room.json       放哪：背景左上角；每件左上角 x、y 和着地线 foot；要藏掉的灰盒 id。entrance.gd 的 _pixel_art() 读它
位置：PLAN 这张表是画图的唯一源；layout.json 里 32 件 mk_ 灰盒（挡人占地）照它摆。开头先核：墙、门口、换装点没动，
PLAN 每件跟 layout.json 里同名那件 rect / h 一样，对不上就停（改了摆法两边一起改）。再从门口做一遍走路检查。
样板原稿在 godot/回执/样板间-化妆间/draw_makeup.py；这份是 02 收进来、改成出游戏用的图，画法一笔没动。
人（新娘、两位化妆师）不画进图里：游戏里用定稿宾客当替身（layout.json npcs 的 standin），以后换 GPT 画的。

用法：python3 godot/tools/pixel_art/room_backhall_makeup.py [--preview 目录]
      --preview 再出整间 1:1、放大 2 倍、跟休息间并排、手机竖屏（站替身）几张给人看
坐标全用游戏画布坐标（1536×1024 那块画布），1 个美术像素 = 1 个画布像素。
斜俯视、没有透视：地面前后 1 米 = 32 像素，左右和高 1 米 = 48 像素。
化妆间 x 0～336（西边是后厅西外墙，东边跟休息间共用 331～341 那道隔墙），门洞 128～208。
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backhall_floor import HW_HEX, HW_RAMP, draw_floor_v3   # 地板 v3：三间共用一份（同一个文件夹）
import backhall_plan_c   # 10/4 方案 C：后厅四间整间平移（这间 +1195），这里照旧按平移前的坐标画

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_backhall", "layout.json")
CHAR_DIR = os.path.join(GODOT, "assets", "characters", "lm") + "/"
LOUNGE_PNG = os.path.join(GODOT, "回执", "样板间-休息间-01版", "lounge01_room.png")
OUT = os.path.join(GODOT, "assets", "pixel_art", "backhall_makeup")
RES = "res://assets/pixel_art/backhall_makeup/"
BG_CROP = (0, 104, 341, 696)   # 进游戏的范围：西外墙到东边那道墙外沿（平移前的坐标）。10/4 方案 C：化妆间挪到最东头，
                               # 西外墙 0～10 落到跟休息室共用的隔墙上，原来归休息间画的 331～341 那道成了最东边外墙，这间自己画（多裁 10 像素）
DX = backhall_plan_c.DX["makeup"]   # 进游戏时整间往东挪多少（出 room.json 时加上；读 layout.json 时先挪回来再核）

# 整间出图的范围（画布坐标）：跟休息间一样宽 352、高 600；西边 8 像素是画布外（x<0），涂深底
X0, Y0, X1, Y1 = -8, 100, 344, 700
W, H = X1 - X0, Y1 - Y0
LOUNGE_X0 = 328                     # 休息间成品图左边对应的画布 x

# ------------------------------------------------------------------ 调色板
# 休息间的 57 色原样照搬（墙、地板、木头一模一样才接得上），新加 5 色：
#   银（sv0～sv2）：民族服装的银饰、西式头冠、婚纱的冷色暗部
#   粉（pk0、pk2）：跟原来的 pk 连成一条粉色色带（花、伴娘裙、粉盒）
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
    # 新加 5 色
    "sv0": "#737a8f", "sv1": "#a3abbe", "sv2": "#d3d8e3",
    "pk0": "#a8455e", "pk2": "#f4bfc8",
}
PAL_HEX.update(HW_HEX)          # 地板 v3：蜜色木 hw0～hw6（新名字的色带，fl0～fl7 一个没改）


def hex2rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


C = {k: hex2rgba(v) for k, v in PAL_HEX.items()}
RAMPS = {
    "hw": HW_RAMP,
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
    "sv": ["sv0", "sv1", "sv2"],
    "pk": ["pk0", "pk", "pk2"],
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

def front_wall_face(L, a, b, start=None):
    """前沿矮墙朝走廊的那一面：木护墙板一格一格（封闭的凸板，左上亮右下暗）+ 踢脚"""
    L.rect(a, FRONT_FACE, b, FRONT_BOT, "wd3")
    L.hl(a, b, FRONT_FACE, "ol")
    L.hl(a, b, FRONT_FACE + 1, "wd4")
    L.hl(a, b, FRONT_FACE + 2, "wd2")
    px0 = a + 3 if start is None else start     # start：凸板从哪起排（对齐隔壁休息间的板）
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



# ------------------------------------------------------------------ 小工具
def sub(x0, y0, x1, y1):
    """一块小画布（画一件小东西、单独描边再贴回去用）"""
    return Layer(x0=int(x0), y0=int(y0), w=int(x1 - x0), h=int(y1 - y0))


def poly_px(pts):
    """多边形里有哪些像素（画布坐标）"""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ox, oy = int(min(xs)) - 1, int(min(ys)) - 1
    w, h = int(max(xs)) - ox + 3, int(max(ys)) - oy + 3
    m = Image.new("1", (w, h), 0)
    ImageDraw.Draw(m).polygon([(x - ox, y - oy) for x, y in pts], fill=1)
    pm = m.load()
    return {(x + ox, y + oy) for y in range(h) for x in range(w) if pm[x, y]}


def rows_of(S):
    r = {}
    for (x, y) in S:
        a, b = r.get(y, (x, x))
        r[y] = (min(a, x), max(b, x))
    return r


def fill_lit(L, S, ramp, lv, hi=2, lo=2):
    """一块布/面（第二版起直接走 cloth：亮、中、暗三档 + 竖褶 + 下摆暗边；高的才加褶）"""
    if S:
        ys = [y for (_, y) in S]
        cloth(L, S, ramp, lv, folds=2 if max(ys) - min(ys) >= 28 else 0, seed=min(x for x, _ in S))
        return
    r = rows_of(S)
    for (x, y) in S:
        a, b = r[y]
        k = lv
        if x < a + hi:
            k = lv + 1
        elif x > b - lo:
            k = lv - 1
        L.p(x, y, rname(ramp, k))


def bottom_of(S):
    cols = {}
    for (x, y) in S:
        cols[x] = max(cols.get(x, y), y)
    return cols


def paste_ol(L, s):
    """小件单独描边后贴到大层上"""
    s.outline()
    L.paste(s)


# ------------------------------------------------------------------ 墙（画布坐标）
CAP_Y0, CAP_Y1 = 104, 114          # 北墙墙顶（剖开的厚度）
FLOOR_Y = 226                      # 北墙脚 = 地板开始
WALL_W = (0, 10)                   # 西外墙（后厅最西边）
WALL_E = (331, 341)                # 跟休息间共用的隔墙（layout 的 wall_1）
FRONT_TOP, FRONT_FACE, FRONT_BOT = 662, 674, 696   # 前沿矮墙：顶面 662..674，正面 674..696
DOOR = (128, 208)                  # 门洞（门口交互点 168,690）
DRESS = (168, 400)                 # 换装交互点
KNOTS = [10, 78, 137, 199, 258, 331]   # 北墙红绸的结（两两之间垂一个弧；结都落在镜子、衣柜之间的缝里）
VW = 56                                 # 化妆台宽
VANITY_X = (78, 140, 202)               # 三台化妆台的西边 x（中间那台正对门口 168）
STOOL_X = tuple(a + VW // 2 for a in VANITY_X)

# ------------------------------------------------------------------ 新摆法（唯一的源：画图、影子、layout 补丁都从这张表来）
# rect = 占地 [x0, y0, x1, y1]（画布坐标，y 是地面前后），h = 高（像素，1 米 48）
# 第二版：红毯拿掉；北墙两头换成两座开放式高衣墙；四个区都是「后排高架 + 前排矮架」前后叠着挂；中间加一张首饰中岛
PLAN = [
    # id, 名字, 区, rect, h, 挡人
    ("mk_closet_cn", "中式开放衣墙（上层绸缎帽盒、中间挂短褂、下层绣花鞋、挂两把团扇）", "中式", [12, 228, 74, 242], 98, True),
    ("mk_vanity_1", "明星化妆台 1（连墙上灯泡镜）", "化妆", [78, 228, 134, 246], 36, True),
    ("mk_vanity_2", "明星化妆台 2（新娘这台）", "化妆", [140, 228, 196, 246], 36, True),
    ("mk_vanity_3", "明星化妆台 3", "化妆", [202, 228, 258, 246], 36, True),
    ("mk_stool_1", "化妆凳 1", "化妆", [97, 258, 115, 268], 22, True),
    ("mk_stool_2", "化妆凳 2（新娘坐）", "化妆", [159, 258, 177, 268], 22, True),
    ("mk_stool_3", "化妆凳 3", "化妆", [221, 258, 239, 268], 22, True),
    ("mk_closet_west", "西式开放衣墙（上层帽盒、中间挂短外套衬衫、下层一排高跟鞋）", "西式", [262, 228, 328, 242], 98, True),
    ("mk_rack_cn_back", "中式后排高架（六件：秀禾、龙凤褂、裙褂、马面裙…）", "中式", [14, 332, 96, 344], 90, True),
    ("mk_rack_cn_front", "中式前排矮架（四件旗袍）", "中式", [36, 374, 104, 384], 78, True),
    ("mk_crown_stand", "凤冠架（头模戴凤冠、披红盖头）", "中式", [12, 378, 32, 388], 74, True),
    ("mk_rack_west_back", "西式后排高架（七件：婚纱、晚礼服、西装、伴娘裙）", "西式", [240, 332, 330, 344], 90, True),
    ("mk_rack_west_front", "西式前排矮架（四件：短婚纱、小礼服、燕尾服、马甲）", "西式", [232, 366, 296, 376], 80, True),
    ("mk_gown_form", "人台上的大拖尾婚纱（带头纱）", "西式", [298, 374, 330, 388], 82, True),
    ("mk_rack_jp_back", "日式后排黑漆衣架（五件振袖、白无垢、留袖）", "日式", [14, 456, 104, 468], 80, True),
    ("mk_iko", "和服衣桁（红打褂）", "日式", [14, 494, 86, 504], 77, True),
    ("mk_tansu", "黑漆小柜（上面腰带卷、扇子、发簪盒；脚边木屐）", "日式", [88, 506, 118, 520], 30, True),
    ("mk_ethnic_wall", "民族饰品墙（帽子、银项圈银锁、绣片、彩带、绣花鞋）", "民族", [226, 462, 330, 476], 88, True),
    ("mk_rack_ethnic", "民族服装架（五件：苗、藏、彝、傣、蒙古）", "民族", [222, 496, 298, 508], 72, True),
    ("mk_silver_crown", "苗族银角头冠架", "民族", [300, 500, 328, 510], 72, True),
    ("mk_steamer", "挂烫机（白、金色挂杆、一件衬衫挂着）", "西式", [222, 336, 236, 346], 82, True),
    ("mk_floor_vase", "落地大花瓶（青花、插牡丹）", "日式", [104, 444, 120, 456], 50, True),
    ("mk_island", "首饰中岛（玻璃台面：戒指耳环手镯项链；台上头冠、捧花、领结领带盒）", "饰品", [138, 500, 198, 528], 40, True),
    ("mk_full_mirror", "落地全身镜", "等候", [14, 598, 42, 606], 82, True),
    ("mk_sofa", "等候沙发（红丝绒两人位）", "等候", [46, 566, 118, 598], 41, True),
    ("mk_trunk", "陪嫁红木箱（上面一朵红绸花）", "等候", [48, 640, 94, 656], 26, True),
    ("mk_flowers", "门口落地花架", "等候", [100, 642, 120, 652], 58, True),
    ("mk_shoes", "鞋架（三层）", "换衣", [216, 598, 258, 612], 43, True),
    ("mk_flowers_e", "门口东边落地花架（跟西边那个一对）", "换衣", [214, 642, 234, 652], 58, True),
    ("mk_pouf", "试鞋圆墩（红丝绒）", "换衣", [238, 620, 258, 632], 20, True),
    ("mk_screen", "喜鹊登梅四扇屏风（换衣）", "换衣", [264, 596, 328, 606], 82, True),
    ("mk_gifts", "礼盒堆", "换衣", [270, 640, 326, 656], 36, True),
]
PLAN_BY_ID = {p[0]: p for p in PLAN}
# 平铺在地上、不挡人的
FLAT = [
    ("mk_dress_rug", "换装小圆毯（dress 交互点，低调）", [142, 390, 194, 418]),
    ("mk_rug_cn", "中式区红毯（回纹边）", [12, 322, 108, 396]),
    ("mk_rug_west", "西式区白毯（粉边、蕾丝角）", [228, 322, 330, 398]),
    ("mk_tatami", "日式区榻榻米（两张，黑布边）", [12, 446, 120, 526]),
    ("mk_rug_ethnic", "民族区彩织毯（条纹、流苏）", [218, 452, 330, 530]),
    ("mk_doormat", "门里地垫（跟休息间那块一样）", [144, 644, 192, 660]),
]
# 替身（以后换成 GPT 画的）：id、谁、用哪张定稿当替身、哪一格、脚点、坐不坐
STANDINS = [
    ("bride", "新娘（坐在中间化妆台前，背对镜头）", "02", 12, (168, 269), True),
    ("makeup_1", "化妆师（站在新娘右手边，侧身朝左）", "03", 4, (194, 273), False),
    ("makeup_2", "化妆师 2（站在中岛和民族区之间，侧身朝右）", "06", 8, (212, 552), False),
    ("guest", "来换装的客人（站在换装点）", "01", 0, (168, 409), False),
]

# 核对：没改的东西（墙、前沿矮墙、门口、换装点）跟 layout.json 对一遍，对不上就停
KEEP = {   # 平移前的坐标（layout.json 里的 −DX）；10/4 方案 C 起化妆间西边是休息室东墙 wall_3，门洞两边是 front_4、front_5
    "wall_3": ([0, 226, 10, 684], 44),
    "front_4": ([-123, 684, 128, 696], 22),
    "front_5": ([208, 684, 341, 696], 22),
}


def check_layout():
    d = backhall_plan_c.shift_layout(json.load(open(LAYOUT, encoding="utf-8")), -DX)
    items = {it["id"]: it for it in d["items"] if "id" in it}
    bad = []
    for iid, (rect, h) in KEEP.items():
        it = items.get(iid)
        if it is None or list(it.get("rect", [])) != rect or it.get("h") != h:
            bad.append("%s：脚本 %s h%s，布局 %s h%s" % (iid, rect, h, it and it.get("rect"), it and it.get("h")))
    for (iid, name, zone, r, h, block) in PLAN:
        it = items.get(iid)
        if it is None or list(it.get("rect", [])) != r or it.get("h") != h:
            bad.append("%s：画的 %s h%s，布局 %s h%s" % (iid, r, h, it and it.get("rect"), it and it.get("h")))
    pts = {p["id"]: p for p in d["points"]}
    if (pts["dress"]["x"], pts["dress"]["y"]) != DRESS:
        bad.append("dress 交互点变了：%s" % pts["dress"])
    if bad:
        raise SystemExit("layout.json 跟这版画的位置对不上：\n" + "\n".join(bad))
    # 新摆法自查：门口通道、换装点周围不许压东西
    for (iid, name, zone, r, h, block) in PLAN:
        x0, y0, x1, y1 = r
        if x1 > DOOR[0] and x0 < DOOR[1] and y1 > 560 and y0 < 662:
            raise SystemExit("%s 堵门口了" % iid)
        cx, cy = min(max(DRESS[0], x0), x1), min(max(DRESS[1], y0), y1)
        if math.hypot(cx - DRESS[0], cy - DRESS[1]) < 60:
            raise SystemExit("%s 离换装点不到 60 像素" % iid)
    return d


# ================================================================== 背景：墙、地板、地毯
def draw_north_wall(L):
    """跟休息间一模一样的北墙（墙纸、顶线脚、腰线、护墙板、踢脚线、墙顶剖面），x 从西外墙画到隔墙外"""
    x0, x1 = WALL_W[0], X1
    L.rect(x0, CAP_Y1, x1, FLOOR_Y, "wl3")
    xr = 331                                       # 休息间墙纸的花纹从 x=331 起算，这里往西接着排
    for y in range(CAP_Y1 + 5, 176):
        for x in range(x0, x1):
            gy = (y - 119) % 12
            gx = ((x - xr) + (6 if ((y - 119) // 12) % 2 else 0)) % 12
            d = abs(gx - 6) + abs(gy - 6)
            if d == 2:
                L.p(x, y, "wl2")
    for x in range(xr + 7 - 20 * 17, x1, 20):
        for y in range(CAP_Y1 + 5, 176):
            if L.g(x, y) == C["wl3"]:
                L.p(x, y, "wl4")
    L.hl(x0, x1, 114, "wd1")
    L.hl(x0, x1, 115, "wd4")
    L.hl(x0, x1, 116, "wd3")
    L.hl(x0, x1, 117, "wd3")
    L.hl(x0, x1, 118, "wd1")
    L.hl(x0, x1, 119, "wl1")
    L.hl(x0, x1, 120, "wl2")
    L.hl(x0, x1, 176, "wl1")
    L.hl(x0, x1, 177, "wd4")
    L.hl(x0, x1, 178, "wd3")
    L.hl(x0, x1, 179, "wd2")
    L.hl(x0, x1, 180, "wd1")
    L.rect(x0, 181, x1, 218, "wd2")
    # 护墙板：东边贴着隔墙往西排（跟休息间那边对称），每格 22 + 缝 4
    b = WALL_E[0] - 4
    while b - 22 > x0 + 2:
        a = b - 22
        L.rect(a, 184, b, 215, "wd3")
        L.hl(a, b, 184, "wd4")
        L.vl(a, 184, 215, "wd4")
        L.hl(a, b, 214, "wd1")
        L.vl(b - 1, 185, 215, "wd1")
        L.rect(a + 3, 187, b - 3, 212, "wd3")
        L.hl(a + 3, b - 3, 187, "wd1")
        L.vl(a + 3, 187, 212, "wd1")
        L.hl(a + 3, b - 3, 211, "wd4")
        L.vl(b - 4, 188, 212, "wd4")
        b = a - 4
    L.hl(x0, x1, 181, "wd1")
    L.hl(x0, x1, 218, "wd4")
    L.rect(x0, 219, x1, 225, "wd1")
    L.hl(x0, x1, 219, "wd2")
    L.hl(x0, x1, 225, "wd0")
    L.rect(x0, CAP_Y0, x1, CAP_Y1, "wl4")
    L.hl(x0, x1, CAP_Y0, "ol")
    L.hl(x0, x1, CAP_Y0 + 1, "wl5")
    L.hl(x0, x1, CAP_Y1 - 1, "ol")


def draw_swag(L):
    """北墙上沿一排红绸（跟宴会厅一个做法）：两个结之间垂一个弧，弧里几道褶，结上一朵金花、垂一束金穗"""
    for k in range(len(KNOTS) - 1):
        a, b = KNOTS[k], KNOTS[k + 1]
        wdt = b - a
        depth = 9 + wdt * 0.07
        for x in range(a, b):
            t = (x + 0.5 - a) / wdt
            sag = math.sin(math.pi * t)
            yb = 116 + depth * sag
            for y in range(116, int(yb) + 1):
                # 褶：跟着弧走的几道线（越往下越暗）
                f = (y - 116) / max(1.0, yb - 116)
                lv = 3
                if f > 0.82:
                    lv = 2
                band = (y - 116 - 3 * sag)
                if 0 <= band < 1.2 or 4.5 <= band < 5.5:
                    lv = 2
                if 1.2 <= band < 2.4 and 0.2 < t < 0.8:
                    lv = 4
                L.p(x, y, rname("rd", lv))
            L.p(x, int(yb) + 1, "rd1")                      # 下沿一条暗边
            if x % 2 == 0:
                L.p(x, int(yb) + 2, "wl1")                  # 墙上一点影（棋盘）
        L.hl(a, b, 115, "rd2")
    for kx in KNOTS:
        # 结：金色小花
        cx = kx
        L.ell(cx - 4, 113, cx + 4, 121, "rd2")
        L.ell(cx - 3, 114, cx + 3, 120, "gd3")
        L.p(cx - 1, 115, "gd4")
        L.p(cx, 117, "rd3")
        L.p(cx + 1, 118, "gd1")
        # 金穗（墙边那两个只垂短的）
        ln = 7 if kx in (KNOTS[0], KNOTS[-1]) else 9
        for yy in range(121, 121 + ln):
            L.p(cx - 1, yy, "gd2")
            L.p(cx, yy, "gd3")
            L.p(cx + 1, yy, "gd1")
        L.hl(cx - 1, cx + 2, 121 + ln, "rd3")
        L.p(cx, 122 + ln, "rd2")


def draw_lantern(L, cx, top, big=False):
    """小红灯笼（挂在红绸结下面）：金顶、红肚子（竖棱、中间透亮）、金底、红穗"""
    rx = 5 if big else 4
    hgt = 11 if big else 9
    L.vl(cx, top - 3, top, "gd1")
    L.rect(cx - 2, top, cx + 3, top + 2, "gd2")
    L.hl(cx - 2, cx + 3, top, "gd3")
    y0, y1 = top + 2, top + 2 + hgt
    L.ell(cx - rx, y0, cx + rx + 1, y1, "rd3")
    L.ell(cx - rx + 2, y0 + 2, cx + rx - 1, y1 - 2, "rd4")
    L.ell(cx - 1, y0 + 3, cx + 2, y1 - 3, "rd5")
    L.p(cx, y0 + 4, "gd4")
    L.vl(cx - rx + 1, y0 + 2, y1 - 2, "rd2")
    L.vl(cx + rx - 1, y0 + 2, y1 - 2, "rd2")
    L.ring(cx - rx, y0, cx + rx + 1, y1, "rd1", only=lambda x, y: x > cx + 1 or y > y1 - 3)
    L.rect(cx - 2, y1, cx + 3, y1 + 2, "gd2")
    L.hl(cx - 2, cx + 3, y1 + 1, "gd1")
    for yy in range(y1 + 2, y1 + 7):
        L.p(cx, yy, "rd3")
        L.p(cx + (1 if yy > y1 + 3 else 0), yy, "rd3")
    L.p(cx - 1, y1 + 6, "rd2")


MIRROR_TOP = 136                        # v3 拱顶最高点（北墙红绸最低垂到 y 130，拱顶让开 5 像素，不顶着红绸）
MIRROR_R = 24                           # 拱的半径 = 镜子宽 48 的一半（整半圆拱）
MIRROR_BAND = 6                         # 金框连灯泡那一圈多宽


def mirror_geom(a):
    """拱形镜子的几何：中心 x、拱心 y；dist(x, y) = 这个像素离拱心多远（拱下面的直段只算左右）"""
    cx = a + VW / 2.0
    cy = MIRROR_TOP + MIRROR_R

    def dist(x, y):
        px, py = x + 0.5, y + 0.5
        if py >= cy:
            return abs(px - cx)
        return math.hypot(px - cx, py - cy)

    def normal(x, y):
        px, py = x + 0.5, y + 0.5
        if py >= cy:
            return (1.0 if px > cx else -1.0), 0.0
        d = max(0.01, math.hypot(px - cx, py - cy))
        return (px - cx) / d, (py - cy) / d
    return cx, cy, dist, normal


def draw_star_mirror(L, a):
    """墙上的明星镜（v3，阿鱼 10/3「镜子可以做成拱形的镜子，你这都看不出来是化妆镜」）：
    上沿整半圆拱、两边直下去；金框一圈灯泡（拱上 7 个、两边直段各 3 个），镜面浅蓝、两道斜反光；下沿被化妆台台面挡住。
    光从左上：框的左上沿亮、右下沿暗，墙上往右下落一像素影"""
    R, B = MIRROR_R, MIRROR_BAND
    cx, cy, dist, normal = mirror_geom(a)
    y_top, y_bot = MIRROR_TOP, 200
    xa, xb = int(cx - R) - 1, int(cx + R) + 2
    inside = lambda x, y, r: y >= y_top - 1 and y < y_bot and dist(x, y) <= r
    # 墙上的影（往右下错一像素）
    for y in range(y_top, 194):
        for x in range(xa, xb + 1):
            if not inside(x, y, R) and inside(x - 1, y - 1, R):
                L.p(x, y, shift(L.g(x, y), -1))      # 墙纸上是 wl2、护墙板上是暗一档的木头
    # 框（金）：外沿左上亮、右下暗；第二圈左上一道浅；里口一圈暗金（镜面凹进去）
    for y in range(y_top - 1, y_bot):
        for x in range(xa, xb):
            d = dist(x, y)
            if d > R:
                continue
            ring = R - d
            if ring >= B:
                continue
            nx, ny = normal(x, y)
            lit = nx + ny                         # 越小越朝左上（受光）
            if ring < 1:
                c = "gd4" if lit < -0.35 else ("gd1" if lit > 0.45 else "gd3")
            elif ring < 2:
                c = "gd3" if lit < -0.2 else "gd2"
            elif ring >= B - 1:
                c = "gd1"
            else:
                c = "gd2"
            L.p(x, y, c)
    # 镜面：中蓝底、左上一块浅、下沿一条暗（台面挡光）；两道斜反光
    g = R - B
    gx0, gx1 = int(cx - g), int(cx + g)
    gy0, gy1 = int(cy - g), y_bot
    for y in range(gy0, gy1):
        for x in range(gx0, gx1 + 1):
            if dist(x, y) > g:
                continue
            u = (x - gx0) / float(gx1 - gx0)
            t = (y - gy0) / float(gy1 - gy0)
            c = "bl3"
            if u + t < 0.75 or (u + t < 0.85 and (x + y) % 2 == 0):
                c = "bl4"
            if t > 0.86 or (t > 0.8 and (x + y) % 2 == 0):
                c = "bl2"
            L.p(x, y, c)
    for (o, wdt) in ((10, 3), (17, 1)):
        for y in range(gy0 + 2, gy1 - 4):
            xx = gx0 + o + (gy1 - y) // 2 - 14
            for k in range(wdt):
                if dist(xx + k, y) <= g - 1.5:
                    L.p(xx + k, y, "wt")
    # 镜面上沿、左沿一线暗（框的影）
    for y in range(gy0, gy1):
        for x in range(gx0, gx1 + 1):
            d = dist(x, y)
            if g - 1 < d <= g:
                nx, ny = normal(x, y)
                if nx + ny < 0.2:
                    L.p(x, y, "bl2")
    # 灯泡：拱上 7 个（等角），两边直段各 3 个
    rc = R - B / 2.0
    bulbs = []
    for k in range(7):
        th = math.pi - k * math.pi / 6
        bulbs.append((cx - 0.5 + rc * math.cos(th), cy - 0.5 - rc * math.sin(th)))
    for k in range(1, 4):
        bulbs.append((cx - 0.5 - rc, cy - 0.5 + k * 11))
        bulbs.append((cx - 0.5 + rc, cy - 0.5 + k * 11))
    for (bx, by) in bulbs:
        bx, by = int(round(bx)), int(round(by))
        L.ell(bx - 2, by - 2, bx + 3, by + 3, "gd4")
        L.p(bx, by, "wt")
        L.p(bx - 1, by - 1, "wt")
        L.p(bx + 1, by + 1, "gd3")


def draw_floor(L):
    """地板 v3（阿鱼 10/3：01 版太细、06 第二版像酱油）：宽板蜜色木，三间共用 backhall_floor.py"""
    draw_floor_v3(L, WALL_W[0], X1, Y1, seed=0)


def draw_dress_rug(L):
    """换装点的小圆毯（第二版缩小、压暗：深红底、一圈细金线、中间一朵暗红小花）——以后换装就站在这上面"""
    cx, cy = DRESS[0], 404
    rx, ry = 26, 14
    L.ell(cx - rx, cy - ry, cx + rx, cy + ry, "rd1")
    L.ell(cx - rx + 1, cy - ry + 1, cx + rx - 1, cy + ry - 1, "rd2")
    L.ring(cx - rx + 3, cy - ry + 2, cx + rx - 3, cy + ry - 2, "gd1")
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        px_, py_ = cx + math.cos(a) * 9, cy + math.sin(a) * 5
        L.ell(px_ - 3, py_ - 2, px_ + 3, py_ + 2, "rd3")
    L.ell(cx - 4, cy - 2, cx + 4, cy + 2, "rd1")
    L.p(cx, cy, "gd2")


def draw_zone_rugs(L):
    """四个服装区各铺一块地，一眼分得开：中式红毯回纹边、西式白毯粉边、日式榻榻米、民族彩织毯"""
    rugs = {r[0]: r[2] for r in FLAT}
    # 中式：深红底、金线、回纹边
    x0, y0, x1, y1 = rugs["mk_rug_cn"]
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
    # 西式：米白底、粉边、四角蕾丝花
    x0, y0, x1, y1 = rugs["mk_rug_west"]
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
    # 日式：两张榻榻米（草绿黄、细纹、黑布边）
    x0, y0, x1, y1 = rugs["mk_tatami"]
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
    # 民族：彩条织毯 + 两头流苏
    x0, y0, x1, y1 = rugs["mk_rug_ethnic"]
    cols = ["rd3", "gd3", "rd2", "gr3", "bl2", "rd4", "or", "ik1", "pk", "tl"]
    for y in range(y0, y1):
        c = cols[((y - y0) // 3) % len(cols)]
        for x in range(x0 + 2, x1 - 2):
            cc = c
            if (y - y0) % 3 == 1 and (x // 3) % 2 == 0:
                cc = "wt" if c in ("ik1", "bl2", "rd2") else shift(c, -1)
            L.p(x, y, cc)
    for y in range(y0 + 1, y1 - 1, 2):
        L.p(x0, y, "wl4")
        L.p(x0 + 1, y, "wl3")
        L.p(x1 - 2, y, "wl3")
        L.p(x1 - 1, y, "wl4")


def draw_petals(L):
    rnd = random.Random(23)
    spots = [(136, 630), (198, 628), (158, 612), (182, 618), (132, 596), (204, 584), (150, 570), (190, 560),
             (172, 590), (166, 636), (124, 640), (210, 646)]
    for (x, y) in spots:
        c1, c2 = rnd.choice([("rd4", "rd5"), ("pk", "pk2"), ("pk", "wt"), ("rd4", "pk")])
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
    draw_zone_rugs(L)
    draw_dress_rug(L)
    draw_doormat(L)
    draw_petals(L)
    draw_north_wall(L)
    for a in VANITY_X:
        draw_star_mirror(L, a)
    draw_swag(L)
    for kx in KNOTS[1:-1]:
        draw_lantern(L, kx, 131)
    # 门槛
    L.rect(DOOR[0], 684, DOOR[1], 696, "wd4")
    L.hl(DOOR[0], DOOR[1], 684, "wd2")
    L.hl(DOOR[0], DOOR[1], 685, "wd5")
    L.hl(DOOR[0], DOOR[1], 690, "wd3")
    L.hl(DOOR[0], DOOR[1], 691, "wd5")
    L.hl(DOOR[0], DOOR[1], 695, "wd2")
    L.rect(X0, 696, X1, Y1, "wl2")
    # 画布外（x<0）
    L.rect(X0, Y0, 0, Y1, "void")
    return L


# ================================================================== 小摆件（化妆品、首饰、鞋、花）
def perfume(L, x, y, body="pk", cap="gd3"):
    """香水瓶：x,y 是瓶底左边；5 宽 7 高"""
    L.rect(x, y - 5, x + 5, y, body)
    L.vl(x, y - 5, y, shift(body, 1))
    L.vl(x + 4, y - 5, y, shift(body, -1))
    L.p(x + 1, y - 4, "wt")
    L.rect(x + 1, y - 7, x + 4, y - 5, cap)
    L.p(x + 1, y - 7, "gd4")


def lipstick(L, x, y, tip="rd4"):
    L.vl(x, y - 3, y, "gd2")
    L.p(x, y - 3, "gd3")
    L.vl(x, y - 5, y - 3, tip)


def brush_cup(L, x, y, cup="wt"):
    """笔筒插化妆刷：杯 5×5，刷子 5 支（木把、黑把，刷头深浅不一）"""
    for k, (dx, ln, hc, tc) in enumerate(((0, 7, "wd2", "wd4"), (1, 9, "ik2", "ik3"), (2, 8, "wd3", "pk"),
                                          (3, 10, "ik1", "wl2"), (4, 7, "wd2", "wd5"))):
        L.vl(x + dx, y - 4 - ln, y - 4, hc)
        L.p(x + dx, y - 5 - ln, tc)
        L.p(x + dx, y - 6 - ln, tc)
    L.rect(x - 1, y - 5, x + 6, y, cup)
    L.vl(x - 1, y - 5, y, shift(cup, 1) if cup != "wt" else "wt")
    L.vl(x + 5, y - 5, y, "bl4" if cup == "wt" else shift(cup, -1))
    L.hl(x - 1, x + 6, y - 3, "pk")


def palette(L, x, y):
    """打开的眼影盘：黑壳、翻起的盖子里一面小镜子、12 格颜色"""
    L.rect(x, y - 9, x + 12, y - 4, "ik1")                    # 盖子（立起来）
    L.rect(x + 1, y - 8, x + 11, y - 5, "bl4")
    L.p(x + 2, y - 8, "wt")
    L.rect(x, y - 4, x + 12, y, "ik1")
    cols = ["pk", "rd4", "gd3", "wd4", "pk2", "rd5", "wl3", "pu", "cl2", "gd4", "pk0", "wd2"]
    for i, c in enumerate(cols):
        L.p(x + 1 + (i % 6) * 2, y - 3 + (i // 6) * 2, c)


def compact(L, x, y, col="pk"):
    L.ell(x, y - 3, x + 6, y, "gd2")
    L.ell(x + 1, y - 3, x + 5, y - 1, col)
    L.p(x + 1, y - 3, "gd4")


def hairdryer(L, x, y):
    """吹风机（躺在台面上，粉色）：圆机身、出风筒朝右、把手朝下、一截电线"""
    L.ell(x, y - 7, x + 7, y, "pk")
    L.ell(x + 1, y - 6, x + 4, y - 3, "pk2")
    L.rect(x + 6, y - 6, x + 13, y - 2, "pk")
    L.hl(x + 6, x + 13, y - 6, "pk2")
    L.hl(x + 6, x + 13, y - 3, "pk0")
    L.rect(x + 13, y - 7, x + 15, y - 1, "ik2")
    L.rect(x + 2, y - 1, x + 5, y + 1, "pk0")
    L.line(x + 3, y + 1, x - 4, y + 1, "ik2")


def curling_iron(L, x, y):
    L.rect(x, y - 2, x + 9, y, "sv1")
    L.hl(x, x + 9, y - 2, "sv2")
    L.rect(x + 9, y - 3, x + 15, y, "ik2")
    L.p(x + 10, y - 3, "ik3")


def peony(L, cx, cy, ramp="pk", r=3):
    """一朵牡丹/玫瑰：圆的一团，左上亮右下暗，中间一点深"""
    L.ell(cx - r, cy - r, cx + r + 1, cy + r + 1, rname(ramp, 1))
    L.ell(cx - r, cy - r, cx + r, cy + r, rname(ramp, 2))
    L.p(cx - 1, cy - 1, "wt" if ramp == "pk" else rname(ramp, 4))
    L.p(cx, cy, rname(ramp, 0))
    L.p(cx + 1, cy, rname(ramp, 1))


def flower_vase(L, x, y, vase="wt"):
    """小花瓶插几朵牡丹（化妆台上）"""
    L.line(x + 3, y - 6, x - 1, y - 13, "gr2")
    L.line(x + 3, y - 6, x + 8, y - 12, "gr2")
    leaf(L, x - 2, y - 10, 6, -2.4, 3, 3, vein=False)
    leaf(L, x + 9, y - 9, 6, -0.6, 3, 3, vein=False)
    peony(L, x, y - 15, "pk", 3)
    peony(L, x + 7, y - 15, "rd", 3)
    peony(L, x + 3, y - 19, "pk", 3)
    L.p(x + 3, y - 12, "wt")
    L.p(x + 4, y - 12, "wt")
    L.rect(x + 1, y - 7, x + 6, y, vase)
    L.vl(x + 5, y - 7, y, "bl4")
    L.hl(x + 1, x + 6, y - 4, "bl2")
    L.rect(x + 2, y - 8, x + 5, y - 7, vase)


def towel_stack(L, x, y):
    for k, c in enumerate(("wt", "pk2", "wt")):
        yy = y - 2 - k * 2
        L.rect(x, yy, x + 9, yy + 2, c)
        L.vl(x + 8, yy, yy + 2, "sv2" if c == "wt" else "pk")


def jewel_box(L, x, y, open_=True):
    """红漆首饰盒：开着的盖子竖起来、里面一支金发簪"""
    L.rect(x, y - 4, x + 8, y, "rd3")
    L.hl(x, x + 8, y - 4, "rd4")
    L.vl(x + 7, y - 4, y, "rd2")
    L.p(x + 4, y - 2, "gd3")
    if open_:
        L.rect(x, y - 9, x + 8, y - 4, "rd2")
        L.rect(x + 1, y - 8, x + 7, y - 5, "rd1")
        L.line(x + 1, y - 5, x + 7, y - 7, "gd3")
        L.p(x + 6, y - 8, "rd5")


# ================================================================== 家具（每件一层）
def prop_vanity(i):
    """明星化妆台：奶白漆台面、金色台沿，左右两个抽屉柜、中间留放腿的空；台面摆满化妆品（三台各不一样）"""
    L = Layer()
    a = VANITY_X[i]
    x0, x1, yf0, yf1, h = a, a + VW, 228, 246, 36
    ty0, ty1 = yf0 - h, yf1 - h            # 192..210
    # 台面
    L.rect(x0, ty0, x1, ty1, "wl4")
    L.hl(x0, x1, ty0, "wl3")                  # 贴墙那边一条暗（镜子的影）
    L.hl(x0 + 1, x1 - 1, ty0 + 1, "wl5")
    L.vl(x0, ty0, ty1, "wl5")
    L.vl(x1 - 1, ty0, ty1, "wl3")
    # 台沿（金）
    L.rect(x0, ty1, x1, ty1 + 3, "gd2")
    L.hl(x0, x1, ty1, "gd4")
    L.hl(x0, x1, ty1 + 2, "gd1")
    # 正面
    fy0 = ty1 + 3
    L.rect(x0, fy0, x1, yf1, "wl3")
    L.vl(x0, fy0, yf1, "wl4")
    L.vl(x1 - 1, fy0, yf1, "wl1")
    pw = 16
    for (p0, p1) in ((x0 + 2, x0 + 2 + pw), (x1 - 2 - pw, x1 - 2)):
        for (d0, d1) in ((fy0 + 2, fy0 + 11), (fy0 + 12, fy0 + 21), (fy0 + 22, yf1 - 4)):
            L.rect(p0, d0, p1, d1, "wl2")
            L.rect(p0 + 1, d0 + 1, p1 - 1, d1 - 1, "wl3")
            L.hl(p0 + 1, p1 - 1, d0 + 1, "wl4")
            L.hl(p0, p1, d1 - 1, "wl1")
            mx = (p0 + p1) // 2
            L.rect(mx - 1, (d0 + d1) // 2 - 1, mx + 2, (d0 + d1) // 2 + 1, "gd3")
            L.p(mx - 1, (d0 + d1) // 2 - 1, "gd4")
    # 中间：浅抽屉 + 放腿的空
    c0, c1 = x0 + 3 + pw, x1 - 3 - pw
    L.rect(c0, fy0 + 2, c1, fy0 + 8, "wl2")
    L.rect(c0 + 1, fy0 + 3, c1 - 1, fy0 + 7, "wl3")
    L.hl(c0 + 1, c1 - 1, fy0 + 3, "wl4")
    L.rect((c0 + c1) // 2 - 2, fy0 + 4, (c0 + c1) // 2 + 2, fy0 + 6, "gd3")
    L.rect(c0, fy0 + 9, c1, yf1, "wd0")
    L.hl(c0, c1, fy0 + 9, "ol")
    L.rect(c0 + 1, fy0 + 10, c1 - 1, yf1, "wd1")
    L.vl(c1 - 2, fy0 + 10, yf1, "wd0")
    # 金脚
    for lx in (x0 + 1, c0 - 3, c1 + 1, x1 - 4):
        L.rect(lx, yf1 - 3, lx + 3, yf1, "gd1")
        L.p(lx, yf1 - 3, "gd3")
    L.hl(x0 + 2, x1 - 2, yf1 - 4, "wl1")
    # 台面上的东西（底边在台面上，往上立起来）
    b = ty0 + 9                            # 摆放的一排「底线」（台面靠后）
    f = ty0 + 15                           # 靠前一排
    if i == 0:
        hairdryer(L, x0 + 3, f)
        brush_cup(L, x0 + 22, b + 1)
        perfume(L, x0 + 31, b, "pk")
        perfume(L, x0 + 37, b - 1, "gd3", "rd3")
        for k, c in enumerate(("rd4", "pk", "rd3", "pk0")):
            lipstick(L, x0 + 30 + k * 2, f)
        compact(L, x0 + 40, f + 1, "pk2")
        towel_stack(L, x0 + 46, b + 1)
        palette(L, x0 + 19, f + 1)
    elif i == 1:
        brush_cup(L, x0 + 4, b + 1, "pk")
        palette(L, x0 + 13, b + 1)
        jewel_box(L, x0 + 28, b + 1)
        perfume(L, x0 + 39, b, "wt", "gd3")
        perfume(L, x0 + 45, b + 1, "rd4")
        for k, c in enumerate(("rd4", "rd3", "pk")):
            lipstick(L, x0 + 5 + k * 2, f + 1)
        compact(L, x0 + 13, f + 1, "pk")
        compact(L, x0 + 21, f + 2, "wl3")
        # 粉扑一团、一卷刷子包摊开
        L.rect(x0 + 30, f - 1, x0 + 48, f + 2, "wl1")
        L.hl(x0 + 30, x0 + 48, f - 1, "wl2")
        for k in range(8):
            L.vl(x0 + 31 + k * 2, f - 3, f + 1, ("ik2", "wd3", "ik1", "wd2")[k % 4])
            L.p(x0 + 31 + k * 2, f - 4, ("wd4", "pk", "ik3", "wl2")[k % 4])
        L.ell(x0 + 50, f - 2, x0 + 55, f + 2, "pk2")
    else:
        flower_vase(L, x0 + 3, b + 1)
        curling_iron(L, x0 + 14, f + 1)
        perfume(L, x0 + 16, b, "pk2")
        perfume(L, x0 + 22, b + 1, "gd3")
        brush_cup(L, x0 + 30, b + 1)
        palette(L, x0 + 38, f + 1)
        for k, c in enumerate(("pk", "rd4", "pk0")):
            lipstick(L, x0 + 52 + k * 2 - 4, b + 1)
        compact(L, x0 + 30, f + 2, "gd3")
    L.outline()
    return L, yf1


def prop_stool(i):
    """化妆凳：圆的红丝绒坐垫（拉扣）、金滚边、四条弯金腿"""
    L = Layer()
    cx = STOOL_X[i]
    yf1 = 268
    top = yf1 - 22                         # 坐垫面中心
    L.ell(cx - 9, top - 6, cx + 10, top + 5, "rd2")
    for y in range(top - 6, top + 5):
        for x in range(cx - 9, cx + 10):
            if L.g(x, y) == C["rd2"]:
                u = (x + 0.5 - cx) / 9.5
                v = (y + 0.5 - top + 0.5) / 5.5
                b = puff_level(u, v)
                L.p(x, y, "rd4" if b > 0.6 else ("rd3" if b > 0.1 else "rd2"))
    L.p(cx, top - 1, "rd1")
    L.p(cx - 1, top - 2, "rd5")
    # 坐垫侧边 + 金滚边
    L.rect(cx - 9, top + 2, cx + 10, top + 7, "rd2")
    L.ell(cx - 9, top + 4, cx + 10, top + 9, "rd2")
    L.hl(cx - 8, cx + 9, top + 3, "gd3")
    L.ring(cx - 9, top + 4, cx + 10, top + 9, "gd2", only=lambda x, y: y >= top + 7)
    L.vl(cx - 9, top + 2, top + 7, "rd3")
    # 腿
    for (lx, d) in ((cx - 7, -1), (cx + 7, 1)):
        L.line(lx, top + 8, lx + d, yf1 - 3, "gd2")
        L.line(lx + 1, top + 8, lx + 1 + d, yf1 - 3, "gd1")
        L.p(lx + 2 * d, yf1 - 2, "gd3")
        L.p(lx + 2 * d + (1 if d > 0 else 0), yf1 - 1, "gd2")
    for lx in (cx - 3, cx + 3):
        L.vl(lx, top + 8, yf1 - 6, "gd1")
    L.outline()
    return L, yf1


# ------------------------------------------------------------------ 衣服（挂在衣架/衣杆上）
def hanger(L, cx, ty):
    L.p(cx, ty - 1, "gd2")
    L.p(cx, ty - 2, "gd3")
    L.p(cx + 1, ty - 3, "gd3")
    L.p(cx + 2, ty - 2, "gd2")


def garment_xiuhe(L, cx, ty, length=62, small=False, gold=False):
    """秀禾服（gold=True 是龙凤褂：通身金线）：宽袖短上衣（立领、盘扣、金边）+ 马面百褶长裙"""
    s = 0.75 if small else 1.0

    def P(dx, dy):
        return (cx + round(dx * s), ty + dy)
    hanger(L, cx, ty)
    jy = 26 if not small else 21
    skirt = poly_px([P(-7, jy), P(7, jy), P(11, length)] + hem_arc(cx, ty + length, round(11 * s), 2)[1:-1] +
                    [P(-11, length)])
    jacket = poly_px([P(-4, 0), P(4, 0), P(9, 3), P(13, jy - 5), P(8, jy - 3), P(7, 12), P(7, jy),
                      P(-7, jy), P(-7, 12), P(-8, jy - 3), P(-13, jy - 5), P(-9, 3)])
    base = 2 if gold else 3
    fill_lit(L, skirt, "rd", base)
    # 百褶：每 3 像素一道褶
    sr = rows_of(skirt)
    for (x, y) in skirt:
        a, b = sr[y]
        if (x - a) % 3 == 0 and a < x < b and y > ty + jy + 2:
            L.p(x, y, rname("rd", base - 1))
    # 马面（正中一块平的，金边）
    for y in range(ty + jy + 1, ty + length):
        w = 2 + (y - ty - jy) // 12
        for x in range(cx - w, cx + w + 1):
            if (x, y) in skirt:
                L.p(x, y, rname("rd", base + 1) if not gold else "gd2")
        L.p(cx - w - 1, y, "gd3")
        L.p(cx + w + 1, y, "gd2")
        if (y - ty) % 6 == 0:
            L.p(cx, y, "gd3" if not gold else "rd3")
    # 裙摆金边
    for (x, y) in skirt:
        if y >= ty + length - 3:
            L.p(x, y, "gd3" if (x + y) % 3 else "gd2")
    if gold:
        # 龙凤褂：裙上一层金鳞纹
        for (x, y) in skirt:
            r_ = (y - ty) // 3
            u = (x - cx + (2 if r_ % 2 else 0)) % 4
            if (y - ty) % 3 == 0 and u in (1, 2) and abs(x - cx) > 3:
                L.p(x, y, "gd3")
    fill_lit(L, jacket, "rd", base)
    br = bottom_of(jacket)
    for (x, y) in jacket:
        if y >= br[x] - 1:
            L.p(x, y, "gd3" if x < cx else "gd2")             # 袖口、下摆金边
    if gold:
        for (x, y) in jacket:
            if (x * 3 + y * 2) % 5 == 0 or ((x + 2 * y) % 7 == 0):
                L.p(x, y, "gd3" if x < cx + 3 else "gd2")
        # 胸前一对金团纹（龙、凤）
        for (ox, oy) in ((-4, 8), (4, 8)):
            L.ell(cx + ox - 2, ty + oy - 2, cx + ox + 3, ty + oy + 3, "gd3")
            L.p(cx + ox, ty + oy, "rd3")
    else:
        for (ox, oy) in ((-5, 9), (4, 14), (-3, 17), (9, 15), (-10, 15)):
            if (cx + round(ox * s), ty + oy) in jacket:
                x_, y_ = cx + round(ox * s), ty + oy
                L.p(x_, y_, "gd3")
                L.p(x_ - 1, y_, "gd2")
                L.p(x_ + 1, y_, "gd2")
                L.p(x_, y_ - 1, "gd2")
                L.p(x_, y_ + 1, "gd2")
    # 立领、对襟、盘扣
    L.rect(cx - 2, ty, cx + 3, ty + 2, "gd3")
    L.p(cx - 2, ty, "gd4")
    L.vl(cx, ty + 2, ty + jy, "rd1")
    for k in range(3):
        yy = ty + 6 + k * (5 if not small else 4)
        L.hl(cx - 1, cx + 2, yy, "gd3")
        L.p(cx - 1, yy, "gd4")


def garment_qipao(L, cx, ty, ramp="rd", lv=3, length=56, motif="gd3"):
    """旗袍：高立领、斜襟（金滚边、两粒盘扣）、短袖、收腰、开衩；身上几朵金花"""
    hanger(L, cx, ty)
    yl = length
    S = poly_px([(cx - 3, ty), (cx + 3, ty), (cx + 7, ty + 3), (cx + 8, ty + 8), (cx + 6, ty + 9),
                 (cx + 5, ty + 15), (cx + 4, ty + 19), (cx + 6, ty + 28), (cx + 6, ty + yl)] + hem_arc(cx, ty + yl, 6, 1)[1:-1] + [(cx - 6, ty + yl),
                 (cx - 6, ty + 28), (cx - 4, ty + 19), (cx - 5, ty + 15), (cx - 6, ty + 9), (cx - 8, ty + 8),
                 (cx - 7, ty + 3)])
    fill_lit(L, S, ramp, lv)
    # 腰身的明暗：腰两边收进去一点暗
    for (x, y) in S:
        if ty + 15 <= y <= ty + 22 and (x - cx) in (-4, 4):
            L.p(x, y, rname(ramp, lv - 1))
    # 领
    L.rect(cx - 2, ty - 2, cx + 3, ty + 1, rname(ramp, lv))
    L.hl(cx - 2, cx + 3, ty - 2, motif)
    L.hl(cx - 2, cx + 3, ty, motif)
    # 斜襟
    L.line(cx, ty + 1, cx + 5, ty + 7, motif)
    L.line(cx + 5, ty + 7, cx + 5, ty + 12, motif)
    L.p(cx + 3, ty + 4, "gd4")
    L.p(cx + 5, ty + 10, "gd4")
    # 袖口滚边
    L.line(cx + 6, ty + 9, cx + 8, ty + 8, motif)
    L.line(cx - 6, ty + 9, cx - 8, ty + 8, motif)
    # 开衩 + 下摆滚边
    L.vl(cx + 5, ty + yl - 13, ty + yl, rname(ramp, lv - 2))
    L.hl(cx - 6, cx + 7, ty + yl - 1, motif)
    # 金花
    for (ox, oy) in ((-2, 22), (2, 33), (-3, 42), (3, 15), (-1, 50)):
        if oy < yl - 2:
            x_, y_ = cx + ox, ty + oy
            L.p(x_, y_, "gd4" if motif == "gd3" else "wt")
            for (dx, dy) in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                L.p(x_ + dx, y_ + dy, motif)


def garment_gown(L, cx, ty, length=72, sleeves=False):
    """白婚纱：抹胸（金珠一排）、收腰缎带、长裙摆（几道冷色褶、蕾丝花边）"""
    hanger(L, cx, ty)
    L.line(cx - 1, ty, cx - 4, ty + 3, "sv1")
    L.line(cx + 1, ty, cx + 4, ty + 3, "sv1")
    bod = poly_px([(cx - 5, ty + 3), (cx - 2, ty + 4), (cx, ty + 3), (cx + 2, ty + 4), (cx + 5, ty + 3),
                   (cx + 5, ty + 13), (cx + 3, ty + 17), (cx - 3, ty + 17), (cx - 5, ty + 13)])
    skirt = poly_px([(cx - 3, ty + 17), (cx + 3, ty + 17), (cx + 8, ty + 38), (cx + 13, ty + length),
                     (cx - 13, ty + length), (cx - 8, ty + 38)])
    if sleeves:
        for d in (-1, 1):
            sl = poly_px([(cx + 5 * d, ty + 3), (cx + 8 * d, ty + 5), (cx + 9 * d, ty + 20), (cx + 6 * d, ty + 20)])
            for (x, y) in sl:
                L.p(x, y, "sv2" if (x + y) % 2 else "wt")       # 蕾丝袖（透一点）
    for (x, y) in skirt:
        L.p(x, y, "wt")
    sr = rows_of(skirt)
    for (x, y) in skirt:
        a, b = sr[y]
        t = (y - ty - 17) / float(length - 17)
        if x > b - 2 - int(t * 3):
            L.p(x, y, "sv2")
        if x >= b:
            L.p(x, y, "sv1")
    # 褶：从腰往下散开的几道
    for k, off in enumerate((-0.55, -0.15, 0.25, 0.6)):
        for y in range(ty + 22, ty + length - 1):
            t = (y - ty - 17) / float(length - 17)
            x = cx + off * (3 + 10 * t) + math.sin(y * 0.35 + k) * 0.6
            L.p(x, y, "sv2" if k % 2 == 0 else "sv1")
            if k == 0 or k == 2:
                L.p(x - 1, y, "wt")
    # 蕾丝下摆：一串小弧
    for (x, y) in skirt:
        if y >= ty + length - 3:
            u = (x - cx) % 4
            if y == ty + length - 1 or (y == ty + length - 2 and u in (0, 3)):
                L.p(x, y, "sv2")
            elif y == ty + length - 3 and u == 1:
                L.p(x, y, "sv1")
    for (x, y) in bod:
        L.p(x, y, "wt")
    for (x, y) in bod:
        if x >= cx + 4:
            L.p(x, y, "sv2")
    for k in range(-4, 5, 2):
        L.p(cx + k, ty + 5, "gd4")
    L.hl(cx - 4, cx + 4, ty + 16, "pk2")
    L.hl(cx - 3, cx + 3, ty + 17, "pk")
    L.p(cx + 2, ty + 18, "pk")
    L.p(cx + 3, ty + 19, "pk")


def garment_tux(L, cx, ty):
    """黑礼服（新郎西装）：缎面翻领、白衬衫、黑领结、红口袋巾、两粒扣；下面一条西裤"""
    hanger(L, cx, ty)
    pants = poly_px([(cx - 6, ty + 36), (cx + 6, ty + 36), (cx + 6, ty + 64), (cx + 1, ty + 64), (cx, ty + 44),
                     (cx - 1, ty + 64), (cx - 6, ty + 64)])
    fill_lit(L, pants, "ik", 1, hi=1, lo=1)
    for (x, y) in pants:
        if (x - cx) in (-3, 3) and y > ty + 40:
            L.p(x, y, "ik2")
    jk = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + 9, ty + 3), (cx + 10, ty + 30), (cx + 8, ty + 40),
                  (cx - 8, ty + 40), (cx - 10, ty + 30), (cx - 9, ty + 3)])
    fill_lit(L, jk, "ik", 1, hi=1, lo=1)
    # 袖子的缝
    for d in (-1, 1):
        L.vl(cx + 7 * d, ty + 6, ty + 34, "ik0")
        L.hl(cx + 7 * d if d > 0 else cx - 10, cx + 10 if d > 0 else cx - 7, ty + 33, "ik3")
    # 衬衫 V + 翻领
    shirt = poly_px([(cx - 3, ty), (cx + 3, ty), (cx, ty + 14)])
    for (x, y) in shirt:
        L.p(x, y, "wt")
    L.line(cx - 3, ty, cx, ty + 15, "ik3")
    L.line(cx - 4, ty + 1, cx - 1, ty + 16, "ik2")
    L.line(cx + 3, ty, cx, ty + 15, "ik2")
    L.line(cx + 4, ty + 1, cx + 1, ty + 16, "ik3")
    L.hl(cx - 2, cx + 3, ty + 3, "ik0")
    L.p(cx, ty + 3, "ik2")
    for k in (19, 25):
        L.p(cx, ty + k, "ik3")
    L.rect(cx - 7, ty + 10, cx - 4, ty + 12, "rd4")
    L.p(cx - 6, ty + 9, "rd5")


def garment_miao(L, cx, ty):
    """苗族盛装：靛蓝对襟上衣（袖上两道彩绣、襟边一串银泡）、百褶裙（下摆彩色花带）"""
    hanger(L, cx, ty)
    skirt = poly_px([(cx - 7, ty + 26), (cx + 7, ty + 26), (cx + 11, ty + 60), (cx - 11, ty + 60)])
    fill_lit(L, skirt, "ik", 1, hi=1, lo=1)
    sr = rows_of(skirt)
    for (x, y) in skirt:
        a, b = sr[y]
        if (x - a) % 2 == 0 and y > ty + 28:
            L.p(x, y, "ik2")
        if y >= ty + 48:
            band = (y - ty - 48) // 3
            L.p(x, y, ("rd3", "gd3", "gr3", "rd4")[band % 4] if (x + band) % 2 else ("rd2", "gd2", "gr2", "rd3")[band % 4])
    jk = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + 9, ty + 3), (cx + 12, ty + 22), (cx + 8, ty + 23), (cx + 7, ty + 12),
                  (cx + 7, ty + 28), (cx - 7, ty + 28), (cx - 7, ty + 12), (cx - 8, ty + 23), (cx - 12, ty + 22),
                  (cx - 9, ty + 3)])
    fill_lit(L, jk, "bl", 1, hi=1, lo=1)
    # 袖上彩绣两道
    for (x, y) in jk:
        if abs(x - cx) > 7:
            yy = y - ty
            if 13 <= yy <= 15 or 18 <= yy <= 20:
                L.p(x, y, ("rd4", "gd3", "or", "gr3")[(x + y) % 4])
    # 襟边、下摆彩绣 + 银泡
    for (x, y) in jk:
        if y >= ty + 26:
            L.p(x, y, ("rd3", "gd3")[(x + y) % 2])
    for k in range(5):
        L.p(cx - 2, ty + 4 + k * 5, "sv2")
        L.p(cx + 2, ty + 4 + k * 5, "sv2")
        L.p(cx - 2, ty + 5 + k * 5, "sv0")
        L.p(cx + 2, ty + 5 + k * 5, "sv0")
    L.vl(cx, ty + 1, ty + 28, "bl0")
    L.rect(cx - 3, ty, cx + 4, ty + 2, "rd4")
    for k in range(-6, 7, 3):
        L.p(cx + k, ty + 29, "sv2")


def garment_tibet(L, cx, ty):
    """藏装：绛红长袍（长袖、斜襟金边）、腰下系一块彩条邦典围裙"""
    hanger(L, cx, ty)
    S = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + 10, ty + 4), (cx + 13, ty + 30), (cx + 9, ty + 31), (cx + 8, ty + 16),
                 (cx + 8, ty + 66), (cx - 8, ty + 66), (cx - 8, ty + 16), (cx - 9, ty + 31), (cx - 13, ty + 30),
                 (cx - 10, ty + 4)])
    fill_lit(L, S, "rd", 2)
    br = bottom_of(S)
    for (x, y) in S:
        if y >= br[x] - 1:
            L.p(x, y, "gd2" if abs(x - cx) > 8 else "wl4")         # 袖口、下摆一道白边（羔皮）
    L.line(cx - 3, ty, cx + 5, ty + 10, "gd3")
    L.line(cx - 3, ty + 1, cx + 5, ty + 11, "bl3")
    L.rect(cx - 7, ty + 26, cx + 8, ty + 29, "gd2")                 # 腰带
    L.hl(cx - 7, cx + 8, ty + 26, "gd3")
    cols = ["rd4", "gd3", "gr3", "bl3", "wt", "pk", "tl2", "or"]
    for y in range(ty + 29, ty + 63):
        k = (y - ty - 29) // 2
        for x in range(cx - 6, cx + 7):
            c = cols[k % len(cols)]
            L.p(x, y, c if x < cx + 5 else shift(c, -1))
    L.vl(cx - 6, ty + 29, ty + 63, "ol")
    L.vl(cx + 7, ty + 29, ty + 63, "ol")
    # 四角绣花
    L.p(cx - 5, ty + 30, "gd4")
    L.p(cx + 5, ty + 30, "gd4")


def garment_yi(L, cx, ty):
    """彝族盛装：黑上衣（领口、袖口红黄镶边）、三层大摆长裙（红、蓝、红黑），层间花边"""
    hanger(L, cx, ty)
    tiers = [((-7, 24), (7, 24), (9, 36), (-9, 36), "rd", 3),
             ((-9, 36), (9, 36), (11, 48), (-11, 48), "bl", 2),
             ((-11, 48), (11, 48), (13, 62), (-13, 62), "rd", 3)]
    for (p1, p2, p3, p4, ramp, lv) in tiers:
        S = poly_px([(cx + p1[0], ty + p1[1]), (cx + p2[0], ty + p2[1]), (cx + p3[0], ty + p3[1]),
                     (cx + p4[0], ty + p4[1])])
        fill_lit(L, S, ramp, lv, hi=1, lo=1)
        for (x, y) in S:
            if y == ty + p4[1] - 1:
                L.p(x, y, "gd3" if x % 2 else "ik1")
            if y == ty + p4[1] - 3 and x % 3 == 0:
                L.p(x, y, "gd3")
    jk = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + 9, ty + 3), (cx + 11, ty + 20), (cx + 8, ty + 21), (cx + 7, ty + 10),
                  (cx + 7, ty + 25), (cx - 7, ty + 25), (cx - 7, ty + 10), (cx - 8, ty + 21), (cx - 11, ty + 20),
                  (cx - 9, ty + 3)])
    fill_lit(L, jk, "ik", 1, hi=1, lo=1)
    br = bottom_of(jk)
    for (x, y) in jk:
        if y >= br[x] - 3 and abs(x - cx) > 7:
            L.p(x, y, ("rd4", "gd3", "rd4", "bl3")[(br[x] - y)])
    L.line(cx - 3, ty, cx + 5, ty + 9, "rd4")
    L.line(cx - 3, ty + 1, cx + 5, ty + 10, "gd3")
    for k in range(3):
        L.p(cx + 5, ty + 13 + k * 4, "sv2")


def prop_gown_form():
    """人台上的大拖尾婚纱：金脚架、白抹胸、蓬蓬大裙摆（一层层裙褶、蕾丝花边），头纱从肩上披下来（网纱）"""
    L = Layer()
    cx, yf1 = 314, PLAN_BY_ID["mk_gown_form"][3][3]
    top = yf1 - 82
    # 头纱（网纱：一格一格的点，透着后面）先画
    veil = poly_px([(cx - 2, top + 2), (cx + 3, top + 2), (cx + 12, top + 30), (cx + 15, top + 70), (cx + 8, top + 74),
                    (cx + 4, top + 40)])
    for (x, y) in veil:
        if (x + y) % 2 == 0:
            L.p(x, y, "wt")
        elif (x * 3 + y) % 7 == 0:
            L.p(x, y, "sv2")
    # 人台：脖子金帽、躯干
    L.rect(cx - 1, top, cx + 2, top + 3, "gd3")
    L.p(cx - 1, top, "gd4")
    torso = poly_px([(cx - 4, top + 3), (cx + 4, top + 3), (cx + 6, top + 8), (cx + 5, top + 20), (cx + 3, top + 28),
                     (cx - 3, top + 28), (cx - 5, top + 20), (cx - 6, top + 8)])
    for (x, y) in torso:
        L.p(x, y, "wl2" if x < cx + 4 else "wl1")
    # 抹胸（白、金珠）
    bod = [(x, y) for (x, y) in torso if y >= top + 9]
    for (x, y) in bod:
        L.p(x, y, "wt" if x < cx + 4 else "sv2")
    L.hl(cx - 5, cx + 6, top + 9, "sv1")
    for k in range(-4, 5, 2):
        L.p(cx + k, top + 10, "gd4")
    # 大裙摆：三层
    for k, (yy0, yy1, hw0, hw1) in enumerate(((top + 27, top + 50, 5, 12), (top + 40, top + 66, 9, 15),
                                               (top + 56, yf1 - 1, 12, 17))):
        S = poly_px([(cx - hw0, yy0), (cx + hw0, yy0), (cx + hw1, yy1), (cx - hw1, yy1)])
        sr = rows_of(S)
        for (x, y) in S:
            a, b = sr[y]
            c = "wt"
            if x > b - 3:
                c = "sv2"
            if x >= b:
                c = "sv1"
            # 裙褶
            t = (x - a) / max(1.0, (b - a))
            if abs(((t * 5) % 1.0) - 0.5) < 0.09 and y > yy0 + 3:
                c = "sv2"
            L.p(x, y, c)
        for x in range(cx - hw1, cx + hw1 + 1):
            if (x - cx) % 3 == 0:
                L.p(x, yy1 - 1, "sv1")
            else:
                L.p(x, yy1, "sv2")
    # 腰上一朵粉缎花
    L.ell(cx - 3, top + 25, cx + 3, top + 30, "pk")
    L.p(cx - 1, top + 26, "pk2")
    L.p(cx + 1, top + 28, "pk0")
    L.outline()
    return L, yf1


# ------------------------------------------------------------------ 首饰区
def phoenix_crown(L, cx, by):
    """凤冠：金色半圆冠身、点翠（蓝）、红绒球、两边各一只小金凤，下沿一排珍珠流苏"""
    L.ell(cx - 7, by - 10, cx + 8, by + 2, "gd2")
    L.ell(cx - 6, by - 9, cx + 6, by, "gd3")
    for (x, y) in ((cx - 4, by - 6), (cx + 3, by - 6), (cx, by - 8), (cx - 1, by - 3), (cx + 4, by - 2)):
        L.p(x, y, "bl2")
        L.p(x + 1, y, "tl")
    for (x, y) in ((cx - 2, by - 10), (cx + 2, by - 11), (cx, by - 12)):
        L.p(x, y, "rd4")
        L.p(x, y - 1, "rd5")
    L.p(cx - 8, by - 6, "gd3")
    L.p(cx - 9, by - 7, "gd4")
    L.p(cx + 8, by - 6, "gd3")
    L.p(cx + 9, by - 7, "gd4")
    for k in range(-6, 7, 2):
        L.vl(cx + k, by, by + 3, "wt")
        L.p(cx + k, by + 3, "rd4")


def tiara(L, cx, by):
    """西式头冠：银色、正中高两边低，几颗亮钻"""
    for k in range(-6, 7):
        hgt = 5 - abs(k) // 2
        L.vl(cx + k, by - hgt, by, "sv1" if k % 2 else "sv2")
    L.hl(cx - 6, cx + 7, by, "sv0")
    for (x, y) in ((cx, by - 6), (cx - 3, by - 4), (cx + 3, by - 4)):
        L.p(x, y, "wt")
    L.p(cx, by - 3, "bl4")
    # 丝绒座
    L.ell(cx - 6, by, cx + 7, by + 4, "rd1")


def bust(L, cx, by, neck="gd"):
    """首饰半身模：深色丝绒，戴项链"""
    L.rect(cx - 1, by - 11, cx + 2, by - 6, "ik2")
    L.poly([(cx - 4, by - 6), (cx + 5, by - 6), (cx + 6, by), (cx - 5, by)], "ik2")
    L.vl(cx - 4, by - 6, by, "ik3")
    if neck == "gd":
        L.ring(cx - 4, by - 9, cx + 5, by - 1, "gd3", only=lambda x, y: y > by - 6)
        L.p(cx, by - 1, "rd4")
        L.p(cx, by, "gd3")
    else:
        for k in range(-3, 4):
            L.p(cx + k, by - 4 + (abs(k) // 2) * -1 + 1, "wt")


# ------------------------------------------------------------------ 日式区
def prop_iko():
    """衣桁（黑漆、金饰件、顶横梁两头翘）上张开一件红色打褂：领子交叠（白衬领、金边）、
    满身白鹤、金云、松枝，下摆一圈厚的「ふき」；脚边一双草履"""
    L = Layer()
    x0, yf0, x1, yf1 = PLAN_BY_ID["mk_iko"][3]
    h = PLAN_BY_ID["mk_iko"][4]
    top = yf1 - h
    cx = (x0 + x1) // 2                   # 56
    # 衣服
    sleeves = []
    for d in (-1, 1):
        a = cx + d * 18
        b = cx + d * 38
        sl = poly_px([(min(a, b), top + 2), (max(a, b), top + 2), (max(a, b), top + 26), (max(a, b) - 2, top + 29),
                      (min(a, b) + 2, top + 29), (min(a, b), top + 26)])
        sleeves.append(sl)
    body = poly_px([(cx - 20, top + 2), (cx + 20, top + 2), (cx + 22, top + 66), (cx - 22, top + 66)])
    allp = body | sleeves[0] | sleeves[1]
    fill_lit(L, allp, "rd", 3, hi=2, lo=2)
    # 袖子下沿、身子跟袖子之间的缝
    for sl in sleeves:
        br = bottom_of(sl)
        for (x, y) in sl:
            if y >= br[x] - 1:
                L.p(x, y, "rd2")
    for d in (-1, 1):
        L.vl(cx + d * 19, top + 4, top + 28, "rd2")
    # 领子：白衬领 + 金边，交叠成 V
    for t in range(0, 34):
        xl = cx - 7 + t * 7 / 34.0
        xr_ = cx + 7 - t * 7 / 34.0
        y = top + 2 + t
        L.p(xl, y, "wt")
        L.p(xl + 1, y, "gd3")
        L.p(xr_, y, "wt")
        L.p(xr_ - 1, y, "gd3")
    L.vl(cx, top + 36, top + 64, "rd1")                   # 前襟
    L.vl(cx + 1, top + 36, top + 64, "rd4")
    # 金云
    rnd = random.Random(5)
    for (ox, oy) in ((-14, 40), (10, 48), (-6, 56), (14, 30), (-28, 14), (26, 10)):
        x, y = cx + ox, top + oy
        for k in range(5):
            L.p(x + k, y, "gd3")
        L.p(x + 1, y - 1, "gd3")
        L.p(x + 3, y - 1, "gd3")
        L.p(x + 2, y - 2, "gd4")
    # 白鹤（白身、黑颈、红顶）
    for (ox, oy, d) in ((-12, 22, 1), (8, 38, -1), (-30, 6, 1)):
        x, y = cx + ox, top + oy
        L.rect(x, y, x + 5, y + 2, "wt")
        L.p(x + (5 if d > 0 else -1), y - 1, "ik1")
        L.p(x + (6 if d > 0 else -2), y - 2, "ik1")
        L.p(x + (6 if d > 0 else -2), y - 3, "rd4")
        L.line(x, y - 2, x + 2, y, "wt")
        L.line(x + 4, y - 3, x + 3, y, "wt")
        L.p(x - (1 if d > 0 else -5), y + 1, "ik1")
    # 松枝
    for (ox, oy) in ((12, 18), (-18, 50), (16, 58)):
        x, y = cx + ox, top + oy
        L.hl(x, x + 6, y, "wd1")
        for k in range(0, 6, 2):
            L.p(x + k, y - 1, "gr3")
            L.p(x + k + 1, y - 1, "gr2")
            L.p(x + k, y + 1, "gr2")
    # 下摆的厚边
    for x in range(cx - 23, cx + 24):
        L.p(x, top + 65, "rd2")
        L.p(x, top + 66, "rd1")
        L.p(x, top + 67, "gd2" if x % 2 else "rd2")
    # 衣桁（黑漆）：立柱、两道横梁（顶梁两头翘）、脚
    for px_ in (x0 + 2, x1 - 5):
        L.rect(px_, top - 2, px_ + 3, yf1 - 3, "ik1")
        L.vl(px_, top - 2, yf1 - 3, "ik3")
        L.rect(px_ - 4, yf1 - 4, px_ + 7, yf1, "ik1")
        L.hl(px_ - 4, px_ + 7, yf1 - 4, "ik3")
        L.p(px_ - 4, yf1 - 1, "gd3")
        L.p(px_ + 6, yf1 - 1, "gd3")
    L.rect(x0 - 3, top - 2, x1 + 3, top + 2, "ik1")
    L.hl(x0 - 3, x1 + 3, top - 2, "ik3")
    for (ex, d) in ((x0 - 3, -1), (x1 + 2, 1)):
        L.p(ex, top - 3, "ik1")
        L.p(ex + d, top - 4, "ik1")
        L.p(ex + d, top - 3, "ik1")
        L.p(ex + d, top - 5, "gd3")
    L.rect(x0 + 2, top + 30, x0 + 6, top + 33, "ik1")
    L.rect(x1 - 5, top + 30, x1 - 1, top + 33, "ik1")
    for px_ in (x0 + 2, x1 - 5):
        L.rect(px_, top - 2, px_ + 3, top + 1, "gd2")
    # 草履一双（白底红带）
    for zx in (cx - 6, cx + 1):
        L.ell(zx, yf1 - 3, zx + 6, yf1 + 1, "wl4")
        L.hl(zx + 1, zx + 5, yf1 - 3, "wt")
        L.p(zx + 2, yf1 - 2, "rd4")
        L.p(zx + 3, yf1 - 3, "rd4")
        L.p(zx + 4, yf1 - 2, "rd4")
    L.outline()
    return L, yf1


def prop_silver_crown():
    """苗族银饰架：木杆上一个靛蓝布面的半身模，头上戴一对大银角（往两边张开、尖往里勾，角面錾花），
    角中间一扇银花；额前一道红绣带、垂一排银流苏；肩上压三层银项圈（一层比一层大）"""
    L = Layer()
    cx, yf1 = 314, PLAN_BY_ID["mk_silver_crown"][3][3]
    # 底座、立杆
    L.ell(cx - 8, yf1 - 5, cx + 9, yf1 + 1, "wd2")
    L.ell(cx - 8, yf1 - 6, cx + 9, yf1 - 1, "wd3")
    L.hl(cx - 5, cx + 5, yf1 - 5, "wd4")
    L.rect(cx - 1, yf1 - 30, cx + 2, yf1 - 4, "wd3")
    L.vl(cx - 1, yf1 - 30, yf1 - 4, "wd5")
    L.vl(cx + 1, yf1 - 30, yf1 - 4, "wd1")
    # 半身模（靛蓝布）
    sy = yf1 - 30                     # 肩下沿
    body = poly_px([(cx - 3, sy - 14), (cx + 4, sy - 14), (cx + 10, sy - 9), (cx + 10, sy), (cx - 9, sy), (cx - 9, sy - 9)])
    fill_lit(L, body, "bl", 1, hi=2, lo=2)
    L.rect(cx - 2, sy - 19, cx + 3, sy - 13, "wl2")          # 脖子
    L.vl(cx + 2, sy - 19, sy - 13, "wl1")
    # 银项圈：三层弯月
    # 先垫一块红绣领（银圈底下露一圈红）
    for x in range(cx - 10, cx + 11):
        u = (x - cx) / 10.0
        yb = sy - 13 + int(round(6 * (1 - u * u)))
        for t in range(3):
            L.p(x, yb + t, "rd3" if t < 2 else "rd2")
    for k in range(3):
        yy = sy - 16 + k * 3
        rx = 5 + k * 2
        for x in range(cx - rx, cx + rx + 1):
            u = (x - cx) / float(rx)
            yb = yy + int(round((3 + k) * (1 - u * u)))
            L.p(x, yb, "wt" if x < cx - 1 else "sv2")
            L.p(x, yb + 1, "sv1")
            L.p(x, yb + 2, "sv0")
    # 头模（没有脸）
    hy = sy - 25
    L.ell(cx - 5, hy - 6, cx + 6, hy + 7, "wl3")
    L.ell(cx - 4, hy - 5, cx + 3, hy + 3, "wl4")
    L.vl(cx + 4, hy - 2, hy + 4, "wl2")
    # 银角：一对，从头顶两边往外、往上，再往里勾
    for d in (-1, 1):
        pts = []
        for k in range(30):
            t = k / 29.0
            x = cx + 0.5 + d * (3 + 15 * math.sin(t * 1.9))
            y = hy - 5 - 24 * t
            pts.append((x, y, 2.6 - 1.7 * t))
        hs = set()
        for (x, y, r) in pts:
            for yy in range(int(y - r) - 1, int(y + r) + 2):
                for xx in range(int(x - r) - 1, int(x + r) + 2):
                    if (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= r * r:
                        hs.add((xx, yy))
        for (xx, yy) in hs:
            L.p(xx, yy, "sv1")
        for (xx, yy) in hs:
            if (xx - 1, yy) not in hs or (xx, yy - 1) not in hs:
                L.p(xx, yy, "sv2" if d < 0 else "sv2")
            if (xx + 1, yy) not in hs or (xx, yy + 1) not in hs:
                L.p(xx, yy, "sv0")
        for k in range(4, 26, 5):                     # 錾花：一个个小亮点
            x, y, r = pts[k]
            L.p(x, y, "wt")
            L.p(x - d, y + 1, "sv0")
    # 中间一扇银花
    for (ox, oy, r) in ((0, -13, 2), (-4, -10, 2), (4, -10, 2), (-2, -17, 1.5), (2, -17, 1.5), (0, -21, 1.5)):
        L.ell(cx + ox - r, hy + oy - r, cx + ox + r + 1, hy + oy + r + 1, "sv1")
        L.p(cx + ox, hy + oy, "wt")
        L.p(cx + ox + 1, hy + oy + 1, "sv0")
    L.vl(cx, hy - 10, hy - 5, "sv0")
    # 额前红绣带 + 银流苏
    L.rect(cx - 6, hy - 6, cx + 7, hy - 2, "rd3")
    L.hl(cx - 6, cx + 7, hy - 6, "rd4")
    for x in range(cx - 5, cx + 7, 2):
        L.p(x, hy - 4, "gd3")
    for k in range(-6, 8, 2):
        ln = 3 + (1 if k % 4 == 0 else 0)
        L.vl(cx + k, hy - 2, hy - 3 + ln, "sv1")
        L.p(cx + k, hy - 3 + ln, "wt")
    L.outline()
    return L, yf1


def prop_trunk():
    """陪嫁红木箱（等候区南边）：红漆箱身、拱一点的箱盖、金包角、正中圆面叶挂一把金锁、两头提环；
    盖上一朵红绸花"""
    L = Layer()
    x0, x1, yf0, yf1, h = 48, 94, 640, 656, 26
    ty0, ty1 = yf0 - h, yf1 - h            # 614..630
    L.rect(x0, ty0, x1, ty1, "rd3")
    L.hl(x0 + 1, x1 - 1, ty0, "rd5")
    L.hl(x0, x1, ty0 + 1, "rd4")
    L.vl(x1 - 1, ty0, ty1, "rd2")
    L.hl(x0, x1, ty1 - 1, "rd2")
    L.rect(x0, ty1, x1, yf1, "rd2")
    L.hl(x0, x1, ty1, "rd4")
    L.hl(x0, x1, ty1 + 6, "rd1")                    # 盖跟箱身的缝
    L.hl(x0, x1, ty1 + 7, "rd3")
    L.vl(x0, ty1, yf1, "rd3")
    L.vl(x1 - 1, ty1, yf1, "rd1")
    L.hl(x0, x1, yf1 - 1, "rd1")
    for (gx, gy) in ((x0, ty1), (x1 - 4, ty1), (x0, yf1 - 4), (x1 - 4, yf1 - 4)):
        L.rect(gx, gy, gx + 4, gy + 4, "gd2")
        L.p(gx + (0 if gx == x0 else 3), gy + (0 if gy == ty1 else 3), "gd4")
        L.p(gx + 1, gy + 1, "gd3")
    for (gx, gy) in ((x0, ty0), (x1 - 3, ty0)):
        L.rect(gx, gy, gx + 3, gy + 3, "gd2")
    cx = (x0 + x1) // 2
    L.ell(cx - 5, ty1 + 3, cx + 6, ty1 + 13, "gd2")
    L.ell(cx - 4, ty1 + 4, cx + 5, ty1 + 12, "gd3")
    L.p(cx - 2, ty1 + 5, "gd4")
    L.rect(cx - 2, ty1 + 9, cx + 3, ty1 + 14, "gd2")
    L.hl(cx - 2, cx + 3, ty1 + 9, "gd4")
    L.p(cx, ty1 + 11, "gd0")
    for hx in (x0 + 2, x1 - 3):
        L.vl(hx, ty1 + 8, ty1 + 13, "gd1")
    # 红绸花
    L.ell(cx - 9, ty0 + 2, cx - 1, ty0 + 10, "rd4")
    L.ell(cx + 1, ty0 + 2, cx + 9, ty0 + 10, "rd3")
    L.ell(cx - 3, ty0 + 3, cx + 4, ty0 + 10, "rd2")
    L.ell(cx - 2, ty0 + 4, cx + 3, ty0 + 9, "rd4")
    L.p(cx, ty0 + 5, "rd5")
    L.line(cx - 2, ty0 + 9, cx - 6, ty1 + 2, "rd3")
    L.line(cx + 2, ty0 + 9, cx + 7, ty1 + 1, "rd2")
    L.outline()
    return L, yf1


# ------------------------------------------------------------------ 等候区、门口
def prop_full_mirror():
    """落地穿衣镜（西南角）：拱顶金框、两根立柱、弯脚；顶上系个红绸花；镜子里照出一点地板"""
    L = Layer()
    x0, x1, yf0, yf1, h = 14, 42, 598, 606, 82
    top = yf1 - h
    cx = (x0 + x1) // 2
    for px_ in (x0 + 1, x1 - 3):
        L.rect(px_, top + 20, px_ + 2, yf1 - 3, "gd2")
        L.vl(px_, top + 20, yf1 - 3, "gd3")
        L.line(px_ + 1, yf1 - 4, px_ - 3, yf1 - 1, "gd2")
        L.line(px_ + 1, yf1 - 4, px_ + 5, yf1 - 1, "gd1")
    # 镜框：拱顶
    fx0, fx1 = x0 + 3, x1 - 3
    fy0, fy1 = top + 4, yf1 - 10
    frame = poly_px([(fx0, fy0 + 8), (fx0 + 4, fy0 + 2), (cx, fy0), (fx1 - 4, fy0 + 2), (fx1, fy0 + 8), (fx1, fy1),
                     (fx0, fy1)])
    for (x, y) in frame:
        L.p(x, y, "gd2")
    inner = poly_px([(fx0 + 3, fy0 + 9), (fx0 + 6, fy0 + 5), (cx, fy0 + 3), (fx1 - 6, fy0 + 5), (fx1 - 3, fy0 + 9),
                     (fx1 - 3, fy1 - 3), (fx0 + 3, fy1 - 3)])
    gy0 = min(y for x, y in inner)
    gy1 = max(y for x, y in inner)
    for (x, y) in inner:
        t = (y - gy0) / float(gy1 - gy0)
        c = "bl4"
        if t > 0.55:
            c = "bl3"
        if t > 0.78:
            c = "hw4" if (x + y) % 2 else "bl3"   # 镜子里照出的地板：v3 起地板是蜜色木 hw（01 F 10/3 定，原来是旧地板 fl4）
        L.p(x, y, c)
    for y in range(gy0, gy1):
        for (o, c) in ((3, "wt"), (7, "wt"), (8, "bl4")):
            xx = fx0 + o + (gy1 - y) // 3 - 5
            if (xx, y) in inner:
                L.p(xx, y, c)
    for (x, y) in frame:
        if (x, y) not in inner:
            if x < cx and (x - 1, y) not in frame or (x, y - 1) not in frame and x < cx + 4:
                L.p(x, y, "gd4")
            elif (x + 1, y) not in frame or (x, y + 1) not in frame:
                L.p(x, y, "gd1")
    # 红绸花
    L.ell(cx - 5, fy0 - 3, cx, fy0 + 2, "rd4")
    L.ell(cx + 1, fy0 - 3, cx + 6, fy0 + 2, "rd3")
    L.ell(cx - 1, fy0 - 2, cx + 2, fy0 + 2, "rd2")
    L.line(cx - 1, fy0 + 2, cx - 3, fy0 + 9, "rd3")
    L.line(cx + 1, fy0 + 2, cx + 3, fy0 + 8, "rd2")
    L.outline()
    return L, yf1


def prop_sofa():
    """等候沙发（红丝绒两人位、朝南）：金色雕花靠背框（顶上一朵卷草）、两块拉扣靠垫、两块坐垫、
    卷边扶手、金脚；一只米白抱枕、一只金色抱枕"""
    L = Layer()
    x0, x1 = 46, 118
    off = 566 - 236                          # 按休息间沙发的高度排（占地往南挪 330）
    Y = lambda y: y + off
    ia, ib = x0 + 10, x1 - 10
    # 金框靠背顶：中间拱起
    for x in range(x0 + 1, x1 - 1):
        t = (x + 0.5 - (x0 + x1) / 2.0) / ((x1 - x0) / 2.0)
        arch = int(round(5 * (1 - t * t)))
        y_top = Y(195) - arch
        L.vl(x, y_top, Y(204), "gd2")
        L.p(x, y_top, "gd4")
        L.p(x, y_top + 1, "gd3")
        L.p(x, Y(203), "gd1")
    cx = (x0 + x1) // 2
    # 卷草（顶上一朵）
    L.ell(cx - 4, Y(186), cx + 5, Y(192), "gd2")
    L.p(cx - 2, Y(187), "gd4")
    L.p(cx, Y(188), "gd1")
    L.p(cx + 2, Y(187), "gd3")
    # 靠背布面
    L.rect(x0 + 3, Y(199), x1 - 3, Y(228), "rd2")
    edges = [ia, cx, ib]
    for k in range(2):
        a, b = edges[k], edges[k + 1]
        puff(L, a, Y(200), b, Y(229), "rd", 3)
        L.vl(b - 1, Y(201), Y(229), "rd1")
        for (bx, by) in ((a + 7, Y(208)), (a + 15, Y(208)), (a + 23, Y(208)), (a + 11, Y(216)), (a + 19, Y(216))):
            if bx < b - 2:
                L.p(bx, by, "rd0")
                L.p(bx - 1, by - 1, "rd4")
    # 扶手
    for (a, b) in ((x0, ia), (ib, x1)):
        L.rect(a, Y(209), b, Y(238), "rd3")
        L.vl(a, Y(210), Y(238), "rd4")
        L.vl(a + 1, Y(210), Y(238), "rd4")
        L.vl(b - 1, Y(210), Y(238), "rd1")
        L.hl(a + 1, b - 1, Y(209), "rd4")
        L.rect(a, Y(238), b, Y(261), "rd2")
        L.hl(a, b, Y(237), "rd3")
        L.hl(a, b, Y(238), "rd4")
        L.ring(a + 1, Y(239), b - 1, Y(250), "rd1")
        L.ell(a + 3, Y(241), b - 3, Y(248), "rd3")
        L.p(a + 4, Y(242), "rd4")
        L.vl(b - 1, Y(239), Y(261), "rd1")
        L.hl(a, b, Y(260), "rd1")
        L.hl(a, b, Y(251), "gd2")
    L.vl(ia, Y(209), Y(252), "rd0")
    L.vl(ib - 1, Y(209), Y(252), "rd1")
    for k in range(2):
        a, b = edges[k], edges[k + 1]
        L.rect(a, Y(229), b, Y(244), "rd3")
        L.hl(a, b, Y(229), "rd1")
        L.hl(a + 1, b - 1, Y(230), "rd2")
        L.vl(a + 1, Y(231), Y(243), "rd4")
        L.vl(b - 1, Y(230), Y(244), "rd2")
        L.hl(a + 1, b - 1, Y(242), "rd4")
        L.hl(a, b, Y(243), "rd4")
        L.hl(a, b, Y(244), "rd5")
        L.rect(a, Y(245), b, Y(252), "rd2")
        L.hl(a, b, Y(245), "rd3")
        L.hl(a, b, Y(251), "rd1")
        if k > 0:
            L.vl(a, Y(229), Y(252), "rd1")
    L.rect(ia, Y(252), ib, Y(261), "rd1")
    L.hl(ia, ib, Y(252), "rd0")
    for xx in range(ia + 3, ib - 2, 6):
        L.vl(xx, Y(255), Y(261), "rd0")
        L.vl(xx + 1, Y(256), Y(261), "rd2")
    L.rect(x0, Y(261), x1, Y(264), "gd2")
    L.hl(x0, x1, Y(261), "gd4")
    L.hl(x0, x1, Y(263), "gd1")
    for lx in (x0 + 2, x1 - 5):
        L.rect(lx, Y(264), lx + 3, Y(268), "gd1")
        L.p(lx, Y(264), "gd3")
        L.p(lx + (-1 if lx < cx else 3), Y(267), "gd2")
    for (px_, py_) in ((ia + 3, Y(231)), (ib - 19, Y(231))):
        L.hl(px_ + 2, px_ + 16, py_ + 1, "rd2")
    pillow(L, ia + 2, Y(212), 16, 19, "wl", "dot")
    pillow(L, ib - 18, Y(213), 15, 18, "gd", "knot")
    L.outline()
    return L, Y(268)


def giftbox(L, x0, x1, yf0, yf1, h, ramp="rd", bow=True):
    ty0, ty1 = yf0 - h, yf1 - h
    L.rect(x0, ty0, x1, ty1, rname(ramp, 4))
    L.hl(x0, x1, ty0, rname(ramp, 5))
    L.vl(x1 - 1, ty0, ty1, rname(ramp, 3))
    L.rect(x0, ty1, x1, yf1, rname(ramp, 3))
    L.hl(x0, x1, ty1, rname(ramp, 4))
    L.vl(x1 - 1, ty1, yf1, rname(ramp, 2))
    L.hl(x0, x1, yf1 - 1, rname(ramp, 2))
    mx = (x0 + x1) // 2
    rib = "gd3" if ramp != "gd" else "rd3"
    rib2 = "gd2" if ramp != "gd" else "rd2"
    L.vl(mx, ty0, yf1, rib)
    L.vl(mx + 1, ty1, yf1, rib2)
    L.hl(x0, x1, (ty0 + ty1) // 2, rib)
    if bow:
        L.ell(mx - 4, ty0 - 3, mx + 1, ty0 + 2, rib)
        L.ell(mx + 1, ty0 - 3, mx + 6, ty0 + 2, rib2)
        L.p(mx, ty0, "gd4" if ramp != "gd" else "rd4")


def prop_gifts():
    """礼盒堆（屏风南边、贴着前墙）：下面三个、中间两个、顶上一个，红盒金带、金盒红带，大小一层层收"""
    L = Layer()
    x0, yb = 270, 656
    boxes = [  # x0, x1, 着地线, 前后深, 底离地, 顶离地, 色
        (x0 + 0, x0 + 18, yb, 12, 0, 14, "rd"), (x0 + 18, x0 + 37, yb, 12, 0, 13, "gd"),
        (x0 + 37, x0 + 56, yb, 12, 0, 14, "rd"),
        (x0 + 7, x0 + 26, yb - 2, 9, 14, 26, "rd"), (x0 + 29, x0 + 48, yb - 2, 9, 14, 25, "pk"),
        (x0 + 17, x0 + 37, yb - 4, 6, 26, 36, "gd"),
    ]
    for (a, b, foot, dep, z0, z1, col) in boxes:
        s = sub(a - 2, foot - dep - z1 - 6, b + 2, foot + 1)
        giftbox_z(s, a, b, foot - dep, foot, z0, z1, col)
        paste_ol(L, s)
    return L, yb


def giftbox_z(L, x0, x1, yf0, yf1, z0, z1, ramp):
    """一个礼盒，底面离地 z0、顶面离地 z1（叠在别的盒子上用）"""
    ty0, ty1 = yf0 - z1, yf1 - z1
    by = yf1 - z0
    L.rect(x0, ty0, x1, ty1, rname(ramp, 4))
    L.hl(x0, x1, ty0, rname(ramp, 5) if ramp == "rd" else "gd4")
    L.vl(x1 - 1, ty0, ty1, rname(ramp, 3))
    L.rect(x0, ty1, x1, by, rname(ramp, 3))
    L.hl(x0, x1, ty1, rname(ramp, 4))
    L.vl(x0, ty1, by, rname(ramp, 4))
    L.vl(x1 - 1, ty1, by, rname(ramp, 2))
    L.hl(x0, x1, by - 1, rname(ramp, 2))
    mx = (x0 + x1) // 2
    rib, rib2 = ("gd3", "gd2") if ramp != "gd" else ("rd3", "rd2")
    L.vl(mx - 1, ty0, by, rib)
    L.vl(mx, ty0, by, rib2)
    L.hl(x0, x1, (ty0 + ty1) // 2, rib)
    # 蝴蝶结
    L.ell(mx - 6, ty0 - 3, mx, ty0 + 2, rib)
    L.ell(mx, ty0 - 3, mx + 6, ty0 + 2, rib2)
    L.p(mx - 4, ty0 - 1, "gd4" if ramp != "gd" else "rd4")
    L.rect(mx - 1, ty0 - 1, mx + 1, ty0 + 1, rib2)
    L.line(mx - 1, ty0 + 1, mx - 3, ty0 + 4, rib)
    L.line(mx, ty0 + 1, mx + 2, ty0 + 4, rib2)


def prop_flowers(pid="mk_flowers"):
    """门口西边一个高花架（深木、三弯腿）上一大盆花：牡丹、白玫瑰、粉花、绿叶"""
    L = Layer()
    x0, yf0, x1, yf1 = PLAN_BY_ID[pid][3]
    cx = (x0 + x1) // 2
    st = yf1 - 38
    # 花架
    L.rect(x0 + 2, st, x1 - 2, st + 3, "wd3")
    L.hl(x0 + 2, x1 - 2, st, "wd5")
    L.hl(x0 + 2, x1 - 2, st + 2, "wd1")
    for (lx, d) in ((x0 + 3, -1), (x1 - 4, 1)):
        L.line(lx, st + 3, lx + d * 2, yf1 - 1, "wd2")
        L.line(lx + 1, st + 3, lx + 1 + d * 2, yf1 - 1, "wd1")
    L.hl(x0 + 4, x1 - 4, st + 22, "wd2")
    # 盆（青花）
    L.rect(cx - 5, st - 6, cx + 6, st, "wt")
    L.vl(cx + 5, st - 6, st, "bl4")
    L.hl(cx - 5, cx + 6, st - 4, "bl2")
    L.hl(cx - 5, cx + 6, st - 2, "bl2")
    # 花和叶
    for (lx, ly, ln, ang) in ((cx - 9, st - 10, 9, -2.7), (cx + 10, st - 10, 9, -0.4), (cx - 6, st - 18, 8, -2.0),
                              (cx + 7, st - 19, 8, -1.0), (cx, st - 8, 7, 1.6)):
        leaf(L, lx, ly, ln, ang, 4, 3, vein=False)
    for (ox, oy, ramp, r) in ((-6, -12, "rd", 4), (5, -13, "pk", 4), (0, -18, "pk", 3), (-8, -20, "wl", 3),
                              (8, -21, "rd", 3), (-1, -24, "rd", 3), (3, -9, "wl", 3), (-3, -10, "pk", 3)):
        if ramp == "wl":
            L.ell(cx + ox - r, st + oy - r, cx + ox + r + 1, st + oy + r + 1, "wl3")
            L.ell(cx + ox - r, st + oy - r, cx + ox + r, st + oy + r, "wt")
            L.p(cx + ox, st + oy, "wl2")
        else:
            peony(L, cx + ox, st + oy, ramp, r)
    L.outline()
    return L, yf1


def shoe(L, x, y, kind):
    """一双鞋（正面看），占 9×4"""
    if kind == "red":                          # 红绣花鞋
        for dx in (0, 5):
            L.rect(x + dx, y - 3, x + dx + 4, y, "rd3")
            L.hl(x + dx, x + dx + 4, y - 3, "rd4")
            L.p(x + dx + 1, y - 2, "gd3")
            L.hl(x + dx, x + dx + 4, y - 1, "wl4")
    elif kind == "heel":                       # 白高跟
        for dx in (0, 5):
            L.rect(x + dx, y - 3, x + dx + 4, y - 1, "wt")
            L.p(x + dx + 3, y - 1, "sv1")
            L.vl(x + dx + 3, y - 1, y, "sv1")
            L.p(x + dx, y - 1, "sv2")
            L.p(x + dx + 1, y - 3, "gd4")
    elif kind == "gold":
        for dx in (0, 5):
            L.rect(x + dx, y - 3, x + dx + 4, y - 1, "gd3")
            L.vl(x + dx + 3, y - 1, y, "gd1")
            L.p(x + dx, y - 3, "gd4")
    elif kind == "black":                      # 黑皮鞋
        for dx in (0, 5):
            L.rect(x + dx, y - 3, x + dx + 4, y, "ik1")
            L.p(x + dx + 1, y - 3, "ik3")
            L.hl(x + dx, x + dx + 4, y - 1, "ik0")
    elif kind == "geta":                       # 木屐（红带）
        for dx in (0, 5):
            L.rect(x + dx, y - 2, x + dx + 4, y, "wd4")
            L.hl(x + dx, x + dx + 4, y - 2, "wd5")
            L.p(x + dx + 1, y - 3, "rd4")
            L.p(x + dx + 2, y - 4, "rd4")
            L.p(x + dx + 3, y - 3, "rd4")
    elif kind == "ethnic":                     # 绣花布鞋（深蓝、彩绣）
        for dx in (0, 5):
            L.rect(x + dx, y - 3, x + dx + 4, y, "bl1")
            L.p(x + dx + 1, y - 2, "rd4")
            L.p(x + dx + 2, y - 3, "gd3")
            L.hl(x + dx, x + dx + 4, y - 1, "wl4")
    elif kind == "pink":
        for dx in (0, 5):
            L.rect(x + dx, y - 3, x + dx + 4, y - 1, "pk")
            L.p(x + dx, y - 3, "pk2")
            L.vl(x + dx + 3, y - 1, y, "pk0")


def prop_shoes():
    """三层鞋架（原木）：红绣花鞋、白高跟、金高跟、黑皮鞋、木屐、绣花布鞋、粉鞋；顶上摆一双红绣鞋和一个鞋盒"""
    L = Layer()
    x0, x1, yf0, yf1, h = 216, 258, 598, 612, 43
    ty0, ty1 = yf0 - h, yf1 - h            # 555..569
    L.rect(x0, ty0, x1, ty1, "wd4")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x1 - 1, ty0, ty1, "wd3")
    for gy in (ty0 + 4, ty0 + 9):
        L.hl(x0 + 3, x1 - 3, gy, "wd3")
    # 正面
    L.rect(x0, ty1, x1, yf1, "wd3")
    L.vl(x0, ty1, yf1, "wd4")
    L.vl(x1 - 1, ty1, yf1, "wd1")
    L.hl(x0, x1, ty1, "wd5")
    shelves = [(ty1 + 2, ty1 + 14), (ty1 + 16, ty1 + 28), (ty1 + 30, yf1 - 2)]
    rows = [["red", "heel", "gold", "pink"], ["black", "geta", "black", "heel"], ["ethnic", "red", "geta", "ethnic"]]
    for (a, b), row in zip(shelves, rows):
        L.rect(x0 + 2, a, x1 - 2, b, "wd0")
        L.hl(x0 + 2, x1 - 2, a, "ol")
        L.rect(x0 + 2, b - 1, x1 - 2, b + 1, "wd4")
        L.hl(x0 + 2, x1 - 2, b - 1, "wd5")
        for k, kind in enumerate(row):
            shoe(L, x0 + 3 + k * 10, b - 1, kind)
    # 顶上：一双红绣鞋（金线）、一个红鞋盒
    shoe(L, x0 + 4, ty0 + 10, "red")
    giftbox(L, x0 + 22, x0 + 36, ty0 + 6, ty0 + 12, 6, "rd", bow=False)
    L.outline()
    return L, yf1


def prop_pouf():
    """试鞋圆墩：红丝绒鼓包、一圈金滚边、看不见脚"""
    L = Layer()
    x0, y_, x1, yf1 = PLAN_BY_ID["mk_pouf"][3]
    h = PLAN_BY_ID["mk_pouf"][4]
    cx = (x0 + x1) // 2
    top = yf1 - h
    L.rect(x0, top - 2, x1, yf1 - 2, "rd2")
    L.ell(x0, yf1 - 6, x1, yf1, "rd2")
    L.vl(x0, top, yf1 - 3, "rd3")
    L.vl(x1 - 1, top, yf1 - 3, "rd1")
    for xx in range(x0 + 3, x1 - 2, 4):
        L.vl(xx, top + 4, yf1 - 3, "rd1")
        L.vl(xx + 1, top + 4, yf1 - 4, "rd3")
    L.ell(x0, top - 7, x1, top + 4, "rd3")
    for y in range(top - 7, top + 4):
        for x in range(x0, x1):
            if L.g(x, y) == C["rd3"]:
                u = (x + 0.5 - cx) / 10.0
                v = (y + 0.5 - top + 1.5) / 5.5
                b = puff_level(u, v)
                L.p(x, y, "rd5" if b > 0.75 else ("rd4" if b > 0.25 else "rd3"))
    L.p(cx, top - 2, "rd1")
    L.p(cx - 1, top - 3, "gd4")
    L.ring(x0, top - 7, x1, top + 4, "gd2", only=lambda x, y: y > top - 2)
    L.hl(x0 + 1, x1 - 1, yf1 - 3, "gd2")
    L.outline()
    return L, yf1


def prop_screen():
    """喜鹊登梅四扇屏风（东南角，换衣用）：红漆框、金角、米白绢面上一枝梅花贯穿四扇、两只喜鹊；
    下面裙板金色团纹；四扇一前一后折着（单数扇往后缩 6 像素、颜色暗一档）；一扇上搭一件粉色衬裙"""
    L = Layer()
    x0, x1 = 264, 328
    pw = 16
    for k in range(4):
        a, b = x0 + k * pw, x0 + (k + 1) * pw
        foot = 606 if k % 2 == 0 else 600
        top = foot - 82
        P = sub(a, top - 2, b, foot + 1)
        P.rect(a, top, b, foot - 2, "rd2")
        P.hl(a, b, top, "gd3")
        P.vl(a, top, foot - 2, "rd3")
        P.vl(b - 1, top, foot - 2, "rd1")
        # 绢面
        sy0, sy1 = top + 3, foot - 22
        P.rect(a + 2, sy0, b - 2, sy1, "wl4")
        P.hl(a + 2, b - 2, sy0, "wl3")
        # 裙板
        P.rect(a + 2, sy1 + 2, b - 2, foot - 5, "rd3")
        P.hl(a + 2, b - 2, sy1 + 2, "rd4")
        cxp, cyp = (a + b) // 2, (sy1 + foot - 3) // 2
        P.ell(cxp - 3, cyp - 3, cxp + 4, cyp + 4, "gd2")
        P.p(cxp, cyp, "gd4")
        P.ell(cxp - 1, cyp - 1, cxp + 2, cyp + 2, "rd3")
        # 金角
        for (gx, gy) in ((a, top), (b - 2, top), (a, foot - 4), (b - 2, foot - 4)):
            P.rect(gx, gy, gx + 2, gy + 2, "gd3")
        # 脚
        P.rect(a + 2, foot - 2, a + 4, foot, "rd1")
        P.rect(b - 4, foot - 2, b - 2, foot, "rd1")
        # 梅枝（四扇连成一枝：从左下往右上）
        for x in range(a + 2, b - 2):
            t = (x - x0) / float(x1 - x0)
            yb = sy1 - 8 - t * 34 + 4 * math.sin(t * 9)
            yy = int(yb + (0 if k % 2 == 0 else -6))
            P.p(x, yy, "wd1")
            P.p(x, yy + 1, "wd2")
            if (x * 7) % 11 == 0:
                P.line(x, yy, x + 2, yy - 5, "wd1")
                P.p(x + 2, yy - 6, "rd4")
                P.p(x + 3, yy - 6, "pk")
                P.p(x + 2, yy - 7, "rd4")
            if (x * 5) % 7 == 0:
                P.p(x, yy - 1, "rd4")
                P.p(x + 1, yy - 1, "pk")
                P.p(x, yy - 2, "rd5")
        if k in (1, 2):
            # 喜鹊（黑身白肚、长尾）
            mx, my = (a + b) // 2 - 3, sy0 + (16 if k == 1 else 22) + (0 if k % 2 == 0 else -6)
            P.rect(mx, my, mx + 6, my + 4, "ik1")
            P.rect(mx + 1, my + 2, mx + 5, my + 4, "wt")
            P.rect(mx + 5, my - 2, mx + 8, my + 1, "ik1")         # 头
            P.p(mx + 8, my - 1, "ik2")                             # 嘴
            P.p(mx + 6, my - 1, "wt")                              # 眼
            P.line(mx, my + 1, mx - 5, my + 5, "ik1")              # 长尾
            P.line(mx, my + 2, mx - 4, my + 5, "bl1")
            P.rect(mx + 1, my, mx + 4, my + 2, "bl1")              # 翅膀一点蓝光
            P.p(mx + 2, my, "bl2")
            P.p(mx + 3, my + 4, "ik2")
            P.p(mx + 4, my + 5, "ik2")
        if k % 2 == 1:
            P.shade_rect(a, top, b, foot, -1)
        P.outline()
        L.paste(P)
    # 搭着的一件粉色丝绸晨袍：搭在第一、二扇接缝上，前面垂得长、下摆有褶，袖子耷拉下来
    a = x0 + pw - 6
    t1 = 606 - 82
    D = sub(a - 4, t1 - 4, a + 16, t1 + 34)
    robe = poly_px([(a, t1 - 2), (a + 10, t1 - 2), (a + 12, t1 + 12), (a + 13, t1 + 26), (a + 9, t1 + 28),
                    (a + 5, t1 + 26), (a + 1, t1 + 28), (a - 1, t1 + 14)])
    fill_lit(D, robe, "pk", 1, hi=2, lo=2)
    for (x, y) in robe:
        if y <= t1 - 1:
            D.p(x, y, "pk2")
    for k, xx in enumerate((a + 3, a + 7)):
        for y in range(t1 + 4, t1 + 26):
            D.p(xx + (1 if (y // 5) % 2 else 0), y, "pk0" if k else "pk2")
    D.line(a + 10, t1 + 2, a + 14, t1 + 17, "pk")               # 耷拉的袖子
    D.line(a + 11, t1 + 2, a + 15, t1 + 17, "pk0")
    for x in range(a, a + 13):
        if (x, t1 + 25) in robe:
            D.p(x, t1 + 25, "wt" if x % 2 else "pk2")             # 下摆一道白蕾丝
    paste_ol(L, D)
    L.outline()
    return L, 606




# ================================================================== 第二版：布料、衣服生成、衣架、衣墙
EXTRA_RAMPS = {"wh": ["sv1", "sv2", "wt"]}     # 白衣服用的一条（只给 rn 用，不进 RAMP_OF，不影响别处挪档）


def rn(ramp, i):
    names = EXTRA_RAMPS.get(ramp) or RAMPS[ramp]
    return names[max(0, min(len(names) - 1, i))]


def hem_arc(cx, y, hw, sag, n=10):
    """下摆的弧（从右往左）：斜俯视看，朝前的那半圈往下垂 sag 像素"""
    return [(cx + hw - 2.0 * hw * i / n, y + sag * math.sin(math.pi * i / n)) for i in range(n + 1)]


def cloth(L, S, ramp, lv, folds=3, top=None, seed=0):
    """布料：本档；每行最左 2 像素亮一档，最右 2 像素暗一档、最边上再暗一档；
    几道竖褶（暗线 + 左边贴一条亮，往下摆走、微微摆动）；下摆最底一行暗一档（弧线就出来了）"""
    if not S:
        return
    r = rows_of(S)
    cols = bottom_of(S)
    ys = [y for (_, y) in S]
    y0, y1 = min(ys), max(ys)
    top = y0 if top is None else top
    for (x, y) in S:
        a, b = r[y]
        k = lv
        if x <= a + 1:
            k = lv + 1
        elif x >= b:
            k = lv - 2
        elif x >= b - 2:
            k = lv - 1
        L.p(x, y, rn(ramp, k))
    rnd = random.Random(seed)
    for i in range(folds):
        t = (i + 1.0) / (folds + 1) + rnd.uniform(-0.07, 0.07)
        start = top + rnd.randrange(0, max(1, (y1 - top) // 3))
        ph = rnd.uniform(0, 6)
        for y in range(start, y1 + 1):
            if y not in r:
                continue
            a, b = r[y]
            if b - a < 6:
                continue
            x = int(round(a + t * (b - a) + 0.7 * math.sin(y * 0.22 + ph)))
            if a + 2 < x < b - 2 and (x, y) in S:
                L.p(x, y, rn(ramp, lv - 1))
                if (x - 1, y) in S:
                    L.p(x - 1, y, rn(ramp, lv + 1))
    for x, yb in cols.items():
        if yb > y1 - 6:
            L.p(x, yb, rn(ramp, lv - 1))


def pattern(L, S, kind, col, col2=None, seed=0, y_from=None):
    """衣服上的花样（只落在衣服里面）"""
    rnd = random.Random(seed)
    if not S:
        return
    ys = [y for (_, y) in S]
    y0, y1 = min(ys), max(ys)
    yf = y_from if y_from is not None else y0
    if kind == "flower":                         # 散花：一朵 = 中心 + 四瓣
        for y in range(yf + 3, y1 - 1, 7):
            for x in range(min(x for x, _ in S) + 2 + (y // 7 % 2) * 3, max(x for x, _ in S) - 1, 7):
                jx, jy = x + rnd.randrange(-1, 2), y + rnd.randrange(-1, 2)
                if all((jx + dx, jy + dy) in S for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))):
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        L.p(jx + dx, jy + dy, col)
                    L.p(jx, jy, col2 or col)
    elif kind == "dots":
        for (x, y) in S:
            if y >= yf and (x * 3 + y * 5) % 11 == 0:
                L.p(x, y, col)
    elif kind == "gold":                         # 金鳞纹（龙凤褂）
        for (x, y) in S:
            if y >= yf:
                u = (x + (2 if (y // 3) % 2 else 0)) % 4
                if y % 3 == 0 and u in (1, 2):
                    L.p(x, y, col)
    elif kind == "stripe":
        for (x, y) in S:
            if y >= yf and (y - yf) % 6 in (0, 1):
                L.p(x, y, col if (y - yf) % 12 < 6 else (col2 or col))
    elif kind == "hemband":                      # 下摆一道花边
        cols = bottom_of(S)
        for (x, y) in S:
            d = cols[x] - y
            if 1 <= d <= 3:
                L.p(x, y, col if d != 2 or x % 2 else (col2 or col))
    elif kind == "wave":                          # 下半截一道道浪纹
        for (x, y) in S:
            if y >= yf and (y - int(1.5 * math.sin(x * 0.7))) % 5 == 0:
                L.p(x, y, col)
    elif kind == "sakura":                        # 樱花：小五点
        for y in range(yf + 2, y1 - 2, 6):
            for x in range(min(x for x, _ in S) + 1 + (y // 6 % 2) * 3, max(x for x, _ in S), 6):
                if (x, y) in S and rnd.random() < 0.8:
                    L.p(x, y, col2 or col)
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        if (x + dx, y + dy) in S:
                            L.p(x + dx, y + dy, col)


def garment(L, g, cx, ty, seed=0):
    """一件挂着的衣服。g = dict(kind, ramp, lv, ln, hw, trim, pat, pc, pc2, ramp2, lv2)
    kind：gown 长裙 / dress 短裙 / jacket 短上衣 / robe 宽袖长袍（和服、褂）/ suit 西装连裤 / set 上衣 + 长裙"""
    kind = g["kind"]
    ramp, lv, ln = g["ramp"], g["lv"], g["ln"]
    hw = g.get("hw", 8)
    trim = g.get("trim")
    hanger(L, cx, ty)
    if kind in ("gown", "dress"):
        wy = ty + 14
        L.line(cx - 1, ty, cx - 4, ty + 2, rn(ramp, lv - 1))
        L.line(cx + 1, ty, cx + 4, ty + 2, rn(ramp, lv - 1))
        sk = [(cx + 3, wy), (cx + hw * 0.5, wy + (ln - 14) * 0.4), (cx + hw, ty + ln)] + \
            hem_arc(cx, ty + ln, hw, 2)[1:-1] + [(cx - hw, ty + ln), (cx - hw * 0.5, wy + (ln - 14) * 0.4), (cx - 3, wy)]
        S = poly_px(sk)
        cloth(L, S, ramp, lv, folds=3 if hw > 6 else 2, top=wy + 3, seed=seed)
        bod = poly_px([(cx - 4, ty + 2), (cx + 4, ty + 2), (cx + 5, ty + 10), (cx + 3, wy), (cx - 3, wy), (cx - 5, ty + 10)])
        cloth(L, bod, ramp, lv, folds=0)
        if g.get("sleeve"):
            for d in (-1, 1):
                sl = poly_px([(cx + 4 * d, ty + 2), (cx + 7 * d, ty + 3), (cx + 8 * d, ty + 7), (cx + 5 * d, ty + 8)])
                for (x, y) in sl:
                    L.p(x, y, rn(ramp, lv + (1 if d < 0 else -1)))
        L.hl(cx - 3, cx + 4, wy, trim or rn(ramp, lv - 1))
        if trim:
            L.p(cx + 2, wy + 1, trim)
    elif kind == "jacket":
        S = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + hw, ty + 3), (cx + hw + 1, ty + ln)] +
                    hem_arc(cx, ty + ln, hw + 1, 1)[1:-1] + [(cx - hw - 1, ty + ln), (cx - hw, ty + 3)])
        cloth(L, S, ramp, lv, folds=1, seed=seed)
        for d in (-1, 1):
            L.vl(cx + d * (hw - 3), ty + 5, ty + ln - 2, rn(ramp, lv - 1))
        L.vl(cx, ty + 2, ty + ln, rn(ramp, lv - 1))
        L.line(cx - 3, ty, cx, ty + 7, rn(ramp, lv + 1))
        L.line(cx + 3, ty, cx, ty + 7, rn(ramp, lv - 1))
        if trim:
            cols = bottom_of(S)
            for (x, y) in S:
                if y >= cols[x] - 1 or (y >= ty + ln - 4 and abs(x - cx) >= hw - 2):
                    L.p(x, y, trim)
            L.line(cx - 3, ty, cx, ty + 7, trim)
            L.line(cx + 3, ty, cx, ty + 7, trim)
            for k in range(3):
                L.p(cx + 1, ty + 9 + k * 5, trim)
    elif kind == "robe":
        sl = g.get("sl", 22)
        S = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + hw, ty + 3), (cx + hw, ty + ln)] +
                    hem_arc(cx, ty + ln, hw, 1)[1:-1] + [(cx - hw, ty + ln), (cx - hw, ty + 3)])
        sleeves = set()
        for d in (-1, 1):
            a, b = (cx + hw - 1, cx + hw + 5) if d > 0 else (cx - hw - 5, cx - hw + 1)
            sleeves |= poly_px([(a, ty + 3), (b, ty + 3), (b, ty + sl - 2), (b - 2, ty + sl), (a + 2, ty + sl), (a, ty + sl - 2)])
        cloth(L, sleeves, ramp, lv - 1, folds=0)
        cloth(L, S, ramp, lv, folds=2, top=ty + 14, seed=seed)
        if g.get("pc"):
            # 袖子上各一朵大花（和服的袖子最显眼），花心一点亮
            for d in (-1, 1):
                fx = cx + d * (hw + 2)
                fy = ty + 9 + (seed % 3) * 3
                for (dx, dy) in ((0, -2), (-2, 0), (2, 0), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)):
                    L.p(fx + dx, fy + dy, g["pc"])
                L.p(fx, fy, g.get("pc2") or "wt")
            # 胸口两朵小的
            for (dx, dy) in ((-4, 18), (3, 24)):
                L.p(cx + dx, ty + dy, g["pc"])
                L.p(cx + dx + 1, ty + dy, g["pc"])
                L.p(cx + dx, ty + dy + 1, g.get("pc2") or "wt")
        col = g.get("collar", "wt")
        for t in range(0, 15):
            L.p(cx - 3 + t * 4 / 15.0, ty + t, col)
            L.p(cx + 3 - t * 4 / 15.0, ty + t, col)
        L.vl(cx + 1, ty + 15, ty + ln, rn(ramp, lv - 1))
        if trim:
            for x in range(cx - hw, cx + hw + 1):
                L.p(x, ty + ln - 1 + int(round(math.sin(math.pi * (x - cx + hw) / (2.0 * hw)))), trim)
    elif kind == "suit":
        pl = g.get("pants", 22)
        P = poly_px([(cx - 5, ty + ln - 2), (cx + 5, ty + ln - 2), (cx + 5, ty + ln + pl), (cx + 1, ty + ln + pl),
                     (cx, ty + ln + 5), (cx - 1, ty + ln + pl), (cx - 5, ty + ln + pl)])
        cloth(L, P, ramp, lv, folds=0)
        S = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + hw, ty + 3), (cx + hw + 1, ty + ln)] +
                    hem_arc(cx, ty + ln, hw + 1, 1)[1:-1] + [(cx - hw - 1, ty + ln), (cx - hw, ty + 3)])
        cloth(L, S, ramp, lv, folds=0, seed=seed)
        for d in (-1, 1):
            L.vl(cx + d * (hw - 3), ty + 5, ty + ln - 3, rn(ramp, lv - 1))
        shirt = g.get("shirt", "wt")
        for t in range(0, 11):
            w_ = 3 - t * 3 / 11.0
            L.hl(int(cx - w_), int(cx + w_) + 1, ty + t, shirt)
        L.line(cx - 3, ty, cx, ty + 12, rn(ramp, lv + 1))
        L.line(cx + 3, ty, cx, ty + 12, rn(ramp, lv + 1))
        L.hl(cx - 1, cx + 2, ty + 2, trim or "ik0")
        L.p(cx, ty + 15, rn(ramp, lv + 1))
        L.p(cx, ty + 20, rn(ramp, lv + 1))
    elif kind == "set":
        jl = g.get("jl", 22)
        ramp2, lv2 = g.get("ramp2", ramp), g.get("lv2", lv)
        sk = poly_px([(cx - 6, ty + jl - 2), (cx + 6, ty + jl - 2), (cx + hw + 2, ty + ln)] +
                     hem_arc(cx, ty + ln, hw + 2, 2)[1:-1] + [(cx - hw - 2, ty + ln)])
        cloth(L, sk, ramp2, lv2, folds=3, top=ty + jl, seed=seed)
        rr = rows_of(sk)
        for (x, y) in sk:
            a, b = rr[y]
            if (x - a) % 3 == 1 and y > ty + jl + 2 and a + 1 < x < b - 1:
                L.p(x, y, rn(ramp2, lv2 - 1))          # 百褶
        if g.get("panel"):
            for y in range(ty + jl, ty + ln):
                w_ = 2 + (y - ty - jl) // 10
                L.p(cx - w_ - 1, y, g["panel"])
                L.p(cx + w_ + 1, y, g["panel"])
        S = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + hw, ty + 3), (cx + hw + 3, ty + jl - 4), (cx + hw - 1, ty + jl - 2),
                     (cx + 6, ty + jl), (cx - 6, ty + jl), (cx - hw + 1, ty + jl - 2), (cx - hw - 3, ty + jl - 4),
                     (cx - hw, ty + 3)])
        cloth(L, S, ramp, lv, folds=0)
        L.vl(cx, ty + 2, ty + jl, rn(ramp, lv - 1))
        if trim:
            cols = bottom_of(S)
            for (x, y) in S:
                if y >= cols[x] - 1:
                    L.p(x, y, trim)
            L.rect(cx - 2, ty, cx + 3, ty + 2, trim)
            for k in range(3):
                L.hl(cx - 1, cx + 2, ty + 5 + k * 5, trim)
    elif kind == "qipao":
        garment_qipao(L, cx, ty, ramp, lv, length=ln, motif=trim or "gd3")
        return
    p = g.get("pat")
    if p:
        allS = set()
        for y in range(ty, ty + ln + (g.get("pants", 0) if kind == "suit" else 0) + 3):
            for x in range(cx - hw - 6, cx + hw + 7):
                c = L.g(x, y)
                if c[3] and c in RAMP_OF and RAMP_OF[c][0] in (ramp, g.get("ramp2", ramp), "sv"):
                    allS.add((x, y))
        pattern(L, allS, p, g.get("pc", "gd3"), g.get("pc2"), seed=seed, y_from=ty + g.get("pat_from", 0))


def rack_frame(L, x0, x1, bar, foot, style):
    """衣架架子：两根立柱、脚、横杆。style：cn 红漆搭脑翘头 / gold 金色细管 / black 黑漆 / wood 原木 / white 白漆金头"""
    if style == "cn":
        for px_ in (x0 + 2, x1 - 5):
            L.rect(px_, bar, px_ + 3, foot - 4, "rd2")
            L.vl(px_, bar, foot - 4, "rd4")
            L.vl(px_ + 2, bar, foot - 4, "rd1")
            L.rect(px_ - 4, foot - 5, px_ + 7, foot, "rd2")
            L.hl(px_ - 4, px_ + 7, foot - 5, "rd4")
            L.hl(px_ - 4, px_ + 7, foot - 1, "rd1")
            L.rect(px_ - 1, foot - 4, px_ + 4, foot - 2, "gd2")
        L.rect(x0 - 2, bar - 3, x1 + 2, bar + 1, "rd2")
        L.hl(x0 - 2, x1 + 2, bar - 3, "rd4")
        L.hl(x0 - 2, x1 + 2, bar, "rd1")
        for (ex, d) in ((x0 - 2, -1), (x1 + 1, 1)):
            L.rect(ex - (2 if d < 0 else 0), bar - 6, ex + (1 if d < 0 else 3), bar - 2, "rd3")
            L.p(ex + 2 * d, bar - 7, "gd3")
            L.p(ex + d, bar - 6, "gd3")
    elif style in ("gold", "white"):
        pc, ph, pd = ("gd2", "gd3", "gd1") if style == "gold" else ("wl3", "wt", "wl1")
        for px_ in (x0 + 1, x1 - 3):
            L.rect(px_, bar, px_ + 2, foot - 3, pc)
            L.vl(px_, bar, foot - 3, ph)
            L.line(px_ + 1, foot - 6, px_ - 4, foot - 2, pc)
            L.line(px_ + 1, foot - 6, px_ + 6, foot - 2, pd)
            for wx in (px_ - 5, px_ + 6):
                L.rect(wx, foot - 2, wx + 2, foot, "ik2")
        L.rect(x0 - 1, bar - 1, x1 + 1, bar + 1, "gd2")
        L.hl(x0 - 1, x1 + 1, bar - 1, "gd4")
        for ex in (x0 - 3, x1 + 1):
            L.ell(ex, bar - 2, ex + 3, bar + 1, "gd3")
    elif style == "black":
        for px_ in (x0 + 1, x1 - 4):
            L.rect(px_, bar - 1, px_ + 3, foot - 3, "ik1")
            L.vl(px_, bar - 1, foot - 3, "ik3")
            L.rect(px_ - 4, foot - 4, px_ + 7, foot, "ik1")
            L.hl(px_ - 4, px_ + 7, foot - 4, "ik3")
            L.p(px_ - 4, foot - 1, "gd3")
            L.p(px_ + 6, foot - 1, "gd3")
        L.rect(x0 - 3, bar - 3, x1 + 3, bar + 1, "ik1")
        L.hl(x0 - 3, x1 + 3, bar - 3, "ik3")
        for (ex, d) in ((x0 - 3, -1), (x1 + 2, 1)):
            L.p(ex + d, bar - 4, "ik1")
            L.p(ex + d, bar - 5, "gd3")
    else:  # wood
        for px_ in (x0 + 1, x1 - 4):
            L.rect(px_, bar - 3, px_ + 3, foot - 3, "wd4")
            L.vl(px_, bar - 3, foot - 3, "wd5")
            L.vl(px_ + 2, bar - 3, foot - 3, "wd2")
            L.ell(px_ - 1, bar - 7, px_ + 4, bar - 2, "wd4")
            L.p(px_, bar - 6, "wd5")
            L.rect(px_ - 4, foot - 4, px_ + 7, foot, "wd3")
            L.hl(px_ - 4, px_ + 7, foot - 4, "wd5")
        L.rect(x0, bar - 1, x1, bar + 2, "wd4")
        L.hl(x0, x1, bar - 1, "wd5")
        L.hl(x0, x1, bar + 1, "wd2")


def G(kind, ramp, lv, ln, **kw):
    d = dict(kind=kind, ramp=ramp, lv=lv, ln=ln)
    d.update(kw)
    return d


def build_rack(pid, style, items, back=False, special=None):
    """一排挂满的衣架：衣服先画（每件单独描边，前后叠一点），再画架子；back=True 的整排暗一档（在后排、光被挡）"""
    L = Layer()
    x0, y0, x1, foot = PLAN_BY_ID[pid][3]
    h = PLAN_BY_ID[pid][4]
    bar = foot - h + 4
    n = len(items)
    step = (x1 - x0 - 22) / float(max(1, n - 1))
    for i, g in enumerate(items):
        cx = int(round(x0 + 11 + i * step))
        s = sub(cx - 16, bar - 6, cx + 17, foot)
        if callable(g):
            g(s, cx, bar + 2)
        else:
            garment(s, g, cx, bar + 2, seed=i * 7 + len(pid))
        if back:
            s.shade_rect(cx - 16, bar - 6, cx + 17, foot, -1)
        paste_ol(L, s)
    F = Layer()
    rack_frame(F, x0, x1, bar, foot, style)
    if special:
        special(F, x0, x1, bar, foot)
    F.outline()
    L.paste(F)
    return L, foot


# ------------------------------------------------------------------ 小件：帽盒、叠好的衣服、团扇
def hatbox(L, x, yb, w, h, ramp, lv, ribbon="gd3"):
    """圆帽盒（正面看）：盒身左亮右暗、上面一圈盒盖、一条丝带 + 蝴蝶结"""
    L.rect(x, yb - h, x + w, yb, rn(ramp, lv))
    L.vl(x, yb - h, yb, rn(ramp, lv + 1))
    L.vl(x + w - 1, yb - h, yb, rn(ramp, lv - 1))
    L.vl(x + w - 2, yb - h, yb, rn(ramp, lv - 1))
    L.ell(x - 1, yb - h - 3, x + w + 1, yb - h + 2, rn(ramp, lv + 1))
    L.hl(x - 1, x + w + 1, yb - h + 1, rn(ramp, lv - 1))
    L.hl(x, x + w, yb - 1, rn(ramp, lv - 1))
    mx = x + w // 2
    L.vl(mx, yb - h, yb, ribbon)
    L.p(mx - 1, yb - h - 2, ribbon)
    L.p(mx + 1, yb - h - 2, ribbon)
    L.p(mx, yb - h - 1, ribbon)


def folded(L, x, yb, w, cols):
    """一摞叠好的衣服：一层 3 像素，上沿亮、右边暗、左边一个折口"""
    for k, c in enumerate(cols):
        y = yb - 3 * (k + 1)
        ramp = RAMP_OF.get(C[c], ("", 0))[0] or "wl"
        L.rect(x, y, x + w, y + 3, c)
        L.hl(x, x + w, y, shift(c, 1))
        L.vl(x + w - 1, y, y + 3, shift(c, -1))
        L.p(x, y + 2, shift(c, -1))


def tuanshan(L, cx, cy, r=3):
    """团扇：圆扇面（米白绢、一点粉花）、金边、木柄、红穗"""
    L.ell(cx - r, cy - r, cx + r + 1, cy + r + 1, "gd2")
    L.ell(cx - r + 1, cy - r + 1, cx + r, cy + r, "wl5")
    L.p(cx, cy, "pk")
    L.p(cx - 1, cy, "rd4")
    L.p(cx + 1, cy + 1, "gr3")
    L.vl(cx, cy + r + 1, cy + r + 5, "wd2")
    L.p(cx, cy + r + 6, "rd3")
    L.p(cx + 1, cy + r + 7, "rd3")


# ------------------------------------------------------------------ 北墙两座开放衣墙
def prop_closet(pid, style):
    """开放式高衣墙：冠檐（回纹/金珠）、两边立板、上层（叠好的衣服、帽盒）、中层挂杆挂一排短衣、
    下层两排鞋；顶上再搁两个帽盒"""
    L = Layer()
    x0, y0, x1, y1 = PLAN_BY_ID[pid][3]
    h = PLAN_BY_ID[pid][4]
    ty0, ty1 = y0 - h, y1 - h
    cn = style == "cn"
    fr, frh, frd = ("rd2", "rd4", "rd1") if cn else ("wl4", "wt", "wl2")
    back = "rd1" if cn else "wl1"
    # 顶面
    L.rect(x0, ty0, x1, ty1, fr)
    L.hl(x0, x1, ty0, frh)
    L.vl(x1 - 1, ty0, ty1, frd)
    # 正面：框
    L.rect(x0, ty1, x1, y1, fr)
    L.vl(x0, ty1, y1, frh)
    L.vl(x1 - 1, ty1, y1, frd)
    # 冠檐
    L.rect(x0 - 1, ty1, x1 + 1, ty1 + 6, "gd2")
    L.hl(x0 - 1, x1 + 1, ty1, "gd4")
    L.hl(x0 - 1, x1 + 1, ty1 + 5, "gd0")
    if cn:
        for x in range(x0 + 1, x1 - 1):
            for r_ in range(4):
                if KEY[r_ + 1][(x - x0) % 8] == "1":
                    L.p(x, ty1 + 1 + r_, "rd2")
    else:
        for x in range(x0 + 1, x1, 3):
            L.p(x, ty1 + 2, "gd4")
            L.p(x, ty1 + 3, "gd1")
    ix0, ix1 = x0 + 3, x1 - 3
    A0, A1 = ty1 + 6, ty1 + 28              # 上层
    B0, B1 = ty1 + 31, ty1 + 77             # 挂衣
    C0, C1 = ty1 + 80, y1 - 4               # 鞋
    for (a, b) in ((A0, A1), (B0, B1), (C0, C1)):
        L.rect(ix0, a, ix1, b, back)
        L.hl(ix0, ix1, a, shift(back, -1) if cn else "wl0")
        L.hl(ix0, ix1, a + 1, shift(back, -1) if cn else "wl0")
    for (a, b) in ((A1, B0), (B1, C0)):     # 隔板
        L.rect(ix0, a, ix1, b, fr)
        L.hl(ix0, ix1, a, frh)
        L.hl(ix0, ix1, b - 1, frd)
    # 上层
    if cn:
        folded(L, ix0 + 1, A1, 12, ["rd3", "gd3", "rd4", "pk", "rd2", "gd2"])
        folded(L, ix0 + 14, A1, 11, ["pk2", "rd3", "gd3", "rd4", "pk"])
        hatbox(L, ix0 + 28, A1, 12, 10, "rd", 3, "gd3")
        hatbox(L, ix0 + 30, A1 - 13, 8, 6, "gd", 3, "rd3")
        folded(L, ix0 + 42, A1, 12, ["gd3", "rd3", "gd2", "rd4"])
    else:
        hatbox(L, ix0 + 1, A1, 13, 11, "pk", 2, "wt")
        hatbox(L, ix0 + 3, A1 - 14, 9, 6, "ik", 2, "gd3")
        folded(L, ix0 + 16, A1, 12, ["wt", "pk2", "sv2", "wl4", "pk", "wt"])
        hatbox(L, ix0 + 30, A1, 12, 9, "wh", 2, "ik1")
        folded(L, ix0 + 44, A1, 13, ["bl3", "sv2", "pk2", "wl3"])
        hatbox(L, ix0 + 46, A1 - 12, 9, 7, "pk", 1, "gd3")
    # 挂杆 + 一排短衣
    L.hl(ix0, ix1, B0 + 3, "gd3")
    L.hl(ix0, ix1, B0 + 4, "gd1")
    if cn:
        items = [G("jacket", "rd", 3, 30, hw=7, trim="gd3", pat="flower", pc="gd2"),
                 G("set", "pk", 1, 40, hw=6, jl=18, ramp2="rd", lv2=2, trim="gd3"),
                 G("jacket", "gd", 2, 32, hw=7, trim="rd3", pat="gold", pc="gd3"),
                 G("robe", "rd", 2, 40, hw=6, sl=16, trim="gd3", collar="gd3"),
                 G("jacket", "rd", 4, 28, hw=6, trim="gd2", pat="dots", pc="gd3")]
    else:
        items = [G("suit", "ik", 1, 28, hw=7, pants=10),
                 G("jacket", "wh", 2, 28, hw=6),
                 G("dress", "pk", 2, 40, hw=6, sleeve=True, trim="wt"),
                 G("jacket", "bl", 2, 30, hw=7, trim="gd3"),
                 G("dress", "wl", 4, 38, hw=6, trim="gd3")]
    n = len(items)
    step = (ix1 - ix0 - 12) / float(n - 1)
    for i, g in enumerate(items):
        cx = int(round(ix0 + 6 + i * step))
        s = sub(max(ix0, cx - 14), B0 + 1, min(ix1, cx + 15), B1)
        garment(s, g, cx, B0 + 6, seed=i + (0 if cn else 30))
        paste_ol(L, s)
    # 团扇两把挂在中式衣墙左立板上；西式挂一个衣袋
    if cn:
        tuanshan(L, x0 + 2, B0 + 10, 3)
        tuanshan(L, x1 - 3, B0 + 22, 3)
    else:
        L.rect(x1 - 6, B0 + 4, x1 - 1, B0 + 30, "sv2")
        L.vl(x1 - 2, B0 + 4, B0 + 30, "sv1")
        L.p(x1 - 4, B0 + 3, "gd3")
    # 鞋：两排
    shoes = (["red", "gold", "red", "pink", "red", "gold"] if cn else ["heel", "red", "gold", "pink", "heel", "black"])
    for row in range(2):
        yb = C0 + 7 + row * 7 if row else C0 + 6
        if row:
            L.hl(ix0, ix1, C0 + 7, frh)
        for k in range(5):
            kind = shoes[(k + row * 2) % len(shoes)]
            shoe(L, ix0 + 1 + k * 11, (C0 + 6) if row == 0 else (C1 - 1), kind)
    # 立板雕花 / 把手
    for yy in (A0 + 4, B0 + 20, C0 + 3):
        L.p(x0 + 1, yy, "gd3")
        L.p(x1 - 2, yy, "gd3")
    # 脚线
    L.rect(x0, y1 - 4, x1, y1, frd)
    L.hl(x0, x1, y1 - 4, "gd2")
    for lx in (x0, x1 - 4):
        L.rect(lx, y1 - 3, lx + 4, y1, "gd1")
    # 顶上搁两个帽盒
    if cn:
        hatbox(L, x0 + 6, ty1 - 2, 12, 7, "rd", 3, "gd3")
        folded(L, x0 + 22, ty1 - 2, 12, ["rd3", "gd3"])
    else:
        hatbox(L, x1 - 20, ty1 - 2, 13, 8, "pk", 2, "wt")
        hatbox(L, x1 - 34, ty1 - 2, 11, 6, "wh", 2, "pk0")
    L.outline()
    return L, y1


# ------------------------------------------------------------------ 中式区
def crown_stand_special():
    pass


def prop_crown_stand():
    """凤冠架：木杆上一个头模，戴凤冠、披红盖头（金边、金穗、四角小流苏），底座圆"""
    L = Layer()
    x0, y0, x1, foot = PLAN_BY_ID["mk_crown_stand"][3]
    h = PLAN_BY_ID["mk_crown_stand"][4]
    cx = (x0 + x1) // 2
    L.ell(cx - 8, foot - 5, cx + 9, foot + 1, "rd1")
    L.ell(cx - 8, foot - 6, cx + 9, foot - 1, "rd2")
    L.hl(cx - 5, cx + 5, foot - 5, "rd4")
    L.rect(cx - 1, foot - 44, cx + 2, foot - 4, "rd2")
    L.vl(cx - 1, foot - 44, foot - 4, "rd4")
    L.vl(cx + 1, foot - 44, foot - 4, "rd1")
    top = foot - h
    hy = top + 14                             # 头模中心
    L.ell(cx - 5, hy - 6, cx + 6, hy + 7, "wl3")
    # 盖头：从冠下披下来，越往下越宽
    veil = poly_px([(cx - 6, hy - 4), (cx + 7, hy - 4), (cx + 10, hy + 22), (cx + 6, hy + 24), (cx, hy + 22),
                    (cx - 5, hy + 24), (cx - 9, hy + 22)])
    cloth(L, veil, "rd", 3, folds=2, top=hy, seed=4)
    cols = bottom_of(veil)
    for x, yb in cols.items():
        L.p(x, yb, "gd3")
        L.p(x, yb - 1, "gd2")
        if x % 2 == 0:
            L.p(x, yb + 1, "gd3")
    for (vx, vy) in ((cx - 9, hy + 22), (cx + 10, hy + 22), (cx, hy + 22)):
        L.vl(vx, vy, vy + 4, "rd4")
        L.p(vx, vy + 4, "gd3")
    # 盖头中间一朵金团花
    L.ell(cx - 2, hy + 8, cx + 4, hy + 14, "gd2")
    L.p(cx, hy + 10, "gd4")
    L.p(cx + 1, hy + 11, "rd3")
    phoenix_crown(L, cx, hy - 3)
    L.outline()
    return L, foot


def special_cn(F, x0, x1, bar, foot):
    """中式架子：搭脑正中红绸花、两头小灯笼"""
    cx = (x0 + x1) // 2
    F.ell(cx - 7, bar - 7, cx, bar, "rd4")
    F.ell(cx + 1, bar - 7, cx + 8, bar, "rd3")
    F.ell(cx - 2, bar - 5, cx + 3, bar, "rd2")
    F.p(cx, bar - 3, "gd3")
    F.line(cx - 1, bar, cx - 4, bar + 9, "rd3")
    F.line(cx + 1, bar, cx + 4, bar + 8, "rd2")


def prop_rack_cn_back():
    items = [lambda s, cx, ty: garment_xiuhe(s, cx, ty, length=66),
             lambda s, cx, ty: garment_xiuhe(s, cx, ty, length=66, gold=True),
             G("set", "rd", 3, 64, hw=8, jl=24, ramp2="gd", lv2=2, trim="gd3", panel="gd3", pat="flower", pc="gd3"),
             G("set", "pk", 1, 62, hw=7, jl=20, ramp2="rd", lv2=3, trim="gd3", panel="gd2"),
             G("robe", "rd", 3, 68, hw=7, sl=24, trim="gd3", collar="gd3", pat="flower", pc="gd2", pc2="gd4"),
             G("set", "bl", 1, 66, hw=7, jl=26, ramp2="ik", lv2=1, trim="gd3")]   # 新郎长衫马褂
    return build_rack("mk_rack_cn_back", "cn", items, back=True, special=special_cn)


def prop_rack_cn_front():
    items = [G("qipao", "rd", 3, 56, trim="gd3"), G("qipao", "pk", 1, 54, trim="gd3"),
             G("qipao", "gd", 3, 58, trim="rd3"), G("qipao", "bl", 4, 52, trim="bl2")]

    def lanterns(F, x0, x1, bar, foot):
        for lx in (x0 - 3, x1 + 2):
            s2 = sub(lx - 7, bar - 4, lx + 8, bar + 22)
            draw_lantern(s2, lx, bar + 1)
            s2.outline()
            F.paste(s2)
    return build_rack("mk_rack_cn_front", "cn", items, special=lanterns)


# ------------------------------------------------------------------ 西式区
def prop_rack_west_back():
    items = [G("gown", "wh", 2, 76, hw=11, trim="pk2"),
             G("gown", "pk", 2, 74, hw=9, trim="wt"),
             G("suit", "ik", 1, 36, hw=8, pants=30, trim="rd4"),
             G("gown", "rd", 4, 74, hw=9, trim="gd3", pat="dots", pc="gd4"),
             G("gown", "wl", 4, 76, hw=10, trim="gd3", sleeve=True),
             G("suit", "bl", 1, 36, hw=8, pants=30, trim="ik0"),
             G("gown", "sv", 2, 72, hw=9, trim="wt", pat="dots", pc="wt")]
    return build_rack("mk_rack_west_back", "white", items, back=True)


def prop_rack_west_front():
    items = [G("dress", "wh", 2, 44, hw=10, trim="pk", sleeve=True, pat="hemband", pc="sv2", pc2="wt"),
             G("suit", "ik", 1, 34, hw=7, pants=26, trim="ik0"),
             G("dress", "pk", 1, 46, hw=9, trim="pk2", pat="flower", pc="pk2", pc2="wt"),
             G("suit", "wl", 3, 34, hw=7, pants=26, trim="gd3", shirt="wt")]
    return build_rack("mk_rack_west_front", "gold", items)


# ------------------------------------------------------------------ 日式区
def prop_rack_jp_back():
    items = [G("robe", "pk", 1, 64, hw=8, sl=32, trim="rd3", collar="wt", pat="sakura", pc="pk2", pc2="wt"),
             G("robe", "tl", 1, 66, hw=8, sl=30, trim="gd3", collar="wt", pat="wave", pc="tl2", pat_from=36),
             G("robe", "wh", 2, 68, hw=9, sl=28, trim="sv1", collar="wt", pat="flower", pc="sv2", pc2="wt"),
             G("robe", "ik", 1, 66, hw=8, sl=22, trim="gd3", collar="wt", pat="flower", pc="gd2", pc2="rd4", pat_from=40),
             G("robe", "rd", 2, 64, hw=8, sl=30, trim="gd3", collar="wt", pat="flower", pc="gd3", pc2="wt")]
    return build_rack("mk_rack_jp_back", "black", items, back=False)


def prop_tansu():
    """黑漆小柜：四个抽屉金环拉手；柜面上三卷腰带、一把打开的扇子、一个发簪盒；脚边一双木屐"""
    L = Layer()
    x0, y0, x1, y1 = PLAN_BY_ID["mk_tansu"][3]
    h = PLAN_BY_ID["mk_tansu"][4]
    ty0, ty1 = y0 - h, y1 - h
    L.rect(x0, ty0, x1, ty1, "ik2")
    L.hl(x0, x1, ty0, "ik3")
    L.vl(x1 - 1, ty0, ty1, "ik1")
    L.rect(x0, ty1, x1, y1, "ik1")
    L.hl(x0, x1, ty1, "ik3")
    L.vl(x0, ty1, y1, "ik2")
    for r_ in range(2):
        for c in range(2):
            a, b = x0 + 2 + c * 13, x0 + 14 + c * 13
            yy0 = ty1 + 2 + r_ * 13
            L.rect(a, yy0, b, yy0 + 11, "ik2")
            L.hl(a, b, yy0, "ik3")
            L.hl(a, b, yy0 + 10, "ik0")
            mx = (a + b) // 2
            L.ring(mx - 2, yy0 + 4, mx + 3, yy0 + 9, "gd3")
            L.p(mx, yy0 + 3, "gd2")
    for (gx, gy) in ((x0, ty1), (x1 - 2, ty1), (x0, y1 - 2), (x1 - 2, y1 - 2)):
        L.rect(gx, gy, gx + 2, gy + 2, "gd2")
    # 腰带卷（横躺，看到一头的圆）
    for k, (ramp, lv) in enumerate((("gd", 3), ("rd", 3), ("tl", 1))):
        bx, by = x0 + 2, ty0 + 2 + k * 4
        L.rect(bx + 2, by, bx + 11, by + 4, rn(ramp, lv))
        L.hl(bx + 2, bx + 11, by, rn(ramp, lv + 1))
        L.ell(bx, by, bx + 5, by + 4, rn(ramp, lv - 1))
        L.p(bx + 2, by + 2, rn(ramp, lv + 1))
        if ramp == "gd":
            for xx in range(bx + 4, bx + 11, 3):
                L.p(xx, by + 2, "rd3")
    # 扇子（立着打开）
    fx, fy = x0 + 20, ty0 + 6
    for k in range(9):
        a = math.pi + k * math.pi / 8
        for t in range(2, 8):
            L.p(fx + math.cos(a) * t, fy + math.sin(a) * t * 0.9, "rd4" if k % 2 else "wl5")
        L.p(fx + math.cos(a) * 8, fy + math.sin(a) * 7.2, "gd3")
    L.p(fx, fy, "ik1")
    L.ell(fx - 3, fy - 4, fx + 1, fy - 1, "gd3")
    # 发簪盒
    L.rect(x0 + 15, ty0 + 9, x0 + 27, ty0 + 13, "ik1")
    L.hl(x0 + 15, x0 + 27, ty0 + 9, "rd3")
    for k, c in enumerate(("pk", "gd3", "wt", "rd4")):
        L.p(x0 + 17 + k * 3, ty0 + 8, c)
        L.p(x0 + 17 + k * 3, ty0 + 10, "gd2")
    L.outline()
    # 木屐一双（地上，单独一小层）
    s = sub(x0 - 12, y1 - 6, x0 + 1, y1 + 2)
    for gx in (x0 - 11, x0 - 5):
        s.rect(gx, y1 - 3, gx + 5, y1, "wd4")
        s.hl(gx, gx + 5, y1 - 3, "wd5")
        s.p(gx + 1, y1 - 4, "rd4")
        s.p(gx + 2, y1 - 5, "rd4")
        s.p(gx + 3, y1 - 4, "rd4")
    paste_ol(L, s)
    return L, y1


# ------------------------------------------------------------------ 民族区
def prop_ethnic_wall():
    """民族饰品墙（原木框、顶上彩绘一排菱形）：上层四顶帽子（苗族靛蓝包头、彝族黑帽红黄边、藏族金边皮帽、
    傣族尖顶竹笠）；中层两副大银项圈挂银锁、两块绣片、三条彩带；下层一排绣花鞋、几卷彩织布"""
    L = Layer()
    x0, y0, x1, y1 = PLAN_BY_ID["mk_ethnic_wall"][3]
    h = PLAN_BY_ID["mk_ethnic_wall"][4]
    ty0, ty1 = y0 - h, y1 - h
    L.rect(x0, ty0, x1, ty1, "wd4")
    L.hl(x0, x1, ty0, "wd5")
    L.rect(x0, ty1, x1, y1, "wd3")
    L.vl(x0, ty1, y1, "wd5")
    L.vl(x1 - 1, ty1, y1, "wd1")
    # 顶上彩绘
    L.rect(x0, ty1, x1, ty1 + 6, "wd2")
    cols = ["rd4", "gd3", "gr3", "bl3", "pk", "or"]
    for k, x in enumerate(range(x0 + 4, x1 - 2, 7)):
        c = cols[k % len(cols)]
        L.poly([(x, ty1 + 1), (x + 3, ty1 + 3), (x, ty1 + 5), (x - 3, ty1 + 3)], c)
        L.p(x, ty1 + 3, "wt")
    ix0, ix1 = x0 + 3, x1 - 3
    L.rect(ix0, ty1 + 6, ix1, y1 - 4, "bl1")
    for y in range(ty1 + 6, y1 - 4):
        for x in range(ix0, ix1):
            if (x + y) % 6 == 0 and (x - y) % 6 == 0:
                L.p(x, y, "bl2")
    L.hl(ix0, ix1, ty1 + 6, "bl0")
    # 上层：帽子挂在木钉上
    hy = ty1 + 20
    L.rect(ix0, hy + 1, ix1, hy + 3, "wd4")
    L.hl(ix0, ix1, hy + 1, "wd5")
    # 苗族包头（靛蓝一圈圈、银泡）
    hx = ix0 + 4
    for k in range(4):
        L.ell(hx - 1 + k, hy - 10 + k * 2, hx + 18 - k, hy - 3 + k * 2, "bl1" if k % 2 else "bl2")
    for xx in range(hx + 2, hx + 16, 3):
        L.p(xx, hy - 4, "sv2")
    L.p(hx + 8, hy - 11, "sv2")
    L.p(hx + 9, hy - 12, "wt")
    # 彝族黑帽（红黄边，顶上一个结）
    hx = ix0 + 26
    L.ell(hx, hy - 6, hx + 16, hy + 1, "ik1")
    L.hl(hx + 1, hx + 15, hy - 2, "rd4")
    L.hl(hx + 1, hx + 15, hy - 1, "gd3")
    L.rect(hx + 6, hy - 11, hx + 10, hy - 5, "ik1")
    L.line(hx + 10, hy - 10, hx + 14, hy - 15, "ik2")
    L.p(hx + 14, hy - 15, "rd4")
    # 藏族皮帽（金锦帽身、白毛边）
    hx = ix0 + 48
    L.rect(hx + 3, hy - 11, hx + 13, hy - 4, "gd3")
    L.hl(hx + 3, hx + 13, hy - 11, "gd4")
    L.vl(hx + 12, hy - 11, hy - 4, "gd1")
    for xx in range(hx + 4, hx + 13, 3):
        L.p(xx, hy - 8, "rd3")
    L.rect(hx, hy - 5, hx + 16, hy, "wl4")
    L.hl(hx, hx + 16, hy - 5, "wt")
    L.vl(hx + 15, hy - 5, hy, "wl2")
    # 傣族竹笠
    hx = ix0 + 70
    L.poly([(hx + 9, hy - 13), (hx + 19, hy), (hx - 1, hy)], "wd5")
    L.line(hx + 9, hy - 13, hx + 19, hy, "wd3")
    for k in range(3):
        L.line(hx + 9, hy - 13, hx + 3 + k * 6, hy - 1, "wd4")
    L.hl(hx, hx + 19, hy - 1, "wd3")
    L.hl(hx + 4, hx + 15, hy - 5, "rd4")
    # 中层：银项圈 + 银锁、绣片、彩带
    my = hy + 5
    for nx in (ix0 + 6, ix0 + 58):
        for k in range(2):
            rx = 9 - k * 2
            L.ring(nx - rx + 9, my - 2 + k * 2, nx + rx + 9, my + 12 - k, "sv1",
                   only=lambda x, y, my=my, k=k: y > my + 3 + k)
            L.ring(nx - rx + 9, my - 2 + k * 2, nx + rx + 9, my + 12 - k, "wt",
                   only=lambda x, y, my=my, k=k, nx=nx: y > my + 3 + k and x < nx + 6)
        L.rect(nx + 6, my + 12, nx + 13, my + 17, "sv1")                    # 银锁
        L.hl(nx + 6, nx + 13, my + 12, "wt")
        L.p(nx + 9, my + 14, "sv0")
        for k in range(4):
            L.vl(nx + 7 + k * 2, my + 17, my + 20, "sv2")
    for (px_, c1, c2) in ((ix0 + 30, "rd3", "gd3"), (ix0 + 80, "gr3", "pk")):     # 绣片（木框里一块方的）
        L.rect(px_ - 1, my - 1, px_ + 14, my + 15, "wd2")
        L.rect(px_, my, px_ + 13, my + 14, "ik1")
        for y in range(my + 1, my + 13):
            for x in range(px_ + 1, px_ + 12):
                d = abs(x - (px_ + 6)) + abs(y - (my + 7))
                if d in (2, 5) or (d == 8 and (x + y) % 2 == 0):
                    L.p(x, y, c1)
                elif d in (3, 6):
                    L.p(x, y, c2)
        L.p(px_ + 6, my + 7, "wt")
    for k, (rx, cs) in enumerate(((ix0 + 48, ["rd4", "gd3", "gr3", "bl3"]), (ix0 + 52, ["pk", "or", "tl2", "gd3"]),
                                  (ix1 - 4, ["rd3", "gd3", "pk", "bl3"]))):
        for y in range(my - 2, my + 24):
            L.p(rx, y, cs[(y // 2) % 4])
            L.p(rx + 1, y, shift(cs[(y // 2) % 4], -1))
        L.p(rx, my + 24, "gd3")
    # 下层：绣花鞋、布卷（多半被前面的衣架挡住）
    sy = y1 - 6
    L.rect(ix0, sy - 14, ix1, sy - 12, "wd4")
    for k, kind in enumerate(("ethnic", "red", "ethnic", "pink", "ethnic", "red", "ethnic", "red", "ethnic")):
        shoe(L, ix0 + 1 + k * 11, sy, kind)
    for k, (ramp, lv) in enumerate((("rd", 3), ("bl", 2), ("gd", 3), ("gr", 3))):
        bx = ix0 + 4 + k * 22
        L.rect(bx, sy - 22, bx + 14, sy - 14, rn(ramp, lv))
        L.hl(bx, bx + 14, sy - 22, rn(ramp, lv + 1))
        L.ell(bx + 12, sy - 22, bx + 17, sy - 14, rn(ramp, lv - 1))
        for xx in range(bx + 2, bx + 12, 3):
            L.vl(xx, sy - 21, sy - 15, "wt" if ramp != "gd" else "rd3")
    L.rect(x0, y1 - 4, x1, y1, "wd2")
    L.hl(x0, x1, y1 - 4, "wd4")
    L.outline()
    return L, y1


def garment_dai(L, cx, ty):
    """傣族：粉色紧身短上衣、银腰带、孔雀绿筒裙（金色横花带）"""
    hanger(L, cx, ty)
    sk = poly_px([(cx - 5, ty + 18), (cx + 5, ty + 18), (cx + 6, ty + 52)] + hem_arc(cx, ty + 52, 6, 1)[1:-1] +
                 [(cx - 6, ty + 52)])
    cloth(L, sk, "tl", 1, folds=1, seed=3)
    for (x, y) in sk:
        if (y - ty) in (30, 31, 44, 45, 50):
            L.p(x, y, "gd3" if x % 2 else "gd2")
        if (y - ty) == 38 and x % 3 == 0:
            L.p(x, y, "gd4")
    top = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + 7, ty + 3), (cx + 8, ty + 14), (cx + 5, ty + 15), (cx + 5, ty + 18),
                   (cx - 5, ty + 18), (cx - 5, ty + 15), (cx - 8, ty + 14), (cx - 7, ty + 3)])
    cloth(L, top, "pk", 1, folds=0)
    L.hl(cx - 5, cx + 6, ty + 18, "sv2")
    L.hl(cx - 5, cx + 6, ty + 19, "sv0")
    L.vl(cx + 2, ty + 2, ty + 17, "pk0")


def garment_mongol(L, cx, ty):
    """蒙古袍：宝蓝长袍、金边斜襟、橙色腰带"""
    hanger(L, cx, ty)
    S = poly_px([(cx - 4, ty), (cx + 4, ty), (cx + 9, ty + 3), (cx + 11, ty + 26), (cx + 8, ty + 27), (cx + 7, ty + 16),
                 (cx + 8, ty + 54)] + hem_arc(cx, ty + 54, 8, 1)[1:-1] +
                [(cx - 8, ty + 54), (cx - 7, ty + 16), (cx - 8, ty + 27), (cx - 11, ty + 26), (cx - 9, ty + 3)])
    cloth(L, S, "bl", 2, folds=2, top=ty + 22, seed=11)
    pattern(L, S, "dots", "bl3")
    L.line(cx - 3, ty, cx + 6, ty + 10, "gd3")
    L.line(cx + 6, ty + 10, cx + 6, ty + 20, "gd3")
    L.rect(cx - 7, ty + 20, cx + 8, ty + 23, "or")
    L.hl(cx - 7, cx + 8, ty + 20, "gd4")
    cols = bottom_of(S)
    for x, yb in cols.items():
        L.p(x, yb - 1, "gd3")
    for x in (cx - 8, cx + 8):
        pass


def prop_rack_ethnic():
    items = [lambda s, cx, ty: garment_miao(s, cx, ty),
             lambda s, cx, ty: garment_tibet(s, cx, ty),
             lambda s, cx, ty: garment_yi(s, cx, ty),
             lambda s, cx, ty: garment_dai(s, cx, ty),
             lambda s, cx, ty: garment_mongol(s, cx, ty)]

    def band(F, x0, x1, bar, foot):
        cols = ["rd4", "gd3", "gr3", "bl3", "pk", "or"]
        for (bx, ln) in ((x0 + 5, 14), (x1 - 9, 10)):
            for y in range(bar - 1, bar + ln):
                for x in range(bx, bx + 4):
                    c = cols[(y - bar) // 2 % len(cols)]
                    F.p(x, y, c if x < bx + 3 else shift(c, -1))
            for x in range(bx, bx + 4, 2):
                F.p(x, bar + ln, "gd3")
    return build_rack("mk_rack_ethnic", "wood", items, special=band)


# ------------------------------------------------------------------ 首饰中岛
def prop_island():
    """首饰中岛（屋子中间偏南）：金框玻璃台面，红丝绒三格托盘（戒指、耳环项链、金手镯）；
    台面后半截摆一顶头冠（丝绒座）、一个打开的领结领带盒、一束新娘捧花（白玫瑰粉牡丹、缎带垂下来）；
    正面上半截玻璃里三个戴项链的半身模，下半截红漆板、金回纹、两朵金团花"""
    L = Layer()
    x0, y0, x1, y1 = PLAN_BY_ID["mk_island"][3]
    h = PLAN_BY_ID["mk_island"][4]
    ty0, ty1 = y0 - h, y1 - h               # 460..488
    L.rect(x0, ty0, x1, ty1, "gd2")
    L.hl(x0, x1, ty0, "gd4")
    L.vl(x0, ty0, ty1, "gd3")
    L.vl(x1 - 1, ty0, ty1, "gd1")
    gx0, gy0, gx1, gy1 = x0 + 2, ty0 + 2, x1 - 2, ty1 - 1
    L.rect(gx0, gy0, gx1, gy1, "rd1")
    third = (gx1 - gx0) // 3
    for k in range(3):
        a, b = gx0 + 1 + k * third, gx0 + (k + 1) * third - 1
        L.rect(a, gy0 + 1, b, gy1 - 1, "rd2")
        L.hl(a, b, gy0 + 1, "gd2")
        L.hl(a, b, gy1 - 2, "rd0")
        if k == 0:
            for j in range(10):
                x = a + 2 + (j % 5) * 3
                y = gy0 + 12 + (j // 5) * 5
                L.ring(x - 1, y - 1, x + 2, y + 2, "gd3")
                L.p(x, y - 1, ("wt", "rd4", "bl4", "gr4", "pk")[j % 5])
        elif k == 1:
            for j in range(5):
                x = a + 2 + j * 3
                L.p(x, gy0 + 13, "gd3")
                L.p(x, gy0 + 14, ("rd4", "wt", "pk", "bl3", "gd4")[j])
            for j in range(15):
                t = j / 14.0
                L.p(a + 1 + t * (b - a - 2), gy0 + 17 + math.sin(t * math.pi) * 4, "wt")
            L.p((a + b) // 2, gy0 + 21, "rd4")
        else:
            for j in range(3):
                x = a + 1 + j * 6
                L.ring(x, gy0 + 13, x + 6, gy0 + 20, "gd3")
                L.ring(x, gy0 + 13, x + 6, gy0 + 20, "gd4", only=lambda xx, yy, x=x: xx < x + 3 and yy < gy0 + 16)
    for k in range(0, gx1 - gx0, 20):
        for t in range(7):
            xx, yy = gx0 + 3 + k + t, gy1 - 2 - t
            if L.g(xx, yy) in (C["rd1"], C["rd2"]):
                L.p(xx, yy, "rd3")
    # 台面后半截：头冠、领结盒、捧花
    tiara(L, gx0 + 9, gy0 + 6)
    bx, by = gx0 + third + 2, gy0 + 9                   # 领结领带盒（盖子立着）
    L.rect(bx, by - 9, bx + 16, by - 4, "ik1")
    L.rect(bx + 1, by - 8, bx + 15, by - 5, "rd1")
    L.rect(bx, by - 4, bx + 16, by + 1, "ik1")
    for j, c in enumerate(("ik0", "rd3", "bl2", "gd3", "pk", "sv1")):
        x = bx + 1 + j * 2 + (j // 3)
        if j < 3:
            L.p(x, by - 3, c)
            L.p(x + 1, by - 3, c)
            L.p(x, by - 2, shift(c, 1) if c != "ik0" else "ik2")
        else:
            L.vl(x + 2, by - 3, by, c)
    # 领结两个（蝴蝶形）
    for (lx, c) in ((bx + 9, "ik0"), (bx + 12, "rd4")):
        L.p(lx, by - 3, c)
        L.p(lx + 2, by - 3, c)
        L.p(lx + 1, by - 2, c)
        L.p(lx, by - 1, c)
        L.p(lx + 2, by - 1, c)
    # 捧花
    cx, cy = gx1 - 10, gy0 + 4
    for (lx, ly, ang) in ((cx - 6, cy + 2, 2.9), (cx + 7, cy + 1, 0.2), (cx, cy + 6, 1.6)):
        leaf(L, lx, ly, 6, ang, 3, 3, vein=False)
    for (ox, oy, ramp) in ((-3, -1, "wl"), (3, -1, "pk"), (0, -4, "wl"), (-4, 3, "pk"), (4, 3, "wl"), (0, 2, "rd")):
        if ramp == "wl":
            L.ell(cx + ox - 2, cy + oy - 2, cx + ox + 3, cy + oy + 3, "wl3")
            L.ell(cx + ox - 2, cy + oy - 2, cx + ox + 2, cy + oy + 2, "wt")
            L.p(cx + ox, cy + oy, "wl2")
        else:
            peony(L, cx + ox, cy + oy, ramp, 2)
    L.line(cx, cy + 5, cx - 3, cy + 13, "pk2")
    L.line(cx + 1, cy + 5, cx + 4, cy + 12, "pk")
    # 正面
    L.rect(x0, ty1, x1, y1, "rd2")
    L.hl(x0, x1, ty1, "gd3")
    L.rect(x0 + 2, ty1 + 2, x1 - 2, ty1 + 16, "gd1")
    L.rect(x0 + 3, ty1 + 3, x1 - 3, ty1 + 15, "rd1")
    for k in range(3):
        bust(L, x0 + 14 + k * 16, ty1 + 15, "gd" if k != 1 else "pearl")
    for k in range(2):                                  # 两个打开的小戒指盒
        rx_ = x0 + 21 + k * 16
        L.rect(rx_, ty1 + 9, rx_ + 6, ty1 + 14, "rd3")
        L.hl(rx_, rx_ + 6, ty1 + 9, "rd4")
        L.ring(rx_ + 1, ty1 + 6, rx_ + 5, ty1 + 10, "gd3")
        L.p(rx_ + 3, ty1 + 6, "wt")
    L.line(x0 + 4, ty1 + 13, x0 + 12, ty1 + 4, "rd2")
    L.line(x1 - 20, ty1 + 13, x1 - 12, ty1 + 4, "rd2")
    L.rect(x0 + 2, ty1 + 18, x1 - 2, y1 - 4, "rd3")
    L.hl(x0 + 2, x1 - 2, ty1 + 18, "rd4")
    L.vl(x1 - 3, ty1 + 18, y1 - 4, "rd1")
    for x in range(x0 + 3, x1 - 3):
        for r_ in range(7):
            if KEY[r_][(x - x0 - 3) % 8] == "1" and False:
                pass
    for (mx_) in (x0 + 15, x1 - 16):
        my_ = (ty1 + 18 + y1 - 4) // 2
        L.ell(mx_ - 5, my_ - 5, mx_ + 6, my_ + 6, "gd2")
        L.ell(mx_ - 4, my_ - 4, mx_ + 5, my_ + 5, "rd3")
        L.p(mx_, my_, "gd4")
        for (dx, dy) in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            L.p(mx_ + dx, my_ + dy, "gd3")
    L.hl(x0 + 24, x1 - 24, (ty1 + y1) // 2 + 6, "gd2")
    L.hl(x0 + 24, x1 - 24, (ty1 + y1) // 2 + 10, "gd2")
    L.rect(x0, y1 - 4, x1, y1, "rd1")
    L.hl(x0, x1, y1 - 4, "gd2")
    for lx in (x0, x1 - 4):
        L.rect(lx, y1 - 3, lx + 4, y1, "gd2")
        L.p(lx + 1, y1 - 3, "gd4")
    L.outline()
    return L, y1


def prop_steamer():
    """挂烫机：白色水箱底座带小轮、金色伸缩杆、顶上衣架挂一件白衬衫、一根蒸汽软管"""
    L = Layer()
    x0, y0, x1, y1 = PLAN_BY_ID["mk_steamer"][3]
    h = PLAN_BY_ID["mk_steamer"][4]
    cx = (x0 + x1) // 2
    L.rect(cx - 5, y1 - 12, cx + 6, y1 - 2, "wt")
    L.vl(cx + 5, y1 - 12, y1 - 2, "sv1")
    L.hl(cx - 5, cx + 6, y1 - 12, "sv2")
    L.rect(cx - 3, y1 - 9, cx + 2, y1 - 5, "bl4")
    L.p(cx - 2, y1 - 8, "wt")
    for wx in (cx - 5, cx + 4):
        L.rect(wx, y1 - 2, wx + 2, y1, "ik2")
    top = y1 - h
    L.rect(cx, top + 4, cx + 2, y1 - 12, "gd2")
    L.vl(cx, top + 4, y1 - 12, "gd3")
    L.hl(cx - 6, cx + 8, top + 4, "gd3")
    L.p(cx + 1, top + 2, "gd3")
    L.p(cx + 1, top + 3, "gd2")
    shirt = poly_px([(cx - 4, top + 5), (cx + 5, top + 5), (cx + 8, top + 8), (cx + 8, top + 32), (cx - 7, top + 32),
                     (cx - 7, top + 8)])
    cloth(L, shirt, "wh", 2, folds=1, seed=2)
    L.vl(cx + 1, top + 6, top + 32, "sv2")
    for k in range(4):
        L.p(cx + 1, top + 10 + k * 5, "sv1")
    L.line(cx - 2, top + 5, cx + 1, top + 9, "sv1")
    L.line(cx + 4, top + 5, cx + 1, top + 9, "sv1")
    # 软管
    for t in range(20):
        u = t / 19.0
        L.p(cx + 6 - 3 * math.sin(u * 3), y1 - 12 - u * 26, "sv0")
    L.outline()
    return L, y1


def prop_floor_vase():
    """落地大青花瓶插一大把牡丹、几枝绿叶"""
    L = Layer()
    x0, y0, x1, y1 = PLAN_BY_ID["mk_floor_vase"][3]
    cx = (x0 + x1) // 2
    prof = {}
    for y in range(y1 - 26, y1):
        t = (y - (y1 - 26)) / 25.0
        half = 3 + 5.5 * math.sin(math.pi * min(1.0, 0.25 + t * 0.85))
        prof[y] = half
        L.hl(int(cx - half + 0.5), int(cx + half + 0.5), y, "wt")
    for y, half in prof.items():
        xa, xb = int(cx - half + 0.5), int(cx + half - 0.5)
        L.p(xb, y, "bl3")
        L.p(xb - 1, y, "bl4")
        L.p(xa, y, "wt")
    for y in (y1 - 21, y1 - 19, y1 - 4):
        L.hl(int(cx - prof[y] + 1), int(cx + prof[y]), y, "bl2")
    for x in range(cx - 6, cx + 7):
        yy = y1 - 12 + round(1.5 * math.sin((x - cx) * 0.8))
        L.p(x, yy, "bl2")
        if x % 3 == 0:
            L.p(x, yy - 1, "bl1")
    L.rect(cx - 3, y1 - 29, cx + 4, y1 - 26, "wt")
    L.hl(cx - 3, cx + 4, y1 - 28, "bl2")
    st = y1 - 29
    for (lx, ly, ln, ang) in ((cx - 7, st - 5, 9, -2.6), (cx + 8, st - 6, 9, -0.5), (cx - 3, st - 14, 8, -1.9),
                              (cx + 5, st - 15, 8, -1.2)):
        leaf(L, lx, ly, ln, ang, 4, 3, vein=False)
    for (ox, oy, ramp, r) in ((-4, -9, "rd", 3), (4, -10, "pk", 3), (0, -16, "pk", 3), (-6, -17, "rd", 2),
                              (6, -18, "wl", 2), (1, -21, "rd", 2), (-1, -5, "wl", 2)):
        if ramp == "wl":
            L.ell(cx + ox - r, st + oy - r, cx + ox + r + 1, st + oy + r + 1, "wl3")
            L.ell(cx + ox - r, st + oy - r, cx + ox + r, st + oy + r, "wt")
        else:
            peony(L, cx + ox, st + oy, ramp, r)
    L.outline()
    return L, y1


def draw_doormat(L):
    """门里一块小地垫（跟休息间那块一样）"""
    x0, y0, x1, y1 = [r for r in FLAT if r[0] == "mk_doormat"][0][2]
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


# ------------------------------------------------------------------ 墙
def prop_side_walls():
    """西外墙、东隔墙：只看得见墙顶（剖开的那一条），从北墙顶一直连到前沿矮墙"""
    L = Layer()
    for (a, b) in (WALL_W, WALL_E):
        L.rect(a, CAP_Y0, b, FRONT_FACE, "wl4")
        L.vl(a + 1, CAP_Y0 + 1, FRONT_FACE, "wl5")
        L.vl(a, CAP_Y0, FRONT_FACE, "ol")
        L.vl(b - 1, CAP_Y0, FRONT_FACE, "ol")
    L.hl(WALL_W[0], WALL_W[1], CAP_Y0, "ol")
    L.hl(WALL_E[0], WALL_E[1], CAP_Y0, "ol")
    for (a, b) in (WALL_W, WALL_E):
        for y in range(CAP_Y0 + 1, CAP_Y1 - 1):
            L.p(a + 1 if a == WALL_E[0] else b - 2, y, "wl5")
    return L, 684


def prop_front_walls():
    """前沿矮墙：顶面（剖开的一条）+ 朝走廊的正面（木护墙板）；门洞两边一对门套"""
    L = Layer()
    for (a, b) in ((WALL_W[0], DOOR[0]), (DOOR[1], X1 + 8)):     # 东段多画 8 像素（出图边裁掉），凸板才排得到休息间那块
        L.rect(a, FRONT_TOP, b, FRONT_FACE, "wl4")
        L.hl(a, b, FRONT_TOP, "ol")
        L.hl(a, b, FRONT_TOP + 1, "wl5")
        L.hl(a, b, FRONT_FACE - 1, "wl3")
        # 门东边那段：凸板跟休息间那段对齐（休息间从 331 起每 18 一块）
        front_wall_face(L, a, b, start=None if a == WALL_W[0] else 331 - 18 * 6)
        if b == DOOR[0]:
            L.vl(b - 1, FRONT_TOP, FRONT_BOT, "ol")
        if a == DOOR[1]:
            L.vl(a, FRONT_TOP, FRONT_BOT, "ol")
    for (a, b) in ((DOOR[0] - 6, DOOR[0]), (DOOR[1], DOOR[1] + 6)):
        L.rect(a, FRONT_TOP - 4, b, FRONT_BOT, "wd2")
        L.vl(a, FRONT_TOP - 4, FRONT_BOT, "wd4")
        L.vl(a + 1, FRONT_TOP - 3, FRONT_BOT, "wd3")
        L.vl(b - 1, FRONT_TOP - 4, FRONT_BOT, "wd1")
        L.hl(a, b, FRONT_TOP - 4, "wd5")
        L.hl(a, b, FRONT_TOP - 3, "wd4")
        L.rect(a, FRONT_BOT - 6, b, FRONT_BOT, "wd1")
        L.hl(a, b, FRONT_BOT - 6, "wd3")
    for (a, b) in (WALL_W, WALL_E):
        L.rect(a + 1, FRONT_TOP, b - 1, FRONT_FACE - 1, "wl4")
    L.outline(skip=lambda x, y: y >= FRONT_FACE or x < WALL_W[0] or x >= WALL_E[1])
    return L, 696


# ================================================================== 影子、暖光
def floor_shading():
    S = ShadeMap()
    S.rect(WALL_W[1], FLOOR_Y, WALL_E[0], FLOOR_Y + 2, -1.5)
    S.rect(WALL_W[1], FLOOR_Y + 2, WALL_E[0], FLOOR_Y + 5, -0.5)
    S.rect(WALL_W[1], FLOOR_Y, WALL_W[1] + 6, 662, -1.0)
    S.rect(WALL_W[1] + 6, FLOOR_Y, WALL_W[1] + 9, 662, -0.5)
    S.rect(WALL_E[0] - 2, FLOOR_Y, WALL_E[0], 662, -0.5)
    S.rect(WALL_W[1], 659, WALL_E[0], 662, -0.5)
    S.rect(WALL_E[1], FLOOR_Y, WALL_E[1] + 6, 662, -1.0)          # 隔墙东边（休息间那侧）
    for (iid, name, zone, r, h, block) in PLAN:
        x0, y0, x1, y1 = r
        k = -2.0 if h < 60 else -1.5
        S.rect(x0 + 1, y0 + 1, x1 + 2, y1 + 2, k, feather=1)
    # 化妆台下面放腿的空、化妆镜灯照到地上（台前一片亮）
    for a in VANITY_X:
        S.ellipse(a + VW // 2, 256, 32, 12, 1.0, edge=1.5)
    # 门口走廊透进来一点光
    cone(S, 168, 683, 618, 40, 0.30, 1.0, edge=1.5)
    return S


def wall_light(L):
    """镜子一圈灯泡照到墙上、灯笼照到墙上"""
    S = ShadeMap()
    for a in VANITY_X:                     # v3：灯泡照亮镜子四周一圈墙，跟着拱形走（原来是一个方块）
        cx, cy, dist, normal = mirror_geom(a)
        for y in range(MIRROR_TOP - 7, 207):
            for x in range(a - 3, a + VW + 4):
                d = max(dist(x, y) - (MIRROR_R + 3), 0.0)
                if y > 206 - 3:
                    d = max(d, y - (206 - 3) + 0.0)
                f = 1.0 if d == 0 else max(0.0, 1.0 - d / 3.5)
                if f > 0:
                    S.add(x, y, f)
    for kx in KNOTS[1:-1]:
        S.ellipse(kx, 138, 8, 9, 1.0, edge=1.5)
    # 只照亮墙纸和木头（镜面、灯泡、红绸自己有颜色，不跟着挪）
    S.apply(L, clip=lambda x, y: CAP_Y1 < y < FLOOR_Y and WALL_W[1] <= x < WALL_E[0]
            and RAMP_OF.get(L.g(x, y), ("",))[0] in ("wl", "wd"))


# ================================================================== 组装
def build():
    bg = background()
    wall_light(bg)
    props = [
        ("closet_cn",) + prop_closet("mk_closet_cn", "cn"),
        ("closet_west",) + prop_closet("mk_closet_west", "west"),
        ("vanity_1",) + prop_vanity(0),
        ("vanity_2",) + prop_vanity(1),
        ("vanity_3",) + prop_vanity(2),
        ("stool_1",) + prop_stool(0),
        ("stool_2",) + prop_stool(1),
        ("stool_3",) + prop_stool(2),
        ("rack_cn_back",) + prop_rack_cn_back(),
        ("rack_cn_front",) + prop_rack_cn_front(),
        ("crown_stand",) + prop_crown_stand(),
        ("rack_west_back",) + prop_rack_west_back(),
        ("rack_west_front",) + prop_rack_west_front(),
        ("gown_form",) + prop_gown_form(),
        ("rack_jp_back",) + prop_rack_jp_back(),
        ("iko",) + prop_iko(),
        ("tansu",) + prop_tansu(),
        ("ethnic_wall",) + prop_ethnic_wall(),
        ("rack_ethnic",) + prop_rack_ethnic(),
        ("silver_crown",) + prop_silver_crown(),
        ("island",) + prop_island(),
        ("steamer",) + prop_steamer(),
        ("floor_vase",) + prop_floor_vase(),
        ("sofa",) + prop_sofa(),
        ("full_mirror",) + prop_full_mirror(),
        ("shoes",) + prop_shoes(),
        ("pouf",) + prop_pouf(),
        ("screen",) + prop_screen(),
        ("gifts",) + prop_gifts(),
        ("trunk",) + prop_trunk(),
        ("flowers",) + prop_flowers(),
        ("flowers_e",) + prop_flowers("mk_flowers_e"),
        ("side_walls",) + prop_side_walls(),
        ("front_walls",) + prop_front_walls(),
    ]
    S = floor_shading()
    S.apply(bg, clip=lambda x, y: y >= FLOOR_Y and WALL_W[1] <= x)
    # 灯泡镜照亮台面
    for name, layer, foot in props:
        if name.startswith("vanity"):
            P = ShadeMap()
            a = VANITY_X[int(name[-1]) - 1]
            P.rect(a + 2, 192, a + VW - 2, 200, 0.5)
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


def standin(n, frame, sit=False):
    im = Image.open(CHAR_DIR + "chr_LM-GUEST-%s.png" % n).convert("RGBA")
    im = im.crop((frame * 64, 0, frame * 64 + 64, 84))
    if sit:
        # 坐着：只留上身（头顶到 62 像素，表里「坐着的人」高 62），下半截让凳子挡住
        im = im.crop((0, 0, 64, 60))
    return im


def people_list():
    out = []
    for (pid, who, n, frame, (fx, fy), sit) in STANDINS:
        img = standin(n, frame, sit)
        if sit:
            # 坐着的人：图底边落在凳面上（凳面中心 y=246），排前后用凳子的着地线 +1
            out.append((img, fx, fy, 252))
        else:
            out.append((img, fx, fy, None))
    return out


def mirror_reflection(L):
    """新娘那面镜子里照出她的正脸（替身：LM-GUEST-02 第 0 格，左右翻过来；只在有人的预览图里有，
    底图的镜子是空的）。贴完把镜面反光再盖一遍，看着像隔着玻璃"""
    a = VANITY_X[1]
    gx0, gy0, gx1, gy1 = a + 10, 138, a + VW - 10, 200
    face = Image.open(CHAR_DIR + "chr_LM-GUEST-02.png").convert("RGBA").crop((0, 0, 64, 84))
    face = face.transpose(Image.FLIP_LEFT_RIGHT).crop((8, 0, 56, 46))
    fx, fy = (gx0 + gx1) // 2 - face.width // 2, 154
    fp = face.load()
    for y in range(face.height):
        for x in range(face.width):
            c = fp[x, y]
            X, Y = fx + x, fy + y
            if c[3] == 255 and gx0 <= X < gx1 and gy0 <= Y < gy1:
                L.p(X, Y, c)
    for (o, wdt) in ((10, 3), (17, 1)):
        for y in range(gy0, gy1 - 4):
            xx = gx0 + o + (gy1 - y) // 2 - 12
            for d in range(wdt):
                if gx0 <= xx + d < gx1 and (xx + d + y) % 2 == 0:
                    L.p(xx + d, y, "wt")


def compose_people(bg, props, with_people):
    """有人的版本：人脚下加影子，按着地线跟家具排前后"""
    bgp = Layer()
    bgp.im = bg.im.copy()
    bgp.px = bgp.im.load()
    plist = people_list() if with_people else []
    S = ShadeMap()
    for (img, fx, fy, seat) in plist:
        if seat is None:
            S.ellipse(fx + 1, fy - 1, 12, 4, -1.5, edge=1.5)
    S.apply(bgp)
    if with_people:
        mirror_reflection(bgp)
    out = bgp.im.copy()
    items = [(foot, 0, name, layer) for (name, layer, foot) in props]
    for k, (img, fx, fy, seat) in enumerate(plist):
        items.append((fy, 1, "p%d" % k, (img, fx, fy, seat)))
    items.sort(key=lambda t: (t[0], t[1]))
    for foot, kind, name, obj in items:
        if kind == 0:
            out.alpha_composite(obj.im, (obj.ox - X0, obj.oy - Y0))
        else:
            img, fx, fy, seat = obj
            bottom = seat if seat else fy
            out.alpha_composite(img, (fx - img.width // 2 - X0, bottom - img.height - Y0))
    return out


def palette_count(im):
    cols = set()
    for c in im.getdata():
        if c[3] == 255:
            cols.add(c[:3])
        elif c[3] != 0:
            raise SystemExit("有半透明像素：%s" % (c,))
    return cols


def walk_check():
    """从门口 (168, 680) 走得到每件东西跟前吗：2 像素一格，人按脚底 12×6 算（左右各让 6、前后各让 3）；
    能站的地 = layout 的 walk 范围（y≥232）里、化妆间墙里、不压任何 block 的东西"""
    step = 2
    blocks = [r for (iid, name, zone, r, h, block) in PLAN if block]

    def free(x, y):
        if not (WALL_W[1] + 6 <= x <= WALL_E[0] - 6 and 232 <= y <= 682):
            return False
        if y > FRONT_TOP - 3 and not (DOOR[0] + 6 <= x <= DOOR[1] - 6):
            return False
        for (x0, y0, x1, y1) in blocks:
            if x0 - 6 < x < x1 + 6 and y0 - 3 < y < y1 + 3:
                return False
        return True
    start = (168, 680)
    seen = {start}
    todo = [start]
    while todo:
        x, y = todo.pop()
        for (dx, dy) in ((step, 0), (-step, 0), (0, step), (0, -step)):
            q = (x + dx, y + dy)
            if q not in seen and free(*q):
                seen.add(q)
                todo.append(q)
    bad = []
    for (iid, name, zone, r, h, block) in PLAN:
        x0, y0, x1, y1 = r
        # 跟前：南边、东边、西边任一处站得到就算（北边多半贴墙）
        cands = [(x, y1 + 4) for x in range(x0 - 6, x1 + 8, 2)] + \
                [(x0 - 8, y) for y in range(y0, y1 + 4, 2)] + [(x1 + 8, y) for y in range(y0, y1 + 4, 2)]
        cands = [((c[0] // 2) * 2, (c[1] // 2) * 2) for c in cands]
        if not any(c in seen for c in cands):
            bad.append(iid)
    dress_ok = (DRESS[0], DRESS[1]) in seen
    print("走得通：%d/%d 件；换装点 %s" % (len(PLAN) - len(bad), len(PLAN), "站得到" if dress_ok else "站不到"))
    if bad:
        print("  走不到：" + "、".join(bad))
    return bad


def crop_alpha(layer):
    """一层先裁到这间的左右范围（BG_CROP 的 x），再裁到画了的那块：回 (图, 左上角画布 x, y)；这间这半什么都没画回 None"""
    x0, x1 = BG_CROP[0] - layer.ox, BG_CROP[2] - layer.ox
    im = layer.im.crop((x0, 0, x1, layer.im.height))
    box = im.getbbox()
    if box is None:
        return None
    return im.crop(box), BG_CROP[0] + box[0], layer.oy + box[1]


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    check_layout()
    if walk_check():
        raise SystemExit("有东西从门口走不到，先改摆法")
    bg, props = build()
    room = compose(bg, props)
    cols = palette_count(room)
    print("整间 %s，颜色 %d 种" % (room.size, len(cols)))
    if len(cols) > 64:
        raise SystemExit("颜色超过 64 种（%d）" % len(cols))
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    bx0, by0, bx1, by1 = BG_CROP
    bgi = bg.im.crop((bx0 - X0, by0 - Y0, bx1 - X0, by1 - Y0))
    palette_count(bgi)
    bgi.save(os.path.join(OUT, "room.png"))
    man = {"note": "tools/pixel_art/room_backhall_makeup.py 生成，别手改。背景左上角放在 background.x/y（画布坐标），1 倍、不插值；"
                   "每件家具左上角在 x/y，着地线 foot（跟人排前后用）；hide 是要藏掉的灰盒（挡人的占地照旧）",
           "background": {"png": RES + "room.png", "x": bx0, "y": by0}, "room": {"x0": bx0, "x1": bx1}, "props": []}
    names = set()
    for name, layer, foot in props:
        cut = crop_alpha(layer)
        if cut is None:
            continue
        im, x, y = cut
        palette_count(im)
        im.save(os.path.join(OUT, "props", name + ".png"))
        names.add(name + ".png")
        hide = ["mk_" + name] if ("mk_" + name) in PLAN_BY_ID else []
        man["props"].append({"id": "px_mk_" + name, "png": RES + "props/%s.png" % name, "x": x, "y": y, "foot": foot, "hide": hide})
    for f in os.listdir(os.path.join(OUT, "props")):   # 改名、删掉的家具别留旧图
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(OUT, "props", f))
    backhall_plan_c.shift_room_json(man, DX)   # 方案 C：整间挪到最东头
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print("背景 %s，家具 %d 件 → %s" % (bgi.size, len(man["props"]), OUT))
    if preview:
        os.makedirs(preview, exist_ok=True)
        room.save(os.path.join(preview, "makeup_room.png"))
        room.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(preview, "makeup_room_x2.png"))
        lounge = Image.open(LOUNGE_PNG).convert("RGBA")
        both = Image.new("RGBA", (680 - X0, H), C["void"])
        both.alpha_composite(lounge, (LOUNGE_X0 - X0, 0))
        both.alpha_composite(room.crop((0, 0, 331 - X0, H)), (0, 0))
        both.save(os.path.join(preview, "makeup_with_lounge.png"))
        phone(bg, props, lounge, preview)


def phone(bg, props, lounge, out_dir):
    """手机竖屏 540×960：镜头靠西边贴着画布边（x 0～540），所以右边露出休息间；北边从 y 40 起"""
    SW, SH = 540, 960
    cx0, cy0 = 0, 40                      # 屏幕左上角对应的画布坐标
    scr = Image.new("RGBA", (SW, SH), C["void"])
    cor = Layer(x0=cx0, y0=696, w=SW, h=SH - (696 - cy0))
    draw_corridor(cor)
    scr.alpha_composite(cor.im, (0, 696 - cy0))
    # 休息间（成品图，没人）
    scr.alpha_composite(lounge.crop((336 - LOUNGE_X0, 0, lounge.width, FRONT_BOT - Y0)), (336 - cx0, Y0 - cy0))
    room = compose_people(bg, props, True).crop((0, 0, W, FRONT_BOT - Y0))
    room = room.crop((0 - X0, 0, 336 - X0, room.height))
    scr.alpha_composite(room, (0 - cx0, Y0 - cy0))
    scr.save(os.path.join(out_dir, "makeup_phone.png"))


def draw_corridor(L):
    """手机图底下那条走廊（跟休息间同一种）：米色石砖错缝、中间一条红地毯（金边、回纹带）、南边墙顶"""
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
            if rnd.random() < 0.3:
                L.p(x + rnd.randrange(4, 44), y + rnd.randrange(3, 10), shift(tone, -1))
            L.vl(x, y, y + 12, "wl0")
        L.hl(x0, x1, y, "wl0")
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
    L.rect(x0, 884, x1, 896, "wl4")
    L.hl(x0, x1, 884, "ol")
    L.hl(x0, x1, 885, "wl5")
    L.hl(x0, x1, 895, "ol")
    for x in range(x0, x1):
        L.shade_px(x, 697, -1)
        if x % 2 == 0:
            L.shade_px(x, 698, -1)
        L.shade_px(x, 883, -1)
        if x % 2:
            L.shade_px(x, 882, -1)


if __name__ == "__main__":
    main()
