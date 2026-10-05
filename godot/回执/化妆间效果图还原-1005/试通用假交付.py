#!/usr/bin/env python3
"""试通用的假交付（02 F，10/5）：GPT 的积木还没交，先拿整张效果图当底图、照 02 F 量的坐标从同一张图上裁方块当零件，
写一份跟任务原文（拆景台 1005 第 5 条）同样格式的 placement.json，给 tools/import_makeup_blocks.py 试通「能拼、能走、能坐」。GPT 交了直接换真的，这份作废。
零件是从底图同一处裁的方块，拼回去看不出差别；人走到它后面才被挡（方块连着一圈地板，挡人时边是直的，真零件是透明底，就没这个毛病）。
坐标照 效果图量的坐标.md（原图像素）。占地 = 每件着地线往北一小条（斜俯视，家具只挡地上那一截）。

用法：python3 试通用假交付.py <输出目录>   （效果图从 git 98f798f 取，不往仓库里多放一份）
"""
import json
import os
import subprocess
import sys
from io import BytesIO

from PIL import Image

REF = "98f798f:docs/参考图/化妆间效果图-GPT-阿鱼10-05.png"

# 名字、图上外框 x0, 顶, x1, 脚、占地前后多深、座位（脚点，原图像素）
PARTS = [
    ("corner_w", 30, 30, 130, 250, 40, []), ("corner_e", 810, 45, 912, 250, 40, []),
    ("dresser_1", 145, 75, 297, 245, 45, []), ("dresser_2", 317, 75, 462, 245, 45, []),
    ("dresser_3", 480, 75, 622, 245, 45, []), ("dresser_4", 642, 75, 795, 245, 45, []),
    ("stool_1", 197, 212, 247, 272, 24, [(222, 274)]), ("stool_2", 363, 212, 413, 272, 24, [(388, 274)]),
    ("stool_3", 526, 212, 576, 272, 24, [(551, 274)]), ("stool_4", 691, 212, 741, 272, 24, [(716, 274)]),
    ("rack_w1", 30, 268, 275, 470, 30, []), ("cab_w1", 280, 290, 322, 462, 24, []),
    ("rack_w2", 30, 480, 250, 650, 30, []), ("mirror_w", 258, 495, 332, 692, 16, []),
    ("rack_w3", 30, 655, 250, 838, 30, []), ("shoes_w", 256, 700, 318, 842, 24, []),
    ("rack_w4", 30, 845, 232, 1027, 30, []), ("cab_w4", 230, 875, 312, 1012, 30, []),
    ("fit_w", 35, 1030, 270, 1215, 95, []), ("fit_stool_w", 87, 1175, 137, 1228, 24, [(112, 1230)]),
    ("cab_fit_w", 28, 1105, 78, 1218, 30, []), ("lamp_w", 25, 1232, 62, 1342, 16, []),
    ("sofa_red", 60, 1262, 268, 1388, 70, [(115, 1392), (165, 1392), (215, 1392)]),
    ("cab_sofa_w", 268, 1255, 322, 1392, 30, []), ("table_w", 105, 1362, 218, 1448, 40, []),
    ("pouf_w", 48, 1392, 108, 1458, 30, [(78, 1460)]), ("chest_w", 253, 1462, 317, 1497, 20, []),
    ("cab_e1", 615, 285, 662, 467, 24, []), ("rack_e1", 660, 268, 887, 472, 30, []),
    ("mirror_e", 622, 492, 692, 683, 16, []), ("rack_e2", 690, 478, 887, 652, 30, []),
    ("shoes_e", 622, 688, 692, 842, 24, []), ("rack_e3", 690, 655, 867, 842, 30, []),
    ("cab_e4", 642, 855, 712, 1012, 30, []), ("rack_e4", 708, 845, 887, 1032, 30, []),
    ("fit_e", 670, 1030, 890, 1215, 95, []), ("fit_stool_e", 803, 1182, 857, 1238, 24, [(830, 1240)]),
    ("cab_fit_e", 862, 1115, 912, 1228, 30, []), ("lamp_e", 882, 1228, 918, 1338, 16, []),
    ("sofa_cream", 668, 1268, 888, 1388, 70, [(725, 1392), (778, 1392), (830, 1392)]),
    ("cab_sofa_e", 618, 1255, 672, 1392, 30, []), ("table_e", 708, 1392, 802, 1462, 40, []),
    ("armchair_e", 822, 1362, 912, 1468, 40, [(867, 1472)]), ("chest_e", 622, 1462, 687, 1497, 20, []),
    ("jewel_1", 352, 418, 588, 592, 40, []), ("jewel_2", 352, 705, 588, 902, 40, []), ("jewel_3", 352, 1015, 588, 1202, 40, []),
    ("door_flower_w", 343, 1402, 397, 1482, 24, []), ("door_flower_e", 543, 1402, 597, 1482, 24, []),
]


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    raw = subprocess.run(["git", "show", REF], capture_output=True, check=True).stdout
    ref = Image.open(BytesIO(raw)).convert("RGBA")
    ref.save(os.path.join(out, "base.png"))
    items = []
    for (n, x0, y0, x1, y1, dep, seats) in PARTS:
        f = "blk_%s.png" % n
        ref.crop((x0, y0, x1, y1)).save(os.path.join(out, f))
        p = {"id": n, "file": f, "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "foot_y": y1, "footprint": [x0, y1 - dep, x1 - x0, dep]}
        if seats:
            p["seats"] = [list(s) for s in seats]
        items.append(p)
    d = {"说明": "试通用假交付（02 F）：不是 GPT 交的，GPT 交了作废", "image": {"w": ref.width, "h": ref.height}, "base": "base.png",
         "doors": [{"id": "south", "rect": [395, 1500, 150, 50]}], "blocked": [], "items": items}
    json.dump(d, open(os.path.join(out, "placement.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("写了 %d 件 → %s" % (len(PARTS), out))


if __name__ == "__main__":
    main()
