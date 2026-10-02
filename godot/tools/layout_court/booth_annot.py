#!/usr/bin/env python3
"""展位标注图（01 E 10/3）：在整块俯视截图上，每件东西按零件编号框出来、写上编号，每个人框出来、写上 LM 编号。
只出给 01、03 看的回执图，不进游戏（游戏里玩家看不到这些字，test_no_dev_text 管）。
数从两处拿，不另算：
  assets/layered/scene_luoman_<场景>/layout.json  items 的 part / inst（第几件），npcs 的 lm
  回执/零件规格/<中文>/<中文>-框.json             gen_specs_court.py 量的每件东西画出来的外框（连高度）
同一个 inst 的几块（礼服架 = 两根柱子 + 横杆 + 礼服 + 底座）合成一个框。人：站着的框 36 宽、高 84 × size；坐着的高 62（ASSETS §15）。
用法：python3 godot/tools/layout_court/booth_annot.py <场景> <整块截图.png> <出的标注图.png>
      截图用 capture.sh 的 <场景>_overview，分辨率跟画布一样（RES=1536x1024 / 1536x1280），一像素就是画布上一像素
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
SCENES = {"lawn": ("scene_luoman_lawn", "草坪"), "lake": ("scene_luoman_lake", "湖边"),
          "orchard": ("scene_luoman_orchard", "果园"), "backhall": ("scene_luoman_backhall", "后厅")}
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
PART = (255, 0, 200)     # 东西的框：洋红
PEOPLE = (0, 200, 255)   # 人的框：青


def main():
    scene, shot, out = sys.argv[1], sys.argv[2], sys.argv[3]
    folder, cn = SCENES[scene]
    layout = json.load(open(os.path.join(GODOT, "assets", "layered", folder, "layout.json"), encoding="utf-8"))
    boxes = {it["id"]: it["box"] for it in json.load(open(os.path.join(GODOT, "回执", "零件规格", cn, "%s-框.json" % cn), encoding="utf-8"))["items"]}
    im = Image.open(shot).convert("RGB")
    W, H = layout["size"]
    if im.size != (W, H):
        raise SystemExit("截图 %s 不是画布大小 %s（RES 要跟画布一样）" % (im.size, (W, H)))
    dim = Image.new("RGB", im.size, (255, 255, 255))
    im = Image.blend(im, dim, 0.25)   # 底图淡一点，框和字看得清
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 11)
    groups = {}
    for it in layout["items"]:
        inst = it.get("inst")
        if not inst or it.get("id") not in boxes:
            continue
        b = boxes[it["id"]]
        g = groups.setdefault(inst, [b[0], b[1], b[2], b[3]])
        g[:] = [min(g[0], b[0]), min(g[1], b[1]), max(g[2], b[2]), max(g[3], b[3])]
    for inst, b in groups.items():
        d.rectangle(b, outline=PART, width=1)
    for n in layout.get("npcs", []):
        if "lm" not in n:
            continue
        x, y = float(n["x"]), float(n["y"])
        h = 62.0 if n.get("sit") else 84.0 * float(n.get("size", 1.0))
        d.rectangle([x - 18, y - h, x + 18, y], outline=PEOPLE, width=1)
    # 字后写，压在框上面
    for inst, b in groups.items():
        t = inst.split("-", 1)[1]   # LW-P03-07 → P03-07
        tw = d.textlength(t, font=f)
        x = max(0, min(W - tw - 2, b[0]))
        y = max(0, b[1] - 12)
        d.rectangle([x, y, x + tw + 2, y + 12], fill=(255, 255, 255))
        d.text((x + 1, y), t, font=f, fill=PART)
    for n in layout.get("npcs", []):
        if "lm" not in n:
            continue
        t = n["lm"].replace("LM-", "")
        x, y = float(n["x"]), float(n["y"])
        tw = d.textlength(t, font=f)
        tx = max(0, min(W - tw - 2, x - tw / 2))
        d.rectangle([tx, y + 1, tx + tw + 2, y + 13], fill=(255, 255, 255))
        d.text((tx + 1, y + 1), t, font=f, fill=(0, 120, 170))
    d.rectangle([8, H - 34, 560, H - 8], fill=(255, 255, 255))
    pre = {"lawn": "LW", "lake": "LK", "orchard": "OR", "backhall": "BH"}[scene]
    d.text((14, H - 30), "%s展位 · 洋红框 = 零件（%s-编号-第几件），青框 = 人（LM 编号）" % (cn, pre),
           font=ImageFont.truetype(FONT, 16), fill=(40, 40, 40))
    im.save(out)
    print("%s：零件 %d 件、人 %d 位 → %s" % (cn, len(groups), sum(1 for n in layout.get("npcs", []) if "lm" in n), out))


if __name__ == "__main__":
    main()
