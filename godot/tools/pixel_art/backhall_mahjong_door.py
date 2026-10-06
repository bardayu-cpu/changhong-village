#!/usr/bin/env python3
"""后厅长条里原来那间麻将室封起来：改成一面墙加一扇门（庄Z1 10/6 派娱乐室接进游戏，庄Z2）。
娱乐室单独成了一间屋（tools/pixel_art/room_entertainment_gpt.py），后厅走廊走到门口整屏换进去；长条里原来那间不再露出来。
画法跟化妆间那扇一模一样（tools/pixel_art/backhall_makeup_door.py：墙纸、护墙板、红绸、红漆双开门、一对灯笼，墙后画成屋顶），只换位置：
  墙 x 523～859（西边跟后厨共用的 wall_1 523～533 只看得见墙顶；东边 wall_2 照旧），门洞 656～736（前墙 front_2、front_3 中间那段，to_mahjong 在 696,702）
门口「娱乐室」牌是游戏里的字牌（后厅布局 signs），不画进图。
这份同时改后厅布局（scene_luoman_backhall/layout.json）：pixel_art 里 backhall_mahjong → backhall_mahjong_door；门洞加挡板 mahjong_door；
加交互点 to_mahjong（走进门洞整屏换进娱乐室）、去掉原来那间里的 mahjong 点；原来那 14 位（life: mahjong）搬走；门牌「麻将室」→「娱乐室」。
用法：python3 godot/tools/pixel_art/backhall_mahjong_door.py [--preview 目录]
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import backhall_makeup_door as bd
mk = bd.mk

GODOT = bd.GODOT
LAYOUT = bd.LAYOUT
OLD = os.path.join(GODOT, "assets", "pixel_art", "backhall_mahjong", "room.json")
OUT = os.path.join(GODOT, "assets", "pixel_art", "backhall_mahjong_door")
RES = "res://assets/pixel_art/backhall_mahjong_door/"

bd.X0, bd.X1 = 523, 859
bd.DIV = (523, 533)
bd.DOOR = (656, 736)


def door_wall():
    """照 backhall_makeup_door.door_wall，挂灯笼、红绸打结的位置换成这面墙的"""
    X0, X1, DIV, DOOR, TOP, FOOT = bd.X0, bd.X1, bd.DIV, bd.DOOR, bd.TOP, bd.FOOT
    bd.frame(X0, TOP, X1 - X0, FOOT - TOP)
    W = mk.Layer(x0=X0, y0=mk.CAP_Y0, w=X1 - X0, h=mk.FLOOR_Y - mk.CAP_Y0)
    mk.WALL_W, mk.WALL_E = (X0, DIV[1]), (X1, X1 + 10)
    mk.X1 = X1
    mk.KNOTS = [DIV[1], 594, DOOR[0], DOOR[1], 798, X1]
    mk.draw_north_wall(W)
    mk.draw_swag(W)
    for kx in (DOOR[0] - 18, DOOR[1] + 18):
        mk.draw_lantern(W, kx, 150, big=True)
    L = mk.Layer(x0=X0, y0=TOP, w=X1 - X0, h=FOOT - TOP)
    L.im.alpha_composite(W.im, (0, mk.CAP_Y0 + bd.DY - TOP))
    bd.draw_door(L)
    for y in range(bd.DOOR_TOP - 7, FOOT - 4):
        L.shade_px(DOOR[1] + 6, y, -1)
    a, b = DIV
    L.rect(a, TOP, b, bd.CAP0 + 1, "wl4")
    L.vl(a + 1, TOP + 1, bd.CAP0, "wl5")
    L.vl(a, TOP, bd.CAP0 + 1, "ol")
    L.vl(b - 1, TOP, bd.CAP0 + 1, "ol")
    L.hl(a, b, TOP, "ol")
    return L


def edit_layout(hide_ids):
    d = json.load(open(LAYOUT, encoding="utf-8"))
    items = {it.get("id"): it for it in d["items"]}
    if items["front_2"]["rect"][2] != bd.DOOR[0] or items["front_3"]["rect"][0] != bd.DOOR[1]:
        raise SystemExit("门洞变了：front_2 %s、front_3 %s" % (items["front_2"]["rect"], items["front_3"]["rect"]))
    d["pixel_art"] = [RES + "room.json" if p.endswith("backhall_mahjong/room.json") else p for p in d["pixel_art"]]
    if "mahjong_door" not in items:
        i = next(k for k, it in enumerate(d["items"]) if it.get("id") == "front_3")
        d["items"].insert(i, {"type": "box", "id": "mahjong_door", "rect": [bd.DOOR[0], 684, bd.DOOR[1], 696], "h": 22, "top": "#8a6048",
                              "front": "#5a3f30", "scale": {"h_m": 0.45},
                              "note": "10/6 原来那间麻将室封起来（庄Z2）：门洞挡上，走到门口 to_mahjong 换进单独那间娱乐室"})
    d["points"] = [p for p in d["points"] if p["id"] != "mahjong"]
    if not any(p["id"] == "to_mahjong" for p in d["points"]):
        mid = (bd.DOOR[0] + bd.DOOR[1]) // 2
        d["points"].append({"id": "to_mahjong", "x": mid, "y": 702, "r": 26, "to": "mahjong", "arrive": [mid, 790],
                            "note": "娱乐室门口：一走进门洞就整屏换进娱乐室（10/6 庄Z2，照化妆间那扇）；从屋里出来站在门口外的走廊上"})
    moved = [n["id"] for n in d["npcs"] if str(n.get("life", "")) == "mahjong"]
    d["npcs"] = [n for n in d["npcs"] if str(n.get("life", "")) != "mahjong"]
    for sg in d.get("signs", []):
        if sg.get("text") == "麻将室":
            sg["text"] = "娱乐室"
    with open(LAYOUT, "w", encoding="utf-8") as fh:
        fh.write("{\n")
        keys = list(d.keys())
        for i, k in enumerate(keys):
            v = d[k]
            comma = "," if i < len(keys) - 1 else ""
            if isinstance(v, list) and v and isinstance(v[0], dict):
                fh.write(' "%s": [\n' % k)
                for j, x in enumerate(v):
                    fh.write("  " + json.dumps(x, ensure_ascii=False) + ("," if j < len(v) - 1 else "") + "\n")
                fh.write(" ]%s\n" % comma)
            else:
                fh.write(' "%s": %s%s\n' % (k, json.dumps(v, ensure_ascii=False), comma))
        fh.write("}\n")
    return moved


def main():
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    old = json.load(open(OLD, encoding="utf-8"))
    hide = set()
    for p in old["props"]:
        hide |= set(p.get("hide", []))
    wall = door_wall()
    bg = mk.Layer(x0=bd.X0, y0=bd.TOP, w=bd.X1 - bd.X0, h=bd.FOOT - bd.TOP)
    bg.rect(bd.X0, bd.TOP, bd.X1, bd.FOOT, "void")
    bd.draw_roof(bg)
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    bg.im.save(os.path.join(OUT, "room.png"))
    box = wall.im.getbbox()
    wall.im.crop(box).save(os.path.join(OUT, "props", "door_wall.png"))
    man = {"note": "tools/pixel_art/backhall_mahjong_door.py 生成，别手改。后厅长条里原来那间麻将室封起来：背景是墙后面那块（画成这间的屋顶），"
                   "door_wall 是那面墙连门、灯笼；hide 藏掉原来那间的家具灰盒和 wall_1、门洞挡板（只藏画，挡人的占地照旧）",
           "background": {"png": RES + "room.png", "x": bd.X0, "y": bd.TOP}, "room": {"x0": bd.X0, "x1": bd.X1},
           "props": [{"id": "px_mahjong_door_wall", "png": RES + "props/door_wall.png", "x": bd.X0 + box[0], "y": bd.TOP + box[1],
                      "foot": bd.FOOT, "hide": sorted(hide | {"wall_1", "mahjong_door"})}]}
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    moved = edit_layout(hide)
    print("墙连门 %s，藏 %d 件灰盒；后厅布局：门洞挡上、加 to_mahjong、搬走 %d 位（%s）、门牌改娱乐室 → %s" % (
        wall.im.crop(box).size, len(man["props"][0]["hide"]), len(moved), "、".join(moved), OUT))
    if preview:
        os.makedirs(preview, exist_ok=True)
        out = bg.im.copy()
        out.alpha_composite(wall.im)
        out.save(os.path.join(preview, "娱乐室门-封起来的墙.png"))


if __name__ == "__main__":
    main()
