#!/usr/bin/env python3
"""摆位表 = 55 桌厅零件规格的唯一源（00 10/2 指导第四节，01 E 派）。从 make_board55.build() 一次生成三处：
  ① 游戏的场景：assets/layered/scene_roman_banquet_55/scene.json（+ base.png、ambience_55.json），就是跑 build_graybox55.py
  ② docs/零件总表.md 里 B55、B55S 那几行的「尺寸」那一格（别的列、表格式一个字不动，gpt_inbox / parts_table.py 还要读）
  ③ 给 GPT 的零件单：北边那块的色块图、标注、零件单 json/md（03 的 export_block_for_gpt.py，原名 export_north_for_gpt.py，那种格式），出到 godot/回执/零件规格/
手写的这三处以后都作废，改尺寸只改摆位表，再跑这个。

用法：python3 godot/tools/layout_55/gen_specs.py            生成三处，最后报这三处跟仓库里现在的比变没变
      python3 godot/tools/layout_55/gen_specs.py --check    只核：生成到临时地方比，不动仓库；三处都没变退出码 0，变了 1

零件尺寸怎么从摆位表来（画出来的框，build() 里每件的 box）：
  桌、主桌 = 桌连椅子的框；宫灯 / 现场版落地灯 = 宫灯的框；花架、花盆、长凳、礼物堆 = 各自的框；北边背景 = 画布宽 × 1024；南边背景 = 画布宽 × SOUTH_BG_H
  瓦片（地砖、竖墙）、人物不在摆位表里（瓦片规格另外定），这几行不动
"""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
REPO = os.path.dirname(GODOT)
TABLE_MD = os.path.join(REPO, "docs", "零件总表.md")
SCENE_FILES = ["assets/layered/scene_roman_banquet_55/scene.json", "assets/layered/scene_roman_banquet_55/base.png",
               "assets/ambience/ambience_55.json"]
PARTS_OUT = os.path.join(GODOT, "回执", "零件规格")


def load_board():
    argv = sys.argv
    sys.argv = [argv[0]]   # make_board55 开头会把 sys.argv[1] 当输出目录
    spec = importlib.util.spec_from_file_location("board", os.path.join(HERE, "make_board55.py"))
    B = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(B)
    sys.argv = argv
    return B


def sizes_from_board(B):
    """编号 → (宽, 高)，全从摆位表里每件画出来的框量"""
    items = B.build()[0]

    def one(pred, what):
        boxes = {tuple(it["box"][2:]) for it in items if pred(it)}
        if len(boxes) != 1:
            raise SystemExit("摆位表里 %s 的框大小不止一种（%s），零件只能一种大小" % (what, boxes))
        return boxes.pop()
    table = one(lambda it: it["kind"] == "table" and it["name"] != "主桌", "普通桌")
    main = one(lambda it: it["kind"] == "table" and it["name"] == "主桌", "主桌")
    lamp = one(lambda it: "宫灯" in it["name"], "宫灯")
    stand = one(lambda it: "花架" in it["name"], "花架")
    pot = one(lambda it: "花盆" in it["name"], "花盆")
    bench = one(lambda it: it["name"] == "长凳", "长凳")
    out = {"B55-BG01": (B.W, 1024), "B55-BG02": (B.W, B.SOUTH_BG_H), "B55-T01": table, "B55-T02": main, "B55-P01": lamp,
           "B55-P02": stand, "B55-P03": pot, "B55-P04": bench,
           "B55S-BG01": (B.W, 1024), "B55S-T01": table, "B55S-T02": main, "B55S-P01": lamp, "B55S-P02": stand,
           "B55S-P03": pot, "B55S-P04": bench}
    gifts = [it for it in items if it.get("group") == "gifts"]
    if gifts:
        out["B55S-P05"] = one(lambda it: it.get("group") == "gifts", "礼物堆")
    return out


def update_table_md(text, sizes):
    """只改 B55 / B55S 行的第 4 格（尺寸）。数一样就不碰原来的字（比如「约 96×80」）；数不一样换成「宽×高」。回 (新文本, 改了哪几行)"""
    out, changed = [], []
    for line in text.split("\n"):
        m = re.match(r"^\| (B55S?-[A-Z]+\d+) \|", line)
        if m and m.group(1) in sizes:
            cells = line.split("|")
            w, h = sizes[m.group(1)]
            nums = re.findall(r"\d+", cells[4])
            if nums[:2] != [str(w), str(h)]:
                old = cells[4].strip()
                cells[4] = " %d×%d " % (w, h)
                changed.append("%s：%s → %d×%d" % (m.group(1), old, w, h))
                line = "|".join(cells)
        out.append(line)
    return "\n".join(out), changed


def git_changed(paths):
    r = subprocess.run(["git", "-C", REPO, "status", "--porcelain", "-z", "--"] + paths, capture_output=True, text=True)
    return [p[3:] for p in r.stdout.split("\0") if p]


def main():
    check = "--check" in sys.argv
    B = load_board()
    sizes = sizes_from_board(B)
    print("摆位表里的零件尺寸：", ", ".join("%s %d×%d" % (k, w, h) for k, (w, h) in sorted(sizes.items())))
    report = {}

    # ① 场景
    if check:
        tmp = tempfile.mkdtemp(prefix="gen_specs_")
        before = {p: open(os.path.join(GODOT, p), "rb").read() for p in SCENE_FILES}
    subprocess.run([sys.executable, os.path.join(HERE, "build_graybox55.py")], check=True, capture_output=True)
    scene_changed = [p for p in SCENE_FILES if git_changed(["godot/" + p])]
    if check:
        scene_changed = [p for p in SCENE_FILES if open(os.path.join(GODOT, p), "rb").read() != before[p]]
        for p, data in before.items():   # 只核不改：放回去
            open(os.path.join(GODOT, p), "wb").write(data)
        subprocess.run(["git", "-C", REPO, "checkout", "-q", "--", "godot/回执/55桌接图v1-北边预览.png", "godot/回执/55桌接图v1-整厅拼图.png"])
    report["① 场景"] = scene_changed

    # ② 零件总表
    text = open(TABLE_MD, encoding="utf-8").read()
    new, changed = update_table_md(text, sizes)
    if changed and not check:
        open(TABLE_MD, "w", encoding="utf-8").write(new)
    report["② 零件总表"] = changed

    # ③ 给 GPT 的零件单（北边那块）
    out = tempfile.mkdtemp(prefix="gen_parts_") if check else PARTS_OUT
    # 03 10/2 正把 export_north_for_gpt.py 改名成 export_block_for_gpt.py（北边、南边都要导）：哪个在用哪个，新名字优先
    exporter = next(os.path.join(HERE, f) for f in ("export_block_for_gpt.py", "export_north_for_gpt.py")
                    if os.path.exists(os.path.join(HERE, f)))
    r = subprocess.run([sys.executable, exporter, out], capture_output=True, text=True)
    if not os.path.exists(os.path.join(out, "宴会厅北-零件单.json")):
        raise SystemExit("导零件单失败：\n" + r.stdout[-1500:] + r.stderr[-1500:])
    gen = json.load(open(os.path.join(out, "宴会厅北-零件单.json"), encoding="utf-8"))
    bad = [p["code"] for p in gen["parts"] if p["code"] in sizes and tuple(p["size"]) != tuple(sizes[p["code"]])]
    if bad:
        raise SystemExit("零件单里的尺寸跟摆位表对不上：%s" % bad)
    if check:
        cur = os.path.join(PARTS_OUT, "宴会厅北-零件单.json")
        same = os.path.exists(cur) and json.load(open(cur, encoding="utf-8")) == gen
        report["③ 零件单"] = [] if same else ["宴会厅北-零件单.json"]
        shutil.rmtree(out)
    else:
        report["③ 零件单"] = git_changed(["godot/回执/零件规格"])
    for k, v in report.items():
        print("%s：%s" % (k, "跟现在一样" if not v else "变了 %s" % v))
    return 0 if not any(report.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
