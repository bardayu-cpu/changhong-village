#!/usr/bin/env python3
"""【v3 副本，2026-10-03】只换了地板（宽板蜜色木，见 backhall_floor.py）和 OUT 那一行；家具、墙、地毯、灯光一行没动。
后厅休息间：用代码画的像素成品，第三版（01 画，阿鱼 10/3「第三版可以」；标准见 docs/罗曼山庄画风.md 第 0 节）。
画法整套照 01 版（1 倍颗粒、硬边、色带挪档、深褐描边、光从左上、按着地线分层），摆法照 06 v2.2 再加东西：
东墙大电视在播晚会、游戏机和手柄、对着电视的三人沙发、西墙书架加看书长沙发、门口双人沙发、单人沙发 6 张、唱片墙；没有行李箱。
阿鱼看完第三版又定了两处（01 F 转，阿鱼「对，两处都改」）：左下看书角那组蓝丝绒沙发换成米白（跟整间别的米白沙发同一条色带，不加色）；
西边中间的棋桌换成小茶几（竹茶盘、青花小茶壶、盖碗，跟北边茶几一家），两张单人沙发留着，地毯还是回纹边米色心的小地毯。

出游戏用的图（assets/pixel_art/backhall_lounge/）：
  room.png        背景：北墙（墙顶、墙纸、护墙板、画、钟、剪纸、红绸）、地板、五块回纹地毯、门里地垫和花瓣、地上的影子和灯光
  props/*.png     每件家具一张（裁到画了的那块），按着地线跟人排前后；跟化妆间共用的西隔墙、前沿矮墙归这份画
  room.json       放哪：背景左上角；每件左上角 x、y 和着地线 foot；要藏掉的灰盒 id。entrance.gd 的 _pixel_art() 读它
位置只从 layout.json 取：开头把 PLAN 每件的 rect / h、墙、门口、交互点跟 layout.json 对一遍，对不上就停；再从门口按脚底 12×6 走一遍，
有一件走不到跟前、站人点站不到、门口到交互点不通，也停。
样板原稿在 godot/回执/样板间-休息间-v3/draw_lounge_v3.py（01 画，改 5 轮）；这份是 02 收进来，改了上面两处、出图改成游戏用的。
第一版（01 版）的图换掉了，原稿还在 godot/回执/样板间-休息间-01版/。

用法：python3 godot/tools/pixel_art/room_backhall_lounge.py [--preview 目录]（跑一次约 15 秒）
      --preview 再出整间 1:1、手机竖屏（站两位定稿宾客当尺子）、「样板 v3 | 改完」并排
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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backhall_floor import HW_HEX, HW_RAMP, draw_floor_v3   # 地板 v3：三间共用一份（同一个文件夹）

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
if not os.path.isdir(os.path.join(GODOT, "assets")):     # v3 副本在仓库外跑：指回仓库（搬回 tools/pixel_art 后这两行不起作用）
    GODOT = os.path.join("/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件", "godot")
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_backhall", "layout.json")
CHAR_DIR = os.path.join(GODOT, "assets", "characters", "lm") + "/"
V3_PNG = os.path.join(GODOT, "回执", "样板间-休息间-v3", "lounge03_room.png")   # 只给 --preview 的并排图用
OUT = os.path.join(HERE, "lounge_layers")   # v3 副本：写进交付目录（搬回仓库时改回 os.path.join(GODOT, "assets", "pixel_art", "backhall_lounge")）
RES = "res://assets/pixel_art/backhall_lounge/"
BG_CROP = (331, 104, 677, 696)   # 背景进游戏只要两道隔墙之间、北墙顶到前沿矮墙
# 每件家具进游戏时藏掉哪几件灰盒（挡人的占地照旧）；没写的就是同名那一件；墙是盖在灰盒的墙上，不藏
HIDE = {"sofa": ["sofa", "sofa_back"], "side_walls": [], "front_walls": []}

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
    # 跟化妆间一样加的 5 色（银三档：游戏机、电视边框的冷色；粉两档）
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


# ------------------------------------------------------------------ 摆法（第三版）
# PLAN 是唯一的源：画图、地上的影子、走路检查、layout 补丁都从它出。
# (id, 名字, 区, 占地 rect [x0, y0, x1, y1]（y 是地面前后）, 高 h, 挡不挡人, 跟 layout.json 比：keep / moved / new)
PLAN = [
    ("vinyl_wall", "唱片墙", "唱片角", [352, 226, 496, 232], 115, True, "keep"),
    ("record_player", "唱片机（连金喇叭）", "唱片角", [396, 258, 452, 284], 97, True, "keep"),
    ("record_crate", "唱片箱（两只木箱叠着）", "唱片角", [356, 272, 386, 290], 22, True, "new"),
    ("fiddle_fig", "琴叶榕", "茶座", [497, 234, 515, 242], 82, True, "keep"),
    ("sofa_back", "三人沙发（靠背）", "茶座", [516, 236, 617, 244], 41, True, "keep"),
    ("sofa", "三人沙发（坐垫）", "茶座", [516, 244, 617, 268], 20, True, "keep"),
    ("tea_table", "茶几", "茶座", [538, 296, 596, 314], 22, True, "keep"),
    ("armchair_w", "单人沙发 1（朝东）", "茶座", [480, 292, 523, 320], 41, True, "keep"),
    ("armchair_e", "单人沙发 2（朝西）", "茶座", [604, 292, 647, 320], 41, True, "keep"),
    ("floor_lamp", "落地灯", "茶座", [624, 252, 634, 260], 77, True, "keep"),
    ("tv_unit", "电视柜连大电视、游戏机", "电视角", [638, 360, 664, 450], 24, True, "moved"),
    ("tv_sofa", "三人沙发（朝东看电视）", "电视角", [548, 378, 590, 458], 41, True, "new"),
    ("tv_table", "电视前长茶几（两个手柄）", "电视角", [598, 398, 620, 438], 18, True, "new"),
    ("bookshelf_1", "书架 1（靠西墙）", "看书角", [342, 330, 362, 392], 86, True, "new"),
    ("bookshelf_2", "书架 2（靠西墙）", "看书角", [342, 428, 362, 490], 86, True, "new"),
    ("reading_lamp", "阅读落地灯", "看书角", [346, 496, 356, 502], 77, True, "new"),
    ("reading_sofa", "看书的长沙发（朝东）", "看书角", [342, 508, 384, 588], 41, True, "new"),
    ("book_table", "放书矮桌", "看书角", [394, 524, 420, 564], 20, True, "new"),
    ("reading_chair", "单人沙发 3（朝西）", "看书角", [424, 528, 462, 556], 41, True, "new"),
    ("floor_lamp_se", "落地灯 2", "门口落座", [652, 530, 662, 536], 77, True, "new"),
    ("loveseat", "双人沙发（朝西）", "门口落座", [628, 544, 664, 592], 41, True, "new"),
    ("se_table", "圆边几", "门口落座", [608, 558, 626, 576], 24, True, "new"),
    ("se_chair", "单人沙发 4（朝东）", "门口落座", [568, 552, 604, 580], 41, True, "new"),
    ("kumquat", "金桔一盆", "门口落座", [638, 630, 662, 646], 60, True, "new"),
    ("west_chair_w", "单人沙发 5（朝东）", "西边茶座", [386, 386, 420, 414], 41, True, "new"),
    ("west_table", "小茶几（竹茶盘、青花小茶壶、盖碗；原来是棋桌，阿鱼 10/3 换）", "西边茶座", [420, 394, 446, 412], 24, True, "new"),
    ("west_chair_e", "单人沙发 6（朝西）", "西边茶座", [446, 386, 480, 414], 41, True, "new"),
    ("coat_rack", "衣帽架（挂外套）", "门口", [548, 646, 566, 654], 84, True, "moved"),
    ("sw_table", "小边几（台灯、杂志）", "看书角", [382, 626, 406, 642], 30, True, "new"),
    ("plant", "绿植（青花盆）", "西南角", [350, 656, 370, 668], 16, True, "keep"),
]
PLAN_BY = {p[0]: p for p in PLAN}
# 平铺在地上、不挡人
FLAT = [
    ("rug_tea", "茶座回纹地毯（01 版原样）", [470, 250, 658, 342]),
    ("rug_tv", "电视角回纹地毯（米色心）", [540, 370, 632, 466]),
    ("rug_read", "看书角回纹地毯（红心）", [376, 504, 468, 598]),
    ("rug_se", "门口落座小地毯（藏青心）", [566, 538, 646, 602]),
    ("rug_west", "西边茶座小地毯（回纹边、米色心）", [378, 374, 488, 424]),
    ("doormat", "门里地垫", [480, 644, 528, 660]),
]
# 以后玩法要站人的地方（阿鱼说的：听唱片、看电视、坐下休息）
SPOTS = [
    ("stand_record", "唱片机前（听唱片）", (424, 312), 16),
    ("stand_tv", "电视前（看电视、打游戏）", (616, 476), 14),
    ("lounge", "休息间交互点（layout 原有）", (504, 420), 20),
]
REMOVED = [("luggage_1", "蓝色拉杆箱（休息间不要行李箱）"), ("luggage_2", "棕色皮箱（同上）")]
# layout.json 里这版没动、要核对的东西
KEEP_CHECK = ["vinyl_wall", "fiddle_fig", "sofa_back", "sofa", "tea_table", "armchair_w", "armchair_e", "floor_lamp",
              "plant", "wall_1", "wall_2", "front_2", "front_3"]


def check_layout():
    """layout.json 里没挪的东西、墙、门口、交互点要跟这版一致，不一致就停"""
    d = json.load(open(LAYOUT, encoding="utf-8"))
    bad = []
    want = {p[0]: (p[3], p[4]) for p in PLAN}
    want.update({"wall_1": ([331, 226, 341, 684], 44), "wall_2": ([667, 226, 677, 684], 44),
                 "front_2": ([208, 684, 464, 696], 22), "front_3": ([544, 684, 800, 696], 22)})
    for iid in list(want):
        rect, h = want[iid]
        it = IT.get(iid)
        if it is None or list(it.get("rect", [])) != rect or it.get("h") != h:
            bad.append("%s：脚本 %s h%s，布局 %s h%s" % (iid, rect, h, it and it.get("rect"), it and it.get("h")))
    for (iid, why) in REMOVED:
        if iid in IT:
            bad.append("%s 还在布局里（%s）" % (iid, why))
    pts = {p["id"]: p for p in d["points"]}
    if (pts["lounge"]["x"], pts["lounge"]["y"]) != (504, 420):
        bad.append("lounge 交互点挪了：%s" % pts["lounge"])
    if bad:
        raise SystemExit("layout.json 跟这版对不上：\n" + "\n".join(bad))
    return d


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
    """地板 v3（阿鱼 10/3：01 版太细、06 第二版像酱油）：宽板蜜色木，三间共用 backhall_floor.py"""
    draw_floor_v3(L, WALL_W[0], WALL_E[1], Y1, seed=1)


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


def draw_rug(L, rect=(470, 250, 658, 342), style="red", medallion=True, bw=12):
    """回纹地毯（01 版那种）：底 + 菱形格 + 中间团花 + 四边金色带上一圈红回纹 + 两头流苏。
    style：red（红底，01 原样）/ cream（米色底红格）/ navy（藏青底金格）；小地毯 bw 收窄"""
    rx0, ry0, rx1, ry1 = rect
    base, grid, dot, m1, m2, m3 = {
        "red": ("rd3", "rd2", "gd2", "rd2", "rd4", "rd3"),
        "cream": ("wl3", "wl2", "rd3", "wl2", "wl4", "wl3"),
        "navy": ("bl1", "bl0", "gd2", "bl0", "bl2", "bl1"),
    }[style]
    L.rect(rx0, ry0, rx1, ry1, base)
    # 地毯纹：菱形格
    for y in range(ry0 + bw + 1, ry1 - bw - 1):
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
        L.ell(cx - sx // 2, cy - sy // 2, cx + sx // 2, cy + sy // 2, m3)
        L.ring(cx - sx // 2, cy - sy // 2, cx + sx // 2, cy + sy // 2, "gd2")
    # 边：金色带 + 红回纹
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


KNOTS = [498, 550, 598, 642]     # 红绸的结（唱片墙东边到挂钟西边）


def draw_swag(L):
    """北墙上沿一段红绸（跟化妆间、宴会厅一个做法）：两个结之间垂一个弧，弧里几道褶，结上一朵金花、垂一束金穗。
    唱片墙那一段被唱片墙挡住，只挂东边三段；弧压浅一点，不碰下面的画和挂钟"""
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
        ln = 6 if kx in (KNOTS[0], KNOTS[-1]) else 8
        for yy in range(121, 121 + ln):
            L.p(cx - 1, yy, "gd2")
            L.p(cx, yy, "gd3")
            L.p(cx + 1, yy, "gd1")
        L.hl(cx - 1, cx + 2, 121 + ln, "rd3")
        L.p(cx, 122 + ln, "rd2")


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
            L.p(x, y, ramp[max(0, min(len(ramp) - 1, lv + k))] if isinstance(ramp, list) else rname(ramp, lv + k))


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


# ================================================================== 第三版新加的家具
def moved(L, dx, dy):
    """把一层整体挪 dx, dy（先裁到有东西的框）"""
    bb = L.im.getbbox()
    N = Layer(x0=L.ox + bb[0] + dx, y0=L.oy + bb[1] + dy, w=bb[2] - bb[0], h=bb[3] - bb[1])
    N.im = L.im.crop(bb)
    N.px = N.im.load()
    return N


def recolor(L, mapping):
    """整层换色：mapping 是 {原色名: 新色名}"""
    m = {C[a]: C[b] for a, b in mapping.items()}
    for y in range(L.h):
        for x in range(L.w):
            c = L.px[x, y]
            if c[3] and c in m:
                L.px[x, y] = m[c]
    return L


BLUE = ["ik1", "bl0", "bl1", "bl1", "bl2", "bl3"]      # 蓝丝绒（样板看书角用过，阿鱼 10/3 换成米白 wl，现在没用上）
LEGS = {"wd": ("wd1", "wd3", "wd5", "wd3"), "gd": ("gd1", "gd3", "gd4", "gd2"), "ik": ("ik0", "ik2", "ik3", "wd2")}


def side_sofa(rect, facing, seats, ramp="wl", legs="wd", pillows=(), tufted=False, throw=None, scroll=True):
    """侧着放的沙发（照 01 版单人沙发的画法推广到几人位）：facing="e" 靠背在西、朝东；"w" 靠背在东、朝西。
    从南边看是它的侧面：北扶手顶面和朝南的里侧、坐垫顶面（一人一块）、靠背顶面（长条）、靠背上的靠垫、
    南扶手顶面和朝镜头的外侧大板（卷边扶手头）、木底座和脚。光照不跟着左右翻：都是左边亮、右边暗。
    pillows：[(在第几人位, 色带, 花样)]；tufted：拉扣（皮沙发）；throw：搭在南扶手上的毯子色带"""
    L = Layer()
    x0, y0, x1, y1 = rect
    if isinstance(ramp, list):
        F = lambda i: ramp[max(0, min(len(ramp) - 1, i))]
    else:
        F = lambda i: rname(ramp, i)
    e = facing == "e"
    if e:
        bx0, bx1, ax0, ax1, sx0, sx1 = x0, x0 + 11, x0 + 9, x1, x0 + 11, x1 - 2
    else:
        bx0, bx1, ax0, ax1, sx0, sx1 = x1 - 11, x1, x0, x1 - 9, x0 + 2, x1 - 11
    bt0, bt1 = y0 - 42, y1 - 40          # 靠背顶面
    na0, na1, ni1 = y0 - 29, y0 - 23, y0 - 15
    st0, st1 = y0 - 15, y1 - 32          # 坐垫顶面
    sa0, sa1, so1 = y1 - 33, y1 - 27, y1 - 7
    # 1) 北扶手：顶面 + 朝南的里侧（阴影里）
    L.rect(ax0, na0, ax1, na1, F(4))
    L.hl(ax0 + 1, ax1 - 1, na0, F(5))
    L.vl(ax0, na0 + 1, na1, F(5))
    L.rect(ax0, na1, ax1, ni1, F(1))
    L.hl(ax0, ax1, na1, F(2))
    L.hl(ax0, ax1, ni1 - 1, F(0))
    # 2) 坐垫：一人一块，块之间一道缝
    seg = [st0 + round((st1 - st0) * k / seats) for k in range(seats + 1)]
    for k in range(seats):
        a, b = seg[k], seg[k + 1]
        puff(L, sx0, a, sx1, b, ramp, 4, cuts=(0.7, 0.05, -0.45))
        L.hl(sx0, sx1, a, F(3) if k == 0 else F(1))
        if k > 0:
            L.hl(sx0 + 1, sx1 - 1, a + 1, F(5))
        L.hl(sx0, sx1, b - 1, F(2))
    fe = sx1 - 1 if e else sx0           # 坐垫朝外那条边（滚边）
    L.vl(fe, st0, st1, F(5) if not e else F(3))
    L.vl(sx0 if e else sx1 - 1, st0, st1, F(2))          # 跟靠背接的折痕
    # 3) 靠背：顶面长条（两头圆）
    L.rect(bx0, bt0 + 1, bx1, bt1, F(4))
    L.hl(bx0 + 1, bx1 - 1, bt0, F(5))
    L.vl(bx0, bt0 + 2, bt1, F(5))
    L.vl(bx0 + 1, bt0 + 1, bt1, F(5))
    L.vl(bx1 - 1, bt0 + 2, bt1, F(2))
    L.vl(bx1 - 2, bt0 + 2, bt1, F(3))
    L.p(bx0, bt0 + 1, F(3))
    L.p(bx1 - 1, bt0 + 1, F(2))
    if tufted:
        for yy in range(bt0 + 5, bt1 - 2, 6):
            for xx in ((bx0 + 3, bx0 + 7) if ((yy - bt0) // 6) % 2 else (bx0 + 5,)):
                L.p(xx, yy, F(1))
                L.p(xx - 1, yy - 1, F(5))
    # 4) 靠在靠背上的靠垫（每人一块，鼓起来，下沿一道暗缝）
    cx0, cx1 = (bx1 - 1, bx1 + 7) if e else (bx0 - 7, bx0 + 1)
    for k in range(seats):
        a, b = seg[k], seg[k + 1]
        ya, yb = a - 9 + (2 if k == 0 else 0), b - 1
        puff(L, cx0, ya, cx1, yb, ramp, 3)
        L.hl(cx0, cx1, ya, F(4))
        L.vl(cx1 - 1, ya, yb, F(1))
        L.hl(cx0, cx1, yb - 1, F(1))
        if tufted:
            L.p((cx0 + cx1) // 2, (ya + yb) // 2, F(0))
    # 5) 抱枕
    for (k, pr, pat) in pillows:
        a, b = seg[k], seg[k + 1]
        py = a - 11 if k == 0 else (b - 21 if k == seats - 1 else (a + b) // 2 - 13)
        px_ = cx1 - 2 if e else cx0 - 8
        pillow(L, px_, py, 10, 15, pr, pat)
    # 6) 靠背朝南那一面
    puff(L, bx0, bt1, bx1, so1, ramp, 2)
    L.hl(bx0, bx1, bt1, F(4))
    L.hl(bx0, bx1, bt1 + 1, F(3))
    L.vl(bx1 - 1, bt1 + 1, so1, F(1))
    L.vl(bx1 if e else bx0 - 1, na0 + 1, so1, F(0))          # 靠背跟扶手中间一道缝
    # 7) 南扶手：顶面 + 朝镜头的外侧大板
    L.rect(ax0, sa0, ax1, sa1, F(4))
    L.hl(ax0 + 1, ax1 - 1, sa0, F(5))
    L.vl(ax0, sa0 + 1, sa1, F(5))
    L.hl(ax0, ax1, sa1 - 1, F(3))
    puff(L, ax0, sa1, ax1, so1, ramp, 2)
    L.hl(ax0, ax1, sa1, F(4))
    L.hl(ax0, ax1, sa1 + 1, F(3))
    L.hl(ax0, ax1, so1 - 1, F(1))
    L.vl(ax1 - 1, sa1, so1, F(1))
    for yy in range(sa1 + 3, so1 - 2):
        L.p((ax0 + ax1) // 2 + (2 if e else -2), yy, F(1))
    if tufted:
        for yy in range(sa1 + 5, so1 - 3, 6):
            for xx in range(ax0 + 4 + (3 if ((yy - sa1) // 6) % 2 else 0), ax1 - 3, 6):
                L.p(xx, yy, F(1))
                L.p(xx - 1, yy - 1, F(5))
    if scroll:                                         # 扶手头往里卷的一道（朝外那头）
        scx = ax1 - 6 if e else ax0 + 6
        L.ell(scx - 6, sa0, scx + 6, sa0 + 12, F(4))
        L.hl(scx - 4, scx + 4, sa0, F(5))
        L.ring(scx - 6, sa0, scx + 6, sa0 + 12, F(1), only=lambda x, y: y > sa0 + 6)
        L.ring(scx - 3, sa0 + 3, scx + 3, sa0 + 9, F(1),
               only=lambda x, y: (x < scx + 1 if e else x > scx - 1) or y > sa0 + 6)
        L.p(scx, sa0 + 6, F(2))
    if throw:                                          # 南扶手上搭一条毯子（格子、下摆穗）
        tx0, tx1 = (ax0 + 4, ax0 + 16) if e else (ax1 - 16, ax1 - 4)
        L.rect(tx0, sa0 - 1, tx1, so1 + 3, rname(throw, 3))
        L.vl(tx0, sa0 - 1, so1 + 3, rname(throw, 4))
        L.vl(tx1 - 1, sa0, so1 + 3, rname(throw, 2))
        L.hl(tx0, tx1, sa1, rname(throw, 2))
        L.hl(tx0, tx1, sa1 - 1, rname(throw, 4))
        for yy in range(sa1 + 3, so1 + 2, 5):
            L.hl(tx0 + 1, tx1 - 1, yy, "wl4")
        for xx in (tx0 + 4, tx0 + 8):
            L.vl(xx, sa0, so1 + 3, "wl4")
        for xx in range(tx0, tx1):
            L.p(xx, so1 + 3 + (xx % 2), "wl3")
    # 8) 底座、脚
    l0, l1, l2, lb = LEGS[legs]
    L.rect(x0, so1, x1, so1 + 3, l1)
    L.hl(x0, x1, so1, l2)
    L.hl(x0, x1, so1 + 2, l0)
    for lx in (x0 + 1, x1 - 4):
        L.rect(lx, so1 + 3, lx + 3, y1, l0)
        L.p(lx, so1 + 3, l1)
    L.outline()
    return L, y1


def prop_record_crate():
    """唱片箱（替掉原来那只蓝箱子）：一只敞口木箱，里面竖着一排唱片（从上面看是一条条封套顶边），
    最前面一张往上抽出一截露出封面；箱子正面是木条，中间一个提手孔"""
    L = Layer()
    x0, x1, yf0, yf1, h = 356, 386, 272, 290, 22
    ty0, ty1 = yf0 - h, yf1 - h          # 250..268
    L.rect(x0, ty0, x1, ty1, "wd1")
    cols = ["rd3", "gd3", "bl2", "wl4", "tl", "pk", "or", "ik2", "gr2", "rd4", "bl3", "wl5", "pu", "gd2"]
    for k, yy in enumerate(range(ty0 + 2, ty1 - 1, 2)):
        c = cols[(k * 5) % len(cols)]
        L.hl(x0 + 2, x1 - 2, yy, c)
        L.p(x0 + 2, yy, shift(c, 1))
        L.p(x1 - 3, yy, shift(c, -1))
        L.hl(x0 + 2, x1 - 2, yy + 1, "wd0")
    # 最前面一张抽出来一截：封面
    T = Layer(x0=x0 + 5, y0=ty1 - 9, w=18, h=10)
    _sleeve_art(T, x0 + 5, ty1 - 9, 0)
    L.paste(T)
    L.vl(x0 + 23, ty1 - 9, ty1, "ol")
    # 箱沿
    L.rect(x0, ty0, x1, ty0 + 1, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    # 正面：三条木板、提手孔
    L.rect(x0, ty1, x1, yf1, "wd3")
    L.hl(x0, x1, ty1, "wd5")
    for yy in (ty1 + 7, ty1 + 14):
        L.hl(x0, x1, yy, "wd1")
        L.hl(x0, x1, yy + 1, "wd4")
    L.rect((x0 + x1) // 2 - 4, ty1 + 3, (x0 + x1) // 2 + 4, ty1 + 5, "wd0")
    L.vl(x0, ty1, yf1, "wd4")
    L.vl(x1 - 1, ty1, yf1, "wd1")
    L.hl(x0, x1, yf1 - 1, "wd1")
    L.outline()
    return L, yf1


BOOK_COLS = ["rd2", "rd3", "bl1", "bl2", "gr1", "gr2", "gd2", "wl4", "pu", "tl", "cl1", "cl2", "ik2", "wl3", "rd4", "bl3"]


def book_row(L, xa, xb, base, hmax, rnd, objects=True):
    """一层书：一本本竖着（宽 2～3、高不一），偶尔一本斜靠、一摞平放、一件小摆设"""
    x = xa
    while x < xb:
        r = rnd.random()
        if objects and r < 0.07 and xb - x >= 7:         # 小摆设：白瓷瓶插红花 / 小相框 / 地球仪
            kind = rnd.choice(["vase", "frame", "globe"])
            if kind == "vase":
                L.rect(x + 1, base - 6, x + 5, base, "wt")
                L.vl(x + 4, base - 6, base, "bl4")
                L.hl(x + 1, x + 5, base - 3, "bl2")
                L.p(x + 2, base - 8, "rd4")
                L.p(x + 3, base - 9, "rd3")
                L.p(x + 3, base - 7, "gr2")
            elif kind == "frame":
                L.rect(x, base - 7, x + 6, base, "gd2")
                L.rect(x + 1, base - 6, x + 5, base - 1, "bl3")
                L.p(x + 2, base - 3, "gr2")
                L.p(x + 3, base - 4, "gr3")
                L.hl(x, x + 6, base - 7, "gd4")
            else:
                L.ell(x, base - 8, x + 6, base - 2, "bl2")
                L.p(x + 2, base - 6, "gr3")
                L.p(x + 3, base - 5, "gr2")
                L.p(x + 1, base - 7, "bl4")
                L.rect(x + 2, base - 2, x + 4, base, "gd2")
            x += 7
            continue
        if r < 0.15 and xb - x >= 7:                     # 一摞平放
            w = min(rnd.randrange(6, 9), xb - x)
            yy = base
            for k in range(rnd.randrange(2, 4)):
                c = rnd.choice(BOOK_COLS)
                L.rect(x, yy - 2, x + w - (k % 2), yy, c)
                L.hl(x, x + w - (k % 2), yy - 2, shift(c, 1))
                L.p(x + w - 1 - (k % 2), yy - 1, "wl4")
                yy -= 2
            x += w + 1
            continue
        w = min(rnd.choice([2, 2, 3, 3, 3]), xb - x)
        hgt = rnd.randrange(hmax - 4, hmax + 1)
        c = rnd.choice(BOOK_COLS)
        if r > 0.93 and x + w + 3 <= xb:                  # 斜靠的一本
            for k in range(hgt):
                xx = x + (k * 3) // hgt
                L.rect(xx, base - k - 1, xx + w, base - k, c)
            L.p(x + 2, base - hgt, shift(c, 1))
            x += w + 3
            continue
        L.rect(x, base - hgt, x + w, base, c)
        L.vl(x, base - hgt, base, shift(c, 1))
        L.hl(x, x + w, base - hgt, shift(c, -1))
        if rnd.random() < 0.5:                            # 书脊上一两道金线
            L.hl(x, x + w, base - hgt + 2, "gd3")
            if rnd.random() < 0.5:
                L.hl(x, x + w, base - 3, "gd2")
        x += w
        if rnd.random() < 0.12:
            x += 1


def prop_bookshelf(y0, y1, seed):
    """靠西墙的高书架（书朝东）。正交斜俯视里朝东那面是看不见的，这里照 06 v2.2 的做法把它「掰正」画：
    一条窄高的正面，五层，书一本本竖着；顶上一条顶板，底下踢脚。占地 x 342～362"""
    L = Layer()
    x0, x1 = 342, 362
    top, bot = y1 - 92, y1
    rnd = random.Random(seed)
    L.rect(x0, top, x1 + 1, top + 5, "wd4")
    L.hl(x0, x1 + 1, top, "wd5")
    L.hl(x0, x1 + 1, top + 3, "wd3")
    L.hl(x0, x1 + 1, top + 4, "wd1")
    L.rect(x0, top + 5, x1, bot, "wd2")
    L.vl(x0, top + 5, bot, "wd4")
    L.vl(x0 + 1, top + 5, bot, "wd3")
    L.vl(x1 - 1, top + 5, bot, "wd1")
    L.rect(x0 + 2, top + 6, x1 - 2, bot - 6, "wd0")
    rows = 5
    pitch = (bot - 6 - (top + 6)) / rows
    for r in range(rows):
        ra = int(top + 6 + r * pitch)
        rb = int(top + 6 + (r + 1) * pitch) - 2
        L.hl(x0 + 2, x1 - 2, ra, "ol")
        book_row(L, x0 + 2, x1 - 2, rb, rb - ra - 3, rnd)
        L.rect(x0 + 2, rb, x1 - 2, rb + 2, "wd3")
        L.hl(x0 + 2, x1 - 2, rb, "wd5")
        L.hl(x0 + 2, x1 - 2, rb + 1, "wd2")
    L.rect(x0, bot - 6, x1, bot, "wd2")
    L.hl(x0, x1, bot - 6, "wd4")
    L.hl(x0, x1, bot - 1, "wd1")
    L.outline()
    return L, bot


def prop_lamp_at(cx, foot, shade=None):
    """落地灯（01 版那盏）挪到别处；shade 给了就把布罩换成那条色带"""
    L, _ = prop_floor_lamp()
    if shade:
        recolor(L, {"wl3": rname(shade, 3), "wl4": rname(shade, 4), "wl5": rname(shade, 5)})
    return moved(L, cx - 629, foot - 260), foot


def gala_px(u, v, U, V, conf):
    """电视屏幕里的晚会（u 0..U、v 0..V）：两边红幕、上面红幕檐和金穗、紫色舞台背景、
    正中一个金圈红心的大团花、两束金色追光、台上三个小小的表演者、满屏彩纸、台口红地板、
    最下面一排观众的头、一条播到一半的进度条。返回颜色名"""
    cx = U / 2.0
    if v >= V - 2:                                     # 进度条
        if v == V - 1:
            return "ik1"
        return "gd3" if u < U * 0.56 else "ik3"
    if v >= V - 6:                                     # 观众的头
        top = V - 6 + (0 if (u % 5) in (1, 2, 3) else 1)
        return "ik0" if v >= top else "rd1"
    stage = V - 14
    if v >= stage:                                     # 台口
        if v == stage:
            return "gd3"
        if v == stage + 1:
            return "gd1"
        if abs(u - cx) < 9 - (v - stage) * 0.3 and v < stage + 5:
            return "rd4"
        return "rd2" if (u + v) % 7 else "rd1"
    cw = 5
    if u < cw or u >= U - cw:                          # 两边红幕
        k = u if u < cw else U - 1 - u
        if k == cw - 1:
            return "rd1"
        return "rd4" if k % 2 == 0 else "rd3"
    if v < 3:                                          # 幕檐
        return "rd3" if v < 2 else ("gd3" if u % 3 else "rd2")
    if v == 3 and u % 6 in (2, 3):
        return "rd3"
    if v == 4 and u % 6 == 2:
        return "gd4"
    for (fx, body) in ((cx - 7, "rd4"), (cx, "wt"), (cx + 7, "rd4")):     # 三个小小的表演者
        dx = u - fx
        if -0.5 <= dx < 1.5 and stage - 9 <= v < stage - 7:
            return "wl3"
        if -1.5 <= dx < 2.5 and stage - 7 <= v < stage:
            w = 1 + (v - (stage - 7)) * 0.35
            if abs(dx - 0.5) <= w:
                return body
    if ((u - cx) / 9.5) ** 2 + ((v - (stage - 1)) / 2.2) ** 2 <= 1:    # 台上一圈追光
        return "gd4" if (u + v) % 2 else "gd3"
    dcx, dcy = u - cx + 0.5, v - 13                    # 正中团花
    d = math.hypot(dcx, dcy * 1.05)
    if d <= 8.5:
        if d >= 7.2:
            return "gd3"
        if d >= 6.2:
            return "gd1"
        if d <= 1.4:
            return "gd4"
        ang = math.atan2(dcy, dcx)
        if 2.5 < d < 5.5 and math.cos(ang * 8) > 0.55:
            return "rd5"
        return "rd3"
    for sx in (cw + 1, U - cw - 2):                    # 两束追光（点状）
        t = (v - 4) / float(stage - 4)
        if 0 <= t <= 1:
            bx = sx + (cx - sx) * t
            half = 1.2 + 3.5 * t
            if abs(u - bx) <= half and (u + v) % 2 == 0:
                return "gd4"
    c = conf.get((u, v))                               # 彩纸
    if c:
        return c
    if v < 9 and bayer(u, v) > (v - 3) / 6.0:
        return "bl0"
    return "pu" if (v < stage - 3 or bayer(u, v) > 0.3) else "bl1"


def prop_tv3():
    """电视柜连大电视、游戏机（东墙边）：矮木柜顺着墙放（抽屉、两扇小门、铜拉手）；
    大电视侧着朝西南、往屋里转（跟 01 版一样的斜面画法，放大），屏幕亮着在播晚会；
    柜上南头立着一台白色游戏机（中间黑芯、两边白翼，不画任何标志），一根线连到电视"""
    L = Layer()
    x0, x1, yf0, yf1, h = 638, 664, 360, 450, 24
    ty0, ty1 = yf0 - h, yf1 - h          # 336..426
    L.rect(x0, ty0, x1, ty1, "wd4")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x0, ty0, ty1, "wd5")
    L.vl(x1 - 1, ty0 + 1, ty1, "wd3")
    for gx, gy0, gy1 in ((643, 340, 356), (649, 362, 380), (655, 344, 352), (646, 392, 410), (657, 386, 398)):
        L.vl(gx, gy0, gy1, "wd3")
    L.hl(x0, x1, ty1 - 1, "wd3")
    L.rect(x0, ty1, x1, yf1 - 3, "wd3")
    L.hl(x0, x1, ty1, "wd5")
    L.vl(x0, ty1, yf1 - 3, "wd4")
    L.vl(x1 - 1, ty1, yf1 - 3, "wd2")
    mx = (x0 + x1) // 2
    L.rect(x0 + 2, ty1 + 3, x1 - 2, ty1 + 9, "wd2")
    L.rect(x0 + 3, ty1 + 4, x1 - 3, ty1 + 8, "wd3")
    L.hl(x0 + 3, x1 - 3, ty1 + 4, "wd4")
    L.rect(mx - 2, ty1 + 5, mx + 2, ty1 + 7, "gd3")
    L.p(mx - 2, ty1 + 5, "gd4")
    for (a, b) in ((x0 + 2, mx), (mx + 1, x1 - 2)):
        L.rect(a, ty1 + 11, b, yf1 - 5, "wd2")
        L.rect(a + 1, ty1 + 12, b - 1, yf1 - 6, "wd3")
        L.hl(a + 1, b - 1, ty1 + 12, "wd4")
    L.p(mx - 2, ty1 + 15, "gd3")
    L.p(mx + 2, ty1 + 15, "gd3")
    L.rect(x0, yf1 - 3, x1, yf1, "wd1")
    L.rect(x0 + 2, yf1 - 3, x1 - 2, yf1 - 1, "wd2")
    # 柜上北头一盆白瓷小多肉
    L.rect(646, 340, 653, 346, "wt")
    L.vl(652, 341, 346, "bl4")
    L.hl(646, 653, 345, "bl4")
    L.hl(646, 653, 342, "bl3")
    for (a, b, c) in ((646, 337, "gr2"), (648, 335, "gr3"), (650, 336, "gr4"), (651, 338, "gr2"), (647, 338, "gr3"),
                      (649, 337, "gr3")):
        L.rect(a, b, a + 2, b + 2, c)
    # ---- 大电视：斜着的屏幕面（左上高、右下低），右边一条机身厚度，细脖子和底板
    PL, PR, TOP, SL, HT = 612, 658, 322, 14, 52

    def ytop(x):
        return TOP + int(round((x - PL) * SL / float(PR - PL)))
    L.rect(643, 372, 647, 384, "ik2")
    L.vl(643, 372, 384, "ik3")
    L.rect(636, 383, 656, 386, "ik2")
    L.hl(636, 656, 383, "ik3")
    L.hl(636, 656, 385, "ik1")
    for x in range(PL, PR):
        yt = ytop(x)
        L.vl(x, yt, yt + HT, "ik0")
    for x in range(PR, PR + 4):
        yt = ytop(PR) - (x - PR) - 1
        L.vl(x, yt + 1, yt + HT + 1, "ik2" if x < PR + 3 else "ik1")
    L.vl(PR, ytop(PR) - 1, ytop(PR) + HT, "ik3")
    U, V = PR - PL - 5, HT - 6
    rnd = random.Random(88)
    conf = {}
    for _ in range(70):
        u, v = rnd.randrange(5, U - 5), rnd.randrange(5, V - 16)
        c = rnd.choice(["rd4", "gd4", "pk", "tl2", "bl3", "wt", "gd3", "or"])
        conf[(u, v)] = c
        if rnd.random() < 0.4:
            conf[(u + 1, v + 1)] = c
    for u in range(U):
        for v in range(V):
            x = PL + 2 + u
            L.p(x, ytop(x) + 3 + v, gala_px(u, v, U, V, conf))
    for k in range(10):                                # 屏幕玻璃一道很淡的斜反光
        x = PL + 4 + k
        y = ytop(x) + 4 + k * 2
        for yy in (y, y + 1):
            c = L.g(x, yy)
            if c in (C["pu"], C["bl0"], C["bl1"]):
                L.p(x, yy, "bl2" if c != C["pu"] else "bl1")
    for x in range(PL, PR):
        L.p(x, ytop(x), "ik3")
    L.vl(PL, ytop(PL), ytop(PL) + HT, "ik2")
    for x in range(PL + 1, PR):
        L.p(x, ytop(x) + HT - 1, "ik2")
    # ---- 游戏机：白色立式（像 PS5 那样两片白翼夹着黑芯，翼比芯高、上沿往外翘、腰往里收），
    #      芯和左翼之间一道蓝灯，底下黑色小底座。不画任何标志、字母
    gx0, gb = 645, 417                                 # 左边、底（柜面上 y 441 的地方）
    gh = 26
    prof = [1, 1, 1, 0, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0]  # 外沿往外(+)/往里(-)
    for k in range(gh):
        y = gb - gh + k
        o = prof[k]
        L.hl(gx0 + 1 - o, gx0 + 6, y, "wt")            # 左翼（受光）
        L.p(gx0 + 1 - o, y, "sv2" if k > 2 else "wt")
        L.hl(gx0 + 10, gx0 + 15 + o, y, "sv2")         # 右翼（背光）
        L.p(gx0 + 14 + o, y, "sv1")
        if k >= 4:
            L.hl(gx0 + 6, gx0 + 10, y, "ik1")          # 黑芯（比翼矮一截）
            L.p(gx0 + 6, y, "bl3" if 6 <= k <= 20 else "ik2")    # 蓝灯
    L.hl(gx0, gx0 + 6, gb - gh, "wt")
    L.hl(gx0 + 10, gx0 + 16, gb - gh, "sv1")
    L.hl(gx0 + 7, gx0 + 10, gb - gh + 4, "ik2")
    L.p(gx0 + 6, gb - gh + 6, "bl4")
    L.rect(gx0 + 3, gb, gx0 + 13, gb + 2, "ik1")     # 底座
    L.hl(gx0 + 4, gx0 + 12, gb, "ik2")
    L.outline()
    return L, yf1


def controller(L, x, y):
    """手柄（白色、两边握把、中间黑色触控板，没有标志和字）：11×7，自带一圈深边"""
    L.rect(x + 1, y + 1, x + 10, y + 4, "wt")
    L.rect(x, y + 2, x + 3, y + 6, "wt")
    L.rect(x + 8, y + 2, x + 11, y + 6, "sv2")
    L.rect(x + 4, y + 1, x + 7, y + 3, "ik1")
    L.p(x + 2, y + 2, "ik2")
    L.p(x + 9, y + 2, "ik2")
    L.p(x + 4, y + 4, "ik2")
    L.p(x + 6, y + 4, "ik2")
    L.hl(x + 1, x + 10, y, "ol")
    L.vl(x - 1, y + 2, y + 6, "ol")
    L.vl(x + 11, y + 2, y + 6, "ol")
    L.hl(x, x + 3, y + 6, "ol")
    L.hl(x + 8, x + 11, y + 6, "ol")
    L.hl(x + 3, x + 8, y + 5, "ol")
    L.p(x, y + 1, "ol")
    L.p(x + 10, y + 1, "ol")


def prop_tv_table():
    """电视前的长茶几（低）：深木，桌面上两个手柄、一碗喜糖；下层一摞游戏盒"""
    L = Layer()
    x0, x1, yf0, yf1, h = 598, 620, 398, 438, 18
    ty0, ty1 = yf0 - h, yf1 - h          # 380..420
    L.rect(x0, ty0, x1, ty1, "wd2")
    L.rect(x0 + 1, ty0 + 1, x1 - 1, ty1 - 1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    for k in range(5):
        L.hl(x0 + 3 + k, x0 + 6 + k, ty0 + 20 + k * 2, "wd4")
    L.rect(x0, ty1, x1, ty1 + 4, "wd2")
    L.hl(x0, x1, ty1, "wd5")
    L.hl(x0, x1, ty1 + 3, "wd1")
    L.rect(x0 + 3, ty1 + 4, x1 - 3, yf1 - 4, "wd0")
    for k, c in enumerate(("bl2", "rd3", "wt", "gr2")):
        L.rect(x0 + 5 + k * 3, yf1 - 9, x0 + 7 + k * 3, yf1 - 4, c)
    L.rect(x0 + 3, yf1 - 4, x1 - 3, yf1 - 3, "wd3")
    for lx in (x0, x1 - 3):
        L.rect(lx, ty1 + 4, lx + 3, yf1, "wd2")
        L.vl(lx, ty1 + 4, yf1, "wd3")
    controller(L, x0 + 6, ty0 + 3)
    controller(L, x0 + 4, ty0 + 13)
    L.ell(x0 + 4, ty0 + 26, x0 + 16, ty0 + 34, "rd1")            # 喜糖碗
    L.ell(x0 + 5, ty0 + 26, x0 + 15, ty0 + 32, "rd3")
    for (a, b, c) in ((7, 28, "gd4"), (9, 29, "rd5"), (11, 28, "wt"), (12, 30, "gd3"), (8, 30, "pk")):
        L.p(x0 + a, ty0 + b, c)
    L.hl(x0 + 6, x0 + 14, ty0 + 33, "wd1")
    L.outline()
    return L, yf1


def prop_book_table():
    """看书的矮桌：桌面上一摞书、一本摊开的书（红丝带书签）、一只青花盖碗；下层塞几本杂志"""
    L = Layer()
    x0, x1, yf0, yf1, h = 394, 420, 524, 564, 20
    ty0, ty1 = yf0 - h, yf1 - h          # 504..544
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    for gx, a, b in ((400, 508, 522), (407, 526, 540), (414, 506, 516)):
        L.vl(gx, a, b, "wd2")
    L.rect(x0, ty1, x1, ty1 + 4, "wd2")
    L.hl(x0, x1, ty1, "wd5")
    L.hl(x0, x1, ty1 + 3, "wd1")
    L.rect(x0 + 3, ty1 + 4, x1 - 3, yf1 - 4, "wd0")
    for k, c in enumerate(("rd3", "wl4", "bl2", "gd2", "wl4")):
        L.hl(x0 + 4, x1 - 5 - (k % 2) * 2, yf1 - 5 - k, c)
    L.rect(x0 + 3, yf1 - 4, x1 - 3, yf1 - 3, "wd3")
    for lx in (x0, x1 - 3):
        L.rect(lx, ty1 + 4, lx + 3, yf1, "wd2")
        L.vl(lx, ty1 + 4, yf1, "wd3")
    yy = ty0 + 12
    for k, (c, w) in enumerate((("bl1", 13), ("rd2", 12), ("gr1", 11))):
        xa = x0 + 3 + k
        L.rect(xa, yy - 3, xa + w, yy, c)
        L.hl(xa, xa + w, yy - 3, shift(c, 1))
        L.vl(xa + w - 1, yy - 2, yy, "wl4")
        L.hl(xa, xa + w, yy, shift(c, -1))
        yy -= 3
    bx, by = x0 + 5, ty0 + 20
    L.rect(bx, by, bx + 16, by + 10, "wl5")
    L.vl(bx + 8, by, by + 10, "wl1")
    L.hl(bx, bx + 16, by + 10, "wl1")
    for k in range(4):
        L.hl(bx + 2, bx + 7, by + 2 + k * 2, "wl2")
        L.hl(bx + 10, bx + 15, by + 2 + k * 2, "wl2")
    L.vl(bx + 11, by - 1, by + 5, "rd3")
    gaiwan(L, x0 + 14, ty0 + 6)
    L.outline()
    return L, yf1


def round_table(cx, foot, top_w=22, top_d=15, h=24, top_ramp="wd", item=None):
    """圆边几：圆桌面（厚 2）、一根车木柱、圆底座。item：桌上放什么"""
    L = Layer()
    x0, x1 = cx - top_w // 2, cx + top_w - top_w // 2
    ty = foot - top_d - h                # 桌面椭圆上沿
    L.rect(cx - 1, ty + top_d, cx + 2, foot - 2, "wd2")
    L.vl(cx - 1, ty + top_d, foot - 2, "wd4")
    L.ell(cx - 8, foot - 5, cx + 9, foot, "wd1")
    L.ell(cx - 7, foot - 5, cx + 8, foot - 1, "wd3")
    L.ell(x0, ty + 2, x1, ty + top_d + 2, rname(top_ramp, 1))
    L.ell(x0, ty, x1, ty + top_d, rname(top_ramp, 3))
    L.ring(x0, ty, x1, ty + top_d, rname(top_ramp, 4), only=lambda x, y: y < ty + top_d / 2 and x < cx + 4)
    L.ell(x0 + 4, ty + 2, x0 + 10, ty + 5, rname(top_ramp, 4))
    if item == "flowers":                              # 青花小瓶插几枝红花
        vx, vy = cx - 3, ty + top_d // 2
        L.rect(vx, vy - 8, vx + 6, vy, "wt")
        L.vl(vx + 5, vy - 8, vy, "bl4")
        L.hl(vx, vx + 6, vy - 4, "bl2")
        L.hl(vx + 1, vx + 5, vy - 9, "wt")
        for (a, b, c) in ((-2, -13, "rd4"), (1, -15, "rd3"), (4, -13, "rd4"), (6, -11, "pk"), (-3, -10, "rd3"),
                          (2, -12, "rd5")):
            L.rect(vx + a, vy + b, vx + a + 2, vy + b + 2, c)
        for (a, b) in ((0, -10), (3, -11), (5, -9)):
            L.p(vx + a, vy + b, "gr2")
    elif item == "lamp":                               # 小台灯 + 两本杂志
        lx, ly = cx - 2, ty + top_d // 2
        L.rect(x0 + 3, ly - 1, x0 + 11, ly + 3, "rd3")
        L.hl(x0 + 3, x0 + 11, ly - 1, "rd4")
        L.rect(x0 + 5, ly + 1, x0 + 12, ly + 4, "bl2")
        L.hl(x0 + 5, x0 + 12, ly + 1, "bl3")
        L.rect(lx + 3, ly - 12, lx + 5, ly, "gd2")
        L.poly([(lx, ly - 22), (lx + 8, ly - 22), (lx + 11, ly - 13), (lx - 3, ly - 13)], "wl4")
        L.hl(lx - 3, lx + 11, ly - 13, "gd3")
        L.vl(lx - 2, ly - 20, ly - 13, "wl5")
        L.vl(lx + 9, ly - 20, ly - 13, "wl3")
        L.ell(lx + 1, ly - 3, lx + 8, ly + 1, "gd2")
    elif item == "go":                                 # 围棋盘（浅木、格线、2×2 的黑白子）、两只棋罐
        bx0, by0 = cx - 9, ty + 3
        L.rect(bx0 - 1, by0 - 1, bx0 + 18, by0 + 12, "gd1")
        L.rect(bx0, by0, bx0 + 17, by0 + 11, "gd3")
        L.hl(bx0, bx0 + 17, by0, "gd4")
        L.hl(bx0 - 1, bx0 + 18, by0 + 12, "wd0")
        for k in range(1, 17, 4):
            L.vl(bx0 + k, by0 + 1, by0 + 11, "gd2")
        for k in range(2, 11, 3):
            L.hl(bx0 + 1, bx0 + 17, by0 + k, "gd2")
        for (a, b, c) in ((4, 1, "ik1"), (8, 4, "wt"), (12, 1, "ik1"), (4, 7, "wt"), (8, 7, "ik1"), (12, 4, "wt"),
                          (0, 4, "ik1"), (12, 7, "ik1")):
            L.rect(bx0 + a, by0 + b, bx0 + a + 2, by0 + b + 2, c)
            if c == "wt":
                L.p(bx0 + a + 1, by0 + b + 1, "sv2")
            else:
                L.p(bx0 + a, by0 + b, "ik3")
        for (qx, c, c2) in ((x0 - 1, "ik1", "ik3"), (x1 - 4, "wt", "sv2")):
            L.ell(qx, ty + 11, qx + 6, ty + 16, "wd1")
            L.ell(qx, ty + 10, qx + 6, ty + 14, c)
            L.p(qx + 2, ty + 11, c2)
    elif item == "tea":                                # 竹茶盘、青花小茶壶、一只盖碗（跟北边茶几一家，阿鱼 10/3 棋桌换成小茶几）
        mx0, my0 = cx - 10, ty + 5
        L.rect(mx0, my0, mx0 + 20, my0 + 8, "wd5")
        L.hl(mx0, mx0 + 20, my0, "wl3")
        L.hl(mx0, mx0 + 20, my0 + 7, "wd3")
        for xx in range(mx0 + 2, mx0 + 19, 3):
            L.vl(xx, my0 + 1, my0 + 7, "wd4")
        px0, py0 = mx0 + 1, my0 - 4                    # 小茶壶：圆肚子、盖钮、左边壶嘴、右边壶把
        L.hl(px0, px0 + 8, py0 + 8, "wd3")
        L.ell(px0, py0, px0 + 8, py0 + 8, "bl4")
        L.ell(px0, py0, px0 + 7, py0 + 7, "wt")
        L.hl(px0 + 1, px0 + 7, py0 + 4, "bl2")
        L.p(px0 + 2, py0 + 1, "wt")
        L.rect(px0 + 3, py0 - 2, px0 + 5, py0, "bl2")
        L.p(px0 - 1, py0 + 3, "wt")
        L.p(px0 - 2, py0 + 2, "wt")
        L.vl(px0 + 8, py0 + 2, py0 + 6, "bl3")
        L.hl(mx0 + 10, mx0 + 19, my0 + 6, "wd3")
        gaiwan(L, mx0 + 10, my0 - 1)
    elif item == "candy":                              # 一盘喜糖、一只盖碗
        L.ell(cx - 7, ty + 3, cx + 5, ty + 10, "rd2")
        L.ell(cx - 6, ty + 3, cx + 4, ty + 8, "rd3")
        for (a, b, c) in ((-4, 5, "gd4"), (-2, 6, "rd5"), (0, 5, "wt"), (1, 7, "gd3"), (-3, 7, "pk")):
            L.p(cx + a, ty + b, c)
        gaiwan(L, cx + 3, ty + 4)
    L.outline()
    return L, foot


def prop_bird_paradise():
    """东墙边落地大盆：天堂鸟（长柄大叶往上张开），白瓷盆金口沿"""
    L = Layer()
    cx, foot = 654, 506
    pot_top = foot - 20
    for (dx, top) in ((-9, 450), (-4, 440), (2, 444), (7, 452), (11, 462), (-12, 462)):
        L.line(cx, pot_top, cx + dx, top + 12, "gr1")
    leaves = [(cx - 12, 456, 20, -1.95, 9, 2), (cx + 11, 458, 20, -1.15, 9, 2), (cx - 4, 440, 22, -1.68, 10, 3),
              (cx + 7, 446, 20, -1.35, 9, 3), (cx - 9, 470, 18, -2.4, 8, 3), (cx + 12, 474, 17, -0.75, 8, 3),
              (cx + 2, 458, 18, -1.5, 9, 3)]
    for (lx, ly, ln, ang, wid, lv) in leaves:
        leaf(L, lx, ly, ln, ang, wid, lv)
        ca, sa = math.cos(ang), math.sin(ang)
        for t in range(-int(ln / 2) + 4, int(ln / 2) - 2, 3):
            px_, py_ = lx + ca * t, ly + sa * t
            L.p(px_ - sa * 2, py_ + ca * 2, rname("gr", lv - 1))
    L.poly([(cx + 3, 452), (cx + 12, 448), (cx + 10, 451)], "or")
    L.p(cx + 9, 449, "gd4")
    L.poly([(cx + 4, 452), (cx + 11, 453), (cx + 5, 454)], "bl2")
    for y in range(pot_top, foot):
        t = (y - pot_top) / float(foot - pot_top)
        half = 10 - 3 * t
        xa, xb = int(cx - half + 0.5), int(cx + half - 0.5)
        L.hl(xa, xb + 1, y, "wt")
        L.p(xb, y, "sv1")
        L.p(xb - 1, y, "sv2")
        L.p(xa, y, "sv2")
    L.ell(cx - 11, pot_top - 3, cx + 11, pot_top + 3, "gd3")
    L.ell(cx - 9, pot_top - 2, cx + 9, pot_top + 2, "wd1")
    L.hl(cx - 9, cx + 10, pot_top + 6, "gd2")
    L.hl(cx - 8, cx + 9, foot - 3, "gd2")
    L.outline()
    return L, foot


def prop_kumquat():
    """门口东边一盆金桔（喜庆）：圆圆一蓬小叶子、满树金黄的小桔子，红盆金边，盆上系一条红绸"""
    L = Layer()
    cx, foot = 650, 646
    pot_top = foot - 16
    rnd = random.Random(31)
    bcx, bcy, rx, ry = cx, pot_top - 22, 14, 18
    L.vl(cx, pot_top - 8, pot_top, "wd2")
    L.vl(cx + 1, pot_top - 6, pot_top, "wd1")
    L.ell(bcx - rx, bcy - ry, bcx + rx, bcy + ry, "gr1")
    for _ in range(140):
        a = rnd.random() * 2 * math.pi
        r = math.sqrt(rnd.random())
        x = bcx + math.cos(a) * r * (rx - 2)
        y = bcy + math.sin(a) * r * (ry - 2)
        lit = (x - bcx) + (y - bcy) < 2
        c = "gr3" if lit else "gr2"
        if (x - bcx) + (y - bcy) < -12:
            c = "gr4" if rnd.random() < 0.5 else "gr3"
        L.p(x, y, c)
        L.p(x + 1, y, c)
        L.p(x, y + 1, rname("gr", 1 if not lit else 2))
    L.ring(bcx - rx, bcy - ry, bcx + rx, bcy + ry, "gr0", only=lambda x, y: (x - bcx) + (y - bcy) > -4)
    for _ in range(19):
        a = rnd.random() * 2 * math.pi
        r = 0.25 + 0.7 * math.sqrt(rnd.random())
        x = int(bcx + math.cos(a) * r * (rx - 3))
        y = int(bcy + math.sin(a) * r * (ry - 3))
        L.rect(x, y, x + 3, y + 3, "or")
        L.p(x + 2, y + 2, "cl2")
        L.p(x, y, "gd4")
        L.p(x + 1, y, "gd3")
    for y in range(pot_top, foot):
        t = (y - pot_top) / float(foot - pot_top)
        half = 11 - 3 * t
        xa, xb = int(cx - half + 0.5), int(cx + half - 0.5)
        L.hl(xa, xb + 1, y, "rd3")
        L.p(xa, y, "rd4")
        L.p(xa + 1, y, "rd4")
        L.p(xb, y, "rd1")
        L.p(xb - 1, y, "rd2")
    L.ell(cx - 12, pot_top - 3, cx + 12, pot_top + 3, "gd3")
    L.ell(cx - 10, pot_top - 2, cx + 10, pot_top + 2, "wd1")
    L.hl(cx - 10, cx + 11, pot_top + 5, "gd2")
    L.rect(cx - 3, pot_top + 4, cx + 3, pot_top + 8, "rd4")
    L.p(cx - 3, pot_top + 4, "rd5")
    L.line(cx - 1, pot_top + 8, cx - 4, pot_top + 13, "rd4")
    L.line(cx + 1, pot_top + 8, cx + 4, pot_top + 13, "rd2")
    L.outline()
    return L, foot


# ================================================================== 影子、暖光
LAMPS = [   # (灯罩口中心 x, 灯脚 y, 地上光圈半径) —— 照地面、照旁边家具
    (630, 263, 46, 30),       # 茶座落地灯（01 原样）
    (373, 507, 38, 24),       # 阅读灯
    (652, 539, 34, 22),       # 门口落座那盏
]


def floor_shading(props_info):
    S = ShadeMap()
    S.rect(WALL_W[1], FLOOR_Y, WALL_E[0], FLOOR_Y + 2, -1.5)
    S.rect(WALL_W[1], FLOOR_Y + 2, WALL_E[0], FLOOR_Y + 5, -0.5)
    S.rect(WALL_W[1], FLOOR_Y, WALL_W[1] + 6, 662, -1.0)
    S.rect(WALL_W[1] + 6, FLOOR_Y, WALL_W[1] + 9, 662, -0.5)
    S.rect(WALL_E[0] - 2, FLOOR_Y, WALL_E[0], 662, -0.5)
    S.rect(WALL_W[1], 659, WALL_E[0], 662, -0.5)
    for (x0, y0, x1, y1, k) in props_info:
        S.rect(x0 + 1, y0 + 1, x1 + 2, y1 + 2, k, feather=1)
    S.rect(541, 296, 593, 314, -1.5)                 # 茶几底下
    S.rect(601, 402, 617, 438, -1.0)                 # 电视茶几底下
    S.rect(397, 528, 417, 564, -1.0)                 # 看书矮桌底下
    for (cx, cy, rx, ry) in LAMPS:
        S.ellipse(cx, cy + 3, rx, ry, 1.0, edge=1.5)
        S.ellipse(cx, cy, rx * 0.52, ry * 0.5, 1.0, edge=1.5)
    # 电视亮着：屏幕前（西南）地上一片淡光，只亮半档（棋盘点）
    S.ellipse(604, 452, 30, 16, 0.5, edge=0)
    cone(S, 504, 683, 618, 40, 0.30, 1.0, edge=1.5)  # 门口透进来的光
    return S


def cone(S, cx, y_from, y_to, half0, spread, val, edge=1):
    """一束光：从 y_from 往 y_to 越来越宽，两条斜边各一像素棋盘点"""
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
    """茶座落地灯照到墙上：灯罩口往上一束、往下一束，越远越淡"""
    S = ShadeMap()
    cone(S, 629, 182, 162, 9, 0.75, 1.0)
    cone(S, 629, 162, 146, 24, 0.75, 0.5)
    cone(S, 629, 202, 226, 13, 0.55, 1.0)
    for y in range(184, 202):
        S.add(619 - (y - 184) // 5, y, 0.5)
        S.add(639 + (y - 184) // 5, y, 0.5)
    S.apply(L, clip=lambda x, y: y < FLOOR_Y and y > CAP_Y1 and x > WALL_W[1] and x < WALL_E[0])


# ================================================================== 组装
def background():
    L = Layer()
    L.rect(X0, Y0, X1, Y1, "void")
    draw_floor(L)
    F = {f[0]: f[2] for f in FLAT}
    draw_rug(L, F["rug_tea"], "red")
    draw_rug(L, F["rug_tv"], "cream", bw=10)
    draw_rug(L, F["rug_read"], "red", bw=10)
    draw_rug(L, F["rug_se"], "navy", medallion=False, bw=10)
    draw_rug(L, F["rug_west"], "cream", medallion=False, bw=10)
    draw_doormat(L)
    draw_petals(L)
    draw_north_wall(L)
    draw_painting(L)
    draw_clock(L)
    draw_papercut(L, 527, 146)
    draw_papercut(L, 606, 146)
    draw_swag(L)
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
    cr = PLAN_BY["coat_rack"][3]
    props = [
        ("vinyl_wall",) + prop_vinyl_wall(),
        ("fiddle_fig",) + prop_plant_n(),
        ("floor_lamp",) + prop_floor_lamp(),
        ("sofa",) + prop_sofa(),
        ("record_player",) + prop_record_player(),
        ("record_crate",) + prop_record_crate(),
        ("tea_table",) + prop_tea_table(),
        ("armchair_w",) + prop_armchair("w"),
        ("armchair_e",) + prop_armchair("e"),
        ("bookshelf_1",) + prop_bookshelf(R["bookshelf_1"][1], R["bookshelf_1"][3], 11),
        ("bookshelf_2",) + prop_bookshelf(R["bookshelf_2"][1], R["bookshelf_2"][3], 23),
        ("tv_unit",) + prop_tv3(),
        ("tv_sofa",) + side_sofa(R["tv_sofa"], "e", 3, "rd", "gd", pillows=[(0, "gd", "knot"), (2, "wl", "dot")]),
        ("tv_table",) + prop_tv_table(),
        ("reading_lamp",) + prop_lamp_at(373, R["reading_lamp"][3], shade="rd"),
        ("reading_sofa",) + side_sofa(R["reading_sofa"], "e", 3, "wl", "wd", pillows=[(0, "gd", "knot")],
                                      throw="rd"),
        ("book_table",) + prop_book_table(),
        ("reading_chair",) + side_sofa(R["reading_chair"], "w", 1, "wl", "wd", pillows=[(0, "rd", "dot")]),
        ("west_chair_w",) + side_sofa(R["west_chair_w"], "e", 1, "wl", "wd", pillows=[(0, "gd", "knot")]),
        ("west_table",) + round_table(433, R["west_table"][3], top_w=26, top_d=17, item="tea"),
        ("west_chair_e",) + side_sofa(R["west_chair_e"], "w", 1, "wl", "wd", pillows=[(0, "rd", "dot")]),
        ("floor_lamp_se",) + prop_lamp_at(652, R["floor_lamp_se"][3]),
        ("loveseat",) + side_sofa(R["loveseat"], "w", 2, "rd", "gd", pillows=[(0, "wl", "dot"), (1, "gd", "knot")]),
        ("se_table",) + round_table(616, R["se_table"][3], item="flowers"),
        ("se_chair",) + side_sofa(R["se_chair"], "e", 1, "wl", "wd", pillows=[(0, "rd", "dot")]),
        ("kumquat",) + prop_kumquat(),
        ("coat_rack", moved(prop_coat_rack()[0], (cr[0] + cr[2]) // 2 - 657, cr[3] - 606), cr[3]),
        ("sw_table",) + round_table(394, R["sw_table"][3], h=30, item="lamp"),
        ("plant",) + prop_plant_sw(),
        ("side_walls",) + prop_side_walls(),
        ("front_walls",) + prop_front_walls(),
    ]
    shadows = [(352, 226, 496, 234, -1.0)]
    thin = {"floor_lamp": (623, 255, 636, 261), "reading_lamp": (367, 502, 380, 508),
            "floor_lamp_se": (646, 534, 659, 540), "coat_rack": (cr[0] + 1, cr[3] - 6, cr[2] - 2, cr[3])}
    for (iid, name, zone, r, h, block, st) in PLAN:
        if iid in ("vinyl_wall",):
            continue
        if iid in thin:
            shadows.append(tuple(thin[iid]) + (-1.5,))
        elif iid in ("tea_table", "tv_table", "book_table"):
            shadows.append((r[0], r[3] - 6, r[2], r[3], -1.0))
        elif iid in ("se_table", "sw_table"):
            cx = (r[0] + r[2]) // 2
            shadows.append((cx - 7, r[3] - 5, cx + 8, r[3], -2.0))
        else:
            shadows.append((r[0], r[1], r[2], r[3], -2.0))
    S = floor_shading(shadows)
    S.apply(bg, clip=lambda x, y: y >= FLOOR_Y)
    wall_light(bg)
    # 灯照到旁边的家具：朝上的面亮一档
    near = {0: ("sofa", "armchair_e"), 1: ("reading_sofa", "book_table", "bookshelf_2"),
            2: ("loveseat", "se_table")}
    for k, (cx, cy, rx, ry) in enumerate(LAMPS):
        for name, layer, foot in props:
            if name in near[k]:
                P = ShadeMap()
                P.ellipse(cx + 2, cy - 24, 30, 30, 1.0, edge=1)
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


def walk_check():
    """从门口 (504, 680) 走得到每件东西跟前、三个站人点吗：2 像素一格，人按脚底 12×6 算；
    能站的地 = 休息间墙里、y≥232、不压任何挡人的东西；门口只能从门洞进"""
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
    start = (504, 680)
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
    for (iid, name, zone, r, h, block, st) in PLAN:
        x0, y0, x1, y1 = r
        cands = [(x, y1 + 4) for x in range(x0 - 6, x1 + 8, 2)] + \
                [(x0 - 8, y) for y in range(y0, y1 + 4, 2)] + [(x1 + 8, y) for y in range(y0, y1 + 4, 2)]
        cands = [((c[0] // 2) * 2, (c[1] // 2) * 2) for c in cands]
        if not any(c in seen for c in cands):
            bad.append(iid)
    spot_bad = []
    for (sid, name, (sx, sy), r) in SPOTS:
        if ((sx // 2) * 2, (sy // 2) * 2) not in seen:
            spot_bad.append(sid)
    # 门口往里那条路：门洞中间 x 486～522 一直走到 lounge 交互点
    lane = all(((x // 2) * 2, (y // 2) * 2) in seen for x in (490, 504, 518) for y in range(430, 680, 2))
    print("走得通：%d/%d 件；站人点 %s；门口到交互点的路 %s" % (
        len(PLAN) - len(bad), len(PLAN), "都站得到" if not spot_bad else "站不到 " + "、".join(spot_bad),
        "通" if lane else "不通"))
    if bad:
        print("  走不到：" + "、".join(bad))
    return bad, spot_bad, lane


def crop_alpha(layer):
    """一层裁到画了的那块：回 (图, 左上角画布 x, y)"""
    box = layer.im.getbbox()
    return layer.im.crop(box), layer.ox + box[0], layer.oy + box[1]


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    check_layout()
    bad, spot_bad, lane = walk_check()
    if bad or spot_bad or not lane:
        raise SystemExit("走路检查没过")
    bg, props = build()
    room = compose(bg, props)
    cols = palette_count(room)
    print("整间 %s，颜色 %d 种（调色板 %d）" % (room.size, len(cols), len(PAL_HEX)))
    if len(cols) > 64:
        raise SystemExit("颜色超过 64 种（%d）" % len(cols))
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    bx0, by0, bx1, by1 = BG_CROP
    bgi = bg.im.crop((bx0 - X0, by0 - Y0, bx1 - X0, by1 - Y0))
    palette_count(bgi)
    bgi.save(os.path.join(OUT, "room.png"))
    man = {"note": "tools/pixel_art/room_backhall_lounge.py 生成，别手改。背景左上角放在 background.x/y（画布坐标），1 倍、不插值；"
                   "每件家具左上角在 x/y，着地线 foot（跟人排前后用）；hide 是要藏掉的灰盒（挡人的占地照旧）",
           "background": {"png": RES + "room.png", "x": bx0, "y": by0}, "room": {"x0": bx0, "x1": bx1}, "props": []}
    names = set()
    for name, layer, foot in props:
        im, x, y = crop_alpha(layer)
        palette_count(im)
        im.save(os.path.join(OUT, "props", name + ".png"))
        names.add(name + ".png")
        hide = HIDE.get(name, [name])
        for h in hide:
            if h not in IT:
                raise SystemExit("%s 要藏的灰盒 %s 布局里没有" % (name, h))
        man["props"].append({"id": "px_" + name, "png": RES + "props/%s.png" % name, "x": x, "y": y, "foot": foot, "hide": hide})
    for f in os.listdir(os.path.join(OUT, "props")):   # 改名、删掉的家具别留旧图
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(OUT, "props", f))
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print("背景 %s，家具 %d 件 → %s" % (bgi.size, len(props), OUT))
    if preview:
        os.makedirs(preview, exist_ok=True)
        room.save(os.path.join(preview, "lounge_room.png"))
        # 样板 v3 | 改完（都是画布 1:1，再一起放大 2 倍）：看两处改对没有
        v3 = Image.open(V3_PNG).convert("RGBA")
        gap = 8
        cmp_ = Image.new("RGBA", (W * 2 + gap * 3, H + gap * 2), C["void"])
        for k, im in enumerate((v3, room)):
            cmp_.alpha_composite(im, (gap + k * (W + gap), gap))
        cmp_.resize((cmp_.width * 2, cmp_.height * 2), Image.NEAREST).save(os.path.join(preview, "lounge_v3_vs_new.png"))
        phone(bg, props, preview)


def phone(bg, props, out_dir):
    SW, SH = 540, 960
    ox, oy = 94 - X0, 80 - Y0            # 画布 → 屏幕
    scr = Image.new("RGBA", (SW, SH), C["void"])
    cor = Layer(x0=-ox, y0=696, w=SW, h=200)
    draw_corridor(cor)
    scr.alpha_composite(cor.im, (0, 696 + oy))
    people = [(guest("03"), 424, 314), (guest("09"), 616, 478)]
    bgp = Layer()
    bgp.im = bg.im.copy()
    bgp.px = bgp.im.load()
    S = ShadeMap()
    for (img, fx, fy) in people:
        S.ellipse(fx + 1, fy - 1, 12, 4, -1.5, edge=1.5)
    S.apply(bgp)
    room = compose(bgp, props, people)
    room = room.crop((0, 0, W, FRONT_BOT - Y0))
    scr.alpha_composite(room, (X0 + ox, Y0 + oy))
    fw = Layer(x0=-ox, y0=FRONT_TOP, w=SW, h=FRONT_BOT - FRONT_TOP)
    for (a, b) in ((-ox, X0), (X1, -ox + SW)):
        fw.rect(a, FRONT_TOP, b, FRONT_FACE, "wl4")
        fw.hl(a, b, FRONT_TOP, "ol")
        fw.hl(a, b, FRONT_TOP + 1, "wl5")
        fw.hl(a, b, FRONT_FACE - 1, "wl3")
        front_wall_face(fw, a, b)
    scr.alpha_composite(fw.im, (0, FRONT_TOP + oy))
    scr.save(os.path.join(out_dir, "lounge_phone.png"))


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
