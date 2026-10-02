#!/usr/bin/env python3
"""开屏图（打开小程序最先看到的加载页，01 E 10/3）：把一张整图做成加载页用的 wxgame/splash/splash.jpg（1080×1920，jpg）。
GPT 交了开屏图（任务：共用文件夹 claude-任务-开屏页.md，540×960 和 1080×1920 两张）就拿 1080×1920 那张跑这个；
图还没到时 --fake：拿宴会厅北边背景当假图，正中截一块竖的，写上「苏七镇奇缘」占位标题（GPT 的图里标题是画好的），最下面五分之一压暗一点给进度条。
动起来的东西（推近、灯笼闪、标题金光、飘花瓣、进度条）都在 wxgame/splash.js 里画，图换了只要改那边 SPLASH 里灯笼、标题的位置。
用 Python 自带的 PIL 转，不用下载别的工具。

用法：python3 godot/tools/splash/make_splash.py GPT的图.png        → wxgame/splash/splash.jpg
      python3 godot/tools/splash/make_splash.py --fake             → 用宴会厅背景做假图
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "wxgame", "splash", "splash.jpg")
W, H = 1080, 1920
QUALITY = 80   # 1080×1920 存成 jpg 大约 200～400 KB（像素画颗粒多，压不太下去）；加载页整套尽量 ≤1 MB


def fake():
    bg = Image.open(os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55", "base.png")).convert("RGB")
    im = bg.crop((480, 0, 1056, 1024)).resize((W, H), Image.LANCZOS)   # 北边正中，囍和舞台在中间
    d = ImageDraw.Draw(im)
    font = None
    for f in ["/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc"]:
        if os.path.exists(f):
            font = ImageFont.truetype(f, 150)
            break
    t = "苏七镇奇缘"
    bw = d.textlength(t, font=font)
    x, y = (W - bw) / 2, 700
    for dx in range(-8, 9, 2):
        for dy in range(-8, 9, 2):
            d.text((x + dx, y + dy), t, font=font, fill=(110, 20, 20))
    d.text((x, y), t, font=font, fill=(240, 200, 90))
    d.text((W / 2, 900), "（假图：宴会厅北边背景，等 GPT 的开屏图）", font=ImageFont.truetype(font.path, 34), fill=(120, 60, 40), anchor="mt")
    shade = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shade)
    for i in range(int(H * 0.2)):
        a = int(150 * i / (H * 0.2))
        sd.line([(0, int(H * 0.8) + i), (W, int(H * 0.8) + i)], fill=a)
    im = Image.composite(Image.new("RGB", (W, H), (40, 10, 10)), im, shade)
    return im


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(64)
    if sys.argv[1] == "--fake":
        im = fake()
    else:
        im = Image.open(sys.argv[1]).convert("RGB")
        if im.size != (W, H):
            print("图是 %s，拉成 %dx%d" % (im.size, W, H))
            im = im.resize((W, H), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT, "JPEG", quality=QUALITY, optimize=True, progressive=True)
    print("开屏图 %s %d KB" % (OUT, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
