#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
《苏七镇奇缘》宴会厅氛围占位像素图生成脚本
==========================================

这批都是「占位」美术：正式美术画好之后，按同名文件放进
assets/ambience/ 目录直接替换即可，本脚本可以留着当以后再要占位图时的参考。

规格（写在这里方便以后对照，别去问阿鱼，先看这段）：
- 比例：左右和高度 1 米 = 48 画布像素；纵深（地面 y 方向）1 米 = 32 画布像素；人高 84 画布像素
- 像素：1 个"美术像素"（下面简称 ap） = 2×2 画布像素。本脚本先在半分辨率（ap 网格）上用
  PIL 的 ImageDraw 画多边形/线/椭圆，最后统一 Image.NEAREST 放大 2 倍，得到硬边缘、
  没有半透明毛边的像素画（alpha 只有 0 或 255）
- 配色取自 assets/layered/scene_roman_banquet/base.png 和 blk_table_round.png：
  红、深红、金、木头棕、米白，描边用深紫黑；不用另起一套鲜艳颜色
- 视角：斜俯视、无透视，光从左上来，物体用 2~3 档明暗表现体积（顶面亮、正面中、右侧暗），
  画法参照 blk_table_round.png 的桌子和椅子
- 画面里不画人；除了"囍"字不写任何字；不加 logo

重新跑一遍：
    python3 tools/make_ambience_art.py

跑完会重新生成 assets/ambience/ 下的所有 PNG 和 amb_art.json，
以及 scratchpad 里的 contact.png（对照表）和 mock.png（贴到场景里的效果图）。
随机数种子固定，多次跑结果一样。

只想改某几张、不碰其余文件时（比如这次协调方只要求改彩带/彩纸/酒杯）：
    python3 tools/make_ambience_art.py --only=amb_streamer_1,amb_streamer_2,amb_cup
这时候只有列出来的名字会真的存盘；amb_art.json 和 contact.png 永远整份重写
（json 本来就是全部素材的汇总，contact.png 是给人看的对照表，没有"只改一部分"这回事），
其余没列到的 PNG 一个字节都不会碰。
"""

import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

random.seed(20260918)

# ---------------------------------------------------------------------------
# 路径
# ---------------------------------------------------------------------------
ROOT = "/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot"
SCENE_DIR = os.path.join(ROOT, "assets/layered/scene_roman_banquet")
OUT_DIR = os.path.join(ROOT, "assets/ambience")
# tools/layout_v7_tables/ 是场景积木的暂存目录（跟 assets/layered/scene_roman_banquet/ 镜像的
# base.png、blk_table_round.png 等都在这），2026-09-18 协调方要的 blk_flower_pot.png 是场景积木、
# 不是氛围占位图，按它自己的规矩放这里，不进 amb_art.json
LAYOUT_DIR = os.path.join(ROOT, "tools/layout_v7_tables")
SCRATCH = (
    "/private/tmp/claude-501/-Users-kayra-ayu-Desktop------/"
    "9522c259-47a8-43c3-aa9c-60a480f2ffcb/scratchpad/amb"
)

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(SCRATCH, exist_ok=True)

BASE_PNG = os.path.join(SCENE_DIR, "base.png")

# ---------------------------------------------------------------------------
# 调色板（取自参考图的红金木色系，见脚本开头说明）
# ---------------------------------------------------------------------------
OUTLINE = (24, 15, 19, 255)         # 深紫黑描边

WOOD_DARK = (43, 22, 12, 255)       # 深木棕（暗面/腿）
WOOD_MID = (93, 50, 25, 255)        # 中木棕
WOOD_LIGHT = (145, 88, 46, 255)     # 浅木棕（高光）

GOLD_DARK = (140, 100, 40, 255)
GOLD = (196, 154, 66, 255)
GOLD_LIGHT = (232, 199, 116, 255)

RED_DARK = (94, 22, 24, 255)        # 深红（暗面/阴影）
RED = (177, 47, 43, 255)            # 正红（主色，取自红毯）
RED_LIGHT = (216, 94, 78, 255)      # 亮红（高光）
MAROON = (68, 18, 20, 255)          # 更深的酒红/描边内暗面

CREAM = (245, 227, 196, 255)        # 米白（桌布、琴键、谱纸）
CREAM_SHADE = (214, 188, 150, 255)  # 米白暗面

PINK = (231, 149, 158, 255)
PINK_DARK = (182, 98, 108, 255)

ORANGE_WOOD = (168, 92, 44, 255)    # 提琴橙棕色
ORANGE_WOOD_DARK = (112, 58, 28, 255)
ORANGE_WOOD_LIGHT = (203, 137, 74, 255)

BLACK_LACQUER = (21, 18, 23, 255)   # 钢琴烤漆黑
LACQUER_SHEEN = (72, 74, 86, 255)   # 烤漆高光灰蓝
LID_INSIDE = (46, 43, 52, 255)      # 琴盖内侧（稍亮一点）

SILVER = (176, 182, 190, 255)
SILVER_DARK = (110, 116, 126, 255)
SILVER_LIGHT = (226, 230, 234, 255)

WHITE = (250, 250, 248, 255)
BLACK_KEY = (18, 16, 20, 255)

FLOOR_TILE = (231, 195, 158, 255)   # 米色地砖（备用/预览背景兜底色）

# 2026-09-18 阿鱼那边协调方反馈：彩带/彩纸/酒杯在游戏里读出来是深红色的污渍和乱线，
# 不像喜庆的彩带——下面这组颜色是按反馈给的十六进制值改的，只给这三样用，不动别的调色板
RIBBON_RED_BODY = (217, 56, 58, 255)     # #d9383a
RIBBON_RED_HI = (255, 123, 107, 255)     # #ff7b6b
RIBBON_RED_SH = (163, 38, 43, 255)       # #a3262b
RIBBON_GOLD_BODY = (230, 179, 74, 255)   # #e6b34a
RIBBON_GOLD_HI = (255, 240, 160, 255)    # #fff0a0
RIBBON_GOLD_SH = (176, 127, 34, 255)     # #b07f22

CONFETTI_RED = (224, 64, 58, 255)        # #e0403a
CONFETTI_GOLD = (240, 192, 64, 255)      # #f0c040
CONFETTI_PINK = (242, 143, 176, 255)     # #f28fb0
CONFETTI_WHITE = (255, 246, 224, 255)    # #fff6e0

# 2026-09-18 新一批：桌下红地毯 + 舞台花瓶。颜色是协调方给的十六进制值，
# 特意跟桌布/椅子的红（RED/RED_DARK）区分开，别撞色
RUG_FIELD = (125, 26, 31, 255)       # #7d1a1f 地毯主色，深绛红
RUG_PATTERN = (158, 42, 43, 255)     # #9e2a2b 暗纹（菱形/花纹）
RUG_GOLD = (212, 165, 58, 255)       # #d4a53a 金边
RUG_GOLD_HI = (240, 207, 106, 255)   # #f0cf6a 金边高光
RUG_EDGE_DARK = (52, 14, 16, 255)    # 金边外面那圈细的深红边线

VASE_DARK = (26, 27, 36, 255)        # 花瓶深蓝黑色瓷
VASE_DARK_HI = (46, 48, 62, 255)     # 花瓶肩部一点高光
LEAF_GREEN = (60, 98, 55, 255)
LEAF_GREEN_DARK = (36, 64, 36, 255)
LEAF_GREEN_LIGHT = (96, 140, 80, 255)

ANCHORS = {}  # 收集每张图的 size / anchor，最后写 amb_art.json


# ---------------------------------------------------------------------------
# 通用画图小工具：都在「半分辨率（ap）」画布上工作
# ---------------------------------------------------------------------------

def new_canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def poly(draw, pts, fill=None, outline=OUTLINE, width=1):
    pts = [(round(x), round(y)) for x, y in pts]
    if fill is not None:
        draw.polygon(pts, fill=fill)
    if outline is not None:
        draw.line(pts + [pts[0]], fill=outline, width=width, joint="curve")


def rect(draw, box, fill=None, outline=OUTLINE, width=1):
    if fill is not None:
        draw.rectangle(box, fill=fill)
    if outline is not None:
        draw.rectangle(box, outline=outline, width=width)


def ellipse(draw, box, fill=None, outline=OUTLINE, width=1):
    if fill is not None:
        draw.ellipse(box, fill=fill)
    if outline is not None:
        draw.ellipse(box, outline=outline, width=width)


def outline_from_alpha(img, color=OUTLINE):
    """给整张图的外轮廓描一圈边，而不是每个形状分开描边——特别小的部件（比如酒杯）
    一个形状本身就只有几个像素，每块都单独描边会被黑边吃掉，不如画完所有色块之后
    统一沿着最终轮廓描一圈。"""
    w, h = img.size
    px = img.load()
    solid = [[px[x, y][3] > 0 for x in range(w)] for y in range(h)]
    out = img.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            if any(
                0 <= x + dx < w and 0 <= y + dy < h and solid[y + dy][x + dx]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
            ):
                opx[x, y] = color
    return out


def binarize_alpha(img):
    """保证 alpha 只有 0 / 255，防止 PIL 画椭圆之类留下的半透明毛边。"""
    r, g, b, a = img.split()
    a = a.point(lambda v: 255 if v >= 128 else 0)
    return Image.merge("RGBA", (r, g, b, a))


def finalize(img, margin_ap=1):
    """贴边裁切（留 0~1 个 ap = 0~2 画布像素），二值化 alpha，再放大 2 倍输出。"""
    img = binarize_alpha(img)
    bbox = img.getbbox()
    if bbox is None:
        raise ValueError("空图像，检查坐标是否画到画布外面了")
    l, t, r, b = bbox
    l = max(0, l - margin_ap)
    t = max(0, t - margin_ap)
    r = min(img.width, r + margin_ap)
    b = min(img.height, b + margin_ap)
    cropped = img.crop((l, t, r, b))
    big = cropped.resize((cropped.width * 2, cropped.height * 2), Image.NEAREST)
    return big


def finalize_with_anchor(img, anchor_ap, margin_ap=1):
    """裁切前半分辨率画布上的锚点坐标 anchor_ap -> 裁切、二值化、放大2倍之后的最终画布像素坐标。
    所有需要"精确锚点"（不是简单居中/贴底）的部件都通过这个函数出图，保证 amb_art.json
    里的 anchor 和实际贴出来的 PNG 是对得上的。"""
    img = binarize_alpha(img)
    bbox = img.getbbox()
    if bbox is None:
        raise ValueError("空图像，检查坐标是否画到画布外面了")
    l, t, r, b = bbox
    l = max(0, l - margin_ap)
    t = max(0, t - margin_ap)
    r = min(img.width, r + margin_ap)
    b = min(img.height, b + margin_ap)
    cropped = img.crop((l, t, r, b))
    big = cropped.resize((cropped.width * 2, cropped.height * 2), Image.NEAREST)
    ax = (anchor_ap[0] - l) * 2
    ay = (anchor_ap[1] - t) * 2
    ax = max(0, min(big.width, ax))
    ay = max(0, min(big.height, ay))
    return big, (int(round(ax)), int(round(ay)))


# ---------------------------------------------------------------------------
# 1. 三角钢琴 amb_piano  目标约 104x100 画布像素
# ---------------------------------------------------------------------------

def build_piano():
    W, H = 76, 64
    OX, OY = 8, 12  # 把手算坐标系挪到画布正中，留够上面撑开的琴盖和下面的琴腿
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    def P(x, y):
        return (x + OX, y + OY)

    # 琴身俯视轮廓：西端(左)是琴键端，东端(右)收成琴尾尖角
    # 后边（北，直线）：从琴键端后角 到 琴尾尖
    back_a, back_b = (12, 16), (52, 10)

    def spine_y(x):
        t = (x - back_a[0]) / (back_b[0] - back_a[0])
        return back_a[1] + (back_b[1] - back_a[1]) * t

    # 前边（南，弧线，鼓出的琴腹）：手摆的点，从琴键端前角 到 琴尾尖
    front_pts = [
        (12, 38), (18, 42), (24, 44), (30, 43),
        (36, 38), (42, 29), (48, 18), (52, 10),
    ]

    case_top = [back_a, back_b] + list(reversed(front_pts[:-1]))
    # case_top: (12,16)->(52,10)->(48,18)->(42,29)->(36,38)->(30,43)->(24,44)->(18,42)->(12,38)

    # 琴盖：沿后边直线撑起来的斜帆，比琴腹曲线矮一些（撑开约45度，视觉上做了透视压缩）
    lid_pts = [back_a]
    for (x, fy) in front_pts:
        sy = spine_y(x)
        offset = fy - sy
        ly = sy - offset * 0.5
        lid_pts.append((x, ly))
    lid_poly = lid_pts  # 从 (12,16) 一路到 (52,10)

    # --- 画顺序：先盖子（最靠后上方），再琴身顶面，再前侧板，再腿，最后琴键和细节 ---

    # 琴盖：外侧稍暗、内侧（朝向玩家的这一面）稍亮，中间画一条棱线分两块
    lid_outer = [P(x, y) for x, y in lid_poly]
    poly(d, lid_outer, fill=BLACK_LACQUER, outline=OUTLINE)
    # 内侧亮面：整块盖子往回收窄一点，叠在上面，营造"斜立的帆"更亮的那一面
    lid_inner = []
    n = len(lid_poly)
    for i, (x, y) in enumerate(lid_poly):
        sy = spine_y(x)
        inset = (sy - y) * 0.35
        lid_inner.append((x, y + inset))
    poly(d, [P(x, y) for x, y in lid_inner], fill=LID_INSIDE, outline=None)
    d.line([P(x, y) for x, y in lid_poly[1:]], fill=GOLD_DARK, width=1)

    # 琴身顶面（黑色烤漆）
    top_ring = [P(x, y) for x, y in case_top]
    poly(d, top_ring, fill=BLACK_LACQUER, outline=OUTLINE)
    # 金线细边：贴着琴腹弧线内侧一圈
    inner_edge = []
    for (x, y) in front_pts:
        sy = spine_y(x)
        inner_edge.append((x, y - (y - sy) * 0.12))
    d.line([P(x, y) for x, y in inner_edge], fill=GOLD, width=1)
    # 两道烤漆高光
    d.line([P(20, 39), P(26, 36)], fill=LACQUER_SHEEN, width=1)
    d.line([P(34, 30), P(39, 25)], fill=LACQUER_SHEEN, width=1)

    # 前侧板（案体厚度）：贴着琴腹曲线往下移一点，颜色更暗，体现体积
    APRON = 5
    side_top = [P(x, y) for (x, y) in front_pts]
    side_bot = [P(x, y + APRON) for (x, y) in front_pts]
    apron_poly = side_top + list(reversed(side_bot))
    poly(d, apron_poly, fill=WOOD_DARK, outline=OUTLINE)

    def apron_bottom(x):
        # front_pts 分段线性插值，找该 x 对应的侧板下沿 y（未加 OY/OX 偏移）
        for i in range(len(front_pts) - 1):
            x0, y0 = front_pts[i]
            x1, y1 = front_pts[i + 1]
            if x0 <= x <= x1:
                t = 0 if x1 == x0 else (x - x0) / (x1 - x0)
                return y0 + (y1 - y0) * t + APRON
        return front_pts[-1][1] + APRON

    # 三条琴腿 + 小脚垫，金棕色
    for lx in (15, 28, 45):
        top_y = apron_bottom(lx)
        leg_h = 6
        rect(d, [P(lx - 1.5, top_y), P(lx + 1.5, top_y + leg_h)], fill=GOLD_DARK, outline=OUTLINE)
        ellipse(d, [P(lx - 2, top_y + leg_h - 1), P(lx + 2, top_y + leg_h + 1.5)], fill=WOOD_DARK, outline=OUTLINE)

    # 踏板架：靠近琴键端，一个小小的金棕色梯形 + 两道踏板
    py0 = apron_bottom(20)
    pedal_box = [P(18, py0), P(24, py0), P(23, py0 + 4), P(19, py0 + 4)]
    poly(d, pedal_box, fill=GOLD_DARK, outline=OUTLINE)
    d.line([P(19.5, py0 + 4), P(19.5, py0 + 5.5)], fill=WOOD_DARK, width=1)
    d.line([P(22.5, py0 + 4), P(22.5, py0 + 5.5)], fill=WOOD_DARK, width=1)

    # 琴键：从琴键端伸出的白键条，带几道黑键（黑键之间留出清楚的间隔，别糊成一块）
    key_x0, key_x1 = OX - 10, OX + 12
    key_y0, key_y1 = OY + 21, OY + 31
    rect(d, [key_x0, key_y0, key_x1, key_y1], fill=CREAM, outline=OUTLINE)
    d.line([(key_x1, key_y0), (key_x1, key_y1)], fill=WOOD_DARK, width=1)
    for i, ky in enumerate(range(key_y0 + 2, key_y1 - 1, 2)):
        d.line([(key_x0 + 1, ky), (key_x1 - 5, ky)], fill=CREAM_SHADE, width=1)
    for bk in range(3):
        by = key_y0 + 1 + bk * 3
        rect(d, [key_x1 - 5, by, key_x1 - 3, by + 1], fill=BLACK_KEY, outline=None)

    anchor_ap = (26, 48)  # 三条腿脚落地那一片的中点（半分辨率坐标，未加 OX/OY）
    return img, (anchor_ap[0] + OX, anchor_ap[1] + OY)


# ---------------------------------------------------------------------------
# 2. 钢琴凳 amb_piano_bench  目标约 30x20
# ---------------------------------------------------------------------------

def build_piano_bench():
    W, H = 22, 20
    OX, OY = 3, 3
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    seat = [OX + 1, OY + 3, OX + 15, OY + 8]
    rect(d, seat, fill=BLACK_LACQUER, outline=OUTLINE)
    d.line([(OX + 2, OY + 4), (OX + 13, OY + 4)], fill=LACQUER_SHEEN, width=1)

    apron = [OX + 1, OY + 8, OX + 15, OY + 10]
    rect(d, apron, fill=WOOD_DARK, outline=OUTLINE)

    for lx in (OX + 2, OX + 13):
        rect(d, [lx, OY + 10, lx + 2, OY + 15], fill=GOLD_DARK, outline=OUTLINE)
        ellipse(d, [lx - 0.5, OY + 14.2, lx + 2.5, OY + 15.7], fill=WOOD_DARK, outline=OUTLINE)

    return img, (OX + 8, OY + 15)


# ---------------------------------------------------------------------------
# 3. 大提琴 amb_cello  立着，约 26x60
# ---------------------------------------------------------------------------

def build_cello():
    W, H = 22, 34
    OX, OY = 6, 2
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    # 琴头卷
    ellipse(d, [OX + 3, OY, OX + 8, OY + 4.2], fill=ORANGE_WOOD, outline=OUTLINE)
    d.line([(OX + 6, OY + 0.8), (OX + 4.6, OY + 3)], fill=ORANGE_WOOD_DARK, width=1)

    # 弦轴箱 + 琴颈/指板
    rect(d, [OX + 3.5, OY + 4.2, OX + 7.5, OY + 7], fill=ORANGE_WOOD_DARK, outline=OUTLINE)
    poly(d, [(OX + 4.2, OY + 7), (OX + 6.8, OY + 7), (OX + 6.4, OY + 14), (OX + 4.6, OY + 14)],
         fill=BLACK_KEY, outline=OUTLINE)

    # 琴身：上侧、腰、下侧三段轮廓（左宽右窄，光从左上来所以左半亮、右半暗）
    body = [
        (OX + 4.4, OY + 14), (OX + 6.6, OY + 14),
        (OX + 9.5, OY + 15.5), (OX + 10.3, OY + 18),
        (OX + 8.2, OY + 19.6), (OX + 7.8, OY + 21.2),
        (OX + 10.6, OY + 23.6), (OX + 10.2, OY + 27),
        (OX + 5.8, OY + 29.4), (OX + 2, OY + 27.8),
        (OX + 1.2, OY + 23.8), (OX + 3.4, OY + 21.2),
        (OX + 2.9, OY + 19.6), (OX + 0.7, OY + 18),
        (OX + 1.9, OY + 15.5),
    ]
    poly(d, body, fill=ORANGE_WOOD, outline=OUTLINE)
    # 右半暗面（体积感）
    shade = [
        (OX + 6.6, OY + 14), (OX + 9.5, OY + 15.5), (OX + 10.3, OY + 18),
        (OX + 8.2, OY + 19.6), (OX + 7.8, OY + 21.2), (OX + 10.6, OY + 23.6),
        (OX + 10.2, OY + 27), (OX + 5.8, OY + 29.4), (OX + 5.8, OY + 14),
    ]
    poly(d, shade, fill=ORANGE_WOOD_DARK, outline=None)
    # 左上高光
    d.line([(OX + 2.9, OY + 16.3), (OX + 2.3, OY + 20.4)], fill=ORANGE_WOOD_LIGHT, width=1)

    # f 孔（两个小竖缝，别画成十字，细细两道就好）
    d.line([(OX + 4.3, OY + 18), (OX + 4.1, OY + 21)], fill=BLACK_KEY, width=1)
    d.line([(OX + 8.1, OY + 18), (OX + 7.9, OY + 21)], fill=BLACK_KEY, width=1)

    # 琴码
    d.line([(OX + 3.8, OY + 22), (OX + 8.6, OY + 22)], fill=CREAM_SHADE, width=1)

    # 弦：只画在琴码往上到指板之间那一段，两道细线隔开，别贴在一起糊成一条粗白杠
    d.line([(OX + 5.4, OY + 7), (OX + 5.4, OY + 22)], fill=CREAM, width=1)
    d.line([(OX + 7.4, OY + 7.3), (OX + 7.4, OY + 22)], fill=CREAM, width=1)

    # 拉弦板
    poly(d, [(OX + 4.3, OY + 25.6), (OX + 7.3, OY + 25.6), (OX + 6.8, OY + 27.4), (OX + 4.8, OY + 27.4)],
         fill=BLACK_KEY, outline=OUTLINE)

    # 尾柱（落地那一点）
    d.line([(OX + 5.8, OY + 29.4), (OX + 5.8, OY + 32.4)], fill=WOOD_DARK, width=1)

    return img, (OX + 5.8, OY + 32.4)


# ---------------------------------------------------------------------------
# 4. 小提琴 amb_violin  横放，约 30x12
# ---------------------------------------------------------------------------

def build_violin():
    W, H = 20, 12
    OX, OY = 2, 3
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    # 琴身：横放的束腰"花生"形，左宽右窄，光从左上来所以左半亮、右半暗
    body = [
        (OX + 0.5, OY + 2.6), (OX + 2, OY + 1), (OX + 4, OY + 1.6),
        (OX + 5.4, OY + 0.8), (OX + 7.2, OY + 1.2), (OX + 8.2, OY + 2.6),
        (OX + 7.2, OY + 4), (OX + 5.4, OY + 4.4), (OX + 4, OY + 3.6),
        (OX + 2, OY + 4.2), (OX + 0.5, OY + 2.6),
    ]
    poly(d, body, fill=ORANGE_WOOD, outline=OUTLINE)
    shade = [
        (OX + 4, OY + 1.6), (OX + 5.4, OY + 0.8), (OX + 7.2, OY + 1.2), (OX + 8.2, OY + 2.6),
        (OX + 7.2, OY + 4), (OX + 5.4, OY + 4.4), (OX + 4, OY + 3.6), (OX + 4, OY + 1.6),
    ]
    poly(d, shade, fill=ORANGE_WOOD_DARK, outline=None)
    d.point([(OX + 1.4, OY + 1.8)], fill=ORANGE_WOOD_LIGHT)

    # 指板 + 琴颈
    d.line([(OX + 8.2, OY + 2.6), (OX + 12.6, OY + 2.6)], fill=BLACK_KEY, width=2)
    # 琴头（木色小卷，跟指板的黑分开，别和身体撞色）
    ellipse(d, [OX + 12.4, OY + 1, OX + 15.4, OY + 4.2], fill=ORANGE_WOOD, outline=OUTLINE)
    d.point([(OX + 13.2, OY + 2)], fill=ORANGE_WOOD_DARK)

    # 腮托：贴在琴身左端下缘
    ellipse(d, [OX - 0.4, OY + 3.6, OX + 2.2, OY + 5.6], fill=BLACK_KEY, outline=OUTLINE)

    out = finalize(img)
    return out, (out.width // 2, out.height // 2)


# ---------------------------------------------------------------------------
# 5. 谱架 amb_music_stand  约 16x40
# ---------------------------------------------------------------------------

def build_music_stand():
    W, H = 14, 24
    OX, OY = 3, 2
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    # 立杆
    d.line([(OX + 4, OY + 5), (OX + 4, OY + 16)], fill=WOOD_DARK, width=1)

    # 三脚（画两条能看见的前脚 + 一条短的后脚痕迹）
    d.line([(OX + 4, OY + 16), (OX + 1, OY + 19)], fill=WOOD_DARK, width=1)
    d.line([(OX + 4, OY + 16), (OX + 7, OY + 19)], fill=WOOD_DARK, width=1)
    d.line([(OX + 4, OY + 16), (OX + 4, OY + 18)], fill=WOOD_DARK, width=1)
    for fx in (OX + 1, OX + 7, OX + 4):
        ellipse(d, [fx - 1, OY + 18.5, fx + 1, OY + 19.7], fill=OUTLINE, outline=None)

    # 斜谱板：一块深色板子朝右上斜立着，上面嵌一张白纸，纸上几道深色横线意思一下五线谱
    board = [(OX - 1, OY + 3), (OX + 7, OY), (OX + 7, OY + 6), (OX - 1, OY + 9)]
    poly(d, board, fill=WOOD_DARK, outline=OUTLINE)
    paper = [(OX - 0.3, OY + 3.4), (OX + 6.3, OY + 0.7), (OX + 6.3, OY + 5.1), (OX - 0.3, OY + 7.8)]
    poly(d, paper, fill=CREAM, outline=None)
    for t in (0.25, 0.45, 0.65, 0.85):
        # 纸左右两边都是竖直的，只是右边比左边整体高一截（纸是斜的），按比例连线就是一道斜线
        ly = (OY + 3.4) + t * ((OY + 7.8) - (OY + 3.4))
        ry = (OY + 0.7) + t * ((OY + 5.1) - (OY + 0.7))
        d.line([(OX - 0.3, ly), (OX + 6.3, ry)], fill=WOOD_MID, width=1)
    # 谱板底沿一条搁纸的小横杆
    d.line([(OX - 1, OY + 8.3), (OX + 7, OY + 5.3)], fill=WOOD_DARK, width=1)

    out = finalize(img)
    cx = out.width // 2
    return out, (cx, out.height - 1)


# ---------------------------------------------------------------------------
# 6. 单人椅 amb_chair  约 24x36，正面朝南
# ---------------------------------------------------------------------------

def build_chair():
    W, H = 18, 24
    OX, OY = 3, 2
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    # 靠背
    rect(d, [OX + 1, OY, OX + 11, OY + 8], fill=WOOD_DARK, outline=OUTLINE)
    rect(d, [OX + 2.3, OY + 1.2, OX + 9.7, OY + 7], fill=RED, outline=OUTLINE)
    d.line([(OX + 2.6, OY + 1.5), (OX + 5, OY + 1.5)], fill=RED_LIGHT, width=1)
    # 金色小菱形装饰
    cx, cy = OX + 6, OY + 4
    poly(d, [(cx, cy - 1.3), (cx + 1.3, cy), (cx, cy + 1.3), (cx - 1.3, cy)], fill=GOLD, outline=None)

    # 坐垫（顶面）
    rect(d, [OX, OY + 8, OX + 12, OY + 13], fill=RED, outline=OUTLINE)
    d.line([(OX + 0.5, OY + 8.5), (OX + 5, OY + 8.5)], fill=RED_LIGHT, width=1)

    # 前侧板
    rect(d, [OX, OY + 13, OX + 12, OY + 15.5], fill=WOOD_MID, outline=OUTLINE)

    # 前两条腿
    for lx in (OX + 1.2, OX + 9.5):
        rect(d, [lx, OY + 15.5, lx + 1.6, OY + 20], fill=WOOD_DARK, outline=OUTLINE)

    out = finalize(img)
    cx = out.width // 2
    return out, (cx, out.height - 1)


# ---------------------------------------------------------------------------
# 7. 礼物堆 amb_gift_pile  约 150x100
# ---------------------------------------------------------------------------

def draw_box(d, x0, y0, bw, bh, dtop, dside, top_c, front_c, side_c, ribbon=None):
    front = [(x0, y0), (x0 + bw, y0), (x0 + bw, y0 + bh), (x0, y0 + bh)]
    top = [(x0, y0), (x0 + bw, y0), (x0 + bw - dside, y0 - dtop), (x0 - dside, y0 - dtop)]
    side = [(x0 + bw, y0), (x0 + bw - dside, y0 - dtop), (x0 + bw - dside, y0 + bh - dtop), (x0 + bw, y0 + bh)]
    poly(d, top, fill=top_c, outline=OUTLINE)
    poly(d, front, fill=front_c, outline=OUTLINE)
    poly(d, side, fill=side_c, outline=OUTLINE)

    if ribbon:
        rc, rc_dark = ribbon
        rw = max(1, bw * 0.14)
        # 竖带：正面 + 顶面
        d.line([(x0 + bw / 2, y0), (x0 + bw / 2, y0 + bh)], fill=rc, width=max(1, int(rw)))
        d.line([(x0 + bw / 2, y0), (x0 + bw / 2 - dside, y0 - dtop)], fill=rc, width=max(1, int(rw)))
        # 横带：只在正面
        d.line([(x0, y0 + bh * 0.45), (x0 + bw, y0 + bh * 0.45)], fill=rc, width=max(1, int(rw)))
        # 蝴蝶结（顶前沿中点，两个小三角）
        bxc, byc = x0 + bw / 2, y0
        poly(d, [(bxc, byc), (bxc - 3, byc - 2.2), (bxc - 0.6, byc - 0.4)], fill=rc, outline=rc_dark, width=1)
        poly(d, [(bxc, byc), (bxc + 3, byc - 2.2), (bxc + 0.6, byc - 0.4)], fill=rc, outline=rc_dark, width=1)
        ellipse(d, [bxc - 1, byc - 1.4, bxc + 1, byc + 0.6], fill=rc_dark, outline=None)


def build_gift_pile():
    W, H = 90, 62
    OX, OY = 4, 8
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    palette = [
        (RED_LIGHT, RED, RED_DARK),
        (RED, RED_DARK, MAROON),
        (GOLD_LIGHT, GOLD, GOLD_DARK),
        (PINK, PINK_DARK, (140, 70, 80, 255)),
        (CREAM, CREAM_SHADE, (170, 148, 118, 255)),
        (MAROON, (54, 14, 16, 255), (36, 10, 12, 255)),
    ]
    ribbons = [(GOLD_LIGHT, GOLD_DARK), (GOLD, GOLD_DARK), None]

    # 手工摆位：后排小，前排大，整体一座小山（数值是 ap，按 W,H=90,62 的画布来配）
    boxes = []
    back_row = [(10, 8, 9, 8), (24, 6, 8, 7), (40, 5, 10, 8), (54, 7, 8, 7), (66, 9, 9, 8)]
    mid_row = [(4, 16, 11, 10), (18, 14, 12, 11), (34, 13, 11, 10), (48, 15, 12, 11), (62, 17, 11, 10)]
    front_row = [(2, 27, 15, 14), (20, 25, 16, 15), (40, 26, 14, 13), (57, 28, 15, 14)]

    idx = 0
    for row in (back_row, mid_row, front_row):
        for (x0, y0, bw, bh) in row:
            pal = palette[idx % len(palette)]
            rib = ribbons[idx % len(ribbons)]
            boxes.append((x0, y0, bw, bh, pal, rib))
            idx += 1

    # 按 y0 从小到大画（后面的先画，前面的盖上去）
    for (x0, y0, bw, bh, (top_c, front_c, side_c), rib) in sorted(boxes, key=lambda b: b[1]):
        dtop = bh * 0.32
        dside = bw * 0.22
        draw_box(d, OX + x0, OY + y0, bw, bh, dtop, dside, top_c, front_c, side_c, ribbon=rib)

    # 最前面斜靠两三个红包
    envelopes = [(18, 45, -8), (30, 47, 6), (44, 45, -4)]
    for (ex, ey, ang) in envelopes:
        rad = math.radians(ang)
        w2, h2 = 5, 7
        pts = []
        for (px, py) in [(-w2, -h2), (w2, -h2), (w2, h2), (-w2, h2)]:
            rx = px * math.cos(rad) - py * math.sin(rad)
            ry = px * math.sin(rad) + py * math.cos(rad)
            pts.append((OX + ex + rx, OY + ey + ry))
        poly(d, pts, fill=RED, outline=OUTLINE)
        cx = OX + ex
        cy = OY + ey
        ellipse(d, [cx - 1.6, cy - 1.6, cx + 1.6, cy + 1.6], fill=GOLD, outline=GOLD_DARK, width=1)

    out = finalize(img)
    cx = out.width // 2
    return out, (cx, out.height - 1)


# ---------------------------------------------------------------------------
# 8. 地上彩带 amb_streamer_1..6
# ---------------------------------------------------------------------------

def _squash(points, factor=0.67):
    return [(x, y * factor) for (x, y) in points]


def _perp_path(pts, off):
    """沿着 pts 这条折线，每一点按局部切线方向的垂线偏移 off，返回一条平行的折线。
    偏移方向是统一的（不是每段各转各的），这样弯来弯去的时候亮边也稳稳地在同一侧，
    不会一会儿在左一会儿在右。"""
    n = len(pts)
    out = []
    for i in range(n):
        if i == 0:
            dx, dy = pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]
        elif i == n - 1:
            dx, dy = pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1]
        else:
            dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        length = math.hypot(dx, dy) or 1.0
        px, py = -dy / length, dx / length
        out.append((pts[i][0] + px * off, pts[i][1] + py * off))
    return out


def _ribbon_image(points, body, hi, sh, width=2, shadow_spans=()):
    """一条实心带子，不描边：主体 + 一侧一条细高光；阴影只在给定的 (t0,t1) 弧段里
    贴一小截，不是整条都描，避免看起来像整条都有一圈边。"""
    pts = _squash(points)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    pad = 3
    minx, maxx = min(xs) - pad, max(xs) + pad
    miny, maxy = min(ys) - pad, max(ys) + pad
    w, h = int(math.ceil(maxx - minx)), int(math.ceil(maxy - miny))
    img = new_canvas(max(w, 4), max(h, 4))
    d = ImageDraw.Draw(img)
    shifted = [(x - minx, y - miny) for (x, y) in pts]
    n = len(shifted)

    d.line(shifted, fill=body, width=width, joint="curve")
    r = width / 2.0
    for p in (shifted[0], shifted[-1]):
        ellipse(d, [p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=body, outline=None)

    hi_path = _perp_path(shifted, width * 0.4)
    d.line(hi_path, fill=hi, width=1, joint="curve")

    sh_path = _perp_path(shifted, -width * 0.4)
    for t0, t1 in shadow_spans:
        i0, i1 = max(0, int(t0 * (n - 1))), min(n - 1, int(t1 * (n - 1)))
        if i1 - i0 >= 1:
            d.line(sh_path[i0:i1 + 1], fill=sh, width=1, joint="curve")

    return img


def rib_curl(n=18, r=6.0, turns=1.35, tail=7.0):
    # 松松卷起来的一截：从一段直的尾巴，慢慢卷成一个越卷越松的开口螺旋（像拿剪刀刮过的
    # 礼品带），半径是从小长到大的，不是同心圆一圈圈叠在一起——叠在一起会糊成一个球，
    # 之前 amb_streamer_1 看着像红白格子块就是这么糊出来的
    pts = [(-tail, 0.8), (-tail * 0.45, 0.3)]
    for i in range(n):
        t = i / (n - 1)
        ang = t * turns * 2 * math.pi
        rr = r * (0.2 + 0.8 * t)
        x = rr - math.cos(ang) * rr
        y = -math.sin(ang) * rr
        pts.append((x, y))
    return pts


def rib_s(n=14, length=28, amp=7.5):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        x = t * length
        y = math.sin(t * math.pi * 1.4) * amp
        pts.append((x, y))
    return pts


def rib_bow(loop_r=5.5, tail=10.5, n_loop=12):
    # 打了个结：两个圈（蝴蝶结的耳朵）中间一个结，左右各甩出一条尾巴
    pts = [(-tail, 3.0), (-tail * 0.5, 1.2), (-0.7, 0.3)]
    cx, cy = -loop_r * 1.05, -loop_r * 0.15
    for i in range(n_loop + 1):
        ang = math.pi * 0.35 + i / n_loop * (2 * math.pi * 0.85)
        pts.append((cx + math.cos(ang) * loop_r, cy + math.sin(ang) * loop_r))
    pts.append((-0.5, 0.25))
    cx2, cy2 = loop_r * 1.05, -loop_r * 0.15
    for i in range(n_loop + 1):
        ang = math.pi * 1.15 - i / n_loop * (2 * math.pi * 0.85)
        pts.append((cx2 + math.cos(ang) * loop_r, cy2 + math.sin(ang) * loop_r))
    pts += [(0.7, 0.3), (tail * 0.5, 1.3), (tail, 3.2)]
    return pts


def rib_loose(n=8, length=16, amp=3.6, seed=5):
    # 短短松松甩开的一截，没什么规律的弯
    rnd = random.Random(seed)
    pts = []
    y = 0
    for i in range(n):
        t = i / (n - 1)
        x = t * length
        y += rnd.uniform(-amp, amp)
        pts.append((x, y))
    return pts


def build_streamers():
    red = (RIBBON_RED_BODY, RIBBON_RED_HI, RIBBON_RED_SH)
    gold = (RIBBON_GOLD_BODY, RIBBON_GOLD_HI, RIBBON_GOLD_SH)
    specs = [
        (rib_curl(), red, [(0.35, 0.6)]),                       # 1: 红，松弹簧卷（原来那张像红白格子的就是这张）
        (rib_s(), red, [(0.55, 0.8)]),                          # 2: 红，大 S 形
        (rib_bow(), red, [(0.18, 0.32)]),                       # 3: 红，打了个结（两个耳朵+两条尾巴）
        (rib_loose(), red, []),                                 # 4: 红，短短松散一截，没有明显转弯就不点阴影
        (rib_s(n=12, length=24, amp=9), gold, [(0.5, 0.75)]),    # 5: 金，大 S 形（幅度不一样，别跟 2 撞样）
        (rib_curl(n=14, r=4.8, turns=1.1, tail=5.5), gold, [(0.3, 0.55)]),  # 6: 金，卷得更松更短，别跟 1 撞样
    ]
    results = []
    for pts, (body, hi, sh), shadow_spans in specs:
        img = _ribbon_image(pts, body, hi, sh, width=2, shadow_spans=shadow_spans)
        out = finalize(img, margin_ap=1)
        cx, cy = out.width // 2, out.height // 2
        results.append((out, (cx, cy)))
    return results


# ---------------------------------------------------------------------------
# 9. 彩纸屑 amb_confetti_1..3
# ---------------------------------------------------------------------------

def build_confetti(seed):
    # 不描边，颜色比原来鲜亮一截；片子比原来大一号（2x1~2x2 ap），撒得更开一点
    rnd = random.Random(seed)
    W, H = 13, 8
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    colors = [CONFETTI_RED, CONFETTI_GOLD, CONFETTI_PINK, CONFETTI_WHITE]
    n = rnd.randint(5, 8)
    for _ in range(n):
        x = rnd.uniform(0.5, W - 2.5)
        y = rnd.uniform(0.5, H - 2.5)
        c = rnd.choice(colors)
        tall = rnd.random() < 0.5
        h2 = 2 if rnd.random() < 0.55 else 1
        if tall:
            d.rectangle([x, y, x + 1, y + h2], fill=c)
        else:
            d.rectangle([x, y, x + h2, y + 1], fill=c)
    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


# ---------------------------------------------------------------------------
# 10. 托盘 amb_tray  约 28x14
# ---------------------------------------------------------------------------

def build_tray():
    W, H = 20, 14
    OX, OY = 2, 4
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    ellipse(d, [OX, OY + 1, OX + 16, OY + 8], fill=SILVER_DARK, outline=OUTLINE)
    ellipse(d, [OX + 0.6, OY + 0.6, OX + 15.4, OY + 7], fill=SILVER, outline=OUTLINE)
    d.line([(OX + 2, OY + 2.2), (OX + 6, OY + 1.4)], fill=SILVER_LIGHT, width=1)

    # 盖着的菜盅：银色小圆顶 + 顶端小圆钮
    dome_cx, dome_cy = OX + 8, OY + 2.6
    ellipse(d, [dome_cx - 4.5, dome_cy - 3.2, dome_cx + 4.5, dome_cy + 2.2], fill=SILVER, outline=OUTLINE)
    d.line([(dome_cx - 3, dome_cy - 1.6), (dome_cx - 1, dome_cy - 2.6)], fill=SILVER_LIGHT, width=1)
    ellipse(d, [dome_cx - 1, dome_cy - 4.2, dome_cx + 1, dome_cy - 2.6], fill=SILVER_DARK, outline=OUTLINE)

    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


# ---------------------------------------------------------------------------
# 11. 音符 amb_note_1 / amb_note_2
# ---------------------------------------------------------------------------

def build_note_single():
    W, H = 10, 12
    OX, OY = 2, 1
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    ellipse(d, [OX, OY + 7, OX + 3.2, OY + 9.6], fill=GOLD, outline=OUTLINE)
    d.line([(OX + 3, OY + 8.3), (OX + 3, OY + 1)], fill=GOLD, width=1)
    poly(d, [(OX + 3, OY + 1), (OX + 6, OY + 2.6), (OX + 5.4, OY + 4.4), (OX + 3, OY + 3.4)],
         fill=GOLD, outline=OUTLINE)
    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


def build_note_beamed():
    W, H = 14, 12
    OX, OY = 1, 1
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    ellipse(d, [OX, OY + 7.4, OX + 3.2, OY + 10], fill=GOLD, outline=OUTLINE)
    ellipse(d, [OX + 6, OY + 6.6, OX + 9.2, OY + 9.2], fill=GOLD, outline=OUTLINE)
    d.line([(OX + 3, OY + 8.7), (OX + 3, OY + 1.6)], fill=GOLD, width=1)
    d.line([(OX + 8, OY + 8), (OX + 8, OY + 1)], fill=GOLD, width=1)
    poly(d, [(OX + 3, OY + 1.6), (OX + 8, OY + 1), (OX + 8, OY + 2.6), (OX + 3, OY + 3.2)],
         fill=GOLD, outline=OUTLINE)
    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


# ---------------------------------------------------------------------------
# 12. 花瓣 / 亮片 amb_petal_1 / amb_petal_2
# ---------------------------------------------------------------------------

def build_petal():
    W, H = 6, 5
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    poly(d, [(1, 2.5), (3, 0.8), (5, 2), (3.2, 4)], fill=PINK, outline=OUTLINE, width=1)
    d.point([(2, 1.6)], fill=(255, 220, 224, 255))
    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


def build_sequin():
    W, H = 5, 5
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    poly(d, [(2, 0.5), (3.6, 2), (2, 3.6), (0.5, 2)], fill=GOLD, outline=OUTLINE, width=1)
    d.point([(1.6, 1.5)], fill=GOLD_LIGHT)
    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


# ---------------------------------------------------------------------------
# 13. 小酒杯 amb_cup  约 6x6
# ---------------------------------------------------------------------------

def build_cup():
    # 敬酒用的小酒杯，坐着的宾客举过头顶那个——协调方反馈说画得跟马克杯一样大了，
    # 缩到 4x5 个美术像素（约 8x10 画布像素）。这么小，色块先不描边，最后沿轮廓统一描一圈细边
    W, H = 5, 6
    OX, OY = 1, 1
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)
    ellipse(d, [OX, OY, OX + 3, OY + 1.2], fill=GOLD, outline=None)
    poly(d, [(OX + 0.2, OY + 0.7), (OX + 2.8, OY + 0.7), (OX + 2.3, OY + 2.3), (OX + 0.7, OY + 2.3)],
         fill=WHITE, outline=None)
    d.point([(OX + 0.6, OY + 1.0)], fill=SILVER_LIGHT)
    d.line([(OX + 1.5, OY + 2.3), (OX + 1.5, OY + 3.1)], fill=GOLD, width=1)
    d.point([(OX + 0.8, OY + 3.4), (OX + 1.5, OY + 3.4), (OX + 2.2, OY + 3.4)], fill=GOLD)

    img = outline_from_alpha(img)
    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


# ---------------------------------------------------------------------------
# 14. 桌下红地毯 amb_rug  约 224x136，平贴地面，锚点图片中心
# ---------------------------------------------------------------------------

def build_rug():
    # 2026-09-18 协调方要的：桌子底下的圆地毯。只有外面一圈会露出来（中间被桌椅盖住），
    # 所以没画桌子；颜色特意跟桌布/椅子的红分开，别撞色。全程不做体积，扁扁贴在地上
    W, H = 120, 76
    cx, cy = 60, 38
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    def ell(rx, ry, color):
        ellipse(d, [cx - rx, cy - ry, cx + rx, cy + ry], fill=color, outline=None)

    ell(56, 34, RUG_EDGE_DARK)   # 最外面一圈细的深红边线
    ell(55, 33, RUG_GOLD)        # 金边（比里面的地毯色垫大 2ap，露出 2ap 宽）
    ell(53, 31, RUG_FIELD)       # 地毯主色

    # 花纹一圈：一圈小菱形，靠近金边内侧
    ring_rx, ring_ry = 45, 25
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        px = cx + math.cos(a) * ring_rx
        py = cy + math.sin(a) * ring_ry
        poly(d, [(px, py - 1.7), (px + 1.7, py), (px, py + 1.7), (px - 1.7, py)],
             fill=RUG_PATTERN, outline=None)

    # 中心一小朵花纹（大半会被桌子盖住，露出来也不突兀）
    for i in range(8):
        a = 2 * math.pi * i / 8
        px = cx + math.cos(a) * 7.5
        py = cy + math.sin(a) * 4.4
        poly(d, [(px, py - 1.3), (px + 1.3, py), (px, py + 1.3), (px - 1.3, py)],
             fill=RUG_PATTERN, outline=None)
    ellipse(d, [cx - 1.6, cy - 1.2, cx + 1.6, cy + 1.2], fill=RUG_GOLD, outline=None)

    # 金边高光：左上方一小段（光从左上来），不做体积，只是这一段的金色换成亮一点的
    for deg in range(190, 261, 6):
        a = math.radians(deg)
        px = cx + math.cos(a) * 54.3
        py = cy + math.sin(a) * 32.3
        d.point([(px, py)], fill=RUG_GOLD_HI)
        d.point([(px, py - 1)], fill=RUG_GOLD_HI)

    # 底边（南）一点点阴影：最多 1 个美术像素，贴着地毯主色的下缘描一丝暗色，不叠体积
    shadow_color = (98, 18, 22, 255)
    for deg in range(50, 131, 4):
        a = math.radians(deg)
        px = cx + math.cos(a) * 51.3
        py = cy + math.sin(a) * 29.3
        d.point([(px, py)], fill=shadow_color)

    out = finalize(img, margin_ap=1)
    return out, (out.width // 2, out.height // 2)


# ---------------------------------------------------------------------------
# 15. 舞台花瓶 blk_flower_pot（场景积木，放 tools/layout_v7_tables/，不进 amb_art.json）
#     约 40x72（0.8m 宽 x 1.5m 高），参照 base.png 舞台两侧花瓶
# ---------------------------------------------------------------------------

def _leaf(d, base, tip, width, color):
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    length = math.hypot(dx, dy) or 1.0
    px, py = -dy / length * width, dx / length * width
    mx, my = (bx + tx) / 2.0, (by + ty) / 2.0
    poly(d, [base, (mx + px, my + py), tip, (mx - px, my - py)], fill=color, outline=None)


def build_flower_pot():
    W, H = 24, 40
    OX, OY = 2, 2
    img = new_canvas(W, H)
    d = ImageDraw.Draw(img)

    def P(x, y):
        return (x + OX, y + OY)

    # 叶子先画（在花朵后面），从花瓶瓶口往外放射状展开
    leaf_tips = [
        ((0, 11), LEAF_GREEN_DARK), ((1, 6), LEAF_GREEN), ((6, 2), LEAF_GREEN_LIGHT),
        ((14, 2), LEAF_GREEN_LIGHT), ((19, 6), LEAF_GREEN), ((20, 11), LEAF_GREEN_DARK),
        ((17, 16), LEAF_GREEN_DARK), ((3, 16), LEAF_GREEN_DARK),
    ]
    base = (10, 15)
    for tip, color in leaf_tips:
        _leaf(d, P(*base), P(*tip), 1.9, color)

    # 花瓶：圆润的罐子形，深蓝黑瓷，肩部一点高光（光从左上来）
    body = [
        (9, 16), (11, 16), (13, 18), (15, 22), (14, 26), (12, 29),
        (8, 29), (6, 26), (5, 22), (7, 18),
    ]
    poly(d, [P(x, y) for x, y in body], fill=VASE_DARK, outline=OUTLINE)
    d.line([P(7.4, 19), P(6.2, 22.5)], fill=VASE_DARK_HI, width=1)
    d.line([P(9, 16.4), P(11, 16.4)], fill=GOLD, width=1)  # 瓶口一道细金边
    for px, py in ((6.6, 23), (9, 24), (11.2, 24), (13.6, 23)):
        poly(d, [P(px, py - 1), P(px + 1, py), P(px, py + 1), P(px - 1, py)], fill=GOLD, outline=None)

    # 花朵：红、米白几朵围成一个圆团，每朵一个深色小花心
    flowers = [
        (10, 5, 3.0, RED_LIGHT), (5, 8, 2.4, CREAM), (15, 8, 2.4, RED),
        (7, 11, 2.2, RED), (13, 11, 2.2, CREAM), (10, 10, 2.0, CREAM_SHADE),
        (3, 12.5, 1.8, RED_DARK), (17, 12.5, 1.8, RED_DARK),
    ]
    for fx, fy, r, color in flowers:
        ellipse(d, [P(fx - r, fy - r), P(fx + r, fy + r)], fill=color, outline=OUTLINE)
        ellipse(d, [P(fx - 0.6, fy - 0.6), P(fx + 0.6, fy + 0.6)], fill=GOLD_DARK, outline=None)

    # 小小的深色木托
    draw_box(d, *P(4, 29), 12, 6, 1.8, 2.5, WOOD_LIGHT, WOOD_MID, WOOD_DARK)

    out = finalize(img, margin_ap=1)
    anchor = (out.width // 2, out.height - 1)
    return out, anchor


# ---------------------------------------------------------------------------
# 主流程：生成所有素材
# ---------------------------------------------------------------------------

def main(write_only=None):
    """write_only=None（默认，命令行不带参数跑）：按脚本一直以来的说明，重新生成
    assets/ambience/ 下所有 PNG。传一个名字集合进来时，只有集合里的名字会真的存盘，
    其余的照样算出图（拼 contact.png 要用），但不碰它们对应的文件——
    2026-09-18 协调方只要求改彩带/彩纸/酒杯这三样时用的就是这条路。"""
    generated = {}  # name -> PIL.Image（放大后的最终成品），方便后面拼 contact/mock

    def _should_write(name):
        return write_only is None or name in write_only

    def emit(name, builder):
        """builder 自己已经调用过 finalize()：返回的图是裁切+放大2倍之后的成品，
        anchor 也已经是最终画布像素坐标（比如 out.width//2 这种）。"""
        img, anchor = builder()
        img = binarize_alpha(img)
        if _should_write(name):
            img.save(os.path.join(OUT_DIR, f"{name}.png"), optimize=True)
        ANCHORS[name] = {"size": [img.width, img.height], "anchor": [int(round(anchor[0])), int(round(anchor[1]))]}
        generated[name] = img

    def emit_raw(name, builder):
        """builder 返回半分辨率、裁切之前的原始图 + 那个坐标系下的锚点，
        这里统一裁切、二值化、放大2倍，并把锚点换算成最终坐标——用在锚点不是
        简单几何中心/贴底居中的部件上（比如钢琴，键盘往左伸、琴尾往右尖，画布并不对称）。"""
        raw_img, anchor_ap = builder()
        img, anchor = finalize_with_anchor(raw_img, anchor_ap)
        if _should_write(name):
            img.save(os.path.join(OUT_DIR, f"{name}.png"), optimize=True)
        ANCHORS[name] = {"size": [img.width, img.height], "anchor": [int(anchor[0]), int(anchor[1])]}
        generated[name] = img

    emit_raw("amb_piano", build_piano)
    emit_raw("amb_piano_bench", build_piano_bench)
    emit_raw("amb_cello", build_cello)
    emit("amb_violin", build_violin)
    emit("amb_music_stand", build_music_stand)
    emit("amb_chair", build_chair)
    emit("amb_gift_pile", build_gift_pile)

    for i, (img, anchor) in enumerate(build_streamers(), start=1):
        name = f"amb_streamer_{i}"
        img = binarize_alpha(img)
        if _should_write(name):
            img.save(os.path.join(OUT_DIR, f"{name}.png"), optimize=True)
        ANCHORS[name] = {"size": [img.width, img.height], "anchor": [int(anchor[0]), int(anchor[1])]}
        generated[name] = img

    for i in range(1, 4):
        emit(f"amb_confetti_{i}", lambda i=i: build_confetti(seed=100 + i))

    emit("amb_tray", build_tray)
    emit("amb_note_1", build_note_single)
    emit("amb_note_2", build_note_beamed)
    emit("amb_petal_1", build_petal)
    emit("amb_petal_2", build_sequin)
    emit("amb_cup", build_cup)
    emit("amb_rug", build_rug)

    with open(os.path.join(OUT_DIR, "amb_art.json"), "w", encoding="utf-8") as f:
        json.dump(ANCHORS, f, ensure_ascii=False, indent=2)

    # blk_flower_pot 是场景积木（不是氛围占位图）：存到 tools/layout_v7_tables/，
    # 不写进 amb_art.json；锚点和地面占位椭圆由脚本回报，协调方自己填场景配置
    flower_img, flower_anchor = build_flower_pot()
    if _should_write("blk_flower_pot"):
        os.makedirs(LAYOUT_DIR, exist_ok=True)
        flower_img.save(os.path.join(LAYOUT_DIR, "blk_flower_pot.png"), optimize=True)
    generated["blk_flower_pot"] = flower_img
    flower_footprint_rx = round((flower_img.width / 2.0) * 0.62, 1)  # 木托比花瓶正面宽一点，量出来的占地半径
    flower_footprint_ry = round(flower_footprint_rx * (32.0 / 48.0), 1)  # 纵深按 32:48 的地面比例换算

    # ------------------------------------------------------------------
    # 预览 1：contact.png —— 所有图放大 3 倍排在地砖底上，旁边标英文文件名
    # ------------------------------------------------------------------
    base = Image.open(BASE_PNG).convert("RGB")
    floor_tile = base.crop((870, 810, 1050, 900))  # 从空地砖区域截一块（纯地面，没有桌椅）

    names = list(generated.keys())
    cell_w, cell_h = 190, 190
    slot_w, slot_h = 170, 150  # 图片实际能占的区域，留出四周和标签的空间
    cols = 6
    rows = math.ceil(len(names) / cols)
    sheet_w, sheet_h = cols * cell_w, rows * cell_h

    sheet = Image.new("RGB", (sheet_w, sheet_h))
    for ty in range(0, sheet_h, floor_tile.height):
        for tx in range(0, sheet_w, floor_tile.width):
            sheet.paste(floor_tile, (tx, ty))

    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    for idx, name in enumerate(names):
        col, row = idx % cols, idx // cols
        cx0, cy0 = col * cell_w, row * cell_h
        img = generated[name]
        # 每张图按自己的大小算一个放大倍数，让所有图在格子里显示得差不多大，
        # 不管原图是 150px 的礼物堆还是 5px 的花瓣
        scale = max(1, min(8, slot_w // max(1, img.width), slot_h // max(1, img.height)))
        big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        px = cx0 + (cell_w - big.width) // 2
        py = cy0 + 8 + (slot_h - big.height) // 2
        sheet.paste(big, (px, py), big)
        label = f"{name.replace('amb_', '')} ({img.width}x{img.height})"
        draw.text((cx0 + 6, cy0 + cell_h - 14), label, fill=(40, 24, 20), font=font)

    contact_path = os.path.join(SCRATCH, "contact.png")
    sheet.save(contact_path)

    # ------------------------------------------------------------------
    # 预览 2：mock.png —— 贴到宴会厅舞台附近地面，看搭不搭
    # ------------------------------------------------------------------
    crop_box = (250, 100, 1450, 420)
    mock = base.crop(crop_box).convert("RGBA")
    cx0, cy0 = crop_box[0], crop_box[1]

    def paste_by_anchor(name, target_xy, extra_dx=0, extra_dy=0):
        img = generated[name]
        info = ANCHORS[name]
        ax, ay = info["anchor"]
        tx, ty = target_xy
        px = tx - cx0 - ax + extra_dx
        py = ty - cy0 - ay + extra_dy
        mock.paste(img, (int(round(px)), int(round(py))), img)

    paste_by_anchor("amb_gift_pile", (410, 302))
    paste_by_anchor("amb_piano_bench", (1000, 300))
    paste_by_anchor("amb_piano", (1075, 300))
    paste_by_anchor("amb_chair", (1175, 300))
    paste_by_anchor("amb_cello", (1188, 297))
    paste_by_anchor("amb_music_stand", (1245, 300))
    paste_by_anchor("amb_music_stand", (1315, 300))

    # 撒几条彩带、彩纸在空地砖上：坐标是提前用颜色比对在 base.png 上量出来的纯地砖点，
    # 避开了红毯 (x 630~870)、舞台台阶 (y<250)、礼物堆和乐器那一排
    scatter_spots = [
        (1382, 324), (406, 404), (526, 260), (318, 260), (942, 332),
        (1206, 364), (1222, 252), (598, 364), (278, 364),
    ]
    streamer_names = [f"amb_streamer_{i}" for i in (1, 2, 3, 4, 5, 6)]
    confetti_names = [f"amb_confetti_{i}" for i in (1, 2, 3)]
    rnd = random.Random(7)
    for i, (sx, sy) in enumerate(scatter_spots):
        name = rnd.choice(streamer_names if i % 2 == 0 else confetti_names)
        paste_by_anchor(name, (sx, sy))

    mock_path = os.path.join(SCRATCH, "mock.png")
    mock.convert("RGB").save(mock_path)

    # ------------------------------------------------------------------
    # 回报用的文件清单
    # ------------------------------------------------------------------
    print("=== assets/ambience 文件清单 ===")
    total = 0
    png_files = sorted(f for f in os.listdir(OUT_DIR) if f.endswith(".png"))
    for fn in png_files:
        size = os.path.getsize(os.path.join(OUT_DIR, fn))
        total += size
        print(f"{fn}\t{size} B")
    json_size = os.path.getsize(os.path.join(OUT_DIR, "amb_art.json"))
    print(f"amb_art.json\t{json_size} B")
    print(f"--- PNG 总大小: {total} B ({total/1024:.1f} KB) ---")
    print(f"contact.png -> {contact_path}")
    print(f"mock.png -> {mock_path}")

    flower_path = os.path.join(LAYOUT_DIR, "blk_flower_pot.png")
    flower_size = os.path.getsize(flower_path) if os.path.exists(flower_path) else 0
    print(f"--- {flower_path} ---")
    print(f"blk_flower_pot.png\t{flower_size} B\tsize={flower_img.width}x{flower_img.height}\t"
          f"anchor(贴地中点)={list(flower_anchor)}\t建议地面占位椭圆 rx,ry≈{flower_footprint_rx},{flower_footprint_ry}")


if __name__ == "__main__":
    import sys
    only_arg = None
    for arg in sys.argv[1:]:
        if arg.startswith("--only="):
            only_arg = set(arg.split("=", 1)[1].split(","))
    main(write_only=only_arg)
