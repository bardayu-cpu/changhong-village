#!/usr/bin/env python3
"""从原底图（GPT 9/24 21:30 的空地面底图）抠出「不是地面、不是红毯」的部分，盖在瓦片上面（01 9/24 定的拼法，
规格见 回执/宴会厅55桌-瓦片规格.md）：地面、红毯全厅用 GPT 的瓦片重铺，北墙、婚礼台、墙上半截、栏杆、大门、东侧门原样用。

怎么抠：
  地面 = 从厅中间一点出发、颜色像地砖（米色砖面、砖缝、橘色小花）且连在一起的像素。
         只认连着的，台子、墙、栏杆里零星的金色花纹颜色再像也不算地面
  红毯 = 婚礼台台阶下沿（y 268）到大门方毯上沿（y 868，量的：这一行起红毯外沿从 661～835 一下宽到 628～869）之间的梯形（透视，越往下越宽；两条边照底图量的，外面再放 3 像素）
  剩下的就是积木。一整张抠完，按接缝行 y 560 切成上下两块：
    blk_hall_upper.png（y 0～560：北墙、婚礼台、两边墙上半截）
    blk_hall_lower.png（y 560～1024：两边墙收口、栏杆、东侧门、大门方毯）
  抠完去掉孤零零的小点（地面上被认成积木的零星像素，连在一起不到 40 像素的）
用法：python3 tools/layout_55/cut_base_blocks.py [检查图输出目录]
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "layout_v11_effect", "base.png")
SEAM = 560
SEED = (300, 600)
CARPET_TOP, CARPET_BOTTOM = 268, 868   # 台阶下沿 y 266 上下；大门方毯从 y 868 变宽


def floorish(c):
    r, g, b = c
    cream = r >= 205 and 160 <= g <= 222 and 115 <= b <= 185 and r - b > 40
    flower = r > 195 and 100 < g < 185 and b < 125 and r - g > 35
    return cream or flower


def carpet_edges(y):
    # 外沿（连金边）照底图量：y 320 左 684 右 810，y 700 左 666 右 831；再往外放 3 像素
    t = (y - 320) / 380.0
    left = 684 + (666 - 684) * t
    right = 810 + (831 - 810) * t
    return left - 3, right + 3


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else None
    base = Image.open(SRC).convert("RGBA")
    w, h = base.size
    px = base.load()
    # 1. 像地砖的像素
    cand = Image.new("L", (w, h), 0)
    cp = cand.load()
    for y in range(h):
        for x in range(w):
            if floorish(px[x, y][:3]):
                cp[x, y] = 255
    # 红毯梯形先算进候选（不然地面被红毯隔成左右两半，只找得到一半）
    for y in range(CARPET_TOP, CARPET_BOTTOM):
        l, r = carpet_edges(y)
        for x in range(int(l), int(r) + 1):
            cp[x, y] = 255
    # 2. 从厅中间连通着找：连着的才是地面
    ImageDraw.floodfill(cand, SEED, 128, thresh=0)
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if cp[x, y] == 128:
                ap[x, y] = 0
    # 3. 红毯梯形
    for y in range(CARPET_TOP, CARPET_BOTTOM):
        l, r = carpet_edges(y)
        for x in range(int(l), int(r) + 1):
            ap[x, y] = 0
    # 3b. 补缝：婚礼台、大门方毯里的浅色花纹颜色像地砖，边上连着地面就会被挖成一道缝。
    #     婚礼台（x 505～990、y 190～270）每一列从上往下补满到这一列最下面那个不透明像素；
    #     大门方毯（y 868 起、x 600～900）每一行补满最左到最右不透明像素之间
    for x in range(505, 991):
        low = -1
        for y in range(190, 271):
            if ap[x, y]:
                low = y
        for y in range(190, low + 1):
            ap[x, y] = 255
    for y in range(CARPET_BOTTOM, h):
        xs = [x for x in range(600, 901) if ap[x, y]]
        if xs:
            for x in range(xs[0], xs[-1] + 1):
                ap[x, y] = 255
    # 4. 去掉孤零零的小点（连在一起不到 40 像素的不透明块）
    seen = bytearray(w * h)
    removed = 0
    for y in range(h):
        for x in range(w):
            if ap[x, y] == 0 or seen[y * w + x]:
                continue
            stack = [(x, y)]
            comp = []
            seen[y * w + x] = 1
            # 整块数完再判（中途停下的话，大块里没数到的像素会被当成小点删掉，留下针眼）
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and ap[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            if len(comp) <= 40:
                for cx, cy in comp:
                    ap[cx, cy] = 0
                removed += len(comp)
    out = base.copy()
    out.putalpha(alpha)
    upper = out.crop((0, 0, w, SEAM))
    lower = out.crop((0, SEAM, w, h))
    upper.save(os.path.join(HERE, "blk_hall_upper.png"))
    lower.save(os.path.join(HERE, "blk_hall_lower.png"))
    print("抠好了：blk_hall_upper.png %s、blk_hall_lower.png %s；去掉零星小点 %d 像素" % (upper.size, lower.size, removed))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        # 检查图：积木盖在品红和绿底上，看边上有没有带出地砖、有没有缺
        for name, col in (("品红", (255, 0, 255, 255)), ("绿", (0, 190, 0, 255))):
            bg = Image.new("RGBA", (w, h), col)
            bg.alpha_composite(out)
            bg.convert("RGB").save(os.path.join(out_dir, "抠图-%s底.png" % name))


if __name__ == "__main__":
    main()
