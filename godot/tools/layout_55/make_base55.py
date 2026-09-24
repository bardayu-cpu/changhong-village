#!/usr/bin/env python3
"""55 桌大厅的底图（占位）：GPT 21:30 那张空地面底图（1536×1024）上下拉长，不重画。01 9/24 派，方案 回执/宴会厅55桌-方案.md

拼法：
  上半截（墙、舞台）和下半截（栏杆、大门、东侧门）原样用；中间拉长 M 像素：
  地面：花纹上下 102 像素一个周期（量过，接缝差 7/255），取 y 352～454 那一条竖着铺
  红毯（x 672～824）、右墙（x 1440 往右）：取接缝那一行拉直（红毯花边、右墙的柱子本来就上下不重复，接不齐，拉直至少没有断缝）
  左边：底图里左墙到 y 540 就收了，下面是地面，照地面铺
这是占位：红毯花边拉成了直线、右墙是一根拉长的柱子。正式的要 GPT 出地面瓦片、一段红毯、一段侧墙
用法：python3 tools/layout_55/make_base55.py 出图.png
"""
import sys
from PIL import Image

SRC = "tools/layout_v11_effect/base.png"
FLOOR_Y, FLOOR_P = 352, 102
CARPET = (672, 824)
RIGHT_WALL = 1440
BS = 560            # 下半截从底图这一行开始（东侧门门框在它下面）
M = 10 * FLOOR_P    # 中间拉长多少（地面花纹整周期，上下接得上）


def main():
    b = Image.open(SRC).convert("RGB")
    w, h = b.size
    H = h + M
    out = Image.new("RGB", (w, H))
    out.paste(b.crop((0, 0, w, BS)), (0, 0))
    out.paste(b.crop((0, BS, w, h)), (0, BS + M))
    seam = b.crop((0, BS - 1, w, BS))
    for y in range(BS, BS + M):
        fy = FLOOR_Y + (y - FLOOR_Y) % FLOOR_P
        out.paste(b.crop((0, fy, RIGHT_WALL, fy + 1)), (0, y))
        out.paste(seam.crop((CARPET[0], 0, CARPET[1], 1)), (CARPET[0], y))
        out.paste(seam.crop((RIGHT_WALL, 0, w, 1)), (RIGHT_WALL, y))
    out.save(sys.argv[1])
    print("出了", sys.argv[1], out.size)


if __name__ == "__main__":
    main()
