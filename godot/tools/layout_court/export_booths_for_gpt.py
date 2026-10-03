#!/usr/bin/env python3
"""后厅（三间，厨房不算）、草坪、湖边、果园 四块色块备料（01 E 10/3 派，03 做）：照迎宾院那套（export_court_for_gpt.py），导给 GPT 照着画的标准答案。
等 01 拿色块给阿鱼看、阿鱼点头以后给 GPT 用；这里只备料，不给 GPT。
数从三处拿，不另算、不手抄：
  assets/layered/scene_luoman_<场景>/layout.json   四块的唯一源（游戏照它画灰盒）：items 的 part / inst 分零件，flat 的平铺矩形是背景，npcs 的 lm 是人
  回执/零件规格/<场景>/<场景>-框.json              gen_specs_court.py 出的每件东西画出来的外框（连高度），一件零件 = 它名下各块框的并集
  docs/零件总表.md                                  零件编号和名字（LW、LK、OR、BH 四节）
零件 = 玩家会走到它前面/后面（按脚点排前后）或点得到的东西；背景 = 地面、水、路、后墙、地板这些平铺的大块。
总表里没有的件（后厅的隔墙、前沿矮墙、行李箱，草坪四周的树）临时起了编号（BH-W01、BH-W02、BH-P13、LW-P08），等 01 定；后厅东头厨房归 GPT（K-BG01），这里只画一块灰、不拆。
用法：python3 godot/tools/layout_court/export_booths_for_gpt.py [--scene backhall|lawn|lake|orchard] --shots <截图目录> [--out <输出根目录>]
      截图目录里要有 <场景>-w1.png（现状：没人没字）、<场景>-w0.png（只有地面）、<场景>-ppl.png（带人），都用 tools/shot_booth.gd 出（要有窗口）。
      默认出到 回执/零件规格/<场景>/<场景>-色块.png、-色块-标注.png、-现状.png、-现状-带人.png、-零件单.md、-零件单.json、-色块验收数.json
不改游戏代码、不改零件总表、不改 02 出的 尺寸表 / 框。
"""
import json
import os
import re
import sys
import colorsys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
DOCS = os.path.join(os.path.dirname(GODOT), "docs", "零件总表.md")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
SCENES = {"backhall": ("scene_luoman_backhall", "后厅", "BH"), "lawn": ("scene_luoman_lawn", "草坪", "LW"),
          "lake": ("scene_luoman_lake", "湖边", "LK"), "orchard": ("scene_luoman_orchard", "果园", "OR")}
PERSON_W = 36        # 人的色块宽（第一格宽 ≤36，量游戏里站着的人是 32 宽）
STAND_H = 84.0       # 站着：84 × size
SIT_H = 50.0         # 坐着：游戏只画上半身 floor(32×0.62)=19 行 × 2.625 ≈ 50（量了 8 位坐着的 47～50）；× size
KITCHEN = [1008.0, 104.0, 1536.0, 684.0]   # 后厅东头厨房整块（归 GPT：flat[9] 厨房地面 + 上面的后墙，GPT 的图盖在上面）


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def parse_names():
    """零件总表：编号 → 名字"""
    out = {}
    for line in open(DOCS, encoding="utf-8"):
        m = re.match(r"^\| ((?:BH|LW|LK|OR)-[A-Z]+\d+) \| ([^|]+?) \|", line)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


NAMES = parse_names()

# ---------- 每块：总表没有的件（临时编号）、不进零件单的东西、背景分组 ----------
# 临时编号：(编号, 名字, [layout 里的 id] 或 "tree_" 开头的前缀, 一件一份还是几件算一份)
EXTRA = {
    "backhall": [("BH-W01", "隔墙（三间房之间那三道）", ["wall_1", "wall_2", "wall_3"]),
                 ("BH-W02", "前沿矮墙（房间和走廊之间，留四个门口）", ["front_1", "front_2", "front_3", "front_4", "front_5"]),
                 ("BH-P13", "行李箱", ["luggage_1", "luggage_2"])],
    "lawn": [("LW-P08", "树（草坪四周）", "prefix:tree_")],
    "lake": [], "orchard": [],
}
# 不进零件单的 layout 物件：原因
SKIP = {
    "backhall": {**{k: "厨房（归 GPT，K-BG01 整间）" for k in ("counter_w", "counter_e", "brick_stove", "pot", "steam", "board", "bowl_table")},
                 **{k: "长辈手里的茶杯（跟人走，不单独画）" for k in ("teacup_1", "teacup_1_tea", "teacup_2", "teacup_2_tea")}},
    "lawn": {}, "lake": {}, "orchard": {},
}
# 背景分组：(编号后缀, 名字, [flat 下标], 说明)。下标照 layout.json 的 flat 数组（含 label，label 不画），说明里写依据；对不上颜色就报错（防 layout 改了这里没跟着改）
BG = {
    "backhall": [
        ("a", "画布底（屋子上下的黑褐底，走不到）", [0], "flat[0]：整张 1536×1024"),
        ("b", "后墙", [1], "flat[1]：y 104～226，三间房顶上整条（厨房那段被厨房图盖住）"),
        ("b2", "后墙顶亮线", [2], "flat[2]：y 104～114"),
        ("b3", "后墙脚暗线", [3], "flat[3]：y 218～226"),
        ("c", "化妆室后墙大镜子（金框玻璃）", [4, 5], "flat[4]、[5]：54～146 × 124～214"),
        ("d1", "化妆室地面", [6], "flat[6]：0～336 × 226～684"),
        ("d2", "休息间地面", [7], "flat[7]：336～672 × 226～684"),
        ("d3", "麻将室地面", [8], "flat[8]：672～1008 × 226～684"),
        ("e", "走廊地面", [34], "flat[34]：0～1536 × 696～884"),
        ("e2", "走廊红地毯（连两条金边）", [35, 36, 37], "flat[35]～[37]：y 764～800"),
        ("e3", "走廊下沿墙", [38], "flat[38]：y 884～900"),
        ("f", "房间通走廊的四个门口门槛", [39, 40, 41, 42], "flat[39]～[42]：128～208、464～544、800～880、1136～1216，各 80×12"),
        ("g", "两头的出口光条（回宴会厅、后门）", [43, 44], "flat[43]、[44]：西 0～14、东 1522～1536 × 720～850"),
    ],
    "lawn": [
        ("a", "草地", [0], "flat[0]：整张 1536×1024"),
        ("b", "草地深浅条纹（7 条）", [1, 2, 3, 4, 5, 6, 7], "flat[1]～[7]：每条 32 高，隔 96"),
        ("c1", "北边林带（西段）", [8], "flat[8]：0～740 × 0～116；740～796 是去果园的口"),
        ("c2", "北边林带（东段）", [9], "flat[9]：796～1536 × 0～116"),
        ("c3", "西边林带（三段）", [10, 11, 12], "flat[10]～[12]：x 0～14，留去后厅（262～338）、回迎宾院（742～818）两个口"),
        ("c4", "东边林带", [13], "flat[13]：1522～1536"),
        ("c5", "南边林带", [14], "flat[14]：y 1010～1024"),
        ("d1", "西南口横路（回迎宾院）", [15, 16], "flat[15]、[16]：0～798 × 758～802，外沿 + 路面"),
        ("d2", "竖路（去果园）", [17, 18], "flat[17]、[18]：738～798 × 0～802，外沿 + 路面"),
        ("d3", "西北口横路（去后厅，折了一下）", [19, 20, 21, 22, 23], "flat[19]～[23]：0～238 × 278～322 接 216～742 × 234～278"),
        ("e", "孩童区沙地", [24, 25], "flat[24]、[25]：1106～1494 × 256～596，外沿 + 沙面"),
    ],
    "lake": [
        ("a", "草地底（整张）", [0], "flat[0]：整张 1536×1280"),
        ("b", "北岸林带（深浅 7 层）", [1, 2, 3, 4, 5, 6, 7], "flat[1]～[7]：y 0～316"),
        ("c", "湖水", [8], "flat[8]：0～1536 × 312～776"),
        ("c2", "水波纹（39 条小横线）", list(range(9, 48)), "flat[9]～[47]：每条 3～4 高、20～45 宽，散在湖面上"),
        ("c3", "岸边浅水带", [48], "flat[48]：y 750～776"),
        ("d", "沙滩", [49], "flat[49]：y 770～804"),
        ("e", "南岸草地", [50], "flat[50]：y 796～1162"),
        ("f", "南边林带", [51], "flat[51]：y 1156～1280"),
        ("g", "沿岸小路（外沿 + 路面）", [52, 53], "flat[52]、[53]：80～1536 × 940～1004"),
        ("g2", "亭子通小路的竖路（外沿 + 路面）", [54, 55], "flat[54]、[55]：740～796 × 804～956"),
        ("h", "栈道（LK-W01，亭子到岸边那段，连两边木边和 15 道板缝）", [56] + list(range(76, 92)), "flat[56]、[76]～[91]：714～822 × 552～818，路面 96 宽"),
        ("i", "亭子地板（连木边和板缝；亭子压在它上面）", list(range(57, 76)), "flat[57]～[75]：618～918 × 422～658，地板 288 见方"),
    ],
    "orchard": [
        ("a", "草地底（整张）", [0], "flat[0]：整张 1536×1280"),
        ("b", "北边草地分层（6 层深浅）", [1, 2, 4, 6, 7, 8], "flat[1]、[2]、[4]、[6]～[8]：y 0～406"),
        ("b2", "北边两条土路", [3, 5], "flat[3]、[5]：y 114～128、186～200"),
        ("c", "田埂（连南沿暗边）", [9, 10], "flat[9]、[10]：0～1536 × 406～456"),
        ("d", "中间竖路（外沿 + 路面）", [11, 12], "flat[11]、[12]：714～822 × 442～1166"),
        ("e1", "草莓地", [13], "flat[13]：88～708 × 494～1068"),
        ("e2", "枇杷地", [14], "flat[14]：840～1462 × 494～1068"),
        ("f", "收购处前路面", [15], "flat[15]：60～1490 × 1102～1150"),
    ],
}
# 背景名字在图上写在哪儿（大块默认写在第一块矩形中心会压到东西，指定一个空地）
LABEL_AT = {
    "backhall": {"a": (768, 40), "b": (200, 100), "c": (100, 140), "d1": (170, 330), "d2": (504, 600), "d3": (840, 640), "e": (600, 740), "e2": (770, 782), "e3": (770, 892), "f": (168, 690), "g": (40, 790), "b2": (400, 108), "b3": (400, 222)},
    "lawn": {"a": (1000, 700), "b": (900, 120), "d1": (200, 780), "d2": (768, 300), "d3": (120, 300), "e": (1300, 560), "c1": (300, 60), "c2": (1150, 60), "c3": (8, 600), "c4": (1500, 600), "c5": (768, 1017)},
    "lake": {"a": (768, 1100), "b": (768, 200), "c": (400, 420), "c2": (300, 380), "c3": (1200, 765), "d": (1100, 787), "e": (1100, 1100), "f": (200, 1230), "g": (1100, 972), "g2": (768, 900), "h": (768, 806), "i": (768, 440)},
    "orchard": {"a": (1000, 1200), "b": (768, 40), "b2": (300, 121), "c": (1200, 424), "d": (768, 600), "e1": (400, 520), "e2": (1150, 520), "f": (768, 1126)},
}
# 零件框叠到别的东西上的特例说明：不用写，自动算（见 overlaps）

# 零件的色块颜色：按编号排好顺序，一个编号一个颜色，跟背景、人的颜色都不重
def make_palette(n):
    out = []
    for i in range(n):
        h = (i * 0.61803398875) % 1.0
        s = 0.85 if i % 2 == 0 else 0.6
        v = 0.95 if i % 3 else 0.75
        r, g, b = colorsys.hsv_to_rgb(h, s, v)
        out.append((int(r * 255), int(g * 255), int(b * 255)))
    return out


PEOPLE_COL = {"stand": (255, 255, 255), "sit": (200, 255, 255), "kid": (255, 255, 150)}


def union(boxes):
    return [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]


def r1(v):
    return int(round(v))


def item_foot(it):
    f = it.get("foot")
    if f is None:
        f = it["rect"][3] if "rect" in it else it.get("y")
    return f


class Scene:
    def __init__(self, key):
        self.key = key
        folder, self.cn, self.pre = SCENES[key]
        self.layout_path = os.path.join(GODOT, "assets", "layered", folder, "layout.json")
        self.boxes_path = os.path.join(GODOT, "回执", "零件规格", self.cn, "%s-框.json" % self.cn)
        self.layout = json.load(open(self.layout_path, encoding="utf-8"))
        self.box = {it["id"]: [float(v) for v in it["box"]] for it in json.load(open(self.boxes_path, encoding="utf-8"))["items"]}
        self.W, self.H = self.layout["size"]
        self.flat = self.layout["flat"]
        self.parts = []   # {code, name, color, temp, inst:[{id, src, box, foot, sort_lines}]}
        self.bgs = []     # {code, name, rects:[(idx, rect, color)], box, basis}
        self.people = []
        self.skipped = {}
        self.build()

    # ---- 零件 ----
    def build(self):
        L = self.layout
        items = L["items"]
        byid = {it["id"]: it for it in items}
        used = set()
        # 总表有编号的：按 inst 分件，按 part 分种
        groups = {}
        order = []
        for it in items:
            if it.get("part") and it.get("inst"):
                if it["part"] not in groups:
                    groups[it["part"]] = {}
                    order.append(it["part"])
                groups[it["part"]].setdefault(it["inst"], []).append(it)
        specs = []
        for code in order:
            specs.append((code, NAMES.get(code, "（总表没有）"), False, [(inst, its) for inst, its in groups[code].items()]))
        for code, name, ids in EXTRA[self.key]:
            if isinstance(ids, str) and ids.startswith("prefix:"):
                pf = ids[7:]
                ids = [it["id"] for it in items if str(it["id"]).startswith(pf)]
            # 一个 id 一件（行李箱两个大小不同，树各自一棵）；隔墙、前沿矮墙也各算一件
            specs.append((code, name, True, [("%s-%02d" % (code, n + 1), [byid[i]]) for n, i in enumerate(ids)]))
        for code, name, temp, insts in specs:
            outi = []
            for inst, its in insts:
                src = [it["id"] for it in its]
                for s in src:
                    used.add(s)
                bs = [self.box[s] for s in src if s in self.box]
                assert bs, "%s 一个框都没有" % inst
                u = union(bs)
                feet = sorted({item_foot(byid[s]) for s in src if item_foot(byid[s]) is not None})
                multi = feet if (feet and feet[-1] - feet[0] > 24 and "bench" not in src[0]) else None
                outi.append({"id": inst, "src": src, "box": u, "foot": ((u[0] + u[2]) / 2.0, u[3]), "sort_lines": multi})
            self.parts.append({"code": code, "name": name, "temp": temp, "inst": outi})
        for k, why in SKIP[self.key].items():
            assert k in byid, "SKIP 里的 %s 不在 layout 里了" % k
            used.add(k)
            self.skipped[k] = why
        left = [it["id"] for it in items if it["id"] not in used]
        assert not left, "layout 里这些东西没归到任何一件：%s" % left
        pal = make_palette(len(self.parts))
        for p, c in zip(self.parts, pal):
            p["color"] = c
        # ---- 背景 ----
        seen = set()
        for suf, name, idxs, basis in BG[self.key]:
            rects = []
            for i in idxs:
                f = self.flat[i]
                assert f.get("type") == "rect", "flat[%d] 不是矩形" % i
                rects.append((i, [float(v) for v in f["rect"]], hexc(f["color"])))
                seen.add(i)
            self.bgs.append({"code": "%s-BG01-%s" % (self.pre, suf), "name": name, "rects": rects, "box": union([r[1] for r in rects]), "basis": basis})
        if self.key == "backhall":
            for i in range(10, 34):
                seen.add(i)    # 厨房地砖线，归厨房
            seen.add(9)
            self.bgs.append({"code": "K-BG01", "name": "厨房整间（归 GPT，这里只画一块灰，不拆）", "rects": [(100, KITCHEN, (128, 128, 128))], "box": KITCHEN,
                             "basis": "flat[9] 厨房地面 1008～1536 × 226～684 加上面的后墙到 y 104；flat[10]～[33] 是厨房地砖线。GPT 的厨房图盖在这一块上面"})
        unused = [i for i, f in enumerate(self.flat) if i not in seen and f.get("type") == "rect"]
        assert not unused, "flat 里这些矩形没归到任何背景：%s" % unused
        # ---- 人 ----
        for n in L.get("npcs", []):
            if "lm" not in n:
                self.skipped[n["id"]] = "厨师（厨房，归 GPT）" if n["id"] == "cook" else "没有 LM 编号"
                continue
            size = float(n.get("size", 1.0))
            sit = bool(n.get("sit", False))
            h = SIT_H * size if sit else STAND_H * size
            x, y = float(n["x"]), float(n["y"])
            self.people.append({"id": n["id"], "who": n["who"], "lm": n["lm"], "x": x, "y": y, "face": n.get("face", "down"), "sit": sit, "size": size,
                                "kid": size < 0.9, "h": h, "box": [x - PERSON_W / 2.0, y - h, x + PERSON_W / 2.0, y]})
        # 编号唯一、颜色不撞
        cols = [p["color"] for p in self.parts] + list(PEOPLE_COL.values())
        bgc = {c for b in self.bgs for _, _, c in b["rects"]}
        assert len(set(cols)) == len(cols) and not (set(cols) & bgc), "色块颜色撞了"

    # ---- 画 ----
    def draw_blocks(self, labels, people=True):
        im = Image.new("RGB", (self.W, self.H), (0, 0, 0))
        g = ImageDraw.Draw(im)
        flat_items = sorted([(i, r, c) for b in self.bgs for i, r, c in b["rects"]], key=lambda t: t[0])
        for _, r, c in flat_items:
            g.rectangle([r[0], r[1], r[2] - 1, r[3] - 1], fill=c)
        allp = [(p, i) for p in self.parts for i in p["inst"]]
        for p, i in sorted(allp, key=lambda t: (t[1]["foot"][1], t[1]["box"][0])):
            x0, y0, x1, y1 = i["box"]
            g.rectangle([x0, y0, x1 - 1, y1 - 1], fill=p["color"])
        for q in sorted(self.people if people else [], key=lambda t: (t["y"], t["x"])):     # 人一律画在最上面，免得被亭子这种大框盖住看不见（人的前后在游戏里另排）
            self.draw_person(g, q)
        if not labels:
            return im
        ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        f9, f11, f13 = ImageFont.truetype(FONT, 9), ImageFont.truetype(FONT, 11), ImageFont.truetype(FONT, 13)
        placed = []

        def txt(xy, s, fnt, col=(255, 255, 255), anchor="mm"):
            bb = d.textbbox(xy, s, font=fnt, anchor=anchor)
            if bb[0] < 2 or bb[2] > self.W - 2:      # 别被画布边切掉
                xy = (xy[0] + (2 - bb[0] if bb[0] < 2 else self.W - 2 - bb[2]), xy[1])
                bb = d.textbbox(xy, s, font=fnt, anchor=anchor)
            k = 0
            while any(not (bb[2] < q[0] or bb[0] > q[2] or bb[3] < q[1] or bb[1] > q[3]) for q in placed) and k < 40:
                xy = (xy[0], xy[1] + 11)
                bb = d.textbbox(xy, s, font=fnt, anchor=anchor)
                k += 1
            placed.append(bb)
            d.text(xy, s, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=2, stroke_fill=(0, 0, 0, 255))

        for b in self.bgs:
            for _, r, _ in b["rects"]:
                if r[2] - r[0] > 30 and r[3] - r[1] > 12:
                    d.rectangle([r[0], r[1], r[2] - 1, r[3] - 1], outline=(0, 0, 0, 110), width=1)
        for p, i in allp:
            x0, y0, x1, y1 = i["box"]
            d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(0, 0, 0, 255), width=1)
        for q in self.people:
            x0, y0, x1, y1 = q["box"]
            d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(0, 0, 0, 255), width=1)
        # 零件编号
        for p, i in allp:
            x0, y0, x1, y1 = i["box"]
            cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
            short = i["id"].replace(self.pre + "-", "", 1)
            fx, fy = i["foot"]
            d.line([(fx - 5, fy), (fx + 5, fy)], fill=(0, 255, 255, 255), width=2)
            d.line([(fx, fy - 5), (fx, fy + 5)], fill=(0, 255, 255, 255), width=2)
            pt = short.split("-")
            if x1 - x0 >= 70:
                txt((cx, cy), short, f13)
            elif x1 - x0 >= 34:
                txt((cx, cy), short, f11)
            else:
                txt((cx, cy - 5), pt[0], f9)
                if len(pt) > 1:
                    txt((cx, cy + 5), "-".join(pt[1:]), f9)
        # 人
        for q in self.people:
            t = q["lm"].replace("LM-", "")
            if q["lm"] == "LM-GUEST":
                t = "GUEST"
            txt((q["x"], q["y"] + 8), t, f9, (255, 240, 120))
        # 背景名字
        for b in self.bgs:
            suf = b["code"].split("-BG01-")[-1] if "-BG01-" in b["code"] else "K"
            xy = LABEL_AT[self.key].get(suf)
            if xy is None:
                r = b["rects"][0][1]
                xy = ((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
            code = b["code"].replace(self.pre + "-", "", 1)
            txt(xy, code + " " + b["name"].split("（")[0], f11, (255, 255, 255))
        txt((self.W / 2, self.H - 14), "青十字 = 脚点（框下沿中点）  黑框 = 画出来的框  黄字 = 人（LM 编号）  图上省略前缀 %s-  %s %d×%d，1:1" % (self.pre, self.cn, self.W, self.H), f13)
        return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")

    @staticmethod
    def draw_person(g, q):
        x0, y0, x1, y1 = q["box"]
        cx = (x0 + x1) / 2.0
        col = PEOPLE_COL["kid"] if q["kid"] else (PEOPLE_COL["sit"] if q["sit"] else PEOPLE_COL["stand"])
        h = y1 - y0
        r = max(4.0, h * 0.16)
        g.ellipse([cx - r, y0, cx + r, y0 + 2 * r], fill=col)
        g.rounded_rectangle([cx - 13 * (0.7 if q["kid"] else 1.0), y0 + 2 * r + 1, cx + 13 * (0.7 if q["kid"] else 1.0), y1 - 1], radius=5, fill=col)

    # ---- 验 ----
    def verify(self, now, bgonly, ppl):
        W, H = self.W, self.H
        res = {}
        diff = ImageChops.difference(now, bgonly).convert("L").point(lambda v: 255 if v else 0)
        allp = [(p, i) for p in self.parts for i in p["inst"]]
        kit = Image.new("L", (W, H), 0)
        diff_all = diff
        if self.key == "backhall":
            ImageDraw.Draw(kit).rectangle([int(KITCHEN[0]), int(KITCHEN[1]), int(KITCHEN[2]) - 1, int(KITCHEN[3]) + 12], fill=255)
            diff = ImageChops.subtract(diff, kit)    # 框外多出多少：厨房那块的物件（灶台、锅这些，归 GPT）不算
        dec = Image.new("L", (W, H), 0)
        dg = ImageDraw.Draw(dec)
        for p, i in allp:
            b = i["box"]
            dg.rectangle([int(b[0]) - 1, int(b[1]) - 1, int(b[2]), int(b[3])], fill=255)
        outside = ImageChops.subtract(diff, dec)
        res["item_pixels"] = diff.histogram()[255]
        res["outside_boxes"] = outside.histogram()[255]
        res["outside_bbox"] = outside.getbbox()
        dev = []
        for p, i in allp:
            x0, y0, x1, y1 = [int(round(v)) for v in i["box"]]
            cx0, cy0, cx1, cy1 = max(0, x0), max(0, y0), min(W, x1), min(H, y1)    # 贴着画布边的（树）只量画布里那部分
            pad = 4
            rx0, ry0, rx1, ry1 = max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)
            crop = diff_all.crop((rx0, ry0, rx1, ry1)).copy()
            cd = ImageDraw.Draw(crop)
            for p2, i2 in allp:     # 别的零件框里的像素挖掉（只留跟自己框重叠的那一截）
                if i2 is i:
                    continue
                b = [int(round(v)) for v in i2["box"]]
                ix0, iy0, ix1, iy1 = max(b[0], x0), max(b[1], y0), min(b[2], x1), min(b[3], y1)
                if b[2] > rx0 and b[0] < rx1 and b[3] > ry0 and b[1] < ry1:
                    cd.rectangle([b[0] - rx0, b[1] - ry0, b[2] - rx0 - 1, b[3] - ry0 - 1], fill=0)
                    if ix1 > ix0 and iy1 > iy0:     # 跟自己重叠的那一块要还回来
                        sub = diff_all.crop((ix0, iy0, ix1, iy1))
                        crop.paste(sub, (ix0 - rx0, iy0 - ry0))
            bb = crop.getbbox()
            if bb is None:
                dev.append({"id": i["id"], "err": "框里什么都没画（跟背景一个颜色）"})
                continue
            m = [bb[0] + rx0, bb[1] + ry0, bb[2] + rx0, bb[3] + ry0]
            e = {"id": i["id"], "declared": [x0, y0, x1, y1], "measured": m}
            e["dev"] = [m[0] - cx0, m[1] - cy0, m[2] - cx1, m[3] - cy1]
            e["edge_on_canvas"] = [x0 >= 0, y0 >= 0, x1 <= W, y1 <= H]
            dev.append(e)
        res["parts_dev"] = dev
        # 背景矩形：按 flat 顺序自己画一遍，跟「只有地面」那张比（厨房整块不算）
        ref = Image.new("RGB", (W, H))
        g = ImageDraw.Draw(ref)
        for f in self.flat:
            if f.get("type") == "rect":
                x0, y0, x1, y1 = f["rect"]
                g.rectangle([x0, y0, x1 - 1, y1 - 1], fill=hexc(f["color"]))
        dd = ImageChops.difference(ref, bgonly.convert("RGB")).convert("L").point(lambda v: 255 if v > 0 else 0)
        if self.key == "backhall":
            dd = ImageChops.subtract(dd, kit)
        res["flat_diff_pixels"] = dd.histogram()[255]
        res["flat_diff_bbox"] = dd.getbbox()
        # 人：站得开的（旁边 40 像素内没有别人）量脚点和个头，拿「带人」对「没人」做差
        dp = ImageChops.difference(ppl, now).convert("L").point(lambda v: 255 if v > 8 else 0)
        pv = []
        allp = [(p, i) for p in self.parts for i in p["inst"]]
        for q in self.people:
            if any(o is not q and abs(o["x"] - q["x"]) < 26 and abs(o["y"] - q["y"]) < 100 for o in self.people):
                continue     # 身子左右 12 像素内有别人（上下叠着）：差出来的像素连着邻居，量不准
            if any(q["y"] < i["foot"][1] < q["y"] + 120 and i["box"][0] < q["box"][2] and i["box"][2] > q["box"][0] and i["box"][1] < q["y"] and i["box"][3] > q["box"][1] for _, i in allp):
                continue     # 脚压在前面东西的框里（果园摊子后面的农夫），露不全，量不准
            box = (int(q["x"] - 12), int(q["y"] - 100), int(q["x"] + 12), int(q["y"] + 14))     # 只量身子正中 24 宽一条（高和脚点不受左右邻居影响）
            bb = dp.crop(box).getbbox()
            if bb is None:
                continue
            pv.append({"id": q["id"], "lm": q["lm"], "sit": q["sit"], "size": q["size"], "foot": [q["x"], q["y"]], "meas_h": bb[3] - bb[1], "foot_dy": bb[3] + box[1] - int(q["y"]),
                       })
        res["people_meas"] = pv
        return res

    def count_on_picture(self, im):
        """色块图上每种零件数出几块（同色相连的算一块）；预期 = 同编号框里相碰的并成一串"""
        px = im.load()
        out = {}
        for p in self.parts:
            col = p["color"]
            xs0 = max(0, int(min(i["box"][0] for i in p["inst"])) - 2)
            xs1 = min(self.W, int(max(i["box"][2] for i in p["inst"])) + 2)
            ys0 = max(0, int(min(i["box"][1] for i in p["inst"])) - 2)
            ys1 = min(self.H, int(max(i["box"][3] for i in p["inst"])) + 2)
            seen = set()
            n = 0
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
            # 预期：框相碰（含相接）的并成一块；被别的零件盖断的不管
            bx = [[int(round(v)) for v in i["box"]] for i in p["inst"]]
            par = list(range(len(bx)))

            def find(a):
                while par[a] != a:
                    par[a] = par[par[a]]
                    a = par[a]
                return a

            for a in range(len(bx)):
                for b in range(a + 1, len(bx)):
                    A, B = bx[a], bx[b]
                    ox = min(A[2], B[2]) - max(A[0], B[0])
                    oy = min(A[3], B[3]) - max(A[1], B[1])
                    if (ox >= 0 and oy > 0) or (oy >= 0 and ox > 0):    # 重叠或者边挨边（4 连通）
                        par[find(a)] = find(b)
            exp = len({find(a) for a in range(len(bx))})
            out[p["code"]] = {"on_picture": n, "expected_clusters": exp, "listed": len(p["inst"])}
        return out

    def overlaps(self):
        """不同零件的框叠在一起多大（面积、两边各占多少），给 GPT 画的时候心里有数"""
        allp = [(p, i) for p in self.parts for i in p["inst"]]
        out = []
        for a in range(len(allp)):
            for b in range(a + 1, len(allp)):
                A, B = allp[a][1]["box"], allp[b][1]["box"]
                ox = min(A[2], B[2]) - max(A[0], B[0])
                oy = min(A[3], B[3]) - max(A[1], B[1])
                if ox > 0 and oy > 0:
                    out.append({"a": allp[a][1]["id"], "b": allp[b][1]["id"], "w": r1(ox), "h": r1(oy), "area": r1(ox * oy)})
        return out


def write_outputs(sc, out_dir, shots):
    os.makedirs(out_dir, exist_ok=True)
    cn = sc.cn
    clean = sc.draw_blocks(False)
    ann = sc.draw_blocks(True)
    clean.save(os.path.join(out_dir, "%s-色块.png" % cn))
    ann.save(os.path.join(out_dir, "%s-色块-标注.png" % cn))
    rep = {"scene": cn, "canvas": [sc.W, sc.H], "count": sc.count_on_picture(sc.draw_blocks(False, people=False)), "overlaps": sc.overlaps()}
    now = Image.open(os.path.join(shots, "%s-w1.png" % sc.key)).convert("RGB")
    bgo = Image.open(os.path.join(shots, "%s-w0.png" % sc.key)).convert("RGB")
    ppl = Image.open(os.path.join(shots, "%s-ppl.png" % sc.key)).convert("RGB")
    assert now.size == (sc.W, sc.H) == bgo.size == ppl.size, "截图大小不是画布大小"
    now.save(os.path.join(out_dir, "%s-现状.png" % cn))
    ppl.save(os.path.join(out_dir, "%s-现状-带人.png" % cn))
    rep["verify"] = sc.verify(now, bgo, ppl)
    json.dump(rep, open(os.path.join(out_dir, "%s-色块验收数.json" % cn), "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=list)
    # ---- json ----
    data = {"canvas": [sc.W, sc.H], "note": "x、y 是画出来的框左上角（整块画布 %d×%d 坐标，1:1，原点画布左上角）；脚点 = 框下沿中点；排前后的线 = 脚点 y（亭子等几条线的写在 sort_lines）；人的 x、y 是脚点，框宽 %d、高 站 84×size / 坐 50×size" % (sc.W, sc.H, PERSON_W),
            "source": ["assets/layered/scene_luoman_%s/layout.json" % {"backhall": "backhall", "lawn": "lawn", "lake": "lake", "orchard": "orchard"}[sc.key], "回执/零件规格/%s/%s-框.json" % (cn, cn), "docs/零件总表.md"],
            "parts": [], "background": [], "people": [], "not_listed": sc.skipped}
    for p in sc.parts:
        b0 = p["inst"][0]["box"]
        sizes = {(r1(i["box"][2] - i["box"][0]), r1(i["box"][3] - i["box"][1])) for i in p["inst"]}
        data["parts"].append({"code": p["code"], "name": p["name"], "temp_code": p["temp"], "count": len(p["inst"]), "size": list(sorted(sizes)[0]) if len(sizes) == 1 else None, "sizes": sorted(sizes),
                              "layer": "世界层（按脚点排前后）",
                              "instances": [{"id": i["id"], "src": i["src"], "x": r1(i["box"][0]), "y": r1(i["box"][1]), "w": r1(i["box"][2] - i["box"][0]), "h": r1(i["box"][3] - i["box"][1]),
                                             "foot": [r1(i["foot"][0]), r1(i["foot"][1])], "sort_y": r1(i["foot"][1]), "sort_lines": i["sort_lines"]} for i in p["inst"]]})
    for b in sc.bgs:
        x0, y0, x1, y1 = b["box"]
        data["background"].append({"id": b["code"], "name": b["name"], "layer": "背景层（最底下，不排前后）", "box": [r1(x0), r1(y0), r1(x1 - x0), r1(y1 - y0)], "rects": len(b["rects"]), "basis": b["basis"],
                                   "rect_list": [[r1(r[1][0]), r1(r[1][1]), r1(r[1][2] - r[1][0]), r1(r[1][3] - r[1][1])] for r in b["rects"]] if len(b["rects"]) <= 20 else None})
    for q in sc.people:
        data["people"].append({"lm": q["lm"], "id": q["id"], "who": q["who"], "foot": [r1(q["x"]), r1(q["y"])], "pose": "坐着" if q["sit"] else "站着", "face": q["face"], "size": q["size"],
                               "box": [r1(q["box"][0]), r1(q["box"][1]), r1(q["box"][2] - q["box"][0]), r1(q["h"])]})
    if sc.key == "lawn":
        data["code_placed"] = lawn_runtime()
    json.dump(data, open(os.path.join(out_dir, "%s-零件单.json" % cn), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    write_md(sc, out_dir, data, rep)
    return rep, data


def lawn_runtime():
    src = open(os.path.join(GODOT, "scripts", "lawn.gd"), encoding="utf-8").read()
    ball = re.search(r"const BALL_START := Vector2\((\d+), (\d+)\)", src)
    dog = re.search(r"const DOG_START := Vector2\((\d+), (\d+)\)", src)
    return {"note": "球（LW-P07）和喜多不在 layout.json，位置写在 scripts/lawn.gd（BALL_START、DOG_START），是代码画的占位、会动；色块图上不画",
            "ball_foot": [int(ball.group(1)), int(ball.group(2))], "dog_foot": [int(dog.group(1)), int(dog.group(2))]}


NOTES = {
    # 草坪
    "LW-P01": "仪式台一整组：大树（带树干）、白纱幔、圆台、台上的花；一起拆成一件。树冠顶在画布上边缘（y 8）",
    "LW-P03": "观礼白椅子：椅背朝北（背对镜头坐的人面朝仪式台）；48 把一个样",
    "LW-P04": "通道矮花丛：一丛一丛，沿通道两边",
    "LW-T01": "甜品台：白桌布、蛋糕、杯子塔",
    "LW-P05": "秋千：两根立柱、横梁、两根绳、座板，一起拆成一件",
    "LW-P06": "滑梯：爬梯塔 + 斜滑道，一起拆成一件；滑道尾巴贴着沙地东边",
    "LW-P08": "草坪四周的树，整棵（树冠加树干），树冠在人前面画；北边一排、西边三棵、东边四棵、南边一排；贴着画布边的树有一截在画布外，画整棵",
    # 湖边
    "LK-P01": "亭子：顶 + 四根柱子；**排前后有几条线**（顶 438、后两根柱 450、前两根柱 646），一整张图排不出「人站亭子里被顶盖住、又在前柱后面」，见回执",
    "LK-P02": "垂柳：整棵（树冠、树干、垂下来的枝条）",
    "LK-P03": "长凳：凳面、两条腿、靠背",
    "LK-P04": "手划小木船：只画船，船夫另算",
    "LK-P05": "脚踏游船：天鹅形，只画船",
    "LK-P06": "小码头：木平台、木桩、板缝；伸进湖里",
    "LK-P07": "钓鱼的地方一组：小凳 + 鱼竿（连鱼线）+ 鱼桶；钓鱼的人另算",
    "LK-P08": "荷叶荷花一丛：浮在水上，一丛一件",
    "LK-P09": "芦苇一丛",
    "LK-P10": "一对鸭子：两只算一件（游戏里两只连着摆）",
    # 果园
    "OR-P01": "草莓垄一段：8 垄，一垄一件，600 宽（总表写一段 96 宽、能左右接长，这里一垄一整条）",
    "OR-P02": "枇杷树：6 棵；有果、没果两态（果子在游戏里按季节出，灰盒里是小点）",
    "OR-P03": "山庄收购处摊子：小木棚、秤、几筐果；招牌空着",
    "OR-P04": "一筐草莓", "OR-P05": "一篮枇杷", "OR-P06": "稻草人：竖杆、横杆、衣服、草帽，一起拆成一件",
    "OR-W01": "竹篱笆：16 段一段 96 宽，首尾相接铺满田埂北边，能左右接长",
    "OR-P07": "板车",
    # 后厅
    "BH-T01": "化妆台连镜子：桌面、镜子、灯泡一圈（框 58×77）",
    "BH-P01": "礼服架：两根立杆、横杆、底座，三件礼服挂着，一起拆成一件",
    "BH-P02": "换衣屏风", "BH-P03": "化妆凳", "BH-P04": "落地全身镜", "BH-P05": "三人沙发：靠背 + 坐垫，一起拆成一件；正面朝南",
    "BH-P06": "单人沙发", "BH-T02": "茶几连茶具", "BH-P07": "电视柜连电视：侧着朝西放，屏幕不画画面",
    "BH-P08": "黑胶唱片墙：一格一张方形封套，封套不画字；有八张正面朝外、露出一截黑唱片", "BH-P09": "唱片机：连小柜、带大喇叭",
    "BH-P10": "落地灯", "BH-P11": "绿植一盆", "BH-T03": "麻将桌：自动麻将机；**麻将室先只留氛围（阿鱼 10/3），不画牌面、桌面不摆牌**；3 张，各自带一圈 4 把椅子（椅子另算 BH-P12）",
    "BH-P12": "麻将椅：12 把，每桌四面各一把", "BH-T04": "小茶几连盖碗茶",
    "BH-W01": "隔墙：房间之间的墙，10 厚、从后墙一直到前沿，三道",
    "BH-W02": "前沿矮墙：房间和走廊之间，每段之间留门口（128～208、464～544、800～880、1136～1216）",
    "BH-P13": "行李箱：两个，一大一小，大的在休息间西头靠唱片墙、小的在休息间东南角",
}


def write_md(sc, out_dir, data, rep):
    cn, pre = sc.cn, sc.pre
    v = rep["verify"]
    L = ["# %s · 色块备料 · 零件单（给 GPT 照着画、照着拆；**现在不给 GPT**，等 01 拿色块给阿鱼看、阿鱼点头）" % cn, "",
         "> 03，2026-10-03，01 E 派。**标准答案**：位置、大小和游戏里一模一样，一整块 **%d×%d**，1:1，原点是画布左上角（不分块、不缩放）。" % (sc.W, sc.H),
         "> 数从唯一源 `assets/layered/scene_luoman_%s/layout.json`、`回执/零件规格/%s/%s-框.json`（`gen_specs_court.py` 出）和 `docs/零件总表.md` 来，不另算、不手抄。脚本 `godot/tools/layout_court/export_booths_for_gpt.py`。" % (sc.key, cn, cn),
         "> 图在同一个文件夹：`%s-色块.png`（标准答案，不写字）、`%s-色块-标注.png`（写了编号、脚点）、`%s-现状.png`（游戏现在这块的样子：灰盒，没人没界面没字）、`%s-现状-带人.png`（带占位的人）。" % (cn, cn, cn, cn), "",
         "**看这几条再动手**", "",
         "- 色块图上每件东西画成它**画出来的框**（矩形，连高度），不是地上的占地；现在游戏里全是灰盒占位，GPT 照框画成正式画面。",
         "- **脚点** = 这件东西落在地上那条线的下沿中点，游戏里按它排谁挡谁。一律取框下沿正中。",
         "- **背景是整张画的**（地面、水、路、后墙、地板），**零件是拆出来的**（透明底，游戏里按脚点排前后）。**人物不画进零件**：人单独出（LM 编号，见下面「人」），色块图上画成人形占位（白 = 站着的大人，淡青 = 坐着，淡黄 = 小孩）。",
         "- 一种东西一个颜色；零件框和背景框、零件框和零件框会重叠，色块图按脚点 y 小的先画（人一律画在最上面，免得被大框盖住）。",
         "- 图里不写字、不画招牌；「化妆室」「去果园」那些字是游戏自己写的，不画。", ""]
    if cn == "后厅":
        L += ["- **东头厨房（x 1008～1536）归 GPT**（K-BG01），色块图上画成一块灰、不拆；灶台、大锅、案板、碗桌、厨师都不在这份单子里。", ""]
    L += ["## 一、零件（要拆）", "", "| 编号 | 名字 | 画出来多大 w×h | 这张图里几件 | 层 | 说明 |", "| --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"]:
        sz = "%d×%d" % tuple(p["size"]) if p["size"] else "、".join("%d×%d" % s for s in p["sizes"][:4]) + ("…" if len(p["sizes"]) > 4 else "")
        mark = "（临时编号）" if p["temp_code"] else ""
        L.append("| %s | %s%s | %s | %d | 世界层，按脚点排前后 | %s |" % (p["code"], p["name"], mark, sz, p["count"], NOTES.get(p["code"], "")))
    L += ["", "合计 **%d 种、%d 件**零件。" % (len(data["parts"]), sum(p["count"] for p in data["parts"])), ""]
    temps = [p for p in data["parts"] if p["temp_code"]]
    if temps:
        L += ["> 「临时编号」= `docs/零件总表.md` 里没有这件，我临时起的（%s），**要不要进总表等 01 定**。" % "、".join("%s %s" % (p["code"], p["name"].split("（")[0]) for p in temps), ""]
    L += ["### 每件的位置（整块画布坐标；x、y 是框左上角；脚点 = 框下沿中点；排前后的线 = 脚点 y）", "",
          "| 编号 | 名字 | x | y | 宽×高 | 脚点 (x, y) | 排前后的线 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"]:
        for i in p["instances"]:
            line = str(i["sort_y"]) if not i["sort_lines"] else "%d（游戏里分几条：%s）" % (i["sort_y"], "、".join(str(int(t)) for t in i["sort_lines"]))
            L.append("| %s | %s | %d | %d | %d×%d | (%d, %d) | %s |" % (i["id"], p["name"].split("（")[0], i["x"], i["y"], i["w"], i["h"], i["foot"][0], i["foot"][1], line))
    L += ["", "## 二、背景（不拆，整张画）", "",
          "> 总表里还没有 %s 背景的编号；`%s-BG01-a…` 都是我临时起的（照迎宾院 `CT-BG01` 的做法），只为对照，**要不要进零件总表等 01 定**。" % (cn, pre), "",
          "| 编号 | 名字 | 框 x, y, 宽×高 | 几块矩形 | 层 | 依据 |", "| --- | --- | --- | --- | --- | --- |"]
    for b in data["background"]:
        L.append("| %s | %s | %d, %d, %d×%d | %d | 背景层 | %s |" % (b["id"], b["name"], b["box"][0], b["box"][1], b["box"][2], b["box"][3], b["rects"], b["basis"]))
    L += ["", "## 三、人（单独出，不画进零件；这里只标位置）", "",
          "> 站着的人 84 高（小孩 × size，0.63 → 53），坐着的游戏只画上半身（大人约 50）；脚点是 (x, y)，框宽 %d。色块图上的人形只是占位。**LM-GUEST** 没有固定编号（观礼客人、麻将桌宾客，几种宾客形象轮着用）。" % PERSON_W, "",
          "| LM 编号 | 谁 | 脚点 (x, y) | 站/坐 | 朝向 | 框 x, y, 宽×高 |", "| --- | --- | --- | --- | --- | --- |"]
    for q in data["people"]:
        L.append("| %s | %s | (%d, %d) | %s | %s | %d, %d, %d×%d |" % (q["lm"], q["who"], q["foot"][0], q["foot"][1], q["pose"], q["face"], q["box"][0], q["box"][1], q["box"][2], q["box"][3]))
    L += ["", "合计 **%d 位**（不含不在这份单子里的）。" % len(data["people"]), ""]
    if sc.skipped:
        L += ["## 四、不在这份零件单里的", "", "| layout 里的 id | 为什么不列 |", "| --- | --- |"]
        for k, why in sc.skipped.items():
            L.append("| %s | %s |" % (k, why))
        L.append("")
    if sc.key == "lawn":
        c = data["code_placed"]
        L += ["## 五、球和喜多（代码里写死的位置）", "", "- 足球 LW-P07：脚点 (%d, %d)；喜多：(%d, %d)。%s" % (c["ball_foot"][0], c["ball_foot"][1], c["dog_foot"][0], c["dog_foot"][1], c["note"]), ""]
    # ---- 验收（量出来的数，原始在 色块验收数.json）----
    parts_dev = v["parts_dev"]
    bad = []
    for x in parts_dev:
        if "err" in x:
            bad.append("%s：%s" % (x["id"], x["err"]))
            continue
        dv = [t if on else 0 for t, on in zip(x["dev"], x["edge_on_canvas"])]
        if any(t != 0 for t in dv):
            bad.append("%s 左上右下差 %s" % (x["id"], dv))
    pm = v["people_meas"]
    L += ["## %s、验收（03 量的；原始数在 `%s-色块验收数.json`）" % ("六" if sc.key == "lawn" else "五", cn), "",
          "- **背景矩形**：照 layout 的 flat 一块块自己画一遍，跟游戏「只有地面」那张差 **%d 像素**（0 = 一模一样；后厅厨房那块是 GPT 的图，不算）。" % v["flat_diff_pixels"],
          "- **物件**：「现状」跟「只有地面」做差就是世界层里的物件，共 %d 像素，**落在所有零件框外面的 %d 像素**。" % (v["item_pixels"], v["outside_boxes"]),
          "- **零件框对现状**（容差 0）：%d 件里 **%d 件四边全是 0 像素**；其余 %d 件见下（原因逐条写在回执里）：" % (len(parts_dev), len(parts_dev) - len(bad), len(bad))]
    L += ["  - " + b for b in bad] if bad else ["  - （没有）"]
    L += ["- **色块图上数一数**：同色相连算一块：%s。" % ("每种零件的块数都跟零件单一样" if all(c["on_picture"] == c["expected_clusters"] for c in rep["count"].values()) else
                                          "、".join("%s 数出 %d 块（零件单 %d 件，框相碰并成 %d 串，被别的零件框盖住分开了）" % (k, c["on_picture"], c["listed"], c["expected_clusters"]) for k, c in rep["count"].items() if c["on_picture"] != c["expected_clusters"])),
          "- **框叠框**：不同零件的框叠在一起 %d 对（画出来的框连高度，叠了不奇怪），原始在 json 的 `overlaps`（只在 `色块验收数.json` 里）。" % len(rep["overlaps"])]
    if pm:
        st = [m for m in pm if not m["sit"]]
        sitm = [m for m in pm if m["sit"]]
        L += ["- **人**：站得开的 %d 位量了脚点（现状带人 对 不带人 做差）：脚点上下差 ≤%d 像素；站着的大人量到 %s 高（色块框 84）；坐着的量到 %s 高（色块框 50）。" % (
            len(pm), max(abs(m["foot_dy"]) for m in pm), "、".join(sorted({str(m["meas_h"]) for m in st if m["size"] >= 0.9}, key=int)) or "—", "、".join(sorted({str(m["meas_h"]) for m in sitm if m["size"] >= 0.9}, key=int)) or "—")]
    L.append("")
    open(os.path.join(out_dir, "%s-零件单.md" % cn), "w", encoding="utf-8").write("\n".join(L))


def summarize(sc, rep, data):
    v = rep["verify"]
    bad_cnt = {k: c for k, c in rep["count"].items() if c["on_picture"] != c["expected_clusters"]}
    print("== %s：零件 %d 种 %d 件、背景 %d 块、人 %d 位" % (sc.cn, len(sc.parts), sum(len(p["inst"]) for p in sc.parts), len(sc.bgs), len(sc.people)))
    print("  色块图上数 vs 预期：%s" % ("全对" if not bad_cnt else bad_cnt))
    print("  物件像素 %d，框外多出 %d 个 %s；背景矩形自己画 vs 只有地面 差 %d 像素 %s" % (v["item_pixels"], v["outside_boxes"], v["outside_bbox"], v["flat_diff_pixels"], v["flat_diff_bbox"]))
    nz = []
    for x in v["parts_dev"]:
        if "err" in x:
            nz.append((x["id"], x["err"]))
            continue
        d = [t for t, on in zip(x["dev"], x["edge_on_canvas"]) if on]
        if any(t != 0 for t in d):
            nz.append((x["id"], x["dev"]))
    print("  零件框对现状：%d 件，有偏差的 %d 件" % (len(v["parts_dev"]), len(nz)))
    for t in nz[:60]:
        print("    ", t)
    print("  框叠框 %d 对" % len(rep["overlaps"]))


def main():
    argv = sys.argv[1:]
    opts = {"--scene": None, "--shots": None, "--out": None}
    for k in opts:
        if k in argv:
            i = argv.index(k)
            opts[k] = argv[i + 1]
            del argv[i:i + 2]
    if not opts["--shots"]:
        raise SystemExit("要 --shots <截图目录>")
    keys = [opts["--scene"]] if opts["--scene"] else list(SCENES)
    for k in keys:
        sc = Scene(k)
        out = os.path.join(opts["--out"], sc.cn) if opts["--out"] else os.path.join(GODOT, "回执", "零件规格", sc.cn)
        rep, data = write_outputs(sc, out, opts["--shots"])
        summarize(sc, rep, data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
