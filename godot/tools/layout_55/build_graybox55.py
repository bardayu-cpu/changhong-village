#!/usr/bin/env python3
"""55 桌大厅灰盒（01 D 9/29 派：不等 GPT 的图，照摆位底图 v3.2 的摆位表做进游戏）。
摆位全从 make_board55.py 的 build() 拿（和摆位表、摆位图同一份数），这里只把它变成游戏的场景：
  assets/layered/scene_roman_banquet_55/base.png   底图：地面、墙、墙上的花拱囍、婚礼台、台阶、乐队地台和乐队、红毯、东侧门
                                                    （这些人都走不到后面去，烘在底图里）
  assets/layered/scene_roman_banquet_55/gb_*.png  色块图块：桌（连椅子）、主桌、宫灯、灯柱、花盆、礼物堆、长凳、栏杆、大门
                                                    按落地排前后（遮挡块），图就是摆位图那套颜色和框（画出来占的框，下沿落地）
  assets/layered/scene_roman_banquet_55/scene.json  桌（主桌 MAIN + T1～T54，桌心、占地半径）、能走的格子、遮挡块、交互点、长凳、座位圈
  assets/ambience/ambience_55.json                  厅里的热闹：每桌 NPC 9～10 个（阿鱼定）、服务员 6 个、彩带彩纸
  回执/55桌灰盒-拼回整厅.png                         自查：底图 + 全部色块按落地线叠回一张，和摆位底图逐像素比（03 拿它跑 board_check）
桌下不铺地毯（阿鱼 9/28），没有横幅、LED（阿鱼 9/28）
用法：python3 tools/layout_55/build_graybox55.py

接图 v1（01 D 9/30）：tools/layout_55/art/ 里有 GPT 交的「空厅背景 + 5 件零件」就用图，不再画色块：
  base.png = 北边空厅背景 base_banquet55_north_v1.png（y 0～1024）+ 往南接出去的地砖（照背景最下面 60 行一段段往下铺，SOUTH_BAND）
             + 背景里没有的东侧门还是色块
  桌、主桌、长凳、宫灯（红毯两边的和墙边灯柱都用这一张）、花盆 → 零件图（art_*.png）；南边栏杆、大门还是色块（没有图）
  婚礼台、台阶、乐队、贺礼堆画在背景里：不当遮挡块，从北墙到它们的脚都不让走（不然人走到它们后面会画在它们上面）
  能走的格子北边照背景量出来的两边墙（背景的墙是透视的，往下越来越宽，y 760 往下出了画面）
  座位圈照零件图里椅子的位置量（普通桌、主桌各一套）
"""
import importlib.util
import json
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55")
AMB = os.path.join(GODOT, "assets", "ambience", "ambience_55.json")
RES = "res://assets/layered/scene_roman_banquet_55/"
ART = os.path.join(HERE, "art")
ART_BG = os.path.join(ART, "base_banquet55_north_v2.png")   # v9（9/30）：阿鱼给的新北边，贺礼架、乐队台跟婚礼台一条线
# v7（01 D 9/30）：桌、主桌、大宫灯、花架换 GPT 南边包里的 v2；长凳、小花盆照旧 v1
ART_PIECES = {"table": "blk_banquet55_table_v2.png", "table_main": "blk_banquet55_table_main_v2.png",
              "bench": "blk_banquet55_bench_v1.png", "lantern": "blk_banquet55_lantern_v2.png", "flowerpot": "blk_banquet55_flowerpot_v1.png",
              "flowerstand": "blk_banquet55_flowerstand_v2.png"}
ART_SOUTH = os.path.join(ART, "base_banquet55_south_v1.png")   # 最南头 1024 那张
# 现场版（B55S，阿鱼 10/2 新做法：GPT 照色块画北边、照零件单拆；01 E 派 02 先铺路）：SUQI55_ART=b55s 时换这一套。
# 图由 import_gpt_pack.py 从 GPT 交的包里接进 art/，名字照零件总表。框和坐标还是 B55 那套（位置以色块为准），所以只换图：
#   北边背景 → B55S-BG01；桌、主桌、灯、花架、花盆、长凳 → B55S-T01、T02、P01～P04（灯一张，红毯两边和墙边都用它）；
#   中间那截地砖 → B55S-W01 一块块铺（对齐北边背景最下面的砖，接缝小）；红毯那一条照旧用北边背景最下面那截往下接。
#   两边墙（01 E 10/2 定）：GPT 照色块把墙画成笔直的一条，能走的格子也照这么宽的平条算——看着能走就要走得上去；
#   宽多少照摆位表 B.WALL（10/2 03 量两张背景都是 46，原来写 40）
#   中间那截竖墙换 B55S-W02（西）、W03（东），跟新北墙一个样子
# 10/2 起默认 b55s（GPT 照色块画的北边 v2，阿鱼验收过，01 E 派接）；SUQI55_ART=b55 退回原来那套
ART_SET = os.environ.get("SUQI55_ART", "b55s")
ART_FLOOR = None
BOUNDS_BG = None
if ART_SET == "b55s":
    BOUNDS_BG = ART_BG
    ART_BG = os.path.join(ART, "base_banquet55_scene_v1.png")
    ART_PIECES = {"table": "blk_banquet55s_table_v1.png", "table_main": "blk_banquet55s_table_main_v1.png",
                  "bench": "blk_banquet55s_bench_v1.png", "lantern": "blk_banquet55s_aisle_post_v1.png",
                  "flowerpot": "blk_banquet55s_flowerpot_v1.png", "flowerstand": "blk_banquet55s_flowerstand_v1.png",
                  "gift": "blk_banquet55s_giftpile_v1.png"}
    ART_FLOOR = os.path.join(ART, "tex_banquet55s_floor_v3.png")   # 10/2 GPT 交 W01 v3（v1 跟北边的砖对不上）
    # 10/2 GPT 照色块画的南边 B55S-BG02（1536×1067，整厅 y 1024～2091）：北边 1024 往南直接接它，中间不再留一截地砖；
    # 大门、栏杆、东侧门画在整厅同一个位置（02 拿摆位表的框套过：门柱、门洞、门槛、栏杆、东侧门 1260～1318 都对上），
    # 所以下面 SOUTH_* 那些坐标照旧（还是按「南边那张上沿 = 厅长 − 1024」算的整厅坐标）。W01 现在被南边那张整个盖住，铺不铺都看不见
    ART_SOUTH = os.path.join(ART, "base_banquet55s_south_v2.png")   # 10/2 BG02 v2（修接缝，阿鱼「都行」）
ART_WALL_W = os.path.join(ART, "tex_banquet55_wall_west_v1.png")   # 中间那截的竖墙，40×240 一段段接
ART_WALL_E = os.path.join(ART, "tex_banquet55_wall_east_v1.png")
if ART_SET == "b55s":
    ART_WALL_W = os.path.join(ART, "tex_banquet55s_wall_west_v1.png")
    ART_WALL_E = os.path.join(ART, "tex_banquet55s_wall_east_v1.png")
WALL_FROM = 724   # 北边那张的墙是透视的，西墙最下那根柱子到 y 724 左右——竖墙从这儿接下去（再往下北边那张两边已经是地砖）
# 乐队台上的乐手（01 D 9/30）：用 12 桌厅那套 GPT 乐手零件（band v3）。只摆两位站着的小提琴手：
# 量过（人 84、坐着 62）：小提琴 a 高 107（1.3 倍）、b 120（1.4 倍），都没超 1.5 倍，照原样摆在背景两个谱架前面；
# 弹钢琴的、拉大提琴的零件里自带钢琴、大提琴和椅子，背景里已经画了一套，摆上去就是两架钢琴两把琴；大提琴手还有 1.85 倍，
# 缩到 0.53 倍脸糊了——这两位先不摆，报 01（见 回执/55桌接图v1-回执.md 9/30 那节）
# 9/30 阿鱼：「先不要铺了，看起来乱糟糟的，我需要你按 gpt 的图先还原」——55 桌厅里代码自己加的装饰全撤：
# 桌下暗影、两位小提琴手、地上的彩带彩纸、飘的花瓣都不要了，画面只剩 GPT 的背景和零件（人照旧坐，玩法要）。
# 下面两样的数留着（以后要加回来改开关就行），开关关着
ART_EXTRAS = False
BAND_PLAYERS = [
    {"id": "小提琴手甲", "file": "blk_banquet_band_violin_player_a_v3.png", "anchor": (45, 135), "foot": (1257, 312)},
    {"id": "小提琴手乙", "file": "blk_banquet_band_violin_player_b_v3.png", "anchor": (43, 134), "foot": (1307, 312)},
]
# 桌下软边暗影（01 D 9/30）：每桌底下一块 150×95、黑 20% 的软边椭圆，烘进底图（压在地砖上、桌子下面）
TABLE_SHADOW = {"w": 150, "h": 95, "alpha": 0.20, "blur": 8, "dx": 5, "dy": 0}
SOUTH_BAND = (964, 1024)   # 往南接地砖用背景的哪几行（最下面一个砖高 60：往下的砖一行行已经差不多一样高了）
# 座位圈（量零件图里椅子的位置，02 9/30）：10 把椅子正好每 36° 一把、从正北起；圈心相对桌子占地中心、圈的半径
# v7 照 GPT v2 桌子零件量：普通桌椅子圈心在占地中心往上 18、半径 63×50；主桌椅子圈大：往上 22、75×57
SEAT_TABLE = {"abs": True, "dx": 0.0, "dy": -18.0, "rx": 63.0, "ry": 50.0}
SEAT_MAIN = {"abs": True, "dx": 0.0, "dy": -22.0, "rx": 75.0, "ry": 57.0}
# 10/2 GPT 十椅桌（B55S）：圈心、半径跟上面一样（02 拿 GPT 的 seats 和图对过），只是东西两头各一把，整圈转 18°
if os.environ.get("SUQI55_ART", "b55s") == "b55s":
    SEAT_TABLE = dict(SEAT_TABLE, a0=18.0)
    SEAT_MAIN = dict(SEAT_MAIN, a0=18.0)
CELL = 10
C = 12                    # 走路离占地留的边（和 build_layered.py 一样）

spec = importlib.util.spec_from_file_location("board", os.path.join(HERE, "make_board55.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)


# 主桌坐谁（阿鱼 9/29 定，以 01 D 最后那条更正为准）：主桌就是普通 10 座。8 位 NPC：爸爸、妈妈、外公、外婆、爷爷、奶奶、弟弟、弟妹；
# 1、2 号空着留给阿鱼、Toretto 本人（服务端进厅分主桌取最小的空号，正好是这两把；上线就坐这儿）。
# 椅子从正北（背对婚礼台、面朝大门那把）起顺时针数；谁坐哪把是 02 排的，【待阿鱼定】，改这张表重跑就行。
# 别的亲友（大爸一家、周叔他们、四孃、小舅……）这一版不做：阿鱼要他们开席前走动、开席后敬酒打牌，玩法 01 先写说明给阿鱼过目
FAMILY = {"table": "MAIN", "reserved": {"1": "阿鱼", "2": "Toretto"}, "seats": [
    {"chair": 3, "title": "爷爷", "sex": "m", "elder": True}, {"chair": 4, "title": "奶奶", "sex": "f", "elder": True}, {"chair": 5, "title": "爸爸", "sex": "m"}, {"chair": 6, "title": "妈妈", "sex": "f"},
    {"chair": 7, "title": "弟弟", "sex": "m"}, {"chair": 8, "title": "弟妹", "sex": "f"}, {"chair": 9, "title": "外公", "sex": "m", "elder": True}, {"chair": 10, "title": "外婆", "sex": "f", "elder": True}]}


# sex：长相按称呼分男女（04 9/29 那张对照表：爸、叔、哥、舅、姑爷、公是男；娘、孃、嫂、妈、媳、婆是女），从现有宾客长相里挑，不画新图；
# elder：老人（爷爷奶奶外公外婆），女的挑灰头发那几种
# 亲友 NPC（01 D 9/29，照 docs/宴会厅-亲友NPC-玩家说明.md a108150，阿鱼点过头）：18 位。
# relation 照那页表里的原话抄；【待讨论】的几位空着，身份卡上只写称呼。没有男方父母、公婆、亲家（出阁宴）。
# table：开席坐哪桌（02 定：主桌附近、不是 T1～T6 游戏桌的 T9、T11、T7）；group：开席前找熟人先找同一组的；
# cards：开席后凑在 T11 打牌的四位（玩家只能看）；toast：开席后会端杯去主桌敬酒
RELATIVES = {
    "feast": [[12, 14], [17, 19]],    # 开席：北京时间每天 12:00～14:00、17:00～19:00（阿鱼 9/29 定），前闭后开
    "tz_hours": 8,                     # 按北京时间算，不看手机时区
    "cards_table": "T11",
    "people": [
        {"title": "大爸", "sex": "m", "relation": "爸爸的大哥", "group": "大爸家", "table": "T9", "toast": True},
        {"title": "大娘", "sex": "f", "relation": "大哥的爱人", "group": "大爸家", "table": "T9", "toast": True},
        {"title": "小虎哥", "sex": "m", "relation": "大爸的大儿子", "group": "大爸家", "table": "T9", "toast": True},
        {"title": "大嫂", "sex": "f", "relation": "小虎哥的爱人", "group": "大爸家", "table": "T9", "toast": True},
        {"title": "二爸", "sex": "m", "relation": "爸爸的二哥", "group": "二爸家", "table": "T9", "toast": True},
        {"title": "二娘", "sex": "f", "relation": "二哥的爱人", "group": "二爸家", "table": "T9", "toast": True},
        {"title": "二孃", "sex": "f", "relation": "妈妈的堂姐", "group": "二爸家", "table": "T9", "toast": True},
        {"title": "四孃", "sex": "f", "relation": "", "group": "四孃家", "table": "T11", "cards": True},
        {"title": "四姑爷", "sex": "m", "relation": "", "group": "四孃家", "table": "T11", "cards": True},
        {"title": "六孃", "sex": "f", "relation": "", "group": "六孃家", "table": "T11", "cards": True},
        {"title": "六姑爷", "sex": "m", "relation": "", "group": "六孃家", "table": "T11", "cards": True},
        {"title": "小舅", "sex": "m", "relation": "", "group": "小舅家", "table": "T11", "toast": True},
        {"title": "小舅妈", "sex": "f", "relation": "", "group": "小舅家", "table": "T11", "toast": True},
        {"title": "周叔", "sex": "m", "relation": "阿鱼爸爸最好的朋友", "group": "爸爸的朋友", "table": "T7", "toast": True},
        {"title": "李叔", "sex": "m", "relation": "阿鱼爸爸最好的朋友", "group": "爸爸的朋友", "table": "T7", "toast": True},
        {"title": "丹孃", "sex": "f", "relation": "周叔的爱人", "group": "爸爸的朋友", "table": "T7", "toast": True},
        {"title": "小江", "sex": "m", "relation": "阿鱼初中起的好朋友，男生，现在最熟的老朋友", "group": "阿鱼的朋友", "table": "T7", "toast": True},
        {"title": "表弟媳", "sex": "f", "relation": "阿鱼表弟的媳妇，有两个女儿", "group": "阿鱼的朋友", "table": "T7", "toast": True},
    ]}


def block_image(it):
    """一件东西画成一张透明底的小图，和摆位图同一套画法"""
    x, y, w, h = it["box"]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g = ImageDraw.Draw(im)
    if it["kind"] == "table":
        fx, fy, fw, fh = it["foot"]
        fx, fy = fx - x, fy - y
        g.ellipse([fx + 10, 0, fx + fw - 10, fh], fill=(90, 50, 25, 255))
        g.ellipse([fx, fy, fx + fw - 1, fy + fh - 1], fill=(90, 50, 25, 255))
        g.ellipse([fx + 27, fy + 17, fx + fw - 27, fy + fh - 17], fill=tuple(it["color"]) + (255,))
    else:
        g.rectangle([0, 0, w - 1, h - 1], fill=tuple(it["color"]) + (255,))
    return im


def art_on():
    ok = os.path.exists(ART_BG) and all(os.path.exists(os.path.join(ART, f)) for f in ART_PIECES.values())
    if ART_SET == "b55s" and not (ok and all(os.path.exists(f) for f in (ART_FLOOR, ART_WALL_W, ART_WALL_E))):
        raise SystemExit("SUQI55_ART=b55s 但 art/ 里现场版的图不齐：先跑 import_gpt_pack.py 接 GPT 的包")
    return ok


def art_piece(it):
    """这件东西用哪张零件图；没有图的（栏杆、大门、花架）回 None 照旧画色块。
    零件图大小和摆位表里画出来的框对不上的（v5 桌子放大到 170、宫灯换成大的，GPT 重画的还没交）也回 None 先画色块"""
    n = it["name"]
    piece = None
    if it["kind"] == "table":
        piece = "table_main" if n == "主桌" else "table"
    elif n == "长凳":
        piece = "bench"
    elif "宫灯" in n or "灯柱" in n:
        piece = "lantern"
    elif "花盆" in n:
        piece = "flowerpot"
    elif "花架" in n:
        piece = "flowerstand"
    elif it.get("group") == "gifts" and "gift" in ART_PIECES:
        piece = "gift"
    if piece is None:
        return None
    w, h = Image.open(os.path.join(ART, ART_PIECES[piece])).size
    return piece if [w, h] == list(it["box"][2:]) else None


def seat_geom_for(it):
    """座位圈：用零件图的桌照零件里椅子量的；色块桌（v5 放大到 170、等 GPT 重画）照色块那一圈：半径比占地小 15、10"""
    piece = art_piece(it)
    if piece == "table":
        return SEAT_TABLE
    if piece == "table_main":
        return SEAT_MAIN
    fx, fy, fw, fh = it["foot"]
    return {"abs": True, "dx": 0.0, "dy": 0.0, "rx": fw / 2.0 - 15.0, "ry": fh / 2.0 - 10.0}


def compose(bg, W, H):
    """v7：北边那张（0～1024）+ 中间照最下面一截地砖一段段接 + 两边竖墙 + 南边那张垫最南头（H-1024～H）。回 (整张, 接缝数)"""
    im, seam = south_extend(bg, W, H)
    if os.path.exists(ART_SOUTH):
        south = Image.open(ART_SOUTH).convert("RGB")
        top = H - south.height
        # 中间那截两边的竖墙（北边那张的墙在 y 760 出画面，从那儿接到南边那张上沿）
        if os.path.exists(ART_WALL_W) and os.path.exists(ART_WALL_E):
            ww = Image.open(ART_WALL_W).convert("RGB")
            we = Image.open(ART_WALL_E).convert("RGB")
            y = wall_from(bg)
            while y < top:
                im.paste(ww, (0, y))
                im.paste(we, (W - we.width, y))
                y += ww.height
        # 中间地砖和南边那张的接缝：南边上沿那一行和它上面一行比
        px = im.load()
        def row_diff(y0, x0, x1):
            return sum(sum(abs(px[x, y0][k] - px[x, y0 - 1][k]) for k in range(3)) for x in range(x0, x1)) / float(x1 - x0) / 3.0
        im.paste(south, (0, top))
        seam["south_all"] = row_diff(top, 40, W - 40)
        seam["south_mid"] = row_diff(top, 300, 1236)
        seam["south_top"] = top
        # 竖墙最后一段接到南边那张上沿：墙那两条的缝
        seam["wall_join"] = (row_diff(top, 0, 40) + row_diff(top, W - 40, W)) / 2.0
    return im, seam


def wall_from(bg):
    """竖墙从哪往下接。v2 背景 y 724 往下两边已经是地砖，竖墙从 724 盖上去；现场版要是 GPT 照色块把两边墙画到底了
    （两条 40 宽里多半不是地砖），就别拿旧竖墙盖它，从北边那张下沿 1024 才接"""
    if ART_SET != "b55s":
        return WALL_FROM
    px = bg.load()
    n = floor = 0
    for y in range(WALL_FROM, bg.height, 4):
        for x in list(range(4, 36, 4)) + list(range(bg.width - 36, bg.width - 4, 4)):
            c = px[x, y]
            n += 1
            floor += c[0] > 175 and c[1] > 160 and c[2] > 120 and c[0] - c[2] < 90
    y0 = WALL_FROM if floor > n / 2 else bg.height
    print("现场版两边 y %d～%d：地砖占 %.0f%%，竖墙从 y %d 接" % (WALL_FROM, bg.height, 100.0 * floor / n, y0))
    return y0


def south_extend(bg, W, H):
    """背景只画到 y 1024：往南用最下面 SOUTH_BAND 那几行一段段接出去。回 (整张, 接缝数)"""
    a, b = SOUTH_BAND
    band = bg.crop((0, a, W, b))
    im = Image.new("RGB", (W, H))
    im.paste(bg, (0, 0))
    y = bg.height
    while y < H:
        im.paste(band, (0, y))
        y += b - a
    if ART_FLOOR and os.path.exists(ART_FLOOR):
        floor_tiles(im, bg, W, H)
    # 接缝数：接缝上下两行像素差，和背景自己最下面相邻两行的差比；分中间（红毯两边各 400 以内）和两边（离画布边 250 以内）
    px = im.load()
    def row_diff(y0, x0, x1):
        return sum(sum(abs(px[x, y0][k] - px[x, y0 - 1][k]) for k in range(3)) for x in range(x0, x1)) / float(x1 - x0) / 3.0
    natural = [row_diff(y0, 0, W) for y0 in range(900, 1020)]
    nat = sum(natural) / len(natural)
    seam = {"seam_all": row_diff(bg.height, 0, W), "seam_mid": row_diff(bg.height, 300, 1236),
            "seam_edge": (row_diff(bg.height, 0, 250) + row_diff(bg.height, W - 250, W)) / 2.0, "natural": nat}
    # 地砖花的位置：背景最下一行花（y 1009 左右）和接出去第一行（band 里同一行）左右差多少（透视：越往边上越错开）
    return im, seam


FLOOR_MATCH_MAX = 8   # 地砖瓦片跟北边背景最下面那两块砖对齐后的平均差（灰度 0～255）超过这个就算对不上（假包、v2 背景自己切的砖是 2）


def floor_tiles(im, bg, W, H):
    """现场版：y 1024 往南的地砖用 B55S-W01 铺。先在北边背景最下面两块砖高里找瓦片对得最齐的错位（ox, oy），
    照这个错位往下铺，北边和中间的接缝就是砖缝而不是一刀切。红毯那一条（摆位表里红毯的框）不铺，留着背景接下来的红毯"""
    tile = Image.open(ART_FLOOR).convert("RGB")
    tw, th = tile.size
    carpet = [it for it in B.build()[0] if it["name"] == "红毯"][0]["box"]
    c0, c1 = carpet[0], carpet[0] + carpet[2]
    ref = bg.crop((60, bg.height - 2 * th, c0 - 20, bg.height)).convert("L")   # 红毯西边那一片地砖
    best = None
    tg = tile.convert("L")
    pat = Image.new("L", (ref.width + tw, ref.height + th))
    for yy in range(0, pat.height, th):
        for xx in range(0, pat.width, tw):
            pat.paste(tg, (xx, yy))
    for oy in range(0, th, 2):
        for ox in range(0, tw, 2):
            # 整厅 x 处的瓦片列 = (x - ox) mod tw；ref 左上角在整厅 (60, bg.height - 2th)
            sx = (60 - ox) % tw
            sy = (bg.height - 2 * th - oy) % th
            d = ImageChops.difference(pat.crop((sx, sy, sx + ref.width, sy + ref.height)), ref)
            score = sum(i * n for i, n in enumerate(d.histogram())) / float(ref.width * ref.height)
            if best is None or score < best[0]:
                best = (score, ox, oy)
    _, ox, oy = best
    if best[0] > FLOOR_MATCH_MAX:
        # 10/2 GPT 北边 v2 交的 W01（80×52、浅米色小花）跟它自己背景里的地砖（米黄、大十字花、砖大一圈）对不上，铺上去是一条浅色带：
        # 对不上就不铺，照旧拿背景最下面那行砖往下接，报出来等 GPT 重画
        print("提醒：地砖 W01 跟北边背景最下面的砖对不上（对齐差 %.1f > %d），不铺，照旧用背景最下面那行砖往南接；W01 要 GPT 照背景的砖重画"
              % (best[0], FLOOR_MATCH_MAX))
        return
    floor = Image.new("RGB", (W, H - bg.height))
    y0 = bg.height - ((bg.height - oy) % th) - th
    for yy in range(y0, H, th):
        for xx in range(ox % tw - tw, W, tw):
            floor.paste(tile, (xx, yy - bg.height))
    mask = Image.new("L", floor.size, 255)
    ImageDraw.Draw(mask).rectangle([c0, 0, c1 - 1, floor.height], fill=0)
    im.paste(floor, (0, bg.height), mask)
    print("现场版地砖 %d×%d 铺中间，对齐北边背景的错位 (%d, %d)，对齐差 %.1f" % (tw, th, ox, oy, best[0]))


def floor_bounds(bg):
    """背景里每一行地砖从哪到哪（两边是透视的墙）：从左往右找第一段连着 8 个浅色地砖的像素，右边同样。y 1024 往下没有墙"""
    px = bg.load()
    W = bg.width
    def floor_like(c):
        return c[0] > 175 and c[1] > 160 and c[2] > 120 and c[0] - c[2] < 90
    out = {}
    for y in range(B.WALL_N, bg.height):
        lx = 0
        for x in range(0, 400):
            if all(floor_like(px[x + k, y]) for k in range(8)):
                lx = x
                break
        rx = W
        for x in range(W - 1, W - 400, -1):
            if all(floor_like(px[x - k, y]) for k in range(8)):
                rx = x
                break
        out[y] = (lx, rx)
    return out


def main():
    items, tid, door, stand_top, rail_foot = B.build()
    W, H = B.W, B.H
    os.makedirs(OUT, exist_ok=True)
    art = art_on()

    occ_kinds = ("table", "prop")
    front_names = ("南边西段栏杆", "南边东段栏杆", "大门（双开门门洞）")
    base_items = [it for it in items if it["kind"] not in occ_kinds + ("mark", "ruler", "zone") and it["name"] not in front_names]
    seam = None
    bounds = {}
    if art:
        bg = Image.open(ART_BG).convert("RGB")
        base, seam = compose(bg, W, H)
        bounds = floor_bounds(bg)
        if BOUNDS_BG:
            # 现场版：走路格子的两边墙照 40 宽平条（01 E 10/2）；新背景照地砖颜色量出来，离平条差 8 像素以上的行报出来
            # （GPT 要是哪段没画直、墙边留了别的东西，这里看得见）
            new_b, bounds = bounds, {y: (B.WALL, W - B.WALL) for y in bounds}
            bad = [(y, new_b[y]) for y in sorted(new_b) if y >= 260 and
                   max(abs(new_b[y][0] - B.WALL), abs(new_b[y][1] - (W - B.WALL))) > 8]
            print("现场版走路格子两边墙照 %d 宽平条；" % B.WALL + "新背景量出来离平条差 8 像素以上的 %d 行%s" % (
                len(bad), "，例：y %d 量到 %s" % bad[0] if bad else ""))
        # 桌下暗影：一块黑的椭圆，边上高斯糊开，乘 20% 叠上去
        sh = TABLE_SHADOW
        pad = sh["blur"] * 3
        m = Image.new("L", (sh["w"] + pad * 2, sh["h"] + pad * 2), 0)
        ImageDraw.Draw(m).ellipse([pad, pad, pad + sh["w"] - 1, pad + sh["h"] - 1], fill=255)
        m = m.filter(ImageFilter.GaussianBlur(sh["blur"])).point(lambda v: int(v * sh["alpha"]))
        dark = Image.new("RGBA", m.size, (0, 0, 0, 0))
        dark.putalpha(m)
        base = base.convert("RGBA")
        for it in (items if ART_EXTRAS else []):
            if it["kind"] == "table":
                fx, fy, fw, fh = it["foot"]
                cx, cy = fx + fw // 2 + sh["dx"], fy + fh // 2 + sh["dy"]
                base.alpha_composite(dark, (cx - m.width // 2, cy - m.height // 2))
        base = base.convert("RGB")
        g = ImageDraw.Draw(base)
        for it in ([] if os.path.exists(ART_SOUTH) else items):
            if it["name"] == "东侧门（门洞）":   # 南边那张没来之前背景里没有侧门：还画色块
                x, y, w, h = it["box"]
                g.rectangle([x, y, x + w - 1, y + h - 1], fill=tuple(it["color"]))
    else:
        base = B.draw(base_items, False, tid, door, stand_top, rail_foot)
    base.save(os.path.join(OUT, "base.png"))
    art_res = {}
    if art:
        for k, f in ART_PIECES.items():
            Image.open(os.path.join(ART, f)).save(os.path.join(OUT, "art_%s.png" % k))
            art_res[k] = RES + "art_%s.png" % k

    # 遮挡块：同样大小同样颜色的只存一张图
    imgs = {}
    occ = []
    for it in items:
        if not (it["kind"] in occ_kinds or it["name"] in front_names):
            continue
        if art and "背景里画好的" in it["name"]:
            continue   # 贺礼堆、南边的大门画在背景里
        if it["group"] == "gifts" and not (art and art_piece(it)):
            continue   # 礼物堆（B55S-P05）：没有图（旧 B55 那套）就不画，挡路照算
        if art and os.path.exists(ART_SOUTH) and it["name"] in front_names:
            continue   # v7：南边栏杆画在南边那张背景里；人走不到栏杆顶以南（见能走的格子），不用挡
        x, y, w, h = it["box"]
        piece = art_piece(it) if art else None
        if piece is not None:
            fx, fy, fw, fh = it["foot"]
            occ.append({"id": it["name"], "image": art_res[piece], "x": x, "y": y, "foot": fy + fh // 2})
            continue
        key = "%s_%dx%d_%02x%02x%02x" % (it["kind"], w, h, *it["color"])
        if key not in imgs:
            name = "gb_%d.png" % len(imgs)
            block_image(it).save(os.path.join(OUT, name))
            imgs[key] = RES + name
        fx, fy, fw, fh = it["foot"]
        foot = fy + fh // 2
        if it["name"] in front_names:
            foot = rail_foot + 1000 + len(occ)   # 栏杆、大门永远画在人前面（和 12 桌厅的栏杆一样）
        occ.append({"id": it["name"], "image": imgs[key], "x": x, "y": y, "foot": foot})

    # 桌：主桌 MAIN + T1～T54；x、y 是占地中心（和 12 桌厅一样的规矩），rx、ry 是占地半径
    if art and ART_EXTRAS:
        for k, bp in enumerate(BAND_PLAYERS):
            name = "art_band_%d.png" % k
            Image.open(os.path.join(ART, bp["file"])).save(os.path.join(OUT, name))
            art_res["band_%d" % k] = RES + name
            ax, ay = bp["anchor"]
            fx, fy = bp["foot"]
            occ.append({"id": bp["id"], "image": RES + name, "x": fx - ax, "y": fy - ay, "foot": fy})
    tables = []
    for it in items:
        if it["kind"] != "table":
            continue
        fx, fy, fw, fh = it["foot"]
        t = {"id": "MAIN" if it["name"] == "主桌" else it["name"], "x": fx + fw // 2, "y": fy + fh // 2, "rx": fw // 2, "ry": fh // 2}
        if it["name"] == "主桌":
            t["main"] = True
        if art:
            t["seat_geom"] = seat_geom_for(it)   # 每张桌自己带座位圈（零件图、色块不一样）
        tables.append(t)
    tables.sort(key=lambda t: (t["id"] != "MAIN", int(t["id"][1:]) if t["id"] != "MAIN" else 0))

    south_art = art and os.path.exists(ART_SOUTH)
    # 能走的格子：厅里（两边墙之间、北墙脚到南边栏杆）减掉挡路东西的占地（外放 12）；东侧门门洞能站；从大门那块空地连通
    cols, rows = math.ceil(W / CELL), math.ceil(H / CELL)
    d0, d1 = door
    blockers = []
    for it in items:
        if it["kind"] in ("mark", "ruler", "zone", "floor", "decor") or it["name"] in ("大门（双开门门洞）", "东侧门（门洞）"):
            continue
        if it["group"] in ("top_decor", "wall_decor", "stage_decor"):
            continue
        blockers.append(it)

    # 接图：婚礼台、台阶、乐队、贺礼堆画在背景里，从北墙到它们的脚都不让走（人走到后面会画在它们上面）
    backdrops = []
    if art:
        for it in items:
            if (it["kind"] in ("stage", "band_floor") or "背景里画好的" in it["name"]) and it["foot"][1] < 1024:   # 只管北边那张里的（南边大门另算）
                fx, fy, fw, fh = it["foot"]
                backdrops.append((fx, B.WALL_N, fw, fy + fh - B.WALL_N))

    def blocked(px, py):
        for fx, fy, fw, fh in backdrops:
            if fx - C < px < fx + fw + C and fy - C < py < fy + fh + C:
                return True
        if art and py < 1024:
            lx, rx = bounds.get(int(py), (0, W))
            if os.path.exists(ART_WALL_W) and py >= WALL_FROM:
                lx, rx = max(lx, B.WALL), min(rx, W - B.WALL)   # 竖墙盖在北边那张上的那一截：墙上不让走
            if px < lx + C or px > rx - C:
                return True   # 背景两边的墙（透视的）
        for it in blockers:
            fx, fy, fw, fh = it["foot"]
            if it["kind"] == "table":
                cx, cy, rx, ry = fx + fw / 2, fy + fh / 2, fw / 2, fh / 2
                if ((px - cx) / (rx + C)) ** 2 + ((py - cy) / (ry + C)) ** 2 < 1.0:
                    return True
            elif fx - C < px < fx + fw + C and fy - C < py < fy + fh + C:
                return True
        return False

    grid = [[False] * cols for _ in range(rows)]
    for j in range(rows):
        py = (j + 0.5) * CELL
        for i in range(cols):
            px = (i + 0.5) * CELL
            inside = B.WALL < px < W - B.WALL and B.WALL_N < py < rail_foot - 8
            if south_art:
                # v7：南边那张里——栏杆顶以南不让走（栏杆画在背景里，人走到它后面会画在它上面）；只有门洞那一截能走到门口；
                # 门柱和开着的两扇门那两块也不让走
                st = H - 1024
                inside = B.WALL < px < W - B.WALL and B.WALL_N < py < st + B.SOUTH_RAIL[0] - 8
                if B.SOUTH_DOORWAY[0] < px < B.SOUTH_DOORWAY[1] and st + B.SOUTH_DOOR_POSTS[1] <= py < st + B.SOUTH_RAIL[1] - 6:
                    inside = True
                elif B.SOUTH_DOOR_POSTS[0] <= px < B.SOUTH_DOOR_POSTS[0] + B.SOUTH_DOOR_POSTS[2] and py >= st + B.SOUTH_DOOR_POSTS[1]:
                    inside = False
            in_side_door = W - B.WALL <= px < W and d0 < py < d1
            if (inside and not blocked(px, py)) or in_side_door:
                grid[j][i] = True
    spawn = [B.CX, stand_top + 48]
    sx, sy = int(spawn[0] // CELL), int(spawn[1] // CELL)
    assert grid[sy][sx], "进场点不在能走的地方"
    seen = {(sx, sy)}
    stack = [(sx, sy)]
    while stack:
        i, j = stack.pop()
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ni, nj = i + di, j + dj
            if 0 <= ni < cols and 0 <= nj < rows and grid[nj][ni] and (ni, nj) not in seen:
                seen.add((ni, nj))
                stack.append((ni, nj))
    for j in range(rows):
        for i in range(cols):
            grid[j][i] = (i, j) in seen

    bench = [it for it in items if it["name"] == "长凳"][0]
    bx, by, bw, bh = bench["foot"]
    steps_bottom = B.STEPS_FOOT[1] + B.STEPS_FOOT[3]
    points = [
        # 主桌悄悄话：红毯上、台阶正前方（新人站在台上）
        {"id": "couple_table", "x": B.CX, "y": steps_bottom + 45, "r": 60, "kind": "talk", "line": "table"},
        {"id": "door", "x": (B.SOUTH_DOORWAY[0] + B.SOUTH_DOORWAY[1]) // 2 if south_art else B.CX,
         "y": (H - 1024 + 950) if south_art else rail_foot - 145 - 20, "r": 40 if south_art else 50, "kind": "door", "line": "leave"},
        {"id": "side_door", "x": W - 20, "y": (d0 + d1) // 2, "r": 30, "kind": "door", "line": "backhall"},
    ]
    scene = {
        "scene": "scene_roman_banquet_55", "mode": "blocks", "revision": "graybox-v3.2",
        "note": "55 桌大厅灰盒（01 D 9/29）：照摆位底图 v3.2（455d828）的摆位表，tools/layout_55/build_graybox55.py 生成，别手改",
        "base": RES + "base.png", "size": [W, H],
        "person_px": {"near_y": H, "near_h": 84, "far_y": 0, "far_h": 84},
        "spawn": spawn,
        "couple": [B.COUPLE_FEET[0][0] + 16, B.COUPLE_FEET[0][1]],
        "points": points,
        "walk_grid": {"cell": CELL, "cols": cols, "rows": ["".join("1" if v else "0" for v in r) for r in grid]},
        "occluders": occ,
        "tables": tables,
        "ambience": "ambience_55.json",
        # 座位圈：灰盒的桌是占地 140×92 的一圈，椅子就在这圈上（12 桌厅是 GPT 那张桌子图，圈心往上挪 0.85 个半径）
        "seat_geom": {"dy": 0.0, "rx": -12.0, "ry": -8.0},
        # 长凳：第 1 排最西那个空位，灰盒色块画了凳子，代码不另画；坐的人排在凳面上
        "bench": {"x0": bx + 12, "x1": bx + bw - 12, "y": by + 2, "draw": False},
        "rugs": False,        # 桌下不铺地毯（阿鱼 9/28）
        "band_art": False,    # 乐队是底图里的色块，不叠第 44 版那块乐队图
        "sign_mode": "near",  # 认桌（01 定）：自己那桌一直挂牌，走近哪桌亮哪桌，其余不挂
        # 每桌一个小游戏（01 D 9/30 v8）：54 张普通桌在这三个里分（各 18 桌），按北京日期洗，同一天大家一样（game_config.gd daily_plan）；
        # 主桌不挂游戏（01 D 9/30：主桌只有阿鱼、Toretto 坐，别人看得到玩不了）
        "table_games": {"mode": "daily", "games": ["lianliankan", "match3", "g2048"], "skip": ["MAIN"], "tz_hours": 8},
    }
    if art:
        scene["revision"] = "art-v1（GPT 空厅背景 + 5 件零件，摆位 v4）"
        scene["note"] = "55 桌大厅接图 v1（01 D 9/30）：GPT 北边空厅背景 + 零件，摆位 v4；tools/layout_55/build_graybox55.py 生成，别手改"
        scene["seat_geom"] = SEAT_TABLE
        scene["south_seam"] = seam
        if ART_SET != "b55":
            scene["revision"] = "art-%s（GPT 照色块画的北边 + 零件，摆位不变）" % ART_SET
            scene["art_set"] = ART_SET
    json.dump(scene, open(os.path.join(OUT, "scene.json"), "w", encoding="utf-8"), ensure_ascii=False)
    # 这回没生成的图（第 47 版留下的拉长底图、GPT 桌子，或者色块少了一种）连同 .import 一起清掉；
    # 生成了的图留着 .import，重跑不换 uid
    keep = {"base.png"} | {v.replace(RES, "") for v in imgs.values()} | {v.replace(RES, "") for v in art_res.values()}
    for f in os.listdir(OUT):
        png = f[:-len(".import")] if f.endswith(".png.import") else f
        if png.endswith(".png") and png not in keep:
            os.remove(os.path.join(OUT, f))

    # 厅里的热闹
    rng = random.Random(55)
    npc = {}
    rel_n = {}
    for r in RELATIVES["people"]:
        rel_n[r["table"]] = rel_n.get(r["table"], 0) + 1
    for t in tables:
        if t["id"] != "MAIN":
            npc[t["id"]] = rng.randint(9, 10)   # 每桌 9～10（阿鱼定）；主桌不放随机宾客，坐阿鱼家里人（family）
            if t["id"] in rel_n:
                npc[t["id"]] = 10 - rel_n[t["id"]]   # 亲友那几桌：随机宾客让出亲友的座（开席前那几把空着，亲友在厅里走动）
    decals = []
    placed = []
    carpet = [it for it in items if it["name"] == "红毯"][0]["box"]
    tries = 0
    while len(decals) < 110 and tries < 40000:
        tries += 1
        x, y = rng.uniform(60, W - 60), rng.uniform(B.WALL_N + 40, rail_foot - 60)
        if carpet[0] - 10 < x < carpet[0] + carpet[2] + 10:
            continue
        if not grid[int(y // CELL)][int(x // CELL)]:
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < 60 ** 2 for px, py in placed):
            continue
        placed.append((x, y))
        art = "amb_streamer_%d" % rng.randint(1, 6) if len(decals) % 3 else "amb_confetti_%d" % rng.randint(1, 3)
        decals.append({"art": art, "x": round(x), "y": round(y), "flip": rng.random() < 0.5})
    if art and not ART_EXTRAS:
        decals = []   # 55 桌厅不要地上的彩带彩纸（阿鱼 9/30：照 GPT 的图还原）
    amb = {
        "note": "55 桌大厅灰盒的热闹摆放，tools/layout_55/build_graybox55.py 生成，别手改",
        "decals": decals, "glows": [],
        "npc_tables": npc,
        "family": FAMILY,
        "relatives": RELATIVES,
        "waiters": {"count": 6, "door": [W - 70, (d0 + d1) // 2], "speed_m": 1.5},
        "petals": {"amount": 60 if (not art or ART_EXTRAS) else 0},   # 飘的花瓣：接图以后关（阿鱼 9/30）
    }
    json.dump(amb, open(AMB, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # 自查：叠回一张整厅，和摆位底图比。只该差比例尺那个小人（人=1 的量尺，不进游戏）
    flat = base.convert("RGBA")
    cache = {}
    for o in sorted(occ, key=lambda o: o["foot"]):
        f = o["image"].replace(RES, "")
        if f not in cache:
            cache[f] = Image.open(os.path.join(OUT, f)).convert("RGBA")
        flat.alpha_composite(cache[f], (int(o["x"]), int(o["y"])))
    flat = flat.convert("RGB")
    if art:
        # 接图：没有「逐像素一样」可比（背景是 GPT 画的）；存一张整厅、一张北边给 01、03 看
        tag = "55桌接图v1" if ART_SET == "b55" else "55桌接图-" + ART_SET
        flat.save(os.path.join(GODOT, "回执", tag + "-整厅拼图.png"))
        flat.crop((0, 0, W, 1024)).save(os.path.join(GODOT, "回执", tag + "-北边预览.png"))
        print("往南接地砖的接缝（每像素平均差，0～255）：整行 %.1f、中间 %.1f、两边 %.1f；背景自己相邻两行平均差 %.1f" % (
            seam["seam_all"], seam["seam_mid"], seam["seam_edge"], seam["natural"]))
    else:
        flat.save(os.path.join(GODOT, "回执", "55桌灰盒-拼回整厅.png"))
    ref = os.path.join(GODOT, "回执", "宴会厅55桌-摆位底图.png")
    if not art and os.path.exists(ref):
        d = ImageChops.difference(flat, Image.open(ref).convert("RGB"))
        ruler = [it["box"] for it in items if it["kind"] == "ruler"]
        n = n_out = 0
        for j in range(H):
            for i in range(W):
                if d.getpixel((i, j)) != (0, 0, 0):
                    n += 1
                    if not any(x <= i < x + w and y <= j < y + h for x, y, w, h in ruler):
                        n_out += 1
        print("拼回整厅和摆位底图：差 %d 像素，比例尺小人以外差 %d 像素" % (n, n_out))
    walk_n = sum(1 for r in grid for v in r if v)
    print("灰盒：画布 %d×%d，桌 %d（主桌 + T1～T%d），遮挡块 %d（图 %d 张），能走 %d 格，NPC %d 个" % (
        W, H, len(tables), len(tables) - 1, len(occ), len(imgs), walk_n, sum(npc.values())))


if __name__ == "__main__":
    main()
