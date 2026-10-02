#!/usr/bin/env python3
"""拿 GPT 交的一张宾客图（比如 C01 v1，64×84、一行 16 格）复制出一整套罗曼山庄的人的假图，给 shot.sh --lm_dir 截「全换上」的样子（01 E 10/2）。
假图只放 scratchpad 这类临时地方，不进仓库、不进游戏。
用法：python3 godot/tools/make_lm_fakes.py <宾客图.png> <输出目录>
  宾客 01～12：每位换一个色相（看得出不是同一个人），11、12 是小孩（缩到 53 高贴格子下沿，height_m 1.1）
  服务员 01～06：两行（走路 + 端托盘，第二行加一块灰托盘），tray 点在右手边
  乐手 01～04：照 03 的格子（64×84、80×96、64×96、64×96）取朝下那 4 帧缩放，play 4 格
"""
import colorsys
import json
import os
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
base = Image.open(src).convert("RGBA")
W, H = 64, 84
WALK = {"down": [0, 1, 2, 3], "left": [4, 5, 6, 7], "right": [8, 9, 10, 11], "up": [12, 13, 14, 15]}


def hue_shift(im, d):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            skin = h < 0.12 and 0.15 < s < 0.75 and v > 0.45   # 皮肤（偏橙、不太饱和、亮）别改
            if s > 0.25 and not skin:   # 只改衣服这类有颜色的，皮肤、头发（饱和度低）留着
                r, g, b = colorsys.hsv_to_rgb((h + d) % 1.0, s, v)
            px[x, y] = (int(r * 255), int(g * 255), int(b * 255), a)
    return im


def save(code, im, meta):
    im.save(os.path.join(out, "chr_%s.png" % code))
    json.dump(meta, open(os.path.join(out, "chr_%s.json" % code), "w"))


for i in range(1, 13):
    im = hue_shift(base.copy(), i / 12.0)
    meta = {"frame": [W, H], "frames": WALK, "fps": 8, "height_m": 1.75}
    if i >= 11:
        kid = Image.new("RGBA", im.size)
        for f in range(16):
            cell = im.crop((f * W, 0, f * W + W, H)).resize((int(W * 53 / 84), 53), Image.NEAREST)
            kid.paste(cell, (f * W + (W - cell.width) // 2, H - 53))
        im = kid
        meta["height_m"] = 1.1
    save("LM-GUEST-%02d" % i, im, meta)

for i in range(1, 7):
    one = hue_shift(base.copy(), 0.95 + i * 0.01)
    im = Image.new("RGBA", (W * 16, H * 2))
    im.paste(one, (0, 0))
    im.paste(one, (0, H))
    for f in range(16):
        for x in range(f * W + 38, f * W + 58):
            for y in range(H + 40, H + 44):
                im.putpixel((x, y), (200, 200, 200, 255))
    save("LM-WAITER-%02d" % i, im, {"frame": [W, H], "frames": WALK, "fps": 8, "height_m": 1.75,
                                     "frames_tray": {k: [v + 16 for v in fr] for k, fr in WALK.items()}, "tray": [48, 40]})

for i, (fw, fh) in enumerate([(64, 84), (80, 96), (64, 96), (64, 96)], start=1):
    im = Image.new("RGBA", (fw * 4, fh))
    for f in range(4):
        cell = base.crop((f * W, 0, f * W + W, H))
        k = min(fw / W, fh / H)
        cell = cell.resize((int(W * k), int(H * k)), Image.NEAREST)
        im.paste(cell, (f * fw + (fw - cell.width) // 2, fh - cell.height))
    save("LM-BAND-%02d" % i, im, {"frame": [fw, fh], "frames": {"play": [0, 1, 2, 3]}, "fps": 6})
print("假图出到", out)
