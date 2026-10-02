#!/usr/bin/env python3
"""接 GPT 造景台交的一包（qiyuan-delivery/3.0），换成 55 桌厅能直接用的零件图（01 E 10/2 派：宴会厅北边·照色块 v1）。

用法：python3 godot/tools/layout_55/import_gpt_pack.py <GPT 交的文件夹> [--art <放哪>] [--dry]
  默认放 godot/tools/layout_55/art/（build_graybox55.py 的 SUQI55_ART=b55s 读这里）；--dry 只查不写。
  出：零件图按零件总表的名字（blk_banquet55s_*_v1.png 等）放进 art/；查了什么、过没过写 godot/回执/接图-宴会厅北/import_b55s.json，
      再跑 tools/check_blocks.py 出一张总览图放同一个文件夹——**最后一定拿眼睛看那张总览图**（02 开场白第三节）。

规矩（为什么这么接）：
  - 位置、大小以 Claude 的色块为准（任务原文「不以你画出来的为准」）：零件按 B55 那套框原样摆，**不用 placement 里 items 的 foot**。
    GPT 的 foot 是它自己的锚点（桌子是占地中心、灯是图里某一点），跟我们的「框左上角 + 图内脚点」不是一套。
  - 每件零件要还原成整框大小的图（桌 180×150 这种）：有 native/ 原图且大小对就用它；没有就拿裁过的图 + generation.crop 贴回整框。
    两样都对不上零件单的大小 → 不接，报出来（任务原文「零件的尺寸必须跟零件单一样」）。
  - 交付.json 里写了 sha256 的逐个核；qa.passed 不是 true 不接。
  - 桌子：GPT 给的 seats（椅子位置）跟游戏里人坐的椅子圈比，报最大偏多少像素（椅子挪了人就坐空）。编号两边不一样，按最近的一把比。
"""
import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))

# 零件总表 B55S 那几行（docs/零件总表.md，418154c）：编号 → 整框大小、存成什么名字、哪种图
PARTS = {
    "B55S-BG01": {"size": (1536, 1024), "out": "base_banquet55_scene_v1.png", "kind": "background"},
    "B55S-T01": {"size": (180, 150), "out": "blk_banquet55s_table_v1.png", "kind": "table"},
    "B55S-T02": {"size": (180, 150), "out": "blk_banquet55s_table_main_v1.png", "kind": "table"},
    "B55S-P01": {"size": (48, 112), "out": "blk_banquet55s_aisle_post_v1.png", "kind": "prop"},
    "B55S-P02": {"size": (56, 112), "out": "blk_banquet55s_flowerstand_v1.png", "kind": "prop"},
    "B55S-P03": {"size": (32, 32), "out": "blk_banquet55s_flowerpot_v1.png", "kind": "prop"},
    "B55S-P04": {"size": (72, 54), "out": "blk_banquet55s_bench_v1.png", "kind": "prop"},
    "B55S-W01": {"size": None, "out": "tex_banquet55s_floor_v1.png", "kind": "tile"},   # 瓦片：大小不定，要双数、不透明
    # 中间那截两边的竖墙（01 E 10/2：北边新背景墙画直了，中间墙跟着换；零件总表 0497340）：40×240，上下接得上
    "B55S-W02": {"size": (40, 240), "out": "tex_banquet55s_wall_west_v1.png", "kind": "walltile"},
    "B55S-W03": {"size": (40, 240), "out": "tex_banquet55s_wall_east_v1.png", "kind": "walltile"},
}
# 游戏里人坐的椅子圈（build_graybox55.py 的 SEAT_TABLE、SEAT_MAIN；圈心 = 占地中心 + dy，占地中心在框里 (90, 100)）
SEAT_RING = {"B55S-T01": (90.0, 100.0 - 18.0, 63.0, 50.0), "B55S-T02": (90.0, 100.0 - 22.0, 75.0, 57.0)}
SEAT_TOL = 6.0       # 椅子偏多少像素以内算没挪（人 84 高，偏 6 像素坐上去看不出来）


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def part_id_of(fname, entry):
    pid = entry.get("part_id") or entry.get("id") or ""
    m = re.search(r"B55S-[A-Z]+\d+", pid) or re.search(r"B55S-[A-Z]+\d+", fname)
    return m.group(0) if m else ""


def full_frame(pack, fname, entry, want):
    """还原成整框大小的图。回 (图, 从哪来的, 错误)"""
    gen = entry.get("generation") or {}
    src = gen.get("source")
    if src and os.path.exists(os.path.join(pack, src)):
        im = Image.open(os.path.join(pack, src))
        if want is None or im.size == tuple(want):
            return im, src, ""
    path = os.path.join(pack, fname)
    if not os.path.exists(path):
        return None, "", "交付里没有这个文件：" + fname
    im = Image.open(path)
    if want is None or im.size == tuple(want):
        return im, fname, ""
    crop = gen.get("crop")
    ssize = entry.get("source_size")
    if crop and ssize and tuple(ssize) == tuple(want) and (crop[2] - crop[0], crop[3] - crop[1]) == im.size:
        canvas = Image.new("RGBA", tuple(want), (0, 0, 0, 0))
        canvas.paste(im.convert("RGBA"), (crop[0], crop[1]))
        return canvas, "%s 贴回整框 crop %s" % (fname, crop), ""
    return None, "", "大小对不上：要 %s，交的是 %s（原图 %s）" % (list(want), list(im.size), ssize)


def alpha_report(im):
    """透明度：硬边（0/255 以外的像素占几成）、不透明的东西离框四边多远（「画满框」）"""
    a = im.convert("RGBA").getchannel("A")
    hist = a.histogram()
    n = im.width * im.height
    semi = n - hist[0] - hist[255]
    bbox = a.getbbox()
    margin = [bbox[0], bbox[1], im.width - bbox[2], im.height - bbox[3]] if bbox else None
    return {"semi_ratio": round(semi / float(n), 4), "opaque_ratio": round(hist[255] / float(n), 3), "margin_lrtb": margin}


def seat_check(pid, entry, crop_xy):
    seats = entry.get("seats") or []
    if pid not in SEAT_RING:
        return None
    if not seats:
        return {"ok": False, "why": "placement 里这张桌没写 seats，没法核椅子位置（要拿眼睛对现状图）"}
    ax, ay = entry.get("anchor", [0, 0])
    ox, oy = crop_xy
    theirs = [(ax + ox + s["at"][0], ay + oy + s["at"][1]) for s in seats]
    cx, cy, rx, ry = SEAT_RING[pid]
    ours = []
    for k in range(10):
        a = -math.pi / 2 + 2 * math.pi * k / 10
        ours.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry))
    worst = 0.0
    for p in ours:
        worst = max(worst, min(math.hypot(p[0] - q[0], p[1] - q[1]) for q in theirs))
    return {"ok": len(seats) == 10 and worst <= SEAT_TOL, "count": len(seats), "worst_px": round(worst, 1), "tol_px": SEAT_TOL}


def tile_report(im):
    """瓦片：不透明、双数、左右上下接得上（对边那一列/行的差，跟图里相邻两列/行的差比）"""
    rgb = im.convert("RGB")
    px = rgb.load()
    w, h = rgb.size
    def col_d(x0, x1):
        return sum(sum(abs(px[x0, y][k] - px[x1, y][k]) for k in range(3)) for y in range(h)) / float(h * 3)
    def row_d(y0, y1):
        return sum(sum(abs(px[x, y0][k] - px[x, y1][k]) for k in range(3)) for x in range(w)) / float(w * 3)
    inner_c = sum(col_d(x, x + 1) for x in range(w - 1)) / float(w - 1)
    inner_r = sum(row_d(y, y + 1) for y in range(h - 1)) / float(h - 1)
    alpha_ok = im.mode != "RGBA" or im.getchannel("A").getextrema() == (255, 255)
    return {"size": [w, h], "even": w % 2 == 0 and h % 2 == 0, "opaque": alpha_ok,
            "wrap_lr": round(col_d(w - 1, 0), 1), "wrap_tb": round(row_d(h - 1, 0), 1),
            "inner_col": round(inner_c, 1), "inner_row": round(inner_r, 1)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack")
    ap.add_argument("--art", default=os.path.join(HERE, "art"))
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--report", default=os.path.join(GODOT, "回执", "接图-宴会厅北"))
    a = ap.parse_args()
    pack = a.pack
    errors, warns = [], []
    rep = {"pack": os.path.abspath(pack), "parts": {}}

    dpath = os.path.join(pack, "交付.json")
    if not os.path.exists(dpath):
        sys.exit("没有 交付.json：照规矩还不算交，不接")
    d = json.load(open(dpath, encoding="utf-8"))
    rep["delivery"] = {k: d.get(k) for k in ("schema", "scene", "revision", "status", "approved_at")}
    if d.get("schema") != "qiyuan-delivery/3.0":
        warns.append("交付.json 的 schema 是 %r，不是 qiyuan-delivery/3.0（照 3.0 读）" % d.get("schema"))
    if not (d.get("qa") or {}).get("passed"):
        errors.append("交付.json 里 qa.passed 不是 true")
    for f in d.get("files") or []:
        p = os.path.join(pack, f["file"])
        if not os.path.exists(p):
            errors.append("交付.json 列了但文件不在：" + f["file"])
        elif f.get("sha256") and sha(p) != f["sha256"]:
            errors.append("sha256 对不上（交了以后又被改过？）：" + f["file"])

    ppath = os.path.join(pack, d.get("placement") or "placement.json")
    pl = json.load(open(ppath, encoding="utf-8"))
    rep["placement_image"] = pl.get("image")
    found = {}
    for fname, entry in (pl.get("files") or {}).items():
        pid = part_id_of(fname, entry)
        if pid in PARTS:
            found[pid] = (fname, entry)
        elif pid:
            warns.append("零件单外的编号，不接：%s（%s）" % (pid, fname))
    # 地砖、竖墙瓦片可能不在 placement 的 files 里（它们不摆，只铺）：按文件名找
    for wid in ("B55S-W01", "B55S-W02", "B55S-W03"):
        if wid not in found:
            for fn in sorted(os.listdir(pack)):
                if wid in fn and fn.endswith(".png"):
                    found[wid] = (fn, {})
    for pid, spec in PARTS.items():
        if pid not in found:
            errors.append("没交：%s（要存成 %s）" % (pid, spec["out"]))
            continue
        fname, entry = found[pid]
        im, came, err = full_frame(pack, fname, entry, spec["size"])
        r = {"file": fname, "from": came, "out": spec["out"]}
        if err:
            errors.append("%s：%s" % (pid, err))
            rep["parts"][pid] = dict(r, error=err)
            continue
        r["size"] = list(im.size)
        if spec["kind"] == "background":
            if im.mode == "RGBA" and im.getchannel("A").getextrema()[0] < 255:
                errors.append("%s 背景有透明的地方" % pid)
            im = im.convert("RGB")
        elif spec["kind"] == "walltile":
            t = tile_report(im)
            r["tile"] = t
            if not t["opaque"]:
                warns.append("%s 竖墙有透明的地方（40 宽整条都是墙，应该不透明）" % pid)
            if t["wrap_tb"] > max(12.0, t["inner_row"] * 3):
                warns.append("%s 上下接不上（上沿和下沿差 %.1f，图里相邻两行差 %.1f）" % (pid, t["wrap_tb"], t["inner_row"]))
            im = im.convert("RGB")
        elif spec["kind"] == "tile":
            t = tile_report(im)
            r["tile"] = t
            if not (t["even"] and t["opaque"]):
                errors.append("%s 瓦片要双数大小、不透明：%s" % (pid, t))
            for k, inner in (("wrap_lr", "inner_col"), ("wrap_tb", "inner_row")):
                if t[k] > max(12.0, t[inner] * 3):
                    warns.append("%s 对边接不上（%s 差 %.1f，图里相邻差 %.1f）" % (pid, k, t[k], t[inner]))
            im = im.convert("RGB")
        else:
            im = im.convert("RGBA")
            ar = alpha_report(im)
            r["alpha"] = ar
            if ar["semi_ratio"] > 0.002:
                errors.append("%s 半透明像素占 %.2f%%（零件要硬边 0/255）" % (pid, ar["semi_ratio"] * 100))
            if ar["margin_lrtb"] and max(ar["margin_lrtb"][0], ar["margin_lrtb"][2]) > 8:
                warns.append("%s 左右没画满框（离边 %s 像素；任务要「左右留几像素就够」）" % (pid, ar["margin_lrtb"][:3:2]))
            # anchor、seats 是对着裁过的那张图（files 里那个文件）说的；整框坐标 = 加上裁的起点，跟这次用的是 native 还是裁图无关
            crop = (entry.get("generation") or {}).get("crop") or [0, 0]
            sc = seat_check(pid, entry, (crop[0], crop[1]))
            if sc is not None:
                r["seats"] = sc
                if not sc["ok"]:
                    warns.append("%s 椅子位置跟游戏里人坐的圈差 %s 像素（容差 %s）：%s" % (
                        pid, sc.get("worst_px"), SEAT_TOL, sc.get("why", "%d 把" % sc.get("count", 0))))
        rep["parts"][pid] = r
        if not a.dry and not errors:
            os.makedirs(a.art, exist_ok=True)
            im.save(os.path.join(a.art, spec["out"]))

    rep["errors"], rep["warnings"] = errors, warns
    rep["ok"] = not errors
    if not a.dry and not errors:
        os.makedirs(a.report, exist_ok=True)
        parts_dir = tempfile.mkdtemp(prefix="b55s_parts_")
        for pid, spec in PARTS.items():
            if spec["kind"] in ("table", "prop"):
                Image.open(os.path.join(a.art, spec["out"])).save(os.path.join(parts_dir, spec["out"]))
        sheet = os.path.join(a.report, "零件总览-check_blocks.png")
        subprocess.run([sys.executable, os.path.join(GODOT, "tools", "check_blocks.py"), parts_dir, sheet])
        rep["check_blocks"] = sheet
        json.dump(rep, open(os.path.join(a.report, "import_b55s.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps(rep, ensure_ascii=False, indent=1))
    print("结论：%s（错 %d、提醒 %d）" % ("能接" if not errors else "不接", len(errors), len(warns)))
    sys.exit(0 if not errors else 1)


if __name__ == "__main__":
    main()
