# -*- coding: utf-8 -*-
# 画风定稿板（阿鱼 9/24 嫌 GPT 画风老跑偏，01 让 02 拼一张定死的）：全用已经过了的图拼，不画新的。
# 每样放原大一份，再放一块 3 倍的局部，看清像素块多大、描边多粗。
# 用法：python3 godot/tools/make_style_board.py            出定稿板
#       python3 godot/tools/make_style_board.py 新图.png [更多新图…]   出「新图 vs 定稿板」并排对照（1 倍、3 倍各一张）
import sys, os
from PIL import Image, ImageDraw, ImageFont

SHARE = "/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作"
GODOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
HALL = SHARE + "/地图一-苏七镇/罗曼山庄/001-宴会厅"
OUT = SHARE + "/claude-画风定稿板.png"
F = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 26)
F2 = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 20)
BG = (242, 236, 226)
INK = (40, 30, 30)

def rgba(p):
    return Image.open(p).convert("RGBA")

def on_bg(im, col=BG):
    b = Image.new("RGBA", im.size, col + (255,))
    b.alpha_composite(im)
    return b.convert("RGB")

def x3(im):
    return im.resize((im.width * 3, im.height * 3), Image.NEAREST)

def row(ims, gap=12):
    w = sum(i.width for i in ims) + gap * (len(ims) - 1)
    h = max(i.height for i in ims)
    o = Image.new("RGB", (w, h), BG)
    x = 0
    for i in ims:
        o.paste(i, (x, 0))
        x += i.width + gap
    return o

def pieces():
    """定稿板上的几样：[(标题, 原大那张, 3 倍那张)]"""
    out = []
    lake = Image.open(SHARE + "/地图一-苏七镇/罗曼山庄/005-湖边/素材图/preview_lake_a_v5.png").convert("RGB")
    # 只截亭子、栈道、水面那一块干净的：原来截得宽，左下角带进一截被切成方块的柳树（接缝），01 9/24 说「标准」里不能有这个；
    # 再宽一点水面上会露出一道横着的拼块缝，这个宽度刚好被亭子顶和灯笼挡住
    lk = lake.crop((548, 20, 962, 680))
    out.append(("湖边场景（preview_lake_a_v5：亭子、栈道、水面）", lk, x3(lake.crop((600, 60, 780, 200)))))
    st = rgba(HALL + "/积木/blk_banquet_band_stage_v4.png")
    out.append(("宴会厅乐队整块舞台（v4，在游戏里）", on_bg(st), x3(on_bg(st.crop((150, 20, 290, 130))))))
    crops = [("水稻", "crop_01"), ("草莓", "crop_02"), ("玉米", "crop_04"), ("辣椒", "crop_09")]
    for name, cid in crops:
        tiles = [on_bg(rgba(f"{GODOT}/assets/minigames/{cid}/step_{k:02d}.png")) for k in range(10)]
        out.append((f"作物成长十级·{name}（在游戏里）", row(tiles, 6), row([x3(tiles[4]), x3(tiles[8])])))
    girl = [on_bg(rgba(f"{HALL}/积木/chr_catch_player_{n}v1.png")) for n in ["left_", "", "right_"]]
    out.append(("接彩头·抱篮子的小姑娘（左、正、右）", row(girl), row([x3(g) for g in girl])))
    return out

def board():
    blocks = []
    for title, one, three in pieces():
        t = Image.new("RGB", (max(one.width + three.width + 40, 1200), 40), BG)
        ImageDraw.Draw(t).text((0, 6), title, fill=INK, font=F)
        cap1 = Image.new("RGB", (one.width, 28), BG); ImageDraw.Draw(cap1).text((0, 2), "原大", fill=(120, 100, 90), font=F2)
        cap3 = Image.new("RGB", (three.width, 28), BG); ImageDraw.Draw(cap3).text((0, 2), "局部放大 3 倍（看像素块大小、描边粗细）", fill=(120, 100, 90), font=F2)
        body = row([col([cap1, one]), col([cap3, three])], 40)
        blocks.append(col([t, body]))
    head = Image.new("RGB", (1200, 110), BG)
    d = ImageDraw.Draw(head)
    d.text((0, 10), "苏七镇奇缘 · 画风定稿板", fill=INK, font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 40))
    d.text((0, 66), "全是已经过了的图，不画新的。GPT 每交一张新图，都拿来和这张比是不是一家的（阿鱼 9/24）", fill=(120, 100, 90), font=F2)
    return col([head] + blocks, 36, pad=30)

def col(ims, gap=8, pad=0):
    w = max(i.width for i in ims) + pad * 2
    h = sum(i.height for i in ims) + gap * (len(ims) - 1) + pad * 2
    o = Image.new("RGB", (w, h), BG)
    y = pad
    for i in ims:
        o.paste(i, (pad, y))
        y += i.height + gap
    return o

def compare(paths, name=""):
    """新交的一批和定稿板并排：1 倍一张、3 倍一张（定稿板取舞台、作物、小姑娘；湖边太大不放）。一批拼成一排出一份"""
    ref = pieces()
    ref_1 = [p[1] for p in ref[1:]]
    ref_3 = [p[2] for p in ref[1:]]
    ims = [Image.open(p).convert("RGBA") for p in paths]
    new1 = row([on_bg(i) for i in ims])
    # 3 倍：大图只取左上一块，免得一张图占满
    new3 = row([x3(on_bg(i if i.width <= 200 else i.crop((0, 0, 200, min(i.height, 200))))) for i in ims[:6]])
    if not name:
        name = os.path.splitext(os.path.basename(paths[0]))[0] + (f"等{len(paths)}张" if len(paths) > 1 else "")
    outs = []
    for tag, new, refs in [("1倍", new1, ref_1), ("3倍", new3, ref_3)]:
        t = Image.new("RGB", (1400, 40), BG)
        ImageDraw.Draw(t).text((0, 6), f"新交的 {name}（上）vs 画风定稿板（下）· {tag}", fill=INK, font=F)
        o = col([t, new, Image.new("RGB", (10, 20), BG), col(refs, 12)], 10, pad=20)
        out = os.path.join(os.path.dirname(OUT), f"claude-画风对照-{name}-{tag}.png")
        o.save(out)
        outs.append(out)
        print("出了", out)
    return outs

if __name__ == "__main__":
    if len(sys.argv) > 1:
        args = [a for a in sys.argv[1:] if not a.startswith("--name=")]
        nm = next((a[7:] for a in sys.argv[1:] if a.startswith("--name=")), "")
        compare(args, nm)
    else:
        b = board()
        b.save(OUT)
        print("出了", OUT, b.size)
