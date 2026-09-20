#!/usr/bin/env python3
"""六块画布的俯视对照图（01 9/20 派）：整张俯视截图上标出画布尺寸、交互点和不能走的地方。

图从哪儿来：
  - 底图：游戏自己截的整张俯视（capture.sh 的 *_overview，1:1 像素）
  - 数据：tools/dump_canvas.gd 导的 json（游戏真在用的走路格子和交互点，不是照布局重算）

用法：python3 tools/make_ref_map.py 截图目录 json目录 输出目录
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter, ImageOps

FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
HEAD = 132          # 顶上的说明条多高
BLOCK = (232, 62, 48)          # 不能走：斜线网格和描边的红（v2，01 9/20：v1 那层淡红盖在湖面、草莓垄上分不出来）
HATCH_GAP = 16                 # 斜线隔多远
DIM = 0.72                     # 不能走的地方压到多暗
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
VER = "v2"                     # 改版加版本号（目录说明的规矩），v1 的画法太淡已作废
# 宴会厅底图已经是 A04 试点的正式图，别的五块还是代码画的灰盒占位
REAL_ART = {"banquet"}


def font(sz):
    return ImageFont.truetype(FONT, sz)


def blocked_mask(img, d):
    """不能走的地方涂白的一张遮罩。用游戏自己算好的那份格子，图和游戏不会对不上。"""
    cell = float(d["cell"])
    m = Image.new("L", img.size, 0)
    dr = ImageDraw.Draw(m)
    for j, line in enumerate(d["rows"]):
        i = 0
        while i < len(line):
            if line[i] == "1":
                i += 1
                continue
            k = i
            while k < len(line) and line[k] == "0":   # 连成一条画，省得几万个小方块
                k += 1
            dr.rectangle([i * cell, j * cell, k * cell - 1, (j + 1) * cell - 1], fill=255)
            i = k
    return m


def draw_blocked(img, d):
    """不能走的地方：去色压暗 + 红斜线 + 红描边；能走的地方原样不动。
    v1 是盖一层淡红，底色是湖面（蓝紫）或草莓垄（棕红）时分不出来（01 9/20 看图提的）。
    去色压暗跟底色什么颜色都不打架，斜线和描边再给一层「这里过不去」的读法。"""
    m = blocked_mask(img, d)
    grey = ImageOps.grayscale(img).convert("RGBA")
    dim = ImageEnhance.Brightness(grey).enhance(DIM)
    out = Image.composite(dim, img, m)
    # 斜线网格（只落在不能走的地方）
    hatch = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(hatch)
    W, H = img.size
    for x in range(-H, W, HATCH_GAP):
        hd.line([(x, 0), (x + H, H)], fill=BLOCK + (96,), width=2)
    out = Image.composite(Image.alpha_composite(out, hatch), out, m)
    # 描边：能走和不能走的交界画一圈红
    edge = m.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(5))
    out.paste(Image.new("RGBA", img.size, BLOCK + (255,)), (0, 0), edge)
    return out


def _hits(box, placed):
    for b in placed:
        if not (box[2] < b[0] or box[0] > b[2] or box[3] < b[1] or box[1] > b[3]):
            return True
    return False


def _place(dr, txt, f, ax, ay, keep_out, W, H, colour):
    """把一块字放在 (ax, ay) 旁边：先试上下左右，撞了就往外挪；
    挨着画布边的时候往里翻，绝不让字被边切掉（01 9/20 看图提的）。放好了画一条细线连回那个点。"""
    tw = dr.textlength(txt, font=f)
    th = 30
    tries = [(ax - tw / 2, ay + 8), (ax - tw / 2, ay - 8 - th), (ax + 12, ay - th / 2), (ax - tw - 12, ay - th / 2)]
    tries += [(ax - tw / 2, ay + 8 + 34 * k) for k in range(1, 7)]
    tries += [(ax - tw / 2, ay - 8 - th - 34 * k) for k in range(1, 7)]
    tries += [(ax + 12 + 40 * k, ay - th / 2) for k in range(1, 5)]
    tries += [(ax - tw - 12 - 40 * k, ay - th / 2) for k in range(1, 5)]
    best = None
    for cx, cy in tries:
        cx = min(max(cx, 8), W - tw - 8)       # 往里翻，别顶出画布
        cy = min(max(cy, 6), H - th - 2)
        box = (cx - 6, cy - 3, cx + tw + 6, cy + th - 3)
        if not _hits(box, keep_out):
            best = (cx, cy, box)
            break
    if best is None:
        cx = min(max(ax - tw / 2, 8), W - tw - 8)
        cy = min(max(ay + 8, 6), H - th - 2)
        best = (cx, cy, (cx - 6, cy - 3, cx + tw + 6, cy + th - 3))
    cx, cy, box = best
    # 字离点远了就牵一条线回去，省得认不出这块字说的是哪个点
    cxm, cym = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    if abs(cxm - ax) > tw / 2 + 30 or abs(cym - ay) > 60:
        dr.line([ax, ay, cxm, cym], fill=colour[:3] + (150,), width=2)
    dr.rectangle(box, fill=(24, 22, 20, 214))
    dr.text((cx, cy), txt, font=f, fill=colour)
    keep_out.append(box)


def draw_points(img, d, name):
    dr = ImageDraw.Draw(img, "RGBA")
    f = font(22)
    W, H = img.size
    # 先把圈本身占的地方记下来：标签不许盖住任何一个交互圈
    keep_out = []
    for p in d["points"]:
        x, y, r = float(p["x"]), float(p["y"]), float(p["r"])
        keep_out.append((x - r - 4, y - r - 4, x + r + 4, y + r + 4))
    circles = list(keep_out)
    for p in d["points"]:
        x, y, r = float(p["x"]), float(p["y"]), float(p["r"])
        dr.ellipse([x - r, y - r, x + r, y + r], outline=POINT, width=4)
        dr.ellipse([x - 5, y - 5, x + 5, y + 5], fill=POINT)
    if "spawn" in d:
        sx, sy = float(d["spawn"][0]), float(d["spawn"][1])
        dr.regular_polygon((sx, sy, 15), 3, rotation=180, fill=SPAWN)
        _place(dr, "进场／到了站这儿", f, sx, sy + 16, keep_out, W, H, SPAWN)
    for p in sorted(d["points"], key=lambda q: (float(q["y"]), float(q["x"]))):
        x, y, r = float(p["x"]), float(p["y"]), float(p["r"])
        _place(dr, f'{p["id"]} ({int(x)},{int(y)}) r{int(r)}', f, x, y + r, keep_out, W, H, POINT)
    b = BAND_H.get(name)
    if b:
        dr.line([0, b, img.size[0], b], fill=BAND, width=4)
        dr.rectangle([12, b - 40, 470, b - 6], fill=(24, 22, 20, 214))
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
    # 图例第一格就是图上「不能走」的画法本身：压暗 + 斜线 + 描边（01 9/20：v2 多了描边，图例要说到）
    sw = Image.new("RGBA", (26, 20), (92, 88, 84, 255))
    sd = ImageDraw.Draw(sw)
    for k in range(-20, 26, 8):
        sd.line([(k, 0), (k + 20, 20)], fill=BLOCK + (140,), width=2)
    sd.rectangle([0, 0, 25, 19], outline=BLOCK + (255,), width=2)
    out.paste(sw, (x, y), sw)
    dr.text((x + 34, y - 2), "不能走（压暗＋斜线，红边是交界）", font=font(22), fill=(226, 214, 196, 255))
    x += 400
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
        path = os.path.join(dst, f"对照图-{cn}-俯视-{VER}.png" if name in REAL_ART else f"对照图-{cn}-灰盒俯视-{VER}.png")
        img.convert("RGB").save(path)
        print(f"好了 {path}  {img.size[0]}×{img.size[1]}")


if __name__ == "__main__":
    main()
