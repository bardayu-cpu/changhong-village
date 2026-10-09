#!/usr/bin/env python3
"""宴会厅 55 桌排法草图（方案用，不是正式布局）。01 9/24 派，方案见 回执/宴会厅55桌-方案.md

照「人 = 1」比例尺（ASSETS 第 15 节：左右 1 米 48 像素、前后 1 米 32 像素）排：
  一桌连椅子、坐着的人占 140×92（桌面 1.8 米 = 86 宽，外面一圈椅子和人各 0.55 米）
  桌距 左右 200（桌与桌之间留 1.3 米过道）、前后 150（留 1.8 米，后排人头不压前排）
  红毯 3 米宽（144），两边各再留 1 米
左右各 3 列、10 行 = 60 个位，空 5 个：前排中间 2（新人敬酒下台的地方）、最后一排中间 2（进门）、东墙侧门口 1（服务员进出）
桌号照服务端「数组顺序即桌序」：从前排往后，每排先中间后两边、先左后右；T1、T2 是离舞台最近的两桌（阿鱼、Toretto 的枝）

用法：python3 godot/tools/plan_hall55.py 出图.png [出json.json]
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 1600, 2048
COLS = [210, 410, 610, 990, 1190, 1390]
ROW0, PITCH_Y = 410, 150
RX, RY = 70, 46
SKIP = {(0, 2), (0, 3), (9, 2), (9, 3), (5, 5)}
VIEW = (576, 1024)          # 手机 540×960 竖屏一屏看到的画布（镜头缩放 960/1024）
FONTS = ["/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc"]


def font(n):
    for p in FONTS:
        try:
            return ImageFont.truetype(p, n)
        except OSError:
            pass
    return ImageFont.load_default()


def tables():
    out = []
    for r in range(10):
        row = [c for c in range(6) if (r, c) not in SKIP]
        # 先中间后两边、先左后右
        row.sort(key=lambda c: (abs(COLS[c] - W / 2), COLS[c]))
        for c in row:
            out.append({"id": "T%d" % (len(out) + 1), "x": COLS[c], "y": ROW0 + r * PITCH_Y, "row": r + 1})
    return out


def main():
    out_png = sys.argv[1]
    ts = tables()
    assert len(ts) == 55, len(ts)
    im = Image.new("RGB", (W, H), (239, 227, 207))
    g = ImageDraw.Draw(im, "RGBA")
    f14, f18, f24, f32 = font(14), font(18), font(24), font(32)
    # 地面瓦片格（64）
    for x in range(0, W, 64):
        g.line([(x, 0), (x, H)], fill=(0, 0, 0, 18))
    for y in range(0, H, 64):
        g.line([(0, y), (W, y)], fill=(0, 0, 0, 18))
    # 墙
    g.rectangle([0, 0, W, 170], fill=(92, 52, 36))
    g.rectangle([0, 0, 40, H], fill=(92, 52, 36))
    g.rectangle([W - 40, 0, W, H], fill=(92, 52, 36))
    g.rectangle([0, H - 40, W, H], fill=(92, 52, 36))
    g.text((W / 2, 110), "北墙（喜字、帘幕）", font=f24, fill="white", anchor="mm")
    # 舞台、新人、乐队、贺礼、长凳
    g.rectangle([560, 150, 1040, 300], fill=(200, 60, 55), outline=(120, 20, 20), width=3)
    g.text((800, 200), "婚礼台", font=f24, fill="white", anchor="mm")
    g.ellipse([780, 272, 796, 288], fill="white")
    g.ellipse([804, 272, 820, 288], fill="white")
    g.text((800, 262), "新人", font=f18, fill="white", anchor="mm")
    g.rectangle([1080, 150, 1482, 300], fill=(150, 110, 200, 200), outline=(90, 60, 140), width=2)
    g.text((1281, 225), "乐队（整块舞台图）", font=f18, fill="white", anchor="mm")
    g.rectangle([380, 200, 538, 300], fill=(230, 120, 120, 220))
    g.text((459, 250), "贺礼堆", font=f18, fill="white", anchor="mm")
    g.rectangle([60, 215, 340, 262], fill=(120, 200, 255, 220))
    g.text((200, 238), "长凳（坐满了坐这）", font=f14, fill="black", anchor="mm")
    # 红毯
    g.rectangle([W / 2 - 72, 300, W / 2 + 72, H - 40], fill=(179, 32, 42))
    g.text((W / 2, 1880), "红毯", font=f24, fill="white", anchor="mm")
    # 进门、侧门
    g.rectangle([W / 2 - 90, H - 44, W / 2 + 90, H], fill=(40, 20, 10))
    g.text((W / 2, H - 70), "大门（进厅站这）", font=f18, fill="white", anchor="mm", stroke_width=3, stroke_fill="black")
    side_y = ROW0 + 5 * PITCH_Y
    g.rectangle([W - 44, side_y - 60, W, side_y + 20], fill=(40, 20, 10))
    g.text((W - 60, side_y - 20), "侧门（服务员、去后厅）", font=f18, fill="white", anchor="rm", stroke_width=3, stroke_fill="black")
    # 服务员的路：侧门 → 各列之间的纵向过道
    for x in (310, 510, 1090, 1290, 1490):
        g.line([(x, 330), (x, 1830)], fill=(255, 90, 200, 110), width=4)
    g.line([(1490, side_y - 20), (W - 44, side_y - 20)], fill=(255, 90, 200, 160), width=4)
    # 桌
    for t in ts:
        x, y = t["x"], t["y"]
        vip = t["id"] in ("T1", "T2")
        g.ellipse([x - RX, y - RY, x + RX, y + RY], fill=(90, 50, 25, 255))
        g.ellipse([x - 43, y - 29, x + 43, y + 29], fill=(216, 67, 63) if not vip else (230, 170, 40))
        g.text((x, y), t["id"], font=f18, fill="white", anchor="mm", stroke_width=2, stroke_fill="black")
    # 比例：一个 84 像素的人
    g.rectangle([1500, 1900, 1532, 1984], fill=(30, 30, 30))
    g.text((1516, 1890), "人 84", font=f14, fill="black", anchor="mb")
    # 手机一屏
    vx, vy = 40, 1000
    g.rectangle([vx, vy, vx + VIEW[0], vy + VIEW[1]], outline=(20, 120, 255), width=5)
    g.text((vx + 10, vy + 10), "手机竖屏一屏看到这么大（576×1024）", font=f18, fill=(20, 120, 255), stroke_width=3, stroke_fill="white")
    # GPT 效果图画哪一块
    g.rectangle([32, 0, 32 + 1536, 1024], outline=(0, 170, 90), width=6)
    g.text((52, 985), "GPT 效果图画这一块：1536×1024，1 比 1（舞台、乐队、贺礼、长凳、前 4 排；后面的排都是重复）",
           font=f18, fill=(0, 130, 70), stroke_width=3, stroke_fill="white")
    g.text((W / 2, 50), "画布 1600×2048（约 2.8 屏宽 × 2 屏高）", font=f32, fill="white", anchor="mm")
    im.save(out_png)
    if len(sys.argv) > 2:
        json.dump({"canvas": [W, H], "tables": ts, "footprint": [RX, RY], "pitch": [200, PITCH_Y]},
                  open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("出了", out_png, "桌", len(ts))


if __name__ == "__main__":
    main()
