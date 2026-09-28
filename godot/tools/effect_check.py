#!/usr/bin/env python3
"""GPT 交的效果图（画出来的、不是纯色块）对摆位色块图：每件东西的中心偏多少、画多大、多出来／少掉哪几件。只用 PIL，不靠 numpy。

用途：55 桌宴会厅北边那块（1536×1024），GPT 照 claude-55桌摆位-北-干净.png 和摆位表画了 5 张效果图；03 量「能不能还原」。
桌子按地面色自动切（脚本里的 detect）；台子、台阶、乐队地台、宫灯这些手量（框文件里写 [x0,y0,x1,y1]，用
  python3 godot/tools/scale_check.py grid 图.png --region x0,y0,x1,y1 --zoom 2.5 --step 20 -o /tmp/g.png 放大盖格子读，±4 像素）。

子命令：
  detect   自动切：地面色以外的东西 → 连通块。打印每块的框，存一张带编号的图（--out），桌子（150～215 宽）单独标 T
    python3 godot/tools/effect_check.py detect --png 效果图.png [--out 编号图.png] [--json 候选.json]
  compare  框文件（图上量的）对摆位表：每件的中心偏、宽高比、下沿偏；桌子做整体配对（谁是谁、多出来、少掉）；出叠图
    python3 godot/tools/effect_check.py compare --boxes 框.json --table 摆位表-北.md --png 效果图.png [--overlay 叠图.jpg] [--clean 干净.png]
框文件：{"image": 图名, "tables": [[x0,y0,x1,y1], ...]（detect 切的，碰红毯的手量后改）,
        "items": {表里的名字: [x0,y0,x1,y1] 或 null（没画）}, "extra": {说明: [x0,y0,x1,y1]}（表里没有、图上多出来的）}
"""
import argparse
import json
import os
import re
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import board_check as bc

FLOOR_SAMPLE = (30, 400, 100, 560)      # 每张图这块都是地面（左边空地）：取里面最多的几种颜色当地面色
TOL = 26                                # 地面色容差（三个通道各差不超过这个）
OPEN = 5                                # 开运算大小：去掉地砖上的小花纹
TABLE_W = (150, 215)                    # 桌子（连椅子）宽的范围；摆位表 140，画大 1.5 倍以内都认


def floor_mask(im):
    reg = im.crop(FLOOR_SAMPLE)
    c = Counter((r // 8 * 8 + 4, g // 8 * 8 + 4, b // 8 * 8 + 4) for r, g, b in reg.getdata())
    pal = [k for k, v in c.most_common(6) if v > 200]
    R, G, B = im.split()
    tot = None
    for (r, g, b) in pal:
        m = ImageChops.darker(ImageChops.darker(R.point(lambda v: 255 if abs(v - r) <= TOL else 0),
                                                G.point(lambda v: 255 if abs(v - g) <= TOL else 0)),
                              B.point(lambda v: 255 if abs(v - b) <= TOL else 0))
        tot = m if tot is None else ImageChops.lighter(tot, m)
    return tot, pal


def carpet_runs(im, fm=None, y0=340, y1=1020, step=8):
    """每隔几行，从 x=768 往两边走到第一处地面色：这一段就是红毯（贴着红毯的椅子、灯会让这一行偏宽，后面拟合时扔掉）"""
    if fm is None:
        fm = floor_mask(im)[0]
    f = fm.load()
    W = im.size[0]
    rows = []
    for y in range(y0, y1 + 1, step):
        L = 768
        while L > 1 and not (f[L, y] and f[L - 1, y] and f[L - 2, y]):
            L -= 1
        R = 768
        while R < W - 3 and not (f[R, y] and f[R + 1, y] and f[R + 2, y]):
            R += 1
        rows.append((y, L + 1, R - 1))
    return rows


def theil_sen(pts):
    """pts: [(y, x)] -> (斜率, 截距)；一堆点对的斜率取中位数，扔得掉一小半的坏点"""
    sl = []
    for i in range(len(pts)):
        for j in range(i + 1, len(pts)):
            if pts[j][0] != pts[i][0]:
                sl.append((pts[j][1] - pts[i][1]) / (pts[j][0] - pts[i][0]))
    sl.sort()
    k = sl[len(sl) // 2]
    ic = sorted(x - k * y for y, x in pts)
    return k, ic[len(ic) // 2]


def carpet_fit(im, fm=None):
    """红毯左右边：{L:(k,b), R:(k,b)}，x = k*y + b。只用宽度 ≤ 200 的行拟合"""
    rows = [r for r in carpet_runs(im, fm) if r[2] - r[1] + 1 <= 200]
    kl, bl = theil_sen([(y, L) for y, L, R in rows])
    kr, br = theil_sen([(y, R) for y, L, R in rows])
    return {"L": (kl, bl), "R": (kr, br)}


def carpet_at(fit, y):
    return round(fit["L"][0] * y + fit["L"][1]), round(fit["R"][0] * y + fit["R"][1])


def strip_poly(fit, y_top, H, margin=6):
    (l0, r0), (l1, r1) = carpet_at(fit, y_top), carpet_at(fit, H - 1)
    return [(l0 - margin, y_top), (r0 + margin, y_top), (r1 + margin, H - 1), (l1 - margin, H - 1)]


def detect(im, y_top=190):
    fm, pal = floor_mask(im)
    fit = carpet_fit(im, fm)
    nf = ImageChops.invert(fm)
    ImageDraw.Draw(nf).polygon(strip_poly(fit, y_top, im.size[1]), fill=0)      # 红毯这一条不算
    nf = nf.filter(ImageFilter.MinFilter(OPEN)).filter(ImageFilter.MaxFilter(OPEN))
    blank = Image.new("L", im.size, 0)
    blank.paste(nf.crop((0, y_top, im.size[0], im.size[1])), (0, y_top))
    comps = [c for c in bc.components(blank) if c[4] > 300 and c[1] > y_top]
    out = []
    for c in comps:
        w = c[2] - c[0] + 1
        if w >= TABLE_W[1] * 1.5 and 100 <= c[3] - c[1] + 1 <= 200 and c[4] > 20000 and c[1] >= 400:      # 两张桌子的椅子挨在一起连成一块：从最窄的那一列切开
            sub = blank.crop((c[0], c[1], c[2] + 1, c[3] + 1)).tobytes()
            h = c[3] - c[1] + 1
            cols = [sum(1 for y in range(h) if sub[y * w + x] == 255) for x in range(w)]
            lo, hi = int(w * 0.35), int(w * 0.65)
            cut = min(range(lo, hi), key=lambda x: cols[x])
            for a, b in ((0, cut), (cut + 1, w - 1)):
                part = blank.crop((c[0] + a, c[1], c[0] + b + 1, c[3] + 1))
                bb = part.getbbox()
                out.append((c[0] + a + bb[0], c[1] + bb[1], c[0] + a + bb[2] - 1, c[1] + bb[3] - 1, c[4] // 2))
        else:
            out.append(c)
    return out, fit, pal


def dark_wood(p):
    return p[0] < 100 and p[1] < 70 and p[2] < 50 and p[0] >= p[1] >= p[2] - 5


def extend_into_strip(im, box, fit, margin=6):
    """桌子的椅子压在红毯边上时，红毯那条被挖掉了，框会少一截：从挖掉的边往红毯里一列列找椅子的深棕描边，
    每列至少 3 个像素才算，一断就停"""
    x0, y0, x1, y1 = box
    px = im.load()
    W = im.size[0]
    ym = (y0 + y1) // 2
    L, R = carpet_at(fit, ym)
    L, R = L - margin, R + margin
    if x1 >= L - 1 and x0 < L:                               # 桌子在红毯西边，右边被挖了
        x = L
        while x < min(W, L + 60) and sum(1 for y in range(y0, y1 + 1) if dark_wood(px[x, y])) >= 3:
            x += 1
        x1 = max(x1, x - 1)
    if x0 <= R + 1 and x1 > R:                               # 桌子在红毯东边，左边被挖了
        x = R
        while x > max(0, R - 60) and sum(1 for y in range(y0, y1 + 1) if dark_wood(px[x, y])) >= 3:
            x -= 1
        x0 = min(x0, x + 1)
    return [x0, y0, x1, y1]


def is_table(c, H):
    """桌子：宽 150～215、面积 6000 以上；高够 120，或者是最南一排（被下沿切掉、或被画成半张，只露 70～130）"""
    w = c[2] - c[0] + 1
    h = c[3] - c[1] + 1
    return TABLE_W[0] <= w <= TABLE_W[1] and c[4] > 6000 and (h >= 120 or (h >= 60 and c[3] >= H - 40))


def cmd_detect(args):
    im = Image.open(args.png).convert("RGB")
    H = im.size[1]
    comps, fit, pal = detect(im)
    print(f"地面色 {pal[:3]}…；红毯 y=400 时 x {carpet_at(fit, 400)}、y=1000 时 x {carpet_at(fit, 1000)}（已挖掉）；共 {len(comps)} 块")
    out = []
    o = im.copy()
    d = ImageDraw.Draw(o)
    ti = 0
    for i, c in enumerate(comps):
        t = is_table(c, H)
        Lm, Rm = carpet_at(fit, (c[1] + c[3]) // 2)
        touch = (c[2] >= Lm - 9 and c[0] < Lm) or (c[0] <= Rm + 9 and c[2] > Rm)
        tag = ""
        if t:
            ti += 1
            tag = f"T{ti}"
        w, h = c[2] - c[0] + 1, c[3] - c[1] + 1
        print(f"  {i:>2} {tag:<4} x{c[0]}～{c[2]} y{c[1]}～{c[3]}  {w}×{h}  面积{c[4]}{'  碰红毯' if touch else ''}{'  被下沿切' if c[3] >= H - 2 else ''}")
        box = [c[0], c[1], c[2], c[3]]
        if t and touch:
            box = extend_into_strip(im, box, fit)
            print(f"       碰红毯：往红毯里找到椅子描边，框改成 x{box[0]}～{box[2]}")
        d.rectangle(box, outline=(0, 255, 255) if t else (255, 255, 0), width=2)
        d.text((c[0] + 4, c[1] + 4), tag or str(i), fill=(255, 255, 255))
        out.append({"id": i, "table": t, "box": box, "area": c[4], "touch_carpet": touch})
    if args.out:
        o.save(args.out)
    if args.json:
        json.dump(out, open(args.json, "w"), ensure_ascii=False, indent=1)


# ---------------- compare：框文件 对 摆位表 ----------------
POS_TOL = 8            # 位置：中心（左右）和落地线（下沿）各差不超过 8 像素算「在原位」
SIZE_LO, SIZE_HI = 0.9, 1.1          # 大小：宽、高各在表里框的 0.9～1.1 倍算「画满了框」
MATCH_R = 120          # 桌子配对：中心距超过这个就不算「同一张」
RED_BIG, RED_SMALL, WARN_BIG, WARN_SMALL = 1.5, 0.5, 1.25, 2.0 / 3.0     # 和 scale_check 一样

UNION = {"婚礼台": ["婚礼台（台面）", "婚礼台（台口立面）"]}


def bp_frame(rows, name):
    names = UNION.get(name, [name])
    rs = [r for r in rows if r["name"] in names]
    if not rs:
        return None
    x0 = min(r["x"] for r in rs); y0 = min(r["y"] for r in rs)
    x1 = max(r["x"] + r["w"] for r in rs); y1 = max(r["y"] + r["h"] for r in rs)
    return [x0, y0, x1, y1], any(r["cut"] for r in rs)


def size_of(b):
    return b[2] - b[0] + 1 if len(b) == 4 else 0, b[3] - b[1] + 1


def ctr(b):
    return (b[0] + b[2]) / 2.0, (b[1] + b[3]) / 2.0


def verdict(ratio):
    if ratio > RED_BIG or ratio < RED_SMALL:
        return "红"
    if ratio > WARN_BIG or ratio < WARN_SMALL:
        return "黄"
    return "绿"


def rows_of(boxes, key, gap=50):
    """按上沿 y 分排：[(排里各张的下标, 平均上沿 y)]，从上到下"""
    order = sorted(range(len(boxes)), key=lambda i: key(boxes[i]))
    out = []
    for i in order:
        if out and abs(key(boxes[i]) - sum(key(boxes[j]) for j in out[-1]) / len(out[-1])) <= gap:
            out[-1].append(i)
        else:
            out.append([i])
    return [(sorted(r, key=lambda i: ctr(boxes[i])[0]), sum(key(boxes[j]) for j in r) / len(r)) for r in out]


def match_tables(bp, drawn):
    """桌子一排一排对：表里 3 排（3／6／6 张）和图上分出来的排，试「从图上第 0 排起」和「从第 1 排起」两种对法
    （有的图北墙下多画了一排），选左右偏差加没配上的罚分最小的；排里按左右位置一对一配（近的先配，超过 MATCH_R 不配）"""
    brows = rows_of([b["box"] for b in bp], lambda b: b[1])
    drows = rows_of(drawn, lambda d: d[1])
    best = None
    for off in (0, 1, 2):
        pairs, cost = [], 0
        for k, (bi, _) in enumerate(brows):
            if k + off >= len(drows):
                cost += 300 * len(bi)
                continue
            dj = drows[k + off][0]
            cand = sorted((abs(ctr(bp[i]["box"])[0] - ctr(drawn[j])[0]), i, j) for i in bi for j in dj)
            ui, uj = set(), set()
            for dist, i, j in cand:
                if i in ui or j in uj or dist > MATCH_R:
                    continue
                ui.add(i); uj.add(j); pairs.append((i, j, dist)); cost += dist
            cost += 300 * (len(bi) - len(ui))
        if best is None or cost < best[0]:
            best = (cost, off, pairs)
    pairs = sorted(best[2])
    ui = {i for i, j, d in pairs}; uj = {j for i, j, d in pairs}
    return pairs, [i for i in range(len(bp)) if i not in ui], [j for j in range(len(drawn)) if j not in uj], best[1], drows


def compare_one(rows, data, H=1024):
    """返回 {items:[...], tables:{pairs, missing, extra}}"""
    res = {"items": [], "tables": {}}
    for name, box in data["items"].items():
        f = bp_frame(rows, name)
        if f is None:
            continue
        fb, cut = f
        fw, fh = fb[2] - fb[0], fb[3] - fb[1]
        if box is None:
            res["items"].append({"name": name, "bp": fb, "drawn": None})
            continue
        dw, dh = box[2] - box[0] + 1, box[3] - box[1] + 1
        (cx, cy), (bx, by) = ctr(box), ctr(fb)
        r = {"name": name, "bp": fb, "drawn": box, "dx": round(cx - bx), "dy_c": round(cy - by),
             "dy_ground": box[3] - fb[3], "dw": dw, "dh": dh, "rw": dw / fw, "rh": dh / fh}
        r["pos_ok"] = abs(r["dx"]) <= POS_TOL and abs(r["dy_ground"]) <= POS_TOL
        r["size_ok"] = SIZE_LO <= r["rw"] <= SIZE_HI and SIZE_LO <= r["rh"] <= SIZE_HI
        r["red"] = verdict(r["rw"]) == "红" or verdict(r["rh"]) == "红"
        r["yellow"] = not r["red"] and (verdict(r["rw"]) == "黄" or verdict(r["rh"]) == "黄")
        res["items"].append(r)
    bps = [{"name": r["name"], "box": [r["x"], r["y"], r["x"] + r["w"] - 1, r["y"] + r["h"] - 1], "cut": bool(r["cut"]),
            "ground": r["ground"]} for r in rows if r["name"] == "主桌" or re.fullmatch(r"T\d+", r["name"])]
    pairs, missing, extra, off, drows = match_tables(bps, data["tables"])
    res["tables"] = {"bp": bps, "pairs": [], "missing": missing, "extra": extra, "row_offset": off,
                     "drawn_rows": [{"y": round(y), "n": len(r), "x": [round(ctr(data["tables"][i])[0]) for i in r]} for r, y in drows]}
    for i, j, dist in pairs:
        b, d = bps[i], data["tables"][j]
        dw, dh = d[2] - d[0] + 1, d[3] - d[1] + 1
        fw, fh = b["box"][2] - b["box"][0] + 1, b["box"][3] - b["box"][1] + 1
        cut_d = d[3] >= H - 3
        res["tables"]["pairs"].append({
            "bp": b["name"], "i": i, "j": j, "dist": dist, "dx": round(ctr(d)[0] - ctr(b["box"])[0]),
            "dy_top": d[1] - b["box"][1], "dy_ground": None if (cut_d or b["cut"]) else d[3] - b["box"][3],
            "dw": dw, "dh": dh, "rw": dw / fw, "rh": dh / fh, "cut_d": cut_d, "cut_bp": b["cut"]})
        pr = res["tables"]["pairs"][-1]
        # 被下沿切掉的（落地线在画外）比上沿；别的比落地线
        pr["in_place"] = abs(pr["dx"]) <= POS_TOL and abs(pr["dy_top"] if pr["dy_ground"] is None else pr["dy_ground"]) <= POS_TOL
    return res


def cmd_compare(args):
    rows = bc.parse_table(args.table)
    data = json.load(open(args.boxes, encoding="utf-8"))
    lines = []
    for n, im in data["images"].items():
        res = compare_one(rows, im, data["canvas"][1])
        lines.append(f"## 图 {n}\n")
        lines.append("| 东西 | 表里的框 x,y,宽×高 | 图上量到的框 | 中心左右偏 | 落地线（下沿）上下偏 | 宽 | 高 | 位置 | 大小 |")
        lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
        for r in res["items"]:
            fb = r["bp"]
            f = f"{fb[0]}, {fb[1]}，{fb[2] - fb[0]}×{fb[3] - fb[1]}"
            if r["drawn"] is None:
                lines.append(f"| {r['name']} | {f} | **没画** | — | — | — | — | 少掉 | — |")
                continue
            d = r["drawn"]
            lines.append(f"| {r['name']} | {f} | {d[0]}, {d[1]}，{r['dw']}×{r['dh']} | {r['dx']:+d} | {r['dy_ground']:+d} | "
                         f"{r['rw']:.2f}× | {r['rh']:.2f}× | {'在原位' if r['pos_ok'] else '偏了'} | "
                         f"{'画满' if r['size_ok'] else ('红' if r['red'] else ('黄' if r['yellow'] else '偏'))} |")
        t = res["tables"]
        lines.append("")
        lines.append("图上桌子的排（上沿 y、张数、各张中心 x）：" + "；".join(
            f"第 {k + 1} 排 y≈{r['y']}，{r['n']} 张，x = {'、'.join(map(str, r['x']))}" for k, r in enumerate(t["drawn_rows"])))
        lines.append("表里桌子的排：第 1 排 y=590，3 张（T1、主桌、T2）；第 2 排 y=770，6 张；第 3 排 y=950（被下沿切），6 张")
        lines.append("")
        lines.append(f"桌子：表里 {len(t['bp'])} 张，图上切出 {len(im['tables'])} 张；配上 {len(t['pairs'])} 对（表里第 1 排对图上第 {t['row_offset'] + 1} 排），"
                     f"表里没配上（少掉）{len(t['missing'])} 张：{'、'.join(t['bp'][i]['name'] for i in t['missing']) or '没有'}；"
                     f"图上没配上（多出来）{len(t['extra'])} 张")
        lines.append("")
        lines.append("| 表里的桌 | 表里框 | 配上的那张 | 中心左右偏 | 上沿上下偏 | 落地线上下偏 | 宽 | 高 | 位置（被切的比上沿） |")
        lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
        for p in t["pairs"]:
            b = t["bp"][p["i"]]["box"]; d = im["tables"][p["j"]]
            g = "被切" if p["dy_ground"] is None else f"{p['dy_ground']:+d}"
            ok = p["in_place"]
            lines.append(f"| {p['bp']} | {b[0]}, {b[1]}，{b[2]-b[0]+1}×{b[3]-b[1]+1} | {d[0]}, {d[1]}，{p['dw']}×{p['dh']} | "
                         f"{p['dx']:+d} | {p['dy_top']:+d} | {g} | {p['rw']:.2f}× | {p['rh']:.2f}× | "
                         f"{'在原位' if ok else '偏了'} |")
        lines.append("")
    text = "\n".join(lines)
    print(text)
    if args.md:
        open(args.md, "w", encoding="utf-8").write(text + "\n")
    if args.json_out:
        out = {}
        for n, im in data["images"].items():
            out[n] = compare_one(rows, im, data["canvas"][1])
        json.dump(out, open(args.json_out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def font(size):
    for f in ("/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc", "/Library/Fonts/Arial Unicode.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except Exception:
            pass
    return ImageFont.load_default()


def cmd_overlay(args):
    """叠图：效果图上盖表里的框（青 = 桌子，黄 = 别的）和图上量到的框（洋红），桌子配上的连一条线"""
    rows = bc.parse_table(args.table)
    data = json.load(open(args.boxes, encoding="utf-8"))
    im = data["images"][args.image]
    res = compare_one(rows, im, data["canvas"][1])
    base = Image.open(args.png).convert("RGB")
    if args.clean:                                    # 把干净版色块图半透明盖在效果图上（地面色那一片不盖）
        cl = Image.open(args.clean).convert("RGB")
        fl = bc.COLORS["地面"]
        R, G, B = cl.split()
        isfloor = ImageChops.darker(ImageChops.darker(R.point(lambda v: 255 if v == fl[0] else 0), G.point(lambda v: 255 if v == fl[1] else 0)),
                                    B.point(lambda v: 255 if v == fl[2] else 0))
        mask = ImageChops.invert(isfloor).point(lambda v: 140 if v else 0)
        base = Image.composite(cl, base, mask)
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    f = font(13)
    if not args.clean:
        for b in res["tables"]["bp"]:
            x0, y0, x1, y1 = b["box"]
            d.rectangle([x0, y0, x1, y1], outline=(0, 255, 255, 255), width=2)
            d.text((x0 + 3, y0 + 2), b["name"], fill=(0, 255, 255, 255), font=f)
        for r in res["items"]:
            x0, y0, x1, y1 = r["bp"]
            d.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(255, 255, 0, 255), width=2)
    for t in im["tables"]:
        d.rectangle(t, outline=(255, 0, 200, 255), width=2)
    for r in res["items"]:
        if r["drawn"]:
            d.rectangle(r["drawn"], outline=(255, 0, 200, 255), width=2)
    for k, b in im.get("extra", {}).items():
        d.rectangle(b, outline=(255, 128, 0, 255), width=2)
        d.text((b[0] + 3, b[3] - 15), "多", fill=(255, 128, 0, 255), font=f)
    for p in res["tables"]["pairs"]:
        a = ctr(res["tables"]["bp"][p["i"]]["box"]); c = ctr(im["tables"][p["j"]])
        d.line([a, c], fill=(255, 255, 255, 230), width=2)
        d.ellipse([a[0] - 3, a[1] - 3, a[0] + 3, a[1] + 3], fill=(0, 255, 255, 255))
        d.ellipse([c[0] - 3, c[1] - 3, c[0] + 3, c[1] + 3], fill=(255, 0, 200, 255))
    out = Image.alpha_composite(base.convert("RGBA"), lay).convert("RGB")
    dd = ImageDraw.Draw(out)
    dd.rectangle([0, 0, 760, 22], fill=(0, 0, 0))
    dd.text((6, 3), f"图 {args.image}：" + ("半透明色块 = 干净版" if args.clean else "青/黄 = 表里的框") + "；洋红 = 图上量到的；橙 = 表里没有的；白线 = 桌子配对（表里中心→图上中心）", fill=(255, 255, 255), font=f)
    out.save(args.out, quality=88)
    print("存了", args.out)


def main():
    ap = argparse.ArgumentParser(description="效果图对色块图")
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("detect")
    d.add_argument("--png", required=True); d.add_argument("--out"); d.add_argument("--json")
    d.set_defaults(fn=cmd_detect)
    c = sub.add_parser("compare")
    c.add_argument("--boxes", required=True); c.add_argument("--table", required=True)
    c.add_argument("--md"); c.add_argument("--json-out", dest="json_out"); c.set_defaults(fn=cmd_compare)
    o = sub.add_parser("overlay")
    o.add_argument("--boxes", required=True); o.add_argument("--table", required=True)
    o.add_argument("--image", required=True); o.add_argument("--png", required=True); o.add_argument("--out", required=True)
    o.add_argument("--clean", help="干净版色块图；给了就半透明盖在效果图上，不画表里的框")
    o.set_defaults(fn=cmd_overlay)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
