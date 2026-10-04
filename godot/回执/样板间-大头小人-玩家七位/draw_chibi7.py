#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
draw_chibi7.py —— 玩家开场能选的 7 个形象，大头小人画法（chibi01）。
  01 青年、02 红裙、03 针织、04 白衬衫、05 花衬衫叔叔、06 眼镜阿姨、08 背带裤（07 GPT 没画、选人里拿掉了）

  python3 draw_chibi7.py             出 7 张图集 + json、lineup.png、scene_chibi.png、walk_chibi.gif
  python3 draw_chibi7.py round2      另存 work/round2.png（7 位全部 28 格 + 参考图，看图用）
  python3 draw_chibi7.py both        第 1 轮用：64、76 两档都出，存 work/two_sizes.png 并排比

阿鱼 10/4：「玩家进入角色选了 A 穿的红色上衣蓝色裤子的，你就让他做游戏内操作移动的是红衣蓝裤的像素人+显著特征就行了」
画法照阿鱼给的参考图（docs/参考图/人物画风参考-阿鱼10-04-大头像素.jpg）：
  约 2 头身（头 0.54）、身子短、手脚小短块；轮廓干净，全身同一个深暖褐描边；脸只有两个小竖条眼睛 + 2 像素小嘴；
  头发一大块有体积；每种颜色 2～3 档明暗、不投影。每位照 GPT 原图配上衣、下装颜色，再加一两样显著特征。
颗粒 1 美术像素 = 1 画布像素；一格 64×84，脚踩最后一行，中线 x=32；光从左上；四个朝向分别画（右不是左翻的）。
图集 1024×168，格子排法跟已交的 chr_CODE-GUEST-xx 一样（02 好接）：
  第一行 0-15 走路（下 左 右 上各 4，第 0 格站定）；第二行 16 待机、17 眨眼、18-19 说话、20-21 朝下坐、22-23 朝左坐、
  24-25 朝右坐、26-27 背坐（第 2 格是呼吸）。
借用上一级 draw_chars2.py 的 Fig（部件图 → 描边 → 上色）和草坪摆椅子的数，不改它、不改它出的图。
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

FW, FH, CX, FOOT = 64, 84, 32.0, 83
REF = dc.REPO + '/docs/参考图/人物画风参考-阿鱼10-04-大头像素.jpg'
LOUNGE = dc.B57 + 'pixel_art/backhall_lounge/'
CODES = ('01', '02', '03', '04', '05', '06', '08')
SIZE = 64          # 第 1 轮两档并排比过，选 64（理由见笔记）


def hx(s):
    return dc.hx(s)


# ---------------------------------------------------------------- 色带 [深, 暗, 中, 亮]；描边全身同一个深暖褐
OUTLINE = '2e1812'
RH = {
    'k_skin':   ['e3936c', 'f2ab80', 'ffd2aa', 'ffe8cc'],
    'k_h01':    ['24160f', '35221a', '4a2f22', '6a4430'],   # 01 深棕乱发
    'k_h02':    ['1f120f', '2e1b15', '42271c', '603a28'],   # 02 深色盘发
    'k_h03':    ['4f2717', '6c3a22', '8a5131', 'ab6e46'],   # 03 栗色卷发
    'k_h04':    ['1e1514', '2c1f1d', '3e2c28', '5a423a'],   # 04 黑短发
    'k_h05':    ['1c1114', '2e1d1e', '452c29', '6b4536'],   # 05 黑卷发
    'k_h06':    ['25191b', '372627', '4e3633', '70504a'],   # 06 深棕波波头
    'k_h08':    ['18161c', '25222a', '35313b', '4e4856'],   # 08 黑发
    'k_teal':   ['17393f', '22525a', '2f6b70', '45898a'],
    'k_cream':  ['b19776', 'd6bf99', 'f2e1bf', 'fff6df'],
    'k_gold':   ['9a6a3e', 'c48e5a', 'e2b27b', 'f7d7a5'],
    'k_pants':  ['1e1819', '2b2324', '3a3031', '4f4344'],
    'k_shoe':   ['4a2410', '693318', '8c4a24', 'b36b3b'],
    'k_shoe_dk': ['24191a', '33262a', '45353a', '5c4a50'],
    'k_wine':   ['47131f', '62202f', '7e2c3c', '9c4152'],
    'k_knit':   ['9f8869', 'bea683', 'd8c29d', 'eedcb8'],
    'k_skirt':  ['1c1416', '271d20', '33282b', '463739'],
    'k_white':  ['a59ba1', 'cfc6c8', 'efe8e6', 'ffffff'],
    'k_grey':   ['25242b', '33323a', '44434c', '5c5b65'],
    'k_mauve':  ['482a33', '5d3942', '74494f', '8f5f64'],
    'k_green':  ['22381b', '2f4c27', '3f6435', '577e46'],
    'k_brass':  ['8a6420', 'b98a2c', 'e0b048', 'fbe08a'],
}
for k, v in RH.items():
    dc.RAMPS[k] = [hx(OUTLINE)] + [hx(c) for c in v]


class _All:
    def __contains__(self, item):
        return True


dc.NOCAST = _All()        # 不投影：参考图就是平涂 + 一两档明暗
EYE = hx('2e1812')
MOUTH = hx('a8483a')
GLASS = hx('3a2420')
FLOWERS = [hx('da4b2c'), hx('ef922f'), hx('f1c94a'), hx('558e3e')]

# ---------------------------------------------------------------- 7 位：颜色照 GPT 原图，显著特征写在 mark 里
CH = {
    '01': dict(name='青年', hair='k_h01', style='messy', top='k_teal', bottom='k_pants', shoe='k_shoe',
               wear='coat', sleeve='k_teal', mark='青绿长外套 + 米色衬里 + 金盘扣，乱发翘毛'),
    '02': dict(name='红裙', hair='k_h02', style='updo', top='k_wine', bottom='k_wine', shoe='k_shoe_dk',
               wear='long_dress', sleeve='k_skin', tw_add=-1, mark='头顶发髻 + 金发箍，酒红长裙 + 金腰带，露胳膊'),
    '03': dict(name='针织', hair='k_h03', style='wavy', top='k_knit', bottom='k_skirt', shoe='k_shoe_dk', leg='k_skin',
               wear='cardigan', sleeve='k_knit', mark='栗色齐肩大波浪 + 金耳环，米色开衫 + 黑打底 + 黑半裙'),
    '04': dict(name='白衬衫', hair='k_h04', style='crew', top='k_white', bottom='k_grey', shoe='k_shoe',
               wear='shirt', sleeve='k_white', rolled=True, brows=True, mark='黑短发 + 浓眉，白衬衫卷袖 + 棕皮带，深灰裤'),
    '05': dict(name='花衬衫', hair='k_h05', style='afro', top='k_cream', bottom='k_pants', shoe='k_shoe',
               wear='floral', sleeve='k_cream', short=True, tw_add=3, happy=True, mark='黑卷发、眯眯笑眼，米底红橙花衬衫，胖一圈'),
    '06': dict(name='眼镜', hair='k_h06', style='bob', top='k_mauve', bottom='k_skirt', shoe='k_shoe_dk', leg='k_skirt',
               wear='sweater', sleeve='k_mauve', glasses=True, mark='深棕波波头 + 圆眼镜，紫灰毛衣 + 黑长裙'),
    '08': dict(name='背带裤', hair='k_h08', style='pigtails', top='k_cream', bottom='k_green', shoe='k_shoe',
               wear='overall', sleeve='k_cream', short=True, tw_add=-1, mark='黑发低双马尾 + 金发绳，米色 T 恤 + 绿背带裤'),
}


def geo(P, H):
    g = {}
    extra = {'updo': round(H * 0.07), 'afro': round(H * 0.04), 'messy': round(H * 0.03)}.get(P['style'], 0)
    Hb = H - extra
    g['H'] = H
    g['top'] = FH - Hb
    g['head_h'] = round(Hb * 0.54)
    g['chin'] = g['top'] + g['head_h'] - 1
    g['hw'] = g['head_h'] * 0.53
    g['frx'] = g['hw'] * 0.74
    g['hcy'] = g['top'] + g['head_h'] * 0.52
    g['hry'] = g['head_h'] * 0.50
    g['leg'] = max(6, round(Hb * 0.17))            # 两截看得见的小短腿
    g['crotch'] = FH - g['leg']
    g['sh'] = g['chin'] - 1
    g['tw'] = round(g['head_h'] * 0.58) + P.get('tw_add', 0)
    g['tl'] = g['crotch'] - g['sh']
    g['ar'] = 1.7 if H < 70 else 2.1
    g['lw'] = max(3, round(g['tw'] * 0.26))
    g['eye_y'] = g['top'] + round(g['head_h'] * 0.60)
    g['eh'] = 3 if g['head_h'] < 38 else 4
    g['ex'] = round(g['frx'] * 0.48)
    g['sd'] = max(2, g['leg'] - 6)
    g['seat'] = g['crotch'] + g['sd'] - 1        # 坐着时屁股底那一行（坐垫面）
    return g


# ---------------------------------------------------------------- 小工具：部件图用 Fig，明暗只有 3 档
def lvl(px, py, cx, cy, rx, ry, hi=0.86, lo=0.28):
    nx, ny = (px - cx) / rx, (py - cy) / ry
    d = nx * nx + ny * ny
    if d > 1:
        s = 1 / math.sqrt(d)
        nx, ny, d = nx * s, ny * s, 1.0
    nz = math.sqrt(max(0.0, 1 - d))
    i = nx * dc.LX + ny * dc.LY + nz * dc.LZ
    return 1 if i >= hi else (0 if i >= lo else -1)


def blob(F, test, bbox, part, grp, mat, shade):
    F.n += 1
    x0, y0, x1, y1 = bbox
    for y in range(max(0, int(y0) - 1), min(FH, int(y1) + 2)):
        for x in range(max(0, int(x0) - 1), min(FW, int(x1) + 2)):
            px, py = x + 0.5, y + 0.5
            if test(px, py):
                F.part[y][x] = part
                F.grp[y][x] = grp
                F.mat[y][x] = mat
                F.shd[y][x] = ('flat', shade(px, py) if callable(shade) else shade)
                F.z[y][x] = F.n


def ell(F, cx, cy, rx, ry, part, grp, mat, shade=None, p=2.0):
    if shade is None:
        shade = lambda px, py: lvl(px, py, cx - rx * 0.25, cy - ry * 0.3, rx * 1.3, ry * 1.3)
    blob(F, lambda px, py: abs((px - cx) / rx) ** p + abs((py - cy) / ry) ** p <= 1,
         (cx - rx, cy - ry, cx + rx, cy + ry), part, grp, mat, shade)


def box(F, x0, y0, x1, y1, part, grp, mat, shade=0, r=1.0):
    def t(px, py):
        if not (x0 <= px <= x1 and y0 <= py <= y1):
            return False
        dx = max(x0 + r - px, 0, px - (x1 - r))
        dy = max(y0 + r - py, 0, py - (y1 - r))
        return dx * dx + dy * dy <= r * r + 0.01
    blob(F, t, (x0, y0, x1, y1), part, grp, mat, shade)


def put(F, x, y, col, parts=None):
    x, y = int(math.floor(x)), int(math.floor(y))
    if 0 <= x < FW and 0 <= y < FH and F.part[y][x] is not None and (parts is None or F.part[y][x] in parts):
        F.ov[(x, y)] = col


def R(m, i):
    return dc.RAMPS[m][i]


def lr_shade(cx, hw):
    def s(px, py):
        t = (px - cx) / max(1.0, hw)
        return 1 if t < -0.62 else (-1 if t > 0.45 else 0)
    return s


def tipwave(x, period, sharp=1.6):
    fr = (x / period) % 1.0
    return (1 - abs(fr * 2 - 1)) ** sharp


# ---------------------------------------------------------------- 头发（正面 / 背面）
def hair_front(F, P, g, dy, back):
    st, hm = P['style'], P['hair']
    top, chin, hh = g['top'] + dy, g['chin'] + dy, g['head_h']
    hcy, hry, hw, frx = g['hcy'] + dy, g['hry'], g['hw'], g['frx']
    eye_y = g['eye_y'] + dy
    hs = lambda px, py: lvl(px, py, CX - hw * 0.35, hcy - hry * 0.45, hw * 1.25, hry * 1.25, hi=0.95, lo=0.42)
    big = 1.4 if st == 'afro' else 0.0
    if st == 'updo' and not back:     # 正面：发髻在头顶后面，先画，头发压住它下半
        bun(F, P, g, dy, CX, behind=True)
    if st == 'messy':
        m0 = dc.lobed(CX, hcy - 0.6, hw + 0.4, hry + 0.6, 15, 0.10, 0.5, pw=1.8)
    elif st == 'afro':
        m0 = dc.lobed(CX, hcy - 1.5, hw + big, hry + 1.8, 14, 0.10, 0.3)
    else:
        m0 = lambda px, py: ((px - CX) / hw) ** 2 + ((py - (hcy - 0.6)) / (hry + 0.6)) ** 2 <= 1
    if st == 'crew':
        m0 = lambda px, py: ((px - CX) / (hw - 0.8)) ** 2 + ((py - (hcy - 1.2)) / (hry)) ** 2 <= 1
    def long_part(px, py):          # 披下来的头发：03 到肩膀、06 波波头到下巴
        dx = abs(px - CX)
        if st == 'wavy':
            w = hw + 0.6 + 0.8 * math.sin(py * 0.7 + (0 if px > CX else 1.6))
            return hcy <= py <= chin + 4 + 1.0 * math.sin(px * 0.9) and dx <= w
        if st == 'bob':
            return hcy <= py <= chin - 0.5 and dx <= hw + 0.3 - max(0.0, py - (chin - 3)) * 0.6
        return False
    if back:
        def t(px, py):
            if not (m0(px, py) or long_part(px, py)):
                return False
            if st == 'updo':
                return py < chin - 3 + abs(px - CX) * 0.15
            if st == 'crew':
                return py < chin - 1.5
            if st in ('wavy', 'bob'):
                return True
            return py < chin - 1
        blob(F, t, (CX - hw - 3, top - 4, CX + hw + 3, chin + 6), 'hair', 'hair', hm, hs)
        if st in ('pigtails',):
            for y in range(int(top) + 2, int(chin) - 3):
                put(F, CX - 0.5, y, R(hm, 2), ('hair',))
        if st == 'afro':
            curls(F, hm)
    else:
        win = face_window(P, g, dy)
        blob(F, lambda px, py: (m0(px, py) or long_part(px, py)) and not win(px, py),
             (CX - hw - 3, top - 4, CX + hw + 3, chin + 6), 'hair', 'hair', hm, hs)
        if st == 'afro':
            curls(F, hm)
        if st == 'wavy':             # 侧分发缝
            for y in range(int(top) + 2, int(top) + 6):
                put(F, CX - 3 + (y - top) * 0.3, y, R(hm, 2), ('hair',))
    # 头顶翘毛 / 发髻 / 辫子
    if st == 'messy':
        for (x0, y0, x1, y1) in ((-1.5, 1.5, -3.0, -1.8), (1.0, 1.0, 2.4, -2.0), (4.5, 2.0, 6.5, 0.0)):
            F.capsule(CX + x0, top + y0, CX + x1, top + y1, 0.9, 0.5, 'hair', 'hair', hm, ('flat', 0))
    if st == 'crew':
        F.capsule(CX + 1, top + 1.8, CX + 2.4, top - 0.4, 1.0, 0.6, 'hair', 'hair', hm, ('flat', 0))
    if st == 'updo' and back:
        bun(F, P, g, dy, CX, behind=False)
    if st == 'pigtails':
        for side in (-1, 1):
            tail(F, P, g, dy, CX + side * (frx + 1.6), side)


def curls(F, hm):
    """05 的卷发：隔几格点一颗暗、一颗亮（一卷一卷）"""
    for y in range(FH):
        for x in range(FW):
            if F.part[y][x] == 'hair':
                if (x * 3 + y * 5) % 9 == 0:
                    F.shd[y][x] = ('flat', -1)
                elif (x * 3 + y * 5) % 9 == 4 and F.shd[y][x][1] >= 0:
                    F.shd[y][x] = ('flat', 1)


def bun(F, P, g, dy, cx, behind):
    top, hh, hm = g['top'] + dy, g['head_h'], P['hair']
    rx, ry = g['hw'] * 0.40, hh * 0.15
    cy = top - ry * 0.55
    if behind:
        # 正面：发髻在头后面，先画；后画的头发会压住它的下半
        pass
    ell(F, cx, cy, rx, ry, 'bun', 'bun', hm)
    y = int(cy + ry * 0.55)
    for x in range(int(cx - rx), int(cx + rx) + 1):
        put(F, x, y, R('k_gold', 3), ('bun',))


def tail(F, P, g, dy, ax, side):
    """08 的低马尾：耳朵下面扎一把，往下垂、发梢收尖，金发绳"""
    eye_y, chin, hm = g['eye_y'] + dy, g['chin'] + dy, P['hair']
    ay = eye_y + 2
    mx, my = ax + side * 1.2, chin + 1
    bx, by = ax + side * 1.6, chin + 8
    nm = 'tail%d' % side
    F.capsule(mx, my, bx, by, 2.9, 0.7, nm, 'tail', hm, shd=('flat', -1 if side > 0 else 0))
    F.capsule(ax, ay, mx, my, 2.2, 2.9, nm, 'tail', hm, shd=('flat', 0))
    for x in range(int(ax - 2), int(ax + 3)):
        put(F, x, ay + 1, R('k_gold', 3), (nm,))


def face_window(P, g, dy):
    top, chin, hh = g['top'] + dy, g['chin'] + dy, g['head_h']
    frx = g['frx']
    eye_y = g['eye_y'] + dy
    st = P['style']
    if st == 'messy':                 # 刘海尖尖地盖到眉毛
        def w(px, py):
            dx = px - (CX - 1)
            edge = eye_y - 4.5 + 2.0 * tipwave(dx + 1.5, 3.2) - 1.5 * max(0.0, 1 - abs(dx) / 1.8)
            return py > edge and abs(px - CX) < frx + 0.5 - max(0.0, eye_y + 2 - py) * 0.15
    elif st == 'updo':                # 往后梳，额头露出来，鬓边两绺
        def w(px, py):
            dx = abs(px - CX)
            return py > top + hh * 0.34 + dx * 0.36 and dx < frx + 0.3
    elif st == 'wavy':                # 侧分刘海，往右斜着盖
        part = CX - 3
        def w(px, py):
            edge = (eye_y - 4.2 + (px - part) * 0.28) if px >= part else (eye_y - 4.2 + (part - px) * 0.45)
            return py > min(edge, eye_y - 1.5) and abs(px - CX) < frx - 0.4
    elif st == 'crew':                # 短发，额头高
        def w(px, py):
            dx = abs(px - CX)
            return py > top + hh * 0.30 + dx * dx * 0.012 and dx < frx + 1.2
    elif st == 'afro':                # 卷发刘海
        def w(px, py):
            dx = px - CX
            return py > top + hh * 0.38 + 1.2 * abs(math.sin(dx * 0.9)) and abs(dx) < frx + 0.2
    elif st == 'bob':                 # 斜刘海盖到眉毛
        def w(px, py):
            edge = eye_y - 3.5 + (CX + 3 - px) * 0.22
            return py > min(edge, eye_y - 1.5) and abs(px - CX) < frx - 0.8
    else:                             # pigtails：中分刘海
        def w(px, py):
            dx = px - CX
            edge = eye_y - 3.5 + 1.0 * tipwave(dx + 1.2, 2.8) - 2.0 * max(0.0, 1 - abs(dx + 0.5) / 1.5)
            return py > edge and abs(dx) < frx - 0.2
    return w


# ---------------------------------------------------------------- 脸（正面 / 侧面）
def face_front(F, P, g, dy, pose):
    eye_y = g['eye_y'] + dy
    eh, ex = g['eh'], g['ex']
    blink = pose.get('blink', False)
    xs = [int(round(CX - ex - 1)), int(round(CX + ex - 1))]
    for x0 in xs:
        if P.get('happy') and not blink:       # 05：眯眯笑眼 ∩
            put(F, x0 - 1, eye_y + 2, EYE, ('face',))
            put(F, x0, eye_y + 1, EYE, ('face',))
            put(F, x0 + 1, eye_y + 1, EYE, ('face',))
            put(F, x0 + 2, eye_y + 2, EYE, ('face',))
        elif not blink:
            for yy in range(eh):
                put(F, x0, eye_y + yy, EYE, ('face',))
                put(F, x0 + 1, eye_y + yy, EYE, ('face',))
        else:
            for d in (-1, 0, 1, 2):
                put(F, x0 + d, eye_y + eh - 1, EYE, ('face',))
        if P.get('brows'):
            for d in (-1, 0, 1, 2):
                put(F, x0 + d, eye_y - 2, EYE, ('face',))
        if P.get('glasses'):                   # 06：圆眼镜
            cx_, cy_ = x0 + 1.0, eye_y + eh / 2
            for y in range(int(cy_) - 4, int(cy_) + 5):
                for x in range(int(cx_) - 5, int(cx_) + 5):
                    d = math.hypot((x + 0.5 - cx_) / 1.1, y + 0.5 - cy_)
                    if 2.6 <= d < 3.6:
                        put(F, x, y, GLASS, ('face', 'hair'))
    if P.get('glasses'):
        for x in range(xs[0] + 4, xs[1] - 2):
            put(F, x, eye_y + 1, GLASS, ('face',))
    my = eye_y + eh + max(2, round(g['head_h'] * 0.09))
    if pose.get('mouth') == 'open':
        put(F, CX - 1, my, MOUTH, ('face',))
        put(F, CX, my, MOUTH, ('face',))
        put(F, CX - 1, my + 1, MOUTH, ('face',))
        put(F, CX, my + 1, MOUTH, ('face',))
    else:
        put(F, CX - 1, my, MOUTH, ('face',))
        put(F, CX, my, MOUTH, ('face',))
        if P.get('happy'):
            put(F, CX - 2, my - 1, MOUTH, ('face',))
            put(F, CX + 1, my - 1, MOUTH, ('face',))
    if P['style'] == 'wavy':                   # 03：金耳环，挂在脸边、头发里面一格（不被头发边吃掉）
        for side in (-1, 1):
            xs_face = [x for x in range(FW) if F.part[int(eye_y + eh + 1)][x] == 'face']
            if xs_face:
                xe = (min(xs_face) - 1 if side < 0 else max(xs_face) + 1)    # 挂在脸外面一格的头发上：亮金配深栗发才看得出
                for dyy, col in ((1, R('k_gold', 4)), (2, R('k_gold', 4)), (3, R('k_gold', 3))):
                    put(F, xe, eye_y + eh + dyy, col, ('hair', 'face'))


def head(F, P, g, dy, d, pose):
    if d in ('down', 'up'):
        back = d == 'up'
        if not back:
            ell(F, CX, g['hcy'] + dy + 1.4, g['frx'] + 0.4, g['hry'] - 1.0, 'face', 'face', 'k_skin', shade=0, p=2.3)
            if P['style'] in ('crew', 'afro'):          # 短发：两边露小耳朵
                for side in (-1, 1):
                    ell(F, CX + side * (g['frx'] + 1.0), g['eye_y'] + dy + 2, 1.5, 2.0, 'ear', 'ear', 'k_skin', shade=0)
        else:
            if P['style'] == 'updo':
                ell(F, CX, g['chin'] + dy - 2, g['frx'] * 0.4, 2.4, 'neck', 'neck', 'k_skin', shade=-1)
            if P['style'] in ('crew', 'updo', 'afro'):
                for side in (-1, 1):
                    ell(F, CX + side * (g['frx'] + 1.0), g['eye_y'] + dy + 2, 1.5, 2.0, 'ear', 'ear', 'k_skin',
                        shade=0 if side < 0 else -1)
        hair_front(F, P, g, dy, back)
        if not back:
            face_front(F, P, g, dy, pose)
    else:
        head_side(F, P, g, dy, -1 if d == 'left' else 1, pose)


def head_side(F, P, g, dy, f, pose):
    st, hm = P['style'], P['hair']
    top, chin, hh = g['top'] + dy, g['chin'] + dy, g['head_h']
    hcy, hry, hw, frx = g['hcy'] + dy, g['hry'], g['hw'], g['frx']
    eye_y = g['eye_y'] + dy
    def sx(u):
        return CX + f * u
    def U(px):
        return (px - CX) * f
    big = 1.4 if st == 'afro' else 0.0
    def skull(px, py):
        return ((px - CX) / (hw + big)) ** 2 + ((py - (hcy - 0.6 - big)) / (hry + 0.6 + big)) ** 2 <= 1
    hairline = {'messy': eye_y - 4.0, 'updo': top + hh * 0.34, 'wavy': eye_y - 3.6, 'crew': top + hh * 0.30,
                'afro': top + hh * 0.38, 'bob': eye_y - 3.2, 'pigtails': eye_y - 3.2}[st]
    fcx, fcy = frx * 0.40, hcy + hh * 0.10
    frw, frh = frx * (0.80 if st in ('crew', 'afro', 'updo') else 0.66), hry * 0.84
    def facewin(px, py):
        if py <= hairline:
            return False
        k = 1 - ((py - fcy) / frh) ** 2
        return k > 0 and U(px) > fcx - frw * math.sqrt(k)
    def face_t(px, py):              # 侧脸前面鼓一点（脸颊）
        u = U(px)
        inside = skull(px, py) or (u > 0 and ((u - frx * 0.25) / (frx * 0.98)) ** 2 + ((py - (hcy + 1)) / (hry - 0.6)) ** 2 <= 1)
        return inside and facewin(px, py)
    def long_part(px, py):
        u = U(px)
        if st == 'wavy':
            return hcy - 2 <= py <= chin + 4 + 1.0 * math.sin(px * 0.9) and -hw - 0.8 - 0.8 * math.sin(py * 0.7) <= u <= frx * 0.1
        if st == 'bob':
            return hcy - 2 <= py <= chin - 0.5 and -hw - 0.3 <= u <= frx * 0.15
        return False
    hs = lambda px, py: lvl(px, py, sx(-hw * 0.1) - 3, hcy - hry * 0.45, hw * 1.25, hry * 1.25, hi=0.95, lo=0.42)
    if st == 'updo':                 # 发髻在头顶偏后
        rx, ry = hw * 0.40, hh * 0.15
        bx, by = sx(-hw * 0.25), top - ry * 0.55
        ell(F, bx, by, rx, ry, 'bun', 'bun', hm)
        for x in range(int(bx - rx), int(bx + rx) + 1):
            put(F, x, int(by + ry * 0.55), R('k_gold', 3), ('bun',))
    def hair_t(px, py):
        if face_t(px, py):
            return False
        if long_part(px, py):
            return True
        if not skull(px, py):
            return False
        if st == 'crew' and U(px) < 0 and py > chin - 4:
            return False
        if st == 'updo' and U(px) < 0 and py > chin - 3:
            return False
        return True
    if st == 'pigtails':             # 远处那条先画，压在头后面
        tail(F, P, g, dy, sx(-frx * 0.55) - f * 1.0, -f)
    blob(F, hair_t, (0, top - 4, FW, chin + 6), 'hair', 'hair', hm, hs)
    if st == 'afro':
        curls(F, hm)
    blob(F, face_t, (0, top, FW, chin + 2), 'face', 'face', 'k_skin', 0)
    if st in ('crew', 'updo'):       # 后颈
        blob(F, lambda px, py: chin - 4 <= py <= chin + 0.5 and -frx * 0.55 <= U(px) <= 0.5 and not F.has(px, py),
             (0, chin - 5, FW, chin + 1), 'neck', 'neck', 'k_skin', -1)
    if st in ('crew', 'afro', 'messy'):   # 耳朵：脸窗后沿
        ux = fcx - frw * 0.92
        ell(F, sx(ux + 0.6), eye_y + 2, 1.4, 2.0, 'ear', 'ear', 'k_skin', shade=0)
        put(F, sx(ux + 0.6), eye_y + 2, R('k_skin', 2), ('ear',))
    if st == 'messy':
        for (u0, y0, u1, y1) in ((-1.0, 1.5, -3.0, -1.8), (2.0, 1.0, 3.5, -2.0), (-5.0, 2.0, -7.5, 0.0)):
            F.capsule(sx(u0), top + y0, sx(u1), top + y1, 0.9, 0.5, 'hair', 'hair', hm, ('flat', 0))
    if st == 'crew':
        F.capsule(sx(1.0), top + 1.8, sx(2.4), top - 0.4, 1.0, 0.6, 'hair', 'hair', hm, ('flat', 0))
    if st == 'pigtails':
        tail(F, P, g, dy, sx(-frx * 0.55), f)
    # 眼睛：一个竖条在脸的前半；嘴在最前面
    eh = g['eh']
    x0 = int(math.floor(sx(frx * 0.52))) - (1 if f < 0 else 0)
    blink = pose.get('blink', False)
    if P.get('happy') and not blink:
        put(F, x0, eye_y + 1, EYE, ('face',))
        put(F, x0 + 1, eye_y + 1, EYE, ('face',))
        put(F, x0 + (2 if f > 0 else -1), eye_y + 2, EYE, ('face',))
        put(F, x0 - (1 if f > 0 else -2), eye_y + 2, EYE, ('face',))
    elif not blink:
        for yy in range(eh):
            put(F, x0, eye_y + yy, EYE, ('face',))
            put(F, x0 + 1, eye_y + yy, EYE, ('face',))
    else:
        for dd in (-1, 0, 1):
            put(F, x0 + dd, eye_y + eh - 1, EYE, ('face',))
    if P.get('brows'):
        for dd in (-1, 0, 1, 2):
            put(F, x0 + dd, eye_y - 2, EYE, ('face',))
    if P.get('glasses'):
        cx_, cy_ = x0 + 1.0, eye_y + eh / 2
        for y in range(int(cy_) - 4, int(cy_) + 5):
            for x in range(int(cx_) - 4, int(cx_) + 5):
                dd = math.hypot((x + 0.5 - cx_) / 0.9, y + 0.5 - cy_)
                if 2.5 <= dd < 3.5:
                    put(F, x, y, GLASS, ('face', 'hair'))
        for k in range(1, 6):
            put(F, cx_ - f * (3 + k), eye_y + 1, GLASS, ('face', 'hair'))
    my = eye_y + eh + max(2, round(hh * 0.09))
    put(F, sx(frx * 0.82), my, MOUTH, ('face',))
    if pose.get('mouth') == 'open':
        put(F, sx(frx * 0.82), my + 1, MOUTH, ('face',))
    if st == 'wavy':
        put(F, sx(-frx * 0.15), eye_y + eh + 1, R('k_gold', 3), ('hair', 'face'))


# ---------------------------------------------------------------- 衣服（正面 / 背面）
def hem_of(P, g, crotch, sit):
    w = P['wear']
    if w == 'long_dress':
        return FOOT - 1.5
    if w == 'coat':
        return crotch + 1 if not sit else crotch - 1
    if w == 'cardigan':
        return crotch - 1
    if w == 'shirt':
        return crotch - 4
    if w == 'sweater':
        return crotch - 1
    return crotch - 1


def body_front(F, P, g, pose, back):
    dy = pose.get('bob', 0)
    sit = pose.get('sit', False)
    sd = g['sd'] if sit else 0
    sh, crotch = g['sh'] + dy + sd, g['crotch'] + dy + sd
    tw, lw, ar = g['tw'], g['lw'], g['ar']
    hw = tw / 2
    w = P['wear']
    legm = P.get('leg', P['bottom'])
    # 腿 + 鞋（坐着：腿往前伸，正面只看得到膝盖往下一小截）
    if not (sit and back):
        for side in (-1, 1):
            lift = pose.get('lf' if side < 0 else 'rf', 0)
            if back:
                lift = pose.get('rf' if side < 0 else 'lf', 0)
            lx = CX + side * (lw * 0.5 + 0.3) + (side * 0.6 if sit else 0)
            ytop = (crotch - 1) if not sit else (crotch - 2)
            ybot = FOOT - 1 - lift
            box(F, lx - lw / 2, ytop, lx + lw / 2, ybot, 'leg%d' % side, 'leg', legm, shade=0 if side < 0 else -1, r=0.6)
            if w == 'overall':           # 浅色卷边裤脚
                for x in range(int(lx - lw / 2), int(lx + lw / 2) + 1):
                    put(F, x, ybot - 3, R('k_knit', 2), ('leg%d' % side,))
            box(F, lx - lw / 2 - 0.6 + side * 0.4, ybot - 2.2, lx + lw / 2 + 0.6 + side * 0.4, ybot + 0.99,
                'shoe%d' % side, 'shoe', P['shoe'], shade=lambda px, py, yb=ybot: 0 if py < yb else -1, r=1.2)
    # 下装：裙子 / 裤腰
    if w in ('cardigan', 'sweater'):     # 半裙：03 到膝盖、06 到小腿
        sk_bot = (crotch + 3) if w == 'cardigan' else (FOOT - 4)
        if sit:
            sk_bot = min(sk_bot, crotch + 2) if w == 'cardigan' else FOOT - 3
        blob(F, lambda px, py: crotch - 3 <= py <= sk_bot + 0.5 and abs(px - CX) <= hw + (py - crotch + 3) * 0.25,
             (0, crotch - 3, FW, sk_bot + 1), 'skirt', 'skirt', P['bottom'], lr_shade(CX, hw + 2))
    if w in ('shirt', 'coat', 'floral', 'overall'):
        blob(F, lambda px, py: crotch - 5 <= py <= crotch + 0.5 and abs(px - CX) <= hw - 0.3,
             (0, crotch - 5, FW, crotch + 1), 'hips', 'hips', P['bottom'], lr_shade(CX, hw))
    # 上身
    hem = hem_of(P, g, crotch, sit)
    if sit and w == 'long_dress':
        hem = FOOT - 1.5
    def top_t(px, py):
        if py < sh or py > hem + 0.5:
            return False
        t = (py - sh) / max(1, hem - sh)
        ww = hw - (1.6 if py < sh + 1 else (0.6 if py < sh + 2 else 0))
        if w == 'long_dress' and t > 0.30:
            ww += (t - 0.30) * 3.4
        if w == 'coat' and py > crotch - 3:
            ww += (py - crotch + 3) * 0.35
        if w == 'floral':
            ww += 0.8 * math.sin(min(1.0, t * 1.2) * math.pi * 0.9)    # 05 的小肚子
        if abs(px - CX) > ww:
            return False
        if w == 'coat' and not back and py > crotch - 2 and abs(px - CX) < 0.5 + (py - crotch + 2) * 0.5:
            return False                  # 外套下摆正面敞开
        return True
    topm = P['top'] if w != 'overall' else P['top']
    blob(F, top_t, (0, sh, FW, hem + 1), 'torso', 'torso', topm, lr_shade(CX, hw + 1.5))
    c = int(CX)
    T = ('torso',)
    if w == 'coat':
        if not back:
            for y in range(sh, crotch - 1):                  # 米色衬里 + 金盘扣
                for x in (c - 2, c - 1, c, c + 1):
                    put(F, x, y, R('k_cream', 3 if x < c else 2), T)
            for k in range(3):
                yy = sh + 3 + k * 4
                for x in range(c - 3, c + 3):
                    put(F, x, yy, R('k_gold', 3), T)
        else:
            for y in range(sh + 3, sh + 12):
                put(F, c - 1, y, R('k_gold', 3), T)
        for x in range(FW):
            put(F, x, hem - 1, R('k_gold', 2), T)
    elif w == 'long_dress':
        belt = sh + round((FOOT - sh) * 0.28)
        for x in range(FW):
            put(F, x, belt, R('k_gold', 3), T)
            put(F, x, hem - 1, R('k_gold', 2), T)
        if not back:
            for i in range(3):
                put(F, c - 2 + i * 0.5, sh + i, R('k_skin', 3), T)
                put(F, c + 1 - i * 0.5, sh + i, R('k_skin', 3), T)
    elif w == 'cardigan':
        if not back:
            for y in range(sh, int(hem)):
                for x in (c - 1, c):
                    put(F, x, y, R('k_skirt', 2), T)
                put(F, c - 2, y, R('k_knit', 4), T)
                put(F, c + 1, y, R('k_knit', 4), T)
        for x in range(FW):
            put(F, x, hem - 1, R('k_knit', 1), T)
    elif w == 'shirt':
        if not back:
            for i in range(3):                               # 敞开的领口
                for x in range(c - 2 + i, c + 2 - i):
                    put(F, x, sh + i, R('k_skin', 3), T)
            for y in range(sh + 3, int(hem)):
                put(F, c - 1, y, R('k_white', 1), T)
        for x in range(FW):                                  # 棕皮带
            put(F, x, crotch - 5, R('k_shoe', 2), ('hips',))
        if not back:
            put(F, c - 1, crotch - 5, R('k_brass', 3), ('hips',))
            put(F, c, crotch - 5, R('k_brass', 3), ('hips',))
    elif w == 'floral':
        tile = ['RR....', 'RY..G.', '...OO.', '.G.OY.', '......', 'O...RR']   # 一朵朵 2×2 的红花、橙花 + 绿叶
        cmap = {'R': FLOWERS[0], 'O': FLOWERS[1], 'Y': FLOWERS[2], 'G': FLOWERS[3]}
        for y in range(sh + 1, int(hem)):
            for x in range(FW):
                ch = tile[(y - sh) % 6][(x + 2) % 6]
                if ch in cmap:
                    put(F, x, y, cmap[ch], T)
        if not back:
            for i in range(2):
                for x in range(c - 1 + i, c + 1 - i):
                    put(F, x, sh + i, R('k_skin', 3), T)
    elif w == 'sweater':
        for x in range(FW):
            put(F, x, hem - 1, R('k_mauve', 1), T)
    elif w == 'overall':
        G = 'k_green'
        waist = sh + round((hem - sh) * 0.55)
        for y in range(waist, int(hem) + 1):
            for x in range(FW):
                put(F, x, y, R(G, 2 if x < c + 2 else 1), T)
        if not back:
            for y in range(sh + 3, waist):                   # 胸前护片
                for x in range(c - 3, c + 3):
                    put(F, x, y, R(G, 2 if x < c + 1 else 1), T)
            for y in range(sh, sh + 3):                      # 背带
                put(F, c - 3 - (sh + 3 - y) // 2, y, R(G, 2), T)
                put(F, c + 2 + (sh + 3 - y) // 2, y, R(G, 1), T)
            put(F, c - 3, sh + 3, R('k_brass', 3), T)
            put(F, c + 2, sh + 3, R('k_brass', 3), T)
        else:
            for y in range(sh, waist):
                for x in (c - 3, c + 2):
                    put(F, x, y, R(G, 2), T)
        for x in range(FW):
            put(F, x, crotch - 1, R(G, 1), ('hips',))
    # 胳膊 + 手
    arms_front(F, P, g, pose, sh, hw, back)


def arms_front(F, P, g, pose, sh, hw, back):
    ar = g['ar']
    for side in (-1, 1):
        sw = pose.get('la' if side < 0 else 'ra', 0)
        if back:
            sw = -pose.get('ra' if side < 0 else 'la', 0)
        ax, ay = CX + side * (hw + 0.2), sh + 2           # 肩在身子边上，胳膊往外伸一点：小手露在身子两边
        L = g['tl'] * 0.52
        hx_, hy_ = ax + side * 2.0 - side * sw * 0.9, ay + L - abs(sw) * 0.6 + (sw * 0.9 if not back else 0)
        if pose.get('lap'):
            hx_, hy_ = CX + side * (hw * 0.45), sh + g['tl'] * 0.62
        if pose.get('talk') and side == -1 and not back:
            hx_, hy_ = CX - hw * 0.25, sh + g['tl'] * 0.30
        draw_arm(F, P, side, ax, ay, hx_, hy_, ar, 0 if side < 0 else -1)


def draw_arm(F, P, side, ax, ay, hx_, hy_, ar, lv):
    nm = 'arm%s' % side
    sleeve = P['sleeve']
    if P.get('short') or P.get('rolled'):
        F.capsule(ax, ay, hx_, hy_ - 0.8, ar * 0.95, ar * 0.85, nm, nm, 'k_skin', shd=('flat', lv))
        k = 0.45 if P.get('short') else 0.62
        mx, my = ax + (hx_ - ax) * k, ay + (hy_ - ay) * k
        F.capsule(ax, ay, mx, my, ar + 0.2, ar + 0.3, nm + 's', nm, sleeve, shd=('flat', lv))
    else:
        F.capsule(ax, ay, hx_, hy_ - 0.8, ar, ar * 0.9, nm, nm, sleeve, shd=('flat', lv))
        if P['wear'] == 'coat':                       # 金袖口
            F.capsule(hx_ + (ax - hx_) * 0.18, hy_ - 1.6 + (ay - hy_) * 0.18, hx_, hy_ - 0.8, ar + 0.1, ar, nm + 'c', nm, 'k_gold',
                      shd=('flat', lv))
    ell(F, hx_, hy_ + 0.3, ar + 0.8, ar + 0.7, 'hand%s' % side, nm, 'k_skin',
        shade=lambda px, py, hx_=hx_, hy_=hy_: 0 if (px < hx_ + 0.6 or py < hy_) else -1)


# ---------------------------------------------------------------- 衣服（侧面）
def body_side(F, P, g, pose, f):
    dy = pose.get('bob', 0)
    sit = pose.get('sit', False)
    sd = g['sd'] if sit else 0
    sh, crotch = g['sh'] + dy + sd, g['crotch'] + dy + sd
    tw, lw, ar = g['tw'], g['lw'], g['ar']
    depth = tw * 0.78
    w = P['wear']
    legm = P.get('leg', P['bottom'])
    def sx(u):
        return CX + f * u
    # 腿
    if not sit:
        legs = (('b', pose['fl']), ('f', pose['nl']))
        for which, (fd, lift) in legs:
            lx = sx(fd)
            ybot = FOOT - 1 - lift
            box(F, lx - lw / 2, crotch - 1, lx + lw / 2, ybot, 'leg' + which, 'leg' + which, legm, shade=0 if which == 'f' else -1, r=0.6)
            if w == 'overall':
                for x in range(int(lx - lw / 2), int(lx + lw / 2) + 1):
                    put(F, x, ybot - 3, R('k_knit', 2), ('leg' + which,))
            x0, x1 = sorted((lx - lw / 2 - 0.4 * f, lx + lw / 2 + 1.8 * f))
            box(F, x0, ybot - 2.2, x1, ybot + 0.99, 'shoe' + which, 'shoe' + which, P['shoe'],
                shade=lambda px, py, yb=ybot: 0 if py < yb else -1, r=1.2)
    else:
        # 坐：大腿往前平伸，小腿垂到地，脚踩地
        for which, du in (('b', -0.8), ('f', 0.6)):
            hipy = crotch - 1
            kx = sx(depth / 2 + 3.5 + du)
            x0, x1 = sorted((sx(-1 + du), kx))
            box(F, x0, hipy - lw / 2, x1, hipy + lw / 2, 'thigh' + which, 'leg' + which, legm, shade=0 if which == 'f' else -1, r=0.8)
            box(F, kx - lw / 2, hipy - 1, kx + lw / 2, FOOT - 1, 'shin' + which, 'leg' + which, legm, shade=0 if which == 'f' else -1, r=0.6)
            sx0, sx1 = sorted((kx - f * (lw / 2 + 0.4), kx + f * (lw / 2 + 1.8)))
            box(F, sx0, FOOT - 3.2, sx1, FOOT - 0.01, 'shoe' + which, 'shoe' + which, P['shoe'],
                shade=lambda px, py: 0 if py < FOOT - 1 else -1, r=1.2)
    def arm(which, s):
        ax, ay = sx(-0.4), sh + 2
        L = g['tl'] * 0.48
        if sit:
            hx_, hy_ = sx(depth / 2 + 1.5), crotch - 3
        elif pose.get('talk') and which == 'f':
            hx_, hy_ = sx(depth / 2 + 2.0), sh + g['tl'] * 0.30
        else:
            hx_, hy_ = sx(s * 3.2), ay + L - abs(s) * 0.8
        draw_arm(F, P, which, ax, ay, hx_, hy_, ar, 0 if which == 'f' else -1)
    arm('b', pose.get('fa', 0))
    # 下装
    swing = (pose['nl'][0] - pose['fl'][0]) if not sit else 0
    if w in ('cardigan', 'sweater'):
        sk_bot = (crotch + 4) if w == 'cardigan' else (FOOT - 3)
        if sit:
            sk_bot = crotch + 1
        def sk(px, py):
            if py < crotch - 3 or py > sk_bot + 0.5:
                return False
            u = (px - CX) * f
            e = (py - crotch + 3) * 0.25 + abs(swing) * 0.15
            fr = depth / 2 + e + (4.5 if sit else 0)
            return -depth / 2 - e <= u <= fr
        blob(F, sk, (0, crotch - 3, FW, sk_bot + 1), 'skirt', 'skirt', P['bottom'], lr_shade(CX - f * 0.5, depth / 2 + 1))
    if w in ('shirt', 'coat', 'floral', 'overall') and not sit:
        blob(F, lambda px, py: crotch - 5 <= py <= crotch + 0.5 and abs((px - CX) * f + 0.2) <= depth / 2 - 0.3,
             (0, crotch - 5, FW, crotch + 1), 'hips', 'hips', P['bottom'], lr_shade(CX, depth / 2))
    if w in ('shirt', 'coat', 'floral', 'overall') and sit:
        blob(F, lambda px, py: crotch - 5 <= py <= crotch + 0.5 and -depth / 2 <= (px - CX) * f <= depth / 2 + 1,
             (0, crotch - 5, FW, crotch + 1), 'hips', 'hips', P['bottom'], lr_shade(CX, depth / 2))
    hem = hem_of(P, g, crotch, sit)
    def top_t(px, py):
        if py < sh or py > hem + 0.5:
            return False
        t = (py - sh) / max(1, hem - sh)
        u = (px - CX) * f
        fr = depth / 2 - (1.4 if py < sh + 1 else (0.5 if py < sh + 2 else 0))
        bk = fr
        if w == 'long_dress' and t > 0.30:
            fr += (t - 0.30) * (3.0 + abs(swing) * 0.25) + (5.0 * t if sit else 0)
            bk += (t - 0.30) * (2.4 + abs(swing) * 0.15)
        if w == 'coat' and py > crotch - 3:
            fr += (py - crotch + 3) * 0.25
            bk += (py - crotch + 3) * 0.45
        if w == 'floral':
            fr += 1.2 * math.sin(min(1.0, t * 1.2) * math.pi * 0.9)
        return -bk <= u <= fr
    blob(F, top_t, (0, sh, FW, hem + 1), 'torso', 'torso', P['top'], lr_shade(CX - f * 0.5, depth / 2 + 1))
    T = ('torso',)
    def front_x(y):
        xs = [x for x in range(FW) if F.part[int(y)][x] == 'torso'] if 0 <= int(y) < FH else []
        return (max(xs) if f > 0 else min(xs)) if xs else None
    if w == 'coat':
        for y in range(sh, int(hem)):
            xf = front_x(y)
            if xf is not None:
                put(F, xf - f * 1, y, R('k_cream', 3) if y < crotch - 1 else R('k_gold', 3), T)
        for k in range(3):
            xf = front_x(sh + 3 + k * 4)
            if xf is not None:
                for dd in (1, 2, 3):
                    put(F, xf - f * dd, sh + 3 + k * 4, R('k_gold', 3), T)
        for x in range(FW):
            put(F, x, hem - 1, R('k_gold', 2), T)
    elif w == 'long_dress':
        belt = sh + round((FOOT - sh) * 0.28)
        for x in range(FW):
            put(F, x, belt, R('k_gold', 3), T)
            put(F, x, hem - 1, R('k_gold', 2), T)
    elif w == 'cardigan':
        for y in range(sh, int(hem)):
            xf = front_x(y)
            if xf is not None:
                put(F, xf - f * 1, y, R('k_skirt', 2), T)
        for x in range(FW):
            put(F, x, hem - 1, R('k_knit', 1), T)
    elif w == 'shirt':
        xf = front_x(sh + 1)
        if xf is not None:
            put(F, xf - f * 1, sh, R('k_skin', 3), T)
            put(F, xf - f * 1, sh + 1, R('k_skin', 3), T)
        for x in range(FW):
            put(F, x, crotch - 5, R('k_shoe', 2), ('hips',))
    elif w == 'floral':
        tile = ['RR....', 'RY..G.', '...OO.', '.G.OY.', '......', 'O...RR']   # 一朵朵 2×2 的红花、橙花 + 绿叶
        cmap = {'R': FLOWERS[0], 'O': FLOWERS[1], 'Y': FLOWERS[2], 'G': FLOWERS[3]}
        for y in range(sh + 1, int(hem)):
            for x in range(FW):
                ch = tile[(y - sh) % 6][(x + 2) % 6]
                if ch in cmap:
                    put(F, x, y, cmap[ch], T)
    elif w == 'sweater':
        for x in range(FW):
            put(F, x, hem - 1, R('k_mauve', 1), T)
    elif w == 'overall':
        G = 'k_green'
        waist = sh + round((hem - sh) * 0.55)
        for y in range(waist, int(hem) + 1):
            for x in range(FW):
                put(F, x, y, R(G, 2), T)
        for y in range(sh + 3, waist):
            xf = front_x(y)
            if xf is not None:
                for dd in (0, 1, 2):
                    put(F, xf - f * dd, y, R(G, 2), T)
        for y in range(sh, sh + 4):          # 背带斜过肩
            xf = front_x(sh + 3)
            if xf is not None:
                put(F, xf - f * (2 + (sh + 3 - y) * 1.5), y, R(G, 2), T)
        xf = front_x(sh + 3)
        if xf is not None:
            put(F, xf - f * 1, sh + 3, R('k_brass', 3), T)
    arm('f', pose.get('na', 0))


# ---------------------------------------------------------------- 一格、动作表
def frame(P, g, d, pose):
    F = dc.Fig()
    dy = pose.get('bob', 0) + pose.get('nod', 0)
    if d in ('down', 'up'):
        body_front(F, P, g, pose, back=(d == 'up'))
    else:
        body_side(F, P, g, pose, -1 if d == 'left' else 1)
    hd = 'left' if pose.get('turn') == 'left' else ('right' if pose.get('turn') == 'right' else d)
    head(F, P, g, dy + (g['sd'] if pose.get('sit') else 0), hd, pose)      # 背坐转头：身子背影、头画侧面
    return F.render()


def walk_poses(d):
    if d in ('down', 'up'):
        return [dict(bob=0, lf=0, rf=0, la=0.25, ra=-0.15),
                dict(bob=1, lf=2, rf=0, la=1.0, ra=-1.0),
                dict(bob=0, lf=0, rf=0, la=0.2, ra=-0.2),
                dict(bob=1, lf=0, rf=2, la=-1.0, ra=1.0)]
    s = 2.6
    return [dict(bob=0, nl=(1.0, 0), fl=(-1.0, 0), na=0.25, fa=-0.2),
            dict(bob=1, nl=(s, 0), fl=(-s, 1), na=-1.0, fa=1.0),
            dict(bob=0, nl=(-0.5, 0), fl=(1.0, 2), na=-0.2, fa=0.2),
            dict(bob=1, nl=(-s, 1), fl=(s, 0), na=1.0, fa=-1.0)]


def build(code, H=SIZE):
    P = CH[code]
    g = geo(P, H)
    im = Image.new('RGBA', (FW * 16, FH * 2), (0, 0, 0, 0))
    k = 0
    for d in ('down', 'left', 'right', 'up'):
        for pose in walk_poses(d):
            im.paste(frame(P, g, d, pose), (k * FW, 0))
            k += 1
    stand = dict(bob=0, lf=0, rf=0, la=0.0, ra=0.0)
    extra = [
        frame(P, g, 'down', dict(stand)),                                   # 16 待机
        frame(P, g, 'down', dict(stand, blink=True)),                       # 17 眨眼
        frame(P, g, 'down', dict(stand, talk=True, mouth='open')),          # 18 说话：抬手、张嘴
        frame(P, g, 'down', dict(stand, talk=True, nod=1)),                 # 19 说话：点头
    ]
    for d in ('down', 'left', 'right', 'up'):                               # 20-27 坐，第 2 格呼吸
        for b in (0, 1):
            extra.append(frame(P, g, d, dict(bob=b, lf=0, rf=0, la=0, ra=0, sit=True, lap=True)))
    extra += [frame(P, g, 'up', dict(bob=0, lf=0, rf=0, sit=True, turn='left', mouth='open')),     # 28 背坐转头朝左说话
              frame(P, g, 'up', dict(bob=0, lf=0, rf=0, sit=True, turn='right', mouth='open'))]    # 29 朝右
    for i, fr in enumerate(extra):
        im.paste(fr, (i * FW, FH))
    bb = im.crop((0, 0, FW, FH)).getbbox()
    drawn = bb[3] - bb[1]
    j = {
        'frame': [FW, FH],
        'frames': {'down': [0, 1, 2, 3], 'left': [4, 5, 6, 7], 'right': [8, 9, 10, 11], 'up': [12, 13, 14, 15],
                   'idle': [16] * 11 + [17], 'talk': [18, 19],
                   'sit_down': [20, 21], 'sit_left': [22, 23], 'sit_right': [24, 25], 'sit_up': [26, 27],
                   'sit_up_talk_left': [28], 'sit_up_talk_right': [29]},
        'fps': 8,
        'height_m': round(1.75 * drawn / 84, 4),
        'idle_fps': 6, 'talk_fps': 3, 'sit_fps': 1,
        'sit_seat': {'down': FOOT - 2, 'left': g['seat'], 'right': g['seat'], 'up': g['seat']},
        'sit_note': ('坐着的四个朝向，脚点照旧是格子下沿正中（脚踩最后一行）：摆的时候把脚点放在座位前沿的地上就行。'
                     'sit_seat 是坐垫面在格子里的哪一行（朝左右、朝上 = 屁股底），要按坐垫高度对齐时用；scene_chibi.png 就是这么摆的。'),
        'mark': P['mark'],
        'note': ('大头小人（chibi01/draw_chibi7.py 生成，%d 档），别手改。整张 1024×168，格子排法跟 chr_CODE-GUEST-xx 一样：'
                 '第一行 16 格走路（下 0-3、左 4-7、右 8-11、上 12-15，第 0 格站定）；第二行 16 待机、17 眨眼'
                 '（idle 序列 11 格睁眼 + 1 格眨眼，idle_fps 6 = 每 2 秒眨一下）、18-19 说话、20-27 坐四个朝向各 2 格；'
                 '多出来 28-29 背对着坐、转头朝左 / 朝右说话（草坪那种一排排坐的场面用，不用可以不接）。'
                 '脚踩最后一行、中线 x=32；height_m 照第 0 格画出来的高（%d 像素）÷84×1.75 算，游戏照 height_m 缩放以后一比一。'
                 % (H, drawn)),
    }
    return im, j


# ---------------------------------------------------------------- 出图
def af(a, idx):
    return dc.atlas_frame(a, idx)


def ref_crop(scale=2):
    im = Image.open(REF).convert('RGBA').crop((110, 80, 290, 344))
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def lineup(at, path, S=4):
    """7 位一排同一底线：上排大头（第 0 格）、下排 GPT 原图第 0 格，放大 4 倍；最上面贴参考图"""
    rc = ref_crop(2)
    cw = FW * S
    W = cw * len(CODES) + 16 * (len(CODES) + 1)
    H = rc.height + 16 + (FH * S + 16) * 2
    out = dc.checker_bg(W, H)
    out.paste(rc, (16, 8))
    y0 = rc.height + 16
    for k, code in enumerate(CODES):
        x = 16 + k * (cw + 16)
        for r, im in enumerate((af(at[code], 0), dc.gpt_frame(code, 0))):
            big = im.resize((cw, FH * S), Image.NEAREST)
            out.paste(big, (x, y0 + r * (FH * S + 16)), big)
    px = out.load()
    for r in range(2):
        yb = y0 + r * (FH * S + 16) + FH * S
        for x in range(W):
            for t in range(2):
                px[x, min(H - 1, yb + t)] = (150, 60, 50, 255)
    out.save(path)


def sheet(at, path):
    S = 2
    rc = ref_crop(1)
    W = FW * 16 * S + rc.width + 16
    out = dc.checker_bg(W, (FH * 2 * S + 12) * len(CODES))
    for r, code in enumerate(CODES):
        a = at[code].resize((FW * 16 * S, FH * 2 * S), Image.NEAREST)
        out.paste(a, (0, r * (FH * 2 * S + 12)), a)
    out.paste(rc, (FW * 16 * S + 16, 0))
    out.save(path)


def walk_gif(at, path):
    """7 位一列一位、四个朝向四排（下 左 右 上）循环走，放大 4 倍"""
    S = 4
    W, Hh = FW * S * len(CODES), FH * S * 4
    frames = []
    for k in range(4):
        can = dc.checker_bg(W, Hh)
        for c, code in enumerate(CODES):
            for r, d in enumerate((0, 4, 8, 12)):
                im = af(at[code], d + k).resize((FW * S, FH * S), Image.NEAREST)
                can.paste(im, (c * FW * S, r * FH * S), im)
        frames.append(can.convert('RGB').quantize(colors=255, method=Image.MEDIANCUT, dither=Image.NONE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=150, loop=0, disposal=1)


def lounge(at):
    jj = json.load(open(LOUNGE + 'room.json'))
    bg = jj['background']
    can = Image.new('RGBA', (1100, 900), (43, 32, 30, 255))
    can.alpha_composite(Image.open(LOUNGE + 'room.png').convert('RGBA'), (bg['x'], bg['y']))
    items = [(p['foot'], 0, Image.open(LOUNGE + 'props/' + p['png'].split('/')[-1]).convert('RGBA'), p['x'], p['y'])
             for p in jj['props']]
    people = [('06', 20, 551, 270), ('05', 21, 584, 270),          # 北边沙发朝下坐
              ('01', 24, 404, 418), ('03', 22, 462, 418),          # 西边茶座面对面
              ('04', 1, 600, 520), ('08', 16, 470, 600), ('02', 5, 560, 470)]
    for (code, idx, fx, fy) in people:
        items.append((fy + 0.5, 1, af(at[code], idx), fx - FW // 2, fy - FH + 1))
    items.sort(key=lambda t: (t[0], t[1]))
    for _, _, im, x, y in items:
        can.alpha_composite(im, (x, y))
    r = jj['room']
    return can.crop((r['x0'] - 6, 98, r['x1'] + 6, 700))


def lawn(at):
    seats = [((0, 'L4'), '01'), ((0, 'L3'), '02'), ((0, 'L2'), '03'), ((0, 'R2'), '04'), ((0, 'R3'), '05'), ((0, 'R4'), '06'),
             ((1, 'L4'), '08'), ((1, 'L3'), '05'), ((1, 'L2'), '01'), ((1, 'R2'), '06'), ((1, 'R3'), '02'), ((1, 'R4'), '03')]
    people = []
    turn = {(0, 'L3'): 29, (0, 'L2'): 28, (0, 'R3'): 29, (0, 'R4'): 28, (1, 'L4'): 29, (1, 'L3'): 28, (1, 'R2'): 29, (1, 'R3'): 28}
    for k, (rs, code) in enumerate(seats):
        x, y, foot = dc.LAWN_CHAIRS[rs]
        g = geo(CH[code], SIZE)
        people.append((at[code], turn.get(rs, 26 + (k % 2)), x + 12, y + 21 - g['seat'] + 83, foot + 2))
    people += [(at['02'], 1, 423, 650, None), (at['08'], 13, 410, 600, None), (at['04'], 18, 300, 712, None),
               (at['03'], 4, 334, 712, None), (at['05'], 9, 520, 706, None)]
    can = dc.lawn_canvas(people)
    return can.crop((232, 376, 612, 728))


def scene(at, path):
    gap = 12
    a, b = lounge(at), lawn(at)
    big_a = a.resize((a.width * 2, a.height * 2), Image.NEAREST)
    big_b = b.resize((b.width * 2, b.height * 2), Image.NEAREST)
    W = max(a.width + gap + b.width, big_a.width + gap + big_b.width)
    H = max(a.height, b.height) + gap + max(big_a.height, big_b.height)
    out = Image.new('RGBA', (W, H), (43, 32, 30, 255))
    out.paste(a, (0, 0))
    out.paste(b, (a.width + gap, 0))
    y = max(a.height, b.height) + gap
    out.paste(big_a, (0, y))
    out.paste(big_b, (big_a.width + gap, y))
    out.save(path)


def two_sizes(path):
    """第 1 轮：64、76 两档并排（第 0 格），各放进休息间看大小"""
    S = 3
    rows = []
    for H in (64, 76):
        strip = Image.new('RGBA', (FW * len(CODES), FH), (0, 0, 0, 0))
        for k, code in enumerate(CODES):
            im, _ = build(code, H)
            strip.paste(af(im, 0), (k * FW, 0))
        rows.append(strip.resize((strip.width * S, FH * S), Image.NEAREST))
    out = dc.checker_bg(rows[0].width, FH * S * 2 + 12)
    for r, s in enumerate(rows):
        out.paste(s, (0, r * (FH * S + 12)), s)
    out.save(path)


def check(at):
    for code in CODES:
        im = at[code]
        hist = im.split()[3].histogram()
        bad = sum(hist[1:255])
        bb = af(im, 0).getbbox()
        cols = len(set(p for p in im.getdata() if p[3] == 255))
        g = geo(CH[code], SIZE)
        print('%s %-3s 半透明 %d | 站着 %d 高 宽 %d | 头 %d（占 %.2f）| 色数 %d%s' % (
            code, CH[code]['name'], bad, bb[3] - bb[1], bb[2] - bb[0], g['head_h'], g['head_h'] / (bb[3] - bb[1]), cols,
            '  <-- 超 64 色' if cols > 64 else ''))


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    if arg == 'both':
        two_sizes(os.path.join(HERE, 'work', 'two_sizes.png'))
    at = {}
    for code in CODES:
        im, j = build(code)
        at[code] = im
        im.save(os.path.join(HERE, 'chr_CHIBI-GUEST-%s.png' % code))
        with open(os.path.join(HERE, 'chr_CHIBI-GUEST-%s.json' % code), 'w', encoding='utf-8') as fp:
            json.dump(j, fp, ensure_ascii=False, indent=1)
    lineup(at, os.path.join(HERE, 'lineup.png'))
    walk_gif(at, os.path.join(HERE, 'walk_chibi.gif'))
    scene(at, os.path.join(HERE, 'scene_chibi.png'))
    sheet(at, os.path.join(HERE, 'sheet_chibi.png'))
    if arg and arg != 'both':
        sheet(at, os.path.join(HERE, 'work', arg + '.png'))
    check(at)


if __name__ == '__main__':
    main()
