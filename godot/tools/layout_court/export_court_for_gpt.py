#!/usr/bin/env python3
"""迎宾院色块备料（01 E 10/3 派，03 做）：照宴会厅北边那套（layout_55/export_block_for_gpt.py），导给 GPT 照着画的标准答案。
等阿鱼锁迎宾院摆法以后给 GPT 用；这里只备料，不给 GPT。
数从两处拿，不另算：
  assets/layered/scene_luoman_entrance/layout.json   迎宾院唯一源（游戏照它画灰盒），背景的平铺矩形（flat）从这儿拿
  回执/零件规格/迎宾院/迎宾院-框.json                  gen_specs_court.py 出的每件东西画出来的外框（连高度）
背景大件（不拆，GPT 整张画）和零件（要拆、游戏里摆多份）分开：
  零件 = 玩家会走到它前面/后面、要按脚点排前后、或者点得到的东西：签到桌、茶桌、祝福牌、回忆册台（连书）、相机三脚架、打印台、凳子、落地宫灯、花箱、树
  背景 = 地面、宴会楼墙和楼门、红毯、两边围墙、小径口、南路面和石板、南墙、大门（门柱和门楼）、花墙、合影地毯
编号：迎宾院用 CT 前缀，类别照 docs/零件总表.md（T 桌、P 立着的东西、BG 整张背景）；背景子件临时起 CT-BG01-a…，等 01 定要不要进总表。
用法：python3 godot/tools/layout_court/export_court_for_gpt.py <输出目录> --now 现状.png --bgonly 只有地面.png
      现状 / 只有地面 用 tools/shot_court.gd 出（--world=0 出只有地面那张）。验：物件框对现状、背景矩形对只有地面那张。
不改游戏代码、不改零件总表。
"""
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_entrance", "layout.json")
BOXES = os.path.join(GODOT, "回执", "零件规格", "迎宾院", "迎宾院-框.json")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
W, H = 1536, 1024

argv = sys.argv[1:]
opts = {}
for k in ("--now", "--bgonly"):
    if k in argv:
        i = argv.index(k)
        opts[k] = argv[i + 1]
        del argv[i:i + 2]
OUT = argv[0] if argv else os.path.join(GODOT, "回执", "出图-迎宾院")

layout = json.load(open(LAYOUT, encoding="utf-8"))
boxes_doc = json.load(open(BOXES, encoding="utf-8"))
BOX = {it["id"]: it["box"] for it in boxes_doc["items"]}
ITEM = {it["id"]: it for it in layout["items"] if "id" in it}
FLAT = layout["flat"]


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---------- 零件（要拆）----------
# (编号, 名字, [layout 里的 id])。多件同种加序号 -01、-02……；回忆册台连书算一件（框 = 台子和书的并集）
PARTS = [
    ("CT-T01", "签到桌", ["sign_table"], (220, 70, 60)),
    ("CT-T02", "茶桌", ["tea_1", "tea_2", "tea_3"], (200, 40, 170)),
    ("CT-P01", "祝福牌", ["blessing_board"], (90, 190, 90)),
    ("CT-P02", "回忆册台（连翻开的书）", ["album_stand", "album_book_cover"], (255, 120, 190)),
    ("CT-P03", "相机三脚架", ["camera_w", "camera_e"], (110, 190, 255)),
    ("CT-P04", "打印台", ["print_desk"], (60, 100, 220)),
    ("CT-P05", "凳子", ["stool_1a", "stool_2a", "stool_2b", "stool_3a", "stool_3b"], (150, 225, 140)),
    ("CT-P06", "落地宫灯", ["lantern_w1", "lantern_e1", "lantern_w2", "lantern_e2", "lantern_w3", "lantern_e3"], (250, 230, 60)),
    ("CT-P07", "花箱", ["flower_box_w", "flower_box_e"], (255, 160, 60)),
    ("CT-P08", "树", ["tree_nw", "tree_ne", "tree_sw", "tree_se"], (30, 150, 70)),
]
# 背景（不拆）：(编号, 名字, 框 x0,y0,x1,y1, 颜色, 依据)；框来自 layout.json 的 flat 矩形或迎宾院-框.json
BG = []


def flat_rect(i):
    return [float(v) for v in FLAT[i]["rect"]]


def add_bg(code, name, box, color, basis):
    BG.append({"code": code, "name": name, "box": [float(v) for v in box], "color": color, "basis": basis})


add_bg("CT-BG01-a", "地面", flat_rect(0), (239, 227, 207), "layout flat[0]：整张 1536×1024，米色地")
add_bg("CT-BG01-g", "南路面", flat_rect(1), (150, 150, 150), "layout flat[1]：y 950 往南灰路面")
add_bg("CT-BG01-g2", "大门前石板", flat_rect(2), (185, 171, 142), "layout flat[2]：大门口 652～884 × 900～1024")
add_bg("CT-BG01-b", "宴会楼墙", flat_rect(3), (122, 74, 58), "layout flat[3]：北边整条墙 y 0～190")
add_bg("CT-BG01-b2", "墙顶梁", flat_rect(5), (62, 42, 36), "layout flat[5]：y 0～36")
add_bg("CT-BG01-b3", "墙脚深色带", flat_rect(4), (94, 53, 40), "layout flat[4]：y 150～190")
add_bg("CT-BG01-c", "楼门", flat_rect(6), (42, 26, 22), "layout flat[6]：宴会楼门洞 648～888 × 88～190")
add_bg("CT-BG01-c2", "门楣金线", flat_rect(7), (212, 175, 55), "layout flat[7]：640～896 × 80～90")
add_bg("CT-BG01-d", "红毯", flat_rect(10), (176, 50, 42), "layout flat[10]：672～864 × 190～900，两边各一条 10 宽的金边（flat[11]、[12]）")
add_bg("CT-BG01-e1", "西围墙（北段）", flat_rect(13), (138, 122, 100), "layout flat[13]：0～40 × 190～486")
add_bg("CT-BG01-e2", "西围墙（南段）", flat_rect(14), (138, 122, 100), "layout flat[14]：0～40 × 554～950；中间 486～554 是西小径口")
add_bg("CT-BG01-e3", "东围墙（北段）", flat_rect(15), (138, 122, 100), "layout flat[15]：1496～1536 × 190～746")
add_bg("CT-BG01-e4", "东围墙（南段）", flat_rect(16), (138, 122, 100), "layout flat[16]：1496～1536 × 814～950；中间 746～814 是东小径口")
add_bg("CT-BG01-f1", "西小径口", flat_rect(17), (194, 179, 147), "layout flat[17]：0～52 × 490～550，通湖边")
add_bg("CT-BG01-f2", "东小径口", flat_rect(18), (194, 179, 147), "layout flat[18]：1484～1536 × 750～810，通草坪")
add_bg("CT-BG01-k", "合影地毯", flat_rect(21), (192, 57, 43), "layout flat[21]～[23]：1094～1286 × 368～432，红底金边")
for i, wid in enumerate(("wall_s_w", "wall_s_e")):
    add_bg("CT-BG01-h%d" % (i + 1), "南墙（%s段）" % ("西" if i == 0 else "东"), BOX[wid], (124, 109, 87), "迎宾院-框.json %s：高 58" % wid)
for i, wid in enumerate(("gate_post_w", "gate_post_e")):
    add_bg("CT-BG01-i%d" % (i + 1), "大门门柱（%s）" % ("西" if i == 0 else "东"), BOX[wid], (110, 33, 27), "迎宾院-框.json %s：高 196" % wid)
add_bg("CT-BG01-i3", "大门门楼（横梁）", BOX["gate_roof"], (62, 42, 36), "迎宾院-框.json gate_roof：344 宽，门洞 232")
add_bg("CT-BG01-j", "花墙（连囍字）", BOX["flower_wall"], (60, 170, 120), "迎宾院-框.json flower_wall：216×125，囍字圆牌在里面")
BG_ORDER = ["CT-BG01-a", "CT-BG01-g", "CT-BG01-g2", "CT-BG01-b", "CT-BG01-b2", "CT-BG01-b3", "CT-BG01-c", "CT-BG01-c2", "CT-BG01-d",
            "CT-BG01-e1", "CT-BG01-e2", "CT-BG01-e3", "CT-BG01-e4", "CT-BG01-f1", "CT-BG01-f2", "CT-BG01-k", "CT-BG01-j",
            "CT-BG01-h1", "CT-BG01-h2", "CT-BG01-i1", "CT-BG01-i2", "CT-BG01-i3"]


def union(boxes):
    return [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]


def foot_of(wid, box):
    """脚点：落地的下沿中点；落地宫灯照 layout 里的锚点 (x, y)，别的取框下沿正中"""
    it = ITEM[wid]
    if it.get("type") == "image":
        return (float(it["x"]), float(it["y"]))
    return ((box[0] + box[2]) / 2.0, box[3])


def build_parts():
    out = []
    for code, name, ids, color in PARTS:
        multi = len(ids) > 1 and code != "CT-P02"
        inst = []
        if code == "CT-P02":
            box = union([BOX["album_stand"], BOX["album_book_cover"]])
            inst.append({"id": code, "src": ids, "box": box, "foot": foot_of("album_stand", BOX["album_stand"])})
        else:
            for n, wid in enumerate(ids):
                box = BOX[wid]
                inst.append({"id": "%s-%02d" % (code, n + 1) if multi else code, "src": [wid], "box": box, "foot": foot_of(wid, box)})
        out.append({"code": code, "name": name, "color": color, "inst": inst})
    return out


def draw_blocks(parts, labels):
    im = Image.new("RGB", (W, H), (239, 227, 207))
    g = ImageDraw.Draw(im)
    bg = {b["code"]: b for b in BG}
    for code in BG_ORDER:
        b = bg[code]
        x0, y0, x1, y1 = b["box"]
        g.rectangle([x0, y0, x1 - 1, y1 - 1], fill=b["color"])
    allp = [(p, i) for p in parts for i in p["inst"]]
    for p, i in sorted(allp, key=lambda t: (t[1]["foot"][1], t[1]["box"][0])):
        x0, y0, x1, y1 = i["box"]
        g.rectangle([x0, y0, x1 - 1, y1 - 1], fill=p["color"])
    if not labels:
        return im
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    f11, f13 = ImageFont.truetype(FONT, 11), ImageFont.truetype(FONT, 13)

    def txt(xy, s, fnt, col=(255, 255, 255), anchor="mm"):
        d.text(xy, s, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=2, stroke_fill=(0, 0, 0, 255))

    for b in [bg[c] for c in BG_ORDER]:
        x0, y0, x1, y1 = b["box"]
        d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(0, 0, 0, 160), width=1)
    for p, i in allp:
        x0, y0, x1, y1 = i["box"]
        d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(0, 0, 0, 255), width=1)
    # 背景编号写在各自的位置（地面等大块写在空地上）
    spots = {"CT-BG01-a": (300, 760), "CT-BG01-g": (300, 990), "CT-BG01-g2": (768, 990), "CT-BG01-b": (340, 120), "CT-BG01-b2": (300, 18), "CT-BG01-b3": (340, 172),
             "CT-BG01-c": (768, 140), "CT-BG01-c2": (768, 80), "CT-BG01-d": (768, 340), "CT-BG01-e1": (20, 330), "CT-BG01-e2": (20, 750), "CT-BG01-e3": (1516, 470),
             "CT-BG01-e4": (1516, 880), "CT-BG01-f1": (26, 520), "CT-BG01-f2": (1510, 780), "CT-BG01-k": (1190, 400), "CT-BG01-j": (1192, 305),
             "CT-BG01-h1": (320, 920), "CT-BG01-h2": (1210, 920), "CT-BG01-i1": (634, 800), "CT-BG01-i2": (902, 800), "CT-BG01-i3": (768, 696)}
    names = {b["code"]: b["name"] for b in BG}
    for code, xy in spots.items():
        left = code in ("CT-BG01-e1", "CT-BG01-e2", "CT-BG01-f1")     # 贴左右边的墙、小径口：字靠边写，别被画布切掉
        right = code in ("CT-BG01-e3", "CT-BG01-e4", "CT-BG01-f2")
        if left:
            txt((44, xy[1]), code.replace("CT-", "") + " " + names[code], f11, anchor="lm")
        elif right:
            txt((1492, xy[1]), code.replace("CT-", "") + " " + names[code], f11, anchor="rm")
        else:
            txt(xy, code.replace("CT-", "") + " " + names[code], f11)
    for p, i in allp:
        x0, y0, x1, y1 = i["box"]
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        short = i["id"].replace("CT-", "")
        if x1 - x0 < 60:
            pt = short.split("-")
            txt((cx, cy - 6), pt[0], f11)
            if len(pt) > 1:
                txt((cx, cy + 8), "-".join(pt[1:]), f11)
        else:
            txt((cx, cy), short, f13)
        fx, fy = i["foot"]
        d.line([(fx - 6, fy), (fx + 6, fy)], fill=(0, 255, 255, 255), width=2)
        d.line([(fx, fy - 6), (fx, fy + 6)], fill=(0, 255, 255, 255), width=2)
    txt((768, 1010), "青十字 = 脚点（落地下沿中点）  黑框 = 画出来的框  图上省略前缀 CT-  迎宾院 1536×1024，1:1", f13)
    return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")


def verify(parts, now, bgonly):
    """① 物件：现状图 vs 只有地面那张，差出来的像素（= 世界层里的物件）跟声明的框比：框外多出的像素数；每件框里差出来的外框 vs 声明的框
       ② 背景矩形：自己按 layout flat 一块块画出来 vs 只有地面那张，差多少像素"""
    res = {}
    d = ImageChops.difference(now, bgonly).convert("L").point(lambda v: 255 if v else 0)
    declared = Image.new("L", (W, H), 0)
    dg = ImageDraw.Draw(declared)
    every = [i["box"] for p in parts for i in p["inst"]] + [BOX[k] for k in ("wall_s_w", "wall_s_e", "gate_post_w", "gate_post_e", "gate_roof", "flower_wall")]
    for b in every:
        dg.rectangle([int(b[0]) - 1, int(b[1]) - 1, int(b[2]), int(b[3])], fill=255)
    outside = ImageChops.subtract(d, declared)
    res["item_pixels"] = d.histogram()[255]
    res["outside_boxes"] = outside.histogram()[255]
    res["outside_bbox"] = outside.getbbox()
    dev = []
    for p in parts:
        for i in p["inst"]:
            x0, y0, x1, y1 = [int(round(v)) for v in i["box"]]
            pad = 4
            # 下沿压进南墙（y 880 以下）的零件（花箱、南边两棵树）：南墙也是物件、连成一片，下沿量不出来，只比上、左、右（取 y 876 以上的行）
            wall = y1 > 880
            yb = min(y1, 876) if wall else y1
            crop = d.crop((x0 - pad, y0 - pad, x1 + pad, yb + (0 if wall else pad)))
            bb = crop.getbbox()
            if bb is None:
                dev.append({"id": i["id"], "err": "框里什么都没画"})
                continue
            m = [bb[0] - pad + x0, bb[1] - pad + y0, bb[2] - pad + x0, bb[3] - pad + y0]
            if wall:
                dev.append({"id": i["id"], "declared": [x0, y0, x1, y1], "measured": m[:3] + [None], "dev": [m[0] - x0, m[1] - y0, m[2] - x1, 0], "wall_overlap": True})
            else:
                dev.append({"id": i["id"], "declared": [x0, y0, x1, y1], "measured": m, "dev": [m[0] - x0, m[1] - y0, m[2] - x1, m[3] - y1]})
    res["parts_dev"] = dev
    # 背景矩形：按 flat 顺序自己画一遍
    ref = Image.new("RGB", (W, H))
    g = ImageDraw.Draw(ref)
    for it in FLAT:
        if it.get("type") == "rect":
            x0, y0, x1, y1 = it["rect"]
            g.rectangle([x0, y0, x1 - 1, y1 - 1], fill=hexc(it["color"]))
    dd = ImageChops.difference(ref, bgonly.convert("RGB")).convert("L").point(lambda v: 255 if v > 0 else 0)
    res["flat_diff_pixels"] = dd.histogram()[255]
    res["flat_diff_bbox"] = dd.getbbox()
    return res


def count_on_picture(im, parts):
    px = im.load()
    out = {}
    for p in parts:
        col = p["color"]
        seen = set()
        n = 0
        xs0 = max(0, int(min(i["box"][0] for i in p["inst"])) - 2)
        xs1 = min(W, int(max(i["box"][2] for i in p["inst"])) + 2)
        ys0 = max(0, int(min(i["box"][1] for i in p["inst"])) - 2)
        ys1 = min(H, int(max(i["box"][3] for i in p["inst"])) + 2)
        for y in range(ys0, ys1):
            for x in range(xs0, xs1):
                if px[x, y] == col and (x, y) not in seen:
                    n += 1
                    st = [(x, y)]
                    seen.add((x, y))
                    while st:
                        cx, cy = st.pop()
                        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                            if xs0 <= nx < xs1 and ys0 <= ny < ys1 and (nx, ny) not in seen and px[nx, ny] == col:
                                seen.add((nx, ny))
                                st.append((nx, ny))
        out[p["code"]] = n
    return out


def r1(v):
    return int(round(v))


def main():
    os.makedirs(OUT, exist_ok=True)
    parts = build_parts()
    clean = draw_blocks(parts, False)
    ann = draw_blocks(parts, True)
    clean.save(os.path.join(OUT, "迎宾院-色块.png"))
    ann.save(os.path.join(OUT, "迎宾院-色块-标注.png"))
    data = {"canvas": [W, H], "note": "x、y 是画出来的框的左上角（整张迎宾院 1536×1024 坐标）；脚点是落地下沿中点，落地宫灯用 layout 里的锚点；回忆册台连书算一件",
            "source": "assets/layered/scene_luoman_entrance/layout.json + 回执/零件规格/迎宾院/迎宾院-框.json", "parts": [], "background": []}
    for p in parts:
        b0 = p["inst"][0]["box"]
        data["parts"].append({"code": p["code"], "name": p["name"], "size": [r1(b0[2] - b0[0]), r1(b0[3] - b0[1])], "count": len(p["inst"]),
                              "instances": [{"id": i["id"], "src": i["src"], "x": r1(i["box"][0]), "y": r1(i["box"][1]), "w": r1(i["box"][2] - i["box"][0]), "h": r1(i["box"][3] - i["box"][1]),
                                             "foot": [r1(i["foot"][0]), r1(i["foot"][1])], "sort_y": r1(i["foot"][1])} for i in p["inst"]]})
    for b in BG:
        x0, y0, x1, y1 = b["box"]
        data["background"].append({"id": b["code"], "name": b["name"], "box": [r1(x0), r1(y0), r1(x1 - x0), r1(y1 - y0)], "basis": b["basis"]})
    json.dump(data, open(os.path.join(OUT, "迎宾院-零件单.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    counts = count_on_picture(clean, parts)
    listed = {p["code"]: len(p["inst"]) for p in parts}
    rep = {"count_on_picture": counts, "count_listed": listed}
    problems = [c for c in listed if counts.get(c, 0) != listed[c]]
    if "--now" in opts and "--bgonly" in opts:
        now = Image.open(opts["--now"]).convert("RGB")
        bgo = Image.open(opts["--bgonly"]).convert("RGB")
        assert now.size == (W, H) and bgo.size == (W, H)
        Image.open(opts["--now"]).convert("RGB").save(os.path.join(OUT, "迎宾院-现状.png"))
        rep["verify"] = verify(parts, now, bgo)
    json.dump(rep, open(os.path.join(OUT, "验收数.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=list)
    # ---- md ----
    L = ["# 迎宾院 · 色块备料 · 零件单（给 GPT 照着画、照着拆；**现在不给 GPT**，等阿鱼锁了迎宾院摆法）", "",
         "> 03，2026-10-03，01 E 派。**标准答案**：位置、大小和游戏里一模一样，一张 **1536×1024**，1:1，坐标原点是画布左上角（没有分块）。",
         "> 数从迎宾院唯一源 `assets/layered/scene_luoman_entrance/layout.json` 和 `回执/零件规格/迎宾院/迎宾院-框.json`（`gen_specs_court.py` 出，已照「人 = 1」比例尺改过）来，不另算。脚本 `godot/tools/layout_court/export_court_for_gpt.py`。",
         "> 图在同一个文件夹：`迎宾院-色块.png`（标准答案，不写字）、`迎宾院-色块-标注.png`（写了编号、脚点）、`迎宾院-现状.png`（游戏现在这块的样子：灰盒，没人没界面没字）。", "",
         "**看这几条再动手**", "",
         "- 色块图上每件东西画成它**画出来的框**（矩形，连高度），不是地上的占地；现在游戏里全是灰盒占位，GPT 照框画成正式画面。",
         "- **脚点** = 这件东西落在地上那条线的下沿中点，游戏里按它排谁挡谁。桌、台、树、三脚架、凳子、花箱 = 框下沿正中；落地宫灯用游戏里的锚点（框下沿往下 4 像素）。",
         "- **背景是整张画的**（地面、楼墙楼门、红毯、围墙、小径口、石板、南墙、大门、花墙、合影地毯），**零件是拆出来的**（透明底，游戏里按脚点排前后）。人物不列、不画进图。",
         "- 一种东西一个颜色；零件框和背景框会重叠（桌压在地面上、灯压在红毯边上），色块图按游戏里排前后的顺序画。",
         "- 图里不写字、不画对联横幅；「宴会楼」「楼门」「签到」那些字是游戏自己写的，不画。", "",
         "## 一、零件（要拆）", "",
         "| 编号 | 名字 | 画出来多大 w×h | 这张图里几件 | 说明 |", "| --- | --- | --- | --- | --- |"]
    note = {"CT-T01": "签到桌：桌面、桌上的签到本和礼金盒都算它", "CT-T02": "茶桌：圆的矮桌；凳子单独算", "CT-P01": "祝福牌：木牌，钉着彩色小纸条（纸条的颜色不用管，字不画）",
            "CT-P02": "回忆册台：台子加台上摊开的一本书，一起拆", "CT-P03": "相机三脚架：只有架子和相机头，不画摄影师", "CT-P04": "打印台：台上一台打印机，纸出口朝外",
            "CT-P05": "凳子：茶桌旁的小圆凳", "CT-P06": "落地宫灯：红毯两边那种，**跟宴会厅的落地灯是一个类型**，高 59（宴会厅那盏 112，这里更矮）", "CT-P07": "花箱：长条花箱，开着花",
            "CT-P08": "树：整棵（树冠加树干），树冠在人前面画"}
    for p in data["parts"]:
        L.append("| %s | %s | %d×%d | %d | %s |" % (p["code"], p["name"], p["size"][0], p["size"][1], p["count"], note[p["code"]]))
    L += ["", "合计 **%d 件**零件。" % sum(p["count"] for p in data["parts"]), "", "### 每件的位置（整张图坐标；x、y 是框左上角；脚点 = 落地下沿中点；排前后的线 = 脚点 y）", "",
          "| 编号 | 名字 | x | y | 宽×高 | 脚点 (x, y) | 排前后的线 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"]:
        for i in p["instances"]:
            L.append("| %s | %s | %d | %d | %d×%d | (%d, %d) | %d |" % (i["id"], p["name"], i["x"], i["y"], i["w"], i["h"], i["foot"][0], i["foot"][1], i["sort_y"]))
    L += ["", "## 二、背景（不拆，整张画）", "",
          "> 总表里还没有迎宾院的编号；`CT-BG01`（整张迎宾院背景）和下面 `-a…-k` 子件都是我临时起的，只为对照，**要不要进零件总表等 01 定**。", "",
          "| 编号 | 名字 | 框 x, y, 宽×高 | 依据 |", "| --- | --- | --- | --- |"]
    for b in data["background"]:
        L.append("| %s | %s | %d, %d, %d×%d | %s |" % (b["id"], b["name"], b["box"][0], b["box"][1], b["box"][2], b["box"][3], b["basis"]))
    L += ["", "「宴会楼」那一整条（`b`、`b2`、`b3`、`c`、`c2`）是北边的楼，楼门里是黑的（进楼门就切到宴会厅）；红毯 `d` 从楼门往南铺到大门口，穿过大门门洞。", ""]
    open(os.path.join(OUT, "迎宾院-零件单.md"), "w", encoding="utf-8").write("\n".join(L))
    print("零件 %d 件、背景 %d 件" % (sum(len(p["inst"]) for p in parts), len(BG)))
    print("色块图上数：", counts, "零件单：", listed, "OK" if not problems else "对不上 %s" % problems)
    if "verify" in rep:
        v = rep["verify"]
        print("物件像素 %d，声明的框外多出 %d 个（外框 %s）；背景矩形自己画的跟只有地面那张差 %d 像素 %s" % (v["item_pixels"], v["outside_boxes"], v["outside_bbox"], v["flat_diff_pixels"], v["flat_diff_bbox"]))
        bad = [x for x in v["parts_dev"] if "err" in x or max(abs(t) for t in x["dev"]) > 1]
        print("零件框对现状：%d 件，偏差 >1 像素的 %d 件 %s" % (len(v["parts_dev"]), len(bad), [(x["id"], x.get("dev", x.get("err"))) for x in bad]))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
