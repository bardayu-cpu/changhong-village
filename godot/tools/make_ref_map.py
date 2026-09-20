#!/usr/bin/env python3
"""六块画布的俯视对照图（01 9/20 派）：整张俯视截图上标出画布尺寸、交互点和不能走的地方。

图从哪儿来：
  - 底图：游戏自己截的整张俯视（capture.sh 的 *_overview，1:1 像素）
  - 数据：tools/dump_canvas.gd 导的 json（游戏真在用的走路格子和交互点，不是照布局重算）

用法：python3 tools/make_ref_map.py 截图目录 json目录 输出目录
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
HEAD = 132          # 顶上的说明条多高
BLOCK = (214, 69, 58, 74)      # 不能走：半透明红
POINT = (255, 208, 74, 255)    # 交互点：黄圈
SPAWN = (108, 214, 126, 255)   # 到了站的点：绿
BAND = (94, 168, 255, 255)     # 风景带的分界线：蓝

# 画布 -> (中文名, 交接目录, 底图文件名)
CANVAS = {
    "banquet": ("宴会厅", "001-宴会厅", "overview.png"),
    "court": ("迎宾院", "002-迎宾院", "court_overview.png"),
    "backhall": ("后厅", "003-后厅", "backhall_overview.png"),
    "lawn": ("草坪", "004-草坪", "lawn_overview.png"),
    "lake": ("湖边", "005-湖边", "lake_overview.png"),
    "orchard": ("果园", "006-果园", "orchard_overview.png"),
}
SCENE = {"banquet": "scene_luoman_hall", "court": "scene_luoman_entrance", "backhall": "scene_luoman_backhall",
         "lawn": "scene_luoman_lawn", "lake": "scene_luoman_lake", "orchard": "scene_luoman_orchard"}
BAND_H = {"lake": 256, "orchard": 256}   # 顶上的纯风景带（人走不到）
# 宴会厅底图已经是 A04 试点的正式图，别的五块还是代码画的灰盒占位
REAL_ART = {"banquet"}


def font(sz):
    return ImageFont.truetype(FONT, sz)


def draw_blocked(img, d):
    """不能走的格子铺一层半透明红。用游戏自己算好的那份格子，图和游戏不会对不上。"""
    cell = float(d["cell"])
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    for j, line in enumerate(d["rows"]):
        i = 0
        while i < len(line):
            if line[i] == "1":
                i += 1
                continue
            k = i
            while k < len(line) and line[k] == "0":   # 连成一条画，省得几万个小方块
                k += 1
            dr.rectangle([i * cell, j * cell, k * cell, (j + 1) * cell], fill=BLOCK)
            i = k
    return Image.alpha_composite(img, layer)


def _hits(box, placed):
    for b in placed:
        if not (box[2] < b[0] or box[0] > b[2] or box[3] < b[1] or box[1] > b[3]):
            return True
    return False


def draw_points(img, d, name):
    dr = ImageDraw.Draw(img, "RGBA")
    f = font(22)
    placed = []
    W, H = img.size
    if "spawn" in d:
        sx, sy = float(d["spawn"][0]), float(d["spawn"][1])
        dr.regular_polygon((sx, sy, 15), 3, rotation=180, fill=SPAWN)
        txt = "进场／到了站这儿"
        sw = dr.textlength(txt, font=f)
        lx = min(max(sx + 22, 8), W - sw - 8)
        ly = min(max(sy - 13, 6), H - 30)
        placed.append((lx - 6, ly - 3, lx + sw + 6, ly + 27))
        dr.rectangle([lx - 6, ly - 3, lx + sw + 6, ly + 27], fill=(24, 22, 20, 205))
        dr.text((lx, ly), txt, font=f, fill=SPAWN)
    for p in sorted(d["points"], key=lambda q: (float(q["y"]), float(q["x"]))):
        x, y, r = float(p["x"]), float(p["y"]), float(p["r"])
        dr.ellipse([x - r, y - r, x + r, y + r], outline=POINT, width=4)
        dr.ellipse([x - 5, y - 5, x + 5, y + 5], fill=POINT)
        label = f'{p["id"]} ({int(x)},{int(y)}) r{int(r)}'
        tw = dr.textlength(label, font=f)
        # 先试点下面，再试上面、右边、左边，都撞就往下错开：标签互相盖住就看不清了
        tries = [(x - tw / 2, y + r + 6), (x - tw / 2, y - r - 34), (x + r + 10, y - 13), (x - r - tw - 10, y - 13)]
        tries += [(x - tw / 2, y + r + 6 + 34 * k) for k in range(1, 6)]
        tx, ty = tries[0]
        for cx, cy in tries:
            box = (cx - 6, cy - 3, cx + tw + 6, cy + 27)
            if box[0] < 2 or box[2] > W - 2 or box[1] < 2 or box[3] > H - 2:
                continue
            if not _hits(box, placed):
                tx, ty = cx, cy
                break
        tx = min(max(tx, 8), W - tw - 8)
        ty = min(max(ty, 6), H - 30)
        placed.append((tx - 6, ty - 3, tx + tw + 6, ty + 27))
        dr.rectangle([tx - 6, ty - 3, tx + tw + 6, ty + 27], fill=(24, 22, 20, 205))
        dr.text((tx, ty), label, font=f, fill=POINT)
    b = BAND_H.get(name)
    if b:
        dr.line([0, b, img.size[0], b], fill=BAND, width=4)
        dr.rectangle([12, b - 40, 470, b - 6], fill=(24, 22, 20, 205))
        dr.text((20, b - 37), f"↑ 上面 {b} 像素是纯风景带（人走不到）", font=font(24), fill=BAND)
    return img


def header(img, name, cn, d):
    out = Image.new("RGBA", (img.size[0], img.size[1] + HEAD), (26, 24, 22, 255))
    out.paste(img, (0, HEAD))
    dr = ImageDraw.Draw(out, "RGBA")
    real = name in REAL_ART
    dr.text((24, 16), f"{cn} · 俯视对照图" + ("" if real else " · 灰盒"), font=font(38), fill=(255, 236, 200, 255))
    pts_txt = "桌椅制，没有交互点这套" if not d["points"] else f'交互点 {len(d["points"])} 个'
    line2 = f'{SCENE[name]}　画布 {d["size"][0]} × {d["size"][1]} 像素　走路格子 {int(float(d["cell"]))} 像素　{pts_txt}'
    dr.text((26, 64), line2, font=font(24), fill=(226, 214, 196, 255))
    # 图例
    x = 26
    y = 98
    dr.rectangle([x, y, x + 26, y + 20], fill=(214, 69, 58, 190))
    dr.text((x + 34, y - 2), "不能走", font=font(22), fill=(226, 214, 196, 255))
    x += 130
    dr.ellipse([x, y - 2, x + 24, y + 22], outline=POINT, width=3)
    dr.text((x + 32, y - 2), "交互点（圈是半径）", font=font(22), fill=(226, 214, 196, 255))
    x += 250
    dr.regular_polygon((x + 12, y + 10, 12), 3, rotation=180, fill=SPAWN)
    dr.text((x + 30, y - 2), "进场／到了站的点", font=font(22), fill=(226, 214, 196, 255))
    x += 240
    tail = "底图是 A04 试点的正式图，红色是挡住走不过去的地方" if real else "底图是代码画的灰盒占位，正式图按这张的尺寸和位置来"
    dr.text((x, y - 2), tail, font=font(22), fill=(168, 158, 146, 255))
    return out


def main():
    shots, dumps, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    for name, (cn, folder, shot) in CANVAS.items():
        d = json.load(open(os.path.join(dumps, name + ".json")))
        img = Image.open(os.path.join(shots, shot)).convert("RGBA")
        if img.size != tuple(d["size"]):
            img = img.resize(tuple(d["size"]), Image.NEAREST)
            print(f"  {name} 截图缩到画布尺寸 {d['size']}")
        img = draw_blocked(img, d)
        img = draw_points(img, d, name)
        img = header(img, name, cn, d)
        dst = os.path.join(out_dir, folder, "交接")
        os.makedirs(dst, exist_ok=True)
        path = os.path.join(dst, f"对照图-{cn}-俯视-v1.png" if name in REAL_ART else f"对照图-{cn}-灰盒俯视-v1.png")
        img.convert("RGB").save(path)
        print(f"好了 {path}  {img.size[0]}×{img.size[1]}")


if __name__ == "__main__":
    main()
