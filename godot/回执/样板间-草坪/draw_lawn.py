#!/usr/bin/env python3
"""lawn01：用代码画罗曼山庄「草坪」上立着的每一件东西（像素硬边、1 倍颗粒、这块画布 ≤64 色）。

分工（阿鱼 10/3 晚）：草坪的底图（草地、灌木边、碎石小路、孩童区沙地）由 GPT 画；这里只画上面立着的东西，
一件一张透明图，等 GPT 底图到了直接叠上去。在那之前用果园的草地、路画法垫一张简单的临时底图。

只读：layout.json（位置）、定稿人物图（预览当尺子）、果园成品图和宴会厅底图（只拿来拼对照图）。只写：本脚本所在目录。
用法：
  python3 draw_lawn.py [roundN]        出 layers/、预览图；给了 roundN 再存一张 roundN.png 和脚本存档
  python3 draw_lawn.py --gpt 图.png    GPT 底图到了：压到同一套色板、叠影子，出 layers/bg_lawn_gpt.png 和 lawn01_full_gpt.png
  python3 draw_lawn.py --snapshot      打印 layout 现在的摆法快照（01 有意改了摆法以后，用它换掉脚本里的 LAYOUT_SNAPSHOT）

坐标全用游戏画布坐标（1536×1024），1 个美术像素 = 1 个画布像素。
斜俯视、没有透视：地面前后 1 米 = 32 像素，左右和高 1 米 = 48 像素。
一件东西 = 占地（x0..x1, y0..y1）+ 高 h；正面从 y1 往上画 h，顶面画在 y0-h..y1-h。光从左上来，影子落右下。
"""
import hashlib
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
LAYOUT = REPO + "/godot/assets/layered/scene_luoman_lawn/layout.json"
CHAR_DIR = REPO + "/godot/assets/characters/lm/"
ORCHARD_FULL = REPO + "/godot/回执/样板间-果园/orchard01_full.png"
BANQUET = REPO + "/godot/assets/layered/scene_roman_banquet_55/base.png"
LAYER_DIR = os.path.join(HERE, "layers")
QUICK = "--quick" in sys.argv      # 只画仪式区和几棵树、不出 layers，看图用
W, H = 1536, 1024

# ------------------------------------------------------------------ 调色板
# 同名颜色跟室内样板（休息间、化妆间）、果园一个值。这块画布新加的颜色：没有（全是已有的名字）
PAL_HEX = {
    "ol": "#22140f",
    "wd0": "#3a2218", "wd1": "#552f1f", "wd2": "#71402a", "wd3": "#8f5535", "wd4": "#ad6d40", "wd5": "#c98d58",
    "fl0": "#5a3e2e", "fl1": "#765238", "fl2": "#8e6846", "fl3": "#a67c54", "fl4": "#ba8e60", "fl5": "#c89e6c",
    "fl6": "#d6b07e", "fl7": "#e6c696",
    "wl2": "#d0b892", "wl3": "#e2cca6", "wl4": "#efdfc0", "wl5": "#f9efda",
    "rd0": "#3d0e13", "rd1": "#62181b", "rd2": "#8a2321", "rd3": "#b1332a", "rd4": "#d24f39", "rd5": "#ea8152",
    "gd0": "#563610", "gd1": "#87591c", "gd2": "#b8862b", "gd3": "#deb550", "gd4": "#f7e09a",
    "wt": "#fdfbf3",
    "sv0": "#737a8f", "sv1": "#a3abbe", "sv2": "#d3d8e3",
    "bl2": "#385a90", "bl3": "#6c8fbd", "bl4": "#b0c6de",
    "gr0": "#1b3022", "gr1": "#284a2c", "gr2": "#3f6935", "gA": "#527d3a", "gr3": "#649340",
    "gB": "#7fa84a", "gr4": "#9cbd5e", "gC": "#c5d888",
    "nl1": "#234536", "nl2": "#31593c", "nl3": "#477a45",
    "pk0": "#a8455e", "pk": "#de8399", "pk2": "#f4bfc8",
}


def hex2rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


C = {k: hex2rgba(v) for k, v in PAL_HEX.items()}
# 色带（暗 → 亮）。同一个颜色在几条色带里时，后写的说了算（背景挪档按草、路、沙走）
RAMPS = {
    "lf": ["gr0", "nl1", "nl2", "nl3", "gr3", "gB"],
    "wd": ["wd0", "wd1", "wd2", "wd3", "wd4", "wd5"],
    "rd": ["rd0", "rd1", "rd2", "rd3", "rd4", "rd5"],
    "gd": ["gd0", "gd1", "gd2", "gd3", "gd4"],
    "wh": ["sv0", "sv1", "sv2", "wt"],
    "pk": ["pk0", "pk", "pk2"],
    "bl": ["bl2", "bl3", "bl4"],
    "fl": ["fl0", "fl1", "fl2", "fl3", "fl4", "fl5", "fl6", "fl7"],
    "wl": ["fl5", "fl6", "wl2", "wl3", "wl4", "wl5"],
    "gr": ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"],
}
RAMP_OF = {}
for _rn, _names in RAMPS.items():
    for _i, _n in enumerate(_names):
        RAMP_OF[C[_n]] = (_rn, _i)
PAL_SET = set(C.values())
assert len(PAL_SET) <= 64


def shift(col, k):
    """颜色沿自己的色带挪 k 档（负数变暗），不在色带里的不动"""
    c = C[col] if isinstance(col, str) else col
    if k == 0 or c not in RAMP_OF:
        return c
    rn, i = RAMP_OF[c]
    names = RAMPS[rn]
    return C[names[max(0, min(len(names) - 1, i + k))]]


def rname(ramp, i):
    names = RAMPS[ramp] if isinstance(ramp, str) else ramp
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


LIGHT = (-0.55, -0.62, 0.56)


def norm3(v):
    n = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) or 1.0
    return (v[0] / n, v[1] / n, v[2] / n)


LIGHT = norm3(LIGHT)


def dot3(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


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
        x = int(math.floor(x)) - self.ox
        y = int(math.floor(y)) - self.oy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = self.c(col)

    def g(self, x, y):
        x = int(math.floor(x)) - self.ox
        y = int(math.floor(y)) - self.oy
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
        """不透明区外面一圈 1 像素描边；pick(x, y, 邻居颜色) 可以按邻居换描边色，回 None 不描"""
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


class ShadeMap:
    """地上的明暗图：每个像素一个数（负 = 暗、正 = 亮），最后取整到半档，半档用棋盘格"""

    def __init__(self):
        self.v = array("f", [0.0]) * (W * H)

    def add(self, x, y, val):
        x, y = int(x), int(y)
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

    def step(self, x, y):
        s = self.v[y * W + x]
        if -0.2 < s < 0.2:
            return 0
        s = round(s * 2) / 2.0
        k = math.floor(s)
        if s - k > 0.25 and (x + y) % 2 == 0:
            k += 1
        return int(k)

    def apply(self, layer):
        for y in range(max(0, layer.oy), min(H, layer.oy + layer.h)):
            for x in range(max(0, layer.ox), min(W, layer.ox + layer.w)):
                k = self.step(x, y)
                if k:
                    layer.shade_px(x, y, k)

    def to_image(self):
        """影子档数图：灰 = 128 + 32×档数（-1 → 96，-2 → 64，+1 → 160），透明 = 不动"""
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        px = im.load()
        for y in range(H):
            for x in range(W):
                k = self.step(x, y)
                if k:
                    g = max(0, min(255, 128 + 32 * k))
                    px[x, y] = (g, g, g, 255)
        return im


# ------------------------------------------------------------------ 布局核对
G_KEYS = ("type", "rect", "h", "deco", "x0", "x1", "top", "thick", "foot", "pts", "block", "x", "y", "w", "rx", "ry", "e")


def layout_snapshot(d):
    snap = {"items": {i["id"]: {k: i[k] for k in G_KEYS if k in i} for i in d["items"]},
            "size": d["size"], "walk": d["walk"],
            "points": {p["id"]: [p["x"], p["y"], p["r"]] for p in d["points"]},
            "flat": [f["rect"] for f in d["flat"] if f.get("type") == "rect"],
            "npcs": {n["id"]: [n["x"], n["y"]] for n in d["npcs"]}}
    return snap


LAYOUT_SNAPSHOT = None   # 下面文件末尾填


def check_layout():
    d = json.load(open(LAYOUT, encoding="utf-8"))
    now = layout_snapshot(d)
    want = json.loads(LAYOUT_SNAPSHOT)
    bad = []
    for k in ("size", "walk", "flat", "points", "npcs"):
        if now[k] != want[k]:
            bad.append("%s 变了" % k)
    for iid, g in want["items"].items():
        if iid not in now["items"]:
            bad.append("%s 不见了" % iid)
        elif now["items"][iid] != g:
            bad.append("%s 变了：%s → %s" % (iid, json.dumps(g, ensure_ascii=False), json.dumps(now["items"][iid], ensure_ascii=False)))
    for iid in now["items"]:
        if iid not in want["items"]:
            bad.append("多了 %s" % iid)
    if bad:
        raise SystemExit("layout.json 跟这版画的位置对不上（摆法改了，先停）：\n" + "\n".join(bad))
    return d


# ================================================================== 小零件（印章）
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
        L.shade_px(x + 1, y + 1, -2)
    elif kind == "white":
        L.p(x, y, "wt")
        L.shade_px(x + 1, y, -1)
    elif kind == "yellow":
        L.p(x, y, "gd4")
        L.p(x + 1, y, "gd3")
        L.shade_px(x + 1, y + 1, -2)


def pebble(L, x, y, rnd):
    w = rnd.randint(2, 4)
    L.hl(x, x + w, y, "fl7")
    L.hl(x, x + w, y + 1, "fl4")
    L.hl(x, x + w + 1, y + 2, shift(L.g(x, y + 2), -1) if L.has(x, y + 2) else "fl2")


# 花：白玫瑰、粉玫瑰、红玫瑰、绣球、满天星。色 = (亮, 中, 暗)
FLOWER_COLS = {"w": ("wt", "sv2", "sv1"), "p": ("pk2", "pk", "pk0"), "r": ("rd5", "rd4", "rd2"),
               "c": ("wl5", "wl4", "wl3"), "y": ("gd4", "gd3", "gd2")}


def rose(L, x, y, kind, size, dark=0):
    """一朵玫瑰（左上亮、右下暗、中间一点旋）：size 3/4/5；dark 1 整朵在背光里"""
    a, b, c = FLOWER_COLS[kind]
    if dark:
        a, b, c = b, c, ("sv0" if kind == "w" else c)
    if size >= 7:
        pat = ["..aab..", ".aaaabb", "aabbbab", "aabcabc", "abacbbc", ".bbbcc.", "..ccc.."]
    elif size == 6:
        pat = [".aaab.", "aabbab", "abcabb", "abbcbc", ".bbcc.", "..cc.."]
    elif size <= 3:
        pat = ["ab.", "abc", ".cc"]
    elif size == 4:
        pat = [".aa.", "abab", "abbc", ".cc."]
    else:
        pat = [".aab.", "aabab", "abacb", "abbcc", ".bcc."]
    for j, row in enumerate(pat):
        for i, ch in enumerate(row):
            if ch == "a":
                L.p(x + i, y + j, a)
            elif ch == "b":
                L.p(x + i, y + j, b)
            elif ch == "c":
                L.p(x + i, y + j, c)


def hydrangea(L, x, y, kind, dark=0):
    """绣球：一团 6×5 的小四瓣花"""
    a, b, c = FLOWER_COLS[kind]
    if dark:
        a, b, c = b, c, ("sv0" if kind == "w" else c)
    pat = [".aab..", "aaabb.", "abaabc", "abbbcc", ".bccc."]
    for j, row in enumerate(pat):
        for i, ch in enumerate(row):
            if ch != ".":
                L.p(x + i, y + j, {"a": a, "b": b, "c": c}[ch])
    L.p(x + 2, y + 1, b)
    L.p(x + 3, y + 3, c)


def leaf_spray(L, x, y, ang, ln, ramp, tone):
    """一小枝叶子：一根细梗，两边交替小叶（2～3 像素）"""
    ca, sa = math.cos(ang), math.sin(ang)
    for t in range(ln):
        px_, py_ = x + ca * t, y + sa * t
        L.p(px_, py_, rname(ramp, tone - 1))
        if t % 2 == 1:
            s = 1 if (t // 2) % 2 else -1
            lx, ly = px_ - sa * s * 1.5, py_ + ca * s * 1.5
            L.p(lx, ly, rname(ramp, tone + (1 if s < 0 else 0)))
            L.p(lx + ca, ly + sa, rname(ramp, tone))


# ================================================================== 花丛（拱门花、台边花、通道花、椅背花都用它）
def bloom_mound(L, cx, foot, rx, hgt, seed, mix=None, leafy=0.0, droop=0, spikes=None):
    """一丛插花：几个高低不一的小圆顶拼成的绿叶底（不是一个球）、边上伸出去的叶枝、
    几朵大白玫瑰和绣球当主花、小花填空、边上一点满天星、一两枝高出来的白穗子。
    cx、foot 是脚点，rx 半宽，hgt 高。mix = {"w": 白玫瑰, "h": 白绣球, "p": 粉, "r": 红, "b": 满天星}"""
    rnd = random.Random(seed)
    mix = mix or {"w": 0.45, "h": 0.25, "p": 0.18, "b": 0.12}
    n_sub = 3 if rx < 12 else (4 if rx < 20 else 5)
    subs = []
    for i in range(n_sub):
        f = (i + 0.5) / n_sub - 0.5
        sx = cx + f * rx * 1.15 + rnd.uniform(-1.5, 1.5)
        hh = hgt * (0.95 - 0.55 * abs(f) * 1.6 + rnd.uniform(-0.08, 0.08))
        hh = max(hgt * 0.45, min(hgt, hh))
        srx = rx * rnd.uniform(0.42, 0.56)
        subs.append((sx, foot - hh * 0.5, srx, hh * 0.5))
    pts = {}
    for (sx, sy, srx, sry) in subs:
        for y in range(int(sy - sry) - 1, int(foot)):
            for x in range(int(sx - srx) - 1, int(sx + srx) + 2):
                dx, dy = (x + 0.5 - sx) / srx, (y + 0.5 - sy) / sry
                d2 = dx * dx + dy * dy
                if d2 <= 1.0:
                    nz = math.sqrt(1 - d2)
                    hgt_here = nz * srx + (foot - sy) * 0.15
                    if hgt_here > pts.get((x, y), (-1e9, 0))[0]:
                        pts[(x, y)] = (hgt_here, dot3(norm3((dx, dy, nz + 0.25)), LIGHT))
    gr = ["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4"]
    for (x, y), (hh, lum) in pts.items():
        n = vnoise(x, y, 2.6, seed) - 0.5
        v = lum + n * 0.55
        t = 1 if v < -0.02 else (2 if v < 0.24 else (3 if v < 0.46 else (4 if v < 0.64 else 5)))
        L.p(x, y, gr[t])
    # 叶枝从边上伸出去（轮廓不圆）
    edge = [k for k in pts if (k[0] - 1, k[1]) not in pts or (k[0] + 1, k[1]) not in pts or (k[0], k[1] - 1) not in pts]
    for _ in range(int(3 + rx / 4)):
        if not edge:
            break
        x, y = rnd.choice(edge)
        ang = math.atan2(y - (foot - hgt * 0.4), x - cx) + rnd.uniform(-0.4, 0.4)
        leaf_spray(L, x, y, ang, rnd.randint(3, 6), gr, rnd.choice([3, 4, 4]))
    for _ in range(droop):
        sx = cx + rnd.uniform(-rx * 0.85, rx * 0.85)
        sy = foot - rnd.uniform(1, hgt * 0.35)
        leaf_spray(L, sx, sy, math.pi / 2 + rnd.uniform(-0.6, 0.6), rnd.randint(5, 9), gr, rnd.choice([3, 4]))
    # 高出来的白穗子
    n_sp = spikes or 0
    for _ in range(n_sp):
        sx = int(cx + rnd.uniform(-rx * 0.5, rx * 0.5))
        top = int(foot - hgt - rnd.uniform(3, 8))
        base = int(foot - hgt * 0.6)
        for y in range(top, base):
            L.p(sx, y, "gr2")
        for y in range(top, base - 3, 2):
            L.p(sx - 1, y, "wt")
            L.p(sx + 1, y + 1, "sv2")
            L.p(sx, y, "wt" if y < top + 6 else "sv2")
    # 花：主花先挑位置（每个小圆顶顶上一朵大的），再撒小的
    kinds = []
    for k, v in mix.items():
        kinds += [k] * int(v * 100)
    placed = []
    big_f = 7 if rx >= 22 else (6 if rx >= 13 else 5)
    for i_s, (sx, sy, srx, sry) in enumerate(subs):
        if leafy < 0.5:
            # 白玫瑰、白绣球轮着当主花（没给的那种就用给了的）
            k = ("w" if (i_s + seed) % 2 == 0 else "h") if ("w" in mix and "h" in mix) else ("w" if "w" in mix else rnd.choice(kinds))
            placed.append((sx + rnd.uniform(-srx * 0.3, srx * 0.2), sy - sry * 0.35, big_f if k == "w" else 5, k))
    keys = list(pts.keys())
    n_target = int(len(keys) / (30 - 18 * (1 - leafy))) if keys else 0
    tries = 0
    while len(placed) < n_target + n_sub and tries < n_target * 40 + 40:
        tries += 1
        x, y = rnd.choice(keys)
        k = rnd.choice(kinds)
        sz = 2 if k == "b" else (5 if k == "h" else rnd.choice([3, 3, 4]))
        if k == "b" and pts[(x, y)][1] > 0.6 and rnd.random() < 0.6:
            continue
        if any((x - a) ** 2 + (y - b) ** 2 < ((sz + s2) * 0.45) ** 2 for (a, b, s2, _k) in placed):
            continue
        placed.append((x, y, sz, k))
    # 小花先画，主花（大的）最后压在上面，一朵朵看得出来
    placed.sort(key=lambda t: (t[2] >= 6, t[1]))
    for (x, y, sz, k) in placed:
        lum = pts.get((int(x), int(y)), (0, 0.3))[1]
        dark = 1 if lum < 0.08 else 0
        xi, yi = int(x - sz / 2), int(y - sz / 2)
        if k == "b":
            L.p(xi, yi, "wt" if not dark else "sv2")
            if rnd.random() < 0.5:
                L.p(xi + 1, yi - 1, "sv2" if not dark else "sv1")
        elif k == "h":
            hydrangea(L, xi, yi, "w", dark)
        else:
            if sz >= 6:
                # 主花垫一圈深绿的边（叶子的缝），跟旁边的白花分得开
                rr = sz / 2.0 + 0.9
                for yy in range(yi - 1, yi + sz + 1):
                    for xx in range(xi - 1, xi + sz + 1):
                        if (xx + 0.5 - (xi + sz / 2.0)) ** 2 + (yy + 0.5 - (yi + sz / 2.0)) ** 2 <= rr * rr:
                            L.p(xx, yy, "gr2")
            rose(L, xi, yi, k, sz, dark)
    return pts


# ================================================================== 白椅子（背对镜头，客人朝北看仪式台）
def chair_parts(x0, foot, kind):
    """返回 (整张椅子, 只有椅背) 两层。kind: plain / aisleL（右边椅背系纱和花）/ aisleR（左边）。
    椅子背对镜头：顶上一道比立柱宽一点的弯顶横档（一排椅子里每把的「帽子」分得开）、两根竖撑、
    空当里露出奶白坐垫、座下横档；腿细、往外叉一点，不画横撑（免得一列椅子连成栅栏）"""
    top = foot - 46
    full = Layer(x0 - 5, top - 4, 32, 52)
    back = Layer(x0 - 5, top - 4, 32, 52)

    def P(L, c, r, col):
        L.p(x0 + c, top + r, col)

    for L, only_back in ((full, False), (back, True)):
        if not only_back:
            for bay0 in (3, 9, 15):
                for r in range(17, 23):
                    for c in range(bay0, bay0 + 4):
                        col = "wl4"
                        if r == 17:
                            col = "wl3"
                        elif r <= 19 and c <= bay0 + 1:
                            col = "wl5"
                        elif c == bay0 + 3:
                            col = "wl3"
                        P(L, c, r, col)
        # 立柱（椅背两边）
        for r in range(4, 26):
            P(L, 1, r, "wt")
            P(L, 2, r, "sv2")
            P(L, 19, r, "wt")
            P(L, 20, r, "sv1")
            P(L, 0, r, "ol")
            P(L, 21, r, "ol")
        # 竖撑
        for r in range(4, 23):
            P(L, 7, r, "wt")
            P(L, 8, r, "sv1")
            P(L, 13, r, "wt")
            P(L, 14, r, "sv1")
        # 弯顶横档：比立柱各宽出一格，中间高一格
        for c in range(0, 22):
            mid = 4 <= c <= 17
            P(L, c, 1 - (1 if mid else 0), "wt")
            P(L, c, 2, "wt" if c < 18 else "sv2")
            P(L, c, 3, "sv2" if c < 18 else "sv1")
            if mid:
                P(L, c, 1, "wt")
            P(L, c, (-1 if mid else 0), "ol")
        for r in range(0, 4):
            P(L, -1, r, "ol")
            P(L, 22, r, "ol")
        P(L, -1, 0, "ol")
        P(L, 0, 0, "ol")
        P(L, 21, 0, "ol")
        P(L, 22, 0, "ol")
        # 竹节小环
        for r in (6, 14):
            P(L, 1, r, "sv2")
            P(L, 2, r, "sv1")
            P(L, 19, r, "sv2")
            P(L, 20, r, "sv0")
        # 座下横档
        for c in range(1, 21):
            P(L, c, 23, "wt")
            P(L, c, 24, "sv2" if c < 18 else "sv1")
            P(L, c, 25, "sv1")
        for c in range(0, 22):
            P(L, c, 26, "ol" if only_back or c in (0, 21) else "sv0")
        if not only_back:
            # 腿：上半截收进一格，下半截往外叉回来；外侧描边
            for r in range(27, 45):
                lx = 2 if r < 36 else 1
                rx_ = 18 if r < 36 else 19
                P(L, lx, r, "wt")
                P(L, lx + 1, r, "sv1")
                P(L, lx - 1, r, "ol")
                P(L, rx_, r, "wt")
                P(L, rx_ + 1, r, "sv1")
                P(L, rx_ + 2, r, "ol")
            for (c, col) in ((1, "sv1"), (2, "sv0"), (19, "sv1"), (20, "sv0")):
                P(L, c, 44, col)
            for c in (0, 1, 2, 3, 18, 19, 20, 21):
                P(L, c, 45, "ol")
        # 过道那一边：椅背上系一团白纱和小花
        if kind != "plain":
            s = 20 if kind == "aisleL" else 1
            d = 1 if kind == "aisleL" else -1
            for r in range(8, 27):
                wob = 1 if (r // 5) % 2 else 0
                for i, col in enumerate(("wt", "wt", "sv2")):
                    P(L, s + d * (i + wob - 1) if d > 0 else s - (i + wob - 1), r, col)
                if r % 6 == 3:
                    P(L, s + d * (1 + wob), r, "sv1")
            for r in range(26, 29):
                P(L, s + d * 1, r, "wt")
                P(L, s + d * 2, r, "sv2")
            for (dc, dr, col) in ((-3, 3, "wt"), (-2, 2, "wt"), (-2, 3, "sv2"), (-1, 4, "sv2"), (2, 2, "wt"), (3, 3, "wt"),
                                  (3, 4, "sv2"), (2, 4, "sv2"), (4, 3, "sv1"), (-4, 4, "sv2")):
                P(L, s + dc * d, dr, col)
            g0 = x0 + s
            leaf_spray(L, g0 - 2 * d, top + 6, math.pi * (0.75 if d > 0 else 0.25), 6, RAMPS["gr"], 4)
            leaf_spray(L, g0 + 1 * d, top + 7, math.pi * (0.35 if d > 0 else 0.65), 6, RAMPS["gr"], 3)
            rose(L, g0 - 2, top + 3, "w", 5)
            rose(L, g0 + (1 if d > 0 else -3), top + 7, "p", 3)
            L.p(g0 + 3 * d, top + 2, "wt")
            L.p(g0 - 3 * d, top + 9, "wt")
    return full, back


# ================================================================== 通道矮花丛（白木花箱 + 一丛花）
def draw_hedge(item, k):
    x0, y0, x1, y1 = item["rect"]
    foot = y1
    L = Layer(x0 - 6, foot - 36, (x1 - x0) + 12, 38)
    cx = (x0 + x1) / 2.0
    # 花箱：正面 8 行、顶沿一行，竖板缝
    by0 = foot - 9
    for y in range(by0, foot):
        for x in range(x0, x1):
            col = "wt"
            if x >= x1 - 4:
                col = "sv2"
            if (x - x0) % 6 == 5:
                col = "sv2" if col == "wt" else "sv1"
            if y == foot - 1:
                col = "sv1"
            L.p(x, y, col)
    for x in range(x0 - 1, x1 + 1):
        L.p(x, by0 - 1, "wt" if x < x1 - 3 else "sv2")
        L.p(x, by0, "sv2" if x < x1 - 3 else "sv1")
    # 花
    seed = 300 + k * 17
    mound = Layer(L.ox, L.oy, L.w, L.h)
    bloom_mound(mound, cx, by0 + 1, (x1 - x0) / 2.0 + 1, 22, seed,
                mix={"w": 0.42, "h": 0.28, "p": 0.18, "b": 0.12}, droop=2)
    mound.outline("gr0", pick=lambda x, y, nb: None if L.has(x, y) else "gr0")
    L.paste(mound)
    # 花箱描边
    L.outline("ol", pick=lambda x, y, nb: None if mound.has(x, y) or y < by0 - 1 else "ol")
    return L


# ================================================================== 仪式台（白色圆台 + 前面一级台阶）
STAGE = dict(cx=420, cy=412, rx=96, ry=64, h=14)


def draw_stage():
    cx, cy, rx, ry, h = STAGE["cx"], STAGE["cy"], STAGE["rx"], STAGE["ry"], STAGE["h"]
    L = Layer(cx - rx - 3, cy - ry - h - 3, 2 * rx + 7, 2 * ry + h + 20)
    rnd = random.Random(55)
    # 侧面（裙边）：竖褶，左边受光、右边背光；比台面暗一档，台面和裙边分得开
    for x in range(cx - rx, cx + rx + 1):
        t = (x + 0.5 - cx) / rx
        if abs(t) > 1:
            continue
        yb = cy + ry * math.sqrt(max(0.0, 1 - t * t))
        for y in range(int(yb - h), int(yb) + 1):
            base = 3 if t < -0.45 else (2 if t < 0.5 else 1)
            for edge in (-0.45, 0.5):
                if abs(t - edge) < 0.05 and (x + y) % 2 == 0:
                    base = base + 1 if t > edge else base
            ph = (x - cx) % 6
            if ph == 5:
                base -= 1
            elif ph == 0 and base < 3:
                base += 1
            if y >= yb - 1:
                base = 1
            L.p(x, y, rname("wh", max(0, base)))
    # 顶面：刷白的木台面，一条条板缝、错开的接缝；离边一点一圈金
    for y in range(cy - ry - h - 1, cy + ry - h + 2):
        row = y - (cy - ry - h)
        for x in range(cx - rx - 1, cx + rx + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - (cy - h)) / ry
            d = math.sqrt(dx * dx + dy * dy)
            if d > 1.0:
                continue
            col = "wl5"
            if row % 7 == 6:
                col = "wl4"
            elif (x + (row // 7) * 37) % 67 == 0 and row % 7 in (1, 2, 3, 4):
                col = "wl4"
            elif row % 7 == 0 and dx < -0.2:
                col = "wt"
            if 0.86 < d < 0.89:
                col = "gd3" if dx < 0.35 else "gd2"
            elif 0.89 <= d < 0.915:
                col = "gd2" if dx < 0.35 else "gd1"
            elif d >= 0.965 and dy < 0:
                col = "wl3"
            L.p(x, y, col)
    # 顶面前沿一线金边（裙边上沿）
    for x in range(cx - rx, cx + rx + 1):
        t = (x + 0.5 - cx) / rx
        if abs(t) > 1:
            continue
        yb = cy + ry * math.sqrt(max(0.0, 1 - t * t))
        L.p(x, yb - h + 1, "gd3" if t < 0.4 else "gd2")
        L.p(x, yb - h + 2, "gd2" if t < 0.4 else "gd1")
    # 裙边上的小绿叶花环（一段一段垂下来）
    for k in range(-7, 8):
        xs = cx + k * 13
        t = (xs - cx) / rx
        if abs(t) > 0.93:
            continue
        for j in range(-6, 7):
            x = xs + j
            tt = (x + 0.5 - cx) / rx
            yb = cy + ry * math.sqrt(max(0.0, 1 - tt * tt))
            sag = int(round(3.2 * (1 - (j / 6.5) ** 2)))
            y = yb - h + 3 + sag
            tone = 4 if tt < 0.3 else 3
            L.p(x, y, rname("gr", tone))
            if j % 2 == 0:
                L.p(x, y + 1, rname("gr", tone - 1))
        tt = (xs - 6.5 + 0.5 - cx) / rx
        yb = cy + ry * math.sqrt(max(0.0, 1 - tt * tt))
        rose(L, xs - 8, yb - h + 1, "w", 3)
    # 台阶（前面正中）
    sx0, sx1, sfoot, sh = cx - 22, cx + 22, cy + ry + 4, 7
    for y in range(sfoot - sh - 8, sfoot):
        for x in range(sx0, sx1):
            if y < sfoot - sh:
                col = "wl5" if y > sfoot - sh - 8 else "wl3"
                if x >= sx1 - 3:
                    col = "wl4"
            else:
                col = "sv2" if x < sx1 - 6 else "sv1"
                if y == sfoot - 1:
                    col = "sv1"
            L.p(x, y, col)
    for x in range(sx0, sx1):
        L.p(x, sfoot - sh, "gd3" if x < sx1 - 8 else "gd2")
    # 花瓣：从台阶到台中间稀稀一条，两边几片
    for _ in range(46):
        t = rnd.random()
        x = int(cx + rnd.gauss(0, 9 + 14 * t))
        y = int(cy + ry - h - 4 - t * 70)
        if L.g(x, y) in (C["wl5"], C["wl4"]) and L.g(x + 1, y) in (C["wl5"], C["wl4"]):
            c = rnd.choice(["pk2", "pk", "pk", "wt"])
            L.p(x, y, c)
            if rnd.random() < 0.6:
                L.p(x + 1, y, shift(c, -1))
    L.outline("ol")
    return L


# ================================================================== 花拱门（白色细铁架 + 白纱 + 鲜花 + 一点红金）
def smooth_keys(keys, y):
    """keys: [(y, a, b, ...)] 从上到下；按 y 用余弦插值出 (a, b, ...)"""
    if y <= keys[0][0]:
        return keys[0][1:]
    for (k0, k1) in zip(keys, keys[1:]):
        if k0[0] <= y <= k1[0]:
            t = (y - k0[0]) / float(max(1, k1[0] - k0[0]))
            t = (1 - math.cos(t * math.pi)) / 2
            return tuple(v0 + (v1 - v0) * t for v0, v1 in zip(k0[1:], k1[1:]))
    return keys[-1][1:]


def drape(L, keys, seed, n=4):
    """一幅纱：几条叠着的布条（每条左边受光、右边一道暗褶），上宽、中间收拢、到地上摊开。
    keys = [(y, 中线 x, 宽)]，从上到下"""
    rnd = random.Random(seed)
    y0, y1 = keys[0][0], keys[-1][0]
    strips = []
    for k in range(n):
        f = (k + 0.5) / n - 0.5
        strips.append((f, rnd.uniform(0, 6.28), rnd.uniform(0.5, 1.3), rnd.uniform(38, 70), rnd.uniform(1.25, 1.5)))
    order = list(range(n))
    rnd.shuffle(order)
    for depth, k in enumerate(order):
        f, ph, amp, per, wf = strips[k]
        back = depth < n // 2
        for y in range(y0, y1 + 1):
            cx, w = smooth_keys(keys, y)
            sc = cx + f * w * 0.9 + amp * math.sin(y / per * 6.283 + ph) * (w / 18.0)
            sw = max(2.0, w / n * wf)
            xl, xr = sc - sw / 2, sc + sw / 2
            for x in range(int(math.floor(xl)), int(math.ceil(xr))):
                g = (x + 0.5 - xl) / sw
                tone = 3
                if g > 0.7:
                    tone = 2
                if g > 0.9 and sw > 3:
                    tone = 1
                if back:
                    tone = max(1, tone - 1) if g > 0.35 else tone
                L.p(x, y, rname("wh", tone))


def arch_tube(L, pts, wdt=4):
    """白铁管：沿一串点盖章，左上亮、右下暗"""
    cols = {0: "wt", 1: "wt", 2: "sv2", 3: "sv1"}
    for (x, y) in pts:
        for j in range(wdt):
            for i in range(wdt):
                L.p(x + i - wdt // 2, y + j - wdt // 2, cols[min(3, (i + j) * 3 // (2 * wdt - 2))])


def draw_arch():
    L = Layer(296, 172, 250, 270)
    rnd = random.Random(808)
    frame = Layer(L.ox, L.oy, L.w, L.h)
    # ---- 白铁架：两根柱子立在台面后沿，顶上一道弧（圆顶拱门）
    post_bot, post_top = 362, 246
    acx, acy, arx, ary = 420, 246, 72, 44
    pts = []
    for y in range(post_top, post_bot):
        pts.append((348, y))
        pts.append((492, y))
    for i in range(0, 361):
        th = math.pi * (1 - i / 360.0)
        pts.append((int(round(acx + arx * math.cos(th))), int(round(acy - ary * math.sin(th)))))
    arch_tube(frame, pts, 4)
    # 柱脚小底座
    for px0 in (348, 492):
        for y in range(post_bot - 3, post_bot + 1):
            for x in range(px0 - 4, px0 + 4):
                frame.p(x, y, "sv2" if x < px0 + 2 else "sv1")
    frame.outline("ol")
    L.paste(frame)
    # ---- 两幅纱从拱顶正中往两边垂，半腰用红绸带收拢，到台两边地上摊开
    tails = []
    for side in (-1, 1):
        keys = [(205, 420 + side * 9, 14), (232, 420 + side * 26, 26), (290, 420 + side * 58, 26), (345, 420 + side * 79, 16),
                (396, 420 + side * 88, 9), (418, 420 + side * 95, 18), (434, 420 + side * 98, 30)]
        tl = Layer(L.ox, L.oy, L.w, L.h)
        drape(tl, keys, 31 + side, n=4)
        tl.outline("sv0")
        tails.append((side, tl, keys))
    for (side, tl, keys) in tails:
        L.paste(tl)
        # 红绸带 + 金扣
        yk = 393
        cx, w = smooth_keys(keys, yk + 2)
        for y in range(yk, yk + 5):
            for x in range(int(cx - w / 2) - 1, int(cx + w / 2) + 2):
                if y in (yk, yk + 4):
                    L.p(x, y, "rd1")
                else:
                    L.p(x, y, "rd4" if x < cx else "rd3")
        kx = int(cx)
        L.p(kx, yk + 2, "gd4")
        L.p(kx + 1, yk + 2, "gd3")
        L.p(kx, yk + 3, "gd2")
        for j in range(9):
            L.p(kx - 1 - j // 3, yk + 5 + j, "rd4" if j % 3 else "rd3")
            L.p(kx + 2 + j // 4, yk + 5 + j, "rd3")
        L.p(kx - 4, yk + 13, "rd1")
        L.p(kx + 4, yk + 13, "rd1")
    # ---- 拱顶正中：小红绸结（金心），纱从这里分开
    bx, by = 420, 205
    bow = [".rr.....rr.",
           "rRRr...rRRr",
           "rRRRrgrRRRr",
           "rRRrgGgrRRr",
           ".rr.rgr.rr.",
           "....r.r...."]
    for j, row in enumerate(bow):
        for i, ch in enumerate(row):
            x, y = bx - 5 + i, by - 2 + j
            col = {"r": "rd2", "R": "rd4" if i < 6 else "rd3", "g": "gd3", "G": "gd4"}.get(ch)
            if col:
                L.p(x, y, col)
    for j in range(10):
        L.p(bx - 1 - j // 4, by + 4 + j, "rd4" if j % 3 else "rd2")
        L.p(bx + 1 + j // 4, by + 4 + j, "rd3")
    # ---- 花：左肩一大团（顺着柱子往下垂几枝），右肩一小团；拱上常春藤
    ivy = Layer(L.ox, L.oy, L.w, L.h)
    for i in range(0, 361, 9):
        th = math.pi * (1 - i / 360.0)
        x, y = acx + arx * math.cos(th), acy - ary * math.sin(th)
        if 380 < x < 470 or rnd.random() < 0.3:
            continue
        leaf_spray(ivy, x, y, math.pi / 2 + rnd.uniform(-0.8, 0.8), rnd.randint(3, 6), RAMPS["gr"], rnd.choice([3, 4]))
    for y in range(250, 340, 5):
        leaf_spray(ivy, 348 + rnd.choice([-2, 0, 2]), y, math.pi / 2 + rnd.uniform(-0.7, 0.7), 4, RAMPS["gr"], 3)
    ivy.outline("gr0", pick=lambda x, y, nb: None if L.has(x, y) else "gr0")
    L.paste(ivy)
    fl = Layer(L.ox, L.oy, L.w, L.h)
    bloom_mound(fl, 360, 240, 30, 44, 4401, mix={"w": 0.45, "h": 0.35, "p": 0.12, "b": 0.08}, droop=7)
    bloom_mound(fl, 388, 216, 15, 22, 4404, mix={"w": 0.5, "h": 0.25, "p": 0.15, "b": 0.1}, droop=2)
    bloom_mound(fl, 348, 272, 12, 24, 4402, mix={"w": 0.5, "h": 0.3, "b": 0.2}, droop=4)
    bloom_mound(fl, 484, 238, 20, 30, 4403, mix={"w": 0.5, "h": 0.3, "p": 0.12, "b": 0.08}, droop=4)
    fl.outline("gr0")
    L.paste(fl)
    return L


# ================================================================== 台边的花（wed_flowers、wed_leaves）
def draw_wed_flowers(item_f, item_l):
    L = Layer(290, 370, 260, 100)
    seq = []
    for k, (x, y, rx, ry) in enumerate(item_f["e"]):
        seq.append((y + ry * 0.6, "f", x, rx, ry, k))
    for k, (x, y, rx, ry) in enumerate(item_l["e"]):
        seq.append((y + ry * 0.6, "l", x, rx, ry, k))
    seq.sort()
    for (foot, kind, x, rx, ry, k) in seq:
        one = Layer(L.ox, L.oy, L.w, L.h)
        if kind == "f":
            bloom_mound(one, x, foot, rx + 3, rx * 1.85, 5100 + k * 7,
                        mix={"w": 0.46, "h": 0.4, "p": 0.06, "b": 0.08}, droop=4)
        else:
            bloom_mound(one, x, foot, rx + 2, rx * 1.9, 5200 + k * 7,
                        mix={"b": 0.45, "w": 0.4, "h": 0.15}, leafy=0.6, droop=4)
        one.outline("gr0")
        L.paste(one)
    return L


# ================================================================== 甜品台
def draw_dessert(item):
    x0, y0, x1, y1 = item["rect"]
    h = item["h"]
    L = Layer(x0 - 4, y0 - h - 50, x1 - x0 + 8, y1 - y0 + h + 54)
    t0, t1 = y0 - h, y1 - h          # 顶面 408..434
    # 台布顶面
    for y in range(t0, t1):
        for x in range(x0, x1):
            col = "wt"
            if y == t0:
                col = "sv2"
            if x >= x1 - 2:
                col = "sv2"
            L.p(x, y, col)
    # 正面：上面三段垂幔、下面落地的裙摆
    for y in range(t1, y1):
        for x in range(x0 - (1 if y > y1 - 4 else 0), x1 + (1 if y > y1 - 4 else 0)):
            u = (x - x0) / float(x1 - x0)
            base = 3 if u < 0.6 else 2
            ph = (x - x0) % 7
            if ph == 6:
                base -= 1
            elif ph == 0 and u > 0.3:
                base -= 0
            if u > 0.88:
                base = min(base, 2) - (1 if ph >= 4 else 0)
            if y == y1 - 1:
                base = 1
            L.p(x, y, rname("wh", base))
    # 金边
    for x in range(x0, x1):
        L.p(x, t1, "gd3" if x < x1 - 14 else "gd2")
    # 垂幔：三段，每段往下弯 7 像素
    sw = (x1 - x0) / 3.0
    for k in range(3):
        a = x0 + k * sw
        for x in range(int(a), int(a + sw) + 1):
            u = (x - a) / sw
            dip = 7.5 * math.sin(u * math.pi)
            for y in range(t1 + 1, int(t1 + 2 + dip) + 1):
                f = (y - t1 - 1) / max(1.0, dip + 1)
                tone = 3 if f < 0.7 else 2
                if x > x1 - 12:
                    tone -= 1
                L.p(x, y, rname("wh", tone))
            L.p(x, int(t1 + 2 + dip) + 1, "sv1")
    # 垂幔交接处一小团花 + 短纱尾
    for k in range(4):
        fx = int(x0 + k * sw)
        for y in range(t1 + 2, t1 + 12):
            L.p(fx, y, "wt")
            L.p(fx + 1, y, "sv2")
        L.p(fx, t1 + 12, "sv1")
        rose(L, fx - 2, t1 - 1, "p" if k % 2 else "w", 4)
        L.p(fx - 3, t1 + 2, "gr3")
        L.p(fx + 3, t1 + 2, "gB")
        L.p(fx + 3, t1 + 3, "gr2")
    # ---- 三层蛋糕（左边）：每层一个白圆柱（左亮右暗、顶上一圈扁椭圆的面、底下一圈珍珠），粉玫瑰斜着落下来
    def tier(cxm, hw, yb, ht):
        for x in range(int(cxm - hw), int(cxm + hw) + 1):
            u = (x + 0.5 - cxm) / hw
            if abs(u) > 1.02:
                continue
            ybot = yb + int(round(1.6 * math.sqrt(max(0.0, 1 - u * u))))
            for y in range(yb - ht, ybot):
                tone = 3 if u < 0.3 else (2 if u < 0.78 else 1)
                if u < -0.86:
                    tone = 2
                L.p(x, y, rname("wh", tone))
            L.p(x, ybot - 1, ("wt" if x % 2 else "sv2") if u < 0.5 else ("sv2" if x % 2 else "sv1"))
        # 顶面
        for x in range(int(cxm - hw), int(cxm + hw) + 1):
            u = (x + 0.5 - cxm) / hw
            if abs(u) > 1.0:
                continue
            e = math.sqrt(max(0.0, 1 - u * u))
            y0_ = int(round(yb - ht - 1.6 * e))
            y1_ = int(round(yb - ht + 1.6 * e))
            for y in range(y0_, y1_ + 1):
                L.p(x, y, "wt")
            L.p(x, y0_, "sv2" if u > -0.6 else "wt")
    L.ell(610, 427, 647, 434, "gd2")
    L.ell(611, 427, 646, 433, "gd3")
    for x in range(612, 646, 3):
        L.p(x, 429, "gd4")
    tier(628.5, 15, 429, 10)
    tier(628.5, 11, 417, 9)
    tier(628.5, 7, 406, 8)
    # 中层一道粉缎带
    for x in range(618, 640):
        L.p(x, 414, "pk2" if x < 634 else "pk")
    for (rx_, ry_, kind, sz) in ((626, 393, "p", 4), (630, 395, "w", 3), (622, 400, "p", 3), (619, 405, "w", 3),
                                 (617, 409, "p", 4), (621, 412, "p", 3), (634, 418, "p", 3), (637, 421, "w", 3),
                                 (639, 424, "p", 4), (615, 421, "w", 3)):
        rose(L, rx_, ry_, kind, sz)
    for (lx, ly) in ((620, 404), (616, 413), (636, 422), (629, 397), (642, 427), (619, 409)):
        L.p(lx, ly, "gr3")
        L.p(lx + 1, ly, "gB")
    # ---- 马卡龙塔（右边，粉、薄荷、柠檬、浅蓝、奶白一圈圈）
    mc = [("pk2", "pk", "pk0"), ("gC", "gr4", "gB"), ("gd4", "gd3", "gd2"), ("bl4", "bl3", "bl2"), ("wl5", "wl4", "wl3")]
    L.ell(655, 427, 683, 432, "gd2")
    L.ell(656, 427, 682, 431, "gd3")
    rows = 7
    for r in range(rows):
        yb = 428 - r * 4
        hw = 13 - r * 1.6
        n = max(1, int(hw * 2 / 4))
        for i in range(n):
            mx = int(669 - hw + i * (2 * hw / n))
            a, b, c = mc[(i + r * 2) % 5]
            dark = mx > 669 + hw * 0.35
            if dark:
                a, b, c = b, c, c
            for (dx, dy, col) in ((0, -3, a), (1, -3, a), (2, -3, b), (0, -2, b), (1, -2, b), (2, -2, c),
                                  (0, -1, "wl5"), (1, -1, "wl5"), (2, -1, "wl4"), (0, 0, b), (1, 0, c), (2, 0, c), (3, -2, c), (3, -1, "wl4")):
                L.p(mx + dx, yb + dy, col)
    rose(L, 667, 396, "p", 4)
    L.p(666, 398, "gr3")
    L.p(671, 398, "gB")
    # ---- 右头一只玻璃花瓶插白花
    for y in range(419, 431):
        L.p(684, y, "bl4")
        L.p(685, y, "wt" if y < 425 else "bl4")
        L.p(686, y, "bl3")
        L.p(687, y, "bl3")
    bloom_mound(L, 686, 420, 5, 13, 707, mix={"w": 0.6, "b": 0.4}, droop=1)
    # 台面上几片花瓣
    for (px_, py_) in ((646, 424), (650, 427), (609, 418), (612, 425), (688, 432), (644, 416)):
        L.p(px_, py_, "pk2")
        L.p(px_ + 1, py_, "pk")
    # ---- 前沿一排小点心：小杯子蛋糕、小碟
    for (sx, kind) in ((608, "p"), (646, "w"), (650, "p")):
        L.p(sx, 432, "gd2")
        L.p(sx + 1, 432, "gd3")
        L.p(sx + 2, 432, "gd2")
        a, b, c = FLOWER_COLS[kind]
        L.p(sx, 431, a)
        L.p(sx + 1, 430, a)
        L.p(sx + 1, 431, b)
        L.p(sx + 2, 431, c)
    L.outline("ol")
    return L


# ================================================================== 秋千
def draw_swing(it):
    """木头秋千：两头各一个 A 字架（往东西两边叉开），顶上一根横梁，麻绳、木座板；
    婚礼那天横梁上缠了一道绿叶白花的花环，绳子上也缠了几朵"""
    L = Layer(1186, 258, 130, 134)
    foot = 382
    wood = ("wd5", "wd4", "wd3", "wd2")

    def leg(xt, yt, xb, yb, w=4):
        n = int(max(abs(xb - xt), abs(yb - yt)))
        for i in range(n + 1):
            t = i / float(n)
            x = xt + (xb - xt) * t
            y = yt + (yb - yt) * t
            for k in range(w):
                L.p(x + k - w // 2, y, wood[min(3, k)])
    # A 字架：每头两条腿，顶点在横梁两端下面，脚叉开到 ±10；腰上一道横拉杆
    for (ax, d) in ((1209, 1), (1291, -1)):
        leg(ax, 274, ax - 10, foot - 1)
        leg(ax, 274, ax + 10, foot - 1)
        for x in range(ax - 6, ax + 7):
            L.p(x, 344, "wd4")
            L.p(x, 345, "wd2")
        for xx in (ax - 12, ax + 8):
            for y in range(foot - 2, foot):
                for i in range(5):
                    L.p(xx + i, y, "wd3" if i < 3 else "wd2")
    # 横梁（顶面亮、正面中、底边暗；两头露出木头截面）
    for y in range(268, 276):
        for x in range(1201, 1300):
            col = "wd5" if y <= 269 else ("wd4" if y <= 272 else ("wd3" if y <= 274 else "wd2"))
            if y in (271, 272) and (x * 13) % 19 == 0:
                col = "wd3"
            L.p(x, y, col)
    for y in range(269, 275):
        L.p(1201, y, "wd3")
        L.p(1299, y, "wd2")
    # 绳子（拧着的麻绳）+ 铁钩
    for rx0 in (1236, 1262):
        L.p(rx0, 276, "sv1")
        L.p(rx0 + 1, 276, "sv0")
        for y in range(277, 359):
            L.p(rx0, y, "fl6" if (y % 3) == 0 else "fl5")
            L.p(rx0 + 1, y, "fl3" if (y % 3) == 1 else "fl4")
    # 座板
    for y in range(358, 365):
        for x in range(1232, 1269):
            col = "wd5" if y <= 359 else ("wd4" if y <= 360 else ("wd3" if y <= 362 else "wd2"))
            if x >= 1265 and y > 359:
                col = shift(col, -1)
            L.p(x, y, col)
    L.outline("ol")
    # 横梁上的花环：一路绿叶，三段往下垂，交接处一团白花
    rnd = random.Random(91)
    gl = Layer(L.ox, L.oy, L.w, L.h)
    pts = []
    for k in range(4):
        xa, xb = 1206 + k * 22, 1206 + (k + 1) * 22
        for x in range(xa, xb):
            u = (x - xa) / 22.0
            pts.append((x, 275 + 7 * math.sin(u * math.pi)))
    for (x, y) in pts:
        gl.p(x, y, "gr3" if (x % 3) else "gB")
        gl.p(x, y + 1, "gr2")
        if x % 4 == 0:
            gl.p(x + 1, y - 1, "gr4")
            gl.p(x - 1, y + 2, "gA")
    for k in range(5):
        x = 1206 + k * 22
        bloom_mound(gl, x, 276, 5, 9, 9100 + k, mix={"w": 0.6, "p": 0.25, "b": 0.15}, droop=1)
    gl.outline("gr0", pick=lambda x, y, nb: None if L.has(x, y) and y < 276 else "gr0")
    L.paste(gl)
    # 绳子上缠几朵
    for rx0 in (1236, 1262):
        for y in range(286, 356, 6):
            s_ = 1 if (y // 6) % 2 else -1
            x = rx0 + (2 if s_ > 0 else -1)
            L.p(x, y, "gr3")
            L.p(x + s_, y + 1, "gB")
            L.p(x, y + 1, "gr2")
            if rnd.random() < 0.5:
                a, b, c = FLOWER_COLS[rnd.choice(["w", "w", "p"])]
                L.p(x - s_, y - 1, a)
                L.p(x - s_ + 1, y - 1, b)
                L.p(x - s_, y, b)
    return L


# ================================================================== 滑梯
def draw_slide(tower, chute):
    L = Layer(1364, 392, 120, 106)
    x0, y0, x1, y1 = tower["rect"]          # 1372..1396 × 470..490
    deck = 44
    # 滑道（先画，塔挡在它西头前面）
    xa, xb = 1396, 1476
    for x in range(xa - 2, xb):
        t = (x - xa) / float(xb - xa)
        t = max(0.0, t)
        if t < 0.82:
            z = deck * (1 - (t / 0.82)) ** 1.25 + 3 * (t / 0.82)
        else:
            z = 3
        yn = 472 + 7 * t
        ys = 488 + 5 * t
        top_n, top_s = int(yn - z), int(ys - z)
        for y in range(top_n, top_s + 4):
            if y <= top_n + 1:
                col = "gd4"                     # 北边沿（亮）
            elif y < top_s - 1:
                f = (y - top_n) / max(1.0, top_s - top_n)
                col = "gd3" if f < 0.45 else ("gd4" if f < 0.6 else "gd3")
            elif y < top_s + 1:
                col = "gd4"                     # 南边沿顶
            else:
                col = "gd2" if y < top_s + 3 else "gd1"   # 南边沿外侧面
            L.p(x, y, col)
    # 滑道中段一根撑脚
    for y in range(470, 489):
        L.p(1440, y, "rd3")
        L.p(1441, y, "rd2")
    # 塔：四根红柱（前两根 418..490，后两根露出顶上 398..418）
    for px0 in (x0, x1 - 3):
        for y in range(y0 - 72, y1):
            for i, col in enumerate(("rd4", "rd3", "rd2")):
                L.p(px0 + i, y, col)
        L.p(px0, y0 - 73, "rd5")
        L.p(px0 + 1, y0 - 73, "rd4")
    # 平台（木板）
    for y in range(y0 - deck, y1 - deck):
        for x in range(x0 + 3, x1 - 3):
            col = "wd4" if (y - (y0 - deck)) % 5 else "wd3"
            L.p(x, y, col)
    for x in range(x0, x1):
        L.p(x, y1 - deck, "wd3")
        L.p(x, y1 - deck + 1, "wd2")
        L.p(x, y1 - deck + 2, "wd1")
    # 后面、两边栏杆（黄）
    for y in range(y0 - 72 + 1, y0 - deck):
        for x in range(x0 + 3, x1 - 3):
            if y == y0 - 72 + 1 or y == y0 - 72 + 2:
                L.p(x, y, "gd3" if y == y0 - 71 else "gd2")
            elif (x - x0) % 4 == 1:
                L.p(x, y, "gd3")
    # 前面扶手横杆（梯子口两边空着）
    for x in range(x0 + 3, x1 - 3):
        if x < x0 + 6 or x > x1 - 7:
            for y in range(y1 - 72 + 1, y1 - deck):
                if (y - (y1 - 72)) % 6 < 2 or x in (x0 + 4, x1 - 5):
                    L.p(x, y, "gd3")
    for x in range(x0 + 3, x1 - 3):
        L.p(x, y1 - 72 + 1, "gd4" if x < x1 - 8 else "gd3")
        L.p(x, y1 - 72 + 2, "gd2")
    # 梯子（前面，从地上到平台）
    for y in range(y1 - deck + 3, y1):
        L.p(x0 + 5, y, "gd2")
        L.p(x1 - 6, y, "gd1")
    for y in range(y1 - deck + 7, y1 - 2, 7):
        for x in range(x0 + 5, x1 - 5):
            L.p(x, y, "gd4" if x < x1 - 9 else "gd3")
            L.p(x, y + 1, "gd2")
    L.outline("ol")
    return L


# ================================================================== 树（香樟、桂花、紫薇；仪式台后面一棵大香樟）
SPECIES = {
    # 香樟：宽圆的冠，叶小而密，向阳的一面嫩黄绿
    "zh": dict(ramp=["gr0", "nl1", "nl2", "nl3", "gr3", "gB", "gr4"], bark=["ol", "wd0", "wd1", "fl1", "fl2", "fl3"],
               cr=(3.4, 5.4), bias=0.0, n_out=8, lobe_r=(0.36, 0.48), rx=0.5, ry=0.3),
    # 桂花：冠更紧、更暗、偏竖的蛋形，九月开金黄的小花藏在叶子里
    "gh": dict(ramp=["gr0", "nl1", "nl2", "nl3", "gA", "gr3", "gB"], bark=["ol", "wd0", "wd1", "fl1", "fl2", "fl3"],
               cr=(2.8, 4.4), bias=0.02, n_out=9, lobe_r=(0.38, 0.5), rx=0.43, ry=0.34),
    # 紫薇：几根光滑的浅色干丛生，冠松、团和团之间透空，顶上粉的花穗
    "zw": dict(ramp=["gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC"], bark=["ol", "wd1", "fl2", "fl3", "fl4", "fl5"],
               cr=(3.4, 5.2), bias=0.0, n_out=7, lobe_r=(0.32, 0.42), lobe_out=(0.7, 0.82), inner=0.85,
               hole_r=(4.5, 7.5), rx=0.5, ry=0.28),
}


def thick_line(L, x0, y0, x1, y1, w0, w1, bark, light_bias=0.0):
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
                    s = (xx + 0.5 - x) / max(hw, 0.5)
                    old = pts.get((xx, yy))
                    if old is None or abs(s) < abs(old):
                        pts[(xx, yy)] = s
    for (x, y), s in pts.items():
        s += light_bias
        idx = 5 if s < -0.55 else (4 if s < -0.1 else (3 if s < 0.45 else 2))
        L.p(x, y, bark[idx])
    return pts


def crown(L, ccx, ccy, RX, RY, seed, sp, n_holes=4, box=None):
    """树冠：外圈一圈大团（鼓出来，轮廓一个个圆弧）+ 里面补几团；每团当一个球算大明暗，
    上面再铺密密的小叶团算小明暗；团和团交界的凹处压暗。沿这种树的叶色带取色"""
    S = SPECIES[sp]
    ramp = S["ramp"]
    rnd = random.Random(seed)
    base_r = min(RX, RY)
    lobes = []
    n_out = S.get("n_out", 8) + (7 if base_r > 80 else 0)
    rmax = 33.0 if base_r > 80 else 999.0
    a0 = rnd.uniform(0, 6.283)
    for i in range(n_out):
        a = a0 + i * 6.283 / n_out + rnd.uniform(-0.18, 0.18)
        r = min(rmax, base_r * rnd.uniform(*S.get("lobe_r", (0.34, 0.46))))
        k = rnd.uniform(*S.get("lobe_out", (0.62, 0.76)))
        if rmax < 100:
            k = rnd.uniform(0.78, 0.9)
        x = ccx + math.cos(a) * (RX - r * 0.5) * k / 0.7
        y = ccy + math.sin(a) * (RY - r * 0.5) * k / 0.7
        # 冠底那几团收一点（树冠底平一些）
        if math.sin(a) > 0.5:
            y -= r * 0.25
        lobes.append((x, y, r))
    # 里面补团
    tries = 0
    while tries < 2000:
        tries += 1
        x = ccx + rnd.uniform(-0.6, 0.6) * RX
        y = ccy + rnd.uniform(-0.6, 0.55) * RY
        if ((x - ccx) / RX) ** 2 + ((y - ccy) / RY) ** 2 > 0.4:
            continue
        cover = any((x - a) ** 2 + (y - b) ** 2 < (c * 0.75) ** 2 for (a, b, c) in lobes)
        if not cover:
            lobes.append((x, y, min(rmax, base_r * rnd.uniform(0.36, 0.48)) * S.get("inner", 1.0)))
    # 收进 layout 给的框里（树高 h、冠宽 w）：顶不出 fy-h，两边不出 w/2
    if box:
        bx0, by0, bx1 = box
        xmin = min(lx - r for (lx, ly, r) in lobes)
        xmax = max(lx + r for (lx, ly, r) in lobes)
        ymin = min(ly - r for (lx, ly, r) in lobes)
        sx = min(1.0, ((bx1 - bx0) / 2.0 - 5) / max(1.0, max(ccx - xmin, xmax - ccx)))
        dy = max(0.0, by0 + 3 - ymin)
        lobes = [(ccx + (lx - ccx) * sx, ly + dy, r * (0.9 + 0.1 * sx)) for (lx, ly, r) in lobes]
    # 高度场（大团的球面；上面的团高一点）、哪一团在最上面
    HF = {}
    for li, (lx, ly, r) in enumerate(lobes):
        for y in range(int(ly - r) - 1, int(ly + r) + 2):
            for x in range(int(lx - r) - 1, int(lx + r) + 2):
                d2 = (x + 0.5 - lx) ** 2 + ((y + 0.5 - ly) * 1.08) ** 2
                if d2 < r * r:
                    hh = math.sqrt(r * r - d2) + 0.3 * (ccy - ly) + 0.15 * (ly - ccy if ly > ccy else 0)
                    if hh > HF.get((x, y), -1e9):
                        HF[(x, y)] = hh
    # 小叶团：抖动网格撒点（边上的伸出去一点，轮廓毛一点）
    cr0, cr1 = S["cr"]
    sp_ = (cr0 + cr1) * 0.62
    clusters = []
    keys = list(HF.keys())
    xs = [k[0] for k in keys]
    ys = [k[1] for k in keys]
    yy = min(ys) - 3
    while yy < max(ys) + 3:
        xx = min(xs) - 3
        while xx < max(xs) + 3:
            x = xx + rnd.uniform(0, sp_)
            y = yy + rnd.uniform(0, sp_)
            key = (int(x), int(y))
            ok = key in HF
            if not ok:
                for (dx, dy) in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                    if (int(x + dx), int(y + dy)) in HF and rnd.random() < 0.5:
                        ok = True
                        break
            if ok:
                r = rnd.uniform(cr0, cr1)
                z = HF.get(key, HF.get((int(x), int(y) - 2), 0))
                clusters.append((z + 0.25 * (y - ccy) + rnd.uniform(-2, 2), x, y, r, rnd.uniform(0, 6.283)))
            xx += sp_
        yy += sp_
    clusters.sort()
    idb = {}
    for k, (z, x, y, r, ph) in enumerate(clusters):
        for py in range(int(y - r - 1), int(y + r + 2)):
            for px_ in range(int(x - r - 1), int(x + r + 2)):
                dx, dy = px_ + 0.5 - x, py + 0.5 - y
                th = math.atan2(dy, dx)
                rr = r * (1 + 0.18 * math.sin(3 * th + ph) + 0.1 * math.sin(5 * th + ph * 2))
                if dx * dx + dy * dy <= rr * rr:
                    idb[(px_, py)] = k
    # 空当：在大团和大团之间、偏下半截（露出里面暗的和枝）
    holes = []
    for _ in range(n_holes):
        for _t in range(60):
            hx = ccx + rnd.uniform(-0.65, 0.65) * RX
            hy = ccy + rnd.uniform(-0.1, 0.6) * RY
            if (int(hx), int(hy)) in HF and all((hx - a) ** 2 + (hy - b) ** 2 > 18 ** 2 for (a, b, _r) in holes):
                holes.append((hx, hy, rnd.uniform(*S.get("hole_r", (3.5, 6.0))) * max(1.0, (base_r / 60.0) ** 0.5)))
                break

    def hf(x, y, d):
        v = HF.get((x, y))
        return d if v is None else v

    tone_of = {}
    for (x, y), k in idb.items():
        z, cx_, cy_, r, ph = clusters[k]
        h0 = hf(x, y, 0.0)
        gx = (hf(x + 2, y, h0 - 4) - hf(x - 2, y, h0 - 4)) / 4.0
        gy = (hf(x, y + 2, h0 - 4) - hf(x, y - 2, h0 - 4)) / 4.0
        nl = norm3((-gx, -gy, 0.9))
        ll = dot3(nl, LIGHT)
        # 凹处（团和团的交界）：比周围低就暗
        cav = h0 - (hf(x + 4, y, h0) + hf(x - 4, y, h0) + hf(x, y + 4, h0) + hf(x, y - 4, h0)) / 4.0
        u, v = (x + 0.5 - cx_) / r, (y + 0.5 - cy_) / r
        nz = math.sqrt(max(0.0, 1 - u * u - v * v))
        lc = dot3(norm3((u, v, nz + 0.25)), LIGHT)
        vv = (y - ccy) / RY
        val = 0.66 * ll + 0.34 * lc - 0.2 * max(0.0, vv) + 0.1 * max(0.0, -vv) + S["bias"] + 0.03 * min(0.0, cav) + 0.06
        val += (vnoise(x, y, 6, seed) - 0.5) * 0.1
        nb = idb.get((x + 1, y + 1))
        if nb is not None and nb != k and u + v > 0.25:
            val -= 0.16
        tone_of[(x, y)] = val
    th = S.get("th", [-0.05, 0.16, 0.33, 0.5, 0.64, 0.78])
    out_t = {}
    for (x, y), val in tone_of.items():
        t = 0
        for j, tt in enumerate(th):
            if val >= tt:
                t = j + 1
        for j, tt in enumerate(th):
            if abs(val - tt) < 0.016:
                t = j + 1 if (x + y) % 2 == 0 else j
                break
        for (hx, hy, hr) in holes:
            d = math.hypot(x + 0.5 - hx, (y + 0.5 - hy) * 1.25) / (1 + 0.3 * math.sin(3 * math.atan2(y - hy, x - hx) + hx))
            if d < hr:
                t = 0
            elif d < hr + 1.6:
                t = min(t, 1)
        out_t[(x, y)] = t
        L.p(x, y, rname(ramp, t))
    return dict(idb=idb, holes=holes, lobes=lobes, tone=out_t, ramp=ramp)


def draw_tree(item, sp, seed):
    fx, fy, h, w = item["x"], item["y"], item["h"], item["w"]
    S = SPECIES[sp]
    big = w > 200
    rv = random.Random(seed * 3 + 11)          # 每棵树自己的高矮胖瘦（不出 layout 的框）
    RX = w * (0.48 if big else S["rx"] * rv.uniform(0.9, 1.0))
    RY = h * (0.33 if big else S["ry"] * rv.uniform(0.86, 1.0))
    ccy = fy - h + RY + 4 + (0 if big else rv.uniform(0, 16))
    ccx = fx + rv.uniform(-3, 3)
    L = Layer(fx - w // 2 - 14, fy - h - 8, w + 28, h + 12)
    rnd = random.Random(seed + 1)
    bark = S["bark"]
    crown_bot = ccy + RY * 0.8
    # ---- 树干、主枝
    if sp == "zw":
        # 紫薇：两三根细干丛生、光滑浅色
        for (dx, w0, lean) in ((-3, 6, -10 + rv.randint(-3, 3)), (3, 6, 12 + rv.randint(-3, 3)), (0, 5, 2)):
            thick_line(L, fx + dx, fy - 1, fx + dx + lean, crown_bot - 10, w0, 4, bark)
    elif big:
        # 仪式台大香樟：粗短的干，齐人头高分成 Y 字三大枝伸进树冠
        tw = 24
        fork = fy - 58
        thick_line(L, fx, fy - 1, fx + 1, fork, tw, tw * 0.82, bark)
        for (dx, ww) in ((-15, 8), (15, 8)):
            thick_line(L, fx + dx * 0.4, fy - 9, fx + dx, fy, ww, 4, bark)
        for (ex, ey, w0, w1) in ((-44, ccy + 44, 14, 6), (48, ccy + 40, 13, 6), (2, ccy + 6, 12, 5)):
            mx_, my_ = fx + ex * 0.45, fork - 30
            thick_line(L, fx + ex * 0.1, fork + 6, mx_, my_, w0, (w0 + w1) / 2.0, bark)
            thick_line(L, mx_, my_, fx + ex, ey, (w0 + w1) / 2.0, w1, bark)
        for _ in range(60):
            x = fx + rnd.randint(-10, 9)
            y = rnd.randint(int(crown_bot), fy - 4)
            for j in range(rnd.randint(4, 12)):
                c = L.g(x, y + j)
                if c in (C[bark[3]], C[bark[4]]):
                    L.p(x, y + j, bark[2])
                elif c == C[bark[5]]:
                    L.p(x, y + j, bark[3])
        for _ in range(16):
            x = fx + rnd.randint(-9, 2)
            y = rnd.randint(int(crown_bot), fy - 6)
            if L.g(x, y) in (C[bark[3]], C[bark[4]]):
                L.p(x, y, bark[5])
                L.p(x, y + 1, bark[5])
    else:
        tw = rv.choice([10, 11, 12, 12, 13, 14])
        thick_line(L, fx, fy - 1, ccx + rv.uniform(-2, 2), crown_bot + 8, tw, tw * 0.72, bark)
        for (dx, ww) in ((-tw * 0.7, tw * 0.4), (tw * 0.7, tw * 0.4), (-tw * 0.3, tw * 0.35)):
            thick_line(L, fx + dx * 0.3, fy - tw * 0.6, fx + dx, fy, ww, 3, bark)
        nlimb = 4 if big else 3
        for k in range(nlimb):
            tx = ccx + (k - (nlimb - 1) / 2.0) * RX * 0.42 + rnd.uniform(-4, 4)
            ty = ccy + rnd.uniform(0.0, 0.4) * RY
            mx = fx + (tx - fx) * 0.4
            my = crown_bot + 8 - (crown_bot + 8 - ty) * 0.35
            thick_line(L, fx + (tx - fx) * 0.08, crown_bot + 12, mx, my, tw * 0.6, tw * 0.45, bark)
            thick_line(L, mx, my, tx, ty, tw * 0.45, 3, bark)
        # 树皮裂纹
        for _ in range(int(h / 10)):
            x = fx + rnd.randint(-int(tw / 2) + 1, int(tw / 2) - 2)
            y = rnd.randint(int(crown_bot), fy - 4)
            for j in range(rnd.randint(3, 9)):
                if L.g(x, y + j) in (C[bark[3]], C[bark[4]], C[bark[5]]):
                    L.p(x, y + j, bark[2])
    # ---- 树冠
    cl = Layer(L.ox, L.oy, L.w, L.h)
    info = crown(cl, ccx, ccy, RX, RY, seed + 7, sp, n_holes=(5 if big else (5 if sp == "zw" else 2)),
                 box=(fx - w / 2.0, fy - h, fx + w / 2.0))
    ramp = info["ramp"]
    # 花：桂花（金黄小点，藏在叶子里）、紫薇（粉的花穗，冠顶外沿）、香樟（冠顶几点嫩叶）
    frnd = random.Random(seed + 9)
    keys = list(info["idb"].keys())
    if sp == "gh":
        for _ in range(int(len(keys) / 70)):
            x, y = frnd.choice(keys)
            if C[ramp[1]] == cl.g(x, y) or C[ramp[2]] == cl.g(x, y) or C[ramp[3]] == cl.g(x, y):
                cl.p(x, y, "gd3")
                if frnd.random() < 0.6:
                    cl.p(x + 1, y, "gd4" if frnd.random() < 0.5 else "gd2")
                if frnd.random() < 0.4:
                    cl.p(x, y + 1, "gd2")
    elif sp == "zw":
        placed = []
        for _ in range(int(len(keys) / 150)):
            x, y = frnd.choice(keys)
            vv = (y - ccy) / RY
            if vv > 0.3 or info["tone"].get((x, y), 0) < 2 or any(abs(x - a) < 7 and abs(y - b) < 7 for (a, b) in placed):
                continue
            placed.append((x, y))
            pat = [".ab.", "aabb", "abbc", ".bc.", "..c."]
            for j, row in enumerate(pat):
                for i, ch in enumerate(row):
                    if ch != ".":
                        cl.p(x + i - 2, y + j - 3, {"a": "pk2", "b": "pk", "c": "pk0"}[ch])
    else:
        for _ in range(int(len(keys) / 180)):
            x, y = frnd.choice(keys)
            if (y - ccy) / RY < -0.25 and cl.g(x, y) in (C[ramp[4]], C[ramp[5]]):
                cl.p(x, y, "gC")
                cl.p(x + 1, y, ramp[6])
    cl.outline("gr0")
    # 左上受光边：最外一圈亮一档
    for (x, y) in keys:
        c = cl.g(x, y)
        if c[3] and c != C["gr0"] and not cl.has(x - 1, y - 1) and (x - ccx) * LIGHT[0] + (y - ccy) * LIGHT[1] > 0.2 * RX:
            if c in [C[n] for n in ramp]:
                i = [C[n] for n in ramp].index(c)
                cl.p(x, y, ramp[min(len(ramp) - 1, i + 1)])
    L.paste(cl)
    # 空当里露出一截枝（只有紫薇：冠松，看得见枝；深色，只画在空当里）
    for (hx, hy, hr) in []:
        br = Layer(L.ox, L.oy, L.w, L.h)
        d = 1 if hx > ccx else -1
        thick_line(br, hx - d * (hr + 2), hy + hr, hx + d * (hr + 2), hy - hr * 0.6, 2.6, 1.8, ["ol", "wd0", "wd1", "wd1", "wd2", "wd2"])
        for (x, y) in list(info["idb"].keys()):
            if br.has(x, y) and math.hypot(x + 0.5 - hx, (y + 0.5 - hy) * 1.15) < hr + 0.5:
                L.p(x, y, br.g(x, y))
    # 树冠底沿在树干上投一道影
    for x in range(int(fx - 14), int(fx + 15)):
        for y in range(int(ccy), fy):
            if cl.has(x, y) and not cl.has(x, y + 1):
                for j in range(1, 6):
                    c = L.g(x, y + j)
                    if c[3] and c in (C[bark[3]], C[bark[4]], C[bark[5]]):
                        L.p(x, y + j, bark[2] if j < 5 else bark[3])
                break
    L.outline("ol", pick=lambda x, y, nb: None if cl.has(x, y) else ("gr0" if RAMP_OF.get(nb, ("", 0))[0] in ("lf", "gr") else "ol"))
    return L


TREE_SPECIES = {
    "tree_0": "zh", "tree_1": "gh", "tree_2": "zh", "tree_3": "zw", "tree_4": "zh", "tree_5": "gh",
    "tree_6": "gh", "tree_7": "zh", "tree_8": "zw", "tree_9": "zh", "tree_10": "gh", "tree_11": "zh",
    "tree_22": "gh", "tree_27": "gh",
    "tree_13": "zh", "tree_14": "gh", "tree_15": "zw", "tree_16": "zh", "tree_17": "gh", "tree_18": "zh",
    "tree_19": "zw", "tree_20": "zh", "tree_21": "gh",
    "tree_24": "zh", "tree_25": "gh", "tree_28": "zh", "tree_29": "zw", "tree_30": "gh",
    "wed_tree": "zh",
}


# ================================================================== 临时底图（照分区图四种地，用果园的草和路的画法，不花太多功夫）
def grass_tone(x, y, bias=0.0):
    # 割草机推出来的一道道（横的，64 一道）
    band = ((y - 116) // 64) % 2
    stripe = 0.045 if band else -0.045
    n = vnoise(x, y * 1.3, 72, 11) * 0.45 + vnoise(x, y * 1.3, 21, 12) * 0.35 + vnoise(x, y, 5, 13) * 0.20 + bias + stripe
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


def in_rects(x, y, rects):
    for (a, b, c, d) in rects:
        if a <= x < c and b <= y < d:
            return True
    return False


SHRUB = [[0, 0, 740, 116], [796, 0, 1536, 116], [0, 116, 14, 262], [0, 338, 14, 742], [0, 818, 14, 1024],
         [1522, 116, 1536, 1024], [0, 1010, 1536, 1024]]
PATHS = [[0, 758, 798, 802], [738, 0, 798, 802], [0, 278, 238, 322], [216, 234, 742, 278], [216, 274, 238, 322]]
SAND = [1106, 256, 1494, 596]


def background():
    rnd = random.Random(7)
    L = Layer(0, 0, W, H)
    # 草坪
    for y in range(H):
        for x in range(W):
            L.px[x, y] = C[grass_tone(x, y)]

    def wob(v, seed, amp=4):
        return int(round((vnoise(v, 0, 13, seed) - 0.5) * amp))

    # 灌木边：一团团的深绿（每团一个小球的明暗）
    shrub_mask = set()
    for (a, b, c, d) in SHRUB:
        for y in range(b, d):
            for x in range(a, c):
                shrub_mask.add((x, y))
    gr = RAMPS["gr"]
    bushes = []
    for (a, b, c, d) in SHRUB:
        yy = b - 6
        while yy < d + 6:
            xx = a - 6
            while xx < c + 6:
                bushes.append((xx + rnd.uniform(0, 9), yy + rnd.uniform(0, 7), rnd.uniform(6, 10)))
                xx += 9
            yy += 7
    bushes.sort(key=lambda t: t[1])
    for (bx, by, br) in bushes:
        for y in range(int(by - br), int(by + br) + 1):
            for x in range(int(bx - br), int(bx + br) + 1):
                dx, dy = (x + 0.5 - bx) / br, (y + 0.5 - by) / br
                if dx * dx + dy * dy > 1 or not (0 <= x < W and 0 <= y < H):
                    continue
                # 只在灌木边范围里（下沿可以鼓出来 3 像素）
                if (x, y) not in shrub_mask and (x, y - 3) not in shrub_mask:
                    continue
                nz = math.sqrt(max(0.0, 1 - dx * dx - dy * dy))
                lum = dot3((dx, dy, nz), LIGHT) + (vnoise(x, y, 3, 21) - 0.5) * 0.4
                t = 0 if lum < -0.1 else (1 if lum < 0.25 else (2 if lum < 0.55 else 3))
                L.px[x, y] = C[gr[t]]
    # 灌木边脚下一两行影（先记下来再改，免得一行一行传下去）
    lawn_cols = (C["gr3"], C["gB"], C["gr4"])
    dark_cols = (C["gr0"], C["gr1"], C["gr2"])
    marks = []
    for y in range(1, H):
        for x in range(W):
            if L.px[x, y] in lawn_cols and L.px[x, y - 1] in dark_cols:
                marks.append((x, y))
    for (x, y) in marks:
        L.px[x, y] = C["gA"]
        if y + 1 < H and L.px[x, y + 1] in lawn_cols and x % 2 == 0:
            L.px[x, y + 1] = C["gA"]
    # 碎石小路
    def gravel(x, y):
        n = vnoise(x, y, 9, 82) * 0.6 + vnoise(x, y, 3, 83) * 0.4
        if n < 0.36:
            return "fl4"
        if n > 0.66:
            return "fl6"
        return "fl5"

    for (a, b, c, d) in PATHS:
        for y in range(max(0, b - 4), min(H, d + 4)):
            aa = a + (wob(y, 80 + a) if a > 0 else 0)
            cc = c + (wob(y, 81 + c) if c < W else 0)
            for x in range(max(0, aa), min(W, cc)):
                bb = b + (wob(x, 82 + b) if b > 0 else 0)
                dd = d + wob(x, 83 + d)
                if bb <= y < dd:
                    L.px[x, y] = C[gravel(x, y)]
    # 路沿：挨着草的西边、北边一两行压暗
    for y in range(1, H):
        for x in range(1, W):
            c = L.px[x, y]
            if not is_ramp(c, "fl"):
                continue
            if is_ramp(L.px[x - 1, y], "gr") or is_ramp(L.px[x, y - 1], "gr"):
                L.px[x, y] = C["fl3"]
    for _ in range(5200):
        x, y = rnd.randrange(0, W), rnd.randrange(0, H)
        if is_ramp(L.px[x, y], "fl") and x + 4 < W and y + 3 < H and is_ramp(L.px[x + 3, y + 2], "fl"):
            L.p(x, y, "fl7")
            L.p(x + 1, y, "fl6")
            L.p(x, y + 1, "fl3")
            L.p(x + 1, y + 1, "fl3")
    # 孩童区沙地 + 一圈木头围边
    a, b, c, d = SAND
    for y in range(b, d):
        for x in range(a, c):
            if x < a + 4 or x >= c - 4 or y < b + 4 or y >= d - 4:
                # 木围边：顶面亮、里侧暗
                inner = (x == a + 3 or x == c - 4 or y == b + 3 or y == d - 4)
                col = "wd2" if inner else ("wd4" if (x + y // 3) % 11 else "wd3")
                if y < b + 1 or x < a + 1:
                    col = "wd5"
                L.px[x, y] = C[col]
            else:
                n = vnoise(x, y, 11, 61) * 0.6 + vnoise(x, y, 3, 62) * 0.4
                col = "wl4" if n < 0.42 else ("wl5" if n > 0.6 else "wl4")
                if n < 0.3:
                    col = "wl3"
                if y < b + 7 or x < a + 7:
                    col = "wl3" if col != "wl5" else "wl4"
                L.px[x, y] = C[col]
    for _ in range(14):       # 小脚印
        x, y = rnd.randrange(a + 20, c - 20), rnd.randrange(b + 20, d - 20)
        for k in range(4):
            xx, yy = x + k * 9, y + (k % 2) * 4
            L.p(xx, yy, "wl3")
            L.p(xx + 1, yy, "wl3")
            L.p(xx, yy + 2, "wl3")
    # 草叶、零星小白花
    for cy in range(0, H, 7):
        for cx in range(0, W, 9):
            x = cx + rnd.randrange(0, 9)
            y = cy + rnd.randrange(0, 7)
            if not (0 < x < W - 5 and 0 < y < H - 2) or L.px[x, y] not in (C["gr3"], C["gB"], C["gr4"]):
                continue
            n = vnoise(x, y, 46, 31)
            if rnd.random() < 0.16 + max(0.0, (n - 0.4) * 0.8):
                tuft(L, x, y, rnd, 1 if rnd.random() < 0.7 else -1)
    for _ in range(160):
        fx, fy = rnd.randrange(20, W - 20), rnd.randrange(130, H - 20)
        for _k in range(rnd.randint(2, 5)):
            xx, yy = fx + rnd.randint(-8, 8), fy + rnd.randint(-5, 5)
            if L.px[xx, yy] in (C["gr3"], C["gB"], C["gr4"]) and L.px[xx + 1, yy + 1] in (C["gr3"], C["gB"], C["gr4"]):
                flower(L, xx, yy, rnd.choice(["daisy", "white", "white", "yellow"]))
    return L


# ================================================================== 地面装饰层（通道的白布 + 花瓣）
def ground_deco():
    rnd = random.Random(1203)
    L = Layer(300, 440, 260, 300)
    x0, x1, y0, y1 = 396, 444, 466, 712
    for y in range(y0, y1):
        for x in range(x0, x1):
            col = "wl5"
            if x in (x0, x1 - 1) or y == y1 - 1:
                col = "wl3"
            elif x in (x0 + 3, x1 - 4) and y < y1 - 3:
                col = "wl4"
            L.p(x, y, col)
    # 花瓣：布上靠台那头多、往南越来越少；一小撮一小撮
    for _ in range(46):
        y = int(y0 + 4 + (y1 - y0 - 10) * (rnd.random() ** 2.2))
        x = rnd.randint(x0 + 3, x1 - 5)
        for _k in range(rnd.randint(1, 3)):
            xx, yy = x + rnd.randint(-3, 3), y + rnd.randint(-2, 2)
            c = rnd.choice(["pk2", "pk2", "pk2", "pk", "wt"])
            L.p(xx, yy, c)
            if rnd.random() < 0.6:
                L.p(xx + 1, yy, shift(c, -1) if c != "wt" else "wl4")
    # 台前草地上稀稀的几片白、粉
    for _ in range(40):
        a = rnd.uniform(0.15, math.pi - 0.15)
        r = rnd.uniform(70, 115)
        x = int(420 + math.cos(a) * r)
        y = int(472 + math.sin(a) * r * 0.32)
        if x0 - 2 <= x <= x1 + 2:
            continue
        c = rnd.choice(["wt", "wt", "pk2"])
        L.p(x, y, c)
        if rnd.random() < 0.5:
            L.p(x + 1, y, "sv2" if c == "wt" else "pk")
    return L


# ================================================================== 地上的影子（档数图：临时底图、地面装饰层、以后 GPT 底图都照它挪档）
def shadow_map(items_meta):
    S = ShadeMap()
    for m in items_meta:
        kind, it = m["kind"], m["item"]
        if kind in ("chair",):
            x0, y0, x1, y1 = it["rect"]
            S.ellipse(x0 + 13, y1 - 5, 12, 7, -1.0)
            S.rect(x0 + 2, y1 - 13, x1 - 2, y1 - 1, -0.5)
        elif kind == "hedge":
            x0, y0, x1, y1 = it["rect"]
            S.ellipse((x0 + x1) / 2 + 4, y1 - 1, 15, 5, -1.0)
        elif kind == "tree":
            fx, fy = it["x"], it["y"]
            if fy > H + 10:
                continue
            big = it["w"] > 200
            if big:
                S.blob(fx + 60, fy + 8, 120, 30, -1.0, fx + fy)
            else:
                S.blob(fx + 18, fy + 3, 54, 16, -1.0, fx + fy)
            S.ellipse(fx + 5, fy, 14 if not big else 26, 5 if not big else 8, -1.0)
            rnd = random.Random(fx * 7 + fy)
            for _ in range(5):
                a = rnd.uniform(0, 6.283)
                r = rnd.uniform(0.3, 0.8)
                S.ellipse(fx + 18 + math.cos(a) * 48 * r, fy + 3 + math.sin(a) * 13 * r, rnd.uniform(3, 6), rnd.uniform(1.5, 2.5), 1.0, edge=1)
        elif kind == "stage":
            S.ellipse(STAGE["cx"] + 8, STAGE["cy"] + 5, STAGE["rx"] + 1, STAGE["ry"] + 1, -1.0)
            S.rect(400, 478, 448, 481, -1.0)
        elif kind == "flowers":
            for (x, y, rx, ry) in it["e"]:
                S.ellipse(x + 3, y + ry * 0.6, rx + 1, 3.5, -1.0)
        elif kind == "dessert":
            x0, y0, x1, y1 = it["rect"]
            S.rect(x0, y1, x1 + 2, y1 + 2, -1.0)
            S.ellipse((x0 + x1) / 2 + 8, y1 + 1, (x1 - x0) / 2 + 4, 5, -1.0)
        elif kind == "swing":
            for ax in (1209, 1291):
                S.ellipse(ax + 3, 382, 15, 3, -1.0)
                for j in range(20):
                    S.add(ax + 2 + j, 382 + j // 3, -1.0)
                    S.add(ax + 3 + j, 382 + j // 3, -1.0)
            S.ellipse(1254, 389, 20, 3.5, -1.0)
        elif kind == "slide":
            S.rect(1371, 488, 1400, 492, -1.0)
            for x in range(1398, 1480):
                t = (x - 1396) / 80.0
                ys = int(489 + 5 * t)
                S.rect(x, ys, x + 1, ys + 2 + int(4 * (1 - t)), -1.0)
        elif kind == "arch":
            for (x, y) in ((322, 436), (518, 436)):
                S.ellipse(x + 3, y, 16, 3, -1.0)
    return S


# ================================================================== 组装
def build(d):
    it = {i["id"]: i for i in d["items"]}
    out = []      # dict(name, layer, foot, foot_x, part, inst, kind, item, extra)

    def add(name, L, foot, fx, item, kind, **kw):
        m = dict(name=name, layer=L, foot=foot, foot_x=fx, part=item.get("part"), inst=item.get("inst"), kind=kind, item=item)
        m.update(kw)
        out.append(m)

    # 仪式区 LW-P01
    add("wed_tree", draw_tree(it["wed_tree"], "zh", 1777), 344, 420, it["wed_tree"], "tree")
    add("wed_arch", draw_arch(), 345, 420, it["wed_drape_top"], "arch",
        ids=["wed_drape_w", "wed_drape_e", "wed_drape_top"])
    add("wed_stage", draw_stage(), 348, 420, it["wed_stage"], "stage")
    add("wed_flowers", draw_wed_flowers(it["wed_flowers"], it["wed_leaves"]), 349, 420, it["wed_flowers"], "flowers",
        ids=["wed_flowers", "wed_leaves"])
    # 通道矮花丛 LW-P04
    for k in range(1, 11):
        h_ = it["hedge_%d" % k]
        add("hedge_%d" % k, draw_hedge(h_, k), h_["rect"][3], (h_["rect"][0] + h_["rect"][2]) // 2, h_, "hedge")
    # 白椅子 LW-P03
    for r in range(6):
        for side in ("L", "R"):
            for c in range(1, 5):
                cid = "chair_%d_%s%d" % (r, side, c)
                ch = it[cid]
                kind = "plain"
                if c == 1:
                    kind = "aisleL" if side == "L" else "aisleR"
                full, back = chair_parts(ch["rect"][0], ch["rect"][3], kind)
                cx_ = (ch["rect"][0] + ch["rect"][2]) // 2
                add(cid, full, ch["rect"][3], cx_, ch, "chair", back=back)
    # 甜品台 LW-T01
    add("dessert_table", draw_dessert(it["dessert_table"]), 470, 649, it["dessert_table"], "dessert")
    # 孩童区
    add("swing", draw_swing(it), 382, 1250, it["swing_post_w"], "swing",
        ids=["swing_post_w", "swing_post_e", "swing_bar", "swing_rope_w", "swing_rope_e", "swing_seat"])
    add("slide", draw_slide(it["slide_tower"], it["slide_chute"]), 494, 1420, it["slide_tower"], "slide",
        ids=["slide_tower", "slide_chute"])
    # 树
    for tid, sp in TREE_SPECIES.items():
        if tid == "wed_tree" or (QUICK and tid not in ("tree_3", "tree_4", "tree_14", "tree_24")):
            continue
        t = it[tid]
        seed = 900 + int(tid.split("_")[1]) * 37
        add(tid, draw_tree(t, sp, seed), t["y"], t["x"], t, "tree", species=sp)
    return out


def paste_clip(out, im, x, y):
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(out.size[0], x + im.size[0]), min(out.size[1], y + im.size[1])
    if x1 <= x0 or y1 <= y0:
        return
    out.alpha_composite(im.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))


def guest(n, frame=0, rows=84):
    im = Image.open(CHAR_DIR + "chr_LM-GUEST-%02d.png" % n).convert("RGBA")
    return im.crop((frame * 64, 0, frame * 64 + 64, rows))


def compose(base, deco, items, people=(), canvas=None):
    """base：底图 Image（可以 None = 透明）；deco：地面装饰层 Layer；items：东西；people：(图, 左上 x, 左上 y, 排序 y)"""
    out = base.copy() if base is not None else Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if deco is not None:
        paste_clip(out, deco.im, deco.ox, deco.oy)
    seq = []
    for m in items:
        seq.append((m["foot"], m["foot_x"], 0, m["layer"]))
        if m.get("back") is not None and m.get("seated"):
            seq.append((m["foot"] + 4, m["foot_x"], 2, m["back"]))
    for (im, x, y, sy) in people:
        seq.append((sy, x, 1, (im, x, y)))
    seq.sort(key=lambda t: (t[0], t[2], t[1]))
    for (foot, fx, kind, L) in seq:
        if kind == 1:
            im, x, y = L
            paste_clip(out, im, x, y)
        else:
            paste_clip(out, L.im, L.ox, L.oy)
    return out


def palette_check(im, name):
    cols = im.getcolors(1 << 22)
    used = set()
    for cnt, c in cols:
        if c[3] not in (0, 255):
            raise SystemExit("%s 有半透明像素 %s" % (name, c))
        if c[3] == 255:
            if c not in PAL_SET:
                raise SystemExit("%s 有调色板外的颜色 %s" % (name, c))
            used.add(c)
    return used


def crop_to_canvas(L):
    bb = L.im.getbbox()
    if bb is None:
        return None, None
    bb = (max(bb[0], -L.ox), max(bb[1], -L.oy), min(bb[2], W - L.ox), min(bb[3], H - L.oy))
    if bb[2] <= bb[0] or bb[3] <= bb[1]:
        return None, None
    return L.im.crop(bb), (L.ox + bb[0], L.oy + bb[1])


# ------------------------------------------------------------------ GPT 底图压色板
def srgb_to_lab(c):
    def f(u):
        u = u / 255.0
        return ((u + 0.055) / 1.055) ** 2.4 if u > 0.04045 else u / 12.92
    r, g, b = f(c[0]), f(c[1]), f(c[2])
    X = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    Y = (0.2126 * r + 0.7152 * g + 0.0722 * b)
    Z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def g_(t):
        return t ** (1 / 3.0) if t > 0.008856 else 7.787 * t + 16 / 116.0
    fx, fy, fz = g_(X), g_(Y), g_(Z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


GROUND_NAMES = RAMPS["gr"] + ["nl1", "nl2", "nl3"] + RAMPS["fl"] + ["wl2", "wl3", "wl4", "wl5"] + RAMPS["wd"] + ["wt", "sv2"]


def quantize_ground(im):
    """把 GPT 的底图压到这套色板里的地面颜色（草、叶、路、沙、木头、白）：每个像素取 Lab 里最近的一色"""
    im = im.convert("RGB").resize((W, H), Image.NEAREST) if im.size != (W, H) else im.convert("RGB")
    labs = [(n, srgb_to_lab(C[n])) for n in GROUND_NAMES]
    cache = {}
    out = Image.new("RGBA", (W, H))
    src = im.load()
    dst = out.load()
    for y in range(H):
        for x in range(W):
            c = src[x, y]
            q = cache.get(c)
            if q is None:
                l0 = srgb_to_lab(c)
                best = min(labs, key=lambda t: (t[1][0] - l0[0]) ** 2 * 0.8 + (t[1][1] - l0[1]) ** 2 + (t[1][2] - l0[2]) ** 2)
                q = C[best[0]]
                cache[c] = q
            dst[x, y] = q
    return out


def main():
    if "--snapshot" in sys.argv:
        d = json.load(open(LAYOUT, encoding="utf-8"))
        print(json.dumps(layout_snapshot(d), sort_keys=True, ensure_ascii=False, separators=(",", ":")))
        return
    d = check_layout()
    gpt = None
    if "--gpt" in sys.argv:
        gpt = sys.argv[sys.argv.index("--gpt") + 1]
    rnd_tag = None
    for a in sys.argv[1:]:
        if a.startswith("round"):
            rnd_tag = a
    os.makedirs(LAYER_DIR, exist_ok=True)
    items = build(d)
    deco = ground_deco()
    S = shadow_map(items)
    bg = background()
    S.apply(bg)
    S.apply(deco)
    if QUICK:
        seat = {m["name"]: m for m in items}
        people = []
        for (cid, g) in (("chair_0_L2", 3), ("chair_1_R3", 5), ("chair_2_L4", 9)):
            m = seat[cid]
            m["seated"] = True
            x0, y0, x1, y1 = m["item"]["rect"]
            people.append((guest(g, 12, 52), (x0 + x1) // 2 - 32, y1 - 22 - 52 + 2, y1 + 3))
        people.append((guest(1, 0), 652 - 32, 512 - 84, 512))
        withp = compose(bg.im, deco, items, people)
        withp.save(os.path.join(HERE, "quick_full.png"))
        withp.crop((280, 176, 640, 616)).resize((720, 880), Image.NEAREST).save(os.path.join(HERE, "quick_x2.png"))
        palette_check(withp.crop((0, 0, 10, 10)), "x")
        return
    used = palette_check(bg.im, "临时底图")
    used |= palette_check(deco.im, "地面装饰层")
    bg.im.save(os.path.join(LAYER_DIR, "bg_lawn_temp.png"))
    deco_im, deco_xy = crop_to_canvas(deco)
    deco_im.save(os.path.join(LAYER_DIR, "ground_deco.png"))
    S.to_image().save(os.path.join(LAYER_DIR, "shadow_steps.png"))
    meta = {"canvas": [W, H],
            "note": "x,y 是这张图左上角在画布上的位置；foot_y 是按着地线跟人排前后的那条线；ids 是这张图包了 layout.json 里哪几件；"
                    "叠法：底图 → ground_deco（地面装饰层）→ 其余按 foot_y 跟人一起排。"
                    "椅子的 back_* 是只有椅背的一张，有人坐的椅子才用，foot_y 比椅子大 4（压在坐着的人前面）",
            "layers": [{"name": "bg_lawn_temp", "file": "bg_lawn_temp.png", "x": 0, "y": 0, "w": W, "h": H, "foot_y": None,
                        "note": "临时底图（影子已经压进去了）；GPT 底图到了换成 bg_lawn_gpt.png"},
                       {"name": "ground_deco", "file": "ground_deco.png", "x": deco_xy[0], "y": deco_xy[1],
                        "w": deco_im.size[0], "h": deco_im.size[1], "foot_y": None, "note": "地面装饰层：通道白布、花瓣，平的，永远在人脚下"},
                       {"name": "shadow_steps", "file": "shadow_steps.png", "x": 0, "y": 0, "w": W, "h": H, "foot_y": None,
                        "note": "影子档数图（不是给游戏直接叠的）：灰 96 = 暗一档、64 = 暗两档、160 = 亮一档；GPT 底图压色板以后照它沿色带挪档"}]}
    for m in items:
        used |= palette_check(m["layer"].im, m["name"])
        im, xy = crop_to_canvas(m["layer"])
        if im is None:
            continue
        im.save(os.path.join(LAYER_DIR, m["name"] + ".png"))
        e = {"name": m["name"], "file": m["name"] + ".png", "x": xy[0], "y": xy[1], "w": im.size[0], "h": im.size[1],
             "foot_y": m["foot"], "foot_x": m["foot_x"], "part": m["part"], "inst": m["inst"],
             "ids": m.get("ids", [m["item"].get("id")])}
        if m.get("species"):
            e["species"] = {"zh": "香樟", "gh": "桂花", "zw": "紫薇"}[m["species"]]
        meta["layers"].append(e)
        if m.get("back") is not None:
            used |= palette_check(m["back"].im, m["name"] + "_back")
            bim, bxy = crop_to_canvas(m["back"])
            bim.save(os.path.join(LAYER_DIR, "back_" + m["name"] + ".png"))
            meta["layers"].append({"name": "back_" + m["name"], "file": "back_" + m["name"] + ".png", "x": bxy[0], "y": bxy[1],
                                   "w": bim.size[0], "h": bim.size[1], "foot_y": m["foot"] + 4, "foot_x": m["foot_x"],
                                   "only_when_seated": True, "of": m["name"]})
    json.dump(meta, open(os.path.join(LAYER_DIR, "layers.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    # 只有东西（透明底）
    objs = compose(None, None, items)
    objs.save(os.path.join(HERE, "lawn01_objects_only.png"))
    full = compose(bg.im, deco, items)
    full.save(os.path.join(HERE, "lawn01_full.png"))
    used |= palette_check(full, "整块")
    # 宾客替身：三位坐在椅子上（背影，只留上半身，椅背压在前面），一位站在甜品台前当尺子
    seat = {m["name"]: m for m in items}
    people = []
    for (cid, g) in (("chair_0_L2", 3), ("chair_1_R3", 5), ("chair_2_L4", 9)):
        m = seat[cid]
        m["seated"] = True
        x0, y0, x1, y1 = m["item"]["rect"]
        im = guest(g, 12, 52)
        people.append((im, (x0 + x1) // 2 - 32, y1 - 22 - 52 + 2, y1 + 3))
    stand = guest(1, 0)
    people.append((stand, 652 - 32, 512 - 84, 512))
    withp = compose(bg.im, deco, items, people)
    px0, py0 = 150, 30
    withp.crop((px0, py0, px0 + 540, py0 + 960)).save(os.path.join(HERE, "lawn01_phone.png"))
    withp.crop((280, 176, 640, 616)).resize((720, 880), Image.NEAREST).save(os.path.join(HERE, "lawn01_detail_x2.png"))
    # 对照：果园 | 草坪 | 宴会厅，同一比例（1:1）各裁 400×520
    cw, chh = 400, 520
    cmp_ = Image.new("RGBA", (cw * 3 + 16, chh), (34, 20, 15, 255))
    orch = Image.open(ORCHARD_FULL).convert("RGBA").crop((600, 420, 600 + cw, 420 + chh))
    lawn = withp.crop((230, 150, 230 + cw, 150 + chh))
    banq = Image.open(BANQUET).convert("RGBA").crop((560, 20, 560 + cw, 20 + chh))
    cmp_.paste(orch, (0, 0))
    cmp_.paste(lawn, (cw + 8, 0))
    cmp_.paste(banq, (2 * cw + 16, 0))
    cmp_.save(os.path.join(HERE, "lawn01_compare.png"))
    if gpt:
        q = quantize_ground(Image.open(gpt))
        gl = Layer(0, 0, W, H)
        gl.im = q
        gl.px = q.load()
        S.apply(gl)
        palette_check(gl.im, "GPT 底图（压过色板）")
        gl.im.save(os.path.join(LAYER_DIR, "bg_lawn_gpt.png"))
        compose(gl.im, deco, items).save(os.path.join(HERE, "lawn01_full_gpt.png"))
        print("GPT 底图已压色板、叠影子：layers/bg_lawn_gpt.png、lawn01_full_gpt.png")
    if rnd_tag:
        full.save(os.path.join(HERE, rnd_tag + ".png"))
        shutil.copy(os.path.abspath(__file__), os.path.join(HERE, "draw_lawn_%s.py" % rnd_tag.replace("round", "r")))
    print("调色板：定义 %d 色，实际用到 %d 色" % (len(PAL_SET), len(used)))
    print("没用到：", [k for k, v in C.items() if v not in used])


LAYOUT_SNAPSHOT = r'''{"flat":[[0,0,1536,1024],[0,116,1536,148],[0,244,1536,276],[0,372,1536,404],[0,500,1536,532],[0,628,1536,660],[0,756,1536,788],[0,884,1536,916],[0,0,740,116],[796,0,1536,116],[0,116,14,262],[0,338,14,742],[0,818,14,1024],[1522,116,1536,1024],[0,1010,1536,1024],[0,758,798,802],[0,762,794,798],[738,0,798,802],[742,0,794,798],[0,278,238,322],[0,282,234,318],[216,234,742,278],[220,238,742,274],[220,274,234,318],[1106,256,1494,596],[1110,260,1490,592]],"items":{"chair_0_L1":{"h":46,"rect":[349,492,371,506],"top":"#f4f1ea","type":"box"},"chair_0_L2":{"h":46,"rect":[319,492,341,506],"top":"#f4f1ea","type":"box"},"chair_0_L3":{"h":46,"rect":[289,492,311,506],"top":"#f4f1ea","type":"box"},"chair_0_L4":{"h":46,"rect":[259,492,281,506],"top":"#f4f1ea","type":"box"},"chair_0_R1":{"h":46,"rect":[469,492,491,506],"top":"#f4f1ea","type":"box"},"chair_0_R2":{"h":46,"rect":[499,492,521,506],"top":"#f4f1ea","type":"box"},"chair_0_R3":{"h":46,"rect":[529,492,551,506],"top":"#f4f1ea","type":"box"},"chair_0_R4":{"h":46,"rect":[559,492,581,506],"top":"#f4f1ea","type":"box"},"chair_1_L1":{"h":46,"rect":[349,530,371,544],"top":"#f4f1ea","type":"box"},"chair_1_L2":{"h":46,"rect":[319,530,341,544],"top":"#f4f1ea","type":"box"},"chair_1_L3":{"h":46,"rect":[289,530,311,544],"top":"#f4f1ea","type":"box"},"chair_1_L4":{"h":46,"rect":[259,530,281,544],"top":"#f4f1ea","type":"box"},"chair_1_R1":{"h":46,"rect":[469,530,491,544],"top":"#f4f1ea","type":"box"},"chair_1_R2":{"h":46,"rect":[499,530,521,544],"top":"#f4f1ea","type":"box"},"chair_1_R3":{"h":46,"rect":[529,530,551,544],"top":"#f4f1ea","type":"box"},"chair_1_R4":{"h":46,"rect":[559,530,581,544],"top":"#f4f1ea","type":"box"},"chair_2_L1":{"h":46,"rect":[349,568,371,582],"top":"#f4f1ea","type":"box"},"chair_2_L2":{"h":46,"rect":[319,568,341,582],"top":"#f4f1ea","type":"box"},"chair_2_L3":{"h":46,"rect":[289,568,311,582],"top":"#f4f1ea","type":"box"},"chair_2_L4":{"h":46,"rect":[259,568,281,582],"top":"#f4f1ea","type":"box"},"chair_2_R1":{"h":46,"rect":[469,568,491,582],"top":"#f4f1ea","type":"box"},"chair_2_R2":{"h":46,"rect":[499,568,521,582],"top":"#f4f1ea","type":"box"},"chair_2_R3":{"h":46,"rect":[529,568,551,582],"top":"#f4f1ea","type":"box"},"chair_2_R4":{"h":46,"rect":[559,568,581,582],"top":"#f4f1ea","type":"box"},"chair_3_L1":{"h":46,"rect":[349,606,371,620],"top":"#f4f1ea","type":"box"},"chair_3_L2":{"h":46,"rect":[319,606,341,620],"top":"#f4f1ea","type":"box"},"chair_3_L3":{"h":46,"rect":[289,606,311,620],"top":"#f4f1ea","type":"box"},"chair_3_L4":{"h":46,"rect":[259,606,281,620],"top":"#f4f1ea","type":"box"},"chair_3_R1":{"h":46,"rect":[469,606,491,620],"top":"#f4f1ea","type":"box"},"chair_3_R2":{"h":46,"rect":[499,606,521,620],"top":"#f4f1ea","type":"box"},"chair_3_R3":{"h":46,"rect":[529,606,551,620],"top":"#f4f1ea","type":"box"},"chair_3_R4":{"h":46,"rect":[559,606,581,620],"top":"#f4f1ea","type":"box"},"chair_4_L1":{"h":46,"rect":[349,644,371,658],"top":"#f4f1ea","type":"box"},"chair_4_L2":{"h":46,"rect":[319,644,341,658],"top":"#f4f1ea","type":"box"},"chair_4_L3":{"h":46,"rect":[289,644,311,658],"top":"#f4f1ea","type":"box"},"chair_4_L4":{"h":46,"rect":[259,644,281,658],"top":"#f4f1ea","type":"box"},"chair_4_R1":{"h":46,"rect":[469,644,491,658],"top":"#f4f1ea","type":"box"},"chair_4_R2":{"h":46,"rect":[499,644,521,658],"top":"#f4f1ea","type":"box"},"chair_4_R3":{"h":46,"rect":[529,644,551,658],"top":"#f4f1ea","type":"box"},"chair_4_R4":{"h":46,"rect":[559,644,581,658],"top":"#f4f1ea","type":"box"},"chair_5_L1":{"h":46,"rect":[349,682,371,696],"top":"#f4f1ea","type":"box"},"chair_5_L2":{"h":46,"rect":[319,682,341,696],"top":"#f4f1ea","type":"box"},"chair_5_L3":{"h":46,"rect":[289,682,311,696],"top":"#f4f1ea","type":"box"},"chair_5_L4":{"h":46,"rect":[259,682,281,696],"top":"#f4f1ea","type":"box"},"chair_5_R1":{"h":46,"rect":[469,682,491,696],"top":"#f4f1ea","type":"box"},"chair_5_R2":{"h":46,"rect":[499,682,521,696],"top":"#f4f1ea","type":"box"},"chair_5_R3":{"h":46,"rect":[529,682,551,696],"top":"#f4f1ea","type":"box"},"chair_5_R4":{"h":46,"rect":[559,682,581,696],"top":"#f4f1ea","type":"box"},"dessert_table":{"deco":[{"color":"#f7efe2","rect":[615,396,641,408]},{"color":"#f2a7c3","rect":[618,408,638,422]},{"color":"#f7efe2","rect":[613,422,643,432]},{"color":"#f2d98a","rect":[663,398,673,406]},{"color":"#f2d98a","rect":[659,406,677,416]},{"color":"#f2d98a","rect":[655,416,681,428]}],"h":36,"rect":[606,444,692,470],"top":"#ffffff","type":"box"},"hedge_1":{"deco":[{"color":"#fbf7ee","rect":[368,468,373,472]},{"color":"#fbf7ee","rect":[378,470,383,474]},{"color":"#f2a7c3","rect":[373,476,378,480]}],"h":29,"rect":[364,494,388,504],"top":"#6a9a5c","type":"box"},"hedge_10":{"deco":[{"color":"#fbf7ee","rect":[456,660,461,664]},{"color":"#fbf7ee","rect":[466,662,471,666]},{"color":"#f2a7c3","rect":[461,668,466,672]}],"h":29,"rect":[452,686,476,696],"top":"#6a9a5c","type":"box"},"hedge_2":{"deco":[{"color":"#fbf7ee","rect":[456,468,461,472]},{"color":"#fbf7ee","rect":[466,470,471,474]},{"color":"#f2a7c3","rect":[461,476,466,480]}],"h":29,"rect":[452,494,476,504],"top":"#6a9a5c","type":"box"},"hedge_3":{"deco":[{"color":"#fbf7ee","rect":[368,516,373,520]},{"color":"#fbf7ee","rect":[378,518,383,522]},{"color":"#f2a7c3","rect":[373,524,378,528]}],"h":29,"rect":[364,542,388,552],"top":"#6a9a5c","type":"box"},"hedge_4":{"deco":[{"color":"#fbf7ee","rect":[456,516,461,520]},{"color":"#fbf7ee","rect":[466,518,471,522]},{"color":"#f2a7c3","rect":[461,524,466,528]}],"h":29,"rect":[452,542,476,552],"top":"#6a9a5c","type":"box"},"hedge_5":{"deco":[{"color":"#fbf7ee","rect":[368,564,373,568]},{"color":"#fbf7ee","rect":[378,566,383,570]},{"color":"#f2a7c3","rect":[373,572,378,576]}],"h":29,"rect":[364,590,388,600],"top":"#6a9a5c","type":"box"},"hedge_6":{"deco":[{"color":"#fbf7ee","rect":[456,564,461,568]},{"color":"#fbf7ee","rect":[466,566,471,570]},{"color":"#f2a7c3","rect":[461,572,466,576]}],"h":29,"rect":[452,590,476,600],"top":"#6a9a5c","type":"box"},"hedge_7":{"deco":[{"color":"#fbf7ee","rect":[368,612,373,616]},{"color":"#fbf7ee","rect":[378,614,383,618]},{"color":"#f2a7c3","rect":[373,620,378,624]}],"h":29,"rect":[364,638,388,648],"top":"#6a9a5c","type":"box"},"hedge_8":{"deco":[{"color":"#fbf7ee","rect":[456,612,461,616]},{"color":"#fbf7ee","rect":[466,614,471,618]},{"color":"#f2a7c3","rect":[461,620,466,624]}],"h":29,"rect":[452,638,476,648],"top":"#6a9a5c","type":"box"},"hedge_9":{"deco":[{"color":"#fbf7ee","rect":[368,660,373,664]},{"color":"#fbf7ee","rect":[378,662,383,666]},{"color":"#f2a7c3","rect":[373,668,378,672]}],"h":29,"rect":[364,686,388,696],"top":"#6a9a5c","type":"box"},"slide_chute":{"block":[1396,440,1474,494],"foot":494,"pts":[[1396,398],[1474,480],[1474,494],[1396,418]],"type":"poly"},"slide_tower":{"h":72,"rect":[1372,470,1396,490],"top":"#c0392b","type":"box"},"swing_bar":{"foot":382,"thick":6,"top":270,"type":"beam","x0":1204,"x1":1296},"swing_post_e":{"h":104,"rect":[1288,374,1294,382],"top":"#6d4a38","type":"box"},"swing_post_w":{"h":104,"rect":[1206,374,1212,382],"top":"#6d4a38","type":"box"},"swing_rope_e":{"foot":386,"thick":84,"top":276,"type":"beam","x0":1262,"x1":1264},"swing_rope_w":{"foot":386,"thick":84,"top":276,"type":"beam","x0":1236,"x1":1238},"swing_seat":{"foot":387,"thick":6,"top":358,"type":"beam","x0":1232,"x1":1268},"tree_0":{"h":252,"type":"tree","w":120,"x":80,"y":168},"tree_1":{"h":252,"type":"tree","w":120,"x":200,"y":168},"tree_10":{"h":252,"type":"tree","w":120,"x":1380,"y":168},"tree_11":{"h":252,"type":"tree","w":120,"x":1480,"y":168},"tree_13":{"h":252,"type":"tree","w":120,"x":220,"y":1090},"tree_14":{"h":252,"type":"tree","w":120,"x":360,"y":1090},"tree_15":{"h":252,"type":"tree","w":120,"x":500,"y":1090},"tree_16":{"h":252,"type":"tree","w":120,"x":640,"y":1090},"tree_17":{"h":252,"type":"tree","w":120,"x":900,"y":1090},"tree_18":{"h":252,"type":"tree","w":120,"x":1040,"y":1090},"tree_19":{"h":252,"type":"tree","w":120,"x":1180,"y":1090},"tree_2":{"h":252,"type":"tree","w":120,"x":320,"y":168},"tree_20":{"h":252,"type":"tree","w":120,"x":1320,"y":1090},"tree_21":{"h":252,"type":"tree","w":120,"x":1460,"y":1090},"tree_22":{"h":252,"type":"tree","w":120,"x":44,"y":170},"tree_24":{"h":252,"type":"tree","w":120,"x":44,"y":560},"tree_25":{"h":252,"type":"tree","w":120,"x":44,"y":680},"tree_27":{"h":252,"type":"tree","w":120,"x":1490,"y":180},"tree_28":{"h":252,"type":"tree","w":120,"x":1490,"y":700},"tree_29":{"h":252,"type":"tree","w":120,"x":1490,"y":820},"tree_3":{"h":252,"type":"tree","w":120,"x":440,"y":168},"tree_30":{"h":252,"type":"tree","w":120,"x":1490,"y":930},"tree_4":{"h":252,"type":"tree","w":120,"x":560,"y":168},"tree_5":{"h":252,"type":"tree","w":120,"x":660,"y":168},"tree_6":{"h":252,"type":"tree","w":120,"x":900,"y":168},"tree_7":{"h":252,"type":"tree","w":120,"x":1020,"y":168},"tree_8":{"h":252,"type":"tree","w":120,"x":1140,"y":168},"tree_9":{"h":252,"type":"tree","w":120,"x":1260,"y":168},"wed_drape_e":{"foot":345,"pts":[[438,206],[458,206],[530,432],[506,432]],"type":"poly"},"wed_drape_top":{"foot":345,"pts":[[346,198],[494,198],[494,206],[420,238],[346,206]],"type":"poly"},"wed_drape_w":{"foot":345,"pts":[[382,206],[402,206],[334,432],[310,432]],"type":"poly"},"wed_flowers":{"e":[[326,402,14,9],[514,402,14,9],[350,444,12,8],[490,444,12,8],[316,424,9,7],[524,424,9,7]],"type":"puffs","y":349},"wed_leaves":{"e":[[334,412,8,6],[506,412,8,6],[358,454,7,5],[482,454,7,5]],"type":"puffs","y":349},"wed_stage":{"foot":348,"h":14,"rx":96,"ry":64,"top":"#f4f1ea","type":"cyl","x":420,"y":412},"wed_tree":{"h":336,"type":"tree","w":280,"x":420,"y":344}},"npcs":{"bridesmaid_1":[320,454],"bridesmaid_2":[296,478],"flower_kid_1":[394,490],"flower_kid_2":[446,490],"groomsman_1":[520,454],"groomsman_2":[544,478],"kid_1":[1250,364],"kid_2":[1352,526],"kid_3":[1176,470],"kid_4":[1290,604],"wed_bride":[432,408],"wed_groom":[408,408],"wed_guest_01":[330,509],"wed_guest_02":[300,509],"wed_guest_03":[270,509],"wed_guest_04":[510,509],"wed_guest_05":[540,509],"wed_guest_06":[570,509],"wed_guest_07":[330,547],"wed_guest_08":[300,547],"wed_guest_09":[270,547],"wed_guest_10":[510,547],"wed_guest_11":[540,547],"wed_guest_12":[570,547],"wed_guest_13":[330,585],"wed_guest_14":[300,585],"wed_guest_15":[270,585],"wed_guest_16":[510,585],"wed_guest_17":[540,585],"wed_guest_18":[570,585],"wed_guest_19":[330,623],"wed_guest_20":[300,623],"wed_guest_21":[270,623],"wed_guest_22":[510,623],"wed_guest_23":[540,623],"wed_guest_24":[570,623],"wed_host":[482,430]},"points":{"kids":[1300,520,70],"to_backhall":[40,300,50],"to_entrance":[40,780,50],"to_orchard":[768,160,60]},"size":[1536,1024],"walk":[[[16,124],[1520,124],[1520,996],[16,996]]]}'''

if __name__ == "__main__":
    main()
