#!/usr/bin/env python3
"""验瓦片「拼起来看不出接缝」（55 桌大厅的地砖、红毯、侧墙，规格见 回执/宴会厅55桌-瓦片规格.md）。

做三件事：
1. 硬规格：尺寸对不对（--size 宽x高）、有没有透明（地砖、红毯不许透明；墙段左边或右边可以透明，--alpha-ok）
2. 接缝差：上边一行和下边一行比、左边一列和右边一列比（瓦片首尾相接时挨着的就是这两行／两列），
   平均每个颜色通道差多少（0～255）。不超过 8 算过（现在底图地砖花纹上下接的差是 7）
   --dir v 只验上下（红毯、侧墙竖着铺），--dir hv 上下左右都验（地砖）
3. 出一张拼好的样子：地砖 4×4、红毯和墙竖着 6 段，接缝处画一道细线标出来（另存一张不画线的，看得出接缝就是没过）

用法：python3 tools/check_tile.py 瓦片.png --size 80x52 --dir hv [--alpha-ok] [--out 出图前缀]
退出码：0 过，1 没过
"""
import argparse
import sys

from PIL import Image, ImageChops, ImageDraw, ImageStat


def edge_diff(a, b):
    return sum(ImageStat.Stat(ImageChops.difference(a, b)).mean[:3]) / 3.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tile")
    ap.add_argument("--size", required=True, help="宽x高，比如 80x52")
    ap.add_argument("--dir", default="hv", choices=["v", "hv"])
    ap.add_argument("--alpha-ok", action="store_true", help="允许透明（侧墙段靠厅外那边）")
    ap.add_argument("--limit", type=float, default=8.0)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    ok = True
    im = Image.open(a.tile)
    w, h = (int(v) for v in a.size.lower().split("x"))
    print("瓦片 %s  %d×%d  %s" % (a.tile, im.width, im.height, im.mode))
    if im.size != (w, h):
        print("  不行 尺寸该是 %d×%d" % (w, h))
        ok = False
    rgba = im.convert("RGBA")
    alpha = rgba.getchannel("A")
    if alpha.getextrema()[0] < 255 and not a.alpha_ok:
        print("  不行 有透明像素（地砖、红毯要整块不透明）")
        ok = False
    rgb = rgba.convert("RGB")
    dv = edge_diff(rgb.crop((0, 0, im.width, 1)), rgb.crop((0, im.height - 1, im.width, im.height)))
    print("  %s 上下接缝差 %.1f（不超过 %.0f）" % ("好" if dv <= a.limit else "不行", dv, a.limit))
    ok = ok and dv <= a.limit
    if a.dir == "hv":
        dh = edge_diff(rgb.crop((0, 0, 1, im.height)), rgb.crop((im.width - 1, 0, im.width, im.height)))
        print("  %s 左右接缝差 %.1f（不超过 %.0f）" % ("好" if dh <= a.limit else "不行", dh, a.limit))
        ok = ok and dh <= a.limit
    if a.out:
        nx, ny = (4, 4) if a.dir == "hv" else (1, 6)
        sheet = Image.new("RGBA", (im.width * nx, im.height * ny), (0, 0, 0, 0))
        for j in range(ny):
            for i in range(nx):
                sheet.paste(rgba, (i * im.width, j * im.height))
        sheet.save(a.out + "-拼.png")
        marked = sheet.copy()
        d = ImageDraw.Draw(marked)
        for j in range(1, ny):
            d.line([(0, j * im.height), (marked.width, j * im.height)], fill=(0, 200, 255, 160))
        for i in range(1, nx):
            d.line([(i * im.width, 0), (i * im.width, marked.height)], fill=(0, 200, 255, 160))
        marked.save(a.out + "-标接缝.png")
        print("  拼好的样子：%s-拼.png（不画线，看得出接缝就是没过）、%s-标接缝.png" % (a.out, a.out))
    print("RESULT", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
