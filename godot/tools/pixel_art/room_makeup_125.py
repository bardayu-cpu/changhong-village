#!/usr/bin/env python3
"""化妆间 · 家具 1.25 倍（庄Z1 10/5 晚派，派活单 godot/回执/派活-化妆间1点25倍-Z2-1006.md 3f803b4；庄Z2 写）。
阿鱼：「1.25 倍蛮合适的」「我感觉尺寸已经很合适了」。底线：人不动（84 高）；家具从 GPT 4 倍原图直接缩，别拿 1 倍图放大。

缩法照庄Z4 godot/回执/化妆间-大小几档示意/画1.25倍效果.py（e0c68d9）：
  - 底图 + 60 件都从共用文件夹 化妆间-精修-v1/ 的 4 倍原图直接 ×0.3125 最近邻（= 1 倍 ×1.25）
  - 整间一套 64 色：这次全部图拼一张现取（八叉树、不抖动），全部重压；透明 ≥128 算不透明，压成二值
  - 位置照零件表 ×0.3125：左上角、着地线；占地、座位照代码零件那格（1 倍）×1.25，占地下沿对齐新着地线
  - 门洞、换装点 ×1.25；墙、能走的范围由导入器按画布宽换算（效果图坐标 × 675/941）
整间 675×1200（比手机一屏宽 135、高 240），layout 写 view_h 960：一屏照旧看 960 高，人跟别的屋子一样大，镜头左右上下跟人走。
出拆景包交 tools/import_makeup_blocks.py（--canvas=675x1200 --view_h=960）。

用法：python3 godot/tools/pixel_art/room_makeup_125.py [--preview 目录]
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import room_makeup_gpt as gpt
import room_makeup_ref as ref

K4 = 1.25 / 4            # 4 倍原图 → 游戏里
K1 = 1.25                # 1 倍代码零件的坐标 → 游戏里
W, H = round(ref.CW * K1), round(ref.CH * K1)   # 675×1200
COLORS = 64


def shrink(path):
    im = Image.open(path).convert("RGBA")
    s = im.resize((round(im.width * K4), round(im.height * K4)), Image.NEAREST)
    a = s.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    return s.convert("RGB"), a


def build():
    table = {r["名字"]: r for r in json.load(open(gpt.TABLE, encoding="utf-8"))["零件"]}
    ref.build_all()                              # 代码零件：占地、座位（1 倍）
    names = ["base"] + [p["id"] for p in ref.PIECES]
    miss = [n for n in names if not os.path.exists(os.path.join(gpt.GPT_DIR, n + ".png"))]
    if miss:
        raise SystemExit("GPT 4 倍原图不齐：%s" % "、".join(miss))
    raw = {n: shrink(os.path.join(gpt.GPT_DIR, n + ".png")) for n in names}
    if raw["base"][0].size != (W, H):
        raise SystemExit("底图缩完 %s，应是 %d×%d" % (raw["base"][0].size, W, H))
    # 整间一套 64 色：全部图拼一张取色（透明的地方不算）
    sheet = Image.new("RGB", (max(r.width for r, _ in raw.values()), sum(r.height for r, _ in raw.values())))
    y = 0
    for r, a in raw.values():
        sheet.paste(Image.composite(r, Image.new("RGB", r.size), a), (0, y))
        y += r.height
    pal = sheet.quantize(colors=COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)

    def q(n):
        r, a = raw[n]
        t = r.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
        t.putalpha(a)
        return t

    base = q("base")
    base.putalpha(255)
    pieces = []
    for p in ref.PIECES:
        t = table[p["id"]]
        foot = round(t["foot_y"] * K4)
        fx, fy, fw, fh = p["footprint"]
        x0, x1 = round(fx * K1), round((fx + fw) * K1)
        y0 = round(fy * K1)
        pieces.append({"id": p["id"], "img": q(p["id"]), "x": round(t["x"] * K4), "y": round(t["y"] * K4), "foot": foot,
                       "footprint": [x0, y0, x1 - x0, foot - y0],
                       "seats": [(round(sx * K1), round(sy * K1)) for (sx, sy) in p["seats"]]})
    cols = set()
    for im in [base] + [p["img"] for p in pieces]:
        cols.update(c[:3] for c in im.getdata() if c[3])
    print("1.25 倍：%d×%d，底图 + %d 件，整间 %d 色（≤ %d）" % (W, H, len(pieces), len(cols), COLORS))
    return base, pieces


def write_package(folder, base, pieces):
    os.makedirs(folder, exist_ok=True)
    base.save(os.path.join(folder, "base.png"))
    items = []
    for p in pieces:
        f = "blk_%s.png" % p["id"]
        p["img"].save(os.path.join(folder, f))
        it = {"id": p["id"], "file": f, "x": p["x"], "y": p["y"], "w": p["img"].width, "h": p["img"].height,
              "foot_y": p["foot"], "footprint": p["footprint"]}
        if p["seats"]:
            it["seats"] = p["seats"]
        items.append(it)
    R = lambda v: round(ref.R(v) * K1)   # 效果图坐标 → 1 倍 → ×1.25
    d = {"说明": "tools/pixel_art/room_makeup_125.py 化妆间家具 1.25 倍（庄Z2）", "image": {"w": W, "h": H}, "base": "base.png",
         "doors": [{"id": "south", "rect": [R(395), R(1500), R(545) - R(395), R(50)]}],
         "spots": {"dress": [R(240), R(1238)]}, "blocked": [], "items": items}
    json.dump(d, open(os.path.join(folder, "placement.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def compose(base, pieces):
    out = base.copy()
    for p in sorted(pieces, key=lambda p: p["foot"]):
        out.alpha_composite(p["img"], (p["x"], p["y"]))
    return out


def main():
    base, pieces = build()
    if "--preview" in sys.argv:
        d = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(d, exist_ok=True)
        compose(base, pieces).save(os.path.join(d, "化妆间-1.25倍-一比一.png"))
    pkg = tempfile.mkdtemp(prefix="makeup_125_")
    write_package(pkg, base, pieces)
    subprocess.run([sys.executable, os.path.join(gpt.GODOT, "tools", "import_makeup_blocks.py"), pkg, "--canvas=%dx%d" % (W, H),
                    "--name=makeup_room", "--view_h=960"], check=True)
    subprocess.run(["rm", "-rf", pkg])


if __name__ == "__main__":
    main()
