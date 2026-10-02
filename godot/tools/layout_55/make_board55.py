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
v4（01 D 9/30，GPT 交了北边空厅背景 base_banquet55_north_v1.png，**背景说了算**）：北边的东西照背景里量出来的位置摆：
  北墙脚 236、婚礼台 528～1008（台面 234～297、台口立面 297～322）、台阶 692～844 下沿 342、红毯从 342 往南、
  乐队地台 1062～1399 前沿 432（钢琴、琴凳、椅子、大提琴、两个谱架都画在背景里，没有乐手）、贺礼堆 387～456 脚 452。
  桌子整体往北挪 120（第 1 排桌心 682 → 562）：第 1 排椅背离贺礼堆脚留 2 米走道（贺礼堆在 T1 正北，是最靠南的一样）；
  行距 180、列距 203、跨红毯 320、空位、桌号都不动；画布跟着短 120（2714 → 2594）
v5（01 D 9/30，阿鱼「按我选的来」：家具照 GPT 效果图 d 的大小；GPT 重画的桌、宫灯、花架还没交，先用色块）：
  桌连椅子 170 宽、画出来 168 高（照零件 140:138 的比例），占地 170×112（照 140×92 放大 1.21 倍）、椅背往上冒 56；
  列距照 d 同一边桌与桌的间距取 215（每边 3 列：离红毯 12、桌与桌之间 45 只够一个人、离墙 44），行距照 d 取 205，横走道占地之间 128 不动；
  第 1 排照 d：贺礼堆西边、东边各一张（西边那张是主桌），红毯东边一张，椅背贴着台口；乐队前、贺礼堆那三个位空着；
  宫灯照 d 换大的（28×118，带灯座）：台前一对照 d 的位置（脚 445），往南的在两条横走道里；墙边的照 d 从脚 680 起每 300 一根；
  花架照 d（44×104）：北墙脚两边各一个、台子两个后角各一个；小花盆照 d 挪到贺礼堆东边、乐队西边；长凳让出桌位，挪到进门那块
v6（01 D 9/30，嫌 v5 每排 6 张比 d 挤）：照 d 的疏密每排 4 张，红毯两边各 2 张：列的位置照 d 第 2 排量（x 373、573、963、1163），
  行距 205；第 1 排照旧照 d（贺礼堆西、主桌、红毯东）；55 桌 + 主桌一排排往南：第 1 排 3 张 + 13 排×4 = 55；
  横走道照原来的规矩每 3～4 排一条（3 + 4 + 4 + 3 排，三条）；红毯宫灯照 d 每隔一排一对，立在红毯边和靠红毯那张桌之间；
  长凳回到 d 的位置（第 2 排西头外侧）；东侧门还开在第二条横走道东头，大门跟着厅长往南挪
v9（01 D 9/30 晚，阿鱼给了新北边 base_banquet55_north_v2.png）：贺礼架、乐队台跟婚礼台一条线；第 1 排改回常规四列（乐队台前照旧空），桌心 y 不动（台口还是 322）。
v7（01 D 9/30，GPT 南边包交了）：桌、主桌照零件实际 180×150 摆（画出来的框），占地照零件里椅子外沿量 146×100（椅背往上冒 50）；
  大宫灯 48×112、花架 56×112（零件实际大小）；疏密照旧照 d（每排 4 张、行距 205、第 1 排照 d）；
  最南头 1024 垫 GPT 南边那张背景：东侧门、大门、栏杆都照那张图量（那张图里门洞 706～826、门柱 640～900、门槛 890～905、
  栏杆顶 958、脚 1000、东侧门 193～251）；厅长到最后一排桌前沿离门柱上沿留 40
      （阿鱼 9/28：「都有地毯的话看起来太乱了，先不要地毯」）：55 桌和主桌下面的地毯全删，中间红毯留着；行距、列距、画布一个数不动
v10（10/2 阿鱼「那就 C 吧」，01 E 锁死）：默认排法换成 C——每边 3 列错开、左右留 45、斜着那条过道 70、行距 153、整厅 2091；
  不留横走道；红毯两边每排一根灯；主桌第 1 排红毯西边第一张；舞台西边地上礼物堆 10 份（B55S-P05）；排法细节见下面「重排」那段
v11（10/2 阿鱼「太整齐了」，挑了「乱得自然」第 1 档，01 E 锁死）：默认 C + 第 1 档（MESS_LEVELS），一排排歪一点、桌有前有后、几对凑近
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
WALL = 46                     # 两边墙厚：GPT 北边、南边两张背景里都画成 46（03 10/2 量；原来写 40，人能走进墙里 6 像素）。
                              # 走路格子、墙的框、贴墙的长凳、栏杆照它；桌子的位置是锁死的排法（C + 第 1 档），不跟着挪
PERSON = 84
VIEW = (576, 1024)            # 手机竖屏一屏看到的画布（540×960，镜头 960/1024）

# ---------- 桌位 ----------
TABLE = (146, 100)            # v7：桌连一圈椅子的占地（照 GPT v2 桌子零件里椅子外沿量：19～164 宽，脚下那一截 100 深）
CHAIR_UP = 50                 # v7：后排椅背往上冒 50
TABLE_BOX = (180, 150)        # v7：画出来的框就是零件图 180×150，脚点在下沿正中
RUG = (190, 125)              # v3.2 起桌下地毯删了（阿鱼：太乱）；这个数只留着定南边那块空地从哪起、中间屏切到哪，画布大小不变
COL_IN_OFF = 195               # v6：靠红毯那列桌心离红毯中线 195（照 d 第 2 排量：574、963）
COL_OUT_OFF = 395              # v6：靠墙那列离红毯中线 395（照 d 第 2 排量：376、1166）
COLS = [CX - COL_OUT_OFF, CX - COL_IN_OFF, CX + COL_IN_OFF, CX + COL_OUT_OFF]   # 373、573、963、1163
ROW0 = 422                    # v7 第 1 排桌心：照 d，零件图上沿 322 贴着台口立面下沿（v9 北边换 v2 背景，台口还是 322，不动）
# v9（01 D 9/30）：北边 v2 背景里贺礼架、乐队台跟婚礼台前沿一条线（288、325），不再往南伸，第 1 排不用躲它们，照常用 COLS；
# v7 那三张（贺礼堆西 235、主桌 550、红毯东 975）是躲 v1 背景里伸到 452、432 的贺礼堆和乐队台
ROW0_X = {}
PITCH = 205                   # v5 行距：照 d 量的 184～222 取中；占地之间 93，画面上前一排前沿到后一排椅背 37
CROSS_GAP = 128               # 横走道：占地之间 128（4 米），v3 不动
CROSS_AFTER = (2, 6, 10)      # v6：第 3、7、11 排后面各一条横走道：3 + 4 + 4 + 3 排
SOUTH_BG_H = 1024             # GPT 补南边那张背景的高：整厅最南头这一截留给它（01 D 9/30）
SOUTH_SIDE_DOOR = (193, 251)  # 那张图里东侧门的上下（v7 照图核过：东墙上 190～250 那个门洞看得见外面）
# v7 照 GPT 南边那张量的（那张图里的坐标，y 从它上沿算）
SOUTH_DOOR_POSTS = (640, 830, 260, 170)   # 大门门柱、开着的两扇门：x 640～900、y 830～1000
SOUTH_DOORWAY = (706, 826)                # 门洞里能走的那一截
SOUTH_THRESHOLD = 890                     # 红毯到门槛这儿断（890～905 是金门槛）
SOUTH_RAIL = (958, 1000)                  # 栏杆顶、脚
SOUTH_GAP = 40                            # 最后一排桌（零件下沿）离门柱上沿至少这么多
NROWS = 14                    # v6：第 1 排 3 张 + 13 排×4 张 = 55 张（含主桌）
rows_y = []
y = ROW0
for r in range(NROWS):
    rows_y.append(y)
    y += (TABLE[1] + CROSS_GAP) if r in CROSS_AFTER else PITCH
# 60 个位：主桌 + T1～T54 一共 55 桌（01 定的默认「55 桌含主桌」，还没跟阿鱼核过），空 5 个
MAIN = (0, 1)   # 第 1 排贺礼堆东边那张（x 550）
# v3.1（04 新 2：最南一排只剩 3 张、缺口正对进门，冷清不对称）：最南一排补回东头那张，4 张左右对称；
# 多出来的那个空位挪到第 1 排最东——正对乐队地台，客人能站着看乐队，和西头放长凳的空位左右对称，离大门最远
EMPTY = {(0, 3): "v6：乐队台前（照 d 空着；v9 照旧空着，站这儿看乐队）"}
N_T = 54

# ---------- 重排（01 E 10/2 插队，阿鱼看了色块图：「堆多点礼物，餐桌摆的更紧实一点」，要现场效果图那种感觉） ----------
# SUQI55_LAYOUT=A / B 时换下面这套，不设就是上面 v9 那套（main 的默认厅不动）：
#   每边 3 列、一排一排错开（单数排往墙那边挪半个桌位）、不留横走道；红毯两边每排一根灯；
#   主桌在第 1 排红毯西边第一张；第 1 排西边那两个位让给舞台左边地上的礼物堆（B55S-P05 96×80 摆十份）；
#   「刚好贴着」= 桌连椅子的占地（146×100）碰上。两个距离分开算：
#     GAP   同一排左右两张桌占地之间（列距 = 146 + GAP）
#     DIAG  错开的上下两排、斜着那两张桌占地之间（行距照它算：最小的整数）
#   A：两个都 35（01 D 10/1 方案 A）。
#   B：01 E 要「各再紧 20」——两个都 20 的话，游戏里人离桌子要留 12（walk 格子），20 的缝过不去，550 把椅子 198 把走不到；
#      都试过，两个一起收只有到 34 才全走得到，跟 A 没区别。所以 B 只收同一排左右（20），斜着那条过道留 35：
#      错开排的过道是一条条之字形横着通到红毯的，左右那条缝不走人也能到每把椅子（02 10/2 试出来的）
# v10（10/2，阿鱼「那就 C 吧」，01 E 锁死）：默认就是 C。这张摆位表是 55 桌厅零件规格的唯一源（00 10/2 指导第四节）。
# SUQI55_LAYOUT=A/B/D 还能出别的几档对比；=v9 出锁死之前那版（每边 2 列、有横走道）
LAYOUT = os.environ.get("SUQI55_LAYOUT", "C")
if LAYOUT == "v9":
    LAYOUT = ""
#   C、D（01 E 10/2，阿鱼看了 A：「我想更松一点，现在太挤了，跟菜市场似的」；第 44/52 版又嫌空，要中间）：
#      排法照 A，只放宽过道。每边 3 列错开，左右最多留 45 就碰墙了（墙 40 到红毯边那根灯 667 一共 627 宽，
#      2.5 个列距 + 一张桌）；所以左右都 45，斜着那条过道（人走的之字形横道）C 放到 70、D 放到 100
GAP = int(os.environ.get("SUQI55_GAP", {"A": "35", "B": "20", "C": "45", "D": "45"}.get(LAYOUT, "0")))
DIAG = int(os.environ.get("SUQI55_DIAG", {"A": "35", "B": "35", "C": "70", "D": "100"}.get(LAYOUT, "0")))
GIFT = (96, 80)               # B55S-P05 礼物堆（零件总表，约 96×80）
# 乱的程度（01 E 10/2，阿鱼：「太整齐了，实际上宴会厅不会真的整齐的，氛围感不是这样的」）：SUQI55_MESS=1/2/3 在 C 上打乱，
#   10/2 阿鱼挑了第 1 档（原话「1」，01 E 锁死）：默认就是 C + 第 1 档；SUQI55_MESS=0 退回 C 原样，=2、3 还能出另两档。不是每张随便抖一下，照真现场分三步：
#     ① 一排排不再一条直线：每排每边各自前后错一点、左右整体挪一点（3、2 交替那个错开就不齐了）；
#     ② 每张再自己偏一点；
#     ③ 挑一些挨着的两张拉近（服务员摆的时候两张凑一块），别处自然就松出来。
#   然后照「占地之间至少留多少」一遍遍推开，推不出墙、红毯边那排灯、北边台口，东侧门口、西墙长凳那块不进桌。
#   55 桌、主桌位置、厅长、墙都不动；疏密跟 C 一样（同样的地方放同样多的桌）
MESS = int(os.environ.get("SUQI55_MESS", "1")) if LAYOUT == "C" else 0   # 别的排法（A/B/D/v9）不打乱
MESS_LEVELS = {
    #    row: 每排前后错  shift: 每排左右挪  ax/ay: 每张自己偏  pairs: 拉近几对  pull: 拉近多少
    #    gap: 一般两桌占地之间至少  close: 拉近那几对至少  spread: 松开时往这么宽匀  seed: 随机种子（挑过：寻路全过、看着不像格子）
    1: dict(row=10, shift=30, ax=14, ay=10, pairs=6, pull=24, gap=38, close=26, spread=70, seed=1),
    2: dict(row=18, shift=55, ax=26, ay=18, pairs=10, pull=40, gap=34, close=22, spread=70, seed=4),
    3: dict(row=24, shift=90, ax=45, ay=30, pairs=14, pull=55, gap=30, close=20, spread=70, seed=6),
}


def _ellipse_gap(dx, dy, a=TABLE[0] / 2.0, b=TABLE[1] / 2.0, n=360):
    """两个一样大的占地椭圆，圈心差 (dx, dy)，边到边最近多远（数值算）"""
    import math
    p = [(a * math.cos(2 * math.pi * k / n), b * math.sin(2 * math.pi * k / n)) for k in range(n)]
    return min(math.hypot(x1 - x2 - dx, y1 - y2 - dy) for x1, y1 in p for x2, y2 in p)


if LAYOUT:
    PITCH_X = TABLE[0] + GAP
    PITCH = next(r for r in range(60, 400) if _ellipse_gap(PITCH_X / 2.0, r) >= DIAG)
    LAMP_FOOT_X = CX - 72 - 4 - 38 + 13          # 红毯西边那根灯的占地左沿（667）
    _hi = LAMP_FOOT_X - TABLE[0] // 2 - 1         # 靠红毯那张桌占地右沿不碰灯
    _lo = 40 + 1 + TABLE[0] // 2 + 2.5 * PITCH_X  # 单数排最靠墙那张占地左沿不碰墙
    assert _lo <= _hi, "每边 3 列错开放不下：加的距离 %d 太大" % GAP
    X_IN = int(round((_lo + _hi) / 2.0))           # 两头离灯、离墙一样多
    COLS = []
    NROWS = 10                                     # 第 1 排 4 张（主桌 + 东边 3）+ 9 排 × 6 = 58 个位，空 3 个 → 55
    ROW0 = 430                                     # 第 1 排桌心：零件上沿 330，在台口（322）、乐队台前沿（325）下面
    rows_y = [ROW0 + r * PITCH for r in range(NROWS)]
    CROSS_AFTER = ()

# ---------- 北边 ----------
# v4：下面这些都是从 GPT 背景 base_banquet55_north_v1.png 上量的（02 9/30）
# v9：北边换 base_banquet55_north_v2.png（阿鱼 9/30「舞台要放这儿」）：北墙脚、台前沿、台阶、红毯没变；
# 婚礼台窄了（555～999）；贺礼架挪到台子西边贴着台（487～555、脚 288）；乐队台往北、往西（1014～1348、前沿 325）
WALL_N = 236                  # 北墙脚（地砖从这一行开始）
STAGE_FOOT = (555, 236, 444, 86)    # 婚礼台占地：贴着北墙，前沿（台口立面下沿）322
STAGE_UP = 25                 # 台口立面高 25（297～322）
STAGE_BOX = (555, 234, 444, 88)     # 画出来：台面 234～297 + 台口立面 297～322，落地线 322
STAGE_TOP = (555, 234, 444, 63)
STAGE_FACE = (555, 297, 444, 25)
STEP_W = 152                  # 台阶：背景里 692～844，比红毯两边各宽 4
STEPS_FOOT = (692, 322, STEP_W, 20)   # 两级，下沿 342
ARCH = (636, 76, 264, 160)    # 花拱（背景里画好的，量的外框）
XI = (704, 110, 126, 126)     # 囍字圆牌（背景里画好的）
COUPLE_FEET = [(CX - 16, 285), (CX + 16, 285)]   # 新人站位：台面中间、囍字正前方
CARPET_TOP = 342              # 红毯从台阶下沿往南铺（背景里 696～840，144 宽）
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
    # v7：厅长由 GPT 南边那张定——最后一排桌（零件下沿）离那张图里门柱上沿 SOUTH_GAP，南边那张垫在最南头
    last_front = rows_y[-1] + TABLE[1] // 2
    south_top = last_front + SOUTH_GAP - SOUTH_DOOR_POSTS[1]
    H = south_top + SOUTH_BG_H
    stand_top = south_top + SOUTH_THRESHOLD - 96   # 进门站的地方：门槛里边 96（3 米）
    rail_foot = south_top + SOUTH_RAIL[1]
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
    side_bottom = south_top + SOUTH_RAIL[0]   # 两边墙画到栏杆顶
    add("西墙", "wall", (0, WALL_N, WALL, side_bottom - WALL_N), wood, "墙厚 %d（GPT 两张背景里量的，§15 没有）；俯看是一条，平的" % WALL, flat=True)
    # 东侧门（v6 更正，01 D 9/30）：GPT 补南边那张背景就是整厅最南头 1024 高一截，门画在那张图里 y 193～251；
    # 背景说了算，这里照它算：整厅 y = (H - 1024) + 193～251。图没到之前色块也先摆在这
    d0, d1 = south_top + SOUTH_SIDE_DOOR[0], south_top + SOUTH_SIDE_DOOR[1]
    add("东墙（北段）", "wall", (W - WALL, WALL_N, WALL, d0 - WALL_N), wood, "墙厚 %d；平的" % WALL, flat=True)
    add("东墙（南段）", "wall", (W - WALL, d1, WALL, side_bottom - d1), wood, "墙厚 %d；平的" % WALL, flat=True)
    add("东侧门（门洞）", "door", (W - WALL, d0, WALL, d1 - d0), (60, 140, 200), "§15 双开门宽 1.8 米；开在东墙上，宽沿地面前后算：1.8×32=58；开在第二条横走道东头", flat=True)
    # 北墙上的：花拱、囍（v3.2 横幅删了）
    add("花拱", "decor", ARCH, (70, 130, 70), "宽 5 米×48=240、高 3.75 米×48=180（§15 没有）", "wall_decor")
    add("囍字圆牌", "decor", XI, (215, 170, 60), "直径 2 米×48=96（§15 没有）", "wall_decor")
    # 婚礼台、台阶、新人
    add("婚礼台（台面）", "stage", STAGE_TOP, (214, 78, 66), "v9 照 v2 背景量：555～999、台面 234～297，贴北墙", "stage", foot=STAGE_FOOT)
    add("婚礼台（台口立面）", "stage", STAGE_FACE, (112, 24, 24), "v9 照 v2 背景量：立面 297～322，落地线 322", "stage", foot=(555, 306, 444, 16))
    add("台阶", "stage", up(STEPS_FOOT, STAGE_UP), (190, 120, 96), "v4 照背景量：692～844、两级、下沿 342", "stage", foot=STEPS_FOOT)
    for i, (fx, fy) in enumerate(COUPLE_FEET):
        add("新人站位%s" % ("（新娘）" if i == 0 else "（新郎）"), "mark", (fx - 12, fy - 4, 24, 8), (255, 255, 255),
            "台面中间、囍字正下方；只标脚下 y %d。人 84 高，头顶到 y %d，在囍字下沿 %d 下面、不挡囍" % (fy, fy - PERSON, XI[1] + XI[3]), "stage_decor")
    # 红毯、宫灯、花盆
    carpet_bottom = south_top + SOUTH_THRESHOLD   # v7：红毯铺到南边背景里的门槛
    add("红毯", "floor", (CX - 72, CARPET_TOP, 144, carpet_bottom - CARPET_TOP), (179, 32, 42), "3 米×48=144（方案）；从台阶下沿到大门门槛", flat=True)
    LAMP = (48, 112)   # v7：GPT v2 大落地宫灯零件实际大小（看得见的灯是中间 13～38 那一截）

    def lamp_pair(y_foot, tag):
        # 看得见的灯（零件里 13～38）离红毯 4；零件两边是透明的，框会和靠红毯那张桌的透明边搭上一点
        for side, x in (("西", CX - 72 - 4 - 38), ("东", CX + 72 + 4 - 13)):
            b = (x, y_foot - LAMP[1], LAMP[0], LAMP[1])
            add("红毯%s侧落地宫灯（%s）" % (side, tag), "prop", b, (240, 200, 60), "v7：GPT v2 大宫灯 48×112；占地是最下面 14", foot=(b[0] + 13, b[1] + b[3] - 14, 25, 14))

    def stand(name, cx, y_foot, group=""):
        b = (cx - 28, y_foot - 112, 56, 112)
        add(name, "prop", b, (60, 140, 60), "v7：GPT v2 花架 56×112；占地最下面 16", group, foot=standing(b, 16))

    def pot(name, x, y_foot):
        b = (x, y_foot - 32, 32, 32)
        add(name, "prop", b, (90, 170, 90), "§15 一盆花 24～38，取 32；占地是最下面 16", foot=standing(b, 16))

    # v6 照 d：每隔一排一对，立在红毯边和靠红毯那张桌之间；脚比那排桌心往南 11（d：第 1 排脚 445、第 3 排脚 818）
    for r in range(0, NROWS, 1 if LAYOUT else 2):   # 重排：现场图里每排一根
        lamp_pair(rows_y[r] + 23, "第 %d 排" % (r + 1))   # d 第 1 排的脚 445，v7 第 1 排桌心 422
    # 小花盆：v9 贺礼架贴着台子、乐队台贴着台子东边，原来那两个位置（贺礼堆东、乐队西）没了；
    # 挪到这一排东西的两头：贺礼架西边、乐队台东边，脚跟它们前沿齐
    if LAYOUT:
        pot("花盆（礼物区西）", 148, 322)   # 重排：贺礼架西边那块让给礼物堆，花盆挨着礼物堆西头（04 10/2：原来靠墙孤零零）
    else:
        pot("花盆（贺礼架西）", 448, 288)
    pot("花盆（乐队东）", 1352, 325)
    # 花架照 d：北墙脚两边各一个，台子两个后角各一个（台上那两个算台子的一部分，不挡路）
    stand("花架（北墙西）", 147, 256)
    stand("花架（台西后角）", 583, 256, "stage_decor")   # v9 台子西沿 555，贺礼架贴在外边：花架往里收，不压贺礼架
    stand("花架（台东后角）", 968, 256, "stage_decor")
    stand("花架（北墙东）", 1390, 256)
    # 墙边宫灯：照 d 从脚 680 起每 300 一根（和台前那对同一款），东边躲开侧门
    for yf in ([] if LAYOUT else range(680, side_bottom - 40, 300)):   # 重排：最靠墙那列贴着墙，墙边落地灯放不下，撤掉
        b = (47 - 24, yf - LAMP[1], LAMP[0], LAMP[1])
        add("西墙边宫灯（y %d）" % yf, "prop", b, (230, 170, 60), "v7：墙边大宫灯 48×112，x 47 居中（照 d）；占地最下面 14", foot=(b[0] + 13, b[1] + b[3] - 14, 25, 14))
        if not (d0 - 20 < yf < d1 + 130):
            b = (W - 47 - 24, yf - LAMP[1], LAMP[0], LAMP[1])
            add("东墙边宫灯（y %d）" % yf, "prop", b, (230, 170, 60), "v7：墙边大宫灯 48×112；占地最下面 14", foot=(b[0] + 13, b[1] + b[3] - 14, 25, 14))
    # 乐队（v4：背景里画好的地台和乐器——钢琴、琴凳、椅子、大提琴、两个谱架，没有乐手；这里只记它占的地方）
    add("乐队地台（背景里画好的）", "band_floor", (1014, 165, 334, 160), (120, 40, 50),
        "v9 照 v2 背景量：地台 1014～1348、台面 222～315、前沿 325；钢琴顶到 165。背景里没画乐手", "band", foot=(1014, 222, 334, 103))
    # 礼物堆（v4：背景里画好的，台子西边地上）
    add("贺礼堆（背景里画好的）", "prop", (487, 182, 68, 106), (230, 120, 120), "v9 照 v2 背景量：贺礼架 487～555、顶 182、脚 288，贴着台子西沿", foot=(487, 256, 68, 32))
    def add_south():
        px0, py0, pw, ph = SOUTH_DOOR_POSTS
        b = (px0, south_top + py0, pw, ph)
        add("大门（门柱和开着的两扇门，南边背景里画好的）", "door", b, (60, 140, 200), "v7 照南边背景量：门柱 640～900、门洞 706～826；落地线 %d" % rail_foot, foot=standing(b, 8))
        b = (WALL, south_top + SOUTH_RAIL[0], px0 - WALL, SOUTH_RAIL[1] - SOUTH_RAIL[0])
        add("南边西段栏杆", "wall", b, (120, 80, 50), "v7 照南边背景量：顶 958、脚 1000（那张图里）", foot=standing(b, 8))
        b = (px0 + pw, south_top + SOUTH_RAIL[0], W - WALL - (px0 + pw), SOUTH_RAIL[1] - SOUTH_RAIL[0])
        add("南边东段栏杆", "wall", b, (120, 80, 50), "v7 照南边背景量", foot=standing(b, 8))
        add("进门站的地方", "zone", (CX - 150, stand_top, 300, 96), None, "门槛里边空出来的地面：宽 300、前后 3 米（96）", flat=True)

    if LAYOUT:
        _relayout_tables(add, items, d0, d1)
        # v10（01 E 10/2）：排法 C 原来摆完桌就 return，南边背景里画好的大门、栏杆、进门站的地方没进摆位表（03 导南边时自己补的）；
        # 摆位表是唯一源，这几件跟 v9 一样放进来，比例尺小人也放
        add_south()
        b = (CX + 90, stand_top + 96 - 4 - PERSON, 32, PERSON)
        add("尺子：人", "ruler", b, (20, 20, 20), "§15 人 84；宽 32（画的人整个撑满这 32×84）", foot=standing(b, 10))
        return items, _relayout_tables.tid, (d0, d1), stand_top, rail_foot

    # 桌、长凳（v3.2 桌下地毯删了）
    def col_x(r, c):
        return ROW0_X[c] if r == 0 and c in ROW0_X else COLS[c]
    ids = []
    for r in range(NROWS):
        cols_r = range(3) if r == 0 else range(len(COLS))
        slots = [c for c in cols_r if (r, c) not in EMPTY and (r, c) != MAIN]
        slots.sort(key=lambda c: (abs(col_x(r, c) - CX), col_x(r, c)))
        ids += [(r, c) for c in slots]
    tid = {rc: "T%d" % (i + 1) for i, rc in enumerate(ids)}
    assert len(tid) == N_T
    for r in range(NROWS):
        for c in (range(3) if r == 0 else range(len(COLS))):
            cx, cy = col_x(r, c), rows_y[r]
            if (r, c) in EMPTY:
                continue
            name = "主桌" if (r, c) == MAIN else tid[(r, c)]
            tf = (cx - TABLE[0] // 2, cy - TABLE[1] // 2, TABLE[0], TABLE[1])
            tb = (cx - TABLE_BOX[0] // 2, cy + TABLE[1] // 2 - TABLE_BOX[1], TABLE_BOX[0], TABLE_BOX[1])
            add(name, "table", tb, (220, 70, 60) if name != "主桌" else (240, 190, 60),
                "v7：GPT v2 桌子零件 180×150（脚点下沿正中），占地照椅子外沿 146×100", "table:" + name, foot=tf)
    add_south()
    # 长凳（v6）：回到 d 的位置——第 2 排西头外侧（d 量的 146～218、脚 555）
    bf = (146, 555 - 16, 72, 16)
    add("长凳", "prop", up(bf, 38), (120, 200, 255), "§15 长凳 宽 72、高 38；v6 照 d：第 2 排西头外侧", foot=bf)
    b = (CX + 90, stand_top + 96 - 4 - PERSON, 32, PERSON)
    add("尺子：人", "ruler", b, (20, 20, 20), "§15 人 84；宽 32（画的人整个撑满这 32×84）", foot=standing(b, 10))
    return items, tid, (d0, d1), stand_top, rail_foot


def _relayout_tables(add, items, d0, d1):
    """重排的桌、长凳、礼物堆。位：(排, 第几个)，第几个 0～2 是西边从红毯往墙、3～5 是东边从红毯往墙"""
    def slot_x(r, k):
        side, i = divmod(k, 3)
        x = X_IN - i * PITCH_X - (PITCH_X / 2.0 if r % 2 else 0)
        return int(round(x if side == 0 else 2 * CX - x))
    empty = {(0, 1): "礼物堆", (0, 2): "礼物堆", (1, 2): "长凳"}
    # 东侧门（东墙上 d0～d1）：门口那排最靠东墙那张空出来，西边同一排对称也空一张
    door_r = min(range(NROWS), key=lambda r: abs(rows_y[r] - (d0 + d1) / 2.0))
    if door_r in (0, 1):
        door_r = 2
    empty[(door_r, 5)] = "东侧门口"
    empty[(door_r, 2)] = "跟东侧门口对称"
    main = (0, 0)
    slots = [(r, k) for r in range(NROWS) for k in range(6) if (r, k) not in empty and (r, k) != main]
    slots.sort(key=lambda rk: (rk[0], abs(slot_x(*rk) - CX), slot_x(*rk)))
    assert len(slots) == N_T, "重排的空位算错了：%d 个位" % len(slots)
    tid = {rk: "T%d" % (i + 1) for i, rk in enumerate(slots)}
    _relayout_tables.tid = tid
    _relayout_tables.empty = empty
    pos = {(r, k): (slot_x(r, k), rows_y[r]) for r in range(NROWS) for k in range(6) if (r, k) not in empty}
    by = rows_y[1] + 4   # 长凳落脚那一行（下面摆长凳也用）
    if MESS:
        pos = _mess(pos, main, d0, d1, by, empty)
    for r in range(NROWS):
        for k in range(6):
            if (r, k) in empty:
                continue
            cx, cy = pos[(r, k)]
            name = "主桌" if (r, k) == main else tid[(r, k)]
            tf = (cx - TABLE[0] // 2, cy - TABLE[1] // 2, TABLE[0], TABLE[1])
            tb = (cx - TABLE_BOX[0] // 2, cy + TABLE[1] // 2 - TABLE_BOX[1], TABLE_BOX[0], TABLE_BOX[1])
            add(name, "table", tb, (220, 70, 60) if name != "主桌" else (240, 190, 60),
                "重排 %s：每边 3 列错开，列距 %d、行距 %d（占地之间左右留 %d、斜着留 %d）" % (LAYOUT, PITCH_X, PITCH, GAP, DIAG), "table:" + name, foot=tf)
    # 长凳：第 2 排最靠西墙那个空位，凳子落在那张桌占地的下沿
    # 04 10/2 第 5 条：凳子孤零零摆在地砖中间像掉在那儿的，贴西墙放（墙 WALL，留 2），高度还在第 2 排那个空位
    bf = (WALL + 2, by - 16, 72, 16)   # by：凳子落在那个位正中偏下，不压上下两排斜过来的桌；贴墙留 2
    add("长凳", "prop", up(bf, 38), (120, 200, 255), "§15 长凳 宽 72、高 38；重排：第 2 排最靠西墙那个空位，贴着西墙", foot=bf)
    # 礼物堆：舞台西边地上，两排错开、一份压一份（像现场图那一大片），后排 5 份、前排 5 份
    for row, (foot_y, x0, step) in enumerate(((290, 180, 69), (322, 186, 68))):   # 前排脚 322：跟台口一条线，主桌零件上沿 330 在它下面
        for i in range(5):
            b = (x0 + step * i, foot_y - GIFT[1], GIFT[0], GIFT[1])
            add("礼物堆 %d" % (row * 5 + i + 1), "prop", b, (236, 110, 140),
                "B55S-P05 礼物堆约 96×80（零件总表）；舞台西边地上，两排错开、相邻压 27；占地最下面 24", "gifts", foot=standing(b, 24))


def _mess(pos, main, d0, d1, by, empty):
    """排法 C 的桌心 → 打乱的桌心（MESS 档，见上面 MESS_LEVELS）。位 (排, 第几个) 不变，桌号就不变"""
    import math
    import random
    P = dict(MESS_LEVELS[MESS])
    P["seed"] = int(os.environ.get("SUQI55_SEED", P["seed"]))
    rng = random.Random(P["seed"])
    a, b = TABLE[0] / 2.0, TABLE[1] / 2.0
    x_in = LAMP_FOOT_X - 1 - a                     # 西边桌心最靠红毯：占地不碰灯（跟 C 一样）
    x_out = 41 + a                                 # 最靠墙：占地不碰墙
    y_lo, y_hi = float(ROW0), float(rows_y[-1])    # 北边不过第 1 排（台口），南边不过最后一排（厅长不变）
    # 不进桌的两块（按桌心算）：西墙长凳那块（桌画出来压着凳子也不行）、东侧门口（门前要留人走）
    keep_out = [(0, by - 106, 190, 208), (W - 41 - a - 90, d0 - 80, 200, d1 - d0 + 160)]
    keys = sorted(pos)
    p = {k: [float(pos[k][0]), float(pos[k][1])] for k in keys}
    # ⓪ C 里跟东侧门口对称空出来的那个位：那一排那一边剩下两张匀开占满（不留一个桌位大的洞）；东侧门口那个洞是门前的路，留着
    for (r, k), why in empty.items():
        if why == "跟东侧门口对称":
            side = [j for j in keys if j[0] == r and j[1] // 3 == k // 3]
            free = (x_in + a) - (x_out - a) - 2 * a * len(side)
            for n, j in enumerate(sorted(side, key=lambda j: -p[j][0] if k < 3 else p[j][0])):
                xl = x_in + a - free / (len(side) + 1) * (n + 1) - 2 * a * n - a
                p[j][0] = xl if k < 3 else 2 * CX - xl
    # ① 每排每边各自前后错、左右挪
    for r in range(NROWS):
        for side in (0, 1):
            dy, dx = rng.uniform(-P["row"], P["row"]), rng.uniform(-P["shift"], P["shift"])
            if r in (0, NROWS - 1):
                dy = abs(dy) if r == 0 else -abs(dy)   # 第 1 排只能往南、最后一排只能往北（不然顶在边上又成一条直线）
            for k in keys:
                if k[0] == r and k[1] // 3 == side and k != main:
                    p[k][0] += dx if side == 0 else -dx
                    p[k][1] += dy
    # ② 每张自己偏
    for k in keys:
        if k != main:
            p[k][0] += rng.uniform(-P["ax"], P["ax"])
            p[k][1] += rng.uniform(-P["ay"], P["ay"])
    # ③ 挑几对挨着的拉近
    close = set()
    cand = [k for k in keys if k != main]
    rng.shuffle(cand)
    for k in cand:
        if len(close) >= P["pairs"]:
            break
        nb = [j for j in keys if j != k and j[1] // 3 == k[1] // 3 and all(k not in c and j not in c for c in close)]
        if not nb:
            continue
        j = min(nb, key=lambda j: math.hypot(p[j][0] - p[k][0], (p[j][1] - p[k][1]) * a / b))
        close.add(frozenset((k, j)))
        dx, dy = p[j][0] - p[k][0], p[j][1] - p[k][1]
        d = math.hypot(dx, dy) or 1.0
        for m, s in ((k, 1), (j, -1)):
            if m != main:
                p[m][0] += s * dx / d * P["pull"] / 2
                p[m][1] += s * dy / d * P["pull"] / 2

    def clamp(k):
        x, y = p[k]
        west = pos[k][0] < CX
        xl = x if west else 2 * CX - x            # 东边照西边镜像算
        xl = min(max(xl, x_out), x_in)
        x = xl if west else 2 * CX - xl
        y = min(max(y, y_lo), y_hi)
        for zx, zy, zw, zh in keep_out:
            if zx < x < zx + zw and zy < y < zy + zh:
                y = zy if y - zy < zy + zh - y else zy + zh   # 往前或往后挪出去，哪边近挪哪边
                if y < y_lo:
                    y = zy + zh
        p[k] = [x, y]

    # 推开：两张一样大的占地椭圆，边到边至少 g ⇔ 圈心差落在 (2a+g, 2b+g) 那个椭圆外面（近似，最后用 _ellipse_gap 量真的）
    # 前一半还带一点「松开」：离得不够 spread 的也轻轻推一下（拉近的那几对不推），C 里空出来的位就有桌慢慢挪过去，不留明显空位
    def push(rounds, soft):
        for it in range(rounds):
            moved = 0.0
            for i, k in enumerate(keys):
                for j in keys[i + 1:]:
                    dx, dy = p[j][0] - p[k][0], p[j][1] - p[k][1]
                    pair_close = frozenset((k, j)) in close
                    g = P["close"] if pair_close else P["gap"]
                    rate = 0.6
                    q = (dx / (2 * a + g)) ** 2 + (dy / (2 * b + g)) ** 2
                    if q >= 1.0 and soft and not pair_close:
                        g, rate = P["spread"], 0.08
                        q = (dx / (2 * a + g)) ** 2 + (dy / (2 * b + g)) ** 2
                    if q >= 1.0:
                        continue
                    if q < 1e-6:
                        dx, dy, q = 1.0, 0.0, (1.0 / (2 * a + g)) ** 2
                    s = 1.0 / math.sqrt(q) - 1.0
                    fk, fj = (0.0, 1.0) if k == main else ((1.0, 0.0) if j == main else (0.5, 0.5))
                    p[k][0] -= dx * s * fk * rate
                    p[k][1] -= dy * s * fk * rate
                    p[j][0] += dx * s * fj * rate
                    p[j][1] += dy * s * fj * rate
                    moved += s * rate
            for k in keys:
                if k != main:
                    clamp(k)
            if moved < 1e-4:
                break
    push(300, True)
    push(800, False)
    _mess.close = close
    return {k: (int(round(v[0])), int(round(v[1]))) for k, v in p.items()}


def overlaps(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


# 画面上可以叠的：坐着的人和他的凳子、椅子
SIT = [{"钢琴手（坐）", "琴凳"}, {"大提琴手（坐）", "大提琴手的椅子"}]
# 本来就挨着的：T1 椅背靠着乐队台；v9 v2 背景里乐队台、贺礼架贴着北墙画好的（跟婚礼台一样）；进门的尺子站在大门里边
BEHIND_OK = [{"T1", "乐队地台（背景里画好的）"},
             {"北墙（立面）", "乐队地台（背景里画好的）"}, {"北墙（立面）", "贺礼堆（背景里画好的）"},
             {"大门（门柱和开着的两扇门，南边背景里画好的）", "尺子：人"}]
# v7：零件图四周有透明边（桌子两边各 16～19、宫灯两边各 13），框搭上一点不算压——比的时候按看得见那一截
VISIBLE_INSET = {"table": (16, 0), "宫灯": (13, 0)}


def _vis(it):
    """画出来看得见的那一截（v7 零件图两边有透明边）"""
    x, y, w, h = it["box"]
    dx = 0
    if it["kind"] == "table":
        dx = VISIBLE_INSET["table"][0]
    elif "宫灯" in it["name"]:
        dx = VISIBLE_INSET["宫灯"][0]
    return (x + dx, y, w - 2 * dx, h)


def check(items):
    """验收：画面上谁压谁、走得开（按占地）、行与行之间露的地面"""
    bad = []
    for i, a in enumerate(items):
        for b in items[i + 1:]:
            if not overlaps(_vis(a), _vis(b)):
                continue
            ka, kb = a["kind"], b["kind"]
            ga, gb = a["group"], b["group"]
            pair = {a["name"], b["name"]}
            if "zone" in (ka, kb) or "ruler" in (ka, kb) and ({ka, kb} & {"floor"}):
                continue
            if pair in BEHIND_OK:
                continue
            if "北墙（立面）" in pair and any(n.startswith("花架") for n in pair):
                continue   # 花架立在北墙脚跟前，画出来挡着墙，不算压
            if "top_decor" in (ga, gb) and ("北墙（立面）" in pair or {ga, gb} == {"top_decor"}):
                continue   # 墙顶的梁、帐幔、挂灯贴在北墙上
            if "wall_decor" in (ga, gb) and ("北墙（立面）" in pair or {ga, gb} == {"wall_decor"}):
                continue   # 花拱、囍贴北墙
            if {ga, gb} <= {"stage", "stage_decor"}:
                continue   # 台面、台口、台阶、新人脚印是一座台子
            if {ga, gb} == {"band"} and (ka == "band_floor" or kb == "band_floor" or pair in SIT):
                continue   # 乐队站在地台上；坐着的人坐在凳子、椅子上
            if LAYOUT and "宫灯" in a["name"] and "宫灯" in b["name"]:
                continue   # 重排：红毯两边每排一根，行距比灯矮，前一根挡住后一根下半截，连成一串（现场图就是这样）
            if LAYOUT and ka == kb == "table":
                continue   # 重排：错开的两排，后排桌的椅背被前排挡住一截（现场图就是这样）
            if "gifts" in (ga, gb) and "贺礼堆（背景里画好的）" in pair:
                continue   # 地上的礼物堆堆在背景里那架贺礼前面
            if {ga, gb} == {"gifts"} or (LAYOUT and "gifts" in (ga, gb) and ka != "table" and kb != "table" and "北墙（立面）" in pair):
                continue   # 礼物堆一份压一份堆成一片
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
    dim((x, y - 8), (x + w, y - 8), "桌 %d" % w)
    dim((x - 10, y), (x - 10, y + h), "画出来 %d" % h)
    dim((x + w + 10, fy), (x + w + 10, fy + fh), "占地 %d" % fh)
    c = COLS
    yy = rows_y[4]
    dim((c[0], yy), (c[1], yy), "列距 %d" % (c[1] - c[0]))
    dim((c[1], yy), (c[2], yy), "跨红毯 %d" % (c[2] - c[1]))
    last = len(c) - 1
    dim((c[last] + 110, rows_y[3]), (c[last] + 110, rows_y[4]), "行距 %d" % (rows_y[4] - rows_y[3]))
    a = [it for it in items if it["name"] == tid[(3, last)]][0]
    b2 = [it for it in items if it["name"] == tid[(4, last)]][0]
    dim((c[last] + 60, a["box"][1] + a["box"][3]), (c[last] + 60, b2["box"][1]), "露地面 %d" % (b2["box"][1] - a["box"][1] - a["box"][3]), (255, 120, 120))
    dim((c[last] + 130, rows_y[2] + TABLE[1] // 2), (c[last] + 130, rows_y[3] - TABLE[1] // 2), "横走道 %d" % CROSS_GAP)
    dim((STAGE_TOP[0], STAGE_TOP[1] + 12), (STAGE_TOP[0] + STAGE_TOP[2], STAGE_TOP[1] + 12), "台 480，画出来 %d" % STAGE_BOX[3])
    dim((STEPS_FOOT[0], STEPS_FOOT[1] + STEPS_FOOT[3] + 6), (STEPS_FOOT[0] + STEP_W, STEPS_FOOT[1] + STEPS_FOOT[3] + 6), "台阶 %d" % STEP_W)
    dim((W - 60, 0), (W - 60, 140), "手机顶上被挡 140", (255, 120, 120))
    dim((W - 110, 0), (W - 110, WALL_N), "北墙 %d" % WALL_N)
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
    r0, r1 = (CROSS_AFTER[0] + 1, CROSS_AFTER[1]) if CROSS_AFTER else (3, 6)
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
    lines = ["# 宴会厅 55 桌 · 摆位表（02，9/30，v9）", "",
             "> 01 D 9/25 派。画布 %d×%d，1:1（人 84）。坐标单位画布像素，x、y 是左上角。依据：ASSETS §15（左右和高 1 米 = 48、地面前后 1 米 = 32）、04 `体验-第47版-55桌.md`、03 `比例量尺-55桌摆位底图v2.md`、方案 `宴会厅55桌-方案.md`。脚本 `tools/layout_55/make_board55.py`，改数重跑。" % (W, H),
             "> **v3：x、y、宽、高是画出来在画面上占的框（色块画的就是它），下沿是落地的地方；「占地」列是地上占的地（走路判定用），平的东西两个一样。**",
             "", "| 名字 | x | y | 宽 | 高 | 占地（x, y, 宽×高） | 依据 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    lines += table_rows(items)
    lines += ["", "## 自检", ""]
    lines += ["- " + b for b in bad] if bad else [
        "- 比例：每样都照 §15 的数取（取值见「依据」列），没有大过 1.5 倍、小过一半的",
        "- 画面上谁也不压谁：按画出来的框比。可以叠的只有：墙上的梁、帐幔、挂灯、花拱、囍贴北墙；台面、台口、台阶、新人脚印是一座台子；乐队站在地台上、坐着的人坐在凳子椅子上。立着的东西画出来挡住它后面的地面（红毯、地面）不算压",
        "- v3.2 起桌下没有地毯了（阿鱼：太乱），中间红毯留着",
        "- v9（9/30 晚）：北边换 base_banquet55_north_v2.png（阿鱼「舞台要放这儿」）：贺礼架（脚 288）、乐队台（前沿 325）跟婚礼台前沿（322）一条线；婚礼台 555～999；第 1 排不再躲贺礼堆、乐队台，改回常规四列（373、573、963，乐队台前那张照旧空）；台口没动，第 1 排桌心还是 422；花盆挪到贺礼架西、乐队台东",
        "- v5（9/30）：家具照 d 的大小——桌 170×168（占地 170×112）、列距 215、行距 205、第 1 排照 d；大宫灯 28×118、花架 44×104；长凳挪到进门那块",
        "- v4（9/30）：北边照 GPT 的空厅背景 base_banquet55_north_v1.png 量（北墙脚 236、台前沿 322、台阶下沿 342、乐队前沿 432、贺礼堆脚 452），桌子整体往北挪 120，行距列距不动，画布 2594 高",
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
    lines = ["# 宴会厅 55 桌摆位表 · 北边那块（y 0～1024，v9）", "",
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
