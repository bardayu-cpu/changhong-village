#!/usr/bin/env python3
"""比例量尺（人 = 1）：拿一张图和几个框，对着「人 = 1」表出偏差表。超过表里的 1.5 倍、或小于一半，标红、退出码 1。

标准以 godot/ASSETS.md 第 15 节「比例尺（人 = 1）」为准（原表 godot/回执/比例尺-人等于1.md）；表在下面 STANDARD，改表两处一起改。
换算：左右和高度 1 米 = 48 像素，地面前后 1 米 = 32 像素；人 84 像素（1.75 米）。表里的数按「人 84 像素」写，
量的画布人不是 84 就在 JSON 里写 person_px，表会按比例缩放。

退出码（measure）：0 = 没有红项，1 = 有红项（该打回），2 = 没量成（框文件、图的路径、表的 key 有问题）。

子命令：
  grid     把图的一块放大、盖上带坐标的格子，读框的坐标用
             python3 godot/tools/scale_check.py grid 图.png --region 500,480,1000,760 --zoom 3 -o /tmp/g.png
  measure  读框文件，出偏差表（--md 存 Markdown、--json 存 JSON、--annot 存标了框的图、--compact 出窄表）
             python3 godot/tools/scale_check.py measure 框.json --annot /tmp/a.png --md /tmp/t.md
  bbox     一张带透明的 PNG（积木、人物帧）不透明部分的外框，量单个积木时用
             python3 godot/tools/scale_check.py bbox 积木.png
  std      把标准表打出来对一眼

框文件（JSON）：
  {"scene": "迎宾院", "image": "图.png", "person_px": 84, "scale": 1.0,
   "objects": [
     {"name": "楼门 高", "std": "double_door_h", "box": [x0, y0, x1, y1], "dim": "h"},
     {"name": "桌上的灯 高", "meters": 0.35, "axis": "h", "box": [...], "dim": "h"},
     {"name": "柳树 高（顶上被图边截断）", "std": "tree_h", "box": [...], "dim": "h", "truncated": true}],
   "rulers": [[x, 脚的y], ...]}
  box 是图上的像素框；dim 量框的高（h）还是宽（w）；scale = 图上 1 像素等于画布几像素
  （画布原图是 1；540×960 的手机截图要换算：画布像素 = 屏幕像素 ÷ 镜头缩放，540×960 时缩放 0.9375，scale 写 1.0667；
    截图是 1080×1920 的先想成 540 宽的，scale 写 0.5333）。
  单个积木（带透明的 PNG）不用手画框：{"name": "落地灯", "std": "lamp_floor_h", "png": "blk_lantern_floor.png", "dim": "h"}，
    框自动取不透明部分的外框（路径相对框文件；这样的项不在标图里画）。
  rulers：标图时把游戏里真的人（scale_person_84.png，84 像素高）按同样比例贴在这几个脚点上当尺子，不写就贴左上角。
  draw：false 表示这项不在图上（比如在游戏里量的人高），标图时不画框。
  group／src／call：一屏东西多的时候用。group 分节（表按节列），src 写「来源」（GPT 图／代码画的占位……），
    call 写「结论」（对／要重画／占位待换……），有 src 或 call 的项，表里多出对应的列。
  std 取表里的行；表里没有的东西写 meters（真实大小，米；不确定的写范围 [下限, 上限]）和 axis（h、w 用 48，d 前后用 32）自己算。
  truncated：东西被图边截掉了，量到的是下限，结果写「≥」，只判「大了」，不判「小了」。
"""
import argparse
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

PERSON_PX = 84.0
PERSON_PNG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scale_person_84.png")  # 游戏里真的 NPC 那一帧，84 像素高
PX_PER_M = 48.0        # 左右、高度
PX_PER_M_DEPTH = 32.0  # 地面前后
RED_BIG = 1.5          # 超过表里的 1.5 倍：红
RED_SMALL = 0.5        # 小于表里的一半：红
WARN_BIG = 1.25        # 超过 1.25 倍、或小于 2/3：黄（看一眼）
WARN_SMALL = 2.0 / 3.0

# key: (名字, 下限像素, 上限像素)。人 84 像素时的数
STANDARD = {
    "person_h": ("人（Q 版，头顶到脚底）高", 84, 84),
    "single_door_h": ("单扇门 高", 100, 100),
    "single_door_w": ("单扇门 宽", 43, 43),
    "double_door_h": ("双开门／院门门洞 高", 115, 145),
    "double_door_w": ("双开门／院门门洞 宽", 86, 115),
    "gate_arch_w": ("山庄大门门楼 门洞宽（迎宾院南边）", 232, 232),
    "gate_arch_h": ("山庄大门门楼 门柱高", 196, 196),
    "gate_arch_total_w": ("山庄大门门楼 整座宽", 344, 344),
    "round_table_w": ("宴会圆桌 宽（直径）", 86, 86),
    "round_table_d": ("宴会圆桌 桌面前后（深）", 58, 58),
    "round_table_h": ("宴会圆桌 桌高", 36, 36),
    "long_table_w": ("长条桌（签到台）长", 86, 115),
    "long_table_d": ("长条桌 前后（深）", 19, 19),
    "long_table_h": ("长条桌 高", 36, 36),
    "chair_h": ("椅子 高", 46, 46),
    "chair_w": ("椅子 宽", 22, 22),
    "book_w": ("翻开的书、回忆册 宽", 19, 24),
    "flower_one": ("一朵花", 5, 5),
    "pot": ("一盆花、一丛花（高或宽）", 24, 38),
    "lantern_hang_h": ("挂着的灯笼 高", 19, 24),
    "lamp_floor_h": ("落地宫灯（连杆）高", 77, 86),
    "lion_h": ("石狮子 高", 58, 58),
    "tree_h": ("柳树、枇杷树 高", 240, 336),
    "strawberry_h": ("草莓（一棵）高", 10, 10),
    "pavilion_h": ("亭子 高", 190, 240),
    "swing_h": ("秋千 高", 106, 106),
    "slide_h": ("滑梯 高", 72, 72),
    "bench_w": ("长凳 宽", 72, 72),
    "bench_h": ("长凳 高", 38, 38),
    "mahjong_w": ("麻将桌 宽", 43, 43),
    "mahjong_h": ("麻将桌 高", 36, 36),
    "stove_h": ("灶台 高", 43, 43),
    "dress_rack_h": ("礼服架 高", 86, 86),
}

CJK_FONTS = [
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/Library/Fonts/Arial Unicode.ttf",
    "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
]


def die(msg):
    """没量成：退出码 2，跟「有红项 = 1」分开，让外面的脚本能分清"""
    print(msg, file=sys.stderr)
    sys.exit(2)


def load_font(size):
    for p in CJK_FONTS:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size), True
            except Exception:
                continue
    return ImageFont.load_default(), False


def expected_range(obj, person_px):
    """这一项表里该是多少像素：(名字, 下限, 上限)。std 按人高缩放，meters 照真实大小 × 48（前后 × 32）。"""
    k = person_px / PERSON_PX
    if "std" in obj:
        key = obj["std"]
        if key not in STANDARD:
            die("标准表里没有 %r，可选：%s" % (key, "、".join(STANDARD)))
        name, lo, hi = STANDARD[key]
        return name, lo * k, hi * k
    if "meters" in obj:
        per = PX_PER_M_DEPTH if obj.get("axis", "h") == "d" else PX_PER_M
        m = obj["meters"]
        lo_m, hi_m = (float(m[0]), float(m[1])) if isinstance(m, (list, tuple)) else (float(m), float(m))
        if lo_m == hi_m:
            return "真实 %g 米 × %d" % (lo_m, per), lo_m * per * k, lo_m * per * k
        return "真实 %g～%g 米 × %d" % (lo_m, hi_m, per), lo_m * per * k, hi_m * per * k
    die("%r 要写 std 或 meters" % obj.get("name"))


def opaque_bbox(path, alpha_min=16):
    """带透明的 PNG 里不透明部分的外框 (x0, y0, x1, y1)；整张都不透明就是整张图。"""
    im = Image.open(path).convert("RGBA")
    mask = im.split()[-1].point(lambda a: 255 if a > alpha_min else 0)
    box = mask.getbbox()
    if box is None:
        die("%s 是全透明的图" % path)
    return list(box)


def judge(measured, lo, hi, truncated=False):
    """倍数：在表里范围内 = 1；比上限大 = 测得/上限；比下限小 = 测得/下限。返回 (倍数, 判定)。"""
    if measured > hi:
        ratio = measured / hi
    elif measured < lo:
        ratio = measured / lo
    else:
        ratio = 1.0
    if truncated and ratio < 1.0:
        return ratio, "绿"   # 被截断的只有下限，不判小
    if ratio > RED_BIG:
        return ratio, "红·大了"
    if ratio < RED_SMALL:
        return ratio, "红·小了"
    if ratio > WARN_BIG:
        return ratio, "黄·偏大"
    if ratio < WARN_SMALL:
        return ratio, "黄·偏小"
    return ratio, "绿"


def cmd_std(_args):
    print("| key | 东西 | 下限 px | 上限 px | 约几个人 |")
    print("| --- | --- | --- | --- | --- |")
    for k, (name, lo, hi) in STANDARD.items():
        pp = ("%.2f" % (lo / PERSON_PX)) if lo == hi else ("%.2f～%.2f" % (lo / PERSON_PX, hi / PERSON_PX))
        print("| %s | %s | %g | %g | %s |" % (k, name, lo, hi, pp))


def cmd_bbox(args):
    x0, y0, x1, y1 = opaque_bbox(args.image, args.alpha)
    print("%s 不透明部分：x %d～%d、y %d～%d，宽 %d × 高 %d（整张 %s）" % (
        args.image, x0, x1, y0, y1, x1 - x0, y1 - y0, "×".join(str(v) for v in Image.open(args.image).size)))


def cmd_grid(args):
    im = Image.open(args.image).convert("RGB")
    if args.region:
        x0, y0, x1, y1 = [int(v) for v in args.region.split(",")]
    else:
        x0, y0, x1, y1 = 0, 0, im.width, im.height
    z = args.zoom
    crop = im.crop((x0, y0, x1, y1)).resize((int((x1 - x0) * z), int((y1 - y0) * z)), Image.NEAREST)
    d = ImageDraw.Draw(crop, "RGBA")
    step = args.step
    font = ImageFont.load_default()
    gx = int(math.ceil(x0 / step) * step)
    while gx <= x1:
        X = (gx - x0) * z
        major = (gx // step) % 2 == 0
        d.line([(X, 0), (X, crop.height)], fill=(0, 255, 255, 120 if major else 55), width=1)
        d.text((X + 2, 2), str(gx), fill=(255, 255, 0, 255), font=font)
        gx += step
    gy = int(math.ceil(y0 / step) * step)
    while gy <= y1:
        Y = (gy - y0) * z
        major = (gy // step) % 2 == 0
        d.line([(0, Y), (crop.width, Y)], fill=(0, 255, 255, 120 if major else 55), width=1)
        d.text((2, Y + 2), str(gy), fill=(255, 255, 0, 255), font=font)
        gy += step
    crop.save(args.out)
    print("存了 %s（区域 %d,%d,%d,%d，放大 %g 倍，格 %d 像素）" % (args.out, x0, y0, x1, y1, z, step))


def cmd_measure(args):
    spec = json.load(open(args.boxes, encoding="utf-8"))
    person_px = float(args.person_px or spec.get("person_px", PERSON_PX))
    scale = float(spec.get("scale", 1.0))
    rows = []
    for i, o in enumerate(spec["objects"], 1):
        if "box" not in o:
            if "png" not in o:
                die("%r 要写 box 或 png" % o.get("name"))
            o = dict(o, box=opaque_bbox(spec_dir_join(args.boxes, o["png"])), draw=False)
        x0, y0, x1, y1 = o["box"]
        dim = o.get("dim", "h")
        raw = (y1 - y0) if dim == "h" else (x1 - x0)
        measured = raw * scale
        ename, lo, hi = expected_range(o, person_px)
        ratio, verdict = judge(measured, lo, hi, bool(o.get("truncated", False)))
        mid = (lo + hi) / 2.0
        rows.append({
            "n": i, "name": o["name"], "box": o["box"], "dim": dim,
            "measured_px": measured, "measured_people": measured / person_px,
            "expected": ename, "lo": lo, "hi": hi, "expected_people": (lo / person_px, hi / person_px),
            "times_vs_mid": measured / mid if mid > 0 else float("nan"),
            "ratio": ratio, "verdict": verdict, "truncated": bool(o.get("truncated", False)),
            "note": o.get("note", ""), "draw": bool(o.get("draw", True)),
            "group": o.get("group", ""), "src": o.get("src", ""), "call": o.get("call", ""),
        })
    reds = [r for r in rows if r["verdict"].startswith("红")]
    warns = [r for r in rows if r["verdict"].startswith("黄")]
    scene = spec.get("scene", "")
    lines = []
    lines.append("比例量尺 · %s（人 = %g 像素，图上 1 像素 = 画布 %g 像素）" % (scene, person_px, scale))
    lines.append("")
    has_src = any(r["src"] for r in rows)
    has_call = any(r["call"] for r in rows)

    def fmt_row(r):
        ge = "≥" if r["truncated"] else ""
        exp_txt = ("%g" % round(r["lo"], 1)) if abs(r["hi"] - r["lo"]) < 0.5 else ("%g～%g" % (round(r["lo"], 1), round(r["hi"], 1)))
        ep = r["expected_people"]
        exp_p = ("%.2f" % ep[0]) if abs(ep[1] - ep[0]) < 0.005 else ("%.2f～%.2f" % ep)
        if args.compact:
            est = "" if not r["expected"].startswith("真实") else "；估 " + r["expected"][2:].split(" ×")[0].strip()
            cells = ["%d" % r["n"], r["name"], "%s%.0f（%s%.2f 人）" % (ge, r["measured_px"], ge, r["measured_people"]), "%s（%s 人%s）" % (exp_txt, exp_p, est),
                     "%s%.1f×" % (ge, r["ratio"]), r["verdict"]]
        else:
            cells = ["%d" % r["n"], r["name"], "×".join(str(int(v)) for v in r["box"]), "%s%.0f" % (ge, r["measured_px"]), "%s%.2f" % (ge, r["measured_people"]),
                     exp_txt, exp_p, "%s%.1f×" % (ge, r["times_vs_mid"]), "%s%.1f×" % (ge, r["ratio"]), r["verdict"]]
        if has_src:
            cells.append(r["src"])
        if has_call:
            cells.append(r["call"])
        return "| " + " | ".join(cells) + " |"

    if args.compact:
        head = ["#", "东西", "测得 px", "表里 px", "超出表里范围几倍", "判定"]
    else:
        head = ["#", "东西", "框", "测得 px", "折合几个人", "表里 px", "表里几个人", "对表中值几倍", "超出表里范围几倍（判定用）", "判定"]
    if has_src:
        head.append("来源")
    if has_call:
        head.append("结论")
    head_lines = ["| " + " | ".join(head) + " |", "| " + " | ".join("---" for _ in head) + " |"]
    order = []
    for r in rows:
        if r["group"] not in order:
            order.append(r["group"])
    for g in order:
        if g:
            lines.append("**%s**" % g)
            lines.append("")
        lines.extend(head_lines)
        lines.extend(fmt_row(r) for r in rows if r["group"] == g)
        lines.append("")
    lines.pop()
    lines.append("")
    lines.append("红 %d · 黄 %d · 绿 %d（共 %d 项）" % (len(reds), len(warns), len(rows) - len(reds) - len(warns), len(rows)))
    if reds:
        lines.append("**打回**：%d 项超出「表里 1.5 倍／一半」——%s" % (len(reds), "、".join("#%d %s（超出表里范围 %.1f×）" % (r["n"], r["name"], r["ratio"]) for r in reds)))
    else:
        lines.append("**没有红项。**")
    if warns:
        lines.append("要看一眼（黄）：%s" % "、".join("#%d %s（%.2f×）" % (r["n"], r["name"], r["ratio"]) for r in warns))
    text = "\n".join(lines)
    print(text)
    if args.md:
        open(args.md, "w", encoding="utf-8").write(text + "\n")
    if args.json:
        json.dump({"scene": scene, "person_px": person_px, "scale": scale, "rows": rows,
                   "red": [r["name"] for r in reds], "warn": [r["name"] for r in warns]},
                  open(args.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    img_path = args.image or spec.get("image")
    if args.annot and img_path:
        base = spec_dir_join(args.boxes, img_path)
        if not os.path.exists(base):
            print("\n没找到图 %s，跳过标图（表照出）。%s" % (base, spec.get("image_how", "")), file=sys.stderr)
            return 1 if reds else 0
        im = Image.open(base).convert("RGB")
        d = ImageDraw.Draw(im, "RGBA")
        font, _cjk = load_font(max(14, im.width // 80))
        colors = {"红": (255, 40, 40, 255), "黄": (255, 200, 0, 255), "绿": (60, 220, 90, 255)}
        rank = {"红": 2, "黄": 1, "绿": 0}
        groups = {}
        for r in rows:
            if r["draw"]:
                groups.setdefault(tuple(r["box"]), []).append(r)
        placed = []  # 已经放了的标签框，后来的躲开它们

        def put_label(text, x, y_above, y_below, color):
            w, h = font.getlength(text) + 8, font.size + 4
            x = max(0, min(x, im.width - w))
            for ly in (y_above - h, y_below, y_above + 2, y_below + h):
                r = (x, ly, x + w, ly + h)
                if ly < 0 or ly + h > im.height:
                    continue
                if any(r[0] < q[2] and q[0] < r[2] and r[1] < q[3] and q[1] < r[3] for q in placed):
                    continue
                break
            else:
                ly = max(0, y_above - h)
                r = (x, ly, x + w, ly + h)
            placed.append(r)
            d.rectangle(r, fill=(0, 0, 0, 215))
            d.text((r[0] + 4, r[1] + 1), text, fill=color, font=font)

        for box, rs in groups.items():
            worst = max(rs, key=lambda r: (rank[r["verdict"][0]], r["ratio"] if r["ratio"] >= 1 else 1.0 / max(r["ratio"], 1e-6)))
            c = colors[worst["verdict"][0]]
            x0, y0, x1, y1 = box
            d.rectangle([x0, y0, x1, y1], outline=c, width=3)
            put_label("#" + ",".join(str(r["n"]) for r in rs) + " %.1f×" % worst["ratio"], x0, y0, y1 + 2, c)
        # 拿游戏里真的人（84 像素）贴在指定的脚点上当尺子；框文件里 rulers: [[x, 脚的 y], ...]，不写就贴在左上角
        rulers = spec.get("rulers") or [[40, 100]]
        if os.path.exists(PERSON_PNG):
            person = Image.open(PERSON_PNG).convert("RGBA")
            k = (person_px / PERSON_PX) / scale
            person = person.resize((max(1, int(person.width * k)), max(1, int(person.height * k))), Image.NEAREST)
            halo = person.split()[-1].filter(ImageFilter.MaxFilter(7))
            halo_img = Image.new("RGBA", person.size, (255, 255, 255, 255))
            for (rx, ry) in rulers:
                px, py = int(rx - person.width / 2), int(ry - person.height)
                im.paste(halo_img, (px, py), halo)
                im.paste(person, (px, py), person)
                put_label("人 %g px" % person_px, px - 10, py, py + person.height + 2, (255, 255, 255, 255))
        else:
            for (rx, ry) in rulers:
                d.rectangle([rx - 10, ry - person_px / scale, rx + 10, ry], fill=(255, 255, 255, 200), outline=(0, 0, 0, 255), width=2)
        im.save(args.annot, quality=75, optimize=True) if args.annot.lower().endswith((".jpg", ".jpeg")) else im.save(args.annot)
        print("\n标了框的图：%s" % args.annot)
    return 1 if reds else 0


def spec_dir_join(boxes_path, img_path):
    if os.path.isabs(img_path) or os.path.exists(img_path):
        return img_path
    return os.path.join(os.path.dirname(os.path.abspath(boxes_path)), img_path)


def main():
    ap = argparse.ArgumentParser(description="比例量尺（人 = 1）")
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("grid", help="放大一块、盖上带坐标的格子，读框用")
    g.add_argument("image")
    g.add_argument("--region", help="x0,y0,x1,y1（图上像素），不写就整张")
    g.add_argument("--zoom", type=float, default=3.0)
    g.add_argument("--step", type=int, default=50, help="格子多大（图上像素）")
    g.add_argument("-o", "--out", required=True)
    g.set_defaults(fn=cmd_grid)
    m = sub.add_parser("measure", help="读框文件，出偏差表")
    m.add_argument("boxes", help="框文件（JSON）")
    m.add_argument("--image", help="不写就用框文件里的 image")
    m.add_argument("--person-px", type=float, help="覆盖框文件里的 person_px")
    m.add_argument("--md")
    m.add_argument("--json")
    m.add_argument("--annot", help="存一张标了框的图")
    m.add_argument("--compact", action="store_true", help="窄表：不列框和几个人，按节、来源、结论排")
    m.set_defaults(fn=cmd_measure)
    b = sub.add_parser("bbox", help="带透明的 PNG 不透明部分的外框")
    b.add_argument("image")
    b.add_argument("--alpha", type=int, default=16, help="透明度大于它才算不透明（默认 16）")
    b.set_defaults(fn=cmd_bbox)
    s = sub.add_parser("std", help="打印标准表")
    s.set_defaults(fn=cmd_std)
    args = ap.parse_args()
    sys.exit(args.fn(args) or 0)


if __name__ == "__main__":
    main()
