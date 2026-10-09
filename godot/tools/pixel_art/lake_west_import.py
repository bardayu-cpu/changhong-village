#!/usr/bin/env python3
"""湖边西半边接进游戏（02 E 10/4，01 G 派：01 画的样板间 godot/回执/样板间-湖边西半边/，a1a7d6b，01 G 看过收下）。
照东半边第 58 版的接法（tools/pixel_art/lake_east.py 末尾那段）：
  图层：layers/bg_lake_west.png → assets/pixel_art/lake_west/room.png；立着的 137 张 → props/，写 room.json（entrance.gd 的 _pixel_art() 读；
        坐标就是游戏坐标，西半边不加偏移；id 前面加 px_w_，免得跟东半边同名的图层撞节点名）
  摆法：layout_west.json → tools/layout_court/lake_west.json（make_lake_long.py 拼进湖边布局）。每件标 on_art：画在像素图层里了，
        游戏只算挡人占地、不再画灰盒（跟东半边一样）；to_orchard 通果园（样板里写的「待定」，01 G 定通果园 A）
样板（draw_lake_west.py）是 01 的，改图在样板那边改、重出 layers/ 和 layout_west.json，再跑这个。
用法：python3 godot/tools/pixel_art/lake_west_import.py
"""
import json
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(GODOT, "回执", "样板间-湖边西半边")
OUT = os.path.join(GODOT, "assets", "pixel_art", "lake_west")
RES = "res://assets/pixel_art/lake_west/"
LAYOUT_OUT = os.path.join(GODOT, "tools", "layout_court", "lake_west.json")


def main():
    lay = json.load(open(os.path.join(SRC, "layers", "layers.json"), encoding="utf-8"))
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    shutil.copyfile(os.path.join(SRC, "layers", lay["base"]["png"]), os.path.join(OUT, "room.png"))
    man = {"note": "tools/pixel_art/lake_west_import.py 从 godot/回执/样板间-湖边西半边/layers/ 拷来，别手改（改图在样板那边改、重跑）。"
                   "背景左上角放在 background.x/y（画布坐标），1 倍、不插值；每件左上角在 x/y，着地线 foot（跟人排前后）。"
                   "灰盒那边对应的东西标了 on_art，只算挡人占地、不画，所以这里不用 hide",
           "background": {"png": RES + "room.png", "x": int(lay["base"]["x"]), "y": int(lay["base"]["y"])}, "props": []}
    names = set()
    for L in lay["layers"]:
        shutil.copyfile(os.path.join(SRC, "layers", L["png"]), os.path.join(OUT, "props", L["png"]))
        names.add(L["png"])
        man["props"].append({"id": "px_w_" + L["name"], "png": RES + "props/" + L["png"], "x": int(L["x"]), "y": int(L["y"]),
                             "foot": int(L["foot_y"]), "hide": []})
    for f in os.listdir(os.path.join(OUT, "props")):   # 样板里删掉的别留旧图
        if f.endswith(".png") and f not in names:
            os.remove(os.path.join(OUT, "props", f))
    with open(os.path.join(OUT, "room.json"), "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    w = json.load(open(os.path.join(SRC, "layout_west.json"), encoding="utf-8"))
    for it in w["items"]:
        it["on_art"] = True
    for p in w["points"]:
        if p.get("to") == "待定":
            p["to"] = "orchard"
            p["note"] = "南墙西头月亮门（x 768，跟东头 2304 对称），门洞往南出去是果园 A（方案 C，01 G 10/4 定）"
    for n in w["npcs"]:   # 码头船夫：点他走到跟前说话（03 报过码头船夫跟前要能站、能点；台词待校对）
        if n["id"] == "boatman_1":
            n["dialogue"] = "res://assets/lake/dialogue/boatman_1.dialogue"
            n["title"] = "船夫"
    w["note"] += "　02 E 10/4 接进游戏：tools/pixel_art/lake_west_import.py 拷来，每件标 on_art（只算挡人、不画灰盒），to_orchard 通果园"
    with open(LAYOUT_OUT, "w", encoding="utf-8") as fh:
        json.dump(w, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print("背景 + 立着的 %d 张 → %s；摆法 %d 件、%d 个点 → %s" % (len(man["props"]), OUT, len(w["items"]), len(w["points"]), LAYOUT_OUT))


if __name__ == "__main__":
    main()
