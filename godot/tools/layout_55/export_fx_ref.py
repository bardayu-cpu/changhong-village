#!/usr/bin/env python3
"""宴会厅彩带与飘落（docs/宴会厅-彩带与飘落-说明.md，01 E 10/2 派，03 做）：出给 GPT 照着画的参考，放 godot/回执/出图-宴会厅彩带/
  红绸-底.png / 红绸-色块参考.png / 红绸-色块参考-放大3倍.png   红毯第 1、2 排灯柱 1:1（shot.sh 截的，不放人没界面），红绸的框和两个挂点画在上面
  片大小-参考.png / 片大小-参考-放大4倍.png                     花瓣 12×12、彩纸 8×8、卷彩带 16×32 的格子（占位形状），旁边站 84 像素的人，底分地砖、红毯两半
  片大小-手机屏模拟.png                                          540×960 手机截图上撒一把这三种片（按镜头缩放 0.9375 缩），看认不认得出
  宴会厅彩带-零件单.md / .json                                    B55S-P06 红绸、B55S-FX01 花瓣、FX02 彩纸、FX03 卷彩带
灯柱的数全从游戏真在用的零件图 art_lantern.png 量（量的不是抄 01 的），底图里灯柱位置跟摆位表逐像素对（偏差 0）。
用法：python3 godot/tools/layout_55/export_fx_ref.py 底图.png 手机屏.png 输出目录
      底图 = shot.sh <提交> --rect=568,310,400,300 --out=…；手机屏 = shot.sh <提交> --rect=0,1200,1536,1024 --people=1 --ui=1 --feast=feast --out=…
"""
import importlib.util
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
SCENE_DIR = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
BASE_PNG, PHONE_PNG, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
CROP = (568, 310, 400, 300)   # 底图在整厅里的位置 x, y, w, h

sys.argv = [sys.argv[0]]
spec = importlib.util.spec_from_file_location("board", os.path.join(HERE, "make_board55.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)
ITEMS = B.build()[0]


def measure_lamp():
    """从零件图量灯柱：花冠底、灯身左右、花冠左右最宽处。花冠底 = 宽度从花冠（≥26）掉到灯身（23）那一行"""
    art = Image.open(os.path.join(SCENE_DIR, "art_lantern.png")).convert("RGBA")
    a = art.getchannel("A")
    W, H = art.size
    widths = []
    for y in range(H):
        xs = [x for x in range(W) if a.getpixel((x, y))]
        widths.append((min(xs), max(xs)) if xs else None)
    body = widths[40]                                  # 灯身（玻璃罩）取 y 40 那行
    crown_rows = [y for y in range(0, 36) if widths[y] and widths[y][1] - widths[y][0] + 1 > body[1] - body[0] + 1 + 2]
    crown_top, crown_bottom = min(y for y in range(H) if widths[y]), max(crown_rows)
    wmax = max(widths[y][1] - widths[y][0] + 1 for y in crown_rows)
    row_max = [y for y in crown_rows if widths[y][1] - widths[y][0] + 1 == wmax][0]
    foot = [it for it in ITEMS if "红毯西侧落地宫灯（第 1 排）" == it["name"]][0]
    return {"size": art.size, "bbox": a.point(lambda v: 255 if v else 0).getbbox(), "body_x": body, "body_center": (body[0] + body[1]) / 2.0,
            "crown_top": crown_top, "crown_bottom": crown_bottom, "crown_x_at_widest": widths[row_max], "crown_widest_row": row_max,
            "foot_in_image": (foot["foot"][0] + foot["foot"][2] // 2 - foot["box"][0], foot["foot"][1] + foot["foot"][3] - foot["box"][1])}


def lamp_pairs():
    """每一对灯柱（第 N 排）：西、东灯的框 x、y"""
    out = {}
    for it in ITEMS:
        if "红毯" in it["name"] and "落地宫灯" in it["name"]:
            n = int(it["name"].split("第 ")[1].split(" ")[0])
            out.setdefault(n, {})["w" if "西侧" in it["name"] else "e"] = it["box"]
    return [(n, out[n]["w"], out[n]["e"]) for n in sorted(out)]


def font(s):
    return ImageFont.truetype(FONT, s)


def txt(d, xy, s, fnt, col=(255, 255, 255), anchor="lm"):
    d.text(xy, s, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=2, stroke_fill=(0, 0, 0, 255))


def main():
    os.makedirs(OUT, exist_ok=True)
    lamp = measure_lamp()
    pairs = lamp_pairs()
    # 挂点：灯身中线（量出来的）、花冠底往下 1 行（灯身开始那行）。01 的数：脚点 25、花冠底 30；量到：灯身中线 24、花冠底 31
    hook_x_art = int(round(lamp["body_center"]))        # 灯身中线（图里 x）
    hook_y_art = lamp["crown_bottom"]                    # 花冠最下一行
    CELL_W, CELL_H = 200, 56
    HOOK_Y_IN_CELL = 6
    n1, w1, e1 = pairs[0]
    span = (e1[0] + hook_x_art) - (w1[0] + hook_x_art)  # 两个挂点相距
    hook_l_in_cell = (CELL_W - span) // 2 + 0           # 先居中，下面再算
    hook_l_in_cell = 11
    hook_r_in_cell = hook_l_in_cell + span
    cell_dx = (w1[0] + hook_x_art) - hook_l_in_cell      # 格子左上角 x（整厅）
    cell_dy = (w1[1] + hook_y_art) - HOOK_Y_IN_CELL      # 格子左上角 y（整厅）
    # ---- 1. 红绸色块参考 ----
    base = Image.open(BASE_PNG).convert("RGB")
    assert base.size == (CROP[2], CROP[3]), base.size
    base.save(os.path.join(OUT, "红绸-底.png"))
    ref = base.convert("RGBA")
    ov = Image.new("RGBA", ref.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    f12, f14 = font(12), font(14)
    for n, w, e in pairs:
        if not (CROP[1] <= w[1] + hook_y_art - HOOK_Y_IN_CELL < CROP[1] + CROP[3] - CELL_H):
            continue
        cx0 = w[0] + hook_x_art - hook_l_in_cell - CROP[0]
        cy0 = w[1] + hook_y_art - HOOK_Y_IN_CELL - CROP[1]
        d.rectangle([cx0, cy0, cx0 + CELL_W - 1, cy0 + CELL_H - 1], fill=(60, 120, 255, 70), outline=(255, 255, 255, 255))
        for hx in (hook_l_in_cell, hook_r_in_cell):
            x, y = cx0 + hx, cy0 + HOOK_Y_IN_CELL
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(0, 255, 255, 255), outline=(0, 0, 0, 255))
        txt(d, (cx0 + 4, cy0 + CELL_H - 8), "第 %d 排  格 %d×%d  挂点 (%d,%d)(%d,%d)" % (n, CELL_W, CELL_H, hook_l_in_cell, HOOK_Y_IN_CELL, hook_r_in_cell, HOOK_Y_IN_CELL), f12)
        # 灯身中线和花冠底的辅助线（灯柱上）
        for lamp_box in (w, e):
            lx = lamp_box[0] + hook_x_art - CROP[0]
            ly = lamp_box[1] + hook_y_art - CROP[1]
            d.line([(lx - 8, ly), (lx + 8, ly)], fill=(255, 255, 0, 255), width=1)
    ref = Image.alpha_composite(ref, ov).convert("RGB")
    ref.save(os.path.join(OUT, "红绸-色块参考.png"))
    ref.resize((ref.width * 3, ref.height * 3), Image.NEAREST).save(os.path.join(OUT, "红绸-色块参考-放大3倍.png"))

    # ---- 2. 片大小参考（占位形状：硬边，一格一个） ----
    FRAMES = 4
    PETAL_C = [(255, 105, 150), (255, 205, 70), (250, 250, 250), (210, 30, 45)]
    PAPER_C = [(255, 80, 80), (255, 205, 70), (80, 190, 255), (120, 220, 120), (255, 255, 255), (230, 120, 255)]
    RIB_C = [(235, 40, 60), (255, 205, 70), (80, 190, 255)]

    def petal(c, k):
        w = (12, 9, 5, 9)[k]
        im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        g = ImageDraw.Draw(im)
        x0 = (12 - w) // 2
        g.ellipse([x0, 0, x0 + w - 1, 11], fill=c + (255,), outline=tuple(int(v * 0.55) for v in c) + (255,))
        return im

    def paper(c, k):
        w = (8, 6, 3, 6)[k]
        im = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        g = ImageDraw.Draw(im)
        x0 = (8 - w) // 2
        g.rectangle([x0, 0, x0 + w - 1, 7], fill=c + (255,), outline=tuple(int(v * 0.55) for v in c) + (255,))
        return im

    def ribbon(c, k):
        im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
        g = ImageDraw.Draw(im)
        dk = tuple(int(v * 0.55) for v in c) + (255,)
        for y in range(32):
            x = 8 + int(round(5 * math.sin(2 * math.pi * (y + k * 8) / 32.0)))
            g.rectangle([x - 2, y, x + 2, y], fill=c + (255,))
            g.point((x - 3, y), fill=dk)
            g.point((x + 3, y), fill=dk)
        return im

    rows = [("花瓣 12×12（4 色 × 4 格翻转）", petal, PETAL_C, 12), ("彩纸 8×8（6 色 × 4 格转）", paper, PAPER_C, 8), ("卷彩带 16×32（3 色 × 4 格）", ribbon, RIB_C, 32)]
    PW, PH = 460, 330
    sheet = Image.new("RGB", (PW, PH), (239, 227, 207))                    # 地砖色
    g = ImageDraw.Draw(sheet)
    g.rectangle([300, 0, PW - 1, PH - 1], fill=(179, 32, 42))                # 右边一块红毯色：看红的片在红毯上认不认得出
    x = 10
    y = 10
    for title, fn, cols, size in rows:
        g.text((x, y), title, font=font(12), fill=(40, 20, 10))
        y += 16
        for c in cols:
            for k in range(FRAMES):
                im = fn(c, k)
                sheet.paste(im, (x + k * (size + 3), y), im)
            y += size + 4
            if fn is paper:
                pass
        y += 8
    person = Image.open(os.path.join(HERE, "..", "scale_person_84.png")).convert("RGBA")
    sheet.paste(person, (230, PH - 84 - 20), person)
    g.text((205, PH - 14), "人 84 高（尺子）", font=font(12), fill=(40, 20, 10))
    # 红毯上再摆一份同色，看对比
    for k, c in enumerate(PETAL_C + RIB_C[:1]):
        im = petal(c, 0)
        sheet.paste(im, (310 + k * 16, 20), im)
    for k, c in enumerate(PAPER_C):
        im = paper(c, 0)
        sheet.paste(im, (310 + k * 12, 50), im)
    for k, c in enumerate(RIB_C):
        im = ribbon(c, 0)
        sheet.paste(im, (310 + k * 22, 80), im)
    g.text((310, 6), "红毯上同样的片", font=font(12), fill=(255, 255, 255))
    sheet.save(os.path.join(OUT, "片大小-参考.png"))
    sheet.resize((PW * 4, PH * 4), Image.NEAREST).save(os.path.join(OUT, "片大小-参考-放大4倍.png"))

    # ---- 手机屏模拟：540×960（镜头缩放 0.9375，画布 1 像素 = 屏幕 0.9375 像素），撒一把片 ----
    phone = Image.open(PHONE_PNG).convert("RGBA")
    s = 0.9375
    rng = random.Random(7)
    pieces = [(petal, c) for c in PETAL_C for _ in range(5)] + [(paper, c) for c in PAPER_C for _ in range(3)] + [(ribbon, c) for c in RIB_C for _ in range(2)]
    rng.shuffle(pieces)
    for fn, c in pieces:
        im = fn(c, rng.randrange(FRAMES))
        im = im.resize((max(1, int(round(im.width * s))), max(1, int(round(im.height * s)))), Image.NEAREST)
        phone.alpha_composite(im, (rng.randrange(10, 540 - 30), rng.randrange(120, 800)))
    phone.convert("RGB").save(os.path.join(OUT, "片大小-手机屏模拟.png"))

    # ---- 3. 零件单 ----
    data = {
        "lamp_measured": lamp, "hook": {"lamp_art_x": hook_x_art, "crown_bottom_art_y": hook_y_art, "span": span},
        "parts": [
            {"code": "B55S-P06", "name": "路引红绸", "cell": [CELL_W, CELL_H], "cells": 3, "sheet": [CELL_W * 3, CELL_H], "layout": "3 格横排，从左到右第 1、2、3 格",
             "hooks_in_cell": [[hook_l_in_cell, HOOK_Y_IN_CELL], [hook_r_in_cell, HOOK_Y_IN_CELL]], "hook_span": span,
             "pairs": [{"row": n, "cell_x": w[0] + hook_x_art - hook_l_in_cell, "cell_y": w[1] + hook_y_art - HOOK_Y_IN_CELL,
                        "hook_west": [w[0] + hook_x_art, w[1] + hook_y_art], "hook_east": [e[0] + hook_x_art, e[1] + hook_y_art]} for n, w, e in pairs]},
            {"code": "B55S-FX01", "name": "花瓣", "cell": [12, 12], "colors": 4, "frames": 4, "sheet": [12 * 4, 12 * 4], "layout": "行 = 颜色（4 行），列 = 帧（4 列翻转）", "center_in_cell": [6, 6]},
            {"code": "B55S-FX02", "name": "彩纸", "cell": [8, 8], "colors": 6, "frames": 4, "sheet": [8 * 4, 8 * 6], "layout": "行 = 颜色（6 行），列 = 帧（4 列转）", "center_in_cell": [4, 4]},
            {"code": "B55S-FX03", "name": "卷彩带", "cell": [16, 32], "colors": 3, "frames": 4, "sheet": [16 * 4, 32 * 3], "layout": "行 = 颜色（3 行），列 = 帧（4 列）", "center_in_cell": [8, 16]},
        ]}
    sug = {"B55S-FX01": [12, 12], "B55S-FX02": [10, 10], "B55S-FX03": [16, 32]}   # 手机屏模拟看过的建议（彩纸 8 太小）
    for p in data["parts"]:
        if p["code"] in sug:
            p["suggested_cell"] = sug[p["code"]]
    json.dump(data, open(os.path.join(OUT, "宴会厅彩带-零件单.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=list)
    L = ["# 宴会厅 · 彩带与飘落 · 零件单（给 GPT 照着画）", "",
         "> 03，2026-10-02，01 E 派（`docs/宴会厅-彩带与飘落-说明.md`）。灯柱的数是从游戏里真在用的零件图 `art_lantern.png` 量的，不是抄的；参考图在同一个文件夹。",
         "> 一律硬边（不透明就是不透明、透明就是透明，没有半透明）、不带字；每格四周不留空，片画满格子。", "",
         "## B55S-P06 路引红绸（一直挂在红毯上方，轻轻晃）", "",
         "- **格**：200×56，**3 格横排**（整张 600×56），从左到右第 1、2、3 格，一格约 0.5 秒来回晃。",
         "- **两个挂点**：左 (%d, %d)、右 (%d, %d)（格内坐标，相距 %d）。红绸从两个挂点挂下来、中间往下垂、中间挂一个红绣球，最低处不超过格底（y 56）。" % (hook_l_in_cell, HOOK_Y_IN_CELL, hook_r_in_cell, HOOK_Y_IN_CELL, span),
         "- **挂点怎么量的**：灯柱零件图 48×112，花冠（花和叶）最下一行是 y %d，往下是灯身（玻璃罩）；灯身 x %d～%d，**中线 x %d**；挂点 = 灯身中线、花冠最下一行。" % (hook_y_art, lamp["body_x"][0], lamp["body_x"][1], hook_x_art),
         "  跟说明里的数比：花冠底 30 → 量到 **31**；脚点 25 → 灯身中线 **24**（脚点 25 是占地的中点，灯身比占地窄 1 像素）。两灯距离 177 一样。格内挂点 (11, 6)、(188, 6) 仍然成立。",
         "- 备选挂法（01 决定，我没改）：挂在花冠最宽那一行的里侧边缘，西灯 x %d（整厅 %d）、东灯 x %d（整厅 %d），相距 %d，红绸更短、不会压到灯身玻璃罩。" % (lamp["crown_x_at_widest"][1], pairs[0][1][0] + lamp["crown_x_at_widest"][1], lamp["crown_x_at_widest"][0], pairs[0][2][0] + lamp["crown_x_at_widest"][0], (pairs[0][2][0] + lamp["crown_x_at_widest"][0]) - (pairs[0][1][0] + lamp["crown_x_at_widest"][1])),
         "- 灯柱在游戏里的位置跟底图逐像素对过：第 1、2 排四盏灯，真图里最贴的位置全是 (0,0)（命中率 1.0）。", "",
         "### 每一道红绸在整厅里的位置（排法 C，10 对灯柱；格的左上角 = 左挂点 − (%d, %d)）" % (hook_l_in_cell, HOOK_Y_IN_CELL), "",
         "| 排 | 格左上角 x | 格左上角 y | 左挂点 (x, y) | 右挂点 (x, y) |", "| --- | --- | --- | --- | --- |"]
    for pr in data["parts"][0]["pairs"]:
        L.append("| %d | %d | %d | (%d, %d) | (%d, %d) |" % (pr["row"], pr["cell_x"], pr["cell_y"], pr["hook_west"][0], pr["hook_west"][1], pr["hook_east"][0], pr["hook_east"][1]))
    L += ["", "## 飘的片（代码让它们落、转）", "",
          "整张图的排法：**行 = 颜色，列 = 帧**，格子一个挨一个、不留缝。中心 = 格子正中，代码绕它转、落。", "",
          "| 编号 | 名字 | 一格 w×h（说明里的数） | 我建议 | 颜色 × 帧 | 整张 w×h | 中心 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for p in data["parts"][1:]:
        sg = p.get("suggested_cell")
        L.append("| %s | %s | %d×%d | %s | %d 色 × %d 帧（%s） | %d×%d | (%d, %d) |" % (p["code"], p["name"], p["cell"][0], p["cell"][1], ("**%d×%d**（整张 %d×%d）" % (sg[0], sg[1], sg[0] * p["frames"], sg[1] * p["colors"])) if sg and sg != p["cell"] else "同", p["colors"], p["frames"], {"B55S-FX01": "翻转", "B55S-FX02": "转", "B55S-FX03": "卷"}[p["code"]], p["sheet"][0], p["sheet"][1], p["center_in_cell"][0], p["center_in_cell"][1]))
    L += ["", "颜色（建议，GPT 可以换，规则是别跟地砖、红毯同色）：花瓣粉、金、白（带深色描边）、深红带浅边；彩纸红、金、蓝、绿、白、紫；卷彩带红、金、蓝。", "",
          "## 片大小：手机屏上认不认得出（`片大小-手机屏模拟.png`，540×960，片按镜头缩放 0.9375 缩）", "",
          "- **花瓣 12×12**：够，屏上约 11 像素，撒在地砖上、红毯上都看得见；红色花瓣压在红毯、红桌布上会隐，要么不用纯红、要么描一圈浅边。",
          "- **彩纸 8×8**：**偏小**，屏上约 7 像素，只有在红毯上、颜色亮的才认得出；白色、浅黄的撒在米色地砖上几乎看不见。**建议 10×10**（屏上约 9 像素），整张 40×60。",
          "- **卷彩带 16×32**：够，屏上约 15×30，窄条带弯，一眼就知道是彩带。",
          "- 共同：所有片都要有 1 像素深色描边（同色相、暗一档），不然浅色片掉进米色地砖里没了。", ""]
    open(os.path.join(OUT, "宴会厅彩带-零件单.md"), "w", encoding="utf-8").write("\n".join(L))
    return data


if __name__ == "__main__":
    d = main()
    print(json.dumps(d["lamp_measured"], ensure_ascii=False, default=list))
    print("挂点：灯身中线 x", d["hook"]["lamp_art_x"], "、花冠底 y", d["hook"]["crown_bottom_art_y"], "、两点相距", d["hook"]["span"])
