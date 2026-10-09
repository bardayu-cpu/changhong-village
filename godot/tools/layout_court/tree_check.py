#!/usr/bin/env python3
"""树冠盖不盖站人的地方：每个交互点、出口上站一个人（脚两边各 18、往上 84），树在人前面画（树脚 y 比人大）、树冠框跟人叠上就报。
照「人 = 1」把树改高以后跟着核（10/3）。用法：python3 tree_check.py <layout.json>，有叠的退出码 1"""
import json
import sys

TRUNK = 0.36


def canopy(it):
    ty = float(it["y"])
    if "h" in it:
        h = float(it["h"])
        th = h * TRUNK
        rx = float(it.get("w", h * 0.53)) / 2
        ry = (h - th) / 2
        cy = ty - th - ry
    else:
        r = float(it["r"])
        rx, ry, cy = r, r * 0.85, ty - 46 - r * 0.7
    return [float(it["x"]) - rx, cy - ry, float(it["x"]) + rx, cy + ry]


def check(d):
    bad = []
    for p in d["points"]:
        x, y = float(p["x"]), float(p["y"])
        body = [x - 18, y - 84, x + 18, y]
        for it in d["items"]:
            if it.get("type") != "tree" or float(it["y"]) <= y:
                continue
            c = canopy(it)
            if c[0] < body[2] and body[0] < c[2] and c[1] < body[3] and body[1] < c[3]:
                bad.append((p["id"], it["id"]))
    return bad


if __name__ == "__main__":
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    b = check(d)
    for pid, tid in b:
        print("盖住了：%s 被 %s 的树冠挡" % (pid, tid))
    print("树冠盖人的地方 %d 处" % len(b))
    sys.exit(1 if b else 0)
