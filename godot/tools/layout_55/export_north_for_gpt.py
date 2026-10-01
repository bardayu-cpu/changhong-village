#!/usr/bin/env python3
"""把宴会厅 55 桌厅北边那块（画布 y 0～1024，1536×1024，1:1）导成「给 GPT 照着画」的标准答案（01 E 10/2 派，03 做）。

新做法：灰盒（色块）位置大小定死 → GPT 照色块画成正式画面 → 阿鱼确认 → GPT 照零件单拆 → 02 按色块原位换上。
这里导出的就是那份「标准答案」。数全从游戏真在用的那两处拿，不另算：
  tools/layout_55/make_board55.py 的 build()          每件摆设画出来的框 box、占地 foot（摆位表）
  assets/layered/scene_roman_banquet_55/scene.json    游戏真摆的遮挡块（零件）x、y、排前后的线
  assets/layered/scene_roman_banquet_55/art_*.png     零件图实际大小

用法：python3 tools/layout_55/export_north_for_gpt.py 输出目录 [--real 游戏真图.png]
出：宴会厅北-色块.png、宴会厅北-色块-标注.png、宴会厅北-零件单.md、宴会厅北-零件单.json、验收数.json
    （宴会厅北-现状.png 是游戏真渲染，由 --real 传进来原样拷贝；怎么渲染见回执）
验收（自己查自己）：零件框对 scene.json 零件逐件 0 偏差；零件图尺寸 = 框；色块图上数得到的件数 = 零件单；
    --real 给了就拿真渲染图逐件模板对位（±3 像素找最贴的位置，必须是 0,0），再量背景大件的边
不改游戏代码、不改零件总表。
"""
import importlib.util
import json
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
SCENE_DIR = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
W, NORTH_H = 1536, 1024

argv = sys.argv[1:]
REAL = None
if "--real" in argv:
    k = argv.index("--real")
    REAL = argv[k + 1]
    del argv[k:k + 2]
OUT = argv[0] if argv else os.path.join(GODOT, "回执", "出图-宴会厅北")

sys.argv = [sys.argv[0]]   # make_board55 开头会读 sys.argv[1] 当输出目录，这里不给它
spec = importlib.util.spec_from_file_location("board", os.path.join(HERE, "make_board55.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)

# ---------- 零件（要拆）：编号照 docs/零件总表.md ----------
# 零件图文件（游戏里用的那份）、颜色（一种一个色，彼此分得开）
PARTS = {
    "B55-T01": {"name": "普通圆桌", "art": "art_table.png", "color": (220, 70, 60)},
    "B55-T02": {"name": "主桌", "art": "art_table_main.png", "color": (200, 40, 170)},
    "B55-P01": {"name": "落地宫灯", "art": "art_lantern.png", "color": (250, 230, 60)},
    "B55-P02": {"name": "落地花架", "art": "art_flowerstand.png", "color": (90, 190, 90)},
    "B55-P03": {"name": "小花盆", "art": "art_flowerpot.png", "color": (150, 225, 140)},
    "B55-P04": {"name": "长凳", "art": "art_bench.png", "color": (110, 190, 255)},
    # 重排（02 10/2，01 E）：舞台西边地上的礼物堆，GPT 多交一件 B55S-P05（约 96×80），真图没到游戏里先不画（scene.json 里没有）
    "B55S-P05": {"name": "礼物堆", "art": None, "color": (245, 150, 60)},
}
# ---------- 背景（不拆）：总表里只有 BG01（北边整张）、W01/W02（竖墙），其余是这次临时起的子编号，等 01 定要不要收进总表 ----------
BG_COLORS = {
    "地面": (239, 227, 207), "北墙": (92, 52, 36), "墙顶横梁": (55, 28, 20), "帐幔": (170, 40, 40), "挂灯": (255, 140, 0),
    "西墙": (135, 95, 65), "东墙": (135, 95, 65), "花拱": (30, 100, 95), "囍字圆牌": (215, 170, 60),
    "红毯": (179, 32, 42), "乐队地台": (110, 60, 140), "婚礼台（台面）": (150, 60, 90), "婚礼台（台口立面）": (95, 20, 45),
    "台阶": (190, 120, 96), "贺礼架": (240, 140, 160), "东侧门": (60, 140, 200),
}


def classify(it):
    """回 (编号前缀, 种类名, 分类, 顺序键)；分类 part=零件 bg=背景；None=不在这次范围"""
    n, k = it["name"], it["kind"]
    if k in ("mark", "ruler", "zone"):
        return None
    if k == "table":
        if n == "主桌":
            return "B55-T02", "主桌", "part", 0
        return "B55-T01", "普通圆桌", "part", int(n[1:])
    if "宫灯" in n:
        return "B55-P01", "落地宫灯", "part", (it["foot"][1], it["foot"][0])
    if "花架" in n:
        return "B55-P02", "落地花架", "part", it["box"][0]
    if "花盆" in n:
        return "B55-P03", "小花盆", "part", it["box"][0]
    if n == "长凳":
        return "B55-P04", "长凳", "part", 0
    if it["group"] == "gifts":
        return "B55S-P05", "礼物堆", "part", (it["foot"][1], it["box"][0])
    bg = {"北墙（立面）": ("B55-BG01-a", "北墙"), "墙顶横梁": ("B55-BG01-b", "墙顶横梁"), "花拱": ("B55-BG01-g", "花拱"),
          "囍字圆牌": ("B55-BG01-h", "囍字圆牌"), "婚礼台（台面）": ("B55-BG01-i", "婚礼台（台面）"),
          "婚礼台（台口立面）": ("B55-BG01-j", "婚礼台（台口立面）"), "台阶": ("B55-BG01-k", "台阶"), "红毯": ("B55-BG01-l", "红毯"),
          "乐队地台（背景里画好的）": ("B55-BG01-m", "乐队地台"), "贺礼堆（背景里画好的）": ("B55-BG01-n", "贺礼架"),
          "西墙": ("B55-W01", "西墙"), "东墙（北段）": ("B55-W02", "东墙"),
          # 重排以后厅变短，东侧门和东墙南段也落进北边这块了
          "东墙（南段）": ("B55-W02", "东墙"), "东侧门（门洞）": ("B55-BG01-o", "东侧门")}
    if n in bg:
        return bg[n][0], bg[n][1], "bg", it["box"][1]
    if n.startswith("帐幔"):
        return "B55-BG01-c", "帐幔", "bg", int(n.split()[1])
    if n.startswith("挂灯"):
        return "B55-BG01-d", "挂灯", "bg", int(n.split()[1])
    raise SystemExit("没认出来的东西：%s（%s）" % (n, k))


def foot_point(it):
    """脚点 = 占地下沿的中点（照 make_board55 的 foot）。桌、长凳、花盆=图下沿正中；宫灯、花架占地偏一点，量出来是啥就是啥"""
    fx, fy, fw, fh = it["foot"]
    return fx + fw // 2, fy + fh


def build_catalog():
    items, tid, door, stand_top, rail_foot = B.build()
    scene = json.load(open(os.path.join(SCENE_DIR, "scene.json"), encoding="utf-8"))
    occ = {(o["x"], o["y"]): o for o in scene["occluders"]}
    parts, bgs = [], []
    for it in items:
        x, y, w, h = it["box"]
        if y >= NORTH_H:
            continue
        c = classify(it)
        if c is None:
            continue
        prefix, kind, cat, key = c
        rec = {"item": it, "prefix": prefix, "kind": kind, "cat": cat, "key": key, "name": it["name"], "box": it["box"]}
        if cat == "part" and prefix == "B55S-P05":
            rec["occ"] = {"x": x, "y": y, "foot": it["foot"][1] + it["foot"][3], "no_scene": True}   # 不在游戏里，按占地下沿排前后
            rec["cut"] = y + h > NORTH_H
            parts.append(rec)
            continue
        if cat == "part":
            o = occ.get((x, y))
            rec["occ"] = o
            rec["cut"] = y + h > NORTH_H
        (parts if cat == "part" else bgs).append(rec)
    # 同种多件加序号：桌按桌号（T3 → -03），别的按位置顺序
    byp = {}
    for r in parts:
        byp.setdefault(r["prefix"], []).append(r)
    for p, lst in byp.items():
        lst.sort(key=lambda r: r["key"])
        for i, r in enumerate(lst):
            if p == "B55-T01":
                r["seq"] = r["key"]
            else:
                r["seq"] = i + 1
            r["id"] = "%s-%02d" % (p, r["seq"]) if len(lst) > 1 or p == "B55-T01" else p
    bgp = {}
    for r in bgs:
        bgp.setdefault(r["prefix"], []).append(r)
    for p, lst in bgp.items():
        lst.sort(key=lambda r: r["key"])
        for i, r in enumerate(lst):
            r["seq"] = i + 1
            r["id"] = "%s-%d" % (p, i + 1) if len(lst) > 1 else p
    return parts, bgs, scene


def part_art(prefix):
    if PARTS[prefix]["art"] is None:   # 礼物堆：没有图，拿一块满的框顶上（只用来量大小、数块）
        return Image.new("RGBA", (96, 80), (255, 255, 255, 255))
    return Image.open(os.path.join(SCENE_DIR, PARTS[prefix]["art"])).convert("RGBA")


def draw_blocks(parts, bgs, scene, labels):
    """色块图：背景大件和零件都画成『画出来的框』（矩形），一种一色；零件按游戏里排前后的线从北往南画，压住后面的"""
    im = Image.new("RGB", (W, NORTH_H), BG_COLORS["地面"])
    g = ImageDraw.Draw(im)
    order = ["北墙", "墙顶横梁", "帐幔", "挂灯", "西墙", "东墙", "东侧门", "花拱", "囍字圆牌", "红毯", "乐队地台", "婚礼台（台面）", "婚礼台（台口立面）", "台阶", "贺礼架"]
    for kind in order:
        for r in bgs:
            if r["kind"] == kind:
                x, y, w, h = r["box"]
                g.rectangle([x, y, x + w - 1, min(y + h, NORTH_H) - 1], fill=BG_COLORS[kind])
    sorted_parts = sorted(parts, key=lambda r: (r["occ"]["foot"], r["box"][0]))
    for r in sorted_parts:
        x, y, w, h = r["box"]
        g.rectangle([x, y, x + w - 1, min(y + h, NORTH_H) - 1], fill=PARTS[r["prefix"]]["color"])
    if not labels:
        return im
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    f11, f13, f16 = (ImageFont.truetype(FONT, s) for s in (11, 13, 16))

    def txt(xy, s, fnt, col=(255, 255, 255), anchor="mm"):
        d.text(xy, s, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=2, stroke_fill=(0, 0, 0, 255))

    for r in bgs + sorted_parts:   # 每件描一圈黑边，叠在一起的看得出谁是谁
        x, y, w, h = r["box"]
        d.rectangle([x, y, x + w - 1, min(y + h, NORTH_H) - 1], outline=(0, 0, 0, 255), width=1)
    for r in bgs:
        x, y, w, h = r["box"]
        k = r["kind"]
        short = r["id"].replace("B55-", "")
        if k in ("北墙",):
            txt((x + 150, 14), "%s 北墙（0,0,1536×236）" % short, f13)
        elif k == "墙顶横梁":
            continue
        elif k == "帐幔":
            txt((x + w / 2, y + 12), short, f11)
        elif k == "挂灯":
            txt((x + w / 2, y + h + 8), short, f11)
        elif k in ("西墙", "东墙"):
            txt((x + w / 2, 420 if k == "西墙" else 560), short.replace("B55-", ""), f11)
            txt((x + w / 2, 440 if k == "西墙" else 580), k, f11)
        elif k == "婚礼台（台口立面）":
            txt((x + w / 2, y + h / 2), "%s 台口立面" % short, f11)
        elif k == "婚礼台（台面）":
            txt((x + w / 2, y + h / 2 - 8), "%s 婚礼台（台面）" % short, f13)
        elif k == "台阶":
            txt((x + w / 2, y + h / 2 + 10), "%s 台阶" % short, f11)
        elif k == "红毯":
            txt((x + w / 2, 700), "%s 红毯" % short, f16)
        elif k == "乐队地台":
            txt((x + w / 2, y + h / 2), "%s 乐队地台" % short, f13)
        elif k == "贺礼架":
            txt((x + w / 2, y + h / 2), "%s" % short, f11)
            txt((x + w / 2, y + h / 2 + 14), "贺礼架", f11)
        elif k == "花拱":
            txt((x + 40, y + 30), "%s 花拱" % short, f11)
        elif k == "囍字圆牌":
            txt((x + w / 2, y + h / 2), "%s 囍" % short, f13)
    for r in sorted_parts:
        x, y, w, h = r["box"]
        short = r["id"].replace("B55-", "")
        if w < 60:
            # 窄的（宫灯、花架、花盆）：编号竖着挨着写在框里
            parts_txt = short.split("-")
            txt((x + w / 2, y + h / 2 - 6), parts_txt[0], f11)
            txt((x + w / 2, y + h / 2 + 8), "-".join(parts_txt[1:]), f11)
        else:
            txt((x + w / 2, y + h / 2), short, f16)
        if r["cut"]:
            txt((x + w / 2, NORTH_H - 10), "被切 整件高 %d" % h, f11, (255, 220, 120))
        fx, fy = foot_point(r["item"])
        if fy <= NORTH_H:
            d.line([(fx - 6, fy), (fx + 6, fy)], fill=(0, 255, 255, 255), width=2)
            d.line([(fx, fy - 6), (fx, fy + 6)], fill=(0, 255, 255, 255), width=2)
    for k, line in enumerate(["青色十字 = 脚点（占地下沿中点）", "黑框 = 画出来的框", "图上省略前缀 B55-", "北边 1536×1024，1:1", "左上角就是整厅 (0,0)"]):
        txt((1075, 352 + k * 20), line, f13, anchor="lm")
    return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")


def build_json(parts, bgs):
    sp = sorted(parts, key=lambda r: (r["prefix"], r["seq"]))
    out = {"canvas": [W, NORTH_H], "origin": "整厅 (0,0) 就是这块左上角", "note": "x、y 是画出来的框的左上角；脚点（foot）是占地下沿的中点，整厅坐标；图内脚点 = 脚点 − (x, y)",
           "parts": [], "background": []}
    for p in PARTS:
        lst = [r for r in sp if r["prefix"] == p]
        if not lst:
            continue
        im = part_art(p)
        out["parts"].append({
            "code": p, "name": PARTS[p]["name"], "size": [lst[0]["box"][2], lst[0]["box"][3]], "art_file": PARTS[p]["art"],
            "foot_in_image": [foot_point(lst[0]["item"])[0] - lst[0]["box"][0], foot_point(lst[0]["item"])[1] - lst[0]["box"][1]],
            "count": len(lst), "count_cut": sum(1 for r in lst if r["cut"]),
            "instances": [{
                "id": r["id"], "name": r["name"], "x": r["box"][0], "y": r["box"][1],
                "foot": list(foot_point(r["item"])), "sort_y": r["occ"]["foot"], "cut": r["cut"],
                "visible_h": min(r["box"][1] + r["box"][3], NORTH_H) - r["box"][1],
                "opaque_bbox_in_image": list(im.getchannel("A").point(lambda a: 255 if a else 0).getbbox())} for r in lst]})
    for r in sorted(bgs, key=lambda r: (r["prefix"], r["seq"])):
        x, y, w, h = r["box"]
        out["background"].append({"id": r["id"], "name": r["name"], "kind": r["kind"], "box": [x, y, w, h],
                                  "foot_box": r["item"]["foot"], "basis": r["item"]["basis"]})
    return out


def build_md(parts, bgs, data, extra):
    L = ["# 宴会厅 55 桌 · 北边那块 · 零件单（给 GPT 照着画、照着拆）", "",
         "> 03 数据测试，2026-10-02，01 E 派。**这是标准答案**：位置、大小和游戏里一模一样（画布 1536×1024，1:1，坐标原点是整厅左上角）。",
         "> 脚本 `godot/tools/layout_55/export_north_for_gpt.py`；数从游戏真在用的 `scene.json` 和摆位表来，不另算。图在同一个文件夹：",
         "> `宴会厅北-色块.png`（标准答案，不写字）、`宴会厅北-色块-标注.png`（写了编号、脚点）、`宴会厅北-现状.png`（游戏现在这块的样子，没人没界面）。", "",
         "**看这几条再动手**", "",
         "- 色块图上每件东西画成它**画出来的框**（矩形），不是地上的占地。零件图本身四周有透明边（桌子两边各约 16～19 像素、宫灯两边各 13），所以画出来看得见的东西比框窄一点。",
         "- **脚点** = 这件东西落在地上那条占地的下沿中点。桌、长凳、小花盆 = 图下沿正中；宫灯、花架的占地比图窄一截，脚点 x 不在图正中（表里写了图里的脚点）。",
         "- 一种东西一个颜色，同种多件长一个样（零件图只画一张，游戏里摆多份）。**零件的框之间会有重叠**（宫灯框和旁边桌子框的透明边搭了几个像素、花架框压在婚礼台框上），色块图按游戏里排前后的顺序画，后面的被前面的压住；标注版描了黑边，看得出谁是谁。",
         "- **人物不列**（人单独出）。图里不放人、不写字、没有界面。",
         "- 北边这块下沿（y 1024）切到 %d 张桌子（%s），它们整件在下一块里，这里只露上面一截（露出来的高度在表里）；GPT 拆件时要拿整件。" % (extra["cut_n"], "、".join(extra["cut_ids"])),
         "", "## 一、零件（要拆，一种一张图，游戏里按下面的坐标摆多份）", "",
         "| 编号 | 名字 | 画出来多大 w×h | 脚点在图里 (x, y) | 这块里几件 | 其中被切 | 现用文件 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"]:
        L.append("| %s | %s | %d×%d | (%d, %d) | %d | %d | `%s` |" % (p["code"], p["name"], p["size"][0], p["size"][1], p["foot_in_image"][0], p["foot_in_image"][1], p["count"], p["count_cut"], p["art_file"]))
    L += ["", "合计：**%d 件**零件摆在这块里（其中 %d 件被下沿切掉一截）。" % (sum(p["count"] for p in data["parts"]), extra["cut_n"]), "",
          "### 每件的位置（整厅坐标，x、y 是框的左上角，脚点是整厅里的脚点坐标）", "",
          "| 编号 | 名字 | x | y | 脚点 (x, y) | 游戏里排前后的线 | 被切 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"]:
        for i in p["instances"]:
            L.append("| %s | %s | %d | %d | (%d, %d) | %d | %s |" % (i["id"], i["name"], i["x"], i["y"], i["foot"][0], i["foot"][1], i["sort_y"], ("切，露出 %d" % i["visible_h"]) if i["cut"] else "—"))
    L += ["", "「游戏里排前后的线」：人和零件谁挡谁，按这条线的 y 比；给 02 摆回去用，GPT 不用管。", "",
          "## 二、背景（不拆，整张画）", "",
          "> 总表里只有 `B55-BG01`（北边整张）、`B55-W01`、`B55-W02`；下面 `-a`～`-n` 是这次临时起的子编号，只为了对照，要不要收进总表等 01 定。",
          "> 框的数是 02 9/30 照阿鱼给的北边 v2 背景量的（摆位表里写着依据），所以这几件是「背景画成这样，色块照着量」，不是反过来；和真图差几个像素见回执。", "",
          "| 编号 | 名字 | 框 x, y, w×h | 依据 |", "| --- | --- | --- | --- |"]
    for b in data["background"]:
        x, y, w, h = b["box"]
        vh = min(y + h, NORTH_H) - y
        size = "%d×%d" % (w, h) if vh == h else "%d×%d（整件高 %d，往南一直到别的块，这块只露到 y 1024）" % (w, vh, h)
        L.append("| %s | %s | %d, %d, %s | %s |" % (b["id"], b["name"], x, y, size, b["basis"]))
    L += ["", "地面：除了上面这些，整块是浅色地砖（色块图里的浅米色）。**西墙、东墙在色块里是 40 宽的平条**（`W01`/`W02`，游戏里 y 724 往下接的就是这套 40×240 竖墙瓦片）；"
          "北边 v2 背景里 y 724 以上的墙是透视的、比 40 宽，两张对不上，见回执。", ""]
    return "\n".join(L)


# ---------- 自查 ----------
def check_scene(parts, scene):
    """零件框对 scene.json：x、y、零件图大小逐件对；件数对；回 (偏差表, 问题)"""
    bad, rows = [], []
    occ_n = [o for o in scene["occluders"] if o["y"] < NORTH_H]
    parts = [r for r in parts if not (r["occ"] or {}).get("no_scene")]   # 礼物堆不在游戏里，不对 scene.json
    if len(occ_n) != len(parts):
        bad.append("scene.json 里 y<1024 的零件 %d 件，零件单 %d 件" % (len(occ_n), len(parts)))
    for r in parts:
        o = r["occ"]
        if o is None:
            bad.append("%s 在 scene.json 里找不到" % r["id"])
            continue
        iw, ih = part_art(r["prefix"]).size
        dx, dy = r["box"][0] - o["x"], r["box"][1] - o["y"]
        dw, dh = r["box"][2] - iw, r["box"][3] - ih
        rows.append((r["id"], dx, dy, dw, dh))
        if (dx, dy, dw, dh) != (0, 0, 0, 0):
            bad.append("%s：框对 scene.json 差 dx %d dy %d，对零件图差 w %d h %d" % (r["id"], dx, dy, dw, dh))
    return rows, bad


def count_on_picture(im, parts):
    """色块图上数件数：每种颜色数连通块（不同色互相压住的地方不算同一块）；和零件单对"""
    px = im.load()
    out = {}
    for prefix, cfg in PARTS.items():
        col = cfg["color"]
        seen = set()
        n = 0
        for y in range(NORTH_H):
            for x in range(W):
                if px[x, y] == col and (x, y) not in seen:
                    n += 1
                    stack = [(x, y)]
                    seen.add((x, y))
                    while stack:
                        cx, cy = stack.pop()
                        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                            if 0 <= nx < W and 0 <= ny < NORTH_H and (nx, ny) not in seen and px[nx, ny] == col:
                                seen.add((nx, ny))
                                stack.append((nx, ny))
        out[prefix] = n
    return out


def match_real(parts, real):
    """真渲染图逐件模板对位：零件图不透明点在 (x+dx, y+dy) 处和真图像素一模一样的比例，dx、dy 取 -3～3，最贴的必须是 0,0"""
    px = real.load()
    res = []
    for r in parts:
        im = part_art(r["prefix"])
        ap = im.load()
        x0, y0 = r["box"][0], r["box"][1]
        pts = [(i, j, ap[i, j][:3]) for j in range(0, im.height, 2) for i in range(0, im.width, 2) if ap[i, j][3] == 255]
        rates = {}
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                hit = tot = 0
                for i, j, c in pts:
                    X, Y = x0 + i + dx, y0 + j + dy
                    if 0 <= X < W and 0 <= Y < NORTH_H:
                        tot += 1
                        if px[X, Y][:3] == c:
                            hit += 1
                rates[(dx, dy)] = hit / tot if tot else 0.0
        best = max(rates, key=lambda k: rates[k])
        second = max(v for k, v in rates.items() if k != best)
        res.append({"id": r["id"], "best": best, "rate0": rates[(0, 0)], "rate_best": rates[best], "second": second})
    return res


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def edge_x(px, rows, x_exp, win=12):
    """竖边：框的边在 x_exp（边落在第 x_exp-1 列和第 x_exp 列之间）。在 ±win 里找一排行平均亮度差最大的那条缝，回 (找到的位置, 强度)"""
    best = None
    for x in range(x_exp - win, x_exp + win + 1):
        d = sum(abs(lum(px[x, y]) - lum(px[x - 1, y])) for y in rows) / len(rows)
        if best is None or d > best[1]:
            best = (x, d)
    return best


def edge_y(px, cols, y_exp, win=12):
    best = None
    for y in range(y_exp - win, y_exp + win + 1):
        d = sum(abs(lum(px[x, y]) - lum(px[x, y - 1])) for x in cols) / len(cols)
        if best is None or d > best[1]:
            best = (y, d)
    return best


def measure_bg(real, bgs):
    """背景大件的边，在游戏真渲染图里找最明显的那条缝，跟色块的框比。背景是 GPT 画的、框是 02 照它量的，所以这里量的是『量得准不准』：
    每条边回 (哪件、哪条边、色块的位置、真图里找到的位置、差)。强度太弱（<12）的边标『看不清』不下结论"""
    px = real.load()
    box = {r["id"]: r["box"] for r in bgs}
    kinds = {}
    for r in bgs:
        kinds.setdefault(r["kind"], []).append(r)
    out = []

    def add(name, edge, exp, got, strength):
        out.append({"item": name, "edge": edge, "expect": exp, "found": got, "diff": got - exp, "strength": round(strength, 1), "clear": strength >= 12})

    st = box["B55-BG01-i"]
    fc = box["B55-BG01-j"]
    g, s = edge_x(px, range(298, 320), st[0]); add("婚礼台", "左缘(台口立面)", st[0], g, s)
    g, s = edge_x(px, range(298, 320), st[0] + st[2]); add("婚礼台", "右缘(台口立面)", st[0] + st[2], g, s)
    g, s = edge_y(px, list(range(600, 660)) + list(range(880, 990)), fc[1] + fc[3], 8); add("婚礼台", "台口立面下沿 y", fc[1] + fc[3], g, s)
    k = box["B55-BG01-k"]
    g, s = edge_x(px, range(300, 320), k[0]); add("台阶", "左缘", k[0], g, s)
    g, s = edge_x(px, range(300, 320), k[0] + k[2]); add("台阶", "右缘", k[0] + k[2], g, s)
    c = box["B55-BG01-l"]
    g, s = edge_x(px, range(470, 700), c[0]); add("红毯", "左缘", c[0], g, s)
    g, s = edge_x(px, range(470, 700), c[0] + c[2]); add("红毯", "右缘", c[0] + c[2], g, s)
    m = box["B55-BG01-m"]
    g, s = edge_x(px, range(300, 320), m[0]); add("乐队地台", "左缘", m[0], g, s)
    g, s = edge_x(px, range(300, 320), m[0] + m[2]); add("乐队地台", "右缘", m[0] + m[2], g, s)
    g, s = edge_y(px, range(1030, 1100), m[1] + m[3]); add("乐队地台", "前沿 y", m[1] + m[3], g, s)
    n = box["B55-BG01-n"]
    g, s = edge_x(px, range(262, 286), n[0]); add("贺礼架", "左缘", n[0], g, s)
    g, s = edge_y(px, range(500, 545), n[1] + n[3]); add("贺礼架", "底 y", n[1] + n[3], g, s)
    xi = box["B55-BG01-h"]
    g, s = edge_x(px, range(165, 180), xi[0]); add("囍字圆牌", "左缘", xi[0], g, s)
    g, s = edge_x(px, range(165, 180), xi[0] + xi[2]); add("囍字圆牌", "右缘", xi[0] + xi[2], g, s)
    g, s = edge_y(px, range(755, 780), xi[1]); add("囍字圆牌", "上沿 y", xi[1], g, s)
    ar = box["B55-BG01-g"]
    g, s = edge_x(px, range(140, 160), ar[0]); add("花拱", "左缘", ar[0], g, s)
    g, s = edge_x(px, range(140, 160), ar[0] + ar[2]); add("花拱", "右缘", ar[0] + ar[2], g, s)
    g, s = edge_y(px, range(730, 800), 236, 10); add("北墙脚", "地砖起点 y（北墙下沿）", 236, g, s)
    for r in sorted(kinds["帐幔"], key=lambda r: r["seq"]):
        x, y, w, h = r["box"]
        g, s = edge_x(px, range(28, 34), x, 14); add(r["id"], "左缘", x, g, s)
        g, s = edge_x(px, range(28, 34), x + w, 14); add(r["id"], "右缘", x + w, g, s)
    for r in sorted(kinds["挂灯"], key=lambda r: r["seq"]):
        x, y, w, h = r["box"]
        g, s = edge_x(px, range(66, 80), x, 10); add(r["id"], "左缘", x, g, s)
        g, s = edge_x(px, range(66, 80), x + w, 10); add(r["id"], "右缘", x + w, g, s)
    return out


def wall_inner(real):
    """西墙、东墙里边那条缝在哪（色块里是 40 宽的平条，西墙里边是 x 40、东墙里边是 x 1496）。逐行找地砖从哪开始"""
    px = real.load()

    def floor_like(c):
        return c[0] > 175 and c[1] > 160 and c[2] > 120 and c[0] - c[2] < 90
    rows = []
    for y in (260, 300, 400, 500, 600, 700, 760, 800, 900, 1000):
        lx = next((x for x in range(0, 400) if all(floor_like(px[x + k, y]) for k in range(8))), None)
        rx = next((x for x in range(W - 1, W - 400, -1) if all(floor_like(px[x - k, y]) for k in range(8))), None)
        rows.append({"y": y, "west_floor_from": lx, "east_floor_to": rx + 1 if rx is not None else None})
    return rows


def render_extra(parts, real):
    """真渲染图 = 北边背景 + 零件，没有别的东西（没有藏着的人、牌子、字）：真图跟 base.png 北边一截逐像素比，
    扣掉零件不透明的地方，剩下不一样的像素数（应该是 0）"""
    from PIL import ImageChops
    base = Image.open(os.path.join(SCENE_DIR, "base.png")).convert("RGB").crop((0, 0, W, NORTH_H))
    mask = Image.new("L", (W, NORTH_H), 0)
    for r in parts:
        a = part_art(r["prefix"]).getchannel("A").point(lambda v: 255 if v else 0)
        mask.paste(255, (r["box"][0], r["box"][1]), a)
    # 游戏里底图是有损导入的（base.png.import compress/mode=1，质量 0.8），真渲染和 png 每个像素差一点点；差大于 64 才算「不一样」
    d = ImageChops.difference(real, base)
    diff = ImageChops.lighter(ImageChops.lighter(d.getchannel(0), d.getchannel(1)), d.getchannel(2)).point(lambda v: 255 if v > 64 else 0)
    left = ImageChops.subtract(diff, mask)
    n_left = left.histogram()[255]
    n_in = ImageChops.multiply(diff, mask).histogram()[255]
    return {"diff_outside_parts": n_left, "diff_inside_parts": n_in, "part_pixels": mask.histogram()[255], "bbox_outside": left.getbbox()}


def main():
    parts, bgs, scene = build_catalog()
    os.makedirs(OUT, exist_ok=True)
    clean = draw_blocks(parts, bgs, scene, False)
    ann = draw_blocks(parts, bgs, scene, True)
    clean.save(os.path.join(OUT, "宴会厅北-色块.png"))
    ann.save(os.path.join(OUT, "宴会厅北-色块-标注.png"))
    data = build_json(parts, bgs)
    cut = [r["id"] for r in parts if r["cut"]]
    extra = {"cut_n": len(cut), "cut_ids": cut}
    json.dump(data, open(os.path.join(OUT, "宴会厅北-零件单.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    open(os.path.join(OUT, "宴会厅北-零件单.md"), "w", encoding="utf-8").write(build_md(parts, bgs, data, extra))
    rows, bad = check_scene(parts, scene)
    counts = count_on_picture(clean, parts)
    listed = {p["code"]: p["count"] for p in data["parts"]}
    for p in PARTS:
        if counts.get(p, 0) != listed.get(p, 0):
            bad.append("色块图上数 %s 得 %d 块，零件单写 %d 件" % (p, counts.get(p, 0), listed.get(p, 0)))
    report = {"scene_dev": rows, "scene_problems": bad, "count_on_picture": counts, "count_listed": listed,
              "n_parts": len(parts), "n_bg": len(bgs), "cut": cut}
    if REAL:
        real = Image.open(REAL).convert("RGB")
        assert real.size == (W, NORTH_H), "真图不是 1536×1024：%s" % (real.size,)
        shutil.copyfile(REAL, os.path.join(OUT, "宴会厅北-现状.png"))
        report["real_match"] = match_real(parts, real)
        report["bg_probe"] = measure_bg(real, bgs)
        report["wall_inner"] = wall_inner(real)
        report["render_extra"] = render_extra(parts, real)
    json.dump(report, open(os.path.join(OUT, "验收数.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("零件 %d 件（被切 %d）、背景 %d 件" % (len(parts), len(cut), len(bgs)))
    print("框对 scene.json、零件图：%s" % ("全部 0 偏差" if not bad else bad))
    print("色块图上数：", counts, "零件单：", listed)
    if REAL:
        off = [m for m in report["real_match"] if m["best"] != (0, 0)]
        print("真图 vs 北边背景图：零件以外不一样的像素", report["render_extra"]["diff_outside_parts"], report["render_extra"])
        print("真图逐件对位：%d 件，最贴不在 0,0 的 %d 件；0,0 命中率最低 %.3f" % (len(report["real_match"]), len(off), min(m["rate0"] for m in report["real_match"])))
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
