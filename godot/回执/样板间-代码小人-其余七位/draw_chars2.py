#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
draw_chars2.py —— 纯代码（Pillow）画罗曼山庄 11 位宾客的像素小人（charcode02，在 charcode01 的 draw_chars.py 上扩出来）。

  python3 draw_chars2.py           出新画的 7 位（01 02 03 04 08 11 12）图集 + json，
                                   已画的 4 位（09 10 05 06）重出到 check4/ 并跟样板逐像素核对；
                                   再出 lineup_all.png / walk_preview_all.gif / scene_preview.png
  python3 draw_chars2.py round3    另外再存一张 round3.png（7 位并排对照 GPT 原图）

  旧四位的画法一行没动：新加的东西都挂在 P.get(参数, 旧默认值) 上，旧四位走的还是原来那条路。

画法（跟 docs/罗曼山庄画风.md 第 0 节同一套）：
  - 1 个美术像素 = 1 个画布像素；一格 64×84，脚踩最后一行，左右以 x=32 为中线
  - 只有全透明 / 全不透明；外圈深色描边；部件之间（手臂压身子、两条腿）也描一道
  - 光从左上来：每个部件按「球 / 圆柱」算法线，跟左上光点乘，分 亮 / 中 / 暗 / 深暗 四档；
    压在前面的部件往右下投一像素影
  - 头身比四位统一：头（头发顶到下巴，不算发髻、爆炸头多出来的那截）= 身高的 0.38
  - 四个朝向都画，右边不是左边翻转出来的（光照照样从左上来）

图集格式照 GPT 那份（godot/assets/characters/lm/chr_LM-GUEST-09.json）：
  第一行 16 格：下 0～3、左 4～7、右 8～11、上 12～15（走路）
  第二行（格号 16 起）：待机 16-17、说话 18-19、坐（下 20-21、左 22-23、右 24-25、上 26-27）
"""
import json
import math
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = '/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件'
B57 = REPO + '/.claude/worktrees/build57/godot/assets/'     # 只读
GPT_DIR = B57 + 'characters/lm/'
LOUNGE = os.path.join(HERE, 'lounge57')       # git show build57:godot/assets/pixel_art/backhall_lounge/ 拷出来的
LAWN = B57 + 'pixel_art/lawn/'
SAMPLE4 = REPO + '/godot/回执/样板间-代码小人-休息间四位/'   # 已进游戏的四位（只读，拿来核对）
FW, FH = 64, 84
CX = 32.0
FOOT = 83


def hx(s):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


# 每种材料一条色带：[描边, 深暗, 暗, 中, 亮]
RAMPS_HEX = {
    'skin':      ['5c2a1e', 'c46f4b', 'e89a6c', 'fac28e', 'ffdfb6'],
    'skin_old':  ['5c2a1e', 'bd6a4a', 'e3966c', 'f7bb8a', 'ffdab0'],
    'hair_silver': ['3d323e', '7b707e', 'a59ba7', 'cfc7ce', 'f3eef0'],
    'hair_grey': ['25242c', '55525d', '83808c', 'b0adb8', 'e0dee6'],
    'hair_curl': ['0d0708', '1c1114', '2e1d1e', '452c29', '6b4536'],
    'hair_bob':  ['120a0b', '25191b', '372627', '4e3633', '70504a'],
    'jacket_plum': ['230f1d', '3b1932', '532742', '6c3456', '8a4a71'],
    'trim_gold': ['4a2a1a', '9a6a3e', 'c48e5a', 'e2b27b', 'f7d7a5'],
    'collar_white': ['4a3c40', 'a59ba1', 'cfc6c8', 'efe8e6', 'ffffff'],
    'skirt_grey': ['141011', '282223', '37302f', '48403f', '5e5554'],
    'suit':      ['121116', '25242b', '33323a', '44434c', '5c5b65'],
    'suit_pants': ['0f0e13', '1e1d23', '2a292f', '37363d', '4a4951'],
    'brass':     ['4a3410', '8a6420', 'b98a2c', 'e0b048', 'fbe08a'],
    'shoe_brown': ['2a1408', '4a2410', '693318', '8c4a24', 'b36b3b'],
    'shoe_black': ['0b0809', '191315', '252022', '342c2f', '4d4347'],
    'shirt_cream': ['4a3524', 'b19776', 'd6bf99', 'f2e1bf', 'fff6df'],
    'flower_red': ['4a1810', '8c281b', 'b43923', 'da4b2c', 'f17657'],
    'flower_orange': ['4a2410', 'a3521c', 'cf7224', 'ef922f', 'fbb85a'],
    'flower_yellow': ['4a3a10', 'a3801c', 'cfa62c', 'f1c94a', 'fde58a'],
    'leaf_green': ['16260f', '2c5222', '3e6e2e', '558e3e', '79ad55'],
    'pants_dark': ['110b0c', '231819', '302324', '3f3030', '544240'],
    'sweater_mauve': ['2a151b', '482a33', '5d3942', '74494f', '8f5f64'],
    'skirt_black': ['0f0a0b', '1c1416', '271d20', '33282b', '463739'],
    'sock': ['3a2622', '7d5e50', 'a07e6c', 'bf9f8a', 'dcc2ac'],
    # ---- charcode02 新加（7 位）
    'hair_brown':   ['0e0807', '1d1310', '2c1e18', '422c22', '5e3f30'],   # 01 青年、11 女孩（深棕近黑）
    'hair_chestnut': ['2a130c', '4f2717', '6c3a22', '8a5131', 'ab6e46'],  # 03 卷发
    'hair_black':   ['0b0a0e', '18161c', '25222a', '35313b', '4e4856'],   # 08 双马尾
    'jacket_teal':  ['0b1c20', '163840', '1f4d54', '2a6367', '3c807e'],   # 01 外套、11 裙子
    'dress_wine':   ['22080f', '40111d', '5a1828', '742334', '913748'],   # 02 长裙
    'knit_beige':   ['4a3a2a', '9f8869', 'bea683', 'd8c29d', 'eedcb8'],   # 03 开衫
    'overall_green': ['121e0e', '22381b', '2f4c27', '3f6435', '577e46'],  # 08 背带裤
    'suit_navy':    ['0b0f1e', '171e37', '212b49', '2d3a5e', '41507a'],   # 12 小西装
}
RAMPS = {k: [hx(c) for c in v] for k, v in RAMPS_HEX.items()}

C = {   # 直接上色的小件（五官等）
    'eye': hx('2b1a14'), 'iris': hx('6a3d26'), 'iris2': hx('8a5232'), 'eye_hl': hx('ffffff'),
    'brow_dark': hx('3a2620'), 'blush': hx('f3a08a'), 'blush2': hx('ec8c76'),
    'mouth': hx('a9483f'), 'mouth_dk': hx('5e1d1a'), 'tongue': hx('e2796a'), 'teeth': hx('fff4ea'),
    'glass': hx('3a2420'), 'lens_hl': hx('fff8f0'),
    'wrinkle': hx('d98a62'),
    'iris_b': hx('333a52'), 'iris_b2': hx('5d6886'),     # 04 白衬衫哥 蓝灰眼
    'iris_dk': hx('3b2217'),                               # 年轻人的深棕瞳孔（浅棕 iris 跟皮肤太近，远看只剩一道眼线）
}

LX, LY, LZ = -0.50, -0.58, 0.64
_n = math.sqrt(LX * LX + LY * LY + LZ * LZ)
LX, LY, LZ = LX / _n, LY / _n, LZ / _n

# 部件分组：同组之间不描线、不投影
NOLINE = {('hair', 'face'), ('acc', 'hair'), ('neck', 'torso'), ('torso', 'neck'), ('neck', 'face')}
NOCAST = {('face', 'hair'), ('neck', 'torso')}


# ---------------------------------------------------------------- 一格画布
class Fig:
    def __init__(self):
        self.part = [[None] * FW for _ in range(FH)]
        self.grp = [[None] * FW for _ in range(FH)]
        self.mat = [[None] * FW for _ in range(FH)]
        self.shd = [[None] * FW for _ in range(FH)]
        self.z = [[0] * FW for _ in range(FH)]
        self.n = 0
        self.dl = {}      # (x,y) -> 档位加减
        self.ov = {}      # (x,y) -> 直接上色（五官、扣子），最后画
        self.noline = set()   # 这些像素不描内线
        self.selfcast = set()  # 这些部件里一块压一块也投影（卷发一卷一卷）

    def fill(self, test, bbox, part, grp, mat, shd):
        self.n += 1
        x0, y0, x1, y1 = bbox
        for y in range(max(0, int(math.floor(y0)) - 1), min(FH, int(math.ceil(y1)) + 1)):
            for x in range(max(0, int(math.floor(x0)) - 1), min(FW, int(math.ceil(x1)) + 1)):
                if test(x + 0.5, y + 0.5):
                    self.part[y][x] = part
                    self.grp[y][x] = grp
                    self.mat[y][x] = mat
                    self.shd[y][x] = shd
                    self.z[y][x] = self.n

    def erase(self, test, bbox, only=None):
        x0, y0, x1, y1 = bbox
        for y in range(max(0, int(y0) - 1), min(FH, int(math.ceil(y1)) + 1)):
            for x in range(max(0, int(x0) - 1), min(FW, int(math.ceil(x1)) + 1)):
                if test(x + 0.5, y + 0.5) and (only is None or self.part[y][x] in only):
                    self.part[y][x] = None
                    self.grp[y][x] = None
                    self.mat[y][x] = None

    def ellipse(self, cx, cy, rx, ry, part, grp, mat, shd=None, p=2.0):
        if shd is None:
            shd = ('sph', cx, cy, rx, ry)
        def t(px, py):
            return abs((px - cx) / rx) ** p + abs((py - cy) / ry) ** p <= 1.0
        self.fill(t, (cx - rx, cy - ry, cx + rx, cy + ry), part, grp, mat, shd)

    def capsule(self, ax, ay, bx, by, ra, rb, part, grp, mat, shd=None):
        if shd is None:
            shd = ('cyl', ax, ay, bx, by, max(ra, rb))
        def t(px, py):
            d, tt = seg_dist(px, py, ax, ay, bx, by)
            return d <= ra + (rb - ra) * tt
        r = max(ra, rb)
        self.fill(t, (min(ax, bx) - r, min(ay, by) - r, max(ax, bx) + r, max(ay, by) + r), part, grp, mat, shd)

    def rows(self, y0, y1, half, part, grp, mat, shd, cx=CX):
        def t(px, py):
            if py < y0 or py > y1:
                return False
            h = half(py)
            if h is None:
                return False
            if isinstance(h, tuple):
                return cx - h[0] <= px <= cx + h[1]
            return abs(px - cx) <= h
        self.fill(t, (0, y0, FW, y1), part, grp, mat, shd)

    def px(self, x, y, part, grp, mat, shd=('flat', 0)):
        self.n += 1
        x, y = int(x), int(y)
        if 0 <= x < FW and 0 <= y < FH:
            self.part[y][x] = part
            self.grp[y][x] = grp
            self.mat[y][x] = mat
            self.shd[y][x] = shd
            self.z[y][x] = self.n

    def recolor(self, x, y, mat=None, dl=None, only=None):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < FW and 0 <= y < FH and self.part[y][x] is not None:
            if only is not None and self.part[y][x] not in only:
                return
            if mat:
                self.mat[y][x] = mat
            if dl is not None:
                self.dl[(x, y)] = self.dl.get((x, y), 0) + dl

    def has(self, x, y, parts=None):
        x, y = int(math.floor(x)), int(math.floor(y))
        if not (0 <= x < FW and 0 <= y < FH) or self.part[y][x] is None:
            return False
        return parts is None or self.part[y][x] in parts

    def put(self, x, y, col, force=False):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < FW and 0 <= y < FH and (force or self.part[y][x] is not None):
            self.ov[(x, y)] = col

    def render(self):
        lev = [[0] * FW for _ in range(FH)]
        for y in range(FH):
            for x in range(FW):
                if self.part[y][x] is not None:
                    lev[y][x] = shade_level(self.shd[y][x], x, y)
        cast = [[False] * FW for _ in range(FH)]
        for y in range(FH):
            for x in range(FW):
                g = self.grp[y][x]
                if g is None:
                    continue
                for dx, dy in ((-1, -1), (0, -1), (-1, 0)):
                    qx, qy = x + dx, y + dy
                    if 0 <= qx < FW and 0 <= qy < FH and self.grp[qy][qx] is not None:
                        gq = self.grp[qy][qx]
                        if self.z[qy][qx] > self.z[y][x]:
                            if (gq != g and (gq, g) not in NOCAST) or \
                               (self.part[y][x] in self.selfcast and self.part[qy][qx] == self.part[y][x]):
                                cast[y][x] = True
        img = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
        pix = img.load()
        for y in range(FH):
            for x in range(FW):
                p = self.part[y][x]
                if p is None:
                    continue
                L = lev[y][x] + self.dl.get((x, y), 0)
                if cast[y][x]:
                    L = min(L, lev[y][x] - 1, 0)
                L = max(-2, min(1, L))
                idx = 3 + L
                edge = False
                inner = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    qx, qy = x + dx, y + dy
                    if not (0 <= qx < FW and 0 <= qy < FH) or self.part[qy][qx] is None:
                        edge = True
                        break
                    q = self.part[qy][qx]
                    if q != p and self.z[qy][qx] < self.z[y][x]:
                        g, gq = self.grp[y][x], self.grp[qy][qx]
                        if (g, gq) not in NOLINE and g != gq and (x, y) not in self.noline:
                            inner = True
                if edge or inner:
                    idx = 0
                pix[x, y] = RAMPS[self.mat[y][x]][idx] + (255,)
        for (x, y), col in self.ov.items():
            pix[x, y] = col + (255,)
        return img


def seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay
    l2 = vx * vx + vy * vy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / l2))
    qx, qy = ax + t * vx, ay + t * vy
    return math.hypot(px - qx, py - qy), t


def shade_level(sh, x, y):
    px, py = x + 0.5, y + 0.5
    k = sh[0]
    off = 0.0
    if k == 'flat':
        return sh[1]
    if k == 'sph':
        cx, cy, rx, ry = sh[1:5]
        off = sh[5] if len(sh) > 5 else 0.0
        nx, ny = (px - cx) / rx, (py - cy) / ry
    elif k == 'cyl':
        _, ax, ay, bx, by, r = sh
        vx, vy = bx - ax, by - ay
        l2 = vx * vx + vy * vy
        t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / l2))
        qx, qy = ax + t * vx, ay + t * vy
        nx, ny = (px - qx) / r, (py - qy) / r
    elif k == 'vcyl':
        cx, hw, tilt = sh[1:4]
        off = sh[4] if len(sh) > 4 else 0.0
        nx, ny = (px - cx) / hw, tilt
    else:
        raise ValueError(k)
    d = nx * nx + ny * ny
    if d > 1:
        s = 1 / math.sqrt(d)
        nx, ny, d = nx * s, ny * s, 1.0
    nz = math.sqrt(max(0.0, 1 - d))
    i = nx * LX + ny * LY + nz * LZ + off
    if i >= 0.86:
        return 1
    if i >= 0.36:
        return 0
    if i >= -0.02:
        return -1
    return -2


# ---------------------------------------------------------------- 四位
CHARS = {
    '09': dict(name='奶奶', H=77, extra=2, sex='f', skin='skin_old', hair='hair_silver', hair_style='bun',
               top='jacket_plum', bottom='skirt_grey', shoe='shoe_black', sleeve='long', skirt=True,
               leg_mat='sock', hem_drop=9, flare=1.4, jacket_frac=0.62,
               sw=23, hipw=23, face_rx=11.5, arm_r=3.3, leg_r=3.2, belly=0, idle_arms='clasp'),
    '10': dict(name='爷爷', H=80, extra=0, sex='m', skin='skin_old', hair='hair_grey', hair_style='swept',
               top='suit', bottom='suit_pants', shoe='shoe_brown', sleeve='long', skirt=False,
               sw=24, hipw=22, face_rx=11.5, arm_r=3.4, leg_r=3.5, belly=0, idle_arms='down'),
    '05': dict(name='叔叔', H=84, extra=3, sex='m', skin='skin', hair='hair_curl', hair_style='afro',
               top='shirt_cream', bottom='pants_dark', shoe='shoe_brown', sleeve='short', skirt=False,
               sw=28, hipw=27, face_rx=13.0, arm_r=4.0, leg_r=4.0, belly=3.2, idle_arms='down'),
    '06': dict(name='阿姨', H=81, extra=1, sex='f', skin='skin', hair='hair_bob', hair_style='bob',
               top='sweater_mauve', bottom='skirt_black', shoe='shoe_black', sleeve='long', skirt=True,
               leg_mat='skirt_black', hem_drop=8, flare=1.5, jacket_frac=0.70,
               sw=24, hipw=24, face_rx=11.5, arm_r=3.4, leg_r=3.1, belly=1.2, idle_arms='clasp'),
    # ---------------- charcode02 新画的 7 位（照 GPT 的 chr_LM-GUEST-xx 配性别、发型、衣服颜色、体型）
    '01': dict(name='青年', H=84, extra=2, sex='m', skin='skin', hair='hair_brown', hair_style='messy',
               top='jacket_teal', bottom='pants_dark', shoe='shoe_brown', sleeve='long', skirt=False, coat=6,
               sw=24, hipw=23, face_rx=11.5, arm_r=3.4, leg_r=3.3, belly=0, idle_arms='down',
               face2=dict(eye='m', iris=('iris_dk', 'iris'), brow=None)),
    '02': dict(name='红裙', H=83, extra=4, sex='f', skin='skin', hair='hair_curl', hair_style='updo',
               top='dress_wine', bottom='dress_wine', shoe='shoe_black', sleeve='none', skirt=True,
               leg_mat='dress_wine', hem_drop=2, flare=2.6, jacket_frac=0.50, shawl=True,
               sw=22, hipw=20, face_rx=11.2, arm_r=3.0, leg_r=2.9, belly=0, idle_arms='clasp',
               face2=dict(eye='f', iris=('iris_dk', 'iris'), brow='thin')),
    '03': dict(name='针织', H=80, extra=1, sex='f', skin='skin', hair='hair_chestnut', hair_style='wavy',
               top='knit_beige', bottom='skirt_black', shoe='shoe_black', sleeve='long', skirt=True,
               leg_mat='skin', hem_drop=12, flare=1.2, jacket_frac=0.80,
               sw=23, hipw=22, face_rx=11.5, arm_r=3.5, leg_r=2.9, belly=0, idle_arms='clasp',
               face2=dict(eye='f', iris=('iris_dk', 'iris'), brow=None)),
    '04': dict(name='白衬衫', H=82, extra=1, sex='m', skin='skin', hair='hair_curl', hair_style='crew',
               top='collar_white', bottom='suit', shoe='shoe_brown', sleeve='rolled', skirt=False, tuck=8,
               sw=26, hipw=24, face_rx=11.8, arm_r=3.7, leg_r=3.7, belly=0, idle_arms='down',
               face2=dict(eye='m', iris=('iris_b', 'iris_b2'), brow='thick')),
    '08': dict(name='背带裤', H=79, extra=1, sex='f', skin='skin', hair='hair_black', hair_style='pigtails',
               top='shirt_cream', bottom='overall_green', shoe='shoe_brown', sleeve='short', skirt=False, overall=True,
               sw=21, hipw=20, face_rx=11.0, arm_r=2.9, leg_r=3.0, belly=0, idle_arms='clasp',
               face2=dict(eye='f', iris=('iris_dk', 'iris'), brow=None)),
    # 小孩：头 = 0.46 × 身高（大人 0.38），腿短一点，鞋矮一格，走路幅度 ×0.65；颗粒、描边、光照跟大人一家
    '11': dict(name='女孩', H=53, extra=1, sex='f', skin='skin', hair='hair_brown', hair_style='braids',
               top='jacket_teal', bottom='jacket_teal', shoe='shoe_black', sleeve='long', skirt=True,
               leg_mat='shirt_cream', hem_drop=10, flare=3.6, jacket_frac=0.50,
               sw=16, hipw=15, face_rx=9.6, arm_r=2.5, leg_r=2.3, belly=0.6, idle_arms='clasp',
               kid=True, head_frac=0.46, leg_frac=0.25, shoe_h=3, ks=0.65, neck_r=3.0,
               face2=dict(eye='k', iris=('iris_dk', 'iris'), brow=None, mouth='grin')),
    '12': dict(name='男孩', H=54, extra=2, sex='m', skin='skin', hair='hair_curl', hair_style='messy',
               top='suit_navy', bottom='suit_navy', shoe='shoe_brown', sleeve='long', skirt=False,
               sw=17, hipw=16, face_rx=9.6, arm_r=2.6, leg_r=2.5, belly=0, idle_arms='down',
               kid=True, head_frac=0.46, leg_frac=0.27, shoe_h=3, ks=0.65, neck_r=3.0,
               face2=dict(eye='k', iris=('iris_dk', 'iris'), brow=None)),
}
OLD4 = ('09', '10', '05', '06')                        # charcode01 已画、已进游戏
NEW7 = ('01', '02', '03', '04', '08', '11', '12')      # 这次画的
ALL11 = ('01', '02', '03', '04', '05', '06', '08', '09', '10', '11', '12')


def geom(P):
    H, extra = P['H'], P['extra']
    Hb = H - extra
    g = {}
    g['top'] = FH - Hb                       # 头发顶（不算发髻、爆炸头多出来那截）
    g['head_h'] = int(P.get('head_frac', 0.38) * Hb + 0.5)       # 头身比大人统一 0.38；小孩 0.46
    g['chin'] = g['top'] + g['head_h'] - 1
    g['sh'] = g['chin'] + 1                  # 肩线
    g['leg'] = int(P.get('leg_frac', 0.27) * Hb + 0.5)          # 腿连鞋
    g['crotch'] = FH - g['leg']
    g['hip'] = g['crotch'] - 3               # 胯关节
    g['shoe_h'] = P.get('shoe_h', 4)
    g['fcy'] = g['chin'] - round(g['head_h'] * 0.42)
    g['fry'] = g['head_h'] * 0.5
    g['eye'] = g['chin'] - round(g['head_h'] * 0.37)
    g['arm_len'] = round((g['crotch'] - g['sh']) * 0.80)
    # 坐：大腿水平、小腿垂下、脚踩格子最后一行
    g['ankle'] = FOOT - g['shoe_h'] + 1
    g['shin'] = int(g['leg'] * 0.40 + 0.5)
    g['knee_sit'] = g['ankle'] - g['shin']
    g['hip_sit'] = g['knee_sit']
    g['sit_dy'] = g['hip_sit'] - g['hip']
    g['seat'] = g['hip_sit'] + int(P['leg_r'] + 0.5)   # 屁股底 / 大腿底那一行 = 坐垫面
    return g


def leg_mat(P):
    return P.get('leg_mat', P['bottom'])


def torso_hem(P, g, sh, crotch):
    if P['skirt']:
        return sh + round((crotch - sh) * P['jacket_frac'])
    if P.get('coat'):                     # 长外套：盖过胯往下
        return crotch + P['coat']
    if P.get('tuck'):                     # 衬衫扎进裤子：衣摆在皮带那
        return crotch - P['tuck']
    return crotch - 1


def hips_top(P, crotch):
    """裤子（胯那块）从哪一行起：扎衬衫的从皮带起，别的照旧 crotch-7"""
    if P.get('tuck'):
        return crotch - P['tuck'] - 1
    return crotch - 7


# ---------------------------------------------------------------- 正面 / 背面 站着走
def draw_front(F, P, pose, back=False):
    g = geom(P)
    bob = pose.get('bob', 0)
    sh = g['sh'] + bob
    crotch = g['crotch'] + bob
    legr = P['leg_r']
    bot, shoe = P['bottom'], P['shoe']
    # 腿 + 鞋
    for side in (-1, 1):
        dx, lift = pose['lf'] if side < 0 else pose['rf']
        if back:
            # 背面：左右对调（角色的左腿在画面右边），保证跟正面同一节奏
            dx, lift = (pose['rf'] if side < 0 else pose['lf'])
        hipx = CX + side * (legr + 0.2)
        fx = hipx + dx
        fy = FOOT - lift
        ank = fy - g['shoe_h'] + 1
        F.capsule(hipx, g['hip'] + bob - 1, fx, ank - 0.5, legr + 0.2, legr - 0.3, 'leg%d' % side, 'leg', leg_mat(P))
        sy = fy - 1.6
        F.ellipse(fx + side * 0.5, sy, legr + 1.1, 2.5, 'shoe%d' % side, 'shoe', shoe,
                  shd=('sph', fx + side * 0.5 - 0.5, sy - 2.5, legr + 2, 4.5), p=2.4)
    if not P['skirt']:
        F.rows(hips_top(P, crotch), crotch + 1.5, lambda y: P['hipw'] / 2 - 0.3, 'hips', 'leg', bot,
               ('vcyl', CX, P['hipw'] / 2 + 1.5, -0.1))
        for y in range(int(crotch) + 0, int(crotch) + 2):
            F.recolor(CX - 0.5, y, dl=-2)
        if P.get('tuck'):
            belt_front(F, P, hips_top(P, crotch), back)
    else:
        draw_skirt_front(F, P, g, sh, crotch, bob, pose, back=back)
    draw_torso_front(F, P, g, sh, torso_hem(P, g, sh, crotch), back)
    if P.get('shawl'):
        shawl_front(F, P, pose, g, sh, crotch, back)
    draw_front_arms(F, P, pose, g, sh, back)
    draw_head_front(F, P, g, bob + pose.get('head_dy', 0), back, pose)


def draw_skirt_front(F, P, g, sh, crotch, bob, pose, hem=None, back=False):
    waist = sh + round((crotch - sh) * 0.50)
    if hem is None:
        hem = FOOT - P['hem_drop'] + bob
    flare = P['flare']
    hw = P['hipw'] / 2
    sw_ = 0.0
    if 'lf' in pose:
        sw_ = (pose['lf'][1] - pose['rf'][1]) * 0.25    # 走路时裙摆往迈出去的那边摆一点
    def half(y):
        t = (y - waist) / max(1, hem - waist)
        w = hw - 0.5 + flare * t
        return (w - sw_ * t, w + sw_ * t)
    F.rows(waist, hem + 0.5, half, 'skirt', 'skirt', P['bottom'], ('vcyl', CX - 1, hw + flare + 1, 0.05))
    if P['name'] == '奶奶':   # 百褶：竖的暗线
        for y in range(int(waist) + 3, int(hem) + 1):
            for xx in (-8, -4, 0, 4, 8):
                F.recolor(CX + xx + 0.5, y, dl=-1, only=('skirt',))
    if 'face2' in P:
        skirt_details_front(F, P, waist, hem, back)


def draw_torso_front(F, P, g, sh, hem_y, back):
    sw, hipw, belly = P['sw'], P['hipw'], P['belly']
    def thalf(y):
        t = (y - sh) / max(1, hem_y - sh)
        if y < sh + 1:
            return sw / 2 - 4.0
        if y < sh + 2:
            return sw / 2 - 1.8
        if y < sh + 3:
            return sw / 2 - 0.6
        b = sw / 2 + belly * math.sin(min(1.0, t * 1.1) * math.pi * 0.85)
        if P['sex'] == 'f' and not belly:
            b -= 0.8 * math.sin(min(1.0, t) * math.pi)       # 一点点腰
        return b + (hipw / 2 - sw / 2) * t
    cr = g['crotch'] + (sh - g['sh'])
    if P.get('coat') and hem_y > cr:
        coat_fill(F, P, sh, hem_y, cr, thalf, back)
    else:
        F.rows(sh, hem_y + 0.5, thalf, 'torso', 'torso', P['top'], ('vcyl', CX - 0.5, sw / 2 + belly + 1.5, -0.12))
    F.rows(sh - 1, sh - 0.01, lambda y: sw / 2 - 5.5, 'torso', 'torso', P['top'], ('flat', -1))
    torso_details(F, P, g, sh, hem_y, back)


def front_arm_targets(P, pose, g, sh, side, back):
    ar = P['arm_r']
    sx = CX + side * (P['sw'] / 2 - 1.0)
    sy = sh + ar - 0.2
    L = g['arm_len']
    mode = pose.get('arms', 'free')
    s = pose.get('la', 0) if side < 0 else pose.get('ra', 0)
    if back:
        s = pose.get('ra', 0) if side < 0 else pose.get('la', 0)
        s = -s
    if mode == 'clasp' and not back:
        ex, ey = sx + side * 1.6, sy + L * 0.50
        hx_, hy_ = CX + side * 2.2, sy + L * 0.78
    elif mode == 'lap':
        ex, ey = sx + side * 1.4, sy + L * 0.48
        hx_, hy_ = CX + side * 5.0, sy + L * 0.82
    elif mode == 'talk' and side == pose.get('talk_side', 1) and not back:
        ex, ey = sx + side * 2.2, sy + L * 0.52
        hx_, hy_ = sx - side * 2.4, sy + L * pose.get('talk_h', 0.25)
    else:
        fwd, bk = max(s, 0), max(-s, 0)
        if P.get('ks') is None:
            hx_ = sx + side * (1.3 - 2.6 * fwd + 1.0 * bk)
            hy_ = sy + L + 1.6 * fwd - 3.6 * bk
        else:                                   # 小孩：摆幅照 ks 缩
            k = P['ks']
            hx_ = sx + side * (1.3 - 2.6 * fwd * k + 1.0 * bk * k)
            hy_ = sy + L + (1.6 * fwd - 3.6 * bk) * k
        ex, ey = (sx + hx_) / 2 + side * 0.9, (sy + hy_) / 2
    return sx, sy, ex, ey, hx_, hy_


def draw_arm(F, P, which, grp, sx, sy, ex, ey, hx_, hy_, hand_shift=(0, 0)):
    ar = P['arm_r']
    top, skin = P['top'], P['skin']
    if P['sleeve'] == 'short':
        mx, my = sx + (ex - sx) * 0.75, sy + (ey - sy) * 0.75
        F.capsule(mx, my, ex, ey, ar - 0.35, ar - 0.4, 'farm' + which, grp, skin)
        F.capsule(ex, ey, hx_, hy_ - 1.0, ar - 0.4, ar - 0.6, 'farm' + which, grp, skin)
        F.capsule(sx, sy, mx, my, ar + 0.1, ar + 0.3, 'uarm' + which, grp, top)
    elif P['sleeve'] == 'none':             # 无袖：整只胳膊是皮肤
        F.capsule(sx, sy, ex, ey, ar - 0.2, ar - 0.35, 'uarm' + which, grp, skin)
        F.capsule(ex, ey, hx_, hy_ - 1.0, ar - 0.35, ar - 0.5, 'farm' + which, grp, skin)
    elif P['sleeve'] == 'rolled':           # 卷到手肘的袖子
        F.capsule(ex, ey, hx_, hy_ - 1.0, ar - 0.4, ar - 0.6, 'farm' + which, grp, skin)
        mx, my = sx + (ex - sx) * 1.08, sy + (ey - sy) * 1.08
        F.capsule(sx, sy, mx, my, ar + 0.2, ar + 0.45, 'uarm' + which, grp, top)
    else:
        F.capsule(sx, sy, ex, ey, ar, ar - 0.15, 'uarm' + which, grp, top)
        F.capsule(ex, ey, hx_, hy_ - 1.2, ar - 0.15, ar - 0.3, 'farm' + which, grp, top)
    hx2, hy2 = hx_ + hand_shift[0], hy_ + hand_shift[1] + 0.6
    F.ellipse(hx2, hy2, ar - 0.2, ar + 0.1, 'hand' + which, 'hand' + which, skin,
              shd=('sph', hx2 - 0.8, hy2 - 1.0, ar + 0.8, ar + 1.0))
    # 袖口
    cx_, cy_ = hx_ + (ex - hx_) * 0.30, hy_ + (ey - hy_) * 0.30
    if P['name'] == '奶奶':
        for d in (-1.5, -0.5, 0.5, 1.5):
            F.recolor(cx_ + d, cy_, mat='trim_gold', only=('farm' + which,))
    if P['name'] == '爷爷':
        F.put(cx_ - 0.5, cy_ + 0.5, RAMPS['collar_white'][3]) if F.has(cx_ - 0.5, cy_ + 0.5, ('farm' + which,)) else None
    if P['name'] == '阿姨':
        for d in (-1.5, -0.5, 0.5, 1.5):
            F.recolor(cx_ + d, cy_, dl=-1, only=('farm' + which,))
    if 'face2' in P:
        arm_details2(F, P, which, sx, sy, ex, ey, hx_, hy_)


def draw_front_arms(F, P, pose, g, sh, back):
    order = (-1, 1)
    for side in order:
        sx, sy, ex, ey, hx_, hy_ = front_arm_targets(P, pose, g, sh, side, back)
        draw_arm(F, P, str(side), 'arm', sx, sy, ex, ey, hx_, hy_)


def torso_details(F, P, g, sh, hem_y, back):
    sh, hem_y = int(round(sh)), int(round(hem_y))
    nm = P['name']
    c = int(CX)
    T = ('torso',)
    if nm == '奶奶':
        if not back:
            # 白衬衫领子（V 领里露出来）＋ 金滚边
            for i in range(0, 7):
                w = max(0, 3 - i // 2)
                for x in range(c - w, c + w):
                    F.px(x, sh + i, 'collar', 'collar', 'collar_white', ('flat', 0 if x < c else -1))
            for i in range(0, 7):
                w = max(0, 3 - i // 2)
                F.recolor(c - w - 1, sh + i, mat='trim_gold', only=T)
                F.recolor(c + w, sh + i, mat='trim_gold', only=T)
            for y in range(sh + 7, hem_y + 1):
                F.recolor(c - 1, y, mat='trim_gold', only=T)
                F.recolor(c, y, dl=-1, only=T)
            for x in range(c - 13, c + 13):
                F.recolor(x, hem_y - 1, mat='trim_gold', dl=-1, only=T)
            # 两边绣的小花枝
            for (ox, oy) in ((-7, -5), (5, -5)):
                for (dx, dy) in ((0, 0), (1, 0), (0, -1), (1, 1), (-1, 1), (2, -1)):
                    F.recolor(c + ox + dx, hem_y + oy + dy, mat='trim_gold', dl=-1, only=T)
        else:
            cy = sh + 10
            for (dx, dy) in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1), (-2, -2), (2, -2), (-2, 2), (2, 2),
                             (0, -3), (0, 3), (-1, 4), (1, 4)):
                F.recolor(c + dx, cy + dy, mat='trim_gold', dl=-1, only=T)
            for x in range(c - 13, c + 13):
                F.recolor(x, hem_y - 1, mat='trim_gold', dl=-1, only=T)
    elif nm == '爷爷':
        if not back:
            for x in range(c - 4, c + 4):          # 立领
                F.recolor(x, sh, dl=1, only=T)
                F.recolor(x, sh + 1, dl=-1, only=T)
            for y in range(sh + 2, hem_y + 1):     # 中缝 + 铜扣
                F.recolor(c, y, dl=-2, only=T)
            for k in range(5):
                F.put(c - 1, sh + 3 + k * 5, RAMPS['brass'][3])
                F.put(c - 1, sh + 4 + k * 5, RAMPS['brass'][1])
            for (x0, y0, w) in ((c - 10, sh + 8, 6), (c + 4, sh + 8, 6), (c - 11, sh + 18, 7), (c + 4, sh + 18, 7)):
                for x in range(x0, x0 + w):
                    F.recolor(x, y0, dl=-2, only=T)
                    F.recolor(x, y0 + 1, dl=1, only=T)
                F.put(x0 + w // 2, y0 + 1, RAMPS['brass'][2]) if F.has(x0 + w // 2, y0 + 1, T) else None
        else:
            for x in range(c - 5, c + 5):
                F.recolor(x, sh, dl=1, only=T)
                F.recolor(x, sh + 1, dl=-1, only=T)
            for y in range(sh + 12, hem_y + 1):
                F.recolor(c, y, dl=-1, only=T)
    elif nm == '叔叔':
        if not back:
            for i in range(0, 6):                  # 敞开的 V 领露脖子
                w = max(0.0, 3.2 - i * 0.6)
                for x in range(int(c - w), int(c + w)):
                    F.px(x, sh + i, 'neck', 'neck', 'skin', ('flat', -1 if i < 2 else 0))
            for i in range(0, 6):                  # 翻领
                w = int(max(0.0, 3.2 - i * 0.6))
                for d in (1, 2):
                    F.recolor(c - w - d, sh + i, dl=1, mat='shirt_cream', only=T)
                    F.recolor(c + w - 1 + d, sh + i, dl=1, mat='shirt_cream', only=T)
            for y in range(sh + 6, hem_y):          # 门襟
                F.recolor(c, y, dl=-1, only=T)
    elif nm == '阿姨':
        if not back:
            for x in range(c - 4, c + 4):
                F.recolor(x, sh + 1, dl=-1, only=T)
        for x in range(c - 16, c + 16):
            F.recolor(x, hem_y, dl=-1, only=T)
            if x % 2 == 0:
                F.recolor(x, hem_y - 1, dl=-1, only=T)
    elif 'face2' in P:
        torso_details2(F, P, g, sh, hem_y, back)


# 叔叔的花衬衫：手画的一块 12×12 花样，错开铺满
FLORAL = [
    '.RR...G.....',
    'RYRR.GG..OO.',
    'RRRR.G..OYOO',
    '.RR.G....OO.',
    '..G.......G.',
    'G......Y..G.',
    '.GG...YYY...',
    '..OO...Y..RR',
    '.OYOO.G..RRRR',
    '..OO..GG.RYRR',
    'G.......G.RR.',
    'GG..Y....G...',
]
FLORAL_MAT = {'R': 'flower_red', 'O': 'flower_orange', 'Y': 'flower_yellow', 'G': 'leaf_green'}


def floral(F, u0, v0):
    for y in range(FH):
        for x in range(FW):
            if F.mat[y][x] != 'shirt_cream' or F.part[y][x] == 'neck':
                continue
            u = int(x - u0) % 12
            v = int(y - v0) % 12
            row = FLORAL[v]
            ch = row[u] if u < len(row) else '.'
            if ch in FLORAL_MAT:
                F.mat[y][x] = FLORAL_MAT[ch]


# ---------------------------------------------------------------- 头（正面 / 背面）
def face_test(P, g, dy):
    top = g['top'] + dy
    chin = g['chin'] + dy
    fcy = g['fcy'] + dy
    frx = P['face_rx']
    def t(px, py):
        dx = abs(px - CX) / frx
        if py < fcy:
            dyv = (fcy - py) / (fcy - top + 0.5)
            return dx ** 2.4 + dyv ** 2.4 <= 1
        dyv = (py - fcy) / (chin + 1 - fcy)
        return dx ** 2.1 + dyv ** 2.5 <= 1
    return t


def face_shd(P, g, dy):
    return ('sph', CX - 3.5, g['fcy'] + dy - 4, P['face_rx'] * 1.6, g['fry'] * 1.6, 0.06)


def draw_head_front(F, P, g, dy, back, pose):
    skin = P['skin']
    top = g['top'] + dy
    chin = g['chin'] + dy
    frx = P['face_rx']
    ear_y = g['eye'] + dy + 2.5
    for side in (-1, 1):
        F.ellipse(CX + side * (frx + 0.1), ear_y, 1.9, 2.5, 'ear%d' % side, 'ear', skin, shd=('flat', 0))
    ft = face_test(P, g, dy)
    if back:
        nr = P.get('neck_r', 3.8)
        F.capsule(CX, chin - 4, CX, chin + 1, nr, nr, 'neck', 'neck', skin, ('flat', -1))
        F.fill(lambda px, py: ft(px, py) and py < chin - 2.5, (CX - frx, top, CX + frx, chin + 1),
               'face', 'face', skin, ('flat', 0))
    else:
        F.fill(ft, (CX - frx, top, CX + frx, chin + 1), 'face', 'face', skin, ('flat', 0))
    hair_front(F, P, g, dy, back)
    for side in (-1, 1):
        x = CX + side * (frx + 0.6) - 0.5
        if F.has(x, ear_y, ('ear%d' % side,)):
            F.put(x, ear_y, RAMPS[skin][2])
    if not back:
        face_crescent(F, g['eye'] + dy - 3, chin)
        face_features_front(F, P, g, dy, pose)


def redo_face(F, P, g, dy):
    """擦掉额头那块头发以后，把脸补回来（只补空着的像素）"""
    t = face_test(P, g, dy)
    top, chin = g['top'] + dy, g['chin'] + dy
    frx = P['face_rx']
    for y in range(max(0, int(top)), int(chin) + 2):
        for x in range(int(CX - frx - 1), int(CX + frx + 1)):
            if F.part[y][x] is None and t(x + 0.5, y + 0.5):
                F.part[y][x] = 'face'
                F.grp[y][x] = 'face'
                F.mat[y][x] = P['skin']
                F.shd[y][x] = ('flat', 0)
                F.z[y][x] = 1


def strands(F, y0, y1, fn, dl=-1, parts=('hair',)):
    for y in range(max(0, int(y0)), min(FH, int(y1))):
        for x in range(FW):
            if F.has(x, y, parts) and fn(x + 0.5, y + 0.5):
                F.recolor(x, y, dl=dl)


def curls(F, pts, hm, r):
    for (x0, y0, rr) in pts:
        rr = rr or r
        F.ellipse(x0, y0, rr, rr * 0.92, 'hair', 'hair', hm, shd=('sph', x0 - 0.6, y0 - 0.7, rr + 0.5, rr + 0.5, 0.05))


def hair_front(F, P, g, dy, back):
    if P['hair_style'] in HAIR2:
        return hair_front2(F, P, g, dy, back)
    st = P['hair_style']
    hm = P['hair']
    top = g['top'] + dy
    chin = g['chin'] + dy
    frx = P['face_rx']
    eye = g['eye'] + dy
    c = CX
    hshd = ('sph', c - 4, top + 5, frx + 7, 16)
    if st == 'bun':
        if not back:
            F.ellipse(c, top - 0.2, 3.4, 2.6, 'bun', 'hair', hm, shd=('sph', c - 1.5, top - 1.5, 4, 3.5))
            F.ellipse(c, top + 10, frx + 3.0, 10.5, 'hair', 'hair', hm, shd=hshd, p=2.3)
            for side in (-1, 1):
                F.ellipse(c + side * (frx + 0.8), eye, 3.6, 7.2, 'hair', 'hair', hm,
                          shd=('sph', c + side * (frx - 3) - 1.5, eye - 5, 8, 11))
            def fore(px, py):
                return py > top + 9.5 + abs(px - c) * 0.42 and abs(px - c) < frx - 2.0 and py < eye + 4
            F.erase(fore, (c - frx, top, c + frx, eye + 4), only=('hair',))
            redo_face(F, P, g, dy)
            hair_bands(F, lambda px, py: math.atan2(py - (top + 1), px - c) * 10, 2.7, top, eye + 8)
        else:
            def bk(px, py):
                return (abs(px - c) / (frx + 2.2)) ** 2.3 + (abs(py - (top + 11)) / 11.0) ** 2.3 <= 1 or \
                       ((abs(px - c) / (frx + 0.8)) ** 2 + ((py - (top + 13)) / 14.0) ** 2 <= 1 and py < chin - 2)
            F.fill(bk, (c - frx - 4, top, c + frx + 4, chin), 'hair', 'hair', hm, hshd)
            bx, by = c, top + 12
            hair_bands(F, lambda px, py: math.atan2(py - by, px - bx) * 9 + math.hypot(px - bx, py - by) * 0.25, 4.0, top, chin + 1, hi=0.10, lo=0.82)
            F.ellipse(bx, by, 5.8, 5.4, 'bun', 'hairbun', hm, shd=('sph', bx - 2, by - 2, 7, 7))
            hair_bands(F, lambda px, py: math.atan2(py - by, px - bx) * 4 + math.hypot(px - bx, py - by) * 0.6, 2.4,
                       top, chin, parts=('bun',), hi=0.2, lo=0.75)
    elif st == 'swept':
        if not back:
            F.ellipse(c, top + 8, frx + 1.9, 8.6, 'hair', 'hair', hm, shd=hshd, p=2.4)
            for side in (-1, 1):
                F.ellipse(c + side * (frx - 0.2), top + 12.5, 2.8, 4.8, 'hair', 'hair', hm,
                          shd=('sph', c + side * (frx - 3) - 1.5, top + 9, 6, 8))
            def fore(px, py):
                return py > top + 8.5 + (abs(px - c) ** 2) * 0.025 and abs(px - c) < frx - 2.6 and py < eye + 3
            F.erase(fore, (c - frx, top, c + frx, eye + 3), only=('hair',))
            redo_face(F, P, g, dy)
            hair_bands(F, lambda px, py: (px - c) * (1.0 - 0.025 * (py - top)) + 0.4 * (py - top), 2.6, top, top + 18)
        else:
            def bk(px, py):
                return (abs(px - c) / (frx + 1.8)) ** 2.4 + (abs(py - (top + 12)) / 14.5) ** 2.4 <= 1 and py < chin - 1.5
            F.fill(bk, (c - frx - 3, top, c + frx + 3, chin), 'hair', 'hair', hm, hshd)
            hair_bands(F, lambda px, py: (px - c) * (1.0 + 0.03 * (py - top)) + 0.6 * math.sin((py - top) * 0.5), 3.4,
                       top, chin, hi=0.15, lo=0.78)
    elif st == 'afro':
        gsh = ('sph', c - 5, top + 4, frx + 9, 18)
        if not back:
            m = lobed(c, top + 10.6, frx + 3.6, 12.6, 15, 0.13, 0.6)
            F.fill(lambda px, py: m(px, py) and py < eye + 5 - max(0.0, abs(px - c) - frx) * 0.8,
                   (c - frx - 6, top - 3, c + frx + 6, eye + 5), 'hair', 'hair', hm, ('flat', 0))
            def fore(px, py):
                lock = 2.4 * abs(math.sin((px - c + 1.2) * math.pi / 3.7)) ** 0.8
                return py > top + 11.0 + lock + abs(px - c) * 0.16 and abs(px - c) < frx - 1.4 and py < eye + 5
            F.erase(fore, (c - frx, top, c + frx, eye + 5), only=('hair',))
            redo_face(F, P, g, dy)
            curly(F, (c - frx - 6, top - 3, c + frx + 6, eye + 6), 7, gsh)
        else:
            m = lobed(c, top + 12, frx + 3.3, 14.2, 15, 0.12, 0.2)
            F.fill(lambda px, py: m(px, py) and py < chin - 1.5, (c - frx - 6, top - 3, c + frx + 6, chin), 'hair', 'hair', hm, ('flat', 0))
            curly(F, (c - frx - 6, top - 3, c + frx + 6, chin), 8, gsh)
    elif st == 'bob':
        part = c - 3
        def bell(px, py):
            """蓬松的波波头：上面圆、往下慢慢变宽，到下巴往里收一点"""
            if py < top + 11:
                return (abs(px - c) / (frx + 3.0)) ** 2.3 + (abs(py - (top + 11)) / 11.3) ** 2.3 <= 1
            hw = frx + 3.0 + min(1.6, (py - (top + 11)) * 0.12)
            if py > chin - 2:
                hw -= (py - (chin - 2)) * 1.1
            return abs(px - c) <= hw and py <= chin + 1.5
        F.fill(bell, (c - frx - 6, top, c + frx + 6, chin + 2), 'hair', 'hair', hm, ('sph', c - 4, top + 6, frx + 7, 19))
        if not back:
            def win(px, py):
                if px >= part:
                    edge = min(eye - 2.2, eye - 4.4 + (px - part) * 0.30)
                else:
                    edge = eye - 4.4 + (part - px) * 0.50
                return py > edge and abs(px - c) < frx - 2.8 - max(0.0, py - (chin - 4)) * 0.5 and py <= chin + 1.5
            F.erase(win, (c - frx, top, c + frx, chin + 2), only=('hair',))
            redo_face(F, P, g, dy)
            hair_bands(F, lambda px, py: math.atan2(py - (top - 3), px - part) * 13, 3.2, top + 1, chin + 2, hi=0.2, lo=0.74)
            for y in range(int(top) + 1, int(top) + 5):
                F.recolor(part - 0.5 + (y - top) * 0.3, y, dl=-2, only=('hair',))
        else:
            hair_bands(F, lambda px, py: math.atan2(py - (top - 4), px - c) * 14, 3.6, top + 1, chin + 2, hi=0.12, lo=0.80)


def face_features_front(F, P, g, dy, pose):
    if 'face2' in P:
        return face2_front(F, P, g, dy, pose)
    e = g['eye'] + dy
    c = int(CX)
    nm = P['name']
    mouth = pose.get('mouth', 'smile')
    blink = pose.get('blink', False)
    if nm == '叔叔':
        for x0 in (c - 8, c + 4):        # 眯眯笑眼 ∩ ∩
            F.put(x0, e + 1, C['eye'])
            F.put(x0 + 1, e, C['eye'])
            F.put(x0 + 2, e, C['eye'])
            F.put(x0 + 3, e + 1, C['eye'])
        for x0 in (c - 10, c + 7):
            F.put(x0, e + 3, C['blush'])
            F.put(x0 + 1, e + 3, C['blush'])
            F.put(x0 + 2, e + 3, C['blush'])
            F.put(x0 + 1, e + 4, C['blush2'])
        for x0 in (c - 8, c + 4):
            for d in range(4):
                F.put(x0 + d, e - 3 + (1 if d in (0, 3) else 0), C['brow_dark'])
    else:
        if nm == '奶奶':
            eye = ['DDD', 'DWI', '.I.'] if not blink else ['...', 'DDD', '...']
            lx, rx = c - 7, c + 4
        elif nm == '爷爷':
            eye = ['DDD', 'DWI'] if not blink else ['...', 'DDD']
            lx, rx = c - 7, c + 4
        else:
            eye = ['DDD', 'WIJ', 'IIJ'] if not blink else ['...', 'DDD', '...']
            lx, rx = c - 7, c + 4
        cmap = {'D': C['eye'], 'W': C['eye_hl'], 'I': C['iris'], 'J': C['iris2']}
        for x0 in (lx, rx):
            for j, row in enumerate(eye):
                for i, ch in enumerate(row):
                    if ch in cmap:
                        F.put(x0 + i, e + j, cmap[ch])
        if nm == '爷爷':
            for x0 in (lx - 1, rx):
                for d in range(4):
                    F.put(x0 + d, e - 2, RAMPS['hair_grey'][1])
                    F.put(x0 + d, e - 3, RAMPS['hair_grey'][2] if d else RAMPS['hair_grey'][1])
        elif nm == '奶奶':
            for x0 in (lx, rx):
                for d in range(3):
                    F.put(x0 + d, e - 2 + (1 if (x0 == lx and d == 0) or (x0 == rx and d == 2) else 0), RAMPS['hair_silver'][1])
        for x0 in (c - 10, c + 7):
            F.put(x0, e + 3, C['blush'])
            F.put(x0 + 1, e + 3, C['blush'])
            F.put(x0 + 2, e + 3, C['blush'])
    F.put(c, e + 4, RAMPS[P['skin']][2])     # 鼻子
    my = e + 7
    if mouth == 'open':
        for d in (-2, -1, 0, 1):
            F.put(c + d, my, C['mouth_dk'])
        F.put(c - 2, my + 1, C['mouth_dk'])
        F.put(c + 1, my + 1, C['mouth_dk'])
        F.put(c - 1, my + 1, C['tongue'])
        F.put(c, my + 1, C['tongue'])
        if nm == '叔叔':
            F.put(c - 3, my, C['mouth_dk'])
            F.put(c + 2, my, C['mouth_dk'])
            for d in (-2, -1, 0, 1):
                F.put(c + d, my, C['teeth'])
            F.put(c - 1, my + 2, C['mouth_dk'])
            F.put(c, my + 2, C['mouth_dk'])
    else:
        F.put(c - 2, my - 1, C['mouth'])
        F.put(c - 1, my, C['mouth'])
        F.put(c, my, C['mouth'])
        F.put(c + 1, my - 1, C['mouth'])
        if nm == '叔叔':
            F.put(c - 3, my - 1, C['mouth'])
            F.put(c + 2, my - 1, C['mouth'])
    if nm == '奶奶':
        F.put(c - 9, e + 1, C['wrinkle'])
        F.put(c + 8, e + 1, C['wrinkle'])
        F.put(c - 4, my, C['wrinkle'])
        F.put(c + 3, my, C['wrinkle'])
    if nm == '爷爷':
        F.put(c - 4, my - 1, C['wrinkle'])
        F.put(c + 3, my - 1, C['wrinkle'])
        F.put(c - 4, my, C['wrinkle'])
        F.put(c + 3, my, C['wrinkle'])
        for d in (-2, -1, 0, 1):
            F.put(c + d, e - 6, C['wrinkle'])
    if nm == '阿姨':
        for ex in (c - 5.5, c + 5.5):    # 圆眼镜
            cy = e + 1.5
            for yy in range(e - 5, e + 8):
                for xx in range(int(ex) - 6, int(ex) + 7):
                    d = math.hypot(xx + 0.5 - ex, yy + 0.5 - cy)
                    if 3.6 <= d < 4.6:
                        F.put(xx, yy, C['glass'])
            F.put(ex - 2.5, e - 1, C['lens_hl'])
        F.put(c - 1, e + 1, C['glass'])
        F.put(c, e + 1, C['glass'])


# ---------------------------------------------------------------- 侧面
def draw_side(F, P, pose, f):
    """f = -1 朝左，+1 朝右。所有 x 用 sx(u) 换算：u 往脸朝的方向为正"""
    g = geom(P)
    def sx(u):
        return CX + f * u
    sit = pose.get('kind') == 'sit'
    bob = pose.get('bob', 0)
    dy_body = bob + (g['sit_dy'] if sit else 0)
    sh = g['sh'] + dy_body
    crotch = g['crotch'] + dy_body
    hip = g['hip'] + dy_body
    legr = P['leg_r']
    ar = P['arm_r']
    depth = P['sw'] * 0.80
    belly = P['belly']
    shoe = P['shoe']
    lm = leg_mat(P)

    def shoe_side(which, u, fy):
        F.ellipse(sx(u + 1.4), fy - 1.7, legr + 2.2, 2.5, 'shoe' + which, 'shoe' + which, shoe, p=2.6,
                  shd=('sph', sx(u + 1.4) - 1.0, fy - 4.0, legr + 3, 4.5))

    def leg(which, fdx, lift, bend):
        hipx = sx(-0.8)
        fy = FOOT - lift
        ank_y = fy - g['shoe_h'] + 1
        ax_ = sx(fdx)
        kx = sx((fdx - 0.8) / 2 + bend)
        ky = (hip + ank_y) / 2 - abs(bend) * 0.4
        F.capsule(hipx, hip - 1, kx, ky, legr + 0.4, legr + 0.1, 'thigh' + which, 'leg' + which, lm)
        F.capsule(kx, ky, ax_, ank_y - 0.5, legr + 0.1, legr - 0.3, 'shin' + which, 'leg' + which, lm)
        shoe_side(which, fdx, fy)

    knee_u = depth / 2 + 5.0
    hyc = g['hip_sit'] + 0.0

    def sit_leg(which, du):
        thigh_mat = P['bottom'] if P['skirt'] else lm
        kx = sx(knee_u + du)
        F.capsule(sx(-1.0 + du * 0.5), hyc, kx, hyc - 0.3, legr + 0.6, legr + 0.4, 'thigh' + which, 'leg' + which, thigh_mat)
        F.capsule(kx, hyc, sx(knee_u + du - 0.4), g['ankle'] - 0.5, legr + 0.1, legr - 0.3, 'shin' + which, 'leg' + which, lm)
        shoe_side(which, knee_u + du - 0.4, FOOT)

    def arm(which, s, grp):
        shx, shy = sx(-0.6), sh + ar
        L = g['arm_len']
        if sit:
            ex, ey = sx(1.4), shy + L * 0.50
            hx_, hy_ = sx(depth / 2 + 3.2), hyc - legr - 0.5 + bob * 0
        else:
            reach = 7.8 if which == 'f' else depth / 2 + 3.0     # 远的那只手往前摆时从胸前露出来
            if P.get('ks') is None:
                hx_ = sx(s * reach)
                hy_ = shy + L - abs(s) * 2.2
                ex = sx(s * 2.8 + (1.6 if s > 0 else 0.3))
            else:                               # 小孩：摆幅照 ks 缩
                k = P['ks']
                hx_ = sx(s * reach * k)
                hy_ = shy + L - abs(s) * 2.2 * k
                ex = sx((s * 2.8 + (1.6 if s > 0 else 0.3)) * k)
            ey = shy + L * 0.5
        if P.get('shawl') and not sit:
            shawl_side(F, P, which, sx, f, ex, ey, hx_, hy_)
        draw_arm(F, P, which, grp, shx, shy, ex, ey, hx_, hy_)

    if not sit:
        arm('b', pose['fa'], 'armb')
        leg('b', *pose['fl'])
        leg('f', *pose['nl'])
        if not P['skirt']:
            hr_ = depth / 2 - 0.5 if not P.get('tuck') else depth / 2 - 2.2   # 扎衬衫的：胯别比腿宽太多（像瓶子）
            F.capsule(sx(-0.8), hips_top(P, crotch), sx(-0.8), crotch - 3, hr_, hr_, 'hips', 'legf', P['bottom'],
                      ('vcyl', CX - f * 1.0, depth / 2 + 2, -0.1))
            if P.get('tuck'):
                belt_side(F, P, hips_top(P, crotch), sx, f, depth)
    else:
        sit_leg('b', -1.4)
        # 屁股：底跟大腿底齐
        F.ellipse(sx(-1.2), hyc - 0.5, depth / 2 + 0.2, legr + 1.0, 'hips', 'legf', P['bottom'],
                  shd=('sph', sx(-1.2) - 2.5, hyc - 4, depth / 2 + 4, legr + 5))
        sit_leg('f', 0.0)
    # 裙子
    if P['skirt']:
        waist = sh + round((crotch - sh) * 0.50)
        flare = P['flare']
        if not sit:
            hem = FOOT - P['hem_drop'] + bob
            swing = pose['nl'][0] - pose['fl'][0]
            def sk(px, py):
                if py < waist or py > hem + 0.5:
                    return False
                t = (py - waist) / max(1, hem - waist)
                fr_ = depth / 2 + 0.3 + flare * t + abs(swing) * 0.30 * t
                bk_ = depth / 2 + 0.3 + flare * t + abs(swing) * 0.20 * t
                u = (px - CX) * f + 0.8
                return -bk_ <= u <= fr_
            F.fill(sk, (0, waist, FW, hem + 1), 'skirt', 'skirt', P['bottom'], ('vcyl', CX - f * 1.5, depth / 2 + 4, 0.05))
            if 'face2' in P:
                skirt_details_side(F, P, waist, hem, sx, f, depth, False)
            if P['name'] == '奶奶':
                for y in range(int(waist) + 3, int(hem) + 1):
                    for uu in (-5, -1, 3, 7):
                        F.recolor(sx(uu), y, dl=-1, only=('skirt',))
        else:
            bottom = hyc + legr + 0.5
            u0, u1 = -depth / 2 - 1.5, knee_u + 2.4
            lap_c, lap_r = (u0 + u1) / 2, (u1 - u0) / 2
            lap_y0 = hyc - legr - 1.5
            def sk(px, py):
                u = (px - CX) * f + 0.8
                if py < waist or py > bottom + 1.5:
                    return False
                if py < lap_y0 + 2:
                    return -depth / 2 - 0.5 <= u <= depth / 2 + 1
                # 腿上那块：圆角，膝盖前面往下垂一点
                ry = (bottom - lap_y0) / 2 + (1.2 if u > knee_u - 1.5 else 0)
                cy = (bottom + lap_y0) / 2 + (0.6 if u > knee_u - 1.5 else 0)
                return (abs(u - lap_c) / lap_r) ** 3 + (abs(py - cy) / ry) ** 3 <= 1
            F.fill(sk, (0, waist, FW, bottom + 3), 'skirt', 'skirt', P['bottom'], ('sph', sx(2) - 4, waist - 2, 22, 18))
            if P.get('hem_drop', 99) <= 4:      # 长裙坐下：膝盖前面垂下来一片，盖住小腿
                def dr(px, py):
                    u = (px - CX) * f + 0.8
                    return hyc <= py <= FOOT - 2 + 0.5 and knee_u - 5.4 <= u <= knee_u + 3.0 + (py - hyc) * 0.12
                F.fill(dr, (0, hyc - 1, FW, FOOT), 'skirtd', 'skirt', P['bottom'], ('vcyl', sx(knee_u) - 1, 5, 0.1))
                for x in range(FW):
                    F.recolor(x, FOOT - 3, mat='trim_gold', only=('skirtd',))
            if 'face2' in P:
                skirt_details_side(F, P, waist, bottom, sx, f, depth, True)
            if P['name'] == '奶奶':
                for y in range(int(hyc - legr), int(bottom) + 2):
                    for uu in (knee_u - 4, knee_u - 8):
                        F.recolor(sx(uu), y, dl=-1, only=('skirt',))
    # 身子
    hem_y = torso_hem(P, g, sh, crotch)
    if sit:
        hem_y = min(hem_y, int(hyc - legr + 1))
    def body(px, py):
        if py < sh or py > hem_y + 0.5:
            return False
        t = (py - sh) / max(1, hem_y - sh)
        fr_ = depth / 2 + belly * 1.25 * math.sin(min(1.0, t * 1.1) * math.pi * 0.9)
        if P['sex'] == 'f' and not belly:
            fr_ += 1.0 * math.sin(min(1.0, t * 2.2) * math.pi) * (1 if t < 0.45 else 0)
        bk_ = depth / 2 + 0.4 * t
        if P.get('coat') and py > crotch - 1:      # 长外套下摆往外撑一点
            fr_ += (py - crotch + 1) * 0.22
            bk_ += (py - crotch + 1) * 0.40
        if py < sh + 1:
            fr_ -= 3.0
            bk_ -= 3.0
        elif py < sh + 2:
            fr_ -= 1.2
            bk_ -= 1.2
        u = (px - CX) * f + 0.8
        return -bk_ <= u <= fr_
    F.fill(body, (0, sh, FW, hem_y + 1), 'torso', 'torso', P['top'], ('vcyl', CX - f * 1.5, depth / 2 + belly + 2, -0.12))
    side_torso_details(F, P, g, sh, hem_y, sx, f, depth)
    arm('f', pose.get('na', 0), 'armf')
    draw_head_side(F, P, g, dy_body + pose.get('head_dy', 0), sx, f, pose)


def side_torso_details(F, P, g, sh, hem_y, sx, f, depth):
    sh, hem_y = int(round(sh)), int(round(hem_y))
    nm = P['name']
    T = ('torso',)
    def u_of(x):
        return (x + 0.5 - CX) * f + 0.8
    if nm == '奶奶':
        for y in range(int(sh) + 2, int(hem_y) + 1):
            for x in range(FW):
                if F.has(x, y, T):
                    u = u_of(x)
                    edge = max(u2 for u2 in [u_of(xx) for xx in range(FW) if F.has(xx, y, T)])
                    if edge - 3.0 < u <= edge - 2.0:
                        F.recolor(x, y, mat='trim_gold', dl=-1)
        for x in range(FW):
            F.recolor(x, hem_y - 1, mat='trim_gold', dl=-1, only=T)
        for d in range(3):
            F.recolor(sx(depth / 2 - 2.5) , sh + d, mat='collar_white', only=T)
            F.recolor(sx(depth / 2 - 1.5), sh + d, mat='collar_white', only=T)
    elif nm == '爷爷':
        for k in range(4):
            F.put(sx(depth / 2 - 1.5), sh + 3 + k * 5, RAMPS['brass'][3]) if F.has(sx(depth / 2 - 1.5), sh + 3 + k * 5, T) else None
        for d in range(5):
            F.recolor(sx(depth / 2 - 4 - d), sh + 8, dl=-2, only=T)
            F.recolor(sx(depth / 2 - 4 - d), sh + 18, dl=-2, only=T)
        for d in range(-3, 4):
            F.recolor(sx(d), sh, dl=1, only=T)
    elif nm == '叔叔':
        for d in range(4):
            for k in range(3 - d // 2):
                F.px(sx(depth / 2 - 1.5 - k), sh + d, 'neck', 'neck', 'skin', ('flat', 0))
    elif nm == '阿姨':
        for x in range(FW):
            if F.has(x, hem_y, T):
                F.recolor(x, hem_y, dl=-1)
                if x % 2 == 0:
                    F.recolor(x, hem_y - 1, dl=-1)
    elif 'face2' in P:
        side_torso_details2(F, P, g, sh, hem_y, sx, f, depth)


def draw_head_side(F, P, g, dy, sx, f, pose):
    skin = P['skin']
    top = g['top'] + dy
    chin = g['chin'] + dy
    fcy = g['fcy'] + dy
    frx = P['face_rx']
    hr = frx + 0.6
    hc = 0.6
    e = g['eye'] + dy
    def head_t(px, py):
        u = (px - CX) * f - hc
        if py < fcy:
            dyv = (fcy - py) / (fcy - top + 0.5)
            return (abs(u) / hr) ** 2.3 + dyv ** 2.3 <= 1
        dyv = (py - fcy) / (chin + 1 - fcy)
        if u > 0:
            return (u / (hr - 0.8)) ** 2.0 + dyv ** 2.2 <= 1
        return (abs(u) / hr) ** 2.2 + dyv ** 3.0 <= 1
    F.fill(head_t, (0, top, FW, chin + 1), 'face', 'face', skin, ('flat', 0))
    nu = hc + hr - 0.2
    F.px(sx(nu + 0.5), e + 3, 'face', 'face', skin, ('flat', 0))
    F.px(sx(nu + 0.5), e + 4, 'face', 'face', skin, ('flat', -1))
    hair_side(F, P, g, dy, sx, f, hc, hr)
    if 'face2' in P and P['hair_style'] in ('crew', 'messy'):
        side_ear(F, P, g, dy, sx, f, hc)
    elif P['hair_style'] in ('swept', 'afro'):
        eu = hc - (1.0 if P['hair_style'] == 'swept' else 2.2)
        F.ellipse(sx(eu), e + 2.5, 1.6, 2.3, 'ear', 'face', skin, shd=('flat', 0))
        F.put(sx(eu + 0.4), e + 3.0, RAMPS[skin][2])
    for x in range(FW):           # 下巴底下一行暗
        yb = int(chin)
        if F.part[yb][x] == 'face' and F.part[yb - 1][x] == 'face':
            F.recolor(x, yb - 1, dl=-1)
    # 后脑勺跟脸接的地方（鬓角后面）压一列暗，脸更有立体感
    face_features_side(F, P, g, dy, sx, f, hc, hr, pose)


def hair_side(F, P, g, dy, sx, f, hc, hr):
    """侧面头发 = 一团头发 − 脸露出来的那块（脸窗：额头发际线以下、鬓角以前）"""
    if P['hair_style'] in HAIR2:
        return hair_side2(F, P, g, dy, sx, f, hc, hr)
    st = P['hair_style']
    hm = P['hair']
    top = g['top'] + dy
    chin = g['chin'] + dy
    e = g['eye'] + dy
    def uu(px):
        return (px - CX) * f - hc
    shd = ('sph', sx(hc + 1) - 2.0, top + 4, hr + 6, 15)
    if st == 'bun':
        u_side, fore, back_bot, side_bot = 0.8, lambda u: top + 9.0 + max(0.0, hr - 2 - u) * 0.10, e + 7, e + 5
        rx, ry, cy = hr + 2.2, 10.8, top + 10
    elif st == 'swept':
        u_side, fore, back_bot, side_bot = -0.4, lambda u: top + 7.5 + max(0.0, hr - 1 - u) * 0.12, e + 6, e + 1
        rx, ry, cy = hr + 1.7, 10.0, top + 9
    elif st == 'afro':
        u_side = -0.9
        fore = lambda u: top + 10.5 + 2.0 * abs(math.sin(u * math.pi / 3.4)) ** 0.8
        back_bot, side_bot = chin - 2, e + 1
        rx, ry, cy = hr + 3.4, 12.6, top + 10.6
    else:   # bob
        u_side, fore, back_bot, side_bot = 3.0, lambda u: e - 2.8 + max(0.0, u - hr + 4) * 0.0, chin + 0.5, chin + 0.5
        rx, ry, cy = hr + 3.2, 12.0, top + 12
    if st == 'afro':
        m = lobed(sx(hc - 1.0), cy, rx, ry, 15, 0.13, 0.4 if f < 0 else 2.0)
    else:
        def m(px, py):
            u = uu(px) + 0.5
            ryy = ry if (py < cy or u > u_side) else ry + 6
            return (abs(u) / rx) ** 2.3 + (abs(py - cy) / ryy) ** 2.3 <= 1
    def h(px, py):
        u = uu(px)
        if not m(px, py):
            return False
        if u > u_side and py > fore(u):
            return False                        # 脸窗
        if st == 'bob' and u > u_side - 0.5 and py > e - 2.8 and u > hr - 1.5:
            return False
        bb = back_bot if u < u_side - 1.5 else side_bot
        if st == 'bob':
            bb -= max(0.0, -u - hr + 1) * 0.9        # 波波头后摆往上收圆
        if py > bb:
            return False
        return True
    F.fill(h, (0, top - 3, FW, chin + 2), 'hair', 'hair', hm, shd if st != 'afro' else ('flat', 0))
    if st == 'bun':
        hair_bands(F, lambda px, py: (py - top) * 1.0 - uu(px) * 0.45, 3.0, top, e + 9, hi=0.18, lo=0.74)
        bx, by = sx(hc - hr - 0.4), top + 10.5
        F.ellipse(bx, by, 4.8, 5.0, 'bun', 'hairbun', hm, shd=('sph', bx - 1.5, by - 2, 6, 6))
        hair_bands(F, lambda px, py: math.atan2(py - by, (px - bx)) * 4 + math.hypot(px - bx, py - by) * 0.6, 2.4,
                   top, e + 8, parts=('bun',), hi=0.2, lo=0.75)
    elif st == 'swept':
        hair_bands(F, lambda px, py: (py - top) * 1.0 + uu(px) * 0.28, 2.8, top, e + 10, hi=0.2, lo=0.74)
    elif st == 'afro':
        gsh = ('sph', sx(hc + 1) - 3.0, top + 4, hr + 9, 18)
        curly(F, (0, top - 3, FW, chin), 9, gsh)
    else:
        hair_bands(F, lambda px, py: uu(px) * 1.0 + (py - top) * 0.30, 3.2, top + 1, chin + 1, hi=0.18, lo=0.74)


def face_features_side(F, P, g, dy, sx, f, hc, hr, pose):
    if 'face2' in P:
        return face2_side(F, P, g, dy, sx, f, hc, hr, pose)
    e = g['eye'] + dy
    nm = P['name']
    fu = hc + hr                        # 脸前沿
    eu = fu - 4.5                       # 眼睛
    mouth = pose.get('mouth', 'smile')
    def X(u):
        return sx(u)
    if nm == '叔叔':
        F.put(X(eu - 1), e + 1, C['eye'])
        F.put(X(eu), e, C['eye'])
        F.put(X(eu + 1), e, C['eye'])
        F.put(X(eu + 2), e + 1, C['eye'])
        for d in (-1, 0, 1):
            F.put(X(eu + d), e - 3, C['brow_dark'])
        F.put(X(eu - 1), e + 3, C['blush'])
        F.put(X(eu), e + 3, C['blush'])
        F.put(X(eu - 2), e + 3, C['blush'])
    else:
        # 侧面眼睛 2 宽：前面那列是眼白高光那侧？光从左上，所以朝左时高光在前，朝右时高光在后
        hl_front = f < 0
        rows = 3 if nm != '阿姨' else 4
        oy = e - (1 if rows == 4 else 0)
        for j in range(rows):
            for i, u in enumerate((eu, eu + 1)):
                front = (i == 1)
                if j == 0 or (rows == 4 and j == 3):
                    col = C['eye']
                elif j == 1:
                    col = C['eye_hl'] if front == hl_front else C['iris']
                else:
                    col = C['iris'] if front else C['eye']
                if rows == 3 and nm == '爷爷' and j == 2:
                    continue
                F.put(X(u), oy + j, col)
        if nm == '爷爷':
            for d in (-1, 0, 1, 2):
                F.put(X(eu + d), e - 2, RAMPS['hair_grey'][1])
                F.put(X(eu + d), e - 3, RAMPS['hair_grey'][2])
        elif nm == '奶奶':
            for d in (-1, 0, 1):
                F.put(X(eu + d), e - 2, RAMPS['hair_silver'][1])
        else:
            for d in (-1, 0, 1):
                F.put(X(eu + d), e - 3, C['brow_dark'])
        F.put(X(eu - 1), e + 3, C['blush'])
        F.put(X(eu - 2), e + 3, C['blush'])
    mu = fu - 1.4
    if mouth == 'open':
        F.put(X(mu), e + 7, C['mouth_dk'])
        F.put(X(mu - 1), e + 7, C['mouth_dk'])
        F.put(X(mu), e + 8, C['tongue'])
    else:
        F.put(X(mu), e + 7, C['mouth'])
        F.put(X(mu - 1), e + 6, C['mouth'])
    if nm == '阿姨':
        cxl = X(eu + 0.5)
        cy = e + 0.5
        for yy in range(e - 5, e + 6):
            for xx in range(int(cxl) - 5, int(cxl) + 5):
                d = math.hypot((xx + 0.5 - cxl) * 1.45, yy + 0.5 - cy)
                if 3.3 <= d < 4.5:
                    F.put(xx, yy, C['glass'])
        for k in range(1, 6):
            F.put(X(eu - 2.5 - k), e - 1 + (1 if k > 3 else 0), C['glass'])
    if nm in ('奶奶', '爷爷'):
        F.put(X(eu - 1.5), e + 1, C['wrinkle'])
        F.put(X(mu - 2), e + 6, C['wrinkle'])


# ---------------------------------------------------------------- 正面坐、背面坐
def draw_front_sit(F, P, pose, back=False):
    g = geom(P)
    bob = pose.get('bob', 0)
    lift = 3 if not back else 0          # 正面坐：胯在后面，画面上比膝盖高几像素
    dy = g['sit_dy'] - lift + bob
    sh = g['sh'] + dy
    legr = P['leg_r']
    bot, shoe = P['bottom'], P['shoe']
    lm = leg_mat(P)
    knee = g['knee_sit']
    hipc = g['hip_sit'] - lift
    if not back:
        for side in (-1, 1):
            fx = CX + side * (legr + 0.5)
            F.capsule(fx, knee + 1, fx, g['ankle'] - 0.5, legr, legr - 0.3, 'shin%d' % side, 'leg', lm)
            sy = FOOT - 1.6
            F.ellipse(fx + side * 0.5, sy, legr + 1.1, 2.5, 'shoe%d' % side, 'shoe', shoe,
                      shd=('sph', fx + side * 0.5 - 0.5, sy - 2.5, legr + 2, 4.5), p=2.4)
        hem_y = int(round(hipc - 1))
    else:
        hem_y = int(round(hipc + legr))
    draw_torso_front(F, P, g, sh, hem_y, back)
    if not back:
        if P['skirt']:
            def sk(px, py):
                return hipc - 4 <= py <= knee + legr + 1.5 and abs(px - CX) <= P['hipw'] / 2 + 1.2 - max(0.0, py - knee) * 0.5
            F.fill(sk, (0, hipc - 5, FW, knee + legr + 3), 'skirt', 'skirt', bot, ('sph', CX - 3, hipc - 6, P['hipw'] / 2 + 6, 12))
            if P.get('hem_drop', 99) <= 4:      # 长裙坐下：裙摆从膝盖垂到脚踝，盖住小腿
                def dr(px, py):
                    return knee <= py <= FOOT - 2 + 0.5 and abs(px - CX) <= P['hipw'] / 2 + 0.4 + (py - knee) * 0.18
                F.fill(dr, (0, knee - 1, FW, FOOT), 'skirt', 'skirt', bot, ('vcyl', CX - 1, P['hipw'] / 2 + 3, 0.1))
                for x in range(FW):
                    F.recolor(x, FOOT - 3, mat='trim_gold', only=('skirt',))
                for y in range(int(knee) + 1, FOOT - 3):
                    F.recolor(CX - 0.5, y, dl=-1, only=('skirt',))
            if P['name'] == '奶奶':
                for y in range(int(hipc), int(knee + legr + 2)):
                    for xx in (-8, -4, 0, 4, 8):
                        F.recolor(CX + xx + 0.5, y, dl=-1, only=('skirt',))
        else:
            for side in (-1, 1):   # 大腿朝镜头：从胯伸到膝盖
                fx = CX + side * (legr + 0.5)
                F.capsule(fx, hipc - 3, fx, knee - 0.5, legr + 1.0, legr + 1.0, 'thigh%d' % side, 'thigh', bot,
                          shd=('sph', fx - 1.2, hipc - 5, legr + 2.5, (knee - hipc) + 6))
    pose2 = dict(pose, arms='lap' if not back else 'free', la=0, ra=0)
    if not back:
        for side in (-1, 1):
            sx_, sy_, ex, ey, hx_, hy_ = front_arm_targets(P, pose2, g, sh, side, back)
            hx_ = CX + side * (legr + 1.8)
            hy_ = knee - 1.0
            ex = sx_ + side * 1.8
            ey = (sy_ + hy_) / 2
            draw_arm(F, P, str(side), 'arm', sx_, sy_, ex, ey, hx_, hy_)
    else:
        hw = P['hipw'] / 2 + 1.0
        F.rows(hem_y - 4, hem_y + 1.5, lambda y: hw - max(0.0, y - hem_y) * 1.2, 'hips', 'legb', bot,
               ('vcyl', CX - 1, hw + 1.5, 0.15))
        draw_front_arms(F, P, pose2, g, sh, back)
    draw_head_front(F, P, g, dy + pose.get('head_dy', 0), back, pose)


def face_crescent(F, y0, y1):
    """脸右边两列压暗一档（光从左上）"""
    for y in range(max(0, int(y0)), min(FH, int(y1) + 1)):
        xs = [x for x in range(FW) if F.part[y][x] == 'face']
        if not xs:
            continue
        xr = max(xs)
        for x in (xr - 1, xr - 2):
            if F.part[y][x] == 'face':
                F.recolor(x, y, dl=-1)


def hair_bands(F, sfn, width, y0=0, y1=FH, parts=('hair',), hi=0.24, lo=0.68):
    """头发一绺一绺：每绺左边亮一档、右边暗一档"""
    for y in range(max(0, int(y0)), min(FH, int(y1))):
        for x in range(FW):
            if F.has(x, y, parts):
                t = (sfn(x + 0.5, y + 0.5) / width) % 1.0
                if t < hi:
                    F.recolor(x, y, dl=1)
                elif t > lo:
                    F.recolor(x, y, dl=-1)


def curly(F, box, seed, gshd, spacing=4.0):
    """卷发：把头发分成一个个小卷（抖动过的格点），每卷自己一个小球的明暗，卷和卷之间压一道暗缝"""
    x0, y0, x1, y1 = box
    rnd = random.Random(seed)
    seeds = []
    yy, row = y0 - spacing, 0
    while yy < y1 + spacing:
        xx = x0 - spacing + (row % 2) * spacing / 2
        while xx < x1 + spacing:
            seeds.append((xx + rnd.uniform(-1.1, 1.1), yy + rnd.uniform(-0.9, 0.9), rnd.uniform(2.4, 3.1)))
            xx += spacing
        yy += spacing * 0.86
        row += 1
    for y in range(max(0, int(y0) - 1), min(FH, int(y1) + 2)):
        for x in range(max(0, int(x0) - 1), min(FW, int(x1) + 2)):
            if F.part[y][x] != 'hair':
                continue
            px, py = x + 0.5, y + 0.5
            ds = sorted(((px - a) ** 2 + (py - b) ** 2, a, b, r) for a, b, r in seeds)[:2]
            d1, a, b, r = ds[0]
            d2 = ds[1][0]
            loc = shade_level(('sph', a - 0.7, b - 0.9, r, r), x, y)
            glob = shade_level(gshd, x, y)
            L = loc + min(0, glob)
            if glob >= 1 and loc >= 0:
                L = 1
            if math.sqrt(d2) - math.sqrt(d1) < 0.75:
                L -= 1
            F.shd[y][x] = ('flat', max(-2, min(1, L)))


def lobed(cx, cy, rx, ry, k, amp, phase=0.0, base=0.93, pw=0.7):
    """一团带圆鼓包的轮廓（卷发外沿）；pw 大 = 鼓包变尖（乱发的发梢）"""
    def t(px, py):
        dx, dyv = (px - cx) / rx, (py - cy) / ry
        r = math.hypot(dx, dyv)
        th = math.atan2(dyv, dx)
        lobe = abs(math.sin(th * k / 2 + phase)) ** pw
        return r <= base + amp * lobe
    return t


# ================================================================ charcode02 新加：7 位用的部件
HAIR2 = ('messy', 'crew', 'updo', 'wavy', 'pigtails', 'braids')


def tipwave(x, period, sharp=1.6):
    """尖的发梢：0～1，尖在每个周期中间"""
    fr = (x / period) % 1.0
    return (1 - abs(fr * 2 - 1)) ** sharp


def band(F, parts, ax, ay, bx, by, t0, t1, mat=None, dl=None):
    """沿 a→b 方向，把 parts 里投影落在 [t0, t1] 的像素改色（袖口、臂环）"""
    vx, vy = bx - ax, by - ay
    l2 = vx * vx + vy * vy or 1e-6
    for y in range(max(0, int(min(ay, by)) - 6), min(FH, int(max(ay, by)) + 7)):
        for x in range(max(0, int(min(ax, bx)) - 6), min(FW, int(max(ax, bx)) + 7)):
            if F.part[y][x] in parts:
                t = ((x + 0.5 - ax) * vx + (y + 0.5 - ay) * vy) / l2
                if t0 <= t <= t1:
                    F.recolor(x, y, mat=mat, dl=dl)


def row_xs(F, y, parts):
    y = int(y)
    if not 0 <= y < FH:
        return []
    return [x for x in range(FW) if F.part[y][x] in parts]


def front_x(F, y, parts, f):
    """侧面：这一行 parts 里最靠脸那一侧的像素 x"""
    xs = row_xs(F, y, parts)
    if not xs:
        return None
    return max(xs) if f > 0 else min(xs)


def back_x(F, y, parts, f):
    xs = row_xs(F, y, parts)
    if not xs:
        return None
    return min(xs) if f > 0 else max(xs)


def gold(i=3):
    return RAMPS['trim_gold'][i]


def brass(i=3):
    return RAMPS['brass'][i]


# ---------------------------------------------------------------- 衣服
def coat_fill(F, P, sh, hem_y, cr, thalf, back):
    """01 青年的长外套：盖过胯，下摆往外撑；正面从衬里底下往下敞开（露出裤子）"""
    yo = cr - 3
    w_cr = thalf(cr - 1)
    def t(px, py):
        if py < sh or py > hem_y + 0.5:
            return False
        h = thalf(py) if py <= cr - 1 else w_cr + (py - (cr - 1)) * 0.30
        dx = px - CX
        if abs(dx) > h:
            return False
        if not back and py > yo and abs(dx) < 0.5 + (py - yo) * 0.42:
            return False
        return True
    F.fill(t, (0, sh, FW, hem_y + 1), 'torso', 'torso', P['top'], ('vcyl', CX - 0.5, P['sw'] / 2 + 1.5, -0.12))


def belt_front(F, P, y0, back):
    """04 扎衬衫：衬衫下摆底下两行皮带，正中铜扣"""
    c = int(CX)
    y0 = int(y0) + 2
    for y in (y0, y0 + 1):
        for x in range(FW):
            if F.has(x, y, ('hips',)):
                F.recolor(x, y, mat='shoe_brown')
    if not back:
        for dx in (-1, 0):
            F.put(c + dx, y0, brass(3))
            F.put(c + dx, y0 + 1, brass(2))
    else:
        for xx in (c - 6, c + 5):
            F.recolor(xx, y0, dl=-1, only=('hips',))
            F.recolor(xx, y0 + 1, dl=-1, only=('hips',))


def belt_side(F, P, y0, sx, f, depth):
    y0 = int(y0) + 2
    for y in (y0, y0 + 1):
        for x in range(FW):
            if F.has(x, y, ('hips',)):
                F.recolor(x, y, mat='shoe_brown')
    xf = front_x(F, y0, ('hips',), f)
    if xf is not None:
        F.put(xf - f * 1, y0, brass(3))
        F.put(xf - f * 1, y0 + 1, brass(2))


def shawl_front(F, P, pose, g, sh, crotch, back):
    """02 红裙的披帛：挂在两边手肘外侧往下垂到膝盖，越往下越宽，底边金线；背面在腰后兜一道"""
    bob = pose.get('bob', 0)
    bot = FOOT - 15 + bob
    ar = P['arm_r']
    elbows = {}
    for side in (-1, 1):
        sx_, sy_, ex, ey, hx_, hy_ = front_arm_targets(P, pose, g, sh, side, back)
        elbows[side] = (ex, ey)
        top_y = ey - 1.0
        def t(px, py, side=side, ex=ex, top_y=top_y):
            if py < top_y or py > bot + 0.5:
                return False
            k = (py - top_y) / max(1.0, bot - top_y)
            inner = ex - side * 1.2
            outer = ex + side * (ar + 1.2 + 2.4 * k)
            return min(inner, outer) <= px <= max(inner, outer)
        F.fill(t, (0, top_y - 1, FW, bot + 2), 'shawl%d' % side, 'shawl', 'dress_wine',
               ('vcyl', ex + side * 2.0 - 1.0, ar + 3.5, 0.05))
        for x in range(FW):
            F.recolor(x, int(bot) - 1, mat='trim_gold', only=('shawl%d' % side,))
    if back:
        xl, xr = elbows[-1][0], elbows[1][0]
        cx, hw = (xl + xr) / 2, (xr - xl) / 2
        yb = crotch + 3 + bob
        def u(px, py):
            if not (xl <= px <= xr):
                return False
            yc = yb - ((px - cx) / hw) ** 2 * 8
            return yc - 3.4 <= py <= yc
        F.fill(u, (0, yb - 14, FW, yb + 2), 'shawlb', 'shawl', 'dress_wine', ('vcyl', CX - 1, hw + 2, 0.1))
        for x in range(FW):
            ys = [y for y in range(FH) if F.part[y][x] == 'shawlb']
            if ys:
                F.recolor(x, max(ys) - 1, mat='trim_gold')


def shawl_side(F, P, which, sx, f, ex, ey, hx_, hy_):
    bot = FOOT - 15
    ar = P['arm_r']
    top_y = ey - 1
    def t(px, py):
        if py < top_y or py > bot + 0.5:
            return False
        k = (py - top_y) / max(1.0, bot - top_y)
        u = (px - ex) * f
        return -(ar + 1.0 + 2.8 * k) <= u <= 1.4 + 0.6 * k
    F.fill(t, (0, top_y - 1, FW, bot + 2), 'shawl' + which, 'shawl' + which, 'dress_wine',
           ('vcyl', ex - f * 1.5 - 1, ar + 4, 0.05))
    for x in range(FW):
        F.recolor(x, int(bot) - 1, mat='trim_gold', only=('shawl' + which,))


def skirt_details_front(F, P, waist, hem, back):
    nm = P['name']
    S = ('skirt',)
    c = CX
    if nm == '红裙':
        if not back:
            for y in range(int(waist) + 1, int(hem) + 1):
                t = (y - waist) / max(1, hem - waist)
                for side in (-1, 1):
                    F.recolor(c + side * (3.0 + 2.6 * t) - 0.5, y, mat='trim_gold', only=S)
                # 斜着垂下来的两道褶：一道暗、紧挨着一道亮
                for (x0, x1, k) in ((c + 1.0, c - 6.5, 0.0), (c + 5.0, c + 0.5, 0.35)):
                    if t >= k:
                        tt = (t - k) / (1 - k) if k < 1 else 0
                        xf = x0 + (x1 - x0) * tt
                        F.recolor(xf, y, dl=-1, only=S)
                        F.recolor(xf + 1, y, dl=1, only=S)
        else:
            for y in range(int(waist) + 1, int(hem) + 1):
                for xx in (-5, 0, 5):
                    F.recolor(c + xx - 0.5, y, dl=-1, only=S)
        for x in range(FW):
            F.recolor(x, int(hem) - 1, mat='trim_gold', only=S)
    elif nm == '女孩':
        if not back:
            for y in range(int(waist), int(hem) + 1):
                t = (y - waist) / max(1, hem - waist)
                w = 1.0 + 3.0 * t
                for x in range(FW):
                    if F.has(x, y, S) and abs(x + 0.5 - c) <= w:
                        F.recolor(x, y, mat='shirt_cream')
                for side in (-1, 1):
                    F.recolor(c + side * (w + 0.8) - 0.5, y, mat='trim_gold', only=S)
        for x in range(FW):
            F.recolor(x, int(hem) - 1, mat='trim_gold', only=S)
            if x % 3 == 0:
                F.recolor(x, int(hem) - 2, mat='trim_gold', dl=-1, only=S)


def skirt_details_side(F, P, waist, hem, sx, f, depth, sit):
    nm = P['name']
    S = ('skirt',)
    if nm == '红裙':
        for y in range(int(waist) + 1, int(hem) + 1):
            xf = front_x(F, y, S, f)
            if xf is not None:
                F.recolor(xf - f * 2, y, mat='trim_gold', only=S)
        for x in range(FW):
            F.recolor(x, int(hem) - 1, mat='trim_gold', only=S)
    elif nm == '女孩':
        for y in range(int(waist), int(hem) + 1):
            xf = front_x(F, y, S, f)
            if xf is not None and not sit:
                F.recolor(xf - f * 1, y, mat='shirt_cream', only=S)
                F.recolor(xf - f * 2, y, mat='trim_gold', only=S)
        for x in range(FW):
            F.recolor(x, int(hem) - 1, mat='trim_gold', only=S)
            if x % 3 == 0:
                F.recolor(x, int(hem) - 2, mat='trim_gold', dl=-1, only=S)


def arm_details2(F, P, which, sx, sy, ex, ey, hx_, hy_):
    nm = P['name']
    up = ('uarm' + which,)
    fa = ('farm' + which,)
    if nm == '青年':        # 宽袖口：金绣一圈，里面露米色衬衫袖
        band(F, fa, ex, ey, hx_, hy_ - 1.2, 0.48, 0.80, mat='trim_gold')
        band(F, fa, ex, ey, hx_, hy_ - 1.2, 0.80, 1.3, mat='shirt_cream')
    elif nm == '红裙':      # 金臂环
        band(F, up, sx, sy, ex, ey, 0.40, 0.62, mat='trim_gold')
    elif nm == '针织':      # 罗纹袖口
        band(F, fa, ex, ey, hx_, hy_ - 1.2, 0.80, 1.3, dl=-1)
    elif nm == '白衬衫':    # 卷起来的袖口
        mx, my = sx + (ex - sx) * 1.08, sy + (ey - sy) * 1.08
        band(F, up, sx, sy, mx, my, 0.70, 0.78, dl=-2)
        band(F, up, sx, sy, mx, my, 0.78, 1.4, dl=1)
    elif nm == '背带裤':    # T 恤袖口
        mx, my = sx + (ex - sx) * 0.75, sy + (ey - sy) * 0.75
        band(F, up, sx, sy, mx, my, 0.86, 1.5, dl=-1)
    elif nm == '女孩':
        band(F, fa, ex, ey, hx_, hy_ - 1.2, 0.76, 1.3, mat='shirt_cream')
    elif nm == '男孩':
        band(F, fa, ex, ey, hx_, hy_ - 1.2, 0.80, 1.3, mat='collar_white')


def torso_details2(F, P, g, sh, hem_y, back):
    sh, hem_y = int(round(sh)), int(round(hem_y))
    nm = P['name']
    c = int(CX)
    T = ('torso',)
    cr = g['crotch'] + (sh - g['sh'])
    if nm == '青年':
        coat_on = hem_y > cr
        yo = cr - 3 if coat_on else hem_y
        if not back:
            for y in range(sh - 1, yo + 1):           # 米色衬里 + 襟边金线
                w = 2 if y < sh + 1 else 3
                for x in range(c - w, c + w):
                    F.recolor(x, y, mat='shirt_cream', only=T)
                F.recolor(c - w - 1, y, mat='trim_gold', only=T)
                F.recolor(c + w, y, mat='trim_gold', only=T)
            n = 3
            step = max(3, (yo - sh - 2) // n)
            for k in range(n):                        # 盘扣
                y = sh + 3 + k * step
                for x in range(c - 3, c + 3):
                    F.recolor(x, y, mat='trim_gold', only=T)
            if coat_on:
                for y in range(yo + 1, hem_y):        # 敞开的前襟：缝边金线
                    xs = row_xs(F, y, T)
                    left = [x for x in xs if x < c]
                    right = [x for x in xs if x >= c]
                    if left and max(left) < c - 1:
                        F.recolor(max(left) - 1, y, mat='trim_gold')
                    if right and min(right) > c:
                        F.recolor(min(right) + 1, y, mat='trim_gold')
        else:
            for y in range(sh + 3, sh + 17):          # 背后金色团纹
                F.recolor(c - 1, y, mat='trim_gold', only=T)
            for (yy, w) in ((sh + 5, 3), (sh + 9, 2), (sh + 13, 3)):
                for x in range(c - 1 - w, c + w):
                    F.recolor(x, yy, mat='trim_gold', only=T)
        if coat_on:                                   # 下摆金绣边：一道金线 + 一排小菱形
            for x in range(FW):
                F.recolor(x, hem_y - 1, mat='trim_gold', only=T)
            for x0 in range(c - 14, c + 15, 5):
                for (dx, dy) in ((0, -4), (-1, -3), (1, -3), (0, -2)):
                    F.recolor(x0 + dx, hem_y + dy, mat='trim_gold', only=T)
    elif nm == '红裙':
        if not back:
            for i in range(0, 6):                     # V 领露皮肤 + 金边
                w = max(0.0, 3.2 - i * 0.6)
                for x in range(int(c - w), int(c + w)):
                    F.px(x, sh + i, 'neck', 'neck', P['skin'], ('flat', -1 if i < 1 else 0))
                wi = int(max(0.0, 3.2 - i * 0.6))
                F.recolor(c - wi - 1, sh + i, mat='trim_gold', only=T)
                F.recolor(c + wi, sh + i, mat='trim_gold', only=T)
        else:
            for i in range(0, 8):                     # 露背
                w = max(0.0, 2.6 - i * 0.35)
                for x in range(int(c - w), int(c + w)):
                    F.px(x, sh + i, 'neck', 'neck', P['skin'], ('flat', 0))
        for y in (hem_y - 2, hem_y - 1, hem_y):       # 金腰带
            for x in range(FW):
                F.recolor(x, y, mat='trim_gold', only=T)
        if not back:
            for (dx, dy) in ((-1, 1), (0, 1), (-1, 2), (0, 3)):
                F.put(c + dx, hem_y + dy, gold(2))
    elif nm == '针织':
        if not back:
            for y in range(sh - 1, hem_y + 1):        # 里面的黑打底 + 开衫门襟
                w = 2 if y < sh + 4 else 3
                for x in range(c - w, c + w):
                    F.recolor(x, y, mat='skirt_black', only=T)
                F.recolor(c - w - 1, y, dl=1, only=T)
                F.recolor(c + w, y, dl=1, only=T)
        for y in range(sh + 3, hem_y - 1):            # 麻花：两道之字暗点
            for ox in ((-8, 6) if not back else (-6, 4)):
                F.recolor(c + ox + (y // 2) % 2, y, dl=-1, only=T)
        for x in range(c - 16, c + 16):               # 罗纹下摆
            F.recolor(x, hem_y, dl=-1, only=T)
            if x % 2 == 0:
                F.recolor(x, hem_y - 1, dl=-1, only=T)
    elif nm == '白衬衫':
        if not back:
            for i in range(0, 6):                     # 敞开的领口
                w = max(0.0, 3.0 - i * 0.55)
                for x in range(int(c - w), int(c + w)):
                    F.px(x, sh + i, 'neck', 'neck', P['skin'], ('flat', -1 if i < 2 else 0))
            for i in range(0, 4):                     # 两片翻领
                w = int(max(0.0, 3.0 - i * 0.55))
                for d in (1, 2, 3):
                    F.recolor(c - w - d, sh + i, dl=1, only=T)
                    F.recolor(c + w - 1 + d, sh + i, dl=1, only=T)
            for x in list(range(c - 7, c - 2)) + list(range(c + 2, c + 7)):
                F.recolor(x, sh + 4, dl=-2, only=T)
            for y in range(sh + 6, hem_y):            # 门襟 + 扣子
                F.recolor(c, y, dl=-1, only=T)
            for y in range(sh + 8, hem_y, 5):
                F.put(c - 1, y, RAMPS['collar_white'][1])
            for (dx, dy) in ((-7, -1), (-6, -1), (-6, -2), (5, -1), (6, -1), (5, -2)):   # 塞进裤腰鼓出来的褶
                F.recolor(c + dx, hem_y + dy, dl=-1, only=T)
        else:
            for x in range(c - 9, c + 9):
                F.recolor(x, sh + 4, dl=-1, only=T)
            for y in range(sh + 5, hem_y):
                F.recolor(c, y, dl=-1, only=T)
    elif nm == '背带裤':
        G = 'overall_green'
        waist = sh + round((hem_y - sh) * 0.52)
        bib_top = sh + 4
        for y in range(waist, hem_y + 1):
            for x in range(FW):
                F.recolor(x, y, mat=G, only=T)
        if not back:
            for y in range(bib_top, waist):
                for x in range(c - 5, c + 5):
                    F.recolor(x, y, mat=G, only=T)
            for x in range(c - 5, c + 5):
                F.recolor(x, bib_top, dl=-1, only=T)
            for y in range(sh - 1, bib_top):          # 背带
                k = bib_top - y
                xl = int(c - 5 - k * 0.6)
                xr = int(c + 4 + k * 0.6)
                for x in (xl, xl + 1, xr - 1, xr):
                    F.recolor(x, y, mat=G, only=T)
            F.put(c - 5, bib_top + 1, brass(3))
            F.put(c + 4, bib_top + 1, brass(3))
            for x in range(c - 3, c + 3):             # 胸前小口袋
                F.recolor(x, bib_top + 3, dl=-1, only=T)
            for y in range(bib_top + 3, bib_top + 7):
                F.recolor(c - 3, y, dl=-1, only=T)
                F.recolor(c + 2, y, dl=-1, only=T)
        else:
            for y in range(sh + 6, waist):
                for x in range(c - 4, c + 4):
                    F.recolor(x, y, mat=G, only=T)
            for y in range(sh - 1, sh + 6):
                for x in (c - 4, c - 3, c + 2, c + 3):
                    F.recolor(x, y, mat=G, only=T)
    elif nm == '女孩':
        if not back:
            for y in range(sh, hem_y + 1):            # 米色前片
                for x in (c - 1, c):
                    F.recolor(x, y, mat='shirt_cream', only=T)
            for x in range(c - 3, c + 3):             # 小翻领
                F.recolor(x, sh, mat='shirt_cream', only=T)
            F.put(c, sh + 3, gold(3))
        else:
            bow = ['GG.GG', 'GGGGG', 'GG.GG', '.G.G.']
            for j, row in enumerate(bow):             # 背后金色蝴蝶结
                for i, ch in enumerate(row):
                    if ch == 'G':
                        F.recolor(c - 2 + i, hem_y - 1 + j, mat='trim_gold', dl=(-1 if i == 2 else None),
                                  only=('torso', 'skirt'))
    elif nm == '男孩':
        if not back:
            for i in range(0, 6):                     # 白衬衫 V + 翻领边
                w = max(0.0, 2.6 - i * 0.45)
                for x in range(int(c - w), int(c + w)):
                    F.recolor(x, sh + i, mat='collar_white', only=T)
                wi = int(max(0.0, 2.6 - i * 0.45))
                F.recolor(c - wi - 1, sh + i, dl=-2, only=T)
                F.recolor(c + wi, sh + i, dl=-2, only=T)
            for (dx, dy, k) in ((-3, 0, 2), (-2, 0, 3), (1, 0, 3), (2, 0, 2), (-1, 0, 1), (0, 0, 1),
                                (-3, 1, 1), (-2, 1, 2), (1, 1, 2), (2, 1, 1)):   # 金领结
                F.put(c + dx, sh + dy, gold(k + 1))
            for y in range(sh + 6, hem_y):
                F.recolor(c, y, dl=-1, only=T)
            for k in range(2):
                F.put(c - 1, sh + 7 + k * 3, brass(3))
            for x in list(range(c - 6, c - 3)) + list(range(c + 3, c + 6)):
                F.recolor(x, hem_y - 3, dl=-2, only=T)
        else:
            for y in range(sh + 3, hem_y + 1):
                F.recolor(c, y, dl=-1, only=T)


def side_torso_details2(F, P, g, sh, hem_y, sx, f, depth):
    sh, hem_y = int(round(sh)), int(round(hem_y))
    nm = P['name']
    T = ('torso',)
    cr = g['crotch'] + (sh - g['sh'])
    if nm == '青年':
        yo = cr - 3 if hem_y > cr else hem_y
        for y in range(sh, hem_y):
            xf = front_x(F, y, T, f)
            if xf is None:
                continue
            if y <= yo:
                F.recolor(xf - f * 1, y, mat='shirt_cream', only=T)
                F.recolor(xf - f * 2, y, mat='trim_gold', only=T)
            else:
                F.recolor(xf - f * 1, y, mat='trim_gold', only=T)
        for k in range(3):
            y = sh + 3 + k * max(3, (yo - sh - 2) // 3)
            xf = front_x(F, y, T, f)
            if xf is not None:
                for d in (1, 2, 3):
                    F.recolor(xf - f * d, y, mat='trim_gold', only=T)
        if hem_y > cr:
            for x in range(FW):
                F.recolor(x, hem_y - 1, mat='trim_gold', only=T)
            xs = row_xs(F, hem_y - 3, T)
            for x in xs[1:-1:4]:
                F.recolor(x, hem_y - 3, mat='trim_gold', only=T)
    elif nm == '红裙':
        for d in range(3):
            xf = front_x(F, sh + d, T, f)
            if xf is not None:
                for k in range(1, 3 - d):
                    F.px(xf - f * k, sh + d, 'neck', 'neck', P['skin'], ('flat', 0))
        for y in (hem_y - 2, hem_y - 1, hem_y):
            for x in range(FW):
                F.recolor(x, y, mat='trim_gold', only=T)
    elif nm == '针织':
        for y in range(sh, hem_y + 1):
            xf = front_x(F, y, T, f)
            if xf is not None:
                F.recolor(xf - f * 1, y, mat='skirt_black', only=T)
                F.recolor(xf - f * 2, y, dl=1, only=T)
        for y in range(sh + 3, hem_y - 1):
            F.recolor(CX - f * 1 + (y // 2) % 2, y, dl=-1, only=T)
        for x in range(FW):
            if F.has(x, hem_y, T):
                F.recolor(x, hem_y, dl=-1)
                if x % 2 == 0:
                    F.recolor(x, hem_y - 1, dl=-1)
    elif nm == '白衬衫':
        for d in range(4):
            for k in range(3 - d // 2):
                F.px(sx(depth / 2 - 1.5 - k), sh + d, 'neck', 'neck', 'skin', ('flat', 0))
        for d in range(3):
            F.recolor(sx(depth / 2 - 4.5), sh + d, dl=1, only=T)
            F.recolor(sx(depth / 2 - 5.5), sh + d, dl=1, only=T)
        for y in range(sh + 5, hem_y):
            xf = front_x(F, y, T, f)
            if xf is not None:
                F.recolor(xf - f * 2, y, dl=-1, only=T)
        for x in range(FW):
            F.recolor(x, hem_y - 1, dl=-1, only=T) if x % 3 == 0 else None
    elif nm == '背带裤':
        G = 'overall_green'
        waist = sh + round((hem_y - sh) * 0.52)
        bib_top = sh + 4
        for y in range(waist, hem_y + 1):
            for x in range(FW):
                F.recolor(x, y, mat=G, only=T)
        for y in range(bib_top, waist):
            xf = front_x(F, y, T, f)
            if xf is not None:
                for k in range(0, 3):
                    F.recolor(xf - f * k, y, mat=G, only=T)
        xb = back_x(F, sh + 2, T, f)
        xf0 = front_x(F, bib_top, T, f)
        if xb is not None and xf0 is not None:
            for y in range(sh - 1, bib_top + 1):       # 背带斜过肩膀
                t = (y - (sh - 1)) / max(1, bib_top - (sh - 1))
                x = round(xb + f * 3 + (xf0 - f * 2 - xb - f * 3) * t)
                for d in (0, -f):
                    F.recolor(x + d, y, mat=G, only=T)
            F.put(xf0 - f * 1, bib_top + 1, brass(3))
    elif nm == '女孩':
        for y in range(sh, hem_y + 1):
            xf = front_x(F, y, T, f)
            if xf is not None:
                F.recolor(xf - f * 1, y, mat='shirt_cream', only=T)
        xb = back_x(F, hem_y - 1, T, f)
        if xb is not None:
            for (k, dy) in ((0, -1), (0, 0), (0, 1), (1, 0), (1, -1), (1, 1)):
                F.recolor(xb + f * k, hem_y + dy, mat='trim_gold', only=('torso', 'skirt'))
    elif nm == '男孩':
        for y in range(sh, sh + 5):
            xf = front_x(F, y, T, f)
            if xf is not None:
                F.recolor(xf - f * 1, y, mat='collar_white', only=T)
                if y < sh + 4:
                    F.recolor(xf - f * 2, y, mat='collar_white', only=T)
                F.recolor(xf - f * 3, y, dl=-2, only=T)
        xf = front_x(F, sh, T, f)
        if xf is not None:
            F.put(xf - f * 1, sh, gold(3))
            F.put(xf - f * 2, sh, gold(2))
            F.put(xf - f * 1, sh + 1, gold(2))
        for k in range(2):
            xf = front_x(F, sh + 7 + k * 3, T, f)
            if xf is not None:
                F.put(xf - f * 2, sh + 7 + k * 3, brass(3))


def post2(F, P, d, pose):
    """画完、上色之前最后一道：08 背带裤的浅色卷边裤脚"""
    if P['name'] == '背带裤':
        cuff = []
        for y in range(FH - 3):
            for x in range(FW):
                p = F.part[y][x]
                if p and (p.startswith('leg') or p.startswith('shin')):
                    for k in (1, 2):
                        q = F.part[y + k][x]
                        if q and q.startswith('shoe'):
                            cuff.append((x, y))
                            break
        for (x, y) in cuff:
            F.recolor(x, y, mat='knit_beige', dl=-1)


def walk_poses_kid(d, k):
    out = []
    for p in walk_poses(d):
        q = dict(p)
        if d in ('down', 'up'):
            q['lf'] = (p['lf'][0] * k, round(p['lf'][1] * k))
            q['rf'] = (p['rf'][0] * k, round(p['rf'][1] * k))
        else:
            q['nl'] = (p['nl'][0] * k, round(p['nl'][1] * k), p['nl'][2] * k)
            q['fl'] = (p['fl'][0] * k, round(p['fl'][1] * k), p['fl'][2] * k)
        out.append(q)
    return out


# ---------------------------------------------------------------- 7 位的头发（正面 / 背面）
def put_face(F, x, y, col):
    """五官只画在露出来的脸上（被刘海盖住的就不画）"""
    x, y = int(math.floor(x)), int(math.floor(y))
    if 0 <= x < FW and 0 <= y < FH and F.part[y][x] == 'face':
        F.ov[(x, y)] = col


SPIKES = {   # 头顶翘起来的几根（相对头顶：x0, y0, x1, y1）
    '青年': [(-1.5, 2.0, -3.2, -1.6), (1.0, 1.5, 2.6, -1.8), (4.5, 2.5, 7.0, 0.2)],
    '男孩': [(-3.0, 2.0, -5.0, -0.8), (0.0, 1.5, 0.6, -1.8), (3.0, 2.0, 5.2, -0.6)],
}


def tails(F, P, g, dy, hm, kind, sides=(-1, 1), side_view=None):
    """08 的双马尾、11 的麻花辫。side_view=(sx, f, hr) 时只画一条、挂在耳朵后面"""
    c = CX
    frx = P['face_rx']
    eye = g['eye'] + dy
    shy = g['sh'] + dy
    for side in sides:
        nm = 'tail%d' % side
        if side_view is None:
            if kind == 'pig':
                ax, ay = c + side * (frx + 1.0), eye + 3.0
                mx_, my_ = c + side * (frx + 3.2), eye + 10.0
                bx_, by_ = c + side * (frx + 3.4), shy + 12.0
            else:
                ax, ay = c + side * (frx + 0.6), eye + 2.5
                mx_, my_ = None, None
                bx_, by_ = c + side * (frx + 3.6), shy + 3.5
        else:
            sx, f, hr = side_view
            if kind == 'pig':
                ax, ay = sx(-3.0), eye + 3.0
                mx_, my_ = sx(-hr - 0.5), eye + 10.0
                bx_, by_ = sx(-hr - 0.2), shy + 12.0
            else:
                ax, ay = sx(-2.5), eye + 2.5
                mx_, my_ = None, None
                bx_, by_ = sx(-hr - 1.5), shy + 3.5
        if kind == 'pig':
            F.capsule(mx_, my_, bx_, by_, 2.9, 0.5, nm, 'tail', hm, shd=('sph', mx_ - 1.5, my_ - 2, 4.5, 11))   # 发梢收尖
            F.capsule(ax, ay, mx_, my_, 2.2, 2.9, nm, 'tail', hm, shd=('sph', mx_ - 1.5, my_ - 4, 4.5, 11))
            hair_bands(F, lambda px, py, ax=ax: (px - ax) * 1.1 + (py - ay) * 0.20, 2.2, ay - 3, by_ + 3, parts=(nm,), hi=0.22, lo=0.70)
            for x in range(int(ax - 3), int(ax + 4)):
                F.recolor(x, ay + 1, mat='brass', only=(nm,))
                F.recolor(x, ay + 2, mat='brass', dl=-1, only=(nm,))
        else:
            n = 4
            F.selfcast.add(nm)
            F.ellipse(bx_ + side * 0.3, by_ + 2.4, 1.1, 1.4, nm, 'tail', hm, shd=('flat', -1))   # 发梢
            for i in reversed(range(n)):      # 从下往上画：上面一节压下面一节，接缝自己投影
                t = i / (n - 1)
                px_, py_ = ax + (bx_ - ax) * t, ay + (by_ - ay) * t
                F.ellipse(px_, py_, 1.9, 1.7, nm, 'tail', hm, shd=('sph', px_ - 0.8, py_ - 0.9, 2.6, 2.6))
            for s2 in (-1, 1):               # 青绿色发带蝴蝶结，扎在最后一节底下
                F.ellipse(bx_ + s2 * 1.5, by_ + 1.2, 1.4, 1.1, 'ribbon%d' % side, 'ribbon', 'jacket_teal', shd=('flat', 0))


def hair_front2(F, P, g, dy, back):
    st = P['hair_style']
    hm = P['hair']
    top = g['top'] + dy
    chin = g['chin'] + dy
    frx = P['face_rx']
    eye = g['eye'] + dy
    c = CX
    kid = P.get('kid', False)
    hh = chin - top
    hshd = ('sph', c - 4, top + 5, frx + 7, 16 if not kid else 13)
    box = (c - frx - 9, top - 6, c + frx + 9, chin + 14)
    def put_hair(test, shd=hshd, part='hair', grp='hair'):
        F.fill(test, box, part, grp, hm, shd)
    if st == 'messy':
        rx = frx + (3.0 if not kid else 3.0)
        ry = hh * 0.40
        cy = top + ry
        m = lobed(c, cy, rx, ry, 17 if not kid else 13, 0.12 if not kid else 0.17, 0.5, pw=1.8)   # 尖尖的乱发梢
        if not back:
            side_bot = eye + (5 if not kid else 3.5)
            part = c - 1.0 if not kid else c + 2.5
            def win(px, py):
                dx = px - part
                if not kid:
                    edge = eye - 5.5 + 2.8 * tipwave(dx + 1.7, 3.4)
                    edge -= 2.0 * max(0.0, 1 - abs(dx) / 2.0)
                elif dx < 0:                  # 12 男孩：刘海从右边分、往左斜着盖下来（GPT 这样）
                    edge = eye - 4.6 + min(2.6, -dx * 0.36) + 1.2 * tipwave(dx, 2.6)
                else:
                    edge = eye - 5.2 + 1.0 * tipwave(dx, 2.6)
                return py > edge and abs(px - c) < frx - 1.6
            def mass(px, py):
                if win(px, py) or py > side_bot - max(0.0, abs(px - c) - frx) * 0.9:
                    return False
                if m(px, py):
                    return True
                for side in (-1, 1):          # 鬓边两绺，尖尖地垂到脸颊
                    lx = c + side * (frx - 0.2)
                    if eye - 4 <= py <= side_bot + 1:
                        k = (side_bot + 1 - py) / (side_bot + 1 - (eye - 4))
                        if abs(px - lx) <= 2.4 * k:
                            return True
                return False
            put_hair(mass)
            hair_bands(F, lambda px, py: math.atan2(py - (top - 3), px - part) * 11, 2.8, top - 4, side_bot + 2, hi=0.13, lo=0.66)
        else:
            m2 = lobed(c, cy + 1, rx, ry + 1.5, 17 if not kid else 13, 0.12 if not kid else 0.17, 0.5, pw=1.8)
            put_hair(lambda px, py: m2(px, py) and py < chin - 1.5 + 2.0 * tipwave(px - c + 1.5, 3.2))
            hair_bands(F, lambda px, py: math.atan2(py - (top + 5), px - c) * 9 + math.hypot(px - c, py - top - 5) * 0.2,
                       3.2, top - 4, chin + 2, hi=0.12, lo=0.72)
        for (x0, y0, x1, y1) in SPIKES.get(P['name'], []):
            F.capsule(c + x0, top + y0, c + x1, top + y1, 0.9, 0.5, 'hair', 'hair', hm, hshd)
    elif st == 'crew':
        gsh = ('sph', c - 5, top + 4, frx + 8, 16)
        if not back:
            m = lobed(c, top + 8.6, frx + 1.8, 8.8, 22, 0.05, 0.3)
            def win(px, py):
                dx = abs(px - c)
                return py > top + 7.4 + dx * dx * 0.02 - 0.8 * max(0.0, 1 - abs(px - c - 1) / 3) and dx < frx - 2.3
            def mass(px, py):
                if win(px, py) or py > eye + 3:
                    return False
                if m(px, py):
                    return True
                for side in (-1, 1):          # 短鬓角
                    if ((px - (c + side * (frx - 0.4))) / 2.4) ** 2 + ((py - (top + 11.5)) / 4.2) ** 2 <= 1:
                        return True
                return False
            put_hair(mass, shd=('flat', 0))
            F.capsule(c + 1, top + 1.5, c + 2.6, top - 0.8, 1.0, 0.6, 'hair', 'hair', hm, ('flat', 0))
            curly(F, box, 11, gsh, spacing=3.0)
        else:
            put_hair(lambda px, py: (abs(px - c) / (frx + 1.9)) ** 2.4 + (abs(py - (top + 12)) / 14.0) ** 2.4 <= 1
                     and py < chin - 3.5, shd=('flat', 0))
            F.capsule(c + 1, top + 1.5, c + 2.6, top - 0.8, 1.0, 0.6, 'hair', 'hair', hm, ('flat', 0))
            curly(F, box, 12, gsh, spacing=3.0)
    elif st == 'updo':
        bx, by = c, top - 0.6
        def bun():
            F.ellipse(bx, by, 6.2, 4.4, 'bun', 'hairbun', hm, shd=('sph', bx - 2, by - 2, 7.5, 6))
            hair_bands(F, lambda px, py: math.atan2(py - by, px - bx) * 4 + math.hypot(px - bx, py - by) * 0.7, 2.4,
                       top - 6, top + 5, parts=('bun',), hi=0.2, lo=0.72)
            for x in range(int(bx - 7), int(bx + 8)):      # 发髻底下一道金发箍
                y = by + 2.2 - ((x + 0.5 - bx) / 6.2) ** 2 * 1.6
                F.recolor(x, y, mat='trim_gold', only=('bun',))
        if not back:
            bun()
            mm = lobed(c, top + 10, frx + 2.9, 10.4, 18, 0.07, 0.4)
            def win(px, py):
                return py > top + 7.4 + abs(px - c) * 0.55 and abs(px - c) < frx - 1.8
            def mass(px, py):
                if win(px, py):
                    return False
                if mm(px, py):
                    return True
                for side in (-1, 1):          # 两边蓬起来的卷发
                    if ((px - (c + side * (frx + 1.1))) / 3.5) ** 2 + ((py - (eye - 2)) / 6.8) ** 2 <= 1:
                        return True
                return False
            put_hair(mass, shd=('flat', 0))
            curly(F, box, 21, hshd, spacing=3.4)
            for side in (-1, 1):              # 鬓边垂下来的小卷
                x0 = c + side * (frx - 0.3)
                pts = [(x0, eye + 1), (x0 + side * 1.3, eye + 4), (x0 - side * 0.1, eye + 7), (x0 + side * 0.9, chin + 0.5)]
                for (a, b) in zip(pts, pts[1:]):
                    F.capsule(a[0], a[1], b[0], b[1], 0.9, 0.9, 'wisp', 'hair', hm, ('flat', -1))
        else:
            mm = lobed(c, top + 11, frx + 2.9, 11.6, 18, 0.07, 0.4)
            put_hair(lambda px, py: mm(px, py) and py < chin - 3, shd=('flat', 0))
            curly(F, box, 22, hshd, spacing=3.4)
            for side in (-1, 1):
                F.capsule(c + side * 4.5, chin - 4, c + side * 5.2, chin - 0.5, 0.9, 0.7, 'wisp', 'hair', hm, ('flat', -1))
            bun()
    elif st == 'wavy':
        part = c - 3
        def wav(px, py):
            dx = px - c
            if py < top + 11:
                return (abs(dx) / (frx + 3.4)) ** 2.3 + (abs(py - (top + 11)) / 11.3) ** 2.3 <= 1
            sg = 0.0 if dx > 0 else 1.9
            hw = frx + 3.4 + min(2.4, (py - (top + 11)) * 0.17) + 1.1 * math.sin((py - top) * 0.40 + sg)
            bot = (chin + 7 if not back else chin + 10) + 1.2 * math.sin(px * 0.72 + 0.5)
            return abs(dx) <= hw and py <= bot
        hs = ('sph', c - 4, top + 6, frx + 7, 19)
        if not back:
            def win(px, py):
                if py > chin + 0.5:
                    return abs(px - c) < frx - 4.4 + (py - chin) * 0.6
                if px >= part:
                    edge = min(eye - 2.0, eye - 4.6 + (px - part) * 0.34)
                else:
                    edge = eye - 4.6 + (part - px) * 0.55
                return py > edge and abs(px - c) < frx - 2.6 - max(0.0, py - (chin - 4)) * 0.5
            put_hair(lambda px, py: wav(px, py) and not win(px, py), shd=hs)
            hair_bands(F, lambda px, py: math.atan2(py - (top - 3), px - part) * 10 + 1.1 * math.sin(py * 0.40), 3.6,
                       top + 1, chin + 12, hi=0.18, lo=0.74)
            for y in range(int(top) + 1, int(top) + 5):
                F.recolor(part - 0.5 + (y - top) * 0.3, y, dl=-2, only=('hair',))
            for side in (-1, 1):              # 金耳环
                ex_ = c + side * (frx - 0.3) - 0.5
                F.put(ex_, eye + 5, brass(3), force=True)
                F.put(ex_, eye + 6, brass(2), force=True)
        else:
            put_hair(wav, shd=hs)
            hair_bands(F, lambda px, py: (px - c) + 1.8 * math.sin((py - top) * 0.36), 3.8, top + 1, chin + 13, hi=0.16, lo=0.76)
    elif st == 'pigtails':
        def mass0(px, py):
            dx = abs(px - c)
            if (dx / (frx + 2.6)) ** 2.3 + (abs(py - (top + 10.5)) / 10.8) ** 2.3 <= 1:
                return True
            return dx <= frx + 2.0 - max(0.0, py - (eye + 2)) * 0.3 and top + 10 <= py <= chin - 1
        if not back:
            def win(px, py):
                dx = px - c
                edge = eye - 3.4 + 1.3 * tipwave(dx + 1.4, 2.8)
                edge -= 2.6 * max(0.0, 1 - abs(dx + 0.5) / 1.6)
                return py > edge and abs(dx) < frx - 2.0
            put_hair(lambda px, py: mass0(px, py) and not win(px, py))
            hair_bands(F, lambda px, py: math.atan2(py - (top - 2), px - (c - 0.5)) * 11, 2.8, top, chin + 1, hi=0.2, lo=0.72)
        else:
            put_hair(mass0)
            hair_bands(F, lambda px, py: math.atan2(py - (top + 1), px - c) * 9, 3.2, top, chin + 1, hi=0.16, lo=0.76)
            for y in range(int(top) + 1, int(chin) - 2):
                F.recolor(c - 0.5, y, dl=-2, only=('hair',))
        tails(F, P, g, dy, hm, 'pig')
    elif st == 'braids':
        rx = frx + 2.6
        ry = hh * 0.43
        cy = top + ry
        m = lobed(c, cy, rx, ry, 16, 0.09, 0.3)
        if not back:
            side_bot = eye + 3
            def win(px, py):
                dx = px - c
                edge = eye - 3.0 + 1.2 * tipwave(dx + 1.2, 2.6) - 2.2 * max(0.0, 1 - abs(dx + 0.5) / 1.6)
                return py > edge and abs(dx) < frx - 1.6
            put_hair(lambda px, py: m(px, py) and not win(px, py) and py < side_bot - max(0.0, abs(px - c) - frx) * 0.6)
            hair_bands(F, lambda px, py: math.atan2(py - (top - 2), px - (c - 0.5)) * 10, 2.6, top - 2, chin, hi=0.2, lo=0.72)
        else:
            put_hair(lambda px, py: m(px, py) and py < chin - 1)
            hair_bands(F, lambda px, py: math.atan2(py - (top + 1), px - c) * 9, 3.0, top - 2, chin, hi=0.16, lo=0.76)
            for y in range(int(top) + 1, int(chin) - 2):
                F.recolor(c - 0.5, y, dl=-2, only=('hair',))
        tails(F, P, g, dy, hm, 'braid')


def ear_u(P):
    """侧面耳朵：(中心 u, 后沿 u)，u 从头的中心往脸那边为正"""
    if P.get('kid'):
        return -2.1, -3.6
    return -2.8, -4.7


def side_ear(F, P, g, dy, sx, f, hc):
    """侧面耳朵：自己一组，后半圈描边（贴脸那半不描），里面点两点暗：看得出是耳朵、不是肉疙瘩"""
    kid = P.get('kid', False)
    e = g['eye'] + dy
    uc = ear_u(P)[0]
    rx, ry = (1.3, 1.9) if kid else (1.7, 2.4)
    cx, cy = sx(hc + uc), e + 2.5
    F.ellipse(cx, cy, rx, ry, 'ear', 'ear', P['skin'], shd=('flat', 0))
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not F.has(x, y, ('ear',)):
                continue
            by_hair = any(F.has(x + dx, y + dy, ('hair',)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if (x + 0.5 - cx) * f > 0.2 or by_hair:    # 贴脸那半、挨着黑头发的不描边
                F.noline.add((x, y))
    F.put(sx(hc + uc + 0.2), cy - 0.5, RAMPS[P['skin']][1])
    F.put(sx(hc + uc + 0.2), cy + 0.5, RAMPS[P['skin']][2])


# ---------------------------------------------------------------- 7 位的头发（侧面）
def hair_side2(F, P, g, dy, sx, f, hc, hr):
    st = P['hair_style']
    hm = P['hair']
    top = g['top'] + dy
    chin = g['chin'] + dy
    e = g['eye'] + dy
    shy = g['sh'] + dy
    kid = P.get('kid', False)
    hh = chin - top
    def uu(px):
        return (px - CX) * f - hc
    shd = ('sph', sx(hc + 1) - 2.0, top + 4, hr + 6, 15 if not kid else 12)
    box = (0, top - 6, FW, chin + 14)
    def ell(u, py, rx, cy, ry_up, ry_dn):
        ry = ry_up if py < cy else ry_dn
        return (abs(u) / rx) ** 2.3 + (abs(py - cy) / ry) ** 2.3 <= 1
    if st == 'messy':
        rx = hr + (3.0 if not kid else 2.4)
        ry = hh * 0.41
        mass = lobed(sx(hc - 1.0), top + ry, rx, ry, 16 if not kid else 13, 0.13 if not kid else 0.17,
                     0.4 if f < 0 else 2.0, pw=1.8)
        u_side = -0.6
        def h(px, py):
            if not mass(px, py):
                return False
            u = uu(px)
            # 刘海：几绺尖尖地往前、往下戳（不再是平平一刀的锅盖）
            tip = tipwave(u + 0.8, 3.8 if not kid else 3.0, sharp=2.4)
            if u > u_side and py > e - (6.8 if not kid else 4.8) + (4.6 if not kid else 2.8) * tip + max(0.0, u - hr + 3) * 0.6:
                return False
            ub = ear_u(P)[1]
            if u >= ub:                      # 鬓角 + 耳朵上面
                return py <= e - 0.5
            # 耳朵后面：发脚从耳朵后沿往后斜下去
            return py <= min(chin - 1.5 + 2.0 * tipwave(px, 3.0), e + 2.0 + (ub - u) * 1.0)
        F.fill(h, box, 'hair', 'hair', hm, shd)
        hair_bands(F, lambda px, py: math.atan2(py - (top - 2), (px - sx(-hr)) * f) * 10, 2.8, top - 4, chin + 2, hi=0.13, lo=0.66)
        for (x0, y0, x1, y1) in SPIKES.get(P['name'], []):
            F.capsule(sx(x0 * 0.5 - 1.0), top + y0, sx(x1 * 0.5 - 2.0), top + y1, 0.9, 0.5, 'hair', 'hair', hm, shd)
    elif st == 'crew':
        u_side = -0.4
        def h(px, py):
            u = uu(px)
            if not ell(u + 0.5, py, hr + 1.8, top + 9.5, 10.2, 10.2 if u > u_side else 15.5):
                return False
            if u > u_side and py > top + 7.5 + max(0.0, hr - 1 - u) * 0.12:
                return False
            ub = ear_u(P)[1]
            if u >= u_side - 1.5:            # 鬓角
                return py <= e - 0.5
            if u >= ub:                      # 耳朵上面
                return py <= e + 0.5
            return py <= min(chin - 3.0, e + 1.5 + (ub - u) * 1.1)
        F.fill(h, box, 'hair', 'hair', hm, ('flat', 0))
        F.capsule(sx(1.0), top + 1.5, sx(2.4), top - 0.8, 1.0, 0.6, 'hair', 'hair', hm, ('flat', 0))
        curly(F, box, 13 if f < 0 else 14, ('sph', sx(hc + 1) - 3.0, top + 4, hr + 8, 16), spacing=3.0)
    elif st == 'updo':
        u_side = 0.6
        def h(px, py):
            u = uu(px)
            if not ell(u + 0.5, py, hr + 2.2, top + 10, 10.4, 10.4 if u > u_side else 14.5):
                return False
            if u > u_side and py > top + 8.0 + max(0.0, hr - 2 - u) * 0.10:
                return False
            if u >= u_side - 1.5:
                return py <= e + 4
            return py <= min(chin - 3.5, e + 4 + (u_side - 1.5 - u) * 0.6)
        F.fill(h, box, 'hair', 'hair', hm, ('flat', 0))
        curly(F, box, 23 if f < 0 else 24, shd, spacing=3.4)
        bx, by = sx(hc - 2.5), top - 0.6
        F.ellipse(bx, by, 5.8, 4.4, 'bun', 'hairbun', hm, shd=('sph', bx - 2, by - 2, 7, 6))
        hair_bands(F, lambda px, py: math.atan2(py - by, px - bx) * 4 + math.hypot(px - bx, py - by) * 0.7, 2.4,
                   top - 6, top + 5, parts=('bun',), hi=0.2, lo=0.72)
        for x in range(int(bx - 7), int(bx + 8)):
            y = by + 2.4 - ((x + 0.5 - bx) / 5.8) ** 2 * 1.6
            F.recolor(x, y, mat='trim_gold', only=('bun',))
        pts = [(sx(hc + 0.4), e + 2), (sx(hc + 1.4), e + 4.5), (sx(hc + 0.5), chin - 1.5)]
        for (a, b) in zip(pts, pts[1:]):
            F.capsule(a[0], a[1], b[0], b[1], 0.9, 0.9, 'wisp', 'hair', hm, ('flat', -1))
    elif st == 'wavy':
        u_side = 2.4
        def m(px, py):
            u = uu(px) + 0.5
            if py < top + 12:
                return (abs(u) / (hr + 3.4)) ** 2.3 + (abs(py - (top + 12)) / 12.0) ** 2.3 <= 1
            ub = -(hr + 3.4 + min(2.0, (py - top - 12) * 0.15) + 1.1 * math.sin((py - top) * 0.40))
            uf = hr + 3.0
            bot = shy + 7 + 1.2 * math.sin(px * 0.72 + 0.5)
            return ub <= u <= uf and py <= bot
        def h(px, py):
            if not m(px, py):
                return False
            u = uu(px)
            if u > u_side and py > e - 3.0:
                return False
            if u >= u_side - 1.5 and py > chin + 0.5:
                return False
            return True
        F.fill(h, box, 'hair', 'hair', hm, shd)
        hair_bands(F, lambda px, py: uu(px) * 1.0 + (py - top) * 0.30 + 1.4 * math.sin(py * 0.38), 3.6, top + 1, shy + 10, hi=0.18, lo=0.74)
        F.put(sx(0.3), e + 5, brass(3), force=True)
        F.put(sx(0.3), e + 6, brass(2), force=True)
    elif st in ('pigtails', 'braids'):
        pig = st == 'pigtails'
        if pig:
            rx, cy, ry = hr + 2.6, top + 10.5, 10.8
        else:
            rx, ry = hr + 2.6, hh * 0.43
            cy = top + ry
        u_side = 0.8 if pig else 0.4
        mass = lobed(sx(hc - 0.5), cy, rx, ry, 16, 0.09, 0.3) if not pig else None
        def h(px, py):
            u = uu(px)
            if pig:
                if not ell(u + 0.5, py, rx, cy, ry, ry + 5):
                    return False
            elif not mass(px, py):
                return False
            if u > u_side and py > e - (3.4 if pig else 3.0) + 1.2 * tipwave(u, 2.6):
                return False
            if u >= u_side - 1.5:
                return py <= e + (4 if pig else 2.5)
            return py <= min(chin - 1, e + (3 if pig else 2) + (u_side - 1.5 - u) * 0.8)
        F.fill(h, box, 'hair', 'hair', hm, shd)
        hair_bands(F, lambda px, py: uu(px) * 1.0 + (py - top) * 0.30, 3.0, top - 2, chin + 1, hi=0.18, lo=0.74)
        tails(F, P, g, dy, hm, 'pig' if pig else 'braid', sides=(1,), side_view=(sx, f, hr))


# ---------------------------------------------------------------- 7 位的五官
def face2_front(F, P, g, dy, pose):
    fc = P['face2']
    e = g['eye'] + dy
    c = int(CX)
    mouth = pose.get('mouth', fc.get('mouth', 'smile'))
    blink = pose.get('blink', False)
    ic, ic2 = C[fc['iris'][0]], C[fc['iris'][1]]
    cmap = {'D': C['eye'], 'W': C['eye_hl'], 'I': ic, 'J': ic2}
    kind = fc['eye']
    if kind == 'k':
        lx, rx = c - 6, c + 3
        blx, brx = c - 8, c + 5
        my, nose_y = e + 5, e + 3
    else:
        lx, rx = c - 7, c + 4
        blx, brx = c - 10, c + 7
        my, nose_y = e + 7, e + 4
    if kind == 'f':                      # 姑娘：眼睛高 4 格（GPT 年轻女孩眼睛大），上眼线往外多一笔
        eye = ['DDD', 'WII', 'IIJ', '.J.'] if not blink else ['...', '...', 'DDD', '...']
        ey0 = e - 1
    else:
        eye = ['DDD', 'WII', 'IIJ'] if not blink else ['...', 'DDD', '...']
        ey0 = e
    for x0 in (lx, rx):
        for j, row in enumerate(eye):
            for i, ch in enumerate(row):
                if ch in cmap:
                    put_face(F, x0 + i, ey0 + j, cmap[ch])
    if kind == 'f':
        put_face(F, lx - 1, ey0, C['eye'])
        put_face(F, rx + 3, ey0, C['eye'])
    if fc.get('brow') == 'thick':
        for x0 in (lx - 1, rx):
            for d in range(4):
                put_face(F, x0 + d, e - 3, C['brow_dark'])
            for d in ((1, 2) if x0 == lx - 1 else (1, 2)):
                put_face(F, x0 + d, e - 2, C['brow_dark'])
    elif fc.get('brow') == 'thin':
        for x0 in (lx, rx):
            for d in range(3):
                put_face(F, x0 + d, e - 4, C['brow_dark'])
    for x0 in (blx, brx):
        for d in range(3):
            put_face(F, x0 + d, e + 3, C['blush'])
    put_face(F, c, nose_y, RAMPS[P['skin']][2])
    if mouth == 'open':
        for d in (-2, -1, 0, 1):
            put_face(F, c + d, my, C['mouth_dk'])
        put_face(F, c - 2, my + 1, C['mouth_dk'])
        put_face(F, c + 1, my + 1, C['mouth_dk'])
        put_face(F, c - 1, my + 1, C['tongue'])
        put_face(F, c, my + 1, C['tongue'])
    elif mouth == 'grin':                 # 小孩咧嘴笑：小小的 D 字嘴
        put_face(F, c - 2, my - 1, C['mouth'])
        put_face(F, c + 1, my - 1, C['mouth'])
        put_face(F, c - 1, my, C['mouth_dk'])
        put_face(F, c, my, C['mouth_dk'])
        put_face(F, c - 1, my + 1, C['tongue'])
        put_face(F, c, my + 1, C['tongue'])
    else:
        put_face(F, c - 2, my - 1, C['mouth'])
        put_face(F, c - 1, my, C['mouth'])
        put_face(F, c, my, C['mouth'])
        put_face(F, c + 1, my - 1, C['mouth'])


def face2_side(F, P, g, dy, sx, f, hc, hr, pose):
    fc = P['face2']
    e = g['eye'] + dy
    kid = P.get('kid', False)
    fu = hc + hr
    eu = fu - (5.6 if not kid else 4.6)     # 侧脸眼睛 3 宽：eu、eu+1、eu+2（后→前）
    mouth = pose.get('mouth', fc.get('mouth', 'smile'))
    X = sx
    ic, ic2 = C[fc['iris'][0]], C[fc['iris'][1]]
    hl = 0 if f > 0 else 2                  # 高光在画面左上：朝右时在后面那列，朝左时在前面那列
    rows = [['D', 'D', 'D'], ['I', 'I', 'I'], ['I', 'J', 'J']]
    rows[1][hl] = 'W'
    cmap = {'D': C['eye'], 'W': C['eye_hl'], 'I': ic, 'J': ic2}
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            put_face(F, X(eu + i), e + j, cmap[ch])
    if fc['eye'] == 'f':
        put_face(F, X(eu - 1), e, C['eye'])
        put_face(F, X(eu - 1), e - 1, C['eye'])
    if fc.get('brow') == 'thick':
        for d in (-1, 0, 1, 2):
            put_face(F, X(eu + d), e - 3, C['brow_dark'])
        for d in (0, 1):
            put_face(F, X(eu + d), e - 2, C['brow_dark'])
    elif fc.get('brow') == 'thin':
        for d in (-1, 0, 1):
            put_face(F, X(eu + d), e - 3, C['brow_dark'])
    put_face(F, X(eu - 1), e + 3, C['blush'])
    put_face(F, X(eu - 2), e + 3, C['blush'])
    my = e + (7 if not kid else 5)
    mu = fu - 1.4
    if mouth in ('open', 'grin'):
        put_face(F, X(mu), my, C['mouth_dk'])
        put_face(F, X(mu - 1), my, C['mouth_dk'])
        put_face(F, X(mu), my + 1, C['tongue'])
    else:
        put_face(F, X(mu), my, C['mouth'])
        put_face(F, X(mu - 1), my - 1, C['mouth'])


# ---------------------------------------------------------------- 动作表
def walk_poses(d, k=1.0):
    """每个朝向 4 格。0 站定（全高，游戏量身高用它）、1 迈一只脚、2 过渡、3 迈另一只脚。
    k：小孩的步幅（大人 1.0 原样返回）"""
    if k != 1.0:
        return walk_poses_kid(d, k)
    if d in ('down', 'up'):
        return [
            dict(bob=0, lf=(0, 0), rf=(0, 0), la=0.0, ra=0.0),
            dict(bob=1, lf=(0, 3), rf=(0.6, 0), la=1.0, ra=-1.0),
            dict(bob=0, lf=(0, 0), rf=(0, 1), la=0.15, ra=-0.15),
            dict(bob=1, lf=(-0.6, 0), rf=(0, 3), la=-1.0, ra=1.0),
        ]
    # 侧面：nl/fl = (脚往前多少, 抬脚, 膝盖往前弯)；na/fa 手往前摆（-1～1）
    return [
        dict(bob=0, nl=(1.0, 0, 0.3), fl=(-1.0, 0, 0.3), na=0.0, fa=0.0),
        dict(bob=1, nl=(6.5, 0, 0.3), fl=(-6.0, 1, -0.6), na=-1.0, fa=1.0),
        dict(bob=0, nl=(-1.0, 0, 0.3), fl=(2.0, 3, 3.0), na=-0.15, fa=0.15),
        dict(bob=1, nl=(-6.0, 1, -0.6), fl=(6.5, 0, 0.3), na=1.0, fa=-1.0),
    ]


def make_frame(P, d, pose):
    F = Fig()
    kind = pose.get('kind', 'walk')
    if kind == 'sit' and d in ('down', 'up'):
        draw_front_sit(F, P, pose, back=(d == 'up'))
    elif d in ('down', 'up'):
        draw_front(F, P, pose, back=(d == 'up'))
    else:
        draw_side(F, P, pose, -1 if d == 'left' else 1)
    if P['name'] == '叔叔':
        g = geom(P)
        v0 = g['sh'] + pose.get('bob', 0) + (g['sit_dy'] if kind == 'sit' else 0)
        floral(F, CX - 6, v0)
    if 'face2' in P:
        post2(F, P, d, pose)
    return F.render()


def all_frames(P):
    frames = []
    for d in ('down', 'left', 'right', 'up'):
        for pose in walk_poses(d, P.get('ks', 1.0)):
            pose = dict(pose, kind='walk', arms='free')
            frames.append(make_frame(P, d, pose))
    extra = []
    ia = P['idle_arms']
    base = dict(lf=(0, 0), rf=(0, 0), la=0, ra=0, arms=ia)
    extra.append(make_frame(P, 'down', dict(base, kind='idle', bob=0)))
    extra.append(make_frame(P, 'down', dict(base, kind='idle', bob=1)))
    extra.append(make_frame(P, 'down', dict(base, kind='talk', bob=0, arms='talk', talk_side=-1, talk_h=0.22, mouth='open')))
    extra.append(make_frame(P, 'down', dict(base, kind='talk', bob=0, head_dy=1, arms='talk', talk_side=-1, talk_h=0.36, mouth='smile')))
    for d in ('down', 'left', 'right', 'up'):
        for k in range(2):
            extra.append(make_frame(P, d, dict(kind='sit', bob=k, la=0, ra=0, fa=0, na=0)))
    return frames, extra


def build_atlas(code):
    P = CHARS[code]
    walk, extra = all_frames(P)
    im = Image.new('RGBA', (FW * 16, FH * 2), (0, 0, 0, 0))
    for i, fr in enumerate(walk):
        im.paste(fr, (i * FW, 0))
    for i, fr in enumerate(extra):
        im.paste(fr, (i * FW, FH))
    g = geom(P)
    bb = im.crop((0, 0, FW, FH)).getbbox()
    drawn_h = bb[3] - bb[1]
    j = {
        'frame': [FW, FH],
        'frames': {'down': [0, 1, 2, 3], 'left': [4, 5, 6, 7], 'right': [8, 9, 10, 11], 'up': [12, 13, 14, 15],
                   'idle': [16, 17], 'talk': [18, 19],
                   'sit_down': [20, 21], 'sit_left': [22, 23], 'sit_right': [24, 25], 'sit_up': [26, 27]},
        'fps': 8,
        'height_m': round(1.75 * drawn_h / 84, 4),
        'idle_fps': 2, 'talk_fps': 3, 'sit_fps': 1,
        'sit_seat': {'down': g['knee_sit'] + int(P['leg_r'] + 0.5), 'left': g['seat'], 'right': g['seat'], 'up': g['seat']},
        'sit_note': ('坐着的四个朝向，脚点照旧是格子下沿正中（朝下、朝左右的脚就踩在最后一行）：摆的时候把脚点放在座位前沿的地上就行，'
                     'lounge_preview.png 就是这么摆的。sit_seat 是坐垫面在格子里的哪一行（朝下 = 膝盖底下、朝左右 = 屁股和大腿底下、'
                     '朝上 = 屁股底），要按坐垫高度对齐时用。'),
        'note': ('draw_chars.py 生成（Claude 代码画），别手改。整张 1024×168：第一行 16 格跟 GPT 那份一样'
                 '（下 0-3、左 4-7、右 8-11、上 12-15，走路，第 0 格是站定）；第二行是多出来的：idle 16-17 朝下站着呼吸、'
                 'talk 18-19 朝下说话（抬手/点头）、sit_* 20-27 坐着四个朝向各 2 格（第 2 格是呼吸）。'
                 '脚踩格子最后一行、左右中线 x=32；height_m 照画出来的高（%d 像素）÷84×1.75 算，'
                 '游戏照 height_m 缩放以后还是一比一（量的是第 0 格）。坐着见 sit_note。' % drawn_h),
    }
    if code in NEW7:     # 新画的 7 位：说明里写清是 draw_chars2.py 出的；旧四位的 json 一个字不改
        j['sit_note'] = j['sit_note'].replace('lounge_preview.png 就是这么摆的', 'scene_preview.png 就是这么摆的')
        j['note'] = j['note'].replace('draw_chars.py 生成', 'draw_chars2.py 生成')
        if P.get('kid'):
            j['note'] += ('小孩：头 = 0.46 × 身高（大人 0.38）、腿 %.2f × 身高、鞋 3 像素高，走路步幅、摆手 ×%.2f；'
                          '坐着照大人的画法画（脚踩格子底），坐垫面比大人低 3 像素：按 sit_seat 对齐放在大人椅子上，脚会离地约 3 像素（没画成晃腿），要摆小孩坐先找 01。' % (P['leg_frac'], P['ks']))
    return im, j


# ---------------------------------------------------------------- 预览
def gpt_frame(code, i):
    im = Image.open(GPT_DIR + 'chr_LM-GUEST-%s.png' % code).convert('RGBA')
    return im.crop((i * FW, 0, i * FW + FW, FH))


def atlas_frame(a, idx):
    return a.crop(((idx % 16) * FW, (idx // 16) * FH, (idx % 16) * FW + FW, (idx // 16) * FH + FH))


def checker_bg(w, h, a=(206, 200, 190), b=(196, 190, 180), s=8):
    bg = Image.new('RGBA', (w, h), a + (255,))
    px = bg.load()
    for y in range(h):
        for x in range(w):
            if ((x // s) + (y // s)) % 2:
                px[x, y] = b + (255,)
    return bg


def compare_sheet(atlases, path):
    """每位一块：GPT 原图 8 格（正面站、正面走、左、左走、右、右走、背、背走）｜ 代码同样 8 格 ｜ 代码第二行 8 格，放大 2 倍"""
    S = 2
    pick = (0, 1, 4, 5, 8, 9, 12, 13)
    pick2 = (16, 18, 19, 20, 22, 24, 26, 3)
    blocks = []
    for code in ('09', '10', '05', '06'):
        gpt = Image.open(GPT_DIR + 'chr_LM-GUEST-%s.png' % code).convert('RGBA')
        blk = Image.new('RGBA', (FW * 8, FH * 3), (0, 0, 0, 0))
        for c, i in enumerate(pick):
            blk.paste(atlas_frame(gpt, i), (c * FW, 0))
            blk.paste(atlas_frame(atlases[code], i), (c * FW, FH))
        for c, i in enumerate(pick2):
            blk.paste(atlas_frame(atlases[code], i), (c * FW, FH * 2))
        blocks.append(blk)
    W = FW * 8 * S * 2 + 16
    H = FH * 3 * S * 2 + 16
    out = checker_bg(W, H)
    for k, b in enumerate(blocks):
        bb = b.resize((b.width * S, b.height * S), Image.NEAREST)
        out.paste(bb, ((k % 2) * (bb.width + 16), (k // 2) * (bb.height + 16)), bb)
    out.save(path)


def lineup(atlases, path):
    S = 3
    gap = 8
    W = (FW * 4 + gap * 5) * S
    H = (FH * 2 + gap * 3) * S
    out = checker_bg(W, H, (214, 208, 198), (204, 198, 188), 12)
    for k, code in enumerate(('09', '10', '05', '06')):
        g = gpt_frame(code, 0).resize((FW * S, FH * S), Image.NEAREST)
        m = atlas_frame(atlases[code], 16).resize((FW * S, FH * S), Image.NEAREST)
        x = (gap + k * (FW + gap)) * S
        out.paste(g, (x, gap * S), g)
        out.paste(m, (x, (gap * 2 + FH) * S), m)
    px = out.load()
    for yb in ((gap + FH) * S, (gap * 2 + FH * 2) * S):
        for x in range(W):
            for t in range(2):
                px[x, yb + t] = (150, 60, 50, 255)
    out.save(path)


def walk_strip(atlases, path):
    S = 2
    W = FW * 16 * S
    H = FH * 4 * S
    out = checker_bg(W, H)
    for k, code in enumerate(('09', '10', '05', '06')):
        row = atlases[code].crop((0, 0, FW * 16, FH)).resize((W, FH * S), Image.NEAREST)
        out.paste(row, (0, k * FH * S), row)
    out.save(path)


# 休息间里四位的位置（画布坐标，脚点 = 格子下沿正中）：(编号, 格号, 脚点 x, 脚点 y)
LOUNGE_PEOPLE = [
    ('09', 20, 551, 270),     # 奶奶 北边三人沙发 朝下坐
    ('10', 21, 584, 270),     # 爷爷 北边三人沙发 朝下坐（第 2 格，跟奶奶错开呼吸）
    ('05', 24, 404, 418),     # 叔叔 西边茶座西椅 朝右坐
    ('06', 22, 462, 418),     # 阿姨 西边茶座东椅 朝左坐
]


def ensure_lounge():
    """休息间底图：没有就用 git show 从 build57 分支读出来（只读仓库，不改）"""
    if os.path.exists(os.path.join(LOUNGE, 'room.json')):
        return
    import subprocess
    base = 'godot/assets/pixel_art/backhall_lounge/'
    names = subprocess.run(['git', '-C', REPO, 'ls-tree', '-r', '--name-only', 'build57', '--', base],
                           capture_output=True, text=True, check=True).stdout.split()
    for n in names:
        if n.endswith('.import'):
            continue
        dst = os.path.join(LOUNGE, n[len(base):])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        data = subprocess.run(['git', '-C', REPO, 'show', 'build57:' + n], capture_output=True, check=True).stdout
        with open(dst, 'wb') as fp:
            fp.write(data)


def lounge_preview(atlases, path, people=None):
    ensure_lounge()
    jj = json.load(open(os.path.join(LOUNGE, 'room.json')))
    bg = jj['background']
    Wc, Hc = 1100, 900
    can = Image.new('RGBA', (Wc, Hc), (43, 32, 30, 255))
    room = Image.open(os.path.join(LOUNGE, 'room.png')).convert('RGBA')
    can.paste(room, (bg['x'], bg['y']), room)
    items = []
    for p in jj['props']:
        im = Image.open(os.path.join(LOUNGE, 'props', p['png'].split('/')[-1])).convert('RGBA')
        items.append((p['foot'], 0, im, p['x'], p['y']))
    for (code, idx, fx, fy) in (people or LOUNGE_PEOPLE):
        im = atlas_frame(atlases[code], idx)
        items.append((fy + 0.5, 1, im, fx - FW // 2, fy - FH + 1))
    items.sort(key=lambda t: (t[0], t[1]))
    for _, _, im, x, y in items:
        can.paste(im, (x, y), im)
    cx = (jj['room']['x0'] + jj['room']['x1']) // 2
    x0 = cx - 270
    y0 = 400 - 480
    shot = Image.new('RGBA', (540, 960), (43, 32, 30, 255))
    crop = can.crop((max(0, x0), max(0, y0), x0 + 540, y0 + 960))
    shot.paste(crop, (max(0, -x0), max(0, -y0)))
    shot.save(path)
    return can


def walk_gif(atlases, path):
    """四位一行、四个朝向四列，循环走路，放大 2 倍，8 帧/秒"""
    S = 2
    frames = []
    for k in range(4):
        can = checker_bg(FW * 4 * S, FH * 4 * S)
        for r, code in enumerate(('09', '10', '05', '06')):
            for c, d in enumerate((0, 4, 8, 12)):
                f = atlas_frame(atlases[code], d + k).resize((FW * S, FH * S), Image.NEAREST)
                can.paste(f, (c * FW * S, r * FH * S), f)
        frames.append(can.convert('P', palette=Image.ADAPTIVE, colors=255))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=125, loop=0, disposal=1)


def check(atlases):
    """硬规矩自查：透明度只有 0/255；站着第 0 格的高；坐着的高；色数；头身比"""
    for code in ALL11:
        im = atlases[code]
        hist = im.split()[3].histogram()
        bad = sum(hist[1:255])
        bb = im.crop((0, 0, FW, FH)).getbbox()
        sb = atlas_frame(im, 20).getbbox()
        sl = atlas_frame(im, 22).getbbox()
        cols = len(set(p for p in im.getdata() if p[3] == 255))
        g = geom(CHARS[code])
        print('%s %-4s 半透明 %d | 站着 %d 高 宽 %d | 头 %d（%.2f）| 朝下坐 %d 高 | 侧坐 %d 高 | 色数 %d%s' % (
            code, CHARS[code]['name'], bad, bb[3] - bb[1], bb[2] - bb[0], g['head_h'], g['head_h'] / (CHARS[code]['H'] - CHARS[code]['extra']),
            sb[3] - sb[1], sl[3] - sl[1], cols, '  <-- 超 64 色' if cols > 64 else ''))


def verify_old4():
    """旧四位：重出来的图集、json 跟已进游戏的样板逐像素 / 逐字节比"""
    from PIL import ImageChops
    ok = True
    for code in OLD4:
        a = Image.open(os.path.join(HERE, 'check4', 'chr_CODE-GUEST-%s.png' % code)).convert('RGBA')
        b = Image.open(SAMPLE4 + 'chr_CODE-GUEST-%s.png' % code).convert('RGBA')
        d = ImageChops.difference(a, b).getbbox()
        ja = open(os.path.join(HERE, 'check4', 'chr_CODE-GUEST-%s.json' % code), 'rb').read()
        jb = open(SAMPLE4 + 'chr_CODE-GUEST-%s.json' % code, 'rb').read()
        same = d is None and a.size == b.size and ja == jb
        ok = ok and same
        print('旧四位核对 %s %s：图 %s，json %s' % (code, CHARS[code]['name'], '一样' if d is None else '不一样 %s' % (d,),
                                              '一样' if ja == jb else '不一样'))
    print('旧四位跟样板一模一样' if ok else '!!! 旧四位跟样板不一样')
    return ok


ORDER = ALL11


def lineup_all(atlases, path):
    """三排同一条底线：GPT 第 0 格 ｜ 代码第 0 格 ｜ 代码待机第 1 格（格号 16，跟样板 lineup 一样），放大 2 倍；一列一位，顺序 01～12"""
    S = 2
    gap = 6
    n = len(ORDER)
    W = (FW * n + gap * (n + 1)) * S
    H = (FH * 3 + gap * 4) * S
    out = checker_bg(W, H, (214, 208, 198), (204, 198, 188), 12)
    for k, code in enumerate(ORDER):
        x = (gap + k * (FW + gap)) * S
        for r, im in enumerate((gpt_frame(code, 0), atlas_frame(atlases[code], 0), atlas_frame(atlases[code], 16))):
            im = im.resize((FW * S, FH * S), Image.NEAREST)
            out.paste(im, (x, (gap * (r + 1) + FH * r) * S), im)
        if code in NEW7:     # 新画的那几列底下点一道绿
            for xx in range(x + 8, x + FW * S - 8):
                for t in range(3):
                    out.putpixel((xx, H - 5 + t), (70, 140, 80, 255))
    px = out.load()
    for r in range(3):
        yb = (gap * (r + 1) + FH * (r + 1)) * S
        for x in range(W):
            for t in range(2):
                px[x, yb + t] = (150, 60, 50, 255)
    out.save(path)


def walk_gif_all(atlases, path):
    """11 位一列一位、四个朝向四排（下 左 右 上），循环走，放大 2 倍，8 帧/秒"""
    S = 2
    n = len(ORDER)
    frames = []
    for k in range(4):
        can = checker_bg(FW * n * S, FH * 4 * S)
        for c, code in enumerate(ORDER):
            for r, d in enumerate((0, 4, 8, 12)):
                f = atlas_frame(atlases[code], d + k).resize((FW * S, FH * S), Image.NEAREST)
                can.paste(f, (c * FW * S, r * FH * S), f)
        frames.append(can.convert('RGB').quantize(colors=255, method=Image.MEDIANCUT, dither=Image.NONE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=125, loop=0, disposal=1)


def compare_sheet2(atlases, path, codes=NEW7):
    """每位一块：上 GPT 原图 8 格（正面站、正面走、左、左走、右、右走、背、背走）｜中 代码同样 8 格 ｜下 代码第二行 8 格，放大 2 倍"""
    S = 2
    pick = (0, 1, 4, 5, 8, 9, 12, 13)
    pick2 = (16, 18, 19, 20, 22, 24, 26, 3)
    blocks = []
    for code in codes:
        gpt = Image.open(GPT_DIR + 'chr_LM-GUEST-%s.png' % code).convert('RGBA')
        blk = Image.new('RGBA', (FW * 8, FH * 3), (0, 0, 0, 0))
        for c, i in enumerate(pick):
            blk.paste(atlas_frame(gpt, i), (c * FW, 0))
            blk.paste(atlas_frame(atlases[code], i), (c * FW, FH))
        for c, i in enumerate(pick2):
            blk.paste(atlas_frame(atlases[code], i), (c * FW, FH * 2))
        blocks.append(blk)
    cols = 2
    rows = (len(blocks) + cols - 1) // cols
    bw, bh = FW * 8 * S, FH * 3 * S
    out = checker_bg(bw * cols + 16, (bh + 16) * rows)
    for k, b in enumerate(blocks):
        bb = b.resize((b.width * S, b.height * S), Image.NEAREST)
        out.paste(bb, ((k % cols) * (bw + 16), (k // cols) * (bh + 16)), bb)
    out.save(path)


def lawn_canvas(people):
    """草坪底图 + 东西（照 room.json 的着地线排前后），人也按着地线排进去。
    people: (图集, 格号, 脚点 x, 脚点 y, 排序线)；排序线 None = 脚点 y"""
    jj = json.load(open(LAWN + 'room.json'))
    can = Image.open(LAWN + 'room.png').convert('RGBA')
    items = []
    for p in jj['props']:
        im = Image.open(LAWN + 'props/' + p['png'].split('/')[-1]).convert('RGBA')
        items.append((p['foot'], 0, im, p['x'], p['y']))
    for (atl, idx, fx, fy, key) in people:
        im = atlas_frame(atl, idx)
        items.append((fy + 0.5 if key is None else key, 1, im, int(fx) - FW // 2, int(fy) - FH + 1))
    items.sort(key=lambda t: (t[0], t[1]))
    for _, _, im, x, y in items:
        can.alpha_composite(im, (x, y))
    return can


# 草坪仪式区的椅子（room.json 里有椅背 back_* 的那几张 = 游戏里有人坐的）：(排, 位) -> (x, y, 着地线)
LAWN_CHAIRS = {(r, s): (x, 459 + 38 * r, 506 + 38 * r)
               for r in range(4) for (s, x) in (('L4', 258), ('L3', 288), ('L2', 318), ('R2', 498), ('R3', 528), ('R4', 558))}


def scene_preview(atlases, path):
    """一比一摆进草坪（build57 的 pixel_art/lawn，只读）：左块仪式区，右块游乐场；底下同样两块放大 2 倍"""
    A = atlases
    people = []
    # 仪式区：朝北坐（背影，格 26/27），坐垫面对齐椅子坐垫（椅子图第 20 行），排在椅子和椅背之间
    seats = [((0, 'L4'), '09'), ((0, 'L3'), '10'), ((0, 'L2'), '06'), ((0, 'R2'), '05'), ((0, 'R3'), '03'), ((0, 'R4'), '08'),
             ((1, 'L4'), '04'), ((1, 'L3'), '02'), ((1, 'L2'), '11'), ((1, 'R2'), '01'), ((1, 'R3'), '12')]
    for k, ((r, sl), code) in enumerate(seats):
        x, y, foot = LAWN_CHAIRS[(r, sl)]
        seat = geom(CHARS[code])['seat']
        people.append((A[code], 26 + (k % 2), x + 12, y + 20 - seat + 83, foot + 2))
    # 过道上往台子走的、底下站着说话的
    people += [
        (A['02'], 1, 423, 690, None),       # 红裙 朝下走
        (A['01'], 13, 418, 610, None),      # 青年 朝上走（背影）
        (A['04'], 18, 300, 712, None),      # 白衬衫 朝下说话
        (A['03'], 4, 334, 712, None),       # 针织 朝左站（跟白衬衫面对面）
        (A['08'], 9, 520, 706, None),       # 背带裤 朝右走
    ]
    # 游乐场
    people += [
        (A['11'], 9, 1290, 470, None),      # 女孩 朝右跑
        (A['12'], 5, 1336, 478, None),      # 男孩 朝左跑
        (A['08'], 16, 1196, 452, None),     # 背带裤 站着（两手交握）
        (A['01'], 8, 1240, 540, None),      # 青年 朝右站
        (A['02'], 19, 1392, 578, None),     # 红裙 说话
        (A['03'], 0, 1150, 560, None),      # 针织 朝下站
    ]
    can = lawn_canvas(people)
    boxes = [(232, 376, 612, 728), (1104, 286, 1484, 638)]
    crops = [can.crop(b) for b in boxes]
    gap = 12
    W = sum(c.width for c in crops) + gap
    H1 = max(c.height for c in crops)
    out = Image.new('RGBA', (W * 2 + gap, H1 + gap + H1 * 2), (43, 32, 30, 255))
    x = (W * 2 + gap - W) // 2                # 上排一比一，居中
    for c in crops:
        out.paste(c, (x, 0))
        x += c.width + gap
    x = 0
    for c in crops:
        big = c.resize((c.width * 2, c.height * 2), Image.NEAREST)
        out.paste(big, (x, H1 + gap))
        x += big.width + gap
    out.save(path)


def main():
    rnd_name = sys.argv[1] if len(sys.argv) > 1 else None
    atlases = {}
    os.makedirs(os.path.join(HERE, 'check4'), exist_ok=True)
    for code in ALL11:
        im, j = build_atlas(code)
        atlases[code] = im
        out = HERE if code in NEW7 else os.path.join(HERE, 'check4')
        im.save(os.path.join(out, 'chr_CODE-GUEST-%s.png' % code))
        with open(os.path.join(out, 'chr_CODE-GUEST-%s.json' % code), 'w', encoding='utf-8') as fp:
            json.dump(j, fp, ensure_ascii=False, indent=1)
    verify_old4()
    lineup_all(atlases, os.path.join(HERE, 'lineup_all.png'))
    walk_gif_all(atlases, os.path.join(HERE, 'walk_preview_all.gif'))
    try:
        scene_preview(atlases, os.path.join(HERE, 'scene_preview.png'))
    except NameError:
        pass
    if rnd_name:
        compare_sheet2(atlases, os.path.join(HERE, rnd_name + '.png'))
    check(atlases)


if __name__ == '__main__':
    main()
