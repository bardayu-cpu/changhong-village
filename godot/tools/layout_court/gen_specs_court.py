#!/usr/bin/env python3
"""迎宾院零件尺寸（01 E 10/3：迎宾院也当唯一源，跟 55 桌厅的 layout_55/gen_specs.py 一套做法）。
唯一源是 assets/layered/scene_luoman_entrance/layout.json：游戏照它画灰盒（scripts/entrance.gd），这里照它出两样：
  ① 尺寸表 回执/零件规格/迎宾院/迎宾院-尺寸表.md：每件东西画多大、对 ASSETS §15「人 = 1」表哪一行、是表的几倍、合不合格
  ② 框 回执/零件规格/迎宾院/迎宾院-框.json：每件东西在画布上画出来的外框（连高度），以后给 GPT 出迎宾院色块就照它
改尺寸只改 layout.json，再跑这个。

layout.json 每件东西的 scale 写它对哪一行：
  w / d / h = scale_check.py STANDARD 的 key（宽、地面前后、高）；w_m / d_m / h_m = 真实多大（米），表里没有的东西用这个
  gap + gap_to = 跟另一件之间的空（大门门洞宽 = 东柱左边 - 西柱右边）
换算照 ASSETS §15：左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素，人 84。超过表的 1.5 倍、不足一半算红（scale_check 一样的线）。

用法：python3 godot/tools/layout_court/gen_specs_court.py [--scene entrance|backhall|lawn|lake|orchard]   生成那一块的两样（默认迎宾院）；有红项退出码 1
      python3 godot/tools/layout_court/gen_specs_court.py --all [--check]   五块都来
      python3 godot/tools/layout_court/gen_specs_court.py --check    只核：跟仓库里的比，变了或有红项退出码 1
      python3 godot/tools/layout_court/gen_specs_court.py --layout 别的.json --out 目录   量别的版本（回执里对比改前用）
"""
import importlib.util
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
# 场景 → (layout.json, 出到 回执/零件规格/<中文名>/)。10/3 起后厅、草坪、湖边、果园也照这套（01 E）
SCENES = {
    "entrance": ("scene_luoman_entrance", "迎宾院"),
    "backhall": ("scene_luoman_backhall", "后厅"),
    "lawn": ("scene_luoman_lawn", "草坪"),
    "lake": ("scene_luoman_lake", "湖边"),
    "orchard": ("scene_luoman_orchard", "果园"),
    "parking": ("scene_luoman_parking", "停车场"),   # 10/3 停车场和大门灰盒（01 F）
    "plaza": ("scene_luoman_plaza", "喷泉广场"),     # 10/4 喷泉广场灰盒（新总图第 ② 步，01 F）
}


def scene_paths(name):
    folder, cn = SCENES[name]
    return os.path.join(GODOT, "assets", "layered", folder, "layout.json"), os.path.join(GODOT, "回执", "零件规格", cn), cn


LAYOUT, OUT, _ = scene_paths("entrance")
PX_M = 48.0      # 左右、高 1 米
PX_M_D = 32.0    # 地面前后 1 米
PERSON = 84.0
TREE_TRUNK = 0.36   # 跟 entrance.gd 的 TREE_TRUNK 一样
TRIPOD = (28.0, 78.0)   # entrance.gd 画三脚架：宽 28、高 78

NAMES = {
    "sign_table": "签到桌", "flower_wall": "花墙", "album_stand": "回忆册台", "album_book_cover": "回忆册（翻开的书）",
    "blessing_board": "祝福牌", "print_desk": "打印台", "camera_w": "相机三脚架（西）", "camera_e": "相机三脚架（东）",
    "gate_post_w": "大门门柱", "gate_roof": "大门门楼", "wall_s_w": "南墙（西段）", "wall_s_e": "南墙（东段）",
    "flower_box_w": "花箱（西）", "flower_box_e": "花箱（东）",
    # 后厅
    "vanity": "化妆台", "rack_post_w": "礼服架", "sofa": "沙发", "tea_table": "茶几", "luggage_1": "行李箱（大）", "luggage_2": "行李箱（小）",
    "mahjong_table": "麻将桌", "counter_w": "灶台（西）", "counter_e": "灶台（东）", "brick_stove": "砖灶", "pot": "大锅", "board": "案板", "bowl_table": "碗桌",
    "wall_1": "隔墙", "front_1": "前沿矮墙",
    # 草坪
    "arch_post_w": "花拱门", "swing_post_w": "秋千", "slide_tower": "滑梯",
    # 湖边
    "pavilion_roof": "亭子", "bench_seat": "长凳",
    # 果园
    "shop_stall": "山庄收购处",
    # 停车场
    "wall_w": "院墙", "gate_post_w": "门楼门柱", "arch_post_w": "气球拱门",
}
GROUPS = (("tea_", "茶桌"), ("stool_", "凳子"), ("lantern_", "落地宫灯"), ("tree_", "树"), ("willow_", "柳树"), ("loquat_", "枇杷树"),
          ("chair_", "白椅子"), ("ridge_", "草莓垄"), ("wall_", "隔墙"), ("front_", "前沿矮墙"))


def load_std():
    spec = importlib.util.spec_from_file_location("scale_check", os.path.join(GODOT, "tools", "scale_check.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m.STANDARD


def res_path(p):
    return os.path.join(GODOT, p[len("res://"):]) if p.startswith("res://") else p


def png_bbox(path):
    from PIL import Image
    im = Image.open(res_path(path)).convert("RGBA")
    return im.getchannel("A").getbbox() or (0, 0, im.width, im.height)


def measure(it):
    """一件东西画出来的外框（画布坐标，连高度）和宽、前后、高（像素），跟 entrance.gd 的 _item 一个算法。
    写了 art_box 的（代码画的成品，比灰盒大一圈，10/3 果园起）：外框照画出来的，宽、前后、高照旧按灰盒量"""
    box, dims = _measure(it)
    if box is not None and "art_box" in it:
        box = [float(v) for v in it["art_box"]]
    return box, dims


def _measure(it):
    k = it.get("type")
    if k == "box":
        x0, y0, x1, y1 = [float(v) for v in it["rect"]]
        h = float(it["h"])
        box = [x0, y0 - h, x1, y1]
        for dd in it.get("deco", []):
            r = dd["rect"]
            box = [min(box[0], r[0]), min(box[1], r[1]), max(box[2], r[2]), max(box[3], r[3])]
        return box, {"w": x1 - x0, "d": y1 - y0, "h": h}
    if k == "cyl":
        cx, cy, rx, ry, h = [float(it[q]) for q in ("x", "y", "rx", "ry", "h")]
        return [cx - rx, cy - h - ry, cx + rx, cy + ry], {"w": 2 * rx, "d": 2 * ry, "h": h}
    if k == "tree":
        tx, ty = float(it["x"]), float(it["y"])
        if "h" in it:
            h = float(it["h"])
            crx = float(it.get("w", h * 0.53)) / 2
            return [tx - crx, ty - h, tx + crx, ty], {"w": 2 * crx, "h": h}
        r = float(it["r"])
        h = 46 + 1.55 * r
        return [tx - r, ty - h, tx + r, ty], {"w": 2 * r, "h": h}
    if k == "tripod":
        px, py = float(it["x"]), float(it["y"])
        return [px - TRIPOD[0] / 2, py - TRIPOD[1], px + TRIPOD[0] / 2, py], {"w": TRIPOD[0], "h": TRIPOD[1]}
    if k == "image":
        b = png_bbox(it["path"])
        ox, oy = float(it["x"]) - float(it["anchor"][0]), float(it["y"]) - float(it["anchor"][1])
        return [ox + b[0], oy + b[1], ox + b[2], oy + b[3]], {"w": float(b[2] - b[0]), "h": float(b[3] - b[1])}
    if k == "beam":
        return [float(it["x0"]), float(it["top"]), float(it["x1"]), float(it["top"]) + float(it["thick"])], {"w": float(it["x1"]) - float(it["x0"])}
    if k == "poly":
        xs = [float(v[0]) for v in it["pts"]]
        ys = [float(v[1]) for v in it["pts"]]
        return [min(xs), min(ys), max(xs), max(ys)], {"w": max(xs) - min(xs), "h": max(ys) - min(ys)}
    return None, {}


def judge(val, lo, hi):
    """表是 lo～hi：落在里面算 1 倍；大了比 hi、小了比 lo。超过 1.5 倍、不足一半算红"""
    if val > hi:
        r = val / hi
    elif val < lo:
        r = val / lo
    else:
        r = 1.0
    return r, ("红" if r > 1.5 or r < 0.5 else "过")


def build(layout_path):
    std = load_std()
    with open(layout_path, encoding="utf-8") as f:
        d = json.load(f)
    items = {it["id"]: it for it in d["items"] if "id" in it}
    boxes, rows = [], []
    measured = {}
    for it in d["items"]:
        box, dims = measure(it)
        if box is None:
            continue
        measured[it["id"]] = (box, dims)
        boxes.append({"id": it["id"], "type": it["type"], "box": [round(v, 1) for v in box],
                      "dims": {q: round(v, 1) for q, v in dims.items()}})
    for it in d["items"]:
        if it.get("id") not in measured:
            continue
        box, dims = measured[it["id"]]
        sc = it.get("scale")
        if not sc:
            continue
        name = sc.get("name") or NAMES.get(it["id"], it["id"])
        if "group" in sc:
            # 几件拼成一样东西（亭子 = 顶 + 四根柱子）：量它们合起来的外框
            gb = [measured[g][0] for g in sc["group"] if g in measured] + [box]
            ub = [min(b[0] for b in gb), min(b[1] for b in gb), max(b[2] for b in gb), max(b[3] for b in gb)]
            dims = {"w": ub[2] - ub[0], "h": ub[3] - ub[1]}
        for dim, label in (("w", "宽"), ("d", "前后"), ("h", "高")):
            if dim in sc:
                key = sc[dim]
                if key not in std:
                    raise SystemExit("%s 的 scale.%s 写的 %s 不在 scale_check STANDARD 里" % (it["id"], dim, key))
                if dim not in dims:
                    raise SystemExit("%s 量不出 %s" % (it["id"], label))
                lo, hi = std[key][1], std[key][2]
                rows.append((name, label, dims[dim], "%s（%s）" % (std[key][0], lo if lo == hi else "%s～%s" % (lo, hi)), lo, hi))
            if dim + "_m" in sc:
                m = float(sc[dim + "_m"])
                px = m * (PX_M_D if dim == "d" else PX_M)
                rows.append((name, label, dims[dim], "真实 %s 米 → %.0f" % (m, px), px, px))
        if "gap" in sc:
            other = items[sc["gap_to"]]
            gap = float(other["rect"][0]) - float(it["rect"][2])
            key = sc["gap"]
            lo, hi = std[key][1], std[key][2]
            rows.append(("大门门洞", "宽", gap, "%s（%s）" % (std[key][0], lo), lo, hi))
    # 同名同尺寸的合成一行（三张茶桌、五个凳子、六盏宫灯、四棵树）
    merged = {}
    order = []
    for name, label, val, ref, lo, hi in rows:
        for pre, nm in GROUPS:
            if name.startswith(pre):
                base = nm
                break
        else:
            base = name
        key = (base, label, val, ref)
        if key not in merged:
            merged[key] = [base, label, val, ref, lo, hi, 0]
            order.append(key)
        merged[key][6] += 1
    table = []
    for key in order:
        base, label, val, ref, lo, hi, n = merged[key]
        r, ok = judge(val, lo, hi)
        table.append({"name": base + ("（%d 件）" % n if n > 1 else ""), "dim": label, "px": round(val, 1),
                      "persons": round(val / PERSON, 2), "ref": ref, "ratio": round(r, 2), "ok": ok})
    return d, boxes, table


def render_md(table, layout_rel, cn="迎宾院"):
    out = ["# %s零件尺寸（照「人 = 1」，ASSETS §15）" % cn, "",
           "> 自动生成，别手改：改 `%s` 再跑 `python3 godot/tools/layout_court/gen_specs_court.py`。" % layout_rel,
           "> 换算：左右和高 1 米 = 48 像素，地面前后 1 米 = 32 像素，人 84 像素。倍数：落在表的范围里算 1；超过 1.5 倍、不足一半算红。", "",
           "| 东西 | 量哪 | 画多大（像素） | 约几个人 | 对表 | 几倍 | 结果 |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for t in table:
        out.append("| %s | %s | %g | %.2f | %s | %.2f | %s |" % (t["name"], t["dim"], t["px"], t["persons"], t["ref"], t["ratio"],
                                                                 "**红**" if t["ok"] == "红" else "过"))
    return "\n".join(out) + "\n"


def write(out_dir, layout_path, cn="迎宾院"):
    d, boxes, table = build(layout_path)
    os.makedirs(out_dir, exist_ok=True)
    rel = os.path.relpath(layout_path, os.path.dirname(GODOT))
    md = os.path.join(out_dir, "%s-尺寸表.md" % cn)
    js = os.path.join(out_dir, "%s-框.json" % cn)
    with open(md, "w", encoding="utf-8") as f:
        f.write(render_md(table, rel, cn))
    with open(js, "w", encoding="utf-8") as f:
        json.dump({"note": "%s每件东西在画布上画出来的外框（x0, y0, x1, y1，连高度）和宽 w、前后 d、高 h（像素），"
                           "gen_specs_court.py 从 layout.json 生成，别手改；给 GPT 出色块照这个" % cn, "canvas": d["size"], "items": boxes},
                  f, ensure_ascii=False, indent=1)
        f.write("\n")
    return md, js, table


def main():
    args = sys.argv[1:]
    if "--all" in args:
        bad = 0
        for sc in SCENES:
            r = __import__("subprocess").run([sys.executable, __file__, "--scene", sc] + [a for a in args if a == "--check"])
            bad += r.returncode != 0
        sys.exit(1 if bad else 0)
    scene = args[args.index("--scene") + 1] if "--scene" in args else "entrance"
    layout, out, cn = scene_paths(scene)
    print("== %s" % cn)
    if "--layout" in args:
        layout = os.path.abspath(args[args.index("--layout") + 1])
    if "--out" in args:
        out = os.path.abspath(args[args.index("--out") + 1])
    if "--check" in args:
        with tempfile.TemporaryDirectory() as tmp:
            md, js, table = write(tmp, layout, cn)
            changed = []
            for f in (md, js):
                mine = os.path.join(out, os.path.basename(f))
                if not os.path.exists(mine) or open(mine, encoding="utf-8").read() != open(f, encoding="utf-8").read():
                    changed.append(os.path.basename(f))
    else:
        md, js, table = write(out, layout, cn)
        changed = []
    red = [t for t in table if t["ok"] == "红"]
    for t in table:
        print("%-14s %-3s %7g  %.2f 人  %.2f 倍  %s" % (t["name"], t["dim"], t["px"], t["persons"], t["ratio"], t["ok"]))
    if changed:
        print("跟仓库里的不一样（layout.json 改了没重跑？）：", "、".join(changed))
    print("红 %d 项；%s" % (len(red), "生成在 " + out if "--check" not in args else ("没变" if not changed else "变了")))
    sys.exit(1 if red or changed else 0)


if __name__ == "__main__":
    main()
