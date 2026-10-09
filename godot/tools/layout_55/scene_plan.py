# 照现场效果图（947 宽聊天压缩图）量的数，排 55 桌，出两种比例的示意
from PIL import Image, ImageDraw, ImageFont
import sys, os
OUT = sys.argv[1]
# ---- 量出来的（947 宽那张的像素）----
IMG_W = 947
PERSON = 68          # 站着的人
TABLE = (150, 105)   # 桌连一圈椅子
CARPET_W = 62
STAGE = (266, 60)    # 婚礼台宽、进深（台面到台口）
NORTH = 205          # 北墙到第一带桌心
SOUTH = 120          # 最后一带桌心到南墙（图里没画到南头，照北边留门口那块估）
BAND = 103           # 靠红毯那列桌的行距
OFF = (145, 270, 395)   # 三列桌心离红毯中线
LAMP_GAP = 85        # 路引（花柱+灯）间距
N = 55

def layout():
    """每两带一组：靠红毯列 2 张、中间列 1 张（错半带）、靠墙列 2 张 → 每边 5 张，两边 10 张"""
    ts = []
    k = 0
    while len(ts) < N:
        y = NORTH + k * BAND
        for side in (-1, 1):
            for c, dy in ((0, 0), (2, 0)):
                ts.append((IMG_W / 2 + side * OFF[c], y + dy))
            if k % 2 == 0:
                ts.append((IMG_W / 2 + side * OFF[1], y + BAND / 2))
        k += 1
    ts = ts[:N]
    last = max(t[1] for t in ts)
    return ts, last + SOUTH

def draw(scale, name, title, note):
    ts, L = layout()
    W, H = int(IMG_W * scale), int(L * scale)
    im = Image.new("RGB", (W, H), (238, 226, 205))
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", max(14, int(18 * scale / 1.2)))
    except Exception:
        f = ImageFont.load_default()
    s = scale
    cx = W / 2
    d.rectangle([0, 0, W, int(150 * s)], fill=(90, 50, 35))   # 北墙
    d.rectangle([cx - STAGE[0] * s / 2, 120 * s, cx + STAGE[0] * s / 2, (120 + STAGE[1]) * s], fill=(200, 60, 60))
    d.rectangle([cx - CARPET_W * s / 2, (120 + STAGE[1]) * s, cx + CARPET_W * s / 2, H], fill=(170, 30, 40))
    y = NORTH - 20
    while y < L - 40:
        for side in (-1, 1):
            x = cx + side * (CARPET_W / 2 + 14) * s
            d.ellipse([x - 7 * s, y * s - 7 * s, x + 7 * s, y * s + 7 * s], fill=(240, 190, 60))
        y += LAMP_GAP
    for i, (x, y) in enumerate(ts):
        x, y = x * s, y * s
        d.ellipse([x - TABLE[0] * s / 2, y - TABLE[1] * s / 2, x + TABLE[0] * s / 2, y + TABLE[1] * s / 2], fill=(150, 30, 35), outline=(90, 10, 15))
        d.ellipse([x - TABLE[0] * s * 0.3, y - TABLE[1] * s * 0.3, x + TABLE[0] * s * 0.3, y + TABLE[1] * s * 0.3], fill=(230, 200, 190))
        d.text((x - 8 * s, y - 8 * s), str(i + 1), fill=(60, 20, 20), font=f)
    # 人的量尺：站在红毯上
    ph = PERSON * s
    px, py = cx + 60 * s, (NORTH + 3 * BAND) * s
    d.rectangle([px - ph * 0.15, py - ph, px + ph * 0.15, py], fill=(20, 20, 20))
    d.text((px + ph * 0.25, py - ph), "人 %d" % round(ph), fill=(0, 0, 0), font=f)
    # 手机一屏：540×960，1:1，放在台前
    vx, vy = cx - 270, max(0, (NORTH - 60) * s)
    d.rectangle([vx, vy, vx + 540, vy + 960], outline=(0, 120, 255), width=6)
    d.text((vx + 10, vy + 10), "手机一屏 540×960", fill=(0, 90, 220), font=f)
    d.text((10, H - 80), title, fill=(0, 0, 0), font=f)
    d.text((10, H - 50), note % (W, H), fill=(0, 0, 0), font=f)
    im.save(os.path.join(OUT, name))
    return W, H, ts

wa, ha, ts = draw(84 / PERSON, "现场效果图-还原方案-A人84.png", "A：人放到 84（整张 ×1.24）", "厅 %d×%d")
wb, hb, _ = draw(1536 / IMG_W, "现场效果图-还原方案-B不放大.png", "B：照 GPT 原图 1536 宽不缩（×1.62），人约 110", "厅 %d×%d")
print("A", wa, ha, "B", wb, hb, "tables", len(ts), "last band y", max(t[1] for t in ts))
