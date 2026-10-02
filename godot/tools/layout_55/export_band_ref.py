#!/usr/bin/env python3
"""乐队台乐手出位置参考（01 E 10/2 派，03 做）：给 GPT 画 4 位乐手用。
乐队台在 GPT 北边 v2 背景里：钢琴、琴凳、一把椅子靠着大提琴、两个谱架都画在背景上，台上没人。
底图 = shot.sh 截的乐队台那一块（1:1、不放人、没界面）；游戏会在脚下画一个黄色「找自己」小三角，已经用底图 base.png 同一处补掉（不然 GPT 会当成台上的东西）。
背景里琴凳、椅子、大提琴、谱架的框是我在放大 5 倍的坐标格子图上读出来的（±2 像素），不是摆位表里的数（摆位表里只有乐队地台那一整个框）。
用法：python3 godot/tools/layout_55/export_band_ref.py 底图.png 输出目录
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
SCENE_DIR = os.path.join(GODOT, "assets", "layered", "scene_roman_banquet_55")
FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
SRC, OUT = sys.argv[1], sys.argv[2]
CROP = (990, 140, 400, 240)   # 底图在整厅里的位置 x, y, w, h

# 背景里已经画好的东西（整厅坐标 x, y, w, h，读图 ±2）
BG = {
    "钢琴": (1012, 165, 128, 123),
    "钢琴键盘一头": (1017, 225, 36, 22),
    "琴凳": (1108, 257, 40, 38),
    "椅子": (1162, 233, 25, 55),
    "大提琴（背景里画好的）": (1194, 212, 37, 80),
    "谱架甲": (1241, 221, 29, 68),
    "谱架乙": (1288, 226, 30, 63),
}
STAND_POLE = {"谱架甲": 1257, "谱架乙": 1302}   # 谱架中杆 x
STAGE = {"台面 y 范围": (222, 315), "台前沿 y": 325, "台 x 范围": (1014, 1348)}   # make_board55 乐队地台

# 乐手：编号、名字、格子 w×h、脚点（整厅）、画出来的人（整厅框 x,y,w,h）、朝向、说明
PERF = [
    {"code": "LM-BAND-01", "name": "钢琴手", "frame": (64, 84), "foot": (1128, 293), "figure": (1110, 231, 36, 62), "face": "朝上（北）或朝左（西）3/4：背景里琴键在钢琴最左头（x 1017～1053），琴凳在钢琴肚子底下，离琴键 55～75 像素，朝上坐着手摆在身前就行",
     "pose": "坐在琴凳上弹琴（坐着的人 62 高：头顶到脚）", "seat_rows": 62},
    {"code": "LM-BAND-02", "name": "大提琴手（含他抱的大提琴）", "frame": (80, 96), "foot": (1200, 292), "figure": (1162, 212, 70, 80), "face": "朝下（南）或朝右 3/4：坐在椅子（x 1162～1187）上，琴在他右手边（x 1194～1231）",
     "pose": "坐在椅子上拉大提琴；他抱的大提琴要把背景里那把（1194～1231 × 212～292）整个盖住，椅子可以被他盖住一部分", "seat_rows": 62},
    {"code": "LM-BAND-03", "name": "小提琴手甲（含谱架）", "frame": (64, 96), "foot": (1257, 290), "figure": (1239, 195, 36, 84), "face": "朝下（南）",
     "pose": "站在谱架甲后面拉小提琴；人 84 高、脚在谱架脚北边 12 像素；谱架（桌面 y 221～242、中杆、三只脚到 290）要画进他这张图里，压在他身前", "seat_rows": 0},
    {"code": "LM-BAND-04", "name": "小提琴手乙（含谱架）", "frame": (64, 96), "foot": (1302, 290), "figure": (1284, 195, 36, 84), "face": "朝下（南）",
     "pose": "站在谱架乙后面拉小提琴；同甲", "seat_rows": 0},
]
COLORS = [(255, 80, 200), (60, 180, 255), (120, 255, 120), (255, 200, 60)]


def font(s):
    return ImageFont.truetype(FONT, s)


def rel(x, y):
    return x - CROP[0], y - CROP[1]


def fix_triangle(im):
    """游戏自己画在脚下的「找自己」黄三角（人藏了它没藏）：用底图 base.png 同一处补掉。它在截图 (36..53, 168..182)"""
    base = Image.open(os.path.join(SCENE_DIR, "base.png")).convert("RGB")
    box = (36, 168, 54, 183)
    patch = base.crop((box[0] + CROP[0], box[1] + CROP[1], box[2] + CROP[0], box[3] + CROP[1]))
    im.paste(patch, (box[0], box[1]))
    return im


def foot_frame_origin(p):
    """格子左上角（整厅）：脚点 = 格子底边正中"""
    w, h = p["frame"]
    return p["foot"][0] - w // 2, p["foot"][1] - (h - 1)


def main():
    os.makedirs(OUT, exist_ok=True)
    im = Image.open(SRC).convert("RGB")
    assert im.size == (CROP[2], CROP[3]), im.size
    im = fix_triangle(im)
    im.save(os.path.join(OUT, "乐队台-底图.png"))
    ref = im.convert("RGBA")
    ov = Image.new("RGBA", ref.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    f11, f13 = font(11), font(13)

    def txt(xy, s, col=(255, 255, 255), fnt=f11, anchor="lm"):
        d.text(xy, s, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=2, stroke_fill=(0, 0, 0, 255))

    for i, p in enumerate(PERF):
        col = COLORS[i]
        fw, fh = p["frame"]
        ox, oy = foot_frame_origin(p)
        rx, ry = rel(ox, oy)
        d.rectangle([rx, ry, rx + fw - 1, ry + fh - 1], fill=col + (40,), outline=col + (255,), width=1)   # 格子
        x, y, w, h = p["figure"]
        fx, fy = rel(x, y)
        d.rectangle([fx, fy, fx + w - 1, fy + h - 1], fill=col + (90,), outline=(255, 255, 255, 255), width=1)   # 画出来的人（含琴、谱架）占的框
    for name, (x, y, w, h) in BG.items():   # 背景里已经有的东西：黄细线框（画在彩色上面）
        rx, ry = rel(x, y)
        d.rectangle([rx, ry, rx + w - 1, ry + h - 1], outline=(255, 255, 0, 230), width=1)
    for i, p in enumerate(PERF):
        px, py = rel(*p["foot"])
        d.line([(px - 6, py), (px + 6, py)], fill=(0, 255, 255, 255), width=2)
        d.line([(px, py - 6), (px, py + 6)], fill=(0, 255, 255, 255), width=2)
        txt((px, py + 11 + (13 if i % 2 else 0)), "%02d %s" % (i + 1, p["name"].split("（")[0]), COLORS[i], f11, "mm")
    for k, line in enumerate(["彩色细框 = 格子；彩色实块 = 画出来的人；青十字 = 脚点", "黄线框 = 背景里已有的东西", "1:1，整厅 (990,140) 起，400×240"]):
        txt((6, 8 + k * 14), line, (255, 255, 255))
    ref = Image.alpha_composite(ref, ov).convert("RGB")
    ref.save(os.path.join(OUT, "乐队台-色块参考.png"))
    ref.resize((ref.width * 3, ref.height * 3), Image.NEAREST).save(os.path.join(OUT, "乐队台-色块参考-放大3倍.png"))

    data = {"canvas_crop": list(CROP), "note": "整厅坐标（x、y）；格子左上角 = 脚点 − (w/2, h−1)；脚点 = 格子底边正中",
            "background_objects": {k: list(v) for k, v in BG.items()}, "stand_pole_x": STAND_POLE, "stage": {k: list(v) if isinstance(v, tuple) else v for k, v in STAGE.items()}, "performers": []}
    for p in PERF:
        ox, oy = foot_frame_origin(p)
        data["performers"].append({"code": p["code"], "name": p["name"], "frame": list(p["frame"]), "frame_origin": [ox, oy], "foot": list(p["foot"]),
                                   "foot_in_frame": [p["frame"][0] // 2, p["frame"][1] - 1], "figure_box": list(p["figure"]), "facing": p["face"], "pose": p["pose"]})
    json.dump(data, open(os.path.join(OUT, "乐手零件单.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    L = ["# 乐队台乐手 · 零件单（给 GPT 画 4 位乐手）", "",
         "> 03，2026-10-02，01 E 派。乐队台在你北边 v2 背景里（舞台东边）：钢琴、琴凳、一把椅子靠着大提琴、两个谱架都画在背景上，台上现在没人。要 4 位乐手。",
         "> 位置全是**整厅坐标**；图是 `乐队台-底图.png`（整厅 (990,140) 起 400×240，1:1，不放人、没界面）和 `乐队台-色块参考-放大3倍.png`。游戏在脚下画的「找自己」黄三角已经补掉了。",
         "> 背景里琴凳、椅子、大提琴、谱架的框是我在放大 5 倍的坐标格子图上读的，**±2 像素**，不是摆位表里的数（摆位表只有乐队地台那一整个框）。", "",
         "**脚点 = 格子底边正中**。格子左上角（整厅）= 脚点 − (宽÷2, 高−1)。一律硬边（0/255）、深色描边、不带字、人大小跟 84 高的宾客一个样。", "",
         "## 背景里已经有的（量到的框，整厅坐标 x, y, 宽×高）", "", "| 东西 | 框 | 说明 |", "| --- | --- | --- |"]
    notes = {"钢琴": "整架三角钢琴（琴盖到琴腿）", "钢琴键盘一头": "键盘在钢琴最左头，朝左下", "琴凳": "红软垫黑凳腿；凳面上沿 y 257，腿底 y 295（凳高 38）",
             "椅子": "金边红椅面靠背椅；椅面 y 约 260～269，腿底 y 288", "大提琴（背景里画好的）": "靠在椅子右边（东），琴头 y 212，琴脚 y 292；**大提琴手抱的琴要盖住它**",
             "谱架甲": "西边那个，中杆 x 1257；桌面 y 221～242，三只脚到 y 288", "谱架乙": "东边那个，中杆 x 1302；桌面 y 226～247，三只脚到 y 289"}
    for k, v in BG.items():
        L.append("| %s | %d, %d, %d×%d | %s |" % (k, v[0], v[1], v[2], v[3], notes[k]))
    L += ["", "乐队台台面 y %d～%d（前沿 y %d），x %d～%d（摆位表 `乐队地台`）。" % (STAGE["台面 y 范围"][0], STAGE["台面 y 范围"][1], STAGE["台前沿 y"], STAGE["台 x 范围"][0], STAGE["台 x 范围"][1]), "",
          "## 4 位乐手", "", "| 编号 | 名字 | 一格 w×h | 脚点（整厅） | 格子左上角（整厅） | 脚点在格内 | 画出来的人占的框 x, y, w×h | 朝向 |", "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    for p in PERF:
        ox, oy = foot_frame_origin(p)
        x, y, w, h = p["figure"]
        L.append("| %s | %s | %d×%d | (%d, %d) | (%d, %d) | (%d, %d) | %d, %d, %d×%d | %s |" % (p["code"], p["name"], p["frame"][0], p["frame"][1], p["foot"][0], p["foot"][1], ox, oy, p["frame"][0] // 2, p["frame"][1] - 1, x, y, w, h, p["face"]))
    L += ["", "怎么摆、怎么画：", ""]
    for p in PERF:
        L.append("- **%s %s**：%s。" % (p["code"], p["name"], p["pose"]))
    L += ["", "- 坐着的人 **62 高**（头顶到脚），画在格子最下面 62 行，格子上面留空；站着的人 **84 高**（谱架那两位格子 96 高，人占上面 84 行，下面 12 行是谱架脚）。",
          "- 一张图一位乐手，每位只要一个朝向、一格（先看位置对不对，动作等阿鱼点头了再出）。", "",
          "## 几处要你知道的（位置对不对的关键）", "",
          "1. **谱架、大提琴、琴凳、椅子是画在背景上的**，乐手是画在背景上面的零件，会盖住它们。所以「站在谱架后面」只能把谱架一起画进乐手这张图里、压在他身前（谱架甲、乙格子里已经按谱架的框留了位置）；「大提琴手抱的琴盖住背景那把」同理，他的琴框要把 1194～1231 × 212～292 整个盖住。",
          "2. **钢琴手离键盘有点远**：键盘在钢琴最左头（x 1017～1053），琴凳在钢琴肚子底下（x 1108～1148），琴凳到键盘约 55～75 像素。我按「坐在琴凳上」摆，朝上坐；要朝左（西）3/4 手伸向键盘也行，脚点和格子不变。",
          "3. **钢琴手压到钢琴多少**：他画出来的人（x 1110～1146、y 231～293）跟钢琴整体框（x 1012～1140、y 165～288）重叠 30×57（只有 x 1110～1140 那截），盖住的是钢琴右下的一条腿和肚子下沿，键盘一头（x 1017～1053）一点不压。要完全不压，只能挪琴凳，我没动背景。",
          "4. 台面 y 222～315，4 位的脚点 y 都在 278～293（台面中后部），在台前沿 325 以北 30 像素以上，不会踩到台边。", ""]
    open(os.path.join(OUT, "乐手零件单.md"), "w", encoding="utf-8").write("\n".join(L))
    print("乐手 %d 位，背景物件 %d 个" % (len(PERF), len(BG)))


if __name__ == "__main__":
    main()
