#!/usr/bin/env python3
"""化妆间挡错检查（01 H 10/5；阿鱼「切图的方式有问题，复杂的场景人可能被图切了」）：人在化妆间每个能站的格子站一下，
看每件零件跟人排前后排得对不对。游戏只按一条着地线排：零件着地线比人的脚靠南，零件画在人上面；靠北，人画在零件上面。

挡错（零件画在人上面，可它在人脚南边一点东西都没有——整件都在人身后，却把人盖了）：
    比如试衣间整张一条线，人站进凹口里，后屏把人盖了；或者 footprint 没画到 foot_y，人站进家具的影子里。
盖错（人画在零件上面，可零件在人脚南边还有一截——那截本该挡住人的脚）：
    比如前帘画进了后屏那张、图比着地线还往南伸。
人按游戏里站着的大小算（宽 32、高 84，脚点在格子中心）；零件只看不透明像素；盖住不到 20 个像素的不算。

用法：
  1. 先倒能走的格子：Godot --headless --path godot --script res://tools/dump_walk_grid.gd -- --dir=<目录>（出 <目录>/makeup.json）
  2. python3 godot/tools/check_makeup_occlusion.py <目录>/makeup.json --md 报告.md --png 标图.png [--shots 截图目录]
     --shots 挑挡错最多的几件，每件找一处让游戏里的人站过去截一张（手机 540×960）
退出码：0 没有挡错、盖错；1 有（报告里列每件、几格、在哪）
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
ROOM = os.path.join(GODOT, "assets", "pixel_art", "makeup_room", "room.json")   # --name= 换（照效果图代码画那版出到 makeup_room）
PW, PH = 32, 84          # 人多宽、多高（游戏里站着的一帧）
MIN_PX = 20              # 盖住不到这么多像素的不算


def res_path(r):
    return os.path.join(GODOT, r.replace("res://", ""))


def main():
    av = sys.argv[1:]
    args = [a for k, a in enumerate(av) if not a.startswith("--") and (k == 0 or av[k - 1] not in ("--md", "--png", "--shots"))]
    if not args:
        raise SystemExit(__doc__)
    opt = lambda k: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else None
    global ROOM
    for a in sys.argv:
        if a.startswith("--name="):
            ROOM = os.path.join(GODOT, "assets", "pixel_art", a.split("=", 1)[1], "room.json")
    grid = json.load(open(args[0], encoding="utf-8"))
    cell = float(grid["cell"])
    rows = grid["rows"]
    room = json.load(open(ROOM, encoding="utf-8"))
    lay = json.load(open(os.path.join(GODOT, "assets", "layered", "scene_luoman_makeup", "layout.json"), encoding="utf-8"))
    fps = {it["id"]: it["rect"] for it in lay["items"] if "rect" in it}
    props = []
    for p in room["props"]:
        im = Image.open(res_path(p["png"])).convert("RGBA")
        a = im.getchannel("A")
        props.append({"id": p["id"], "x": int(p["x"]), "y": int(p["y"]), "w": im.width, "h": im.height, "foot": float(p["foot"]),
                      "a": a.load(), "img": im, "fp": fps.get(p["id"][3:])})
    wrong_over, wrong_under = {}, {}   # id -> [(x, y, 盖了几像素)]
    n_cells = 0
    for j, line in enumerate(rows):
        for i, ch in enumerate(line):
            if ch != "1":
                continue
            n_cells += 1
            fx, fy = (i + 0.5) * cell, (j + 0.5) * cell
            px0, px1, py0, py1 = int(fx - PW / 2), int(fx + PW / 2), int(fy - PH), int(fy)
            for p in props:
                if p["foot"] > 3000:
                    continue   # fg：永远在人前面，本来就盖
                ix0, ix1 = max(px0, p["x"]), min(px1, p["x"] + p["w"])
                iy0, iy1 = max(py0, p["y"]), min(py1, p["y"] + p["h"])
                if ix0 >= ix1 or iy0 >= iy1:
                    continue
                a = p["a"]
                over = sum(1 for yy in range(iy0, iy1) for xx in range(ix0, ix1) if a[xx - p["x"], yy - p["y"]])
                if over < MIN_PX:
                    continue
                # 这件在人脚南边（人脚到图下沿）有没有东西
                south = 0
                for yy in range(int(fy) + 1, p["y"] + p["h"]):
                    for xx in range(ix0, ix1):
                        if a[xx - p["x"], yy - p["y"]]:
                            south += 1
                # 人站在这件底座的正后方（横着落在它占地的宽里）才算：站在旁边、被伸出来的花冠灯头盖住是对的（那截本来就在人前面）
                behind = p["fp"] is not None and p["fp"][0] - 4 <= fx <= p["fp"][2] + 4
                if p["foot"] > fy + 3 and south == 0 and behind:   # 脚离着地线不到 3 像素的是边界，不算
                    wrong_over.setdefault(p["id"], []).append((fx, fy, over))
                elif p["foot"] < fy - 3 and south >= MIN_PX:
                    wrong_under.setdefault(p["id"], []).append((fx, fy, south))
    bad = len(wrong_over) + len(wrong_under)
    lines = ["# 化妆间挡错检查", "",
             "- 能站的格子 %d 个（每格 %d 像素），零件 %d 件" % (n_cells, int(cell), len(props)),
             "- **挡错**（零件画在人上面，可它整件都在人身后）：%d 件" % len(wrong_over),
             "- **盖错**（人画在零件上面，可零件在人脚南边还有一截）：%d 件" % len(wrong_under), ""]
    for title, dd in (("挡错", wrong_over), ("盖错", wrong_under)):
        if not dd:
            continue
        lines += ["## %s" % title, "", "| 零件 | 几格 | 举例（脚点） |", "| --- | --- | --- |"]
        for pid, lst in sorted(dd.items(), key=lambda kv: -len(kv[1])):
            ex = "、".join("(%d,%d)" % (x, y) for (x, y, _) in lst[:4])
            lines.append("| %s | %d | %s |" % (pid, len(lst), ex))
        lines.append("")
    if not bad:
        lines.append("没有挡错、盖错。")
    text = "\n".join(lines) + "\n"
    print(text)
    if opt("--md"):
        open(opt("--md"), "w", encoding="utf-8").write(text)
    if opt("--png"):
        out = Image.open(res_path(room["background"]["png"])).convert("RGBA")
        for p in sorted(props, key=lambda p: p["foot"]):
            out.alpha_composite(p["img"], (p["x"], p["y"]))
        dr = ImageDraw.Draw(out)
        for dd, col in ((wrong_over, (230, 30, 30, 255)), (wrong_under, (30, 120, 230, 255))):
            for pid, lst in dd.items():
                p = next(q for q in props if q["id"] == pid)
                dr.rectangle([p["x"], p["y"], p["x"] + p["w"] - 1, p["y"] + p["h"] - 1], outline=col)
                for (x, y, _) in lst:
                    dr.ellipse([x - 2, y - 2, x + 2, y + 2], fill=col)
        out.save(opt("--png"))
    if opt("--shots"):
        d = opt("--shots")
        os.makedirs(d, exist_ok=True)
        g = os.environ.get("SUQI_GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
        worst = sorted(list(wrong_over.items()) + list(wrong_under.items()), key=lambda kv: -len(kv[1]))[:6]
        for pid, lst in worst:
            x, y, _ = lst[len(lst) // 2]
            out = os.path.join(d, "%s.png" % pid)
            subprocess.run([g, "--path", GODOT, "--resolution", "540x960", "--script", "res://tools/shot_view.gd", "--",
                            "--canvas=makeup", "--at=%d,%d" % (x, y), "--face=up", "--out=" + out],
                           capture_output=True, timeout=200)
            print("截了 %s（人站在 %d,%d）" % (out, x, y))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
