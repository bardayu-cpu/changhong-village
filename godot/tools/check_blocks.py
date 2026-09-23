#!/usr/bin/env python3
"""把一批积木图摊开看一眼——素材进项目之前必过的一关。

起因（阿鱼 2026-09-22 真机打回乐队那批）：
    我原来只做了「逐块拿去和效果图比色差」，八块全是 0.0 就当验过了。
    **那是个盲点**：抠出来的图粘着原图的背景时，贴回原图当然严丝合缝，
    0.0 只证明「是从这张图上拆的」，证明不了「拆干净了」。
    实际上三个乐手身上挂着成块的红地毯和墙，有一个人的脸被一块墙顶掉了。
    数值测试（不管我写还是 03 写）都抓不住这种事，**只有把图摊开看一眼能抓住**。

用法：
    python3 tools/check_blocks.py <图所在目录> [输出png]

出什么：
    一张总览图，每块按原样画在白底和深底上（白底看深色边、深底看浅色边），
    底下标出自动量出来的三个可疑处：
      · 背景残留：不透明像素里有多大一块贴着图的边、而且颜色扎堆（多半是抠的时候带出来的底）
      · 破洞：silhouette 里面整块透明（人身上缺一块）
      · 半透明边：alpha 不是只有 0 和 255（交付规格要求只有 0 和 255）
    自动量的只是提示，**最后还是得拿眼睛看那张图**。
"""
import sys, os, glob, json
from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
WHITE = (255, 255, 255)
DARK = (28, 22, 30)


def font(n):
    try:
        return ImageFont.truetype(FONT, n)
    except Exception:
        return ImageFont.load_default()


def alpha_stats(im):
    """alpha 有几档、是不是只有 0 和 255"""
    vals = set(im.getchannel("A").getdata())
    return len(vals), (vals <= {0, 255})


def holes(im):
    """silhouette 里面的整块透明：从四边灌水，灌不到又透明的就是破洞"""
    w, h = im.size
    a = im.getchannel("A").load()
    seen = [[False] * w for _ in range(h)]
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if a[x, y] < 128 and not seen[y][x]:
                seen[y][x] = True
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if a[x, y] < 128 and not seen[y][x]:
                seen[y][x] = True
                stack.append((x, y))
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and a[nx, ny] < 128:
                seen[ny][nx] = True
                stack.append((nx, ny))
    return sum(1 for y in range(h) for x in range(w) if a[x, y] < 128 and not seen[y][x])


def edge_slabs(im):
    """背景残留的粗测：贴着图边缘那一圈里，有多少不透明像素的颜色和「大块同色区」一致。
    抠干净的人物边缘是杂色（头发、衣服、乐器）；带出来的地毯／墙是大片同一种色。"""
    w, h = im.size
    px = im.load()
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 128:
                continue
            # 贴着透明的那一圈
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] < 128:
                    edge.append((px[x, y][0] >> 4, px[x, y][1] >> 4, px[x, y][2] >> 4))
                    break
    if not edge:
        return 0.0, 0
    bins = {}
    for c in edge:
        bins[c] = bins.get(c, 0) + 1
    top = max(bins.values())
    return top / float(len(edge)), len(edge)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    d = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/blocks_check.png"
    files = sorted(glob.glob(os.path.join(d, "*.png")))
    if not files:
        print("这个目录里没有 png：", d)
        sys.exit(1)
    ims = [(os.path.basename(f), Image.open(f).convert("RGBA")) for f in files]
    # 每张按原比例缩进一个固定格子，太小的就按整数倍放大（像素图放大要用 NEAREST）
    CELL, PAD, HEAD, CAP = 170, 10, 62, 20
    COLS = min(6, max(1, len(ims)))
    lines = []
    for name, im in ims:
        n_a, clean = alpha_stats(im)
        hol = holes(im)
        slab, _ = edge_slabs(im)
        flags = []
        if not clean:
            flags.append("alpha %d 档（该只有 0/255）" % n_a)
        if hol > 20:
            flags.append("破洞 %d 像素" % hol)
        if slab > 0.28:
            flags.append("边上 %.0f%% 是同一种色（多半带了底）" % (slab * 100))
        lines.append("%-24s %s" % (name.replace(".png", ""), "、".join(flags) if flags else "自动检查没报警——还是得看图"))
    rows = (len(ims) + COLS - 1) // COLS
    band_h = CELL + CAP
    W = PAD * 2 + COLS * (CELL + PAD)
    H = HEAD + rows * (band_h * 2 + 12) + 14 + len(lines) * 20 + PAD
    sh = Image.new("RGB", (W, H), (242, 242, 244))
    dr = ImageDraw.Draw(sh)
    dr.text((PAD, 8), "积木摊开看：每块上白底、下深底（接进项目之前必看这一眼）", font=font(19), fill=(20, 20, 20))
    dr.text((PAD, 34), "抠干净的图，边上只该有人物本身。粘着成片的地毯／墙、或者人身上缺一块，就是没抠干净。",
            font=font(14), fill=(90, 90, 90))
    for i, (name, im) in enumerate(ims):
        k = max(1, int(CELL / max(im.width, im.height))) if max(im.width, im.height) <= CELL else 0
        if k:
            thumb = im.resize((im.width * k, im.height * k), Image.NEAREST)
        else:
            r = CELL / float(max(im.width, im.height))
            thumb = im.resize((max(1, int(im.width * r)), max(1, int(im.height * r))), Image.NEAREST)
        cx = PAD + (i % COLS) * (CELL + PAD)
        cy = HEAD + (i // COLS) * (band_h * 2 + 12)
        for b, bgc in enumerate((WHITE, DARK)):
            cell = Image.new("RGB", (CELL, CELL), bgc)
            cell.paste(thumb, ((CELL - thumb.width) // 2, (CELL - thumb.height) // 2), thumb)
            sh.paste(cell, (cx, cy + b * band_h))
        dr.text((cx, cy + 2 * band_h - CAP + 2), name.replace(".png", "").replace("_player", ""),
                font=font(13), fill=(60, 60, 60))
    y = HEAD + rows * (band_h * 2 + 12) + 8
    for i, t in enumerate(lines):
        bad = "没报警" not in t
        dr.text((PAD, y + i * 20), t, font=font(14), fill=(170, 40, 40) if bad else (70, 110, 70))
    sh.save(out)
    print("出了：", out)
    for t in lines:
        print("  " + t)


if __name__ == "__main__":
    main()
