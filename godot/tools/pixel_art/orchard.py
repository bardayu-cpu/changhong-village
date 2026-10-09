#!/usr/bin/env python3
"""罗曼山庄果园：用代码画的像素成品（01 画，改 8 轮；阿鱼 10/3 看了回「能」；标准见 docs/罗曼山庄画风.md 第 0 节）。
1 倍颗粒、硬边、这块画布 ≤64 色（同名颜色全游戏一个值：木、地板木、红、金、白、蓝、墨跟室内样板同值）、光从左上来、按着地线分层。

出游戏用的图（assets/pixel_art/orchard/）：
  room.png        背景：整块 1536×1280（北边远景、田埂、小路、草地、草莓地垄沟、树盘、地上的影子和落叶都在里面）
  props/*.png     每件立着的东西一张：8 条草莓垄、6 棵枇杷树各「有果 / 没果」两张，16 段篱笆、稻草人、4 只筐、收购处摊子、板车
  room.json       放哪：每张左上角 x、y、着地线 foot、要藏的灰盒 hide；有果没果那几张多写 plot（哪块地）和 fruit（true 有果）。
                  entrance.gd 的 _pixel_art() 铺上，orchard.gd 照每块地熟没熟显示其中一张
位置只从 layout.json 取：开头 check_layout() 把用到的东西逐件跟 layout.json 对一遍；每件画出来的外框还要跟 layout 里的 art_box 一样
（零件规格的「框」照画的尺寸出，gen_specs_court.py 读 art_box），对不上就停。
样板原稿在 godot/回执/样板间-果园/draw_orchard.py；这份是 02 收进来、改成出游戏用的图，画法一笔没动。

用法：python3 godot/tools/pixel_art/orchard.py [--preview 目录]（跑一次约 30 秒）
      --preview 再出整块有果、没果 1:1 和手机竖屏（站两位定稿宾客当尺子）
坐标全用游戏画布坐标（1536×1280），1 个美术像素 = 1 个画布像素。
斜俯视、没有透视：地面前后 1 米 = 32 像素，左右和高 1 米 = 48 像素。
一件东西 = 占地（x0..x1, yf0..yf1）+ 高 z；顶面画在 y = yf - z。光从左上来，影子落右下。
"""
import json
import math
import os
import random
import shutil
import sys
from array import array

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_orchard", "layout.json")
CHAR_DIR = os.path.join(GODOT, "assets", "characters", "lm") + "/"
OUT = os.path.join(GODOT, "assets", "pixel_art", "orchard")
RES = "res://assets/pixel_art/orchard/"
W, H = 1536, 1280

# ------------------------------------------------------------------ 调色板
# 室内样板（休息间）的木、地板木、红、金、白、蓝、墨照搬原值；户外新加草、叶、土、竹、水、远景雾色几条色带
PAL_HEX = {
    "ol": "#22140f",
    "wd0": "#3a2218", "wd1": "#552f1f", "wd2": "#71402a", "wd3": "#8f5535", "wd4": "#ad6d40", "wd5": "#c98d58",
    "fl0": "#5a3e2e", "fl1": "#765238", "fl2": "#8e6846", "fl3": "#a67c54", "fl4": "#ba8e60", "fl5": "#c89e6c",
    "fl6": "#d6b07e", "fl7": "#e6c696",
    "rd0": "#3d0e13", "rd1": "#62181b", "rd2": "#8a2321", "rd3": "#b1332a", "rd4": "#d24f39", "rd5": "#ea8152",
    "gd0": "#563610", "gd1": "#87591c", "gd2": "#b8862b", "gd3": "#deb550", "gd4": "#f7e09a",
    "wt": "#fdfbf3",
    "bl1": "#243863", "bl2": "#385a90", "bl3": "#6c8fbd", "bl4": "#b0c6de",
    "ik2": "#34303d", "ik3": "#554e60",
    # 草（8 档）：前 5 档是样板的 gr0～gr4，中间插了 gA、gB，最亮加 gC
    "gr0": "#1b3022", "gr1": "#284a2c", "gr2": "#3f6935", "gA": "#527d3a", "gr3": "#649340",
    "gB": "#7fa84a", "gr4": "#9cbd5e", "gC": "#c5d888",
    # 枇杷叶（偏蓝的深绿，跟草分开）
    "nl1": "#234536", "nl2": "#31593c", "nl3": "#477a45",
    # 土（四川紫色土，偏红紫）
    "so0": "#2c1c1c", "so1": "#46292a", "so2": "#613a35", "so3": "#7d4f43", "so4": "#98654f",
    # 竹（干竹篱笆、竹筐）
    "bb0": "#50491f", "bb1": "#807636", "bb2": "#ad9f50", "bb3": "#d6c782",
    # 水（水田倒映天光）
    "wa0": "#5d8c95", "wa1": "#8fbcc0", "wa2": "#c3e0dc",
    # 远景雾色（远处的田一层层淡）
    "hz0": "#7e9b78", "hz1": "#a0b693", "hz2": "#c3d1ad",
    "wl2": "#d0b892", "wl3": "#e2cca6",
    # 枇杷果、小花
    "or": "#dd7a2c", "lq": "#f0a43c", "pk": "#de8399",
}


def hex2rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


C = {k: hex2rgba(v) for k, v in PAL_HEX.items()}
# 色带（暗 → 亮）。同一个颜色在几条色带里时，后写的说了算（背景挪档按草、土、路走）
RAMPS = {
    "lf": ["gr0", "nl1", "nl2", "nl3", "gr3", "gB"],
    "lq": ["or", "lq", "gd4"],
    "wd": ["wd0", "wd1", "wd2", "wd3", "wd4", "wd5"],
    "fl": ["fl0", "fl1", "fl2", "fl3", "fl4", "fl5", "fl6", "fl7"],
    "rd": ["rd0", "rd1", "rd2", "rd3", "rd4", "rd5"],
    "gd": ["gd0", "gd1", "gd2", "gd3", "gd4"],
    "bl": ["bl1", "bl2", "bl3", "bl4", "wt"],
    "ik": ["ik2", "ik3"],
    "so": ["so0", "so1", "so2", "so3", "so4"],
    "bb": ["bb0", "bb1", "bb2", "bb3"],
    "wa": ["wa0", "wa1", "wa2"],
    "hz": ["hz0", "hz1", "hz2"],
    "wl": ["fl6", "wl2", "wl3"],
    "gr": ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"],
}
RAMP_OF = {}
for rn, names in RAMPS.items():
    for i, n in enumerate(names):
        RAMP_OF[C[n]] = (rn, i)
PAL_SET = set(C.values())


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
    return names[max(0, min(len(names) - 1, int(i)))]


def is_ramp(col, rn):
    return col[3] and col in RAMP_OF and RAMP_OF[col][0] == rn


# ------------------------------------------------------------------ 噪声（只用来挑色块、定疏密，不出半透明）
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

    def shade_rect(self, x0, y0, x1, y1, k):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.shade_px(x, y, k)

    def outline(self, col="ol", pick=None):
        """不透明区外面一圈 1 像素描边；pick(x, y, 邻居颜色) 可以按邻居换描边色"""
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

    def copy(self):
        n = Layer(self.ox, self.oy, self.w, self.h)
        n.im = self.im.copy()
        n.px = n.im.load()
        return n


class ShadeMap:
    """背景的明暗图：每个像素一个数（负 = 暗、正 = 亮），最后取整到半档，半档用棋盘格"""

    def __init__(self):
        self.v = array("f", [0.0]) * (W * H)

    def add(self, x, y, val):
        if 0 <= x < W and 0 <= y < H:
            self.v[y * W + x] += val

    def rect(self, x0, y0, x1, y1, val):
        for y in range(max(0, int(y0)), min(H, int(y1))):
            for x in range(max(0, int(x0)), min(W, int(x1))):
                self.v[y * W + x] += val

    def ellipse(self, cx, cy, rx, ry, val, edge=1.5):
        """里面整档，最外 edge 像素那圈给一半（取整后是一圈棋盘点）"""
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

    def blob(self, cx, cy, rx, ry, val, seed, wob=0.18, edge=1.5):
        """不规则的一团（树影）：半径按角度起伏"""
        ph = [h2(seed, i, 77) * 6.28 for i in range(3)]
        rm = (rx + ry) / 2.0
        for y in range(int(cy - ry * 1.3) - 1, int(cy + ry * 1.3) + 2):
            for x in range(int(cx - rx * 1.3) - 1, int(cx + rx * 1.3) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                th = math.atan2(dy, dx)
                rr = 1 + wob * (0.6 * math.sin(3 * th + ph[0]) + 0.4 * math.sin(5 * th + ph[1]))
                d = math.sqrt(dx * dx + dy * dy) / rr
                if d >= 1.0:
                    continue
                f = 1.0 if (1.0 - d) * rm > edge else 0.5
                self.add(x, y, val * f)

    def apply(self, layer):
        for y in range(H):
            base = y * W
            for x in range(W):
                s = self.v[base + x]
                if -0.2 < s < 0.2:
                    continue
                s = round(s * 2) / 2.0
                k = math.floor(s)
                if s - k > 0.25 and (x + y) % 2 == 0:
                    k += 1
                if k:
                    layer.shade_px(x, y, k)


# ------------------------------------------------------------------ 布局核对
RIDGE_Y = [544, 612, 680, 748, 816, 884, 952, 1020]
TREES = {"loquat_0_0": (862, 612), "loquat_0_1": (1150, 612), "loquat_0_2": (1438, 612),
         "loquat_1_0": (862, 1040), "loquat_1_1": (1150, 1040), "loquat_1_2": (1438, 1040)}
BASKETS = {"basket_strawberry_shop": [1068, 1078, 1092, 1088], "basket_loquat_shop": [1098, 1078, 1122, 1088],
           "basket_strawberry_field": [648, 522, 672, 532], "basket_loquat_field": [1288, 552, 1312, 562]}
STALL = [900, 1056, 1060, 1088]
CART = [1132, 1052, 1228, 1080]
FLATS_USED = [[714, 442, 822, 1166], [720, 446, 816, 1162], [88, 494, 708, 1068], [840, 494, 1462, 1068],
              [60, 1102, 1490, 1150], [0, 406, 1536, 442], [0, 442, 1536, 456], [0, 114, 1536, 128],
              [0, 186, 1536, 200]]
NPCS = {"farmer_1": (250, 594), "farmer_2": (560, 866), "farmer_3": (1110, 650), "farmer_4": (980, 1050)}
POINTS = {"strawberry": (400, 796, 60), "loquat": (1150, 756, 60), "shop": (980, 1122, 55)}   # 口（to_*）归连图管，这里不核

# 10/4 方案 C（阿鱼「行，C」：照阿鱼图只上下翻、左右不变，godot/回执/方向方案C-上下翻-1004.png）：果园 B 枇杷挪到西、A 草莓挪到东。
# 上面这些数、下面的画法照旧是翻之前的摆法（一笔不改）；出图时：
#   北边田埂往南（y ≥ SPLIT_Y）的地面整片左右翻（北边田野、小房子、篱笆不翻）；
#   立着的东西（草莓垄、枇杷树、稻草人、篮子、收购摊、板车）照原样画、不翻，各按参照点 fx 挪到 W − fx（光还是从左上来）；
#   地上的影子、落叶照挪过去的位置算。layout.json 里地面、口、牌子、人跟着翻，挡人占地跟着画一起挪（check_layout 照这个核）
MIRROR = True
SPLIT_Y = 412


def dx_of(fx):
    """参照点在 fx 的东西，方案 C 要往右挪多少（fx → W − fx）"""
    return (W - 2 * fx) if MIRROR else 0


def mx(x):
    """地面上的 x 翻过去"""
    return (W - x) if MIRROR else x


def mrect(r):
    return [mx(r[2]), r[1], mx(r[0]), r[3]] if MIRROR else list(r)


def shifted(r, fx):
    d = dx_of(fx)
    return [r[0] + d, r[1], r[2] + d, r[3]]


def basket_fx(rc):
    return (rc[0] + rc[2]) // 2


def check_layout():
    d = json.load(open(LAYOUT, encoding="utf-8"))
    it = {i["id"]: i for i in d["items"] if "id" in i}
    bad = []

    def want(cond, msg):
        if not cond:
            bad.append(msg)

    want(d["size"] == [W, H], "画布大小 %s" % d["size"])
    for k, y in enumerate(RIDGE_Y):
        r = it.get("ridge_%d" % k, {})
        want(r.get("rect") == shifted([100, y, 700, y + 28], 400) and r.get("h") == 10, "ridge_%d %s h%s" % (k, r.get("rect"), r.get("h")))
    for tid, (x, y) in TREES.items():
        t = it.get(tid, {})
        want((t.get("x"), t.get("y"), t.get("h"), t.get("w")) == (mx(x), y, 252, 130), "%s (%s,%s) h%s w%s" % (
            tid, t.get("x"), t.get("y"), t.get("h"), t.get("w")))
    s = it.get("shop_stall", {})
    want(s.get("rect") == shifted(STALL, 980) and s.get("h") == 43, "shop_stall %s h%s" % (s.get("rect"), s.get("h")))
    c = it.get("cart", {})
    want(c.get("rect") == shifted(CART, 1196) and c.get("h") == 30, "cart %s h%s" % (c.get("rect"), c.get("h")))
    for bid, rc in BASKETS.items():
        b = it.get(bid, {})
        want(b.get("rect") == shifted(rc, basket_fx(rc)) and b.get("h") == 14, "%s %s" % (bid, b.get("rect")))
    for i in range(1, 17):
        f = it.get("fence_%02d" % i, {})
        want(f.get("rect") == [96 * (i - 1), 398, 96 * i, 404] and f.get("h") == 48, "fence_%02d %s" % (i, f.get("rect")))
    sd = dx_of(400)    # 稻草人跟草莓地一起挪
    p = it.get("scarecrow_post", {})
    want(p.get("rect") == [397 + sd, 524, 403 + sd, 530] and p.get("h") == 77, "scarecrow_post %s" % p.get("rect"))
    a = it.get("scarecrow_arms", {})
    want((a.get("x0"), a.get("x1"), a.get("top"), a.get("thick")) == (376 + sd, 424 + sd, 474, 5), "scarecrow_arms")
    want(it.get("scarecrow_shirt", {}).get("pts") == [[x + sd, y] for x, y in [[388, 470], [412, 470], [416, 500], [384, 500]]], "scarecrow_shirt")
    want(it.get("scarecrow_hat", {}).get("pts") == [[x + sd, y] for x, y in [[384, 460], [416, 460], [408, 453], [404, 446], [396, 446], [392, 453]]],
         "scarecrow_hat")
    rects = [f["rect"] for f in d["flat"] if f.get("type") == "rect"]
    for r in FLATS_USED:
        want(mrect(r) in rects, "平铺 %s 不见了" % mrect(r))
    npcs = {n["id"]: (n["x"], n["y"]) for n in d.get("npcs", [])}
    for k, (x, y) in NPCS.items():
        want(npcs.get(k) == (mx(x), y), "%s 站位 %s" % (k, npcs.get(k)))
    pts = {p["id"]: (p["x"], p["y"], p["r"]) for p in d.get("points", [])}
    for k, (x, y, r) in POINTS.items():
        want(pts.get(k) == (mx(x), y, r), "交互点 %s %s" % (k, pts.get(k)))
    want(d.get("walk") == [[[mx(1490), 466], [mx(60), 466], [mx(60), 1156], [mx(1490), 1156]]], "walk 变了")
    if bad:
        raise SystemExit("layout.json 跟这版画的位置对不上（摆法改了，先停）：\n" + "\n".join(bad))


# ================================================================== 小零件（印章）
def tuft(L, x, y, rnd, k=1):
    """一小撮草：2～4 根竖着的叶片，比底色亮 k 档（k<0 是暗草），叶根压暗一档"""
    xs = sorted(rnd.sample([-4, -2, 0, 2, 4], rnd.randint(2, 4)))
    for bx in xs:
        hgt = rnd.randint(2, 3) if k > 0 else rnd.randint(1, 2)
        lean = rnd.choice([0, 0, -1, 1])
        for j in range(hgt):
            px_ = x + bx + (lean if j == hgt - 1 and hgt > 1 else 0)
            kk = k + (1 if (j == hgt - 1 and k > 0 and hgt == 3) else 0)
            L.shade_px(px_, y - j, kk)
        L.shade_px(x + bx, y + 1, -1)


def flower(L, x, y, kind):
    if kind == "daisy":
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            L.p(x + dx, y + dy, "wt")
        L.p(x, y, "gd3")
        L.shade_px(x + 1, y + 1, -2)
    elif kind == "yellow":
        L.p(x, y, "gd4")
        L.p(x + 1, y, "gd3")
        L.p(x, y + 1, "gd3")
        L.p(x + 1, y + 1, "gd2")
        L.shade_px(x + 2, y + 1, -2)
    elif kind == "pink":
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            L.p(x + dx, y + dy, "pk")
        L.p(x, y, "wt")
        L.shade_px(x + 1, y + 1, -2)
    elif kind == "blue":
        L.p(x, y, "bl3")
        L.p(x + 1, y, "bl4")
        L.p(x, y + 1, "bl2")
        L.shade_px(x + 1, y + 1, -2)
    elif kind == "white":
        L.p(x, y, "wt")
        L.shade_px(x + 1, y, -1)


def pebble(L, x, y, rnd):
    w = rnd.randint(2, 4)
    L.hl(x, x + w, y, "fl7")
    L.hl(x, x + w, y + 1, "fl4")
    if w > 2:
        L.p(x + w - 1, y, "fl5")
    L.p(x + w, y + 1, shift(L.g(x + w, y + 1), -2) if L.has(x + w, y + 1) else "fl2")
    L.hl(x, x + w + 1, y + 2, shift(L.g(x, y + 2), -1) if L.has(x, y + 2) else "fl2")


def fallen_leaf(L, x, y, rnd, palette=None):
    cols = palette or ["gd2", "nl3", "gd1", "wd3", "gr3", "gd3"]
    a = rnd.choice(cols)
    if rnd.random() < 0.5:
        L.hl(x, x + 3, y, a)
        L.p(x + 1, y + 1, shift(a, -1))
    else:
        L.p(x, y, a)
        L.p(x + 1, y + 1, a)
        L.p(x + 2, y + 1, shift(a, -1))


# ================================================================== 背景
def grass_tone(x, y, bias=0.0):
    n = vnoise(x, y * 1.3, 72, 11) * 0.45 + vnoise(x, y * 1.3, 21, 12) * 0.35 + vnoise(x, y, 5, 13) * 0.20 + bias
    tones = ("gr3", "gB", "gr4")
    th = (0.31, 0.71)
    idx = 0
    for t in th:
        if n >= t:
            idx += 1
    for j, t in enumerate(th):
        if abs(n - t) < 0.018:
            idx = j + 1 if (x + y) % 2 == 0 else j
            break
    return tones[idx]


def paint_grass(L, x0, y0, x1, y1, bias=0.0, test=None):
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            if test and not test(x, y):
                continue
            L.px[x, y] = C[grass_tone(x, y, bias)]


def grass_details(L, rnd, area, dens=1.0, flowers=True):
    """草叶、成团的小花、碎石。只落在草色上"""
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
                if n > 0.62 and rnd.random() < 0.5:
                    tuft(L, x + rnd.randint(-4, 4), y + rnd.randint(2, 4), rnd, 1)
    if flowers:
        area_px = (x1 - x0) * (y1 - y0)
        for _ in range(int(area_px / 9000 * dens)):
            fx = rnd.randrange(x0, x1)
            fy = rnd.randrange(y0, y1)
            if not is_ramp(L.g(fx, fy), "gr"):
                continue
            kind = rnd.choice(["daisy", "daisy", "yellow", "yellow", "pink", "blue", "white", "white"])
            nfl = rnd.randint(3, 8)
            for _ in range(nfl):
                xx = fx + rnd.randint(-9, 9)
                yy = fy + rnd.randint(-6, 6)
                if is_ramp(L.g(xx, yy), "gr") and is_ramp(L.g(xx + 1, yy + 1), "gr"):
                    L.shade_px(xx, yy + 1, -1)
                    flower(L, xx, yy, kind)
        for _ in range(int(area_px / 14000 * dens)):
            px_ = rnd.randrange(x0, x1)
            py_ = rnd.randrange(y0, y1)
            if is_ramp(L.g(px_, py_), "gr"):
                pebble(L, px_, py_, rnd)


def bund(L, x0, x1, y, face, lip, face_cols, foot):
    """田坎：一行亮的坎沿 + face 行朝南的坎面 + 一行坎脚暗边（坎沿、坎脚随噪声起伏一点）"""
    for x in range(x0, x1):
        wob = 1 if vnoise(x, y, 11, 5) > 0.62 else 0
        L.p(x, y - 1 - wob, lip)
        if wob:
            L.p(x, y - 1, lip)
        for j in range(face):
            L.p(x, y + j, face_cols[min(len(face_cols) - 1, j)])
        L.p(x, y + face, foot)


def rice_clump(L, x, y, k, rnd, ramp=("gd1", "gd2", "gd3", "gd4")):
    """一丛熟稻：两三根弯下来的穗（亮）+ 下面的秆（暗）；k 是这丛整体亮暗（-1/0/+1）"""
    d0, d1, d2, d3 = [ramp[max(0, min(3, i + k))] for i in range(4)]
    for (ox, oy) in rnd.sample([(-2, 0), (0, -1), (2, 0), (1, 1)], rnd.randint(2, 3)):
        px_, py_ = x + ox, y + oy
        L.p(px_, py_, d2)
        L.p(px_ + 1, py_ - 1, d3)
        L.p(px_ + 2, py_ - 1, d3 if rnd.random() < 0.6 else d2)
        L.p(px_ + 3, py_, d2)
        L.p(px_ + 3, py_ + 1, d1)
        L.p(px_, py_ + 1, d1)
    L.p(x, y + 2, d0)
    L.p(x + 1, y + 2, d1)


def egret(L, x, y, face):
    """一只白鹭（站在水里，约 14 宽 16 高）：白身、黄嘴、黑脚，水里一道倒影"""
    f = face
    # 身子
    L.ell(x - 5, y - 8, x + 5, y - 2, "wt")
    L.p(x - 5 * f, y - 6, "wt")
    L.p(x - 6 * f, y - 5, "wt")
    L.p(x - 7 * f, y - 4, "bl4")
    for i in range(-3, 4):
        L.p(x + i, y - 2, "bl4")
    # 脖子和头
    L.p(x + 3 * f, y - 9, "wt")
    L.p(x + 3 * f, y - 10, "wt")
    L.p(x + 4 * f, y - 11, "wt")
    L.p(x + 4 * f, y - 12, "wt")
    L.p(x + 5 * f, y - 12, "wt")
    L.p(x + 5 * f, y - 13, "wt")
    L.p(x + 6 * f, y - 13, "bl4")
    L.p(x + 5 * f, y - 12, "ol")
    L.p(x + 7 * f, y - 13, "gd3")
    L.p(x + 8 * f, y - 13, "gd3")
    L.p(x + 9 * f, y - 12, "gd2")
    # 脚
    L.vl(x - 1, y - 1, y + 2, "ol")
    L.vl(x + 1, y - 1, y + 2, "ol")
    # 倒影
    for i in range(-4, 5, 2):
        L.p(x + i, y + 3, "wa2")
    L.p(x, y + 4, "wa2")


def shrub(L, x, y, rnd, hazy=False):
    """一丛矮灌木 / 野草（脚在 y）"""
    if hazy:
        cols = ("hz0", "hz1", "hz2")
    else:
        cols = ("gr2", "gr3", "gr4")
    w = rnd.randint(7, 13)
    hgt = rnd.randint(5, 8)
    L.ell(x - w // 2, y - hgt, x + w // 2 + 1, y + 1, cols[1])
    L.ell(x - w // 2 + 1, y - hgt, x + 1, y - hgt // 2 + 1, cols[2])
    L.ell(x, y - hgt // 2, x + w // 2 + 1, y + 1, cols[0], only=lambda a, b: (a - x) + (b - y) > -3)
    for i in range(-w // 2, w // 2 + 1, 2):
        L.p(x + i, y - hgt - (1 if i % 4 else 0), cols[2] if i < 0 else cols[1])
    L.hl(x - w // 2 + 1, x + w // 2 + 2, y + 1, cols[0])


def north_fields(L, rnd):
    # ---- 最远：一片片竹林盘（树冠在画外，只露下面的竹叶和竹竿），中间露一户川西人家 y 0～60
    for y in range(0, 60):
        for x in range(W):
            n = vnoise(x, y, 5, 39)
            L.p(x, y, "hz2" if n > 0.82 else "hz1")
    # 林盘一团团
    x = -20
    house_x = 640
    groves = []
    while x < W + 20:
        w = rnd.randint(90, 170)
        if x < house_x + 60 and x + w > house_x - 60:
            x = house_x + 80
            continue
        groves.append((x, x + w, rnd.randint(16, 26)))
        x += w + rnd.randint(14, 50)
    for (a, b, yb) in groves:
        # 竹竿（树冠在画外，下面露出一根根竿子）
        for cx in range(a + 6, b - 6, 5):
            if rnd.random() < 0.75:
                bot = yb + rnd.randint(12, 20)
                for y in range(yb - 6, bot):
                    L.p(cx, y, "hz0")
                    L.p(cx + 1, y, "hz1")
                for y in range(yb - 2, bot, 7):
                    L.p(cx, y, "hz1")
                    L.p(cx + 1, y, "hz2")
                L.p(cx + 2, bot - 1, "hz0")
        # 竹叶团：一个个往下垂的圆团，左上亮右下暗，底沿一排尖
        lob = []
        x = a
        while x < b:
            r = rnd.uniform(11, 17)
            lob.append((x + r * 0.6, yb - r * 0.55 + rnd.uniform(-3, 3), r))
            x += r * 1.1
        for (lx, ly, r) in lob:
            for y in range(int(ly - r) - 1, int(ly + r) + 2):
                for xx in range(int(lx - r) - 1, int(lx + r) + 2):
                    dx, dy = (xx + 0.5 - lx) / r, (y + 0.5 - ly) / r
                    d2 = dx * dx + dy * dy
                    if d2 > 1.0 or y < 0:
                        continue
                    lum = -(dx * 0.6 + dy * 0.75)
                    col = "hz2" if lum > 0.35 else ("hz1" if lum > -0.25 else "hz0")
                    if 0.25 < lum <= 0.35 and (xx + y) % 2:
                        col = "hz1"
                    if -0.35 < lum <= -0.25 and (xx + y) % 2:
                        col = "hz1"
                    L.p(xx, y, col)
            # 底沿垂下来的竹叶尖
            for xx in range(int(lx - r * 0.8), int(lx + r * 0.8), 3):
                yy = int(ly + math.sqrt(max(0.0, r * r - (xx - lx) ** 2))) - 1
                L.p(xx, yy + 1, "hz0")
                L.p(xx + 1, yy + 2, "hz0")
        # 林下一溜影
        for xx in range(a + 4, b + 8):
            yy = yb + 20
            L.p(xx, yy, "hz0" if xx % 2 else "hz1")
            L.p(xx, yy + 1, "hz1")
    # 川西人家：青瓦檐口、白墙、木柱（远，雾里）
    hx0, hx1 = house_x - 56, house_x + 56
    L.rect(hx0 - 6, 0, hx1 + 6, 14, "wa0")
    for x in range(hx0 - 6, hx1 + 6, 3):
        L.vl(x, 0, 14, "hz0")
    L.hl(hx0 - 6, hx1 + 6, 14, "hz0")
    L.hl(hx0 - 6, hx1 + 6, 15, "wa1")
    L.rect(hx0, 16, hx1, 40, "wt")
    L.rect(hx0, 16, hx1, 19, "hz2")
    for x in (hx0, hx0 + 28, house_x - 1, hx1 - 29, hx1 - 3):
        L.rect(x, 16, x + 3, 40, "hz0")
    L.rect(house_x - 9, 22, house_x + 8, 40, "hz0")
    L.rect(house_x - 7, 24, house_x + 6, 40, "wd3")
    L.vl(house_x - 1, 24, 40, "wd2")
    L.rect(house_x - 9, 20, house_x + 8, 22, "rd3")          # 门楣一道红（办喜事）
    for wx in (hx0 + 9, hx1 - 21):
        L.rect(wx, 24, wx + 12, 33, "hz0")
        L.rect(wx + 1, 25, wx + 11, 32, "wa1")
        L.vl(wx + 6, 25, 32, "hz0")
    L.hl(hx0 - 2, hx1 + 2, 40, "hz0")
    L.rect(hx0 - 4, 41, hx1 + 4, 46, "wl3")                  # 院坝
    # 门口挂两盏红灯笼（远）
    for lx in (house_x - 14, house_x + 12):
        L.rect(lx, 19, lx + 3, 25, "rd3")
        L.p(lx + 1, 20, "rd4")
        L.p(lx + 1, 25, "gd3")
    bund(L, 0, W, 60, 3, "hz2", ["hz1", "hz0", "hz0"], "fl6")
    # ---- 远的梯田：熟稻（雾里的金），等高线弯弯的三层 y 64～110
    L.rect(0, 64, W, 110, "wl2")
    phs = [rnd.uniform(0, 6.28) for _ in range(3)]
    def contour(x, k):
        return 64 + k * 15 + 3.0 * math.sin(x / 95.0 + phs[k % 3]) + 1.5 * math.sin(x / 37.0 + k)
    for k in range(3):
        for x in range(W):
            ya = int(contour(x, k)) if k else 64
            yb = int(contour(x, k + 1)) if k < 2 else 110
            for y in range(ya, yb):
                L.p(x, y, "wl2" if (y - ya) % 4 else "fl6")
        for _ in range(int(W * 15 / 6)):
            x = rnd.randrange(0, W)
            ya = contour(x, k) if k else 64
            yb = contour(x, k + 1) if k < 2 else 110
            y = int(rnd.uniform(ya + 2, yb - 2))
            sheen = 1 if vnoise(x, y, 60, 53) > 0.62 else 0
            rice_clump(L, x, y, sheen, rnd, ("fl6", "wl2", "bb3", "wl3"))
        if k:
            for x in range(W):
                y = int(contour(x, k))
                L.p(x, y - 1, "wl3")
                L.p(x, y, "fl5")
                L.p(x, y + 1, "fl6")
    bund(L, 0, W, 110, 3, "wl3", ["fl6", "fl5", "fl5"], "fl4")
    # ---- 远处的田间土路 y 114～128
    for y in range(114, 128):
        for x in range(W):
            n = vnoise(x, y, 20, 42)
            col = "fl7" if n > 0.45 else "wl3"
            if y in (117, 124) and vnoise(x, y, 14, 43) > 0.35:
                col = "fl6"
            L.p(x, y, col)
    for x in range(W):
        if vnoise(x, 0, 7, 44) > 0.5:
            L.p(x, 114, "hz1")
            L.p(x, 115, "hz1" if vnoise(x, 9, 4, 44) > 0.5 else "wl3")
        if vnoise(x, 1, 7, 44) > 0.6:
            L.p(x, 127, "hz1")
    # ---- 中间一层：菜地（一块块，不同的菜，比远处绿一点）y 128～182
    L.rect(0, 128, W, 182, "fl6")
    x = 0
    plots = []
    kinds = ["cabbage", "onion", "tilled", "rape", "cabbage", "bean"]
    while x < W:
        w = rnd.randrange(150, 270)
        plots.append((x, min(W, x + w), kinds[len(plots) % len(kinds)]))
        x += w
    for (a, b, kind) in plots:
        for y in range(129, 181):
            rr = (y - 129) % 9
            for x in range(a + 2, b - 2):
                if kind == "tilled":
                    col = "fl7" if rr < 2 else ("fl6" if rr < 6 else "fl5")
                    L.p(x, y, col)
                elif kind == "onion":
                    if rr < 6 and x % 3 == 0:
                        L.p(x, y, "gC" if rr < 2 else "hz1")
                    elif rr >= 7:
                        L.p(x, y, "fl5")
                elif kind == "rape":
                    if rr < 6:
                        L.p(x, y, "hz1" if (x + y) % 3 else "gr4")
                        if rr < 2 and (x * 5 + y) % 7 == 0:
                            L.p(x, y, "gd4")
                    else:
                        L.p(x, y, "fl5")
                elif kind == "bean":
                    if rr < 7:
                        L.p(x, y, "gr4" if (x // 2 + rr) % 4 else "gC")
                        if rr == 6:
                            L.p(x, y, "hz0")
                    if x % 14 == 0 and rr < 7:
                        L.p(x, y, "fl4")
        if kind == "cabbage":
            for y in range(130, 178, 9):
                for x in range(a + 4 + ((y // 9) % 2) * 3, b - 6, 7):
                    L.ell(x, y, x + 5, y + 5, "hz1")
                    L.p(x + 1, y + 1, "gC")
                    L.p(x + 2, y + 1, "hz2")
                    L.p(x + 1, y + 2, "hz2")
                    L.hl(x + 1, x + 5, y + 5, "fl5")
                    L.p(x + 4, y + 3, "hz0")
        for y in range(128, 182):
            L.p(b - 1, y, "hz1")
            L.p(b - 2, y, "fl7")
    bund(L, 0, W, 182, 3, "gC", ["hz1", "hz0", "hz0"], "fl5")
    # ---- 近一点的土路 y 186～200（带车辙）
    for y in range(186, 200):
        for x in range(W):
            n = vnoise(x, y, 24, 45)
            col = "fl6" if n > 0.4 else "fl5"
            if y in (189, 196):
                col = "fl4" if vnoise(x, y, 9, 46) > 0.25 else col
            if y in (190, 197):
                col = "fl7" if vnoise(x, y, 9, 47) > 0.55 else col
            L.p(x, y, col)
    for x in range(W):
        for y, s in ((186, 48), (199, 49)):
            if vnoise(x, y, 6, s) > 0.5:
                L.p(x, y, "gr4" if y == 186 else "gB")
    # ---- 水田：倒映天光和云，秧苗一窝窝 y 200～250
    for y in range(200, 250):
        for x in range(W):
            n = vnoise(x * 0.45, y * 2.0, 26, 50)
            col = "wa1"
            if n > 0.66:
                col = "wa2"
            elif n > 0.63 and (x + y) % 2 == 0:
                col = "wa2"
            if y < 203 or (y < 205 and (x + y) % 2 == 0):
                col = "wa0"
            L.p(x, y, col)
    for y in range(206, 248, 6):
        off = ((y - 206) // 6 % 2) * 4
        for x in range(off, W, 8):
            jx = x + rnd.choice([0, 0, 1, -1])
            if rnd.random() < 0.06:
                continue
            L.p(jx, y, "gr4")
            L.p(jx - 1, y + 1, "gr3")
            L.p(jx + 1, y + 1, "gB")
            L.p(jx, y + 1, "gr3")
            L.p(jx, y + 2, "wa0")
            if rnd.random() < 0.4:
                L.p(jx + 1, y - 1, "gr4")
    for xb in (380, 760, 1130):
        for y in range(200, 250):
            xx = xb + int((y - 200) * 0.1)
            L.p(xx, y, "gB")
            L.p(xx + 1, y, "gr3")
            L.p(xx + 2, y, "gA")
    bund(L, 0, W, 250, 4, "gr4", ["gB", "gr3", "gA", "gr2"], "gr1")
    # 水田里几只白鹭
    for (ex, ey, face) in ((300, 226, 1), (318, 238, -1), (1012, 232, 1), (1340, 220, -1)):
        egret(L, ex, ey, face)
    # 田坎、路边一丛丛矮灌木和野草（把一条条横线打断）
    for _ in range(40):
        x = rnd.randrange(0, W)
        y = rnd.choice([112, 127, 184, 199, 252])
        shrub(L, x, y, rnd, hazy=y < 190)
    # ---- 最近一层：熟了的金稻子（不加雾），风吹过一道道亮 y 256～344
    L.rect(0, 255, W, 344, "gd1")   # 02 10/3：从 255 起铺（样板从 256 起，田坎脚 254 到稻子中间空了一行透明，游戏里漏出灰盒的绿线）
    for row, y in enumerate(range(258, 342, 5)):
        x = (row % 2) * 3 - 6
        while x < W + 6:
            jx = x + rnd.randint(-1, 1)
            jy = y + rnd.choice([0, 0, 0, 1])
            n = vnoise(jx * 0.6, jy * 1.8, 80, 54) * 0.75 + vnoise(jx, jy, 20, 55) * 0.25
            k = 1 if n > 0.6 else (-1 if n < 0.32 else 0)
            rice_clump(L, jx, jy, k, rnd)
            x += rnd.randint(5, 7)
        # 每行下面一道暗缝
        for xx in range(W):
            if L.g(xx, y + 3) in (C["gd2"],) and (xx + row) % 3 == 0:
                L.p(xx, y + 3, "gd1")
    for y in (256, 257):
        for x in range(W):
            if L.g(x, y) == C["gd1"]:
                L.p(x, y, "gd2")
    # 稻田中间一道田坎（分两块），坎上几棵豆苗
    bund(L, 0, W, 300, 3, "gB", ["gr3", "gA", "gr2"], "gd0")
    for x in range(0, W, 9):
        if rnd.random() < 0.5:
            L.p(x, 298, "gr4")
            L.p(x + 1, 297, "gr4")
            L.p(x + 1, 298, "gr3")
    # ---- 篱笆后面一窄条草 y 344～406
    paint_grass(L, 0, 344, W, 406, bias=-0.05)
    for x in range(W):
        L.p(x, 344, "gd0" if (x % 2) else "gr2")


def field_bank(L, rnd):
    """北边田埂：顶面 406～442（压实的土路、两边草），朝南的坎面 442～456"""
    for y in range(406, 442):
        for x in range(W):
            n = vnoise(x, y, 28, 60) * 0.7 + vnoise(x, y, 7, 61) * 0.3
            col = "fl5" if n < 0.5 else ("fl6" if n < 0.72 else "fl4")
            if 0.49 < n < 0.51 and (x + y) % 2:
                col = "fl6"
            L.p(x, y, col)
    # 北边贴着篱笆一溜草、南边沿上一溜草（边缘起伏）
    for x in range(W):
        e1 = 406 + int(vnoise(x, 1, 9, 62) * 6)
        for y in range(406, e1):
            L.p(x, y, grass_tone(x, y, -0.05))
        e2 = 442 - int(vnoise(x, 2, 8, 63) * 4)
        for y in range(e2, 442):
            L.p(x, y, grass_tone(x, y, 0.05))
    # 田埂中间被踩出来的两道浅沟（人走的）
    for x in range(W):
        if vnoise(x, 3, 15, 64) > 0.3:
            L.p(x, 421, "fl4")
            L.p(x, 422, "fl6" if vnoise(x, 4, 5, 65) > 0.5 else "fl5")
        if vnoise(x, 5, 13, 66) > 0.35:
            L.p(x, 429, "fl4")
            L.p(x, 430, "fl7" if vnoise(x, 6, 5, 67) > 0.6 else "fl6")
    # 坎面
    for x in range(W):
        for y in range(442, 456):
            j = y - 442
            col = "so3" if j < 4 else ("so2" if j < 10 else "so1")
            if j == 0:
                col = "so4"
            if 3 <= j <= 11 and vnoise(x, y, 4, 68) > 0.72:
                col = shift(col, -1)
            L.p(x, y, col)
        L.p(x, 456, "gr1")
        # 坎沿上垂下来的草
        if vnoise(x, 7, 5, 69) > 0.45:
            ln = 1 + int(vnoise(x, 8, 3, 70) * 4)
            for j in range(ln):
                L.p(x, 442 + j, "gr3" if j < ln - 1 else "gA")
    # 碎土块、小石子
    for _ in range(90):
        x = rnd.randrange(0, W)
        y = rnd.randrange(445, 454)
        L.p(x, y, "so4")
        L.p(x + 1, y + 1, "so1")


def dirt(x, y, seed):
    n = vnoise(x, y, 26, seed) * 0.65 + vnoise(x, y, 7, seed + 1) * 0.35
    if n < 0.36:
        return "fl4"
    if n < 0.38 and (x + y) % 2:
        return "fl4"
    if n > 0.68:
        return "fl6"
    if n > 0.66 and (x + y) % 2:
        return "fl6"
    return "fl5"


def paths(L, rnd):
    """中间南北小路、南边东西土路、往南出口；车辙、脚印、路边草"""
    def edge(v, seed):
        return int(round((vnoise(v, 0, 13, seed) - 0.5) * 5))

    # 南北小路 714～822 × 442～1166
    for y in range(442, 1170):
        a = 716 + edge(y, 80)
        b = 820 + edge(y, 81)
        for x in range(a, b):
            L.p(x, y, dirt(x, y, 82))
    # 南边东西土路 60～1490 × 1102～1150
    for x in range(56, 1496):
        a = 1103 + edge(x, 83)
        b = 1149 + edge(x, 84)
        # 两头圆一点
        if x < 80:
            k = (80 - x) // 3
            a += k
            b -= k
        if x > 1470:
            k = (x - 1470) // 3
            a += k
            b -= k
        for y in range(a, b):
            L.p(x, y, dirt(x, y, 85))
    # 往南出口（回草坪）：一条窄的往下走到画布底
    for y in range(1150, H):
        half = 30 - min(10, (y - 1150) // 10)
        a = 768 - half + edge(y, 86)
        b = 768 + half + edge(y, 87)
        for x in range(a, b):
            L.p(x, y, dirt(x, y, 88))
    # 路沿：西边、北边挨着草的那一两行压暗（草沿比路面高一点，投下一道影）；十字路口不会有缝
    for y in range(457, H):
        for x in range(50, 1500):
            c = L.g(x, y)
            if not is_ramp(c, "fl"):
                continue
            if is_ramp(L.g(x - 1, y), "gr") or is_ramp(L.g(x, y - 1), "gr"):
                L.p(x, y, "fl3")
            elif is_ramp(L.g(x - 2, y), "gr") or is_ramp(L.g(x, y - 2), "gr"):
                L.p(x, y, "fl4")
    # 车辙：南北路两道
    for (cx0, sd) in ((744, 90), (792, 91)):
        for y in range(450, 1166):
            cx = cx0 + int(round((vnoise(0, y, 60, sd) - 0.5) * 4))
            if vnoise(cx, y, 9, sd + 5) < 0.12:
                continue
            L.p(cx - 1, y, "fl3")
            L.p(cx, y, "fl4")
            if vnoise(cx, y, 6, sd + 9) > 0.45:
                L.p(cx + 1, y, "fl4")
            if vnoise(cx, y, 5, sd + 11) > 0.6:
                L.p(cx + 2, y, "fl6")
        # 辙中间的草（只在两道辙之间）
    for y in range(452, 1100, 3):
        if vnoise(768, y, 20, 92) > 0.45:
            x = 768 + rnd.randint(-5, 5)
            for k in range(rnd.randint(1, 3)):
                L.p(x + k * 2, y, "gB")
                L.p(x + k * 2, y + 1, "gr3")
    # 车辙：东西路两道
    for (cy0, sd) in ((1114, 93), (1137, 94)):
        for x in range(70, 1480):
            cy = cy0 + int(round((vnoise(x, 0, 70, sd) - 0.5) * 3))
            if vnoise(x, cy, 9, sd + 5) < 0.12:
                continue
            L.p(x, cy - 1, "fl3")
            if vnoise(x, cy, 6, sd + 9) > 0.4:
                L.p(x, cy, "fl4")
            if vnoise(x, cy, 5, sd + 11) > 0.6:
                L.p(x, cy + 1, "fl6")
    # 脚印：两串（南口进来往北）
    for (sx, sd) in ((760, 95), (778, 96)):
        y = 1260
        side = 0
        while y > 460:
            x = sx + (3 if side else -3) + int((vnoise(0, y, 80, sd) - 0.5) * 10)
            if rnd.random() < 0.75:
                L.p(x, y, "fl3")
                L.p(x + 1, y, "fl3")
                L.p(x, y + 1, "fl4")
                L.p(x + 1, y + 1, "fl4")
                L.p(x, y + 3, "fl4")
                L.p(x + 1, y + 3, "fl3")
            side ^= 1
            y -= rnd.randint(13, 17)
    # 路边的草往路上探一点
    for _ in range(700):
        x = rnd.randrange(56, 1496)
        y = rnd.randrange(442, H)
        c = L.g(x, y)
        if is_ramp(c, "fl"):
            # 离草近才长
            near = any(is_ramp(L.g(x + dx, y + dy), "gr") for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3)))
            if near:
                tuft(L, x, y, rnd, 1)
                for bx in (-1, 0, 1):
                    if is_ramp(L.g(x + bx, y), "fl"):
                        L.p(x + bx, y, "gr3")
    # 路上的小石子
    for _ in range(140):
        x = rnd.randrange(56, 1496)
        y = rnd.randrange(442, H)
        if is_ramp(L.g(x, y), "fl") and is_ramp(L.g(x + 4, y + 2), "fl"):
            L.hl(x, x + 2, y, "fl7")
            L.p(x, y + 1, "fl3")
            L.p(x + 1, y + 1, "fl2")


def strawberry_ground(L, rnd):
    """草莓地：垄沟里的紫色土，中间被踩实的一线浅、撒着稻草；地边一圈草长进来"""
    x0, y0, x1, y1 = 88, 494, 708, 1068
    for y in range(y0 - 4, y1 + 4):
        for x in range(x0 - 4, x1 + 4):
            # 地边起伏
            dx = min(x - x0, x1 - 1 - x)
            dy = min(y - y0, y1 - 1 - y)
            d = min(dx, dy)
            wob = (vnoise(x, y, 9, 100) - 0.5) * 6
            if d + wob < 0:
                continue
            n = vnoise(x, y, 22, 101) * 0.5 + vnoise(x, y, 5, 102) * 0.5
            col = "so3" if n < 0.62 else "so4"
            if 0.6 < n < 0.64 and (x + y) % 2:
                col = "so4" if col == "so3" else "so3"
            if d + wob < 2:
                col = "so2"
            L.p(x, y, col)
    # 垄沟中间踩实的浅一线
    for k in range(len(RIDGE_Y) + 1):
        if k == 0:
            yc = 512
        elif k == len(RIDGE_Y):
            yc = RIDGE_Y[-1] + 28 + 9
        else:
            yc = RIDGE_Y[k - 1] + 28 + (RIDGE_Y[k] - 10 - RIDGE_Y[k - 1] - 28) // 2
        for x in range(96, 704):
            if vnoise(x, yc, 18, 103) > 0.35:
                L.p(x, yc + int((vnoise(x, 0, 40, 104) - 0.5) * 4), "fl2")
    # 稻草：短短一截一截（金）
    for _ in range(1600):
        x = rnd.randrange(x0, x1)
        y = rnd.randrange(y0, y1)
        if not is_ramp(L.g(x, y), "so"):
            continue
        ln = rnd.randint(2, 4)
        dxs = rnd.choice([(1, 0), (1, 0), (1, 1), (1, -1)])
        for j in range(ln):
            L.p(x + dxs[0] * j, y + dxs[1] * j, "gd3" if j == 0 else "gd2")
    # 土坷垃
    for _ in range(700):
        x = rnd.randrange(x0, x1)
        y = rnd.randrange(y0, y1)
        if is_ramp(L.g(x, y), "so") and is_ramp(L.g(x + 1, y + 1), "so"):
            L.p(x, y, "so4")
            L.p(x + 1, y + 1, "so1")
    # 沟里的杂草
    for _ in range(120):
        x = rnd.randrange(x0, x1)
        y = rnd.randrange(y0, y1)
        if is_ramp(L.g(x, y), "so"):
            for bx in (0, 2):
                L.p(x + bx, y, "gr3")
                L.p(x + bx, y - 1, "gB")
            L.p(x + 1, y + 1, "so1")


def worn_trail(L, pts, width, seed):
    """草地上踩出来的小径：中间断断续续露土，两边一圈压浅、压倒的草"""
    hw = width / 2.0
    cells = {}
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)))
        for i in range(n + 1):
            t = i / max(1, n)
            cx = x0 + (x1 - x0) * t
            cy = y0 + (y1 - y0) * t
            for yy in range(int(cy - hw) - 1, int(cy + hw) + 2):
                for xx in range(int(cx - hw) - 1, int(cx + hw) + 2):
                    d = math.hypot(xx + 0.5 - cx, yy + 0.5 - cy) / hw
                    if d <= 1.0 and d < cells.get((xx, yy), 9):
                        cells[(xx, yy)] = d
    for (xx, yy), d in cells.items():
        c = L.g(xx, yy)
        if not is_ramp(c, "gr"):
            continue
        nz = vnoise(xx, yy, 6, seed) * 0.6 + vnoise(xx, yy, 17, seed + 3) * 0.4
        v = nz + 0.55 - d * 0.75
        if v > 0.52:
            L.p(xx, yy, "fl5" if vnoise(xx, yy, 3, seed + 1) > 0.45 else "fl4")
        elif v > 0.46 and (xx + yy) % 2:
            L.p(xx, yy, "fl4")
        elif v > 0.34:
            L.p(xx, yy, "gr4" if c != C["gr4"] else "gC")


def clover(L, rnd, area, n):
    x0, y0, x1, y1 = area
    for _ in range(n):
        cx = rnd.randrange(x0, x1)
        cy = rnd.randrange(y0, y1)
        if not is_ramp(L.g(cx, cy), "gr"):
            continue
        for _ in range(rnd.randint(5, 12)):
            x = cx + rnd.randint(-10, 10)
            y = cy + rnd.randint(-6, 6)
            if not (is_ramp(L.g(x, y), "gr") and is_ramp(L.g(x + 2, y + 2), "gr")):
                continue
            # 三片小圆叶
            L.p(x, y, "gC")
            L.p(x + 1, y, "gr4")
            L.p(x - 1, y + 1, "gr4")
            L.p(x + 2, y + 1, "gr4")
            L.p(x, y + 1, "gB")
            L.p(x + 1, y + 1, "gr3")
            L.p(x, y + 2, "gr3")
            L.p(x + 1, y + 2, "gA")
            if rnd.random() < 0.25:
                L.p(x + 1, y - 2, "wt")
                L.p(x, y - 1, "wt")
                L.p(x + 1, y - 1, "pk")


def loquat_ground(L, rnd):
    """枇杷园：农人踩出来的小径、树下一圈松过的土（树盘）、三叶草"""
    # 一条弯弯的主径：从小路拐进园子，在两排树中间穿过去；只往两棵树岔一下
    pts = []
    for k in range(0, 33):
        x = 818 + k * 20
        y = 826 + 12 * math.sin(k * 0.55 + 0.8) + 5 * math.sin(k * 1.7)
        pts.append((x, y))
    worn_trail(L, pts, 20, 140)
    worn_trail(L, [(1140, 830), (1132, 760), (1144, 690), (1150, 630)], 14, 141)
    clover(L, rnd, (840, 494, 1462, 1068), 26)
    for (fx, fy) in TREES.values():
        L.ell(fx - 30, fy - 12, fx + 31, fy + 13, "so2")
        L.ell(fx - 28, fy - 11, fx + 29, fy + 12, "so3")
        for _ in range(110):
            a = rnd.uniform(0, 6.283)
            r = math.sqrt(rnd.random())
            x = int(fx + math.cos(a) * r * 26)
            y = int(fy + math.sin(a) * r * 10)
            L.p(x, y, rnd.choice(["so4", "so2", "fl2"]))
        # 草沿压回来一点
        for _ in range(40):
            a = rnd.uniform(0, 6.283)
            x = int(fx + math.cos(a) * 30)
            y = int(fy + math.sin(a) * 12)
            tuft(L, x, y, rnd, 1)


def background(rnd_seed=7):
    rnd = random.Random(rnd_seed)
    L = Layer(0, 0, W, H)
    paint_grass(L, 0, 344, W, H)
    # 枇杷园草色压深一点（常年树荫、修剪过）
    paint_grass(L, 836, 490, 1466, 1072, bias=-0.05)
    north_fields(L, rnd)
    field_bank(L, rnd)
    strawberry_ground(L, rnd)
    loquat_ground(L, rnd)
    paths(L, rnd)
    grass_details(L, rnd, (0, 344, W, 406), 0.7, flowers=False)
    grass_details(L, rnd, (0, 456, W, H), 1.0)
    return L


# ================================================================== 草莓垄
def berry(L, x, y, ripe=True):
    """一颗草莓（3×4）：绿萼、红果、左上一点亮、尖朝下"""
    if ripe:
        L.p(x + 1, y, "gr3")
        L.p(x, y + 1, "rd5")
        L.p(x + 1, y + 1, "rd4")
        L.p(x + 2, y + 1, "rd3")
        L.p(x, y + 2, "rd4")
        L.p(x + 1, y + 2, "rd3")
        L.p(x + 2, y + 2, "rd2")
        L.p(x + 1, y + 3, "rd2")
    else:
        L.p(x + 1, y, "gr3")
        L.p(x, y + 1, "wt")
        L.p(x + 1, y + 1, "gC")
        L.p(x, y + 2, "gC")
        L.p(x + 1, y + 2, "gr4")


def straw_plant(L, x, y, rnd, fruit, frnd):
    """一棵草莓（约 15 宽 10 高，脚在 x,y）：几片三出复叶，叶片左上亮、右下暗，外圈深绿描边"""
    P = Layer(x - 10, y - 13, 21, 16)
    # 每片复叶：叶柄端点 + 三片小叶（3×3 的圆角块）
    leaves = []
    n = rnd.randint(3, 4)
    base_angles = [-2.4, -1.57, -0.75, -1.2, -1.95]
    rnd.shuffle(base_angles)
    for i in range(n):
        a = base_angles[i] + rnd.uniform(-0.2, 0.2)
        ln = rnd.uniform(4.5, 6.5)
        leaves.append((x + math.cos(a) * ln * 1.15, y - 1 + math.sin(a) * ln, a))
    # 前面再一片小的（遮住根）
    leaves.append((x + rnd.uniform(-2, 2), y - 2, 1.57))
    leaves.sort(key=lambda t: t[1])
    for (lx, ly, a) in leaves:
        lx, ly = int(round(lx)), int(round(ly))
        # 叶柄
        P.line(x, y - 1, lx, ly, "gr2")
        for (ox, oy) in ((-3, 0), (2, 0), (-1, -2)):
            bx, by = lx + ox, ly + oy - 1
            pts = [(bx + i, by + j) for j in range(3) for i in range(3) if not (i == 2 and j == 0) and not (i == 0 and j == 2)]
            pts += [(bx + 1, by - 1)] if oy < 0 else []
            for (px_, py_) in pts:
                if P.has(px_, py_) and P.g(px_, py_) != C["gr2"]:
                    pass
                lit = (px_ - bx) + (py_ - by) <= 1
                P.p(px_, py_, "gr4" if lit else "gr3")
            # 小叶右下一圈暗（叠着的也分得开）
            P.p(bx + 2, by + 2, "gA")
            P.p(bx + 2, by + 1, "gA")
            P.p(bx + 1, by + 3, "gr2")
            P.p(bx + 3, by + 2, "gr2")
    # 外圈描边
    P.outline("gr0")
    L.paste(P)
    if fruit:
        # 果子挂在叶子外沿、往下垂
        for _ in range(frnd.choice([1, 2, 2, 3])):
            side = frnd.choice([-1, 1])
            bx = x + side * frnd.randint(4, 7) - 1
            by = y - frnd.randint(2, 5)
            berry(L, bx, by, ripe=frnd.random() < 0.85)
            # 果子描一圈深红，压在叶子上也分得开
            for (px_, py_) in ((bx + 3, by + 1), (bx + 3, by + 2), (bx + 2, by + 3), (bx + 1, by + 4), (bx - 1, by + 1), (bx - 1, by + 2), (bx, by + 3)):
                if not L.has(px_, py_) or L.g(px_, py_) not in (C["rd2"], C["rd3"], C["rd4"], C["rd5"]):
                    L.p(px_, py_, "rd1")
        if frnd.random() < 0.35:
            fx, fy = x + frnd.randint(-4, 4), y - frnd.randint(7, 10)
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                L.p(fx + dx, fy + dy, "wt")
            L.p(fx, fy, "gd3")
    else:
        if frnd.random() < 0.08:
            fx, fy = x + frnd.randint(-4, 4), y - frnd.randint(7, 10)
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                L.p(fx + dx, fy + dy, "wt")
            L.p(fx, fy, "gd3")


def draw_ridge(k, fruit):
    y0 = RIDGE_Y[k]
    x0, x1 = 100, 700
    h = 10
    yt0, yt1 = y0 - h, y0 + 28 - h      # 顶面
    yf1 = y0 + 28                        # 着地线
    L = Layer(x0 - 4, yt0 - 14, (x1 - x0) + 8, (yf1 - yt0) + 16)
    rnd = random.Random(500 + k)
    # 垄的形状：两头圆
    def inside_top(x, y):
        r = 7
        if x < x0 + r:
            return (x - (x0 + r)) ** 2 / r ** 2 + ((y - (yt0 + yt1) / 2) / ((yt1 - yt0) / 2)) ** 2 * 0.35 <= 1.0
        if x >= x1 - r:
            return (x - (x1 - r)) ** 2 / r ** 2 + ((y - (yt0 + yt1) / 2) / ((yt1 - yt0) / 2)) ** 2 * 0.35 <= 1.0
        return True
    for y in range(yt0, yf1):
        for x in range(x0, x1):
            if y < yt1:
                if not inside_top(x, y):
                    continue
                n = vnoise(x, y, 14, 510 + k)
                col = "so3" if n < 0.6 else "so4"
                if y == yt0:
                    col = "so4"
                elif y >= yt1 - 2:
                    col = "so2"
                if x < x0 + 3:
                    col = shift(col, 1)
            else:
                if not inside_top(x, y - h):
                    continue
                j = y - yt1
                col = "so2" if j < 3 else ("so1" if j < h - 1 else "so0")
                if j == 0:
                    col = "so3"
                if 2 <= j <= 7 and vnoise(x, y, 4, 520 + k) > 0.7:
                    col = shift(col, -1)
                if x < x0 + 6:
                    col = shift(col, 1)
                if x > x1 - 6:
                    col = shift(col, -1)
            L.p(x, y, col)
    # 顶面盖的稻草
    for _ in range(260):
        x = rnd.randrange(x0 + 4, x1 - 4)
        y = rnd.randrange(yt0 + 1, yt1 - 1)
        ln = rnd.randint(2, 5)
        d = rnd.choice([(1, 0), (1, 0), (1, 1), (1, -1)])
        for j in range(ln):
            L.p(x + d[0] * j, y + d[1] * j, "gd3" if j < 2 else "gd2")
    # 坎面上挂下来几根稻草、小土块
    for _ in range(50):
        x = rnd.randrange(x0 + 4, x1 - 4)
        L.p(x, yt1 + 1, "gd2")
        if rnd.random() < 0.5:
            L.p(x, yt1 + 2, "gd1")
    L.outline("ol", pick=lambda x, y, nb: "ol" if y >= yt1 - 1 or x <= x0 or x >= x1 - 1 else "so1")
    # 草莓：两行错开
    frnd = random.Random(900 + k)
    for row, (fy, off) in enumerate(((yt0 + 10, 7), (yt0 + 22, 15))):
        x = x0 + off
        while x < x1 - 6:
            straw_plant(L, x + rnd.randint(-1, 1), fy + rnd.randint(-1, 1), rnd, fruit, frnd)
            x += 16 + rnd.randint(-2, 2)
    return L


# ================================================================== 枇杷树
LIGHT = (-0.55, -0.62, 0.56)


def norm3(v):
    n = math.sqrt(sum(a * a for a in v))
    return tuple(a / n for a in v)


LIGHT = norm3(LIGHT)


def loquat_leaf(L, cx, cy, ln, ang, wid, tone):
    """一片枇杷叶（长条、尖头）：朝光的半边亮一档，背光边一圈暗，亮叶中间一条叶脉"""
    ca, sa = math.cos(ang), math.sin(ang)
    pts = {}
    r = int(ln / 2) + 2
    for y in range(int(cy) - r, int(cy) + r + 1):
        for x in range(int(cx) - r, int(cx) + r + 1):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = dx * ca + dy * sa
            v = -dx * sa + dy * ca
            if -ln / 2 <= u <= ln / 2:
                t = (u + ln / 2) / ln
                half = wid / 2 * (math.sin(math.pi * min(1.0, t * 1.08)) ** 0.8)
                if abs(v) <= half:
                    pts[(x, y)] = (u, v, half)
    # 光从左上：法线 (-sa, ca) 跟光的方向点乘，判断哪半边朝光
    side = 1 if (-sa * LIGHT[0] + ca * LIGHT[1]) > 0 else -1
    for (x, y), (u, v, half) in pts.items():
        lv = tone
        if v * side > 0.2 * half:
            lv = tone + 1
        if u > ln / 2 - 2 and tone >= 2:
            lv = tone + 1
        L.p(x, y, rname("lf", lv))
    for (x, y), (u, v, half) in pts.items():
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge and v * side < 0:
            L.p(x, y, rname("lf", tone - 1))
    if tone >= 3:
        for t in range(-int(ln / 2) + 2, int(ln / 2) - 2):
            L.p(cx + ca * t, cy + sa * t, rname("lf", tone - 1 if tone < 5 else 3))


def loquat_fruit(L, x, y, shade):
    """一颗枇杷（4×4 去角的圆）：左上亮、右下暗；shade 0 亮处 1 背光"""
    a, b, c = ("gd4", "lq", "or") if shade == 0 else ("lq", "or", "wd3")
    for (i, j, col) in ((1, 0, a), (2, 0, b), (0, 1, a), (1, 1, b), (2, 1, b), (3, 1, c),
                        (0, 2, b), (1, 2, b), (2, 2, c), (3, 2, c), (1, 3, c), (2, 3, c)):
        L.p(x + i, y + j, col)


def loquat_fruit_ol(L, x, y, shade, ol="wd1"):
    """带一圈深边的枇杷：先垫 6×6 去角的深色，再画果，一颗颗分得开"""
    for j in range(-1, 5):
        for i in range(-1, 5):
            if (i in (-1, 4)) and (j in (-1, 4)):
                continue
            if (i, j) in ((-1, 0), (0, -1), (3, -1), (4, 0), (-1, 3), (0, 4), (4, 3), (3, 4)) and False:
                continue
            L.p(x + i, y + j, ol)
    loquat_fruit(L, x, y, shade)


def loquat_bunch(L, cx, cy, n, rnd, shade):
    """一串枇杷：从叶簇中间垂下来，上面一根果柄"""
    spots = [(0, 0), (-4, 2), (4, 2), (-1, 4), (3, 6), (-4, 6), (0, 8)]
    use = spots[:n]
    use.sort(key=lambda s: s[1])
    L.line(cx + 1, cy - 4, cx + 1, cy - 1, "fl2")
    L.p(cx, cy - 3, "gd1")
    for (dx, dy) in use:
        loquat_fruit_ol(L, cx + dx - 1, cy + dy - 1, shade)
        if dy >= 4 and rnd.random() < 0.5:
            L.p(cx + dx + 1, cy + dy + 2, "wd1")


def tree_plan(tid, fx, fy):
    """一棵树的长法（树冠分几大团、每团几簇叶、枝干），有果没果共用"""
    seed = sum(ord(c) for c in tid) * 31 + fx + fy
    rnd = random.Random(seed)
    ccx, ccy = fx + rnd.randint(-2, 2), fy - 146
    RX, RY = 47 + rnd.uniform(-1.5, 1.0), 82 + rnd.uniform(-2, 1)
    ph = [rnd.uniform(0, 6.283) for _ in range(3)]

    def rad(th):
        return 1 + 0.06 * math.sin(3 * th + ph[0]) + 0.05 * math.sin(5 * th + ph[1]) + 0.03 * math.sin(7 * th + ph[2])

    def inside(x, y, shrink=0.0):
        dx, dy = (x - ccx) / RX, (y - ccy) / RY
        th = math.atan2(dy, dx)
        # 下半截收窄一点（伞形）
        if dy > 0:
            dx *= 1 + 0.18 * dy
        return math.sqrt(dx * dx + dy * dy) <= rad(th) - shrink

    # 大团：泊松撒点（团大小 22～30）
    clumps = []
    tries = 0
    while len(clumps) < 12 and tries < 6000:
        tries += 1
        x = ccx + rnd.uniform(-RX, RX)
        y = ccy + rnd.uniform(-RY, RY)
        if not inside(x, y, 0.26) or abs(x - fx) > 34:
            continue
        if all((x - a) ** 2 + (y - b) ** 2 > 28 ** 2 for (a, b, r) in clumps):
            clumps.append((x, y, rnd.uniform(25, 31)))
    # 核心区没盖到的地方补一团（免得树冠缺一块）
    for gy in range(int(ccy - RY), int(ccy + RY), 6):
        for gx in range(int(ccx - RX), int(ccx + RX), 6):
            if inside(gx, gy, 0.32) and all((gx - a) ** 2 + (gy - b) ** 2 > (r * 0.78) ** 2 for (a, b, r) in clumps):
                clumps.append((gx, gy, rnd.uniform(22, 26)))
    plan = []
    for (bx, by, br) in clumps:
        u, v = (bx - ccx) / RX, (by - ccy) / RY
        zg = math.sqrt(max(0.0, 1 - u * u - v * v))
        rosettes = []
        t2 = 0
        while len(rosettes) < 10 and t2 < 800:
            t2 += 1
            a = rnd.uniform(0, 6.283)
            r = math.sqrt(rnd.random()) * (br - 6)
            x, y = bx + math.cos(a) * r, by + math.sin(a) * r * 0.9
            if not inside(x, y, 0.06) or abs(x - fx) > 52:
                continue
            if all((x - p) ** 2 + (y - q) ** 2 > 11 ** 2 for (p, q, *_r) in rosettes):
                lu, lv = (x - bx) / br, (y - by) / br
                lz = math.sqrt(max(0.0, 1 - lu * lu - lv * lv))
                nl = norm3((lu * 0.9 + u * 0.3, lv * 0.9 + v * 0.3, lz * 0.75 + zg * 0.35))
                lum = nl[0] * LIGHT[0] + nl[1] * LIGHT[1] + nl[2] * LIGHT[2]
                lum -= 0.32 * max(0.0, lv) + 0.2 * max(0.0, v)      # 团底、树冠底更暗
                lum += 0.12 * max(0.0, -v)                          # 树冠顶上受光多
                tone = 3 if lum > -0.05 else 2
                seed_r = rnd.randrange(1 << 30)
                rosettes.append((x, y, lz, tone, seed_r))
        rosettes.sort(key=lambda t: (t[2], t[1]))
        plan.append((zg * 0.5 + 0.6 * v, bx, by, br, rosettes))
    plan.sort(key=lambda t: t[0])
    fork_y = fy - rnd.randint(44, 50)
    limbs = []
    nlimb = rnd.choice([3, 4])
    for k in range(nlimb):
        tx = ccx + (k - (nlimb - 1) / 2) * 24 + rnd.uniform(-5, 5)
        ty = ccy + rnd.uniform(15, 45)
        limbs.append((tx, ty))
    return dict(rnd_seed=seed, ccx=ccx, ccy=ccy, RX=RX, RY=RY, inside=inside, plan=plan, fork_y=fork_y, limbs=limbs)


BARK = ["ol", "wd0", "wd1", "fl1", "fl2", "fl3"]


def thick_line(L, x0, y0, x1, y1, w0, w1, light_bias=0.0):
    """一根枝：从粗 w0 到细 w1，横截面左亮右暗（树皮色带）"""
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    pts = {}
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        w = w0 + (w1 - w0) * t
        hw = w / 2.0
        for yy in range(int(y - hw) - 1, int(y + hw) + 2):
            for xx in range(int(x - hw) - 1, int(x + hw) + 2):
                d = math.hypot(xx + 0.5 - x, yy + 0.5 - y)
                if d <= hw:
                    s = (xx + 0.5 - x) / max(hw, 0.5)        # -1 左 … 1 右
                    old = pts.get((xx, yy))
                    if old is None or abs(s) < abs(old):
                        pts[(xx, yy)] = s
    for (x, y), s in pts.items():
        s += light_bias
        idx = 5 if s < -0.55 else (4 if s < -0.1 else (3 if s < 0.45 else 2))
        L.p(x, y, BARK[idx])
    return pts


def canopy_form(canopy, T):
    """树冠的大明暗：每个大团当一个球，取最高的那个当表面，按法线对光算亮暗，
    再沿叶子色带挪档（-2～+1，半档用棋盘格）。叶子的细节留着，大团一簇簇分出来"""
    clumps = [(bx, by, br * 1.08) for (_z, bx, by, br, _r) in T["plan"]]
    ccx, ccy, RX, RY = T["ccx"], T["ccy"], T["RX"], T["RY"]

    def height(x, y):
        best = -1e9
        for (bx, by, r) in clumps:
            d2 = (x - bx) ** 2 + ((y - by) * 1.05) ** 2
            if d2 < r * r:
                hh = math.sqrt(r * r - d2) + 0.18 * (ccy - by)      # 上面的团高一点
                if hh > best:
                    best = hh
        if best < -1e8:
            u, v = (x - ccx) / RX, (y - ccy) / RY
            best = 8 * math.sqrt(max(0.0, 1 - u * u - v * v)) - 4
        return best

    lumap = {}
    for y in range(canopy.oy, canopy.oy + canopy.h):
        for x in range(canopy.ox, canopy.ox + canopy.w):
            c = canopy.g(x, y)
            if not c[3]:
                continue
            h0 = height(x, y)
            gx = height(x + 1.5, y) - height(x - 1.5, y)
            gy = height(x, y + 1.5) - height(x, y - 1.5)
            n = norm3((-gx / 3.0, -gy / 3.0, 1.0))
            lum = n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2]
            v = (y - ccy) / RY
            lum -= 0.22 * max(0.0, v) - 0.08 * max(0.0, -v)
            lumap[(x, y)] = lum
            if lum > 0.78:
                s = 1.0
            elif lum > 0.66:
                s = 0.5
            elif lum > 0.42:
                s = 0.0
            elif lum > 0.3:
                s = -0.5
            elif lum > 0.14:
                s = -1.0
            elif lum > 0.02:
                s = -1.5
            else:
                s = -2.0
            k = math.floor(s)
            if s - k > 0.25 and (x + y) % 2 == 0:
                k += 1
            if k and RAMP_OF.get(c, ("", 0))[0] == "lf":
                canopy.p(x, y, shift(c, k))
    return lumap


def draw_tree(tid, fruit):
    fx, fy = TREES[tid]
    T = tree_plan(tid, fx, fy)
    L = Layer(fx - 65, fy - 252, 130, 253)
    rnd = random.Random(T["rnd_seed"] + 1)
    # ---- 枝干：粗短的主干，齐腰高分三四根，往树冠里伸
    fork_y = T["fork_y"]
    thick_line(L, fx, fy - 1, fx + 1, fork_y, 14, 11)
    for (dx, w) in ((-8, 5), (8, 5), (-3, 4)):
        thick_line(L, fx + dx * 0.3, fy - 7, fx + dx, fy, w, 3)
    for (tx, ty) in T["limbs"]:
        mx = fx + (tx - fx) * 0.45
        my = fork_y - 18
        thick_line(L, fx + (tx - fx) * 0.1, fork_y + 3, mx, my, 8, 6)
        thick_line(L, mx, my, tx, ty, 6, 3)
    # 树皮：竖的裂纹、浅斑
    for _ in range(18):
        x = fx + rnd.randint(-5, 4)
        y = rnd.randint(fork_y, fy - 4)
        for j in range(rnd.randint(3, 8)):
            if L.g(x, y + j) in (C["fl1"], C["fl2"], C["fl3"]):
                L.p(x, y + j, "wd1")
    for _ in range(8):
        x = fx + rnd.randint(-6, 2)
        y = rnd.randint(fork_y, fy - 6)
        if L.g(x, y) in (C["fl1"], C["fl2"]):
            L.p(x, y, "fl3")
            L.p(x + 1, y, "fl3")
    # ---- 树冠
    canopy = Layer(fx - 65, fy - 252, 130, 253)
    frnd = random.Random(T["rnd_seed"] + 2)
    cands = []
    for (_z, bx, by, br, rosettes) in T["plan"]:
        # 团里先垫一层暗色（叶簇之间的缝是深的），团底再深一档
        canopy.ell(bx - br + 5, by - br * 0.85 + 5, bx + br - 5, by + br * 0.9 - 4, "nl1")
        canopy.ell(bx - br + 8, by, bx + br - 6, by + br * 0.9 - 4, "gr0")
        for (x, y, lz, tone, sr) in rosettes:
            r2 = random.Random(sr)
            canopy.ell(x - 5, y - 4, x + 6, y + 5, rname("lf", max(1, tone - 1)))
            nleaf = r2.randint(7, 10)
            angs = [6.283 * i / nleaf + r2.uniform(-0.25, 0.25) for i in range(nleaf)]
            angs.sort(key=lambda a: math.sin(a))     # 朝上的先画、朝下的后画（压在前面）
            for a in angs:
                ln = r2.uniform(10, 14)
                wd = r2.uniform(3.6, 4.6)
                sy = 0.85 if math.sin(a) > 0 else 1.0
                lx = x + math.cos(a) * (ln / 2 + 1)
                ly = y + math.sin(a) * (ln / 2 + 1) * sy
                dt = math.cos(a - math.atan2(LIGHT[1], LIGHT[0]))
                t = tone + (1 if dt > 0.6 else (-1 if dt < -0.65 else 0))
                loquat_leaf(canopy, lx, ly, ln * (0.9 if sy < 1 else 1), a, wd, max(1, min(5, t)))
            if tone >= 2 and lz > 0.25:
                cands.append((frnd.random(), x, y + 3, tone, frnd.randrange(1 << 30)))
    form = canopy_form(canopy, T)
    canopy.outline("gr0")
    # 树冠左上一圈受光边：最外一行叶子亮一档
    for y in range(canopy.oy, canopy.oy + canopy.h):
        for x in range(canopy.ox, canopy.ox + canopy.w):
            c = canopy.g(x, y)
            if c[3] and c != C["gr0"] and (not canopy.has(x - 2, y - 2) or canopy.g(x - 2, y - 2) == C["gr0"]):
                if (x - T["ccx"]) * LIGHT[0] + (y - T["ccy"]) * LIGHT[1] > 25:
                    canopy.p(x, y, shift(c, 1) if RAMP_OF.get(c, ("", 0))[0] == "lf" else c)
    L.paste(canopy)
    # 树冠底沿在树干上投一道影
    for x in range(fx - 12, fx + 13):
        for y in range(fy - 252, fy):
            if canopy.has(x, y) and not canopy.has(x, y + 1):
                for j in range(1, 5):
                    c = L.g(x, y + j)
                    if c[3] and c in (C["fl1"], C["fl2"], C["fl3"]):
                        L.p(x, y + j, "wd1" if j < 4 else "fl1")
                break
    L.outline("ol", pick=lambda x, y, nb: None if canopy.has(x, y) else ("gr0" if RAMP_OF.get(nb, ("", 0))[0] in ("lf", "gr") else "ol"))
    if fruit:
        cands.sort()
        pick = []
        for c in cands:
            if all((c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2 > 20 ** 2 for p in pick):
                pick.append(c)
            if len(pick) >= 13:
                break
        pick.sort(key=lambda b: b[2])
        for (_r, x, y, tone, sr) in pick:
            r3 = random.Random(sr)
            lum = form.get((int(x), int(y)), 0.5)
            loquat_bunch(L, int(x), int(y), r3.randint(3, 6), r3, 0 if lum > 0.42 else 1)
    return L


# ================================================================== 竹篱笆
def bamboo_v(L, x, y0, y1, w=3, tone=0, rnd=None):
    """一根竖竹：左亮右暗、外圈描边，十几像素一个竹节"""
    cols = [rname("bb", 3 + tone), rname("bb", 2 + tone), rname("bb", 1 + tone)]
    if w == 4:
        cols = [rname("bb", 3 + tone), rname("bb", 2 + tone), rname("bb", 2 + tone), rname("bb", 1 + tone)]
    for y in range(y0, y1):
        for i, c in enumerate(cols):
            L.p(x + i, y, c)
    node = y0 + (rnd.randint(5, 12) if rnd else 8)
    while node < y1 - 3:
        for i in range(w):
            L.p(x + i, node, rname("bb", 0 + tone) if i else rname("bb", 1 + tone))
            L.p(x + i, node + 1, rname("bb", 3 + tone) if i < w - 1 else rname("bb", 2 + tone))
        node += rnd.randint(13, 17) if rnd else 15
    # 顶上斜切口
    L.p(x + w - 1, y0, "bb0")
    L.p(x, y0 - 1, cols[0])


def bamboo_h(L, x0, x1, y):
    for x in range(x0, x1):
        L.p(x, y, "bb3")
        L.p(x, y + 1, "bb2")
        L.p(x, y + 2, "bb1")
    nx = x0 + 20
    while nx < x1:
        L.p(nx, y, "bb1")
        L.p(nx, y + 1, "bb0")
        L.p(nx, y + 2, "bb0")
        L.p(nx + 1, y, "bb3")
        nx += 31


def red_lantern(L, cx, top):
    """小红灯笼（14 宽 19 高 + 穗）：金顶金底、竖棱、中间透亮"""
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


def red_bow(L, cx, cy):
    """红布扎的一朵花结 + 两条飘带"""
    L.ell(cx - 7, cy - 3, cx, cy + 4, "rd3")
    L.ell(cx + 1, cy - 3, cx + 8, cy + 4, "rd3")
    L.ell(cx - 6, cy - 2, cx - 2, cy + 1, "rd4")
    L.ell(cx + 2, cy - 2, cx + 6, cy + 1, "rd4")
    L.p(cx - 5, cy - 2, "rd5")
    L.rect(cx - 1, cy - 2, cx + 2, cy + 3, "rd2")
    L.p(cx, cy - 1, "gd3")
    for j in range(9):
        L.p(cx - 2 - j // 3, cy + 3 + j, "rd3" if j % 3 else "rd4")
        L.p(cx + 2 + j // 4, cy + 3 + j, "rd2" if j % 3 else "rd3")


def draw_fence(i):
    x0 = 96 * (i - 1)
    rnd = random.Random(300 + i)
    L = Layer(x0 - 12, 330, 120, 82)
    # 竖竹（照灰盒每 12 一根，3 宽）
    for k in range(8):
        sx = x0 + 6 + 12 * k
        top = 351 + rnd.randint(-1, 3)
        tone = -1 if rnd.random() < 0.15 else 0
        bamboo_v(L, sx, top, 404, 3, tone, rnd)
    # 段头一根粗竹桩
    bamboo_v(L, x0, 346, 406, 4, 0, rnd)
    for j in (347, 348):
        L.hl(x0, x0 + 4, j, "bb3")
    L.outline("ol")
    # 两道横竹在前面
    H1 = Layer(x0 - 12, 330, 120, 82)
    bamboo_h(H1, x0, x0 + 96, 364)
    bamboo_h(H1, x0, x0 + 96, 386)
    H1.outline("ol", pick=lambda x, y, nb: "ol" if y < 364 or 366 < y < 386 or y > 388 else None)
    L.paste(H1)
    # 绑绳（交叉处一个小叉）
    for k in range(8):
        sx = x0 + 6 + 12 * k
        for ry in (364, 386):
            L.p(sx, ry - 1, "fl3")
            L.p(sx + 2, ry + 3, "fl3")
            L.p(sx + 1, ry + 1, "fl5")
            L.p(sx + 2, ry - 1, "fl2")
            L.p(sx, ry + 3, "fl2")
    # 有几段爬着牵牛花
    if i in (2, 5, 6, 12, 15):
        vr = random.Random(700 + i)
        y = 362
        for x in range(x0 + 2, x0 + 94):
            y += vr.choice([-1, 0, 0, 1])
            y = max(352, min(392, y))
            L.p(x, y, "gr2")
            if vr.random() < 0.22:
                lx, ly = x, y + vr.choice([-3, 1])
                L.p(lx, ly, "gB")
                L.p(lx + 1, ly, "gr3")
                L.p(lx, ly + 1, "gr3")
                L.p(lx + 1, ly + 1, "gA")
                L.p(lx - 1, ly, "gr2")
                L.p(lx + 2, ly + 1, "gr1")
            if vr.random() < 0.07:
                col = vr.choice(["pk", "bl3", "pk"])
                fx_, fy_ = x, y - 2
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (0, 0)):
                    L.p(fx_ + dx, fy_ + dy, col)
                L.p(fx_, fy_, "wt")
                L.p(fx_ + 1, fy_ + 1, "rd2" if col == "pk" else "bl2")
    # 小路北头那根桩上：红布花结 + 一盏小红灯笼
    if i == 9:
        red_bow(L, x0 + 2, 352)
        red_lantern(L, x0 + 2, 372 - 4)
    return L


# ================================================================== 稻草人
def draw_scarecrow():
    L = Layer(366, 436, 68, 98)
    # 竖杆
    for y in range(452, 531):
        L.p(398, y, "wd4")
        L.p(399, y, "wd3")
        L.p(400, y, "wd3")
        L.p(401, y, "wd2")
    for y in range(458, 530, 9):
        L.p(399, y, "wd2")
    # 横杆
    for x in range(375, 426):
        L.p(x, 474, "wd4")
        L.p(x, 475, "wd3")
        L.p(x, 476, "wd3")
        L.p(x, 477, "wd2")
    # 衣服（旧蓝布褂子）
    L.poly([(388, 470), (412, 470), (416, 500), (384, 500)], "bl2")
    # 两只袖子顺着横杆
    L.rect(379, 471, 389, 481, "bl2")
    L.rect(411, 471, 421, 481, "bl2")
    for x in range(379, 421):
        L.p(x, 471, "bl3")
    L.rect(386, 471, 394, 500, "bl3")
    for y in range(472, 500):
        L.p(410 + (y - 470) // 8, y, "bl1")
    L.hl(381, 389, 480, "bl1")
    L.hl(411, 421, 480, "bl1")
    # 衣襟、扣子
    L.vl(400, 472, 500, "bl1")
    for y in (477, 484, 491):
        L.p(401, y, "wt")
    # 补丁
    L.rect(404, 486, 410, 492, "fl6")
    L.hl(404, 410, 486, "fl7")
    L.p(405, 489, "fl3")
    L.p(408, 489, "fl3")
    L.rect(388, 492, 393, 497, "rd3")
    L.p(389, 493, "rd4")
    # 衣领
    L.p(397, 470, "bl4")
    L.p(403, 470, "bl4")
    # 袖口、下摆露出的稻草
    for (x, y, d) in ((378, 472, -1), (378, 475, -1), (378, 478, -1), (421, 472, 1), (421, 475, 1), (421, 478, 1)):
        for j in range(3):
            L.p(x + d * j, y + (j if y > 476 else -j // 2), "gd3" if j < 2 else "gd4")
    for x in range(385, 416, 2):
        ln = 2 + (x * 7) % 4
        for j in range(ln):
            L.p(x + (1 if j == ln - 1 and x % 4 == 1 else 0), 500 + j, "gd3" if j < ln - 1 else "gd2")
    # 头：麻布包（扎口）
    L.ell(392, 456, 409, 472, "fl5")
    L.ell(393, 457, 403, 466, "fl6")
    L.p(395, 459, "fl7")
    L.ell(398, 461, 409, 472, "fl4", only=lambda x, y: x + y > 868)
    L.p(397, 464, "ol")
    L.p(403, 464, "ol")
    for x in range(397, 404):
        L.p(x, 468 + (1 if x in (399, 400, 401) else 0), "fl2" if x % 2 else "fl3")
    L.hl(396, 405, 471, "fl2")
    L.p(395, 472, "gd3")
    L.p(405, 472, "gd3")
    # 斗笠（尖顶草帽）+ 一道红布
    L.poly([(383, 461), (417, 461), (408, 453), (403, 446), (397, 446), (392, 453)], "gd3")
    L.poly([(397, 447), (403, 447), (406, 452), (394, 452)], "gd4")
    L.poly([(403, 447), (408, 453), (417, 461), (406, 461), (404, 452)], "gd2")
    L.hl(383, 418, 461, "gd1")
    L.hl(384, 417, 460, "gd2")
    for x in range(386, 416, 3):
        L.p(x, 457 + (0 if x < 400 else 0), "gd1")
    L.hl(391, 410, 455, "rd3")
    L.hl(392, 409, 456, "rd2")
    L.p(393, 455, "rd4")
    # 胳膊上系的红布条（飘）
    for j in range(8):
        L.p(415 + j // 2, 477 + j, "rd3" if j % 3 else "rd4")
        L.p(416 + j // 2, 477 + j, "rd2")
    # 另一只胳膊挂一个亮晶晶的铁皮盖（吓鸟）
    L.vl(383, 478, 484, "ik3")
    L.ell(380, 484, 387, 491, "bl4")
    L.p(382, 486, "wt")
    L.ell(383, 486, 387, 491, "bl3", only=lambda x, y: x + y > 870)
    L.outline("ol")
    # 杆脚埋进土里的一小堆土
    L.hl(394, 406, 530, "so2")
    L.hl(395, 405, 529, "so3")
    L.p(396, 528, "so4")
    return L


# ================================================================== 筐、篮
def basket(rect, kind):
    x0, yb0, x1, yb1 = rect
    foot = yb1
    L = Layer(x0 - 2, foot - 27, 28, 29)
    cx = x0 + 12
    # 筐身：上宽下窄
    for y in range(foot - 15, foot):
        t = (y - (foot - 15)) / 15.0
        half = 11.5 - 2.5 * t
        for x in range(int(cx - half), int(cx + half) + 1):
            s = (x - (cx - half)) / (2 * half)
            row = (y - foot) % 3
            col = "bb2"
            if row == 0:
                col = "bb1"
            if (x + (y // 3)) % 4 == 0:
                col = "bb3" if row else "bb2"
            if s > 0.7:
                col = shift(col, -1)
            if s < 0.2:
                col = shift(col, 1)
            L.p(x, y, col)
    L.hl(cx - 9, cx + 10, foot - 1, "bb0")
    # 筐口一圈（椭圆）
    L.ell(x0, foot - 20, x0 + 24, foot - 11, "bb3")
    L.ell(x0 + 2, foot - 19, x0 + 22, foot - 12, "bb1")
    # 里面的果子堆
    frnd = random.Random(x0 * 3 + foot)
    if kind == "strawberry":
        L.ell(x0 + 2, foot - 22, x0 + 22, foot - 12, "rd2")
        spots = [(x, y) for y in range(foot - 22, foot - 13, 3) for x in range(x0 + 3, x0 + 21, 3)]
        for (x, y) in spots:
            dx = (x + 1 - cx) / 10.0
            dy = (y + 2 - (foot - 17)) / 5.0
            if dx * dx + dy * dy <= 1.0:
                xx = x + ((y // 3) % 2)
                L.p(xx, y, "rd4")
                L.p(xx + 1, y, "rd3")
                L.p(xx, y + 1, "rd3")
                L.p(xx + 1, y + 1, "rd2")
                if frnd.random() < 0.5:
                    L.p(xx, y, "rd5")
                if frnd.random() < 0.4:
                    L.p(xx + 1, y - 1, "gr3")
    else:
        L.ell(x0 + 2, foot - 22, x0 + 22, foot - 12, "or")
        for (x, y) in ((x0 + 3, foot - 17), (x0 + 7, foot - 19), (x0 + 11, foot - 20), (x0 + 15, foot - 19), (x0 + 18, foot - 17),
                       (x0 + 5, foot - 15), (x0 + 9, foot - 16), (x0 + 13, foot - 16), (x0 + 17, foot - 15)):
            loquat_fruit(L, x, y, 0)
        # 两片枇杷叶
        loquat_leaf(L, x0 + 6, foot - 21, 9, -0.5, 3.4, 3)
        # 篮子提手（竹弓）
        for x in range(x0 + 2, x0 + 23):
            t = (x - (x0 + 12)) / 10.5
            y = int(round(foot - 15 - 11 * math.sqrt(max(0.0, 1 - t * t))))
            L.p(x, y, "bb2" if x < x0 + 12 else "bb1")
            L.p(x, y + 1, "bb1" if x < x0 + 12 else "bb0")
    L.outline("ol")
    return L


# ================================================================== 收购处摊子
def draw_stall():
    X0, X1, YB, YF = STALL
    h = 43
    L = Layer(X0 - 14, 896, (X1 - X0) + 28, YF - 896 + 2)
    rnd = random.Random(1201)
    # 后面两根木柱（撑篷子）
    for px_ in (X0 + 3, X1 - 7):
        for y in range(930, YB - h + 2):
            L.p(px_, y, "wd4")
            L.p(px_ + 1, y, "wd3")
            L.p(px_ + 2, y, "wd3")
            L.p(px_ + 3, y, "wd2")
    # 篷子：红、米白相间的布，往前斜，前沿一排波浪边
    top, front = 922, 946
    for y in range(top, front):
        t = (y - top) / (front - top)
        xa = X0 - 6 + int(round(-2 * t))
        xb = X1 + 6 + int(round(2 * t))
        for x in range(xa, xb):
            stripe = ((x - X0 + 6) // 12) % 2
            col = "rd3" if stripe == 0 else "fl7"
            if y < top + 2:
                col = "rd4" if stripe == 0 else "wt"
            if t > 0.7:
                col = shift(col, -1)
            # 布面一道道褶（每条中间略亮）
            if (x - X0 + 6) % 12 in (1, 2) and t < 0.7:
                col = shift(col, 1)
            L.p(x, y, col)
    for x in range(X0 - 8, X1 + 8):
        stripe = ((x - X0 + 6) // 12) % 2
        k = (x - X0 + 6) % 12
        depth = 6 - abs(k - 5.5) * 0.9
        for j in range(int(depth) + 1):
            col = "rd3" if stripe == 0 else "fl6"
            if j == int(depth):
                col = "rd1" if stripe == 0 else "fl3"
            L.p(x, front + j, col)
        L.p(x, front, "gd3")
    L.hl(X0 - 6, X1 + 6, top, "rd2")
    # 篷顶空招牌（不写字）：木框、红底、金边
    bx0, bx1, by0, by1 = 948, 1012, 902, 920
    L.vl(958, by1, top, "wd2")
    L.vl(1002, by1, top, "wd2")
    L.rect(bx0, by0, bx1, by1, "wd2")
    L.hl(bx0, bx1, by0, "wd4")
    L.rect(bx0 + 2, by0 + 2, bx1 - 2, by1 - 2, "rd3")
    L.hl(bx0 + 2, bx1 - 2, by0 + 2, "rd4")
    L.rect(bx0 + 3, by0 + 3, bx1 - 3, by1 - 3, "rd3")
    for x in range(bx0 + 3, bx1 - 3):
        L.p(x, by0 + 3, "gd3")
        L.p(x, by1 - 4, "gd2")
    for y in range(by0 + 3, by1 - 3):
        L.p(bx0 + 3, y, "gd3")
        L.p(bx1 - 4, y, "gd2")
    # 篷子两角各挂一盏小红灯笼
    # （画在柜台之后，免得被盖）
    # ---- 柜台
    ty0, ty1 = YB - h, YF - h        # 顶面 1013～1045
    fy0, fy1 = YF - h, YF            # 正面 1045～1088
    for y in range(ty0, ty1):
        for x in range(X0, X1):
            col = "wd4" if ((y - ty0) // 6) % 2 == 0 else "wd5"
            if (y - ty0) % 6 == 5:
                col = "wd3"
            L.p(x, y, col)
    L.hl(X0, X1, ty0, "wd5")
    # 正面竖木板
    for x in range(X0, X1):
        k = (x - X0) % 10
        for y in range(fy0, fy1):
            col = "wd3"
            if k == 0:
                col = "wd1"
            elif k == 1:
                col = "wd4"
            elif k >= 8:
                col = "wd2"
            L.p(x, y, col)
    L.rect(X0, fy0, X1, fy0 + 4, "wd4")
    L.hl(X0, X1, fy0, "wd5")
    L.hl(X0, X1, fy0 + 4, "wd1")
    L.rect(X0, fy1 - 5, X1, fy1, "wd2")
    L.hl(X0, X1, fy1 - 5, "wd3")
    # 正面中间搭一块红布（金边、中间一朵金团花）
    cx0, cx1 = 944, 1016
    for y in range(fy0 + 1, fy0 + 30):
        for x in range(cx0, cx1):
            col = "rd3"
            if x in (cx0, cx1 - 1):
                col = "rd2"
            if y == fy0 + 1:
                col = "rd4"
            L.p(x, y, col)
    for x in range(cx0, cx1):
        L.p(x, fy0 + 26, "gd3")
        L.p(x, fy0 + 27, "gd2")
        if x % 3 == 0:
            L.p(x, fy0 + 30, "gd3")
            L.p(x, fy0 + 31, "gd2")
        L.p(x, fy0 + 28, "rd3")
        L.p(x, fy0 + 29, "rd2")
    mx, my = 980, fy0 + 13
    for (dx, dy) in ((0, -5), (0, 5), (-6, 0), (6, 0), (-4, -3), (4, -3), (-4, 3), (4, 3)):
        L.p(mx + dx, my + dy, "gd3")
    L.ell(mx - 3, my - 3, mx + 4, my + 4, "gd3")
    L.ell(mx - 1, my - 1, mx + 2, my + 2, "rd3")
    L.p(mx, my, "gd4")
    # 柜台上：台秤（左）、两只竹匾的果子、算盘（右）、一只青花茶缸
    # 台秤
    L.rect(908, 1022, 932, 1036, "ik2")
    L.hl(908, 932, 1022, "ik3")
    L.ell(912, 1024, 922, 1034, "wt")
    L.ell(913, 1025, 921, 1033, "bl4", only=lambda x, y: x + y > 1945)
    L.line(917, 1029, 919, 1026, "rd3")
    for (dx, dy) in ((0, -4), (4, 0), (-4, 0), (3, -3), (-3, -3)):
        L.p(917 + dx, 1029 + dy, "ik3")
    L.ell(906, 1014, 934, 1022, "bl4")
    L.ell(908, 1015, 932, 1021, "wt")
    L.ell(914, 1016, 930, 1021, "bl4", only=lambda x, y: x > 922)
    # 秤盘里几颗枇杷
    loquat_fruit(L, 914, 1015, 0)
    loquat_fruit(L, 918, 1016, 0)
    # 竹匾 × 2
    for (bx, kind) in ((942, "s"), (976, "l")):
        L.ell(bx, 1017, bx + 30, 1031, "bb1")
        L.ell(bx + 1, 1017, bx + 29, 1030, "bb3")
        L.ell(bx + 3, 1018, bx + 27, 1029, "bb2")
        if kind == "s":
            for y in range(1019, 1028, 3):
                for x in range(bx + 6 + (y % 2) * 2, bx + 24, 3):
                    if ((x - bx - 15) / 11.0) ** 2 + ((y - 1023) / 4.5) ** 2 <= 1:
                        L.p(x, y, "rd4")
                        L.p(x + 1, y, "rd3")
                        L.p(x, y + 1, "rd3")
                        L.p(x + 1, y + 1, "rd2")
                        L.p(x, y - 1, "gr3")
        else:
            for (x, y) in ((bx + 5, 1020), (bx + 9, 1019), (bx + 13, 1020), (bx + 17, 1019), (bx + 21, 1020),
                           (bx + 7, 1023), (bx + 11, 1023), (bx + 15, 1023), (bx + 19, 1023)):
                loquat_fruit(L, x, y, 0)
    # 算盘
    ax0, ax1, ay0, ay1 = 1014, 1048, 1018, 1034
    L.rect(ax0, ay0, ax1, ay1, "wd1")
    L.rect(ax0 + 2, ay0 + 2, ax1 - 2, ay1 - 2, "wd0")
    L.hl(ax0 + 2, ax1 - 2, ay0 + 6, "wd2")
    for x in range(ax0 + 4, ax1 - 3, 4):
        L.vl(x, ay0 + 2, ay1 - 2, "ik3")
        L.p(x, ay0 + 4, "rd3")
        L.p(x - 1, ay0 + 4, "rd4")
        for yy in (ay0 + 9, ay0 + 11, ay0 + 13) if x % 8 else (ay0 + 8, ay0 + 12):
            L.p(x, yy, "rd3")
            L.p(x - 1, yy, "rd4")
    L.hl(ax0, ax1, ay0, "wd3")
    # 茶缸
    L.rect(1050, 1020, 1057, 1030, "wt")
    L.hl(1050, 1057, 1024, "bl2")
    L.hl(1050, 1057, 1026, "bl3")
    L.vl(1056, 1021, 1030, "bl4")
    L.hl(1050, 1057, 1020, "bl4")
    L.p(1058, 1023, "wt")
    L.p(1058, 1026, "wt")
    L.outline("ol")
    # 灯笼（篷子两角）
    red_lantern(L, X0 - 4, 952)
    red_lantern(L, X1 + 4, 952)
    return L


# ================================================================== 板车
def draw_cart():
    X0, YB, X1, YF = CART
    L = Layer(X0 - 4, 1004, 136, 90)
    rnd = random.Random(1301)
    ty0, ty1 = 1022, 1050          # 车板顶面
    # 车把（往东伸到 1260，把手深色）
    for (yy, tone) in ((1025, 0), (1046, -1)):
        for x in range(X0 - 2, 1261):
            L.p(x, yy, rname("wd", 4 + tone))
            L.p(x, yy + 1, rname("wd", 3 + tone))
            L.p(x, yy + 2, rname("wd", 2 + tone))
        for x in range(1248, 1261):
            L.p(x, yy, "wd1")
            L.p(x, yy + 1, "wd0")
            L.p(x, yy + 2, "wd0")
    # 两根车把之间的横撑
    for y in range(1027, 1047):
        L.p(1238, y, "wd3")
        L.p(1239, y, "wd2")
    # 车板：横铺木板
    for y in range(ty0, ty1):
        for x in range(X0, X1):
            k = (y - ty0) % 7
            col = "wd4" if k else "wd2"
            if k == 1:
                col = "wd5"
            L.p(x, y, col)
    # 板头接缝
    for y in range(ty0, ty1):
        if (y - ty0) // 7 % 2:
            L.p(X0 + 40, y, "wd2")
        else:
            L.p(X0 + 66, y, "wd2")
    # 车板前沿厚度
    L.rect(X0, ty1, X1, ty1 + 4, "wd2")
    L.hl(X0, X1, ty1, "wd3")
    L.hl(X0, X1, ty1 + 3, "wd1")
    # 后挡板（北边一溜矮栏）
    for x in range(X0, X1):
        L.p(x, ty0 - 4, "wd4")
        L.p(x, ty0 - 3, "wd3")
        L.p(x, ty0 - 2, "wd3")
        L.p(x, ty0 - 1, "wd1")
    for x in range(X0, X1 + 1, 16):
        L.rect(x, ty0 - 7, x + 3, ty0, "wd3")
        L.vl(x, ty0 - 7, ty0, "wd4")
    # 西头支腿
    for x in (X0 + 2, X0 + 3):
        for y in range(ty1 + 4, YF):
            L.p(x, y, "wd3" if x == X0 + 2 else "wd2")
    L.hl(X0, X0 + 7, YF - 1, "wd2")
    # 车上的货：两筐枇杷叠着（西）、一筐草莓（中）、红布包袱（照灰盒那块红在 1150～1176）
    for (bx, by, kind) in ((1138, 1046, "l"), (1182, 1048, "s")):
        Bk = basket([bx, by - 10, bx + 24, by], "loquat" if kind == "l" else "strawberry")
        L.paste(Bk)
    # 红布包袱
    L.ell(1149, 1010, 1178, 1030, "rd3")
    L.ell(1151, 1011, 1166, 1022, "rd4")
    L.p(1155, 1014, "rd5")
    L.ell(1162, 1016, 1178, 1030, "rd2", only=lambda x, y: x + y > 2185)
    L.vl(1163, 1011, 1030, "gd3")
    L.hl(1150, 1178, 1020, "gd3")
    L.p(1163, 1020, "gd4")
    L.p(1164, 1009, "rd3")
    L.p(1162, 1008, "rd4")
    L.p(1166, 1008, "rd2")
    # 车把上挂一顶草帽
    L.ell(1210, 1030, 1234, 1043, "gd2")
    L.ell(1212, 1030, 1232, 1041, "gd3")
    L.ell(1216, 1031, 1228, 1038, "gd4")
    L.hl(1216, 1229, 1038, "rd3")
    L.outline("ol")
    # 车轮（前面那只，压在车板前沿下）
    wx, wy, r = 1180, 1066, 14
    Wl = Layer(wx - r - 2, wy - r - 2, 2 * r + 5, 2 * r + 5)
    for y in range(wy - r, wy + r + 1):
        for x in range(wx - r, wx + r + 1):
            d = math.hypot(x + 0.5 - wx - 0.5, y + 0.5 - wy - 0.5)
            if d <= r:
                if d > r - 3:
                    ang = math.atan2(y - wy, x - wx)
                    col = "ik3" if -2.6 < ang < -1.0 else "ik2"
                    if d > r - 1:
                        col = "ik2"
                elif d > r - 4:
                    col = "bl4" if x + y < wx + wy else "bl3"
                else:
                    col = None
                if col:
                    Wl.p(x, y, col)
    for k in range(8):
        a = k * math.pi / 4 + 0.2
        Wl.line(wx, wy, wx + math.cos(a) * (r - 4), wy + math.sin(a) * (r - 4), "ik3" if k % 2 else "bl3")
    Wl.ell(wx - 3, wy - 3, wx + 4, wy + 4, "ik2")
    Wl.p(wx - 1, wy - 1, "bl4")
    Wl.outline("ol")
    L.paste(Wl)
    return L


# ================================================================== 地上的影子（画进背景）
def ground_shadows(bg):
    S = ShadeMap()
    # 方案 C：影子跟着各件挪过去的位置（往右下拖的方向不变，光还是从左上来）
    dr = dx_of(400)
    # 草莓垄：着地一行压暗 2 档，往右下拖 5 像素
    for y0 in RIDGE_Y:
        S.rect(102 + dr, y0 + 28, 706 + dr, y0 + 30, -1.5)
        S.rect(106 + dr, y0 + 30, 708 + dr, y0 + 34, -1.0)
        S.rect(110 + dr, y0 + 34, 708 + dr, y0 + 35, -0.5)
    # 篱笆：田埂顶上一溜竹影（斜的条纹）
    S.rect(0, 406, W, 410, -1.0)
    for i in range(16):
        for k in range(8):
            sx = 96 * i + 6 + 12 * k
            for j in range(0, 10):
                y = 410 + j
                for dx in range(3):
                    S.add(sx + dx + j, y, -1.0 if j < 7 else -0.5)
    # 枇杷树：树冠的影落在右下一大团，团里漏几块光斑
    for tid, (fx0, fy) in TREES.items():
        sd = fx0 + fy          # 影子的样子照原来的位置定（跟着树挪，不变样）
        fx = mx(fx0)
        S.blob(fx + 18, fy + 2, 66, 26, -1.0, sd)
        S.ellipse(fx + 6, fy, 22, 8, -1.0)
        S.ellipse(fx + 2, fy, 10, 4, -0.5)
        rnd = random.Random(sd)
        for _ in range(7):
            a = rnd.uniform(0, 6.283)
            r = rnd.uniform(0.3, 0.85)
            S.ellipse(fx + 18 + math.cos(a) * 60 * r, fy + 2 + math.sin(a) * 22 * r, rnd.uniform(3, 6), rnd.uniform(1.5, 3), 1.0, edge=1)
    # 收购处：柜台着地压暗、篷子的影落在前面路上
    ds = dx_of(980)
    S.rect(901 + ds, 1088, 1062 + ds, 1090, -1.0)
    S.ellipse(988 + ds, 1093, 86, 6, -1.0)
    # 板车：车底下一片暗（看得见的就是车板和轮子中间那条）、往右下拖一点
    dc = dx_of(1196)
    S.rect(1136 + dc, 1054, 1228 + dc, 1080, -1.0)
    S.ellipse(1186 + dc, 1081, 54, 5, -1.0)
    S.ellipse(1182 + dc, 1081, 15, 3, -1.0)
    S.ellipse(1250 + dc, 1050, 12, 3, -1.0)
    # 筐
    for rc in BASKETS.values():
        S.ellipse(rc[0] + dx_of(basket_fx(rc)) + 14, rc[3], 14, 3.5, -1.5)
    # 稻草人（跟草莓地一起挪）
    S.ellipse(404 + dr, 531, 8, 3, -1.5)
    for j in range(16):
        S.add(402 + dr + j, 531 + j // 4, -1.0)
        S.add(403 + dr + j, 531 + j // 4, -1.0)
    S.ellipse(422 + dr, 535, 14, 4, -1.0)
    S.apply(bg)


def ground_extras(bg):
    """影子之后再撒：树下落叶"""
    rnd = random.Random(4242)
    for (fx0, fy) in TREES.values():
        fx = mx(fx0)   # 方案 C：树挪过去了，落叶跟着
        for _ in range(26):
            x = int(fx + rnd.gauss(12, 30))
            y = int(fy + rnd.gauss(2, 11))
            c = bg.g(x, y)
            if c[3] and (is_ramp(c, "gr") or is_ramp(c, "so")):
                fallen_leaf(bg, x, y, rnd)


# ================================================================== 组装、出图
def flip_ground(bg):
    """方案 C：北边田埂往南（y ≥ SPLIT_Y）的地面整片左右翻，上面的田野、小房子、篱笆不动"""
    top = bg.im.crop((0, 0, W, SPLIT_Y))
    bg.im = bg.im.transpose(Image.FLIP_LEFT_RIGHT)
    bg.im.paste(top, (0, 0))
    bg.px = bg.im.load()


def build():
    bg = background()
    if MIRROR:
        flip_ground(bg)
    ground_shadows(bg)
    ground_extras(bg)
    items = []      # (name, layer, foot_y, foot_x)
    for k in range(8):
        for fr in (True, False):
            items.append(("ridge_%d_%s" % (k, "fruit" if fr else "nofruit"), draw_ridge(k, fr), RIDGE_Y[k] + 28, 400, fr))
    for tid, (fx, fy) in TREES.items():
        for fr in (True, False):
            items.append(("%s_%s" % (tid, "fruit" if fr else "nofruit"), draw_tree(tid, fr), fy, fx, fr))
    for i in range(1, 17):
        items.append(("fence_%02d" % i, draw_fence(i), 404, 96 * i - 48, None))
    items.append(("scarecrow", draw_scarecrow(), 530, 400, None))
    for bid, rc in BASKETS.items():
        items.append((bid, basket(rc, "strawberry" if "strawberry" in bid else "loquat"), rc[3], (rc[0] + rc[2]) // 2, None))
    items.append(("shop_stall", draw_stall(), 1088, 980, None))
    items.append(("cart", draw_cart(), 1090, 1196, None))
    if MIRROR:   # 方案 C：立着的照原样画、不翻，各按参照点 fx 挪到 W − fx（篱笆在北边，不动）
        moved = []
        for (name, L, foot, fx, fr) in items:
            if not name.startswith("fence_"):
                d = dx_of(fx)
                L.ox += d
                fx += d
            moved.append((name, L, foot, fx, fr))
        items = moved
    return bg, items


def compose(bg, items, fruit=True, people=()):
    out = bg.im.copy()
    seq = []
    for (name, L, foot, fx, fr) in items:
        if fr is None or fr == fruit:
            seq.append((foot, fx, 0, L))
    for (im, x, y) in people:
        seq.append((y, x, 1, (im, x, y)))
    seq.sort(key=lambda t: (t[0], t[2], t[1]))
    for (foot, fx, kind, L) in seq:
        if kind == 0:
            out.alpha_composite(L.im, (L.ox, L.oy)) if L.ox >= 0 and L.oy >= 0 else paste_clip(out, L.im, L.ox, L.oy)
        else:
            im, x, y = L
            paste_clip(out, im, x - 32, y - 84)
    return out


def paste_clip(out, im, x, y):
    tmp = Image.new("RGBA", out.size, (0, 0, 0, 0))
    tmp.paste(im, (x, y))
    out.alpha_composite(tmp)


def guest(n, frame=0):
    im = Image.open(CHAR_DIR + "chr_LM-GUEST-%02d.png" % n).convert("RGBA")
    return im.crop((frame * 64, 0, frame * 64 + 64, 84))


def palette_check(im, name):
    cols = im.getcolors(1 << 20)
    used = set()
    for cnt, c in cols:
        if c[3] not in (0, 255):
            raise SystemExit("%s 有半透明像素 %s" % (name, c))
        if c[3] == 255:
            if c not in PAL_SET:
                raise SystemExit("%s 有调色板外的颜色 %s" % (name, c))
            used.add(c)
    return used


# 每张图进游戏时藏掉哪几件灰盒（挡人的占地照旧）、哪块地（有果没果按地块换）
def hide_of(name):
    if name.startswith("ridge_") or name.startswith("loquat_"):
        return [name.rsplit("_", 1)[0]]
    if name == "scarecrow":
        return ["scarecrow_post", "scarecrow_arms", "scarecrow_shirt", "scarecrow_hat"]
    return [name]


def art_box_of(items):
    """每件画出来的外框（画布坐标 x0, y0, x1, y1；有果没果两张取并）→ {layout 里的 id: 框}"""
    out = {}
    for (name, L, foot, fx, fr) in items:
        bb = L.im.getbbox()
        box = [max(L.ox + bb[0], 0), max(L.oy + bb[1], 0), min(L.ox + bb[2], W), min(L.oy + bb[3], H)]
        key = hide_of(name)[0]
        if key in out:
            o = out[key]
            box = [min(o[0], box[0]), min(o[1], box[1]), max(o[2], box[2]), max(o[3], box[3])]
        out[key] = box
    return out


def check_art_box(items):
    d = json.load(open(LAYOUT, encoding="utf-8"))
    it = {i["id"]: i for i in d["items"] if "id" in i}
    bad = ["%s：画出来 %s，layout art_box %s" % (k, v, it.get(k, {}).get("art_box"))
           for k, v in art_box_of(items).items() if it.get(k, {}).get("art_box") != v]
    if bad:
        raise SystemExit("画出来的外框跟 layout.json 的 art_box 对不上（改了画法就把 art_box 改成画出来的）：\n" + "\n".join(bad))


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    check_layout()
    bg, items = build()
    if "--print-art-box" in sys.argv:
        print(json.dumps(art_box_of(items)))
        return
    check_art_box(items)
    used = palette_check(bg.im, "背景")
    for (name, L, foot, fx, fr) in items:
        used |= palette_check(L.im, name)
    print("调色板：定义 %d 色，实际用到 %d 色" % (len(PAL_SET), len(used)))
    if len(used) > 64:
        raise SystemExit("这块画布超过 64 色（%d）" % len(used))
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    bg.im.save(os.path.join(OUT, "room.png"))
    man = {"note": "tools/pixel_art/orchard.py 生成，别手改。背景左上角放在 background.x/y（画布坐标），1 倍、不插值；"
                   "每件左上角在 x/y，着地线 foot（跟人排前后用）；hide 是要藏掉的灰盒（挡人的占地照旧）；"
                   "plot + fruit：这块地熟了显示 fruit=true 那张，没熟显示 fruit=false 那张（orchard.gd）",
           "background": {"png": RES + "room.png", "x": 0, "y": 0}, "props": []}
    names = set()
    # 着地线一样的照 x 排（跟样板 compose 一个顺序）；游戏里同一条着地线按加进去的先后画
    for (name, L, foot, fx, fr) in sorted(items, key=lambda t: (t[2], t[3])):
        bb = L.im.getbbox()
        bb = (max(bb[0], -L.ox), max(bb[1], -L.oy), min(bb[2], W - L.ox), min(bb[3], H - L.oy))   # 不出画布
        L.im.crop(bb).save(os.path.join(OUT, "props", name + ".png"))
        names.add(name + ".png")
        p = {"id": "px_" + name, "png": RES + "props/%s.png" % name, "x": L.ox + bb[0], "y": L.oy + bb[1], "foot": foot,
             "hide": hide_of(name)}
        if fr is not None:
            p["plot"] = hide_of(name)[0]
            p["fruit"] = fr
        man["props"].append(p)
    for f in os.listdir(os.path.join(OUT, "props")):   # 改名、删掉的别留旧图
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(OUT, "props", f))
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print("背景 %s，立着的 %d 张 → %s" % (bg.im.size, len(items), OUT))
    if preview:
        os.makedirs(preview, exist_ok=True)
        compose(bg, items, True).save(os.path.join(preview, "orchard_full.png"))
        compose(bg, items, False).save(os.path.join(preview, "orchard_full_nofruit.png"))
        px0, py0 = 498, 300
        people = [(guest(3), 640, 728), (guest(9), 786, 900)]
        compose(bg, items, True, people).crop((px0, py0, px0 + 540, py0 + 960)).save(os.path.join(preview, "orchard_phone.png"))


if __name__ == "__main__":
    main()
