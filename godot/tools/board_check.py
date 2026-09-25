#!/usr/bin/env python3
"""摆位底图（纯色块）核对：从干净版 png 上按颜色量东西，再和摆位表、手机屏对。只用 PIL，不靠 numpy。

用途：02 把大厅按比例尺用色块排好（比如 55 桌摆位底图），GPT 照它画，02 照它还原——数一定要对。
03 拿这个脚本从图上量，不抄 02 的表，再和表对一遍。

摆位表的格式（v3 起）：| 名字 | x | y | 宽 | 高 | 占地（x, y, 宽×高（落地线 N）／同框（平的）） | 依据 |
  x／y／宽／高是「画出来在画面上占的框」（色块画的就是它），占地是地上占的地（走路判定用）。北边那张表多一列「被切」。

四个子命令：
  diff   摆位表里每一件，按名字找到图上同色的那一块（离表里中心最近的），比 x／y／宽／高；差超过 2 像素的列出来，
         再检查「占地」列（落地线 = 框下沿？占地在框里？）；给了 --annot 就到标注版里找洋红的落地线；另外列 20 件抽样
    python3 godot/tools/board_check.py diff  --png 底图.png --table 摆位表.md [--annot 标注.png]
  walk   走道：画面上（按图上的框）和地上（按表里的占地）行间、列间、横走道、红毯两边最窄多宽；行与行之间画面上
         露出的地面最窄多少（连地毯／不连）；再用「人宽 43 的圆」从进门那块空地走，看每张桌能不能走到、路上最窄一段多宽
         （按占地算，再按画面上的框算一遍）。--fig 存一张走道图（绿 = 人能站；橙 = 空着但太窄）
    python3 godot/tools/board_check.py walk  --png 底图.png [--table 摆位表.md] [--fig 走道图.jpg]
  north  北边那三样（GPT 用的）和整厅比：干净版逐像素比整厅 y 0～1024 那块、有没有字、标注版、表逐行
    python3 godot/tools/board_check.py north --png 整厅.png --north 北-干净.png [--annot 整厅标注.png --north-annot 北-标注.png]
                                             [--table 整厅表.md --north-table 北-表.md]
  phone  手机屏：是不是画布 0.9375 倍的裁剪（一屏 576×1024）；顶上 140 那条里有什么；台子在不在屏里；--middle 是有人的那张
    python3 godot/tools/board_check.py phone --png 底图.png --door 进门.png --stage 舞台.png [--middle 中间.png] [--fig 核对图.jpg]

颜色（COLORS）是 02 的 make_board55.py 用的色；02 换色了，改这里。表里名字到颜色的对应在 color_of()。
v3 加的两种：琴凳和大提琴手的椅子（80,50,30）、谱架（60,60,60）；桌子后排椅背用的还是桌一圈那个深棕。
"""
import argparse
import heapq
import math
import re
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

PERSON_W = 43          # 一人宽（ASSETS 表里的人宽），走道窄过它就是过不去
ZOOM = 0.9375          # 手机屏镜头：屏高 960 ÷ 画布 1024
MAGENTA = (255, 0, 200)   # 标注版里落地线的颜色
COLORS = {
    "地面": (239, 227, 207), "墙": (92, 52, 36), "墙顶横梁": (60, 32, 22), "帐幔": (170, 40, 40), "挂灯": (240, 170, 60),
    "花拱": (70, 130, 70), "囍": (215, 170, 60), "横幅": (150, 30, 30), "台面": (200, 60, 55), "台口立面": (150, 40, 38),
    "台阶": (175, 50, 46), "LED": (20, 10, 8), "脚印": (255, 255, 255), "红毯": (179, 32, 42), "落地宫灯": (240, 200, 60),
    "花盆": (90, 170, 90), "壁边灯柱": (230, 170, 60), "乐队地台": (120, 40, 50), "钢琴": (30, 30, 30), "坐乐手": (70, 60, 110),
    "站乐手": (110, 70, 140), "大提琴": (140, 80, 40), "贺礼堆": (230, 120, 120), "长凳": (120, 200, 255),
    "桌一圈": (90, 50, 25), "桌面": (220, 70, 60), "主桌桌面": (240, 190, 60), "地毯": (150, 70, 40), "主桌地毯": (200, 150, 40),
    "栏杆": (120, 80, 50), "门": (60, 140, 200), "人": (20, 20, 20),
    "凳椅": (80, 50, 30), "谱架": (60, 60, 60),
}
# 「看着挡路」的颜色（红毯、地毯、地面、门、人的尺子不挡）
BLOCKERS = ["墙", "墙顶横梁", "帐幔", "挂灯", "花拱", "囍", "横幅", "台面", "台口立面", "台阶", "LED", "脚印", "落地宫灯", "花盆",
            "壁边灯柱", "乐队地台", "钢琴", "坐乐手", "站乐手", "大提琴", "贺礼堆", "长凳", "桌一圈", "桌面", "主桌桌面", "栏杆",
            "凳椅", "谱架"]


# ---------------- 切块 ----------------
def mask_of(chans, c):
    r, g, b = c
    R, G, B = chans
    return ImageChops.darker(ImageChops.darker(R.point(lambda v: 255 if v == r else 0), G.point(lambda v: 255 if v == g else 0)),
                             B.point(lambda v: 255 if v == b else 0))


def components(mask):
    """8 连通块：[(x0, y0, x1, y1, 面积)]，x1、y1 含最后一个像素；按 (y0, x0) 排"""
    W, H = mask.size
    data = mask.tobytes()
    parent = {}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    pat = re.compile(b"\xff+")
    prev, allr, nid = [], [], 0
    for y in range(H):
        row = data[y * W:(y + 1) * W]
        cur = []
        for m in pat.finditer(row):
            a, b = m.start(), m.end() - 1
            parent[nid] = nid
            cur.append((a, b, nid))
            allr.append((a, b, y, nid))
            nid += 1
        for (a, b, k) in cur:
            for (pa, pb, pk) in prev:
                if pa <= b + 1 and pb >= a - 1:
                    ra, rb = find(k), find(pk)
                    if ra != rb:
                        parent[rb] = ra
        prev = cur
    comps = {}
    for (a, b, y, k) in allr:
        r = find(k)
        c = comps.get(r)
        if c is None:
            comps[r] = [a, y, b, y, b - a + 1]
        else:
            c[0] = min(c[0], a); c[1] = min(c[1], y); c[2] = max(c[2], b); c[3] = max(c[3], y); c[4] += b - a + 1
    return sorted((tuple(v) for v in comps.values()), key=lambda t: (t[1], t[0]))


def load(png):
    im = Image.open(png).convert("RGB")
    chans = im.split()
    comps = {}
    for name, c in COLORS.items():
        comps[name] = components(mask_of(chans, c))
    return im, chans, comps


def wh(t):
    return (t[0], t[1], t[2] - t[0] + 1, t[3] - t[1] + 1)


# ---------------- 摆位表 ----------------
FOOT_RE = re.compile(r"(-?\d+),\s*(-?\d+),\s*(\d+)×(\d+)（落地线\s*(-?\d+)）")


def parse_table(path):
    """摆位表 -> [{name, x, y, w, h, foot(x,y,w,h), ground, flat, cut, basis}]；老格式（没有占地列）foot 为 None"""
    rows = []
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 6 or not re.fullmatch(r"-?\d+", cells[1]) or not re.fullmatch(r"-?\d+", cells[2]):
            continue
        r = {"name": cells[0], "x": int(cells[1]), "y": int(cells[2]), "w": int(cells[3]), "h": int(cells[4]),
             "foot": None, "ground": None, "flat": False, "cut": "", "basis": ""}
        m = FOOT_RE.search(cells[5])
        if m:
            r["foot"] = tuple(int(m.group(i)) for i in range(1, 5))
            r["ground"] = int(m.group(5))
            rest = cells[6:]
        elif cells[5].startswith("同框"):
            r["foot"] = (r["x"], r["y"], r["w"], r["h"])
            r["flat"] = True
            rest = cells[6:]
        else:
            rest = cells[5:]
        if len(rest) >= 2:
            r["cut"], r["basis"] = rest[0], rest[1]
        elif rest:
            r["basis"] = rest[0]
        rows.append(r)
    return rows


def color_of(name):
    """摆位表里的名字 -> COLORS 里的名字（找不到返回 None：墙、进门站的地方这类没有独立颜色的）"""
    if name.startswith("帐幔"): return "帐幔"
    if name.startswith("挂灯"): return "挂灯"
    if name == "墙顶横梁": return "墙顶横梁"
    if name == "花拱": return "花拱"
    if name == "囍字圆牌": return "囍"
    if name == "横幅": return "横幅"
    if name == "婚礼台（台面）": return "台面"
    if name == "婚礼台（台口立面）": return "台口立面"
    if name.startswith("台阶"): return "台阶"
    if name == "LED 屏": return "LED"
    if name.startswith("新人站位"): return "脚印"
    if name == "红毯": return "红毯"
    if "落地宫灯" in name: return "落地宫灯"
    if name.startswith("花盆"): return "花盆"
    if "壁边灯柱" in name: return "壁边灯柱"
    if name == "乐队地台": return "乐队地台"
    if name == "三角钢琴": return "钢琴"
    if name in ("钢琴手（坐）", "大提琴手（坐）"): return "坐乐手"
    if name in ("琴凳", "大提琴手的椅子"): return "凳椅"
    if name.startswith("谱架"): return "谱架"
    if name == "大提琴": return "大提琴"
    if name.startswith("小提琴手"): return "站乐手"
    if name == "贺礼堆": return "贺礼堆"
    if name == "长凳": return "长凳"
    if name == "主桌 地毯": return "主桌地毯"
    if name.endswith(" 地毯"): return "地毯"
    if name == "主桌" or re.fullmatch(r"T\d+", name): return "桌一圈"
    if name == "大门（双开门门洞）" or name.startswith("东侧门"): return "门"
    if "栏杆" in name: return "栏杆"
    if name.startswith("尺子：人"): return "人"
    return None


SAMPLE = ["T1", "主桌", "T27", "T54", "T1 地毯", "主桌 地毯", "婚礼台（台面）", "台阶（西）", "LED 屏", "横幅", "囍字圆牌", "花拱", "红毯",
          "大门（双开门门洞）", "东侧门（门洞）", "南边东段栏杆", "三角钢琴", "乐队地台", "贺礼堆", "长凳"]


# ---------------- diff：表 对 图 ----------------
def cmd_diff(args):
    im, chans, comps = load(args.png)
    W, H = im.size
    rows = parse_table(args.table)
    res, skipped = [], []
    for r in rows:
        cn = color_of(r["name"])
        if cn is None or not comps.get(cn):
            skipped.append(r["name"])
            continue
        t = (r["x"], r["y"], r["w"], r["h"])
        cx, cy = t[0] + t[2] / 2.0, t[1] + t[3] / 2.0
        best = min((wh(c) for c in comps[cn]), key=lambda b: (b[0] + b[2] / 2.0 - cx) ** 2 + (b[1] + b[3] / 2.0 - cy) ** 2)
        res.append((r["name"], t, best, r))
    print("摆位表 %d 件（画布 %d×%d）；能按颜色在图上找到的 %d 件；没有独立颜色 %d 件：%s" % (len(rows), W, H, len(res), len(skipped), "、".join(skipped)))
    from collections import Counter
    cnt = Counter((b[2] - t[2], b[3] - t[3]) for (_, t, b, _) in res if abs(b[0] - t[0]) <= 1 and abs(b[1] - t[1]) <= 1)
    print("位置差 ≤1 的里，宽／高差的分布（图上量到 − 表里）：" + "；".join("%+d／%+d：%d 件" % (k[0], k[1], v) for k, v in sorted(cnt.items())))
    bad = []
    for (name, t, b, r) in res:
        d = (b[0] - t[0], b[1] - t[1], b[2] - t[2], b[3] - t[3])
        if max(abs(v) for v in d) > 2:
            bad.append((name, t, b, d))
    print("\n表和图差超过 2 像素的（框，%d 件）：" % len(bad))
    for (name, t, b, d) in bad:
        print("  %s：表里 x%d y%d 宽%d 高%d；图上 x%d y%d 宽%d 高%d；差 %+d／%+d／%+d／%+d" % ((name,) + t + b + d))
    for r in rows:
        if r["x"] + r["w"] > W or r["y"] + r["h"] > H:
            print("  %s 在画布外：x%d～%d、y%d～%d（画布 %d×%d）" % (r["name"], r["x"], r["x"] + r["w"], r["y"], r["y"] + r["h"], W, H))
    # ---- 占地列 ----
    stand = [r for r in rows if r["foot"] and not r["flat"]]
    flat = [r for r in rows if r["flat"]]
    print("\n占地列：立着的 %d 件、平的（占地就是框）%d 件、没有占地列 %d 件" % (len(stand), len(flat), len([r for r in rows if r["foot"] is None])))
    problems = []
    for r in stand:
        fx, fy, fw, fh = r["foot"]
        g = r["ground"]
        fb = r["y"] + r["h"]
        if g != fy + fh:
            problems.append((r["name"], "落地线 %d ≠ 占地下沿 %d" % (g, fy + fh)))
        if fx < r["x"] or fx + fw > r["x"] + r["w"]:
            problems.append((r["name"], "占地 x %d～%d 不在框 x %d～%d 里" % (fx, fx + fw, r["x"], r["x"] + r["w"])))
        if fh > r["h"]:
            problems.append((r["name"], "占地进深 %d 比框还高 %d" % (fh, r["h"])))
        if g != fb:
            problems.append((r["name"], "落地线 %d ≠ 框下沿 %d（差 %+d）" % (g, fb, g - fb)))
    print("占地和框对不上的（%d 处）：" % len(problems) + ("没有" if not problems else ""))
    for p in problems:
        print("  %s：%s" % p)
    # 立着的东西：框比占地高出来的部分，表里「依据」写的往上加多少，对得上吗
    up_bad = []
    for r in stand:
        m = re.search(r"往上(?:加|冒)[^0-9]*?(\d+)", r["basis"])
        if m and r["foot"]:
            up = r["h"] - r["foot"][3]
            if int(m.group(1)) != up and r["name"] != "婚礼台（台面）":
                up_bad.append((r["name"], int(m.group(1)), up))
    print("依据里写的「往上加／冒 N」和 框高 − 占地进深 对不上的（%d 处）：%s" % (len(up_bad), "；".join("%s 写 %d 算 %d" % u for u in up_bad) if up_bad else "没有"))
    if args.annot:
        an = Image.open(args.annot).convert("RGB")
        ap = an.load()
        aw, ah = an.size

        def near_mag(c):
            return c[0] > 240 and c[1] < 12 and 185 <= c[2] <= 210
        miss = []
        for r in stand:
            fx, fy, fw, fh = r["foot"]
            g = r["ground"]
            hit = sum(1 for x in range(fx, min(fx + fw, aw)) if any(near_mag(ap[x, yy]) for yy in (g - 1, g, g + 1) if 0 <= yy < ah))
            if hit < 0.5 * fw:
                miss.append((r["name"], g, hit, fw))
        print("标注版里找洋红落地线：立着的 %d 件里，线在表里落地线那一行、盖住占地宽一半以上的 %d 件；没找到的 %d 件%s" % (
            len(stand), len(stand) - len(miss), len(miss), ("：" + "；".join("%s 线 y%d 只找到 %d／%d 列" % m for m in miss)) if miss else ""))
    print("\n抽样 20 件（| 东西 | 摆位表框 x／y／宽／高 | 图上量到 x／y／宽／高 | 差 |）：")
    by = {r[0]: r for r in res}
    for n in SAMPLE:
        if n not in by:
            continue
        _, t, b, _ = by[n]
        print("| %s | %d／%d／%d／%d | %d／%d／%d／%d | %+d／%+d／%+d／%+d |" % ((n,) + t + b + (b[0] - t[0], b[1] - t[1], b[2] - t[2], b[3] - t[3])))


# ---------------- walk：走道 ----------------
def edt(flags, w, h):
    """精确欧氏距离变换（Felzenszwalb）：flags[y][x] 为真表示「挡路」，返回每格到最近挡路格的距离（格）"""
    INF = 1e12

    def one(f, n):
        v = [0] * n
        z = [0.0] * (n + 1)
        k = 0
        z[0] = -INF
        z[1] = INF
        for q in range(1, n):
            while True:
                s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0 * q - 2.0 * v[k])
                if s <= z[k]:
                    k -= 1
                    if k < 0:
                        k = 0; v[0] = q; z[0] = -INF; z[1] = INF
                        break
                else:
                    k += 1; v[k] = q; z[k] = s; z[k + 1] = INF
                    break
        out = [0.0] * n
        k = 0
        for q in range(n):
            while z[k + 1] < q:
                k += 1
            out[q] = (q - v[k]) ** 2 + f[v[k]]
        return out

    grid = [[0.0 if flags[y][x] else INF for x in range(w)] for y in range(h)]
    for x in range(w):
        col = one([grid[y][x] for y in range(h)], h)
        for y in range(h):
            grid[y][x] = col[y]
    for y in range(h):
        grid[y] = one(grid[y], w)
    return [[math.sqrt(v) for v in row] for row in grid]


def blocker_shape(name):
    """表里名字 -> 走路时按占地挡路的形状：'e' 椭圆、'r' 矩形、None 不挡（挂在墙上、铺在地上、门洞、台上的小东西）"""
    if name == "主桌" or re.fullmatch(r"T\d+", name):
        return "e"
    if name in ("北墙（立面）", "西墙", "东墙（北段）", "东墙（南段）"):
        return "r"
    if name.startswith(("婚礼台", "台阶", "乐队地台", "贺礼堆", "长凳")):
        return "r"
    if any(k in name for k in ("落地宫灯", "花盆", "壁边灯柱", "栏杆")):
        return "r"
    return None


def reach(blk, W, H, start, targets, S=2):
    """人宽 43 的圆从 start 出发：能到每个 target（椭圆占地 fx, fy, fw, fh）边上吗；到那儿最好走的那条路上，最窄一段多宽（像素）。
    路宽取桌边 60 像素内、本身宽 ≥60 的走道上的最好走法（站到桌边那一步离桌子近，本身就窄，不算进去）。
    返回 (走不到的 targets, [(路宽, target, 站的地方)], dist, best, small)"""
    w, h = W // S, H // S
    small = blk.filter(ImageFilter.MaxFilter(3)).resize((w, h), Image.NEAREST)   # 略偏保守：每边多算 1 像素
    sp = small.load()
    flags = [[bool(sp[x, y]) for x in range(w)] for y in range(h)]
    dist = [[v * S for v in row] for row in edt(flags, w, h)]
    r_need = PERSON_W / 2.0
    sx, sy = start[0] // S, start[1] // S
    assert dist[sy][sx] > r_need, "进门那块空地起点站不下一个人"
    best = [[-1.0] * w for _ in range(h)]
    best[sy][sx] = dist[sy][sx]
    pq = [(-best[sy][sx], sx, sy)]
    while pq:
        nb, x, y = heapq.heappop(pq)
        b = -nb
        if b < best[y][x]:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                v = min(b, dist[ny][nx])
                if v > best[ny][nx]:
                    best[ny][nx] = v
                    heapq.heappush(pq, (-v, nx, ny))
    unreach, widths = [], []
    for t in targets:
        fx, fy, fw, fh = t
        cx, cy, a, b_ = fx + fw / 2.0, fy + fh / 2.0, fw / 2.0, fh / 2.0
        pts = [(cx + a * math.cos(math.radians(i)), cy + b_ * math.sin(math.radians(i))) for i in range(0, 360, 3)]
        cand, lane = [], []
        for gy in range(int(fy - 70) // S, int(fy + fh + 70) // S + 1):
            for gx in range(int(fx - 70) // S, int(fx + fw + 70) // S + 1):
                if 0 <= gx < w and 0 <= gy < h and dist[gy][gx] >= 30:
                    px_, py_ = gx * S + S / 2.0, gy * S + S / 2.0
                    dd = min(math.hypot(px_ - ex, py_ - ey) for ex, ey in pts)
                    if dd <= 60:
                        lane.append((best[gy][gx], gx * S, gy * S))
                    if dd <= 34 and dist[gy][gx] >= r_need:
                        cand.append((best[gy][gx], gx * S, gy * S))
        if not cand or max(cand)[0] < r_need:
            unreach.append(t)
        else:
            top = max(lane) if lane else max(cand)
            widths.append((2 * top[0], t, top[1:]))
    return unreach, sorted(widths), dist, best, small


def visible_floor(im, rings, pairs_pred):
    """图上按像素扫：上一排桌画出来的最下沿，到下一排桌画出来的最上沿之间，每一列露出多少地面（连地毯 / 只算地面色）。
    pairs_pred(gap) 为真的才算（比如块内的、横走道的）。返回 (最窄连地毯, 最窄只地面, 出现的位置)"""
    px = im.load()
    ring = COLORS["桌一圈"]
    floor = COLORS["地面"]
    by_col = {}
    for r in rings:
        by_col.setdefault(r[0], []).append(r)
    best_all, best_bare = None, None
    for x0, lst in by_col.items():
        lst.sort(key=lambda r: r[1])
        for a, b in zip(lst, lst[1:]):
            if not pairs_pred(b[1] - a[3] - 1):
                continue
            for x in range(max(a[0], b[0]), min(a[2], b[2]) + 1):
                a_bot = next((y for y in range(a[3], a[1] - 1, -1) if px[x, y] == ring), None)
                b_top = next((y for y in range(b[1], b[3] + 1) if px[x, y] == ring), None)
                if a_bot is None or b_top is None or b_top <= a_bot:
                    continue
                run = range(a_bot + 1, b_top)
                tot = len(run)
                bare = sum(1 for y in run if px[x, y] == floor)
                if best_all is None or tot < best_all[0]:
                    best_all = (tot, x, a_bot + 1, b_top - 1)
                if best_bare is None or bare < best_bare[0]:
                    best_bare = (bare, x, a_bot + 1, b_top - 1)
    return best_all, best_bare


def cmd_walk(args):
    im, chans, comps = load(args.png)
    W, H = im.size
    box = lambda t: (t[0], t[1], t[2], t[3])
    rings = [box(t) for t in comps["桌一圈"]]
    rugs = [box(t) for t in comps["地毯"]] + [box(t) for t in comps["主桌地毯"]]
    carpet = box(comps["红毯"][0])
    trows = parse_table(args.table) if args.table else []
    print("画布 %d×%d；桌 %d 张（画出来的框 %s）；地毯 %d 块；红毯 x%d～%d（宽 %d）" % (
        W, H, len(rings), "、".join(sorted(set("%d×%d" % (r[2] - r[0] + 1, r[3] - r[1] + 1) for r in rings))), len(rugs),
        carpet[0], carpet[2], carpet[2] - carpet[0] + 1))
    gv = lambda a, b: b[1] - a[3] - 1
    gh = lambda a, b: b[0] - a[2] - 1
    cols = sorted(set(r[0] for r in rings)); rows = sorted(set(r[1] for r in rings))

    def gaps(rects):
        row_g, col_g = [], []
        for x0 in sorted(set(r[0] for r in rects)):
            c = sorted([r for r in rects if r[0] == x0], key=lambda r: r[1])
            row_g += [gv(a, b) for a, b in zip(c, c[1:])]
        for y0 in sorted(set(r[1] for r in rects)):
            c = sorted([r for r in rects if r[1] == y0], key=lambda r: r[0])
            col_g += [gh(a, b) for a, b in zip(c, c[1:])]
        return row_g, col_g

    row_gaps, col_gaps = gaps(rings)
    inner_r = [g for g in row_gaps if g < 100 + 60]; cross_r = [g for g in row_gaps if g >= 100 + 60]
    # 块内行间和横走道：按大小分不开时（v3 行距 180，占地间 88，横走道 128），以「最小的一类」和「其余」分
    small_r = min(row_gaps)
    inner_r = [g for g in row_gaps if g <= small_r + 5]; cross_r = [g for g in row_gaps if g > small_r + 5]
    inner_c = [g for g in col_gaps if g < 100]; cross_c = [g for g in col_gaps if g >= 100]
    print("\n【画面上，按图上画出来的框（桌加椅背）】")
    print("行间（块内上下两排桌之间，地面前后 32 像素一米）：%s 像素 = %.2f 米" % (sorted(set(inner_r)), min(inner_r) / 32.0))
    print("列间（块内左右两张桌之间，左右 48 像素一米）：%s 像素 = %.2f 米" % (sorted(set(inner_c)), min(inner_c) / 48.0))
    print("横走道（桌到桌）：%s 像素 = %.2f 米" % (sorted(set(cross_r)), min(cross_r) / 32.0))
    print("跨红毯（红毯两边最近的桌之间）：%d 像素 = %.2f 米" % (min(cross_c), min(cross_c) / 48.0))
    lr = max(r[2] for r in rings if r[2] < carpet[0]); rl = min(r[0] for r in rings if r[0] > carpet[2])
    print("红毯边到最近的桌：左 %d、右 %d 像素" % (carpet[0] - lr - 1, rl - carpet[2] - 1))
    lg = max(r[2] for r in rugs if r[2] < carpet[0]); rg = min(r[0] for r in rugs if r[0] > carpet[2])
    print("红毯边到最近的地毯：左 %d、右 %d 像素" % (carpet[0] - lg - 1, rg - carpet[2] - 1))
    rug_v = [gv(a, b) for a in rugs for b in rugs if a[0] == b[0] and b[1] > a[1]]
    rug_h = [gh(a, b) for a in rugs for b in rugs if a[1] == b[1] and b[0] > a[0]]
    print("地毯之间露出的地面：上下最窄 %d、左右最窄 %d 像素（一人宽 %d）" % (min(rug_v), min(rug_h), PERSON_W))
    # 行与行之间画面上露出的地面：按像素扫
    if trows:
        rr = [(r["x"], r["y"], r["x"] + r["w"] - 1, r["y"] + r["h"] - 1) for r in trows if color_of(r["name"]) in ("地毯", "主桌地毯")]
        rv = [gv(a, b) for a in rr for b in rr if a[0] == b[0] and b[1] > a[1]]
        rh = [gh(a, b) for a in rr for b in rr if a[1] == b[1] and b[0] > a[0]]
        print("地毯之间露出的地面（按表里地毯的框，105 高）：上下最窄 %d、左右最窄 %d 像素；图上量到的地毯被后排椅背盖住一截（见 diff），所以上面那行上下是 %d" % (
            min(rv), min(rh), min(rug_v)))
    va, vb = visible_floor(im, rings, lambda g: g <= small_r + 5)
    print("行与行之间画面上露出的地面（前一排桌画出来的前沿 → 后一排椅背最上沿，逐列扫）：最窄 %d 像素（连地毯）；只算地面色最窄 %d 像素（在 x=%d 那一列）" % (va[0], vb[0], vb[1]))
    vc, vd = visible_floor(im, rings, lambda g: g > small_r + 5)
    print("横走道画面上露出的地面：最窄 %d 像素（连地毯）；只算地面色最窄 %d 像素" % (vc[0], vd[0]) if vc else "横走道：图上没有")
    # ---- 地上，按表里的占地 ----
    foot_rects = []
    if trows:
        tr = [r for r in trows if blocker_shape(r["name"]) == "e"]
        ok, bad = 0, []
        for r in tr:
            fx, fy, fw, fh = r["foot"]
            near = min(rings, key=lambda q: (q[0] - r["x"]) ** 2 + (q[1] - r["y"]) ** 2)
            if near[0] == fx and near[3] == fy + fh - 1 and near[2] - near[0] + 1 == fw:
                ok += 1
            else:
                bad.append(r["name"])
        print("\n【地上，按表里的占地（桌 %d 张）】占地和图上桌子画出来的框对得上（左边 x、下沿、宽一样）：%d 张%s" % (
            len(tr), ok, ("；对不上：" + "、".join(bad)) if bad else ""))
        foot_rects = [(r["foot"][0], r["foot"][1], r["foot"][0] + r["foot"][2] - 1, r["foot"][1] + r["foot"][3] - 1) for r in tr]
        frow, fcol = gaps(foot_rects)
        f_small = min(frow)
        f_inner = [g for g in frow if g <= f_small + 5]; f_cross = [g for g in frow if g > f_small + 5]
        print("行间（占地之间）：%s 像素 = %.2f 米；横走道（占地之间）：%s 像素 = %.2f 米；列间：%s 像素 = %.2f 米" % (
            sorted(set(f_inner)), min(f_inner) / 32.0, sorted(set(f_cross)), min(f_cross) / 32.0,
            sorted(set(g for g in fcol if g < 100)), min(g for g in fcol if g < 100) / 48.0))
    wl = [box(t) for t in comps["壁边灯柱"] if t[0] < 100]; wr = [box(t) for t in comps["壁边灯柱"] if t[0] > 1400]
    rails = [box(t) for t in comps["栏杆"]]
    px = im.load()
    y = H // 2
    x = 0
    while px[x, y] == COLORS["墙"]:
        x += 1
    wall_l = x
    x = W - 1
    while px[x, y] == COLORS["墙"]:
        x -= 1
    wall_r = x
    print("\n桌到西墙内沿 %d、到东墙内沿 %d；桌到壁边灯柱 %d（西）／%d（东）；最后一排桌（画出来的）到南边栏杆（画出来的）%d 像素" % (
        min(r[0] for r in rings) - wall_l, wall_r - max(r[2] for r in rings),
        min(r[0] for r in rings) - max(w[2] for w in wl) - 1, min(w[0] for w in wr) - max(r[2] for r in rings) - 1,
        min(r[1] for r in rails) - max(r[3] for r in rings) - 1))
    gate = [wh(t) for t in comps["门"] if t[0] < W - 100][0]
    edoor = [wh(t) for t in comps["门"] if t[0] > W - 100][0]
    print("大门洞宽 %d 像素 = %.1f 米；东侧门（沿墙）%d 像素 = %.1f 米（前后 32 一米）" % (gate[2], gate[2] / 48.0, edoor[3], edoor[3] / 32.0))
    # ---- 道具和道具之间的窄缝（画出来的框；不是走道，是死角；桌子是椭圆，外框会多算，这里不比桌子）----
    props = []
    for nm in ("落地宫灯", "花盆", "壁边灯柱", "贺礼堆", "长凳", "乐队地台", "台阶", "栏杆"):
        props += [(nm, box(t)) for t in comps[nm]]
    st_top, st_front = box(comps["台面"][0]), box(comps["台口立面"][0])
    props.append(("婚礼台", (st_top[0], st_top[1], st_top[2], st_front[3])))
    narrow = {}
    for i in range(len(props)):
        for j in range(i + 1, len(props)):
            (na, a), (nb, b) = props[i], props[j]
            if {na, nb} <= {"婚礼台", "台阶"}:
                continue
            dx = max(b[0] - a[2] - 1, a[0] - b[2] - 1, 0)
            dy = max(b[1] - a[3] - 1, a[1] - b[3] - 1, 0)
            if (dx == 0) != (dy == 0):
                g = max(dx, dy)
                if 0 < g < PERSON_W:
                    key = ("↔".join(sorted([na, nb])), g)
                    narrow[key] = narrow.get(key, 0) + 1
    print("道具之间、道具到台子之间（画出来的框），空隙窄过 %d 的（%d 处，不是走道）：%s" % (PERSON_W, sum(narrow.values()),
          "；".join("%s %d（%d 处）" % (k[0], k[1], v) for k, v in sorted(narrow.items(), key=lambda kv: (kv[0][1], kv[0][0])))))
    # ---- 用「人宽 43 的圆」从进门那块空地走 ----
    r_need = PERSON_W / 2.0
    stand_row = next((r for r in trows if r["name"].startswith("进门站的地方")), None)
    start = (stand_row["x"] + stand_row["w"] // 2, stand_row["y"] + stand_row["h"] // 2) if stand_row else (W // 2, min(r[1] for r in rails) - 150)
    print("\n人宽 %d（半径 %.1f）的圆，从进门那块空地（%d, %d）出发：" % (PERSON_W, r_need, start[0], start[1]))
    fig_data = None
    if trows:
        blk = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(blk)
        wall_n = next((r["h"] for r in trows if r["name"] == "北墙（立面）"), 0)
        d.rectangle([0, 0, W - 1, wall_n - 1], fill=255)
        gmax = 0
        for r in trows:
            sh = blocker_shape(r["name"])
            if sh is None or r["foot"] is None:
                continue
            fx, fy, fw, fh = r["foot"]
            if sh == "e":
                d.ellipse([fx, fy, fx + fw - 1, fy + fh - 1], fill=255)
            else:
                d.rectangle([fx, fy, fx + fw - 1, fy + fh - 1], fill=255)
            if "栏杆" in r["name"] and r["ground"]:
                gmax = max(gmax, r["ground"])
        if gmax:
            d.rectangle([0, gmax, W, H], fill=255)
        targets = [r["foot"] for r in trows if blocker_shape(r["name"]) == "e"]
        unreach, widths, dist, best, small = reach(blk, W, H, start, targets)
        from collections import Counter
        dist_w = Counter(int(round(v[0])) for v in widths)
        print("  按表里的占地（走路的）：%d 张桌里走不到桌边的 %d 张%s；每张桌按最好走的那条路，路上最窄一段：最窄 %.0f 像素（比一人宽 %d 宽 %.0f）、最宽 %.0f；分布 %s" % (
            len(targets), len(unreach), ("：" + str(unreach)) if unreach else "", widths[0][0], PERSON_W, widths[0][0] - PERSON_W, widths[-1][0],
            "、".join("%d 像素×%d 张" % kv for kv in sorted(dist_w.items()))))
        fig_data = (dist, small)
    # 按图上画出来的色块（含椅背，看着挡路的）再算一遍
    blk2 = Image.new("L", (W, H), 0)
    for n in BLOCKERS:
        blk2 = ImageChops.lighter(blk2, mask_of(chans, COLORS[n]))
    ImageDraw.Draw(blk2).rectangle([0, max(r[3] for r in rails) + 1, W, H], fill=255)
    targets2 = [(r[0], r[3] - 91, r[2] - r[0] + 1, 92) for r in rings]   # 桌子在哪：框下沿往上 92（没有表时的近似）
    if trows:
        targets2 = [r["foot"] for r in trows if blocker_shape(r["name"]) == "e"]
    unreach2, widths2, dist2, best2, small2 = reach(blk2, W, H, start, targets2)
    from collections import Counter as _C
    dist_w2 = _C(int(round(v[0])) for v in widths2)
    print("  按图上画出来的色块（含椅背，看着挡路的）：%d 张桌里走不到桌边的 %d 张%s%s" % (
        len(targets2), len(unreach2), ("：" + str([(t[0], t[1]) for t in unreach2])) if unreach2 else "",
        ("；路上最窄一段：最窄 %.0f 像素、最宽 %.0f；分布 %s" % (widths2[0][0], widths2[-1][0], "、".join("%d 像素×%d 张" % kv for kv in sorted(dist_w2.items())))) if widths2 else ""))
    if fig_data is None:
        fig_data = (dist2, small2)
    if args.fig:
        dist, small = fig_data
        w, h = W // 2, H // 2
        S = 2
        base = im.resize((w, h), Image.NEAREST).convert("RGBA")
        ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        po = ov.load()
        blocked = small.load()
        for y in range(h):
            for x in range(w):
                if blocked[x, y]:
                    continue
                po[x, y] = (40, 200, 90, 90) if dist[y][x] >= r_need else (255, 150, 0, 150)
        out = Image.alpha_composite(base, ov).convert("RGB")
        d = ImageDraw.Draw(out)
        font = None
        for fp in ("/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc", "/Library/Fonts/Arial Unicode.ttf"):
            try:
                from PIL import ImageFont
                font = ImageFont.truetype(fp, 14)
                break
            except Exception:
                continue
        # 标注：每种走道挑一处，放在不同的行里，字不叠在一起
        marks = {}
        col0 = sorted([r for r in rings if r[0] == cols[1]], key=lambda r: r[1])
        for a, b in zip(col0, col0[1:]):
            g = gv(a, b)
            marks.setdefault("行间（画面）" if g <= small_r + 5 else "横走道", ((a[0] + a[2]) // 2 - 20, a[3] + 1, (a[0] + a[2]) // 2 - 20, b[1] - 1, g))
        if foot_rects:
            fc0 = sorted([r for r in foot_rects if r[0] == cols[1]], key=lambda r: r[1])
            a, b = fc0[0], fc0[1]
            marks["行间（占地）"] = ((a[0] + a[2]) // 2 + 20, a[3] + 1, (a[0] + a[2]) // 2 + 20, b[1] - 1, gv(a, b))

        def row_pairs(y0):
            c = sorted([r for r in rings if r[1] == y0], key=lambda r: r[0])
            return [(gh(a, b), a, b) for a, b in zip(c, c[1:])]
        g_, a_, b_ = min((p for p in row_pairs(rows[6]) if p[0] < 100), key=lambda p: p[1][0])
        marks["列间"] = (a_[2] + 1, (a_[1] + a_[3]) // 2, b_[0] - 1, (a_[1] + a_[3]) // 2, g_)
        g_, a_, b_ = min((p for p in row_pairs(rows[3]) if p[0] >= 100), key=lambda p: p[0])
        marks["跨红毯"] = (a_[2] + 1, (a_[1] + a_[3]) // 2, b_[0] - 1, (a_[1] + a_[3]) // 2, g_)
        ring_l = min((r for r in rings if r[2] == lr and r[1] == rows[4]), key=lambda r: r[0])
        marks["红毯边（左）"] = (lr + 1, (ring_l[1] + ring_l[3]) // 2, carpet[0] - 1, (ring_l[1] + ring_l[3]) // 2, carpet[0] - lr - 1)
        ring_r = min((r for r in rings if r[0] == rl and r[1] == rows[5]), key=lambda r: r[0])
        marks["红毯边（右）"] = (carpet[2] + 1, (ring_r[1] + ring_r[3]) // 2, rl - 1, (ring_r[1] + ring_r[3]) // 2, rl - carpet[2] - 1)
        for name, (x0, y0, x1, y1, g) in marks.items():
            a, b, c2, d2 = x0 // S, y0 // S, x1 // S, y1 // S
            d.line([(a, b), (c2, d2)], fill=(220, 0, 0), width=2)
            for (ex, ey) in ((a, b), (c2, d2)):
                if abs(x1 - x0) > abs(y1 - y0):
                    d.line([(ex, ey - 4), (ex, ey + 4)], fill=(220, 0, 0), width=2)
                else:
                    d.line([(ex - 4, ey), (ex + 4, ey)], fill=(220, 0, 0), width=2)
            label = "%s %d" % (name, g)
            tw = int(font.getlength(label)) + 6 if font is not None else 0
            if name.startswith("行间（占地") or name == "横走道":
                tx, ty = a + 8, (b + d2) // 2 - 8
            elif name.startswith("行间（画面"):
                tx, ty = a - tw - 8, (b + d2) // 2 - 8
            elif name == "红毯边（左）":
                tx, ty = a - tw - 8, b - 8
            elif name == "红毯边（右）":
                tx, ty = c2 + 8, b - 8
            else:
                tx, ty = (a + c2) // 2 - tw // 2, b - 26
            if font is not None:
                d.rectangle([tx - 2, ty - 1, tx + tw, ty + 17], fill=(255, 255, 255))
                d.text((tx, ty), label, fill=(180, 0, 0), font=font)
        out.save(args.fig, quality=80, optimize=True) if args.fig.lower().endswith((".jpg", ".jpeg")) else out.save(args.fig)
        print("走道图：%s（半分辨率 %d×%d；绿 = 一个人能站，橙 = 空着但站不下）" % (args.fig, w, h))


# ---------------- north：北边三样 ----------------
def top_colors(im, box, k=3):
    cs = sorted(im.crop((box[0], box[1], box[2] + 1, box[3] + 1)).getcolors(maxcolors=100000), reverse=True)[:k]
    out = []
    for n, c in cs:
        nm = [key for key, v in COLORS.items() if v == c]
        out.append("%s×%d" % (nm[0] if nm else str(c), n))
    return "、".join(out)


def cmd_north(args):
    whole = Image.open(args.png).convert("RGB")
    north = Image.open(args.north).convert("RGB")
    W, H = whole.size
    if north.size[0] != W:
        print("北边干净版宽 %d 和整厅宽 %d 不一样" % (north.size[0], W))
    nh = north.size[1]
    crop = whole.crop((0, 0, W, nh))
    print("北边干净版 %d×%d；对整厅 y 0～%d 那块" % (north.size[0], nh, nh - 1))
    diff = ImageChops.difference(crop, north).convert("L").point(lambda v: 255 if v else 0)
    n = sum(1 for v in diff.getdata() if v)
    print("【干净版】逐像素比：不一样的 %d 个像素（占 %.3f%%）" % (n, 100.0 * n / (W * nh)))
    for c in components(diff)[:12]:
        bb = c[:4]
        print("  一块 x%d～%d、y%d～%d（%d×%d）：整厅这块主要是 %s；北边这块主要是 %s" % (
            bb[0], bb[2], bb[1], bb[3], bb[2] - bb[0] + 1, bb[3] - bb[1] + 1, top_colors(crop, bb), top_colors(north, bb)))
    unknown = [(cnt, c) for cnt, c in north.getcolors(maxcolors=100000) if c not in COLORS.values()]
    print("北边干净版里不在调色板的颜色（有字会有抗锯齿的杂色）：%s" % ("没有，没字" if not unknown else str(unknown[:8])))
    _, _, ncomps = load(args.north)
    ppl = ncomps["人"]
    print("北边干净版里的人（%s）：%d 个%s" % ("、".join(str(COLORS["人"])), len(ppl), "；" + "；".join("x%d～%d、y%d～%d（%d×%d，脚点约 (%d, %d)）" % (
        p[0], p[2], p[1], p[3], p[2] - p[0] + 1, p[3] - p[1] + 1, (p[0] + p[2]) // 2, p[3] + 1) for p in ppl)))
    fp = ncomps["脚印"]
    print("北边干净版里的新人脚印（白色）：%d 个；整厅干净版里的：%d 个" % (len(fp), len([c for c in components(mask_of(crop.split(), COLORS['脚印']))])))
    if args.annot and args.north_annot:
        wa = Image.open(args.annot).convert("RGB").crop((0, 0, W, nh))
        na = Image.open(args.north_annot).convert("RGB")
        d2 = ImageChops.difference(wa, na).convert("L").point(lambda v: 255 if v else 0)
        n2 = sum(1 for v in d2.getdata() if v)
        print("\n【标注版】逐像素比整厅标注版 y 0～%d：不一样的 %d 个像素（占 %.3f%%）" % (nh - 1, n2, 100.0 * n2 / (W * nh)))
        if n2:
            dd = d2.filter(ImageFilter.MaxFilter(15))
            cs = sorted(components(dd), key=lambda c: -c[4])[:8]
            for c in cs:
                print("  一块 x%d～%d、y%d～%d" % (c[0] + 7, c[2] - 7, c[1] + 7, c[3] - 7))
    if args.table and args.north_table:
        wt = {r["name"]: r for r in parse_table(args.table)}
        nt = parse_table(args.north_table)
        nnames = [r["name"] for r in nt]
        print("\n【表】北边表 %d 行；整厅表 %d 行" % (len(nt), len(wt)))
        extra = [r["name"] for r in nt if r["name"] not in wt]
        print("北边表里有、整厅表里没有的：%s" % ("、".join(extra) if extra else "没有"))
        diffs = []
        for r in nt:
            o = wt.get(r["name"])
            if o is None:
                continue
            for key in ("x", "y", "w", "h", "foot", "ground"):
                if r[key] != o[key]:
                    diffs.append((r["name"], key, o[key], r[key]))
        print("同名的行，x／y／宽／高／占地／落地线 和整厅表不一样的：%s" % ("没有" if not diffs else "；".join("%s 的 %s 整厅 %s 北边 %s" % d for d in diffs[:10])))
        should = [name for name, o in wt.items() if o["y"] < nh]
        missing = [x for x in should if x not in nnames]
        print("整厅表里框的上沿在 y<%d 的 %d 行，北边表里缺的：%s" % (nh, len(should), "、".join(missing) if missing else "没有"))
        wrong_cut = []
        for r in nt:
            over = r["y"] + r["h"] > nh
            m = re.search(r"露出\s*(\d+)", r["cut"])
            if over and (not m or int(m.group(1)) != nh - r["y"]):
                wrong_cut.append((r["name"], r["cut"], nh - r["y"]))
            if not over and r["cut"].strip():
                wrong_cut.append((r["name"], r["cut"], "没被切却写了被切"))
        print("下沿超出 y=%d 的应该标「被切（露出 N）」，N = %d − y：%s" % (nh, nh, "都对" if not wrong_cut else "；".join(str(w) for w in wrong_cut[:10])))


# ---------------- phone：手机屏 ----------------
def cmd_phone(args):
    canvas = Image.open(args.png).convert("RGB")
    _, chans, comps = load(args.png)
    rings = comps["桌一圈"]
    marks = []
    H_ = canvas.size[1]
    for label, path, y0 in (("舞台", args.stage, 0), ("进门", args.door, H_ - 1024)):
        ph = Image.open(path).convert("RGB")
        if ph.size != (540, 960):
            print("%s 屏：不是 540×960，是 %s" % (label, ph.size))
        exp = canvas.crop((480, y0, 480 + 576, y0 + 1024)).resize((540, 960), Image.NEAREST)
        diff = ImageChops.difference(ph, exp).convert("L").point(lambda v: 255 if v > 24 else 0)
        n = sum(1 for v in diff.getdata() if v)
        print("\n%s屏：和画布 x 480～1056、y %d～%d 裁下来缩到 540×960（0.9375 倍）比，不一致 %d 个像素" % (label, y0, y0 + 1023, n))
        pc = ph.split()

        def bb(cn):
            return mask_of(pc, COLORS[cn]).getbbox()

        if label == "舞台":
            for cn in ("花拱", "囍", "横幅", "台面", "台口立面", "LED", "台阶"):
                b = bb(cn)
                if b:
                    print("  %-6s 屏上 x %3d～%3d，y %3d～%3d（画布 y %.0f～%.0f）" % (cn, b[0], b[2] - 1, b[1], b[3] - 1, b[1] / ZOOM, (b[3] - 1) / ZOOM))
            for lim, txt in ((140, "屏上 140"), (131, "屏上 131（画布 140）")):
                cols = sorted(ph.crop((0, 0, 540, lim)).getcolors(maxcolors=1000), reverse=True)
                names = []
                for _, c in cols:
                    nm = [k for k, v in COLORS.items() if v == c]
                    names.append(nm[0] if nm else str(c))
                print("  顶上 %s 那条里的颜色：%s" % (txt, "、".join(names)))
            if args.fig:
                marks.append(("舞台", ph.copy(), [("h", 140, "屏上 140", (255, 255, 0)), ("h", 131, "画布 140（屏上 131）", (0, 255, 255)),
                                                ("t", bb("花拱")[1], "花拱顶 %d" % bb("花拱")[1], (255, 255, 255)), ("t", bb("囍")[1], "囍顶 %d" % bb("囍")[1], (255, 255, 255)),
                                                ("t", bb("横幅")[1], "横幅顶 %d" % bb("横幅")[1], (255, 255, 255)),
                                                ("v", bb("台面")[0], "台左 %d" % bb("台面")[0], (255, 255, 0)), ("v", bb("台面")[2] - 1, "台右 %d" % (bb("台面")[2] - 1), (255, 255, 0))]))
            st = bb("台面"); fr = bb("台口立面"); sp_ = bb("台阶")
            print("  台面 x %d～%d、台口立面 x %d～%d、台阶 x %d～%d（屏宽 0～539）；左边留 %d、右边留 %d" % (
                st[0], st[2] - 1, fr[0], fr[2] - 1, sp_[0], sp_[2] - 1, st[0], 539 - (st[2] - 1)))
            for cn in ("乐队地台", "贺礼堆"):
                for t in comps[cn]:
                    out_r, out_l = t[0] - 1056, 480 - (t[2] + 1)
                    print("  %s 画布 x %d～%d：%s" % (cn, t[0], t[2], ("在这一屏（480～1055）外面，离屏边 %d 像素" % (out_r if out_r >= 0 else out_l)) if (out_r >= 0 or out_l >= 0) else "在这一屏里"))
        else:
            for cn in ("门", "红毯", "栏杆", "人"):
                b = bb(cn)
                if b:
                    print("  %-4s 屏上 x %3d～%3d，y %3d～%3d" % (cn, b[0], b[2] - 1, b[1], b[3] - 1))
            if args.fig:
                marks.append(("进门", ph.copy(), [("t", bb("门")[1], "大门顶 %d" % bb("门")[1], (255, 255, 255)), ("t", bb("人")[1], "人头顶 %d（79 高）" % bb("人")[1], (255, 255, 255))]))
            full = [r for r in rings if r[0] >= 480 and r[2] <= 1055 and r[1] >= y0 and r[3] <= y0 + 1023]
            part = [r for r in rings if r[2] >= 480 and r[0] <= 1055 and r[3] >= y0 and r[1] <= y0 + 1023]
            print("  屏里整张看得见的桌 %d 张；露出一部分的 %d 张" % (len(full), len(part)))
    if args.middle:
        ph = Image.open(args.middle).convert("RGB")
        pal = set(c for _, c in canvas.getcolors(maxcolors=100000))
        pp = ph.load()
        best = None
        for y0 in range(0, H_ - 1024 + 1, 2):
            ep = canvas.crop((480, y0, 480 + 576, y0 + 1024)).resize((540, 960), Image.NEAREST).load()
            bad = tot = 0
            for y in range(0, 960, 8):
                for x in range(0, 540, 8):
                    c = pp[x, y]
                    if c in pal:
                        tot += 1
                        if ep[x, y] != c:
                            bad += 1
            if best is None or bad < best[0]:
                best = (bad, y0, tot)
        print("\n有人的那张（--middle）：最像画布 y %d～%d 那一屏（画布调色板里的像素采样 %d 个，不一致 %d 个）" % (best[1], best[1] + 1023, best[2], best[0]))
        extra = [(n, c) for n, c in ph.getcolors(maxcolors=100000) if c not in pal]
        print("  屏里有、画布里没有的颜色（人的剪影、托盘）：%s" % "；".join("%s×%d" % (c, n) for n, c in sorted(extra, reverse=True)))
        # 服务员：最深的那个颜色的块
        dark = max(extra, key=lambda nc: 0 if nc[1] != (40, 40, 40) else 1)
        wc = components(mask_of(ph.split(), (40, 40, 40)))
        print("  (40,40,40) 的块：%s" % "；".join("%d×%d" % (c[2] - c[0] + 1, c[3] - c[1] + 1) for c in wc[:6]))
    if args.fig and marks:
        draw_phone_fig(marks, args.fig)


def draw_phone_fig(marks, out):
    from PIL import ImageFont
    font = None
    for fp in ("/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc", "/Library/Fonts/Arial Unicode.ttf"):
        try:
            font = ImageFont.truetype(fp, 14)
            break
        except Exception:
            continue
    fig = Image.new("RGB", (1100, 960), (255, 255, 255))
    for i, (label, ph, items) in enumerate(marks):
        ox = i * 560
        fig.paste(ph, (ox, 0))
        d = ImageDraw.Draw(fig)
        for (kind, v, text, col) in items:
            if kind == "h":
                d.line([(ox, v), (ox + 539, v)], fill=col, width=2)
                y1 = v + 3 if v >= 135 else v - 19          # 两条线挨得近：上面那条的字放线上面，下面那条的放线下面
                d.rectangle([ox + 4, y1, ox + 4 + int(font.getlength(text)) + 6, y1 + 16], fill=(0, 0, 0))
                d.text((ox + 7, y1 + 1), text, fill=col, font=font)
            elif kind == "t":
                d.line([(ox, v), (ox + 539, v)], fill=(0, 0, 0), width=1)
                tx = ox + (330 if label == "舞台" else 230)
                d.rectangle([tx, v - 1, tx + int(font.getlength(text)) + 6, v + 16], fill=(0, 0, 0))
                d.text((tx + 3, v), text, fill=col, font=font)
            else:
                d.line([(ox + v, 0), (ox + v, 959)], fill=col, width=1)
                d.rectangle([ox + v + 2, 600, ox + v + 2 + int(font.getlength(text)) + 6, 617], fill=(0, 0, 0))
                d.text((ox + v + 5, 601), text, fill=col, font=font)
        d.rectangle([ox + 4, 938, ox + 4 + int(font.getlength("%s屏（540×960，0.9375 倍）" % label)) + 8, 958], fill=(255, 255, 255))
        d.text((ox + 8, 940), "%s屏（540×960，0.9375 倍）" % label, fill=(255, 0, 0), font=font)
    fig.crop((0, 0, 1100, 960)).save(out, quality=85, optimize=True) if out.lower().endswith((".jpg", ".jpeg")) else fig.save(out)
    print("手机屏核对图：%s" % out)


def main():
    ap = argparse.ArgumentParser(description="摆位底图核对")
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("diff")
    d.add_argument("--png", required=True); d.add_argument("--table", required=True); d.add_argument("--annot")
    d.set_defaults(fn=cmd_diff)
    w = sub.add_parser("walk")
    w.add_argument("--png", required=True); w.add_argument("--table"); w.add_argument("--fig"); w.set_defaults(fn=cmd_walk)
    n = sub.add_parser("north")
    n.add_argument("--png", required=True); n.add_argument("--north", required=True)
    n.add_argument("--annot"); n.add_argument("--north-annot"); n.add_argument("--table"); n.add_argument("--north-table")
    n.set_defaults(fn=cmd_north)
    p = sub.add_parser("phone")
    p.add_argument("--png", required=True); p.add_argument("--door", required=True); p.add_argument("--stage", required=True)
    p.add_argument("--middle", help="有人的那张")
    p.add_argument("--fig", help="存一张把两屏并排、标了线的核对图")
    p.set_defaults(fn=cmd_phone)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
