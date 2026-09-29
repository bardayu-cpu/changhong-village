#!/usr/bin/env python3
"""55 桌摆位底图（01 D 9/25 派）：GPT 画 5 张效果图的底子，每样东西的坐标、像素大小在这一步定死，拆回来的图照这张原样摆回游戏。
依据：ASSETS §15 比例尺（左右和高 1 米 = 48 像素、地面前后 1 米 = 32 像素、人 84）、回执/宴会厅55桌-方案.md、
回执/体验-第47版-55桌.md（04）、回执/比例量尺-55桌摆位底图v2.md（03）。全用色块，不贴任何现成的图。

v3（01 D 9/25，起因是 03 量 v2 的风险第 1 条）：**每样东西的色块 = 它画出来在画面上占的框，下沿是它落地的地方**。
  每件记两个框：
    box  = 画出来占的框（色块画的就是它）
    foot = 地上占的地（走路判定、落地线用）
  平的（红毯、地面、乐队地台）两个框一样；立着的从占地往上加它的高：
    有进深的（桌连椅、婚礼台连台口、台阶、礼物堆、钢琴、长凳、琴凳、椅子）：框 = 占地 + 往上高出的那截
    细高的（人、宫灯、灯柱、花盆、谱架、大提琴、门、栏杆）：框就是 §15 的高，占地是框最下面那一条
  行距 148 → 180（前一排前沿到后一排椅背，画面上露 42 地面）；横走道那两处（占地之间 128）不动

出四样（都进 godot/回执/）：
  宴会厅55桌-摆位底图.png        整厅 1:1，纯色块、一个字不写，站一个 84 像素的人当尺子
  宴会厅55桌-摆位底图-标注.png   同一张，标名字、桌号、关键尺寸、落地线
  宴会厅55桌-摆位表.md           每样东西一行：画出来的框、占地、依据
  宴会厅55桌-手机屏-进门.png / -舞台.png   按手机竖屏 540×960 的视野（镜头 960/1024 倍，一屏看画布 576×1024）切的两屏
自检：比例对 §15、画面上谁压谁、每张桌从红毯走得到（按占地、路至少 43 宽）、行与行之间画面上露的地面最窄多少
v3.2（阿鱼 9/28：「不要横幅和 led 了，太丑了」）：删掉横幅、LED 屏；台阶回到台口正中一段 144 宽（像第 44 版），红毯接到台阶下沿
v3.3（阿鱼 9/29：出阁宴，主桌坐满阿鱼家 13 位）：主桌换大一号的圆桌 2.2 米，连一圈椅子占地 160×106；
  台前那对宫灯跟着主桌椅背往上挪 7；别的桌一张不动
      （阿鱼 9/28：「都有地毯的话看起来太乱了，先不要地毯」）：55 桌和主桌下面的地毯全删，中间红毯留着；行距、列距、画布一个数不动
用法：python3 tools/layout_55/make_board55.py [输出目录，默认 回执/]
      python3 tools/layout_55/make_board55.py --north 输出目录   切北边 y 0～1024 给 GPT（干净版、标注版、这块的摆位表）
"""
import collections
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else os.path.join(HERE, "..", "..", "回执")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"

W = 1536
CX = 768                      # 红毯中线
PERSON = 84
VIEW = (576, 1024)            # 手机竖屏一屏看到的画布（540×960，镜头 960/1024）

# ---------- 桌位 ----------
TABLE = (140, 92)             # 桌连一圈椅子的占地（§15 宴会圆桌 1.8 米 + 一圈椅子，04 / 01 定）
# 主桌（v3.3，阿鱼 9/29：13 位）：2.2 米大圆桌 + 一圈椅子。椅子那圈和普通桌一样宽：普通桌 140 = (1.8 + 2×0.56)×48，
# 所以主桌左右 (2.2 + 1.12)×48 = 159.4 → 160，前后 ×32 = 106.2 → 106。13 人坐一圈，每人约 0.53 米桌边（普通桌 10 人 0.57）
MAIN_TABLE = (160, 106)
MAIN_SEATS = 13
CHAIR_UP = 46                 # 后排椅背往上冒的高（§15 椅子高 46）：画出来 140×138（01 v3）
RUG = (160, 105)              # v3.2 起桌下地毯删了（阿鱼：太乱）；这个数只留着定南边那块空地从哪起、中间屏切到哪，画布大小不变
COLS = [CX - 160 - 203 * 2, CX - 160 - 203, CX - 160, CX + 160, CX + 160 + 203, CX + 160 + 203 * 2]   # 块内列距 203、跨红毯 320
ROW0 = 682                    # 第 1 排桌心：台前红毯两边的宫灯（画出来 80 高）要站在台阶下沿 525 和第 1 排椅背之间
PITCH = 180                   # 行距（v3：148 → 180；占地之间 88，画面上前一排前沿到后一排椅背 42）
CROSS_GAP = 128               # 横走道：占地之间 128（4 米），v3 不动
CROSS_AFTER = (2, 6)          # 第 3 排、第 7 排后面各一条横走道：3 + 4 + 3 排
rows_y = []
y = ROW0
for r in range(10):
    rows_y.append(y)
    y += (TABLE[1] + CROSS_GAP) if r in CROSS_AFTER else PITCH
# 60 个位：主桌 + T1～T54 一共 55 桌（01 定的默认「55 桌含主桌」，还没跟阿鱼核过），空 5 个
MAIN = (0, 2)
# v3.1（04 新 2：最南一排只剩 3 张、缺口正对进门，冷清不对称）：最南一排补回东头那张，4 张左右对称；
# 多出来的那个空位挪到第 1 排最东——正对乐队地台，客人能站着看乐队，和西头放长凳的空位左右对称，离大门最远
EMPTY = {(0, 3): "新人下台敬酒的路，看台子不挡", (0, 0): "放长凳（普通桌坐满了坐这）", (9, 2): "进门客人站的地方", (9, 3): "进门客人站的地方",
         (0, 5): "v3.1 挪来的空位（55 桌含主桌）：正对乐队地台，客人站着看乐队；和西头放长凳的空位左右对称；离大门最远，进门看不见缺口"}
N_T = 54

# ---------- 北边 ----------
WALL_N = 336                  # 北墙立面高 7 米（手机顶上约 140 那条被胶囊和左上角牌子挡，那条里只放墙顶、梁、帐幔、挂灯）
STAGE_FOOT = (528, 365, 480, 128)   # 婚礼台占地：宽 10 米、前后 4 米
STAGE_UP = 29                 # 台高 0.6 米：台面画在占地往上 29，台口立面就是这 29
STAGE_BOX = (528, 336, 480, 157)    # 画出来：台面 336～464 + 台口立面 464～493，落地线 493
STAGE_TOP = (528, 336, 480, 128)
STAGE_FACE = (528, 464, 480, 29)
STEP_W = 144                  # 台阶回到台口正中一段（v3.2，像第 44 版；宽照 v1 的 144，和红毯一样宽 3 米）
STEPS_FOOT = (CX - STEP_W // 2, 493, STEP_W, 32)
ARCH = (CX - 120, 152, 240, 180)   # 花拱：宽 5 米、高 3.75 米，贴北墙，整个在 150 以下
XI = (CX - 48, 188, 96, 96)   # 囍字圆牌：直径 2 米
COUPLE_FEET = [(CX - 16, 434), (CX + 16, 434)]   # 新人站位：台面中间、囍字正下方（只标位置）
CARPET_TOP = 525              # 红毯从台阶下沿往南铺（v3.2）
H = None


def up(foot, h_up):
    """立着、有进深的：占地往上加 h_up 就是画出来的框"""
    x, y, w, h = foot
    return (x, y - h_up, w, h + h_up)


def standing(box, foot_h):
    """细高的：框就是画出来的（§15 的高），占地是框最下面 foot_h 那一条"""
    x, y, w, h = box
    return (x, y + h - foot_h, w, foot_h)


def build():
    global H
    last_rug_bottom = rows_y[-1] + RUG[1] // 2 + 1
    stand_top = last_rug_bottom + 30
    STAND = 96
    rail_foot = stand_top + STAND + 145
    H = rail_foot + 8
    items = []

    def add(name, kind, box, color, basis, group="", foot=None, flat=False):
        items.append({"name": name, "kind": kind, "box": [int(v) for v in box], "foot": [int(v) for v in (foot or box)],
                      "color": color, "basis": basis, "group": group, "flat": flat})

    wood = (92, 52, 36)
    # 墙
    add("北墙（立面）", "wall", (0, 0, W, WALL_N), wood, "墙高 7 米：7×48=336（§15 没有墙这一行）", foot=(0, WALL_N - 16, W, 16))
    add("墙顶横梁", "decor", (0, 0, W, 24), (60, 32, 22), "梁高 0.5 米×48=24", "top_decor")
    # 帐幔 7 段，在两边墙之间（40～1496）左右匀开：段与段、段与墙之间的缝一样宽（v3.1，03：原来东边空出一段光板）
    gap = (W - 80 - 7 * 152) // 8
    drapes = [40 + gap + k * (152 + gap) for k in range(7)]
    for k, x0 in enumerate(drapes):
        add("帐幔 %d" % (k + 1), "decor", (x0, 24, 152, 40), (170, 40, 40), "垂下 0.8 米×48=40；一段 3.2 米宽", "top_decor")
    for k in range(len(drapes) - 1):   # 挂灯只挂在两段帐幔之间的缝里，挂在缝正中
        add("挂灯 %d" % (k + 1), "decor", (drapes[k] + 152 + (gap - 20) // 2, 60, 20, 24), (240, 170, 60), "§15 挂着的灯笼 高 19～24，取 24；宽 20", "top_decor")
    side_bottom = rail_foot - 48
    add("西墙", "wall", (0, WALL_N, 40, side_bottom - WALL_N), wood, "墙厚 40（约 0.8 米，§15 没有）；俯看是一条，平的", flat=True)
    cross2_mid = (rows_y[CROSS_AFTER[1]] + TABLE[1] // 2 + rows_y[CROSS_AFTER[1] + 1] - TABLE[1] // 2) // 2
    d0, d1 = cross2_mid - 29, cross2_mid + 29
    add("东墙（北段）", "wall", (W - 40, WALL_N, 40, d0 - WALL_N), wood, "墙厚 40（约 0.8 米）；平的", flat=True)
    add("东墙（南段）", "wall", (W - 40, d1, 40, side_bottom - d1), wood, "墙厚 40（约 0.8 米）；平的", flat=True)
    add("东侧门（门洞）", "door", (W - 40, d0, 40, d1 - d0), (60, 140, 200), "§15 双开门宽 1.8 米；开在东墙上，宽沿地面前后算：1.8×32=58；开在第二条横走道东头", flat=True)
    # 北墙上的：花拱、囍（v3.2 横幅删了）
    add("花拱", "decor", ARCH, (70, 130, 70), "宽 5 米×48=240、高 3.75 米×48=180（§15 没有）", "wall_decor")
    add("囍字圆牌", "decor", XI, (215, 170, 60), "直径 2 米×48=96（§15 没有）", "wall_decor")
    # 婚礼台、台阶、新人
    add("婚礼台（台面）", "stage", STAGE_TOP, (214, 78, 66), "占地宽 10 米×48=480、前后 4 米×32=128（365～493）；台高 0.6 米，台面画在占地往上 29（336～464）", "stage", foot=STAGE_FOOT)
    add("婚礼台（台口立面）", "stage", STAGE_FACE, (112, 24, 24), "台高 0.6 米×48=29；落地线 493；色块比台面深得多（v3.1，04 新 3：台面、立面要分得开）", "stage", foot=(528, 477, 480, 16))
    add("台阶", "stage", up(STEPS_FOOT, STAGE_UP), (190, 120, 96), "台口正中一段（v3.2，像第 44 版）：占地宽 3 米×48=144（和红毯一样宽）、前后 1 米×32=32，两级；最上一级和台面一样高 0.6 米，往上加 29", "stage", foot=STEPS_FOOT)
    for i, (fx, fy) in enumerate(COUPLE_FEET):
        add("新人站位%s" % ("（新娘）" if i == 0 else "（新郎）"), "mark", (fx - 12, fy - 4, 24, 8), (255, 255, 255),
            "台面中间、囍字正下方；只标脚下 y %d。人 84 高，头顶到 y %d，在囍字下沿 %d 下面、不挡囍" % (fy, fy - PERSON, XI[1] + XI[3]), "stage_decor")
    # 红毯、宫灯、花盆
    carpet_bottom = rail_foot - 145
    add("红毯", "floor", (CX - 72, CARPET_TOP, 144, carpet_bottom - CARPET_TOP), (179, 32, 42), "3 米×48=144（方案）；从台阶下沿到大门跟前", flat=True)
    LAMP = (24, 80)

    def lamp_pair(y_foot, tag):
        for side, x in (("西", CX - 72 - 24), ("东", CX + 72)):
            b = (x, y_foot - LAMP[1], LAMP[0], LAMP[1])
            add("红毯%s侧落地宫灯（%s）" % (side, tag), "prop", b, (240, 200, 60), "§15 落地宫灯高 77～86，取 80；宽 0.5 米×48=24；占地是最下面 12", foot=standing(b, 12))

    def pot(name, x, y_foot):
        b = (x, y_foot - 32, 32, 32)
        add(name, "prop", b, (90, 170, 90), "§15 一盆花 24～38，取 32；占地是最下面 16", foot=standing(b, 16))

    # 台前两盏：落在台口立面下沿和第 1 排椅背（ROW0 - 46 - 46）之间，红毯两边、贴着台阶两侧
    row0_top = ROW0 - MAIN_TABLE[1] // 2 - CHAIR_UP   # 第 1 排椅背最高的是主桌（v3.3 大一号）
    lamp_pair(row0_top - 6, "台前")
    for k, r in enumerate(CROSS_AFTER):
        prev_front = rows_y[r] + TABLE[1] // 2
        next_top = rows_y[r + 1] - TABLE[1] // 2 - CHAIR_UP
        lamp_pair(next_top - 2, "第 %d 条横走道" % (k + 1))
        pot("花盆（第 %d 条横走道西）" % (k + 1), CX - 72 - 24 - 8 - 32, next_top - 2)
        pot("花盆（第 %d 条横走道东）" % (k + 1), CX + 72 + 24 + 8, next_top - 2)
    pot("花盆（台西角）", STAGE_FOOT[0] - 40, 493)
    pot("花盆（台东角）", STAGE_FOOT[0] + STAGE_FOOT[2] + 8, 493)
    # 壁边灯柱：两边墙根，每 300 一根，东边躲开侧门
    for yf in range(ROW0 - 2, side_bottom - 40, 300):
        b = (44, yf - 80, 24, 80)
        add("西墙壁边灯柱（y %d）" % yf, "prop", b, (230, 170, 60), "§15 壁边灯柱照落地宫灯 77～86，取 80；宽 24；占地最下面 12", foot=standing(b, 12))
        if not (d0 - 20 < yf < d1 + 100):
            b = (W - 40 - 4 - 24, yf - 80, 24, 80)
            add("东墙壁边灯柱（y %d）" % yf, "prop", b, (230, 170, 60), "§15 壁边灯柱照落地宫灯 77～86，取 80；宽 24；占地最下面 12", foot=standing(b, 12))
    # 乐队（台子东边的地台上）
    pf = (1076, 416, 340, 96)   # 地台占地：宽 7 米、前后 3 米
    add("乐队地台", "band_floor", up(pf, 10), (120, 40, 50), "占地宽 7 米×48=340（钢琴 72 + 琴凳 + 4 人各 32 + 谱架 + 间隔）、前后 3 米×32=96；台高 0.2 米，往上加 10", "band", foot=pf)
    fl = 500   # 乐手、钢琴的落地线
    piano_f = (1084, fl - 48, 72, 48)
    add("三角钢琴", "band", up(piano_f, 48), (30, 30, 30), "§15 三角钢琴 长 72、琴身高 48；占地进深 1.5 米×32=48，往上加琴身高 48", "band", foot=piano_f)
    bench_f = (1176, fl - 16, 32, 16)   # 琴凳往东错出 16：人坐在凳子西半截，凳子露出来一截（不然整个被人挡住，图上看不见）
    add("琴凳", "band", up(bench_f, 22), (80, 50, 30), "宽 32、进深 0.5 米×32=16、高 0.45 米×48=22（§15 没有）；钢琴手坐在西半截，东边露 16", "band", foot=bench_f)
    b = (1160, fl - 62, 32, 62)
    add("钢琴手（坐）", "band", b, (70, 60, 110), "§15 坐着的人 62（头顶到脚）；宽 32；坐在琴凳上", "band", foot=standing(b, 10))
    chair_f = (1212, fl - 16, 24, 16)   # 椅子比人往西错出 12，露出来一截
    add("大提琴手的椅子", "band", up(chair_f, 46), (80, 50, 30), "§15 椅子 高 46、宽 22 取 24；进深 16；大提琴手坐在东半截，西边露 12", "band", foot=chair_f)
    b = (1224, fl - 62, 32, 62)
    add("大提琴手（坐）", "band", b, (70, 60, 110), "§15 坐着的人 62；宽 32；坐在椅子上", "band", foot=standing(b, 10))
    b = (1260, fl - 62, 20, 62)
    add("大提琴", "band", b, (140, 80, 40), "琴高 1.2 米×48=58，加尾柱着地 4 共 62（§15 没有；v3.1 从 70 收到 62，在 03 估的 48～62 里）", "band", foot=standing(b, 8))
    for k, (sx, px) in enumerate(((1284, 1302), (1346, 1364))):
        b = (sx, fl - 66, 16, 66)
        add("谱架 %s" % "甲乙"[k], "band", b, (60, 60, 60), "高 1.2 米×48=58 + 脚 8 = 66、宽 16（§15 没有）", "band", foot=standing(b, 8))
        b = (px, fl - 84, 32, 84)
        add("小提琴手 %s（站）" % "甲乙"[k], "band", b, (110, 70, 140), "§15 人 84；宽 32", "band", foot=standing(b, 10))
    # 礼物堆（台子西边地上）
    gf = (400, 490, 72, 32)
    add("贺礼堆", "prop", up(gf, 48), (230, 120, 120), "§15 礼物堆整堆高 48；宽 72（1.5 米）、占地进深 1 米×32=32，往上加 48", foot=gf)
    # 桌、长凳（v3.2 桌下地毯删了）
    ids = []
    for r in range(10):
        slots = [c for c in range(6) if (r, c) not in EMPTY and (r, c) != MAIN]
        slots.sort(key=lambda c: (abs(COLS[c] - CX), COLS[c]))
        ids += [(r, c) for c in slots]
    tid = {rc: "T%d" % (i + 1) for i, rc in enumerate(ids)}
    assert len(tid) == N_T
    for r in range(10):
        for c in range(6):
            cx, cy = COLS[c], rows_y[r]
            if (r, c) in EMPTY:
                if EMPTY[(r, c)].startswith("放长凳"):
                    bf = (cx - 36, cy + 30 - 16, 72, 16)
                    add("长凳", "prop", up(bf, 38), (120, 200, 255), "§15 长凳 宽 72、高 38；进深 0.5 米×32=16，往上加 38；放在第 1 排最西的空位", foot=bf)
                continue
            name = "主桌" if (r, c) == MAIN else tid[(r, c)]
            tw, th = MAIN_TABLE if name == "主桌" else TABLE
            tf = (cx - tw // 2, cy - th // 2, tw, th)
            basis = ("占地 160×106（v3.3 阿鱼：主桌坐 13 位，2.2 米大圆桌 + 一圈椅子，椅圈宽照普通桌）；后排椅背往上冒 46，画出来 160×152"
                     if name == "主桌" else
                     "占地 140×92（§15 宴会圆桌 1.8 米 + 一圈椅子，04 / 01）；后排椅背往上冒 46（§15 椅子高 46），画出来 140×138")
            add(name, "table", up(tf, CHAIR_UP), (220, 70, 60) if name != "主桌" else (240, 190, 60), basis, "table:" + name, foot=tf)
    # 南边：栏杆、大门、进门站的地方
    door_w = 114
    b = (CX - door_w // 2, rail_foot - 145, door_w, 145)
    add("大门（双开门门洞）", "door", b, (60, 140, 200), "§15 双开门／院门门洞 宽 86～115、高 115～145，取 114×145；落地线 %d" % rail_foot, foot=standing(b, 8))
    b = (40, rail_foot - 48, CX - door_w // 2 - 40, 48)
    add("南边西段栏杆", "wall", b, (120, 80, 50), "§15 齐腰栏杆 高 48；落地线 %d" % rail_foot, foot=standing(b, 8))
    b = (CX + door_w // 2, rail_foot - 48, W - 40 - (CX + door_w // 2), 48)
    add("南边东段栏杆", "wall", b, (120, 80, 50), "§15 齐腰栏杆 高 48；落地线 %d" % rail_foot, foot=standing(b, 8))
    add("进门站的地方", "zone", (CX - 150, stand_top, 300, rail_foot - 145 - stand_top), None, "大门里边空出来的地面：宽 300、前后 3 米（96）", flat=True)
    b = (CX + 90, rail_foot - 145 - 4 - PERSON, 32, PERSON)
    add("尺子：人", "ruler", b, (20, 20, 20), "§15 人 84；宽 32（画的人整个撑满这 32×84）", foot=standing(b, 10))
    return items, tid, (d0, d1), stand_top, rail_foot


def overlaps(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


# 画面上可以叠的：坐着的人和他的凳子、椅子
SIT = [{"钢琴手（坐）", "琴凳"}, {"大提琴手（坐）", "大提琴手的椅子"}]


def check(items):
    """验收：画面上谁压谁、走得开（按占地）、行与行之间露的地面"""
    bad = []
    for i, a in enumerate(items):
        for b in items[i + 1:]:
            if not overlaps(a["box"], b["box"]):
                continue
            ka, kb = a["kind"], b["kind"]
            ga, gb = a["group"], b["group"]
            pair = {a["name"], b["name"]}
            if "zone" in (ka, kb) or "ruler" in (ka, kb) and ({ka, kb} & {"floor"}):
                continue
            if "top_decor" in (ga, gb) and ("北墙（立面）" in pair or {ga, gb} == {"top_decor"}):
                continue   # 墙顶的梁、帐幔、挂灯贴在北墙上
            if "wall_decor" in (ga, gb) and ("北墙（立面）" in pair or {ga, gb} == {"wall_decor"}):
                continue   # 花拱、囍贴北墙
            if {ga, gb} <= {"stage", "stage_decor"}:
                continue   # 台面、台口、台阶、新人脚印是一座台子
            if {ga, gb} == {"band"} and (ka == "band_floor" or kb == "band_floor" or pair in SIT):
                continue   # 乐队站在地台上；坐着的人坐在凳子、椅子上
            if a["flat"] and b["flat"]:
                continue
            if a["flat"] or b["flat"]:
                continue   # 立着的东西画出来会挡住它后面的地面（红毯、地面），这不算压
            bad.append("画面上压住了：%s × %s" % (a["name"], b["name"]))
    for it in items:
        x, y, w, h = it["box"]
        if x < 0 or y < 0 or x + w > W or y + h > H:
            bad.append("出了画布：%s" % it["name"])
        if y < 140 and it["group"] != "top_decor" and it["name"] != "北墙（立面）":
            bad.append("手机顶上被挡的那条里放了 %s" % it["name"])
        if it["group"] == "top_decor" and y + h > 140:
            bad.append("墙顶的 %s 伸到了 140 下面" % it["name"])
    for n, box in (("囍字圆牌", XI), ("花拱", ARCH)):
        if box[1] < 150:
            bad.append("%s 没整个落在 150 以下" % n)
    fl = [it for it in items if it["kind"] == "band_floor"][0]["foot"]
    for it in items:
        if it["group"] == "band" and it["kind"] == "band":
            x, y, w, h = it["foot"]
            if not (x >= fl[0] and x + w <= fl[0] + fl[2] and y >= fl[1] and y + h <= fl[1] + fl[3]):
                bad.append("%s 不在乐队地台上" % it["name"])
    # 走得开：按占地。4 像素一格；挡路的是立着的东西的占地、墙、台子、乐队地台；红毯能走。
    # 人宽 43：离挡路的东西 21 像素以内的格子不算能站
    g = 4
    cols, rows = W // g, H // g
    block = bytearray(cols * rows)
    for it in items:
        if it["flat"] and it["kind"] != "wall":
            continue
        if it["kind"] in ("mark", "ruler", "zone") or it["group"] in ("top_decor", "wall_decor", "stage_decor"):
            continue
        if it["kind"] == "door":
            continue
        x, y, w, h = it["foot"]
        for j in range(max(0, (y - 21) // g), min(rows, (y + h + 21) // g + 1)):
            for i in range(max(0, (x - 21) // g), min(cols, (x + w + 21) // g + 1)):
                block[j * cols + i] = 1
    for j in range(rows):
        for i in list(range(0, 6)) + list(range(cols - 6, cols)):
            block[j * cols + i] = 1
    seen = bytearray(cols * rows)
    q = collections.deque()
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
        x, y, w, h = it["foot"]
        ok = False
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
    return bad


def row_gaps(items):
    """行与行之间画面上露出的地面：同一列里，后一排画出来的上沿（椅背）减前一排画出来的下沿（前沿）"""
    tables = {}
    for it in items:
        if it["kind"] == "table":
            tables[(it["foot"][0], it["foot"][1])] = it
    by_col = collections.defaultdict(list)
    for (x, y), it in tables.items():
        by_col[x].append(it)
    g1 = []
    for x, lst in by_col.items():
        lst.sort(key=lambda it: it["foot"][1])
        for a, b in zip(lst, lst[1:]):
            if b["foot"][1] - a["foot"][1] > PITCH + 1:
                continue   # 隔着空位或横走道的不算「行与行」
            a_front = a["box"][1] + a["box"][3]
            b_top = b["box"][1]
            g1.append(b_top - a_front)
    return min(g1)


def draw(items, labels, tid, door, stand_top, rail_foot):
    im = Image.new("RGB", (W, H), (239, 227, 207))
    g = ImageDraw.Draw(im)
    order = ["floor", "zone", "band_floor", "wall", "stage", "decor", "mark", "door", "table", "prop", "band", "ruler"]
    # 立着的东西按落地线从北往南画（南边的挡北边的）
    for k in order:
        lst = [it for it in items if it["kind"] == k and it["color"] is not None]
        if k in ("table", "prop", "band"):
            lst.sort(key=lambda it: it["foot"][1] + it["foot"][3])
        for it in lst:
            x, y, w, h = it["box"]
            if k == "mark":
                g.ellipse([x, y, x + w, y + h], fill=it["color"])
            elif k == "table":
                fx, fy, fw, fh = it["foot"]
                g.ellipse([fx + 10, y, fx + fw - 10, y + fh], fill=(90, 50, 25))            # 后排椅背冒上去那截
                g.ellipse([fx, fy, fx + fw - 1, fy + fh - 1], fill=(90, 50, 25))           # 桌连一圈椅子的占地
                g.ellipse([fx + 27, fy + 17, fx + fw - 27, fy + fh - 17], fill=it["color"])   # 桌面
            elif k == "rug":
                g.ellipse([x, y, x + w - 1, y + h - 1], fill=it["color"])
            elif k == "ruler":
                g.ellipse([x + 8, y, x + w - 9, y + 17], fill=it["color"])
                g.rectangle([x, y + 18, x + w - 1, y + 58], fill=it["color"])
                g.rectangle([x + 3, y + 58, x + 13, y + h - 1], fill=it["color"])
                g.rectangle([x + w - 14, y + 58, x + w - 4, y + h - 1], fill=it["color"])
            elif it["name"] == "囍字圆牌":
                g.ellipse([x, y, x + w - 1, y + h - 1], fill=it["color"])
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

    # 落地线：立着的东西（不是平的、不是墙上贴的）占地的下沿画一道洋红线
    for it in items:
        if it["flat"] or it["group"] in ("top_decor", "wall_decor", "stage_decor") or it["kind"] in ("zone", "mark") or it["name"] == "北墙（立面）":
            continue
        fx, fy, fw, fh = it["foot"]
        d.line([(fx, fy + fh), (fx + fw, fy + fh)], fill=(255, 0, 200, 255), width=2)
    for it in items:
        x, y, w, h = it["box"]
        n = it["name"]
        if it["kind"] == "table":
            game = n in ("T1", "T2", "T3", "T4", "T5", "T6")
            fx, fy, fw, fh = it["foot"]
            txt((fx + fw / 2, fy + fh / 2), n, f18 if n != "主桌" else f22, (255, 240, 120) if game or n == "主桌" else (255, 255, 255))
            if game:
                txt((fx + fw / 2, fy + fh + 8), "游戏桌", f12, (255, 240, 120))
        elif it["kind"] in ("rug", "floor"):
            continue
        elif it["kind"] == "zone":
            d.rectangle([x, y, x + w, y + h], outline=(0, 160, 255, 255), width=2)
            txt((x + w / 2, y + h / 2), "进门站的地方", f14, (0, 200, 255))
        elif n.startswith("新人站位"):
            if "新娘" in n:
                txt((CX, y - 14), "新人站位", f14, (255, 255, 255))
        elif "壁边灯柱" in n or "落地宫灯" in n or n.startswith("花盆") or it["group"] == "top_decor" and n != "墙顶横梁":
            continue
        elif it["kind"] == "band_floor":
            txt((x + w / 2, y + h - 10), n, f14)
        elif it["kind"] == "band":
            continue
        elif it["kind"] in ("stage", "wall", "decor", "door", "prop"):
            if n in ("婚礼台（台口立面）", "东墙（南段）", "西墙"):
                continue
            txt((x + w / 2, y + h / 2), n.replace("（台面）", "").replace("（立面）", "").replace("（北段）", ""), f14 if w < 120 else f18)
    txt((1246, 392), "乐队：钢琴、琴凳、钢琴手、椅子、大提琴手、大提琴、谱架×2、小提琴手×2", f12)
    # 尺寸
    t0 = [it for it in items if it["name"] == tid[(1, 1)]][0]
    x, y, w, h = t0["box"]
    fx, fy, fw, fh = t0["foot"]
    dim((x, y - 8), (x + w, y - 8), "桌 140")
    dim((x - 10, y), (x - 10, y + h), "画出来 138")
    dim((x + w + 10, fy), (x + w + 10, fy + fh), "占地 92")
    c = COLS
    yy = rows_y[4]
    dim((c[0], yy), (c[1], yy), "列距 203")
    dim((c[2], yy), (c[3], yy), "跨红毯 320")
    dim((c[4] + 90, rows_y[3]), (c[4] + 90, rows_y[4]), "行距 180")
    a = [it for it in items if it["name"] == tid[(3, 5)]][0]
    b2 = [it for it in items if it["name"] == tid[(4, 5)]][0]
    dim((c[5] + 60, a["box"][1] + a["box"][3]), (c[5] + 60, b2["box"][1]), "露地面 42", (255, 120, 120))
    dim((c[5] + 100, rows_y[2] + 46), (c[5] + 100, rows_y[3] - 46), "横走道 128")
    dim((STAGE_TOP[0], STAGE_TOP[1] + 12), (STAGE_TOP[0] + STAGE_TOP[2], STAGE_TOP[1] + 12), "台 480，画出来 157")
    dim((STEPS_FOOT[0], STEPS_FOOT[1] + STEPS_FOOT[3] + 6), (STEPS_FOOT[0] + STEP_W, STEPS_FOOT[1] + STEPS_FOOT[3] + 6), "台阶 144")
    dim((W - 60, 0), (W - 60, 140), "手机顶上被挡 140", (255, 120, 120))
    dim((W - 110, 0), (W - 110, WALL_N), "北墙 336")
    dim((CX - 57, rail_foot + 4), (CX + 57, rail_foot + 4), "大门 114")
    txt((W - 20, 40), "画布 %d×%d（1:1，人 84）" % (W, H), f22, anchor="rm")
    txt((W - 20, 72), "洋红线 = 落地线", f14, (255, 120, 220), anchor="rm")
    txt((W - 28, (door[0] + door[1]) / 2), "东侧门", f14, anchor="rm")
    for ru in [it for it in items if it["kind"] == "ruler"]:
        rb = ru["box"]
        txt((rb[0] + rb[2] + 30, rb[1] + 42), "人 84", f14)
    im = Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")
    return im


SIT_H = 62                    # 坐着的人（§15 坐着的人头顶到脚 62）
SIT_W = 24                    # 剪影宽：一桌 10 把椅子一圈，32 宽排不开，取 24（0.5 米）


def draw_table(g, it, part="all"):
    """part：back = 椅背和一圈椅子；top = 桌面；all = 都画"""
    fx, fy, fw, fh = it["foot"]
    x, y, w, h = it["box"]
    if part in ("all", "back"):
        g.ellipse([fx + 10, y, fx + fw - 10, y + fh], fill=(90, 50, 25))
        g.ellipse([fx, fy, fx + fw - 1, fy + fh - 1], fill=(90, 50, 25))
    if part in ("all", "top"):
        g.ellipse([fx + 27, fy + 17, fx + fw - 27, fy + fh - 17], fill=it["color"])


def draw_sitter(g, sx, sy, col):
    """坐着的剪影：脚在 (sx, sy)，62 高、24 宽；头一个圆、身子一块、腿收着"""
    x0, y0 = sx - SIT_W // 2, sy - SIT_H
    g.ellipse([x0 + 5, y0, x0 + SIT_W - 6, y0 + 14], fill=col)
    g.rectangle([x0 + 2, y0 + 14, x0 + SIT_W - 3, y0 + 44], fill=col)
    g.rectangle([x0 + 4, y0 + 44, x0 + SIT_W - 5, sy - 1], fill=col)


def draw_stander(g, sx, sy, col, tray=True):
    """站着的剪影（服务员）：脚在 (sx, sy)，84 高、32 宽，手上一个托盘"""
    x0, y0 = sx - 16, sy - PERSON
    g.ellipse([x0 + 8, y0, x0 + 23, y0 + 17], fill=col)
    g.rectangle([x0, y0 + 18, x0 + 31, y0 + 58], fill=col)
    g.rectangle([x0 + 3, y0 + 58, x0 + 13, sy - 1], fill=col)
    g.rectangle([x0 + 18, y0 + 58, x0 + 28, sy - 1], fill=col)
    if tray:
        g.rectangle([x0 + 22, y0 + 30, x0 + 44, y0 + 34], fill=(230, 230, 230))


def middle_with_people(items, tid, door, stand_top, rail_foot, out_path):
    """手机屏-中间（01 D 9/25：阿鱼问 55 桌会不会看着太挤）：两条横走道之间那段（第 4～7 排），
    每桌随机坐 9～10 个人（阿鱼 9/25 定，10 把椅子空 0～1 把；坐着 62 高的剪影，坐在椅子的位置上），红毯上站两个服务员（84）；别的图照旧不放人"""
    import random
    im = draw(items, False, tid, door, stand_top, rail_foot)
    g = ImageDraw.Draw(im)
    rng = random.Random(55)
    r0, r1 = CROSS_AFTER[0] + 1, CROSS_AFTER[1]
    top = rows_y[r0] - TABLE[1] // 2 - CHAIR_UP
    bot = rows_y[r1] + RUG[1] // 2
    cy = (top + bot) // 2
    y0 = max(0, min(H - VIEW[1], cy - VIEW[1] // 2))
    tables = sorted([it for it in items if it["kind"] == "table"], key=lambda it: it["foot"][1])
    seated = 0
    for it in tables:
        fx, fy, fw, fh = it["foot"]
        if fy + fh < y0 - 20 or fy > y0 + VIEW[1] + 80:
            continue
        cx, cyy = fx + fw / 2, fy + fh / 2
        n = rng.randint(9, 10)   # 阿鱼 9/25：「人不能少做，标准就是 9-10 人一桌」（04 第 47 版的 4～7 作废）
        chairs = sorted(rng.sample(range(10), n))
        import math
        pts = []
        for k in chairs:
            a = -math.pi / 2 + 2 * math.pi * k / 10
            pts.append((cx + math.cos(a) * 58, cyy + math.sin(a) * 34 + 10))
        back = [p for p in pts if p[1] < cyy + 6]
        front = [p for p in pts if p[1] >= cyy + 6]
        cols = [(55, 55, 70), (70, 55, 60), (60, 70, 60), (80, 70, 55)]
        draw_table(g, it, "back")   # 先椅背、一圈椅子
        for p in sorted(back, key=lambda p: p[1]):
            draw_sitter(g, int(p[0]), int(p[1]), cols[rng.randrange(4)])   # 后排的人坐在椅背前面
        draw_table(g, it, "top")    # 桌面盖住后排人的腿
        for p in sorted(front, key=lambda p: p[1]):
            draw_sitter(g, int(p[0]), int(p[1]), cols[rng.randrange(4)])
        vx0 = CX - VIEW[0] // 2
        if fx + fw > vx0 and fx < vx0 + VIEW[0] and fy + fh > y0 and it["box"][1] < y0 + VIEW[1]:
            seated += n   # 只数这一屏里看得见的桌
    # 红毯上两个服务员
    wy = [rows_y[r0 + 1] + 20, rows_y[r1 - 1] + 60]
    draw_stander(g, CX - 30, wy[0], (40, 40, 40))
    draw_stander(g, CX + 20, wy[1], (40, 40, 40))
    vx = CX - VIEW[0] // 2
    im.crop((vx, y0, vx + VIEW[0], y0 + VIEW[1])).resize((540, 960), Image.NEAREST).save(out_path)
    return y0, seated


def table_rows(items, only_north=False):
    out = []
    for it in items:
        x, y, w, h = it["box"]
        fx, fy, fw, fh = it["foot"]
        if only_north and (y >= 1024 or it["kind"] == "zone"):
            continue
        cut = ""
        if only_north and y + h > 1024:
            cut = "被切（露出 %d）" % (1024 - y)
        foot = "同框（平的）" if it["foot"] == it["box"] else "%d, %d, %d×%d（落地线 %d）" % (fx, fy, fw, fh, fy + fh)
        note = "（只在标注版）" if it["kind"] == "mark" else ""
        row = "| %s%s | %d | %d | %d | %d | %s |" % (it["name"], note, x, y, w, h, foot)
        row += (" %s |" % cut) if only_north else ""
        row += " %s |" % it["basis"]
        out.append(row)
    return out


def table_md(items, bad, gaps):
    lines = ["# 宴会厅 55 桌 · 摆位表（02，9/29，v3.3）", "",
             "> 01 D 9/25 派。画布 %d×%d，1:1（人 84）。坐标单位画布像素，x、y 是左上角。依据：ASSETS §15（左右和高 1 米 = 48、地面前后 1 米 = 32）、04 `体验-第47版-55桌.md`、03 `比例量尺-55桌摆位底图v2.md`、方案 `宴会厅55桌-方案.md`。脚本 `tools/layout_55/make_board55.py`，改数重跑。" % (W, H),
             "> **v3：x、y、宽、高是画出来在画面上占的框（色块画的就是它），下沿是落地的地方；「占地」列是地上占的地（走路判定用），平的东西两个一样。**",
             "", "| 名字 | x | y | 宽 | 高 | 占地（x, y, 宽×高） | 依据 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    lines += table_rows(items)
    lines += ["", "## 自检", ""]
    lines += ["- " + b for b in bad] if bad else [
        "- 比例：每样都照 §15 的数取（取值见「依据」列），没有大过 1.5 倍、小过一半的",
        "- 画面上谁也不压谁：按画出来的框比。可以叠的只有：墙上的梁、帐幔、挂灯、花拱、囍贴北墙；台面、台口、台阶、新人脚印是一座台子；乐队站在地台上、坐着的人坐在凳子椅子上。立着的东西画出来挡住它后面的地面（红毯、地面）不算压",
        "- v3.2 起桌下没有地毯了（阿鱼：太乱），中间红毯留着",
        "- v3.3 主桌大一号（阿鱼 9/29：出阁宴，主桌坐阿鱼家 13 位）：2.2 米大圆桌，占地 160×106，画出来 160×152；台前宫灯跟着往上 7；别的桌不动",
        "- 主桌 + T1～T54（55 桌），每张都能从红毯走到；走路按占地算，路按人宽 43 算（离挡路的东西 21 像素以内不算能站）",
        "- 手机顶上 140 那条里只有墙顶横梁、帐幔、挂灯；囍、花拱都整个在 150 以下",
        "- 乐队的钢琴、琴凳、椅子、谱架和 4 个人，占地都在乐队地台里",
        "- 所有东西都在画布里（v2 表里的「挂灯 8」出了画布，v3 挂灯只挂在帐幔之间的 7 条缝里）"]
    lines += ["- **行与行之间画面上露出的地面，最窄 %d**（前一排桌画出来的前沿到后一排椅背）" % gaps]
    return "\n".join(lines) + "\n"


def main():
    items, tid, door, stand_top, rail_foot = build()
    bad = check(items)
    gaps = row_gaps(items)
    os.makedirs(OUT, exist_ok=True)
    clean = draw([it for it in items if it["kind"] != "mark"], False, tid, door, stand_top, rail_foot)   # 干净版不画新人脚印（v3.1，03：表里写「只在标注版」）
    clean.save(os.path.join(OUT, "宴会厅55桌-摆位底图.png"))
    draw(items, True, tid, door, stand_top, rail_foot).save(os.path.join(OUT, "宴会厅55桌-摆位底图-标注.png"))
    vx = CX - VIEW[0] // 2
    clean.crop((vx, H - VIEW[1], vx + VIEW[0], H)).resize((540, 960), Image.NEAREST).save(os.path.join(OUT, "宴会厅55桌-手机屏-进门.png"))
    clean.crop((vx, 0, vx + VIEW[0], VIEW[1])).resize((540, 960), Image.NEAREST).save(os.path.join(OUT, "宴会厅55桌-手机屏-舞台.png"))
    open(os.path.join(OUT, "宴会厅55桌-摆位表.md"), "w", encoding="utf-8").write(table_md(items, bad, gaps))
    my, seated = middle_with_people(items, tid, door, stand_top, rail_foot, os.path.join(OUT, "宴会厅55桌-手机屏-中间.png"))
    print("手机屏-中间：画布 y %d～%d（含），这一屏里的桌坐了 %d 人（每桌 9～10）、红毯上 2 个服务员" % (my, my + VIEW[1] - 1, seated))
    print("画布 %d×%d，东西 %d 件，主桌 + T1～T%d" % (W, H, len(items), N_T))
    print("自检：", "全过" if not bad else bad)
    print("行与行之间画面上露的地面最窄 %d" % gaps)
    print("排：", rows_y)
    return 0 if not bad else 1


NORTH_RULER_FOOT = (CX, 610)   # 北边那块的尺子：红毯正中、台前两盏宫灯和第 1 排之间，不压任何东西


def north(out_dir):
    """切北边那块（y 0～1024）给 GPT 画效果图用（01 D 9/25）：
    干净版去掉新人脚印、在红毯上站一个 84 像素的人当尺子；标注版同一块；表只列落在这块里的，被下沿切掉的标「被切」"""
    items, tid, door, stand_top, rail_foot = build()
    bad = check(items)
    fx, fy = NORTH_RULER_FOOT
    b = (fx - 16, fy - PERSON, 32, PERSON)
    ruler = {"name": "尺子：人（北边）", "kind": "ruler", "box": list(b), "foot": list(standing(b, 10)), "color": (20, 20, 20),
             "basis": "§15 人 84、宽 32（画的人撑满 32×84）；脚点 (%d, %d)，站在红毯正中" % (fx, fy), "group": "", "flat": False}
    for it in items:   # 尺子画出来的框不许压任何立着的东西（红毯是地面，站在上面不算）
        if not it["flat"] and it["kind"] not in ("zone",) and overlaps(it["box"], ruler["box"]):
            bad.append("北边尺子压着 %s" % it["name"])
    no_feet = [it for it in items if it["kind"] not in ("mark", "ruler")] + [ruler]
    with_feet = [it for it in items if it["kind"] != "ruler"] + [ruler]
    clean = draw(no_feet, False, tid, door, stand_top, rail_foot).crop((0, 0, W, 1024))
    ann = draw(with_feet, True, tid, door, stand_top, rail_foot).crop((0, 0, W, 1024))
    os.makedirs(out_dir, exist_ok=True)
    clean.save(os.path.join(out_dir, "claude-55桌摆位-北-干净.png"))
    ann.save(os.path.join(out_dir, "claude-55桌摆位-北-标注.png"))
    lines = ["# 宴会厅 55 桌摆位表 · 北边那块（y 0～1024，v3.3）", "",
             "> 02 9/25。从整厅摆位底图（1536×%d，v3；脚本 `godot/tools/layout_55/make_board55.py --north`）切出北边 1536×1024，给 GPT 画效果图用。坐标是整厅的，这块左上角就是整厅 (0,0)，数不用换算。" % H,
             "> **x、y、宽、高是画出来在画面上占的框（色块画的就是它），下沿是落地的地方；「占地」是地上占的地。**干净版：没有字、没有新人脚印，只在红毯上站一个 84 像素的人当尺子（脚点 (%d, %d)）。新人站位只在标注版里标。被下沿（y 1024）切掉一截的标「被切」，宽高写的是整件的。" % (fx, fy),
             "", "| 名字 | x | y | 宽 | 高 | 占地（x, y, 宽×高） | 被切 | 依据 |", "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    rows = table_rows(with_feet, only_north=True)
    lines += rows
    open(os.path.join(out_dir, "claude-55桌摆位表-北.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("北边：%d 件；尺子脚点 %s；自检 %s" % (len(rows), NORTH_RULER_FOOT, "全过" if not bad else bad))
    return 0 if not bad else 1


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--north":
        sys.exit(north(sys.argv[2]))
    sys.exit(main())
