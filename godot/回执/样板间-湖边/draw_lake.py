#!/usr/bin/env python3
"""罗曼山庄湖边 · 上面的东西（lakeobj01）：用代码画像素，叠在 GPT 画的湖边底图上。
标准见 docs/罗曼山庄画风.md 第 0 节；户外画法、色带照 godot/tools/pixel_art/orchard.py（果园，已进游戏）接着用。

分工（阿鱼 10/3）：底图（远景、湖水、岸、草地、土路、南边灌木）GPT 画；这份画上面每一件东西，一件一张透明图。
GPT 底图没到之前，这份另外垫一张简单的临时底图 bg_lake_temp.png（照分区图），游戏先能用。

1 倍颗粒（1 个美术像素 = 1 个画布像素）、硬边（透明只有 0 和 255）、这块画布 ≤64 色（同名颜色全游戏一个值）、
光从左上来、深褐描边、按着地线分层、图上不写字。位置只从 layout.json 取，开头 check_layout() 核对，摆法一改就停。

用法：
  python3 draw_lake.py                 出全部（layers/、整块、手机、放大、对照）
  python3 draw_lake.py round3          另存 round3.png 和脚本存档 draw_lake_r3.py
  python3 draw_lake.py --base 某.png   GPT 底图到了：压到这套调色板、叠上影子和倒影 → layers/bg_lake.png，整块预览改用它
坐标全用游戏画布坐标（1536×1280）。斜俯视、没有透视：左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素。
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
REPO = "/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件"
GODOT = os.path.join(REPO, "godot")
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_lake", "layout.json")
CHAR_DIR = os.path.join(GODOT, "assets", "characters", "lm")
ORCHARD_FULL = os.path.join(GODOT, "回执", "样板间-果园", "orchard01_full.png")
BANQUET = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55", "base.png")
LAYER_DIR = os.path.join(HERE, "layers")
W, H = 1536, 1280

# ------------------------------------------------------------------ 调色板（64 色）
# 木、地板木、红、金、白、蓝、墨、草、枇杷叶、竹、水、远景雾色照果园原值；
# 银三档 sv、粉 pk0/pk2 照休息间、化妆间原值；新加的只有湖水深处三档 lk0～lk2
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
    "sv0": "#737a8f", "sv1": "#a3abbe", "sv2": "#d3d8e3",
    "gr0": "#1b3022", "gr1": "#284a2c", "gr2": "#3f6935", "gA": "#527d3a", "gr3": "#649340",
    "gB": "#7fa84a", "gr4": "#9cbd5e", "gC": "#c5d888",
    "nl1": "#234536", "nl2": "#31593c", "nl3": "#477a45",
    "bb0": "#50491f", "bb1": "#807636", "bb2": "#ad9f50", "bb3": "#d6c782",
    "wa0": "#5d8c95", "wa1": "#8fbcc0", "wa2": "#c3e0dc",
    "lk0": "#22495f", "lk1": "#2d6079", "lk2": "#3d7890",
    "hz0": "#7e9b78", "hz1": "#a0b693", "hz2": "#c3d1ad",
    "or": "#dd7a2c", "pk0": "#a8455e", "pk": "#de8399", "pk2": "#f4bfc8",
}


def hex2rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


C = {k: hex2rgba(v) for k, v in PAL_HEX.items()}
NAME_OF = {v: k for k, v in C.items()}
# 色带（暗 → 亮）。同一个颜色在几条色带里时，后写的说了算
RAMPS = {
    "lf": ["gr0", "nl1", "nl2", "nl3", "gr3", "gB"],       # 荷叶（偏蓝的深绿，跟果园枇杷叶同一条）
    "wd": ["wd0", "wd1", "wd2", "wd3", "wd4", "wd5"],
    "fl": ["fl0", "fl1", "fl2", "fl3", "fl4", "fl5", "fl6", "fl7"],
    "rd": ["rd0", "rd1", "rd2", "rd3", "rd4", "rd5"],
    "gd": ["gd0", "gd1", "gd2", "gd3", "gd4"],
    "bl": ["bl1", "bl2", "bl3", "bl4", "wt"],
    "sv": ["ik2", "ik3", "sv0", "sv1", "sv2", "wt"],      # 青瓦、石头、白东西的暗面
    "pk": ["pk0", "pk", "pk2"],
    "bb": ["bb0", "bb1", "bb2", "bb3"],
    "hz": ["hz0", "hz1", "hz2"],
    "lk": ["lk0", "lk1", "lk2", "wa0", "wa1", "wa2"],      # 湖水：深 → 浅（果园 wa0～wa2 接在后面）
    "gr": ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"],
}
RAMP_OF = {}
for _rn, _names in RAMPS.items():
    for _i, _n in enumerate(_names):
        RAMP_OF[C[_n]] = (_rn, _i)
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

    def shade_rect(self, x0, y0, x1, y1, k, checker_edge=False):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                if checker_edge and (y in (int(y0), int(y1) - 1) or x in (int(x0), int(x1) - 1)) and (x + y) % 2:
                    continue
                self.shade_px(x, y, k)

    def outline(self, col="ol", pick=None):
        """不透明区外面一圈 1 像素描边；pick(x, y, 邻居颜色) 可以按邻居换描边色（None = 不描）"""
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
    """整块画布的明暗图（影子、倒影）：每个像素一个数（负 = 暗、正 = 亮），取整到半档，半档用棋盘格。
    叠到底图上就是沿色带挪档，不出半透明；GPT 底图到了照样叠"""

    def __init__(self):
        self.v = array("f", [0.0]) * (W * H)

    def add(self, x, y, val):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H:
            self.v[y * W + x] += val

    def rect(self, x0, y0, x1, y1, val, edge=False):
        for y in range(max(0, int(y0)), min(H, int(y1))):
            for x in range(max(0, int(x0)), min(W, int(x1))):
                f = 0.5 if edge and (x in (int(x0), int(x1) - 1) or y in (int(y0), int(y1) - 1)) else 1.0
                self.v[y * W + x] += val * f

    def ellipse(self, cx, cy, rx, ry, val, edge=1.5):
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

    def blob(self, cx, cy, rx, ry, val, seed, wob=0.2, edge=1.5):
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

    def k_at(self, x, y):
        s = self.v[y * W + x]
        if -0.2 < s < 0.2:
            return 0
        s = round(s * 2) / 2.0
        k = math.floor(s)
        if s - k > 0.25 and (x + y) % 2 == 0:
            k += 1
        return int(k)

    def apply(self, layer):
        for y in range(H):
            for x in range(W):
                k = self.k_at(x, y)
                if k:
                    layer.shade_px(x, y, k)

    def mask_image(self):
        """存成一张灰度图：128 = 不动，每挪 1 档 ±40（-2 档 = 48，+1 档 = 168）"""
        im = Image.new("L", (W, H), 128)
        px = im.load()
        for y in range(H):
            for x in range(W):
                k = self.k_at(x, y)
                if k:
                    px[x, y] = max(0, min(255, 128 + 40 * k))
        return im


# ------------------------------------------------------------------ 布局核对（快照是 10/3 的 layout.json）
SNAPSHOT = json.loads(r'''{"size":[1536,1280],"items":{"pavilion_roof":{"type":"poly","pts":[[768,300],[944,400],[944,418],[592,418],[592,400]],"foot":438},"pavilion_roof_edge":{"type":"poly","pts":[[592,414],[944,414],[944,430],[592,430]],"foot":439},"post_nw":{"type":"box","rect":[636,440,646,450],"h":92,"top":"#a0714a"},"post_ne":{"type":"box","rect":[890,440,900,450],"h":92,"top":"#a0714a"},"post_sw":{"type":"box","rect":[636,636,646,646],"h":92,"top":"#a0714a"},"post_se":{"type":"box","rect":[890,636,900,646],"h":92,"top":"#a0714a"},"bench_seat":{"type":"beam","top":950,"thick":8,"x0":364,"x1":436,"foot":972},"bench_leg_w":{"type":"box","rect":[370,962,380,970],"h":14,"top":"#6d4a38"},"bench_leg_e":{"type":"box","rect":[420,962,430,970],"h":14,"top":"#6d4a38"},"bench_back":{"type":"beam","top":972,"thick":6,"x0":364,"x1":436,"foot":988},"bench_block":{"type":"poly","pts":[[364,946],[436,946],[436,972],[364,972]],"foot":946},"bench2_seat":{"type":"beam","top":950,"thick":8,"x0":1114,"x1":1186,"foot":972},"bench2_leg_w":{"type":"box","rect":[1120,962,1130,970],"h":14,"top":"#6d4a38"},"bench2_leg_e":{"type":"box","rect":[1170,962,1180,970],"h":14,"top":"#6d4a38"},"bench2_back":{"type":"beam","top":972,"thick":6,"x0":1114,"x1":1186,"foot":988},"bench2_block":{"type":"poly","pts":[[1114,946],[1186,946],[1186,972],[1114,972]],"foot":946},"dock_deck":{"type":"poly","pts":[[318,560],[462,560],[462,786],[318,786]],"foot":560},"dock_plank_0":{"type":"beam","top":600,"thick":2,"x0":318,"x1":462,"foot":561},"dock_plank_1":{"type":"beam","top":640,"thick":2,"x0":318,"x1":462,"foot":561},"dock_plank_2":{"type":"beam","top":680,"thick":2,"x0":318,"x1":462,"foot":561},"dock_plank_3":{"type":"beam","top":720,"thick":2,"x0":318,"x1":462,"foot":561},"dock_plank_4":{"type":"beam","top":760,"thick":2,"x0":318,"x1":462,"foot":561},"dock_edge":{"type":"poly","pts":[[318,786],[462,786],[462,798],[318,798]],"foot":560},"dock_post_0":{"type":"box","rect":[318,552,326,560],"h":16,"top":"#8c5f3c"},"dock_post_1":{"type":"box","rect":[454,552,462,560],"h":16,"top":"#8c5f3c"},"rowboat_1":{"type":"box","rect":[166,582,310,612],"h":14,"top":"#c19a68","deco":[{"rect":[206,568,212,598],"color":"#8c5f3c"},{"rect":[264,568,270,598],"color":"#8c5f3c"}]},"rowboat_2":{"type":"box","rect":[166,526,310,556],"h":14,"top":"#c19a68","deco":[{"rect":[206,512,212,542],"color":"#8c5f3c"},{"rect":[264,512,270,542],"color":"#8c5f3c"}]},"swanboat_1":{"type":"box","rect":[470,572,590,612],"h":24,"top":"#f4f1ea","deco":[{"rect":[476,540,488,572],"color":"#fbf7ee"},{"rect":[472,540,488,548],"color":"#fbf7ee"},{"rect":[472,544,476,547],"color":"#e8742a"},{"rect":[510,554,580,560],"color":"#4A6FA5"}]},"swanboat_2":{"type":"box","rect":[470,516,590,556],"h":24,"top":"#f4f1ea","deco":[{"rect":[476,484,488,516],"color":"#fbf7ee"},{"rect":[472,484,488,492],"color":"#fbf7ee"},{"rect":[472,488,476,491],"color":"#e8742a"},{"rect":[510,498,580,504],"color":"#4A6FA5"}]},"rowboat_3":{"type":"box","rect":[1080,440,1224,470],"h":14,"top":"#c19a68","deco":[{"rect":[1120,426,1126,456],"color":"#8c5f3c"},{"rect":[1178,426,1184,456],"color":"#8c5f3c"}]},"fish_stool_1":{"type":"box","rect":[1160,814,1180,822],"h":19,"top":"#6d4a38"},"fish_rod_1":{"type":"poly","pts":[[1176,790],[1179,788],[1276,676],[1274,678]],"foot":823},"fish_bucket_1":{"type":"cyl","x":1146,"y":822,"h":12,"rx":7,"ry":4,"top":"#4A6FA5"},"fish_stool_2":{"type":"box","rect":[1430,814,1450,822],"h":19,"top":"#6d4a38"},"fish_rod_2":{"type":"poly","pts":[[1434,790],[1431,788],[1334,676],[1336,678]],"foot":823},"fish_bucket_2":{"type":"cyl","x":1464,"y":822,"h":12,"rx":7,"ry":4,"top":"#4A6FA5"},"lotus_1":{"type":"cyl","x":100,"y":730,"h":2,"rx":36,"ry":12,"top":"#5c8a4a"},"lotus_flower_1":{"type":"puffs","y":743,"e":[[88,722,5,4],[114,726,4,3]]},"lotus_2":{"type":"cyl","x":880,"y":740,"h":2,"rx":36,"ry":12,"top":"#5c8a4a"},"lotus_flower_2":{"type":"puffs","y":753,"e":[[868,732,5,4],[894,736,4,3]]},"lotus_3":{"type":"cyl","x":1190,"y":728,"h":2,"rx":36,"ry":12,"top":"#5c8a4a"},"lotus_flower_3":{"type":"puffs","y":741,"e":[[1178,720,5,4],[1204,724,4,3]]},"reed_1":{"type":"poly","pts":[[116,800],[122,734],[126,760],[130,728],[134,760],[139,736],[144,800]],"foot":800},"reed_2":{"type":"poly","pts":[[676,800],[682,734],[686,760],[690,728],[694,760],[699,736],[704,800]],"foot":800},"reed_3":{"type":"poly","pts":[[916,800],[922,734],[926,760],[930,728],[934,760],[939,736],[944,800]],"foot":800},"duck_1":{"type":"box","rect":[980,412,1004,420],"h":10,"top":"#f4f1ea","deco":[{"rect":[977,400,985,408],"color":"#f4f1ea"},{"rect":[973,403,977,405],"color":"#e8742a"}]},"duck_2":{"type":"box","rect":[1010,424,1034,432],"h":10,"top":"#f4f1ea","deco":[{"rect":[1007,412,1015,420],"color":"#f4f1ea"},{"rect":[1003,415,1007,417],"color":"#e8742a"}]},"willow_0":{"type":"tree","x":230,"y":882,"h":264,"w":150},"willow_1":{"type":"tree","x":540,"y":892,"h":264,"w":150},"willow_2":{"type":"tree","x":1044,"y":872,"h":264,"w":150},"willow_3":{"type":"tree","x":1306,"y":908,"h":264,"w":150},"willow_4":{"type":"tree","x":880,"y":1300,"h":264,"w":150},"willow_5":{"type":"tree","x":600,"y":1300,"h":264,"w":150}},"npcs":{"music_1":[696,482],"music_2":[744,482],"music_3":[792,482],"music_4":[840,482],"boatman_1":[390,640],"boatman_2":[1152,472],"fisher_1":[1170,824],"fisher_2":[1440,824]},"points":{"pavilion":[768,596,60],"bench":[400,976,50],"to_entrance":[1500,956,50]},"walk":[[[80,796],[1520,796],[1520,1156],[80,1156]],[[720,556],[816,556],[816,816],[720,816]],[[624,428],[912,428],[912,652],[624,652]]],"flats":[[618,422,918,658],[624,428,912,652],[714,552,822,818],[720,556,816,816],[740,804,796,956],[0,312,1536,776],[0,770,1536,804],[80,940,1536,1004]]}''')
GEOM_KEYS = ["type", "rect", "pts", "x", "y", "h", "w", "rx", "ry", "top", "thick", "x0", "x1", "foot", "deco", "e"]


def check_layout():
    d = json.load(open(LAYOUT, encoding="utf-8"))
    bad = []
    if d["size"] != SNAPSHOT["size"]:
        bad.append("画布大小 %s" % d["size"])
    items = {i["id"]: i for i in d["items"] if "id" in i}
    for iid, g in SNAPSHOT["items"].items():
        it = items.get(iid)
        if it is None:
            bad.append("%s 不见了" % iid)
            continue
        cur = {k: it[k] for k in GEOM_KEYS if k in it}
        if cur != g:
            bad.append("%s 变了：%s → %s" % (iid, json.dumps(g, ensure_ascii=False), json.dumps(cur, ensure_ascii=False)))
    for iid in items:
        if iid not in SNAPSHOT["items"]:
            bad.append("多了一件 %s（这版没画）" % iid)
    npcs = {n["id"]: [n["x"], n["y"]] for n in d.get("npcs", [])}
    if npcs != SNAPSHOT["npcs"]:
        bad.append("人的站位变了：%s" % npcs)
    pts = {p["id"]: [p["x"], p["y"], p["r"]] for p in d.get("points", [])}
    if pts != SNAPSHOT["points"]:
        bad.append("交互点变了：%s" % pts)
    if d.get("walk") != SNAPSHOT["walk"]:
        bad.append("能走的地方 walk 变了")
    rects = [f["rect"] for f in d["flat"] if f.get("type") == "rect"]
    for r in SNAPSHOT["flats"]:
        if r not in rects:
            bad.append("平铺 %s 不见了（亭子台面、栈道、小路、湖、岸、土路是照它画的）" % r)
    if bad:
        raise SystemExit("layout.json 跟这版画的位置对不上（摆法改了，先停）：\n" + "\n".join(bad))


def item(iid):
    return SNAPSHOT["items"][iid]


# ================================================================== 小零件（印章）
def red_lantern(L, cx, top):
    """小红灯笼（15 宽 19 高 + 穗，照果园那盏）：金顶金底、竖棱、中间透亮"""
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


def red_bow(L, cx, cy, tails=9):
    """红绸扎的一朵花结 + 两条飘带（照果园那朵）"""
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


def mini_bow(L, cx, cy):
    """小号红绸结（桩头、船头用）：5 宽，两条短飘带"""
    L.p(cx - 2, cy, "rd4")
    L.p(cx - 1, cy - 1, "rd4")
    L.p(cx - 1, cy, "rd3")
    L.p(cx, cy, "rd2")
    L.p(cx + 1, cy - 1, "rd3")
    L.p(cx + 1, cy, "rd3")
    L.p(cx + 2, cy, "rd2")
    L.p(cx - 1, cy + 1, "rd3")
    L.p(cx - 1, cy + 2, "rd2")
    L.p(cx + 1, cy + 1, "rd2")
    L.p(cx + 2, cy + 2, "rd2")


def rope_line(L, x0, y0, x1, y1, sag, cols=("fl6", "fl4")):
    """一根往下垂的绳子（1 像素，下沿一行暗）"""
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 1.4) + 2
    last = None
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t + sag * math.sin(math.pi * t)
        ip = (int(round(x)), int(round(y)))
        if ip != last:
            L.p(ip[0], ip[1], cols[0])
            last = ip
    return L


def plank_floor(L, x0, x1, y0, y1, pitch, seed, joint_len=96, base="fl4"):
    """横铺木板：每块 pitch 高，上沿一行亮、下沿一行缝；接缝错开、接缝两边一对钉子、木纹"""
    for y in range(y0, y1):
        row = (y - y0) // pitch
        k = (y - y0) % pitch
        r = h2(row, 0, seed)
        tone = 0 if r < 0.55 else (-1 if r < 0.8 else 1)
        off = int(h2(row, 2, seed) * joint_len)
        for x in range(x0, x1):
            seg = (x - x0 + off) // joint_len
            jt = tone + (1 if h2(row, seg + 7, seed) > 0.85 else 0) - (1 if h2(row, seg + 9, seed) > 0.88 else 0)
            if k == pitch - 1:
                col = "fl1"
            elif k == 0:
                col = shift(base, 1 + jt)
            elif k == pitch - 2:
                col = shift(base, -1 + jt)
            else:
                col = shift(base, jt)
            jx = (x - x0 + off) % joint_len
            if jx == 0:
                col = "fl1"
            elif jx in (2, joint_len - 3) and k == pitch // 2:
                col = "fl1"
            L.p(x, y, col)
    rnd = random.Random(seed)
    for _ in range((x1 - x0) * (y1 - y0) // 150):
        x = rnd.randrange(x0, x1)
        y = rnd.randrange(y0, y1)
        k = (y - y0) % pitch
        if 1 <= k <= pitch - 3:
            for i in range(rnd.randint(4, 14)):
                c = L.g(x + i, y)
                if c[3] and is_ramp(c, "fl") and c != C["fl1"]:
                    L.p(x + i, y, shift(c, -1))


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


def bez(P0, P1, P2, t):
    a = (1 - t) * (1 - t)
    b = 2 * t * (1 - t)
    c = t * t
    return (a * P0[0] + b * P1[0] + c * P2[0], a * P0[1] + b * P1[1] + c * P2[1])


# ================================================================== 亭子（LK-P01）
# 台面 x 624～912、y 428～652（平铺照 layout）；北边一半盖瓦顶（乐手坐在顶下），南边一半是敞开的月台。
# 瓦顶只能画在北边：盖满 6 米的话，里面的乐手和站着的人全被顶挡住（游戏不会把顶变透明）。
# 顶下面那排柱子（前檐柱）是加的两根；layout 的四根柱子：北边两根撑顶（被前檐柱挡住），南边两根画成挂灯笼的灯柱
PAV_X0, PAV_X1, PAV_Y0, PAV_Y1 = 624, 912, 428, 652
EAVE_C = 414          # 正中瓦当一行（檐口）在 y 414
RIDGE_L, RIDGE_R = 680, 856
RIDGE_TOP, RIDGE_BOT = 304, 316
ROOF_L, ROOF_R = 592, 944
FRONT_POSTS = ((636, 646), (890, 900))   # 前檐柱（加的），脚在 y 516


def eave_y(x):
    dx = abs(x - 768)
    if dx <= 100:
        return EAVE_C
    t = min(1.0, (dx - 100) / 76.0)
    return int(round(EAVE_C - 18 * t * t))


def hip_y_table(side):
    """戗脊（斜脊）：从正脊头弯到檐角的曲线；返回 {x: y}（x 在正脊头和檐角之间）和曲线上的点"""
    if side < 0:
        P0, P1, P2 = (RIDGE_L, RIDGE_BOT), (642, 390), (ROOF_L, eave_y(ROOF_L))
    else:
        P0, P1, P2 = (RIDGE_R, RIDGE_BOT), (894, 390), (ROOF_R, eave_y(ROOF_R))
    tab = {}
    pts = []
    for i in range(1201):
        x, y = bez(P0, P1, P2, i / 1200.0)
        pts.append((x, y))
        xi = int(round(x))
        if xi not in tab or y < tab[xi]:
            tab[xi] = y
    return tab, pts


def roof_back_top(x):
    """顶的上沿（正脊下沿 / 两边斜面的后檐线）"""
    if RIDGE_L <= x <= RIDGE_R:
        return RIDGE_BOT
    if x < RIDGE_L:
        return RIDGE_BOT + (RIDGE_L - x) * 24.0 / (RIDGE_L - ROOF_L)
    return RIDGE_BOT + (x - RIDGE_R) * 24.0 / (ROOF_R - RIDGE_R)


def red_post(L, x0, x1, ytop, ybot, base=True):
    """红漆圆柱：左亮右暗；上头一道金箍；脚下石柱础"""
    w = x1 - x0
    for i in range(w):
        f = i / max(1, w - 1)
        col = "rd4" if i == 0 else ("rd3" if f < 0.45 else ("rd2" if f < 0.8 else "rd1"))
        for y in range(ytop, ybot):
            L.p(x0 + i, y, col)
    for i in range(w):
        L.p(x0 + i, ytop + 3, "gd3" if i < w * 0.5 else "gd2")
        L.p(x0 + i, ytop + 4, "gd2" if i < w * 0.5 else "gd1")
    if base:
        bx0, bx1 = x0 - 2, x1 + 2
        for y in range(ybot, ybot + 7):
            for x in range(bx0 + (1 if y == ybot else 0), bx1 - (1 if y == ybot else 0)):
                f = (x - bx0) / (bx1 - bx0)
                if y == ybot:
                    col = "sv2"
                elif y >= ybot + 5:
                    col = "ik3" if f < 0.7 else "ik2"
                else:
                    col = "sv1" if f < 0.3 else ("sv0" if f < 0.75 else "ik3")
                L.p(x, y, col)


def draw_pavilion_deck():
    """亭子台面（平的，比所有立着的都先画）：木地板、一圈边梁、南边台沿正面和桩、乐手坐的红毯、顶的影子"""
    L = Layer(612, 418, 312, 266)
    L.rect(619, 423, 917, 653, "wd3")
    L.hl(619, 917, 423, "wd4")
    L.vl(619, 423, 653, "wd4")
    L.vl(916, 423, 653, "wd2")
    L.hl(619, 917, 652, "wd4")
    plank_floor(L, PAV_X0, PAV_X1, PAV_Y0, PAV_Y1, 6, 51)
    # 南边台沿的正面（台子的厚度），栈道那段不画
    for x in range(619, 917):
        if 720 <= x < 816:
            continue
        for y in range(653, 661):
            L.p(x, y, "wd2" if y < 657 else "wd1")
        if (x - 619) % 24 == 23:
            for y in range(653, 661):
                L.p(x, y, "wd1")
        L.p(x, 661, "wd0")
    # 桩：台沿下面露一截进水
    for px in (626, 672, 858, 904):
        for y in range(662, 672):
            L.p(px, y, "wd3")
            L.p(px + 1, y, "wd2")
            L.p(px + 2, y, "wd2")
            L.p(px + 3, y, "wd1")
    # 乐手坐的红毯：一圈深红边、金色回纹边、里面红底压一层菱形格，两头金流苏
    rx0, rx1, ry0, ry1 = 676, 860, 458, 504
    for y in range(ry0, ry1):
        for x in range(rx0, rx1):
            e = min(x - rx0, rx1 - 1 - x, y - ry0, ry1 - 1 - y)
            if e == 0:
                col = "rd1"
            elif e in (1, 5):
                col = "rd2"
            elif 2 <= e <= 4:
                # 回纹：金底上一格格深红的钩
                k = ((x - rx0) if (y - ry0 < 5 or ry1 - 1 - y < 5) else (y - ry0)) % 6
                j = e - 2
                col = "gd2"
                if (k == 0 and j < 2) or (k in (0, 1, 2) and j == 2 and k != 2) or (k == 3 and j > 0):
                    col = "rd2"
            else:
                col = "rd3"
                dx, dy = x - rx0 - 6, y - ry0 - 6
                if (dx + dy) % 10 == 0 or (dx - dy) % 10 == 0:
                    col = "rd2"
                if (dx % 20 == 10 and dy % 10 == 5):
                    col = "gd2"
            L.p(x, y, col)
    for y in range(ry0 + 1, ry1 - 1, 2):
        L.p(rx0 - 1, y, "gd3")
        L.p(rx1, y, "gd3")
    # 顶的影子：顶下一整片暗一档，最里面再暗一档；往右下拖一点
    def shade_region(x0, x1, y0, y1, k):
        for y in range(y0, y1):
            for x in range(x0, x1):
                edge = (y == y1 - 1 or x == x1 - 1)
                if edge and (x + y) % 2:
                    continue
                c = L.g(x, y)
                if c[3]:
                    L.p(x, y, shift(c, k))
    shade_region(619, 917, 423, 532, -1)
    shade_region(640, 917, 532, 546, -1)
    shade_region(619, 917, 423, 478, -1)
    L.outline("ol")
    return L


def draw_pavilion_roof():
    """瓦顶（青瓦歇山顶，飞檐翘角）+ 前檐柱、额枋、挂落、雀替 + 檐角两盏红灯笼。着地线 438，排在乐手后面"""
    L = Layer(566, 276, 404, 246)
    hipW, ptsW = hip_y_table(-1)
    hipE, ptsE = hip_y_table(+1)

    def region(x, y):
        """0 外面、1 前坡、2 西斜面、3 东斜面"""
        if x < ROOF_L or x > ROOF_R:
            return 0
        top = roof_back_top(x)
        if y < top or y > eave_y(x):
            return 0
        if x < RIDGE_L and y < hipW.get(x, 999):
            return 2
        if x > RIDGE_R and y < hipE.get(x, 999):
            return 3
        return 1

    # ---- 瓦面
    for y in range(RIDGE_BOT - 30, EAVE_C + 1):
        for x in range(ROOF_L, ROOF_R + 1):
            r = region(x, y)
            if r == 0:
                continue
            if r == 1:
                c = (x - 598) % 8
                ry = (y - RIDGE_BOT) % 5
                if c == 0:
                    col = "ik2"
                elif c in (1, 2):
                    col = "sv1"
                elif c == 3:
                    col = "sv0"
                elif c == 4:
                    col = "ik3"
                elif c == 5:
                    col = "ik2"
                else:
                    col = "sv0" if ry == 0 else ("ik2" if ry == 1 else "ik3")
                if c in (1, 2, 3) and (y - RIDGE_BOT) % 10 == 9:
                    col = shift(col, -1)
                k = 0
                if y < RIDGE_BOT + 8:
                    k = -1
                elif y > eave_y(x) - 9 and c in (1, 2, 3):
                    k = 1
                L.p(x, y, shift(col, k))
            else:
                ry = (y - RIDGE_BOT) % 6
                col = ["sv1", "sv1", "sv0", "sv0", "ik3", "ik2"][ry]
                # 斜面上的瓦：一行行错开的竖缝；越往下（檐口那头翘起来）越亮一点
                if (x + (y // 6) * 4) % 8 == 0 and ry in (1, 2, 3):
                    col = "ik3"
                k = 0 if r == 2 else -1
                if y > 372 and r == 2:
                    k = 1 if (x + y) % 2 == 0 else 0
                if y < 330:
                    k -= 1
                # 侧边檐口：每行瓦头一个小圆
                edge_x = ROOF_L if r == 2 else ROOF_R
                if abs(x - edge_x) <= 1 and ry in (0, 1, 2, 3):
                    col = "sv1" if ry in (1, 2) else "ik3"
                L.p(x, y, shift(col, k))
    # ---- 两边斜面上沿的垂脊（正脊头 → 后檐角）
    for side in (-1, 1):
        xa, xb = (ROOF_L, RIDGE_L) if side < 0 else (RIDGE_R, ROOF_R)
        for x in range(xa, xb + 1):
            y = int(round(roof_back_top(x)))
            L.p(x, y - 2, "sv2" if side < 0 else "sv1")
            L.p(x, y - 1, "sv1" if side < 0 else "sv0")
            L.p(x, y, "sv0" if side < 0 else "ik3")
            L.p(x, y + 1, "ik3")
            L.p(x, y + 2, "ik2")
            if (x - xa) % 7 == 0:
                L.p(x, y - 1, "ik3")
    # ---- 戗脊：沿曲线一条 4 像素的脊，左上亮、右下暗；檐角往上翘
    for side, pts in ((-1, ptsW), (1, ptsE)):
        for (x, y) in pts:
            xi, yi = int(round(x)), int(round(y))
            L.p(xi - 1, yi - 2, "sv2")
            L.p(xi, yi - 2, "sv1")
            L.p(xi - 1, yi - 1, "sv1")
            L.p(xi, yi - 1, "sv0")
            L.p(xi + 1, yi - 1, "sv0")
            L.p(xi, yi, "ik3")
            L.p(xi + 1, yi, "ik3")
            L.p(xi + side, yi + 1, "ik2")
        # 脊上一节节（每 7 像素一道缝）
        for i in range(0, len(pts), 70):
            x, y = pts[i]
            L.p(int(round(x)), int(round(y)) - 1, "ik3")
        # 翘角：从檐角往外往上勾
        cx, cy = ROOF_L if side < 0 else ROOF_R, eave_y(ROOF_L)
        hook = [(0, 0), (1, -1), (2, -1), (3, -2), (4, -3), (5, -4), (5, -5), (6, -6), (6, -7), (6, -8), (5, -9)]
        for (dx, dy) in hook:
            x = cx + side * dx
            y = cy + dy
            L.p(x, y - 1, "sv1")
            L.p(x, y, "sv0")
            L.p(x, y + 1, "ik3")
            L.p(x - side, y + 1, "ik3")
        L.p(cx + side * 5, cy - 11, "sv2")
        L.p(cx + side * 4, cy - 11, "sv1")
        L.p(cx + side * 5, cy - 10, "sv1")
    # ---- 正脊：两头微微翘（生起），中间一溜花脊；两头鸱吻、正中宝瓶
    for x in range(RIDGE_L - 4, RIDGE_R + 5):
        d = min(x - (RIDGE_L - 4), RIDGE_R + 4 - x)
        lift = 2 if d < 6 else (1 if d < 18 else 0)
        y0 = RIDGE_TOP - lift
        rows = ["sv2", "sv1", "sv0", "ik3", "ik3", "ik3", "ik3", "ik3", "sv0", "ik3", "ik2", "ik2"]
        for j, col in enumerate(rows):
            if 3 <= j <= 7:
                c = (x - RIDGE_L) % 10
                if c in (4, 5) and j in (4, 5, 6):
                    col = "sv1" if j == 4 else "sv0"
                elif c in (3, 6) and j == 5:
                    col = "sv0"
            L.p(x, y0 + j, col)
        for j in range(y0 + 12, RIDGE_BOT + 1):
            L.p(x, j, "ik2")
    for side in (-1, 1):
        ex = RIDGE_L - 6 if side < 0 else RIDGE_R + 6
        # 吻座
        for y in range(RIDGE_TOP - 4, RIDGE_BOT + 1):
            for i in range(-4, 5):
                f = (i + 4) / 8.0
                col = "sv1" if f < 0.35 else ("sv0" if f < 0.75 else "ik3")
                L.p(ex + i, y, col)
        # 往上卷、往里勾的鸱吻尾巴
        curl = [(0, -5), (0, -6), (-1, -7), (-1, -8), (-1, -9), (0, -10), (1, -11), (2, -12), (3, -12), (4, -11),
                (4, -10), (3, -9)]
        for (dx, dy) in curl:
            x = ex - side * dx
            y = RIDGE_TOP + dy
            L.p(x, y, "sv1")
            L.p(x - side, y, "sv0")
            L.p(x + side, y, "ik3")
        L.p(ex - side * 3, RIDGE_TOP - 10, "sv2")
    # 宝瓶（正中）
    L.ell(763, RIDGE_TOP - 8, 774, RIDGE_TOP + 1, "sv0")
    L.ell(764, RIDGE_TOP - 7, 770, RIDGE_TOP - 2, "sv1")
    L.ell(765, RIDGE_TOP - 13, 772, RIDGE_TOP - 7, "sv0")
    L.p(766, RIDGE_TOP - 11, "sv2")
    L.vl(768, RIDGE_TOP - 17, RIDGE_TOP - 13, "sv0")
    L.p(768, RIDGE_TOP - 18, "sv1")
    # ---- 檐口：瓦当一行 + 滴水 + 红漆封檐板
    for x in range(ROOF_L + 1, ROOF_R):
        ye = eave_y(x)
        c = (x - 598) % 8
        if c in (1, 2, 3, 4):
            if c in (2, 3):
                L.p(x, ye - 1, "sv2" if c == 2 else "sv1")
            L.p(x, ye, "sv1" if c in (1, 2) else ("sv0" if c == 3 else "ik3"))
            L.p(x, ye + 1, "sv0" if c in (1, 2) else "ik3")
            if c in (2, 3):
                L.p(x, ye + 2, "ik3")
        else:
            L.p(x, ye, "ik3")
            L.p(x, ye + 1, "ik2" if c != 6 else "ik3")
            if c == 6:
                L.p(x, ye + 2, "ik2")
        for j, col in enumerate(("rd4", "rd3", "rd2", "rd2", "rd1")):
            L.p(x, ye + 3 + j, col)
        if x % 6 == 0:
            L.p(x, ye + 5, "gd2")
    # 翘角下面封檐板跟着往上勾
    for side in (-1, 1):
        cx = ROOF_L if side < 0 else ROOF_R
        cy = eave_y(cx)
        for dx in range(0, 5):
            for j, col in enumerate(("rd3", "rd2", "rd1")):
                L.p(cx + side * dx, cy + 3 + j - dx, col)
    # ---- 前檐柱（加的两根）、额枋、挂落、雀替
    beam_y = EAVE_C + 8          # 422
    for (x0, x1) in FRONT_POSTS:
        red_post(L, x0, x1, beam_y, 509)
    for x in range(FRONT_POSTS[0][0] - 6, FRONT_POSTS[1][1] + 6):
        for j, col in enumerate(("rd4", "rd3", "gd3", "rd3", "rd2", "rd1")):
            L.p(x, beam_y + j, col)
    # 额枋两头的箍头（金）
    for (x0, x1) in FRONT_POSTS:
        for x in range(x0 - 6, x1 + 6):
            if x in (x0 - 6, x0 - 5, x1 + 4, x1 + 5):
                for j in range(1, 5):
                    L.p(x, beam_y + j, "gd2" if j > 2 else "gd3")
    # 挂落：一溜镂空的木格（红底金边），柱间整段
    gy0, gy1 = beam_y + 6, beam_y + 14
    xa, xb = FRONT_POSTS[0][1], FRONT_POSTS[1][0]
    for x in range(xa, xb):
        k = (x - xa) % 12
        for y in range(gy0, gy1):
            j = y - gy0
            on = False
            if j == 0 or j == gy1 - gy0 - 1:
                on = True
            elif k in (0, 6):
                on = True
            elif j == 3 and k not in (3,):
                on = k in (1, 2, 4, 5, 7, 8, 10, 11)
            elif k in (3, 9) and j in (1, 2, 4, 5, 6):
                on = (k == 3 and j <= 3) or (k == 9 and j >= 3)
            if on:
                L.p(x, y, "gd2" if j == 0 else ("rd1" if j == gy1 - gy0 - 1 else "rd2"))
    # 雀替：柱头两边一对金红的托
    for (x0, x1) in FRONT_POSTS:
        for side, xs in ((-1, x0 - 1), (1, x1)):
            if (side < 0 and x0 < 700) or (side > 0 and x0 > 800):
                continue
            for r in range(0, 11):
                wdt = 11 - r
                for i in range(wdt):
                    x = xs + side * i
                    y = gy0 + r
                    col = "rd3" if i < wdt - 1 else "gd2"
                    if r == 0:
                        col = "gd3"
                    if i == 3 and 2 <= r <= 6:
                        col = "gd2"
                    L.p(x, y, col)
    L.outline("ol")
    # 檐角两盏红灯笼（翘角底下挂）
    for side in (-1, 1):
        cx = (ROOF_L - 4) if side < 0 else (ROOF_R + 4)
        L.vl(cx, eave_y(ROOF_L) - 6, eave_y(ROOF_L) + 2, "ol")
        red_lantern(L, cx, eave_y(ROOF_L) + 4)
    return L


def draw_side_rail(side):
    """东、西两边的栏杆（侧着看是一条竖的木条），着地线放在北头 452，人总在它前面"""
    xr = 622 if side < 0 else 909
    L = Layer(xr - 3, 420, 12, 238)
    for y in range(426, 651):
        for i, col in enumerate(("wd4", "wd3", "wd3", "wd2", "wd1")):
            if y >= 452 - 22 and (y - 430) % 10 == 0 and 1 <= i <= 3:
                col = shift(col, -1)
            if y < 431:
                col = shift(col, 1)
            L.p(xr + i, y, col)
    L.outline("ol")
    return L


def wood_rail(L, xa, xb, yb, posts_at):
    """朝南的一段栏杆：上下两道扶手、中间一道腰枋、竖的栏杆柱，两头望柱"""
    top = yb - 26
    for x in range(xa, xb):
        for j, col in enumerate(("wd5", "wd4", "wd3", "wd1")):
            L.p(x, top + j, col)
        for j, col in enumerate(("wd4", "wd3", "wd2", "wd1")):
            L.p(x, yb - 6 + j, col)
        L.p(x, yb - 2, "wd1")
        L.p(x, yb - 15, "wd3")
        L.p(x, yb - 14, "wd1")
    for x in range(xa + 6, xb - 4, 8):
        for y in range(top + 4, yb - 6):
            if y in (yb - 15, yb - 14):
                continue
            L.p(x, y, "wd3")
            L.p(x + 1, y, "wd1")
    for px in posts_at:
        for y in range(top - 4, yb - 1):
            for i, col in enumerate(("wd5", "wd4", "wd3", "wd3", "wd2", "wd1")):
                L.p(px + i, y, col)
        L.rect(px - 1, top - 6, px + 7, top - 4, "wd4")
        L.hl(px - 1, px + 7, top - 6, "wd5")
        L.ell(px, top - 10, px + 6, top - 5, "wd4")
        L.p(px + 1, top - 9, "wd5")


def silk_swag(L, xa, xb, ytop, nseg):
    """红绸沿扶手垂成几个弧，弧和弧之间打个结"""
    seg = (xb - xa) / float(nseg)
    for s in range(nseg):
        a = xa + seg * s
        for x in range(int(a), int(a + seg) + 1):
            u = (x - a) / seg
            y = ytop + int(round(5 * math.sin(math.pi * u)))
            L.p(x, y, "rd4")
            L.p(x, y + 1, "rd3")
            L.p(x, y + 2, "rd2")
    for s in range(nseg + 1):
        x = int(round(xa + seg * s))
        L.p(x - 1, ytop - 1, "rd4")
        L.p(x, ytop - 1, "rd3")
        L.p(x + 1, ytop - 1, "rd3")
        L.p(x, ytop + 3, "rd2")
        L.p(x - 1, ytop + 4, "rd3")
        L.p(x + 1, ytop + 5, "rd2")


def draw_pavilion_front():
    """月台南沿的栏杆 + 两根灯柱（layout 的南边两根柱子，高 92）挂红灯笼、扎红绸花。着地线 652"""
    L = Layer(596, 530, 344, 128)
    wood_rail(L, 619, 720, 652, (619, 714))
    wood_rail(L, 816, 917, 652, (816, 911))
    silk_swag(L, 625, 714, 628, 2)
    silk_swag(L, 822, 911, 628, 2)
    L.outline("ol")
    for name, out in (("post_sw", -1), ("post_se", 1)):
        r = item(name)["rect"]
        x0, x1, yb = r[0], r[2], r[3]
        hgt = item(name)["h"]
        P = Layer(596, 530, 344, 128)
        red_post(P, x0, x1, yb - hgt, yb - 6)
        # 柱头：金顶
        P.rect(x0 - 1, yb - hgt - 3, x1 + 1, yb - hgt, "gd2")
        P.hl(x0 - 1, x1 + 1, yb - hgt - 3, "gd3")
        P.ell(x0 + 2, yb - hgt - 9, x1 - 2, yb - hgt - 2, "gd3")
        P.p(x0 + 3, yb - hgt - 7, "gd4")
        # 挑杆：从柱头往外伸
        ax0 = x1 if out > 0 else x0 - 1
        for i in range(12):
            P.p(ax0 + out * i, yb - hgt + 6, "wd4")
            P.p(ax0 + out * i, yb - hgt + 7, "wd2")
        P.p(ax0 + out * 11, yb - hgt + 5, "wd4")
        P.outline("ol")
        L.paste(P)
        lx = ax0 + out * 9
        L.vl(lx, yb - hgt + 8, yb - hgt + 12, "ol")
        red_lantern(L, lx, yb - hgt + 12)
        # 柱腰一朵红绸花
        red_bow(L, (x0 + x1) // 2, 598, tails=12)
    return L


def draw_boardwalk():
    """栈道（平的）：亭子南沿到岸边，横铺木板、两边边梁、东边一道厚度；两边一溜矮桩拉红绸绳"""
    L = Layer(706, 640, 124, 192)
    plank_floor(L, 720, 816, 652, 816, 7, 61, joint_len=400, base="fl4")
    L.rect(716, 652, 720, 816, "wd3")
    L.vl(716, 652, 816, "wd4")
    L.rect(816, 652, 820, 816, "wd3")
    L.vl(819, 652, 816, "wd2")
    L.rect(820, 653, 822, 816, "wd1")
    # 南头一级台阶（落到小路上）
    for x in range(716, 822):
        L.p(x, 816, "wd4")
        for y in range(817, 822):
            L.p(x, y, "wd2" if y < 820 else "wd1")
    posts = (676, 712, 748, 784)
    for side_x in (713, 817):
        for i, y in enumerate(posts):
            for yy in range(y - 12, y + 1):
                for j, col in enumerate(("wd4", "wd3", "wd3", "wd2", "wd1")):
                    L.p(side_x + j, yy, col)
            L.hl(side_x, side_x + 5, y - 13, "fl5")
            L.p(side_x + 1, y - 13, "fl6")
            if i + 1 < len(posts):
                y2 = posts[i + 1]
                for yy in range(y - 9, y2 - 9):
                    L.p(side_x + 2, yy, "rd3" if (yy % 4) else "rd4")
    L.outline("ol")
    for side_x in (713, 817):
        for y in posts:
            mini_bow(L, side_x + 2, y - 14)
    return L


def draw_dock():
    """小码头（LK-P06）：横铺木板、两边边梁、南头台沿、北头两根粗桩（缠麻绳、扎红绸）、
    两边矮桩、一盘缆绳、一只红白救生圈。平的，着地线 560（照 layout）"""
    L = Layer(304, 526, 172, 278)
    plank_floor(L, 322, 458, 561, 786, 7, 71, joint_len=1000, base="fl3")
    # 板子底下三根龙骨：每块板上一对钉子对成一竖排；几块换过的新板子亮一档、几块缺口
    for row, y in enumerate(range(561, 786, 7)):
        for jx in (338, 390, 442):
            L.p(jx, y + 2, "fl1")
            L.p(jx + 1, y + 2, "fl0" if h2(row, jx, 3) > 0.5 else "fl1")
        if h2(row, 1, 77) > 0.86:
            for x in range(322, 458):
                for yy in range(y + 1, y + 5):
                    c = L.g(x, yy)
                    if c[3] and c not in (C["fl1"], C["fl0"]):
                        L.p(x, yy, shift(c, 1))
        if h2(row, 2, 78) > 0.9:
            gx = 330 + int(h2(row, 3, 79) * 100)
            L.hl(gx, gx + 5, y + 5, "fl0")
    L.rect(318, 558, 322, 786, "wd3")
    L.vl(318, 558, 786, "wd4")
    L.rect(458, 558, 462, 786, "wd3")
    L.vl(461, 558, 786, "wd2")
    L.rect(318, 558, 462, 561, "wd3")
    L.hl(318, 462, 558, "wd4")
    L.rect(462, 560, 464, 786, "wd1")
    for x in range(318, 464):
        L.p(x, 786, "wd4")
        for y in range(787, 797):
            col = "wd2" if y < 792 else "wd1"
            if (x - 318) % 18 == 17:
                col = "wd1"
            L.p(x, y, col)
        L.p(x, 797, "wd0")
    # 两边的桩：贴着码头边从水里立起来，冒出板面一截，顶上看得到年轮
    for y in (616, 674, 732):
        for sx in (311, 463):
            for yy in range(y - 9, y + 9):
                for j, col in enumerate(("wd4", "wd4", "wd3", "wd3", "wd2", "wd1")):
                    L.p(sx + j, yy, col)
            L.ell(sx, y - 12, sx + 6, y - 7, "fl5")
            L.p(sx + 2, y - 10, "fl3")
            L.p(sx + 3, y - 10, "fl4")
    # 北头两根粗桩（dock_post_0/1，高 16）
    for name in ("dock_post_0", "dock_post_1"):
        r = item(name)["rect"]
        x0, x1, yb = r[0], r[2], r[3]
        top = yb - item(name)["h"] - 2
        for y in range(top, yb + 1):
            for i, col in enumerate(("wd4", "wd4", "wd3", "wd3", "wd3", "wd2", "wd1", "wd1")):
                L.p(x0 + i, y, col)
        L.ell(x0, top - 2, x1, top + 3, "fl5")
        L.ell(x0 + 2, top - 1, x1 - 2, top + 2, "fl4")
        L.p(x0 + 3, top, "fl3")
        for y in range(top + 6, top + 11):
            for i in range(8):
                L.p(x0 + i, y, "fl7" if (i + y) % 3 == 0 else ("fl5" if i < 5 else "fl3"))
    # 一盘缆绳
    for k, (rx, ry) in enumerate(((11, 5), (8, 3.6), (5, 2.2))):
        L.ell(340 - rx, 578 - ry, 340 + rx, 578 + ry, "fl5" if k % 2 == 0 else "fl3")
    L.ell(337, 576, 341, 579, "fl1")
    for (x, y) in ((331, 575), (334, 574), (345, 574), (338, 573)):
        L.p(x, y, "fl7")
    L.line(351, 579, 362, 584, "fl5")
    # 救生圈（红白相间）
    cx, cy = 440, 598
    for y in range(cy - 6, cy + 7):
        for x in range(cx - 10, cx + 11):
            dx, dy = (x + 0.5 - cx) / 10.0, (y + 0.5 - cy) / 6.0
            d = dx * dx + dy * dy
            if 0.28 < d <= 1.0:
                ang = math.atan2(dy, dx)
                q = int(((ang + math.pi) / (math.pi / 2)) + 0.5) % 2
                col = "rd3" if q == 0 else "wt"
                if dx + dy > 0.35:
                    col = shift(col, -1)
                elif dx + dy < -0.6:
                    col = shift(col, 1)
                L.p(x, y, col)
    L.outline("ol")
    for name in ("dock_post_0", "dock_post_1"):
        r = item(name)["rect"]
        mini_bow(L, r[0] + 4, r[3] - item(name)["h"] + 12)
    return L


# ================================================================== 船（LK-P04 手划小木船 ×3、LK-P05 脚踏天鹅船 ×2）
def hull_half(u, wmax):
    """船身一半宽（u 0 = 船尾、1 = 船头）：船尾方、船头尖"""
    if u < 0.45:
        return wmax * (0.72 + 0.28 * math.sin(math.pi / 2 * u / 0.45))
    v = (u - 0.45) / 0.55
    return wmax * max(0.0, math.cos(math.pi / 2 * min(1.0, v) ** 1.25))


def draw_rowboat(name, bow, oars="in", rope_to=None, split=False):
    """手划小木船：从上往下看得到船舱（北边舱壁内侧、舱底板、两道坐板）、船沿、朝南的船帮；
    船头尖、扎红绸。bow +1 船头朝东。split=True 时船帮另出一张（船里坐了人，船帮要压在人前面）"""
    it = item(name)
    x0, y0, x1, y1 = it["rect"]
    h = it["h"]
    length = x1 - x0
    wmax = (y1 - y0) / 2.0 - 0.5
    yc = (y0 + y1) / 2.0 - h
    seats = [d["rect"][0] for d in it["deco"]]
    ox, oy = x0 - 34, y0 - h - 44
    L = Layer(ox, oy, length + 68, (y1 - y0) + h + 70)
    F = Layer(ox, oy, length + 68, (y1 - y0) + h + 70)
    rnd = random.Random(sum(map(ord, name)))

    def u_of(x):
        return (x - x0) / float(length) if bow > 0 else (x1 - x) / float(length)

    cols = {}
    for x in range(x0, x1 + 1):
        u = u_of(x)
        w = hull_half(u, wmax)
        if w < 0.6:
            continue
        lift = 1.0 + 4.5 * u ** 3
        yn = int(round(yc - w - lift + 1))
        ys = int(round(yc + w - lift))
        yw = int(round(yc + h + 0.78 * w))
        floor_top = int(round(yc + h - 0.6 * w - 4 - lift * 0.3))
        cols[x] = (yn, ys, yw, floor_top, u, w)
    # ---- 船舱
    for x, (yn, ys, yw, ft, u, w) in cols.items():
        for y in range(yn, ys):
            if y < ft:
                col = "wd2" if y > yn + 1 else "wd3"
                if (x - x0) % 12 == 5:
                    col = "wd1"
            else:
                col = "wd3" if (y - ft) % 3 != 2 else "wd2"
                if y == ft:
                    col = "wd1"
            L.p(x, y, col)
    # 坐板（横跨船舱）
    for sx in seats:
        for x in range(sx, sx + 6):
            if x not in cols:
                continue
            yn, ys, yw, ft, u, w = cols[x]
            for y in range(yn + 2, ys):
                L.p(x, y, "wd5" if x == sx else ("wd4" if x < sx + 5 else "wd2"))
        for x in range(sx + 6, sx + 9):
            if x in cols:
                yn, ys, yw, ft, u, w = cols[x]
                for y in range(ft + 1, ys):
                    L.shade_px(x, y, -1)
    # 桨：舱里放两支（停着的船）
    if oars == "in":
        a0 = x0 + 14 if bow > 0 else x1 - 14
        for k, dy in enumerate((-3, 2)):
            xs = a0
            xe = a0 + bow * 92
            ys0 = int(yc + dy + 1)
            ye = int(yc + dy - 2)
            L.line(xs, ys0, xe, ye, "fl5")
            L.line(xs, ys0 + 1, xe, ye + 1, "fl3")
            for i in range(14):
                bx = xs + bow * i
                L.p(bx, ys0 - 1, "fl6")
                L.p(bx, ys0 + 2, "fl3")
    # ---- 船沿（北边一线、南边一道亮）
    for x, (yn, ys, yw, ft, u, w) in cols.items():
        L.p(x, yn, "wd4")
        L.p(x, yn - 1, "wd5")
    # ---- 朝南的船帮（split 时画在 F）
    T = F if split else L
    for x, (yn, ys, yw, ft, u, w) in cols.items():
        span = max(1, yw - ys)
        for y in range(ys, yw + 1):
            s = (y - ys) / float(span)
            if y <= ys + 1:
                col = "wd5" if y == ys else "wd4"
            elif s < 0.4:
                col = "wd3"
            elif s < 0.75:
                col = "wd2"
            else:
                col = "wd1"
            if abs(s - 0.42) < 0.5 / span or abs(s - 0.76) < 0.5 / span:
                col = "wd1"
            # 船头那一截转向东，背光暗一档；船尾转向西，亮一档
            if bow > 0 and u > 0.82:
                col = shift(col, -1)
            if bow < 0 and u > 0.82:
                col = shift(col, 1)
            T.p(x, y, col)
        T.p(x, yw, "wd0")
    # 船头柱
    bx = x1 if bow > 0 else x0
    bx -= bow * 2
    yn, ys, yw, ft, u, w = cols.get(bx, cols[min(cols, key=lambda k: abs(k - bx))])
    for y in range(int(yc - 9), int(yc + h)):
        T.p(bx, y, "wd3")
        T.p(bx + bow, y, "wd1")
    T.p(bx, int(yc - 10), "wd4")
    # 桨：伸出船外（船夫划的船）
    if oars == "out":
        mx = (x0 + x1) // 2 + bow * 4
        yn_m = cols[mx][0]
        ys_m = cols[mx][1]
        L.line(mx, yn_m, mx - bow * 22, yn_m - 9, "fl4")
        L.line(mx, yn_m + 1, mx - bow * 22, yn_m - 8, "fl2")
        L.ell(mx - bow * 28 - 4, yn_m - 13, mx - bow * 28 + 5, yn_m - 8, "fl4")
        T.line(mx, ys_m, mx - bow * 26, ys_m + 18, "fl4")
        T.line(mx + 1, ys_m, mx - bow * 26 + 1, ys_m + 18, "fl2")
        T.ell(mx - bow * 31 - 4, ys_m + 17, mx - bow * 31 + 5, ys_m + 24, "fl4")
    L.outline("ol")
    if split:
        F.outline("ol")
    # 红绸：船头柱上扎一朵、两条飘带顺船帮垂下
    mini_bow(T, bx, int(yc - 7))
    for j in range(8):
        T.p(bx - bow * (2 + j // 2), int(yc - 5 + j), "rd3" if j % 3 else "rd4")
    # 缆绳拴到码头桩上
    if rope_to:
        rope_line(L, bx + bow, int(yc - 8), rope_to[0], rope_to[1], 4)
    return (L, F) if split else L


def draw_swanboat(name, rope_to=None):
    """脚踏天鹅船（头朝西，照 layout）：胸口高、船舱低、船尾两只翅膀往上翘（翅尖分开几根长羽）、中间一撮尾巴；
    船帮上面圆肩亮、往水线一层层暗；翅膀压一道影、两排鳞片羽毛；船舱灰蓝、一条蓝坐凳带靠背、方向盘；
    S 形长脖子、头、橙嘴黑鼻疙瘩；胸前扎一朵大红绸花"""
    it = item(name)
    x0, y0, x1, y1 = it["rect"]
    h = it["h"]
    length = x1 - x0
    wmax = (y1 - y0) / 2.0 - 2
    yc = (y0 + y1) / 2.0 - h + 1
    OX, OY, OW, OH = x0 - 24, y0 - h - 50, length + 48, (y1 - y0) + h + 60

    def half(u):        # u 0 = 船头（西）… 1 = 船尾（东）
        if u < 0.28:
            return wmax * math.sqrt(max(0.0, 1 - ((0.28 - u) / 0.29) ** 2))
        if u > 0.82:
            v = (u - 0.82) / 0.18
            return wmax * 0.94 * (1 - 0.35 * v * v) * math.sqrt(max(0.0, 1 - max(0.0, (v - 0.7) / 0.32) ** 2))
        return wmax * (0.94 + 0.06 * math.sin(math.pi * (u - 0.28) / 0.54))

    def lift(u):        # 船沿高低：胸口高、中间低、船尾往上
        if u < 0.25:
            return 3.0 * (1 - u / 0.25) ** 0.7
        if u > 0.6:
            return 5.0 * ((u - 0.6) / 0.4) ** 2
        return 0.0

    def wing_h(u):
        if u < 0.3:
            return 0.0
        v = (u - 0.3) / 0.7
        return 1.5 + 15.0 * v ** 2.2

    cols = {}
    for x in range(x0, x1 + 1):
        u = (x - x0) / float(length)
        w = half(u)
        if w < 1.0:
            continue
        lf = lift(u)
        yn = int(round(yc - w + 1 - lf))
        ys = int(round(yc + w - lf))
        yw = int(round(yc + h + 0.64 * w))
        cols[x] = (yn, ys, yw, u, w, wing_h(u))
    pit = lambda u: 0.3 < u < 0.8
    B = Layer(OX, OY, OW, OH)
    # ---- 北边翅膀（在船舱后面）：看得到里面那面，顶上一道亮边
    for x, (yn, ys, yw, u, w, wh) in cols.items():
        if u < 0.3:
            continue
        top = int(round(yn - wh))
        for y in range(top, yn + 3):
            B.p(x, y, "wt" if y <= top + 1 else ("sv2" if y < yn else "sv1"))
    # ---- 甲板、船舱、船帮
    for x, (yn, ys, yw, u, w, wh) in cols.items():
        for y in range(yn, ys):
            if pit(u) and yn + 2 <= y < ys - 1:
                col = "sv1" if y < yn + 5 else ("sv0" if y < yn + 7 else "sv1")
            elif u < 0.3 or u > 0.8:
                col = "wt" if y < ys - 2 else "sv2"
            else:
                col = "wt"
            if y == yn and not pit(u):
                col = "wt"
            B.p(x, y, col)
        span = max(1, yw - ys)
        for y in range(ys, yw + 1):
            s = (y - ys) / float(span)
            col = "wt" if s < 0.22 else ("sv2" if s < 0.62 else ("sv1" if s < 0.9 else "sv0"))
            if u < 0.12 and s < 0.62:
                col = "wt"
            if abs(s - 0.7) < 0.5 / span and 0.08 < u < 0.95:
                col = "sv0"                       # 一道护舷条
            elif abs(s - 0.7) < 1.5 / span and s < 0.7 and 0.08 < u < 0.95:
                col = "wt"
            if u > 0.88 or (u > 0.62 and s > 0.45 and (u > 0.74 or (x + y) % 2 == 0)):
                col = shift(col, -1)
            B.p(x, y, col)
    # 坐凳（南北向：蓝坐垫 + 东边一块靠背立起来）、方向盘
    sx = x0 + 62
    for x in range(sx, sx + 11):
        yn, ys, yw, u, w, wh = cols[x]
        for y in range(yn + 2, ys - 1):
            col = "bl4" if x == sx else ("bl3" if x < sx + 7 else "bl2")
            if y == ys - 2:
                col = "bl2"
            B.p(x, y, col)
    for x in range(sx + 8, sx + 13):
        yn, ys, yw, u, w, wh = cols[x]
        for y in range(yn - 6, ys - 3):
            col = "bl3" if x == sx + 8 else ("bl2" if x < sx + 11 else "bl1")
            if y == yn - 6:
                col = "bl4"
            B.p(x, y, col)
    B.ell(x0 + 44, int(yc - 1), x0 + 54, int(yc + 5), "ik2")
    B.ell(x0 + 46, int(yc), x0 + 52, int(yc + 4), "sv1")
    B.p(x0 + 49, int(yc + 2), "ik2")
    B.vl(x0 + 49, int(yc + 4), int(yc + 11), "ik3")
    B.outline("ol")
    # ---- 南边翅膀：盖在船帮上半截，往船尾翘起来；下沿压一道影；两排鳞片羽毛
    Wg = Layer(OX, OY, OW, OH)
    for x, (yn, ys, yw, u, w, wh) in cols.items():
        if u < 0.3:
            continue
        top = int(round(ys - wh))
        bot = int(round(ys + 3 + 6 * min(1.0, (u - 0.3) / 0.35)))
        for y in range(top, bot + 1):
            if y <= top + 1:
                col = "wt"
            elif y < top + 4:
                col = "wt" if u < 0.75 else "sv2"
            elif y == bot:
                col = "sv1"
            else:
                col = "sv2"
            Wg.p(x, y, col)
    for row in range(2):
        for k in range(12):
            fx0 = x0 + 42 + row * 5 + k * 9
            for i in range(9):
                x = fx0 + i
                if x not in cols or cols[x][3] < 0.36:
                    continue
                yn, ys, yw, u, w, wh = cols[x]
                top = int(round(ys - wh))
                y = top + 4 + row * 4 + int(round(2.4 * math.sin(math.pi * i / 8.0)))
                if Wg.has(x, y + 1) and Wg.g(x, y + 1) != C["sv1"]:
                    Wg.p(x, y, "sv1" if 1 <= i <= 7 else "sv2")
                    if 3 <= i <= 5:
                        Wg.p(x, y - 1, "wt")
    # 翅尖：船尾几根长羽毛分开往上翘
    for j, (dx, ln) in enumerate(((-12, 8), (-7, 11), (-2, 14))):
        bx = x1 - 10 + dx
        if bx not in cols:
            continue
        yn, ys, yw, u, w, wh = cols[bx]
        top = int(round(ys - wh))
        for i in range(ln):
            x = bx + i // 3
            y = top - i
            Wg.p(x, y, "wt")
            Wg.p(x + 1, y, "sv2")
            Wg.p(x + 2, y + 1, "sv1")
    Wg.outline("ol")
    B.paste(Wg)
    # ---- 尾巴（两只翅膀中间往上翘的一撮）
    Tl = Layer(OX, OY, OW, OH)
    tx = x1 - 5
    tyb = cols[tx][0] if tx in cols else int(yc)
    for j in range(12):
        y = tyb - j
        wdt = max(1, 6 - j // 2)
        for i in range(wdt):
            Tl.p(tx - j // 3 + i - wdt // 2, y, "wt" if i < wdt - 1 else "sv2")
    Tl.outline("ol")
    B.paste(Tl)
    # ---- 脖子、头
    N = Layer(OX, OY, OW, OH)
    bx, by = x0 + 15, yc + 2
    hx, hy = x0 + 11, yc - 27
    for i in range(81):
        t = i / 80.0
        nx = bx + (hx + 1 - bx) * t + 3.6 * math.sin(math.pi * t * 1.55)
        ny = by + (hy + 3 - by) * t
        wd = 9.0 - 3.4 * t
        for dx in range(-6, 7):
            if abs(dx) <= wd / 2:
                col = "wt" if dx < wd / 6 else "sv2"
                N.p(int(round(nx + dx)), int(round(ny)), col)
    N.ell(hx - 5, hy - 5, hx + 6, hy + 4, "wt")
    N.ell(hx + 1, hy - 3, hx + 6, hy + 4, "sv2", only=lambda x, y: x >= hx + 2 and y >= hy - 1)
    N.p(hx - 2, hy - 4, "wt")
    for i in range(6):
        N.p(hx - 5 - i, hy - 1, "or" if i < 5 else "rd4")
        N.p(hx - 5 - i, hy, "or" if i < 4 else "rd3")
    N.p(hx - 6, hy - 2, "gd3")
    N.p(hx - 5, hy - 2, "ol")
    N.p(hx - 4, hy - 2, "ol")
    N.p(hx - 4, hy - 1, "ol")
    N.p(hx - 3, hy - 2, "ol")
    N.p(hx - 1, hy - 2, "ik2")
    N.outline("ol")
    B.paste(N)
    # 胸前一朵大红绸花
    red_bow(B, bx - 1, int(yc + 4), tails=10)
    if rope_to:
        rope_line(B, x0 + 5, int(yc + 7), rope_to[0], rope_to[1], 3)
    return B


# ================================================================== 柳树（LK-P02 ×6）
WILLOWS = {k: (item(k)["x"], item(k)["y"]) for k in
           ("willow_0", "willow_1", "willow_2", "willow_3", "willow_4", "willow_5")}
WI = ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"]
BARK = ["ol", "wd0", "wd1", "fl1", "fl2", "fl3"]


def wi(i):
    return WI[max(0, min(7, int(i)))]


def strand_path(x0, y0, vx, vy, y_end, sway):
    pts = []
    x, y = float(x0), float(y0)
    guard = 0
    while y < y_end and guard < 700:
        guard += 1
        sp = math.hypot(vx, vy) or 1.0
        x += vx / sp
        y += vy / sp
        vy = min(1.0, vy + 0.07)
        if vy > 0:
            vx *= 0.955
            vx += sway * 0.012 * vy
        ip = (int(round(x)), int(round(y)))
        if not pts or ip != pts[-1]:
            pts.append(ip)
    return pts


def draw_strand(L, pts, tone, phase):
    """一缕柳条：中间一根细枝，两边交替长两像素的小尖叶（左边朝光亮一档、右边暗一档），梢上叶子变小"""
    n = len(pts)
    if n < 4:
        return
    for i, (px, py) in enumerate(pts):
        t = i / float(n - 1)
        tt = tone - (1 if t > 0.72 else 0) - (1 if t > 0.93 else 0)
        j0, j1 = max(0, i - 2), min(n - 1, i + 2)
        dx = pts[j1][0] - pts[j0][0]
        dy = pts[j1][1] - pts[j0][1]
        dl = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / dl, dx / dl
        if nx > 0:
            nx, ny = -nx, -ny
        L.p(px, py, wi(tt))
        k = (i + phase) % 4
        small = t > 0.9
        if k == 0:
            L.p(px + round(nx), py + round(ny), wi(tt + 1))
            if not small:
                L.p(px + round(nx * 2), py + round(ny * 2) + 1, wi(tt + 1))
        elif k == 2:
            L.p(px - round(nx), py - round(ny), wi(tt - 1))
            if not small:
                L.p(px - round(nx * 2), py - round(ny * 2) + 1, wi(tt - 1))


def draw_willow(tid):
    """垂柳：粗树干往一边歪、分三四根大枝；大枝梢上一簇簇细枝像喷泉往外拱、再垂下来，
    每簇 4～7 根柳条挨在一起成一缕，缕和缕之间留缝（看得到后面的枝、树干和水）。
    柳条：一根细枝两边交替长小尖叶，左边朝光亮、右边暗；后面的缕暗、前面的亮，树冠左边亮、右边暗"""
    fx, fy = WILLOWS[tid]
    it = item(tid)
    th, tw = it["h"], it["w"]
    seed = sum(map(ord, tid)) * 17 + fx
    rnd = random.Random(seed)
    top = fy - th
    L = Layer(fx - tw // 2 - 14, top - 8, tw + 28, th + 10)
    ccx = fx + rnd.randint(-6, 6)
    lean = rnd.uniform(-10, 10)
    half = tw / 2.0 - 6
    sway = 0.6                     # 风从西边来，柳条梢往东飘一点
    # ---- 树干、大枝（先画在一层里，后面的缕画在它前面、前面的缕盖住它）
    T = Layer(L.ox, L.oy, L.w, L.h)
    fork_x, fork_y = fx + lean, fy - rnd.randint(96, 116)
    thick_line(T, fx, fy - 1, fork_x, fork_y, 17, 12, BARK)
    for (dx, w) in ((-9, 6), (9, 6), (-3, 5), (5, 4)):
        thick_line(T, fx + dx * 0.3, fy - 9, fx + dx, fy, w, 3, BARK)
    limbs = [(ccx - 40, top + 50), (ccx - 12, top + 22), (ccx + 18, top + 26), (ccx + 44, top + 56)]
    ends = []
    for (tx, ty) in limbs:
        # 大枝：三段折一折（不是一根直棍），越往上越细
        mx = fork_x + (tx - fork_x) * 0.35 + rnd.uniform(-7, 7)
        my = fork_y - 26 - rnd.uniform(0, 12)
        qx = mx + (tx - mx) * 0.55 + rnd.uniform(-8, 8)
        qy = my + (ty - my) * 0.55 + rnd.uniform(-6, 6)
        thick_line(T, fork_x, fork_y + 4, mx, my, 9, 7, BARK)
        thick_line(T, mx, my, qx, qy, 7, 4, BARK)
        thick_line(T, qx, qy, tx, ty, 4, 2, BARK)
        ends.append((tx, ty))
        ends.append((qx, qy))
    for _ in range(26):
        x = int(fx + rnd.uniform(-6, 6) + lean * rnd.random() * 0.5)
        y = rnd.randint(int(fork_y), fy - 4)
        for j in range(rnd.randint(4, 10)):
            if T.g(x, y + j) in (C["fl1"], C["fl2"], C["fl3"]):
                T.p(x, y + j, "wd1")
    # ---- 一簇簇的起点（树冠顶上一圈拱形）
    nb = rnd.randint(20, 23)
    bunches = []
    for k in range(nb):
        u = -1 + 2 * (k + rnd.uniform(0.2, 0.8)) / nb
        d = rnd.random()
        bx = ccx + u * (half - 14) + rnd.uniform(-3, 3)
        by = top + 8 + 30 * u * u + rnd.uniform(0, 20) + (1 - d) * 4
        bunches.append((d, u, bx, by))
    for k in range(8):                          # 中间再补几簇，免得树冠中间空
        u = rnd.uniform(-0.6, 0.6)
        bunches.append((rnd.uniform(0.0, 0.55), u, ccx + u * 44, top + 30 + rnd.uniform(0, 30)))
    bunches.sort(key=lambda b: b[0])
    # 细枝：从最近的大枝梢连到每簇的起点
    for (d, u, bx, by) in bunches:
        ex, ey = min(ends, key=lambda e: (e[0] - bx) ** 2 + (e[1] - by) ** 2)
        T.line(ex, ey, bx, by + 2, "wd1")
        T.line(ex + 1, ey, bx + 1, by + 2, "fl1")
    T.outline("ol", pick=lambda x, y, nb: "ol" if y > top + 70 else None)

    def put(b):
        d, u, bx, by = b
        n = rnd.randint(5, 8)
        base_len = rnd.uniform(40, 112) + (0 if abs(u) < 0.8 else 24)
        T0 = 1.6 + d * 3.4 - u * 1.2
        vy0 = -rnd.uniform(0.45, 0.95) * (1 - 0.4 * abs(u))
        for j in range(n):
            off = (j - (n - 1) / 2.0)
            x0 = bx + off * 2.0 + rnd.uniform(-0.6, 0.6)
            vx = u * 0.75 + off * 0.07 + rnd.uniform(-0.08, 0.08)
            vy = vy0 + rnd.uniform(-0.08, 0.08)
            edge = abs(off) / max(1.0, (n - 1) / 2.0)
            y_end = fy - base_len - edge * rnd.uniform(6, 26) + rnd.uniform(-6, 6)
            tone = T0 + (0.9 if j == 0 else 0) - (0.9 if j == n - 1 else 0)
            pts = strand_path(x0, by, vx, vy, y_end, sway)
            pts = [(x, y) for (x, y) in pts if abs(x - fx) <= tw // 2 + 6]
            draw_strand(L, pts, int(round(tone)), (j * 2 + int(bx)) % 4)

    for b in bunches:
        if b[0] < 0.35:
            put(b)
    L.paste(T)
    for b in bunches:
        if b[0] >= 0.35:
            put(b)
    return L


# ================================================================== 长凳（LK-P03 ×2）
def draw_bench(prefix):
    """公园长凳，面朝湖（从背后看）：两头铸铁凳脚带卷边扶手，木条靠背两道、板缝里看得到后面的凳面，
    靠背中间扎个小红绸结。着地线 972"""
    x0 = item(prefix + "_seat")["x0"]
    x1 = item(prefix + "_seat")["x1"]
    L = Layer(x0 - 6, 908, (x1 - x0) + 12, 68)
    ia, ib = x0 + 5, x1 - 5
    # 凳面（在靠背后面，从板缝和靠背上沿露出来）：横木条
    for y in range(925, 946):
        k = (y - 925) % 4
        for x in range(ia, ib):
            col = "wd3" if k in (1, 2) else ("wd4" if k == 0 else "wd1")
            if y > 939:
                col = shift(col, -1)
            L.p(x, y, col)
    # 凳面南沿的厚度
    for x in range(ia, ib):
        L.p(x, 946, "wd4")
        L.p(x, 947, "wd2")
        L.p(x, 948, "wd1")
    # 靠背：两道木条 + 下面一道横档；中间两根立撑
    for (ya, yb) in ((929, 934), (936, 941)):
        for x in range(ia - 1, ib + 1):
            for y in range(ya, yb):
                col = "wd5" if y == ya else ("wd2" if y == yb - 1 else "wd4")
                if (x * 7 + y * 3) % 29 == 0 and ya < y < yb - 1:
                    col = "wd3"
                L.p(x, y, col)
    for x in range(ia, ib):
        L.p(x, 943, "wd3")
        L.p(x, 944, "wd2")
    for xm in (x0 + 25, x0 + 46):
        for y in range(929, 946):
            L.p(xm, y, "wd3")
            L.p(xm + 1, y, "wd1")
    # 两头铸铁凳脚：一整片带镂空，顶上卷边扶手
    for side, ex in ((-1, x0), (1, x1 - 6)):
        for y in range(918, 972):
            for i in range(6):
                inner = i in (2, 3) and 950 < y < 966
                if inner:
                    continue
                col = "ik3" if i <= 1 else ("ik2" if i < 5 else "ik2")
                if i == 0 and y < 950:
                    col = "sv0"
                L.p(ex + i, y, col)
        # 扶手卷边
        cx = ex + 3 + side * 2
        for (dx, dy, c) in ((-3, 0, "ik3"), (-2, -1, "sv0"), (-1, -2, "sv0"), (0, -2, "ik3"), (1, -2, "ik3"), (2, -1, "ik2"),
                            (3, 0, "ik2"), (3, 1, "ik2"), (2, 2, "ik2"), (1, 2, "ik3"), (0, 1, "sv0")):
            L.p(cx + dx * side, 918 + dy, c)
        # 脚底一小块往外撇
        L.hl(ex - 1, ex + 7, 971, "ik2")
        L.p(ex + (7 if side > 0 else -1), 970, "ik2")
    L.outline("ol")
    mini_bow(L, (x0 + x1) // 2, 931)
    return L


# ================================================================== 荷叶荷花（LK-P08 ×3）、芦苇（LK-P09 ×3）
LOTUS = [("lotus_1", "lotus_flower_1"), ("lotus_2", "lotus_flower_2"), ("lotus_3", "lotus_flower_3")]


def lotus_pad(L, cx, cy, w, rnd, notch_ang):
    """一片浮在水上的荷叶（斜俯视压扁成椭圆）：左上一圈亮边、右下暗、放射叶脉、一道缺口"""
    rx, ry = w / 2.0, w * 0.32
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = dx * dx + dy * dy
            if d > 1.0:
                continue
            ang = math.atan2(dy, dx)
            da = (ang - notch_ang + math.pi) % (2 * math.pi) - math.pi
            if abs(da) < 0.16 and d > 0.05:
                continue
            col = "nl2"
            if d > 0.62:
                col = "nl3" if (dx + dy) < -0.2 else ("nl1" if (dx + dy) > 0.25 else "nl2")
            elif (dx + dy) < -0.55:
                col = "nl3"
            # 叶脉
            for va in range(8):
                a = va * math.pi / 4 + 0.3
                if abs((ang - a + math.pi) % (2 * math.pi) - math.pi) < 0.07 and 0.08 < d < 0.8:
                    col = "nl3" if (dx + dy) < 0.2 else "nl1"
            L.p(x, y, col)
    L.p(int(cx), int(cy), "gB")


def draw_lotus_pads(L, rnd):
    for (pid, fid) in LOTUS:
        it = item(pid)
        cx, cy, rx, ry = it["x"], it["y"], it["rx"], it["ry"]
        placed = []
        tries = 0
        while len(placed) < 8 and tries < 400:
            tries += 1
            px = cx + rnd.uniform(-rx + 6, rx - 6)
            py = cy + rnd.uniform(-ry + 2, ry - 2)
            w = rnd.choice([10, 13, 16, 19, 22, 24])
            if all(math.hypot(px - a, (py - b) * 1.6) > (w + ww) * 0.42 for (a, b, ww) in placed):
                placed.append((px, py, w))
        placed.sort(key=lambda p: p[1])
        P = Layer(L.ox, L.oy, L.w, L.h)
        for (px, py, w) in placed:
            Q = Layer(L.ox, L.oy, L.w, L.h)
            lotus_pad(Q, px, py, w, rnd, rnd.uniform(0, 6.28))
            Q.outline("gr0", pick=lambda x, y, nb: "gr0" if not P.has(x, y) else "gr0")
            P.paste(Q)
        L.paste(P)
        # 几片小浮叶、几颗落在水上的花瓣
        for _ in range(4):
            x = int(cx + rnd.uniform(-rx - 14, rx + 14))
            y = int(cy + rnd.uniform(-ry - 4, ry + 6))
            if not L.has(x, y):
                L.hl(x, x + 3, y, "nl3")
                L.hl(x, x + 3, y + 1, "nl2")
                L.p(x - 1, y + 1, "gr0")
                L.p(x + 3, y + 1, "gr0")
        for _ in range(3):
            x = int(cx + rnd.uniform(-rx, rx + 10))
            y = int(cy + rnd.uniform(ry - 2, ry + 8))
            if not L.has(x, y):
                L.p(x, y, "pk2")
                L.p(x + 1, y, "pk")


def lotus_flower(L, cx, cy):
    """一朵开着的荷花（约 13 宽 10 高）：外瓣粉、里瓣浅粉带白、瓣尖深粉，中间黄莲蓬"""
    # 后排瓣
    for (dx, dy, c) in ((-3, -6, "pk"), (-2, -7, "pk2"), (0, -8, "pk2"), (1, -8, "pk"), (2, -7, "pk2"), (3, -6, "pk"),
                        (-1, -7, "pk2"), (0, -7, "wt"), (1, -7, "pk2")):
        L.p(cx + dx, cy + dy, c)
    L.p(cx, cy - 9, "pk0")
    L.p(cx - 3, cy - 7, "pk0")
    L.p(cx + 3, cy - 7, "pk0")
    # 莲蓬
    L.hl(cx - 2, cx + 3, cy - 5, "gd3")
    L.hl(cx - 2, cx + 3, cy - 4, "gd2")
    L.p(cx - 1, cy - 5, "gd4")
    L.p(cx + 1, cy - 4, "gd1")
    # 两侧张开的瓣
    for side in (-1, 1):
        for (dx, dy, c) in ((3, -5, "pk2"), (4, -5, "pk"), (5, -4, "pk"), (6, -4, "pk0"), (4, -4, "pk2"),
                            (3, -3, "wt"), (5, -3, "pk"), (6, -2, "pk0")):
            L.p(cx + side * dx, cy + dy, c if side < 0 or c != "pk2" else "pk")
    # 前排瓣
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


def draw_lotus_stand(pid, fid):
    """立起来的：两朵花（layout 两团粉的位置）、一个花苞、一张举出水面的荷叶。着地线照 layout（lotus_flower 的 y）"""
    it = item(pid)
    fl = item(fid)
    cx, cy, rx = it["x"], it["y"], it["rx"]
    L = Layer(cx - rx - 10, cy - 40, 2 * rx + 20, 56)
    rnd = random.Random(cx * 7 + cy)
    (ax, ay, _a1, _a2), (bx, by, _b1, _b2) = fl["e"]
    # 举出水面的荷叶（伞）
    lx, ly = cx + rnd.choice([-18, 16]), cy - 14
    L.vl(lx, ly + 2, cy + 2, "nl2")
    L.ell(lx - 8, ly - 3, lx + 9, ly + 4, "nl2")
    L.ell(lx - 7, ly - 3, lx + 4, ly + 2, "nl3")
    L.ell(lx - 3, ly - 2, lx + 3, ly + 1, "gB")
    L.p(lx, ly, "nl1")
    L.hl(lx - 6, lx + 8, ly + 3, "nl1")
    # 茎
    for (sx, sy, top) in ((ax, ay, ay - 6), (bx, by, by - 3), (cx + 4, cy, cy - 18)):
        L.vl(sx, top, cy + 3, "nl2")
        L.vl(sx + 1, top + 2, cy + 3, "nl1")
    lotus_flower(L, ax, ay - 6)
    lotus_flower(L, bx + 1, by - 3)
    lotus_bud(L, cx + 4, cy - 18)
    L.outline("ol", pick=lambda x, y, nb: "gr0" if is_ramp(nb, "lf") or is_ramp(nb, "gr") else "pk0" if nb in (C["pk"], C["pk2"], C["wt"]) else "ol")
    return L


def draw_reed(rid):
    """一丛芦苇（1.5 米）：十几片长叶从一个窄窄的根上往上、往外弯（叶子两像素：左边亮、右边暗一道边），
    绿的多、枯黄的少，有几片梢头折下来；四根抽了穗，穗头毛茸茸往东垂。根上一小撮深色，不描整圈的边"""
    pts = item(rid)["pts"]
    xs = [p[0] for p in pts]
    x0, x1 = min(xs), max(xs)
    foot = max(p[1] for p in pts)
    cx = (x0 + x1) // 2
    L = Layer(x0 - 24, foot - 88, (x1 - x0) + 48, 92)
    rnd = random.Random(cx * 13 + 5)
    GR = ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4"]
    DRY = ["bb0", "bb0", "bb1", "bb1", "bb2", "bb2", "bb3"]

    def blade(bx, hh, lean, tone, ramp, droop):
        n = hh + 6
        last = None
        for i in range(n):
            t = i / float(n)
            x = bx + lean * t ** 1.7
            y = foot - 2 - hh * t
            if droop and t > 0.72:
                y += (t - 0.72) * hh * 1.6
                x += (t - 0.72) * lean * 1.2
            xi, yi = int(round(x)), int(round(y))
            if (xi, yi) == last:
                continue
            last = (xi, yi)
            L.p(xi, yi, ramp[min(6, tone + (1 if t < 0.5 else 0))])
            if t < 0.82:
                L.p(xi + 1, yi, ramp[max(0, tone - 2)])
            if t < 0.3:
                L.p(xi - 1, yi, ramp[min(6, tone)])

    blades = []
    for k in range(24):
        bx = cx + (-4 if k % 2 else 5) + int(rnd.gauss(0, 2.6))
        hh = rnd.randint(28, 64)
        lean = rnd.uniform(-14, 14) + (bx - cx) * 1.6
        d = rnd.random()
        dry = rnd.random() < 0.2
        droop = rnd.random() < 0.25 and abs(lean) > 6
        blades.append((d, bx, hh, lean, dry, droop))
    blades.sort()
    for (d, bx, hh, lean, dry, droop) in blades[:9]:
        blade(bx, hh, lean, 2 + int(d * 2), DRY if dry else GR, droop)
    # 穗：五根，高低、左右错开
    for k, (dxp, hh) in enumerate(((-9, 62), (-3, 76), (2, 68), (7, 80), (12, 58))):
        sx = cx + dxp // 2 + rnd.randint(-1, 1)
        lean = dxp * 0.9 + rnd.uniform(-2, 2)
        top_x, top_y = sx + lean, foot - hh
        for i in range(hh):
            t = i / float(hh)
            L.p(int(round(sx + lean * t * t)), int(round(foot - 2 - hh * t)), "bb1" if t < 0.85 else "fl2")
        for j in range(13):
            w = 1 + (j > 2) + (j > 6) - (j > 10)
            for i in range(w + 1):
                x = int(round(top_x + i + j * 0.4))
                y = int(round(top_y + j - 1))
                col = "bb3" if i == 0 else ("bb2" if i == 1 else "fl3")
                if (i + j) % 4 == 3:
                    col = "fl4"
                L.p(x, y, col)
            L.p(int(round(top_x + w + 1 + j * 0.4)), int(round(top_y + j - 1)), "fl2")
    for (d, bx, hh, lean, dry, droop) in blades[9:]:
        blade(bx, hh, lean, 3 + int(d * 3), DRY if dry else GR, droop)
    # 根：一小撮深色
    for x in range(cx - 6, cx + 7):
        for y in range(foot - 3, foot + 1):
            if L.has(x, y) or abs(x - cx) < 5 - (foot - y):
                L.p(x, y, "gr1" if (x + y) % 3 else "gr0")
    return L


# ================================================================== 钓鱼的（LK-P07 ×2：小凳、钓竿、水桶）
def draw_stool(sid):
    """钓鱼的小马扎：红白条帆布凳面、两条木腿交叉成 X"""
    r = item(sid)["rect"]
    x0, y0, x1, y1 = r
    h = item(sid)["h"]
    L = Layer(x0 - 3, y0 - h - 4, (x1 - x0) + 6, (y1 - y0) + h + 6)
    top = y0 - h
    # X 腿（前面一对）
    L.line(x0 + 2, top + 6, x1 - 3, y1 - 1, "wd3")
    L.line(x0 + 3, top + 6, x1 - 2, y1 - 1, "wd2")
    L.line(x1 - 3, top + 6, x0 + 2, y1 - 1, "wd4")
    L.line(x1 - 2, top + 6, x0 + 3, y1 - 1, "wd2")
    L.p((x0 + x1) // 2, (top + 6 + y1) // 2, "sv1")
    # 凳面：两根横木夹一块帆布
    for x in range(x0, x1):
        L.p(x, top, "wd4")
        L.p(x, top + 1, "wd3")
        for y in range(top + 2, top + 5):
            L.p(x, y, "rd3" if ((x - x0) // 3) % 2 == 0 else "wt")
            if y == top + 4:
                L.p(x, y, shift(L.g(x, y), -1))
        L.p(x, top + 5, "wd3")
        L.p(x, top + 6, "wd1")
    L.outline("ol")
    return L


def draw_rod(rid):
    """竹钓竿：根上缠一截黑把手，一节节竹节，梢细；鱼线垂到水里，一只红白浮漂"""
    pts = item(rid)["pts"]
    (ax, ay), (tx, ty) = pts[0], pts[2]
    L = Layer(min(ax, tx) - 12, ty - 4, abs(tx - ax) + 24, ay - ty + 40)
    n = int(math.hypot(tx - ax, ty - ay))
    for i in range(n + 1):
        t = i / float(n)
        x = ax + (tx - ax) * t
        y = ay + (ty - ay) * t
        xi, yi = int(round(x)), int(round(y))
        if t < 0.1:
            L.p(xi, yi, "ik2")
            L.p(xi + 1, yi, "ik3")
            L.p(xi, yi + 1, "ik2")
        elif t < 0.55:
            node = (i % 16) == 0
            L.p(xi, yi, "bb0" if node else "bb2")
            L.p(xi + 1, yi, "bb0" if node else "bb1")
        else:
            L.p(xi, yi, "bb3" if t > 0.9 else "bb2")
    # 鱼线和浮漂
    fx = tx + (6 if tx > ax else -6)
    fy = ty + 30
    for i in range(0, 31):
        t = i / 30.0
        x = tx + (fx - tx) * t
        y = ty + (fy - ty) * t
        if i % 2 == 0:
            L.p(int(round(x)), int(round(y)), "sv2")
    L.p(fx, fy - 4, "rd4")
    L.p(fx, fy - 3, "wt")
    L.p(fx, fy - 2, "rd3")
    L.p(fx, fy - 1, "rd3")
    L.outline("ol", pick=lambda x, y, nb: "ol" if nb in (C["rd4"], C["rd3"], C["wt"], C["ik2"], C["ik3"]) or abs(x - ax) < 30 else None)
    return L, (fx, fy)


def draw_bucket(bid):
    """蓝塑料水桶：桶沿一圈、桶里有水和一条鱼尾巴、细铁提手"""
    it = item(bid)
    cx, cy, rx, ry, h = it["x"], it["y"], it["rx"], it["ry"], it["h"]
    L = Layer(cx - rx - 3, cy - h - ry - 8, 2 * rx + 6, h + 2 * ry + 12)
    for y in range(cy - h, cy + ry):
        for x in range(cx - rx, cx + rx + 1):
            dx = (x + 0.5 - cx) / (rx + 0.5)
            if y > cy and ((y - cy + 0.5) / ry) ** 2 + dx * dx > 1:
                continue
            col = "bl3" if dx < -0.45 else ("bl2" if dx < 0.5 else "bl1")
            if y - (cy - h) in (3, 4):
                col = shift(col, 1)
            L.p(x, y, col)
    L.ell(cx - rx - 1, cy - h - ry, cx + rx + 2, cy - h + ry + 1, "bl3")
    L.ell(cx - rx + 1, cy - h - ry + 1, cx + rx, cy - h + ry, "lk2")
    L.ell(cx - rx + 2, cy - h - ry + 2, cx + 1, cy - h + 1, "wa0")
    L.p(cx + 2, cy - h - 1, "sv1")
    L.p(cx + 3, cy - h - 2, "sv2")
    L.p(cx + 4, cy - h - 2, "sv1")
    for i in range(-rx, rx + 1):
        L.p(cx + i, cy - h - ry - 5 + int(round(4 * (i / float(rx)) ** 2)), "sv0")
    L.outline("ol")
    return L


# ================================================================== 鸭子（LK-P10，会动，单独一张帧图）
DUCK_FW, DUCK_FH = 36, 26
DUCK_ANCHOR = (18, 21)     # 帧里的「脚点」：身子正中、水线


def duck_frame(face, frame):
    """一只白鸭子在水上（约 31 宽 20 高）：face -1 头朝西、+1 朝东；4 帧：身子一上一下、尾巴摆、身后水纹往外扩"""
    L = Layer(0, 0, DUCK_FW, DUCK_FH)
    ax, ay = DUCK_ANCHOR
    bob = (0, -1, 0, 1)[frame] if frame != 3 else 0
    bob = (0, -1, -1, 0)[frame]
    wy = ay + bob

    def X(u):
        return ax + face * u

    # 身子
    for y in range(wy - 9, wy + 1):
        for u in range(-12, 11):
            du = u / 11.5
            dv = (y - (wy - 4.5)) / 5.0
            if du * du + dv * dv <= 1.0:
                x = X(u)
                col = "wt"
                if y >= wy - 1:
                    col = "sv1"
                elif y >= wy - 3 or (x - ax) + (y - wy + 5) * 2 > 9:
                    col = "sv2"
                L.p(x, y, col)
    # 尾巴（往上翘、帧里左右摆一像素）
    wag = (0, 1, 0, -1)[frame]
    for j in range(4):
        L.p(X(-12 - j), wy - 5 - j + (wag if j > 1 else 0), "wt" if j < 3 else "sv2")
        L.p(X(-11 - j), wy - 5 - j, "wt")
    # 翅膀：一道弧 + 几根羽尖
    for u in range(-8, 4):
        L.p(X(u), wy - 7 + (1 if abs(u + 2) > 5 else 0), "sv2")
    for u in (-9, -7, -5):
        L.p(X(u), wy - 5, "sv1")
    # 脖子和头
    for j in range(5):
        L.p(X(7), wy - 7 - j, "wt")
        L.p(X(8), wy - 7 - j, "wt")
        L.p(X(9), wy - 8 - j, "sv2" if face > 0 else "wt")
    L.ell(X(8) - 3.5, wy - 17, X(8) + 4.5, wy - 10, "wt")
    L.p(X(10), wy - 12, "sv2")
    L.p(X(9), wy - 15, "ol")
    # 嘴（橙）
    for u in (12, 13, 14):
        L.p(X(u), wy - 14, "or")
        L.p(X(u), wy - 13, "or" if u < 14 else "rd3")
    L.p(X(12), wy - 15, "gd3")
    L.outline("ol")
    # 水纹（不描边）：身下一道亮线，身后一个往外扩的 V
    for u in range(-11, 10):
        if (u + frame) % 5 != 4:
            L.p(X(u), wy + 1, "wa2")
    spread = (2, 3, 4, 5)[frame]
    for i in range(spread + 2):
        L.p(X(-14 - i), wy + 2 + i // 3, "wa1")
        if i > 1:
            L.p(X(-14 - i), wy + 1 - i // 4, "wa1")
    return L


def draw_duck_sheet():
    sheet = Image.new("RGBA", (DUCK_FW * 8, DUCK_FH), (0, 0, 0, 0))
    for k in range(8):
        face = -1 if k < 4 else 1
        fr = duck_frame(face, k % 4)
        sheet.alpha_composite(fr.im, (k * DUCK_FW, 0))
    return sheet


# ================================================================== 水面装饰层（平的，紧贴在底图上）
def ripple(L, x, y, w, col="wa2", col2="wa1"):
    """一道水纹：中间一段亮、两头断开的短线"""
    for i in range(-w, w + 1):
        if abs(i) < w * 0.6 or (i % 2 == 0):
            L.p(x + i, y, col if abs(i) < w * 0.6 else col2)


def boat_ripples(L, rect, layers, bow):
    """船边水纹：贴着船底那圈描边下面一行，断断续续（中间亮、两头暗）；再往外一道更淡、更短的；船头推起一个小 V"""
    x0, y0, x1, y1 = rect
    bottoms = {}
    for Ly in layers:
        px = Ly.im.load()
        for xx in range(Ly.w):
            x = Ly.ox + xx
            if not (x0 - 2 <= x <= x1 + 2):
                continue
            for yy in range(Ly.h - 1, -1, -1):
                y = Ly.oy + yy
                if y > y1 + 2:
                    continue
                if px[xx, yy][3]:
                    bottoms[x] = max(bottoms.get(x, -1), y)
                    break
    if not bottoms:
        return
    xs = sorted(bottoms)
    xa, xb = xs[0], xs[-1]
    mid = (xa + xb) / 2.0
    for x in xs:
        u = abs(x - mid) / max(1.0, (xb - xa) / 2.0)
        if h2(x // 3, 1, x0) > 0.28:
            L.p(x, bottoms[x] + 1, "wa2" if u < 0.75 else "wa1")
        if u < 0.7 and h2(x // 4, 2, x0) > 0.55:
            L.p(x, bottoms[x] + 4, "wa1")
    # 两头水纹往外拖一点
    for side, xe in ((-1, xa), (1, xb)):
        ye = bottoms[xe]
        for j in range(1, 6):
            if j % 3:
                L.p(xe + side * j, ye + 1 + j // 3, "wa1")
    # 船头小 V
    xe = xb if bow > 0 else xa
    ye = bottoms[xe]
    for j in range(1, 5):
        L.p(xe + bow * j, ye - 1 - j // 2, "wa2")
        L.p(xe + bow * j, ye + j // 2, "wa2")


def draw_water_deco(float_pts, boat_layers):
    L = Layer(0, 300, W, 500)
    rnd = random.Random(909)
    draw_lotus_pads(L, rnd)
    # 亭子台沿下的桩：水纹
    for px in (626, 672, 858, 904):
        ripple(L, px + 2, 672, 5)
        ripple(L, px + 2, 675, 3, "wa1", "wa1")
    for x in range(619, 917):
        if 720 <= x < 816:
            continue
        if (x * 5) % 9 < 5:
            L.p(x, 663, "wa1")
    # 栈道两边：水线
    for y in range(664, 770, 2):
        if h2(y, 1, 5) > 0.35:
            L.p(714, y, "wa1")
            L.p(823, y, "wa1")
    # 码头两边的桩：桩脚一圈水纹；码头边一道断断续续的水线
    for y in (616, 674, 732):
        for sx in (311, 463):
            ripple(L, sx + 3, y + 9, 5)
            ripple(L, sx + 3, y + 12, 3, "wa1", "wa1")
    for y in range(564, 770, 3):
        if h2(y, 3, 7) > 0.55:
            L.p(316, y, "wa1")
            L.p(465, y, "wa1")
    # 船
    for name, bow in (("rowboat_1", 1), ("rowboat_2", 1), ("rowboat_3", -1), ("swanboat_1", -1), ("swanboat_2", -1)):
        boat_ripples(L, item(name)["rect"], boat_layers[name], bow)
    # 浮漂一圈圈
    for (fx, fy) in float_pts:
        for (rx, col) in ((3, "wa2"), (6, "wa1")):
            for i in range(-rx, rx + 1):
                if abs(i) > 1 or rx == 6:
                    L.p(fx + i, fy + 1 + (1 if abs(i) == rx else 0) - (rx == 6), col)
    # 荷叶边上的小水纹
    for (pid, fid) in LOTUS:
        it = item(pid)
        for k in range(5):
            x = int(it["x"] + rnd.uniform(-it["rx"] - 8, it["rx"] + 8))
            y = int(it["y"] + it["ry"] + rnd.uniform(1, 6))
            if not L.has(x, y):
                ripple(L, x, y, 3, "wa1", "wa1")
    return L


# ================================================================== 临时底图（照分区图，简单垫一张，GPT 底图到了就换）
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


def flower(L, x, y, kind):
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
    elif kind == "blue":
        L.p(x, y, "bl3")
        L.p(x + 1, y, "bl4")
        L.p(x, y + 1, "bl2")
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
    area_px = (x1 - x0) * (y1 - y0)
    for _ in range(int(area_px / 9000 * dens)):
        fx = rnd.randrange(x0, x1)
        fy = rnd.randrange(y0, y1)
        if not is_ramp(L.g(fx, fy), "gr"):
            continue
        kind = rnd.choice(["daisy", "daisy", "yellow", "yellow", "pink", "blue", "white", "white"])
        for _ in range(rnd.randint(3, 8)):
            xx = fx + rnd.randint(-9, 9)
            yy = fy + rnd.randint(-6, 6)
            if is_ramp(L.g(xx, yy), "gr") and is_ramp(L.g(xx + 1, yy + 1), "gr"):
                L.shade_px(xx, yy + 1, -1)
                flower(L, xx, yy, kind)


def dirt(x, y, seed):
    n = vnoise(x, y, 26, seed) * 0.65 + vnoise(x, y, 7, seed + 1) * 0.35
    if n < 0.36 or (n < 0.38 and (x + y) % 2):
        return "fl4"
    if n > 0.68 or (n > 0.66 and (x + y) % 2):
        return "fl6"
    return "fl5"


def temp_base():
    L = Layer(0, 0, W, H)
    px = L.px
    rnd = random.Random(7)
    # ---- 天、云
    for y in range(0, 320):
        for x in range(W):
            if y < 10 or (y < 16 and (x + y) % 2 == 0):
                c = "bl3"
            elif y < 70 or (y < 78 and (x + y) % 2 == 0):
                c = "bl4"
            else:
                c = "wa2"
            px[x, y] = C[c]
    for (cx, cy, s) in ((180, 30, 1.0), (560, 20, 0.7), (980, 34, 1.2), (1360, 22, 0.8)):
        for k in range(7):
            ex = cx + (k - 3) * 22 * s + rnd.uniform(-6, 6)
            ey = cy - (8 if 1 <= k <= 4 else 0) * s + rnd.uniform(-3, 3)
            r = (16 - abs(k - 3) * 2.5) * s
            L.ell(ex - r * 1.3, ey - r, ex + r * 1.3, ey + r * 0.6, "wt")
        for x in range(int(cx - 90 * s), int(cx + 90 * s)):
            for y in range(int(cy), int(cy + 10 * s)):
                if L.g(x, y) == C["wt"] and (y > cy + 2 * s or (x + y) % 2 == 0):
                    L.p(x, y, "bl4")
    # ---- 远山三层、对岸树林、草坡
    def ridge(x, base, amp, cell, seed):
        return base - amp * (vnoise(x, 0, cell, seed) * 0.7 + vnoise(x, 0, cell / 3.0, seed + 1) * 0.3)

    hills = [(96, 46, 260, 21, ("wa0", "wa1", "wa2")), (140, 48, 200, 23, ("hz0", "hz1", "hz2")),
             (184, 40, 150, 25, ("gA", "hz0", "hz1"))]
    for (base, amp, cell, seed, (dk, md, lt)) in hills:
        for x in range(W):
            yt = int(ridge(x, base, amp, cell, seed))
            slope = ridge(x + 3, base, amp, cell, seed) - ridge(x - 3, base, amp, cell, seed)
            for y in range(max(0, yt), 320):
                c = md
                if y < yt + 2 and slope < -0.3:
                    c = lt
                elif slope > 0.6 and y < yt + 6 + slope * 5:
                    c = dk if (y < yt + 4 + slope * 3 or (x + y) % 2 == 0) else md
                px[x, y] = C[c]
    # 对岸树林：一个个圆冠
    for x0 in range(-10, W + 20, 13):
        cx = x0 + rnd.randint(-4, 4)
        cy = 228 + rnd.randint(-8, 8)
        r = rnd.randint(10, 17)
        L.ell(cx - r, cy - r, cx + r, cy + r + 30, "nl2")
        L.ell(cx - r + 2, cy - r + 1, cx + r - 6, cy + 2, "nl3")
        L.ell(cx - r + 4, cy - r + 2, cx - 2, cy - r + 8, "gr3")
        L.ell(cx + 2, cy + 2, cx + r, cy + r + 20, "nl1", only=lambda a, b: (a + b) % 2 == 0 or b > cy + 8)
    for y in range(262, 312):
        for x in range(W):
            n = vnoise(x, y * 2, 40, 27)
            c = "gA" if n < 0.45 else ("gr3" if n < 0.8 else "gB")
            if y < 268 and (x + y) % 2 == 0:
                c = "nl1"
            px[x, y] = C[c]
    for x in range(W):
        yb = 304 + int(vnoise(x, 0, 14, 28) * 6)
        for y in range(yb, 312):
            px[x, y] = C["gr1" if (x + y) % 3 else "sv0"]
    # ---- 湖水：远处深、靠岸浅；顶上一道对岸的倒影；横的波纹
    LK = ["lk0", "lk1", "lk2", "wa0"]
    for y in range(310, 772):
        d = (y - 310) / 460.0
        for x in range(W):
            n = vnoise(x, y * 3.0, 70, 41) * 0.6 + vnoise(x, y * 2.0, 19, 42) * 0.4
            v = d * 1.05 + (n - 0.5) * 0.32
            if y < 334:
                v = min(v, 0.05 + (y - 310) / 160.0)
            idx = 0 if v < 0.2 else (1 if v < 0.56 else (2 if v < 0.88 else 3))
            for j, t in enumerate((0.2, 0.56, 0.88)):
                if abs(v - t) < 0.025:
                    idx = j + 1 if (x + y) % 2 == 0 else j
            px[x, y] = C[LK[idx]]
    for _ in range(5200):
        y = rnd.randrange(318, 764)
        x = rnd.randrange(0, W)
        ln = rnd.randint(3, 6 + int((y - 310) / 40))
        k = 1 if rnd.random() < 0.7 else -1
        for i in range(ln):
            L.shade_px(x + i, y, k)
        if k > 0 and rnd.random() < 0.5:
            for i in range(1, ln - 1):
                L.shade_px(x + i, y + 1, -1)
    for _ in range(160):
        x = rnd.randrange(0, W)
        y = rnd.randrange(360, 760)
        L.p(x, y, "wa2")
        L.p(x + 1, y, "wa1")
    # ---- 岸：湿沙一道、沙、卵石，挨草那边草探进来
    for x in range(W):
        yw = 766 + int(vnoise(x, 0, 23, 51) * 6)
        yg = 792 + int(vnoise(x, 0, 17, 52) * 6)
        for y in range(yw, yg):
            if y < yw + 2:
                c = "wa1" if (x + y) % 3 else "wa2"
            elif y < yw + 5:
                c = "fl3" if (x + y) % 2 else "fl4"
            else:
                n = vnoise(x, y, 9, 53)
                c = "fl5" if n < 0.45 else ("fl6" if n < 0.85 else "fl7")
            px[x, y] = C[c]
        for y in range(yg, 800):
            px[x, y] = C[grass_tone(x, y)]
    for _ in range(900):
        x = rnd.randrange(0, W)
        y = rnd.randrange(772, 794)
        if is_ramp(L.g(x, y), "fl") and is_ramp(L.g(x + 3, y + 2), "fl"):
            c = rnd.choice(["sv1", "sv2", "sv0", "fl7"])
            L.hl(x, x + rnd.randint(1, 3), y, c)
            L.p(x + 1, y + 1, shift(c, -1))
    # ---- 草地
    for y in range(800, 1160):
        for x in range(W):
            px[x, y] = C[grass_tone(x, y)]
    # 土路：东西一条 x 80～1536、y 940～1006；往北接湖岸一条 x 740～798、y 795～940
    def edge(v, seed):
        return int(round((vnoise(v, 0, 13, seed) - 0.5) * 5))

    for x in range(76, W):
        a = 941 + edge(x, 83)
        b = 1005 + edge(x, 84)
        if x < 96:
            k = (96 - x) // 3
            a += k
            b -= k
        for y in range(a, b):
            px[x, y] = C[dirt(x, y, 85)]
    for y in range(788, 950):
        a = 741 + edge(y, 80)
        b = 797 + edge(y, 81)
        for x in range(a, b):
            if y < 798 and not is_ramp(L.g(x, y), "fl") and not is_ramp(L.g(x, y), "gr"):
                continue
            px[x, y] = C[dirt(x, y, 82)]
    grass_details(L, rnd, (0, 798, W, 1158))
    for y in range(790, 1010):
        for x in range(60, W):
            c = L.g(x, y)
            if not is_ramp(c, "fl") or y < 800 and x < 735:
                continue
            if is_ramp(L.g(x - 1, y), "gr") or is_ramp(L.g(x, y - 1), "gr"):
                L.p(x, y, "fl3")
            elif is_ramp(L.g(x - 2, y), "gr") or is_ramp(L.g(x, y - 2), "gr"):
                L.p(x, y, "fl4")
    for (cy0, sd) in ((958, 93), (988, 94)):
        for x in range(90, W):
            cy = cy0 + int(round((vnoise(x, 0, 70, sd) - 0.5) * 3))
            if vnoise(x, cy, 9, sd + 5) < 0.14:
                continue
            L.p(x, cy - 1, "fl3")
            if vnoise(x, cy, 6, sd + 9) > 0.4:
                L.p(x, cy, "fl4")
    for _ in range(500):
        x = rnd.randrange(60, W)
        y = rnd.randrange(800, 1010)
        if is_ramp(L.g(x, y), "fl") and any(is_ramp(L.g(x + dx, y + dy), "gr") for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3))):
            tuft(L, x, y, rnd, 1)
    # ---- 南边矮灌木
    for y in range(1158, H):
        for x in range(W):
            v = vnoise(x, y, 7, 61)
            px[x, y] = C["gr1" if v < 0.6 else ("gr0" if v < 0.8 else "gr2")]
    for row, (yb, rr) in enumerate(((1162, (12, 20)), (1196, (14, 22)), (1236, (14, 24)))):
        x = -10 + row * 9
        while x < W + 20:
            r = rnd.randint(*rr)
            cy = yb + rnd.randint(-5, 5)
            L.ell(x - r, cy - r * 0.8, x + r, cy + r * 0.8, "gr2")
            L.ell(x - r + 2, cy - r * 0.8 + 1, x + r * 0.3, cy - r * 0.1, "gA")
            L.ell(x - r * 0.6, cy - r * 0.75, x - r * 0.1, cy - r * 0.4, "gr3")
            L.ell(x, cy - r * 0.1, x + r, cy + r * 0.8, "gr1", only=lambda a, b: (a + b) % 2 == 0 or b > cy + r * 0.3)
            x += int(r * 1.5)
    for _ in range(2600):
        x = rnd.randrange(0, W)
        y = rnd.randrange(1150, H)
        if is_ramp(L.g(x, y), "gr"):
            L.shade_px(x, y, 1 if rnd.random() < 0.6 else -1)
            L.shade_px(x + 1, y + 1, -1)
    return L


# ================================================================== 影子和倒影（叠在底图上）
def build_shade(objs):
    S = ShadeMap()
    # 亭子：台子在水上往东、往南投影；瓦顶的影子落在台子东边的水上
    S.rect(917, 428, 934, 664, -1.0, edge=True)
    S.rect(619, 662, 937, 682, -1.0, edge=True)
    S.rect(930, 412, 962, 540, -1.0, edge=True)
    # 台沿和桩的倒影：一道道断开的暗线
    for y in range(682, 700, 2):
        for x in range(622, 914):
            if (720 <= x < 816) or h2(x // 3, y, 3) < 0.35:
                continue
            S.add(x, y, -1.0)
    # 栈道、码头东边的影子
    S.rect(822, 654, 832, 772, -1.0, edge=True)
    S.rect(464, 562, 476, 772, -1.0, edge=True)
    S.rect(318, 798, 466, 801, -1.0)
    S.rect(716, 822, 824, 825, -1.0)
    # 船：船底的倒影（木船暗、白天鹅船亮），一行行断开
    for name in ("rowboat_1", "rowboat_2", "rowboat_3", "swanboat_1", "swanboat_2"):
        it = item(name)
        x0, y0, x1, y1 = it["rect"]
        val = 1.0 if name.startswith("swan") else -1.0
        for y in range(y1 + 2, y1 + 2 + it["h"] // 2 + 2):
            for x in range(x0 + 6, x1 - 6):
                if (y - y1) % 3 == 0 or h2(x // 4, y, 9) < 0.25:
                    continue
                S.add(x, y, val)
    # 柳树：树下一团碎影（往右下），树脚一圈更暗
    for tid, (fx, fy) in WILLOWS.items():
        if fy > H:
            continue
        S.blob(fx + 26, fy + 8, 66, 20, -1.0, fx + fy, wob=0.25)
        rnd = random.Random(fx)
        for _ in range(12):
            a = rnd.uniform(0, 6.283)
            r = rnd.uniform(0.2, 0.85)
            S.ellipse(fx + 26 + math.cos(a) * 60 * r, fy + 8 + math.sin(a) * 18 * r, rnd.uniform(2, 5), rnd.uniform(1, 2.5), 1.0, edge=1)
        S.ellipse(fx + 6, fy + 1, 16, 5, -1.0)
    # 长凳
    for prefix in ("bench", "bench2"):
        x0 = item(prefix + "_seat")["x0"]
        S.rect(x0 + 4, 948, x0 + 70, 972, -1.0, edge=True)
        S.ellipse(x0 + 44, 973, 40, 4, -1.0)
    # 芦苇、凳子、水桶
    for rid in ("reed_1", "reed_2", "reed_3"):
        xs = [p[0] for p in item(rid)["pts"]]
        S.ellipse((min(xs) + max(xs)) / 2 + 8, 801, 16, 3, -1.0)
    for sid in ("fish_stool_1", "fish_stool_2"):
        r = item(sid)["rect"]
        S.ellipse((r[0] + r[2]) / 2 + 4, r[3] + 1, 13, 3, -1.0)
    for bid in ("fish_bucket_1", "fish_bucket_2"):
        it = item(bid)
        S.ellipse(it["x"] + 3, it["y"] + it["ry"], 9, 2.5, -1.0)
    return S


# ================================================================== 组装、出图
def build_objects():
    """返回 [(name, layer, foot_y, foot_x, kind, hide)]；kind = flat（平的，先画）/ stand（按着地线排）"""
    objs = []

    def add(name, L, foot, fx, kind="stand", hide=()):
        objs.append((name, L, foot, fx, kind, list(hide)))

    add("pavilion_deck", draw_pavilion_deck(), 428, 768, "flat", [])
    add("boardwalk", draw_boardwalk(), 556, 768, "flat", [])
    add("dock", draw_dock(), 560, 390, "flat",
        ["dock_deck", "dock_plank_0", "dock_plank_1", "dock_plank_2", "dock_plank_3", "dock_plank_4", "dock_edge",
         "dock_post_0", "dock_post_1"])
    add("pavilion_roof", draw_pavilion_roof(), 438, 768, "stand",
        ["pavilion_roof", "pavilion_roof_edge", "post_nw", "post_ne"])
    add("pavilion_rail_w", draw_side_rail(-1), 452, 624)
    add("pavilion_rail_e", draw_side_rail(1), 452, 912)
    add("pavilion_front", draw_pavilion_front(), 652, 768, "stand", ["post_sw", "post_se"])
    dock_w = (322, 545)
    dock_e = (458, 545)
    add("rowboat_1", draw_rowboat("rowboat_1", 1, rope_to=dock_w), 612, 238, "stand", ["rowboat_1"])
    add("rowboat_2", draw_rowboat("rowboat_2", 1, rope_to=dock_w), 556, 238, "stand", ["rowboat_2"])
    b3, b3f = draw_rowboat("rowboat_3", -1, oars="out", split=True)
    add("rowboat_3", b3, 470, 1152, "stand", ["rowboat_3"])
    add("rowboat_3_front", b3f, 474, 1152, "stand", [])
    add("swanboat_1", draw_swanboat("swanboat_1", rope_to=dock_e), 612, 530, "stand", ["swanboat_1"])
    add("swanboat_2", draw_swanboat("swanboat_2", rope_to=dock_e), 556, 530, "stand", ["swanboat_2"])
    for tid, (fx, fy) in WILLOWS.items():
        add(tid, draw_willow(tid), fy, fx, "stand", [tid])
    for prefix in ("bench", "bench2"):
        add(prefix, draw_bench(prefix), 972, item(prefix + "_seat")["x0"] + 36, "stand",
            [prefix + "_seat", prefix + "_leg_w", prefix + "_leg_e", prefix + "_back"])
    for (pid, fid) in LOTUS:
        add(pid + "_flowers", draw_lotus_stand(pid, fid), item(fid)["y"], item(pid)["x"], "stand", [fid])
    for rid in ("reed_1", "reed_2", "reed_3"):
        xs = [p[0] for p in item(rid)["pts"]]
        add(rid, draw_reed(rid), 800, (min(xs) + max(xs)) // 2, "stand", [rid])
    floats = []
    for k in (1, 2):
        r = item("fish_stool_%d" % k)["rect"]
        add("fish_stool_%d" % k, draw_stool("fish_stool_%d" % k), r[3], (r[0] + r[2]) // 2, "stand", ["fish_stool_%d" % k])
        rod, fpt = draw_rod("fish_rod_%d" % k)
        floats.append(fpt)
        add("fish_rod_%d" % k, rod, 823, item("fish_rod_%d" % k)["pts"][0][0], "stand", ["fish_rod_%d" % k])
        it = item("fish_bucket_%d" % k)
        add("fish_bucket_%d" % k, draw_bucket("fish_bucket_%d" % k), it["y"] + it["ry"], it["x"], "stand", ["fish_bucket_%d" % k])
    return objs, floats


DUCKS = {"duck_1": (992, 420, 0), "duck_2": (1022, 432, 2)}   # 脚点（身子正中、水线）和静止时用第几帧


def duck_layers(sheet):
    out = []
    for name, (x, y, fr) in DUCKS.items():
        L = Layer(x - DUCK_ANCHOR[0], y - DUCK_ANCHOR[1], DUCK_FW, DUCK_FH)
        L.im = sheet.crop((fr * DUCK_FW, 0, fr * DUCK_FW + DUCK_FW, DUCK_FH))
        L.px = L.im.load()
        out.append((name, L, y, x, "anim", [name]))
    return out


def paste_clip(out, im, x, y):
    tmp = Image.new("RGBA", out.size, (0, 0, 0, 0))
    tmp.paste(im, (x, y))
    out.alpha_composite(tmp)


def put_layer(out, L):
    if L.ox >= 0 and L.oy >= 0 and L.ox + L.w <= out.width and L.oy + L.h <= out.height:
        out.alpha_composite(L.im, (L.ox, L.oy))
    else:
        paste_clip(out, L.im, L.ox, L.oy)


def compose(base_im, water, objs, people=()):
    out = base_im.copy() if base_im is not None else Image.new("RGBA", (W, H), (0, 0, 0, 0))
    put_layer(out, water)
    for (name, L, foot, fx, kind, hide) in sorted([o for o in objs if o[4] == "flat"], key=lambda o: o[2]):
        put_layer(out, L)
    seq = [(foot, 0, fx, L) for (name, L, foot, fx, kind, hide) in objs if kind != "flat"]
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


def quantize_base(path):
    """GPT 底图压到这套调色板（最近色，不抖动）"""
    src = Image.open(path).convert("RGB")
    if src.size != (W, H):
        if src.size == (W * 2, H * 2):
            src = src.resize((W, H), Image.NEAREST)
        else:
            raise SystemExit("底图尺寸 %s，要 1536×1280（或 3072×2560）" % (src.size,))
    pal_img = Image.new("P", (1, 1))
    flat = []
    names = list(PAL_HEX)
    for n in names:
        flat.extend(C[n][:3])
    flat.extend(flat[:3] * (256 - len(names)))
    pal_img.putpalette(flat)
    q = src.quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGBA")
    L = Layer(0, 0, W, H)
    L.im = q
    L.px = L.im.load()
    return L


def main():
    args = sys.argv[1:]
    check_layout()
    label = next((a for a in args if a.startswith("round")), None)
    base_path = args[args.index("--base") + 1] if "--base" in args else None
    os.makedirs(LAYER_DIR, exist_ok=True)
    objs, floats = build_objects()
    sheet = draw_duck_sheet()
    objs += duck_layers(sheet)
    boat_layers = {}
    for (name, L, foot, fx, kind, hide) in objs:
        if name.startswith("rowboat") or name.startswith("swanboat"):
            boat_layers.setdefault(name.replace("_front", ""), []).append(L)
    water = draw_water_deco(floats, boat_layers)
    shade = build_shade(objs)
    base = temp_base()
    shade.apply(base)
    used = palette_check(base.im, "临时底图") | palette_check(water.im, "水面装饰层") | palette_check(sheet, "鸭子")
    for (name, L, foot, fx, kind, hide) in objs:
        used |= palette_check(L.im, name)
    print("调色板：定义 %d 色，这块画布用到 %d 色" % (len(PAL_SET), len(used)))
    if len(used) > 64:
        raise SystemExit("超过 64 色（%d）" % len(used))
    # ---- 存每一层（裁到有东西的地方、不出画布）
    man = {"note": "draw_lake.py 生成，别手改。每张图左上角放在 x、y（画布坐标），1 倍、不插值；"
                   "kind：flat = 平的（台面、栈道、码头，比人先画），stand = 立着的（按 foot_y 跟人排前后），"
                   "anim = 会动的（鸭子，帧图见 sheet）；water 层紧贴底图，比 flat 还先画；"
                   "hide = 进游戏时要藏掉的灰盒（挡人的占地照旧）",
           "canvas": [W, H],
           "base": {"png": "bg_lake_temp.png", "x": 0, "y": 0, "temp": True,
                    "note": "临时底图（影子、倒影已经叠进去了）；GPT 底图到了用 --base 出 bg_lake.png 换掉"},
           "shade": {"png": "shade_lake.png", "note": "影子和倒影：灰度 128 = 不动，每 ±40 = 沿色带挪 1 档；叠在压过色的底图上"},
           "layers": []}
    keep = set()

    def save(L, fname):
        bb = L.im.getbbox()
        bb = (max(bb[0], -L.ox), max(bb[1], -L.oy), min(bb[2], W - L.ox), min(bb[3], H - L.oy))
        L.im.crop(bb).save(os.path.join(LAYER_DIR, fname))
        keep.add(fname)
        return L.ox + bb[0], L.oy + bb[1], bb[2] - bb[0], bb[3] - bb[1]

    x, y, w, h = save(water, "water_deco.png")
    man["layers"].append({"name": "water_deco", "png": "water_deco.png", "x": x, "y": y, "w": w, "h": h,
                          "foot_y": None, "kind": "water", "hide": ["lotus_1", "lotus_2", "lotus_3"]})
    for (name, L, foot, fx, kind, hide) in sorted(objs, key=lambda o: (o[4] != "flat", o[2], o[3])):
        x, y, w, h = save(L, name + ".png")
        e = {"name": name, "png": name + ".png", "x": x, "y": y, "w": w, "h": h, "foot_y": foot, "foot_x": fx,
             "kind": kind, "hide": hide}
        if kind == "anim":
            e["sheet"] = {"png": "duck_sheet.png", "frame": [DUCK_FW, DUCK_FH], "anchor": list(DUCK_ANCHOR),
                          "frames": {"left": [0, 1, 2, 3], "right": [4, 5, 6, 7]}, "fps": 4,
                          "note": "脚点 anchor 对准 (foot_x, foot_y)；静止时这张就是其中一帧"}
        man["layers"].append(e)
    sheet.save(os.path.join(LAYER_DIR, "duck_sheet.png"))
    keep.add("duck_sheet.png")
    base.im.save(os.path.join(LAYER_DIR, "bg_lake_temp.png"))
    keep.add("bg_lake_temp.png")
    shade.mask_image().save(os.path.join(LAYER_DIR, "shade_lake.png"))
    keep.add("shade_lake.png")
    use_base = base
    if base_path:
        gb = quantize_base(base_path)
        shade.apply(gb)
        palette_check(gb.im, "GPT 底图")
        gb.im.save(os.path.join(LAYER_DIR, "bg_lake.png"))
        keep.add("bg_lake.png")
        man["base"] = {"png": "bg_lake.png", "x": 0, "y": 0, "temp": False,
                       "note": "GPT 底图压到 64 色、叠了影子和倒影（%s）" % os.path.basename(base_path)}
        use_base = gb
    with open(os.path.join(LAYER_DIR, "layers.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    keep.add("layers.json")
    for f in os.listdir(LAYER_DIR):
        if f not in keep:
            os.remove(os.path.join(LAYER_DIR, f))
    # ---- 预览
    compose(None, water, objs).save(os.path.join(HERE, "lake01_objects_only.png"))
    full = compose(use_base.im, water, objs)
    full.save(os.path.join(HERE, "lake01_full.png"))
    people = [(guest(3, 12), 768, 596), (guest(9, 0), 768, 736), (guest(5, 4), 420, 700)]
    px0, py0 = 420, 262
    phone = compose(use_base.im, water, objs, people).crop((px0, py0, px0 + 540, py0 + 960))
    phone.save(os.path.join(HERE, "lake01_phone.png"))
    det = compose(use_base.im, water, objs, people).crop((150, 276, 960, 900))
    det.resize((det.width * 2, det.height * 2), Image.NEAREST).save(os.path.join(HERE, "lake01_detail_x2.png"))
    # 对照：果园 | 湖边 | 宴会厅，各裁 360×360，同放大 2 倍
    panels = []
    if os.path.exists(ORCHARD_FULL):
        panels.append(Image.open(ORCHARD_FULL).convert("RGBA").crop((720, 340, 1080, 700)))
    panels.append(full.crop((588, 292, 948, 652)))
    if os.path.exists(BANQUET):
        panels.append(Image.open(BANQUET).convert("RGBA").crop((560, 0, 920, 360)))
    gap = 8
    cmp_im = Image.new("RGBA", (len(panels) * 720 + (len(panels) - 1) * gap, 720), C["ol"])
    for i, p in enumerate(panels):
        cmp_im.paste(p.resize((720, 720), Image.NEAREST), (i * (720 + gap), 0))
    cmp_im.save(os.path.join(HERE, "lake01_compare.png"))
    if label:
        full.save(os.path.join(HERE, label + ".png"))
        shutil.copy(os.path.abspath(__file__), os.path.join(HERE, "draw_lake_r%s.py" % label[5:]))
    print("出好了：layers/ %d 张、整块、手机、放大、对照%s" % (len(keep), "，存了 " + label if label else ""))


if __name__ == "__main__":
    main()
