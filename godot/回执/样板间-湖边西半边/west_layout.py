# -*- coding: utf-8 -*-
"""西半边的 layout_west.json、能走范围（从图上算出来）、核对图、手机图、对照图、接缝核对。draw_lake_west.py 调它。"""
import json
import math
import os

from PIL import Image, ImageDraw, ImageFilter

import draw_lake_west as D
import lake_engine as E

HERE = D.HERE
W, H = D.W, D.H
XO = D.XO
G, GM = D.G, D.GM
WALK_BOTTOM = D.WALL_Y - D.WALL_T - 6        # 墙里能走到 1023（跟东半边一样）


# ------------------------------------------------------------------ 能走的范围：从图算出来（地面 = 不是水、不在墙外；离水 8 像素；亭子只走前沿）
def rail_footprints(stands):
    """石栏杆的着地线（游戏坐标线段），从能走的范围里扣掉"""
    segs = []
    for (n, L, f) in stands:
        m = D.META.get(n, {})
        if m.get("kind") == "rail":
            segs.append(((GM(m["x0"]), m["y"] - 2), (GM(m["x1"]), m["y"] - 2)))
        elif m.get("kind") == "rail_seg":
            (ax, ay), (bx, by) = m["a"], m["b"]
            segs.append(((GM(ax), ay), (GM(bx), by)))
    return segs


def pav_strip_poly():
    """亭子里人能站的前沿：六角里缩 0.3 米、前沿往里 36 像素（头还在檐口下面露得出来）"""
    yf = D.FRONT_Y
    R = D.RP - 0.3
    hexpts = [E.scr(D.PGX + R * math.cos(math.radians(a)), D.PGY + R * math.sin(math.radians(a))) for a in (180, 240, 300, 360)]
    top = yf - 36
    poly = []
    (x180, y180), (x240, y240), (x300, y300), (x360, y360) = hexpts

    def lerp_x(xa, ya, xb, yb, y):
        return xa + (xb - xa) * (y - ya) / (yb - ya)
    poly.append((lerp_x(x180, y180, x240, y240, top), top))
    poly.append((lerp_x(x360, y360, x300, y300, top), top))
    poly.append((x300, y300))
    poly.append((x240, y240))
    return [(GM(x), int(round(y))) for x, y in poly], yf


def walk_mask(stands):
    land = Image.new("L", (W + 40, H), 0)
    px = land.load()
    for y in range(0, H):
        for gx in range(-20, W + 20):
            g = min(W - 1, max(0, gx))
            if y < D.FAR_Y + 3:
                if gx < 90 and not D.WMg(g, D.FAR_Y + 3):
                    px[gx + 20, y] = 255      # 西北角地一直接到对岸：上沿不往里缩，免得那一溜地走不到
                continue
            if not D.WMg(g, y) or gx >= W:
                px[gx + 20, y] = 255
    er = land.filter(ImageFilter.MinFilter(17)).crop((20, 0, W + 20, H))
    m = Image.new("L", (W, H), 0)
    m.paste(er, (0, 0))
    d = ImageDraw.Draw(m)
    d.rectangle([0, WALK_BOTTOM + 1, W, H], fill=0)
    d.rectangle([0, 0, W, D.FAR_Y + 2], fill=0)
    d.rectangle([0, 0, 23, H], fill=0)
    # 亭子：整块扣掉，再加前沿那条和正南的口
    hexR = [E.scr(D.PGX + (D.RP + 0.06) * math.cos(math.radians(a)), D.PGY + (D.RP + 0.06) * math.sin(math.radians(a))) for a in range(0, 360, 60)]
    d.polygon([(GM(x), y) for x, y in hexR], fill=0)
    strip, yf = pav_strip_poly()
    d.polygon(strip, fill=255)
    gx0 = GM(E.scr(D.PGX - 0.55, 0)[0])
    gx1 = GM(E.scr(D.PGX + 0.55, 0)[0])
    d.rectangle([gx0, int(yf - 10), gx1, int(yf + 12)], fill=255)
    # 码头：栈桥、平台，边上留 6 像素
    P, Hd = D.PIER, D.HEAD
    d.rectangle([GM(P[0]) + 6, Hd[3] - 8, GM(P[1]) - 7, P[3] + 4], fill=255)
    d.rectangle([GM(Hd[0]) + 6, Hd[2] + 8, GM(Hd[1]) - 7, Hd[3] - 1], fill=255)
    # 月亮门门洞（跟东头一样到墙外 38 像素）
    gc = GM(D.GATE_C[0])
    d.rectangle([gc - 40, D.WALL_Y - D.WALL_T - 10, gc + 40, D.WALL_Y + 38], fill=255)
    # 石栏杆着地线扣掉（两边各 3 像素）
    for (a, b) in rail_footprints(stands):
        d.line([a, b], fill=0, width=7)
    return m


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    (x0, y0), (x1, y1) = pts[0], pts[-1]
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    best, bi = -1, 0
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        d = abs(dy * x - dx * y + x1 * y0 - y1 * x0) / L if L else math.hypot(x - x0, y - y0)
        if d > best:
            best, bi = d, i
    if best > eps:
        a = rdp(pts[:bi + 1], eps)
        b = rdp(pts[bi:], eps)
        return a[:-1] + b
    return [pts[0], pts[-1]]


def simplify_closed(pts, eps=1.6):
    if pts[0] == pts[-1]:
        pts = pts[:-1]
    # 从最左上的点切开
    i0 = min(range(len(pts)), key=lambda i: (pts[i][0] + pts[i][1] * 0.001))
    seq = pts[i0:] + pts[:i0]
    far = max(range(len(seq)), key=lambda i: (seq[i][0] - seq[0][0]) ** 2 + (seq[i][1] - seq[0][1]) ** 2)
    a = rdp(seq[:far + 1], eps)
    b = rdp(seq[far:] + [seq[0]], eps)
    return a[:-1] + b[:-1]


def walk_polys(mask):
    # 每一块只描外圈（这里没有洞）
    comps = []
    m = mask.copy()
    raw = trace_components(m)
    for pts in raw:
        s = simplify_closed(pts, 1.6)
        comps.append([[int(x), int(y)] for x, y in s])
    return comps


def trace_components(m):
    """逐块：找最上最左的点、描外圈、再把这块抹掉，接着找下一块"""
    w, h = m.size
    out = []
    while True:
        bb = m.getbbox()
        if not bb:
            break
        px = m.load()
        start = None
        for y in range(bb[1], bb[3]):
            for x in range(bb[0], bb[2]):
                if px[x, y] > 0:
                    start = (x, y)
                    break
            if start:
                break
        pts = trace_one(m, start)
        out.append(pts)
        # 抹掉这块（洪水填充）
        ImageDraw.floodfill(m, start, 0)
    return out


def trace_one(m, s):
    w, h = m.size
    px = m.load()

    def inn(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y] > 0
    cx, cy, dx, dy = s[0], s[1], 1, 0
    start = (cx, cy, dx, dy)
    pts = [(cx, cy)]
    guard = 0
    while guard < 2000000:
        guard += 1
        nx, ny = cx + dx, cy + dy
        if (dx, dy) == (1, 0):
            al, ar = (nx, ny - 1), (nx, ny)
        elif (dx, dy) == (0, 1):
            al, ar = (nx, ny), (nx - 1, ny)
        elif (dx, dy) == (-1, 0):
            al, ar = (nx - 1, ny), (nx - 1, ny - 1)
        else:
            al, ar = (nx - 1, ny - 1), (nx, ny - 1)
        cx, cy = nx, ny
        if inn(*al):
            dx, dy = dy, -dx
            pts.append((cx, cy))
        elif inn(*ar):
            pass
        else:
            dx, dy = -dy, dx
            pts.append((cx, cy))
        if (cx, cy, dx, dy) == start:
            break
    return pts


# ------------------------------------------------------------------ 导出 layout_west.json
def export(stands, BG):
    items = []

    def art(n, L):
        return {"png": "layers/%s.png" % n, "x": L.ox + XO, "y": L.oy, "w": L.w, "h": L.h}

    for (n, L, f) in stands:
        m = D.META.get(n, {"kind": "art"})
        k = m["kind"]
        if k == "wall":
            gl, gr = D.GATE_C[0] - D.GATE_R - 8, D.GATE_C[0] + D.GATE_R + 8
            items.append({"type": "box", "id": "wall_s_w1", "rect": [0, D.WALL_Y - D.WALL_T - 1, GM(gl), D.WALL_Y], "h": 100,
                          "top": "#5a5f68", "front": "#f2efe6", "scale": {"h_m": 2.1, "name": "白墙灰瓦"}, "part": "LK-W01",
                          "art": art(n, L), "note": "白墙、西头月亮门、花窗、红绸红灯笼是一张图（wall_gate_w.png），着地线 1040"})
            items.append({"type": "box", "id": "wall_s_w2", "rect": [GM(gr), D.WALL_Y - D.WALL_T - 1, W, D.WALL_Y], "h": 100,
                          "top": "#5a5f68", "front": "#f2efe6", "part": "LK-W01"})
            items.append({"type": "beam", "id": "moongate_w", "x0": GM(gl), "x1": GM(gr), "top": D.WALL_TOP - 40, "thick": 40,
                          "foot": D.WALL_Y + 1, "color": "#f2efe6", "scale": {"w_m": 2.4, "name": "西头月亮门（门洞直径 2.4 米，人能过，以后通果园 A）"},
                          "part": "LK-W02"})
        elif k == "box":
            r = m["rect"]
            it = {"type": "box", "id": n, "rect": [GM(r[0]), r[1], GM(r[2]), r[3]], "h": m["h"], "top": "#9aa0a8",
                  "front": "#7a8088", "scale": {"name": m.get("name", n)}, "art": art(n, L), "foot": f}
            if m.get("block") is False:
                it["block"] = False
            if m.get("boat"):
                it["note"] = "泊在码头边的船（在水上，不挡路；以后坐船的玩法从码头点进）"
            items.append(it)
        elif k == "cyl":
            it = {"type": "cyl", "id": n, "x": GM(m["x"]), "y": m["y"], "rx": m["rx"], "ry": m["ry"], "h": m["h"],
                  "foot": f, "top": "#6a9a5c", "front": "#3f6a3f", "scale": {"name": m.get("name", n)}, "art": art(n, L)}
            if m.get("water"):
                it["note"] = "在水上（本来就走不到）"
            items.append(it)
        elif k == "tree":
            it = {"type": "tree", "id": n, "x": GM(m["x"]), "y": m["y"], "h": m["h"], "w": m["w"], "trunk": "#6d4a38",
                  "leaf": "#4f7a4a", "leaf2": "#6a9a5c", "scale": {"name": m.get("name", n)}, "art": art(n, L)}
            if m.get("droop"):
                it["droop"] = True
            if m.get("outside"):
                it["note"] = "在南墙外面（不能走的地方），只是景"
            items.append(it)
        elif k == "bench":
            x0, x1, foot = D.BENCH_W
            items.append({"type": "beam", "id": "bench_w_seat", "x0": GM(x0), "x1": GM(x1), "top": foot - 24, "thick": 8, "foot": foot,
                          "color": "#d2985d", "scale": {"w_m": 1.5, "name": "长凳（面朝湖）"}, "part": "LK-P03", "art": art(n, L)})
            items.append({"type": "box", "id": "bench_w_leg_w", "rect": [GM(x0), foot - 8, GM(x0 + 6), foot], "h": 22,
                          "top": "#34303d", "front": "#201c26", "block": False, "part": "LK-P03"})
            items.append({"type": "box", "id": "bench_w_leg_e", "rect": [GM(x1 - 6), foot - 8, GM(x1), foot], "h": 22,
                          "top": "#34303d", "front": "#201c26", "block": False, "part": "LK-P03"})
            items.append({"type": "poly", "id": "bench_w_block", "pts": [[GM(x0), foot - 24], [GM(x1), foot - 24], [GM(x1), foot], [GM(x0), foot]],
                          "foot": foot - 24, "color": "#00000000", "block": [GM(x0), foot - 24, GM(x1), foot], "part": "LK-P03"})
        elif k == "rail":
            items.append({"type": "box", "id": n, "rect": [GM(m["x0"]), m["y"] - 6, GM(m["x1"]), m["y"]], "h": 36, "top": "#d3d8e3",
                          "front": "#a3abbe", "scale": {"h_m": 0.75, "name": m["name"]}, "art": art(n, L), "foot": f,
                          "note": "沿近岸的石栏杆（在能走范围北边沿上，挡人）"})
        elif k == "rail_seg":
            (ax, ay), (bx, by) = m["a"], m["b"]
            items.append({"type": "poly", "id": n, "pts": [[GM(ax), ay], [GM(bx), by], [GM(bx), by + 3], [GM(ax), ay + 3]], "foot": f,
                          "color": "#00000000", "art": art(n, L),
                          "note": "半岛东沿的石栏杆（斜的一段；能走范围已经让开它的着地线，这条不再挡）"})
        else:
            items.append({"type": "poly", "id": n, "pts": [[L.ox + XO, L.oy], [L.ox + L.w + XO, L.oy], [L.ox + L.w + XO, L.oy + L.h],
                                                          [L.ox + XO, L.oy + L.h]], "foot": f, "color": "#00000000", "art": art(n, L),
                          "note": "只是图，不挡路（能走的范围在 walk 里已经让开了）"})
    for ang in (120, 60, 180, 0, 240, 300):
        bx, by = D.pav(D.RC, ang, 0)
        bx, by = int(round(bx)), int(round(by))
        items.append({"type": "box", "id": "pavw_post_%d" % ang, "rect": [GM(bx - 6), by - 6, GM(bx + 7), by + 1], "h": 120,
                      "top": "#b1332a", "front": "#8a2321", "scale": {"h_m": 2.5, "name": "亭柱"}, "part": "LK-P01",
                      "clear": 4, "note": "画在 pavilion_w_front / pavilion_w_back 里，这条只管挡路"})
    mask = walk_mask(stands)
    mask.save(os.path.join(HERE, "_walk_mask.png"))
    walk = walk_polys(mask)
    yf = D.FRONT_Y
    head_cx = GM((D.HEAD[0] + D.HEAD[1]) // 2)
    bx0, bx1, bfoot = D.BENCH_W
    bcx = GM((bx0 + bx1) // 2)
    gc = GM(D.GATE_C[0])
    npcs = [
        {"id": "boatman_1", "who": "船夫", "x": head_cx, "y": D.HEAD[2] + 30, "face": "down", "look": "boatman", "lm": "LM-BOATMAN-01",
         "note": "站在码头平台上（栈桥头那块横的木台），船在他两边泊着"},
        {"id": "fisher_1", "who": "钓鱼的人", "x": GM(D.FISH[0][0]), "y": D.FISH[0][1], "face": "up", "look": "fisher_1", "sit": True,
         "lm": "LM-FISHER-01", "note": "坐在小方凳上（fishing_1.png），鱼竿架在丫杈上"},
        {"id": "fisher_2", "who": "钓鱼的人", "x": GM(D.FISH[1][0]), "y": D.FISH[1][1], "face": "up", "look": "fisher_2", "sit": True,
         "lm": "LM-FISHER-02", "note": "坐在小方凳上（fishing_2.png）"},
    ]
    d = {
        "scene": "scene_luoman_lake",
        "title": "湖边（西半边）",
        "note": "罗曼山庄 · 湖边西头（照阿鱼 10/3 左右翻转的效果图 1：小半岛亭子、游船码头、湖尽头；画法跟东半边一套）。draw_lake_west.py 生成，别手改。"
                "这张是 3072×1280 长湖岸的左半边（x 0～1536），坐标就是游戏画布坐标（不用加偏移）；东半边照旧用 layout_east.json。"
                "格式照东半边 layout_east.json：items 是 box / cyl / tree / beam / poly，每件多一个 art（layers/ 里的图和它左上角）。"
                "base 是地面底图（天、远山、湖、倒影、草地、石板路、亭子石台、码头木台、影子都在里面）；立着的东西按 foot 跟人排前后。"
                "walk 是从图上算出来的：凡是地面（草、石板、木台）都能走，离水边留 8 像素；亭子顶不透明，人只走前沿那条；"
                "码头栈桥和平台能走；南墙西头月亮门门洞能走，往南以后通果园 A（原来通停车场的不要了）。",
        "size": [3072, 1280],
        "covers": [0, 0, W, H],
        "person_px": {"near_y": 1024, "near_h": 84, "far_y": 0, "far_h": 84},
        "base": {"png": "layers/bg_lake_west.png", "x": 0, "y": 0},
        "from_orchard": [gc, D.WALL_Y - D.WALL_T - 30],
        "bench_seat_w": [bcx, bfoot - 12],
        "bench_stand_w": [bcx, bfoot + 20],
        "points": [
            {"id": "dock", "x": head_cx, "y": D.HEAD[3] + 14, "r": 50, "note": "游船码头：栈桥头上，跟船夫搭话（坐船玩法从这儿进）"},
            {"id": "pavilion_w", "x": GM(D.PCX), "y": int(yf - 14), "r": 50, "note": "半岛亭子前沿（正南口进去那条）"},
            {"id": "bench_w", "x": bcx, "y": bfoot + 18, "r": 50, "note": "西半边湖边的长凳（往东小路北沿、面朝湖，跟东头那张对着）"},
            {"id": "to_orchard", "x": gc, "y": D.WALL_Y + 26, "r": 36, "to": "待定",
             "note": "南墙西头月亮门，以后通果园 A（原来灰盒的 to_parking 不要了；接到哪个场景待 01 定）"},
            {"id": "lake_end", "x": GM(D.TERRACE[0]), "y": D.TERRACE[1], "r": 40, "note": "湖尽头看湖的小石台（没有玩法，景点；要不要做玩法点 01 定）"},
        ],
        "walk": walk,
        "flat": [
            {"type": "rect", "rect": [0, D.FAR_Y, W, 786], "color": "#385a90", "note": "湖（实际岸线是弯的，画在底图里）"},
            {"type": "rect", "rect": [GM(D.PLAZA[0]), D.PLAZA[2], GM(D.PLAZA[1]), D.PLAZA[3]], "color": "#a3abbe"},
            {"type": "rect", "rect": [GM(D.PATH_S[0]), D.PATH_S[2], GM(D.PATH_S[1]), D.WALL_Y + 40], "color": "#a3abbe"},
            {"type": "rect", "rect": [GM(D.PIER[0]), D.PIER[2], GM(D.PIER[1]), D.PIER[3]], "color": "#d2985d", "note": "栈桥"},
            {"type": "rect", "rect": [GM(D.HEAD[0]), D.HEAD[2], GM(D.HEAD[1]), D.HEAD[3]], "color": "#d2985d", "note": "码头平台"},
        ],
        "items": items,
        "npcs": npcs,
        "not_drawn": ["灰盒西半边的 reed_1（x 116）那里现在是湖尽头的岸上，芦苇挪到了水边几处", "灰盒的 to_parking / from_parking 改成 to_orchard / from_orchard（通果园 A）",
                      "灰盒西半边的 rail_0（x 0～492）没画：那一段现在是半岛和湖湾，岸边改成草岸 + 石头岸壁"],
    }
    with open(os.path.join(HERE, "layout_west.json"), "w", encoding="utf-8") as fh:
        json.dump(d, fh, ensure_ascii=False, indent=1)
    return d


# ------------------------------------------------------------------ 核对图、手机图、对照、接缝、能走核对
def blockers(lay):
    b = Image.new("L", (2 * W, H), 0)
    g = ImageDraw.Draw(b)
    for it in lay["items"]:
        t = it["type"]
        if t == "box" and it.get("block", True):
            r = it["rect"]
            g.rectangle([r[0], r[1], r[2] - 1, r[3] - 1], fill=255)
        elif t == "cyl":
            g.ellipse([it["x"] - it["rx"], it["y"] - it["ry"], it["x"] + it["rx"], it["y"] + it["ry"]], fill=255)
        elif t == "tree":
            g.ellipse([it["x"] - 14, it["y"] - 8, it["x"] + 14, it["y"] + 8], fill=255)
        elif t == "poly" and isinstance(it.get("block"), list):
            bb = it["block"]
            g.rectangle([bb[0], bb[1], bb[2] - 1, bb[3] - 1], fill=255)
    return b


def draw_check(full, lays, path, crop=None):
    base = full.copy()
    ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(ov)
    for li, d in enumerate(lays):
        wc = (60, 220, 90, 70) if li == 0 else (60, 160, 255, 60)
        wo = (40, 255, 80, 255) if li == 0 else (60, 160, 255, 255)
        for poly in d["walk"]:
            g.polygon([tuple(p) for p in poly], fill=wc, outline=wo)
        for it in d["items"]:
            t = it["type"]
            if t == "box" and it.get("block", True):
                r = it["rect"]
                g.rectangle([r[0], r[1], r[2], r[3]], outline=(255, 40, 40, 255), fill=(255, 40, 40, 90))
            elif t == "cyl":
                g.ellipse([it["x"] - it["rx"], it["y"] - it["ry"], it["x"] + it["rx"], it["y"] + it["ry"]], outline=(255, 60, 60, 255))
            elif t == "tree":
                g.ellipse([it["x"] - 14, it["y"] - 8, it["x"] + 14, it["y"] + 8], outline=(255, 60, 60, 255), fill=(255, 40, 40, 90))
            elif t == "poly" and isinstance(it.get("block"), list):
                bb = it["block"]
                g.rectangle([bb[0], bb[1], bb[2], bb[3]], outline=(255, 40, 40, 255), fill=(255, 40, 40, 90))
        for p in d["points"]:
            g.ellipse([p["x"] - p["r"], p["y"] - p["r"], p["x"] + p["r"], p["y"] + p["r"]], outline=(255, 230, 0, 255), width=2)
        for n in d["npcs"]:
            g.ellipse([n["x"] - 4, n["y"] - 4, n["x"] + 4, n["y"] + 4], fill=(40, 120, 255, 255))
        for k in ("spawn", "from_orchard", "bench_seat", "bench_stand", "bench_seat_w", "bench_stand_w"):
            if k in d:
                x, y = d[k]
                g.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 255, 255, 255))
    g.line([(W, 0), (W, H)], fill=(255, 0, 255, 160), width=1)
    base.alpha_composite(ov)
    if crop:
        base = base.crop(crop)
    base.save(path)


def walk_report(lay, lay_e, BGim, full=None, cover=None):
    """看着是地面的（草、石板、木台）是不是都在能走范围里；从门里能不能走到每个玩法点"""
    mask = Image.new("L", (2 * W, H), 0)
    g = ImageDraw.Draw(mask)
    for d in (lay, lay_e):
        for poly in d["walk"]:
            g.polygon([tuple(p) for p in poly], fill=255)
    mp = mask.load()
    bl = blockers(lay)
    blp = bl.load()
    bg = BGim.load()
    ground_names = set(["gr0", "gr1", "gr2", "gA", "gr3", "gB", "gr4", "gC", "sv0", "sv1", "sv2", "ik3", "wt", "hw0", "hw1", "hw2", "hw3", "hw4", "hw5", "hw6",
                        "pk", "pk2", "pk0", "gd3", "gd4"])
    gcols = set(E.C[n] for n in ground_names)
    fl = full.load() if full is not None else None
    cv = cover.load() if cover is not None else None
    tot = miss = 0
    gap = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gp = gap.load()
    near_water = Image.new("L", (W, H), 0)
    nw = near_water.load()
    for y in range(D.FAR_Y + 3, H):
        for x in range(W):
            if D.WMg(x, y):
                nw[x, y] = 255
    near_water = near_water.filter(ImageFilter.MaxFilter(21))
    nw = near_water.load()
    for y in range(D.FAR_Y + 3, WALK_BOTTOM + 1):
        for x in range(24, W):
            c = bg[x, y]
            if c not in gcols or D.WMg(x, y) or D.is_water(G(x), y):
                continue
            if (fl is not None and fl[x, y] != c) or (cv is not None and cv[x, y]):
                continue                      # 被树冠、墙、栏杆这些立着的东西盖住了，看不见这块地
            gxx, gyy = E.gnd(G(x), y)
            if D.in_hex(gxx, gyy, D.RP + 0.1):
                continue
            tot += 1
            if mp[x, y] == 0:
                if nw[x, y] or blp[x, y]:
                    continue
                miss += 1
                gp[x, y] = (255, 0, 255, 255)
    # 走得到：从西头月亮门里边洪水填充（能走 − 挡路）
    free = Image.new("L", (2 * W, H), 0)
    fp = free.load()
    for y in range(H):
        for x in range(2 * W):
            if mp[x, y] and not blp[x, y]:
                fp[x, y] = 255
    sx, sy = lay["from_orchard"]
    ImageDraw.floodfill(free, (sx, sy), 128)
    fp = free.load()
    targets = {"码头（船夫跟前）": (lay["points"][0]["x"], lay["points"][0]["y"]), "亭子前沿": (lay["points"][1]["x"], lay["points"][1]["y"]),
               "长凳站点": tuple(lay["bench_stand_w"]), "月亮门外（去果园 A）": (lay["points"][3]["x"], lay["points"][3]["y"] - 4),
               "湖尽头小石台": (lay["points"][4]["x"], lay["points"][4]["y"]), "钓鱼位 1 旁边": (lay["npcs"][1]["x"] + 24, lay["npcs"][1]["y"] + 24),
               "钓鱼位 2 旁边": (lay["npcs"][2]["x"] + 24, lay["npcs"][2]["y"] + 24), "接缝往东（东半边小路）": (W + 40, 838),
               "东头月亮门里（东半边 spawn）": tuple(lay_e["spawn"])}
    reach = {}
    for k, (x, y) in targets.items():
        ok = False
        for dy in range(-6, 7, 2):
            for dx in range(-6, 7, 2):
                xx, yy = int(x + dx), int(y + dy)
                if 0 <= xx < 2 * W and 0 <= yy < H and fp[xx, yy] == 128:
                    ok = True
        reach[k] = ok
    gap.save(os.path.join(HERE, "_walk_gaps.png"))
    # 接缝：x 1535 / 1536 两列能走的行是不是一样
    seam_rows_w = [y for y in range(H) if mp[W - 1, y]]
    seam_rows_e = [y for y in range(H) if mp[W, y]]
    return {"ground_px": tot, "ground_not_walk": miss, "reach": reach,
            "seam_walk_w": (min(seam_rows_w), max(seam_rows_w)) if seam_rows_w else None,
            "seam_walk_e": (min(seam_rows_e), max(seam_rows_e)) if seam_rows_e else None}


def seam_report(bg_w, bg_e, full):
    """接缝：西底图最东一列跟东底图最西一列逐行比，同一种材料（色带）算接上"""
    pw, pe = bg_w.load(), bg_e.load()
    same_col = same_ramp = 0
    bad = []
    for y in range(H):
        a, b = pw[W - 1, y], pe[0, y]
        if a == b:
            same_col += 1
        ra = E.RAMP_OF.get(a, ("?", 0))[0]
        rb = E.RAMP_OF.get(b, ("?", 0))[0]
        if ra == rb or a == b:
            same_ramp += 1
        else:
            bad.append(y)
    # 连成段报
    segs = []
    for y in bad:
        if segs and y == segs[-1][1] + 1:
            segs[-1][1] = y
        else:
            segs.append([y, y])
    # 第二道：两列各自跟自己隔壁那列比（缝两边的差异 vs 平常相邻两列的差异）
    def coldiff(img, xa, xb):
        p = img.load()
        return sum(1 for y in range(H) if p[xa, y] != p[xb, y])
    f = full
    return {"same_color_rows": same_col, "same_ramp_rows": same_ramp, "bad_segments": segs,
            "diff_seam": coldiff(f, W - 1, W), "diff_w_inner": coldiff(f, W - 2, W - 1), "diff_e_inner": coldiff(f, W, W + 1),
            "diff_w_inner2": coldiff(f, W - 30, W - 29), "diff_e_inner2": coldiff(f, W + 30, W + 31)}


def make_views(BG, stands, bg_e, stands_e, full, lay, compose_full):
    guest = E.guest
    # 手机竖屏 540×960，人站在里面当尺子
    views = [
        ("lake_west_phone_dock.png", (638, 150, 1178, 1110), [(guest(5), 908, 708), (guest(3), 760, 872), (guest(2), 908, 588)]),
        ("lake_west_phone_pavilion.png", (286, 130, 826, 1090), [(guest(1), 556, 598), (guest(4), 606, 770), (guest(6), 452, 880)]),
        ("lake_west_phone_gate.png", (498, 310, 1038, 1270), [(guest(5), 768, 1006), (guest(2), 768, 1150), (guest(3), 900, 868)]),
        ("lake_west_phone_seam.png", (1266, 150, 1806, 1110), [(guest(4), 1500, 840), (guest(1), 1580, 846), (guest(6), 1336, 834)]),
        ("lake_west_phone_lakeend.png", (0, 150, 540, 1110), [(guest(3), 62, 500), (guest(5), 150, 724), (guest(1), 300, 860)]),
        ("_check_pav_back.png", (386, 380, 726, 700), [(guest(2), 556, 579), (guest(4), 512, 592), (guest(1), 604, 592), (guest(6), 556, 640)]),
    ]
    for (fn, box, people) in views:
        im = compose_full(BG.im, stands, bg_e, stands_e, people).crop(box)
        im.save(os.path.join(HERE, fn))
    # 并排：西半边 | 翻转的效果图 1
    ref = Image.open(D.REF1).convert("RGBA")
    rw = int(ref.width * 960 / ref.height)
    ref_s = ref.resize((rw, 960), Image.LANCZOS)
    west = full.crop((0, 0, W, H)).resize((int(W * 960 / H), 960), Image.LANCZOS)
    vs = Image.new("RGBA", (west.width + 16 + rw, 960), (34, 20, 15, 255))
    vs.paste(west, (0, 0))
    vs.paste(ref_s, (west.width + 16, 0))
    vs.save(os.path.join(HERE, "lake_vs.png"))
    # 核对图（西半边 + 缝东边 260 像素，东半边的 walk 用蓝色画）
    lay_e = json.load(open(os.path.join(D.EAST_DIR, "layout_east.json"), encoding="utf-8"))
    draw_check(full, [lay, lay_e], os.path.join(HERE, "layout_west_check.png"), crop=(0, 0, W + 260, H))
    # 接缝放大（缝两边各 80 像素，放大 3 倍）
    z = full.crop((W - 80, 0, W + 80, H)).resize((480, H * 3), Image.NEAREST)
    z.save(os.path.join(HERE, "_seam_zoom.png"))
    sr = seam_report(BG.im, bg_e, full)
    cover = Image.new("L", (2 * W, H), 0)
    for (n, L, f) in stands + stands_e:
        a = L.im.split()[3]
        cover.paste(255, (L.ox + XO, L.oy), a)
    wr = walk_report(lay, lay_e, BG.im, full, cover)
    rep = {"seam": sr, "walk": wr}
    with open(os.path.join(HERE, "_report.json"), "w", encoding="utf-8") as fh:
        json.dump(rep, fh, ensure_ascii=False, indent=1)
    print("接缝：", json.dumps(sr, ensure_ascii=False))
    print("能走：", json.dumps(wr, ensure_ascii=False))
