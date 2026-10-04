#!/usr/bin/env python3
"""后厅长条里原来那间化妆室封起来：改成一面墙加一扇门（01 H 10/4 派，02 F 画）。
化妆间单独成了一间屋（tools/pixel_art/room_makeup.py），后厅走廊走到门口整屏换进去；长条里原来那间不再露出来，
从走廊看是一面整墙（跟各间北墙同一种墙纸、护墙板、红绸），门洞那里一扇关着的红漆双开门，两边挂一对红灯笼。
门口「化妆间」牌是游戏里的字牌（后厅布局 signs），不画进图。

出 assets/pixel_art/backhall_makeup_door/（后厅布局 pixel_art 里替掉原来那间的 backhall_makeup/room.json）：
  room.png        背景：墙后面那块（原来的屋里）涂成墙外的深色
  props/door_wall.png   那面墙连门、灯笼、休息间东边那道墙顶，着地线 696（走廊里的人在它前面）
  room.json       hide：原来那间的 32 件家具灰盒、wall_3、front_5（只藏画，挡人的占地照旧）
原来那间的三位（新娘、两位化妆师）还在后厅布局里，07 搬；这份不管人。
画法借 room_backhall_makeup.py（墙纸、护墙板、红绸、灯笼），颜色都在那份的调色板里。
用法：python3 godot/tools/pixel_art/backhall_makeup_door.py [--preview 目录]
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import room_backhall_makeup as mk

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
LAYOUT = os.path.join(GODOT, "assets", "layered", "scene_luoman_backhall", "layout.json")
OUT = os.path.join(GODOT, "assets", "pixel_art", "backhall_makeup_door")
RES = "res://assets/pixel_art/backhall_makeup_door/"

X0, X1 = 1195, 1536                # 原来那间：西边跟休息间共用的 wall_3（1195～1205）到画布东边
TOP, FOOT = 104, 696               # 墙顶以上（原来的屋里）到走廊这边的墙脚
DY = FOOT - mk.FLOOR_Y             # 墙照各间北墙那套画（旧坐标 104～226），整条往下挪到墙脚 696（+470）
CAP0 = mk.CAP_Y0 + DY              # 墙顶剖面 574～584
DIV = (1195, 1205)                 # 休息间东边那道墙（只看得见墙顶）
DOOR = (1323, 1403)                # 门洞（跟原来一样，to_makeup 在 1363,702）
DOOR_TOP = 604                     # 门扇上沿（门高 92 ≈ 1.9 米）


def check_layout():
    d = json.load(open(LAYOUT, encoding="utf-8"))
    items = {it["id"]: it for it in d["items"] if "id" in it}
    pts = {p["id"]: p for p in d["points"]}
    bad = []
    if items["front_4"]["rect"][2] != DOOR[0] or items["front_5"]["rect"][0] != DOOR[1]:
        bad.append("门洞变了：front_4 %s、front_5 %s" % (items["front_4"]["rect"], items["front_5"]["rect"]))
    if items["wall_3"]["rect"][:3:2] != list(DIV):
        bad.append("wall_3 变了：%s" % items["wall_3"]["rect"])
    to = pts.get("to_makeup")
    if to is None or not (DOOR[0] < to["x"] < DOOR[1]):
        bad.append("to_makeup 不在门洞里：%s" % to)
    if bad:
        raise SystemExit("后厅布局跟这版画的对不上：\n" + "\n".join(bad))
    return [i for i in items if i.startswith("mk_")]


def frame(x0, y0, w, h):
    mk.X0, mk.Y0, mk.W, mk.H = x0, y0, w, h
    mk.X1, mk.Y1 = x0 + w, y0 + h


def draw_door(L):
    """关着的红漆双开门：木门套、门楣，两扇门各三排金门钉、一对金门环，中间一道门缝；光从左上来"""
    a, b = DOOR
    # 门套（两边、上面）
    L.rect(a - 6, DOOR_TOP - 8, b + 6, FOOT, "wd2")
    L.vl(a - 6, DOOR_TOP - 8, FOOT, "wd4")
    L.vl(a - 5, DOOR_TOP - 7, FOOT, "wd3")
    L.vl(b + 5, DOOR_TOP - 8, FOOT, "wd1")
    L.hl(a - 6, b + 6, DOOR_TOP - 8, "wd5")
    L.hl(a - 6, b + 6, DOOR_TOP - 7, "wd4")
    L.hl(a - 6, b + 6, DOOR_TOP - 1, "wd1")
    # 门楣上一条金线
    L.hl(a - 4, b + 4, DOOR_TOP - 4, "gd2")
    # 门扇
    mid = (a + b) // 2
    for (p0, p1, left) in ((a, mid, True), (mid, b, False)):
        L.rect(p0, DOOR_TOP, p1, FOOT, "rd3")
        L.vl(p0, DOOR_TOP, FOOT, "rd4" if left else "rd2")
        L.vl(p1 - 1, DOOR_TOP, FOOT, "rd2" if left else "rd1")
        L.hl(p0, p1, DOOR_TOP, "rd4")
        # 两块凹进去的门板
        for (q0, q1) in ((DOOR_TOP + 8, DOOR_TOP + 40), (DOOR_TOP + 52, FOOT - 10)):
            L.rect(p0 + 5, q0, p1 - 5, q1, "rd2")
            L.rect(p0 + 6, q0 + 1, p1 - 5, q1, "rd3")
            L.hl(p0 + 6, p1 - 5, q1 - 1, "rd4")
            L.vl(p1 - 6, q0 + 1, q1, "rd4")
        # 金门钉：上面那块门板里三排、每排三颗
        for r in range(3):
            for c in range(3):
                x = p0 + 11 + c * 9
                y = DOOR_TOP + 15 + r * 9
                L.rect(x, y, x + 3, y + 3, "gd2")
                L.p(x, y, "gd4")
                L.p(x + 2, y + 2, "gd1")
        # 门环（铺首）：靠门缝一边
        cx = p1 - 7 if left else p0 + 6
        cy = DOOR_TOP + 47
        L.ell(cx - 3, cy - 3, cx + 4, cy + 4, "gd1")
        L.ell(cx - 2, cy - 2, cx + 3, cy + 3, "gd3")
        L.p(cx - 1, cy - 1, "gd4")
        L.ring(cx - 4, cy + 1, cx + 5, cy + 10, "gd2", only=lambda x, y, cy=cy: y > cy + 3)
    L.vl(mid - 1, DOOR_TOP, FOOT, "rd0")                   # 门缝
    L.vl(mid, DOOR_TOP, FOOT, "rd1")
    # 门槛
    L.rect(a - 6, FOOT - 4, b + 6, FOOT, "wd1")
    L.hl(a - 6, b + 6, FOOT - 4, "wd4")
    L.hl(a - 6, b + 6, FOOT - 1, "wd0")


def door_wall():
    """那面墙（旧坐标画完往下挪）+ 门 + 灯笼 + 休息间东墙顶，一层"""
    frame(X0, TOP, X1 - X0, FOOT - TOP)
    W = mk.Layer(x0=X0, y0=mk.CAP_Y0, w=X1 - X0, h=mk.FLOOR_Y - mk.CAP_Y0)   # 旧坐标 104～226
    mk.WALL_W, mk.WALL_E = (X0, DIV[1]), (X1, X1 + 10)
    mk.X1 = X1
    mk.KNOTS = [DIV[1], 1264, DOOR[0], DOOR[1], 1470, X1]
    mk.draw_north_wall(W)
    mk.draw_swag(W)
    for kx in (DOOR[0] - 18, DOOR[1] + 18):              # 门两边一对红灯笼（挂在墙上）
        mk.draw_lantern(W, kx, 150, big=True)
    L = mk.Layer(x0=X0, y0=TOP, w=X1 - X0, h=FOOT - TOP)
    L.im.alpha_composite(W.im, (0, mk.CAP_Y0 + DY - TOP))
    draw_door(L)
    # 墙上门两边一点影（门套往右下错一像素）
    for y in range(DOOR_TOP - 7, FOOT - 4):
        x = DOOR[1] + 6
        L.shade_px(x, y, -1)
    # 休息间东边那道墙：从后厅北边墙顶一直连到这面墙顶，只看得见剖开的一条
    a, b = DIV
    L.rect(a, TOP, b, CAP0 + 1, "wl4")
    L.vl(a + 1, TOP + 1, CAP0, "wl5")
    L.vl(a, TOP, CAP0 + 1, "ol")
    L.vl(b - 1, TOP, CAP0 + 1, "ol")
    L.hl(a, b, TOP, "ol")
    return L


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    mk_ids = check_layout()
    wall = door_wall()
    bg = mk.Layer(x0=X0, y0=TOP, w=X1 - X0, h=FOOT - TOP)
    bg.rect(X0, TOP, X1, FOOT, "void")
    for im in (bg.im, wall.im):
        mk.palette_count(im)
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    bg.im.save(os.path.join(OUT, "room.png"))
    box = wall.im.getbbox()
    wall.im.crop(box).save(os.path.join(OUT, "props", "door_wall.png"))
    man = {"note": "tools/pixel_art/backhall_makeup_door.py 生成，别手改。后厅长条里原来那间化妆室封起来：背景是墙后面那块（涂深色），"
                   "door_wall 是那面墙连门、灯笼；hide 藏掉原来那间的家具灰盒和 wall_3、front_5（只藏画，挡人的占地照旧）",
           "background": {"png": RES + "room.png", "x": X0, "y": TOP}, "room": {"x0": X0, "x1": X1},
           "props": [{"id": "px_makeup_door_wall", "png": RES + "props/door_wall.png", "x": X0 + box[0], "y": TOP + box[1],
                      "foot": FOOT, "hide": sorted(mk_ids) + ["wall_3", "front_5", "makeup_door"]}]}
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    cols = mk.palette_count(wall.im) | mk.palette_count(bg.im)
    print("墙连门 %s，颜色 %d 种，藏 %d 件灰盒 → %s" % (wall.im.crop(box).size, len(cols), len(man["props"][0]["hide"]), OUT))
    if preview:
        os.makedirs(preview, exist_ok=True)
        out = bg.im.copy()
        out.alpha_composite(wall.im)
        out.save(os.path.join(preview, "封起来的墙.png"))
        out.resize((out.width * 2, out.height * 2), Image.NEAREST).crop((0, 900, 682, 1184)).save(os.path.join(preview, "封起来的墙-门放大.png"))


if __name__ == "__main__":
    main()
