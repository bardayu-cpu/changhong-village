#!/usr/bin/env python3
"""沙盒截图标注版（01 G 10/4 派；工作规范第三节：新地图先出沙盒截图给阿鱼，过了再让 GPT 画效果图、代码还原）。
拿一比一干净版（tools/shot_court.gd --labels=0 截的），照这块的 layout.json 标三样：块名、每个口去哪、主要东西叫什么。
同一种东西（同一个零件编号 part）只标一次、带件数；墙、绿篱不标（太乱）。只读布局、只写出图。
用法：python3 godot/tools/layout_court/sandbox_annot.py <画布名，比如 plaza> <干净版.png> <标注版.png>
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
CN = {"plaza": "喷泉广场", "court": "迎宾院", "lawn": "草坪", "backhall": "后厅", "kids": "儿童乐园", "shop": "小卖部",
      "rest2": "休息厅 2", "wkitchen": "西餐厨房", "garden": "后花园", "frontgate": "前门", "parking": "停车场",
      "banquet": "宴会厅", "lake": "湖边", "orchard": "果园", "backgate": "后门", "entrance": "迎宾院"}
# 布局里没写名字的，照 id 开头补个叫法
FALLBACK = {"tree": "大树", "bench": "长椅", "tea": "茶几", "plant": "盆栽", "fridge": "冰箱", "bed": "花坛",
            "gazebo": "白色凉亭柱", "fountain_ring": "喷泉一圈浅色石板", "fountain_tier": "喷泉小水盘", "lamp": "路灯",
            "flowerbed": "花坛", "shelf": "货架"}
SKIP = ("wall_", "hedge", "gatewall", "围墙", "绿篱", "院墙")
SAY = {"frontgate_out": "门外：走不出去，走到这说一句", "backgate_out": "门外是小山：走不出去，走到这说一句"}


def center(it):
    t = it.get("type")
    if "rect" in it:
        x0, y0, x1, y1 = it["rect"]
        return ((x0 + x1) / 2, y0 - it.get("h", 0) / 2)
    if t == "beam":
        return ((it["x0"] + it["x1"]) / 2, it["top"])
    if t in ("cyl", "tree"):
        return (it["x"], it["y"] - it.get("h", 0) / 2)
    if t == "poly":
        pts = it["pts"]
        return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    return None


def item_name(it):
    n = (it.get("scale") or {}).get("name")
    if n:
        return n
    iid = it["id"]
    for k in sorted(FALLBACK, key=len, reverse=True):
        if iid.startswith(k):
            return FALLBACK[k]
    return None


def main():
    key, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    lay = json.load(open(os.path.join(GODOT, "assets", "layered", "scene_luoman_" + key, "layout.json"), encoding="utf-8"))
    W, H = lay["size"]
    base = Image.open(src).convert("RGB")
    BAND = 64
    img = Image.new("RGB", (W, H + BAND), (34, 26, 22))
    img.paste(base, (0, BAND))
    d = ImageDraw.Draw(img)
    f_title = ImageFont.truetype(FONT, 30)
    f = ImageFont.truetype(FONT, 22)
    f_s = ImageFont.truetype(FONT, 18)
    d.text((16, 14), "%s · 第 65 版沙盒（灰盒，全是色块占位） · 画布 %d × %d" % (CN.get(key, key), W, H), font=f_title, fill=(244, 217, 122))
    legend = "橙圈 = 口　白牌 = 东西叫什么"
    if W >= 1400:
        d.text((W - 16, 22), legend, font=f_s, fill=(230, 220, 200), anchor="ra")
    else:   # 窄的画布（停车场）标题占满了，图例放到底下
        d.text((W - 16, H + BAND - 30), legend, font=f_s, fill=(255, 255, 255), anchor="ra", stroke_width=3, stroke_fill=(30, 24, 20))
    placed = []

    def tag(x, y, text, fg=(30, 24, 20), bg=(255, 255, 255), font=f):
        bb = d.textbbox((0, 0), text, font=font)
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        x = max(4, min(W - w - 12, x - w / 2))
        y = max(BAND + 4, min(H + BAND - h - 12, y + BAND - h / 2))
        for _ in range(12):   # 跟已经标过的牌子叠了就往下挪一格
            box = (x - 6, y - 4, x + w + 6, y + h + 8)
            if not any(box[0] < q[2] and q[0] < box[2] and box[1] < q[3] and q[1] < box[3] for q in placed):
                break
            y += h + 14
        placed.append((x - 6, y - 4, x + w + 6, y + h + 8))
        d.rounded_rectangle([x - 6, y - 4, x + w + 6, y + h + 8], radius=6, fill=bg, outline=(60, 50, 40))
        d.text((x, y - bb[1]), text, font=font, fill=fg)

    # 主要东西：同一个零件编号只标一次，带件数
    groups = {}
    order = []
    for it in lay["items"]:
        nm = item_name(it)
        iid = str(it["id"])
        if nm is None or any(s in iid or s in nm for s in SKIP):
            continue
        part = it.get("part") or iid.rstrip("0123456789_")
        if part == "PK-P07":
            nm = "别的客人的车"
        sn = (it.get("scale") or {}).get("name")
        if part != "PK-P07" and sn and part in groups and groups[part]["named"] and groups[part]["named"] != sn:
            part = part + ":" + sn    # 同一个零件编号、名字不一样（洗手间、杂物处两间小屋）：分开标
        if part not in groups:
            groups[part] = {"name": nm, "items": [], "named": sn}
            order.append(part)
        elif sn and not groups[part]["named"]:
            groups[part]["name"] = sn if part != "PK-P07" else nm   # 布局里写了名字的优先（喷泉水池那组）
            groups[part]["named"] = sn
        groups[part]["items"].append(it)
    for part in order:
        g = groups[part]
        c = center(g["items"][0])
        if c is None:
            continue
        n = len(g["items"])
        tag(c[0], c[1], g["name"] + (" ×%d" % n if n > 1 else ""))
    # 口
    for p in lay["points"]:
        x, y = p["x"], p["y"]
        if p.get("to"):
            r = p.get("r", 40)
            d.ellipse([x - r, y - r + BAND, x + r, y + r + BAND], outline=(240, 130, 30), width=5)
            dx, dy = W / 2 - x, H / 2 - y
            ln = max(1.0, (dx * dx + dy * dy) ** 0.5)
            tx, ty = x + dx / ln * (r + 70), y + dy / ln * (r + 50)
            tag(tx, ty, "去" + CN.get(p["to"], p["to"]), fg=(255, 255, 255), bg=(214, 110, 20))
        elif p.get("say") in SAY:
            tag(x, y - 50, SAY[p["say"]], fg=(255, 255, 255), bg=(120, 90, 60), font=f_s)
        elif p["id"] == "my_car":
            tag(x, y + 50, "下车站这（自己的车旁）", fg=(255, 255, 255), bg=(120, 90, 60), font=f_s)
    if any(p.get("say", "").endswith("_wip") and p["id"] == "wip" for p in lay["points"]):
        d.text((16, H + BAND - 30), "走进块中间会说一句「还在布置」（话待校对）", font=f_s, fill=(255, 255, 255), stroke_width=3, stroke_fill=(30, 24, 20))
    img.save(dst)
    print("写了 %s：标了 %d 种东西、%d 个口" % (dst, len(order), sum(1 for p in lay["points"] if p.get("to"))))


if __name__ == "__main__":
    main()
