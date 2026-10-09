#!/usr/bin/env python3
"""还原对照：效果图（或 GPT 拼回去的那张）对游戏里同一块的截图，看画面还原得像不像（01 D 10/2 派）。
只用 PIL，不靠 numpy。

出什么：
  1. 一张对照图：左效果图、中游戏截图（已经对齐到效果图上）、右差异热图（越红差得越多），差得多的地方框出来，
     有摆放清单就标零件的 id，没有就标「区域 N」
  2. 几个数（打在终端，另存一份 JSON）：
     - 整体差多少：平均差（0～255）、差得多的像素占几成
     - 每件零件（有摆放清单才有）：位置偏了几像素（dx, dy）、大小差几成、像不像（匹配差）
  3. 给了 --pass 就判过没过（退出码 0 过、1 没过），过了才给 04 和阿鱼看

用法：
  python3 godot/tools/restore_check.py 效果图.png 游戏截图.png --out 出图.png
      [--placement 清单.json] [--placement-frame ref|game]
      [--game-scale 0.6165] [--align 24] [--search 20] [--cell 16] [--thresh 40]
      [--pass 平均差上限,零件偏移上限像素,大小差上限成]   例：--pass 18,6,0.1

  --placement：摆放清单。认两种：
      - GPT 造景台的 placement JSON（02 提的格式，见 godot/回执/造景台摆放清单-格式建议.md）：items 里每件 id、file、foot，
        files 里每个文件的 anchor；零件图从 --parts 文件夹找（默认清单旁边的「积木」「人物」）
      - 我们游戏的 scene.json（55 桌厅 assets/layered/scene_roman_banquet_55/scene.json）：occluders 里每件 id、image、x、y
  --placement-frame：清单里的坐标是哪张图上的。ref = 效果图（GPT 清单，默认），game = 游戏截图（我们的 scene.json）
  --game-scale：游戏截图缩多少倍才跟效果图一样大；不给就按宽度自动算
  --align：整张再挪多少像素以内找最对得上的位置（同一镜头时设小一点）
  --search：每件零件在多大范围里找它（像素，效果图上的）
怎么算的（写给以后改的人）：
  - 对齐：游戏截图缩到效果图大小，在 ±align 里找整体平移，取灰度平均差最小的
  - 热图：两张都轻微模糊（去掉像素抖动）再相减，灰度，乘 4；按 cell×cell 一格格取平均，超过 thresh 的格子连成块就是一个框
  - 零件：把零件那一块从清单所在的图上抠出来，在另一张图 ±search、缩放 0.8～1.25 里找最像的位置；
    先在 1/4 大小上粗找，再回原大小 ±3 细找；一样像时偏向没缩放、没挪（TIE）；偏移按脚（下沿正中）报，贴图边的零件裁到图里那一截
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageStat

FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
SCALES = [0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2, 1.25]
TIE = 1.0   # 一样像的时候偏向「没缩放、没挪」：缩 5% 记 1 分、挪 1 像素记 0.05 分（匹配差是 0～255 的灰度平均差）


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except Exception:
        return ImageFont.load_default()


def gray(im):
    return im.convert("L")


def mean_diff(a, b):
    return ImageStat.Stat(ImageChops.difference(a, b)).mean[0]


# ---------- 对齐 ----------
def align(ref, game, scale, radius):
    """游戏截图缩放到效果图大小，在 ±radius 里找整体平移。返回 (对齐后的 RGB 图, dx, dy, 平均差)"""
    gw, gh = game.size
    g = game.resize((max(1, round(gw * scale)), max(1, round(gh * scale))), Image.LANCZOS)
    W, H = ref.size

    def placed(img, dx, dy):
        c = Image.new(img.mode, (W, H), 0 if img.mode == "L" else (0, 0, 0))
        c.paste(img, (dx, dy))
        return c

    q = 4
    rs = gray(ref).resize((max(1, W // q), max(1, H // q)), Image.BOX)
    gs = gray(g).resize((max(1, g.width // q), max(1, g.height // q)), Image.BOX)
    best = (1e9, 0, 0)
    r = max(1, radius // q)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = mean_diff(rs, placed(gs, dx, dy))
            if d < best[0]:
                best = (d, dx * q, dy * q)
    _, bx, by = best
    rg = gray(ref)
    gg = gray(g)
    for dy in range(by - q, by + q + 1):
        for dx in range(bx - q, bx + q + 1):
            d = mean_diff(rg, placed(gg, dx, dy))
            if d < best[0]:
                best = (d, dx, dy)
    d, dx, dy = best
    out = ref.copy()   # 游戏截图挪了以后空出来的边用效果图补上，不算差
    out.paste(g.convert("RGB"), (dx, dy))
    return out, dx, dy, d


# ---------- 热图和框 ----------
def heat(ref, game, cell, thresh):
    a = gray(ref).filter(ImageFilter.GaussianBlur(2))
    b = gray(game).filter(ImageFilter.GaussianBlur(2))
    diff = ImageChops.difference(a, b)
    W, H = diff.size
    cw, ch = max(1, W // cell), max(1, H // cell)
    grid = diff.resize((cw, ch), Image.BOX)
    px = grid.load()
    hot = [[px[x, y] > thresh for x in range(cw)] for y in range(ch)]
    seen = [[False] * cw for _ in range(ch)]
    boxes = []
    for y in range(ch):
        for x in range(cw):
            if not hot[y][x] or seen[y][x]:
                continue
            stack = [(x, y)]
            seen[y][x] = True
            cells = []
            while stack:
                cx, cy = stack.pop()
                cells.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < cw and 0 <= ny < ch and hot[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if len(cells) < 3:
                continue
            xs = [c[0] for c in cells]
            ys = [c[1] for c in cells]
            boxes.append({"box": [min(xs) * cell, min(ys) * cell, (max(xs) + 1) * cell, (max(ys) + 1) * cell],
                          "cells": len(cells),
                          "mean": round(sum(px[c] for c in cells) / len(cells), 1)})
    boxes.sort(key=lambda b: -b["cells"] * b["mean"])
    over = ImageStat.Stat(diff.point(lambda v: 255 if v > thresh else 0)).mean[0] / 255.0
    overall = ImageStat.Stat(diff).mean[0]
    amp = diff.point(lambda v: min(255, v * 4))
    return amp, boxes, overall, over


# ---------- 摆放清单 ----------
def load_placement(path, parts_dir):
    """统一成 [{id, box:[x,y,w,h], image:路径或 None}]"""
    d = json.load(open(path, encoding="utf-8-sig"))
    out = []
    here = os.path.dirname(os.path.abspath(path))
    if "occluders" in d:   # 我们的 scene.json
        godot = here
        while godot != "/" and not os.path.exists(os.path.join(godot, "project.godot")):
            godot = os.path.dirname(godot)
        if not os.path.exists(os.path.join(godot, "project.godot")):
            godot = os.getcwd()   # 清单不在 godot 工程里（比如拷出去了）：按在 godot/ 里跑算
        for o in d["occluders"]:
            img = str(o.get("image", ""))
            p = os.path.join(godot, img.replace("res://", "")) if img.startswith("res://") else None
            try:
                w, h = Image.open(p).size if p else (0, 0)
            except Exception:
                w, h, p = 0, 0, None
            if w and h:
                out.append({"id": str(o["id"]), "box": [int(o["x"]), int(o["y"]), w, h], "image": p})
        return out
    files = d.get("files", {})
    dirs = [parts_dir] if parts_dir else [os.path.join(here, "..", "积木"), os.path.join(here, "..", "人物"), here]
    for it in d.get("items", []):
        f = it.get("file") or it.get("sheet")
        if not f or "foot" not in it:
            continue
        p = next((os.path.join(dd, f) for dd in dirs if dd and os.path.exists(os.path.join(dd, f))), None)
        if p is None:
            continue
        w, h = Image.open(p).size
        cell = files.get(f, {}).get("cell") if isinstance(files.get(f), dict) else None
        if cell:
            w, h = int(cell[0]), int(cell[1])
        ax, ay = files.get(f, {}).get("anchor", [w // 2, h]) if isinstance(files.get(f), dict) else (w // 2, h)
        fx, fy = it["foot"]
        out.append({"id": str(it["id"]), "box": [int(fx - ax), int(fy - ay), w, h], "image": p})
    return out


def to_ref(box, frame, scale, dx, dy):
    if frame == "ref":
        return list(box)
    x, y, w, h = box
    return [round(x * scale + dx), round(y * scale + dy), max(1, round(w * scale)), max(1, round(h * scale))]


# ---------- 每件零件找位置、大小 ----------
def match_part(src, dst, box, search):
    """src 上 box 那一块，在 dst 里 ±search、缩放 SCALES 里找最像的。返回 (dx, dy, scale, 匹配差)"""
    x, y, w, h = box
    W, H = src.size
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)   # 贴着图边的零件：裁到图里那一截
    if x1 - x0 < 6 or y1 - y0 < 6:
        return None
    x, y, w, h = x0, y0, x1 - x0, y1 - y0
    tpl = src.crop((x, y, x + w, y + h))
    best = (1e9, 0, 0, 1.0)
    q = 4
    srcq = (max(1, w // q), max(1, h // q))
    dstq = dst.resize((max(1, dst.width // q), max(1, dst.height // q)), Image.BOX)
    for s in SCALES:
        tw, th = max(2, round(w * s / q)), max(2, round(h * s / q))
        t = tpl.resize((tw, th), Image.BOX)
        cx, cy = (x + w / 2) / q, (y + h / 2) / q
        r = max(1, search // q)
        for oy in range(-r, r + 1):
            for ox in range(-r, r + 1):
                l, tp = round(cx + ox - tw / 2), round(cy + oy - th / 2)
                if l < 0 or tp < 0 or l + tw > dstq.width or tp + th > dstq.height:
                    continue
                d = mean_diff(t, dstq.crop((l, tp, l + tw, tp + th))) + TIE * (abs(s - 1) * 20 + (abs(ox) + abs(oy)) * 0.05)
                if d < best[0]:
                    best = (d, ox * q, oy * q, s)
    _, bx, by, bs = best
    if best[0] >= 1e9:
        return None
    best = (1e9, 0, 0, 1.0)   # 原大小上重新比：粗找在 1/4 上取整会差一两个像素，缩放也可能挑歪，邻近两档和「不缩放」都再试
    cx, cy = x + w / 2, y + h / 2
    tries = sorted({round(bs - 0.05, 2), bs, round(bs + 0.05, 2), 1.0})
    for s in tries:
        tw, th = max(2, round(w * s)), max(2, round(h * s))
        t = tpl if s == 1.0 else tpl.resize((tw, th), Image.LANCZOS)
        centers = [(bx, by), (0, 0)] if s == 1.0 else [(bx, by)]
        for ccx, ccy in centers:
            for oy in range(ccy - 3, ccy + 4):
                for ox in range(ccx - 3, ccx + 4):
                    l, tp = round(cx + ox - tw / 2), round(cy + oy - th / 2)
                    if l < 0 or tp < 0 or l + tw > dst.width or tp + th > dst.height:
                        continue
                    d = mean_diff(t, dst.crop((l, tp, l + tw, tp + th))) + TIE * (abs(s - 1) * 20 + (abs(ox) + abs(oy)) * 0.05)
                    if d < best[0]:
                        best = (d, ox, oy, s)
    d, ox, oy, s = best
    tw, th = max(2, round(w * s)), max(2, round(h * s))
    t = tpl if s == 1.0 else tpl.resize((tw, th), Image.LANCZOS)
    raw = mean_diff(t, dst.crop((round(cx + ox - tw / 2), round(cy + oy - th / 2), round(cx + ox - tw / 2) + tw, round(cy + oy - th / 2) + th)))
    # 零件都是脚踩在图下沿：偏移按脚（下沿正中）算，放大缩小时脚不动就算没偏
    foot_dy = oy + (h * s - h) / 2.0
    return ox, round(foot_dy), s, round(raw, 1)


# ---------- 出图 ----------
def panel(ref, game, amp, boxes, parts, out):
    W, H = ref.size
    hm = Image.merge("RGB", (amp, Image.new("L", amp.size, 0), Image.new("L", amp.size, 0)))
    over = Image.blend(gray(ref).convert("RGB"), hm, 0.6)
    d = ImageDraw.Draw(over)
    f = font(max(12, W // 70))
    for i, b in enumerate(boxes[:20]):
        x0, y0, x1, y1 = b["box"]
        d.rectangle([x0, y0, x1, y1], outline=(255, 230, 0), width=2)
        d.text((x0 + 3, y0 + 2), b.get("label", "区域 %d" % (i + 1)), fill=(255, 255, 0), font=f)
    for p in parts:
        if p.get("dx") is None:
            continue
        x, y, w, h = p["box"]
        col = (0, 220, 255) if abs(p["dx"]) <= 6 and abs(p["dy"]) <= 6 and abs(p["scale"] - 1) <= 0.1 else (255, 80, 255)
        d.rectangle([x, y, x + w, y + h], outline=col, width=1)
    gap = 12
    head = max(24, W // 40)
    canvas = Image.new("RGB", (W * 3 + gap * 2, H + head), (30, 30, 30))
    hd = ImageDraw.Draw(canvas)
    hf = font(max(14, W // 60))
    for k, (img, title) in enumerate(((ref, "效果图"), (game, "游戏截图（已对齐）"), (over, "差异（越红差越多；黄框=差得多，青框=零件对上，紫框=零件偏了）"))):
        canvas.paste(img.convert("RGB"), (k * (W + gap), head))
        hd.text((k * (W + gap) + 6, 4), title, fill=(240, 240, 240), font=hf)
    canvas.save(out)


def main():
    ap = argparse.ArgumentParser(description="还原对照：效果图 vs 游戏截图")
    ap.add_argument("ref")
    ap.add_argument("game")
    ap.add_argument("--out", required=True)
    ap.add_argument("--placement")
    ap.add_argument("--placement-frame", choices=["ref", "game"], default="ref")
    ap.add_argument("--parts")
    ap.add_argument("--game-scale", type=float)
    ap.add_argument("--align", type=int, default=24)
    ap.add_argument("--search", type=int, default=20)
    ap.add_argument("--cell", type=int, default=16)
    ap.add_argument("--thresh", type=float, default=40)
    ap.add_argument("--pass", dest="pass_line")
    ap.add_argument("--match-bad", type=float, default=30, help="零件匹配差超过这个就算「没找到像的」（样子不一样、没画、被挡住），不报偏移")
    a = ap.parse_args()

    ref = Image.open(a.ref).convert("RGB")
    game0 = Image.open(a.game).convert("RGB")
    scale = a.game_scale or ref.width / game0.width
    game, gdx, gdy, gdiff = align(ref, game0, scale, a.align)
    amp, boxes, overall, over = heat(ref, game, a.cell, a.thresh)

    parts = []
    if a.placement:
        items = load_placement(a.placement, a.parts)
        for it in items:
            box = to_ref(it["box"], a.placement_frame, scale, gdx, gdy)
            if box[0] >= ref.width or box[1] >= ref.height or box[0] + box[2] <= 0 or box[1] + box[3] <= 0:
                continue   # 不在这块画面里（比如 55 桌厅南边那些）
            # 清单在哪张图上，就从哪张图抠零件、去另一张找
            src, dst = (ref, game) if a.placement_frame == "ref" else (game, ref)
            m = match_part(gray(src), gray(dst), box, a.search)
            row = {"id": it["id"], "box": box}
            if m and m[3] <= a.match_bad:
                row.update({"dx": m[0], "dy": m[1], "scale": m[2], "match": m[3]})
            elif m:
                row["match"] = m[3]   # 找了，但最像的地方也差很多：不报偏移，免得报出一个假的数
            parts.append(row)
        for b in boxes:   # 框里压着哪几件零件
            x0, y0, x1, y1 = b["box"]
            hit = []
            for p in parts:
                x, y, w, h = p["box"]
                ix = max(0, min(x1, x + w) - max(x0, x))
                iy = max(0, min(y1, y + h) - max(y0, y))
                if ix * iy > 0.3 * w * h:
                    hit.append(p["id"])
            if hit:
                b["label"] = "、".join(hit[:3]) + ("等 %d 件" % len(hit) if len(hit) > 3 else "")
                b["parts"] = hit
    for i, b in enumerate(boxes):
        b.setdefault("label", "区域 %d" % (i + 1))

    panel(ref, game, amp, boxes, parts, a.out)
    report = {
        "ref": a.ref, "game": a.game, "game_scale": round(scale, 4), "align_dx": gdx, "align_dy": gdy,
        "overall_mean_diff": round(overall, 1), "over_thresh_share": round(over, 3),
        "boxes": boxes[:20], "parts": parts,
    }
    json.dump(report, open(os.path.splitext(a.out)[0] + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    print("对齐：游戏截图缩 %.4f 倍、整体挪 (%d, %d)" % (scale, gdx, gdy))
    print("整体：平均差 %.1f（0～255），差得多（>%g）的像素占 %.1f%%" % (overall, a.thresh, over * 100))
    print("差得多的地方 %d 块（图上黄框，前 20 块）：" % len(boxes))
    for b in boxes[:8]:
        print("  %s：框 %s，平均差 %.0f" % (b["label"], b["box"], b["mean"]))
    moved = [p for p in parts if p.get("dx") is not None]
    if parts:
        moved.sort(key=lambda p: -(abs(p["dx"]) + abs(p["dy"]) + abs(p["scale"] - 1) * 100))
        lost = [p for p in parts if p.get("dx") is None]
        print("零件 %d 件，找到像的 %d 件；没找到像的 %d 件（匹配差 > %g：样子不一样、没画、被挡住）%s" % (
            len(parts), len(moved), len(lost), a.match_bad, "：" + "、".join(p["id"] for p in lost[:8]) + ("……" if len(lost) > 8 else "") if lost else ""))
        if moved:
            print("找到的里面偏得最多的：")
        for p in moved[:10]:
            print("  %s：偏 (%+d, %+d) 像素，大小 %+.0f%%，匹配差 %.0f" % (p["id"], p["dx"], p["dy"], (p["scale"] - 1) * 100, p["match"]))
    print("出图：%s（数另存 %s）" % (a.out, os.path.splitext(a.out)[0] + ".json"))
    if a.pass_line:
        lim_diff, lim_px, lim_scale = [float(v) for v in a.pass_line.split(",")]
        bad_parts = [p for p in moved if abs(p["dx"]) > lim_px or abs(p["dy"]) > lim_px or abs(p["scale"] - 1) > lim_scale]
        ok = overall <= lim_diff and not bad_parts and len(moved) == len(parts)
        print("判定：%s（平均差 %.1f / 上限 %g；偏了的零件 %d 件；没找到的 %d 件）" % ("过" if ok else "没过", overall, lim_diff, len(bad_parts), len(parts) - len(moved)))
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
