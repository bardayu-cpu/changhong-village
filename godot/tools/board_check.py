#!/usr/bin/env python3
"""摆位底图（纯色块）核对：从干净版 png 上按颜色量东西，再和摆位表、手机屏对。只用 PIL，不靠 numpy。

用途：02 把大厅按比例尺用色块排好（比如 55 桌摆位底图），GPT 照它画，02 照它还原——数一定要对。
03 拿这个脚本从图上量，不抄 02 的表，再和表对一遍。

三个子命令（都读同一张干净版 png）：
  diff   摆位表里每一件，按名字找到图上同色的那一块（离表里中心最近的），比 x／y／宽／高；差超过 1 像素的列出来，
         另外列 20 件抽样。图上「宽、高多 1」是画椭圆时含终点（PIL 画法），不算差
    python3 godot/tools/board_check.py diff  --png 底图.png --table 摆位表.md
  walk   走道：行间、列间、横走道、红毯两边、桌到墙／灯柱／栏杆最窄多宽；再用「人宽 43 的圆」从进门那块空地走，
         看每张桌能不能走到、路上最窄的一段多宽。--fig 存一张走道图（绿 = 人能站；橙 = 空着但太窄）
    python3 godot/tools/board_check.py walk  --png 底图.png [--fig 走道图.jpg]
  phone  手机屏两张：是不是画布 0.9375 倍的裁剪（一屏 576×1024）；顶上 140 那条里有什么；台子在不在屏里
    python3 godot/tools/board_check.py phone --png 底图.png --door 进门.png --stage 舞台.png

颜色（COLORS）是 02 的 make_board55.py 用的色；02 换色了，改这里。表里名字到颜色的对应在 color_of()。
"""
import argparse
import heapq
import math
import re
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

PERSON_W = 43          # 一人宽（ASSETS 表里的人宽），走道窄过它就是过不去
ZOOM = 0.9375          # 手机屏镜头：屏高 960 ÷ 画布 1024
COLORS = {
    "地面": (239, 227, 207), "墙": (92, 52, 36), "墙顶横梁": (60, 32, 22), "帐幔": (170, 40, 40), "挂灯": (240, 170, 60),
    "花拱": (70, 130, 70), "囍": (215, 170, 60), "横幅": (150, 30, 30), "台面": (200, 60, 55), "台口立面": (150, 40, 38),
    "台阶": (175, 50, 46), "LED": (20, 10, 8), "脚印": (255, 255, 255), "红毯": (179, 32, 42), "落地宫灯": (240, 200, 60),
    "花盆": (90, 170, 90), "壁边灯柱": (230, 170, 60), "乐队地台": (120, 40, 50), "钢琴": (30, 30, 30), "坐乐手": (70, 60, 110),
    "站乐手": (110, 70, 140), "大提琴": (140, 80, 40), "贺礼堆": (230, 120, 120), "长凳": (120, 200, 255),
    "桌一圈": (90, 50, 25), "桌面": (220, 70, 60), "主桌桌面": (240, 190, 60), "地毯": (150, 70, 40), "主桌地毯": (200, 150, 40),
    "栏杆": (120, 80, 50), "门": (60, 140, 200), "人": (20, 20, 20),
}
# 走路时挡路的颜色（红毯、地毯、地面、门、人的尺子不挡）
BLOCKERS = ["墙", "墙顶横梁", "帐幔", "挂灯", "花拱", "囍", "横幅", "台面", "台口立面", "台阶", "LED", "脚印", "落地宫灯", "花盆",
            "壁边灯柱", "乐队地台", "钢琴", "坐乐手", "站乐手", "大提琴", "贺礼堆", "长凳", "桌一圈", "桌面", "主桌桌面", "栏杆"]


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


# ---------------- diff：表 对 图 ----------------
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
    if name == "大提琴": return "大提琴"
    if name.startswith("小提琴手"): return "站乐手"
    if name == "贺礼堆": return "贺礼堆"
    if name == "长凳": return "长凳"
    if name == "主桌 地毯": return "主桌地毯"
    if name.endswith(" 地毯"): return "地毯"
    if name == "主桌" or re.fullmatch(r"T\d+", name): return "桌一圈"
    if name == "大门（双开门门洞）" or name.startswith("东侧门"): return "门"
    if "栏杆" in name: return "栏杆"
    if name == "尺子：人": return "人"
    return None


SAMPLE = ["T1", "主桌", "T27", "T54", "T1 地毯", "主桌 地毯", "婚礼台（台面）", "台阶（西）", "LED 屏", "横幅", "囍字圆牌", "花拱", "红毯",
          "大门（双开门门洞）", "东侧门（门洞）", "南边东段栏杆", "三角钢琴", "乐队地台", "贺礼堆", "长凳"]


def parse_table(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\| (.+?) \| (-?\d+) \| (-?\d+) \| (\d+) \| (\d+) \| (.*) \|$", line.rstrip("\n"))
        if m:
            rows.append((m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))))
    return rows


def cmd_diff(args):
    im, chans, comps = load(args.png)
    rows = parse_table(args.table)
    res, skipped = [], []
    for (name, x, y, w, h) in rows:
        cn = color_of(name)
        if cn is None:
            skipped.append(name)
            continue
        cx, cy = x + w / 2.0, y + h / 2.0
        best = min((wh(t) for t in comps[cn]), key=lambda b: (b[0] + b[2] / 2.0 - cx) ** 2 + (b[1] + b[3] / 2.0 - cy) ** 2)
        res.append((name, (x, y, w, h), best))
    print("摆位表 %d 件；能按颜色在图上找到的 %d 件；没有独立颜色（墙、进门站的地方）%d 件：%s" % (len(rows), len(res), len(skipped), "、".join(skipped)))
    from collections import Counter
    cnt = Counter((b[2] - t[2], b[3] - t[3]) for (_, t, b) in res if abs(b[0] - t[0]) <= 1 and abs(b[1] - t[1]) <= 1)
    print("位置差 ≤1 的里，宽／高差的分布（图上量到 − 表里）：" + "；".join("%+d／%+d：%d 件" % (k[0], k[1], v) for k, v in sorted(cnt.items())))
    bad = []
    for (name, t, b) in res:
        d = (b[0] - t[0], b[1] - t[1], b[2] - t[2], b[3] - t[3])
        if max(abs(v) for v in d) > 2:
            bad.append((name, t, b, d))
    print("\n表和图差超过 2 像素的（%d 件）：" % len(bad))
    for (name, t, b, d) in bad:
        print("  %s：表里 x%d y%d 宽%d 高%d；图上 x%d y%d 宽%d 高%d；差 %+d／%+d／%+d／%+d" % ((name,) + t + b + d))
    # 表里有、图上没有（挂灯 8 那种：中心离画布外）
    W, H = im.size
    for (name, x, y, w, h) in rows:
        if x + w > W or y + h > H:
            print("  %s 在画布外：x%d～%d（画布宽 %d）" % (name, x, x + w, W))
    print("\n抽样 20 件（| 东西 | 摆位表 x／y／宽／高 | 图上量到 x／y／宽／高 | 差 |）：")
    by = {r[0]: r for r in res}
    for n in SAMPLE:
        if n not in by:
            continue
        _, t, b = by[n]
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


def cmd_walk(args):
    im, chans, comps = load(args.png)
    W, H = im.size
    box = lambda t: (t[0], t[1], t[2], t[3])
    rings = [box(t) for t in comps["桌一圈"]]
    rugs = [box(t) for t in comps["地毯"]] + [box(t) for t in comps["主桌地毯"]]
    carpet = box(comps["红毯"][0])
    print("桌 %d 张；地毯 %d 块；红毯 x%d～%d（宽 %d）" % (len(rings), len(rugs), carpet[0], carpet[2], carpet[2] - carpet[0] + 1))
    gv = lambda a, b: b[1] - a[3] - 1
    gh = lambda a, b: b[0] - a[2] - 1
    cols = sorted(set(r[0] for r in rings)); rows = sorted(set(r[1] for r in rings))
    row_gaps, col_gaps = [], []
    for x0 in cols:
        c = sorted([r for r in rings if r[0] == x0], key=lambda r: r[1])
        row_gaps += [gv(a, b) for a, b in zip(c, c[1:])]
    for y0 in rows:
        c = sorted([r for r in rings if r[1] == y0], key=lambda r: r[0])
        col_gaps += [gh(a, b) for a, b in zip(c, c[1:])]
    inner_r = [g for g in row_gaps if g < 100]; cross_r = [g for g in row_gaps if g >= 100]
    inner_c = [g for g in col_gaps if g < 100]; cross_c = [g for g in col_gaps if g >= 100]
    print("行间（块内上下两排桌之间，地面前后 32 像素一米）：最窄 %d 像素 = %.2f 米" % (min(inner_r), min(inner_r) / 32.0))
    print("列间（块内左右两张桌之间，左右 48 像素一米）：%s 像素 = %.2f 米" % (sorted(set(inner_c)), min(inner_c) / 48.0))
    print("横走道（桌到桌）：%s 像素 = %.2f 米" % (sorted(set(cross_r)), min(cross_r) / 32.0))
    print("跨红毯（红毯两边最近的桌之间）：%d 像素 = %.2f 米" % (min(cross_c), min(cross_c) / 48.0))
    lr = max(r[2] for r in rings if r[2] < carpet[0]); rl = min(r[0] for r in rings if r[0] > carpet[2])

    print("红毯边到最近的桌：左 %d、右 %d 像素" % (carpet[0] - lr - 1, rl - carpet[2] - 1))
    lg = max(r[2] for r in rugs if r[2] < carpet[0]); rg = min(r[0] for r in rugs if r[0] > carpet[2])
    print("红毯边到最近的地毯：左 %d、右 %d 像素" % (carpet[0] - lg - 1, rg - carpet[2] - 1))
    rug_v = [gv(a, b) for a in rugs for b in rugs if a[0] == b[0] and b[1] > a[1]]
    rug_h = [gh(a, b) for a in rugs for b in rugs if a[1] == b[1] and b[0] > a[0]]
    # 走道图上的标注：每种走道挑一处，放在不同的行里，字不叠在一起
    marks = {}
    col0 = sorted([r for r in rings if r[0] == cols[0]], key=lambda r: r[1])
    for a, b in zip(col0, col0[1:]):
        g = gv(a, b)
        marks.setdefault("行间" if g < 100 else "横走道", ((a[0] + a[2]) // 2, a[3] + 1, (a[0] + a[2]) // 2, b[1] - 1, g))

    def row_pairs(y0):
        c = sorted([r for r in rings if r[1] == y0], key=lambda r: r[0])
        return [(gh(a, b), a, b) for a, b in zip(c, c[1:])]
    g_, a_, b_ = min((p for p in row_pairs(rows[2]) if p[0] < 100), key=lambda p: p[1][0])
    marks["列间"] = (a_[2] + 1, (a_[1] + a_[3]) // 2, b_[0] - 1, (a_[1] + a_[3]) // 2, g_)
    g_, a_, b_ = min((p for p in row_pairs(rows[3]) if p[0] >= 100), key=lambda p: p[0])
    marks["跨红毯"] = (a_[2] + 1, (a_[1] + a_[3]) // 2, b_[0] - 1, (a_[1] + a_[3]) // 2, g_)
    ring_l = min((r for r in rings if r[2] == lr and r[1] == rows[4]), key=lambda r: r[0])
    marks["红毯边（左）"] = (lr + 1, (ring_l[1] + ring_l[3]) // 2, carpet[0] - 1, (ring_l[1] + ring_l[3]) // 2, carpet[0] - lr - 1)
    ring_r = min((r for r in rings if r[0] == rl and r[1] == rows[5]), key=lambda r: r[0])
    marks["红毯边（右）"] = (carpet[2] + 1, (ring_r[1] + ring_r[3]) // 2, rl - 1, (ring_r[1] + ring_r[3]) // 2, rl - carpet[2] - 1)
    rg_row = sorted([g for g in rugs if g[1] == rows[6] - 6], key=lambda g: g[0])
    ra, rb = next((a, b) for a, b in zip(rg_row, rg_row[1:]) if gh(a, b) == min(rug_h))
    marks["地毯间"] = (ra[2] + 1, (ra[1] + ra[3]) // 2, rb[0] - 1, (ra[1] + ra[3]) // 2, min(rug_h))
    print("地毯之间露出的地面：上下最窄 %d、左右最窄 %d 像素（一人宽 %d）" % (min(rug_v), min(rug_h), PERSON_W))
    wl = [box(t) for t in comps["壁边灯柱"] if t[0] < 100]; wr = [box(t) for t in comps["壁边灯柱"] if t[0] > 1400]
    rails = [box(t) for t in comps["栏杆"]]
    # 墙内沿：地面色这一行从哪儿开始
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
    print("桌到西墙内沿 %d、到东墙内沿 %d；桌到壁边灯柱 %d（西）／%d（东）；最后一排桌到南边栏杆 %d 像素" % (
        min(r[0] for r in rings) - wall_l, wall_r - max(r[2] for r in rings),
        min(r[0] for r in rings) - max(w[2] for w in wl) - 1, min(w[0] for w in wr) - max(r[2] for r in rings) - 1,
        min(r[1] for r in rails) - max(r[3] for r in rings) - 1))
    gate = [wh(t) for t in comps["门"] if t[0] < W - 100][0]
    edoor = [wh(t) for t in comps["门"] if t[0] > W - 100][0]
    print("大门洞宽 %d 像素 = %.1f 米；东侧门（沿墙）%d 像素 = %.1f 米（前后 32 一米）" % (gate[2], gate[2] / 48.0, edoor[3], edoor[3] / 32.0))
    # ---- 道具和道具之间、道具和墙／台子之间的窄缝（不是走道，是死角；桌子是椭圆，外框会多算，这里不比桌子）----
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
                continue                                     # 台阶就是台子的一部分，挨着是设计
            dx = max(b[0] - a[2] - 1, a[0] - b[2] - 1, 0)
            dy = max(b[1] - a[3] - 1, a[1] - b[3] - 1, 0)
            if (dx == 0) != (dy == 0):                       # 一个方向上对着，另一个方向上有空隙
                g = max(dx, dy)
                if 0 < g < PERSON_W:
                    key = ("↔".join(sorted([na, nb])), g)
                    narrow[key] = narrow.get(key, 0) + 1
    print("道具之间、道具到台子之间，空隙窄过 %d 的（%d 处，不是走道）：%s" % (PERSON_W, sum(narrow.values()),
          "；".join("%s %d（%d 处）" % (k[0], k[1], v) for k, v in sorted(narrow.items(), key=lambda kv: (kv[0][1], kv[0][0])))))
    # ---- 用「人宽 43 的圆」从进门那块空地走 ----
    S = 2
    blk = Image.new("L", (W, H), 0)
    for n in BLOCKERS:
        blk = ImageChops.lighter(blk, mask_of(chans, COLORS[n]))
    ImageDraw.Draw(blk).rectangle([0, max(r[3] for r in rails) + 1, W, H], fill=255)   # 栏杆以南不算厅里
    w, h = W // S, H // S
    small = blk.filter(ImageFilter.MaxFilter(3)).resize((w, h), Image.NEAREST)   # 略偏保守：每边多算 1 像素
    sp = small.load()
    flags = [[bool(sp[x, y]) for x in range(w)] for y in range(h)]
    dist = [[v * S for v in row] for row in edt(flags, w, h)]
    start = (W // 2 // S, (min(r[1] for r in rails) - 150) // S)
    r_need = PERSON_W / 2.0
    assert dist[start[1]][start[0]] > r_need, "进门那块空地起点站不下一个人"
    best = [[-1.0] * w for _ in range(h)]
    best[start[1]][start[0]] = dist[start[1]][start[0]]
    pq = [(-best[start[1]][start[0]], start[0], start[1])]
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

    def to_ellipse(pxx, pyy, r):
        x0, y0, x1, y1 = r
        cx, cy = (x0 + x1 + 1) / 2.0, (y0 + y1 + 1) / 2.0
        a, b = (x1 - x0 + 1) / 2.0, (y1 - y0 + 1) / 2.0
        return min(math.hypot(pxx - (cx + a * math.cos(math.radians(i))), pyy - (cy + b * math.sin(math.radians(i)))) for i in range(0, 360, 3))

    unreach, widths = [], []
    for r in rings:
        cand = []
        for cy in range((r[1] - 40) // S, (r[3] + 40) // S + 1):
            for cx in range((r[0] - 40) // S, (r[2] + 40) // S + 1):
                if 0 <= cx < w and 0 <= cy < h and dist[cy][cx] >= r_need and to_ellipse(cx * S + S / 2.0, cy * S + S / 2.0, r) <= 34:
                    cand.append((best[cy][cx], cx * S, cy * S))
        if not cand or max(cand)[0] < r_need:
            unreach.append(r)
        else:
            widths.append((2 * max(cand)[0], r, max(cand)[1:]))
    print("\n人宽 %d（半径 %.1f）的圆，从进门那块空地出发：%d 张桌里走不到桌边的 %d 张%s" % (
        PERSON_W, r_need, len(rings), len(unreach), ("：" + str([(r[0], r[1]) for r in unreach])) if unreach else ""))
    if widths:
        widths.sort()
        print("每张桌按最好走的那条路，路上最窄的一段：最窄 %.0f 像素（%s），最宽 %.0f 像素；比一人宽 %d 宽 %.0f 像素" % (
            widths[0][0], "桌 x%d y%d" % (widths[0][1][0], widths[0][1][1]), widths[-1][0], PERSON_W, widths[0][0] - PERSON_W))
    if args.fig:
        # 走道图：绿 = 人能站（离挡路的东西 ≥ 半宽）；橙 = 空着但太窄
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
            if name in ("行间", "横走道"):
                tx, ty = a + 8, (b + d2) // 2 - 8
            elif name == "红毯边（左）":
                tx, ty = a - tw - 8, b - 8
            elif name == "红毯边（右）":
                tx, ty = c2 + 8, b - 8
            elif name == "地毯间":
                tx, ty = (a + c2) // 2 - tw // 2, b + 14
            else:
                tx, ty = (a + c2) // 2 - tw // 2, b - 26
            if font is not None:
                d.rectangle([tx - 2, ty - 1, tx + tw, ty + 17], fill=(255, 255, 255))
                d.text((tx, ty), label, fill=(180, 0, 0), font=font)
        out.save(args.fig, quality=80, optimize=True) if args.fig.lower().endswith((".jpg", ".jpeg")) else out.save(args.fig)
        print("走道图：%s（半分辨率 %d×%d；绿 = 一个人能站，橙 = 空着但站不下）" % (args.fig, w, h))


# ---------------- phone：手机屏 ----------------
def cmd_phone(args):
    canvas = Image.open(args.png).convert("RGB")
    _, chans, comps = load(args.png)
    rings = comps["桌一圈"]
    fig = Image.new("RGB", (1100, 960), (255, 255, 255)) if args.fig else None
    marks = []
    for label, path, y0 in (("舞台", args.stage, 0), ("进门", args.door, canvas.size[1] - 1024)):
        ph = Image.open(path).convert("RGB")
        if ph.size != (540, 960):
            print("%s 屏：不是 540×960，是 %s" % (label, ph.size))
        exp = canvas.crop((480, y0, 480 + 576, y0 + 1024)).resize((540, 960), Image.NEAREST)
        diff = ImageChops.difference(ph, exp).convert("L").point(lambda v: 255 if v > 24 else 0)
        n = sum(1 for v in diff.getdata() if v)
        print("\n%s屏：和画布 x 480～1056、y %d～%d 裁下来缩到 540×960（0.9375 倍）比，不一致 %d 个像素" % (label, y0, y0 + 1023, n))
        pc = ph.split()

        def bb(cn):
            b = mask_of(pc, COLORS[cn]).getbbox()
            return b

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
            if fig is not None:
                ph_ = ph.copy()
                marks.append(("舞台", ph_, [("h", 140, "屏上 140", (255, 255, 0)), ("h", 131, "画布 140（屏上 131）", (0, 255, 255)),
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
            if fig is not None:
                marks.append(("进门", ph.copy(), [("t", bb("门")[1], "大门顶 %d" % bb("门")[1], (255, 255, 255)), ("t", bb("人")[1], "人头顶 %d（79 高）" % bb("人")[1], (255, 255, 255))]))
            full = [r for r in rings if r[0] >= 480 and r[2] <= 1055 and r[1] >= y0 and r[3] <= y0 + 1023]
            part = [r for r in rings if r[2] >= 480 and r[0] <= 1055 and r[3] >= y0 and r[1] <= y0 + 1023]
            print("  屏里整张看得见的桌 %d 张；露出一部分的 %d 张" % (len(full), len(part)))
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
                up = v < 135                       # 两条线挨得近：上面那条的字放线上面，下面那条的放线下面
                y1 = v - 17 if not up else v - 17
                y1 = v + 3 if v >= 135 else v - 19
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
    d.add_argument("--png", required=True); d.add_argument("--table", required=True); d.set_defaults(fn=cmd_diff)
    w = sub.add_parser("walk")
    w.add_argument("--png", required=True); w.add_argument("--fig"); w.set_defaults(fn=cmd_walk)
    p = sub.add_parser("phone")
    p.add_argument("--png", required=True); p.add_argument("--door", required=True); p.add_argument("--stage", required=True)
    p.add_argument("--fig", help="存一张把两屏并排、标了线的核对图")
    p.set_defaults(fn=cmd_phone)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
