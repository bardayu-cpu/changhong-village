#!/usr/bin/env python3
"""后厅麻将室：用代码画的像素成品（mahjong03，2026-10-03；标准见 docs/罗曼山庄画风.md 第 0 节）。
第三版在 06 第二版（分支 alt/cloud/mahjong-v2）上改：阿鱼嫌第二版「颜色太深了，看起来跟酱油一样很脏」，
地板换成三间共用的宽板蜜色木（backhall_floor.py，新色带 hw0～hw6），红木家具整体亮一档（BAM、lift_wood），
门口长红地毯换成跟宴会厅、走廊一家的正红，扑克牌大一号；摆法、桌椅位置跟第二版一模一样。
画法整套照休息间第三版、化妆间（1 倍颗粒、硬边、色带挪档、深褐描边、光从左上、按着地线分层），
墙、墙顶、踢脚线、地板跟休息间同一套接着画；调色板是那 62 色 + tl0（麻将桌绒面暗档）+ hw0～hw6（地板）。

只留氛围（阿鱼 10/3「先保留氛围」）：长辈在打麻将、客人能围观；不做能打的麻将、不画牌面——
桌上只有背面朝外的牌墙、立着的手牌背面和牌的侧边；朝镜头那家的手牌只画空白牌（没有任何花纹），而且被坐着的人挡住；
不画骰子点数、不画筹码和钱。打牌那桌（三个人，炸金花的氛围）只画扑克牌背（白边蓝心），不画牌面、钱、筹码。
门口写房间名的牌子归游戏程序（字牌），图上不写字、不画牌子。

用法（10/3 收进仓库，02 E）：python3 godot/tools/pixel_art/room_backhall_mahjong.py [--preview 目录]
  图层出到 assets/pixel_art/backhall_mahjong/（背景、每件单图、room.json），entrance.gd 的 _pixel_art() 读；--preview 再出下面那些预览图。
  样板原稿在 godot/回执/样板间-后厅三间-v3/draw_mahjong.py（01 画，第三版）；这份只改了出图的位置，画法一笔没动。
原稿用法：python3 draw_mahjong.py [roundN]（要跟 backhall_floor.py 放在同一个文件夹）
  出：mahjong03_room.png（整间 1:1，站了替身）、mahjong03_room_x2.png、mahjong03_room_empty.png（没人，游戏底图 + 家具）、
      mahjong03_phone.png（540×960）、mahjong03_with_lounge.png（休息间 + 麻将室并排）、
      mahjong03_compare.png（休息间 | 麻将室 | 宴会厅裁一块）、layers/（背景、每件单图、room.json）、layout补丁.json
  roundN 再多存 roundN.png（放大 2 倍、站替身）和 roundN_1x.png（1:1、没人）
坐标全用游戏画布坐标（1536×1024），1 个美术像素 = 1 个画布像素；地面前后 1 米 = 32 像素，左右和高 1 米 = 48 像素。
一件东西 = 占地（x0..x1, yf0..yf1）+ 高 z；顶面画在 y = yf - z。
只读仓库；写的东西全在这个脚本所在的文件夹。
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backhall_floor import HW_HEX, HW_RAMP, draw_floor_v3   # 地板 v3：三间共用一份（同一个文件夹）
import backhall_plan_c   # 10/4 方案 C：后厅四间整间平移（这间 −144），这里照旧按平移前的坐标画

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))   # 从脚本所在位置往上找仓库根
if not os.path.isdir(os.path.join(REPO, "godot", "assets")):  # v3 在仓库外的工作目录跑：指回仓库（只读）
    REPO = "/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件"
GODOT = os.path.join(REPO, "godot")
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_backhall", "layout.json")
CHAR_DIR = os.path.join(GODOT, "assets", "characters", "lm") + "/"
LOUNGE_DIR = os.path.join(GODOT, "assets", "pixel_art", "backhall_lounge")      # 休息间第三版（游戏里那套）
MAKEUP_DIR = os.path.join(GODOT, "assets", "pixel_art", "backhall_makeup")
# v2：三间一起换新地板。预览里的休息间、化妆间用这个文件夹里换了地板的副本出的图层（没有就退回游戏里那套）
if os.path.isdir(os.path.join(HERE, "lounge_layers")):
    LOUNGE_DIR = os.path.join(HERE, "lounge_layers")
if os.path.isdir(os.path.join(HERE, "makeup_layers")):
    MAKEUP_DIR = os.path.join(HERE, "makeup_layers")
KITCHEN_PNG = os.path.join(GODOT, "assets", "kitchen", "kitchen_room_v1.png")
BANQUET_PNG = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55", "base.png")
OUT = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None   # 预览图出到哪（不给就不出）
LAYERS = os.path.join(GODOT, "assets", "pixel_art", "backhall_mahjong")                 # 游戏用的图层
BG_CROP = (667, 104, 1008, 696)     # 背景进游戏的范围（平移前的坐标）：西墙外沿到东墙中间。10/4 方案 C 麻将室西边挨后厨，西墙 667～677 归这间画
DX = backhall_plan_c.DX["mahjong"]   # 进游戏时整间往西挪多少（东墙 1003～1013 落到跟休息室共用的 859～869；出 room.json 时加上，读 layout.json 时先挪回来再核）

# 整间出图的范围（画布坐标）：跟休息间、化妆间一样 352×600
X0, Y0, X1, Y1 = 664, 100, 1016, 700
W, H = X1 - X0, Y1 - Y0

# ------------------------------------------------------------------ 调色板（休息间、化妆间那 62 色原样 + tl0）
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
    "sv0": "#737a8f", "sv1": "#a3abbe", "sv2": "#d3d8e3",
    "pk0": "#a8455e", "pk2": "#f4bfc8",
    # 麻将室新加 1 色：绒面暗档（跟 tl、tl2 连成一条三档的青绿色带）
    "tl0": "#1c5150",
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
    "tl": ["tl0", "tl", "tl2"],
    "sv": ["sv0", "sv1", "sv2"],
    "pk": ["pk0", "pk", "pk2"],
}
RAMP_OF = {}
for rn, names in RAMPS.items():
    for i, n in enumerate(names):
        RAMP_OF[C[n]] = (rn, i)


def shift(col, k):
    c = C[col] if isinstance(col, str) else col
    if k == 0 or c not in RAMP_OF:
        return c
    rn, i = RAMP_OF[c]
    names = RAMPS[rn]
    return C[names[max(0, min(len(names) - 1, i + k))]]


def rname(ramp, i):
    names = RAMPS[ramp]
    return names[max(0, min(len(names) - 1, i))]


# ------------------------------------------------------------------ 画布（照休息间）
class Layer:
    def __init__(self, x0=X0, y0=Y0, w=W, h=H):
        self.ox, self.oy, self.w, self.h = x0, y0, w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
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

    def ring(self, x0, y0, x1, y1, col, only=None):
        tmp = set()
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        rx, ry = (x1 - x0) / 2.0, (y1 - y0) / 2.0
        for y in range(int(math.floor(y0)), int(math.ceil(y1))):
            for x in range(int(math.floor(x0)), int(math.ceil(x1))):
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

    def outline(self, col="ol", skip=None):
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


def sub(x0, y0, x1, y1):
    return Layer(x0=int(x0), y0=int(y0), w=int(x1 - x0), h=int(y1 - y0))


def paste_ol(L, s):
    s.outline()
    L.paste(s)


class ShadeMap:
    def __init__(self):
        self.v = [[0.0] * W for _ in range(H)]

    def add(self, x, y, val):
        x -= X0
        y -= Y0
        if 0 <= x < W and 0 <= y < H:
            self.v[y][x] += val

    def rect(self, x0, y0, x1, y1, val, feather=0):
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


def cone(S, cx, y_from, y_to, half0, spread, val, edge=1):
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


# ------------------------------------------------------------------ 墙（画布坐标）
CAP_Y0, CAP_Y1 = 104, 114          # 北墙墙顶（剖开的厚度）
FLOOR_Y = 226                      # 北墙脚 = 地板开始
WALL_W = (667, 677)                # 西墙（方案 C 起挨后厨，layout wall_1；这份画。原来跟休息间共用，归休息间画）
WALL_E = (1003, 1013)              # 东墙（方案 C 起跟休息室共用，layout wall_2；这份、休息室那份都画，落在同一处）
FRONT_TOP, FRONT_FACE, FRONT_BOT = 662, 674, 696
DOOR = (800, 880)                  # 门洞
MJ_POINT = (852, 420)              # 麻将室交互点（layout 原有）

# ------------------------------------------------------------------ 摆法（唯一的源：画图、影子、走路检查、layout 补丁都从这张表出）
# (id, 名字, 区, 占地 rect [x0, y0, x1, y1]（y 是地面前后）, 高 h, 挡不挡人, keep / moved / new, 真实尺寸 (宽, 深, 高) 米)
PLAN = [
    ("mahjong_table", "麻将桌 1（东边，四位长辈）", "牌桌 1", [921, 380, 964, 409], 36, True, "keep", (0.9, 0.9, 0.75)),
    ("mj1_chair_n", "红木椅（桌 1 北）", "牌桌 1", [931, 353, 953, 365], 46, True, "keep", (0.45, 0.4, 0.95)),
    ("mj1_chair_w", "红木椅（桌 1 西）", "牌桌 1", [891, 387, 913, 397], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mj1_chair_e", "红木椅（桌 1 东）", "牌桌 1", [972, 387, 994, 397], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mj1_chair_s", "红木椅（桌 1 南）", "牌桌 1", [931, 425, 953, 435], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mahjong_table_2", "麻将桌 2（西北）", "牌桌 2", [716, 300, 759, 329], 36, True, "keep", (0.9, 0.9, 0.75)),
    ("mj2_chair_n", "红木椅（桌 2 北）", "牌桌 2", [726, 273, 748, 285], 46, True, "keep", (0.45, 0.4, 0.95)),
    ("mj2_chair_w", "红木椅（桌 2 西）", "牌桌 2", [686, 307, 708, 317], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mj2_chair_e", "红木椅（桌 2 东）", "牌桌 2", [767, 307, 789, 317], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mj2_chair_s", "红木椅（桌 2 南）", "牌桌 2", [726, 345, 748, 355], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mahjong_table_3", "麻将桌 3（西南，南边空一位）", "牌桌 3", [716, 490, 759, 519], 36, True, "keep", (0.9, 0.9, 0.75)),
    ("mj3_chair_n", "红木椅（桌 3 北）", "牌桌 3", [726, 463, 748, 475], 46, True, "keep", (0.45, 0.4, 0.95)),
    ("mj3_chair_w", "红木椅（桌 3 西）", "牌桌 3", [686, 497, 708, 507], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mj3_chair_e", "红木椅（桌 3 东）", "牌桌 3", [767, 497, 789, 507], 46, True, "keep", (0.45, 0.3, 0.95)),
    ("mj3_chair_s", "红木椅（桌 3 南，空位）", "牌桌 3", [726, 535, 748, 545], 46, True, "keep", (0.45, 0.3, 0.95)),
    # 茶水
    ("mj_sideboard", "茶水柜（靠北墙：暖水瓶、长嘴铜壶、盖碗、喜糖罐、瓜子盘、茶叶罐、收音机）", "茶水", [810, 228, 934, 242], 40, True, "new", (2.6, 0.45, 0.85)),
    ("mj_stand_1", "茶凳（桌 1 东南角：盖碗、瓜子；地上一只红暖水瓶）", "牌桌 1", [966, 408, 990, 422], 22, True, "new", (0.5, 0.45, 0.45)),
    ("mj_stand_2", "茶凳（桌 2 西北角）", "牌桌 2", [688, 280, 712, 296], 22, True, "new", (0.5, 0.5, 0.45)),
    ("mj_stand_3", "茶凳（桌 3 西南角）", "牌桌 3", [688, 518, 712, 532], 22, True, "new", (0.5, 0.45, 0.45)),
    ("mj_tea_1", "小茶几连盖碗茶（东南歇脚，两把红木圈椅中间）", "东南歇脚", [934, 566, 963, 580], 24, True, "moved", (0.6, 0.45, 0.5)),
    ("mj_rest_chair_w", "红木圈椅（东南歇脚，茶几西边，朝南）", "东南歇脚", [906, 560, 930, 574], 46, True, "new", (0.5, 0.45, 0.95)),
    ("mj_rest_chair_e", "红木圈椅（东南歇脚，茶几东边，朝南）", "东南歇脚", [968, 560, 992, 574], 46, True, "new", (0.5, 0.45, 0.95)),
    ("mj_cage_stand", "鸟笼架（东北：两只鸟笼，一只搭着蓝布）", "角落", [936, 296, 960, 304], 86, True, "new", (0.5, 0.25, 1.8)),
    # v2（阿鱼 10/3「棋牌室可以再放3 个人在炸金花」；01 复述后阿鱼确认「只画牌背、不放钱」）：原来的长条板凳拿掉，那块空地放一桌三个人打牌
    ("card_table", "打牌的小方桌（三个人打扑克，只画牌背，不放钱、不放筹码）", "打牌", [826, 292, 862, 316], 34, True, "new", (0.75, 0.75, 0.7)),
    ("card_chair_n", "红木椅（打牌桌北）", "打牌", [833, 266, 855, 278], 46, True, "new", (0.45, 0.4, 0.95)),
    ("card_chair_w", "红木椅（打牌桌西）", "打牌", [800, 298, 822, 308], 46, True, "new", (0.45, 0.3, 0.95)),
    ("card_chair_e", "红木椅（打牌桌东）", "打牌", [866, 298, 888, 308], 46, True, "new", (0.45, 0.3, 0.95)),
    ("mj_candy_table", "喜糖台（桌 1 南边：一摞红礼盒、一大盘喜糖，客人随手拿）", "围观", [928, 492, 972, 506], 22, True, "new", (0.9, 0.45, 0.45)),
    ("mj_lamp_w", "落地宫灯（门里西边）", "门口", [779, 640, 791, 648], 80, True, "new", (0.25, 0.25, 1.65)),
    ("mj_lamp_e", "落地宫灯（门里东边）", "门口", [888, 640, 900, 648], 80, True, "new", (0.25, 0.25, 1.65)),
    ("mj_flower_stand", "高花几（东墙边：青花梅瓶插红梅）", "东墙边", [984, 516, 1000, 524], 44, True, "new", (0.35, 0.25, 0.9)),
    ("mj_coat_rack", "衣帽架（西墙边：长辈脱下的外套、草帽、红围巾）", "西墙边", [688, 408, 706, 416], 84, True, "new", (0.4, 0.25, 1.75)),
    ("mj_tea_2", "小茶几连盖碗茶（西南歇脚）", "西南歇脚", [682, 610, 711, 624], 24, True, "keep", (0.6, 0.45, 0.5)),
    ("mj_recliner", "红木罗汉榻（西南歇脚，v2 换掉竹躺椅：围板、红坐垫、两只圆枕）", "西南歇脚", [714, 602, 788, 620], 41, True, "new", (1.55, 0.55, 0.85)),
    # 角落
    ("mj_fan", "落地扇（东北角）", "角落", [978, 238, 996, 248], 62, True, "new", (0.4, 0.3, 1.3)),
    ("mj_plant_nw", "观音竹（西北角，大陶盆）", "角落", [679, 230, 699, 242], 86, True, "new", (0.45, 0.4, 1.8)),
    ("mj_plant_se", "发财树（东南角）", "角落", [980, 636, 1000, 650], 72, True, "new", (0.45, 0.45, 1.5)),
]
PLAN_BY = {p[0]: p for p in PLAN}
FLAT = [
    ("rug_mj1", "桌 1 下面的方地毯（红底回纹边）", [889, 345, 996, 442]),
    ("rug_mj2", "桌 2 下面的方地毯", [686, 265, 793, 362]),
    ("rug_mj3", "桌 3 下面的方地毯", [686, 455, 793, 552]),
    ("rug_rest", "东南歇脚的小地毯（米色心回纹边）", [900, 552, 998, 592]),
    ("rug_card", "打牌那桌下面的地毯", [796, 258, 892, 334]),
    ("runner", "门口一直铺到交互点的长红地毯（v2：换掉门里小地垫；跟宴会厅红毯一家）", [810, 440, 870, 684]),
]
# 替身（以后换 GPT 画的）：id、谁、定稿宾客几号、第几格、脚点、怎么坐（sit_n 坐北朝南 / sit_s 背对镜头 / sit_w 坐西朝东 / sit_e / stand）
STANDINS = [
    ("elder_n", "长辈（桌 1 北，朝南）", "10", 0, (942, 367), "sit_n"),
    ("elder_w", "长辈（桌 1 西，朝东）", "09", 8, (902, 399), "sit_w"),
    ("elder_e", "长辈（桌 1 东，朝西）", "05", 4, (983, 399), "sit_e"),
    ("elder_s", "长辈（桌 1 南，背对镜头）", "06", 12, (942, 437), "sit_s"),
    ("elder_5", "长辈（桌 2 北）", "03", 0, (737, 287), "sit_n"),
    ("elder_6", "长辈（桌 2 西）", "04", 8, (697, 319), "sit_w"),
    ("mj_guest_1", "宾客（桌 2 东）", "01", 4, (778, 319), "sit_e"),
    ("mj_guest_2", "宾客（桌 2 南，背对镜头）", "02", 12, (737, 357), "sit_s"),
    ("mj3_n", "长辈（桌 3 北，新加）", "08", 0, (737, 477), "sit_n"),
    ("mj3_w", "长辈（桌 3 西，新加）", "10", 8, (697, 509), "sit_w"),
    ("mj3_e", "长辈（桌 3 东，新加）", "02", 4, (778, 509), "sit_e"),
    ("card_n", "打牌的客人（北，朝南，新加）", "09", 0, (844, 280), "sit_n"),
    ("card_w", "打牌的客人（西，朝东，新加）", "06", 8, (811, 310), "sit_w"),
    ("card_e", "打牌的客人（东，朝西，新加）", "08", 4, (877, 310), "sit_e"),
]
SEATED = {"mahjong_table": "nwes", "mahjong_table_2": "nwes", "mahjong_table_3": "nwe"}
# 围观站人点（以后玩法用；代码不读）
SPOTS = [
    ("mahjong", "麻将室交互点（layout 原有）", MJ_POINT, 20),
    ("watch_mj1_w", "桌 1 西边看牌（站在西家身后）", (878, 392), 10),
    ("watch_mj1_s", "桌 1 西南角看牌", (918, 450), 10),
    ("watch_mj2_e", "桌 2 东南角看牌（站在东家、南家中间）", (790, 344), 10),
    ("watch_card_se", "打牌桌东南角看牌（v2 新加）", (880, 342), 10),
    ("watch_mj3_s", "桌 3 南边空位后面看牌", (737, 560), 10),
    ("watch_mj3_e", "桌 3 东边看牌", (802, 522), 10),
]
# 预览里站两个围观的小孩（定稿宾客 11、12 号），游戏里要不要放 01 定
WATCHERS = [
    ("watch_kid_1", "围观的小孩（桌 1 西南角，背对镜头看奶奶打牌）", "12", 12, (918, 450), "stand"),
    ("watch_kid_2", "围观的小孩（打牌桌东南角，背对镜头看大人打牌）", "11", 12, (880, 342), "stand"),
]
KEEP_IDS = [p[0] for p in PLAN if p[6] == "keep"]
LAYOUT_IDS = {it["id"] for it in json.load(open(LAYOUT, encoding="utf-8"))["items"] if "id" in it}


def check_layout():
    """三张桌、十二把椅子、两张茶几、墙、前沿矮墙、门口、交互点跟 layout.json 一致，不一致就停"""
    d = backhall_plan_c.shift_layout(json.load(open(LAYOUT, encoding="utf-8")), -DX)
    items = {it["id"]: it for it in d["items"] if "id" in it}
    bad = []
    want = {p[0]: (p[3], p[4]) for p in PLAN if p[6] == "keep"}
    # 10/4 方案 C 起：西墙 wall_1、东墙 wall_2，门洞两边 front_2（西段从后厨那头接过来）、front_3
    want.update({"wall_1": ([667, 226, 677, 684], 44), "wall_2": ([1003, 226, 1013, 684], 44),
                 "front_2": ([352, 684, 800, 696], 22), "front_3": ([880, 684, 1136, 696], 22)})
    must = [p[0] for p in PLAN if p[0].startswith("mahjong_table") or "_chair_" in p[0] and p[0][2] in "123"]
    if len(must) != 15:
        bad.append("脚本里桌椅不是 3 + 12 件：%d" % len(must))
    for iid, (rect, h) in want.items():
        it = items.get(iid)
        if it is None or list(it.get("rect", [])) != list(rect) or it.get("h") != h:
            bad.append("%s：脚本 %s h%s，布局 %s h%s" % (iid, rect, h, it and it.get("rect"), it and it.get("h")))
    pts = {p["id"]: p for p in d["points"]}
    if (pts["mahjong"]["x"], pts["mahjong"]["y"]) != MJ_POINT:
        bad.append("mahjong 交互点挪了：%s" % pts["mahjong"])
    npcs = {n["id"]: n for n in d["npcs"]}
    for (sid, who, code, frame, (fx, fy), mode) in STANDINS:
        if sid in npcs and (npcs[sid]["x"], npcs[sid]["y"]) != (fx, fy):
            bad.append("npc %s 的位置变了：%s" % (sid, (npcs[sid]["x"], npcs[sid]["y"])))
    if bad:
        raise SystemExit("layout.json 跟这版对不上（摆法改了，脚本停下）：\n" + "\n".join(bad))
    # 新加的东西不许压门口、不许压交互点四周
    for (iid, name, zone, r, h, block, st, real) in PLAN:
        x0, y0, x1, y1 = r
        if x1 > DOOR[0] - 6 and x0 < DOOR[1] + 6 and y1 > 600:
            raise SystemExit("%s 堵门口了" % iid)
        cx, cy = min(max(MJ_POINT[0], x0), x1), min(max(MJ_POINT[1], y0), y1)
        if math.hypot(cx - MJ_POINT[0], cy - MJ_POINT[1]) < 26:
            raise SystemExit("%s 离麻将室交互点太近" % iid)
        if not (WALL_W[1] <= x0 and x1 <= WALL_E[0] and FLOOR_Y <= y0 and y1 <= FRONT_TOP):
            raise SystemExit("%s 出了房间" % iid)
    for a in PLAN:
        for b in PLAN:
            if a[0] < b[0]:
                ra, rb = a[3], b[3]
                if ra[0] < rb[2] and rb[0] < ra[2] and ra[1] < rb[3] and rb[1] < ra[3]:
                    raise SystemExit("%s 跟 %s 占地叠在一起" % (a[0], b[0]))
    return d


# ================================================================== 背景：墙、地板、地毯
def draw_north_wall(L):
    """跟休息间一模一样的北墙；墙纸暗花、细竖条的起点都按休息间（x 331 起算）接着排"""
    x0, x1 = WALL_W[0], BG_CROP[2]
    L.rect(x0, CAP_Y1, x1, FLOOR_Y, "wl3")
    for y in range(CAP_Y1 + 5, 176):
        for x in range(x0, x1):
            gy = (y - 119) % 12
            gx = ((x - 331) + (6 if ((y - 119) // 12) % 2 else 0)) % 12
            if abs(gx - 6) + abs(gy - 6) == 2:
                L.p(x, y, "wl2")
    for x in range(338, x1, 20):
        if x < x0:
            continue
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
    px0 = WALL_W[1] + 4
    while px0 < WALL_E[0] - 4:
        pw = 22
        a, b = px0, min(px0 + pw, WALL_E[0] - 3)
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
        px0 += pw + 4
    L.hl(x0, x1, 181, "wd1")
    L.hl(x0, x1, 218, "wd4")
    L.rect(x0, 219, x1, 225, "wd1")
    L.hl(x0, x1, 219, "wd2")
    L.hl(x0, x1, 225, "wd0")
    L.rect(x0, CAP_Y0, x1, CAP_Y1, "wl4")
    L.hl(x0, x1, CAP_Y0, "ol")
    L.hl(x0, x1, CAP_Y0 + 1, "wl5")
    L.hl(x0, x1, CAP_Y1 - 1, "ol")


FLOOR_SEED = 2          # 三间各用自己的种子（化妆间 0、休息间 1、麻将室 2）
FLOOR_X = (WALL_W[0], WALL_E[1])
FLOOR_ROW = 12      # v2（阿鱼 10/3「地板太细了……颜色更深点，整体更大气一点」）：一排 12 像素（原来 7），三间同一排距从 y 226 起


def draw_floor(L):
    """地板 v3（阿鱼 10/3：01 版太细、06 第二版像酱油）：宽板蜜色木，三间共用 backhall_floor.py"""
    draw_floor_v3(L, FLOOR_X[0], FLOOR_X[1], Y1, seed=FLOOR_SEED)


KEY = ["11111110", "10000010", "10111010", "10101010", "10100010", "10111110", "10000000"]


def draw_rug(L, rect, style="red", medallion=False, bw=10):
    """回纹地毯（休息间那种）"""
    rx0, ry0, rx1, ry1 = rect
    base, grid, dot, m1, m2, m3 = {
        "red": ("rd3", "rd2", "gd2", "rd2", "rd4", "rd3"),
        "cream": ("wl3", "wl2", "rd3", "wl2", "wl4", "wl3"),
        "navy": ("bl1", "bl0", "gd2", "bl0", "bl2", "bl1"),
        "wine": ("rd2", "rd1", "gd2", "rd1", "rd3", "rd2"),
        "runner": ("rd3", None, None, "rd2", "rd4", "rd3"),     # v3 门口长红地毯：正红、不画网格
    }[style]
    L.rect(rx0, ry0, rx1, ry1, base)
    if grid is None:                     # v3 长红地毯：中间一列金菱形（照走廊那条红毯），里面一圈细金线
        cx = (rx0 + rx1) // 2
        for y in range(ry0 + bw + 8, ry1 - bw - 4, 18):
            L.poly([(cx, y - 3), (cx + 3, y), (cx, y + 3), (cx - 3, y)], "gd2")
            L.p(cx, y, "gd4")
            L.p(cx - 1, y - 1, "gd3")
        for (a, b) in ((rx0 + bw + 2, rx0 + bw + 3), (rx1 - bw - 3, rx1 - bw - 2)):
            L.rect(a, ry0 + bw + 2, b, ry1 - bw - 2, "rd2")
        L.rect(rx0 + bw + 2, ry0 + bw + 2, rx1 - bw - 2, ry0 + bw + 3, "rd2")
        L.rect(rx0 + bw + 2, ry1 - bw - 3, rx1 - bw - 2, ry1 - bw - 2, "rd2")
    for y in range(ry0 + bw + 1, ry1 - bw - 1) if grid is not None else ():
        for x in range(rx0 + bw + 1, rx1 - bw - 1):
            u = (x - rx0) % 12
            v = ((y - ry0) * 3 // 2) % 12
            if u == v or u == 11 - v:
                L.p(x, y, grid)
            if (u, v) in ((0, 0), (6, 6)):
                L.p(x, y, dot)
    if medallion:
        cx, cy = (rx0 + rx1) // 2, (ry0 + ry1) // 2
        sx = min(34, (rx1 - rx0) // 2 - bw - 4)
        sy = min(20, (ry1 - ry0) // 2 - bw - 4)
        L.ell(cx - sx, cy - sy, cx + sx, cy + sy, m1)
        L.ell(cx - sx + 4, cy - sy + 3, cx + sx - 4, cy + sy - 3, m2)
        L.ring(cx - sx + 4, cy - sy + 3, cx + sx - 4, cy + sy - 3, "gd3")
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
            L.p(rx0 - 1, y, "wl4")
            L.p(rx0 - 2, y, "wl3")
            L.p(rx1, y, "wl4")
            L.p(rx1 + 1, y, "wl3")


def draw_papercut(L, cx, cy, col="rd3", hole="wl3"):
    """红色团花剪纸（不画字）：外圈八瓣、每瓣一个镂空小孔，里面一圈断开的镂空环，花心一点金（照休息间）"""
    n, rd, pr, inner = 8, 6.0, 2.6, 4.2
    under = {}
    for y in range(int(cy) - 10, int(cy) + 12):
        for x in range(int(cx) - 10, int(cx) + 12):
            under[(x, y)] = L.g(x, y)
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
                L.p(x, y, col)
            if inner - 0.2 < d < inner + 0.8 and (math.atan2(py_ - cy, px_ - cx) * n / (2 * math.pi)) % 1 < 0.5:
                L.p(x, y, under[(x, y)] if hole is None else hole)
    for (qx, qy) in petals:
        X, Y = qx + 0.4 * (qx - cx) / rd - 0.5, qy + 0.4 * (qy - cy) / rd - 0.5
        L.p(X, Y, under.get((int(math.floor(X)), int(math.floor(Y))), C["wl3"]) if hole is None else hole)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        X, Y = cx + math.cos(a) * 1.6 - 0.5, cy + math.sin(a) * 1.6 - 0.5
        L.p(X, Y, under.get((int(math.floor(X)), int(math.floor(Y))), C["wl3"]) if hole is None else hole)
    L.p(cx - 0.5, cy - 0.5, "gd3")


KNOTS = [688, 740, 792, 846, 898, 950, 998]     # 北墙红绸的结


def draw_swag(L):
    """北墙上沿一整排红绸（跟休息间、化妆间一个做法）"""
    y0 = 116
    for k in range(len(KNOTS) - 1):
        a, b = KNOTS[k], KNOTS[k + 1]
        wdt = b - a
        depth = 6 + wdt * 0.05
        for x in range(a, b):
            t = (x + 0.5 - a) / wdt
            sag = math.sin(math.pi * t)
            yb = y0 + depth * sag
            for y in range(y0, int(yb) + 1):
                f = (y - y0) / max(1.0, yb - y0)
                lv = 3
                if f > 0.82:
                    lv = 2
                band = (y - y0 - 3 * sag)
                if 0 <= band < 1.2 or 4.5 <= band < 5.5:
                    lv = 2
                if 1.2 <= band < 2.4 and 0.2 < t < 0.8:
                    lv = 4
                L.p(x, y, rname("rd", lv))
            L.p(x, int(yb) + 1, "rd1")
            if x % 2 == 0:
                L.p(x, int(yb) + 2, "wl1")
        L.hl(a, b, y0 - 1, "rd2")
    for kx in KNOTS:
        cx = kx
        L.ell(cx - 4, 113, cx + 4, 121, "rd2")
        L.ell(cx - 3, 114, cx + 3, 120, "gd3")
        L.p(cx - 1, 115, "gd4")
        L.p(cx, 117, "rd3")
        L.p(cx + 1, 118, "gd1")
        if kx in LANTERN_KNOTS:
            continue
        ln = 6 if kx in (KNOTS[0], KNOTS[-1]) else 8
        for yy in range(121, 121 + ln):
            L.p(cx - 1, yy, "gd2")
            L.p(cx, yy, "gd3")
            L.p(cx + 1, yy, "gd1")
        L.hl(cx - 1, cx + 2, 121 + ln, "rd3")
        L.p(cx, 122 + ln, "rd2")


LANTERN_KNOTS = [792, 950]


def draw_lantern(L, cx, top, big=True):
    """红灯笼（挂在红绸结下面）：金顶、红肚子（竖棱、中间透亮）、金底、红穗（照化妆间）"""
    rx = 6 if big else 4
    hgt = 13 if big else 9
    L.vl(cx, 121, top, "gd1")
    L.rect(cx - 2, top, cx + 3, top + 2, "gd2")
    L.hl(cx - 2, cx + 3, top, "gd3")
    y0, y1 = top + 2, top + 2 + hgt
    L.ell(cx - rx, y0, cx + rx + 1, y1, "rd3")
    L.ell(cx - rx + 2, y0 + 2, cx + rx - 1, y1 - 2, "rd4")
    L.ell(cx - 1, y0 + 3, cx + 2, y1 - 3, "rd5")
    L.p(cx, y0 + 4, "gd4")
    L.vl(cx - rx + 2, y0 + 2, y1 - 2, "rd2")
    L.vl(cx + rx - 2, y0 + 2, y1 - 2, "rd2")
    L.vl(cx - 3, y0 + 1, y1 - 1, "rd3")
    L.vl(cx + 3, y0 + 1, y1 - 1, "rd3")
    L.ring(cx - rx, y0, cx + rx + 1, y1, "rd1", only=lambda x, y: x > cx + 1 or y > y1 - 3)
    L.rect(cx - 2, y1, cx + 3, y1 + 2, "gd2")
    L.hl(cx - 2, cx + 3, y1 + 1, "gd1")
    for yy in range(y1 + 2, y1 + 9):
        L.p(cx, yy, "rd3")
        L.p(cx + (1 if yy > y1 + 3 else -1), yy, "rd3" if yy < y1 + 7 else "rd2")
    L.p(cx - 1, y1 + 8, "rd2")


def draw_window(L):
    """北墙花窗（桌 2 上方）：深木框、方格窗棂、窗纸暖白，贴四张红窗花（两朵团花、两对角花），不写字"""
    x0, y0, x1, y1 = 708, 132, 768, 173
    # 外框
    L.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 3, "wd1")
    L.rect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, "wd3")
    L.hl(x0 - 1, x1 + 1, y0 - 1, "wd4")
    L.vl(x0 - 1, y0 - 1, y1 + 1, "wd4")
    L.hl(x0 - 2, x1 + 2, y1 + 1, "wd4")          # 窗台
    L.hl(x0 - 3, x1 + 3, y1 + 2, "wd2")
    L.hl(x0 - 3, x1 + 3, y1 + 3, "wd1")
    # 窗纸：上亮下暗一档（外头的光透进来）
    L.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, "wl5")
    for y in range(y0 + 1, y1 - 1):
        for x in range(x0 + 1, x1 - 1):
            if y > y0 + 26 or (y > y0 + 22 and (x + y) % 2 == 0):
                L.p(x, y, "wl4")
    # 窗棂：方格 + 中间一圈套方（步步锦的意思）
    for x in range(x0, x1, 10):
        L.vl(x, y0, y1, "wd2")
    for y in range(y0, y1, 10):
        L.hl(x0, x1, y, "wd2")
    L.vl(x1 - 1, y0, y1, "wd2")
    L.hl(x0, x1, y1 - 1, "wd2")
    # 中间套方
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    L.rect(cx - 9, cy - 7, cx + 10, cy + 8, "wd2")
    L.rect(cx - 8, cy - 6, cx + 9, cy + 7, "wl5")
    L.rect(cx - 8, cy + 1, cx + 9, cy + 7, "wl4")
    # 窗花：中间一朵大团花、两边各一朵小的，四角角花
    draw_papercut(L, cx + 0.5, cy + 0.5, hole=None)
    for (qx, qy) in ((x0 + 10, y0 + 15), (x1 - 10, y0 + 15)):
        draw_mini_round(L, qx, qy)
    for (ax, ay, sx, sy) in ((x0 + 1, y0 + 1, 1, 1), (x1 - 2, y0 + 1, -1, 1), (x0 + 1, y1 - 2, 1, -1),
                             (x1 - 2, y1 - 2, -1, -1)):
        for k in range(6):
            for j in range(6 - k):
                if (k + j) % 3 != 2:
                    L.p(ax + sx * j, ay + sy * k, "rd3")
        L.p(ax + sx * 1, ay + sy * 1, "wl4")
    # 窗框右下影
    L.vl(x1 + 2, y0, y1 + 3, "wl1")


def draw_small_flower(L, cx, cy):
    """小窗花：五瓣梅（红），花心镂空一点"""
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5
        L.ell(cx + math.cos(a) * 2.6 - 1.6, cy + math.sin(a) * 2.6 - 1.6, cx + math.cos(a) * 2.6 + 1.6,
              cy + math.sin(a) * 2.6 + 1.6, "rd3")
    L.ell(cx - 1.5, cy - 1.5, cx + 1.5, cy + 1.5, "rd3")
    L.p(cx, cy, "gd3")
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5 + math.pi / 5
        L.p(cx + math.cos(a) * 2.2, cy + math.sin(a) * 2.2, "wl5")


def draw_mini_round(L, cx, cy):
    """小圆窗花：一圈红（外沿八个小齿）、里面一圈镂空小孔、花心一点（只有圆和点，没有横竖笔画）"""
    for y in range(int(cy) - 5, int(cy) + 6):
        for x in range(int(cx) - 5, int(cx) + 6):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            a = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
            rim = 4.2 + 0.7 * math.cos(8 * a)
            if d <= rim:
                L.p(x, y, "rd3")
            if 2.0 <= d <= 3.0 and (a * 6 / (2 * math.pi)) % 1 < 0.45:
                L.p(x, y, "wl5")
    L.p(cx, cy, "gd3")


def draw_painting(L):
    """茶水柜上方一幅横幅挂画：熊猫翠竹（四川味），金框米色衬纸；没有题字、没有印章"""
    x0, y0, x1, y1 = 838, 127, 906, 168
    L.rect(x0, y0, x1, y1, "gd2")
    L.hl(x0, x1, y0, "gd4")
    L.vl(x0, y0, y1, "gd3")
    L.hl(x0, x1, y1 - 1, "gd0")
    L.vl(x1 - 1, y0, y1, "gd1")
    L.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, "gd1")
    L.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "wl4")
    ix0, iy0, ix1, iy1 = x0 + 5, y0 + 5, x1 - 5, y1 - 5
    L.rect(ix0, iy0, ix1, iy1, "wl5")
    # 远处淡竹（浅绿影子）
    for bx in (ix0 + 34, ix0 + 46, ix0 + 52):
        for y in range(iy0, iy1):
            if (y + bx) % 7 != 0:
                L.p(bx, y, "wl3")
    # 竹竿：几根，从下到上，节一格一格
    stalks = [(ix0 + 4, "gr2"), (ix0 + 9, "gr3"), (ix1 - 9, "gr2"), (ix1 - 4, "gr3")]
    for (sx, col) in stalks:
        for y in range(iy0, iy1):
            L.p(sx, y, col)
            L.p(sx + 1, y, "gr1" if col == "gr2" else "gr2")
            if (y - iy0) % 8 == 5:
                L.p(sx, y, "gr1")
                L.p(sx + 1, y, "gr0")
    # 竹叶：一簇簇斜着的短叶
    rnd = random.Random(5)
    for (sx, col) in stalks:
        for k in range(4):
            ly = iy0 + 2 + k * 7 + rnd.randrange(0, 3)
            side = -1 if (k + sx) % 2 else 1
            for j in range(3):
                for t in range(5):
                    L.p(sx + side * (2 + t), ly + j * 2 + t // 2, "gr3" if j == 0 else "gr2")
    # 石头
    L.poly([(ix0 + 16, iy1), (ix0 + 19, iy1 - 6), (ix0 + 26, iy1 - 8), (ix0 + 33, iy1 - 5), (ix0 + 36, iy1)], "wl2")
    L.hl(ix0 + 20, ix0 + 31, iy1 - 7, "wl1")
    # 熊猫：坐着抱一根竹子啃（黑耳朵、黑眼圈、黑四肢、白身子）
    pcx, pby = ix0 + 28, iy1 - 3
    L.ell(pcx - 6, pby - 11, pcx + 6, pby, "wt")             # 身子
    L.ring(pcx - 6, pby - 11, pcx + 6, pby, "wl2")
    L.ell(pcx - 4, pby - 18, pcx + 5, pby - 10, "wt")         # 头
    L.ring(pcx - 4, pby - 18, pcx + 5, pby - 10, "wl2")
    L.rect(pcx - 4, pby - 19, pcx - 2, pby - 17, "ik1")       # 耳朵
    L.rect(pcx + 3, pby - 19, pcx + 5, pby - 17, "ik1")
    L.p(pcx - 2, pby - 15, "ik1")                             # 眼圈
    L.p(pcx - 1, pby - 15, "ik1")
    L.p(pcx + 2, pby - 15, "ik1")
    L.p(pcx + 3, pby - 15, "ik1")
    L.p(pcx, pby - 13, "ik1")                                 # 鼻子
    L.rect(pcx - 6, pby - 9, pcx - 3, pby - 4, "ik1")         # 胳膊
    L.rect(pcx + 3, pby - 9, pcx + 6, pby - 4, "ik1")
    L.rect(pcx - 6, pby - 3, pcx - 2, pby, "ik1")             # 脚
    L.rect(pcx + 2, pby - 3, pcx + 6, pby, "ik1")
    L.vl(pcx + 6, pby - 16, pby - 3, "gr2")                    # 抱着的竹子
    L.p(pcx + 7, pby - 16, "gr3")
    L.p(pcx + 8, pby - 17, "gr3")
    # 墙上的影（右、下）
    L.vl(x1, y0 + 2, y1 + 1, "wl1")
    L.hl(x0 + 2, x1 + 1, y1, "wl1")


def draw_knot(L, cx, top):
    """大红中国结（东边墙上）：盘长结的方菱形 + 上面挂绳 + 下面长穗"""
    L.vl(cx, 121, top, "rd2")
    L.rect(cx - 1, top, cx + 2, top + 3, "rd3")
    cy = top + 11
    for y in range(cy - 8, cy + 9):
        for x in range(cx - 8, cx + 9):
            d = abs(x - cx) + abs(y - cy)
            if d <= 8:
                u, v = (x - cx + y - cy), (x - cx - y + cy)
                if d >= 7 or u % 4 == 0 or v % 4 == 0:
                    L.p(x, y, "rd3" if (x - cx) + (y - cy) < 2 else "rd2")
    for (dx, dy) in ((-8, 0), (8, 0), (0, -8)):
        L.ell(cx + dx - 2, cy + dy - 2, cx + dx + 3, cy + dy + 3, "rd3")
        L.p(cx + dx, cy + dy, "rd4")
    L.rect(cx - 1, cy + 8, cx + 2, cy + 11, "gd3")
    for yy in range(cy + 11, cy + 26):
        for dx in (-2, -1, 0, 1, 2):
            if abs(dx) < 2 or yy > cy + 14:
                L.p(cx + dx, yy, "rd3" if dx < 1 else "rd2")
    L.hl(cx - 2, cx + 3, cy + 26, "rd2")


def draw_doormat(L):
    x0, y0, x1, y1 = PLAN_FLAT("doormat")
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


def PLAN_FLAT(fid):
    return {f[0]: f[2] for f in FLAT}[fid]


def draw_petals(L):
    """门口几片花瓣，牌桌底下零星几粒瓜子壳（四川茶馆的样子，很少）"""
    rnd = random.Random(16)
    spots = [(806, 628), (822, 618), (857, 624), (874, 636), (791, 652), (884, 610), (839, 600), (848, 670),
             (866, 664), (812, 667), (899, 648), (830, 637)]
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
    for (x, y) in ((902, 418), (968, 416), (925, 440), (700, 340), (768, 336), (706, 530), (772, 470), (958, 372)):
        L.p(x, y, "wd1")
        L.p(x + 1, y, "wl4")              # v3：瓜子壳亮的那半（原来 fl6，地板不再用 fl）


# ================================================================== 小东西
def gaiwan(L, x, y):
    """盖碗：托、碗、盖（青花），x,y 是托的左上（照休息间）"""
    L.ell(x, y + 4, x + 9, y + 7, "bl4")
    L.hl(x + 1, x + 8, y + 5, "wt")
    L.rect(x + 2, y + 1, x + 7, y + 5, "wt")
    L.hl(x + 2, x + 7, y + 3, "bl2")
    L.vl(x + 6, y + 1, y + 5, "bl4")
    L.ell(x + 2, y - 1, x + 7, y + 2, "wt")
    L.p(x + 4, y - 1, "bl2")
    L.p(x + 5, y, "bl4")


def gaiwan_small(L, x, y):
    """小盖碗（7 宽）：放在茶凳上"""
    L.ell(x, y + 3, x + 7, y + 6, "bl4")
    L.rect(x + 1, y + 1, x + 6, y + 4, "wt")
    L.hl(x + 1, x + 6, y + 2, "bl2")
    L.vl(x + 5, y + 1, y + 4, "bl4")
    L.ell(x + 1, y - 1, x + 6, y + 2, "wt")
    L.p(x + 3, y - 1, "bl2")


def thermos(L, cx, base, tall=20, style="red"):
    """红色暖水瓶：红铁皮瓶身（牡丹花）、铝的肩和底圈、木塞、右边一个提手；style="bamboo" 是竹编外壳那种老式的"""
    w = 7
    x0 = cx - w // 2
    top = base - tall
    if style == "red":
        body = ("rd2", "rd3", "rd4")
    else:
        body = ("gd1", "gd2", "gd3")
    # 瓶身
    L.rect(x0, top + 5, x0 + w, base - 2, body[1])
    L.vl(x0, top + 5, base - 2, body[2])
    L.vl(x0 + 1, top + 5, base - 2, body[2] if style == "red" else body[1])
    L.vl(x0 + w - 1, top + 5, base - 2, body[0])
    if style == "red":
        # 牡丹：白底一朵粉红花、两片叶
        fy = top + 10
        L.ell(x0 + 1, fy - 2, x0 + 6, fy + 3, "pk")
        L.p(x0 + 3, fy, "pk2")
        L.p(x0 + 2, fy - 1, "pk2")
        L.p(x0 + 4, fy + 1, "pk0")
        L.p(x0 + 1, fy + 3, "gr3")
        L.p(x0 + 5, fy + 3, "gr2")
        L.hl(x0 + 1, x0 + w - 1, top + 6, "gd3")
        L.hl(x0 + 1, x0 + w - 1, base - 4, "gd3")
    else:
        for y in range(top + 5, base - 2):          # 竹编格子
            for x in range(x0, x0 + w):
                if (x + y) % 3 == 0:
                    L.p(x, y, body[0])
    # 肩（铝）+ 瓶口 + 木塞
    L.rect(x0, top + 3, x0 + w, top + 5, "sv1")
    L.hl(x0 + 1, x0 + w - 1, top + 3, "sv2")
    L.p(x0 + w - 1, top + 4, "sv0")
    L.rect(x0 + 2, top + 1, x0 + w - 2, top + 3, "sv1")
    L.p(x0 + 2, top + 1, "sv2")
    L.rect(x0 + 2, top - 1, x0 + w - 2, top + 1, "wd4")
    L.p(x0 + 2, top - 1, "wd5")
    # 底圈（铝）
    L.rect(x0, base - 2, x0 + w, base, "sv1")
    L.hl(x0, x0 + w, base - 2, "sv2")
    L.p(x0 + w - 1, base - 1, "sv0")
    # 提手：右边一道弯的铁丝
    L.vl(x0 + w, top + 6, top + 13, "sv1")
    L.p(x0 + w + 1, top + 7, "sv1")
    L.p(x0 + w + 1, top + 12, "sv1")
    L.vl(x0 + w + 2, top + 8, top + 12, "sv0")


def seed_plate(L, x, y, w=12):
    """一盘瓜子（米灰色小粒）+ 几颗喜糖（彩纸两头拧）"""
    L.ell(x, y, x + w, y + 6, "rd2")
    L.ell(x + 1, y, x + w - 1, y + 5, "rd3")
    rnd = random.Random(x * 7 + y)
    for _ in range(w + 4):
        px_ = x + 2 + rnd.randrange(0, w - 4)
        py_ = y + 1 + rnd.randrange(0, 3)
        L.p(px_, py_, rnd.choice(["wl1", "wl0", "ik2", "wl2"]))
    for (dx, dy, c) in ((3, 2, "gd3"), (w - 4, 1, "rd5"), (w // 2, 3, "pk")):
        L.p(x + dx, y + dy, c)
        L.p(x + dx + 1, y + dy, c)


def candy_jar(L, x, base):
    """玻璃糖罐：透明罐身（冷白边、里面一颗颗喜糖），红盖"""
    x1 = x + 10
    top = base - 13
    L.rect(x, top + 3, x1, base, "sv2")
    rnd = random.Random(3)
    for y in range(top + 5, base - 1):
        for xx in range(x + 1, x1 - 1):
            L.p(xx, y, rnd.choice(["rd4", "gd3", "pk", "wt", "rd5", "gd4", "rd3", "pk2"]))
    L.vl(x, top + 3, base, "wt")
    L.vl(x1 - 1, top + 3, base, "sv1")
    L.vl(x + 2, top + 4, base - 2, "wt")
    L.hl(x, x1, base - 1, "sv1")
    L.rect(x + 1, top, x1 - 1, top + 3, "rd3")
    L.hl(x + 1, x1 - 1, top, "rd4")
    L.rect(x + 3, top - 2, x1 - 3, top, "rd2")


def tea_canister(L, x, base, col="rd", band="gd"):
    """茶叶罐：圆筒，罐身一条金带、盖子"""
    w, hgt = 7, 11
    top = base - hgt
    L.rect(x, top + 2, x + w, base, rname(col, 3))
    L.vl(x, top + 2, base, rname(col, 4))
    L.vl(x + w - 1, top + 2, base, rname(col, 2))
    L.hl(x, x + w, top + 6, rname(band, 3))
    L.hl(x, x + w, top + 7, rname(band, 2))
    L.p(x + 3, top + 6, rname(band, 4))
    L.rect(x, top, x + w, top + 2, rname(col, 2))
    L.hl(x, x + w, top, rname(col, 4))


def copper_kettle(L, x, base):
    """长嘴铜壶（四川茶馆掺茶用）：扁圆铜壶身、壶盖钮、提梁，一根长长的壶嘴往左上伸"""
    cx = x + 8
    L.line(cx - 6, base - 6, cx - 24, base - 22, "cl1")    # 壶嘴（细长）
    L.line(cx - 6, base - 7, cx - 24, base - 23, "gd2")
    L.p(cx - 25, base - 24, "gd3")
    L.p(cx - 26, base - 24, "cl1")
    L.ell(cx - 8, base - 9, cx + 8, base, "cl1")
    L.ell(cx - 7, base - 9, cx + 7, base - 1, "cl2")
    L.ell(cx - 6, base - 8, cx + 1, base - 4, "cl3")
    L.p(cx - 4, base - 7, "gd4")
    L.hl(cx - 7, cx + 8, base - 5, "gd2")
    L.ell(cx - 4, base - 12, cx + 5, base - 7, "cl2")       # 壶盖
    L.hl(cx - 3, cx + 4, base - 11, "cl3")
    L.rect(cx - 1, base - 14, cx + 2, base - 12, "gd2")
    # 提梁
    L.line(cx - 6, base - 9, cx - 4, base - 18, "ik2")
    L.line(cx + 6, base - 9, cx + 4, base - 18, "ik2")
    L.hl(cx - 4, cx + 5, base - 18, "ik2")
    L.hl(cx - 3, cx + 4, base - 19, "ik3")


def birdcage(L, cx, base):
    """竹鸟笼（老茶客带来的）：圆顶、竹条、底圈，里面一只小黄鸟站在横杆上，顶上一个钩"""
    w, hgt = 13, 18
    x0, x1 = cx - w // 2, cx + w // 2 + 1
    top = base - hgt
    # 竹条（透着看得见后面的墙：竹条之间留空）
    for k, x in enumerate(range(x0, x1, 2)):
        t = (x + 0.5 - cx) / (w / 2.0)
        ytop = top + 4 + int(4 * t * t)
        L.vl(x, ytop, base - 2, "gd2" if k % 2 else "gd3")
    L.ring(x0, top + 1, x1, top + 12, "gd2", only=lambda x, y: y < top + 6)
    L.hl(x0, x1, base - 2, "wd3")
    L.hl(x0, x1, base - 1, "wd2")
    L.hl(x0 + 1, x1 - 1, base - 6, "gd1")
    # 小黄鸟
    bx, by = cx - 1, base - 9
    L.rect(bx, by, bx + 4, by + 3, "gd3")
    L.p(bx + 3, by - 1, "gd3")
    L.p(bx + 4, by - 1, "gd4")
    L.p(bx + 5, by, "or")
    L.p(bx + 3, by, "ik1")
    L.p(bx - 1, by + 2, "gd2")
    L.hl(cx - 4, cx + 5, base - 6, "wd4")
    # 顶钩
    L.vl(cx, top - 2, top + 2, "ik2")
    L.p(cx + 1, top - 3, "ik2")
    L.p(cx + 2, top - 2, "ik2")


def radio(L, x, base):
    """老式木壳收音机：木壳、喇叭布、一个金色调频窗（没有数字）、两个旋钮"""
    w, hgt = 16, 10
    top = base - hgt
    L.rect(x, top, x + w, base, "wd3")
    L.hl(x, x + w, top, "wd5")
    L.vl(x, top, base, "wd4")
    L.vl(x + w - 1, top, base, "wd1")
    L.hl(x, x + w, base - 1, "wd1")
    L.rect(x + 2, top + 2, x + 9, base - 2, "wl2")
    for yy in range(top + 3, base - 2, 2):
        L.hl(x + 2, x + 9, yy, "wl1")
    L.rect(x + 10, top + 2, x + 14, top + 4, "gd3")
    L.p(x + 11, top + 2, "gd4")
    L.p(x + 11, base - 3, "gd2")
    L.p(x + 13, base - 3, "gd2")


def leaf(L, cx, cy, ln, ang, wid, ramp_i, vein=True):
    """一片尖叶子（照休息间）"""
    ca, sa = math.cos(ang), math.sin(ang)
    pts = {}
    for y in range(int(cy - ln) - 1, int(cy + ln) + 2):
        for x in range(int(cx - ln) - 1, int(cx + ln) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = dx * ca + dy * sa
            v = -dx * sa + dy * ca
            if -ln / 2 <= u <= ln / 2:
                half = wid / 2 * math.sin(math.pi * (u + ln / 2) / ln) ** 0.75
                if abs(v) <= half:
                    pts[(x, y)] = (u, v, half)
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


# ================================================================== 家具
# v2（阿鱼「整体更大气一点」）：竹器全改成深红木（wd 色带），不画竹节——椅子、圈椅、茶凳、躺椅一起变沉、变厚重
BAM = ["wd2", "wd3", "wd4", "wd5"]      # v3 红木亮一档（第二版 wd1～wd4 在亮地板上发闷）；01 版是老竹的蜜色 gd1～gd4
NODE = "wd1"
WOOD = True                             # True：不画竹节


def bamboo_v(L, x, y0, y1, w=2, nodes=9):
    """一根竖的竹竿：左亮右暗，每隔几像素一道竹节（暗一档 + 下面一像素亮）"""
    for y in range(int(y0), int(y1)):
        L.p(x, y, BAM[3] if w > 1 else BAM[2])
        if w > 1:
            L.p(x + 1, y, BAM[1])
        if w > 2:
            L.p(x + 2, y, BAM[0])
    if nodes and not WOOD:
        for y in range(int(y0) + 3, int(y1) - 1, nodes):
            for k in range(w):
                L.p(x + k, y, NODE if k else BAM[1])


def bamboo_h(L, x0, x1, y, h=2, nodes=11):
    for x in range(int(x0), int(x1)):
        L.p(x, y, BAM[3])
        if h > 1:
            L.p(x, y + 1, BAM[1])
        if h > 2:
            L.p(x, y + 2, BAM[0])
    if nodes and not WOOD:
        for x in range(int(x0) + 4, int(x1) - 1, nodes):
            L.p(x, y, BAM[1])
            if h > 1:
                L.p(x, y + 1, NODE)


def prop_chair(rect, facing, arms=False, cushion=None):
    """竹靠背椅（四川茶馆那种）。facing：n = 摆在桌北、人朝南（看得见椅子正面）；s = 摆在桌南、背对镜头（看得见椅背后面，
    椅背是一根根竹条、中间留空，坐着的人从缝里看得见）；w = 摆在桌西、朝东（侧面）；e = 摆在桌东、朝西（侧面）。
    竹竿左亮右暗、一节一节；座面是横着的竹片；高 46（靠背顶），座面高 22"""
    x0, f0, x1, f1 = rect
    L = Layer()
    if facing in ("n", "s"):
        a, b = x0, x1
        if facing == "n":
            back_y = f0                 # 靠背在北沿
            st0, st1 = f0 - 22, f1 - 22
            bh = 42 if arms else 46     # 圈椅靠背矮一点
            # 后腿 = 靠背两根立柱，一直到地
            bamboo_v(L, a + 1, back_y - bh + 2, back_y, 2)
            bamboo_v(L, b - 3, back_y - bh + 2, back_y, 2)
            # 靠背顶上弯的一道（圈椅是中间拱起的搭脑）
            for x in range(a + 1, b - 1):
                arch = int(2 * math.sin(math.pi * (x - a - 1) / max(1, b - a - 3))) if arms else 0
                L.p(x, back_y - bh - arch, BAM[3])
                L.p(x, back_y - bh + 1 - arch, BAM[2])
                L.p(x, back_y - bh + 2 - arch, BAM[0])
            L.p(a + 1, back_y - bh, BAM[2])
            L.p(b - 2, back_y - bh, BAM[1])
            # 靠背竹条
            for x in range(a + 4, b - 4, 3):
                bamboo_v(L, x, back_y - bh + 3, back_y - 26, 1, nodes=0)
                L.p(x + 1, back_y - bh + 3, BAM[0])
            bamboo_h(L, a + 1, b - 1, back_y - 27, 2, nodes=0)
            # 座面
            L.rect(a, st0, b, st1, BAM[2])
            for y in range(st0, st1):
                if (y - st0) % 3 == 2:
                    L.hl(a, b, y, BAM[1])
            L.hl(a, b, st0, BAM[3])
            bamboo_h(L, a, b, st1, 2, nodes=7)          # 前沿一根竹
            if cushion:
                L.rect(a + 2, st0 - 1, b - 2, st1, rname(cushion, 3))
                L.hl(a + 3, b - 3, st0 - 1, rname(cushion, 4))
                L.vl(a + 2, st0, st1, rname(cushion, 4))
                L.hl(a + 2, b - 2, st1 - 1, rname(cushion, 2))
                L.vl(b - 3, st0, st1, rname(cushion, 2))
                L.p((a + b) // 2, (st0 + st1) // 2, rname(cushion, 1))
            if arms:                    # 圈椅的扶手圈：一道横着的弯竹，从上看是半个椭圆，前头断开，两头一根立柱落到座面
                ry0, ry1 = f0 - 34, f1 - 30
                cyy = (ry0 + ry1) / 2.0
                hoop = set()
                for y in range(ry0, ry1):
                    for x in range(a - 1, b + 1):
                        dx = (x + 0.5 - (a + b) / 2.0) / ((b - a + 2) / 2.0)
                        dy = (y + 0.5 - cyy) / ((ry1 - ry0) / 2.0)
                        d = dx * dx + dy * dy
                        if 0.55 <= d <= 1.0 and not (y > cyy and abs(dx) < 0.62):
                            hoop.add((x, y))
                for (x, y) in hoop:
                    up = (x, y - 1) not in hoop or (x - 1, y) not in hoop
                    L.p(x, y, BAM[3] if up and x < (a + b) // 2 + 3 else (BAM[2] if up else BAM[1]))
                for ax in (a - 1, b - 1):
                    bamboo_v(L, ax, int(cyy) + 3, st1 + 1, 2, nodes=0)
            # 前腿
            bamboo_v(L, a + 1, st1 + 2, f1, 2, nodes=6)
            bamboo_v(L, b - 3, st1 + 2, f1, 2, nodes=6)
            bamboo_h(L, a + 1, b - 1, f1 - 7, 1, nodes=0)   # 横枨
        else:
            back_y = f1                 # 靠背在南沿（朝镜头）
            st0, st1 = f0 - 22, f1 - 22
            # 先画看得见的远处：前腿（北边）
            bamboo_v(L, a + 2, st1 + 1, f0, 2, nodes=0)
            bamboo_v(L, b - 4, st1 + 1, f0, 2, nodes=0)
            L.shade_rect(a, st1 + 1, b, f0, -1)
            # 座面（大半被人挡住）
            L.rect(a + 1, st0, b - 1, st1, BAM[2])
            for y in range(st0, st1):
                if (y - st0) % 3 == 2:
                    L.hl(a + 1, b - 1, y, BAM[1])
            bamboo_h(L, a, b, st1, 2, nodes=7)
            # 后腿 = 靠背立柱（离镜头最近）
            bamboo_v(L, a, back_y - 44, back_y, 2)
            bamboo_v(L, b - 2, back_y - 44, back_y, 2)
            for x in range(a, b):
                L.p(x, back_y - 46, BAM[3])
                L.p(x, back_y - 45, BAM[2])
                L.p(x, back_y - 44, BAM[0])
            L.p(a, back_y - 46, BAM[2])
            # 靠背竹条：三根，中间留空
            for x in (a + 5, a + 10, a + 15):
                if x < b - 3:
                    bamboo_v(L, x, back_y - 43, back_y - 30, 1, nodes=0)
                    L.p(x + 1, back_y - 43, BAM[0])
            bamboo_h(L, a, b, back_y - 30, 2, nodes=0)
            bamboo_h(L, a + 2, b - 2, back_y - 8, 1, nodes=0)   # 横枨
    else:
        e = facing == "w"               # 摆在桌西、朝东：靠背在西边
        # 座面：侧面看是一条（前后 10 行 = 座面的宽）
        st0, st1 = f0 - 22, f1 - 22
        bx = x0 if e else x1 - 3        # 靠背那根竹在哪一边
        fx = x1 - 3 if e else x0        # 前腿
        # 远处（北边）一侧：后腿和前腿各一根，暗一档
        bamboo_v(L, bx, f0 - 46, f0, 2)
        bamboo_v(L, fx, st0 + 2, f0, 2, nodes=6)
        L.shade_rect(x0, f0 - 46, x1, f0, -1)
        # 靠背：两根立柱之间的竹条（侧着看见竹条的边）
        for y in range(f0 - 44, st0 + 1):
            for k in range(3):
                L.p(bx + k, y + (f1 - f0) * 0, BAM[2] if k == 1 else BAM[1])
        if arms:                        # 远处那根扶手（暗一档）
            ax0, ax1 = min(bx, fx), max(bx, fx) + 2
            bamboo_h(L, ax0, ax1, f0 - 33, 2, nodes=0)
            L.shade_rect(ax0, f0 - 33, ax1, f0 - 31, -1)
        # 座面
        L.rect(x0 + 1, st0, x1 - 1, st1, BAM[2])
        for x in range(x0 + 1, x1 - 1):
            if (x - x0) % 3 == 2:
                L.vl(x, st0, st1, BAM[1])
        L.hl(x0 + 1, x1 - 1, st0, BAM[3])
        if cushion:                     # 座上一块红垫子（鼓一点、一颗扣）
            ca, cb = (x0 + 3, x1 - 2) if e else (x0 + 2, x1 - 3)
            L.rect(ca, st0 - 1, cb, st1, rname(cushion, 3))
            L.hl(ca + 1, cb - 1, st0 - 1, rname(cushion, 4))
            L.vl(ca, st0, st1, rname(cushion, 4))
            L.hl(ca, cb, st1 - 1, rname(cushion, 2))
            L.vl(cb - 1, st0, st1, rname(cushion, 2))
            L.p((ca + cb) // 2, (st0 + st1) // 2, rname(cushion, 1))
        bamboo_h(L, x0, x1, st1, 2, nodes=7)
        # 近处（南边）一侧：后腿连靠背立柱一直到地，前腿，横枨
        bamboo_v(L, bx, f1 - 46, f1, 2)
        for x in range(bx - 1, bx + 3):
            L.p(x, f1 - 46, BAM[3])
            L.p(x, f1 - 47, BAM[2])
        bamboo_v(L, fx, st1 + 2, f1, 2, nodes=6)
        bamboo_h(L, x0 + 1, x1 - 1, f1 - 7, 1, nodes=0)
        if arms:                        # 近处的扶手：从靠背伸到前腿上头，前头一根立柱
            ax0, ax1 = min(bx, fx), max(bx, fx) + 2
            bamboo_h(L, ax0, ax1, f1 - 33, 2, nodes=0)
            L.p(fx if e else fx + 1, f1 - 33, BAM[3])
            bamboo_v(L, fx, f1 - 31, st1, 2, nodes=0)
            for x in range(ax0 + 3, ax1 - 3, 4):            # 扶手下面几根细竹
                L.vl(x, f1 - 31, st1, BAM[1])
    L.outline()
    foot = f1 + 3 if facing == "s" else f1        # 背对镜头的椅子要压在坐着的人前面
    return L, foot


TILE_BACK = ("gd2", "gd3", "gd4")       # 牌背：金黄（暗、中、亮）
TILE_FACE = ("wl3", "wl5", "wt")        # 牌的象牙白（只露侧边和空白的面，没有任何花纹）


WALLS = {   # 每桌打到哪了（四面牌墙各剩多长，0～1）：桌 2 刚码好牌，桌 1、桌 3 打到一半，墙短了、断了一截
    "mahjong_table": (0.55, 1.0, 1.0, 0.6),
    "mahjong_table_2": (1.0, 1.0, 1.0, 1.0),
    "mahjong_table_3": (1.0, 0.7, 0.5, 1.0),
}


def prop_mj_table(tid, rect, seated):
    """麻将桌：深色木桌、浅木桌沿、青绿绒面；四面牌墙（背面朝上、两层摞着，只看得见金黄的牌背和象牙白的侧边）；
    有人坐的那一面摆一排立着的手牌：北边那家的手牌背面朝镜头（金黄）；东西两家的手牌只看得见顶边和侧边；
    南边那家（背对镜头）的手牌朝着他，画成空白的象牙白小方块，再被他的背挡住。中间不放打出来的牌、不放骰子。"""
    x0, yf0, x1, yf1 = rect
    h = 36
    ty0, ty1 = yf0 - h, yf1 - h
    L = Layer()
    # 后腿（藏在牙板后头，露一截暗的）
    for lx in (x0 + 2, x1 - 5):
        L.rect(lx, ty1 + 3, lx + 3, yf0, "wd1")
    # 桌下暗处（看得见后腿之间的横枨）
    L.hl(x0 + 4, x1 - 4, yf0 - 6, "wd0")
    # 牙板
    L.rect(x0, ty1 + 2, x1, ty1 + 7, "wd2")
    L.hl(x0, x1, ty1 + 2, "wd3")
    L.hl(x0 + 1, x1 - 1, ty1 + 6, "wd1")
    mx = (x0 + x1) // 2
    L.rect(mx - 4, ty1 + 5, mx + 5, ty1 + 9, "wd2")       # 中间一朵卷云
    L.p(mx - 2, ty1 + 5, "wd4")
    L.p(mx + 2, ty1 + 5, "wd4")
    L.hl(mx - 3, mx + 4, ty1 + 8, "wd1")
    # 前腿（方腿、内收的马蹄足）
    for lx in (x0, x1 - 4):
        L.rect(lx, ty1 + 2, lx + 4, yf1 - 2, "wd2")
        L.vl(lx, ty1 + 2, yf1 - 2, "wd3")
        L.vl(lx + 3, ty1 + 2, yf1 - 2, "wd1")
    L.rect(x0, yf1 - 2, x0 + 5, yf1, "wd2")
    L.hl(x0, x0 + 5, yf1 - 2, "wd3")
    L.rect(x1 - 5, yf1 - 2, x1, yf1, "wd2")
    L.hl(x1 - 5, x1, yf1 - 2, "wd3")
    L.hl(x0 + 4, x1 - 4, yf1 - 9, "wd1")                   # 前面的横枨
    L.hl(x0 + 4, x1 - 4, yf1 - 10, "wd3")
    # 桌面：木框（左上亮、右下暗）
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    L.hl(x0, x1, ty1 - 1, "wd4")
    L.hl(x0, x1, ty1, "wd4")                              # 桌沿厚度
    L.hl(x0, x1, ty1 + 1, "wd2")
    # 绒面（凹进去：上边、左边一道桌框的影）
    fx0, fy0, fx1, fy1 = x0 + 3, ty0 + 3, x1 - 3, ty1 - 3
    L.rect(fx0, fy0, fx1, fy1, "tl")
    L.hl(fx0, fx1, fy0, "tl0")
    L.vl(fx0, fy0, fy1, "tl0")
    L.hl(fx0 + 1, fx1, fy1 - 1, "tl2")                   # 下沿、右沿受光的一道
    L.vl(fx1 - 1, fy0 + 1, fy1, "tl2")
    L.hl(x0 + 2, x1 - 2, ty0 + 2, "wd2")                  # 框里口
    L.vl(x0 + 2, ty0 + 2, ty1 - 2, "wd2")
    FW, FH = fx1 - fx0, fy1 - fy0                         # 37 × 23
    B0, B1, B2 = TILE_BACK
    I0, I1, I2 = TILE_FACE

    def shadow_px(x, y):
        if L.g(x, y) in (C["tl"], C["tl2"]):
            L.p(x, y, "tl0")

    def wall_h(xa, xb, y):
        """横着的一面牌墙：两层，顶上一层牌背（2 行），朝南的侧边：象牙白 + 下层牌背（各 1 行），每 3 像素一摞"""
        for x in range(xa, xb):
            sep = (x - xa) % 3 == 2
            L.p(x, y, B2 if not sep else B1)
            L.p(x, y + 1, B1 if not sep else B0)
            L.p(x, y + 2, I2 if not sep else I0)
            L.p(x, y + 3, B0)
        for x in range(xa + 1, xb + 1):
            shadow_px(x, y + 4)
        for y2 in range(y + 1, y + 4):
            shadow_px(xb, y2)

    def wall_v(x, ya, yb):
        """竖着的一面牌墙：从上看是 3 像素宽的牌背，每 3 像素一道缝；南头露出侧边"""
        for y in range(ya, yb):
            sep = (y - ya) % 3 == 2
            L.p(x, y, B2 if not sep else B1)
            L.p(x + 1, y, B1 if not sep else B0)
            L.p(x + 2, y, B0)
        L.hl(x, x + 3, yb, I2)
        L.hl(x, x + 3, yb + 1, B0)
        for y in range(ya + 1, yb + 2):
            shadow_px(x + 3, y)
        for xx in range(x + 1, x + 4):
            shadow_px(xx, yb + 2)

    # 四面牌墙（围成一个方；打到一半的桌，有的墙短了一截）
    wn, ws, ww, we = WALLS[tid]
    xa, xb = fx0 + 8, fx1 - 8
    ln = int(round((xb - xa) * wn / 3.0)) * 3
    wall_h(xb - ln, xb, fy0 + 5)                          # 北墙（从东头往西剩）
    ln = int(round((xb - xa) * ws / 3.0)) * 3
    wall_h(xa, xa + ln, fy1 - 8)                          # 南墙（从西头往东剩）
    ya, yb = fy0 + 7, fy1 - 9
    ln = max(3, int(round((yb - ya) * ww / 3.0)) * 3)
    wall_v(fx0 + 4, yb - ln, yb)                          # 西墙
    ln = max(3, int(round((yb - ya) * we / 3.0)) * 3)
    wall_v(fx1 - 7, ya, ya + ln)                          # 东墙
    # 手牌
    if "n" in seated:          # 北家：背面朝镜头（顶边象牙白一行 + 牌背两行），每 3 像素一张
        xa, xb = fx0 + 7, fx1 - 6
        for x in range(xa, xb):
            sep = (x - xa) % 3 == 2
            L.p(x, fy0, I2 if not sep else I0)
            L.p(x, fy0 + 1, B2 if not sep else B1)
            L.p(x, fy0 + 2, B1 if not sep else B0)
        for x in range(xa + 1, xb + 1):
            shadow_px(x, fy0 + 3)
    if "w" in seated:          # 西家：从上看一条，靠西那半是象牙白（牌面朝他），靠东那半是牌背
        ya, yb = fy0 + 4, fy1 - 3
        for y in range(ya, yb):
            sep = (y - ya) % 3 == 2
            L.p(fx0 + 1, y, I2 if not sep else I0)
            L.p(fx0 + 2, y, B1 if not sep else B0)
        L.hl(fx0 + 1, fx0 + 3, yb, B0)
        for y in range(ya + 1, yb + 1):
            shadow_px(fx0 + 3, y)
    if "e" in seated:
        ya, yb = fy0 + 4, fy1 - 3
        for y in range(ya, yb):
            sep = (y - ya) % 3 == 2
            L.p(fx1 - 3, y, B2 if not sep else B1)
            L.p(fx1 - 2, y, I1 if not sep else I0)
        L.hl(fx1 - 3, fx1 - 1, yb, B0)
        for y in range(ya + 1, yb + 1):
            shadow_px(fx1 - 1, y)
    if "s" in seated:          # 南家：牌面朝他（朝镜头），画成空白象牙白，被人挡住
        xa, xb = fx0 + 7, fx1 - 6
        for x in range(xa, xb):
            sep = (x - xa) % 3 == 2
            L.p(x, fy1 - 3, B1 if not sep else B0)
            L.p(x, fy1 - 2, I1 if not sep else I0)
            L.p(x, fy1 - 1, I1 if not sep else I0)
    L.outline()
    return L, yf1


CARD_BACK = ("bl0", "bl1", "wt")        # 扑克牌背：白边、蓝底（跟金黄的麻将牌背分开）


def card_back(L, x, y, w=3, h=4):
    """一张扑克牌的背面（从上看）：白边一圈、蓝底（右下一线深蓝，像有厚度）；不画任何牌面"""
    L.rect(x, y, x + w, y + h, CARD_BACK[2])
    if w > 2 and h > 2:
        L.rect(x + 1, y + 1, x + w - 1, y + h - 1, CARD_BACK[1])
    if w > 3 and h > 3:
        L.rect(x + 1, y + 1, x + w - 2, y + h - 2, "bl2")


def prop_card_table(rect):
    """打牌的小方桌（v2 新加）：深木桌、红桌布垂一圈、金边；桌中间一小叠牌（背面朝上），
    三家面前各几张牌背（北家竖着拿、背朝镜头；东西两家扣在桌沿）；南边空着、朝门口。
    **只画牌背**：不画牌面、不画钱、不画筹码、不画骰子（小游戏审核会把赌博画面打回）"""
    x0, yf0, x1, yf1 = rect
    h = 34
    ty0, ty1 = yf0 - h, yf1 - h
    L = Layer()
    for lx in (x0 + 2, x1 - 5):                             # 后腿
        L.rect(lx, ty1 + 3, lx + 3, yf0, "wd1")
    for lx in (x0 + 1, x1 - 4):                             # 前腿
        L.rect(lx, ty1 + 4, lx + 3, yf1, "wd2")
        L.vl(lx, ty1 + 4, yf1, "wd3")
        L.vl(lx + 2, ty1 + 4, yf1, "wd1")
    L.hl(x0 + 4, x1 - 4, yf1 - 8, "wd1")                    # 横枨
    L.hl(x0 + 4, x1 - 4, yf1 - 9, "wd3")
    # 桌面 + 红桌布：顶面红、前沿垂下 5 行（褶子一明一暗）、金边
    L.rect(x0, ty0, x1, ty1, "rd3")
    L.hl(x0, x1, ty0, "rd4")
    L.vl(x0, ty0, ty1, "rd4")
    L.vl(x1 - 1, ty0, ty1, "rd2")
    for x in range(x0, x1):
        fold = (x - x0) % 6
        col = "rd3" if fold < 3 else "rd2"
        L.vl(x, ty1, ty1 + 5, col)
        L.p(x, ty1 + 5, "gd2" if fold != 5 else "gd1")      # 垂边一圈金线
    L.hl(x0, x1, ty1, "rd4")
    for x in range(x0 + 2, x1 - 2, 3):                      # 桌布上一圈小金点
        L.p(x, ty0 + 2, "gd3")
        L.p(x, ty1 - 3, "gd3")
    # v3：牌大一号（4×5），手机上认得出是一张张牌；还是只有牌背（白边蓝心），没有牌面
    cx, cy = (x0 + x1) // 2, (ty0 + ty1) // 2
    # 中间一叠牌：摞着露两道边（下面一层错开一像素）+ 旁边散着一张
    card_back(L, cx - 2, cy - 1, 6, 7)
    card_back(L, cx - 3, cy - 2, 6, 7)
    L.hl(cx - 2, cx + 4, cy + 5, "bl0")
    L.vl(cx + 3, cy - 1, cy + 5, "bl0")
    card_back(L, cx + 5, cy + 2, 4, 5)
    # 三家手里各一把扇开的三张（背朝外）：北家朝镜头竖着拿；西家、东家在各自那边桌沿
    for k, dx in enumerate((-6, -2, 2)):
        card_back(L, cx + dx, ty0 - 2 - (1 if k == 1 else 0), 4, 6)
    for k, dy in enumerate((5, 8, 11)):
        card_back(L, x0 + 1 + (1 if k == 1 else 0), ty0 + dy, 5, 4)
    for k, dy in enumerate((6, 9, 12)):
        card_back(L, x1 - 6 - (1 if k == 1 else 0), ty0 + dy, 5, 4)
    # 一只盖碗（南边空位西头，桌沿上；v3 挪开，不跟散着的那张牌叠在一起）
    L.rect(x0 + 5, ty1 - 6, x0 + 9, ty1 - 3, "wl5")
    L.hl(x0 + 5, x0 + 9, ty1 - 6, "wt")
    L.p(x0 + 7, ty1 - 7, "wl3")
    L.outline()
    return L, yf1


def prop_stand(rect, thermos_style="red", seed=0):
    """茶凳（竹面小方凳当茶几）：上面两只盖碗、一小盘瓜子喜糖；凳子旁边地上立一只暖水瓶"""
    x0, f0, x1, f1 = rect
    L = Layer()
    sx0, sx1 = x0, x0 + 16
    h = 20
    st0, st1 = f0 + 2 - h, f1 - h
    # 凳腿（竹）
    bamboo_v(L, sx0 + 1, st1, f1, 2, nodes=5)
    bamboo_v(L, sx1 - 3, st1, f1, 2, nodes=5)
    bamboo_v(L, sx0 + 3, st1, f0 + 4, 1, nodes=0)
    L.shade_rect(sx0 + 3, st1, sx0 + 4, f0 + 4, -1)
    bamboo_h(L, sx0 + 1, sx1 - 1, f1 - 6, 1, nodes=0)
    # 凳面（竹片）
    L.rect(sx0, st0, sx1, st1, BAM[2])
    for y in range(st0, st1):
        if (y - st0) % 3 == 2:
            L.hl(sx0, sx1, y, BAM[1])
    L.hl(sx0, sx1, st0, BAM[3])
    bamboo_h(L, sx0, sx1, st1, 2, nodes=5)
    # 凳面上
    s = sub(sx0 - 2, st0 - 6, sx1 + 2, st1 + 2)
    gaiwan_small(s, sx0 + 1, st0 + 1)
    seed_plate(s, sx0 + 5, st0 + 4, w=10)
    gaiwan_small(s, sx0 + 8, st0)
    L.paste(s)
    # 暖水瓶（地上）
    t = sub(x1 - 10, f1 - 24, x1 + 1, f1 + 1)
    thermos(t, x1 - 5, f1, tall=19, style=thermos_style)
    t.outline()
    L.outline()
    L.paste(t)
    return L, f1


def prop_low_table(rect, h=24, items=("gaiwan", "gaiwan", "candy")):
    """小茶几（方的、木的）：桌面、厚沿、牙板、四条腿；上面盖碗、喜糖盘"""
    x0, f0, x1, f1 = rect
    L = Layer()
    ty0, ty1 = f0 - h, f1 - h
    for lx in (x0 + 1, x1 - 4):
        L.rect(lx, ty1 + 3, lx + 3, f0 + 2, "wd1")
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    for k in range(4):
        L.hl(x0 + 12 + k * 2, x0 + 16 + k * 2, ty0 + 2 + k * 2, "wd4")
    L.rect(x0, ty1, x1, ty1 + 3, "wd2")
    L.hl(x0, x1, ty1, "wd5")
    L.hl(x0, x1, ty1 + 2, "wd1")
    L.rect(x0 + 3, ty1 + 3, x1 - 3, ty1 + 6, "wd2")
    L.hl(x0 + 3, x1 - 3, ty1 + 5, "wd1")
    for lx in (x0, x1 - 3):
        L.rect(lx, ty1 + 3, lx + 3, f1, "wd2")
        L.vl(lx, ty1 + 3, f1, "wd3")
        L.vl(lx + 2, ty1 + 3, f1, "wd1")
    s = sub(x0 - 2, ty0 - 8, x1 + 2, ty1 + 2)
    gaiwan(s, x0 + 2, ty0 + 3)
    gaiwan(s, x0 + 11, ty0 + 5)
    seed_plate(s, x1 - 13, ty0 + 2, w=11)
    L.paste(s)
    L.outline()
    return L, f1


def prop_sideboard(rect):
    """茶水柜（靠北墙）：深木柜身、三扇小门两个抽屉（铜拉手）、柜面浅木；
    柜面上从西到东：两只红暖水瓶、一只竹壳暖水瓶、托盘上一摞盖碗、长嘴铜壶、玻璃喜糖罐、一盘瓜子喜糖、两罐茶叶、老收音机"""
    x0, f0, x1, f1 = rect
    h = 40
    ty0, ty1 = f0 - h, f1 - h          # 188..202
    L = Layer()
    # 柜身正面
    L.rect(x0, ty1, x1, f1 - 3, "wd2")
    L.hl(x0, x1, ty1, "wd4")
    L.hl(x0, x1, ty1 + 1, "wd5")
    L.hl(x0, x1, ty1 + 2, "wd3")
    L.hl(x0, x1, ty1 + 3, "wd1")
    n = 5
    pw = (x1 - x0 - 4) / n
    for k in range(n):
        a = int(x0 + 2 + k * pw)
        b = int(x0 + 2 + (k + 1) * pw) - 2
        drawer = k in (1, 3)
        if drawer:
            for (ya, yb) in ((ty1 + 6, ty1 + 18), (ty1 + 20, f1 - 6)):
                L.rect(a, ya, b, yb, "wd3")
                L.hl(a, b, ya, "wd4")
                L.vl(a, ya, yb, "wd4")
                L.hl(a, b, yb - 1, "wd1")
                L.vl(b - 1, ya, yb, "wd1")
                cx = (a + b) // 2
                L.rect(cx - 2, (ya + yb) // 2, cx + 3, (ya + yb) // 2 + 1, "gd3")
                L.p(cx - 2, (ya + yb) // 2 - 1, "gd4")
        else:
            ya, yb = ty1 + 6, f1 - 6
            L.rect(a, ya, b, yb, "wd3")
            L.hl(a, b, ya, "wd4")
            L.vl(a, ya, yb, "wd4")
            L.hl(a, b, yb - 1, "wd1")
            L.vl(b - 1, ya, yb, "wd1")
            L.rect(a + 3, ya + 3, b - 3, yb - 3, "wd2")      # 门心凹进去
            L.hl(a + 3, b - 3, ya + 3, "wd1")
            L.vl(a + 3, ya + 3, yb - 3, "wd1")
            L.hl(a + 3, b - 3, yb - 4, "wd4")
            # 门心一朵金色团花（雕的，不是字）
            cx, cy = (a + b) // 2, (ya + yb) // 2
            for (dx, dy) in ((-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)):
                L.p(cx + dx, cy + dy, "gd2" if dx + dy > 0 else "gd3")
            L.p(b - 5 if k < 2 else a + 4, cy + 4, "gd3")    # 铜拉手
    # 柜脚
    L.rect(x0, f1 - 3, x1, f1, "wd1")
    L.rect(x0 + 1, f1 - 3, x0 + 5, f1, "wd2")
    L.rect(x1 - 5, f1 - 3, x1 - 1, f1, "wd2")
    L.hl(x0, x1, f1 - 3, "wd0")
    # 柜面（v2：红木深一档、一道反光）
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    for k in range(5):
        L.hl(x0 + 70 + k * 2, x0 + 78 + k * 2, ty0 + 2 + k * 2, "wd4")
    # v2：白钩花桌布换成一条红桌旗（金边，前沿垂下一截、两头金穗）——少一块碎白，多一道喜庆的红
    ra, rb = x0 + 14, x1 - 14
    L.rect(ra, ty0 + 3, rb, ty1, "rd3")
    L.hl(ra, rb, ty0 + 3, "rd4")
    L.hl(ra, rb, ty0 + 4, "gd3")
    L.hl(ra, rb, ty1 - 2, "gd3")
    for x in range(ra + 3, rb - 3, 6):
        L.p(x, (ty0 + ty1) // 2 + 1, "gd2")
    for y in range(ty1, ty1 + 6):                       # 前沿垂下来一截
        L.hl(ra + 30, rb - 30, y, "rd3" if y < ty1 + 5 else "rd2")
    L.hl(ra + 30, rb - 30, ty1 + 4, "gd3")
    for tx in (ra + 30, rb - 31):                       # 两头金穗
        L.vl(tx, ty1 + 6, ty1 + 10, "gd3")
        L.p(tx, ty1 + 10, "gd2")
    L.outline()
    # 柜面上的东西（每件单独描边再贴上，叠在一起分得开）
    base = ty0 + 9
    things = []

    def put(fn, *args, box=(-14, -30, 14, 2)):
        s = sub(args[0] + box[0], args[1] + box[1], args[0] + box[2], args[1] + box[3])
        fn(s, *args)
        things.append(s)

    # v2：只留几件大的（两只红暖水瓶、托盘盖碗、长嘴铜壶、喜糖罐、一盘瓜子），竹壳暖水瓶、两罐茶叶、收音机拿掉
    put(thermos, x0 + 8, base + 1, 20, "red", box=(-5, -23, 6, 1))
    put(thermos, x0 + 18, base + 2, 19, "red", box=(-5, -22, 6, 1))
    # 托盘一摞盖碗
    def tray(s, x, b):
        s.rect(x, b - 3, x + 18, b, "wd5")
        s.hl(x, x + 18, b - 3, "wl3")
        s.hl(x, x + 18, b - 1, "wd3")
        gaiwan(s, x + 1, b - 10)
        gaiwan(s, x + 8, b - 9)
        s.ell(x + 10, b - 13, x + 17, b - 10, "wt")      # 叠着的盖
        s.ell(x + 10, b - 15, x + 17, b - 12, "wt")
        s.hl(x + 11, x + 16, b - 12, "bl3")
    put(tray, x0 + 32, base + 2, box=(-2, -18, 21, 1))
    put(copper_kettle, x0 + 56, base + 1, box=(-22, -28, 18, 1))
    put(candy_jar, x0 + 74, base, box=(-1, -17, 12, 1))
    put(seed_plate, x0 + 86, base - 4, box=(-1, -2, 15, 8))
    put(thermos, x1 - 10, base + 1, 20, "red", box=(-5, -23, 6, 1))
    for s in things:
        paste_ol(L, s)
    return L, f1


def prop_fan(rect):
    """落地扇（老式）：圆底座、铝杆、奶白电机壳、铝网罩（一圈圈、一根根辐条，网罩里看得见三片淡蓝扇叶），稍微朝西南转着"""
    x0, f0, x1, f1 = rect
    cx = (x0 + x1) // 2
    L = Layer()
    # 底座
    L.ell(cx - 9, f1 - 6, cx + 9, f1, "sv0")
    L.ell(cx - 9, f1 - 7, cx + 9, f1 - 1, "sv1")
    L.ell(cx - 6, f1 - 6, cx + 3, f1 - 3, "sv2")
    # 杆
    top = f1 - 62
    L.rect(cx - 1, top + 26, cx + 1, f1 - 4, "sv1")
    L.vl(cx - 1, top + 26, f1 - 4, "sv2")
    L.rect(cx - 2, top + 34, cx + 2, top + 37, "sv0")      # 调高低的旋扭
    L.p(cx - 2, top + 34, "sv1")
    # 电机壳（网罩后面）
    L.ell(cx - 3, top + 14, cx + 7, top + 26, "wl4")
    L.ell(cx, top + 15, cx + 6, top + 22, "wl3")
    # 网罩：椭圆（朝西南转了一点）
    gcx, gcy = cx - 2, top + 13
    rx, ry = 11, 12
    grill = Layer(x0=gcx - rx - 1, y0=gcy - ry - 1, w=2 * rx + 3, h=2 * ry + 3)
    # 扇叶（三片，淡蓝）
    for k in range(3):
        a = -math.pi / 2 + k * 2 * math.pi / 3 + 0.4
        for t in range(2, 10):
            for wv in (-1.6, -0.8, 0, 0.8, 1.6):
                bx = gcx + math.cos(a) * t - math.sin(a) * wv * (0.6 + t * 0.12)
                by = gcy + math.sin(a) * t * 1.05 + math.cos(a) * wv * (0.6 + t * 0.12)
                grill.p(bx, by, "bl3" if wv <= 0 else "bl2")
    grill.ring(gcx - rx, gcy - ry, gcx + rx + 1, gcy + ry + 1, "sv1")
    grill.ring(gcx - rx + 1, gcy - ry + 1, gcx + rx, gcy + ry, "sv0", only=lambda x, y: x > gcx + 3 or y > gcy + 3)
    grill.ring(gcx - 7, gcy - 8, gcx + 8, gcy + 9, "sv1")
    for k in range(12):
        a = k * math.pi / 6
        for t in range(3, rx):
            if k % 2 == 0 or t > 6:
                grill.p(gcx + 0.5 + math.cos(a) * t, gcy + 0.5 + math.sin(a) * t * ry / rx, "sv2" if k < 6 else "sv1")
    grill.ell(gcx - 2, gcy - 2, gcx + 3, gcy + 3, "wl4")
    grill.p(gcx - 1, gcy - 1, "wt")
    grill.p(gcx + 1, gcy + 1, "wl2")
    L.paste(grill)
    L.outline()
    return L, f1


def prop_plant_bamboo(rect):
    """观音竹（西北角）：一丛细竹竿、一片片窄竹叶，大陶盆（腰上一道红绸）"""
    x0, f0, x1, f1 = rect
    cx = (x0 + x1) // 2
    L = Layer()
    pot_top = f1 - 18
    rnd = random.Random(41)
    stalks = [(-5, 70), (-2, 82), (1, 76), (4, 84), (6, 66), (-7, 58)]
    tips = []
    for (dx, hgt) in stalks:
        lean = dx * 0.12
        prev = None
        for k in range(hgt - 14):
            y = pot_top - k
            x = cx + dx + lean * k * 0.25
            L.p(x, y, "gr3" if dx < 2 else "gr2")
            L.p(x + 1, y, "gr1")
            if k % 9 == 4:
                L.p(x, y, "gr1")
                L.p(x + 1, y, "gr0")
        tips.append((cx + dx + lean * (hgt - 14) * 0.25, pot_top - (hgt - 14)))
    # 竹叶：一簇一簇在竿子上半截
    for (dx, hgt) in stalks:
        for k in range(5):
            yy = pot_top - (hgt - 14) + 4 + k * 9 + rnd.randrange(0, 4)
            if yy > pot_top - 12:
                continue
            xx = cx + dx + dx * 0.12 * (pot_top - yy) * 0.25
            for side in (-1, 1):
                ang = (-0.5 if side > 0 else -2.64) + rnd.uniform(-0.35, 0.35)
                leaf(L, xx + side * 4, yy + 1, 10, ang, 3, 3 if side < 0 else 2, vein=False)
    for (tx, ty) in tips:
        leaf(L, tx, ty - 3, 9, -1.57 + rnd.uniform(-0.3, 0.3), 3, 3, vein=False)
    # 盆：陶盆，口沿、往下收
    for y in range(pot_top, f1):
        t = (y - pot_top) / float(f1 - pot_top)
        half = 10.5 - 3 * t
        xa, xb = int(cx + 0.5 - half + 0.5), int(cx + 0.5 + half - 0.5)
        L.hl(xa, xb + 1, y, "cl2")
        L.p(xa, y, "cl3")
        L.p(xa + 1, y, "cl3")
        L.p(xb, y, "cl0")
        L.p(xb - 1, y, "cl1")
    L.ell(cx - 11, pot_top - 3, cx + 12, pot_top + 4, "cl2")
    L.ring(cx - 11, pot_top - 3, cx + 12, pot_top + 4, "cl3", only=lambda x, y: y < pot_top or x < cx - 5)
    L.ell(cx - 9, pot_top - 2, cx + 10, pot_top + 2, "wd1")
    L.hl(cx - 7, cx + 8, pot_top - 1, "wd0")
    L.hl(cx - 9, cx + 10, pot_top + 7, "rd3")             # 红绸一道
    L.hl(cx - 9, cx + 10, pot_top + 8, "rd2")
    L.rect(cx + 3, pot_top + 6, cx + 7, pot_top + 10, "rd4")
    L.line(cx + 4, pot_top + 10, cx + 2, pot_top + 15, "rd3")
    L.line(cx + 6, pot_top + 10, cx + 8, pot_top + 15, "rd2")
    L.hl(cx - 7, cx + 8, f1 - 1, "cl0")
    L.outline()
    return L, f1


def prop_money_tree(rect):
    """发财树（东南角）：几根辫着的树干、顶上一蓬一蓬掌状叶，白瓷盆金口沿，树干上系红绸"""
    x0, f0, x1, f1 = rect
    cx = (x0 + x1) // 2
    L = Layer()
    pot_top = f1 - 16
    # 树干（三根拧着往上）
    for y in range(pot_top - 34, pot_top):
        k = pot_top - y
        for j, ph in enumerate((0, 2.1, 4.2)):
            x = cx + math.sin(k * 0.22 + ph) * 2.2
            L.p(x, y, ("wd3", "wd4", "wd2")[j])
            L.p(x + 1, y, "wd1" if j == 2 else "wd2")
    L.rect(cx - 3, pot_top - 22, cx + 4, pot_top - 19, "rd3")          # 红绸
    L.hl(cx - 3, cx + 4, pot_top - 22, "rd4")
    L.line(cx + 3, pot_top - 19, cx + 6, pot_top - 13, "rd3")
    L.line(cx + 2, pot_top - 19, cx + 1, pot_top - 12, "rd2")
    # 叶冠：几蓬掌状叶（每蓬五片）
    clusters = [(cx - 8, pot_top - 44, 2), (cx + 8, pot_top - 46, 2), (cx, pot_top - 56, 3), (cx - 10, pot_top - 56, 3),
                (cx + 10, pot_top - 58, 3), (cx + 1, pot_top - 40, 2), (cx - 3, pot_top - 64, 3), (cx + 6, pot_top - 66, 3)]
    for (lx, ly, lv) in clusters:
        L.line(cx, pot_top - 34, lx, ly, "wd2")
    for (lx, ly, lv) in clusters:
        for k in range(5):
            a = -math.pi / 2 + (k - 2) * 0.62
            leaf(L, lx + math.cos(a) * 5, ly + math.sin(a) * 4 + 2, 9, a, 4, lv, vein=False)
    # 盆
    for y in range(pot_top, f1):
        t = (y - pot_top) / float(f1 - pot_top)
        half = 10 - 2.5 * t
        xa, xb = int(cx - half + 0.5), int(cx + half - 0.5)
        L.hl(xa, xb + 1, y, "wt")
        L.p(xb, y, "sv1")
        L.p(xb - 1, y, "sv2")
        L.p(xa, y, "sv2")
    L.ell(cx - 11, pot_top - 3, cx + 11, pot_top + 3, "gd3")
    L.ell(cx - 9, pot_top - 2, cx + 9, pot_top + 2, "wd1")
    L.hl(cx - 9, cx + 10, pot_top + 5, "gd2")
    L.hl(cx - 8, cx + 9, f1 - 3, "gd2")
    L.outline()
    return L, f1


def prop_recliner(rect):
    """竹躺椅（四川茶馆的凉椅）：从侧面看，西头靠背斜着翘起来（顶上往后卷一道当枕头）、中间座面、东头搁脚往下斜到地；
    竹片一条条，朝西上方的面（搁脚）亮、朝东上方的面（靠背）暗；两边一根弯竹扶手；靠背上一块红绸垫子，座上搁一把蒲扇"""
    x0, f0, x1, f1 = rect
    L = Layer()
    ln = x1 - x0

    def z(x):
        t = (x - x0) / float(ln)
        if t < 0.08:                        # 枕头卷：往后翻一点
            return 33 + 3 * (t / 0.08)
        if t < 0.32:                        # 靠背：从 36 斜着降到 18
            return 36 - (36 - 18) * ((t - 0.08) / 0.24)
        if t < 0.70:                        # 座面
            return 18 - 2 * ((t - 0.32) / 0.38)
        return 16 - 10 * ((t - 0.70) / 0.30)   # 搁脚

    def face(x):                            # 这一段椅面朝哪：靠背暗、座面中、搁脚亮
        t = (x - x0) / float(ln)
        return 1 if 0.08 <= t < 0.32 else (3 if t >= 0.70 else 2)

    # 远处（北边）的腿和扶手
    for lx in (x0 + 8, x0 + int(ln * 0.62), x1 - 6):
        zt = int(z(lx))
        L.vl(lx, f0 - zt, f0, BAM[1])
        L.vl(lx + 1, f0 - zt, f0, BAM[0])
    ax0, ax1 = x0 + int(ln * 0.16), x0 + int(ln * 0.64)
    for x in range(ax0, ax1):
        y = f0 - 26 - int(2 * math.sin(math.pi * (x - ax0) / (ax1 - ax0)))
        L.p(x, y, BAM[1])
        L.p(x, y + 1, BAM[0])
    # 椅面：每一列一条竹片
    for x in range(x0, x1):
        zz = int(round(z(x)))
        ya, yb = f0 - zz, f1 - zz
        lv = face(x)
        sep = (x - x0) % 3 == 2
        for y in range(ya, yb):
            L.p(x, y, BAM[max(0, lv - 1)] if sep else BAM[lv])
        L.p(x, ya, BAM[min(3, lv + 1)])
    # 红坐垫（只铺座面一截，鼓一点）
    ca, cb = x0 + int(ln * 0.33), x0 + int(ln * 0.66)
    for x in range(ca, cb):
        zz = int(round(z(x))) + 1
        ya, yb = f0 - zz + 2, f1 - zz - 1
        for y in range(ya, yb):
            L.p(x, y, "rd4" if y - ya < 2 else "rd3")
        L.p(x, ya, "rd5")
        L.p(x, yb, "rd1")
    L.vl(ca, f0 - int(z(ca)) + 1, f1 - int(z(ca)) - 1, "rd2")
    L.vl(cb - 1, f0 - int(z(cb)) + 1, f1 - int(z(cb)) - 1, "rd1")
    # 枕头：一个圆滚滚的红枕（金色两头），横在靠背顶上
    pa, pb = x0 + int(ln * 0.06), x0 + int(ln * 0.15)
    for x in range(pa, pb):
        zz = int(round(z(x))) + 3
        ya, yb = f0 - zz + 1, f1 - zz - 1
        u = (x - pa) / float(pb - pa)
        col = "rd4" if u < 0.35 else ("rd3" if u < 0.75 else "rd2")
        for y in range(ya, yb):
            L.p(x, y, col)
        L.p(x, ya, "gd3")
        L.p(x, yb - 1, "gd2")
    # 蒲扇（搁在座面上）
    palm_fan(L, x0 + int(ln * 0.52), f0 - 18 + 9)
    # 近处（南边）的框：一根竹顺着椅面边
    for x in range(x0, x1):
        y = int(round(f1 - z(x)))
        L.p(x, y, BAM[3])
        L.p(x, y + 1, BAM[1])
        if (x - x0) % 12 == 7:
            L.p(x, y + 1, NODE)
    for x in range(ax0, ax1):
        y = f1 - 26 - int(2 * math.sin(math.pi * (x - ax0) / (ax1 - ax0)))
        L.p(x, y, BAM[3])
        L.p(x, y + 1, BAM[1])
    for lx in (ax0, ax1 - 2):
        bamboo_v(L, lx, f1 - 25, f1 - int(z(lx)), 2, nodes=0)
    for lx in (x0 + 7, x0 + int(ln * 0.62), x1 - 7):
        bamboo_v(L, lx, f1 - int(z(lx)) + 1, f1, 2, nodes=6)
    bamboo_h(L, x0 + 7, x1 - 6, f1 - 5, 1, nodes=0)
    L.outline()
    return L, f1


def prop_luohan(rect):
    """红木罗汉榻（v2）：三面围板（后背高、两头低，围板里一圈开光）、厚榻面、红坐垫、两头各一只红圆枕（金色两头）、
    牙板一道、四条内翻马蹄腿。朝南摆，看得见正面"""
    x0, f0, x1, f1 = rect
    L = Layer()
    seat_h = 18
    st0, st1 = f0 - seat_h, f1 - seat_h            # 榻面（顶面）
    back_top = f0 - 41
    # 后围板（贴北沿，高到 41）
    L.rect(x0 + 1, back_top, x1 - 1, st0 + 1, "wd2")
    L.hl(x0 + 1, x1 - 1, back_top, "wd4")
    L.hl(x0 + 1, x1 - 1, back_top + 1, "wd3")
    for px0 in range(x0 + 6, x1 - 10, 16):          # 围板开光（一格一格的长方框）
        L.rect(px0, back_top + 4, px0 + 12, st0 - 3, "wd1")
        L.rect(px0 + 1, back_top + 5, px0 + 11, st0 - 4, "wd3")
        L.hl(px0 + 1, px0 + 11, back_top + 5, "wd4")
        L.p(px0 + 6, (back_top + st0) // 2, "gd3")
    # 两头扶手围板（低一截，前头往外卷）
    for (ax, d) in ((x0, 1), (x1 - 5, -1)):
        L.rect(ax, st0 - 12, ax + 5, st1 + 2, "wd2")
        L.hl(ax, ax + 5, st0 - 12, "wd4")
        L.vl(ax if d == 1 else ax + 4, st0 - 12, st1 + 2, "wd3" if d == 1 else "wd1")
        L.rect(ax, st1 - 3, ax + 5, st1 + 2, "wd3")      # 前头卷起来的一截
        L.hl(ax, ax + 5, st1 - 3, "wd4")
    # 榻面 + 红坐垫
    L.rect(x0 + 5, st0, x1 - 5, st1, "wd3")
    L.rect(x0 + 6, st0, x1 - 6, st1 - 1, "rd3")
    L.hl(x0 + 6, x1 - 6, st0, "rd4")
    L.hl(x0 + 6, x1 - 6, st1 - 2, "rd2")
    for x in range(x0 + 10, x1 - 8, 8):              # 坐垫上一排金线小花
        L.p(x, (st0 + st1) // 2, "gd3")
    # 两只红圆枕（金色两头）
    for (bx, d) in ((x0 + 6, 1), (x1 - 15, -1)):
        L.rect(bx, st0 - 4, bx + 9, st0 + 2, "rd3")
        L.hl(bx, bx + 9, st0 - 4, "rd4")
        L.hl(bx, bx + 9, st0 + 1, "rd2")
        L.vl(bx, st0 - 4, st0 + 2, "gd3")
        L.vl(bx + 8, st0 - 4, st0 + 2, "gd2")
    # 榻面前沿（厚）、牙板、腿
    L.rect(x0 + 1, st1, x1 - 1, st1 + 5, "wd2")
    L.hl(x0 + 1, x1 - 1, st1, "wd4")
    L.hl(x0 + 1, x1 - 1, st1 + 4, "wd1")
    mx = (x0 + x1) // 2
    L.rect(mx - 8, st1 + 5, mx + 8, st1 + 8, "wd2")   # 牙板中间一段卷云
    L.hl(mx - 6, mx + 6, st1 + 7, "wd1")
    for lx in (x0 + 2, x1 - 6):
        L.rect(lx, st1 + 5, lx + 4, f1 - 1, "wd2")
        L.vl(lx, st1 + 5, f1 - 1, "wd3")
        L.rect(lx + (1 if lx < mx else -1), f1 - 2, lx + 5 if lx < mx else lx + 3, f1, "wd2")   # 马蹄足往里翻
    L.outline()
    return L, f1


def prop_thermos_rack(rect):
    """暖水瓶条凳（四川茶馆门口那种）：一条矮木凳，上面一排六只暖水瓶（红的、竹壳的间着），凳脚边一只铁皮小水桶"""
    x0, f0, x1, f1 = rect
    h = 18
    L = Layer()
    ty0, ty1 = f0 - h, f1 - h
    for lx in (x0 + 2, x1 - 5):
        L.rect(lx, ty1 + 2, lx + 3, f0 + 1, "wd1")
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    L.rect(x0, ty1, x1, ty1 + 3, "wd2")
    L.hl(x0, x1, ty1, "wd4")
    L.hl(x0, x1, ty1 + 2, "wd1")
    for lx in (x0, x1 - 3):
        L.rect(lx, ty1 + 3, lx + 3, f1, "wd2")
        L.vl(lx, ty1 + 3, f1, "wd3")
        L.vl(lx + 2, ty1 + 3, f1, "wd1")
    L.hl(x0 + 3, x1 - 3, f1 - 5, "wd1")
    L.outline()
    styles = ["red", "red", "bamboo", "red", "red", "bamboo"]
    n = len(styles)
    for k, st in enumerate(styles):
        cx = x0 + 6 + int(k * (x1 - x0 - 12) / (n - 1))
        base = (ty0 + ty1) // 2 + 2 + (k % 2)
        t = sub(cx - 6, base - 23, cx + 7, base + 1)
        thermos(t, cx, base, tall=20 - (k % 2), style=st)
        paste_ol(L, t)
    return L, f1


def prop_coat_rack(rect):
    """衣帽架（西墙边）：车木立杆、三只脚、顶球、挂钩；挂一件长辈的深灰外套、一顶草帽、一条红围巾"""
    x0, f0, x1, f1 = rect
    L = Layer()
    cx, foot = (x0 + x1) // 2, f1
    top = foot - 84
    L.line(cx - 1, foot - 9, cx - 8, foot - 1, "wd2")
    L.line(cx - 1, foot - 8, cx - 8, foot, "wd1")
    L.line(cx + 1, foot - 9, cx + 8, foot - 1, "wd2")
    L.line(cx + 1, foot - 8, cx + 8, foot, "wd1")
    L.rect(cx - 1, foot - 10, cx + 2, foot - 2, "wd2")
    L.rect(cx - 1, top + 5, cx + 2, foot - 8, "wd3")
    L.vl(cx - 1, top + 5, foot - 8, "wd5")
    L.vl(cx + 1, top + 5, foot - 8, "wd1")
    for ry in (top + 40, foot - 14):
        L.rect(cx - 2, ry, cx + 3, ry + 3, "wd3")
        L.hl(cx - 2, cx + 3, ry, "wd5")
        L.hl(cx - 2, cx + 3, ry + 2, "wd1")
    L.ell(cx - 3, top, cx + 4, top + 6, "wd3")
    L.p(cx - 1, top + 1, "wd5")
    L.hl(cx - 1, cx + 3, top + 5, "wd1")
    for (dx, dy) in ((-6, 8), (7, 8), (-5, 14), (6, 14)):
        sx = cx if dx < 0 else cx + 1
        L.line(sx, top + dy + 2, cx + dx, top + dy - 1, "wd2")
        L.p(cx + dx, top + dy - 2, "gd3")
    # 红围巾（右钩）
    sx0 = cx + 4
    L.rect(sx0, top + 8, sx0 + 4, top + 36, "rd3")
    L.vl(sx0, top + 8, top + 36, "rd4")
    L.vl(sx0 + 3, top + 10, top + 36, "rd2")
    for yy in range(top + 14, top + 36, 6):
        L.hl(sx0, sx0 + 4, yy, "rd2")
    for xx in range(sx0, sx0 + 4):
        L.p(xx, top + 36 + (xx % 2), "gd3")
    # 深灰外套（左钩，中山装：四个口袋、一排扣子）
    hx, hy = cx - 6, top + 7
    body = [(hx - 1, hy + 1), (hx + 3, hy + 2), (hx + 5, hy + 8), (hx + 6, hy + 46), (hx - 12, hy + 48),
            (hx - 11, hy + 12), (hx - 8, hy + 4)]
    L.poly(body, "ik2")
    L.poly([(hx - 1, hy + 2), (hx - 8, hy + 5), (hx - 10, hy + 12), (hx - 10, hy + 46), (hx - 5, hy + 46),
            (hx - 4, hy + 10)], "ik3")
    L.poly([(hx - 1, hy + 1), (hx + 3, hy + 2), (hx + 1, hy + 7), (hx - 2, hy + 5)], "ik1")
    L.vl(hx - 2, hy + 7, hy + 47, "ik1")
    for k in range(5):
        L.p(hx - 3, hy + 10 + k * 7, "sv1")
    for (px_, py_) in ((hx - 9, hy + 16), (hx - 9, hy + 32)):
        L.hl(px_, px_ + 5, py_, "ik1")
        L.hl(px_, px_ + 5, py_ - 1, "sv0")
    L.poly([(hx - 11, hy + 12), (hx - 8, hy + 13), (hx - 8, hy + 40), (hx - 12, hy + 41)], "ik2")
    L.vl(hx - 11, hy + 13, hy + 41, "ik3")
    L.hl(hx - 12, hx + 6, hy + 47, "ik1")
    # 草帽（挂在顶上）
    L.ell(cx - 9, top + 2, cx + 6, top + 9, "gd2")
    L.ell(cx - 8, top + 2, cx + 5, top + 8, "gd3")
    L.ell(cx - 5, top - 2, cx + 3, top + 5, "gd3")
    L.ell(cx - 4, top - 2, cx + 1, top + 3, "gd4")
    L.hl(cx - 5, cx + 3, top + 4, "rd3")
    for x in range(cx - 8, cx + 5, 2):
        L.p(x, top + 7, "gd1")
    L.outline()
    return L, foot


def prop_cage_stand(rect):
    """鸟笼架（老茶客把鸟带来挂着）：十字底座、一根木杆、顶上一根横担，两头各挂一只竹鸟笼；东边那只搭着半块蓝布"""
    x0, f0, x1, f1 = rect
    cx, foot = (x0 + x1) // 2, f1
    L = Layer()
    # 底座（十字，前后两只脚看得见）
    L.rect(cx - 10, foot - 2, cx + 11, foot, "wd2")
    L.hl(cx - 10, cx + 11, foot - 2, "wd4")
    L.rect(cx - 2, foot - 6, cx + 3, foot - 1, "wd2")
    L.hl(cx - 2, cx + 3, foot - 6, "wd4")
    # 杆
    top = foot - 86
    L.rect(cx - 1, top, cx + 2, foot - 5, "wd3")
    L.vl(cx - 1, top, foot - 5, "wd5")
    L.vl(cx + 1, top, foot - 5, "wd1")
    # 横担
    L.rect(cx - 13, top, cx + 14, top + 3, "wd3")
    L.hl(cx - 13, cx + 14, top, "wd5")
    L.hl(cx - 13, cx + 14, top + 2, "wd1")
    L.ell(cx - 2, top - 3, cx + 3, top + 2, "wd3")
    L.p(cx - 1, top - 2, "wd5")
    L.line(cx - 1, top + 3, cx - 8, top + 10, "wd2")         # 斜撑
    L.line(cx + 2, top + 3, cx + 9, top + 10, "wd2")
    # 两只鸟笼，挂绳
    for (dx, base, cover) in ((-11, foot - 44, False), (12, foot - 40, True)):
        s = sub(cx + dx - 9, base - 24, cx + dx + 10, base + 2)
        birdcage(s, cx + dx, base)
        if cover:                                             # 半块蓝布搭在笼顶，垂下来一截
            for y in range(base - 19, base - 8):
                for x in range(cx + dx - 6, cx + dx + 8):
                    t = (y - (base - 19)) / 11.0
                    if x < cx + dx - 6 + (14 if t < 0.35 else 9 - int(t * 3)):
                        s.p(x, y, "bl2" if (x - cx - dx) < 2 else "bl1")
            s.hl(cx + dx - 6, cx + dx + 8, base - 19, "bl3")
            for y in range(base - 17, base - 8, 3):
                s.p(cx + dx - 4, y, "bl3")
        paste_ol(L, s)
        L.vl(cx + dx, top + 3, base - 21, "ik2")
    L.outline()
    return L, foot


def prop_bench(rect):
    """长条板凳（茶馆那种）：厚木凳面、四条往外撇的腿、两头一根横枨；凳上搁一把蒲扇、一只盖碗"""
    x0, f0, x1, f1 = rect
    h = 22
    L = Layer()
    st0, st1 = f0 - h, f1 - h
    for (lx, d) in ((x0 + 6, -1), (x1 - 7, 1)):             # 远处两条腿（暗）
        L.line(lx, st1 + 2, lx + d * 3, f0, "wd1")
        L.line(lx + 1, st1 + 2, lx + 1 + d * 3, f0, "wd0")
    L.rect(x0, st0, x1, st1, "wd3")
    L.hl(x0, x1, st0, "wd5")
    L.vl(x0, st0, st1, "wd4")
    L.vl(x1 - 1, st0, st1, "wd2")
    for k in range(4):                                        # 凳面一道反光
        L.hl(x0 + 30 + k * 2, x0 + 34 + k * 2, st0 + 2 + k * 2, "wd4")
    L.rect(x0, st1, x1, st1 + 3, "wd2")                        # 凳面厚度
    L.hl(x0, x1, st1, "wd4")
    L.hl(x0, x1, st1 + 2, "wd1")
    for (lx, d) in ((x0 + 4, -1), (x1 - 6, 1)):              # 近处两条腿（往外撇）
        for k in range(f1 - st1 - 3):
            xx = lx + d * (k * 3) // (f1 - st1 - 3)
            L.p(xx, st1 + 3 + k, "wd3")
            L.p(xx + 1, st1 + 3 + k, "wd1")
    L.hl(x0 + 5, x0 + 9, f1 - 8, "wd2")                        # 两头的横枨
    L.hl(x1 - 9, x1 - 5, f1 - 8, "wd2")
    L.rect(x0 + 5, f1 - 9, x1 - 5, f1 - 7, "wd2")
    L.hl(x0 + 5, x1 - 5, f1 - 9, "wd3")
    L.outline()
    s = sub(x0, st0 - 8, x1, st1 + 2)
    palm_fan(s, x1 - 16, st0 + 4)
    gaiwan_small(s, x0 + 8, st0 + 1)
    paste_ol(L, s)
    return L, f1


def prop_flower_stand(rect):
    """高花几（深红木、四条细腿、下面一层隔板）上一只青花梅瓶，插几枝红梅（喜事里常摆的）"""
    x0, f0, x1, f1 = rect
    h = 44
    L = Layer()
    ty0, ty1 = f0 - h, f1 - h
    for lx in (x0 + 1, x1 - 3):
        L.rect(lx, ty1 + 2, lx + 2, f0 + 1, "wd0")
    L.rect(x0 - 1, ty0, x1 + 1, ty1, "wd2")
    L.hl(x0 - 1, x1 + 1, ty0, "wd4")
    L.rect(x0 - 1, ty1, x1 + 1, ty1 + 3, "wd1")
    L.hl(x0 - 1, x1 + 1, ty1, "wd3")
    for lx in (x0, x1 - 2):
        L.rect(lx, ty1 + 3, lx + 2, f1, "wd1")
        L.vl(lx, ty1 + 3, f1, "wd2")
    L.rect(x0 + 1, f1 - 14, x1 - 1, f1 - 12, "wd2")      # 下层隔板
    L.hl(x0 + 1, x1 - 1, f1 - 14, "wd3")
    L.rect(x0 + 1, ty1 + 3, x1 - 1, ty1 + 5, "wd1")      # 牙子
    L.outline()
    # 梅瓶：小口、丰肩、往下收
    s = sub(x0 - 14, ty0 - 46, x1 + 14, ty0 + 3)
    cx, vb = (x0 + x1) // 2, (ty0 + ty1) // 2 + 1
    for y in range(vb - 20, vb):
        t = (y - (vb - 20)) / 20.0
        half = 2 + 5.2 * math.sin(math.pi * min(1.0, t * 1.35 + 0.08)) ** 0.8 - 1.5 * t
        xa, xb = int(cx + 0.5 - half + 0.5), int(cx + 0.5 + half - 0.5)
        s.hl(xa, xb + 1, y, "wt")
        s.p(xb, y, "bl3")
        s.p(xb - 1, y, "bl4")
        s.p(xa, y, "bl4")
        if (y - vb) % 5 == 0:
            s.hl(xa + 1, xb, y, "bl2")
    s.rect(cx - 1, vb - 23, cx + 2, vb - 20, "wt")
    s.p(cx + 1, vb - 22, "bl3")
    # 红梅：几根弯枝、一朵朵小红花、花苞
    rnd = random.Random(9)
    branches = [((cx, vb - 23), (cx - 9, vb - 40), (cx - 13, vb - 44)), ((cx, vb - 23), (cx + 6, vb - 36), (cx + 12, vb - 42)),
                ((cx, vb - 23), (cx + 1, vb - 42), (cx - 3, vb - 46))]
    for br in branches:
        for (a, b) in zip(br, br[1:]):
            s.line(a[0], a[1], b[0], b[1], "wd1")
        for (a, b) in zip(br, br[1:]):
            for k in range(1, 4):
                t = k / 4.0
                fx, fy = a[0] + (b[0] - a[0]) * t + rnd.choice([-2, 2]), a[1] + (b[1] - a[1]) * t
                s.rect(fx - 1, fy - 1, fx + 2, fy + 2, "rd4")
                s.p(fx, fy, "gd4")
                s.p(fx + 1, fy + 1, "rd2")
    paste_ol(L, s)
    return L, f1


def prop_palace_lamp(rect):
    """落地宫灯（跟宴会厅的灯柱一家）：十字木底座、深木立杆、顶上一盏六角宫灯（金框、红纱三面透亮、上下金檐、四角垂红穗）"""
    x0, f0, x1, f1 = rect
    cx, foot = (x0 + x1) // 2, f1
    L = Layer()
    L.rect(cx - 6, foot - 2, cx + 7, foot, "wd1")
    L.hl(cx - 6, cx + 7, foot - 2, "wd3")
    L.rect(cx - 2, foot - 5, cx + 3, foot - 1, "wd2")
    L.hl(cx - 2, cx + 3, foot - 5, "wd4")
    top = foot - 80
    L.rect(cx - 1, top + 24, cx + 2, foot - 4, "wd2")
    L.vl(cx - 1, top + 24, foot - 4, "wd4")
    L.vl(cx + 1, top + 24, foot - 4, "wd1")
    for ry in (top + 40, foot - 16):
        L.rect(cx - 2, ry, cx + 3, ry + 2, "gd2")
        L.hl(cx - 2, cx + 3, ry, "gd3")
    # 灯：上檐
    L.poly([(cx - 4, top), (cx + 5, top), (cx + 8, top + 4), (cx - 7, top + 4)], "gd2")
    L.hl(cx - 4, cx + 5, top, "gd4")
    L.hl(cx - 6, cx + 7, top + 3, "gd1")
    L.rect(cx - 1, top - 3, cx + 2, top, "gd3")
    # 灯身：三面红纱（中间那面最亮）、金框
    by0, by1 = top + 4, top + 19
    L.rect(cx - 6, by0, cx + 7, by1, "rd3")
    L.rect(cx - 2, by0 + 1, cx + 3, by1 - 1, "rd5")
    L.rect(cx - 1, by0 + 3, cx + 2, by1 - 3, "gd4")
    L.rect(cx - 5, by0 + 1, cx - 3, by1 - 1, "rd4")
    L.rect(cx + 4, by0 + 1, cx + 6, by1 - 1, "rd2")
    for xx in (cx - 6, cx - 3, cx + 3, cx + 6):
        L.vl(xx, by0, by1, "gd2")
    L.vl(cx - 6, by0, by1, "gd3")
    # 下檐 + 红穗
    L.poly([(cx - 7, by1), (cx + 8, by1), (cx + 5, by1 + 3), (cx - 4, by1 + 3)], "gd2")
    L.hl(cx - 7, cx + 8, by1, "gd3")
    for (tx, ln) in ((cx - 7, 7), (cx + 7, 7), (cx, 6)):
        for yy in range(by1 + 1, by1 + 1 + ln):
            L.p(tx, yy, "rd3")
        L.p(tx, by1, "gd3")
    L.outline()
    return L, foot


def giftbox(L, x0, x1, ytop, hgt, dep, ramp="rd", ribbon="gd"):
    """一只礼盒（斜俯视：顶面 dep 行、正面 hgt 行），十字金丝带、顶上一个蝴蝶结；没有字"""
    F = lambda i: rname(ramp, i)
    G = lambda i: rname(ribbon, i)
    L.rect(x0, ytop, x1, ytop + dep, F(4))
    L.hl(x0, x1, ytop, F(5) if ramp == "rd" else F(4))
    L.rect(x0, ytop + dep, x1, ytop + dep + hgt, F(3))
    L.vl(x1 - 1, ytop + dep, ytop + dep + hgt, F(2))
    L.hl(x0, x1, ytop + dep + hgt - 1, F(2))
    cx = (x0 + x1) // 2
    L.vl(cx, ytop, ytop + dep + hgt, G(3))
    L.hl(x0, x1, ytop + dep // 2, G(3))
    L.p(cx - 2, ytop - 1, G(3))
    L.p(cx - 1, ytop, G(4))
    L.p(cx + 1, ytop, G(4))
    L.p(cx + 2, ytop - 1, G(3))
    L.p(cx, ytop, G(2))


def prop_candy_table(rect):
    """喜糖台：一张矮木桌，桌上一摞红礼盒（大的垫底、小的摞上去，金丝带）、一大盘喜糖、两只小盖碗"""
    x0, f0, x1, f1 = rect
    h = 22
    L = Layer()
    ty0, ty1 = f0 - h, f1 - h
    for lx in (x0 + 2, x1 - 5):
        L.rect(lx, ty1 + 3, lx + 3, f0 + 2, "wd1")
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    L.rect(x0, ty1, x1, ty1 + 3, "wd2")
    L.hl(x0, x1, ty1, "wd5")
    L.hl(x0, x1, ty1 + 2, "wd1")
    L.rect(x0 + 3, ty1 + 3, x1 - 3, ty1 + 6, "wd2")
    L.hl(x0 + 3, x1 - 3, ty1 + 5, "wd1")
    for lx in (x0, x1 - 3):
        L.rect(lx, ty1 + 3, lx + 3, f1, "wd2")
        L.vl(lx, ty1 + 3, f1, "wd3")
        L.vl(lx + 2, ty1 + 3, f1, "wd1")
    L.outline()
    s = sub(x0 - 2, ty0 - 26, x1 + 2, ty1 + 2)
    giftbox(s, x0 + 2, x0 + 20, ty0 - 2, 8, 6)
    giftbox(s, x0 + 4, x0 + 18, ty0 - 13, 6, 5, "rd", "gd")
    giftbox(s, x0 + 6, x0 + 15, ty0 - 21, 5, 4, "gd", "rd")
    seed_plate(s, x0 + 22, ty0 + 3, w=14)
    gaiwan_small(s, x1 - 9, ty0 + 2)
    paste_ol(L, s)
    return L, f1


def lift_wood(res, k=1):
    """v3：整件红木亮 k 档（只挪 wd 色带的像素，描边、红垫子、瓷器不动）——第二版的深红木在亮地板上一坨坨发闷"""
    L, foot = res
    for y in range(L.h):
        for x in range(L.w):
            c = L.px[x, y]
            if c[3] and RAMP_OF.get(c, ("",))[0] == "wd":
                L.px[x, y] = shift(c, k)
    return L, foot


def palm_fan(L, cx, cy):
    """蒲扇（老人家扇风那种）：圆扇面、一圈扇骨、一根短柄"""
    L.ell(cx - 5, cy - 4, cx + 5, cy + 4, "gd3")
    L.ring(cx - 5, cy - 4, cx + 5, cy + 4, "gd1")
    for k in range(5):
        a = -2.4 + k * 0.4
        L.line(cx + 4, cy + 2, cx + 4 + math.cos(a) * 7, cy + 2 + math.sin(a) * 5, "gd2")
    L.p(cx - 3, cy - 2, "gd4")
    L.line(cx + 4, cy + 2, cx + 8, cy + 5, "wd2")


def prop_side_walls(with_west=False):
    """东墙（跟厨房共用）的墙顶；with_west 再画休息间那道隔墙（只给整间图看，游戏里归休息间）"""
    L = Layer()
    walls = [WALL_E] + ([WALL_W] if with_west else [])
    for (a, b) in walls:
        L.rect(a, CAP_Y0, b, FRONT_FACE, "wl4")
        L.vl(a + 1, CAP_Y0 + 1, FRONT_FACE, "wl5")
        L.vl(a, CAP_Y0, FRONT_FACE, "ol")
        L.vl(b - 1, CAP_Y0, FRONT_FACE, "ol")
        L.hl(a, b, CAP_Y0, "ol")
        for y in range(CAP_Y0 + 1, CAP_Y1 - 1):
            L.p(a + 1 if a == WALL_W[0] else b - 2, y, "wl5")
    return L, 684


def front_wall_face(L, a, b):
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
    """前沿矮墙：西墙外沿（667，方案 C 起；原来从休息间隔墙外沿 677 起）到门洞、门洞到东墙外沿（1013）；门洞两边一对门套（跟休息间一样）"""
    L = Layer()
    for (a, b) in ((WALL_W[1], DOOR[0]), (DOOR[1], WALL_E[1])):
        L.rect(a, FRONT_TOP, b, FRONT_FACE, "wl4")
        L.hl(a, b, FRONT_TOP, "ol")
        L.hl(a, b, FRONT_TOP + 1, "wl5")
        L.hl(a, b, FRONT_FACE - 1, "wl3")
        front_wall_face(L, a, b)
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
    # 10/4 方案 C：麻将室挪到后厨东边，西墙那头没有休息间的矮墙接着了——西墙脚下补一截矮墙（667～677，原来那段一笔不动），
    # 西墙顶也拐进前沿墙顶，端头描一条边
    a, b = WALL_W
    L.rect(a, FRONT_TOP, b, FRONT_FACE, "wl4")
    L.hl(a, b, FRONT_TOP, "ol")
    L.hl(a, b, FRONT_TOP + 1, "wl5")
    L.hl(a, b, FRONT_FACE - 1, "wl3")
    front_wall_face(L, a, b)
    # 东墙顶、西墙顶在这里拐进前沿墙顶
    L.rect(WALL_E[0] + 1, FRONT_TOP, WALL_E[1] - 1, FRONT_FACE - 1, "wl4")
    L.rect(WALL_W[0] + 1, FRONT_TOP, WALL_W[1] - 1, FRONT_FACE - 1, "wl4")
    L.outline(skip=lambda x, y: y >= FRONT_FACE or x < WALL_W[0] or x >= WALL_E[1])
    L.vl(WALL_W[0], FRONT_TOP, FRONT_BOT, "ol")
    return L, 696


# ================================================================== 影子、暖光
TABLE_LAMPS = [(942, 395), (737, 315), (737, 505), (844, 305)]     # 每张牌桌上头一盏灯（灯不画，只画桌子四周地上亮一圈）


def floor_shading(shadows):
    S = ShadeMap()
    S.rect(WALL_W[1], FLOOR_Y, WALL_E[0], FLOOR_Y + 2, -1.5)
    S.rect(WALL_W[1], FLOOR_Y + 2, WALL_E[0], FLOOR_Y + 5, -0.5)
    S.rect(WALL_W[1], FLOOR_Y, WALL_W[1] + 6, 662, -1.0)
    S.rect(WALL_W[1] + 6, FLOOR_Y, WALL_W[1] + 9, 662, -0.5)
    S.rect(WALL_E[0] - 2, FLOOR_Y, WALL_E[0], 662, -0.5)
    S.rect(WALL_W[1], 659, DOOR[0], 662, -0.5)          # v3：前沿矮墙根的影只在墙前，门洞（长红地毯过门那截）不画
    S.rect(DOOR[1], 659, WALL_E[0], 662, -0.5)
    for (x0, y0, x1, y1, k) in shadows:
        S.rect(x0 + 1, y0 + 1, x1 + 2, y1 + 2, k, feather=1)
    for (cx, cy) in TABLE_LAMPS:                       # v3：光圈收小（第二版 62×44 在亮地板上一块块发白）
        rx, ry = (40, 27) if cx == 844 else (52, 35)
        S.ellipse(cx, cy, rx, ry, 1.0, edge=2.5)
    cone(S, (DOOR[0] + DOOR[1]) // 2, 683, 626, 40, 0.30, 1.0, edge=1.5)
    cone(S, (DOOR[0] + DOOR[1]) // 2, 626, 614, 57, 0.30, 0.5, edge=1.5)   # v3：远头 12 行只亮半档（棋盘点），不再切一道横边
    for (lx, ly) in ((785, 646), (894, 646)):           # 两盏宫灯照亮脚下一小圈
        S.ellipse(lx, ly, 16, 9, 1.0, edge=1.5)
    return S


def wall_light(L):
    """两只灯笼照亮墙纸一圈；花窗透光照亮窗下护墙板一点"""
    S = ShadeMap()
    for kx in LANTERN_KNOTS:
        S.ellipse(kx, 142, 12, 14, 1.0, edge=1.5)
    S.apply(L, clip=lambda x, y: CAP_Y1 < y < FLOOR_Y and WALL_W[1] <= x < WALL_E[0]
            and RAMP_OF.get(L.g(x, y), ("",))[0] in ("wl", "wd"))


# ================================================================== 组装
def background():
    L = Layer()
    L.rect(X0, Y0, X1, Y1, "void")
    draw_floor(L)
    for f in FLAT:
        if f[0].startswith("rug_mj"):
            draw_rug(L, f[2], "red", bw=10)
    draw_rug(L, PLAN_FLAT("rug_rest"), "cream", bw=8)
    draw_rug(L, PLAN_FLAT("rug_card"), "cream", bw=8)
    draw_rug(L, PLAN_FLAT("runner"), "runner", bw=8)
    draw_petals(L)
    draw_north_wall(L)
    draw_window(L)
    draw_painting(L)
    draw_swag(L)
    for kx in LANTERN_KNOTS:
        draw_lantern(L, kx, 128)
    draw_knot(L, 975, 124)
    draw_papercut(L, 818, 148)
    draw_papercut(L, 926, 148)
    L.rect(DOOR[0], 684, DOOR[1], 696, "wd4")
    L.hl(DOOR[0], DOOR[1], 684, "wd2")
    L.hl(DOOR[0], DOOR[1], 685, "wd5")
    L.hl(DOOR[0], DOOR[1], 690, "wd3")
    L.hl(DOOR[0], DOOR[1], 691, "wd5")
    L.hl(DOOR[0], DOOR[1], 695, "wd2")
    L.rect(X0, 696, X1, Y1, "wl2")
    return L


def build():
    bg = background()
    R = {p[0]: p[3] for p in PLAN}
    props = []
    for tid in ("mahjong_table", "mahjong_table_2", "mahjong_table_3"):
        props.append((tid,) + lift_wood(prop_mj_table(tid, R[tid], SEATED[tid])))   # v3 红木亮一档，跟椅子一家
    for p in PLAN:
        if "_chair_" in p[0] and p[0][2] in "123":
            props.append((p[0],) + prop_chair(p[3], p[0][-1], cushion="rd"))
    props += [
        ("mj_sideboard",) + lift_wood(prop_sideboard(R["mj_sideboard"])),   # v3：亮一档，跟后面的深色护墙板分开
        ("mj_stand_1",) + prop_stand(R["mj_stand_1"], "red"),
        ("mj_stand_2",) + prop_stand(R["mj_stand_2"], "bamboo"),
        ("mj_stand_3",) + prop_stand(R["mj_stand_3"], "red"),
        ("mj_tea_1",) + lift_wood(prop_low_table(R["mj_tea_1"])),
        ("mj_rest_chair_w",) + prop_chair(R["mj_rest_chair_w"], "n", arms=True, cushion="rd"),
        ("mj_rest_chair_e",) + prop_chair(R["mj_rest_chair_e"], "n", arms=True, cushion="rd"),
        ("mj_cage_stand",) + prop_cage_stand(R["mj_cage_stand"]),
        ("card_table",) + lift_wood(prop_card_table(R["card_table"])),
        ("card_chair_n",) + prop_chair(R["card_chair_n"], "n", cushion="rd"),
        ("card_chair_w",) + prop_chair(R["card_chair_w"], "w", cushion="rd"),
        ("card_chair_e",) + prop_chair(R["card_chair_e"], "e", cushion="rd"),
        ("mj_candy_table",) + lift_wood(prop_candy_table(R["mj_candy_table"])),
        ("mj_lamp_w",) + prop_palace_lamp(R["mj_lamp_w"]),
        ("mj_lamp_e",) + prop_palace_lamp(R["mj_lamp_e"]),
        ("mj_flower_stand",) + prop_flower_stand(R["mj_flower_stand"]),
        ("mj_coat_rack",) + prop_coat_rack(R["mj_coat_rack"]),
        ("mj_tea_2",) + lift_wood(prop_low_table(R["mj_tea_2"])),
        ("mj_recliner",) + lift_wood(prop_luohan(R["mj_recliner"])),
        ("mj_fan",) + prop_fan(R["mj_fan"]),
        ("mj_plant_nw",) + prop_plant_bamboo(R["mj_plant_nw"]),
        ("mj_plant_se",) + prop_money_tree(R["mj_plant_se"]),
        ("side_walls",) + prop_side_walls(with_west=True),   # 方案 C：西墙挨后厨，这间自己画
        ("front_walls",) + prop_front_walls(),
    ]
    shadows = []
    for (iid, name, zone, r, h, block, st, real) in PLAN:
        if iid.startswith("mahjong_table") or iid.startswith("mj_tea"):
            shadows.append((r[0], r[1] + 2, r[2], r[3], -1.5))
        elif iid == "mj_fan":
            shadows.append((r[0], r[3] - 6, r[2], r[3], -1.5))
        else:
            shadows.append((r[0], r[1], r[2], r[3], -1.5 if h < 30 else -2.0))
    S = floor_shading(shadows)
    rx0, ry0, rx1, ry1 = PLAN_FLAT("runner")
    door = ShadeMap()                                   # v3：门口那束光不照长红地毯（照上去那一截发橙，像接了另一块毯子）
    cone(door, (DOOR[0] + DOOR[1]) // 2, 683, 626, 40, 0.30, 1.0, edge=1.5)
    cone(door, (DOOR[0] + DOOR[1]) // 2, 626, 614, 57, 0.30, 0.5, edge=1.5)
    for y in range(max(0, ry0 - Y0), min(H, ry1 - Y0)):
        for x in range(rx0 - X0, rx1 - X0):
            S.v[y][x] -= door.v[y][x]
    S.apply(bg, clip=lambda x, y: y >= FLOOR_Y)
    wall_light(bg)
    return bg, props


SIT_LIFT = 66          # 坐着的人头顶离脚点多高（表里坐着 62；Q 版头大，取 66 才露得出肩膀）


def sit_rows(fx, fy, mode):
    """坐着的人只留上面几行，下半截让桌子、椅子挡住：坐北的留到桌面后沿往下 5 行；其余留到座面"""
    top = fy - SIT_LIFT
    if mode == "sit_n":
        for p in PLAN:
            if p[0].startswith("mahjong_table"):
                x0, yf0, x1, yf1 = p[3]
                if x0 <= fx <= x1 and 0 < yf0 - fy < 30:
                    return (yf0 - p[4] + 5) - top
    return (fy - 19) - top


def standin(code, frame, mode, fx=0, fy=0):
    im = Image.open(CHAR_DIR + "chr_LM-GUEST-%s.png" % code).convert("RGBA")
    im = im.crop((frame * 64, 0, frame * 64 + 64, 84))
    if mode == "stand":
        return im, 0
    return im.crop((0, 0, 64, sit_rows(fx, fy, mode))), SIT_LIFT


def people_list(extra=()):
    out = []
    for (sid, who, code, frame, (fx, fy), mode) in list(STANDINS) + list(extra):
        img, lift = standin(code, frame, mode, fx, fy)
        top = fy - (lift if lift else img.height)
        out.append((img, fx, top, fy, mode))
    return out


def compose(bg, props, people=()):
    out = bg.im.copy()
    items = [(foot, 0, name, layer) for (name, layer, foot) in props]
    for k, person in enumerate(people):
        items.append((person[3], 1, "p%d" % k, person))
    items.sort(key=lambda t: (t[0], t[1]))
    for foot, kind, name, obj in items:
        if kind == 0:
            out.alpha_composite(obj.im, (obj.ox - X0, obj.oy - Y0))
        else:
            img, fx, top, key, mode = obj
            out.alpha_composite(img, (fx - img.width // 2 - X0, top - Y0))
    return out


def with_people(bg, props, extra=()):
    plist = people_list(extra)
    bgp = Layer()
    bgp.im = bg.im.copy()
    bgp.px = bgp.im.load()
    S = ShadeMap()
    for (img, fx, top, key, mode) in plist:
        if mode == "stand":
            S.ellipse(fx + 1, key - 1, 12, 4, -1.5, edge=1.5)
    S.apply(bgp)
    return compose(bgp, props, plist)


def palette_count(im):
    cols = set()
    for c in im.getdata():
        if c[3] == 255:
            cols.add(c[:3])
        elif c[3] != 0:
            raise SystemExit("有半透明像素：%s" % (c,))
    return cols


def tile_check(props):
    """牌面检查：三张桌的绒面范围里只许有绒面三档、牌背金黄、牌侧象牙白、描边这几种颜色——
    万、条、筒的花色要用红、绿、蓝、黑点，只要冒出一个这种颜色的像素就停"""
    ok = {C[n] for n in ("tl0", "tl", "tl2", "gd0", "gd1", "gd2", "gd3", "gd4", "wl3", "wl5", "wt", "ol")}
    for name, layer, foot in props:
        if not name.startswith("mahjong_table"):
            continue
        x0, yf0, x1, yf1 = PLAN_BY[name][3]
        ty0, ty1 = yf0 - 36, yf1 - 36
        for y in range(ty0 + 3, ty1 - 3):
            for x in range(x0 + 3, x1 - 3):
                c = layer.g(x, y)
                if c[3] and c not in ok:
                    raise SystemExit("牌面检查没过：%s 绒面 (%d, %d) 有 %s" % (name, x, y, c))
    # v2 打牌桌：桌面范围里只许有红桌布、金边金点、扑克牌背（白边蓝底）、盖碗白瓷、描边——
    # 扑克牌面要用黑、红花色和数字，钱、筹码要用绿、金、黑这些，出现别的颜色就停
    ok_card = {C[n] for n in ("rd2", "rd3", "rd4", "gd1", "gd2", "gd3", "bl0", "bl1", "bl2", "wt", "wl3", "wl5", "ol")}
    for name, layer, foot in props:
        if name != "card_table":
            continue
        x0, yf0, x1, yf1 = PLAN_BY[name][3]
        for y in range(yf0 - 34 - 2, yf1 - 34):
            for x in range(x0, x1):
                c = layer.g(x, y)
                if c[3] and c not in ok_card:
                    raise SystemExit("牌面检查没过：打牌桌 (%d, %d) 有 %s" % (x, y, c))
        # 每张扑克牌背中间一格都得是蓝底：白里不许出现别的点（牌面的花色、数字）
    print("牌面检查：三张麻将桌的牌只有金黄牌背、象牙白侧边和空白面；打牌桌只有扑克牌背（白边蓝底），没有牌面、钱、筹码、骰子")


def walk_check(verbose=True):
    """从门口 (840, 680) 走得到每件东西跟前、交互点、围观站人点吗：2 像素一格，人按脚底 12×6 算（照休息间）"""
    step = 2
    blocks = [p[3] for p in PLAN if p[5]]

    def free(x, y):
        if not (WALL_W[1] + 6 <= x <= WALL_E[0] - 6 and 232 <= y <= 682):
            return False
        if y > FRONT_TOP - 3 and not (DOOR[0] + 6 <= x <= DOOR[1] - 6):
            return False
        for (x0, y0, x1, y1) in blocks:
            if x0 - 6 < x < x1 + 6 and y0 - 3 < y < y1 + 3:
                return False
        return True
    start = (840, 680)
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
    for (iid, name, zone, r, h, block, st, real) in PLAN:
        x0, y0, x1, y1 = r
        cands = [(x, y1 + 4) for x in range(x0 - 6, x1 + 8, 2)] + [(x, y0 - 4) for x in range(x0 - 6, x1 + 8, 2)] + \
                [(x0 - 8, y) for y in range(y0, y1 + 4, 2)] + [(x1 + 8, y) for y in range(y0, y1 + 4, 2)]
        cands = [((c[0] // 2) * 2, (c[1] // 2) * 2) for c in cands]
        if not any(c in seen for c in cands):
            bad.append(iid)
    spot_bad = [s[0] for s in SPOTS if ((s[2][0] // 2) * 2, (s[2][1] // 2) * 2) not in seen]
    lane = all(((x // 2) * 2, (y // 2) * 2) in seen for x in (828, 840, 852) for y in range(430, 680, 2))
    if verbose:
        print("走得通：%d/%d 件；站人点 %s；门口到交互点的路 %s" % (
            len(PLAN) - len(bad), len(PLAN), "都站得到" if not spot_bad else "站不到 " + "、".join(spot_bad),
            "通" if lane else "不通"))
        if bad:
            print("  走不到：" + "、".join(bad))
    return bad, spot_bad, lane, seen


def crop_alpha(layer):
    box = layer.im.getbbox()
    return layer.im.crop(box), layer.ox + box[0], layer.oy + box[1]


def lounge_game():
    """休息间第三版游戏里那套（背景 + 每件家具按着地线叠好），画布坐标 x 328～680"""
    man = json.load(open(os.path.join(LOUNGE_DIR, "room.json"), encoding="utf-8"))
    return man


def paste_room_json(out, ox, oy, d, people_layer=None):
    man = json.load(open(os.path.join(d, "room.json"), encoding="utf-8"))
    bgd = man["background"]
    im = Image.open(os.path.join(d, "room.png")).convert("RGBA")
    out.alpha_composite(im, (bgd["x"] - ox, bgd["y"] - oy))
    for p in sorted(man["props"], key=lambda p: p["foot"]):
        pi = Image.open(os.path.join(d, "props", os.path.basename(p["png"]))).convert("RGBA")
        out.alpha_composite(pi, (p["x"] - ox, p["y"] - oy))


def main():
    rnd_name = None
    check_layout()
    bad, spot_bad, lane, seen = walk_check()
    if bad or spot_bad or not lane:
        raise SystemExit("走路检查没过")
    bg, props = build()
    tile_check(props)
    room_empty = compose(bg, props)
    cols = palette_count(room_empty)
    print("整间 %s，颜色 %d 种（调色板 %d）" % (room_empty.size, len(cols), len(PAL_HEX)))
    if len(cols) > 64:
        raise SystemExit("颜色超过 64 种（%d）" % len(cols))
    # 整间图：左边补上休息间那道隔墙（游戏里归休息间画）
    west = prop_side_walls(with_west=True)[0]
    bgw = Layer()
    bgw.im = bg.im.copy()
    bgw.px = bgw.im.load()
    props_w = [p for p in props if p[0] != "side_walls"] + [("side_walls", west, 684)]
    room_empty = compose(bgw, props_w)
    room = with_people(bgw, props_w, WATCHERS)
    export_layers(bg, props)
    print("图层出到 %s" % LAYERS)
    if OUT is None:
        return
    os.makedirs(OUT, exist_ok=True)
    room_empty.save(os.path.join(OUT, "mahjong03_room_empty.png"))
    room.save(os.path.join(OUT, "mahjong03_room.png"))
    room.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(OUT, "mahjong03_room_x2.png"))
    phone(bgw, props_w)
    side_by_side(bg, props)
    compare(room)
    write_patch()
    print("预览出完了 → %s" % OUT)


def export_layers(bg, props):
    os.makedirs(os.path.join(LAYERS, "props"), exist_ok=True)
    bx0, by0, bx1, by1 = BG_CROP
    bgi = bg.im.crop((bx0 - X0, by0 - Y0, bx1 - X0, by1 - Y0))
    palette_count(bgi)
    bgi.save(os.path.join(LAYERS, "room.png"))
    hide = {"side_walls": ["wall_1"], "front_walls": []}   # 方案 C：这间画的西墙盖 wall_1（挨后厨那道）
    man = {"note": "draw_mahjong.py 生成。照 tools/pixel_art 休息间、化妆间的 room.json 写法：背景左上角放在 background.x/y（画布坐标），"
                   "1 倍、不插值；每件家具左上角在 x/y，着地线 foot（跟人排前后用；桌南那四把背对镜头的椅子 foot 比占地多 3，"
                   "好压在坐着的人前面）；hide 是要藏掉的灰盒（挡人的占地照旧）",
           "background": {"png": "res://assets/pixel_art/backhall_mahjong/room.png", "x": bx0, "y": by0},
           "room": {"x0": bx0, "x1": bx1}, "props": []}
    names = set()
    for name, layer, foot in props:
        im, x, y = crop_alpha(layer)
        palette_count(im)
        im.save(os.path.join(LAYERS, "props", name + ".png"))
        names.add(name + ".png")
        # 墙那两张跟休息间的同名（px_side_walls、px_front_walls），节点会撞名：麻将室的加 mj_
        pid = "px_mj_" + name if name in ("side_walls", "front_walls") else "px_" + name
        man["props"].append({"id": pid, "png": "res://assets/pixel_art/backhall_mahjong/props/%s.png" % name,
                             "x": x, "y": y, "foot": foot, "hide": hide.get(name, [name] if name in LAYOUT_IDS else [])})
    for f in os.listdir(os.path.join(LAYERS, "props")):
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(LAYERS, "props", f))
    backhall_plan_c.shift_room_json(man, DX)   # 方案 C：整间往西挪
    with open(os.path.join(LAYERS, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")


def draw_corridor(L):
    """手机图底下那条走廊（照休息间）"""
    x0, x1 = L.ox, L.ox + L.w
    rnd = random.Random(7)
    L.rect(x0, 696, x1, 884, "wl2")
    for row, y in enumerate(range(696, 884, 12)):
        off = 0 if row % 2 == 0 else 24
        for x in range(x0 - 48 + off - (x0 % 48), x1, 48):
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
                if row[x % 8] == "1":
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


RULER = ("ruler", "当尺子的定稿宾客（站在交互点，正面）", "06", 0, (852, 430), "stand")


def scene_canvas(cx0, cy0, w, h, bg, props, people=True, extra=()):
    """画布坐标 (cx0, cy0) 起一块 w×h：左边休息间（游戏里那套）、中间麻将室、右边厨房（游戏里同样拉成 528×586）"""
    out = Image.new("RGBA", (w, h), C["void"])
    k = Image.open(KITCHEN_PNG).convert("RGBA").resize((528, 586), Image.NEAREST)
    out.alpha_composite(k, (1008 - cx0, 104 - cy0))
    paste_room_json(out, cx0, cy0, LOUNGE_DIR)
    room = with_people(bg, props, extra) if people else compose(bg, props)
    # 麻将室：只贴休息间隔墙外沿以东（隔墙归休息间）
    part = room.crop((WALL_W[1] - X0, 0, W, FRONT_BOT - Y0))
    out.alpha_composite(part, (WALL_W[1] - cx0, Y0 - cy0))
    return out


def phone(bg, props):
    """540×960 手机竖屏：镜头对着麻将室（画布 x 570～1110），底下一条走廊，站一个定稿宾客当尺子"""
    SW, SH = 540, 960
    cx0, cy0 = 570, 20
    scr = Image.new("RGBA", (SW, SH), C["void"])
    cor = Layer(x0=cx0, y0=696, w=SW, h=200)
    draw_corridor(cor)
    scr.alpha_composite(cor.im, (0, 696 - cy0))
    top = scene_canvas(cx0, cy0, SW, 696 - cy0, bg, props, True, extra=[RULER] + WATCHERS)
    scr.alpha_composite(top, (0, 0))
    # 前沿矮墙在走廊上面压一条（休息间、麻将室的 props 已经画了，厨房那段补上）
    fw = Layer(x0=cx0, y0=FRONT_TOP, w=SW, h=FRONT_BOT - FRONT_TOP)
    fw.rect(WALL_E[1], FRONT_TOP, cx0 + SW, FRONT_FACE, "wl4")
    fw.hl(WALL_E[1], cx0 + SW, FRONT_TOP, "ol")
    fw.hl(WALL_E[1], cx0 + SW, FRONT_TOP + 1, "wl5")
    fw.hl(WALL_E[1], cx0 + SW, FRONT_FACE - 1, "wl3")
    front_wall_face(fw, WALL_E[1], cx0 + SW)
    scr.alpha_composite(fw.im, (0, FRONT_TOP - cy0))
    scr.save(os.path.join(OUT, "mahjong03_phone.png"))


def side_by_side(bg, props):
    """休息间第三版（游戏里那套）和麻将室并排连着：画布 x 328～1016"""
    cx0, cy0 = 328, 100
    w, h = 1016 - 328, 600
    out = scene_canvas(cx0, cy0, w, h, bg, props, True, extra=WATCHERS)
    out.save(os.path.join(OUT, "mahjong03_with_lounge.png"))
    out.resize((w * 2, h * 2), Image.NEAREST).save(os.path.join(OUT, "mahjong03_with_lounge_x2.png"))


def compare(room):
    """三联：休息间第三版 | 麻将室 | 宴会厅 base.png 裁一块（x 240～592、y 0～600），都是画布 1:1 再一起放大 2 倍"""
    lounge = Image.new("RGBA", (W, H), C["void"])
    paste_room_json(lounge, 328, 100, LOUNGE_DIR)
    ban = Image.open(BANQUET_PNG).convert("RGBA").crop((240, 0, 592, 600))
    gap = 8
    cmp_ = Image.new("RGBA", (W * 3 + gap * 4, H + gap * 2), C["void"])
    for k, im in enumerate((lounge, room, ban)):
        cmp_.alpha_composite(im, (gap + k * (W + gap), gap))
    cmp_.resize((cmp_.width * 2, cmp_.height * 2), Image.NEAREST).save(os.path.join(OUT, "mahjong03_compare.png"))


def write_patch():
    d = json.load(open(LAYOUT, encoding="utf-8"))
    items = {it["id"]: it for it in d["items"] if "id" in it}
    out = {
        "note": "麻将室摆法（mahjong03，2026-10-03；摆法跟 mahjong02 一模一样，只改了画；跟第二版那份比只改了 name 的字：竹椅、竹圈椅改叫红木椅、红木圈椅（第二版起就是红木），鸟笼架去掉「竹」字）。只是补丁，不改 layout.json 本身：本地 02 照这份改。rect = 占地（画布坐标，y 是地面前后），"
                "h = 高（像素，1 米 48）；block=true 挡人。status：keep = layout.json 里原样没动、moved = 挪了、new = 新加。"
                "三张麻将桌、十二把椅子、两张茶几原样没动；墙、前沿矮墙、门洞、mahjong 交互点没动。part 编号没给（零件总表归 01）。",
        "room": {"x": [677, 1003], "door_gap": list(DOOR), "mahjong_point": list(MJ_POINT)},
        "remove": [],
        "items": [],
        "flat": [{"id": f[0], "name": f[1], "rect": f[2], "block": False} for f in FLAT],
        "npcs": [],
        "spots": [{"id": s[0], "name": s[1], "x": s[2][0], "y": s[2][1], "r": s[3]} for s in SPOTS],
        "keep_clear": KEEP_CLEAR,
    }
    for (iid, name, zone, r, h, block, st, real) in PLAN:
        it = {"type": "box", "id": iid, "name": name, "rect": r, "h": h, "block": block, "zone": zone, "status": st,
              "scale": {"w_m": real[0], "d_m": real[1], "h_m": real[2]},
              "foot": r[3] + (3 if iid.endswith("_chair_s") else 0)}
        if iid in items and "part" in items[iid]:
            it["part"] = items[iid]["part"]
        out["items"].append(it)
    npcs = {n["id"]: n for n in d["npcs"]}
    for (sid, who, code, frame, (fx, fy), mode) in STANDINS:
        rows = 84 if mode == "stand" else sit_rows(fx, fy, mode)
        e = {"id": sid, "who": who, "x": fx, "y": fy, "status": "keep" if sid in npcs else "new",
             "sit": mode != "stand", "face": {"sit_n": "down", "sit_s": "up", "sit_w": "right", "sit_e": "left"}.get(mode, "down"),
             "standin": {"code": "LM-GUEST-%s" % code, "frame": frame, "rows": rows,
                         "bottom": fy - (84 if mode == "stand" else SIT_LIFT) + rows}}
        out["npcs"].append(e)
    with open(os.path.join(OUT, "layout补丁.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)
        fh.write("\n")


KEEP_CLEAR = [
    {"what": "门口往里那条路（门洞 800～880，从门槛一直到 mahjong 交互点）", "rect": [798, 430, 882, 684]},
    {"what": "mahjong 交互点四周", "rect": [826, 394, 878, 446]},
]

if __name__ == "__main__":
    main()
