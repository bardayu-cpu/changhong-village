#!/usr/bin/env python3
"""restore_check.py 的自测：拿 55 桌厅北边（v2 背景 + scene.json 里摆的零件）拼两张一样的图，
第二张故意改三处——整张挪 (+4, +3)、T1 挪 (+10, +6)、主桌放大 15%（脚不动）——看工具找不找得回来。
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


d = tempfile.mkdtemp()
comp({}).save(os.path.join(d, "ref.png"))
g = comp({"T1": {"dx": 10, "dy": 6}, "主桌": {"scale": 1.15}})
g2 = Image.new("RGB", g.size)
g2.paste(g, (4, 3))
g2.save(os.path.join(d, "game.png"))
json.dump({"occluders": occ}, open(os.path.join(d, "placement.json"), "w"), ensure_ascii=False)
subprocess.run([sys.executable, os.path.join(HERE, "restore_check.py"), os.path.join(d, "ref.png"), os.path.join(d, "game.png"),
                "--out", os.path.join(d, "out.png"), "--placement", os.path.join(d, "placement.json"), "--placement-frame", "ref"],
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
m = parts["主桌"]
check("主桌放大 15%%、脚没动：%s" % [m.get("dx"), m.get("dy"), m.get("scale")], m.get("dx") == 0 and abs(m.get("dy", 99)) <= 1 and abs(m.get("scale", 0) - 1.15) < 0.01)
others = [p for k, p in parts.items() if k not in ("T1", "主桌") and p.get("dx") is not None
          and (abs(p["dx"]) > 1 or abs(p["dy"]) > 1 or p["scale"] != 1.0)]
check("别的 %d 件都没报偏（报偏的：%s）" % (len(parts) - 2, [p["id"] for p in others]), not others and all(p.get("dx") is not None for p in parts.values()))
print("RESULT", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
