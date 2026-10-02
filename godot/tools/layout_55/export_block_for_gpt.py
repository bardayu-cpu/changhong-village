#!/usr/bin/env python3
"""把宴会厅 55 桌厅的一块（北边 y 0～1024，或南边 y 1024～厅尾）导成「给 GPT 照着画」的标准答案（03 做，01 E 派）。

新做法（色块法，00 10/2 冻结）：我们摆色块 → 阿鱼点头 → GPT 照色块画 → GPT 照零件单拆 → 02 换回游戏。
这里导出的就是那份「标准答案」。数全从游戏真在用的几处拿，不另算：
  tools/layout_55/make_board55.py 的 build()          每件摆设画出来的框 box、占地 foot（摆位表，零件规格唯一源）
  assets/layered/scene_roman_banquet_55/scene.json    游戏真摆的遮挡块（零件）x、y、排前后的线
  assets/layered/scene_roman_banquet_55/art_*.png     零件图实际大小（现在游戏里用的 B55 那套；B55S 新图到了尺寸一样）

用法：python3 tools/layout_55/export_block_for_gpt.py north|south 输出目录 [--real 游戏真图.png]
  north = 整厅 y 0～1024；south = y 1024～厅尾。--real 是 shot.sh 出的这一块 1:1 真图（没人没界面）
出：宴会厅<北|南>-色块.png、-色块-标注.png、-零件单.md/.json、验收数.json，--real 给了再拷一份 -现状.png
验收（自己查自己）：零件框对 scene.json 逐件 0 偏差、零件图尺寸 = 框、零件尺寸 = 零件总表、色块图上数得到的件数 = 零件单；
    --real 给了就拿真图逐件模板对位（±3 像素找最贴的位置，必须是 0,0），真图 = 背景 + 零件、没有别的东西，再量背景大件的边
不改游戏代码、不改零件总表。
"""
import importlib.util
import json
import os
import re
import shutil
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
SCENE_DIR = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55")
TABLE_MD = os.path.join(os.path.dirname(GODOT), "docs", "零件总表.md")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
W = 1536

argv = sys.argv[1:]
REAL = None
if "--real" in argv:
    k = argv.index("--real")
    REAL = argv[k + 1]
    del argv[k:k + 2]
if not argv or argv[0] not in ("north", "south"):
    raise SystemExit("用法：export_block_for_gpt.py north|south 输出目录 [--real 真图.png]")
BLOCK = argv[0]
OUT = argv[1] if len(argv) > 1 else os.path.join(GODOT, "回执", "出图-宴会厅" + ("北" if BLOCK == "north" else "南"))
LABEL = "北" if BLOCK == "north" else "南"

sys.argv = [sys.argv[0]]   # make_board55 开头会读 sys.argv[1] 当输出目录，这里不给它
spec = importlib.util.spec_from_file_location("board", os.path.join(HERE, "make_board55.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)

# ---------- 零件（要拆）：编号照 docs/零件总表.md B55S ----------
PARTS = {
    "B55S-T01": {"name": "圆桌", "art": "art_table.png", "color": (220, 70, 60)},
    "B55S-T02": {"name": "主桌", "art": "art_table_main.png", "color": (200, 40, 170)},
    "B55S-P01": {"name": "落地灯（路引）", "art": "art_lantern.png", "color": (250, 230, 60)},
    "B55S-P02": {"name": "落地花架", "art": "art_flowerstand.png", "color": (90, 190, 90)},
    "B55S-P03": {"name": "小花盆", "art": "art_flowerpot.png", "color": (150, 225, 140)},
    "B55S-P04": {"name": "长凳", "art": "art_bench.png", "color": (110, 190, 255)},
    "B55S-P05": {"name": "礼物堆", "art": None, "color": (255, 120, 190)},   # 96×80，GPT 还没交图，游戏里没有，色块先摆着
}
# 背景（不拆）颜色：一种东西一个色，彼此和零件的色分得开
BG_COLORS = {
    "地面": (239, 227, 207), "北墙": (92, 52, 36), "墙顶横梁": (55, 28, 20), "帐幔": (170, 40, 40), "挂灯": (255, 140, 0),
    "西墙": (135, 95, 65), "东墙": (135, 95, 65), "花拱": (30, 100, 95), "囍字圆牌": (215, 170, 60),
    "红毯": (179, 32, 42), "乐队地台": (110, 60, 140), "婚礼台（台面）": (150, 60, 90), "婚礼台（台口立面）": (95, 20, 45),
    "台阶": (190, 120, 96), "贺礼架": (240, 140, 160),
    "东侧门": (0, 170, 190), "大门": (60, 120, 215), "门洞口": (70, 185, 125), "门槛": (205, 160, 0), "栏杆": (205, 140, 70),
}
# 背景件编号：总表里只有 B55S-BG01（北边背景）、B55S-W01（地砖）、B55S-W02/W03（竖墙）。其余临时起的子编号，等 01 定要不要进总表。
BG_CODES = {
    "北墙": "B55S-BG01-a", "墙顶横梁": "B55S-BG01-b", "帐幔": "B55S-BG01-c", "挂灯": "B55S-BG01-d", "花拱": "B55S-BG01-g",
    "囍字圆牌": "B55S-BG01-h", "婚礼台（台面）": "B55S-BG01-i", "婚礼台（台口立面）": "B55S-BG01-j", "台阶": "B55S-BG01-k",
    "乐队地台": "B55S-BG01-m", "贺礼架": "B55S-BG01-n",
    "西墙": "B55S-W02", "东墙": "B55S-W03",
    "红毯": "B55S-BG02-a", "东侧门": "B55S-BG02-b", "大门": "B55S-BG02-c", "门洞口": "B55S-BG02-d", "门槛": "B55S-BG02-e", "栏杆": "B55S-BG02-f",
}

ITEMS, TID, DOOR, STAND_TOP, RAIL_FOOT = B.build()
H = B.H
Y0, Y1 = (0, 1024) if BLOCK == "north" else (1024, H)
BH = Y1 - Y0
SOUTH_TOP = H - B.SOUTH_BG_H   # 南边背景从哪起（排法 C 里 1067），大门、栏杆、门槛的数以它为准


def south_items():
    """排法 C 的 build() 在摆桌那步提前 return，没把南边背景里画好的大门、栏杆、门槛放进 items；这几件从 make_board55 的 SOUTH_* 常量按同样的算法补出来
    （同一份常量，之前 v9 的 build() 就是这么加的）。跟 02 对一下要不要补进摆位表。"""
    px0, py0, pw, ph = B.SOUTH_DOOR_POSTS
    st = SOUTH_TOP
    out = []

    def add(name, box, basis, foot=None):
        out.append({"name": name, "kind": "bgx", "box": list(box), "foot": list(foot or box), "color": None, "basis": basis, "group": "", "flat": False})

    dl, dr = B.SOUTH_DOORWAY
    add("大门（西门柱和门扇）", (px0, st + py0, dl - px0, ph), "照南边背景量（make_board55 SOUTH_DOOR_POSTS）：门柱 640～706、y 830～1000（南边图里），落地线 %d；中间 706～826 是门洞，不属于它" % RAIL_FOOT)
    add("大门（东门柱和门扇）", (dr, st + py0, px0 + pw - dr, ph), "同西边：826～900；两边门扇开着、占着门洞两侧")
    add("门槛", (B.SOUTH_DOORWAY[0], st + B.SOUTH_THRESHOLD, B.SOUTH_DOORWAY[1] - B.SOUTH_DOORWAY[0], 15), "金门槛 890～905（SOUTH_THRESHOLD 注释），宽 = 门洞 120")
    add("门洞口", (B.SOUTH_DOORWAY[0], st + B.SOUTH_THRESHOLD + 15, B.SOUTH_DOORWAY[1] - B.SOUTH_DOORWAY[0], RAIL_FOOT - (st + B.SOUTH_THRESHOLD + 15)),
        "门槛以南、人能走出去的那截：宽 120（SOUTH_DOORWAY 706～826），下到栏杆脚 %d" % RAIL_FOOT)
    add("栏杆（西段）", (40, st + B.SOUTH_RAIL[0], px0 - 40, B.SOUTH_RAIL[1] - B.SOUTH_RAIL[0]), "照南边背景量：顶 958、脚 1000（南边图里，SOUTH_RAIL）")
    add("栏杆（东段）", (px0 + pw, st + B.SOUTH_RAIL[0], W - 40 - (px0 + pw), B.SOUTH_RAIL[1] - B.SOUTH_RAIL[0]), "同西段")
    return out


def classify(it):
    """回 (编号前缀, 种类名, 分类, 顺序键)；分类 part=零件 bg=背景；None=不在这次范围"""
    n, k = it["name"], it["kind"]
    if k in ("mark", "ruler", "zone"):
        return None
    if k == "table":
        if n == "主桌":
            return "B55S-T02", "主桌", "part", 0
        return "B55S-T01", "圆桌", "part", int(n[1:])
    if "宫灯" in n or "落地灯" in n:
        return "B55S-P01", "落地灯（路引）", "part", (it["foot"][1], it["foot"][0])
    if "花架" in n:
        return "B55S-P02", "落地花架", "part", it["box"][0]
    if "花盆" in n:
        return "B55S-P03", "小花盆", "part", it["box"][0]
    if n == "长凳":
        return "B55S-P04", "长凳", "part", 0
    if n.startswith("礼物堆"):
        return "B55S-P05", "礼物堆", "part", int(n.split()[1])
    simple = {"北墙（立面）": "北墙", "墙顶横梁": "墙顶横梁", "花拱": "花拱", "囍字圆牌": "囍字圆牌", "婚礼台（台面）": "婚礼台（台面）",
              "婚礼台（台口立面）": "婚礼台（台口立面）", "台阶": "台阶", "红毯": "红毯", "乐队地台（背景里画好的）": "乐队地台",
              "贺礼堆（背景里画好的）": "贺礼架", "西墙": "西墙", "东墙（北段）": "东墙", "东墙（南段）": "东墙", "东侧门（门洞）": "东侧门",
              "大门（西门柱和门扇）": "大门", "大门（东门柱和门扇）": "大门", "门槛": "门槛", "门洞口": "门洞口", "栏杆（西段）": "栏杆", "栏杆（东段）": "栏杆"}
    if n in simple:
        return BG_CODES[simple[n]], simple[n], "bg", (it["box"][1], it["box"][0])
    if n.startswith("帐幔"):
        return BG_CODES["帐幔"], "帐幔", "bg", int(n.split()[1])
    if n.startswith("挂灯"):
        return BG_CODES["挂灯"], "挂灯", "bg", int(n.split()[1])
    raise SystemExit("没认出来的东西：%s（%s）" % (n, k))


def foot_point(it):
    """脚点 = 占地下沿的中点（make_board55 的 foot）。桌、长凳、花盆 = 图下沿正中；宫灯、花架、礼物堆占地比图窄，脚点 x 不在图正中就是不在"""
    fx, fy, fw, fh = it["foot"]
    return fx + fw // 2, fy + fh


def in_block(it):
    x, y, w, h = it["box"]
    return y < Y1 and y + h > Y0


def build_catalog():
    scene = json.load(open(os.path.join(SCENE_DIR, "scene.json"), encoding="utf-8"))
    occ = {(o["x"], o["y"]): o for o in scene["occluders"]}
    parts, bgs = [], []
    items = ITEMS + (south_items() if BLOCK == "south" else [])
    for it in items:
        if not in_block(it):
            continue
        c = classify(it)
        if c is None:
            continue
        x, y, w, h = it["box"]
        prefix, kind, cat, key = c
        if kind == "东侧门":
            it = dict(it, basis="东墙上 y %d～%d（南边背景里画的那个门，make_board55 SOUTH_SIDE_DOOR）；门洞看得见外面；宽沿地面前后 1.8×32≈58" % (it["box"][1], it["box"][1] + it["box"][3]))
        rec = {"item": it, "prefix": prefix, "kind": kind, "cat": cat, "key": key, "name": it["name"], "box": it["box"]}
        if cat == "part":
            rec["occ"] = occ.get((x, y))
            rec["cut_top"] = y < Y0
            rec["cut_bottom"] = y + h > Y1
            rec["cut"] = rec["cut_top"] or rec["cut_bottom"]
        (parts if cat == "part" else bgs).append(rec)
    byp = {}
    for r in parts:
        byp.setdefault(r["prefix"], []).append(r)
    for p, lst in byp.items():
        lst.sort(key=lambda r: r["key"])
        for i, r in enumerate(lst):
            r["seq"] = r["key"] if p == "B55S-T01" else i + 1
            r["id"] = "%s-%02d" % (p, r["seq"]) if len(lst) > 1 or p == "B55S-T01" else p
    bgp = {}
    for r in bgs:
        bgp.setdefault(r["prefix"], []).append(r)
    for p, lst in bgp.items():
        lst.sort(key=lambda r: r["key"])
        for i, r in enumerate(lst):
            r["seq"] = i + 1
            r["id"] = "%s-%d" % (p, i + 1) if len(lst) > 1 else p
    return parts, bgs, scene


def part_art(prefix, box=None):
    f = PARTS[prefix]["art"]
    if f is None:
        return Image.new("RGBA", (box[2], box[3]), (255, 255, 255, 255))   # 没有图的：整框不透明
    return Image.open(os.path.join(SCENE_DIR, f)).convert("RGBA")


def clip_box(x, y, w, h):
    """整厅的框 → 这块里的矩形（块内坐标，含端点），整个在外面回 None"""
    ya, yb = max(y, Y0), min(y + h, Y1)
    if yb <= ya:
        return None
    return [x, ya - Y0, x + w - 1, yb - Y0 - 1]


def draw_blocks(parts, bgs, labels):
    """色块图：背景大件和零件都画成『画出来的框』（矩形），一种一色；零件按游戏里排前后的线从北往南画，压住后面的"""
    im = Image.new("RGB", (W, BH), BG_COLORS["地面"])
    g = ImageDraw.Draw(im)
    order = ["北墙", "墙顶横梁", "帐幔", "挂灯", "西墙", "东墙", "东侧门", "花拱", "囍字圆牌", "红毯", "乐队地台", "婚礼台（台面）", "婚礼台（台口立面）",
             "台阶", "贺礼架", "栏杆", "大门", "门槛", "门洞口"]
    for kind in order:
        for r in bgs:
            if r["kind"] == kind:
                c = clip_box(*r["box"])
                if c:
                    g.rectangle(c, fill=BG_COLORS[kind])
    sorted_parts = sorted(parts, key=lambda r: ((r["occ"]["foot"] if r["occ"] else r["item"]["foot"][1] + r["item"]["foot"][3]), r["box"][0]))
    for r in sorted_parts:
        c = clip_box(*r["box"])
        g.rectangle(c, fill=PARTS[r["prefix"]]["color"])
    if not labels:
        return im
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    f11, f13, f16 = (ImageFont.truetype(FONT, s) for s in (11, 13, 16))

    def txt(xy, s, fnt, col=(255, 255, 255), anchor="mm"):
        d.text(xy, s, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=2, stroke_fill=(0, 0, 0, 255))

    for r in bgs + sorted_parts:
        c = clip_box(*r["box"])
        if c:
            d.rectangle(c, outline=(0, 0, 0, 255), width=1)
    for r in bgs:
        c = clip_box(*r["box"])
        if not c:
            continue
        x, y, w, h = r["box"]
        cx, cy = (c[0] + c[2]) / 2.0, (c[1] + c[3]) / 2.0
        k = r["kind"]
        short = r["id"].replace("B55S-", "")
        if k == "北墙":
            txt((x + 150, 14 - Y0), "%s 北墙" % short, f13)
        elif k in ("墙顶横梁",):
            continue
        elif k == "帐幔":
            txt((cx, y + 12 - Y0), short, f11)
        elif k == "挂灯":
            txt((cx, y + h + 8 - Y0), short, f11)
        elif k in ("西墙", "东墙"):
            for ty in range(200, BH - 60, 360):
                txt((cx, ty), short, f11)
                txt((cx, ty + 15), k, f11)
        elif k == "东侧门":
            txt((cx - 70, cy), "%s 东侧门" % short, f13, anchor="mm")
        elif k == "红毯":
            for ty in range(120, BH - 200, 520):
                txt((cx, ty + 330 if BLOCK == "north" else ty), "%s 红毯" % short, f13)
        elif k == "大门":
            txt((cx, c[1] + 40), short.replace("BG02-", ""), f11)
            txt((cx, c[1] + 54), "大门", f11)
        elif k == "门槛":
            txt((x + w + 70, c[1] + 6), "%s 门槛" % short, f11)
        elif k == "门洞口":
            txt((cx, cy + 4), "%s 门洞口" % short, f11)
        elif k == "栏杆":
            txt((cx, cy), "%s 栏杆" % short, f13)
        elif k in ("婚礼台（台面）", "乐队地台", "花拱", "囍字圆牌", "贺礼架", "台阶", "婚礼台（台口立面）"):
            txt((cx, cy), "%s %s" % (short, k.replace("婚礼台（", "台").replace("）", "")), f11)
    for r in sorted_parts:
        c = clip_box(*r["box"])
        x, y, w, h = r["box"]
        short = r["id"].replace("B55S-", "")
        cx, cy = (c[0] + c[2]) / 2.0, (c[1] + c[3]) / 2.0
        if w < 60:
            pt = short.split("-")
            txt((cx, cy - 6), pt[0], f11)
            txt((cx, cy + 8), "-".join(pt[1:]), f11)
        else:
            txt((cx, cy), short, f16)
        if r["cut_bottom"]:
            txt((cx, BH - 10), "被切 整件高 %d" % h, f11, (255, 220, 120))
        if r["cut_top"]:
            txt((cx, 10), "被切 上面少 %d" % (Y0 - y), f11, (255, 220, 120))
        fx, fy = foot_point(r["item"])
        if Y0 <= fy < Y1:
            fy -= Y0
            d.line([(fx - 6, fy), (fx + 6, fy)], fill=(0, 255, 255, 255), width=2)
            d.line([(fx, fy - 6), (fx, fy + 6)], fill=(0, 255, 255, 255), width=2)
    # 图例放在红毯东边第一格能看清的地方：南边放在第一排之间的空地较少，放进西北角地砖里
    leg = ["青色十字 = 脚点（占地下沿中点）", "黑框 = 画出来的框", "图上省略前缀 B55S-", "%s边 1536×%d，1:1" % (LABEL, BH), "块内 y = 整厅 y − %d" % Y0]
    for k, line in enumerate(leg):
        txt((1075 if BLOCK == "north" else 60, (352 if BLOCK == "north" else 870) + k * 20), line, f13, anchor="lm")
    return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")


def build_json(parts, bgs):
    sp = sorted(parts, key=lambda r: (r["prefix"], r["seq"]))
    out = {"block": BLOCK, "canvas": [W, BH], "y_offset": Y0,
           "origin": "x 照整厅；整厅 y = 块内 y + %d。下面所有 x、y 都是整厅坐标" % Y0,
           "note": "x、y 是画出来的框的左上角；脚点（foot）是占地下沿的中点；图内脚点 = 脚点 − (x, y)", "parts": [], "background": []}
    for p in PARTS:
        lst = [r for r in sp if r["prefix"] == p]
        if not lst:
            continue
        b0 = lst[0]["box"]
        out["parts"].append({
            "code": p, "name": PARTS[p]["name"], "size": [b0[2], b0[3]], "art_file": PARTS[p]["art"],
            "foot_in_image": [foot_point(lst[0]["item"])[0] - b0[0], foot_point(lst[0]["item"])[1] - b0[1]],
            "count": len(lst), "count_cut": sum(1 for r in lst if r["cut"]),
            "instances": [{
                "id": r["id"], "name": r["name"], "x": r["box"][0], "y": r["box"][1], "y_in_block": r["box"][1] - Y0,
                "foot": list(foot_point(r["item"])), "sort_y": r["occ"]["foot"] if r["occ"] else None,
                "cut": "上" if r["cut_top"] else ("下" if r["cut_bottom"] else ""),
                "visible_h": min(r["box"][1] + r["box"][3], Y1) - max(r["box"][1], Y0)} for r in lst]})
    for r in sorted(bgs, key=lambda r: (r["prefix"], r["seq"])):
        x, y, w, h = r["box"]
        out["background"].append({"id": r["id"], "name": r["name"], "kind": r["kind"], "box": [x, y, w, h], "y_in_block": y - Y0,
                                  "foot_box": r["item"]["foot"], "basis": r["item"]["basis"]})
    return out


def build_md(parts, bgs, data, extra):
    own = "整厅 y 0～1024" if BLOCK == "north" else "整厅 y 1024～%d" % Y1
    L = ["# 宴会厅 55 桌（排法 C）· %s边那块 · 零件单（给 GPT 照着画、照着拆）" % LABEL, "",
         "> 03 数据测试，2026-10-02，01 E 派。**这是标准答案**：位置、大小和游戏里一模一样。这块是%s，一张 **1536×%d**，1:1。" % (own, BH),
         "> 坐标：x 就是整厅的 x；**整厅 y = 块内 y + %d**（表里两个都写了）。" % Y0,
         "> 脚本 `godot/tools/layout_55/export_block_for_gpt.py`；数从摆位表 `make_board55.py`（排法 C）和游戏真在用的 `scene.json` 来，不另算。图在同一个文件夹：",
         "> `宴会厅%s-色块.png`（标准答案，不写字）、`宴会厅%s-色块-标注.png`（写了编号、脚点）、`宴会厅%s-现状.png`（游戏现在这块的样子，没人没界面）。" % (LABEL, LABEL, LABEL), "",
         "**看这几条再动手**", "",
         "- 色块图上每件东西画成它**画出来的框**（矩形），不是地上的占地。零件图本身四周有透明边（桌子两边各约 16～19 像素、灯两边各 13），所以画出来看得见的东西比框窄一点。",
         "- **脚点** = 这件东西落在地上那条占地的下沿中点。桌、长凳、小花盆 = 图下沿正中；落地灯、花架、礼物堆的占地比图窄一截，脚点 x 不在图正中（表里写了图里的脚点）。",
         "- 一种东西一个颜色。**零件的框之间会有重叠**（灯的框和旁边桌子的透明边搭几个像素），色块图按游戏里排前后的顺序画，后面的被前面压住；标注版描了黑边。",
         "- **人物不列**（人单独出）。图里不放人、不写字、没有界面。桌和灯是零件，**不画在背景里**。"]
    cut = extra["cut_ids"]
    if cut:
        L.append("- 这块的上下边界切到 %d 件零件（%s）：整件另一半在隔壁那块里，这里只露一截（表里写了「被切」和露出多少）；GPT 拆件时拿整件，别拿这一截。" % (len(cut), "、".join(cut)))
    L += ["", "## 一、零件（要拆，一种一张图，游戏里按下面的坐标摆多份）", "",
          "| 编号 | 名字 | 画出来多大 w×h | 脚点在图里 (x, y) | 这块里几件 | 其中被切 | 现用文件 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"]:
        L.append("| %s | %s | %d×%d | (%d, %d) | %d | %d | %s |" % (p["code"], p["name"], p["size"][0], p["size"][1], p["foot_in_image"][0], p["foot_in_image"][1], p["count"], p["count_cut"], ("`%s`" % p["art_file"]) if p["art_file"] else "还没有图"))
    L += ["", "合计：**%d 件**零件摆在这块里（其中 %d 件被切）。" % (sum(p["count"] for p in data["parts"]), len(cut)), "",
          "### 每件的位置（x、y 是框的左上角，整厅坐标；块内 y = 整厅 y − %d；脚点是整厅里的脚点坐标）" % Y0, "",
          "| 编号 | 名字 | x | y（整厅） | y（块内） | 脚点 (x, y 整厅) | 游戏里排前后的线 | 被切 |", "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"]:
        for i in p["instances"]:
            L.append("| %s | %s | %d | %d | %d | (%d, %d) | %s | %s |" % (i["id"], i["name"], i["x"], i["y"], i["y_in_block"], i["foot"][0], i["foot"][1], i["sort_y"] if i["sort_y"] is not None else "—", ("切（%s），露出 %d" % (i["cut"], i["visible_h"])) if i["cut"] else "—"))
    L += ["", "「游戏里排前后的线」：人和零件谁挡谁，按这条线的 y 比；给 02 摆回去用，GPT 不用管。", "",
          "## 二、背景（不拆，整张画）", "",
          "> 总表里只有 `B55S-BG01`（北边背景）、`B55S-W01`（地砖）、`B55S-W02/W03`（竖墙）。`BG01-a…n`、`BG02-a…f` 是临时起的子编号，只为了对照，要不要进总表等 01 定。", "",
          "| 编号 | 名字 | 框 x, y（整厅）, w×h | y（块内） | 依据 |", "| --- | --- | --- | --- | --- |"]
    for b in data["background"]:
        x, y, w, h = b["box"]
        ya, yb = max(y, Y0), min(y + h, Y1)
        size = "%d×%d" % (w, h) if (ya, yb) == (y, y + h) else "%d×%d（整件 y %d～%d，这块露 %d）" % (w, yb - ya, y, y + h, yb - ya)
        L.append("| %s | %s | %d, %d, %s | %d | %s |" % (b["id"], b["name"], x, ya, size, ya - Y0, b["basis"]))
    L += ["", "地面：除了上面这些，整块是浅色地砖（色块图里的浅米色，对应 `B55S-W01`）。", ""]
    return "\n".join(L)


# ---------- 自查 ----------
def check_scene(parts, scene):
    """零件框对 scene.json：x、y、零件图大小逐件对；件数对"""
    bad, rows = [], []
    occ_n = [o for o in scene["occluders"] if o["y"] < Y1 and o["y"] + part_h(o) > Y0]
    if len(occ_n) != len(parts):
        # 礼物堆、有的东西 scene.json 里没有（图还没来）：只比有图的
        n_img = sum(1 for r in parts if PARTS[r["prefix"]]["art"])
        if len(occ_n) != n_img:
            bad.append("scene.json 里这块的零件 %d 件，零件单有图的 %d 件" % (len(occ_n), n_img))
    for r in parts:
        if PARTS[r["prefix"]]["art"] is None:
            continue
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


_SIZE_CACHE = {}


def part_h(o):
    f = o["image"].replace("res://", "")
    if f not in _SIZE_CACHE:
        _SIZE_CACHE[f] = Image.open(os.path.join(GODOT, f)).size[1]
    return _SIZE_CACHE[f]


def check_table(data):
    """零件单尺寸 = docs/零件总表.md B55S 那几行（P05 写的是「约 96×80」，照数比）"""
    tab = open(TABLE_MD, encoding="utf-8").read()
    rows = {}
    for l in tab.splitlines():
        m = re.match(r"\| (B55S-[A-Z]+\d+) \| ([^|]*) \| `([^`]*)` \| (?:约 )?(\d+)×(\d+) \|", l)
        if m:
            rows[m.group(1)] = (int(m.group(4)), int(m.group(5)))
    bad = []
    for p in data["parts"]:
        t = rows.get(p["code"])
        if t is None:
            bad.append("%s 总表里找不到尺寸" % p["code"])
        elif tuple(p["size"]) != t:
            bad.append("%s 零件单 %s，总表 %s" % (p["code"], p["size"], t))
    return rows, bad


def count_on_picture(im):
    """色块图上数件数：每种颜色数连通块"""
    px = im.load()
    out = {}
    for prefix, cfg in PARTS.items():
        col = cfg["color"]
        seen = set()
        n = 0
        for y in range(BH):
            for x in range(W):
                if px[x, y] == col and (x, y) not in seen:
                    n += 1
                    stack = [(x, y)]
                    seen.add((x, y))
                    while stack:
                        cx, cy = stack.pop()
                        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                            if 0 <= nx < W and 0 <= ny < BH and (nx, ny) not in seen and px[nx, ny] == col:
                                seen.add((nx, ny))
                                stack.append((nx, ny))
        out[prefix] = n
    return out


def match_real(parts, real):
    """真图逐件模板对位：零件图不透明点在 (x+dx, y+dy) 处和真图像素一模一样的比例，dx、dy 取 -3～3，最贴的必须是 0,0"""
    px = real.load()
    res = []
    for r in parts:
        if PARTS[r["prefix"]]["art"] is None:
            continue
        im = part_art(r["prefix"])
        ap = im.load()
        x0, y0 = r["box"][0], r["box"][1] - Y0
        pts = [(i, j, ap[i, j][:3]) for j in range(0, im.height, 2) for i in range(0, im.width, 2) if ap[i, j][3] == 255]
        rates = {}
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                hit = tot = 0
                for i, j, c in pts:
                    X, Y = x0 + i + dx, y0 + j + dy
                    if 0 <= X < W and 0 <= Y < BH:
                        tot += 1
                        if px[X, Y][:3] == c:
                            hit += 1
                rates[(dx, dy)] = hit / tot if tot else None
        valid = {k: v for k, v in rates.items() if v is not None}
        if not valid:
            res.append({"id": r["id"], "best": None, "rate0": None, "rate_best": None, "second": None, "note": "整件在块外"})
            continue
        best = max(valid, key=lambda k: valid[k])
        second = max((v for k, v in valid.items() if k != best), default=0.0)
        res.append({"id": r["id"], "best": best, "rate0": rates[(0, 0)], "rate_best": valid[best], "second": second, "cut": bool(r["cut"])})
    return res


def render_extra(parts, real):
    """真图 = 背景 + 零件，没有别的（没有藏着的人、牌子、字）：真图跟 base.png 这一块逐像素比，扣掉零件不透明的地方，剩下不一样的像素数（应该是 0）。
    游戏里底图是有损导入（base.png.import compress/mode=1，质量 0.8），每点差几个色阶，差 > 64 才算不一样"""
    base = Image.open(os.path.join(SCENE_DIR, "base.png")).convert("RGB").crop((0, Y0, W, Y1))
    mask = Image.new("L", (W, BH), 0)
    for r in parts:
        if PARTS[r["prefix"]]["art"] is None:
            continue
        a = part_art(r["prefix"]).getchannel("A").point(lambda v: 255 if v else 0)
        mask.paste(255, (r["box"][0], r["box"][1] - Y0), a)
    d = ImageChops.difference(real, base)
    diff = ImageChops.lighter(ImageChops.lighter(d.getchannel(0), d.getchannel(1)), d.getchannel(2)).point(lambda v: 255 if v > 64 else 0)
    left = ImageChops.subtract(diff, mask)
    return {"diff_outside_parts": left.histogram()[255], "bbox_outside": left.getbbox(), "part_pixels": mask.histogram()[255]}


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def edge_x(px, rows, x_exp, win=12):
    """竖边：框的边在 x_exp（落在第 x_exp-1 列和第 x_exp 列之间）。±win 里找一排行平均亮度差最大的缝，回 (位置, 强度)"""
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


def measure_bg_south(real, bgs):
    """南边背景大件的边：在真图里找最明显的亮度缝跟色块框比（背景是 GPT 画的，框是 02 量的）。强度 < 12 标「看不清」"""
    px = real.load()
    by = {}
    for r in bgs:
        by.setdefault(r["kind"], []).append(r)
    out = []

    def add(name, edge, exp, got, strength):
        out.append({"item": name, "edge": edge, "expect": exp, "found": got, "diff": got - exp, "strength": round(strength, 1), "clear": strength >= 12})

    def ly(y):   # 整厅 y → 块内
        return y - Y0
    c = by["红毯"][0]["box"]
    # 灯的间隙里量：每排灯脚在 rows_y+23，灯高 112，两盏灯之间有空
    rows = []
    for ry in B.rows_y[5:9]:
        rows += list(range(ly(ry + 26), ly(ry + 60)))
    g, s = edge_x(px, rows, c[0]); add("红毯", "左缘", c[0], g, s)
    g, s = edge_x(px, rows, c[0] + c[2]); add("红毯", "右缘", c[0] + c[2], g, s)
    gw, ge = sorted(by["大门"], key=lambda r: r["box"][0])
    rg = range(ly(gw["box"][1] + 100), ly(gw["box"][1] + 150))
    for nm, r in (("西", gw), ("东", ge)):
        x, y, w, h = r["box"]
        g, s = edge_x(px, rg, x); add("大门（%s门柱）" % nm, "左缘", x, g, s)
        g, s = edge_x(px, rg, x + w); add("大门（%s门柱）" % nm, "右缘", x + w, g, s)
    sill = by["门槛"][0]["box"]
    g, s = edge_y(px, range(sill[0] + 14, sill[0] + 100), ly(sill[1]), 10); add("门槛", "上沿 y", sill[1], g + Y0, s)
    hole = by["门洞口"][0]["box"]
    g, s = edge_x(px, range(ly(hole[1] + 20), ly(hole[1] + 60)), hole[0], 14); add("门洞口", "左缘", hole[0], g, s)
    g, s = edge_x(px, range(ly(hole[1] + 20), ly(hole[1] + 60)), hole[0] + hole[2], 14); add("门洞口", "右缘", hole[0] + hole[2], g, s)
    for r in sorted(by["栏杆"], key=lambda r: r["box"][0]):
        x, y, w, h = r["box"]
        cols = list(range(x + 60, x + w - 60, 4))
        g, s = edge_y(px, cols, ly(y), 10); add(r["id"] + "（%s）" % ("西" if x < 700 else "东"), "栏杆顶 y", y, g + Y0, s)
        g, s = edge_y(px, cols, ly(y + h), 10); add(r["id"] + "（%s）" % ("西" if x < 700 else "东"), "栏杆脚 y", y + h, g + Y0, s)
    for name, xe in (("西墙", 40), ("东墙", W - 40)):
        for lo, hi in ((1262, 1392), (1556, 1702)):   # 这两段两边没有桌压着墙；东墙要躲开东侧门（1260～1318）
            rows_w = list(range(ly(max(lo, 1330) if name == "东墙" and lo == 1262 else lo), ly(hi)))
            g, s = edge_x(px, rows_w, xe, 12); add(name, "里边 x（整厅 y %d～%d）" % (lo, hi), xe, g, s)
    for r in by["东侧门"]:
        x, y, w, h = r["box"]
        g, s = edge_y(px, range(x + 4, x + 34, 3), ly(y), 10); add("东侧门", "上沿 y", y, g + Y0, s)
        g, s = edge_y(px, range(x + 4, x + 34, 3), ly(y + h), 10); add("东侧门", "下沿 y", y + h, g + Y0, s)
    return out


def wall_inner(real):
    """两边墙里边那条缝在哪：逐行找地砖从哪开始（色块里西墙里边 x 40、东墙里边 x 1496）"""
    px = real.load()

    def floor_like(c):
        return c[0] > 175 and c[1] > 160 and c[2] > 120 and c[0] - c[2] < 90
    rows = []
    for gy in range(Y0 + 60, Y1 - 120, 140):
        y = gy - Y0
        lx = next((x for x in range(0, 400) if all(floor_like(px[x + k, y]) for k in range(8))), None)
        rx = next((x for x in range(W - 1, W - 400, -1) if all(floor_like(px[x - k, y]) for k in range(8))), None)
        rows.append({"y": gy, "west_floor_from": lx, "east_floor_to": rx + 1 if rx is not None else None})
    return rows


def main():
    parts, bgs, scene = build_catalog()
    os.makedirs(OUT, exist_ok=True)
    clean = draw_blocks(parts, bgs, False)
    ann = draw_blocks(parts, bgs, True)
    clean.save(os.path.join(OUT, "宴会厅%s-色块.png" % LABEL))
    ann.save(os.path.join(OUT, "宴会厅%s-色块-标注.png" % LABEL))
    data = build_json(parts, bgs)
    cut = [r["id"] for r in parts if r["cut"]]
    extra = {"cut_ids": cut}
    json.dump(data, open(os.path.join(OUT, "宴会厅%s-零件单.json" % LABEL), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    open(os.path.join(OUT, "宴会厅%s-零件单.md" % LABEL), "w", encoding="utf-8").write(build_md(parts, bgs, data, extra))
    rows, bad = check_scene(parts, scene)
    _, bad_t = check_table(data)
    counts = count_on_picture(clean)
    listed = {p["code"]: p["count"] for p in data["parts"]}
    for p in PARTS:
        if counts.get(p, 0) != listed.get(p, 0):
            bad.append("色块图上数 %s 得 %d 块，零件单写 %d 件" % (p, counts.get(p, 0), listed.get(p, 0)))
    report = {"block": BLOCK, "scene_dev": rows, "scene_problems": bad, "table_problems": bad_t, "count_on_picture": counts, "count_listed": listed,
              "n_parts": len(parts), "n_bg": len(bgs), "cut": cut}
    if REAL:
        real = Image.open(REAL).convert("RGB")
        assert real.size == (W, BH), "真图不是 1536×%d：%s" % (BH, real.size)
        shutil.copyfile(REAL, os.path.join(OUT, "宴会厅%s-现状.png" % LABEL))
        report["real_match"] = match_real(parts, real)
        report["render_extra"] = render_extra(parts, real)
        report["wall_inner"] = wall_inner(real)
        if BLOCK == "south":
            report["bg_probe"] = measure_bg_south(real, bgs)
    json.dump(report, open(os.path.join(OUT, "验收数.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("%s边：零件 %d 件（被切 %d）、背景 %d 件" % (LABEL, len(parts), len(cut), len(bgs)))
    print("框对 scene.json、零件图：%s" % ("全部 0 偏差" if not bad else bad))
    print("零件单尺寸对零件总表：%s" % ("全对" if not bad_t else bad_t))
    print("色块图上数：", counts, "零件单：", listed)
    if REAL:
        rm = [m for m in report["real_match"] if m["best"] is not None]
        off = [m for m in rm if m["best"] != (0, 0)]
        print("真图 vs 底图：零件以外不一样的像素", report["render_extra"]["diff_outside_parts"])
        print("真图逐件对位：%d 件，最贴不在 0,0 的 %d 件；0,0 命中率最低 %.3f" % (len(rm), len(off), min(m["rate0"] for m in rm)))
    return 0 if not (bad or bad_t) else 1


if __name__ == "__main__":
    sys.exit(main())
