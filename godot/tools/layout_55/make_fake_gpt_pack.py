#!/usr/bin/env python3
"""假包：照 GPT 造景台 3.0 的交付格式，拿游戏现在用的 B55 那套图冒充 B55S 打一包，给 import_gpt_pack.py 先跑通（01 E 10/2 派）。
**只用来试路，不进游戏、不进 main**（出到哪由参数定，放草稿目录）。

用法：python3 godot/tools/layout_55/make_fake_gpt_pack.py <输出文件夹> [--break size|sha|qa]
  --break 故意做坏一样，看 import_gpt_pack.py 会不会拦：size 桌子大一圈、sha 交了以后改一个文件、qa 没过

格式照的是造景台真产物（.runtime/qa/技术验收产物/001-宴会厅/开席前-v2-20261002/）：
  交付.json（schema qiyuan-delivery/3.0、qa.passed、files 带 sha256）、placement.json（files 里每件 part_id、裁过的 size、anchor、
  source_size、generation.source/crop、桌子带 seats；items 每件 foot = 锚点落在哪）、native/ 整框原图、裁过的零件图、定稿效果图.png。
  锚点、foot、seats 的编号故意照 GPT 那套（桌子锚点在占地中心、椅子 1 号在东边），和我们的不一样，看接的时候会不会被带偏。
内容 = 现在游戏里的图，所以接完重新生成、渲出来应该和现状几乎一样；差多了就是接错了。
"""
import argparse
import hashlib
import json
import math
import os
import shutil

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
ART = os.path.join(HERE, "art")
SHEET = os.path.join(GODOT, "回执", "出图-宴会厅北", "宴会厅北-零件单.json")

# 冒充用：B55S 编号 ← 现在游戏里的图
SRC = {"B55S-T01": "blk_banquet55_table_v2.png", "B55S-T02": "blk_banquet55_table_main_v2.png",
       "B55S-P01": "blk_banquet55_lantern_v2.png", "B55S-P02": "blk_banquet55_flowerstand_v2.png",
       "B55S-P03": "blk_banquet55_flowerpot_v1.png", "B55S-P04": "blk_banquet55_bench_v1.png"}
CODE_OF = {"B55-T01": "B55S-T01", "B55-T02": "B55S-T02", "B55-P01": "B55S-P01", "B55-P02": "B55S-P02",
           "B55-P03": "B55S-P03", "B55-P04": "B55S-P04"}


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def fake_tile(bg):
    """从北边背景最下面那一行砖（y 964～1024，SOUTH_BAND）里切一块砖宽：横向自相关找砖的周期"""
    row = bg.crop((300, 964, 680, 1024)).convert("L")
    px = row.load()
    best = None
    for p in range(60, 110):
        d = sum(abs(px[x, y] - px[x + p, y]) for y in range(0, 60, 3) for x in range(0, row.width - p, 2))
        d /= float(len(range(0, 60, 3)) * len(range(0, row.width - p, 2)))
        if best is None or d < best[0]:
            best = (d, p)
    p = best[1] + (best[1] % 2)
    return bg.crop((400, 964, 400 + p, 1024))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--break", dest="brk", choices=["size", "sha", "qa"])
    a = ap.parse_args()
    out = a.out
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(os.path.join(out, "native"))
    sheet = json.load(open(SHEET, encoding="utf-8"))
    files, items = {}, []

    bg = Image.open(os.path.join(ART, "base_banquet55_north_v2.png")).convert("RGB")
    bg.save(os.path.join(out, "native", "B55S-BG01.png"))
    bg.save(os.path.join(out, "base_B55S-BG01_v1.png"))
    files["base_B55S-BG01_v1.png"] = {"id": "B55S-BG01", "kind": "background", "part_id": "B55S-BG01", "size": [1536, 1024],
                                      "anchor": [0, 0], "footprint": {}, "seats": [], "native_size": True, "source_size": [1536, 1024],
                                      "generation": {"source": "native/B55S-BG01.png", "sha256": sha(os.path.join(out, "native", "B55S-BG01.png")),
                                                     "resized": False, "crop": [0, 0, 1536, 1024]}}
    tile = fake_tile(bg)
    tile.save(os.path.join(out, "tex_B55S-W01_v1.png"))

    final = bg.convert("RGBA")
    frames = []
    for part in sheet["parts"]:
        pid = CODE_OF[part["code"]]
        full = Image.open(os.path.join(ART, SRC[pid])).convert("RGBA")
        if a.brk == "size" and pid == "B55S-T01":
            full = full.resize((198, 165))
        fw, fh = full.size
        bbox = full.getchannel("A").getbbox()
        cropped = full.crop(bbox)
        native = os.path.join(out, "native", pid + ".png")
        full.save(native)
        fname = "blk_%s_v1.png" % pid
        cropped.save(os.path.join(out, fname))
        is_table = pid.startswith("B55S-T")
        # GPT 那套锚点：桌子 = 占地中心（框里 (90, 100)），别的 = 图下沿往上 7 像素的正中
        anchor_full = (90, 100) if is_table else (fw // 2, fh - 7)
        anchor = [anchor_full[0] - bbox[0], anchor_full[1] - bbox[1]]
        entry = {"id": pid, "kind": "table" if is_table else "prop", "part_id": pid, "size": list(cropped.size), "anchor": anchor,
                 "footprint": {"ellipse": [-73, -30, 146, 60]} if is_table else {"rect": [-fw // 2, -8, fw, 8]},
                 "seats": [], "split": "whole", "variations": 0, "variant": 0, "attachments": {}, "native_size": True,
                 "source_size": [fw, fh], "generation": {"source": "native/%s.png" % pid, "sha256": sha(native), "resized": False,
                                                         "crop": list(bbox)}}
        if is_table:
            cx, cy, rx, ry = (90.0, 82.0, 63.0, 50.0) if pid == "B55S-T01" else (90.0, 78.0, 75.0, 57.0)
            for k in range(10):
                # 同一圈椅子（从正北起每 36° 一把），编号照 GPT 那套：1 号是最靠东那把（我们的 4 号），顺时针
                ang = -math.pi / 2 + 2 * math.pi * ((k + 3) % 10) / 10
                sx, sy = cx + math.cos(ang) * rx, cy + math.sin(ang) * ry
                entry["seats"].append({"no": k + 1, "at": [round(sx - anchor_full[0]), round(sy - anchor_full[1])],
                                       "face": "left" if k == 0 else "up"})
        files[fname] = entry
        for inst in part["instances"]:
            x, y = inst["x"], inst["y"]
            items.append({"id": inst["id"], "part": pid, "foot": [x + anchor_full[0], y + anchor_full[1]], "variant": 0,
                          "kind": entry["kind"], "file": fname, "split": "whole", "variations": 0, "scale": 1})
            frames.append((inst["sort_y"], x, y, full))
    for _, x, y, im in sorted(frames, key=lambda f: f[0]):
        final.alpha_composite(im, (x, y))   # 被下沿切的桌子：贴出画布的那截 PIL 自己裁掉
    final.convert("RGB").save(os.path.join(out, "定稿效果图.png"))

    placement = {"schema": "qiyuan-placement/3.0", "scene": "banquet-north-blocks", "image": {"file": "定稿效果图.png", "w": 1536, "h": 1024},
                 "background": "base_B55S-BG01_v1.png", "person_px": 84, "units": "px", "sort": "foot_y",
                 "blocked": {"polygons": [[[0, 0], [1536, 0], [1536, 236], [0, 236]]]}, "files": files, "sheets": {}, "items": items}
    json.dump(placement, open(os.path.join(out, "placement.json"), "w", encoding="utf-8"), ensure_ascii=False)
    json.dump({"parts": [{"id": p, "kind": "x"} for p in sorted(set(CODE_OF.values()))]},
              open(os.path.join(out, "零件单.json"), "w", encoding="utf-8"), ensure_ascii=False)
    listed = []
    for root, _, fs in os.walk(out):
        for f in sorted(fs):
            p = os.path.join(root, f)
            rel = os.path.relpath(p, out)
            listed.append({"file": rel, "bytes": os.path.getsize(p), "sha256": sha(p)})
    delivery = {"schema": "qiyuan-delivery/3.0", "task_id": "fake-02-trial", "scene": "banquet-north-blocks", "revision": 1,
                "status": "02 做的假包，只试路", "placement": "placement.json", "approved_at": "2026-10-02T00:00:00Z",
                "qa": {"passed": a.brk != "qa", "errors": [], "warnings": []}, "files": listed,
                "claude_game_restore": "待 Claude 照 placement 摆进游戏后，用原生 restore_check.py 对一次游戏截图"}
    json.dump(delivery, open(os.path.join(out, "交付.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    if a.brk == "sha":
        Image.open(os.path.join(out, "blk_B55S-P03_v1.png")).rotate(90).save(os.path.join(out, "blk_B55S-P03_v1.png"))
    print("假包：%s（%d 个文件，%d 件摆放，瓦片 %s）%s" % (out, len(listed), len(items), tile.size, " 故意做坏：" + a.brk if a.brk else ""))


if __name__ == "__main__":
    main()
