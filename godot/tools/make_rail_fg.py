# 把试点底图下面两角画死的栏杆原样抠成前景积木（fg_rail_left/right.png），底图本身一个像素不改。
# 做法：栏杆框里「不是地砖颜色」的像素算栏杆；去掉零星的小斑点；被栏杆围住的地砖色像素也算进来（补洞）。
# 用法：python3 tools/make_rail_fg.py tools/layout_v7_tables   （9/18 助理 01：12 张桌要第三排，第三排在栏杆后面）
import sys, os
from collections import deque
from PIL import Image

folder = sys.argv[1]
im = Image.open(os.path.join(folder, "base.png")).convert("RGB")
px = im.load()

# 地砖颜色：从栏杆上方干净的地面取样，按 8 级量化，比对时看自己和相邻格
Q = 8
floor = set()
for y in range(705, 745):
    for x in list(range(110, 380)) + list(range(1130, 1400)):
        r, g, b = px[x, y]
        floor.add((r // Q, g // Q, b // Q))

def is_floor(c):
    r, g, b = c[0] // Q, c[1] // Q, c[2] // Q
    for dr in (-1, 0, 1):
        for dg in (-1, 0, 1):
            for db in (-1, 0, 1):
                if (r + dr, g + dg, b + db) in floor:
                    return True
    return False

def cut(box, name):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    rail = [[not is_floor(px[x0 + i, y0 + j]) for i in range(w)] for j in range(h)]
    # 去零星斑点：连通块小于 60 像素的不要（地砖上的花纹被误判）
    seen = [[False] * w for _ in range(h)]
    for j in range(h):
        for i in range(w):
            if rail[j][i] and not seen[j][i]:
                comp, q = [], deque([(i, j)])
                seen[j][i] = True
                while q:
                    a, b = q.popleft()
                    comp.append((a, b))
                    for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        na, nb = a + da, b + db
                        if 0 <= na < w and 0 <= nb < h and rail[nb][na] and not seen[nb][na]:
                            seen[nb][na] = True
                            q.append((na, nb))
                if len(comp) < 60:
                    for a, b in comp:
                        rail[b][a] = False
    # 补洞：从框的上、下、靠地面那一侧边走地砖色，走不到的地砖色像素是被栏杆围住的，也算栏杆
    outside = [[False] * w for _ in range(h)]
    q = deque()
    starts = [(i, 0) for i in range(w)] + [(i, h - 1) for i in range(w)]
    starts += [(w - 1, j) for j in range(h)] if name == "left" else [(0, j) for j in range(h)]
    for i, j in starts:
        if not rail[j][i] and not outside[j][i]:
            outside[j][i] = True
            q.append((i, j))
    while q:
        a, b = q.popleft()
        for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            na, nb = a + da, b + db
            if 0 <= na < w and 0 <= nb < h and not rail[nb][na] and not outside[nb][na]:
                outside[nb][na] = True
                q.append((na, nb))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    n = 0
    for j in range(h):
        for i in range(w):
            if rail[j][i] or not outside[j][i]:
                r, g, b = px[x0 + i, y0 + j]
                op[i, j] = (r, g, b, 255)
                n += 1
    bb = out.getbbox()
    out = out.crop(bb)
    path = os.path.join(folder, "fg_rail_%s.png" % name)
    out.save(path)
    ox, oy = x0 + bb[0], y0 + bb[1]
    print("fg_rail_%s.png %d×%d 放在 (%d, %d)，栏杆像素 %d" % (name, out.width, out.height, ox, oy, n))
    return ox, oy, out.width, out.height

cut((0, 740, 440, 1024), "left")
cut((1050, 740, 1462, 1024), "right")
