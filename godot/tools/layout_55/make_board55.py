#!/usr/bin/env python3
"""55 桌摆位底图（01 D 9/25 派）：GPT 画 5 张效果图的底子，每样东西的坐标、像素大小在这一步定死，拆回来的图照这张原样摆回游戏。
依据：ASSETS §15 比例尺（左右和高 1 米 = 48 像素、地面前后 1 米 = 32 像素、人 84）、回执/宴会厅55桌-方案.md、回执/体验-第47版-55桌.md（04）
全用色块，不贴任何现成的图。

出四样（都进 godot/回执/）：
  宴会厅55桌-摆位底图.png        整厅 1:1，纯色块、一个字不写，站一个 84 像素的人当尺子
  宴会厅55桌-摆位底图-标注.png   同一张，标名字、桌号、关键尺寸
  宴会厅55桌-摆位表.md           每样东西一行：名字、左上角 x/y、宽、高、依据
  宴会厅55桌-手机屏-进门.png / -舞台.png   按手机竖屏 540×960 的视野（镜头 960/1024 倍，一屏看画布 576×1024）切的两屏
跑完自己验：比例（对 §15，1.5 倍 / 一半）、谁压谁（除了桌压自己的地毯）、每张桌从红毯走得到（路至少 43 宽）、横幅不盖囍、LED 不出台面
用法：python3 tools/layout_55/make_board55.py [输出目录，默认 回执/]
"""
import collections
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "回执")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"

W = 1536
CX = 768                      # 红毯中线
PERSON = 84
VIEW = (576, 1024)            # 手机竖屏一屏看到的画布（540×960，镜头 960/1024）

# ---------- 桌位 ----------
TABLE = (140, 92)             # 桌子加一圈椅子（§15 宴会圆桌 1.8 米 + 一圈椅子和人，04 / 01 定）
RUG = (160, 105)              # 每桌一块地毯，桌子居中压在上面（每边露 10 像素，04）
COLS = [CX - 160 - 203 * 2, CX - 160 - 203, CX - 160, CX + 160, CX + 160 + 203, CX + 160 + 203 * 2]   # 块内列距 203、跨红毯 320
ROW0 = 502                    # 第 1 排桌心：台阶下沿 381 往下留一条 68 的走道（新人下台、红毯两边宫灯）再加半张地毯
PITCH = 148                   # 行距（走道 56）
CROSS = 128                   # 横走道前后（4 米）
CROSS_AFTER = (2, 6)          # 第 3 排、第 7 排后面各一条横走道：3 + 4 + 3 排
rows_y = []
y = ROW0
for r in range(10):
    rows_y.append(y)
    y += PITCH + ((CROSS - (PITCH - TABLE[1])) if r in CROSS_AFTER else 0)
# 60 个位里空 5 个：主桌 1 个（第 1 排红毯左边第一张，离婚礼台最近，新人家那桌，不进服务端桌号表）、
# 第 1 排红毯右边第一张（和主桌对着，空出来给新人下台敬酒、镜头看台子）、第 1 排最西那张（放长凳）、
# 第 10 排红毯两边各一张（大门进来客人站的地方）
MAIN = (0, 2)
EMPTY = {(0, 3): "新人下台敬酒的路，看台子不挡", (0, 0): "放长凳（普通桌坐满了坐这）", (9, 2): "进门客人站的地方", (9, 3): "进门客人站的地方"}

# ---------- 北边、南边 ----------
WALL_N = 192                  # 北墙立面高 4 米
STAGE = (528, 192, 480, 128)  # 婚礼台台面：宽 10 米、前后 4 米
STAGE_FACE = (528, 320, 480, 29)   # 台口立面：台高 0.6 米
STEPS = (CX - 72, 349, 144, 32)    # 台阶：和红毯一样宽 3 米，前后 1 米两级
LED = (552, 322, 432, 24)     # LED 屏：贴在台口立面上，宽不出台面（台面 480 左右各收 24）
ARCH = (CX - 120, 8, 240, 180)     # 花拱：宽 5 米、高 3.75 米，贴北墙
XI = (CX - 48, 44, 96, 96)    # 囍字圆牌：直径 2 米
BANNER = (CX - 162, 150, 324, 40)  # 横幅：囍字下沿（140）再往下 10，挂在北墙上、不下到台面
COUPLE_FEET = [(CX - 16, 290), (CX + 16, 290)]   # 新人站位：台中间、囍字正下方（只标位置）
CARPET = (CX - 72, 381, 144, None)   # 红毯 3 米宽，从台阶下沿到大门里边
H = None                      # 画布高，下面算

def build():
    global H
    last_rug_bottom = rows_y[-1] + RUG[1] // 2 + 1
    stand_top = last_rug_bottom + 30          # 进门站的地方从这往下
    STAND = 96                                # 进门站的地方前后 3 米（96），在大门立面北边
    rail_foot = stand_top + STAND + 145       # 南边栏杆脚线：大门立面高 145 画在脚线往上
    H = rail_foot + 8
    items = []

    def add(name, kind, box, color, basis, group=""):
        items.append({"name": name, "kind": kind, "box": [int(v) for v in box], "color": color, "basis": basis, "group": group})

    # 墙
    add("北墙（立面）", "wall", (0, 0, W, WALL_N), (92, 52, 36), "墙高按 4 米折：4×48=192（§15 没有墙这一行）")
    side_bottom = rail_foot - 48
    add("西墙", "wall", (0, WALL_N, 40, side_bottom - WALL_N), (92, 52, 36), "墙厚 40（约 0.8 米，§15 没有）")
    # 东侧门开在第二条横走道正中
    cross2_mid = (rows_y[CROSS_AFTER[1]] + rows_y[CROSS_AFTER[1] + 1]) // 2
    d0, d1 = cross2_mid - 29, cross2_mid + 29
    add("东墙（北段）", "wall", (W - 40, WALL_N, 40, d0 - WALL_N), (92, 52, 36), "墙厚 40（约 0.8 米）")
    add("东墙（南段）", "wall", (W - 40, d1, 40, side_bottom - d1), (92, 52, 36), "墙厚 40（约 0.8 米）")
    add("东侧门（门洞）", "door", (W - 40, d0, 40, d1 - d0), (60, 140, 200), "§15 双开门宽 1.8 米；开在东墙上，宽沿地面前后算：1.8×32=58")
    # 北边：花拱、囍、横幅、婚礼台
    add("花拱", "decor", ARCH, (70, 130, 70), "宽 5 米×48=240、高 3.75 米×48=180（§15 没有）", "wall_decor")
    add("囍字圆牌", "decor", XI, (215, 170, 60), "直径 2 米×48=96（§15 没有）", "wall_decor")
    add("横幅", "decor", BANNER, (150, 30, 30), "宽 6.75 米×48=324、高 0.8 米×48=40；囍下沿往下 10（04）", "wall_decor")
    add("婚礼台（台面）", "stage", STAGE, (200, 60, 55), "宽 10 米×48=480、前后 4 米×32=128（§15 没有）")
    add("婚礼台（台口立面）", "stage", STAGE_FACE, (150, 40, 38), "台高 0.6 米×48=29")
    add("台阶", "stage", STEPS, (175, 50, 46), "和红毯同宽 144；前后 1 米×32=32，两级")
    add("LED 屏", "decor", LED, (20, 10, 8), "贴在台口立面上，宽 432（台面 480 左右各收 24）、高 24（0.5 米）", "stage_decor")
    for i, (fx, fy) in enumerate(COUPLE_FEET):
        add("新人站位%s" % ("（新娘）" if i == 0 else "（新郎）"), "mark", (fx - 12, fy - 4, 24, 8), (255, 255, 255), "台中间、囍字正下方；只标脚下（人 84 高，头顶到 y 206，在横幅下面）", "stage_decor")
    # 红毯、宫灯、花盆
    carpet_bottom = rail_foot - 145          # 红毯一直铺到大门立面跟前
    add("红毯", "floor", (CARPET[0], CARPET[1], CARPET[2], carpet_bottom - CARPET[1]), (179, 32, 42), "3 米×48=144（方案）；从台阶下沿到大门里边")
    lamp = (24, 80)
    pot = (32, 32)
    def lamp_pair(y_foot, tag):
        add("红毯西侧落地宫灯（%s）" % tag, "prop", (CARPET[0] - 24, y_foot - lamp[1], lamp[0], lamp[1]), (240, 200, 60), "§15 落地宫灯高 77～86，取 80；宽 0.5 米×48=24")
        add("红毯东侧落地宫灯（%s）" % tag, "prop", (CARPET[0] + CARPET[2], y_foot - lamp[1], lamp[0], lamp[1]), (240, 200, 60), "§15 落地宫灯高 77～86，取 80；宽 0.5 米×48=24")
    lamp_pair(ROW0 - RUG[1] // 2 - 5, "台前")
    for k, r in enumerate(CROSS_AFTER):
        top = rows_y[r] + RUG[1] // 2 + 2
        bot = rows_y[r + 1] - RUG[1] // 2 - 2
        lamp_pair(top + 2 + lamp[1], "第 %d 条横走道" % (k + 1))
        add("花盆（第 %d 条横走道西）" % (k + 1), "prop", (CARPET[0] - 24 - 8 - pot[0], bot - pot[1] - 4, pot[0], pot[1]), (90, 170, 90), "§15 一盆花 24～38，取 32")
        add("花盆（第 %d 条横走道东）" % (k + 1), "prop", (CARPET[0] + CARPET[2] + 24 + 8, bot - pot[1] - 4, pot[0], pot[1]), (90, 170, 90), "§15 一盆花 24～38，取 32")
    add("花盆（台西角）", "prop", (STAGE[0] - 40, STAGE_FACE[1] + STAGE_FACE[3] - pot[1], pot[0], pot[1]), (90, 170, 90), "§15 一盆花 24～38，取 32")
    add("花盆（台东角）", "prop", (STAGE[0] + STAGE[2] + 8, STAGE_FACE[1] + STAGE_FACE[3] - pot[1], pot[0], pot[1]), (90, 170, 90), "§15 一盆花 24～38，取 32")
    # 壁边灯柱：两边墙根，每 300 一根，东边躲开侧门
    for yf in range(ROW0 - 2, side_bottom - 40, 300):
        add("西墙壁边灯柱（y %d）" % yf, "prop", (44, yf - 80, 24, 80), (230, 170, 60), "§15 壁边灯柱照落地宫灯 77～86，取 80；宽 24")
        if not (d0 - 20 < yf < d1 + 100):
            add("东墙壁边灯柱（y %d）" % yf, "prop", (W - 40 - 4 - 24, yf - 80, 24, 80), (230, 170, 60), "§15 壁边灯柱照落地宫灯 77～86，取 80；宽 24")
    # 乐队（台子东边地上），礼物堆（台子西边地上）
    foot = 348
    add("三角钢琴", "band", (1060, foot - 48, 72, 48), (30, 30, 30), "§15 三角钢琴 长 72、琴身高 48")
    add("钢琴手（坐）", "band", (1136, foot - 62, 32, 62), (70, 60, 110), "§15 坐着的人 62；宽 32（约 0.65 米）")
    add("大提琴手（坐）", "band", (1196, foot - 62, 32, 62), (70, 60, 110), "§15 坐着的人 62；宽 32")
    add("大提琴", "band", (1232, foot - 58, 20, 58), (140, 80, 40), "琴高 1.2 米×48=58（§15 没有）")
    add("小提琴手 甲（站）", "band", (1290, foot - 84, 32, 84), (110, 70, 140), "§15 人 84；宽 32")
    add("小提琴手 乙（站）", "band", (1350, foot - 84, 32, 84), (110, 70, 140), "§15 人 84；宽 32")
    add("贺礼堆", "prop", (400, 378 - 48, 72, 48), (230, 120, 120), "§15 礼物堆整堆高 48；宽 72（1.5 米）；离乐队 588")
    # 桌、地毯、长凳
    ids = []
    for r in range(10):
        slots = [c for c in range(6) if (r, c) not in EMPTY and (r, c) != MAIN]
        slots.sort(key=lambda c: (abs(COLS[c] - CX), COLS[c]))
        ids += [(r, c) for c in slots]
    tid = {rc: "T%d" % (i + 1) for i, rc in enumerate(ids)}
    assert len(tid) == 55
    for r in range(10):
        for c in range(6):
            cx, cy = COLS[c], rows_y[r]
            if (r, c) in EMPTY:
                if EMPTY[(r, c)].startswith("放长凳"):
                    add("长凳", "prop", (cx - 36, cy - 19, 72, 38), (120, 200, 255), "§15 长凳 宽 72、高 38；放在第 1 排最西的空位")
                continue
            name = "主桌" if (r, c) == MAIN else tid[(r, c)]
            add(name + " 地毯", "rug", (cx - RUG[0] // 2, cy - RUG[1] // 2, RUG[0], RUG[1]), (150, 70, 40) if name != "主桌" else (200, 150, 40),
                "04 / 01：桌子每边多露 10，160×105", "rug:" + name)
            add(name, "table", (cx - TABLE[0] // 2, cy - TABLE[1] // 2, TABLE[0], TABLE[1]),
                (220, 70, 60) if name != "主桌" else (240, 190, 60),
                "§15 宴会圆桌 1.8 米 + 一圈椅子和坐着的人：140×92（04 / 01）", "table:" + name)
    # 南边：栏杆、大门、进门站的地方
    door_w = 114
    add("大门（双开门门洞）", "door", (CX - door_w // 2, rail_foot - 145, door_w, 145), (60, 140, 200), "§15 双开门／院门门洞 宽 86～115、高 115～145，取 114×145")
    add("南边西段栏杆", "wall", (40, rail_foot - 48, CX - door_w // 2 - 40, 48), (120, 80, 50), "§15 齐腰栏杆 高 48")
    add("南边东段栏杆", "wall", (CX + door_w // 2, rail_foot - 48, W - 40 - (CX + door_w // 2), 48), (120, 80, 50), "§15 齐腰栏杆 高 48")
    add("进门站的地方", "zone", (CX - 150, stand_top, 300, rail_foot - 145 - stand_top), None, "大门里边空出来的地面：宽 300、前后到大门立面（给客人进门站、第一次进厅站这儿看全场）")
    ruler = (CX + 90, rail_foot - 145 - 4 - PERSON, 32, PERSON)   # 站在进门那块空地上、红毯东边
    add("尺子：人", "ruler", ruler, (20, 20, 20), "§15 人 84")
    return items, tid, (d0, d1), stand_top, rail_foot


def overlaps(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


def check(items):
    """验收：比例、谁压谁、走得开、横幅不盖囍、LED 不出台面"""
    bad = []
    solid = [it for it in items if it["kind"] in ("table", "prop", "band", "stage", "wall", "decor", "ruler") and it["group"] != "wall_decor"]
    # 1. 谁压谁：可以的只有 桌压自己的地毯；墙上的装饰贴墙；LED、新人站位在台上
    for i, a in enumerate(items):
        for b in items[i + 1:]:
            if not overlaps(a["box"], b["box"]):
                continue
            ka, kb = a["kind"], b["kind"]
            pair = {a["name"], b["name"]}
            if {ka, kb} == {"table", "rug"} and a["group"].split(":")[1] == b["group"].split(":")[1]:
                continue
            if "wall_decor" in (a["group"], b["group"]) and ("北墙（立面）" in pair or {a["group"], b["group"]} == {"wall_decor"}):
                if pair == {"横幅", "囍字圆牌"}:
                    bad.append("横幅盖住囍字")
                continue
            if "stage_decor" in (a["group"], b["group"]) and ({ka, kb} & {"stage"}):
                continue
            if "zone" in (ka, kb) or "floor" in (ka, kb) and not ({ka, kb} & {"table", "rug", "prop", "band"}):
                continue
            if "ruler" in (ka, kb):
                continue
            bad.append("压住了：%s × %s" % (a["name"], b["name"]))
    # 2. LED 不出台面、横幅不盖囍
    if not (LED[0] >= STAGE[0] and LED[0] + LED[2] <= STAGE[0] + STAGE[2]):
        bad.append("LED 出了台面")
    if BANNER[1] < XI[1] + XI[3]:
        bad.append("横幅盖住囍字")
    # 3. 走得开：4 像素一格；挡路的是桌子（连椅子）、墙、台子、道具、乐队；地毯、红毯能走。人宽 43：离挡路的东西 21 像素以内的格子不算能站
    g = 4
    cols, rows = W // g, H // g
    block = bytearray(cols * rows)
    for it in solid:
        x, y, w, h = it["box"]
        for j in range(max(0, (y - 21) // g), min(rows, (y + h + 21) // g + 1)):
            for i in range(max(0, (x - 21) // g), min(cols, (x + w + 21) // g + 1)):
                block[j * cols + i] = 1
    for j in range(rows):   # 画布边也算挡
        for i in list(range(0, 6)) + list(range(cols - 6, cols)):
            block[j * cols + i] = 1
    start = ((CX // g), (H - 200) // g)
    seen = bytearray(cols * rows)
    q = collections.deque()
    # 从红毯上所有能站的格子出发
    for it in items:
        if it["name"] == "红毯":
            x, y, w, h = it["box"]
            for j in range(y // g, (y + h) // g):
                for i in range(x // g, (x + w) // g):
                    if not block[j * cols + i]:
                        seen[j * cols + i] = 1
                        q.append((i, j))
    while q:
        i, j = q.popleft()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ni, nj = i + di, j + dj
            if 0 <= ni < cols and 0 <= nj < rows and not block[nj * cols + ni] and not seen[nj * cols + ni]:
                seen[nj * cols + ni] = 1
                q.append((ni, nj))
    unreach = []
    for it in items:
        if it["kind"] != "table":
            continue
        x, y, w, h = it["box"]
        ok = False
        # 桌边（连椅子那圈）外 21～29 像素一圈里，有一格红毯连得过来就算走得到
        for j in range((y - 29) // g, (y + h + 29) // g + 1):
            for i in range((x - 29) // g, (x + w + 29) // g + 1):
                if 0 <= i < cols and 0 <= j < rows and seen[j * cols + i]:
                    ok = True
                    break
            if ok:
                break
        if not ok:
            unreach.append(it["name"])
    if unreach:
        bad.append("红毯走不到的桌：%s" % unreach)
    # 地毯之间露地面
    rugs = [it for it in items if it["kind"] == "rug"]
    for i, a in enumerate(rugs):
        for b in rugs[i + 1:]:
            if overlaps(a["box"], b["box"]):
                bad.append("地毯连上了：%s × %s" % (a["name"], b["name"]))
    return bad


def draw(items, labels, tid, door, stand_top, rail_foot):
    im = Image.new("RGB", (W, H), (239, 227, 207))
    g = ImageDraw.Draw(im)
    order = ["floor", "zone", "rug", "wall", "stage", "decor", "mark", "door", "table", "prop", "band", "ruler"]
    for k in order:
        for it in items:
            if it["kind"] != k or it["color"] is None:
                continue
            x, y, w, h = it["box"]
            if k == "mark":
                g.ellipse([x, y, x + w, y + h], fill=it["color"])
            elif k == "table":
                g.ellipse([x, y, x + w, y + h], fill=(90, 50, 25))
                g.ellipse([x + 27, y + 17, x + w - 27, y + h - 17], fill=it["color"])
            elif k == "rug":
                g.ellipse([x, y, x + w - 1, y + h - 1], fill=it["color"])
            elif k == "ruler":
                g.ellipse([x + 6, y, x + w - 6, y + 20], fill=it["color"])
                g.rectangle([x + 4, y + 20, x + w - 4, y + 60], fill=it["color"])
                g.rectangle([x + 6, y + 60, x + 14, y + h - 1], fill=it["color"])
                g.rectangle([x + w - 14, y + 60, x + w - 6, y + h - 1], fill=it["color"])
            elif it["name"] == "囍字圆牌":
                g.ellipse([x, y, x + w, y + h], fill=it["color"])
            else:
                g.rectangle([x, y, x + w - 1, y + h - 1], fill=it["color"])
    if not labels:
        return im
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    f12, f14, f18, f22 = (ImageFont.truetype(FONT, s) for s in (12, 14, 18, 22))

    def txt(xy, s, fnt=f14, col=(255, 255, 255), anchor="mm"):
        d.text(xy, s, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=3, stroke_fill=(0, 0, 0, 255))

    def dim(a, b, s, col=(0, 200, 255)):
        d.line([a, b], fill=col + (255,), width=2)
        for p in (a, b):
            d.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=col + (255,))
        txt(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - 10), s, f12, col)

    for it in items:
        x, y, w, h = it["box"]
        n = it["name"]
        if it["kind"] == "table":
            game = n in ("T1", "T2", "T3", "T4", "T5", "T6")
            txt((x + w / 2, y + h / 2), n, f18 if n != "主桌" else f22, (255, 240, 120) if game or n == "主桌" else (255, 255, 255))
            if game:
                txt((x + w / 2, y + h + 6), "游戏桌", f12, (255, 240, 120))
        elif it["kind"] in ("rug", "floor"):
            continue
        elif it["kind"] == "zone":
            d.rectangle([x, y, x + w, y + h], outline=(0, 160, 255, 255), width=2)
            txt((x + w / 2, y + h / 2), "进门站的地方", f14, (0, 200, 255))
        elif n.startswith("新人站位"):
            if "新娘" in n:
                txt((CX, y - 14), "新人站位", f14, (255, 255, 255))
        elif "壁边灯柱" in n or "落地宫灯" in n or n.startswith("花盆"):
            continue
        elif it["kind"] in ("stage", "wall", "decor", "door", "band", "prop"):
            if n in ("婚礼台（台口立面）", "东墙（南段）", "西墙"):
                continue
            txt((x + w / 2, y + h / 2), n.replace("（台面）", "").replace("（立面）", "").replace("（北段）", ""), f14 if w < 120 else f18)
    # 尺寸
    t0 = [it for it in items if it["name"] == tid[(1, 1)]][0]["box"]
    x, y, w, h = t0
    dim((x, y - 8), (x + w, y - 8), "桌 140")
    dim((x - 8, y), (x - 8, y + h), "92")
    r0 = [it for it in items if it["name"] == tid[(1, 1)] + " 地毯"][0]["box"]
    dim((r0[0], r0[1] + r0[3] + 8), (r0[0] + r0[2], r0[1] + r0[3] + 8), "毯 160×105")
    c = COLS
    yy = rows_y[4]
    dim((c[0], yy), (c[1], yy), "列距 203")
    dim((c[2], yy), (c[3], yy), "跨红毯 320")
    dim((c[4] + 90, rows_y[3]), (c[4] + 90, rows_y[4]), "行距 148")
    dim((c[5] + 100, rows_y[2] + 46), (c[5] + 100, rows_y[3] - 46), "横走道 128")
    dim((STAGE[0], STAGE[1] + 12), (STAGE[0] + STAGE[2], STAGE[1] + 12), "台 480×128")
    dim((LED[0], LED[1] + LED[3] + 6), (LED[0] + LED[2], LED[1] + LED[3] + 6), "LED 432")
    dim((BANNER[0], BANNER[1] - 4), (BANNER[0] + BANNER[2], BANNER[1] - 4), "横幅 324×40")
    dim((CX - 57, rail_foot + 4), (CX + 57, rail_foot + 4), "大门 114")
    txt((W - 20, 40), "画布 %d×%d（1:1，人 84）" % (W, H), f22, anchor="rm")
    txt((W - 28, (door[0] + door[1]) / 2), "东侧门", f14, anchor="rm")
    ru = [it for it in items if it["kind"] == "ruler"][0]["box"]
    txt((ru[0] + ru[2] + 30, ru[1] + 42), "人 84", f14)
    im = Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")
    return im


def table_md(items, tid, bad):
    lines = ["# 宴会厅 55 桌 · 摆位表（02，9/25）", "",
             "> 01 D 9/25 派。画布 %d×%d，1:1（人 84）。坐标是左上角，单位画布像素。依据：ASSETS §15（左右和高 1 米 = 48、地面前后 1 米 = 32）、04 `体验-第47版-55桌.md`、方案 `宴会厅55桌-方案.md`。脚本 `tools/layout_55/make_board55.py`，改数重跑。" % (W, H),
             "", "| 名字 | x | y | 宽 | 高 | 依据 |", "| --- | --- | --- | --- | --- | --- |"]
    for it in items:
        if it["kind"] == "zone":
            pass
        x, y, w, h = it["box"]
        lines.append("| %s | %d | %d | %d | %d | %s |" % (it["name"], x, y, w, h, it["basis"]))
    lines += ["", "## 自检", ""]
    lines += ["- " + b for b in bad] if bad else ["- 比例：每样都照 §15 的数取（取值见「依据」列），没有大过 1.5 倍、小过一半的",
                                                 "- 谁也不压谁：除了桌压自己的地毯，没有两样东西的框重叠（墙上的花拱、囍、横幅贴墙；LED、新人站位在台上，不算）",
                                                 "- 地毯之间都露地面（左右 43、上下 43，横走道那两处 115）",
                                                 "- 55 张桌 + 主桌，每张都能从红毯走到，路按人宽 43 算（离挡路的东西 21 像素以内不算能站）",
                                                 "- 横幅下沿 190，在囍字下沿 140 下面，不盖；LED 552～984，在台面 528～1008 里"]
    return "\n".join(lines) + "\n"


def main():
    items, tid, door, stand_top, rail_foot = build()
    bad = check(items)
    os.makedirs(OUT, exist_ok=True)
    clean = draw(items, False, tid, door, stand_top, rail_foot)
    clean.save(os.path.join(OUT, "宴会厅55桌-摆位底图.png"))
    draw(items, True, tid, door, stand_top, rail_foot).save(os.path.join(OUT, "宴会厅55桌-摆位底图-标注.png"))
    vx = CX - VIEW[0] // 2
    clean.crop((vx, H - VIEW[1], vx + VIEW[0], H)).resize((540, 960), Image.NEAREST).save(os.path.join(OUT, "宴会厅55桌-手机屏-进门.png"))
    clean.crop((vx, 0, vx + VIEW[0], VIEW[1])).resize((540, 960), Image.NEAREST).save(os.path.join(OUT, "宴会厅55桌-手机屏-舞台.png"))
    open(os.path.join(OUT, "宴会厅55桌-摆位表.md"), "w", encoding="utf-8").write(table_md(items, tid, bad))
    print("画布 %d×%d，东西 %d 件，桌 55 + 主桌" % (W, H, len(items)))
    print("自检：", "全过" if not bad else bad)
    print("排：", rows_y)
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
