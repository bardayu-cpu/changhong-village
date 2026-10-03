#!/usr/bin/env python3
"""后厅三间（化妆间、休息间、麻将室）共用的地板 v3（2026-10-03，01 派、Claude 画）。

阿鱼看了两版：01 版「地板太细了，感觉不好看」；06 第二版宽深红木「颜色太深了，看起来跟酱油一样很脏」「只要不是这样的酱油色就行了」。
第三版：留第二版的宽木板（一排 12 像素 ≈ 0.37 米），颜色换成暖、亮、干净的蜜色木（新色带 hw，不碰 fl0～fl7：果园土路在用）；
木纹少而长、几乎不放木节；板缝只比板面暗两档，不压黑。

三个脚本都 import 这一份（放在同一个文件夹），各自把 HW_HEX 并进自己的 PAL_HEX、把 "hw" 色带并进 RAMPS，
灯光、影子照旧用各自的 ShadeMap 在 hw 色带里挪档。三间同一排距（从 y 226 起每 12 一排），板缝在一条线上；各用自己的种子。
"""
import random

# 蜜色木地板（暗 → 亮）：暗部往红褐偏、亮部往蜜黄偏；hw4 是大多数板子的颜色
HW_HEX = {
    "hw0": "#77452a",   # 最深：墙脚、家具底下最暗的影
    "hw1": "#955a35",   # 影子
    "hw2": "#ae6f41",   # 板缝、浅影
    "hw3": "#c2844e",   # 深一点的板 / 木纹
    "hw4": "#d2985d",   # 大多数板
    "hw5": "#dfac70",   # 亮一点的板 / 倒角
    "hw6": "#ebc288",   # 灯底下最亮
}
HW_RAMP = ["hw0", "hw1", "hw2", "hw3", "hw4", "hw5", "hw6"]

FLOOR_Y0 = 226          # 北墙脚（三间一样）
FLOOR_ROW = 12          # 一排 12 像素（第二版定的宽板，留着）


def draw_floor_v3(L, x0, x1, y_end, seed):
    """横铺宽木地板：每排上沿一条板缝（hw2），下一行倒角亮一线；板长 100～220（2～4.5 米）、上下排接缝错开；
    板子深浅只在 hw3 / hw4 / hw5 三档里换（大多 hw4），每块一两道长木纹（暗一档、断续、缓缓起伏），木节极少"""
    rnd = random.Random(20261031 + seed)
    y = FLOOR_Y0
    prev = []
    while y < y_end:
        L.hl(x0, x1, y, "hw2")                                   # 排与排之间的缝
        x = x0 - rnd.randrange(0, 140)
        joints = []
        last = None
        while x < x1:
            ln = rnd.randrange(100, 220)
            for j in prev:                                       # 上下两排的接缝错开 30 以上
                if abs(x + ln - j) < 30:
                    ln += 44
            t = rnd.choice([4, 4, 4, 4, 4, 5, 5, 3])
            if t == last:
                t = 5 if t == 4 else 4
            last = t
            base = "hw%d" % t
            a, b = max(x, x0), min(x + ln, x1)
            if b > a:
                L.rect(a, y + 1, b, y + FLOOR_ROW, base)
                L.hl(a, b, y + 1, "hw%d" % min(6, t + 1))        # 倒角那一线亮
                # 木纹：一两道长纹（板长的一半以上），断续、偶尔上下挪一行
                n = rnd.choice([1, 1, 1, 2, 2, 0])
                for _ in range(n):
                    gy = y + rnd.randrange(4, FLOOR_ROW - 2)
                    span = b - a
                    gx = a + rnd.randrange(4, max(5, span // 4))
                    gl = rnd.randrange(max(8, span // 2), max(9, span * 4 // 5))
                    gaps = set()
                    for _ in range(rnd.choice([0, 1, 1, 2])):         # 一道纹断开一两处（每处 2～4 像素）
                        g0 = rnd.randrange(6, max(7, gl - 6))
                        gaps.update(range(g0, g0 + rnd.randrange(2, 5)))
                    k = 0
                    while k < gl:
                        xx = gx + k
                        if xx >= b - 3:
                            break
                        if k not in gaps:
                            L.p(xx, gy, "hw%d" % (t - 1))
                        if k > 4 and rnd.random() < 0.03:             # 偶尔顺着纹挪一行（缓缓起伏）
                            gy = max(y + 3, min(y + FLOOR_ROW - 2, gy + rnd.choice([-1, 1])))
                        k += 1
                if rnd.random() < 0.025 and b - a > 40:          # 极少一个小木节
                    kx = rnd.randrange(a + 10, b - 10)
                    ky = y + rnd.randrange(4, FLOOR_ROW - 3)
                    L.p(kx, ky, "hw%d" % (t - 2))
                    L.p(kx + 1, ky, "hw%d" % (t - 1))
                    L.p(kx - 1, ky, "hw%d" % (t - 1))
                if x >= x0:                                      # 两块板头对头的缝 + 右边一线亮
                    L.vl(x, y + 1, y + FLOOR_ROW, "hw2")
                    L.vl(x + 1, y + 2, y + FLOOR_ROW, "hw%d" % min(6, t + 1))
                    joints.append(x)
            x += ln
        prev = joints
        y += FLOOR_ROW
