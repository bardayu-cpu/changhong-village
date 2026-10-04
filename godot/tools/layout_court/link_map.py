#!/usr/bin/env python3
"""连法总图（10/4 方案 C，02 E）：游戏里的连法 + 方案 C 图并排，给 01 看方向对不对。
左边：每块画布一个框，摆在方案 C 图里那块的位置；框里的小圆点是布局里写了 to 的口（照口在画布里的相对位置画，口在框的哪条边就是在画布的哪条边），
     线连着两头的口（从这边口出去、从对面那个口进来）。宴会厅三道门（南门、西侧门、东侧门）、迎宾院大门另读。
右边：godot/回执/方向方案C-上下翻-1004.png（阿鱼图只上下翻）。
用法：python3 godot/tools/layout_court/link_map.py <出图.png>
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
PLAN_C = os.path.join(GODOT, "回执", "方向方案C-上下翻-1004.png")
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"

# 每块画布摆在方案 C 图里的哪（方案 C 图的像素坐标 x0, y0, x1, y1；湖是一整条长画布，放在湖那块的南沿）
BOXES = {
    "backgate": ("后门", (229, 372, 317, 412)),
    "orchard": ("果园（西 B 枇杷 / 东 A 草莓）", (120, 440, 517, 558)),
    "lake": ("湖边（长湖岸）", (540, 395, 1000, 505)),
    "lawn": ("草坪", (136, 596, 252, 815)),
    "backhall": ("后厅（西→东 后厨 麻将 休息 化妆）", (262, 596, 584, 666)),
    "banquet": ("宴会厅", (600, 521, 738, 693)),
    "garden": ("后花园", (753, 580, 905, 690)),
    "wkitchen": ("西餐厨房", (262, 694, 348, 746)),
    "plaza": ("喷泉广场", (390, 691, 551, 815)),
    "court": ("迎宾院", (600, 715, 737, 800)),
    "parking": ("停车场", (753, 720, 918, 880)),
    "kids": ("儿童乐园", (136, 841, 261, 893)),
    "shop": ("小卖部", (291, 841, 377, 893)),
    "rest2": ("休息厅 2", (396, 842, 483, 894)),
    "frontgate": ("前门", (590, 860, 720, 930)),
}
LAYOUT = {
    "court": "scene_luoman_entrance", "backhall": "scene_luoman_backhall", "lawn": "scene_luoman_lawn",
    "lake": "scene_luoman_lake", "orchard": "scene_luoman_orchard", "parking": "scene_luoman_parking",
    "plaza": "scene_luoman_plaza",
}
for k in ("kids", "shop", "rest2", "wkitchen", "garden", "frontgate", "backgate"):
    LAYOUT[k] = "scene_luoman_" + k
Z = 2   # 左边整体放大


def load(k):
    if k == "banquet":
        d = json.load(open(os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55", "scene.json"), encoding="utf-8"))
        pts = []
        for p in d["points"]:
            if p["id"] == "door":
                pts.append({"id": "door", "x": p["x"], "y": p["y"], "to": "court"})
            elif p["id"] == "side_door":
                pts.append({"id": "side_door", "x": p["x"], "y": p["y"], "to": "backhall"})
            elif p.get("to"):
                pts.append(p)
        return d["size"], pts
    d = json.load(open(os.path.join(GODOT, "assets", "layered", LAYOUT[k], "layout.json"), encoding="utf-8"))
    pts = [p for p in d["points"] if p.get("to")]
    if k == "court":
        for p in d["points"]:
            if p["id"] == "gate":
                pts.append({"id": "gate", "x": p["x"], "y": p["y"], "to": "frontgate"})
    return d["size"], pts


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "连法总图.png"
    data = {k: load(k) for k in BOXES}

    def at(k, p):
        (W, H) = data[k][0]
        x0, y0, x1, y1 = BOXES[k][1]
        return ((x0 + (x1 - x0) * p["x"] / W) * Z, (y0 + (y1 - y0) * p["y"] / H) * Z)

    links, lone = [], []
    seen = set()
    for a in BOXES:
        for p in data[a][1]:
            b = p["to"]
            if b not in data:
                lone.append((a, p))
                continue
            back = [q for q in data[b][1] if q["to"] == a]
            if p.get("via"):
                back = [q for q in back if q["id"] == p["via"]]
            elif len(back) > 1:
                back = [q for q in back if q.get("via") == p["id"]] or back
            if not back:
                lone.append((a, p))
                continue
            q = back[0]
            key = tuple(sorted([(a, p["id"]), (b, q["id"])]))
            if key in seen:
                continue
            seen.add(key)
            links.append((a, p, b, q))

    plan = Image.open(PLAN_C).convert("RGB")
    LW = 1080 * Z
    img = Image.new("RGB", (LW + plan.width * Z // 1 + 40, max(1080 * Z, plan.height * Z)), (246, 244, 240))
    dr = ImageDraw.Draw(img)
    f_big = ImageFont.truetype(FONT, 22 * Z // 2 + 8)
    f = ImageFont.truetype(FONT, 11 * Z)
    dr.text((20, 16), "游戏里的连法（第 65 版，方案 C）：每块一个框，摆在方案 C 图那块的位置；圆点 = 布局里的口；线 = 能直接走过去（%d 条）" % len(links),
            font=f_big, fill=(30, 30, 30))
    for k, (name, (x0, y0, x1, y1)) in BOXES.items():
        col = (210, 70, 60) if k in ("court", "backhall", "lawn", "lake", "orchard", "parking", "banquet") else (90, 140, 200)
        dr.rectangle([x0 * Z, y0 * Z, x1 * Z, y1 * Z], fill=col, outline=(60, 40, 30), width=2)
        dr.text((x0 * Z + 6, y0 * Z + 4), name, font=f, fill=(255, 255, 255))
    for (a, p, b, q) in links:
        pa, pb = at(a, p), at(b, q)
        dr.line([pa, pb], fill=(230, 130, 30), width=3)
    for (a, p, b, q) in links:
        for (k, pt) in ((a, p), (b, q)):
            x, y = at(k, pt)
            dr.ellipse([x - 6, y - 6, x + 6, y + 6], fill=(255, 220, 80), outline=(80, 50, 20), width=2)
    for (a, p) in lone:
        x, y = at(a, p)
        dr.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(0, 0, 0))
    dr.text((20, 1040 * Z - 40), "红框：原来就有的块；蓝框：连图新加的灰盒。黄点是口，橙线两头的口互通。黑点 = 对面没有通回来的口（应为 0 个：%d）" % len(lone),
            font=f, fill=(60, 60, 60))
    img.paste(plan.resize((plan.width * Z, plan.height * Z)), (LW + 40, 0))
    img.save(out)
    print("写了 %s：%d 条连线，对面没通回来的口 %d 个" % (out, len(links), len(lone)))
    for (a, p, b, q) in links:
        print("  %s.%s ↔ %s.%s" % (a, p["id"], b, q["id"]))


if __name__ == "__main__":
    main()
