#!/usr/bin/env python3
"""图和数据的硬检查：不用人判断、对就是对的那几条（01 D 10/1 派，阿鱼点头；思路见 回执/参考-ClaudeCodeGameStudios.md 第 2 节）。

查什么：
  拦下（退出码 1，提交不了）：
    1. JSON 读不出来（写错了逗号、括号、引号）
    2. 场景零件有半透明的像素：blk_*、art_*、fg_*、chr_* 开头的图，和 assets/kitchen/ 里的图集，透明度只许 0 或 255。
       界面底和特效（base_ui_*、decal_*、tex_ui_*）放行（01 D 9/30：界面底和特效允许半透明，0/255 只管场景零件）；
       零件的影子另出一层 shadow_*，允许半透明（01 D 10/2：零件本身照旧硬边）
    3. 尺寸不对：
       - 场景文件夹里的 base.png 要跟同一个文件夹 scene.json / layout.json 里写的 size 一样大；
       - GPT 交的整张背景 base_*.png 宽必须 1536；
       - 瓦片照 回执/宴会厅55桌-瓦片规格.md：地砖 80×52、红毯 140×96、侧墙 96×240，55 桌那两条竖墙 40×240；地砖、红毯不许透明
  只提醒（退出码 0，照样能提交）：
    4. 一张要进包的图（路径里有 assets/）超过 1 MB；这次提交让要进包的图一共多出 2 MB 以上
    5. assets/ 下文件名有空格或大写字母

用法：
  python3 godot/tools/check_assets.py --staged      查这次要提交的（git 暂存区里的内容，不是硬盘上的），提交前检查用这个
  python3 godot/tools/check_assets.py 文件 ...       查硬盘上的文件（gpt_inbox.py 查 GPT 新交的用这个）
只用 PIL 和 Python 自带的库。
"""
import io
import json
import os
import re
import subprocess
import sys

from PIL import Image

STRICT_PREFIX = ("blk_", "art_", "fg_", "chr_")
STRICT_DIRS = ("assets/kitchen/",)
UI_PREFIX = ("base_ui_", "decal_", "tex_ui_")
SHADOW_PREFIX = ("shadow_",)   # 零件的影子另出一层，允许半透明（01 D 10/2；零件本身照旧硬边）
TILES = [  # (文件名开头, 宽, 高, 能不能透明)
    ("tex_banquet_floor", 80, 52, False),
    ("tex_banquet_carpet", 140, 96, False),
    ("tex_banquet_wall_left", 96, 240, True),
    ("tex_banquet_wall_right", 96, 240, True),
    ("tex_banquet55_wall_west", 40, 240, True),
    ("tex_banquet55_wall_east", 40, 240, True),
]
CANVAS_W = 1536
ONE_MB = 1024 * 1024
SKIP_DIRS = ("回执/", "参考/", ".godot/")   # 回执里的截图、对照图，别人的参考包，导入缓存：不查


class Source:
    """取文件内容：暂存区（--staged）或者硬盘"""

    def __init__(self, staged: bool):
        self.staged = staged
        self.root = ""
        if staged:
            self.root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()

    def read(self, path: str):
        if not self.staged:
            try:
                return open(path, "rb").read()
            except OSError:
                return None
        r = subprocess.run(["git", "-C", self.root, "show", ":" + path], capture_output=True)
        return r.stdout if r.returncode == 0 else None

    def head_size(self, path: str) -> int:
        """改之前（上一个提交里）这个文件多大，新文件是 0"""
        if not self.staged:
            return 0
        r = subprocess.run(["git", "-C", self.root, "cat-file", "-s", "HEAD:" + path], capture_output=True, text=True)
        return int(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip().isdigit() else 0


def staged_files(root: str) -> list:
    out = subprocess.run(["git", "-C", root, "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR"],
                         capture_output=True, text=True).stdout
    return [p for p in out.split("\0") if p]


def skipped(path: str) -> bool:
    p = path.replace(os.sep, "/")
    return any(("/" + d) in ("/" + p) for d in SKIP_DIRS)


def scene_size(src: Source, png_path: str):
    """base.png 旁边 scene.json / layout.json 里写的画布大小"""
    d = os.path.dirname(png_path)
    for name in ("scene.json", "layout.json"):
        raw = src.read(os.path.join(d, name).replace(os.sep, "/") if src.staged else os.path.join(d, name))
        if raw is None:
            continue
        try:
            size = json.loads(raw.decode("utf-8-sig")).get("size")
        except Exception:
            return None
        if isinstance(size, list) and len(size) == 2:
            return int(size[0]), int(size[1]), name
    return None


def check_png(src: Source, path: str, raw: bytes, errors: list, warns: list) -> None:
    name = os.path.basename(path)
    norm = path.replace(os.sep, "/")
    try:
        im = Image.open(io.BytesIO(raw))
        im.load()
    except Exception as e:
        errors.append((path, "图打不开（%s）" % e, "重新导出这张 PNG"))
        return
    w, h = im.size
    has_alpha = im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info)
    semi = 0
    if has_alpha:
        hist = im.convert("RGBA").getchannel("A").histogram()
        semi = sum(hist[1:255])
        clear = hist[0]
    strict = name.startswith(STRICT_PREFIX) or any(("/" + d) in ("/" + norm) for d in STRICT_DIRS)
    if strict and not name.startswith(UI_PREFIX + SHADOW_PREFIX) and semi:
        errors.append((path, "场景零件有 %d 个半透明像素（透明度只许 0 或 255）" % semi,
                       "让画图的把边缘改成硬边：要么全透明、要么全不透明（界面底、特效、另出的影子层 shadow_* 才可以半透明）"))
    for prefix, tw, th, alpha_ok in TILES:
        if name.startswith(prefix):
            if (w, h) != (tw, th):
                errors.append((path, "瓦片 %d×%d，规格是 %d×%d" % (w, h, tw, th), "照 回执/宴会厅55桌-瓦片规格.md 的尺寸重出"))
            if not alpha_ok and has_alpha and (semi or clear):
                errors.append((path, "地砖、红毯瓦片不许有透明", "铺满不透明的颜色重出"))
            break
    if name == "base.png":
        want = scene_size(src, path)
        if want and (w, h) != (want[0], want[1]):
            errors.append((path, "底图 %d×%d，旁边 %s 写的画布是 %d×%d" % (w, h, want[2], want[0], want[1]),
                           "底图拉成画布大小，或者改 %s 的 size（两个要一样）" % want[2]))
    elif name.startswith("base_") and not name.startswith(UI_PREFIX) and w != CANVAS_W:
        errors.append((path, "整张背景宽 %d，画布宽是 %d" % (w, CANVAS_W), "背景照 1536 宽出"))


def run(paths: list, src: Source) -> int:
    errors, warns = [], []
    grew = 0
    for path in paths:
        if skipped(path):
            continue
        low = path.lower()
        if not (low.endswith(".json") or low.endswith(".png")):
            continue
        raw = src.read(path)
        if raw is None:
            continue
        if low.endswith(".json"):
            try:
                json.loads(raw.decode("utf-8-sig"))
            except Exception as e:
                errors.append((path, "JSON 读不出来：%s" % e, "照报的行号、列号去看，多半是少了或多了逗号、括号、引号"))
            continue
        check_png(src, path, raw, errors, warns)
        if "assets/" in path.replace(os.sep, "/"):
            if len(raw) > ONE_MB:
                warns.append((path, "这张图 %.1f MB，超过 1 MB" % (len(raw) / ONE_MB), "能缩就缩：照画出来的大小出图（人 84 高就别画 450 高）"))
            grew += len(raw) - src.head_size(path)
            base = os.path.basename(path)
            if re.search(r"[A-Z ]", base):
                warns.append((path, "文件名有大写或空格", "assets/ 下文件名用小写字母、数字、下划线"))
    if grew > 2 * ONE_MB:
        warns.append(("（这次提交）", "要进包的图一共多了 %.1f MB" % (grew / ONE_MB), "看看是不是图比画出来大很多；主包 4 MB、游戏内容越大首次加载越久"))
    for path, what, fix in errors:
        print("拦下  %s\n      %s\n      怎么办：%s" % (path, what, fix))
    for path, what, fix in warns:
        print("提醒  %s\n      %s\n      建议：%s" % (path, what, fix))
    if errors:
        print("—— 一共 %d 处要改，%d 处提醒。改完重新 git add，再提交。" % (len(errors), len(warns)))
        return 1
    if warns:
        print("—— 没有要拦的；%d 处提醒（不挡提交）。" % len(warns))
    return 0


def main() -> int:
    args = sys.argv[1:]
    if args == ["--staged"]:
        src = Source(True)
        return run(staged_files(src.root), src)
    if not args or args[0].startswith("-"):
        print(__doc__)
        return 2
    return run(args, Source(False))


if __name__ == "__main__":
    sys.exit(main())
