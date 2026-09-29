#!/usr/bin/env python3
"""试一套别人的零件包（01 D 9/29 派）：看「先画零件、再拼场景」这条路走不走得通。
包：godot/参考/拼图构建贝旺/（别人的素材，只拿来试，不进仓库、不进游戏；.gitignore 里挡着，.gdignore 让 Godot 不导入）
用这套零件拼一块 1536×1024：地面铺瓦片，放十几件房子、树、路、小物，出一张图 回执/零件包试拼-拼图构建贝旺.png

这套包没有地面瓦片，也没有 JSON，拼法全在这个脚本里：
  地面：从一块草皮中间切 96×96（包里没有能无缝铺的草），2×2 左右上下镜像拼成 192×192 再铺，保证没有硬接缝；再撒几块不规则草皮打破重复
  每件：实画部分（透明度 >16）的下沿中点当脚点；包里每件底下留的空白 0～61 不等，不能拿画布下沿当脚点
  透明度：包里实心部分只有 249～251（整件约 2% 半透明），拼之前一律改成 0 或 255（>=128 当实心）
  前后：按脚点 y 从北往南画，南边的挡北边的
  比例：原样用，不缩放（包里的人约 100 高；我们的人 84，要缩就得 0.84 倍，像素画缩非整数倍会糊，见回执）
用法：python3 tools/parts_pack_try.py [出图路径]
"""
import os
import sys

from PIL import Image, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.join(HERE, "..", "参考", "拼图构建贝旺", "拼图构建贝旺")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "回执", "零件包试拼-拼图构建贝旺.png")
W, H = 1536, 1024


def load(rel, rot=0, flip=False):
    im = Image.open(os.path.join(PACK, rel)).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)   # 半透明改成 0/255
    im.putalpha(a)
    if rot:
        im = im.rotate(rot, expand=True)
    if flip:
        im = ImageOps.mirror(im)
    bb = im.getchannel("A").getbbox()
    return im, bb


def ground():
    src = Image.open(os.path.join(PACK, "草甸自然", "asset_002.png")).convert("RGB").crop((48, 40, 144, 136))
    t = Image.new("RGB", (192, 192))
    t.paste(src, (0, 0))
    t.paste(ImageOps.mirror(src), (96, 0))
    t.paste(ImageOps.flip(src), (0, 96))
    t.paste(ImageOps.flip(ImageOps.mirror(src)), (96, 96))
    g = Image.new("RGBA", (W, H))
    for y in range(0, H, 192):
        for x in range(0, W, 192):
            g.paste(t, (x, y))
    return g


# 平贴在地上的（路、草皮）：按左上角贴，先画
FLAT = [
    ("草甸自然/asset_006.png", 60, 560, 0), ("草甸自然/asset_007.png", 1230, 610, 0), ("草甸自然/asset_012.png", 540, 40, 0),
]
# 土路：按实画部分首尾挨着接（不按画布摆），看包里的路能不能接成一条。T 字路口实画中心放在 (768, 430)，
# 往南竖着接两段，往东西各接两段（包里只有竖的直路，横的是转 90°）
ROAD_T = "道路系统/-_2.png"
ROAD = "道路系统/-.png"


def road(im):
    t, bb = load(ROAD_T)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    tx, ty = 768 - tw // 2, 430 - th // 2      # T 字实画左上角
    im.alpha_composite(t, (tx - bb[0], ty - bb[1]))
    v, vb = load(ROAD)
    vh = vb[3] - vb[1]
    stem_x = 768 - (vb[0] + vb[2]) // 2
    y = ty + th
    for k in range(2):
        im.alpha_composite(v, (stem_x, y - vb[1]))
        y += vh
    h, hb = load(ROAD, 90)
    hw = hb[2] - hb[0]
    # 横的接在 T 字左右两端，竖直方向对齐 T 字横梁（实画上半截的中线）
    bar_mid = ty + (th * 3) // 10
    hy = bar_mid - (hb[1] + hb[3]) // 2
    x = tx
    for k in range(2):
        x -= hw
        im.alpha_composite(h, (x - hb[0], hy))
    x = tx + tw
    for k in range(2):
        im.alpha_composite(h, (x - hb[0], hy))
        x += hw
    return (tx, ty, tw, th)
# 立着的：给脚点（实画下沿中点），按脚点 y 排前后
STAND = [
    ("阿尔卑斯住宅/asset_001.png", 330, 390), ("阿尔卑斯住宅/asset_002.png", 1200, 392),
    ("农业建筑/__3.png", 300, 930), ("阿尔卑斯住宅/asset_013.png", 1240, 880),
    ("针叶森林/5.png", 90, 330), ("针叶森林/asset_004.png", 560, 300), ("针叶森林/asset_003.png", 980, 300),
    ("针叶森林/asset_009.png", 1450, 350), ("针叶森林/asset_006.png", 620, 1000), ("针叶森林/asset_007.png", 930, 1010),
    ("针叶森林/_.png", 1480, 990),
    ("农业建筑/Eljl_2.png", 560, 720), ("生活小物/asset_011.png", 1000, 700),
    ("生活小物_2/asset_066.png", 1060, 610), ("生活小物_2/asset_068.png", 460, 640),
    ("生活小物_2/asset_080.png", 740, 520), ("生活小物_2/asset_081.png", 820, 700), ("生活小物_2/asset_086.png", 880, 520),
    ("生活小物/asset_016.png", 1120, 980), ("生活小物/asset_014.png", 470, 470),
]


def main():
    im = ground()
    for rel, x, y, rot in FLAT:
        t, bb = load(rel, rot)
        im.alpha_composite(t, (x, y))
    road(im)
    placed = []
    for rel, fx, fy in STAND:
        t, bb = load(rel)
        # 脚点 = 实画下沿中点
        ox = fx - (bb[0] + bb[2]) // 2
        oy = fy - bb[3]
        placed.append((fy, rel, t, ox, oy))
    for fy, rel, t, ox, oy in sorted(placed, key=lambda p: p[0]):
        im.alpha_composite(t, (ox, oy))
    im.convert("RGB").save(OUT)
    print("拼好了", OUT, "草皮 %d 块、路 7 段、立着 %d 件" % (len(FLAT), len(STAND)))


if __name__ == "__main__":
    main()
