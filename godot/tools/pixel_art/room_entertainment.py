#!/usr/bin/env python3
"""罗曼山庄后厅「娱乐室」（原麻将室）代码画 v1（庄Z4，2026-10-05 晚；场景还原规范 方案一 第 3 步）。

布局照 godot/回执/娱乐室-排法/零件表-草稿.json（阿鱼说 OK）：画布 1080×1560，人 84 高不动，家具按旧比例 ×1.25，
1 个美术像素 = 1 个画布像素。画法、调色板借后厅麻将室 room_backhall_mahjong.py（import 进来只读，不改它）：
深褐描边、光从左上、亮暗投影三层、贴地一行接触阴影、硬边（只有全透和不透明）、斜俯视没透视、墙顶画出剖开厚度。

×1.25 怎么落：旧画法里 左右和高 1 米 48、地面前后 1 米 32 → 这里 60 和 40；
旧家具有原型的（麻将桌、椅子、宫灯、观音竹、发财树、暖水瓶、衣帽架、鸟笼架、落地扇、花几）按旧尺寸 ×1.25 重画（不是放大小图）；
旧画法里没有原型的（茶水台、茶叶柜、小几、长椅、记分板）照草稿的宽高画。

用法：python3 godot/tools/pixel_art/room_entertainment.py
  出到 godot/回执/娱乐室-排法/代码画-v1/：room.png、props/*.png、room.json、preview.png、preview_x2.png、
  phone_1_进门.png、phone_2_第一排.png、check_坐人.png（坐几个 NPC 看椅子朝向、遮挡，放大 2 倍）
"""
import json
import math
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import room_backhall_mahjong as MJ    # 只借调色板和画法小工具，不改它

REPO = MJ.REPO
GODOT = os.path.join(REPO, "godot")
DRAFT = os.path.join(GODOT, "回执", "娱乐室-排法", "零件表-草稿.json")
OUT = os.path.join(GODOT, "回执", "娱乐室-排法", "代码画-v1")
CHAR_DIR = MJ.CHAR_DIR

C, shift, rname, RAMP_OF = MJ.C, MJ.shift, MJ.rname, MJ.RAMP_OF


def leaf(L, cx, cy, ln, ang, wid, ramp_i, vein=True):
    """一片尖叶子（照麻将室 leaf，只多一处：sin 取不小于 0，免得浮点误差出负数）"""
    ca, sa = math.cos(ang), math.sin(ang)
    pts = {}
    for y in range(int(cy - ln) - 1, int(cy + ln) + 2):
        for x in range(int(cx - ln) - 1, int(cx + ln) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            u = dx * ca + dy * sa
            v = -dx * sa + dy * ca
            if -ln / 2 <= u <= ln / 2:
                half = wid / 2 * max(0.0, math.sin(math.pi * (u + ln / 2) / ln)) ** 0.75
                if abs(v) <= half:
                    pts[(x, y)] = (u, v, half)
    light_side = 1 if (-sa * -1 + ca * -1) < 0 else -1
    for (x, y), (u, v, half) in pts.items():
        L.p(x, y, rname("gr", ramp_i + 1 if v * light_side > 0.15 * half else ramp_i))
    for (x, y), (u, v, half) in pts.items():
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge and (x - cx) + (y - cy) > -1:
            L.p(x, y, rname("gr", ramp_i - 2))
    if vein:
        for t in range(-int(ln / 2) + 2, int(ln / 2) - 1):
            L.p(cx + ca * t, cy + sa * t, rname("gr", ramp_i - 1))
Layer = MJ.Layer
BAM = MJ.BAM            # 红木（亮一档那套）wd2～wd5

# ------------------------------------------------------------------ 画布、墙
W, H = 1080, 1560
CAP1 = 13               # 北墙墙顶（剖开的厚度）0～13
FLOOR_Y = 150           # 北墙脚 = 地板开始
SIDE = 16               # 东西墙顶宽 0～16、1064～1080
WALL_S = 1460           # 南墙矮墙墙顶从这里起（墙顶 1460～1475、墙面 1475～1503）
S_FACE, S_BOT = 1475, 1503
DOOR = (470, 610)       # 门洞（照草稿）
WALK_Y1 = 1458          # 屋里人脚最多走到这（再往南就到矮墙后头了）


def sub(x0, y0, x1, y1):
    return Layer(x0=int(x0), y0=int(y0), w=int(x1 - x0), h=int(y1 - y0))


def paste_ol(L, s):
    s.outline()
    L.paste(s)


def lift_wood(L, k=1):
    """整件红木亮 k 档（照麻将室 v3：红木在亮地板上别发闷）"""
    for y in range(L.h):
        for x in range(L.w):
            c = L.px[x, y]
            if c[3] and RAMP_OF.get(c, ("",))[0] == "wd":
                L.px[x, y] = shift(c, k)
    return L


def moved(fn, region, dx, dy, *args):
    """用旧画法（坐标写死在旧画布上）在旧坐标画一块，原大小平移过来（不缩放）"""
    x0, y0, x1, y1 = region
    t = sub(x0, y0, x1, y1)
    fn(t, *args)
    t.ox += dx
    t.oy += dy
    return t


class ShadeMap:
    """照麻将室的 ShadeMap，换成这块画布的大小：累加明暗，按档挪色带，半档用棋盘点"""
    def __init__(self):
        self.v = [[0.0] * W for _ in range(H)]

    def add(self, x, y, val):
        if 0 <= x < W and 0 <= y < H:
            self.v[y][x] += val

    def rect(self, x0, y0, x1, y1, val, feather=0):
        for y in range(int(y0) - feather, int(y1) + feather):
            for x in range(int(x0) - feather, int(x1) + feather):
                dx = max(x0 - x - 0.5, x + 0.5 - x1, 0)
                dy = max(y0 - y - 0.5, y + 0.5 - y1, 0)
                d = max(dx, dy)
                f = (1.0 if d == 0 else 0.0) if feather == 0 else max(0.0, 1.0 - d / (feather + 0.5))
                if f > 0:
                    self.add(x, y, val * f)

    def ellipse(self, cx, cy, rx, ry, val, edge=1.5):
        rm = (rx + ry) / 2.0
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                d = math.sqrt(dx * dx + dy * dy)
                if d < 1.0:
                    self.add(x, y, val * (1.0 if (1.0 - d) * rm > edge else 0.5))

    def cone(self, cx, y_from, y_to, half0, spread, val, edge=1.5):
        step = 1 if y_to > y_from else -1
        for y in range(y_from, y_to, step):
            half = half0 + abs(y - y_from) * spread
            for x in range(int(cx - half) - 1, int(cx + half) + 2):
                dx = abs(x + 0.5 - cx)
                if dx <= half - edge:
                    self.add(x, y, val)
                elif dx <= half:
                    self.add(x, y, val * 0.5)

    def apply(self, layer, clip=None, step=0.5):
        for y in range(H):
            row = self.v[y]
            for x in range(W):
                s = row[x]
                if abs(s) < 0.2 or (clip and not clip(x, y)):
                    continue
                s = round(s / step) * step
                k = math.floor(s)
                if s - k > 0.25 and (x + y) % 2 == 0:
                    k += 1
                if k:
                    layer.shade_px(x, y, k)


# ================================================================== 背景：地板、墙
def draw_floor(L, x0, x1, y0, y1, seed=3):
    """后厅三间那套蜜色宽木地板（backhall_floor.py v3），×1.25：一排 15 像素、板长 125～275"""
    rnd = random.Random(20261031 + seed)
    row = 15
    y = y0
    prev = []
    while y < y1:
        L.hl(x0, x1, y, "hw2")
        x = x0 - rnd.randrange(0, 175)
        joints, last = [], None
        while x < x1:
            ln = rnd.randrange(125, 275)
            for j in prev:
                if abs(x + ln - j) < 38:
                    ln += 55
            t = rnd.choice([4, 4, 4, 4, 4, 5, 5, 3])
            if t == last:
                t = 5 if t == 4 else 4
            last = t
            a, b = max(x, x0), min(x + ln, x1)
            if b > a:
                L.rect(a, y + 1, b, y + row, "hw%d" % t)
                L.hl(a, b, y + 1, "hw%d" % min(6, t + 1))
                for _ in range(rnd.choice([1, 1, 1, 2, 2, 0])):
                    gy = y + rnd.randrange(4, row - 2)
                    span = b - a
                    gx = a + rnd.randrange(4, max(5, span // 4))
                    gl = rnd.randrange(max(8, span // 2), max(9, span * 4 // 5))
                    gaps = set()
                    for _ in range(rnd.choice([0, 1, 1, 2])):
                        g0 = rnd.randrange(6, max(7, gl - 6))
                        gaps.update(range(g0, g0 + rnd.randrange(2, 5)))
                    k = 0
                    while k < gl and gx + k < b - 3:
                        if k not in gaps:
                            L.p(gx + k, gy, "hw%d" % (t - 1))
                        if k > 4 and rnd.random() < 0.03:
                            gy = max(y + 3, min(y + row - 2, gy + rnd.choice([-1, 1])))
                        k += 1
                if rnd.random() < 0.025 and b - a > 40:
                    kx, ky = rnd.randrange(a + 10, b - 10), y + rnd.randrange(4, row - 3)
                    L.p(kx, ky, "hw%d" % (t - 2))
                    L.p(kx + 1, ky, "hw%d" % (t - 1))
                    L.p(kx - 1, ky, "hw%d" % (t - 1))
                if x >= x0:
                    L.vl(x, y + 1, y + row, "hw2")
                    L.vl(x + 1, y + 2, y + row, "hw%d" % min(6, t + 1))
                    joints.append(x)
            x += ln
        prev = joints
        y += row


def draw_north_wall(L):
    """北墙（照麻将室北墙 ×1.25）：墙顶剖面、上沿木线、墙纸暗花、腰线、护墙板、踢脚"""
    x0, x1 = 0, W
    L.rect(x0, CAP1, x1, FLOOR_Y, "wl3")
    for y in range(CAP1 + 8, 88):                          # 墙纸暗花（菱形点，15 一格）
        for x in range(x0, x1):
            gy = (y - CAP1 - 8) % 15
            gx = (x + (7 if ((y - CAP1 - 8) // 15) % 2 else 0)) % 15
            if abs(gx - 7) + abs(gy - 7) == 2:
                L.p(x, y, "wl2")
    for x in range(9, x1, 25):                             # 细竖条
        for y in range(CAP1 + 8, 88):
            if L.g(x, y) == C["wl3"]:
                L.p(x, y, "wl4")
    for y, c in ((13, "wd1"), (14, "wd4"), (15, "wd3"), (16, "wd3"), (17, "wd3"), (18, "wd1"), (19, "wl1"), (20, "wl2"),
                 (88, "wl1"), (89, "wd4"), (90, "wd3"), (91, "wd3"), (92, "wd2"), (93, "wd1")):
        L.hl(x0, x1, y, c)
    L.rect(x0, 94, x1, 141, "wd2")                         # 护墙板
    px0 = SIDE + 5
    while px0 < W - SIDE - 5:
        a, b = px0, min(px0 + 28, W - SIDE - 4)
        L.rect(a, 98, b, 137, "wd3")
        L.hl(a, b, 98, "wd4")
        L.vl(a, 98, 137, "wd4")
        L.hl(a, b, 136, "wd1")
        L.vl(b - 1, 99, 137, "wd1")
        L.rect(a + 4, 102, b - 4, 133, "wd3")
        L.hl(a + 4, b - 4, 102, "wd1")
        L.vl(a + 4, 102, 133, "wd1")
        L.hl(a + 4, b - 4, 132, "wd4")
        L.vl(b - 5, 103, 133, "wd4")
        px0 += 33
    L.hl(x0, x1, 94, "wd1")
    L.hl(x0, x1, 140, "wd4")
    L.rect(x0, 141, x1, 150, "wd1")                        # 踢脚
    L.hl(x0, x1, 141, "wd2")
    L.hl(x0, x1, 149, "wd0")
    L.rect(x0, 0, x1, CAP1, "wl4")                         # 墙顶剖面
    L.hl(x0, x1, 0, "ol")
    L.hl(x0, x1, 1, "wl5")
    L.hl(x0, x1, CAP1 - 1, "ol")


def draw_side_walls(L):
    """东西墙顶那一条（照麻将室 prop_side_walls）：一直接到南墙墙顶"""
    for (a, b) in ((0, SIDE), (W - SIDE, W)):
        L.rect(a, 0, b, S_FACE, "wl4")
        L.vl(a, 0, S_FACE, "ol")
        L.vl(b - 1, 0, S_FACE, "ol")
        L.vl(a + 1 if a == 0 else b - 2, 1, S_FACE, "wl5")
        L.vl(b - 2 if a == 0 else a + 1, CAP1, S_FACE, "wl3")
        L.hl(a, b, 0, "ol")


def front_wall_face(L, a, b):
    """南墙矮墙正面：护墙板一格一格（照麻将室 ×1.25）"""
    L.rect(a, S_FACE, b, S_BOT, "wd3")
    L.hl(a, b, S_FACE, "ol")
    L.hl(a, b, S_FACE + 1, "wd4")
    L.hl(a, b, S_FACE + 2, "wd2")
    px0 = a + 4
    while px0 + 19 <= b - 2:
        L.rect(px0, S_FACE + 6, px0 + 19, S_BOT - 7, "wd3")
        L.hl(px0, px0 + 19, S_FACE + 6, "wd2")
        L.vl(px0, S_FACE + 6, S_BOT - 7, "wd2")
        L.hl(px0 + 1, px0 + 19, S_BOT - 8, "wd4")
        L.vl(px0 + 18, S_FACE + 7, S_BOT - 7, "wd4")
        L.rect(px0 + 4, S_FACE + 10, px0 + 15, S_BOT - 11, "wd3")
        L.hl(px0 + 4, px0 + 15, S_FACE + 10, "wd4")
        L.vl(px0 + 4, S_FACE + 10, S_BOT - 11, "wd4")
        L.hl(px0 + 4, px0 + 15, S_BOT - 12, "wd2")
        L.vl(px0 + 14, S_FACE + 11, S_BOT - 11, "wd2")
        px0 += 23
    L.rect(a, S_BOT - 5, b, S_BOT, "wd1")
    L.hl(a, b, S_BOT - 5, "wd2")
    L.hl(a, b, S_BOT - 1, "wd0")


def draw_south_wall(L):
    """南墙：门洞两边的矮墙（墙顶剖面 + 正面护墙板）、一对门套、门槛；门外一条走廊地砖"""
    rnd = random.Random(7)
    L.rect(0, S_BOT, W, H, "wl2")                          # 门外走廊（照麻将室 draw_corridor ×1.25）
    for row, y in enumerate(range(S_BOT, H, 15)):
        off = 0 if row % 2 == 0 else 30
        for x in range(-60 + off, W, 60):
            tone = rnd.choice(["wl2", "wl2", "wl3", "wl2", "wl1"])
            L.rect(x + 1, y + 1, x + 60, y + 15, tone)
            L.hl(x + 1, x + 60, y + 1, shift(tone, 1))
            L.vl(x + 1, y + 1, y + 15, shift(tone, 1))
            if rnd.random() < 0.3:
                L.p(x + rnd.randrange(4, 55), y + rnd.randrange(3, 12), shift(tone, -1))
            L.vl(x, y, y + 15, "wl0")
        L.hl(0, W, y, "wl0")
    for x in range(W):                                     # 矮墙脚下一行影
        L.shade_px(x, S_BOT, -1)
        if x % 2 == 0:
            L.shade_px(x, S_BOT + 1, -1)
    # 门槛（门洞里矮墙那一截的地面）
    L.rect(DOOR[0], 1488, DOOR[1], S_BOT, "wd4")
    for y, c in ((1488, "wd2"), (1489, "wd5"), (1495, "wd3"), (1496, "wd5"), (S_BOT - 1, "wd2")):
        L.hl(DOOR[0], DOOR[1], y, c)
    for (a, b) in ((SIDE, DOOR[0]), (DOOR[1], W - SIDE)):
        L.rect(a, WALL_S, b, S_FACE, "wl4")
        L.hl(a, b, WALL_S, "ol")
        L.hl(a, b, WALL_S + 1, "wl5")
        L.hl(a, b, S_FACE - 1, "wl3")
        front_wall_face(L, a, b)
    for (a, b) in ((0, SIDE), (W - SIDE, W)):              # 东西墙顶拐进南墙墙顶，墙角正面也接上
        L.rect(a, WALL_S + 1, b, S_FACE, "wl4")
        front_wall_face(L, a, b)
        L.vl(a, WALL_S, S_BOT, "ol")
        L.vl(b - 1, WALL_S, S_BOT, "ol")
    for (a, b) in ((DOOR[0] - 7, DOOR[0]), (DOOR[1], DOOR[1] + 7)):   # 门套
        L.rect(a, WALL_S - 5, b, S_BOT, "wd2")
        L.vl(a, WALL_S - 5, S_BOT, "wd4")
        L.vl(a + 1, WALL_S - 4, S_BOT, "wd3")
        L.vl(b - 1, WALL_S - 5, S_BOT, "wd1")
        L.hl(a, b, WALL_S - 5, "wd5")
        L.hl(a, b, WALL_S - 4, "wd4")
        L.rect(a, S_BOT - 7, b, S_BOT, "wd1")
        L.hl(a, b, S_BOT - 7, "wd3")
        L.vl(a - 1, WALL_S - 5, S_BOT, "ol")
        L.vl(b, WALL_S - 5, S_BOT, "ol")
        L.hl(a - 1, b + 1, WALL_S - 6, "ol")


def draw_window(L, x0, y0, x1, y1, seed=0):
    """雕花木窗（照麻将室花窗，放宽成横窗）：深木框、步步锦窗棂、窗纸上亮下暗、中间团花、两边小圆窗花、四角角花；不写字"""
    L.rect(x0 - 3, y0 - 3, x1 + 3, y1 + 4, "wd1")
    L.rect(x0 - 2, y0 - 2, x1 + 2, y1 + 2, "wd3")
    L.hl(x0 - 2, x1 + 2, y0 - 2, "wd4")
    L.vl(x0 - 2, y0 - 2, y1 + 2, "wd4")
    L.hl(x0 - 3, x1 + 3, y1 + 2, "wd4")                    # 窗台
    L.hl(x0 - 4, x1 + 4, y1 + 3, "wd2")
    L.hl(x0 - 4, x1 + 4, y1 + 4, "wd1")
    L.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, "wl5")
    for y in range(y0 + 1, y1 - 1):
        for x in range(x0 + 1, x1 - 1):
            if y > y0 + 38 or (y > y0 + 33 and (x + y) % 2 == 0):
                L.p(x, y, "wl4")
    for x in range(x0, x1, 12):
        L.vl(x, y0, y1, "wd2")
    for y in range(y0, y1, 12):
        L.hl(x0, x1, y, "wd2")
    L.vl(x1 - 1, y0, y1, "wd2")
    L.hl(x0, x1, y1 - 1, "wd2")
    # 雕花：每格里一个小十字结（步步锦），中间分三扇的立梃加粗
    for x in range(x0 + 12, x1 - 3, 12):                   # 窗棂交叉处一颗小木钉（不成笔画）
        for y in range(y0 + 12, y1 - 3, 12):
            L.p(x - 1, y - 1, "wd3")
            L.p(x + 1, y + 1, "wd1")
    for mx in (x0 + (x1 - x0) // 3, x0 + 2 * (x1 - x0) // 3):
        mx = x0 + round((mx - x0) / 12.0) * 12
        L.rect(mx - 1, y0, mx + 2, y1, "wd3")
        L.vl(mx - 1, y0, y1, "wd4")
        L.vl(mx + 1, y0, y1, "wd1")
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    L.rect(cx - 12, cy - 9, cx + 13, cy + 10, "wd2")
    L.rect(cx - 11, cy - 8, cx + 12, cy + 9, "wl5")
    L.rect(cx - 11, cy + 2, cx + 12, cy + 9, "wl4")
    MJ.draw_papercut(L, cx + 0.5, cy + 0.5, hole=None)
    for qx in (x0 + 18, x1 - 18):
        L.rect(qx - 7, cy - 7, qx + 8, cy + 8, "wl5")
        MJ.draw_mini_round(L, qx, cy)
    for (ax, ay, sx, sy) in ((x0 + 1, y0 + 1, 1, 1), (x1 - 2, y0 + 1, -1, 1), (x0 + 1, y1 - 2, 1, -1), (x1 - 2, y1 - 2, -1, -1)):
        for k in range(7):
            for j in range(7 - k):
                if (k + j) % 3 != 2:
                    L.p(ax + sx * j, ay + sy * k, "rd3")
        L.p(ax + sx, ay + sy, "wl4")
    L.vl(x1 + 3, y0, y1 + 4, "wl1")


KNOTS = [20, 120, 220, 330, 435, 540, 645, 750, 860, 960, 1060]
LANTERNS = [220, 330, 750, 860]
SWAG_Y = 16


def draw_swag(L):
    """北墙上沿一整排红绸（照麻将室 ×1.25），结下挂灯笼或短穗"""
    y0 = SWAG_Y
    for k in range(len(KNOTS) - 1):
        a, b = KNOTS[k], KNOTS[k + 1]
        wdt = b - a
        depth = 7 + wdt * 0.05
        for x in range(a, b):
            t = (x + 0.5 - a) / wdt
            sag = math.sin(math.pi * t)
            yb = y0 + depth * sag
            for y in range(y0, int(yb) + 1):
                f = (y - y0) / max(1.0, yb - y0)
                lv = 2 if f > 0.82 else 3
                band = (y - y0 - 3 * sag)
                if 0 <= band < 1.4 or 5.5 <= band < 6.7:
                    lv = 2
                if 1.4 <= band < 2.8 and 0.2 < t < 0.8:
                    lv = 4
                L.p(x, y, rname("rd", lv))
            L.p(x, int(yb) + 1, "rd1")
            if x % 2 == 0:
                L.p(x, int(yb) + 2, "wl1")
        L.hl(a, b, y0 - 1, "rd2")
    for kx in KNOTS:
        L.ell(kx - 5, 12, kx + 5, 22, "rd2")
        L.ell(kx - 4, 13, kx + 4, 21, "gd3")
        L.p(kx - 1, 14, "gd4")
        L.p(kx, 17, "rd3")
        L.p(kx + 1, 18, "gd1")
        if kx in LANTERNS:
            continue
        ln = 7 if kx in (KNOTS[0], KNOTS[-1]) else 10
        for yy in range(22, 22 + ln):
            L.p(kx - 1, yy, "gd2")
            L.p(kx, yy, "gd3")
            L.p(kx + 1, yy, "gd1")
        L.hl(kx - 1, kx + 2, 22 + ln, "rd3")
        L.p(kx, 23 + ln, "rd2")


def draw_lantern(L, cx, top):
    """红灯笼（照麻将室 ×1.25）：金顶、红肚子竖棱、中间透亮、金底、红穗"""
    rx, hgt = 8, 16
    L.vl(cx, 22, top, "gd1")
    L.rect(cx - 3, top, cx + 4, top + 3, "gd2")
    L.hl(cx - 3, cx + 4, top, "gd3")
    y0, y1 = top + 3, top + 3 + hgt
    L.ell(cx - rx, y0, cx + rx + 1, y1, "rd3")
    L.ell(cx - rx + 2, y0 + 2, cx + rx - 1, y1 - 2, "rd4")
    L.ell(cx - 2, y0 + 3, cx + 3, y1 - 3, "rd5")
    L.p(cx, y0 + 5, "gd4")
    L.p(cx - 1, y0 + 6, "gd4")
    for vx in (cx - rx + 2, cx + rx - 2):
        L.vl(vx, y0 + 2, y1 - 2, "rd2")
    for vx in (cx - 4, cx + 4):
        L.vl(vx, y0 + 1, y1 - 1, "rd3")
    L.ring(cx - rx, y0, cx + rx + 1, y1, "rd1", only=lambda x, y: x > cx + 2 or y > y1 - 4)
    L.rect(cx - 3, y1, cx + 4, y1 + 3, "gd2")
    L.hl(cx - 3, cx + 4, y1 + 2, "gd1")
    for yy in range(y1 + 3, y1 + 13):
        L.p(cx, yy, "rd3")
        L.p(cx + (1 if yy > y1 + 5 else -1), yy, "rd3" if yy < y1 + 10 else "rd2")
    L.p(cx - 1, y1 + 12, "rd2")
    L.p(cx + 2, y1 + 12, "rd2")


def draw_round_fan(L, cx, cy):
    """墙上挂的团扇（不写字）：红木扇柄、米白绢面画一枝粉花、一圈金边，下面一束红穗"""
    rx, ry = 8, 9
    L.vl(cx, cy - ry - 4, cy - ry, "rd2")                   # 挂绳
    L.ell(cx - rx, cy - ry, cx + rx + 1, cy + ry + 1, "gd2")
    L.ell(cx - rx + 1, cy - ry + 1, cx + rx, cy + ry, "wl5")
    L.ell(cx - rx + 2, cy + 1, cx + rx - 1, cy + ry - 1, "wl4", only=lambda x, y: (x + y) % 2 == 0)
    L.line(cx - 5, cy + 5, cx + 3, cy - 3, "wd2")         # 一枝花
    for (fx, fy) in ((cx + 3, cy - 4), (cx - 1, cy), (cx + 4, cy + 1)):
        L.rect(fx - 1, fy - 1, fx + 2, fy + 2, "pk")
        L.p(fx, fy, "pk2")
        L.p(fx + 1, fy + 1, "pk0")
    L.p(cx - 3, cy + 2, "gr3")
    L.p(cx - 4, cy + 3, "gr2")
    L.ring(cx - rx, cy - ry, cx + rx + 1, cy + ry + 1, "gd1", only=lambda x, y: x > cx or y > cy + 2)
    L.rect(cx - 1, cy + ry, cx + 2, cy + ry + 9, "wd3")    # 扇柄
    L.vl(cx - 1, cy + ry, cy + ry + 9, "wd4")
    L.p(cx, cy + ry + 9, "gd3")
    for yy in range(cy + ry + 10, cy + ry + 17):
        L.p(cx, yy, "rd3")
        L.p(cx + 1, yy, "rd2")


def draw_doormat(L, x0, y0, x1, y1):
    """门口地垫（照麻将室，放大一号的尺寸重画）：红底金边、一排菱形"""
    L.rect(x0, y0, x1, y1, "rd2")
    L.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, "gd2")
    L.rect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, "rd2")
    cy = (y0 + y1) // 2
    n = (x1 - x0 - 16) // 12
    for k in range(n + 1):
        cx = x0 + 8 + k * 12
        L.poly([(cx, cy - 3), (cx + 4, cy), (cx, cy + 3), (cx - 4, cy)], "rd4")
        L.p(cx, cy, "gd3")
    L.hl(x0, x1, y0, "rd3")
    L.hl(x0, x1, y1 - 1, "rd1")
    for x in range(x0 + 1, x1 - 1, 2):                     # 两头流苏
        L.p(x, y0 - 1, "wl4")
        L.p(x, y1, "wl4")


# ================================================================== 小东西（×1.25 重画的几样 + 原大小借来的几样）
def gaiwan(L, x, y):
    """盖碗（照麻将室 ×1.25，11 宽）：托、碗、盖，青花"""
    L.ell(x, y + 5, x + 11, y + 9, "bl4")
    L.hl(x + 1, x + 10, y + 6, "wt")
    L.rect(x + 2, y + 1, x + 9, y + 6, "wt")
    L.hl(x + 2, x + 9, y + 4, "bl2")
    L.vl(x + 8, y + 1, y + 6, "bl4")
    L.ell(x + 2, y - 1, x + 9, y + 3, "wt")
    L.p(x + 5, y - 1, "bl2")
    L.p(x + 6, y, "bl4")


def thermos(L, cx, base, tall=25, style="red"):
    """暖水瓶（照麻将室 ×1.25，9 宽）：红铁皮瓶身画一朵粉牡丹 / 竹壳；铝肩、木塞、底圈、右边提手"""
    w = 9
    x0 = cx - w // 2
    top = base - tall
    body = ("rd2", "rd3", "rd4") if style == "red" else ("gd1", "gd2", "gd3")
    L.rect(x0, top + 6, x0 + w, base - 2, body[1])
    L.vl(x0, top + 6, base - 2, body[2])
    L.vl(x0 + 1, top + 6, base - 2, body[2] if style == "red" else body[1])
    L.vl(x0 + w - 1, top + 6, base - 2, body[0])
    if style == "red":
        fy = top + 13
        L.ell(x0 + 1, fy - 3, x0 + 8, fy + 3, "pk")
        L.p(x0 + 4, fy, "pk2")
        L.p(x0 + 3, fy - 1, "pk2")
        L.p(x0 + 5, fy + 1, "pk0")
        L.p(x0 + 1, fy + 4, "gr3")
        L.p(x0 + 7, fy + 4, "gr2")
        L.hl(x0 + 1, x0 + w - 1, top + 7, "gd3")
        L.hl(x0 + 1, x0 + w - 1, base - 5, "gd3")
    else:
        for y in range(top + 6, base - 2):
            for x in range(x0, x0 + w):
                if (x + y) % 3 == 0:
                    L.p(x, y, body[0])
    L.rect(x0, top + 3, x0 + w, top + 6, "sv1")
    L.hl(x0 + 1, x0 + w - 1, top + 3, "sv2")
    L.p(x0 + w - 1, top + 5, "sv0")
    L.rect(x0 + 2, top + 1, x0 + w - 2, top + 3, "sv1")
    L.p(x0 + 2, top + 1, "sv2")
    L.rect(x0 + 3, top - 1, x0 + w - 3, top + 1, "wd4")
    L.p(x0 + 3, top - 1, "wd5")
    L.rect(x0, base - 2, x0 + w, base, "sv1")
    L.hl(x0, x0 + w, base - 2, "sv2")
    L.p(x0 + w - 1, base - 1, "sv0")
    L.vl(x0 + w, top + 7, top + 16, "sv1")
    L.p(x0 + w + 1, top + 8, "sv1")
    L.p(x0 + w + 1, top + 15, "sv1")
    L.vl(x0 + w + 2, top + 9, top + 15, "sv0")


def fruit_plate(L, x, y, w=16):
    """一盘水果（橘子、红苹果）：红瓷盘、上面堆几个"""
    L.ell(x, y + 2, x + w, y + 9, "rd2")
    L.ell(x + 1, y + 2, x + w - 1, y + 8, "wt")
    L.ring(x + 1, y + 2, x + w - 1, y + 8, "bl4")
    fruits = [(x + 3, y + 1, "or"), (x + 8, y + 2, "rd"), (x + 5, y - 2, "or"), (x + w - 7, y - 1, "or")]
    for (fx, fy, kind) in fruits:
        if kind == "or":
            L.ell(fx, fy, fx + 6, fy + 6, "cl2")
            L.ell(fx, fy, fx + 5, fy + 5, "or")
            L.p(fx + 1, fy + 1, "gd4")
            L.p(fx + 3, fy, "gr2")
        else:
            L.ell(fx, fy, fx + 6, fy + 6, "rd2")
            L.ell(fx, fy, fx + 5, fy + 5, "rd4")
            L.p(fx + 1, fy + 1, "rd5")
            L.p(fx + 3, fy - 1, "wd1")


def seed_plate(L, x, y, w=14):
    """一盘瓜子（照麻将室）+ 几颗喜糖"""
    MJ.seed_plate(L, x, y, w)


def giftbox(L, x0, x1, ytop, hgt, dep, ramp="rd", ribbon="gd"):
    MJ.giftbox(L, x0, x1, ytop, hgt, dep, ramp, ribbon)


# ================================================================== 家具：椅子
def bamboo_v(L, x, y0, y1, w=3):
    """一根红木立柱：左亮右暗（照麻将室 bamboo_v，不画竹节）"""
    for y in range(int(y0), int(y1)):
        L.p(x, y, BAM[3] if w > 1 else BAM[2])
        if w > 1:
            L.p(x + 1, y, BAM[1] if w == 2 else BAM[2])
        if w > 2:
            L.p(x + 2, y, BAM[0])


def bamboo_h(L, x0, x1, y, h=3):
    for x in range(int(x0), int(x1)):
        L.p(x, y, BAM[3])
        if h > 1:
            L.p(x, y + 1, BAM[1] if h == 2 else BAM[2])
        if h > 2:
            L.p(x, y + 2, BAM[0])


CH_H, CH_SEAT = 50, 27      # 椅子：靠背顶高 50、座面高 27（座面照旧 22 ×1.25；靠背 ×1.25 是 57，人不放大，背对镜头坐的人会被整个挡住，降到 50）


def prop_chair(rect, facing, cushion="rd"):
    """红木靠背椅（照麻将室 prop_chair ×1.25）。facing：n 摆在桌北、人朝南（看见椅子正面）；s 摆在桌南、背对镜头
    （看见椅背后面，竹条中间留空）；w 摆在桌西朝东；e 摆在桌东朝西（侧面）。返回 (图层, 着地线)"""
    x0, f0, x1, f1 = rect
    L = sub(x0 - 3, f0 - CH_H - 4, x1 + 3, f1 + 2)
    st0, st1 = f0 - CH_SEAT, f1 - CH_SEAT

    def seat(a, b):
        L.rect(a, st0, b, st1, BAM[2])
        for y in range(st0, st1):
            if (y - st0) % 4 == 3:
                L.hl(a, b, y, BAM[1])
        L.hl(a, b, st0, BAM[3])

    def pad(a, b):
        if not cushion:
            return
        L.rect(a, st0 - 1, b, st1, rname(cushion, 3))
        L.hl(a + 1, b - 1, st0 - 1, rname(cushion, 4))
        L.vl(a, st0, st1, rname(cushion, 4))
        L.hl(a, b, st1 - 1, rname(cushion, 2))
        L.vl(b - 1, st0, st1, rname(cushion, 2))
        L.p((a + b) // 2, (st0 + st1) // 2, rname(cushion, 1))

    if facing == "n":
        a, b, back_y = x0, x1, f0
        bamboo_v(L, a + 1, back_y - CH_H + 2, back_y, 3)
        bamboo_v(L, b - 4, back_y - CH_H + 2, back_y, 3)
        for x in range(a + 1, b - 1):
            L.p(x, back_y - CH_H, BAM[3])
            L.p(x, back_y - CH_H + 1, BAM[2])
            L.p(x, back_y - CH_H + 2, BAM[2])
            L.p(x, back_y - CH_H + 3, BAM[0])
        L.p(a + 1, back_y - CH_H, BAM[2])
        for x in range(a + 6, b - 6, 4):
            bamboo_v(L, x, back_y - CH_H + 4, back_y - 33, 2)
        bamboo_h(L, a + 1, b - 1, back_y - 34, 3)
        seat(a, b)
        bamboo_h(L, a, b, st1, 3)
        pad(a + 2, b - 2)
        bamboo_v(L, a + 1, st1 + 3, f1, 3)
        bamboo_v(L, b - 4, st1 + 3, f1, 3)
        bamboo_h(L, a + 1, b - 1, f1 - 9, 2)
    elif facing == "s":
        a, b, back_y = x0, x1, f1
        bamboo_v(L, a + 3, st1 + 1, f0, 3)                 # 远处前腿（暗一档）
        bamboo_v(L, b - 6, st1 + 1, f0, 3)
        L.shade_rect(a, st1 + 1, b, f0, -1)
        seat(a + 1, b - 1)
        bamboo_h(L, a, b, st1, 3)
        bamboo_v(L, a, back_y - CH_H + 2, back_y, 3)       # 靠背立柱（离镜头最近）
        bamboo_v(L, b - 3, back_y - CH_H + 2, back_y, 3)
        for x in range(a, b):
            L.p(x, back_y - CH_H, BAM[3])
            L.p(x, back_y - CH_H + 1, BAM[2])
            L.p(x, back_y - CH_H + 2, BAM[2])
            L.p(x, back_y - CH_H + 3, BAM[0])
        L.p(a, back_y - CH_H, BAM[2])
        for x in (a + 7, a + 13, a + 19):
            if x < b - 4:
                bamboo_v(L, x, back_y - CH_H + 4, back_y - 33, 2)
        bamboo_h(L, a, b, back_y - 33, 3)
        bamboo_h(L, a + 3, b - 3, back_y - 10, 2)
    else:
        e = facing == "w"
        bx = x0 if e else x1 - 4
        fx = x1 - 4 if e else x0
        bamboo_v(L, bx, f0 - CH_H, f0, 3)                  # 远处一侧（暗一档）
        bamboo_v(L, fx, st0 + 2, f0, 3)
        L.shade_rect(x0, f0 - CH_H, x1, f0, -1)
        for y in range(f0 - CH_H + 2, st0 + 1):            # 靠背侧边
            for k in range(4):
                L.p(bx + k, y, BAM[2] if k in (1, 2) else BAM[1])
        seat(x0 + 1, x1 - 1)
        if cushion:
            ca, cb = (x0 + 4, x1 - 2) if e else (x0 + 2, x1 - 4)
            pad(ca, cb)
        bamboo_h(L, x0, x1, st1, 3)
        bamboo_v(L, bx, f1 - CH_H, f1, 3)                  # 近处一侧
        for x in range(bx - 1, bx + 4):
            L.p(x, f1 - CH_H, BAM[3])
            L.p(x, f1 - CH_H - 1, BAM[2])
        bamboo_v(L, fx, st1 + 3, f1, 3)
        bamboo_h(L, x0 + 1, x1 - 1, f1 - 9, 2)
    L.outline()
    return L, (f1 + 3 if facing == "s" else f1)


# ================================================================== 家具：牌桌
TILE_BACK = ("gd2", "gd3", "gd4")
TILE_FACE = ("wl3", "wl5", "wt")
TABLE_H = 45                # 桌高（旧 36 ×1.25）


def table_frame(L, rect, top_col=None):
    """方牌桌的木架子（照麻将室 prop_mj_table ×1.25）：后腿、牙板（中间一朵卷云）、方腿马蹄足、横枨、桌面木框"""
    x0, yf0, x1, yf1 = rect
    ty0, ty1 = yf0 - TABLE_H, yf1 - TABLE_H
    for lx in (x0 + 3, x1 - 7):
        L.rect(lx, ty1 + 4, lx + 4, yf0, "wd1")
    L.hl(x0 + 5, x1 - 5, yf0 - 8, "wd0")
    L.rect(x0, ty1 + 2, x1, ty1 + 9, "wd2")
    L.hl(x0, x1, ty1 + 2, "wd3")
    L.hl(x0 + 1, x1 - 1, ty1 + 8, "wd1")
    mx = (x0 + x1) // 2
    L.rect(mx - 5, ty1 + 6, mx + 6, ty1 + 11, "wd2")
    L.p(mx - 3, ty1 + 6, "wd4")
    L.p(mx + 3, ty1 + 6, "wd4")
    L.hl(mx - 4, mx + 5, ty1 + 10, "wd1")
    for lx in (x0, x1 - 5):
        L.rect(lx, ty1 + 2, lx + 5, yf1 - 3, "wd2")
        L.vl(lx, ty1 + 2, yf1 - 3, "wd3")
        L.vl(lx + 4, ty1 + 2, yf1 - 3, "wd1")
    for (a, b) in ((x0, x0 + 6), (x1 - 6, x1)):
        L.rect(a, yf1 - 3, b, yf1, "wd2")
        L.hl(a, b, yf1 - 3, "wd3")
    L.hl(x0 + 5, x1 - 5, yf1 - 12, "wd1")
    L.hl(x0 + 5, x1 - 5, yf1 - 13, "wd3")
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    L.hl(x0, x1, ty1 - 1, "wd4")
    L.hl(x0, x1, ty1, "wd4")
    L.hl(x0, x1, ty1 + 1, "wd2")
    L.hl(x0 + 3, x1 - 3, ty0 + 3, "wd2")
    L.vl(x0 + 3, ty0 + 3, ty1 - 3, "wd2")
    fx0, fy0, fx1, fy1 = x0 + 4, ty0 + 4, x1 - 4, ty1 - 4
    if top_col:
        a, b, c = top_col
        L.rect(fx0, fy0, fx1, fy1, b)
        L.hl(fx0, fx1, fy0, a)
        L.vl(fx0, fy0, fy1, a)
        L.hl(fx0 + 1, fx1, fy1 - 1, c)
        L.vl(fx1 - 1, fy0 + 1, fy1, c)
    return fx0, fy0, fx1, fy1


# 每张麻将桌打到哪、手牌、茶杯（三张以上各有点不一样）
# walls：北、南、西、东四面牌墙剩多长（0～1）；hands：哪几家立着手牌；cups：茶杯放哪几个角；gap：牌墙断开的一截
MJ_VAR = {
    "mahjong_1": dict(walls=(0.55, 1.0, 1.0, 0.6), hands="nwes", cups=("nw", "se"), gap=None),
    "mahjong_2": dict(walls=(1.0, 1.0, 1.0, 1.0), hands="nwes", cups=("ne", "sw"), gap=None),
    "mahjong_3": dict(walls=(1.0, 0.7, 0.5, 1.0), hands="nwe", cups=("nw", "ne"), gap="n"),
    "mahjong_4": dict(walls=(0.4, 0.85, 1.0, 0.35), hands="nwes", cups=("sw", "se"), gap="s"),
    "mahjong_5": dict(walls=(0.85, 1.0, 0.6, 0.9), hands="wes", cups=("ne",), gap=None),
    "mahjong_play": dict(walls=(1.0, 1.0, 1.0, 1.0), hands="nwe", cups=("nw", "ne", "sw", "se"), gap=None),
}


def prop_mj_table(name, rect):
    """四川麻将桌（照麻将室 ×1.25）：青绿绒面、四面牌墙（背面朝上两层摞着，只露金黄牌背和象牙白侧边），
    有人坐的那面立着一排手牌（北家牌背朝镜头；东西两家只露顶边侧边；南家朝他的那面画空白象牙白）；
    角上放盖碗茶。不画牌面、不画骰子、不画钱和筹码"""
    v = MJ_VAR[name]
    x0, yf0, x1, yf1 = rect
    L = sub(x0 - 3, yf0 - TABLE_H - 14, x1 + 3, yf1 + 2)
    fx0, fy0, fx1, fy1 = table_frame(L, rect, ("tl0", "tl", "tl2"))
    B0, B1, B2 = TILE_BACK
    I0, I1, I2 = TILE_FACE

    def shadow_px(x, y):
        if L.g(x, y) in (C["tl"], C["tl2"]):
            L.p(x, y, "tl0")

    def wall_h(xa, xb, y, gap=None):
        """横着的一面牌墙：顶上两行牌背、两行象牙白侧边、一行下层牌背；每 4 像素一摞"""
        for x in range(xa, xb):
            if gap and gap[0] <= x < gap[1]:
                continue
            sep = (x - xa) % 4 == 3
            L.p(x, y, B2 if not sep else B1)
            L.p(x, y + 1, B1 if not sep else B0)
            L.p(x, y + 2, I2 if not sep else I0)
            L.p(x, y + 3, I1 if not sep else I0)
            L.p(x, y + 4, B0)
            shadow_px(x + 1, y + 5)
        for y2 in range(y + 1, y + 5):
            shadow_px(xb, y2)

    def wall_v(x, ya, yb):
        """竖着的一面牌墙：从上看 4 像素宽的牌背，每 3 行一道缝（地面前后压扁）；南头露侧边"""
        for y in range(ya, yb):
            sep = (y - ya) % 3 == 2
            L.p(x, y, B2 if not sep else B1)
            L.p(x + 1, y, B1 if not sep else B0)
            L.p(x + 2, y, B1 if not sep else B0)
            L.p(x + 3, y, B0)
            shadow_px(x + 4, y + 1)
        L.hl(x, x + 4, yb, I2)
        L.hl(x, x + 4, yb + 1, I1)
        L.hl(x, x + 4, yb + 2, B0)
        for xx in range(x + 1, x + 5):
            shadow_px(xx, yb + 3)

    wn, ws, ww, we = v["walls"]
    xa, xb = fx0 + 9, fx1 - 9
    span = xb - xa
    ln = int(round(span * wn / 4.0)) * 4
    gap = (xb - ln + 8, xb - ln + 12) if v["gap"] == "n" else None
    wall_h(xb - ln, xb, fy0 + 5, gap)
    ln = int(round(span * ws / 4.0)) * 4
    gap = (xa + 12, xa + 16) if v["gap"] == "s" else None
    wall_h(xa, xa + ln, fy1 - 11, gap)
    ya, yb = fy0 + 8, fy1 - 12
    ln = max(3, int(round((yb - ya) * ww / 3.0)) * 3)
    wall_v(fx0 + 4, yb - ln, yb)
    ln = max(3, int(round((yb - ya) * we / 3.0)) * 3)
    wall_v(fx1 - 8, ya, ya + ln)
    hands = v["hands"]
    if "n" in hands:
        xa, xb = fx0 + 9, fx1 - 7
        for x in range(xa, xb):
            sep = (x - xa) % 4 == 3
            L.p(x, fy0, I2 if not sep else I0)
            L.p(x, fy0 + 1, B2 if not sep else B1)
            L.p(x, fy0 + 2, B1 if not sep else B0)
            L.p(x, fy0 + 3, B1 if not sep else B0)
            shadow_px(x + 1, fy0 + 4)
    if "w" in hands:
        for y in range(fy0 + 5, fy1 - 4):
            sep = (y - fy0 - 5) % 3 == 2
            L.p(fx0 + 1, y, I2 if not sep else I0)
            L.p(fx0 + 2, y, B1 if not sep else B0)
            shadow_px(fx0 + 3, y + 1)
        L.hl(fx0 + 1, fx0 + 3, fy1 - 4, B0)
    if "e" in hands:
        for y in range(fy0 + 5, fy1 - 4):
            sep = (y - fy0 - 5) % 3 == 2
            L.p(fx1 - 3, y, B2 if not sep else B1)
            L.p(fx1 - 2, y, I1 if not sep else I0)
        L.hl(fx1 - 3, fx1 - 1, fy1 - 4, B0)
    if "s" in hands:
        xa, xb = fx0 + 9, fx1 - 7
        for x in range(xa, xb):
            sep = (x - xa) % 4 == 3
            L.p(x, fy1 - 4, B1 if not sep else B0)
            L.p(x, fy1 - 3, I1 if not sep else I0)
            L.p(x, fy1 - 2, I1 if not sep else I0)
            L.p(x, fy1 - 1, I1 if not sep else I0)
    L.outline()
    ty0, ty1 = yf0 - TABLE_H, yf1 - TABLE_H
    spots = {"nw": (x0 - 1, ty0 - 3), "ne": (x1 - 10, ty0 - 3), "sw": (x0 - 1, ty1 - 8), "se": (x1 - 10, ty1 - 8)}
    for c in v["cups"]:
        cx, cy = spots[c]
        s = sub(cx - 1, cy - 2, cx + 13, cy + 11)
        gaiwan(s, cx, cy)
        paste_ol(L, s)
    lift_wood(L)
    return L, yf1


def er27_card(L, x, y, vert=True):
    """贰柒拾的一张字牌（窄长条）：米白底、右下一线暗边当厚度；不写字，只当牌背"""
    w, h = (3, 9) if vert else (9, 3)
    L.rect(x, y, x + w, y + h, "wl5")
    L.hl(x, x + w, y, "wt")
    L.vl(x + w - 1, y, y + h, "wl2")
    L.hl(x, x + w, y + h - 1, "wl2")
    L.p(x, y, "wt")


def prop_er27_table(name, rect, seed=0):
    """贰柒拾桌（四川长牌，只画不能玩）：红木方桌（跟麻将桌同一个木架子）、藏青桌布、
    桌上散着窄长的字牌（只画米白的长条，不写任何字）：中间一叠牌堆、四家面前各一把扇开的、几张随手搁着的。不画钱"""
    x0, yf0, x1, yf1 = rect
    L = sub(x0 - 3, yf0 - TABLE_H - 14, x1 + 3, yf1 + 2)
    fx0, fy0, fx1, fy1 = table_frame(L, rect, ("bl0", "bl1", "bl2"))
    for x in range(fx0 + 2, fx1 - 1, 4):                   # 桌布一圈金线小点
        L.p(x, fy0 + 2, "gd2")
        L.p(x, fy1 - 2, "gd2")
    L.outline()
    s = sub(fx0 - 4, fy0 - 4, fx1 + 4, fy1 + 4)
    cx, cy = (fx0 + fx1) // 2, (fy0 + fy1) // 2
    for k in range(3):                                      # 牌堆（横着摞，错开一像素）
        er27_card(s, cx - 5 + k, cy - 2 - k, vert=False)
    rnd = random.Random(seed)
    fans = {"n": [(cx - 9 + k * 4, fy0 - 2 - (k % 2)) for k in range(5)],
            "s": [(cx - 9 + k * 4, fy1 - 7 + (k % 2)) for k in range(5)]}
    for pts in fans.values():
        for (x, y) in pts:
            er27_card(s, x, y, vert=True)
    for k in range(4):                                      # 西家、东家：横着一把
        er27_card(s, fx0 - 2 + (k % 2), fy0 + 5 + k * 4, vert=False)
        er27_card(s, fx1 - 7 - (k % 2), fy0 + 6 + k * 4, vert=False)
    loose = [(cx + 7, cy + 1, "v"), (cx - 14, cy + 2, "h"), (cx + 2, cy - 8, "h"), (cx - 3, cy + 4, "v"),
             (cx + 11, cy - 7, "v")]
    rnd.shuffle(loose)
    for (x, y, k) in loose[: 3 + seed % 2]:
        er27_card(s, x, y, k == "v")
    s.outline()
    L.paste(s)
    # 一只盖碗（东北角桌沿）
    ty0 = yf0 - TABLE_H
    c = sub(x1 - 12, ty0 - 5, x1 + 2, ty0 + 9)
    gaiwan(c, x1 - 11, ty0 - 3)
    paste_ol(L, c)
    lift_wood(L)
    return L, yf1


def card_back(L, x, y, w=5, h=6):
    """扑克牌背（照麻将室，大一号 5×6）：白边、蓝底，不画牌面"""
    L.rect(x, y, x + w, y + h, "wt")
    L.rect(x + 1, y + 1, x + w - 1, y + h - 1, "bl1")
    if w > 3 and h > 3:
        L.rect(x + 1, y + 1, x + w - 2, y + h - 2, "bl2")


def prop_poker_table(rect):
    """炸金花圆桌（只画不能玩）：红木圆桌、红桌布垂一圈（褶子一明一暗、金边）；六家面前各三张扣着的牌背、中间一叠，
    两只盖碗。只画牌背（白边蓝底），不画牌面、钱、筹码、骰子"""
    x0, yf0, x1, yf1 = rect
    cx = (x0 + x1) // 2
    L = sub(x0 - 3, yf0 - TABLE_H - 12, x1 + 3, yf1 + 2)
    ty0, ty1 = yf0 - TABLE_H, yf1 - TABLE_H
    rx, ry = (x1 - x0) / 2.0, (yf1 - yf0) / 2.0
    tcy = (ty0 + ty1) / 2.0
    # 腿（桌布下面露出来四条，前两条亮、后两条暗）
    for (lx, yb, col) in ((cx - 22, yf0 + 12, "wd1"), (cx + 19, yf0 + 12, "wd1")):
        L.rect(lx, ty1, lx + 4, yb, col)
    for (lx, yb) in ((cx - 30, yf1 - 10), (cx + 26, yf1 - 10)):
        L.rect(lx, ty1, lx + 5, yb, "wd2")
        L.vl(lx, ty1, yb, "wd3")
        L.vl(lx + 4, ty1, yb, "wd1")
        L.rect(lx - 1, yb - 2, lx + 6, yb, "wd2")
        L.hl(lx - 1, lx + 6, yb - 2, "wd3")

    def ey(x):          # 桌面椭圆在 x 处的下沿
        d = (x + 0.5 - cx) / rx
        return tcy + ry * math.sqrt(max(0.0, 1 - d * d))

    # 垂下来的桌布：下沿 10 行，褶子一明一暗，金边
    for x in range(x0, x1):
        yb = ey(x)
        fold = (x - x0) % 7
        col = "rd3" if fold < 4 else "rd2"
        for y in range(int(yb) - 2, int(yb) + 10):
            L.p(x, y, col)
        L.p(x, int(yb) + 10, "gd2" if fold != 6 else "gd1")
        L.p(x, int(yb) + 9, "gd3" if fold < 4 else "gd2")
    # 桌面（红布），一圈金线、左上亮
    L.ell(x0, ty0, x1, ty1, "rd3")
    L.ell(x0 + 1, ty0 + 1, x1 - 1, ty1 - 1, "rd3")
    L.ring(x0, ty0, x1, ty1, "rd4", only=lambda x, y: x < cx + 6 and y < tcy + 4)
    L.ring(x0 + 4, ty0 + 3, x1 - 4, ty1 - 3, "gd2")
    for k in range(18):
        a = k * math.pi / 9
        L.p(cx + math.cos(a) * (rx - 8), tcy + math.sin(a) * (ry - 6), "gd3")
    L.outline()
    s = sub(x0 - 4, ty0 - 6, x1 + 4, ty1 + 4)
    icy = int(tcy)
    card_back(s, cx - 3, icy - 3, 7, 8)                    # 中间一叠（错开一层）+ 散着一张
    card_back(s, cx - 4, icy - 4, 7, 8)
    s.hl(cx - 3, cx + 4, icy + 5, "bl0")
    s.vl(cx + 3, icy - 3, icy + 5, "bl0")
    card_back(s, cx + 7, icy + 1, 5, 6)
    seats = [(-16, -1), (16, -1), (-27, 0.15), (27, 0.15), (-16, 1), (16, 1)]
    for (dx, side) in seats:
        if abs(dx) > 20:              # 西、东两家：牌扣在桌沿，横着三张
            bx = cx + (-int(rx) + 4 if dx < 0 else int(rx) - 11)
            for k in range(3):
                card_back(s, bx + (1 if k == 1 else 0), icy - 6 + k * 4, 6, 5)
        else:
            by = ty0 + 3 if side < 0 else ty1 - 10
            for k in range(3):
                card_back(s, cx + dx - 6 + k * 4, by - (1 if k == 1 else 0), 5, 6)
    s.outline()
    L.paste(s)
    for (gx, gy) in ((cx - 24, int(tcy) + 2), (cx + 12, int(tcy) - 12)):
        c = sub(gx - 1, gy - 2, gx + 13, gy + 11)
        gaiwan(c, gx, gy)
        paste_ol(L, c)
    lift_wood(L)
    return L, yf1


# ================================================================== 家具：北墙茶水台、茶叶柜
def prop_tea_bar(rect):
    """茶水台（靠北墙，照麻将室茶水柜的画法、草稿 150×100 大小）：红木柜身五格（三扇门两列抽屉、门心金团花、铜拉手），
    柜面一条红桌旗；上面从西到东：两只红暖水瓶、托盘一摞盖碗、长嘴铜壶、玻璃喜糖罐、一盘瓜子、两罐茶叶、一只竹壳暖水瓶"""
    x0, f0, x1, f1 = rect
    h = 54
    ty0, ty1 = f0 - h, f1 - h
    L = sub(x0 - 4, ty0 - 32, x1 + 4, f1 + 2)
    L.rect(x0, ty1, x1, f1 - 4, "wd2")
    for y, c in ((ty1, "wd4"), (ty1 + 1, "wd5"), (ty1 + 2, "wd3"), (ty1 + 3, "wd1")):
        L.hl(x0, x1, y, c)
    n = 5
    pw = (x1 - x0 - 4) / n
    for k in range(n):
        a = int(x0 + 2 + k * pw)
        b = int(x0 + 2 + (k + 1) * pw) - 2
        if k in (1, 3):
            for (ya, yb) in ((ty1 + 7, ty1 + 22), (ty1 + 24, f1 - 7)):
                L.rect(a, ya, b, yb, "wd3")
                L.hl(a, b, ya, "wd4")
                L.vl(a, ya, yb, "wd4")
                L.hl(a, b, yb - 1, "wd1")
                L.vl(b - 1, ya, yb, "wd1")
                cx = (a + b) // 2
                L.rect(cx - 3, (ya + yb) // 2, cx + 4, (ya + yb) // 2 + 1, "gd3")
                L.p(cx - 3, (ya + yb) // 2 - 1, "gd4")
        else:
            ya, yb = ty1 + 7, f1 - 7
            L.rect(a, ya, b, yb, "wd3")
            L.hl(a, b, ya, "wd4")
            L.vl(a, ya, yb, "wd4")
            L.hl(a, b, yb - 1, "wd1")
            L.vl(b - 1, ya, yb, "wd1")
            L.rect(a + 4, ya + 4, b - 4, yb - 4, "wd2")
            L.hl(a + 4, b - 4, ya + 4, "wd1")
            L.vl(a + 4, ya + 4, yb - 4, "wd1")
            L.hl(a + 4, b - 4, yb - 5, "wd4")
            cx, cy = (a + b) // 2, (ya + yb) // 2
            for (dx, dy) in ((-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)):
                L.p(cx + dx, cy + dy, "gd2" if dx + dy > 0 else "gd3")
            L.p(cx, cy, "gd4")
            L.rect(b - 7 if k < 2 else a + 5, cy + 5, (b - 7 if k < 2 else a + 5) + 2, cy + 7, "gd3")
    L.rect(x0, f1 - 4, x1, f1, "wd1")
    L.rect(x0 + 1, f1 - 4, x0 + 6, f1, "wd2")
    L.rect(x1 - 6, f1 - 4, x1 - 1, f1, "wd2")
    L.hl(x0, x1, f1 - 4, "wd0")
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    for k in range(6):
        L.hl(x0 + 88 + k * 2, x0 + 98 + k * 2, ty0 + 2 + k * 3, "wd4")
    ra, rb = x0 + 18, x1 - 18                               # 红桌旗
    L.rect(ra, ty0 + 4, rb, ty1, "rd3")
    L.hl(ra, rb, ty0 + 4, "rd4")
    L.hl(ra, rb, ty0 + 5, "gd3")
    L.hl(ra, rb, ty1 - 2, "gd3")
    for x in range(ra + 4, rb - 3, 7):
        L.p(x, (ty0 + ty1) // 2 + 1, "gd2")
    for y in range(ty1, ty1 + 7):
        L.hl(ra + 38, rb - 38, y, "rd3" if y < ty1 + 6 else "rd2")
    L.hl(ra + 38, rb - 38, ty1 + 5, "gd3")
    for tx in (ra + 38, rb - 39):
        L.vl(tx, ty1 + 7, ty1 + 12, "gd3")
        L.p(tx, ty1 + 12, "gd2")
    L.outline()
    base = ty0 + 11
    things = []

    def put(fn, args, box):
        s = sub(*box)
        fn(s, *args)
        things.append(s)

    put(thermos, (x0 + 10, base + 1, 25, "red"), (x0 + 3, base - 27, x0 + 19, base + 3))
    put(thermos, (x0 + 22, base + 3, 24, "red"), (x0 + 15, base - 23, x0 + 31, base + 5))

    def tray(s, x, b):
        s.rect(x, b - 4, x + 24, b, "wd5")
        s.hl(x, x + 24, b - 4, "wl3")
        s.hl(x, x + 24, b - 1, "wd3")
        gaiwan(s, x + 1, b - 12)
        gaiwan(s, x + 12, b - 11)
        s.ell(x + 13, b - 16, x + 22, b - 12, "wt")
        s.ell(x + 13, b - 18, x + 22, b - 14, "wt")
        s.hl(x + 14, x + 21, b - 14, "bl3")
    put(tray, (x0 + 37, base + 3), (x0 + 34, base - 20, x0 + 64, base + 5))
    put(MJ.copper_kettle, (x0 + 74, base + 1), (x0 + 48, base - 28, x0 + 92, base + 3))
    put(MJ.candy_jar, (x0 + 94, base), (x0 + 92, base - 17, x0 + 106, base + 2))
    put(seed_plate, (x0 + 107, base - 4, 14), (x0 + 105, base - 6, x0 + 124, base + 5))
    put(MJ.tea_canister, (x0 + 124, base + 1, "rd", "gd"), (x0 + 122, base - 12, x0 + 133, base + 3))
    put(MJ.tea_canister, (x0 + 132, base + 2, "gr", "gd"), (x0 + 130, base - 11, x0 + 141, base + 4))
    put(thermos, (x1 - 7, base + 1, 25, "bamboo"), (x1 - 14, base - 27, x1 + 2, base + 3))
    for s in things:
        paste_ol(L, s)
    lift_wood(L)
    return L, f1


def teapot(L, x, base, col="cl"):
    """紫砂壶（陶色）：扁圆壶身、盖钮、右边把、左边短嘴"""
    L.ell(x, base - 8, x + 12, base, rname(col, 1))
    L.ell(x + 1, base - 8, x + 11, base - 1, rname(col, 2))
    L.p(x + 3, base - 6, rname(col, 3))
    L.p(x + 4, base - 6, rname(col, 3))
    L.ell(x + 3, base - 10, x + 9, base - 6, rname(col, 1))
    L.p(x + 6, base - 11, rname(col, 2))
    L.line(x, base - 5, x - 3, base - 8, rname(col, 1))
    L.ring(x + 10, base - 8, x + 15, base - 2, rname(col, 0))


def prop_tea_cabinet(rect, mirror=False):
    """茶叶柜（靠北墙、照草稿 75×120）：红木高柜，顶上一道冠檐；上半截三层开格（多宝格）摆茶叶罐、紫砂壶、
    叠着的盖碗、一摞小礼盒；下半截两扇门（门心金团花、铜拉手）、底座"""
    x0, f0, x1, f1 = rect
    h = 100
    ty0, ty1 = f0 - h, f1 - h
    L = sub(x0 - 4, ty0 - 6, x1 + 4, f1 + 2)
    # 冠檐（顶面 + 往外挑一像素）
    L.rect(x0 - 1, ty0, x1 + 1, ty1, "wd3")
    L.hl(x0 - 1, x1 + 1, ty0, "wd5")
    L.vl(x0 - 1, ty0, ty1, "wd4")
    L.vl(x1, ty0, ty1, "wd2")
    for k in range(4):
        L.hl(x0 + 40 + k * 2, x0 + 46 + k * 2, ty0 + 3 + k * 3, "wd4")
    L.rect(x0 - 1, ty1, x1 + 1, ty1 + 5, "wd2")
    L.hl(x0 - 1, x1 + 1, ty1, "wd4")
    L.hl(x0 - 1, x1 + 1, ty1 + 4, "wd1")
    for x in range(x0 + 2, x1 - 1, 5):                      # 冠檐下一排小雕花（回纹点）
        L.p(x, ty1 + 2, "gd2")
    # 柜身
    body0 = ty1 + 5
    L.rect(x0, body0, x1, f1 - 5, "wd2")
    L.vl(x0, body0, f1 - 5, "wd3")
    L.vl(x1 - 1, body0, f1 - 5, "wd1")
    split = body0 + 54                                       # 上半截开格到这
    shelves = [body0 + 2, body0 + 19, body0 + 36, split]
    for k in range(3):
        a, b = shelves[k] + 1, shelves[k + 1] - 1
        # 每层分两格（多宝格，一大一小，左右交替）
        mid = x0 + (30 if (k % 2 == 0) != mirror else 44)
        for (ca, cb) in ((x0 + 3, mid), (mid + 3, x1 - 3)):
            L.rect(ca, a, cb, b, "wd0")
            L.hl(ca, cb, a, "ol")
            L.vl(ca, a, b, "wd0")
            L.rect(ca + 1, b - 3, cb, b, "wd1")              # 格子底板（往外一截亮）
            L.hl(ca, cb, b - 1, "wd4")
        L.hl(x0 + 1, x1 - 1, b, "wd4")
        L.hl(x0 + 1, x1 - 1, b + 1, "wd3")
    L.outline()
    things = []

    def put(fn, args, box):
        s = sub(*box)
        fn(s, *args)
        things.append(s)

    rows = [shelves[k + 1] - 2 for k in range(3)]
    order = [("can", "can2", "pot"), ("bowls", "box", "can"), ("pot", "can2", "can")]
    if mirror:
        order = [("pot", "can", "can2"), ("can", "bowls", "box"), ("can2", "can", "pot")]
    xs = (x0 + 6, x0 + 20, x0 + 52)
    for k in range(3):
        b = rows[k]
        for j, what in enumerate(order[k]):
            x = xs[j] if not mirror else (x0 + 6, x0 + 34, x0 + 50)[j]
            if what == "can":
                put(MJ.tea_canister, (x, b, "rd", "gd"), (x - 2, b - 13, x + 10, b + 2))
            elif what == "can2":
                put(MJ.tea_canister, (x, b, "bl", "gd"), (x - 2, b - 13, x + 10, b + 2))
            elif what == "pot":
                put(teapot, (x + 2, b), (x - 3, b - 13, x + 19, b + 2))
            elif what == "bowls":
                def bowls(s, x, b):
                    for i in range(3):
                        s.ell(x, b - 4 - i * 3, x + 10, b - i * 3, "wt")
                        s.hl(x + 1, x + 9, b - 2 - i * 3, "bl3")
                put(bowls, (x, b), (x - 2, b - 14, x + 12, b + 2))
            elif what == "box":
                def boxes(s, x, b):
                    giftbox(s, x, x + 13, b - 12, 6, 5)
                put(boxes, (x, b), (x - 2, b - 15, x + 15, b + 2))
    for s in things:
        paste_ol(L, s)
    # 下半截两扇门
    for (a, b) in ((x0 + 3, (x0 + x1) // 2 - 1), ((x0 + x1) // 2 + 1, x1 - 3)):
        ya, yb = split + 4, f1 - 8
        L.rect(a, ya, b, yb, "wd3")
        L.hl(a, b, ya, "wd4")
        L.vl(a, ya, yb, "wd4")
        L.hl(a, b, yb - 1, "wd1")
        L.vl(b - 1, ya, yb, "wd1")
        L.rect(a + 4, ya + 4, b - 4, yb - 4, "wd2")
        L.hl(a + 4, b - 4, ya + 4, "wd1")
        L.vl(a + 4, ya + 4, yb - 4, "wd1")
        L.hl(a + 4, b - 4, yb - 5, "wd4")
        cx, cy = (a + b) // 2, (ya + yb) // 2
        for (dx, dy) in ((-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, -2), (-2, 2), (2, 2)):
            L.p(cx + dx, cy + dy, "gd2" if dx + dy > 0 else "gd3")
        L.p(cx, cy, "gd4")
        hx = b - 2 if a < (x0 + x1) // 2 else a + 1
        L.rect(hx, cy - 2, hx + 1, cy + 3, "gd3")
    L.rect(x0, f1 - 5, x1, f1, "wd1")                       # 底座
    L.hl(x0, x1, f1 - 5, "wd3")
    L.rect(x0 + 1, f1 - 3, x0 + 7, f1, "wd2")
    L.rect(x1 - 7, f1 - 3, x1 - 1, f1, "wd2")
    lift_wood(L)
    return L, f1


# ================================================================== 家具：小几、长椅、记分板、绿植、宫灯
def prop_side_table(rect, items="fruit"):
    """小几（照麻将室小茶几的画法、草稿 50×55）：方几面、厚沿、牙板、四条腿；上面瓜子、果盘、盖碗"""
    x0, f0, x1, f1 = rect
    h = 30
    ty0, ty1 = f0 - h, f1 - h
    L = sub(x0 - 3, ty0 - 12, x1 + 3, f1 + 2)
    for lx in (x0 + 1, x1 - 5):
        L.rect(lx, ty1 + 4, lx + 4, f0 + 2, "wd1")
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd4")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    for k in range(4):
        L.hl(x0 + 26 + k * 2, x0 + 31 + k * 2, ty0 + 2 + k * 3, "wd4")
    L.rect(x0, ty1, x1, ty1 + 4, "wd2")
    L.hl(x0, x1, ty1, "wd5")
    L.hl(x0, x1, ty1 + 3, "wd1")
    L.rect(x0 + 4, ty1 + 4, x1 - 4, ty1 + 8, "wd2")
    L.hl(x0 + 4, x1 - 4, ty1 + 7, "wd1")
    for lx in (x0, x1 - 4):
        L.rect(lx, ty1 + 4, lx + 4, f1, "wd2")
        L.vl(lx, ty1 + 4, f1, "wd3")
        L.vl(lx + 3, ty1 + 4, f1, "wd1")
    L.hl(x0 + 4, x1 - 4, f1 - 7, "wd1")
    L.outline()
    s = sub(x0 - 2, ty0 - 10, x1 + 2, ty1 + 2)
    if items == "fruit":
        fruit_plate(s, x0 + 3, ty0 + 3, 18)
        seed_plate(s, x1 - 19, ty0 + 6, 15)
    elif items == "seeds":
        seed_plate(s, x0 + 3, ty0 + 7, 16)
        gaiwan(s, x1 - 15, ty0 + 2)
        gaiwan(s, x0 + 18, ty0 + 1)
    else:
        fruit_plate(s, x1 - 22, ty0 + 2, 18)
        gaiwan(s, x0 + 3, ty0 + 5)
    paste_ol(L, s)
    lift_wood(L)
    return L, f1


def prop_bench(rect):
    """长椅（看牌的人坐，照草稿 138×70）：红木靠背长椅，靠背朝镜头（人坐上去面朝屋里）——
    三根立柱、搭脑、一排竖靠背条（缝里看得见后面的座面）、下面座面沿、四条腿和横枨；座上搁一把蒲扇、一块红坐垫"""
    x0, f0, x1, f1 = rect
    L = sub(x0 - 3, f1 - 60, x1 + 3, f1 + 2)
    st0, st1 = f0 - CH_SEAT, f1 - CH_SEAT
    back_top = f1 - 48
    # 远处（北边）的腿，暗
    for lx in (x0 + 5, (x0 + x1) // 2, x1 - 8):
        bamboo_v(L, lx, st1 + 1, f0, 3)
    L.shade_rect(x0, st1 + 1, x1, f0, -1)
    # 座面（被靠背挡住大半，缝里看得见）
    L.rect(x0 + 1, st0, x1 - 1, st1, BAM[2])
    for y in range(st0, st1):
        if (y - st0) % 4 == 3:
            L.hl(x0 + 1, x1 - 1, y, BAM[1])
    L.hl(x0 + 1, x1 - 1, st0, BAM[3])
    L.rect(x0 + 30, st0 - 1, x0 + 60, st1, "rd3")           # 红坐垫
    L.hl(x0 + 31, x0 + 59, st0 - 1, "rd4")
    L.hl(x0 + 30, x0 + 60, st1 - 1, "rd2")
    s = sub(x1 - 34, st0 - 8, x1 - 10, st1 + 4)
    MJ.palm_fan(s, x1 - 24, st0 + 4)
    paste_ol(L, s)
    bamboo_h(L, x0, x1, st1, 3)
    # 靠背（离镜头最近）
    for px in (x0, (x0 + x1) // 2 - 1, x1 - 3):
        bamboo_v(L, px, back_top + 2, f1, 3)
    for x in range(x0, x1):
        L.p(x, back_top, BAM[3])
        L.p(x, back_top + 1, BAM[2])
        L.p(x, back_top + 2, BAM[2])
        L.p(x, back_top + 3, BAM[0])
    for x in range(x0 + 8, x1 - 5, 7):
        if abs(x - ((x0 + x1) // 2 - 1)) > 3:
            bamboo_v(L, x, back_top + 4, f1 - 33, 2)
    bamboo_h(L, x0, x1, f1 - 33, 3)
    bamboo_h(L, x0 + 3, x1 - 3, f1 - 10, 2)
    L.outline()
    return L, f1 + 3


def prop_board(rect):
    """立式记分小黑板（照草稿 62×100）：木画架三条腿、黑板木框、下沿粉笔槽搁两截粉笔；
    板上只有几道粉笔划痕（几组短竖道、一两道横线），不写字不写数"""
    x0, f0, x1, f1 = rect
    cx = (x0 + x1) // 2
    L = sub(x0 - 6, f1 - 104, x1 + 6, f1 + 2)
    top = f1 - 100
    L.line(cx, top + 6, cx + 2, f0, "wd1")                  # 后腿（暗）
    L.line(cx + 1, top + 6, cx + 3, f0, "wd0")
    for (fx, d) in ((x0 + 2, -1), (x1 - 3, 1)):              # 前两条腿往外撇
        L.line(cx + d * 14, top + 2, fx, f1 - 1, "wd3")
        L.line(cx + d * 14 + 1, top + 2, fx + 1, f1 - 1, "wd2")
    by0, by1 = top + 6, top + 50                            # 黑板
    bx0, bx1 = x0 + 4, x1 - 4
    L.rect(bx0, by0, bx1, by1, "wd3")
    L.hl(bx0, bx1, by0, "wd5")
    L.vl(bx0, by0, by1, "wd4")
    L.vl(bx1 - 1, by0, by1, "wd1")
    L.hl(bx0, bx1, by1 - 1, "wd1")
    L.rect(bx0 + 3, by0 + 3, bx1 - 3, by1 - 3, "ik2")
    L.rect(bx0 + 3, by0 + 3, bx1 - 3, by0 + 4, "ik1")
    L.vl(bx0 + 3, by0 + 3, by1 - 3, "ik1")
    for y in range(by0 + 5, by1 - 4):                       # 擦过的灰印子（棋盘点一小片）
        for x in range(bx0 + 20, bx0 + 34):
            if (x + y) % 2 == 0 and by0 + 20 < y < by0 + 30:
                L.p(x, y, "ik3")
    # 粉笔划痕：几道长短不一的斜道、一道波浪线、一道擦了一半的横线（不成字、不成数）
    for (gx, gy, ln, d) in ((bx0 + 6, by0 + 7, 7, -1), (bx0 + 10, by0 + 8, 6, -1), (bx0 + 14, by0 + 7, 7, -1),
                            (bx0 + 18, by0 + 9, 5, -1), (bx0 + 8, by0 + 24, 6, -1), (bx0 + 12, by0 + 25, 6, -1),
                            (bx0 + 36, by0 + 26, 6, -1)):
        for k in range(ln):
            L.p(gx + (k // 2) * d, gy + k, "wt" if k % 3 else "wl4")
    for x in range(bx0 + 16, bx1 - 9):
        L.p(x, by0 + 19 + (1 if (x // 3) % 2 else 0), "wl3")
    for x in range(bx0 + 6, bx1 - 16):
        if x % 5 != 0:
            L.p(x, by0 + 38, "wl3")
    L.rect(bx0 - 1, by1, bx1 + 1, by1 + 3, "wd3")           # 粉笔槽
    L.hl(bx0 - 1, bx1 + 1, by1, "wd5")
    L.hl(bx0 - 1, bx1 + 1, by1 + 2, "wd1")
    L.hl(bx0 + 8, bx0 + 13, by1 - 1, "wt")
    L.hl(bx0 + 22, bx0 + 26, by1 - 1, "pk2")
    L.outline()
    lift_wood(L)
    return L, f1


def prop_bamboo_plant(rect, seed=41):
    """观音竹（照麻将室 ×1.25）：一丛细竹竿、一片片窄叶，大陶盆，腰上一道红绸"""
    x0, f0, x1, f1 = rect
    cx = (x0 + x1) // 2
    L = sub(x0 - 14, f1 - 112, x1 + 14, f1 + 2)
    pot_top = f1 - 22
    rnd = random.Random(seed)
    stalks = [(-6, 88), (-2, 102), (1, 95), (5, 105), (8, 82), (-9, 72), (3, 78)]
    tips = []
    for (dx, hgt) in stalks:
        lean = dx * 0.12
        for k in range(hgt - 17):
            y = pot_top - k
            x = cx + dx + lean * k * 0.25
            L.p(x, y, "gr3" if dx < 2 else "gr2")
            L.p(x + 1, y, "gr1")
            if k % 11 == 5:
                L.p(x, y, "gr1")
                L.p(x + 1, y, "gr0")
        tips.append((cx + dx + lean * (hgt - 17) * 0.25, pot_top - (hgt - 17)))
    for (dx, hgt) in stalks:
        for k in range(5):
            yy = pot_top - (hgt - 17) + 5 + k * 11 + rnd.randrange(0, 5)
            if yy > pot_top - 14:
                continue
            xx = cx + dx + dx * 0.12 * (pot_top - yy) * 0.25
            for side in (-1, 1):
                ang = (-0.5 if side > 0 else -2.64) + rnd.uniform(-0.35, 0.35)
                leaf(L, xx + side * 5, yy + 1, 12, ang, 4, 3 if side < 0 else 2, vein=False)
    for (tx, ty) in tips:
        leaf(L, tx, ty - 4, 11, -1.57 + rnd.uniform(-0.3, 0.3), 4, 3, vein=False)
    for y in range(pot_top, f1):
        t = (y - pot_top) / float(f1 - pot_top)
        half = 13 - 3.5 * t
        xa, xb = int(cx + 0.5 - half + 0.5), int(cx + 0.5 + half - 0.5)
        L.hl(xa, xb + 1, y, "cl2")
        L.p(xa, y, "cl3")
        L.p(xa + 1, y, "cl3")
        L.p(xb, y, "cl0")
        L.p(xb - 1, y, "cl1")
    L.ell(cx - 14, pot_top - 4, cx + 15, pot_top + 5, "cl2")
    L.ring(cx - 14, pot_top - 4, cx + 15, pot_top + 5, "cl3", only=lambda x, y: y < pot_top or x < cx - 6)
    L.ell(cx - 11, pot_top - 2, cx + 12, pot_top + 3, "wd1")
    L.hl(cx - 9, cx + 10, pot_top - 1, "wd0")
    L.hl(cx - 12, cx + 13, pot_top + 9, "rd3")
    L.hl(cx - 12, cx + 13, pot_top + 10, "rd2")
    L.rect(cx + 4, pot_top + 8, cx + 9, pot_top + 13, "rd4")
    L.line(cx + 5, pot_top + 13, cx + 3, pot_top + 19, "rd3")
    L.line(cx + 8, pot_top + 13, cx + 10, pot_top + 19, "rd2")
    L.hl(cx - 9, cx + 10, f1 - 1, "cl0")
    L.outline()
    return L, f1


def prop_money_tree(rect, scale=1.25, seed=0):
    """发财树（照麻将室 ×1.25）：三根辫着的树干、一蓬蓬掌状叶，白瓷盆金口沿，树干上系红绸"""
    x0, f0, x1, f1 = rect
    cx = (x0 + x1) // 2
    s_ = scale
    L = sub(x0 - 20, f1 - int(100 * s_), x1 + 20, f1 + 2)
    pot_top = f1 - int(16 * s_)
    trunk = int(34 * s_)
    for y in range(pot_top - trunk, pot_top):
        k = pot_top - y
        for j, ph in enumerate((0, 2.1, 4.2)):
            x = cx + math.sin(k * 0.18 + ph) * 2.6
            L.p(x, y, ("wd3", "wd4", "wd2")[j])
            L.p(x + 1, y, "wd1" if j == 2 else "wd2")
    ry = pot_top - int(22 * s_)
    L.rect(cx - 4, ry, cx + 5, ry + 4, "rd3")
    L.hl(cx - 4, cx + 5, ry, "rd4")
    L.line(cx + 4, ry + 4, cx + 7, ry + 11, "rd3")
    L.line(cx + 2, ry + 4, cx + 1, ry + 12, "rd2")
    base = [(-8, 44, 2), (8, 46, 2), (0, 56, 3), (-10, 56, 3), (10, 58, 3), (1, 40, 2), (-3, 64, 3), (6, 66, 3)]
    clusters = [(cx + int(dx * s_), pot_top - int(dy * s_), lv) for (dx, dy, lv) in base]
    for (lx, ly, lv) in clusters:
        L.line(cx, pot_top - trunk, lx, ly, "wd2")
    for (lx, ly, lv) in clusters:
        for k in range(5):
            a = -math.pi / 2 + (k - 2) * 0.62
            leaf(L, lx + math.cos(a) * 6, ly + math.sin(a) * 5 + 2, int(9 * s_), a, int(4 * s_), lv, vein=False)
    for y in range(pot_top, f1):
        t = (y - pot_top) / float(f1 - pot_top)
        half = 10 * s_ - 2.5 * s_ * t
        xa, xb = int(cx - half + 0.5), int(cx + half - 0.5)
        L.hl(xa, xb + 1, y, "wt")
        L.p(xb, y, "sv1")
        L.p(xb - 1, y, "sv2")
        L.p(xa, y, "sv2")
    hw = int(11 * s_)
    L.ell(cx - hw, pot_top - 4, cx + hw, pot_top + 4, "gd3")
    L.ell(cx - hw + 2, pot_top - 2, cx + hw - 2, pot_top + 2, "wd1")
    L.hl(cx - hw + 2, cx + hw - 1, pot_top + 6, "gd2")
    L.hl(cx - hw + 3, cx + hw - 2, f1 - 3, "gd2")
    L.outline()
    return L, f1


def prop_palace_lamp(rect):
    """落地宫灯（照麻将室 ×1.25，100 高）：十字木底座、深木立杆、六角宫灯（金框、红纱三面透亮、上下金檐、垂红穗）"""
    x0, f0, x1, f1 = rect
    cx, foot = (x0 + x1) // 2, f1
    L = sub(cx - 16, foot - 106, cx + 17, foot + 2)
    L.rect(cx - 8, foot - 3, cx + 9, foot, "wd1")
    L.hl(cx - 8, cx + 9, foot - 3, "wd3")
    L.rect(cx - 3, foot - 7, cx + 4, foot - 2, "wd2")
    L.hl(cx - 3, cx + 4, foot - 7, "wd4")
    top = foot - 100
    L.rect(cx - 1, top + 30, cx + 2, foot - 6, "wd2")
    L.vl(cx - 1, top + 30, foot - 6, "wd4")
    L.vl(cx + 1, top + 30, foot - 6, "wd1")
    for ry in (top + 50, foot - 20):
        L.rect(cx - 3, ry, cx + 4, ry + 3, "gd2")
        L.hl(cx - 3, cx + 4, ry, "gd3")
    L.poly([(cx - 5, top), (cx + 6, top), (cx + 10, top + 5), (cx - 9, top + 5)], "gd2")
    L.hl(cx - 5, cx + 6, top, "gd4")
    L.hl(cx - 8, cx + 9, top + 4, "gd1")
    L.rect(cx - 1, top - 4, cx + 2, top, "gd3")
    by0, by1 = top + 5, top + 24
    L.rect(cx - 8, by0, cx + 9, by1, "rd3")
    L.rect(cx - 3, by0 + 1, cx + 4, by1 - 1, "rd5")
    L.rect(cx - 1, by0 + 4, cx + 2, by1 - 4, "gd4")
    L.rect(cx - 7, by0 + 1, cx - 4, by1 - 1, "rd4")
    L.rect(cx + 5, by0 + 1, cx + 8, by1 - 1, "rd2")
    for xx in (cx - 8, cx - 4, cx + 4, cx + 8):
        L.vl(xx, by0, by1, "gd2")
    L.vl(cx - 8, by0, by1, "gd3")
    L.poly([(cx - 9, by1), (cx + 10, by1), (cx + 6, by1 + 4), (cx - 5, by1 + 4)], "gd2")
    L.hl(cx - 9, cx + 10, by1, "gd3")
    for (tx, ln) in ((cx - 9, 9), (cx + 9, 9), (cx, 7)):
        for yy in range(by1 + 1, by1 + 1 + ln):
            L.p(tx, yy, "rd3")
        L.p(tx, by1, "gd3")
    L.outline()
    return L, foot


# ================================================================== 装饰区里的小东西（画进底图，人只站在它们前面）
def deco_coat_rack(cx, foot):
    """衣帽架（照麻将室 ×1.25，105 高）：车木立杆、三只脚、顶球、挂钩；挂一件深灰外套、一顶草帽、一条红围巾"""
    L = sub(cx - 22, foot - 112, cx + 22, foot + 2)
    top = foot - 105
    for d in (-1, 1):
        L.line(cx + d, foot - 11, cx + d * 10, foot - 1, "wd2")
        L.line(cx + d, foot - 10, cx + d * 10, foot, "wd1")
    L.rect(cx - 1, foot - 12, cx + 2, foot - 2, "wd2")
    L.rect(cx - 1, top + 6, cx + 2, foot - 10, "wd3")
    L.vl(cx - 1, top + 6, foot - 10, "wd5")
    L.vl(cx + 1, top + 6, foot - 10, "wd1")
    for ry in (top + 50, foot - 17):
        L.rect(cx - 2, ry, cx + 3, ry + 4, "wd3")
        L.hl(cx - 2, cx + 3, ry, "wd5")
        L.hl(cx - 2, cx + 3, ry + 3, "wd1")
    L.ell(cx - 4, top, cx + 5, top + 8, "wd3")
    L.p(cx - 1, top + 2, "wd5")
    for (dx, dy) in ((-8, 10), (9, 10), (-6, 17), (8, 17)):
        L.line(cx if dx < 0 else cx + 1, top + dy + 2, cx + dx, top + dy - 2, "wd2")
        L.p(cx + dx, top + dy - 3, "gd3")
    sx0 = cx + 5                                            # 红围巾
    L.rect(sx0, top + 10, sx0 + 5, top + 45, "rd3")
    L.vl(sx0, top + 10, top + 45, "rd4")
    L.vl(sx0 + 4, top + 12, top + 45, "rd2")
    for yy in range(top + 17, top + 45, 7):
        L.hl(sx0, sx0 + 5, yy, "rd2")
    for xx in range(sx0, sx0 + 5):
        L.p(xx, top + 45 + (xx % 2), "gd3")
    hx, hy = cx - 7, top + 9                                # 深灰外套
    L.poly([(hx - 1, hy + 1), (hx + 4, hy + 2), (hx + 6, hy + 10), (hx + 7, hy + 57), (hx - 15, hy + 60),
            (hx - 14, hy + 15), (hx - 10, hy + 5)], "ik2")
    L.poly([(hx - 1, hy + 2), (hx - 10, hy + 6), (hx - 12, hy + 15), (hx - 12, hy + 57), (hx - 6, hy + 57),
            (hx - 5, hy + 12)], "ik3")
    L.poly([(hx - 1, hy + 1), (hx + 4, hy + 2), (hx + 1, hy + 9), (hx - 3, hy + 6)], "ik1")
    L.vl(hx - 2, hy + 9, hy + 59, "ik1")
    for k in range(5):
        L.p(hx - 3, hy + 13 + k * 9, "sv1")
    for (px_, py_) in ((hx - 11, hy + 20), (hx - 11, hy + 40)):
        L.hl(px_, px_ + 6, py_, "ik1")
        L.hl(px_, px_ + 6, py_ - 1, "sv0")
    L.hl(hx - 15, hx + 7, hy + 59, "ik1")
    L.ell(cx - 11, top + 2, cx + 8, top + 11, "gd2")       # 草帽
    L.ell(cx - 10, top + 2, cx + 7, top + 10, "gd3")
    L.ell(cx - 6, top - 3, cx + 4, top + 6, "gd3")
    L.ell(cx - 5, top - 3, cx + 2, top + 4, "gd4")
    L.hl(cx - 6, cx + 4, top + 5, "rd3")
    for x in range(cx - 10, cx + 7, 2):
        L.p(x, top + 9, "gd1")
    L.outline()
    lift_wood(L)
    return L


def deco_thermos_bench(x0, x1, foot):
    """暖水瓶条凳（照麻将室 ×1.25）：一条矮木凳，上面一排暖水瓶（红的、竹壳的间着），凳脚边一只铁皮小水桶"""
    f0, f1 = foot - 15, foot
    h = 22
    ty0, ty1 = f0 - h, f1 - h
    L = sub(x0 - 4, ty0 - 32, x1 + 16, f1 + 2)
    for lx in (x0 + 2, x1 - 6):
        L.rect(lx, ty1 + 3, lx + 4, f0 + 1, "wd1")
    L.rect(x0, ty0, x1, ty1, "wd3")
    L.hl(x0, x1, ty0, "wd5")
    L.vl(x0, ty0, ty1, "wd4")
    L.vl(x1 - 1, ty0, ty1, "wd2")
    L.rect(x0, ty1, x1, ty1 + 4, "wd2")
    L.hl(x0, x1, ty1, "wd4")
    L.hl(x0, x1, ty1 + 3, "wd1")
    for lx in (x0, x1 - 4):
        L.rect(lx, ty1 + 4, lx + 4, f1, "wd2")
        L.vl(lx, ty1 + 4, f1, "wd3")
        L.vl(lx + 3, ty1 + 4, f1, "wd1")
    L.hl(x0 + 4, x1 - 4, f1 - 6, "wd1")
    L.outline()
    styles = ["red", "bamboo", "red", "red", "bamboo"]
    n = len(styles)
    for k, st in enumerate(styles):
        cx = x0 + 8 + int(k * (x1 - x0 - 16) / (n - 1))
        base = (ty0 + ty1) // 2 + 3 + (k % 2)
        t = sub(cx - 7, base - 28, cx + 9, base + 1)
        thermos(t, cx, base, tall=25 - (k % 2), style=st)
        paste_ol(L, t)
    b = sub(x1 + 1, f1 - 15, x1 + 15, f1 + 1)               # 铁皮小水桶
    bx = x1 + 2
    b.rect(bx, f1 - 11, bx + 11, f1, "sv1")
    b.vl(bx, f1 - 11, f1, "sv2")
    b.vl(bx + 10, f1 - 11, f1, "sv0")
    b.ell(bx, f1 - 13, bx + 11, f1 - 9, "sv0")
    b.ell(bx + 1, f1 - 12, bx + 10, f1 - 10, "bl3")
    b.hl(bx, bx + 11, f1 - 6, "sv0")
    b.line(bx, f1 - 12, bx + 5, f1 - 16, "ik2")
    b.line(bx + 10, f1 - 12, bx + 6, f1 - 16, "ik2")
    paste_ol(L, b)
    lift_wood(L)
    return L


def deco_fan(cx, foot):
    """落地扇（照麻将室 ×1.25，77 高）：圆底座、铝杆、奶白电机壳、铝网罩里三片淡蓝扇叶"""
    L = sub(cx - 18, foot - 82, cx + 18, foot + 2)
    L.ell(cx - 11, foot - 7, cx + 11, foot, "sv0")
    L.ell(cx - 11, foot - 8, cx + 11, foot - 1, "sv1")
    L.ell(cx - 7, foot - 7, cx + 4, foot - 4, "sv2")
    top = foot - 77
    L.rect(cx - 1, top + 32, cx + 1, foot - 5, "sv1")
    L.vl(cx - 1, top + 32, foot - 5, "sv2")
    L.rect(cx - 2, top + 42, cx + 2, top + 46, "sv0")
    L.ell(cx - 4, top + 17, cx + 9, top + 32, "wl4")
    L.ell(cx, top + 18, cx + 7, top + 27, "wl3")
    gcx, gcy = cx - 2, top + 16
    rx, ry = 14, 15
    g = sub(gcx - rx - 1, gcy - ry - 1, gcx + rx + 2, gcy + ry + 2)
    for k in range(3):
        a = -math.pi / 2 + k * 2 * math.pi / 3 + 0.4
        for t in range(2, 13):
            for wv in (-2.0, -1.0, 0, 1.0, 2.0):
                bx = gcx + math.cos(a) * t - math.sin(a) * wv * (0.6 + t * 0.12)
                by = gcy + math.sin(a) * t * 1.05 + math.cos(a) * wv * (0.6 + t * 0.12)
                g.p(bx, by, "bl3" if wv <= 0 else "bl2")
    g.ring(gcx - rx, gcy - ry, gcx + rx + 1, gcy + ry + 1, "sv1")
    g.ring(gcx - rx + 1, gcy - ry + 1, gcx + rx, gcy + ry, "sv0", only=lambda x, y: x > gcx + 4 or y > gcy + 4)
    g.ring(gcx - 9, gcy - 10, gcx + 10, gcy + 11, "sv1")
    for k in range(12):
        a = k * math.pi / 6
        for t in range(4, rx):
            if k % 2 == 0 or t > 8:
                g.p(gcx + 0.5 + math.cos(a) * t, gcy + 0.5 + math.sin(a) * t * ry / rx, "sv2" if k < 6 else "sv1")
    g.ell(gcx - 3, gcy - 3, gcx + 4, gcy + 4, "wl4")
    g.p(gcx - 1, gcy - 1, "wt")
    L.paste(g)
    L.outline()
    return L


def deco_cage_stand(cx, foot):
    """鸟笼架（照麻将室 ×1.25，107 高）：十字底座、木杆、横担，两头各挂一只竹鸟笼（借旧画法的鸟笼，原大小），一只搭着蓝布"""
    L = sub(cx - 28, foot - 114, cx + 28, foot + 2)
    L.rect(cx - 12, foot - 3, cx + 13, foot, "wd2")
    L.hl(cx - 12, cx + 13, foot - 3, "wd4")
    L.rect(cx - 3, foot - 8, cx + 4, foot - 2, "wd2")
    L.hl(cx - 3, cx + 4, foot - 8, "wd4")
    top = foot - 107
    L.rect(cx - 1, top, cx + 2, foot - 7, "wd3")
    L.vl(cx - 1, top, foot - 7, "wd5")
    L.vl(cx + 1, top, foot - 7, "wd1")
    L.rect(cx - 17, top, cx + 18, top + 4, "wd3")
    L.hl(cx - 17, cx + 18, top, "wd5")
    L.hl(cx - 17, cx + 18, top + 3, "wd1")
    L.ell(cx - 3, top - 4, cx + 4, top + 2, "wd3")
    L.p(cx - 1, top - 3, "wd5")
    L.line(cx - 1, top + 4, cx - 10, top + 13, "wd2")
    L.line(cx + 2, top + 4, cx + 11, top + 13, "wd2")
    for (dx, base, cover) in ((-14, foot - 52, False), (15, foot - 47, True)):
        s = sub(cx + dx - 10, base - 25, cx + dx + 11, base + 2)
        MJ.birdcage(s, cx + dx, base)
        if cover:
            for y in range(base - 19, base - 8):
                for x in range(cx + dx - 6, cx + dx + 8):
                    t = (y - (base - 19)) / 11.0
                    if x < cx + dx - 6 + (14 if t < 0.35 else 9 - int(t * 3)):
                        s.p(x, y, "bl2" if (x - cx - dx) < 2 else "bl1")
            s.hl(cx + dx - 6, cx + dx + 8, base - 19, "bl3")
        paste_ol(L, s)
        L.vl(cx + dx, top + 4, base - 21, "ik2")
    L.outline()
    lift_wood(L)
    return L


def deco_flower_stand(cx, foot):
    """高花几（照麻将室 ×1.25）：深红木四条细腿、下面一层隔板；上面一只青花梅瓶插红梅"""
    x0, x1 = cx - 10, cx + 10
    f0, f1 = foot - 10, foot
    h = 55
    ty0, ty1 = f0 - h, f1 - h
    L = sub(x0 - 20, ty0 - 60, x1 + 20, f1 + 2)
    for lx in (x0 + 1, x1 - 4):
        L.rect(lx, ty1 + 3, lx + 3, f0 + 1, "wd0")
    L.rect(x0 - 1, ty0, x1 + 1, ty1, "wd2")
    L.hl(x0 - 1, x1 + 1, ty0, "wd4")
    L.rect(x0 - 1, ty1, x1 + 1, ty1 + 4, "wd1")
    L.hl(x0 - 1, x1 + 1, ty1, "wd3")
    for lx in (x0, x1 - 3):
        L.rect(lx, ty1 + 4, lx + 3, f1, "wd1")
        L.vl(lx, ty1 + 4, f1, "wd2")
    L.rect(x0 + 1, f1 - 17, x1 - 1, f1 - 14, "wd2")
    L.hl(x0 + 1, x1 - 1, f1 - 17, "wd3")
    L.outline()
    s = sub(x0 - 18, ty0 - 58, x1 + 18, ty0 + 4)
    vb = (ty0 + ty1) // 2 + 1
    for y in range(vb - 25, vb):
        t = (y - (vb - 25)) / 25.0
        half = 2.5 + 6.5 * math.sin(math.pi * min(1.0, t * 1.35 + 0.08)) ** 0.8 - 1.9 * t
        xa, xb = int(cx + 0.5 - half + 0.5), int(cx + 0.5 + half - 0.5)
        s.hl(xa, xb + 1, y, "wt")
        s.p(xb, y, "bl3")
        s.p(xb - 1, y, "bl4")
        s.p(xa, y, "bl4")
        if (y - vb) % 6 == 0:
            s.hl(xa + 1, xb, y, "bl2")
    s.rect(cx - 1, vb - 29, cx + 2, vb - 25, "wt")
    s.p(cx + 1, vb - 28, "bl3")
    rnd = random.Random(9)
    branches = [((cx, vb - 29), (cx - 11, vb - 50), (cx - 16, vb - 55)), ((cx, vb - 29), (cx + 8, vb - 45), (cx + 15, vb - 52)),
                ((cx, vb - 29), (cx + 1, vb - 52), (cx - 4, vb - 57))]
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
    lift_wood(L)
    return L


def deco_gift_pile(x0, foot, wide=True):
    """礼盒堆（照麻将室喜糖台上的礼盒，放大一号的尺寸重画）：大的垫底、小的摞上去，红金两色、金丝带、蝴蝶结；没有字"""
    L = sub(x0 - 3, foot - 50, x0 + 70, foot + 2)
    if wide:
        giftbox(L, x0, x0 + 30, foot - 18, 12, 6)
        giftbox(L, x0 + 32, x0 + 58, foot - 16, 10, 6, "gd", "rd")
        giftbox(L, x0 + 4, x0 + 26, foot - 33, 9, 6, "gd", "rd")
        giftbox(L, x0 + 35, x0 + 54, foot - 29, 8, 5)
        giftbox(L, x0 + 8, x0 + 22, foot - 45, 7, 5)
    else:
        giftbox(L, x0, x0 + 28, foot - 18, 12, 6)
        giftbox(L, x0 + 3, x0 + 25, foot - 33, 9, 6, "gd", "rd")
        giftbox(L, x0 + 7, x0 + 21, foot - 45, 7, 5)
        giftbox(L, x0 + 30, x0 + 46, foot - 13, 8, 5, "rd", "gd")
    L.outline()
    return L


# ================================================================== 摆法（唯一的源）
DRAFT_ITEMS = {it["名字"]: it for it in json.load(open(DRAFT, encoding="utf-8"))["零件"]}


def mj_parts(cx, F):
    """方桌连四把椅子（Y01、Y02 一样）：旧麻将室桌椅间距 ×1.25，北边椅子跟桌子的空稍收一点（16）"""
    return {
        "table": [cx - 27, F - 65, cx + 27, F - 29],
        "chair_n": [cx - 14, F - 96, cx + 14, F - 81],
        "chair_w": [cx - 64, F - 56, cx - 37, F - 43],
        "chair_e": [cx + 37, F - 56, cx + 64, F - 43],
        "chair_s": [cx - 14, F - 13, cx + 14, F],
    }


def poker_parts(cx, F):
    """炸金花圆桌连六把椅子：北两把、南两把（背对镜头）、东西各一把"""
    return {
        "table": [cx - 36, F - 75, cx + 36, F - 27],
        "chair_nw": [cx - 32, F - 104, cx - 4, F - 89],
        "chair_ne": [cx + 4, F - 104, cx + 32, F - 89],
        "chair_w": [cx - 73, F - 57, cx - 46, F - 44],
        "chair_e": [cx + 46, F - 57, cx + 73, F - 44],
        "chair_sw": [cx - 32, F - 13, cx - 4, F],
        "chair_se": [cx + 4, F - 13, cx + 32, F],
    }


def draft_c(name):
    d = DRAFT_ITEMS[name]
    return d["x"] + d["w"] // 2, d["foot_y"]


# 调了的位置（相对草稿）：名字 → (中心 x, 着地线, 为什么)
ADJUST = {
    "tea_bar": (540, 174, "草稿着地线 235 离北墙 85 行（2 米多）像飘在屋中间；往北挪 61 贴墙，跟排法图上「挨着墙」的样子对上"),
    "cab_tea_w": (420, 170, "同茶水台：往北挪 65 贴墙"),
    "cab_tea_e": (660, 170, "同茶水台：往北挪 65 贴墙"),
}


SIZE_NOTE = {
    "Y01": "宽照草稿（131，草稿 140）；高 148 比草稿 120 多：桌椅按旧麻将室 ×1.25 画，北边那把椅背往上冒出草稿框 27，着地线不变",
    "Y02": "同 Y01",
    "Y03": "宽 149（草稿 160）；高 156 比草稿 130 多：北边两把椅背往上冒出草稿框 25，着地线不变",
    "Y04": "大小照草稿；着地线往北挪了 61（见「调了」）",
    "Y05": "大小照草稿；着地线往北挪了 65（见「调了」）",
    "Y06": "照草稿（高 50，草稿 55）",
    "Y07": "长照草稿；靠背跟椅子一样降到 48 高，整件高 50（草稿 70）——背对镜头坐的人才露得出头",
    "Y08": "照草稿",
    "Y09": "照草稿（观音竹按旧 86 ×1.25 = 107；门口发财树画成同样高）",
    "Y10": "宫灯按旧 80 ×1.25 画成 100 高、22 宽（草稿 30×82 没乘 1.25）；着地线不变",
}


def build_plan():
    """出零件清单：(id, 编号, 组名, 占地 rect, 画法)；还有每组的草稿框"""
    parts = []
    for name in ("mahjong_1", "mahjong_2", "mahjong_3", "mahjong_4", "mahjong_5", "mahjong_play"):
        cx, F = draft_c(name)
        P = mj_parts(cx, F)
        parts.append((name + "_table", "Y01", name, P["table"], lambda r, n=name: prop_mj_table(n, r)))
        for side in "nwes":
            parts.append((name + "_chair_" + side, "Y01", name, P["chair_" + side], lambda r, s=side: prop_chair(r, s)))
    for k, name in enumerate(("er27_1", "er27_2")):
        cx, F = draft_c(name)
        P = mj_parts(cx, F)
        parts.append((name + "_table", "Y02", name, P["table"], lambda r, s=k: prop_er27_table("", r, seed=s)))
        for side in "nwes":
            parts.append((name + "_chair_" + side, "Y02", name, P["chair_" + side], lambda r, s=side: prop_chair(r, s)))
    cx, F = draft_c("poker")
    P = poker_parts(cx, F)
    parts.append(("poker_table", "Y03", "poker", P["table"], prop_poker_table))
    for key, facing in (("chair_nw", "n"), ("chair_ne", "n"), ("chair_w", "w"), ("chair_e", "e"), ("chair_sw", "s"), ("chair_se", "s")):
        parts.append(("poker_" + key, "Y03", "poker", P[key], lambda r, f=facing: prop_chair(r, f)))
    cx, F = ADJUST["tea_bar"][:2]
    parts.append(("tea_bar", "Y04", "tea_bar", [cx - 73, F - 22, cx + 73, F], prop_tea_bar))
    for name, mirror in (("cab_tea_w", False), ("cab_tea_e", True)):
        cx, F = ADJUST[name][:2]
        parts.append((name, "Y05", name, [cx - 36, F - 18, cx + 36, F], lambda r, m=mirror: prop_tea_cabinet(r, m)))
    for name, items in (("side_w", "fruit"), ("side_e", "seeds"), ("side_mid_w", "seeds"), ("side_mid_e", "fruit2")):
        cx, F = draft_c(name)
        parts.append((name, "Y06", name, [cx - 23, F - 18, cx + 23, F], lambda r, i=items: prop_side_table(r, i)))
    for name in ("bench_w", "bench_e"):
        cx, F = draft_c(name)
        parts.append((name, "Y07", name, [cx - 68, F - 18, cx + 68, F], prop_bench))
    cx, F = draft_c("board")
    parts.append(("board", "Y08", "board", [cx - 28, F - 14, cx + 28, F], prop_board))
    for name in ("plant_nw", "plant_ne"):
        cx, F = draft_c(name)
        parts.append((name, "Y09", name, [cx - 14, F - 16, cx + 14, F],
                      lambda r, s=(41 if name == "plant_nw" else 43): prop_bamboo_plant(r, s)))
    for name in ("plant_door_w", "plant_door_e"):
        cx, F = draft_c(name)
        parts.append((name, "Y09", name, [cx - 14, F - 16, cx + 14, F], lambda r: prop_money_tree(r, 1.2)))
    for name in ("lamp_1", "lamp_2", "lamp_3"):
        cx, F = draft_c(name)
        parts.append((name, "Y10", name, [cx - 8, F - 8, cx + 8, F], prop_palace_lamp))
    return parts


# 人站坐的点
SIT_LIFT = 71           # 坐着的人头顶离脚点多高（旧 66，座面高了 5）
FACE = {"n": ("down", 0), "s": ("up", 12), "w": ("right", 8), "e": ("left", 4)}


def seats(parts):
    out = []
    for (pid, code, grp, r, fn) in parts:
        if "_chair_" not in pid:
            continue
        side = pid.split("_chair_")[1]
        facing = {"nw": "n", "ne": "n", "sw": "s", "se": "s"}.get(side, side)
        face, frame = FACE[facing]
        x = (r[0] + r[2]) // 2
        y = r[3] + 2
        who = "player" if (grp == "mahjong_play" and side == "s") else "npc"
        out.append({"id": "seat_" + pid.replace("_chair_", "_"), "table": grp, "chair": pid, "side": side,
                    "x": x, "y": y, "face": face, "frame": frame, "who": who})
    for b in ("bench_w", "bench_e"):            # 长椅上三个座（背对镜头、面朝屋里）
        cx, F = draft_c(b)
        for k, dx in enumerate((-40, 0, 40)):
            out.append({"id": "seat_%s_%d" % (b, k + 1), "table": b, "chair": b, "side": "s", "x": cx + dx, "y": F + 1,
                        "face": "up", "frame": 12, "who": "npc"})
    return out


ENTRY = (540, 1440)     # 进门站的点（门里、地垫上，朝北）
POINTS = [
    {"id": "door_in", "名字": "进门站的点（门里地垫上，朝上）", "x": ENTRY[0], "y": ENTRY[1], "face": "up"},
    {"id": "door_out", "名字": "出门的点（门外走廊）", "x": 540, "y": 1535, "face": "down"},
    {"id": "tea_bar_front", "名字": "茶水台跟前（倒茶）", "x": 540, "y": 190, "face": "up"},
    {"id": "board_front", "名字": "记分板跟前", "x": 100, "y": 646, "face": "left"},
]
DOORMAT = (492, 1414, 588, 1452)
DECO_ZONES = [
    {"id": "deco_north", "名字": "贴北墙一条（衣帽架、落地扇、暖水瓶条凳、礼盒堆、高花几、鸟笼架）", "rect": [SIDE, FLOOR_Y, W - SIDE, 184]},
    {"id": "deco_nw", "名字": "西北角（大盆观音竹）", "rect": [SIDE, FLOOR_Y, 92, 254]},
    {"id": "deco_ne", "名字": "东北角（大盆观音竹）", "rect": [988, FLOOR_Y, W - SIDE, 254]},
    {"id": "deco_sw", "名字": "西南角（礼盒堆）", "rect": [SIDE, 1384, 80, WALK_Y1 + 2]},
    {"id": "deco_se", "名字": "东南角（发财树）", "rect": [1000, 1384, W - SIDE, WALK_Y1 + 2]},
]


# ================================================================== 组装
def decorations():
    """装饰区里加的东西：(名字, 图层, 着地线 rect 用来画影)"""
    D = []
    D.append(("衣帽架（西北，窗西边）", deco_coat_rack(120, 176), (110, 166, 132, 176)))
    D.append(("落地扇（西窗下）", deco_fan(258, 178), (248, 170, 270, 178)))
    D.append(("暖水瓶条凳 + 小水桶（茶叶柜西边）", deco_thermos_bench(300, 360, 176), (300, 161, 375, 176)))
    D.append(("礼盒堆（茶叶柜东边）", deco_gift_pile(708, 178, True), (708, 166, 766, 178)))
    D.append(("高花几插红梅（东窗下）", deco_flower_stand(806, 178), (796, 168, 816, 178)))
    D.append(("鸟笼架（东北，窗东边）", deco_cage_stand(962, 176), (950, 170, 975, 176)))
    D.append(("礼盒堆（西南角）", deco_gift_pile(22, 1452, False), (22, 1440, 68, 1452)))
    sl, _ = prop_money_tree([1018, 1436, 1046, 1452], 1.15)
    D.append(("发财树（东南角）", sl, (1018, 1440, 1046, 1452)))
    return D


TABLE_GROUPS = ["mahjong_1", "mahjong_2", "mahjong_3", "mahjong_4", "mahjong_5", "mahjong_play", "er27_1", "er27_2", "poker"]


def background(parts, decos):
    L = Layer(x0=0, y0=0, w=W, h=H)
    L.rect(0, 0, W, H, "void")
    draw_floor(L, 0, W, FLOOR_Y, WALL_S + 45)
    draw_doormat(L, *DOORMAT)
    # 地上的明暗：墙脚影、家具贴地影、桌上头的灯照一圈、宫灯脚下一圈、门口进来的光
    S = ShadeMap()
    S.rect(SIDE, FLOOR_Y, W - SIDE, FLOOR_Y + 3, -1.5)
    S.rect(SIDE, FLOOR_Y + 3, W - SIDE, FLOOR_Y + 7, -0.5)
    S.rect(SIDE, FLOOR_Y, SIDE + 8, WALL_S, -1.0)
    S.rect(SIDE + 8, FLOOR_Y, SIDE + 12, WALL_S, -0.5)
    S.rect(W - SIDE - 3, FLOOR_Y, W - SIDE, WALL_S, -0.5)
    S.rect(SIDE, WALL_S - 4, DOOR[0], WALL_S, -0.5)
    S.rect(DOOR[1], WALL_S - 4, W - SIDE, WALL_S, -0.5)
    for (pid, code, grp, r, fn) in parts:
        x0, y0, x1, y1 = r
        if pid.endswith("_table"):
            S.rect(x0, y0 + 3, x1, y1, -1.5, feather=1)
        elif code in ("Y09", "Y10"):
            S.ellipse((x0 + x1) / 2 + 2, y1 - 2, (x1 - x0) / 2 + 3, 5, -1.5)
        else:
            S.rect(x0 + 1, y0 + 1, x1 + 2, y1 + 2, -2.0 if code in ("Y04", "Y05", "Y07") else -1.5, feather=1)
    for (nm, dl, r) in decos:
        S.rect(r[0] + 1, r[1] + 1, r[2] + 2, r[3] + 2, -1.5, feather=1)
    for grp in TABLE_GROUPS:
        cx, F = draft_c(grp)
        if grp == "poker":
            S.ellipse(cx, F - 51, 74, 48, 1.0, edge=2.5)
        else:
            S.ellipse(cx, F - 47, 66, 44, 1.0, edge=2.5)
    for (pid, code, grp, r, fn) in parts:
        if code == "Y10":
            S.ellipse((r[0] + r[2]) / 2, r[3] - 3, 22, 11, 1.0)
    S.cone(540, WALL_S - 1, 1372, 52, 0.30, 1.0)
    S.cone(540, 1372, 1356, 74, 0.30, 0.5)
    S.apply(L, clip=lambda x, y: FLOOR_Y <= y < WALL_S and SIDE <= x < W - SIDE)
    draw_north_wall(L)
    draw_window(L, 150, 26, 290, 82)
    draw_window(L, 790, 26, 930, 82)
    pt = moved(MJ.draw_painting, (834, 124, 912, 172), 502 - 838, 30 - 127)   # 熊猫翠竹挂画（旧画原大小平移，没题字没印章）
    L.paste(pt)
    draw_swag(L)
    for kx in LANTERNS:
        draw_lantern(L, kx, 28)
    for (kx, ky) in ((60, 30), (1020, 30)):                 # 两头墙角各挂一只大红中国结（旧画法原大小，平移）
        L.paste(moved(MJ.draw_knot, (kx - 10, 118, kx + 11, 160), 0, 22 - 121, kx, 124))
    draw_round_fan(L, 363, 62)
    draw_round_fan(L, 717, 62)
    # 灯笼照亮墙纸一圈、花窗透光照亮窗下护墙板一点
    S2 = ShadeMap()
    for kx in LANTERNS:
        S2.ellipse(kx, 40, 16, 18, 1.0)
    S2.apply(L, clip=lambda x, y: CAP1 < y < FLOOR_Y and RAMP_OF.get(L.g(x, y), ("",))[0] in ("wl",))
    for (nm, dl, r) in sorted(decos, key=lambda d: d[2][3]):
        L.paste(dl)
    draw_south_wall(L)
    draw_side_walls(L)
    return L


def build():
    parts = build_plan()
    decos = decorations()
    bg = background(parts, decos)
    props = []
    for (pid, code, grp, r, fn) in parts:
        layer, foot = fn(r)
        props.append({"id": pid, "code": code, "group": grp, "rect": r, "layer": layer, "foot": foot})
    side = Layer(x0=0, y0=0, w=W, h=S_FACE)
    draw_side_walls(side)
    side_l = sub(0, 0, W, S_FACE)
    side_l.im = side.im
    side_l.px = side_l.im.load()
    props.append({"id": "side_walls", "code": "墙", "group": "side_walls", "rect": [0, 0, W, S_FACE], "layer": side_l,
                  "foot": H + 100})
    return bg, props, parts, decos


# ================================================================== 人、预览
def standin(code, frame, sit=None):
    im = Image.open(CHAR_DIR + "chr_LM-GUEST-%s.png" % code).convert("RGBA")
    return im.crop((frame * 64, 0, frame * 64 + 64, 84))


def sit_rows(seat, parts_by):
    """坐着的人只留上面几行：坐北的留到桌面后沿往下 5 行；其余留到座面上 4 行"""
    top = seat["y"] - SIT_LIFT
    if seat["side"] in ("n", "nw", "ne"):
        r = parts_by[seat["table"] + "_table"][3]
        return (r[1] - TABLE_H + 5) - top
    return (seat["y"] - 23) - top


def person_sprites(people, parts_by):
    out = []
    for p in people:
        im = standin(p["code"], p["frame"])
        if p.get("seat"):
            s = p["seat"]
            rows = sit_rows(s, parts_by)
            im = im.crop((0, 0, 64, rows))
            out.append((im, s["x"] - 32, s["y"] - SIT_LIFT, s["y"], False))
        else:
            out.append((im, p["x"] - 32, p["y"] - 84 + 1, p["y"], True))
    return out


def compose(bg, props, people=(), parts_by=None):
    base = bg.im.copy()
    sprites = person_sprites(people, parts_by) if people else []
    if sprites:
        b2 = Layer(x0=0, y0=0, w=W, h=H)
        b2.im = base
        b2.px = base.load()
        S = ShadeMap()
        for (im, x, y, foot, standing) in sprites:
            if standing:
                S.ellipse(x + 33, foot - 1, 13, 4, -1.5)
        S.apply(b2)
    items = [(p["foot"], 0, k, p) for k, p in enumerate(props)]
    items += [(s[3], 1, k, s) for k, s in enumerate(sprites)]
    items.sort(key=lambda t: (t[0], t[1], t[2]))
    for foot, kind, k, obj in items:
        if kind == 0:
            base.alpha_composite(obj["layer"].im, (obj["layer"].ox, obj["layer"].oy))
        else:
            base.alpha_composite(obj[0], (obj[1], obj[2]))
    return base


def phone_shot(img, center):
    """手机一屏 540×960：镜头跟人、卡在画布边"""
    cx, cy = center
    x0 = max(0, min(W - 540, cx - 270))
    y0 = max(0, min(H - 960, cy - 480))
    return img.crop((x0, y0, x0 + 540, y0 + 960)), (x0, y0)


# ================================================================== 检查
def colors_of(im):
    cols = set()
    for c in im.getdata():
        if c[3] == 255:
            cols.add(c[:3])
        elif c[3] != 0:
            raise SystemExit("有半透明像素：%s" % (c,))
    return cols


def felt_check(props):
    """麻将桌绒面里只许有绒面三档、牌背金黄、牌侧象牙白、描边、盖碗青白（只在四个角）；扑克桌面只许红布、金、牌背白蓝、盖碗"""
    ok = {C[n] for n in ("tl0", "tl", "tl2", "gd0", "gd1", "gd2", "gd3", "gd4", "wl3", "wl5", "wt", "ol")}
    cup = {C[n] for n in ("bl2", "bl4", "wt", "ol")}
    for p in props:
        if not (p["group"].startswith("mahjong") and p["id"].endswith("_table")):
            continue
        x0, yf0, x1, yf1 = p["rect"]
        ty0, ty1 = yf0 - TABLE_H, yf1 - TABLE_H
        for y in range(ty0 + 4, ty1 - 4):
            for x in range(x0 + 4, x1 - 4):
                c = p["layer"].g(x, y)
                corner = (x < x0 + 12 or x >= x1 - 12) and (y < ty0 + 10 or y >= ty1 - 11)
                if c[3] and c not in ok and not (corner and c in cup):
                    raise SystemExit("牌面检查没过：%s (%d,%d) %s" % (p["id"], x, y, c))
    ok_p = {C[n] for n in ("rd2", "rd3", "rd4", "gd1", "gd2", "gd3", "bl0", "bl1", "bl2", "bl4", "wt", "ol")}
    for p in props:
        if p["id"] != "poker_table":
            continue
        x0, yf0, x1, yf1 = p["rect"]
        for y in range(yf0 - TABLE_H, yf1 - TABLE_H):
            for x in range(x0, x1):
                c = p["layer"].g(x, y)
                if c[3] and c not in ok_p:
                    raise SystemExit("扑克桌检查没过 (%d,%d) %s" % (x, y, c))
    print("牌面检查：麻将桌只有金黄牌背、象牙白侧边和空白面，角上盖碗；炸金花桌只有扑克牌背（白边蓝底），没有牌面、钱、筹码、骰子")


def walk_check(parts, seats_, points):
    """从门口走得到每个坐点、每个站点吗：2 像素一格，人按脚底 12×6 算；挡人的 = 家具占地 + 装饰区 + 墙"""
    step = 2
    blocks = [p[3] for p in parts] + [z["rect"] for z in DECO_ZONES]

    def free(x, y, goal=None):
        in_room = SIDE + 6 <= x <= W - SIDE - 6 and FLOOR_Y + 4 <= y <= WALK_Y1
        in_door = DOOR[0] + 10 <= x <= DOOR[1] - 10 and WALK_Y1 < y <= H - 6
        if not (in_room or in_door):
            return False
        for (x0, y0, x1, y1) in blocks:
            if x0 - 6 < x < x1 + 6 and y0 - 3 < y < y1 + 3:
                return False
        return True
    start = (540, 1530)
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
    for s in seats_:
        # 坐点在椅子上：看椅子四周有没有一格走得到（人走到椅子边坐下）
        r = [p for p in parts if p[0] == s["chair"]][0][3]
        ring = [(x, r[3] + 4) for x in range(r[0] - 8, r[2] + 9, 2)] + [(x, r[1] - 4) for x in range(r[0] - 8, r[2] + 9, 2)] + \
               [(r[0] - 8, y) for y in range(r[1], r[3] + 5, 2)] + [(r[2] + 8, y) for y in range(r[1], r[3] + 5, 2)]
        if not any(((a // 2) * 2, (b // 2) * 2) in seen for (a, b) in ring):
            bad.append(s["id"])
    for p in points:
        if ((p["x"] // 2) * 2, (p["y"] // 2) * 2) not in seen:
            bad.append(p["id"])
    print("走路检查：%d 个坐点、%d 个站点%s" % (len(seats_), len(points), "全走得到" if not bad else "，走不到：" + "、".join(bad)))
    return bad


def crop_alpha(layer):
    box = layer.im.getbbox()
    return layer.im.crop(box), layer.ox + box[0], layer.oy + box[1]


# ================================================================== 主程序
def main():
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    bg, props, parts, decos = build()
    parts_by = {p[0]: p for p in parts}
    felt_check(props)
    seats_ = seats(parts)
    bad = walk_check(parts, seats_, POINTS)
    # 颜色：底图 + 全部家具合起来
    allc = colors_of(bg.im)
    crops = {}
    for p in props:
        im, x, y = crop_alpha(p["layer"])
        crops[p["id"]] = (im, x, y)
        allc |= colors_of(im)
    print("颜色：底图 + 全部家具合起来 %d 种" % len(allc))
    if len(allc) > 64:
        raise SystemExit("颜色超过 64 种")
    names = {}
    for k, v in C.items():
        names.setdefault(v[:3], k)
    unknown = [c for c in allc if c not in names]
    if unknown:
        raise SystemExit("有不在调色板里的颜色：%s" % unknown[:5])
    # 出图
    bg.im.save(os.path.join(OUT, "room.png"))
    for f in os.listdir(os.path.join(OUT, "props")):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, "props", f))
    man_props = []
    for p in props:
        im, x, y = crops[p["id"]]
        im.save(os.path.join(OUT, "props", p["id"] + ".png"))
        man_props.append({"id": p["id"], "编号": p["code"], "组": p["group"], "png": "props/%s.png" % p["id"],
                          "x": x, "y": y, "w": im.width, "h": im.height, "foot": p["foot"],
                          "占地": p["rect"] if p["id"] != "side_walls" else None})
    # 每组跟草稿比
    groups = []
    for name, d in DRAFT_ITEMS.items():
        mine = [mp for mp in man_props if mp["组"] == name]
        gx0 = min(m["x"] for m in mine)
        gy0 = min(m["y"] for m in mine)
        gx1 = max(m["x"] + m["w"] for m in mine)
        gy1 = max(m["y"] + m["h"] for m in mine)
        foot = max(max(m["占地"][3] for m in mine), 0)
        note = ADJUST[name][2] if name in ADJUST else ""
        groups.append({"名字": name, "编号": d["编号"], "放什么": d["放什么"],
                       "草稿": {"x": d["x"], "y": d["y"], "w": d["w"], "h": d["h"], "foot_y": d["foot_y"]},
                       "实际": {"x": gx0, "y": gy0, "w": gx1 - gx0, "h": gy1 - gy0, "foot_y": foot},
                       "零件": [m["id"] for m in mine], "调了": note, "大小": SIZE_NOTE[d["编号"]]})
    man = {
        "说明": "娱乐室代码画 v1（庄Z4 10/5 晚，tools/pixel_art/room_entertainment.py 出）。画布 1080×1560，1 倍、不插值；"
               "background 是底图（墙、地板、地垫、装饰区里的小东西都画在里面）；props 每件一张，x/y 是左上角，foot 是着地线（跟人按着地线排前后），"
               "占地 = 挡人的地面范围 [x0,y0,x1,y1]；桌南背对镜头的椅子 foot 比占地多 3（压在坐着的人前面）；长椅同理；"
               "side_walls 是东西墙顶那一条，底图里也有，再单出一张 foot 放最大，人贴墙走时墙顶压在人前面。"
               "seats：坐点 x/y 是人的脚点，face 朝向、frame 是宾客图第几格（0 朝下、4 朝左、8 朝右、12 朝上），"
               "坐着的人头顶 = y − sit_lift；mahjong_play 南边那把（who=player）是玩家坐的，别的给 NPC。"
               "deco_zones 整块走不进去；walk 是人脚能到的范围。",
        "画布": {"w": W, "h": H}, "view_h": 960, "sit_lift": SIT_LIFT,
        "background": {"png": "room.png", "x": 0, "y": 0},
        "walk": {"x0": SIDE + 6, "x1": W - SIDE - 6, "y0": FLOOR_Y + 4, "y1": WALK_Y1, "door_gap": list(DOOR),
                 "门外到": H - 6},
        "props": man_props, "groups": groups, "seats": seats_, "points": POINTS, "deco_zones": DECO_ZONES,
        "flat": [{"id": "doormat", "名字": "门口地垫", "rect": list(DOORMAT)}],
        "装饰（画进底图）": [d[0] for d in decos] + ["北墙：两扇雕花木窗、四只红灯笼、红绸、两只中国结、两把团扇、熊猫翠竹挂画（不写字）"],
    }
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    # 预览
    empty = compose(bg, props)
    empty.save(os.path.join(OUT, "preview.png"))
    empty.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(OUT, "preview_x2.png"))
    seat_by = {s["id"]: s for s in seats_}
    shot1 = [dict(code="05", frame=12, x=ENTRY[0], y=ENTRY[1]),
             dict(code="09", frame=4, x=636, y=1196),
             dict(code="10", frame=0, x=330, y=1110)]
    img1 = compose(bg, props, shot1, parts_by)
    p1, o1 = phone_shot(img1, ENTRY)
    p1.save(os.path.join(OUT, "phone_1_进门.png"))
    shot2 = [dict(code="06", frame=12, x=540, y=196),
             dict(code="10", frame=8, x=380, y=520),
             dict(code="05", frame=0, x=690, y=300)]
    img2 = compose(bg, props, shot2, parts_by)
    p2, o2 = phone_shot(img2, (540, 300))
    p2.save(os.path.join(OUT, "phone_2_第一排.png"))
    # 坐人检查：mahjong_2 坐满四个、mahjong_play 坐三个 NPC + 玩家、炸金花坐三个、长椅坐一个
    sitters = []
    codes = ["05", "06", "09", "10"]
    k = 0
    for sid in ["seat_mahjong_2_n", "seat_mahjong_2_w", "seat_mahjong_2_e", "seat_mahjong_2_s",
                "seat_mahjong_play_n", "seat_mahjong_play_w", "seat_mahjong_play_e", "seat_mahjong_play_s",
                "seat_poker_nw", "seat_poker_e", "seat_poker_sw", "seat_er27_1_n", "seat_er27_1_s", "seat_bench_w_2"]:
        s = seat_by[sid]
        sitters.append(dict(code=codes[k % 4], frame=s["frame"], seat=s))
        k += 1
    img3 = compose(bg, props, sitters, parts_by)
    tiles = [img3.crop((380, 280, 700, 500)), img3.crop((380, 1040, 700, 1260)), img3.crop((380, 580, 700, 800)),
             img3.crop((60, 880, 380, 1100))]
    chk = Image.new("RGBA", (640 + 8, 440 + 8), C["void"])
    for i, t in enumerate(tiles):
        chk.alpha_composite(t, ((i % 2) * 328, (i // 2) * 228))
    chk.resize((chk.width * 2, chk.height * 2), Image.NEAREST).save(os.path.join(OUT, "check_坐人.png"))
    print("出到 %s：room.png、props/%d 张、room.json、preview、手机图两张（镜头左上 %s、%s）、坐人检查" % (OUT, len(props), o1, o2))
    if bad:
        raise SystemExit("走路检查没过")


if __name__ == "__main__":
    main()
