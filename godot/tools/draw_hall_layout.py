#!/usr/bin/env python3
"""宴会厅摆位图：把 export_hall_layout.gd 导出的坐标标到底图上，每样东西给编号，并把编号写回 json（图和 json 对得上）。

01 9/24 派：GPT 照游戏能还原的尺寸和位置画宴会厅效果图，拆下来要能原样放回游戏，所以要底图 + 每样东西的坐标。
坐标全是游戏里跑出来的（不在这里排），这里只加编号、画图。

用法：
  Godot --headless --path godot --script res://tools/export_hall_layout.gd -- --out=摆位-原始.json
  python3 godot/tools/draw_hall_layout.py 摆位-原始.json 底图.png 出图.png 出json.json
出图：上面 1536×1024 就是画布（左上角 0,0，坐标一一对上），下面加一条图例
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

FONTS = ["/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc",
         "/System/Library/Fonts/Hiragino Sans GB.ttc", "/Library/Fonts/Arial Unicode.ttf"]


def font(size):
    for p in FONTS:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


C = {
    "table": (255, 255, 255), "seat": (80, 220, 255), "seat_npc": (80, 220, 255), "rug": (255, 210, 60),
    "book": (120, 255, 120), "dish": (255, 140, 40), "spot": (255, 90, 200), "lamp": (255, 240, 120),
    "pot": (140, 255, 160), "gift": (255, 120, 120), "couple": (255, 255, 255), "band": (200, 160, 255),
    "path": (255, 90, 200), "bench": (120, 200, 255), "rail": (190, 190, 190), "spawn": (255, 255, 255),
}
LEGEND_H = 150


def main():
    src, base, out_png, out_json = sys.argv[1:5]
    d = json.load(open(src, encoding="utf-8"))
    bg = Image.open(base).convert("RGB")
    W, H = bg.size
    # 底图压暗一点，标记才看得清
    dim = Image.blend(bg, Image.new("RGB", bg.size, (0, 0, 0)), 0.35)
    im = Image.new("RGB", (W, H + LEGEND_H), (30, 26, 24))
    im.paste(dim, (0, 0))
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(ov)
    f10, f12, f14, f18, f22 = font(10), font(12), font(14), font(18), font(22)

    def label(xy, text, col, fnt=f14, anchor="mm"):
        x, y = xy
        g.text((x, y), text, font=fnt, fill=col + (255,), anchor=anchor, stroke_width=3, stroke_fill=(0, 0, 0, 255))

    def box(r, col, w=2, a=255):
        g.rectangle([r[0], r[1], r[2], r[3]], outline=col + (a,), width=w)

    def dot(p, col, r=4, fill=True):
        x, y = p
        g.ellipse([x - r, y - r, x + r, y + r], fill=(col + (255,)) if fill else None, outline=(0, 0, 0, 255) if fill else col + (255,), width=1 if fill else 2)

    # 服务员的路（最底下画）
    sv = d["服务员"]
    sv["编号"] = "服门"
    for i, pth in enumerate(sv["去各桌的路（从门出发，拐点）"]):
        pth["编号"] = "路-%s" % pth["去"]
        pts = [tuple(p) for p in pth["路"]]
        g.line(pts, fill=C["path"] + (110,), width=2)

    for t in d["桌"]:
        tid = t["id"]
        r = t["地毯"]["框"]
        t["地毯"]["编号"] = tid + "-毯"
        box(r, C["rug"], 1, 170)
        t["桌子编号"] = tid
        box(t["桌子积木框"], C["table"], 1, 120)
        cx, cy = t["桌心"]
        # 桌号写在地毯框左上角外面，不压座位号
        label((r[0] + 4, r[1] - 12), tid, C["table"], f22, "lm")
        t["簿子"]["编号"] = tid + "-簿"
        box(t["簿子"]["框"], C["book"], 2)
        for k, dp in enumerate(t["上菜"]):
            letter = "abcd"[k]
            dp["菜编号"] = "%s-菜%s" % (tid, letter)
            dp["站点编号"] = "%s-站%s" % (tid, letter)
            dot(dp["菜放在"], C["dish"], 3)
            dot(dp["服务员站的点"], C["spot"], 4, fill=False)
        for s in t["座位"]:
            s["编号"] = "%s-%d" % (tid, s["号"])
            fx, fy = s["脚点"]
            dot((fx, fy), C["seat"], 3)
            # 座位号写在脚点外侧一点，避开桌心
            ox, oy = fx - cx, fy - cy
            n = max((ox * ox + oy * oy) ** 0.5, 1)
            label((fx + ox / n * 11, fy + oy / n * 9), str(s["号"]), C["seat"], f10)

    for i, it in enumerate(d["落地灯"], 1):
        it["编号"] = "灯%d" % i
        box(it["框"], C["lamp"], 1)
        dot(it["着地点"], C["lamp"], 3)
        label((it["框"][2] + 4, it["框"][1] + 8), it["编号"], C["lamp"], f14, "lm")
    for i, it in enumerate(d["花盆"], 1):
        it["编号"] = "花%d" % i
        box(it["框"], C["pot"], 1)
        dot(it["着地点"], C["pot"], 3)
        label((it["框"][0] - 4, it["框"][1] + 8), it["编号"], C["pot"], f14, "rm")
    for i, it in enumerate(d["前景栏杆"], 1):
        it["编号"] = "栏%d" % i
        box(it["框"], C["rail"], 1, 150)
        label(((it["框"][0] + it["框"][2]) / 2, it["框"][3] - 16), it["编号"], C["rail"], f18)

    gp = d["贺礼堆"]
    gp["编号"] = "礼"
    box(gp["框"], C["gift"], 2)
    dot(gp["着地点"], C["gift"], 4)
    label(((gp["框"][0] + gp["框"][2]) / 2, gp["框"][1] + 14), "礼", C["gift"], f18)

    cp = d["新人"]
    cp["编号"] = "新人"
    box(cp["合照立绘框"], C["couple"], 2)
    dot(cp["两人中间的脚点"], C["couple"], 5)
    label(((cp["合照立绘框"][0] + cp["合照立绘框"][2]) / 2, cp["合照立绘框"][1] - 10), "新人", C["couple"], f18)

    band = d["乐队"]
    band["编号"] = "乐台"
    box(band["舞台框"], C["band"], 1, 170)
    label((band["舞台框"][0] + 6, band["舞台框"][1] + 10), "乐台", C["band"], f14, "lm")
    for i, mu in enumerate(band["四个人"], 1):
        mu["编号"] = "乐%d" % i
        box(mu["人所在框"], C["band"], 1, 200)
        dot(mu["脚点"], C["band"], 4)
        label((mu["脚点"][0], mu["脚点"][1] + 12), mu["编号"], C["band"], f14)

    dot(sv["进出的门（脚点）"], C["path"], 6)
    label((sv["进出的门（脚点）"][0] - 8, sv["进出的门（脚点）"][1] - 16), "服门", C["path"], f18, "rm")

    b = d["长凳"]
    b["编号"] = "凳"
    box(b["框"], C["bench"], 2)
    label((b["框"][0] + 4, b["框"][1] - 10), "凳", C["bench"], f18, "lm")
    for s in b["坐的位（8 个人时）"]:
        s["编号"] = "凳%d" % s["号"]
        dot(s["脚点"], C["bench"], 3)
        label((s["脚点"][0], s["脚点"][1] + 9), str(s["号"]), C["bench"], f10)

    d["玩家进厅站的点编号"] = "进"
    sp = d["玩家进厅站的点"]
    dot(sp, C["spawn"], 5, fill=False)
    label((sp[0], sp[1] + 18), "进（玩家进厅站这）", C["spawn"], f14)

    # 图例
    y0 = H + 12
    items = [
        ("T1～T12", "桌号（写在地毯框左上角）；白细框＝桌子积木", C["table"]),
        ("T1-1～10", "座位脚点（蓝点，小字是椅子号，1 号在桌子正后方、顺时针）", C["seat"]),
        ("T1-毯", "桌下地毯范围（黄框）", C["rug"]),
        ("T1-簿", "桌心簿子（绿小框）", C["book"]),
        ("T1-菜a～d", "新上的菜放的点（橙点）", C["dish"]),
        ("T1-站a～d", "服务员放菜时站的脚点（粉圈）；粉线＝服务员从「服门」去各桌的路", C["spot"]),
        ("灯1～7 / 花1～5", "红毯两边和墙边的落地灯、花盆（框＝积木，点＝着地点）", C["lamp"]),
        ("礼 / 新人 / 乐1～4 / 凳1～8", "贺礼堆、新人（两人中间的脚点）、乐队四人脚点、长凳 8 个位", C["gift"]),
    ]
    for i, (k, txt, col) in enumerate(items):
        x = 16 + (i // 4) * 770
        y = y0 + (i % 4) * 32
        g.rectangle([x, y + 4, x + 14, y + 18], fill=col + (255,))
        g.text((x + 22, y), k, font=f18, fill=col + (255,))
        g.text((x + 22 + g.textlength(k, font=f18) + 10, y + 2), txt, font=f14, fill=(230, 230, 230, 255))
    g.text((W - 16, H + LEGEND_H - 10), "坐标＝1536×1024 画布像素，左上角 0,0；人按脚点。坐标全从游戏里导出（tools/export_hall_layout.gd）",
           font=f12, fill=(180, 180, 180, 255), anchor="rs")

    im = Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")
    im.save(out_png)
    json.dump(d, open(out_json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("出了", out_png, out_json)


if __name__ == "__main__":
    main()
