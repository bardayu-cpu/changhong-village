#!/usr/bin/env python3
"""罗曼山庄全景地图的数据（07 10/4，蓝图第 22 条，01 H 派）：出 assets/map/estate_map.json，scripts/estate_map.gd 照它用代码画地图、点了传送。
阿鱼原话：「但是地区位太大了呢，你就需要有一些直达的切换的路径。所以左上角应该是能够看到这一整个地图，然后用户点了之后就可以问他确认一下是不是要直接传送过去，
或者点了之后就直接传送好吧」「这个地图这种展开的区域地图的话，你也可以把它做一张地图，就绘制得好一点。如果你不会画，你就让GPT来帮你画得更写真一点」

每块在地图上摆哪、多大：MAP（这份里，地图像素，512 宽）。方向、谁挨着谁跟连法总图（link_map.py 的 BOXES，第 68 版新位置）一样——前门在下、湖在上、草坪在左；
  但连法总图那种比例在手机上小块太窄（儿童乐园、小卖部只有 47 像素宽，名字写不下），地图这边把小块放大到写得下两行 24 像素的字。块挪了、加了块改 MAP；
路：照各块布局里写了 to 的口现算（跟 link_map.py 同一套），哪块加了口、挪了口，重跑这份地图跟着变；
传送站哪：每块挑一个「门口」（DOOR，那块布局里口的 id），游戏里照那块的 arrival_at(口) 算站点（口里边、能走的地上）；迎宾院站大门里边、宴会厅站厅门口。
用法：python3 godot/tools/layout_court/make_estate_map.py
"""
import json
import os

import link_map

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "map", "estate_map.json")

# 地图上写的名字（短的；BOXES 里的是给 01 看的长说明）
NAMES = {"court": "迎宾院", "banquet": "宴会厅", "backhall": "后厅", "lawn": "草坪", "lake": "湖边", "orchard": "果园",
         "parking": "停车场", "plaza": "喷泉广场", "kids": "儿童乐园", "shop": "小卖部", "rest2": "休息厅 2", "wkitchen": "西餐厨房",
         "garden": "后花园", "frontgate": "前门", "backgate": "后门"}
# 传送过去站哪个口里边（"spawn" = 那块的出生点：迎宾院是大门里边、宴会厅是厅门口）
DOOR = {"court": "spawn", "banquet": "spawn", "backhall": "to_plaza", "lawn": "to_plaza", "lake": "to_garden", "orchard": "to_lawn",
        "parking": "to_plaza", "plaza": "to_frontgate", "kids": "to_plaza", "shop": "to_plaza", "rest2": "to_plaza", "wkitchen": "to_plaza",
        "garden": "to_banquet", "frontgate": "to_plaza", "backgate": "to_orchard"}
# 画什么样：屋子（木墙瓦顶色）、户外（草）、水、停车场（沥青）、门楼（红）、广场（石板）
KIND = {"court": "yard", "banquet": "hall", "backhall": "hall", "lawn": "grass", "lake": "water", "orchard": "grass", "parking": "lot",
        "plaza": "plaza", "kids": "grass", "shop": "house", "rest2": "house", "wkitchen": "house", "garden": "grass", "frontgate": "gate",
        "backgate": "gate"}
# 地图上每块摆哪（地图像素 x0, y0, x1, y1；512 宽，北在上）。谁挨着谁照连法总图：草坪在西一长条；后厅、宴会厅、后花园一排；广场在正中，
# 迎宾院在广场东边、宴会厅下面；停车场在迎宾院、后花园下面；前门在广场正下方，西边挨着休息厅 2、小卖部、儿童乐园
MAP = {
    "backgate": (64, 0, 144, 36),
    "orchard": (0, 46, 250, 118),
    "lake": (268, 34, 512, 100),
    "lawn": (0, 140, 84, 336),
    "backhall": (98, 140, 332, 196),
    "banquet": (346, 118, 430, 258),
    "garden": (444, 140, 512, 250),
    "wkitchen": (98, 210, 176, 268),
    "plaza": (190, 210, 332, 336),
    "court": (346, 272, 430, 336),
    "parking": (346, 350, 512, 446),
    "frontgate": (222, 350, 300, 410),
    "rest2": (148, 350, 214, 410),
    "shop": (76, 350, 142, 410),
    "kids": (0, 350, 70, 410),
}
LINES = {"title": "罗曼山庄", "go_fmt": "去%s？", "yes": "去", "no": "不去", "here": "你就在这里", "close": "关上", "me": "你"}


def main():
    data = {k: link_map.load(k) for k in link_map.BOXES}
    blocks = []
    for k, (_, rect) in link_map.BOXES.items():
        blocks.append({"id": k, "name": NAMES[k], "rect": list(MAP[k]), "size": list(data[k][0]), "door": DOOR[k], "kind": KIND[k]})

    def at(k, p):
        (W, H) = data[k][0]
        x0, y0, x1, y1 = MAP[k]
        return [round(x0 + (x1 - x0) * p["x"] / W, 1), round(y0 + (y1 - y0) * p["y"] / H, 1)]

    roads, seen = [], set()
    for a in link_map.BOXES:
        for p in data[a][1]:
            b = p["to"]
            if b not in data:
                continue
            back = [q for q in data[b][1] if q["to"] == a]
            if p.get("via"):
                back = [q for q in back if q["id"] == p["via"]]
            elif len(back) > 1:
                back = [q for q in back if q.get("via") == p["id"]] or back
            if not back:
                continue
            key = tuple(sorted([(a, p["id"]), (b, back[0]["id"])]))
            if key in seen:
                continue
            seen.add(key)
            roads.append([a, b] + at(a, p) + at(b, back[0]))
    xs = [v for b in blocks for v in (b["rect"][0], b["rect"][2])]
    ys = [v for b in blocks for v in (b["rect"][1], b["rect"][3])]
    out = {
        "note": "罗曼山庄全景地图（07 10/4，蓝图第 22 条）。tools/layout_court/make_estate_map.py 生成，别手改；各块挪了、加了口重跑。"
                "rect 是地图上的位置（地图像素 512 宽；方向、谁挨着谁照连法总图：前门在下、湖在上、草坪在左；小块放大到写得下名字）；size 是那块画布多大（标「你在这」照它换算）；"
                "door 是传送过去站哪个口里边（spawn = 出生点）；roads 是两块之间能直接走过去的路（两头的口在地图上的位置）。lines 是界面上的字，待校对",
        "status": "待校对",
        "lines": LINES,
        "bounds": [min(xs), min(ys), max(xs), max(ys)],
        "blocks": blocks,
        "roads": roads,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("{\n")
        keys = list(out.keys())
        for i, k in enumerate(keys):
            v = out[k]
            comma = "," if i < len(keys) - 1 else ""
            if isinstance(v, list) and v and isinstance(v[0], (dict, list)):
                f.write(' "%s": [\n' % k)
                for j, x in enumerate(v):
                    f.write("  " + json.dumps(x, ensure_ascii=False) + ("," if j < len(v) - 1 else "") + "\n")
                f.write(" ]%s\n" % comma)
            else:
                f.write(' "%s": %s%s\n' % (k, json.dumps(v, ensure_ascii=False), comma))
        f.write("}\n")
    print("写了 %s：%d 块、%d 条路" % (OUT, len(blocks), len(roads)))


if __name__ == "__main__":
    main()
