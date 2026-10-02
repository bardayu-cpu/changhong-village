#!/usr/bin/env python3
"""零件总表（docs/零件总表.md）读写：GPT 新交的图对上编号就把状态改成「交了」（01 D 10/2 派）。
gpt_inbox.py 调 apply(新交的文件路径列表)；也能单独跑：python3 godot/tools/parts_table.py 图1.png 图2.png ...（只看对得上哪行，不改表）

怎么对：文件名去掉扩展名和末尾的 _v数字（blk_banquet55_table_v3.png → blk_banquet55_table）跟表里「文件」那格一样，
或者文件名里直接带了编号（比如 B55S-T01_圆桌.png、chr_LM-WAITER-01_v1.png）。
编号两种（01 E 10/2）：场景零件 `B55S-T01`；罗曼山庄的人按身份 `LM-GUEST-01`（两个横杠）。
一行管一批的（`LM-WAITER-01～40`）：交来一位就在状态里记「交了 n/40（01、02…）」，文件、尺寸那两格不动。
只看「积木/」「人物/」文件夹里的 .png，和「拆景/<任务>-v<版本>-<日期>/」里带种类前缀（blk_ chr_ base_ tex_ fx_ decal_）的 .png
（素材图、效果图、预览、交接单不是零件）。
对上了：
  - 表里状态是「要画」，或者交来的是新的一版（文件名不一样）：文件、尺寸换成交来的，状态改「交了」；
    原来进过游戏的，「进游戏」那格前面记一句「游戏里还是 旧文件」
  - 同一个文件重存（文件名一样）：不改状态，报「重存了」，02 要重核
  - 状态是「归GPT」的（厨房那批）：不动
对不上的：报出来，02 判断是新零件（加一行、起编号）还是 GPT 名字起错了
"""
import os
import re
import sys

TABLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "零件总表.md")
# 编号：B55S-T01；LM-GUEST-01；一批的 LM-WAITER-01～40。「文件」那格反引号后面可以跟一句说明（比如「（v1 交时叫 …）」），原样留着
ROW = re.compile(r"^\| (?P<id>[A-Z0-9]+(?:-[A-Z]+)?-[A-Z]*[0-9]+(?:～[0-9]+)?) \| (?P<name>[^|]*?) \| `(?P<file>[^`]+)`(?P<filex>[^|]*?) \| (?P<size>[^|]*?) \| (?P<status>[^|]*?) \| (?P<ingame>[^|]*?) \|(?P<rest>.*)$")
RANGE = re.compile(r"^(?P<pre>.*-)(?P<lo>[0-9]+)～(?P<hi>[0-9]+)$")
PART_DIRS = ("积木", "人物")
SPLIT_DIR = "拆景"   # GPT 10/2 起交到「拆景/<任务>-v<版本>-<日期>/」，里面还有预览图，只认带种类前缀的
KIND_PREFIX = ("blk_", "chr_", "base_", "tex_", "fx_", "decal_")


def stem(filename: str) -> str:
    s = os.path.splitext(os.path.basename(filename))[0]
    return re.sub(r"_v\d+$", "", s)


def load(path: str = TABLE):
    lines = open(path, encoding="utf-8").read().split("\n")
    rows = []
    for i, line in enumerate(lines):
        m = ROW.match(line)
        if m:
            rows.append((i, m.groupdict()))
    return lines, rows


def in_range(id_: str, base: str):
    """一行管一批（LM-WAITER-01～40）：文件名里的编号落在这批里就回序号（"07"），不在回 None"""
    m = RANGE.match(id_)
    if not m:
        return None
    hit = re.search(re.escape(m.group("pre")) + r"([0-9]+)(?![0-9])", base)
    if hit and int(m.group("lo")) <= int(hit.group(1)) <= int(m.group("hi")):
        return hit.group(1)
    return None


def find(rows, filename: str):
    base = os.path.basename(filename)
    for i, r in rows:
        if re.search(re.escape(r["id"]) + r"(?![0-9])", base):
            return i, r
    for i, r in rows:
        if in_range(r["id"], base) is not None:
            return i, r
    st = stem(base)
    for i, r in rows:
        if stem(r["file"]) == st:
            return i, r
    return None


def is_part(path: str) -> bool:
    parts = path.replace(os.sep, "/").split("/")
    if not path.lower().endswith(".png"):
        return False
    if any(p in PART_DIRS for p in parts[:-1]):
        return True
    return SPLIT_DIR in parts[:-1] and parts[-1].startswith(KIND_PREFIX)


def image_size(path: str) -> str:
    try:
        from PIL import Image
        w, h = Image.open(path).size
        return "%d×%d" % (w, h)
    except Exception:
        return "?"


def render(r: dict) -> str:
    return "| %s | %s | `%s`%s | %s | %s | %s |%s" % (r["id"], r["name"], r["file"], r.get("filex", ""), r["size"], r["status"], r["ingame"], r["rest"])


def apply(paths: list, write: bool = True, path: str = TABLE) -> list:
    """返回给人看的几行话；write=True 时把改了的写回表"""
    lines, rows = load(path)
    out = []
    changed = False
    for p in paths:
        if not is_part(p):
            continue
        if "_idle" in os.path.basename(p):
            continue   # 人物的待机那张（chr_LM-GUEST-01_idle_v2.png）跟走路那张是一件，不另算
        hit = find(rows, p)
        base = os.path.basename(p)
        if hit is None:
            out.append("对不上编号：%s（新零件就在总表加一行起编号；GPT 名字起错了就让它改）" % base)
            continue
        i, r = hit
        if r["status"].strip() == "归GPT":
            out.append("%s %s：归 GPT，不动（%s）" % (r["id"], r["name"], base))
            continue
        n = in_range(r["id"], base)
        if n is not None:
            # 一批的：状态记「交了 几/共几（哪几位）」，文件、尺寸不动
            m = RANGE.match(r["id"])
            total = int(m.group("hi")) - int(m.group("lo")) + 1
            got = re.search(r"交了 \d+/\d+（([0-9、]+)）", r["status"])
            if not got and r["status"].strip() != "要画":
                # 状态是人写的（比如「交了（目录阿鱼点头…）」）：不改，只报一句
                out.append("%s %s：第 %s 位交了（%s），状态是人写的不动：%s" % (r["id"], r["name"], n, base, r["status"].strip()))
                continue
            have = set(got.group(1).split("、")) if got else set()
            if n in have:
                out.append("%s %s：第 %s 位重存了（%s），02 要重核" % (r["id"], r["name"], n, base))
                continue
            have.add(n)
            old_status = r["status"].strip()
            r["status"] = "交了 %d/%d（%s）" % (len(have), total, "、".join(sorted(have, key=int)))
            lines[i] = render(r)
            rows = [(j, rr if j != i else r) for j, rr in rows]
            changed = True
            out.append("%s %s：%s → %s（%s）" % (r["id"], r["name"], old_status, r["status"].strip(), base))
            continue
        if base == r["file"] and r["status"].strip() != "要画":
            out.append("%s %s：%s 重存了，状态不动（%s），02 要重核" % (r["id"], r["name"], base, r["status"].strip()))
            continue
        old_file, old_status = r["file"], r["status"].strip()
        if old_file != base and old_status == "进游戏" and "游戏里还是" not in r["ingame"]:
            r["ingame"] = "游戏里还是 %s（%s）" % (old_file, r["ingame"].strip())
        r["file"] = base
        size = image_size(p)
        if not r["size"].strip().startswith(size):   # 尺寸没变就留着原来那格的说明（比如「480×56（3 格 160×56）」）
            r["size"] = size
        r["status"] = "交了"
        lines[i] = render(r)
        rows = [(j, rr if j != i else r) for j, rr in rows]
        changed = True
        out.append("%s %s：%s → 交了（%s → %s）" % (r["id"], r["name"], old_status, old_file, base))
    if changed and write:
        open(path, "w", encoding="utf-8").write("\n".join(lines))
    return out


if __name__ == "__main__":
    for line in apply(sys.argv[1:], write=False):
        print(line)
