#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
draw_cute.py —— 可爱化样张（cute01）：9 号奶奶、2 号红裙、11 号女孩三位。

  python3 draw_cute.py           出 3 位可爱化图集 + compare.png / scene_cute.png / blink.gif / sheet_cute.png
  python3 draw_cute.py round2    另外存一张 work/round2.png（3 位全部 32 格 + 定调图的脸，看图用）

做法：把上一级的 draw_chars2.py 当库读进来（不改它、不改它出的图），在这个进程里换掉几样：
  - 脸：大眼睛（4×5，深棕虹膜、白高光、粗上眼线）、往下放、两颊腮红、小笑嘴；眨眼一格
  - 皮肤：暖亮色带，脸只用中档（亮），下巴底下压一行影；描边全部换成深暖褐（不用接近黑的）
  - 比例：头 0.44（小孩 0.50）、腿短、胳膊短、手圆
  - 背影：后脑勺加亮、露耳朵；新加「背对坐着、转头跟旁边人说话」朝左、朝右各 2 格
图集还是 1024×168：第二行用满 16 格（16 待机 / 17 眨眼 / 18-19 说话 / 20-27 坐 / 28-29 背坐转头朝左说话 / 30-31 背坐转头朝右说话）。
"""
import importlib.util
import json
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PARENT = os.path.dirname(HERE)
_spec = importlib.util.spec_from_file_location('dc', os.path.join(PARENT, 'draw_chars2.py'))
dc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dc)

FW, FH, CX, FOOT = dc.FW, dc.FH, dc.CX, dc.FOOT
TONE = '/Users/kayra_ayu/Desktop/苏七镇奇缘/阿鱼夫妇（人物定调）.png'   # 只看画风
LOUNGE = dc.B57 + 'pixel_art/backhall_lounge/'
CODES = ('09', '02', '11')


def hx(s):
    return dc.hx(s)


# ---------------------------------------------------------------- 色带：暖亮皮肤、亮一点的深发、暖褐描边
dc.RAMPS_HEX.update({
    'skin_cute':     ['6a3a28', 'd4825c', 'efa478', 'ffc89b', 'ffe2c2'],
    'skin_cute_old': ['6a3a28', 'cd7d5a', 'eba077', 'fcc49a', 'ffdfbf'],
    'hair_cute_dk':  ['2a1511', '2c1914', '3d241b', '553424', '7a4d36'],   # 02 的深色卷发：深，但亮档暖一点，背影不再一团黑
    'hair_cute_br':  ['2a1511', '33201a', '4a2e20', '664129', '8c5d3a'],   # 11 的深棕发
})
for k, v in dc.RAMPS_HEX.items():
    dc.RAMPS[k] = [hx(c) for c in v]


def warm_outline(ramp):
    """描边：取色带最暗那档跟深暖褐 3a1d14 掺一半，再压暗一点；不会比原来更黑，只是偏暖偏褐"""
    r1, g1, b1 = ramp[1]
    w = (0x3a, 0x1d, 0x14)
    o = tuple(int((a * 0.45 + b * 0.55) * 0.88) for a, b in zip((r1, g1, b1), w))
    return o


# 近黑的衣服提亮一档（裙子、鞋）：衣服太黑，整个人下半截发沉、显阴
dc.RAMPS_HEX['skirt_grey'] = ['141011', '3a3334', '4a4243', '5d5455', '786e6e']
dc.RAMPS_HEX['shoe_black'] = ['0b0809', '33231f', '45302a', '5a4036', '7a5848']
for k in ('skirt_grey', 'shoe_black'):
    dc.RAMPS[k] = [hx(c) for c in dc.RAMPS_HEX[k]]
for k in list(dc.RAMPS.keys()):
    if k in ('skin_cute', 'skin_cute_old', 'hair_cute_dk', 'hair_cute_br'):
        continue
    dc.RAMPS[k] = [warm_outline(dc.RAMPS[k])] + dc.RAMPS[k][1:]

SHINE_HAIRS = ('hair_cute_dk', 'hair_cute_br', 'hair_silver')
_SH = {}
for k in SHINE_HAIRS:
    r, g_, b = dc.RAMPS[k][4]
    _SH[k] = (int(r + (255 - r) * 0.35), int(g_ + (236 - g_) * 0.35), int(b + (214 - b) * 0.35))

dc.C.update({
    'eye': hx('2a1610'),          # 上眼线：深暖褐
    'iris_c': hx('4a2216'),       # 虹膜深处
    'iris_c2': hx('8a3f26'),      # 虹膜下半（红棕，定调图那种）
    'iris_c3': hx('c0683a'),      # 虹膜最底一点反光
    'eye_w': hx('ffffff'),
    'blush_c': hx('f7987f'),
    'blush_c2': hx('fbb39b'),
    'mouth_c': hx('9a3a2e'),
    'mouth_in': hx('6e2420'),
    'tongue_c': hx('ee7f6f'),
    'brow_old': hx('a59ba7'),
})

# ---------------------------------------------------------------- 三位的参数（在原来的基础上改）
CUTE = {}
P = dict(dc.CHARS['09'])
P.update(head_frac=0.44, leg_frac=0.24, arm_frac=0.72, face_rx=13.0, skin='skin_cute_old',
         sw=22, hipw=22, arm_r=3.4, leg_r=3.3, hand_k=0.7,
         cute=dict(eye_frac=0.40, gap=4, lash=False, mouth='smile', old=True, ears_back=True, side_hairline=-7))
CUTE['09'] = P
P = dict(dc.CHARS['02'])
P.update(H=79, head_frac=0.45, leg_frac=0.24, arm_frac=0.72, face_rx=13.2, skin='skin_cute', hair='hair_cute_dk',
         sw=21, hipw=19, arm_r=3.0, leg_r=2.9, hand_k=0.6, hairline_dy=3,
         cute=dict(eye_frac=0.40, gap=4, lash=False, mouth='smile', ears_back=True, side_hairline=-5))
CUTE['02'] = P
P = dict(dc.CHARS['11'])
P.update(head_frac=0.50, leg_frac=0.22, arm_frac=0.72, face_rx=10.8, skin='skin_cute', hair='hair_cute_br',
         sw=15, hipw=14, arm_r=2.5, leg_r=2.4, hand_k=0.5, hem_drop=9, idle_arms='wave',
         cute=dict(eye_frac=0.42, gap=3, lash=False, mouth='grin', kid=True, side_hairline=-3))
CUTE['11'] = P
for code, P in CUTE.items():
    P['face2'] = P.get('face2', dict(eye='f', iris=('iris_dk', 'iris'), brow=None))   # 让 7 位那套细节函数照常认得
    dc.CHARS['C' + code] = P


# ---------------------------------------------------------------- 换掉的几样
_geom0 = dc.geom


def geom_cute(P):
    g = _geom0(P)
    if P.get('arm_frac'):
        g['arm_len'] = round((g['crotch'] - g['sh']) * P['arm_frac'])
    if P.get('cute'):
        g['eye'] = g['chin'] - round(g['head_h'] * P['cute']['eye_frac'])   # 5 格高的大眼睛，眼睛底在脸的 7 成处
    return g


dc.geom = geom_cute

_draw_arm0 = dc.draw_arm


def draw_arm_cute(F, P, which, grp, sx, sy, ex, ey, hx_, hy_, hand_shift=(0, 0)):
    _draw_arm0(F, P, which, grp, sx, sy, ex, ey, hx_, hy_, hand_shift)
    k = P.get('hand_k')
    if k:                       # 手画圆一点、大一点
        ar = P['arm_r']
        hx2, hy2 = hx_ + hand_shift[0], hy_ + hand_shift[1] + 0.6
        F.ellipse(hx2, hy2, ar - 0.2 + k, ar + 0.1 + k * 0.8, 'hand' + which, 'hand' + which, P['skin'],
                  shd=('sph', hx2 - 0.8, hy2 - 1.0, ar + 0.8 + k, ar + 1.0 + k))


dc.draw_arm = draw_arm_cute

_fat0 = dc.front_arm_targets


def front_arm_targets_cute(P, pose, g, sh, side, back):
    sx, sy, ex, ey, hx_, hy_ = _fat0(P, pose, g, sh, side, back)
    if pose.get('arms') == 'wave' and side == pose.get('wave_side', 1) and not back:   # 举手打招呼
        L = g['arm_len']
        return sx, sy, sx + side * 3.4, sy + L * 0.28, sx + side * 4.4, sy - L * 0.22
    if P.get('cute') and pose.get('arms', 'free') in ('free', 'wave') and pose.get('kind') != 'sit':
        hx_ += side * 1.0           # 手离开身子一点，不再贴着裤缝站
        ex += side * 0.5
    return sx, sy, ex, ey, hx_, hy_


dc.front_arm_targets = front_arm_targets_cute


def face_shadow_cute(F, y0, y1):
    """皮肤以亮为主：脸不再压右边两列暗，只在下巴底下（脖子 / 领口那一行）压一行影"""
    chin_row = {}
    for y in range(FH):
        for x in range(FW):
            if F.part[y][x] == 'face':
                chin_row[x] = y
    for x, y in chin_row.items():
        if y + 1 < FH and F.part[y + 1][x] in ('torso', 'neck', 'collar'):
            F.recolor(x, y + 1, dl=-1)


dc.face_crescent = face_shadow_cute


def put_face(F, x, y, col):
    x, y = int(math.floor(x)), int(math.floor(y))
    if 0 <= x < FW and 0 <= y < FH and F.part[y][x] == 'face':
        F.ov[(x, y)] = col


def cute_face_front(F, P, g, dy, pose):
    cu = P['cute']
    e = g['eye'] + dy
    c = int(CX)
    gap = cu['gap']
    lx = c - gap // 2 - 4            # 左眼 4 宽
    rx = c + (gap - gap // 2)        # 右眼
    blink = pose.get('blink', False)
    mouth = pose.get('mouth', cu.get('mouth', 'smile'))
    if cu.get('kid') and mouth == 'smile' and 'mouth' not in pose:
        mouth = 'grin'
    D, W, I, J, K = dc.C['eye'], dc.C['eye_w'], dc.C['iris_c'], dc.C['iris_c2'], dc.C['iris_c3']
    if not blink:
        # 4×5 的大眼睛：粗上眼线、左上白高光、虹膜上深下红棕、右下一点小反光
        # 圆圆的纽扣眼：上沿圆、左上白高光、下半红棕；左右眼外形镜像，高光都在左上（光从左上来）
        left = ['.DD.',
                'DWWI',
                'DWII',
                'DIJJ',
                '.JJ.']
        cmap = {'D': D, 'W': W, 'I': I, 'J': J, 'K': K}
        for x0, mirror in ((lx, False), (rx, True)):
            for j, row in enumerate(left):
                rr = row if not mirror else row[::-1]
                for i, ch in enumerate(rr):
                    if ch in cmap:
                        col = cmap[ch]
                        if mirror and ch == 'W':
                            col = I
                        put_face(F, x0 + i, e + j, col)
            if mirror:
                for j, row in enumerate(left):
                    for i, ch in enumerate(row):
                        if ch == 'W':
                            put_face(F, x0 + i, e + j, W)
            if cu.get('lash'):       # 姑娘：外眼角一根睫毛（平着往外，不往上翘，往上翘像吊梢眉）
                put_face(F, (x0 - 1) if not mirror else (x0 + 4), e + 1, D)
    else:
        for x0 in (lx, rx):          # 眨眼：弯弯的一道
            put_face(F, x0, e + 2, D)
            put_face(F, x0 + 1, e + 3, D)
            put_face(F, x0 + 2, e + 3, D)
            put_face(F, x0 + 3, e + 2, D)
    if cu.get('old'):                # 奶奶：淡淡的银眉毛
        for x0 in (lx, rx):
            for d in range(4):
                put_face(F, x0 + d, e - 2, dc.C['brow_old'])
    # 腮红：眼睛外下方，各一小块
    for x0 in (lx - 2, rx + 3):
        for d in range(3):
            put_face(F, x0 + d, e + 6, dc.C['blush_c'])
        put_face(F, x0 + 1, e + 5, dc.C['blush_c2'])
    my = e + 8 if not cu.get('kid') else e + 7
    if mouth in ('open', 'grin'):
        for d in (-2, -1, 0, 1):
            put_face(F, c + d, my, dc.C['mouth_in'])
        put_face(F, c - 1, my + 1, dc.C['tongue_c'])
        put_face(F, c, my + 1, dc.C['tongue_c'])
        put_face(F, c - 2, my - 1, dc.C['mouth_c']) if mouth == 'grin' else None
        put_face(F, c + 1, my - 1, dc.C['mouth_c']) if mouth == 'grin' else None
    else:                            # 小笑嘴：两边往上翘
        put_face(F, c - 2, my - 1, dc.C['mouth_c'])
        put_face(F, c - 1, my, dc.C['mouth_c'])
        put_face(F, c, my, dc.C['mouth_c'])
        put_face(F, c + 1, my - 1, dc.C['mouth_c'])
    if cu.get('old'):                # 奶奶：眼角两道细纹（淡）
        put_face(F, lx - 1, e + 2, dc.RAMPS[P['skin']][2])
        put_face(F, rx + 4, e + 2, dc.RAMPS[P['skin']][2])


def cute_face_side(F, P, g, dy, sx, f, hc, hr, pose):
    cu = P['cute']
    e = g['eye'] + dy
    fu = hc + hr
    eu = fu - (7.4 if not cu.get('kid') else 5.8)
    blink = pose.get('blink', False)
    mouth = pose.get('mouth', cu.get('mouth', 'smile'))
    if cu.get('kid') and mouth == 'smile' and 'mouth' not in pose:
        mouth = 'grin'
    D, W, I, J, K = dc.C['eye'], dc.C['eye_w'], dc.C['iris_c'], dc.C['iris_c2'], dc.C['iris_c3']
    if not blink:
        # 侧脸也是圆纽扣眼（3×5）：后面那列深色、上沿圆；高光在画面左上
        rows = [['.', 'D', 'D'], ['D', 'I', 'I'], ['D', 'I', 'I'], ['D', 'I', 'J'], ['D', 'J', 'J'], ['.', 'J', '.']]
        cmap = {'D': D, 'I': I, 'J': J}
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in cmap:
                    put_face(F, sx(eu + i), e + j, cmap[ch])
        xs = sorted([int(math.floor(sx(eu + i))) for i in range(3)])
        hx0 = xs[1] if f > 0 else xs[0]         # 画面左上那格（朝右：中间列；朝左：最前那列）
        put_face(F, hx0, e + 1, W)
        put_face(F, hx0, e + 2, W)
        if cu.get('lash'):
            put_face(F, sx(eu - 1), e, D)
            put_face(F, sx(eu - 1), e - 1, D)
    else:
        put_face(F, sx(eu), e + 2, D)
        put_face(F, sx(eu + 1), e + 3, D)
        put_face(F, sx(eu + 2), e + 2, D)
    if cu.get('old'):
        for d in (0, 1, 2):
            put_face(F, sx(eu + d), e - 2, dc.C['brow_old'])
    for (du, dyy, col) in ((-1, 6, 'blush_c'), (-2, 6, 'blush_c'), (-3, 6, 'blush_c'), (-2, 5, 'blush_c2'), (-1, 7, 'blush_c2')):
        put_face(F, sx(eu + du), e + dyy, dc.C[col])
    my = e + 8 if not cu.get('kid') else e + 7
    mu = fu - 1.6
    if mouth in ('open', 'grin'):
        put_face(F, sx(mu), my, dc.C['mouth_in'])
        put_face(F, sx(mu - 1), my, dc.C['mouth_in'])
        put_face(F, sx(mu), my + 1, dc.C['tongue_c'])
    else:
        put_face(F, sx(mu), my, dc.C['mouth_c'])
        put_face(F, sx(mu - 1), my - 1, dc.C['mouth_c'])


_hs0 = dc.hair_side


def hair_side_cute(F, P, g, dy, sx, f, hc, hr):
    """侧脸：头发和脸的分界改成一条弧线（额头发际线 → 绕到耳朵后面 → 下巴），不再竖直一刀；
    露耳朵、脸颊圆一点；鬓边小卷在脸上的那截擦掉"""
    _hs0(F, P, g, dy, sx, f, hc, hr)
    if not P.get('cute'):
        return
    cu = P['cute']
    e = g['eye'] + dy
    top = g['top'] + dy
    chin = g['chin'] + dy
    fcy = g['fcy'] + dy
    x0 = sx(0)
    def U(px):                         # 绝对 u（跟 sx 反过来）
        return (px - x0) * f
    hl = e + cu.get('side_hairline', -4)
    uc, rw, yc = hc + hr * 0.25, hr * 0.80, e + 3
    rh = max(chin + 1 - yc, yc - hl) + 0.5
    def win(px, py):
        if py <= hl or py > chin + 0.5:
            return False
        k = 1 - ((py - yc) / rh) ** 2
        return k > 0 and U(px) > uc - rw * math.sqrt(k)
    def head(px, py):                  # 圆一点的侧脸（下巴前面那块比原来鼓）
        u = U(px) - hc
        if py < fcy:
            dyv = (fcy - py) / (fcy - top + 0.5)
            return (abs(u) / hr) ** 2.3 + dyv ** 2.3 <= 1
        dyv = (py - fcy) / (chin + 1 - fcy)
        if u > 0:
            return (u / (hr - 0.3)) ** 2.0 + dyv ** 2.6 <= 1
        return (abs(u) / hr) ** 2.2 + dyv ** 3.0 <= 1
    for y in range(max(0, int(top) - 2), min(FH, int(chin) + 2)):
        for x in range(FW):
            px, py = x + 0.5, y + 0.5
            if F.part[y][x] in ('hair', 'wisp') and win(px, py) and head(px, py):
                F.part[y][x] = None
            if F.part[y][x] is None and head(px, py) and (win(px, py) or py > fcy):
                F.part[y][x] = 'face'
                F.grp[y][x] = 'face'
                F.mat[y][x] = P['skin']
                F.shd[y][x] = ('flat', 0)
                F.z[y][x] = 1
    # 鼻子那一点：跟脸连不上就去掉（不再飘在脸外）
    for y in range(int(e) + 2, int(e) + 6):
        for x in range(FW):
            if F.part[y][x] == 'face' and not any(F.part[y][x + d] == 'face' for d in (-1, 1) if 0 <= x + d < FW):
                F.part[y][x] = None
    # 小鼻子：脸前沿在眼睛下面鼓出一格（连着脸，不飘）
    ny = int(e) + (5 if not cu.get('kid') else 4)
    xf = [x for x in range(FW) if F.part[ny][x] == 'face']
    if xf:
        xn = (max(xf) + 1) if f > 0 else (min(xf) - 1)
        if 0 <= xn < FW and F.part[ny][xn] is None:
            F.part[ny][xn] = 'face'; F.grp[ny][xn] = 'face'; F.mat[ny][xn] = P['skin']
            F.shd[ny][xn] = ('flat', 0); F.z[ny][xn] = 1
    # 耳朵：露在脸和后脑勺头发中间
    uc_e = hc - (2.8 if not cu.get('kid') else 2.1)
    rx, ry = (1.6, 2.3) if not cu.get('kid') else (1.3, 1.9)
    cx_, cy_ = sx(uc_e), e + 2.5
    if win(cx_, cy_):
        F.ellipse(cx_, cy_, rx, ry, 'ear', 'ear', P['skin'], shd=('flat', 0))
        for y in range(int(cy_ - ry) - 1, int(cy_ + ry) + 2):
            for x in range(int(cx_ - rx) - 1, int(cx_ + rx) + 2):
                if F.has(x, y, ('ear',)) and ((x + 0.5 - cx_) * f > 0.2 or
                                              any(F.has(x + a, y + b, ('hair',)) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))):
                    F.noline.add((x, y))
        F.put(sx(uc_e + 0.2), cy_ - 0.5, dc.RAMPS[P['skin']][2])
        F.put(sx(uc_e + 0.2), cy_ + 0.5, dc.RAMPS[P['skin']][2])
    hair_ring(F, P, g, dy, sx(hc - 1.0), f)


dc.hair_side = hair_side_cute

_ff0 = dc.face_features_front
_fs0 = dc.face_features_side


def face_front_hook(F, P, g, dy, pose):
    if P.get('cute'):
        return cute_face_front(F, P, g, dy, pose)
    return _ff0(F, P, g, dy, pose)


def face_side_hook(F, P, g, dy, sx, f, hc, hr, pose):
    if P.get('cute'):
        return cute_face_side(F, P, g, dy, sx, f, hc, hr, pose)
    return _fs0(F, P, g, dy, sx, f, hc, hr, pose)


dc.face_features_front = face_front_hook
dc.face_features_side = face_side_hook

_dhf0 = dc.draw_head_front


def draw_head_front_cute(F, P, g, dy, back, pose):
    if pose.get('turn'):
        # 背对着坐、头转过去跟旁边人说话：身子是背影，头画侧面（朝说话那边挪 1 像素）
        f = -1 if pose['turn'] == 'left' else 1
        shift = f * 1.0
        def sx(u, f=f):
            return CX + f * u + shift
        return dc.draw_head_side(F, P, g, dy, sx, f, pose)
    _dhf0(F, P, g, dy, back, pose)
    if P.get('cute') and back:
        back_head_extras(F, P, g, dy)
    if P.get('cute') and not back:
        hair_ring(F, P, g, dy, CX)


dc.draw_head_front = draw_head_front_cute


SHINE = _SH


def hair_ring(F, P, g, dy, cx, f=0):
    """头发的光泽圈：头顶偏左一道弧形亮条（定调图那种亮亮的头发）；银发本来就亮，只压一道暗衬托"""
    top = g['top'] + dy
    frx = P['face_rx']
    rcx, rcy = cx - 1.5 - f * 1.5, top + 11.5
    rx, ry = frx + 1.2, 8.5
    old = P['cute'].get('old')
    for y in range(max(0, int(top)), int(top) + 10):
        for x in range(FW):
            if F.part[y][x] not in ('hair', 'bun'):
                continue
            d = math.hypot((x + 0.5 - rcx) / rx, (y + 0.5 - rcy) / ry)
            if old or x + 0.5 > rcx + frx * 0.5:
                continue
            if 0.95 <= d <= 1.07:
                F.mat[y][x] = P['hair']
                F.shd[y][x] = ('flat', 1)
                F.dl.pop((x, y), None)
                if x + 0.5 < rcx - frx * 0.1 and (x + y) % 2 == 0:
                    F.put(x, y, SHINE[P['hair']])        # 最亮那段点几颗更亮的
            elif 1.07 < d <= 1.17:
                F.shd[y][x] = ('flat', -1)
                F.dl.pop((x, y), None)


def back_head_extras(F, P, g, dy):
    """背影：两边露一点耳朵；后脑勺左上压一道亮（光从左上），别是一团黑"""
    cu = P['cute']
    frx = P['face_rx']
    e = g['eye'] + dy
    top = g['top'] + dy
    if cu.get('ears_back'):
        for side in (-1, 1):
            cx_, cy_ = CX + side * (frx + 0.6), e + 3.0
            F.ellipse(cx_, cy_, 1.5, 2.2, 'earb%d' % side, 'ear', P['skin'], shd=('flat', 0 if side < 0 else -1))
    for y in range(int(top), int(top) + 9):
        xs = [x for x in range(FW) if F.part[y][x] in ('hair', 'bun')]
        if not xs:
            continue
        x0 = min(xs)
        for x in (x0 + 2, x0 + 3, x0 + 4):
            if (x, y) in [(xx, y) for xx in xs] and (y - top) > 1:
                F.recolor(x + (y - top) // 3, y, dl=1, only=('hair', 'bun'))


# ---------------------------------------------------------------- 动作表（第二行 16 格用满）
def all_frames_cute(P):
    frames = []
    for d in ('down', 'left', 'right', 'up'):
        for k, pose in enumerate(dc.walk_poses(d, P.get('ks', 1.0))):
            pose = dict(pose, kind='walk', arms='free')
            if k == 0:                 # 站定那格：两手一前一后，不再左右对称、贴着裤缝
                pose.update(la=0.35, ra=-0.2) if d in ('down', 'up') else pose.update(na=0.3, fa=-0.25)
            frames.append(dc.make_frame(P, d, pose))
    extra = []
    ia = P['idle_arms']
    base = dict(lf=(0, 0), rf=(0, 0), la=0, ra=0, arms=ia)
    extra.append(dc.make_frame(P, 'down', dict(base, kind='idle', bob=0)))                       # 16 待机
    extra.append(dc.make_frame(P, 'down', dict(base, kind='idle', bob=0, blink=True)))           # 17 眨眼
    extra.append(dc.make_frame(P, 'down', dict(base, kind='talk', bob=0, arms='talk', talk_side=-1, talk_h=0.22, mouth='open')))
    extra.append(dc.make_frame(P, 'down', dict(base, kind='talk', bob=0, head_dy=1, arms='talk', talk_side=-1, talk_h=0.36, mouth='smile')))
    for d in ('down', 'left', 'right', 'up'):
        for k in range(2):
            extra.append(dc.make_frame(P, d, dict(kind='sit', bob=k, la=0, ra=0, fa=0, na=0)))
    for turn in ('left', 'right'):                                                                # 28-31 背坐转头说话
        extra.append(dc.make_frame(P, 'up', dict(kind='sit', bob=0, la=0, ra=0, turn=turn, mouth='open')))
        extra.append(dc.make_frame(P, 'up', dict(kind='sit', bob=1, la=0, ra=0, turn=turn, mouth='smile')))
    return frames, extra


def build_atlas_cute(code):
    P = CUTE[code]
    walk, extra = all_frames_cute(P)
    im = Image.new('RGBA', (FW * 16, FH * 2), (0, 0, 0, 0))
    for i, fr in enumerate(walk):
        im.paste(fr, (i * FW, 0))
    for i, fr in enumerate(extra):
        im.paste(fr, (i * FW, FH))
    g = dc.geom(P)
    bb = im.crop((0, 0, FW, FH)).getbbox()
    drawn_h = bb[3] - bb[1]
    j = {
        'frame': [FW, FH],
        'frames': {'down': [0, 1, 2, 3], 'left': [4, 5, 6, 7], 'right': [8, 9, 10, 11], 'up': [12, 13, 14, 15],
                   'idle': [16] * 11 + [17], 'talk': [18, 19],
                   'sit_down': [20, 21], 'sit_left': [22, 23], 'sit_right': [24, 25], 'sit_up': [26, 27],
                   'sit_up_talk_left': [28, 29], 'sit_up_talk_right': [30, 31]},
        'fps': 8,
        'height_m': round(1.75 * drawn_h / 84, 4),
        'idle_fps': 6, 'talk_fps': 3, 'sit_fps': 1,
        'sit_seat': {'down': g['knee_sit'] + int(P['leg_r'] + 0.5), 'left': g['seat'], 'right': g['seat'], 'up': g['seat']},
        'note': ('可爱化样张（cute01/draw_cute.py 生成），还没进游戏。第二行 16 格用满：16 待机、17 眨眼（idle 序列 11 格睁眼 + 1 格眨眼，'
                 'idle_fps 6 = 每 2 秒眨一下）、18-19 说话、20-27 坐四个朝向、28-29 背对坐转头朝左说话、30-31 背对坐转头朝右说话。'
                 'height_m 照第 0 格画出来的高（%d 像素）算。' % drawn_h),
    }
    return im, j


# ---------------------------------------------------------------- 出图
def af(a, idx):
    return dc.atlas_frame(a, idx)


def current_atlas(code):
    if code in dc.OLD4:
        return Image.open(os.path.join(PARENT, 'check4', 'chr_CODE-GUEST-%s.png' % code)).convert('RGBA')
    return Image.open(os.path.join(PARENT, 'chr_CODE-GUEST-%s.png' % code)).convert('RGBA')


def tone_faces(scale=1):
    im = Image.open(TONE).convert('RGBA').crop((95, 50, 385, 250))
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST) if scale != 1 else im


def compare(cute, path):
    """每位一行：现在的 → 可爱化的（都用待机格 16：站着不动时的样子）→ GPT 原图第 0 格（GPT 第 0 格就是交握站着），
    放大 4 倍；最右边贴定调图的脸（原大）"""
    S = 4
    tf = tone_faces()
    rowh = FH * S
    W = FW * S * 3 + 24 * 3 + tf.width + 12
    out = dc.checker_bg(W, rowh * 3 + 12 * 4)
    for r, code in enumerate(CODES):
        y = 12 + r * (rowh + 12)
        ims = (af(current_atlas(code), 16), af(cute[code], 16), dc.gpt_frame(code, 0))
        for k, im in enumerate(ims):
            big = im.resize((FW * S, FH * S), Image.NEAREST)
            out.paste(big, (12 + k * (FW * S + 24), y), big)
        out.paste(tf, (12 + 3 * (FW * S + 24), y + (rowh - tf.height) // 2))
    out.save(path)


def sheet(cute, path):
    """3 位各两排（32 格），放大 2 倍；右边贴定调图的脸（原大）"""
    S = 2
    tf = tone_faces()
    W = FW * 16 * S + tf.width + 16
    H = FH * 2 * S * 3 + 16 * 2
    out = dc.checker_bg(W, max(H, tf.height))
    for r, code in enumerate(CODES):
        a = cute[code].resize((FW * 16 * S, FH * 2 * S), Image.NEAREST)
        out.paste(a, (0, r * (FH * 2 * S + 16)), a)
    out.paste(tf, (FW * 16 * S + 16, 0))
    out.save(path)


def blink_gif(cute, path):
    """3 位待机眨眼循环，放大 4 倍；三位错开眨"""
    S = 4
    W, H = FW * S * 3, FH * S
    def frame(blinks):
        can = dc.checker_bg(W, H)
        for k, code in enumerate(CODES):
            im = af(cute[code], 17 if code in blinks else 16).resize((FW * S, FH * S), Image.NEAREST)
            can.paste(im, (k * FW * S, 0), im)
        return can.convert('RGB').quantize(colors=255, method=Image.MEDIANCUT, dither=Image.NONE)
    seq = [((), 700), (('09',), 140), ((), 500), (('02',), 140), ((), 450), (('11',), 140), ((), 600), (('09', '02', '11'), 140)]
    frames = [frame(b) for b, _ in seq]
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=[d for _, d in seq], loop=0, disposal=1)


def lounge_canvas(people):
    jj = json.load(open(LOUNGE + 'room.json'))
    bg = jj['background']
    can = Image.new('RGBA', (1100, 900), (43, 32, 30, 255))
    room = Image.open(LOUNGE + 'room.png').convert('RGBA')
    can.alpha_composite(room, (bg['x'], bg['y']))
    items = []
    for p in jj['props']:
        im = Image.open(LOUNGE + 'props/' + p['png'].split('/')[-1]).convert('RGBA')
        items.append((p['foot'], 0, im, p['x'], p['y']))
    for (atl, idx, fx, fy) in people:
        items.append((fy + 0.5, 1, af(atl, idx), fx - FW // 2, fy - FH + 1))
    items.sort(key=lambda t: (t[0], t[1]))
    for _, _, im, x, y in items:
        can.alpha_composite(im, (x, y))
    return can, jj


def scene(cute, path):
    A = cute
    # 休息间：奶奶坐北边沙发（朝下）、红裙坐西边茶座西椅（朝右）、女孩坐东椅（朝左），跟样板摆法一样：脚点放在座位前沿的地上
    lc, jj = lounge_canvas([(A['09'], 20, 560, 270), (A['02'], 24, 404, 418), (A['11'], 22, 462, 418),
                            (A['11'], 1, 600, 520), (A['02'], 16, 470, 600)])
    r = jj['room']
    lounge = lc.crop((r['x0'] - 6, 98, r['x1'] + 6, 700))
    # 草坪仪式区：前两排坐满，混着背影（26/27）和转头说话（28-31：朝左 28/29、朝右 30/31）
    seats = [((0, 'L4'), '09', 26), ((0, 'L3'), '02', 30), ((0, 'L2'), '11', 28),
             ((0, 'R2'), '02', 27), ((0, 'R3'), '09', 31), ((0, 'R4'), '11', 29),
             ((1, 'L4'), '02', 26), ((1, 'L3'), '11', 27), ((1, 'L2'), '09', 26),
             ((1, 'R2'), '11', 30), ((1, 'R3'), '02', 28), ((1, 'R4'), '09', 27)]
    people = []
    for (rs, code, idx) in seats:
        x, y, foot = dc.LAWN_CHAIRS[rs]
        seat = dc.geom(CUTE[code])['seat']
        people.append((A[code], idx, x + 12, y + 20 - seat + 83, foot + 2))
    people += [(A['02'], 1, 423, 650, None), (A['11'], 9, 404, 700, None), (A['09'], 16, 520, 704, None)]
    can = dc.lawn_canvas(people)
    lawn = can.crop((232, 376, 612, 728))
    gap = 12
    top_w = lounge.width + gap + lawn.width
    big_l = lounge.resize((lounge.width * 2, lounge.height * 2), Image.NEAREST)
    big_w = lawn.resize((lawn.width * 2, lawn.height * 2), Image.NEAREST)
    W = max(top_w, big_l.width + gap + big_w.width)
    H = max(lounge.height, lawn.height) + gap + max(big_l.height, big_w.height)
    out = Image.new('RGBA', (W, H), (43, 32, 30, 255))
    out.paste(lounge, (0, 0))
    out.paste(lawn, (lounge.width + gap, 0))
    y2 = max(lounge.height, lawn.height) + gap
    out.paste(big_l, (0, y2))
    out.paste(big_w, (big_l.width + gap, y2))
    out.save(path)


def check(cute):
    for code in CODES:
        im = cute[code]
        hist = im.split()[3].histogram()
        bad = sum(hist[1:255])
        bb = af(im, 0).getbbox()
        cols = len(set(p for p in im.getdata() if p[3] == 255))
        g = dc.geom(CUTE[code])
        Hb = CUTE[code]['H'] - CUTE[code]['extra']
        print('%s %-3s 半透明 %d | 站着 %d 高 | 头 %d（%.2f）| 色数 %d%s' % (
            code, CUTE[code]['name'], bad, bb[3] - bb[1], g['head_h'], g['head_h'] / Hb, cols, '  <-- 超 64 色' if cols > 64 else ''))


def main():
    rnd = sys.argv[1] if len(sys.argv) > 1 else None
    cute = {}
    for code in CODES:
        im, j = build_atlas_cute(code)
        cute[code] = im
        im.save(os.path.join(HERE, 'chr_CUTE-GUEST-%s.png' % code))
        with open(os.path.join(HERE, 'chr_CUTE-GUEST-%s.json' % code), 'w', encoding='utf-8') as fp:
            json.dump(j, fp, ensure_ascii=False, indent=1)
    compare(cute, os.path.join(HERE, 'compare.png'))
    sheet(cute, os.path.join(HERE, 'sheet_cute.png'))
    blink_gif(cute, os.path.join(HERE, 'blink.gif'))
    scene(cute, os.path.join(HERE, 'scene_cute.png'))
    if rnd:
        sheet(cute, os.path.join(HERE, 'work', rnd + '.png'))
    check(cute)


if __name__ == '__main__':
    main()
