#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
draw_chars.py —— 纯代码（Pillow）画罗曼山庄休息间四位宾客的像素小人。

  python3 draw_chars.py            出四份图集 + json + lineup / walk_strip / lounge_preview
  python3 draw_chars.py round3     另外再存一张 round3.png（并排对照 GPT 原图）

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
GPT_DIR = REPO + '/godot/assets/characters/lm/'
LOUNGE = os.path.join(HERE, 'lounge57')       # git show build57:godot/assets/pixel_art/backhall_lounge/ 拷出来的
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
}
RAMPS = {k: [hx(c) for c in v] for k, v in RAMPS_HEX.items()}

C = {   # 直接上色的小件（五官等）
    'eye': hx('2b1a14'), 'iris': hx('6a3d26'), 'iris2': hx('8a5232'), 'eye_hl': hx('ffffff'),
    'brow_dark': hx('3a2620'), 'blush': hx('f3a08a'), 'blush2': hx('ec8c76'),
    'mouth': hx('a9483f'), 'mouth_dk': hx('5e1d1a'), 'tongue': hx('e2796a'), 'teeth': hx('fff4ea'),
    'glass': hx('3a2420'), 'lens_hl': hx('fff8f0'),
    'wrinkle': hx('d98a62'),
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
}


def geom(P):
    H, extra = P['H'], P['extra']
    Hb = H - extra
    g = {}
    g['top'] = FH - Hb                       # 头发顶（不算发髻、爆炸头多出来那截）
    g['head_h'] = int(0.38 * Hb + 0.5)       # 头身比四位统一
    g['chin'] = g['top'] + g['head_h'] - 1
    g['sh'] = g['chin'] + 1                  # 肩线
    g['leg'] = int(0.27 * Hb + 0.5)          # 腿连鞋
    g['crotch'] = FH - g['leg']
    g['hip'] = g['crotch'] - 3               # 胯关节
    g['shoe_h'] = 4
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
    return crotch - 1


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
        F.rows(crotch - 7, crotch + 1.5, lambda y: P['hipw'] / 2 - 0.3, 'hips', 'leg', bot,
               ('vcyl', CX, P['hipw'] / 2 + 1.5, -0.1))
        for y in range(int(crotch) + 0, int(crotch) + 2):
            F.recolor(CX - 0.5, y, dl=-2)
    else:
        draw_skirt_front(F, P, g, sh, crotch, bob, pose)
    draw_torso_front(F, P, g, sh, torso_hem(P, g, sh, crotch), back)
    draw_front_arms(F, P, pose, g, sh, back)
    draw_head_front(F, P, g, bob + pose.get('head_dy', 0), back, pose)


def draw_skirt_front(F, P, g, sh, crotch, bob, pose, hem=None):
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
        hx_ = sx + side * (1.3 - 2.6 * fwd + 1.0 * bk)
        hy_ = sy + L + 1.6 * fwd - 3.6 * bk
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
        F.capsule(CX, chin - 4, CX, chin + 1, 3.8, 3.8, 'neck', 'neck', skin, ('flat', -1))
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
            hx_ = sx(s * reach)
            hy_ = shy + L - abs(s) * 2.2
            ex = sx(s * 2.8 + (1.6 if s > 0 else 0.3))
            ey = shy + L * 0.5
        draw_arm(F, P, which, grp, shx, shy, ex, ey, hx_, hy_)

    if not sit:
        arm('b', pose['fa'], 'armb')
        leg('b', *pose['fl'])
        leg('f', *pose['nl'])
        if not P['skirt']:
            F.capsule(sx(-0.8), crotch - 7, sx(-0.8), crotch - 3, depth / 2 - 0.5, depth / 2 - 0.5, 'hips', 'legf', P['bottom'],
                      ('vcyl', CX - f * 1.0, depth / 2 + 2, -0.1))
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
    if P['hair_style'] in ('swept', 'afro'):
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


def lobed(cx, cy, rx, ry, k, amp, phase=0.0, base=0.93):
    """一团带圆鼓包的轮廓（卷发外沿）"""
    def t(px, py):
        dx, dyv = (px - cx) / rx, (py - cy) / ry
        r = math.hypot(dx, dyv)
        th = math.atan2(dyv, dx)
        lobe = abs(math.sin(th * k / 2 + phase)) ** 0.7
        return r <= base + amp * lobe
    return t


# ---------------------------------------------------------------- 动作表
def walk_poses(d):
    """每个朝向 4 格。0 站定（全高，游戏量身高用它）、1 迈一只脚、2 过渡、3 迈另一只脚"""
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
    return F.render()


def all_frames(P):
    frames = []
    for d in ('down', 'left', 'right', 'up'):
        for pose in walk_poses(d):
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
    """硬规矩自查：透明度只有 0/255；站着第 0 格的高；坐着的高；色数"""
    for code, im in atlases.items():
        hist = im.split()[3].histogram()
        bad = sum(hist[1:255])
        bb = im.crop((0, 0, FW, FH)).getbbox()
        sb = atlas_frame(im, 20).getbbox()
        sl = atlas_frame(im, 22).getbbox()
        cols = len(set(p for p in im.getdata() if p[3] == 255))
        print('%s %s 半透明 %d | 站着 %d 高 宽 %d | 朝下坐 %d 高 | 侧坐 %d 高 | 色数 %d' % (
            code, CHARS[code]['name'], bad, bb[3] - bb[1], bb[2] - bb[0], sb[3] - sb[1], sl[3] - sl[1], cols))


def main():
    rnd_name = sys.argv[1] if len(sys.argv) > 1 else None
    atlases = {}
    for code in ('09', '10', '05', '06'):
        im, j = build_atlas(code)
        atlases[code] = im
        im.save(os.path.join(HERE, 'chr_CODE-GUEST-%s.png' % code))
        with open(os.path.join(HERE, 'chr_CODE-GUEST-%s.json' % code), 'w', encoding='utf-8') as fp:
            json.dump(j, fp, ensure_ascii=False, indent=1)
    lineup(atlases, os.path.join(HERE, 'lineup.png'))
    walk_strip(atlases, os.path.join(HERE, 'walk_strip.png'))
    lounge_preview(atlases, os.path.join(HERE, 'lounge_preview.png'))
    walk_gif(atlases, os.path.join(HERE, 'walk_preview.gif'))
    if rnd_name:
        compare_sheet(atlases, os.path.join(HERE, rnd_name + '.png'))
    check(atlases)


if __name__ == '__main__':
    main()
