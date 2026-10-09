#!/usr/bin/env python3
"""restore_check.py 的自测：拿 55 桌厅北边（v2 背景 + scene.json 里摆的零件）拼两张一样的图，
第二张故意改三处——整张挪 (+4, +3)、T1 挪 (+10, +6)、一张谁也不压、谁也不压它的桌放大 15%（脚不动）——看工具找不找得回来。
（10/2 改：原来放大的是主桌；排法 C 以后主桌被第 1 排红毯边的灯压着一角，放大以后被灯盖住的那块对不上，
  匹配差 37.7 超过 30 报「没找到」——是自测的假图跟着排法变了，不是工具坏了。改成自己挑一张周围没东西压着的桌。
  还有一层：10/2 起桌子换成 GPT 的十椅桌（细节多），假图里最近邻放大 15% 跟工具里平滑缩放比，最像那处也差 32.8，
  工具找得对（放大 1.15、脚不动、左右差 1 像素），只是过了默认的 30。自测跑工具时把「没找到」的线放到 40、左右允许差 1）
用法：在 godot/ 里跑 python3 tools/restore_check_selftest.py；最后一行 RESULT PASS 才算过"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
os.chdir(GODOT)
sc = json.load(open("assets/layered/scene_roman_banquet_55/scene.json"))
base = Image.open("tools/layout_55/art/base_banquet55_north_v2.png").convert("RGBA")
occ = sorted([o for o in sc["occluders"] if int(o["y"]) < 1024], key=lambda o: o["foot"])


def comp(mod):
    im = base.copy()
    for o in occ:
        p = Image.open(o["image"].replace("res://", "")).convert("RGBA")
        x, y = int(o["x"]), int(o["y"])
        k = mod.get(o["id"], {})
        if "scale" in k:
            w, h = p.size
            nw, nh = round(w * k["scale"]), round(h * k["scale"])
            p = p.resize((nw, nh), Image.NEAREST)
            x -= (nw - w) // 2
            y -= nh - h
        im.alpha_composite(p, (x + k.get("dx", 0), y + k.get("dy", 0)))
    return im.convert("RGB")


def box_of(o):
    w, h = Image.open(o["image"].replace("res://", "")).size
    return (int(o["x"]), int(o["y"]), w, h)
def overlaps(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]
def lonely(o):
    """放大 15% 以后的框也不碰别的零件（放大往上、往两边长）"""
    x, y, w, h = box_of(o)
    big = (x - round(w * 0.08) - 2, y - round(h * 0.15) - 2, round(w * 1.15) + 4, round(h * 1.15) + 4)
    return all(not overlaps(big, box_of(q)) for q in occ if q is not o)
GROW = next(o["id"] for o in occ if o["id"] != "T1" and "art_table" in o["image"] and lonely(o))
d = tempfile.mkdtemp()
comp({}).save(os.path.join(d, "ref.png"))
g = comp({"T1": {"dx": 10, "dy": 6}, GROW: {"scale": 1.15}})
g2 = Image.new("RGB", g.size)
g2.paste(g, (4, 3))
g2.save(os.path.join(d, "game.png"))
json.dump({"occluders": occ}, open(os.path.join(d, "placement.json"), "w"), ensure_ascii=False)
subprocess.run([sys.executable, os.path.join(HERE, "restore_check.py"), os.path.join(d, "ref.png"), os.path.join(d, "game.png"),
                "--out", os.path.join(d, "out.png"), "--placement", os.path.join(d, "placement.json"), "--placement-frame", "ref", "--match-bad", "40"],
               stdout=subprocess.DEVNULL, check=True)
r = json.load(open(os.path.join(d, "out.json")))
parts = {p["id"]: p for p in r["parts"]}
ok = True


def check(name, cond):
    global ok
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond


check("整张挪回来 (-4, -3)：%s" % [r["align_dx"], r["align_dy"]], (r["align_dx"], r["align_dy"]) == (-4, -3))
t1 = parts["T1"]
check("T1 偏 (+10, +6)：%s" % [t1.get("dx"), t1.get("dy"), t1.get("scale")], (t1.get("dx"), t1.get("dy"), t1.get("scale")) == (10, 6, 1.0))
m = parts[GROW]
check("%s 放大 15%%、脚没动：%s" % (GROW, [m.get("dx"), m.get("dy"), m.get("scale")]), m.get("dx") is not None and abs(m["dx"]) <= 1 and abs(m.get("dy", 99)) <= 1 and abs(m.get("scale", 0) - 1.15) < 0.01)
others = [p for k, p in parts.items() if k not in ("T1", GROW) and p.get("dx") is not None
          and (abs(p["dx"]) > 1 or abs(p["dy"]) > 1 or p["scale"] != 1.0)]
check("别的 %d 件都没报偏（报偏的：%s）" % (len(parts) - 2, [p["id"] for p in others]), not others and all(p.get("dx") is not None for p in parts.values()))
print("RESULT", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
