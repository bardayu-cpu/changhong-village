# assemble.py：按场景配置把积木贴到底图上，出三张图给阿鱼审，顺便检查能不能走
# 用法：python3 assemble.py <场景文件夹> <配置文件名> <输出前缀>
# 例：python3 assemble.py 素材交付/layered/scene_roman_banquet_v7 scene_pilot.json 素材交付/reference/banquet_pilot_v7
# 出：<前缀>_assembled.png 拼装预览（带灰色参照小人）、<前缀>_walk.png 能走的范围、<前缀>_exploded.png 积木平铺
# 只贴图，不改图。游戏里用同样的规则摆，所以拼装预览就是游戏画面
import json, os, sys
from collections import deque
from PIL import Image, ImageDraw, ImageOps

folder, cfg_name, prefix = sys.argv[1:4]
cfg = json.load(open(os.path.join(folder, cfg_name), encoding="utf-8"))
W, H = cfg["canvas"]
PH = cfg["person_h"]
bad = []
base = Image.open(os.path.join(folder, cfg["base"])).convert("RGBA")
if base.size != (W, H):
    bad.append("底图应是 %d×%d，现在是 %d×%d" % (W, H, base.size[0], base.size[1]))
    base = base.resize((W, H))
sprites = {}
for name, b in cfg["blocks"].items():
    im = Image.open(os.path.join(folder, name + ".png")).convert("RGBA")
    ax, ay = b["anchor"]
    if not (0 <= ax <= im.width and 0 <= ay <= im.height):
        bad.append(name + " 的脚点不在图里")
    sprites[name] = im

def figure(w, h, color):
    # 灰色参照小人、新人占位：只用来看比例，不是素材
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, w - 1, w - 1), fill=color, outline=(30, 30, 30, 255))
    d.rectangle((w // 8, w - 2, w - 1 - w // 8, h - 1), fill=color, outline=(30, 30, 30, 255))
    return im

items = []   # (前景?, 脚点 y, 顺序, 图, 左上角, 是不是参照)
for i, p in enumerate(cfg["place"]):
    if p["block"] not in sprites:
        bad.append("place 第 %d 条的积木 %s 没在 blocks 里" % (i + 1, p["block"]))
        continue
    im = sprites[p["block"]]
    ax, ay = cfg["blocks"][p["block"]]["anchor"]
    if p.get("flip"):
        im = ImageOps.mirror(im)
        ax = im.width - ax
    items.append((bool(p.get("front")), p["y"], i, im, (p["x"] - ax, p["y"] - ay), False))
guest = figure(max(8, PH * 2 // 5), PH, (160, 160, 160, 255))
for j, (x, y) in enumerate(cfg.get("preview_people", [])):
    items.append((False, y, 100000 + j, guest, (x - guest.width // 2, y - PH), True))
ch = PH * 11 // 10
couple = figure(ch * 7 // 10, ch, (120, 120, 200, 255))   # 新人占位：游戏里换成合照
cx, cy = cfg["couple"]
items.append((False, cy, 200000, couple, (cx - couple.width // 2, cy - ch), True))

def compose(with_people):
    out = base.copy()
    for front, y, i, im, xy, ref in sorted(items, key=lambda t: (t[0], t[1], t[2])):
        if ref and not with_people:
            continue
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        layer.paste(im, xy)
        out = Image.alpha_composite(out, layer)
    return out

compose(True).convert("RGB").save(prefix + "_assembled.png")

# 能走的地方：在 walk 多边形里、离每块积木的占地 12 像素以外；从进场点出发，看交互点走不走得到
C, CL = 8, 12
def inside(x, y, poly):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
        j = i
    return c
feet = [(p["x"], p["y"], cfg["blocks"][p["block"]]["footprint"]) for p in cfg["place"]
        if p["block"] in sprites and "footprint" in cfg["blocks"][p["block"]]]
def blocked(x, y):
    for fx, fy, fp in feet:
        if "ellipse" in fp:
            rx, ry = fp["ellipse"]
            if ((x - fx) / (rx + CL)) ** 2 + ((y - fy) / (ry + CL)) ** 2 < 1.0:
                return True
        elif abs(x - fx) < fp["rect"][0] / 2 + CL and abs(y - fy) < fp["rect"][1] / 2 + CL:
            return True
    return False
cols, rows = W // C, H // C
ok = [[any(inside((i + .5) * C, (j + .5) * C, poly) for poly in cfg["walk"]) and not blocked((i + .5) * C, (j + .5) * C)
       for i in range(cols)] for j in range(rows)]
sx, sy = cfg["spawn"]
seen = set()
if ok[int(sy // C)][int(sx // C)]:
    seen.add((int(sx // C), int(sy // C)))
    q = deque(seen)
    while q:
        i, j = q.popleft()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (i + di, j + dj)
            if 0 <= n[0] < cols and 0 <= n[1] < rows and ok[n[1]][n[0]] and n not in seen:
                seen.add(n)
                q.append(n)
else:
    bad.append("进场点 spawn 不在能走的地方")
for p in cfg["points"]:
    if not any(((i + .5) * C - p["x"]) ** 2 + ((j + .5) * C - p["y"]) ** 2 < p["r"] ** 2 for i, j in seen):
        bad.append("交互点 %s 从进场点走不到" % p["id"])
for name, (x, y) in [("spawn", cfg["spawn"]), ("couple", cfg["couple"])] + [(p["id"], (p["x"], p["y"])) for p in cfg["points"]]:
    if not (150 <= y <= H - 164):
        bad.append("%s 的 y=%d 不在 150～%d 之间（上面有标题，下面有对话框）" % (name, y, H - 164))

wim = compose(False)
ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(ov)
for i, j in seen:
    d.rectangle((i * C, j * C, i * C + C - 1, j * C + C - 1), fill=(0, 255, 90, 80))
for fx, fy, fp in feet:
    if "ellipse" in fp:
        rx, ry = fp["ellipse"]
    else:
        rx, ry = fp["rect"][0] / 2, fp["rect"][1] / 2
    box = (fx - rx, fy - ry, fx + rx, fy + ry)
    (d.ellipse if "ellipse" in fp else d.rectangle)(box, outline=(255, 40, 40, 255), width=2)
    d.ellipse((fx - 3, fy - 3, fx + 3, fy + 3), fill=(255, 40, 40, 255))
for p in cfg["points"]:
    d.ellipse((p["x"] - p["r"], p["y"] - p["r"], p["x"] + p["r"], p["y"] + p["r"]), outline=(60, 150, 255, 255), width=3)
d.ellipse((sx - 6, sy - 6, sx + 6, sy + 6), fill=(60, 150, 255, 255))
Image.alpha_composite(wim, ov).convert("RGB").save(prefix + "_walk.png")

# 积木平铺：每块积木一张，红点是脚点，红框是占地
pad = 24
sheet_w = max(640, sum(im.width + pad for im in sprites.values()) + pad)
sheet_h = max(im.height for im in sprites.values()) + pad * 3
sheet = Image.new("RGBA", (sheet_w, sheet_h), (225, 225, 225, 255))
d = ImageDraw.Draw(sheet)
x = pad
for name, im in sprites.items():
    sheet.alpha_composite(im, (x, pad))
    ax, ay = cfg["blocks"][name]["anchor"]
    fp = cfg["blocks"][name].get("footprint", {})
    if "ellipse" in fp or "rect" in fp:
        rx, ry = fp["ellipse"] if "ellipse" in fp else (fp["rect"][0] / 2, fp["rect"][1] / 2)
        (d.ellipse if "ellipse" in fp else d.rectangle)((x + ax - rx, pad + ay - ry, x + ax + rx, pad + ay + ry), outline=(255, 40, 40, 255))
    d.ellipse((x + ax - 3, pad + ay - 3, x + ax + 3, pad + ay + 3), fill=(255, 40, 40, 255))
    d.text((x, sheet_h - pad * 2 + 4), name, fill=(0, 0, 0, 255))
    x += im.width + pad
sheet.convert("RGB").save(prefix + "_exploded.png")

print("画布 %d×%d，积木 %d 种，摆了 %d 次，能走 %d 格" % (W, H, len(sprites), len(cfg["place"]), len(seen)))
print("\n".join("不行：" + b for b in bad) if bad else "检查：全部好")
