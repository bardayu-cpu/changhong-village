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

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55")
AMB = os.path.join(GODOT, "assets", "ambience", "ambience_55.json")
RES = "res://assets/layered/scene_roman_banquet_55/"
ART = os.path.join(HERE, "art")
ART_BG = os.path.join(ART, "base_banquet55_north_v1.png")
ART_PIECES = {"table": "blk_banquet55_table_v1.png", "table_main": "blk_banquet55_table_main_v1.png",
              "bench": "blk_banquet55_bench_v1.png", "lantern": "blk_banquet55_lantern_v1.png", "flowerpot": "blk_banquet55_flowerpot_v1.png"}
SOUTH_BAND = (964, 1024)   # 往南接地砖用背景的哪几行（最下面一个砖高 60：往下的砖一行行已经差不多一样高了）
# 座位圈（量零件图里椅子的位置，02 9/30）：10 把椅子正好每 36° 一把、从正北起；圈心相对桌子占地中心、圈的半径
SEAT_TABLE = {"abs": True, "dx": 5.0, "dy": -8.0, "rx": 52.0, "ry": 40.0}
SEAT_MAIN = {"abs": True, "dx": 4.0, "dy": -12.0, "rx": 60.0, "ry": 45.0}
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
    return os.path.exists(ART_BG) and all(os.path.exists(os.path.join(ART, f)) for f in ART_PIECES.values())


def art_piece(it):
    """这件东西用哪张零件图；没有图的（栏杆、大门）回 None 照旧画色块"""
    n = it["name"]
    if it["kind"] == "table":
        return "table_main" if n == "主桌" else "table"
    if n == "长凳":
        return "bench"
    if "宫灯" in n or "灯柱" in n:
        return "lantern"
    if "花盆" in n:
        return "flowerpot"
    return None


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
        base, seam = south_extend(bg, W, H)
        bounds = floor_bounds(bg)
        g = ImageDraw.Draw(base)
        for it in items:
            if it["name"] == "东侧门（门洞）":   # 背景里没有侧门（墙在 y 760 往下出了画面）：还画色块
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
            continue   # 贺礼堆画在背景里
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
    tables = []
    for it in items:
        if it["kind"] != "table":
            continue
        fx, fy, fw, fh = it["foot"]
        t = {"id": "MAIN" if it["name"] == "主桌" else it["name"], "x": fx + fw // 2, "y": fy + fh // 2, "rx": fw // 2, "ry": fh // 2}
        if it["name"] == "主桌":
            t["main"] = True
            if art:
                t["seat_geom"] = SEAT_MAIN   # 主桌那张图的椅子圈比普通桌大
        tables.append(t)
    tables.sort(key=lambda t: (t["id"] != "MAIN", int(t["id"][1:]) if t["id"] != "MAIN" else 0))

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
            if it["kind"] in ("stage", "band_floor") or "背景里画好的" in it["name"]:
                fx, fy, fw, fh = it["foot"]
                backdrops.append((fx, B.WALL_N, fw, fy + fh - B.WALL_N))

    def blocked(px, py):
        for fx, fy, fw, fh in backdrops:
            if fx - C < px < fx + fw + C and fy - C < py < fy + fh + C:
                return True
        if art and py < 1024:
            lx, rx = bounds.get(int(py), (0, W))
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
            inside = 40 < px < W - 40 and B.WALL_N < py < rail_foot - 8
            in_side_door = W - 40 <= px < W and d0 < py < d1
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
        {"id": "door", "x": B.CX, "y": rail_foot - 145 - 20, "r": 50, "kind": "door", "line": "leave"},
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
    }
    if art:
        scene["revision"] = "art-v1（GPT 空厅背景 + 5 件零件，摆位 v4）"
        scene["note"] = "55 桌大厅接图 v1（01 D 9/30）：GPT 北边空厅背景 + 零件，摆位 v4；tools/layout_55/build_graybox55.py 生成，别手改"
        scene["seat_geom"] = SEAT_TABLE
        scene["south_seam"] = seam
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
    amb = {
        "note": "55 桌大厅灰盒的热闹摆放，tools/layout_55/build_graybox55.py 生成，别手改",
        "decals": decals, "glows": [],
        "npc_tables": npc,
        "family": FAMILY,
        "relatives": RELATIVES,
        "waiters": {"count": 6, "door": [W - 70, (d0 + d1) // 2], "speed_m": 1.5},
        "petals": {"amount": 60},
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
        flat.save(os.path.join(GODOT, "回执", "55桌接图v1-整厅拼图.png"))
        flat.crop((0, 0, W, 1024)).save(os.path.join(GODOT, "回执", "55桌接图v1-北边预览.png"))
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
