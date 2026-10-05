#!/usr/bin/env python3
"""化妆间 · 家具 1.25 倍（庄Z1 10/5 晚派，派活单 godot/回执/派活-化妆间1点25倍-Z2-1006.md 3f803b4；庄Z2 写）。
阿鱼：「1.25 倍蛮合适的」「我感觉尺寸已经很合适了」。底线：人不动（84 高）；家具从 GPT 4 倍原图直接缩，别拿 1 倍图放大。

缩法照庄Z4 godot/回执/化妆间-大小几档示意/画1.25倍效果.py（e0c68d9）：
  - 底图 + 60 件都从共用文件夹 化妆间-精修-v1/ 的 4 倍原图直接 ×0.3125 最近邻（= 1 倍 ×1.25）
  - 整间一套 64 色：这次全部图拼一张现取（八叉树、不抖动），全部重压；透明 ≥128 算不透明，压成二值
  - 位置照零件表 ×0.3125：左上角、着地线；占地、座位照代码零件那格（1 倍）×1.25，占地下沿对齐新着地线
  - 门洞、换装点 ×1.25；墙、能走的范围由导入器按画布宽换算（效果图坐标 × 675/941）
整间 675×1200（比手机一屏宽 135、高 240），镜头左右上下跟人走。不写 view_h（第二轮退掉：铺了像素画的屋子镜头本来就取整到 1，庄Z3 实测）。
出拆景包交 tools/import_makeup_blocks.py（--canvas=675x1200）。

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
        seats = [(round(sx * K1), round(sy * K1)) for (sx, sy) in p["seats"]]
        if p["id"] == "sofa_cream" and len(seats) == 3:
            seats = [seats[0], seats[2]]   # 第二轮：奶油沙发中间那座正对着大抱枕，坐上去只露半个脑袋（庄Z3 体验复看第 2 条）——拿掉，只留两头
        pieces.append({"id": p["id"], "img": q(p["id"]), "x": round(t["x"] * K4), "y": round(t["y"] * K4), "foot": foot,
                       "footprint": [x0, y0, x1 - x0, foot - y0], "seats": seats})
    cols = set()
    for im in [base] + [p["img"] for p in pieces]:
        cols.update(c[:3] for c in im.getdata() if c[3])
    print("1.25 倍：%d×%d，底图 + %d 件，整间 %d 色（≤ %d）" % (W, H, len(pieces), len(cols), COLORS))
    return base, pieces


GRID = 12                 # 游戏里能走的格子（entrance.GRID_CELL）
HEAD = (12, 81, 47)       # 人站着：头肩那块，脚往上 81～47、左右各 12（人 84 高，图里不透明 81 行）
HIDE_OVER = 0.5           # 头肩被前面的家具盖住一半以上，就算「人不见了」


SUB = (-6, -3, 0, 3, 5)   # 一格里取的点（格子 12 宽：中心往两边各 6）


def _covered(alphas, x, y):
    """人脚在 (x, y)：头肩那块被画在人前面的家具盖住几成"""
    hw, top, bot = HEAD
    hb = (x - hw, y - top, x + hw, y - bot)
    mask = Image.new("L", (hb[2] - hb[0], hb[3] - hb[1]), 0)
    for p, a in alphas:
        if p["foot"] <= y:
            continue   # 人站在它南边：人画在它前面，不挡
        ox0, oy0 = max(hb[0], p["x"]), max(hb[1], p["y"])
        ox1, oy1 = min(hb[2], p["x"] + a.width), min(hb[3], p["y"] + a.height)
        if ox0 >= ox1 or oy0 >= oy1:
            continue
        mask.paste(255, (ox0 - hb[0], oy0 - hb[1]), a.crop((ox0 - p["x"], oy0 - p["y"], ox1 - p["x"], oy1 - p["y"])))
    return mask.histogram()[255] / float(mask.width * mask.height)


def no_stand(pieces):
    """第二轮（庄Z3 体验复看第 1 条：人走到首饰柜、衣架后面整个不见）：每个能走的格子假设人站在那，量头肩那块被画在人前面
    （着地线比人脚靠南）的家具盖了多少，盖过一半的格子划成站不了。回 [x0, y0, x1, y1] 一溜一溜（只包住格子中心，clear 0）"""
    k = W / 941.0
    fx0, fx1, fy0, fy1 = round(36 * k), round(905 * k), round(210 * k), round(1492 * k)   # 能走范围（导入器照效果图换算的那块）
    alphas = [(p, p["img"].getchannel("A")) for p in pieces]
    out, n = [], 0
    for j in range(H // GRID):
        cy = j * GRID + GRID // 2
        if not (fy0 <= cy <= fy1):
            continue
        run = None
        for i in range(W // GRID + 1):
            cx = i * GRID + GRID // 2
            hid = False
            if fx0 <= cx <= fx1:
                # 人不一定站在格子正中：格子里取 5×5 个点，哪一点头肩被盖过一半，整格都划掉
                hid = any(_covered(alphas, cx + dx, cy + dy) > HIDE_OVER for dy in SUB for dx in SUB)
            if hid:
                n += 1
                run = [cx, cx] if run is None else [run[0], cx]
            elif run is not None:
                out.append([run[0] - 5, cy - 5, run[1] + 5, cy + 5])
                run = None
        if run is not None:
            out.append([run[0] - 5, cy - 5, run[1] + 5, cy + 5])
    print("站进去头肩会被盖住一半以上的格子：%d 个（%d 溜）" % (n, len(out)))
    return out


def write_package(folder, base, pieces, empty_seat=None):
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
         "spots": {"dress": [R(240), R(1238)]}, "blocked": [], "items": items, "no_stand": no_stand(pieces), "empty_seat": empty_seat}
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
    cream = next(p for p in pieces if p["id"] == "sofa_cream")
    write_package(pkg, base, pieces, empty_seat=list(cream["seats"][-1]))   # 奶油沙发东头那座空着，给玩家坐（原来坐满了，坐不下）
    subprocess.run([sys.executable, os.path.join(gpt.GODOT, "tools", "import_makeup_blocks.py"), pkg, "--canvas=%dx%d" % (W, H),
                    "--name=makeup_room"], check=True)
    subprocess.run(["rm", "-rf", pkg])


if __name__ == "__main__":
    main()
