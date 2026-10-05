#!/usr/bin/env python3
"""化妆间 · 换上 GPT 精修图（庄Z1 10/5 派，庄Z2 写；阿鱼「还不错，他已经交完了，你让他员工拼回去」「那不行，还是要用统一画风」）。

做法：先照代码画那版（room_makeup_ref.py）把底图和 60 格全画出来，再把 GPT 交的精修图一格一格换进去：
  - GPT 文件夹里有哪些就换哪些（文件名 = 零件名，base.png 是底图），缺的格子照旧用代码零件顶着，跑完列出来；剩下的到了再跑一次就全换完
  - 缩法照总002 godot/回执/化妆间精修-缩到1倍/缩法.md（b136d92）：
      1. 4 倍 → 1 倍最近邻（每 4×4 取一个像素），跟人物同一种 1 倍颗粒、硬边
      2. 整间一套调色板限 64 色（八叉树、不抖动）：**每次跑都从这次文件夹里全部 GPT 图（底图 + 零件）现取一次色，再把这些图全部重压**，
         不沿用上一次的调色板——50 件交齐那次跑，就是整间重新取色、全部重压（总002 定）
      3. 透明压成全透或全不透（≥128 不透明）
      4. 位置照零件表：左上角 (x/4, y/4)、底边 foot_y/4（跟代码零件同一格，所以占地、挡人、座位都不变）
  - 代码零件顶着的格子不压色，照原样（总002 定）
  - GPT 4 倍原图一张不动、不删，只读
出拆景包交 tools/import_makeup_blocks.py 拼回游戏（跟代码画那版一样：按着地线跟人排前后、占地挡人、座位坐人），两道遮挡检查照跑。

用法：python3 godot/tools/pixel_art/room_makeup_gpt.py [GPT 文件夹] [--preview 目录]
   GPT 文件夹不给就用共用文件夹 …/003-后厅/化妆间-精修-v1/
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import room_makeup_ref as ref   # 代码画那版：底图、60 格、拆景包、导入都借它

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
def _share():
    """共用文件夹：从这里往上逐层找「游戏制作中-gpt 和 claude 合作」（主仓库、工作树里层数不一样）"""
    d = GODOT
    while d != os.path.dirname(d):
        c = os.path.join(d, "游戏制作中-gpt 和 claude 合作")
        if os.path.isdir(c):
            return os.path.join(c, "地图一-苏七镇", "罗曼山庄", "003-后厅")
        d = os.path.dirname(d)
    raise SystemExit("找不到共用文件夹「游戏制作中-gpt 和 claude 合作」")


SHARE = _share()
GPT_DIR = os.path.join(SHARE, "化妆间-精修-v1")
TABLE = os.path.join(SHARE, "化妆间-代码零件-v1", "零件表.json")
Z = 4
COLORS = 64


def shrink(im):
    """4 倍 → 1 倍最近邻；透明压成二值。回 (RGB 图, 透明遮罩)"""
    im = im.convert("RGBA")
    s = im.resize((im.width // Z, im.height // Z), Image.NEAREST)
    a = s.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    return s.convert("RGB"), a


def main():
    args = [a for k, a in enumerate(sys.argv[1:]) if not a.startswith("--") and (k == 0 or sys.argv[k] != "--preview")]
    gdir = args[0] if args else GPT_DIR
    preview = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    table = {r["名字"]: r for r in json.load(open(TABLE, encoding="utf-8"))["零件"]}
    # 1. 代码画那版（底图 + 60 格）
    bg = ref.background()
    ref.build_all()
    ref.floor_shadows(bg)
    # 2. GPT 文件夹里有哪些
    have = {os.path.splitext(f)[0]: os.path.join(gdir, f) for f in os.listdir(gdir) if f.endswith(".png")}
    names = ["base"] + [p["id"] for p in ref.PIECES]
    got = [n for n in names if n in have]
    missing = [n for n in names if n not in have]
    bad = []
    shrunk = {}
    for n in got:
        im = Image.open(have[n])
        r = table[n]
        if im.size != (r["w"], r["h"]):
            bad.append("%s：GPT 图 %s，零件表 %d×%d" % (n, im.size, r["w"], r["h"]))
            continue
        shrunk[n] = shrink(im)
    if bad:
        raise SystemExit("尺寸对不上（没换）：\n" + "\n".join(bad))
    # 3. 这次全部 GPT 图拼一张，现取 64 色；全部重压（不沿用上一次的调色板）
    w = max(rgb.width for rgb, _ in shrunk.values())
    h = sum(rgb.height for rgb, _ in shrunk.values())
    sheet = Image.new("RGB", (w, h), (0, 0, 0))
    y = 0
    for rgb, a in shrunk.values():
        black = Image.new("RGB", rgb.size, (0, 0, 0))
        sheet.paste(Image.composite(rgb, black, a), (0, y))   # 透明的地方不算颜色
        y += rgb.height
    pal = sheet.quantize(colors=COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    done = {}
    for n, (rgb, a) in shrunk.items():
        q = rgb.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
        q.putalpha(a)
        done[n] = q
    # 4. 换进去：底图、零件（位置照零件表 /4；跟代码零件同一格）
    if "base" in done:
        bg.im = done["base"].copy()
        bg.im.putalpha(255)
        bg.px = bg.im.load()
    moved = []
    for p in ref.PIECES:
        if p["id"] in done:
            r = table[p["id"]]
            p["img"] = done[p["id"]]
            nx, ny, nf = r["x"] // Z, r["y"] // Z, r["foot_y"] // Z
            if (nx, ny, nf) != (p["x"], p["y"], p["foot"]):
                moved.append("%s：零件表 /4 = (%d, %d) 底 %d，代码零件 (%d, %d) 底 %d" % (p["id"], nx, ny, nf, p["x"], p["y"], p["foot"]))
            p["x"], p["y"] = nx, ny
    if moved:
        raise SystemExit("位置对不上：\n" + "\n".join(moved))
    gpt_cols = set()
    for im in done.values():
        for c in im.getdata():
            if c[3]:
                gpt_cols.add(c[:3])
    print("换了 GPT：%d 张（%s）；GPT 图一共 %d 色（≤ %d）" % (len(done), "、".join(n for n in names if n in done), len(gpt_cols), COLORS))
    print("还是代码零件顶着：%d 格（%s）" % (len([n for n in missing if n != "base"]), "、".join(n for n in missing if n != "base") or "没有"))
    # 5. 拼回游戏
    pkg = tempfile.mkdtemp(prefix="makeup_gpt_")
    ref.write_package(pkg, bg)
    subprocess.run([sys.executable, os.path.join(GODOT, "tools", "import_makeup_blocks.py"), pkg, "--canvas=%dx%d" % (ref.CW, ref.CH),
                    "--name=makeup_room"], check=True)
    if preview:
        os.makedirs(preview, exist_ok=True)
        room = ref.compose(bg)
        room.save(os.path.join(preview, "化妆间-一比一.png"))
        with open(os.path.join(preview, "还缺.txt"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(n for n in missing) + "\n")
    subprocess.run(["rm", "-rf", pkg])


if __name__ == "__main__":
    main()
