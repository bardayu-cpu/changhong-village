#!/usr/bin/env python3
"""山庄四块的目录图（01 E 10/3）：GPT 照 claude-任务-山庄四块-目录.md 出 8 张目录，交到
003-后厅、004-草坪、005-湖边、006-果园 的「拆景/目录-<类>-v<版>-<日期>/」，每个文件夹写一个交付.json（状态「等阿鱼看」，
每个编号一条：编号、是什么、在图里第几行第几列；阿鱼点头那版加「阿鱼确认」）。
这里把这些文件夹按编号列出来给 01：状态、阿鱼确认没有、交了哪几个编号、该交没交的、总表里没有的编号。
目录图不是零件（parts_table 不认，不改零件总表的状态）；阿鱼点头前一样都不往下画、不进游戏。
gpt_inbox.py 每回都调 report()；也能单独跑：python3 godot/tools/catalog_inbox.py [共用文件夹根目录]
"""
import glob
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = "/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作"
TABLE = os.path.join(HERE, "..", "..", "docs", "零件总表.md")
SCENES = ("003-后厅", "004-草坪", "005-湖边", "006-果园")
# 8 张目录各该有哪些编号（照任务单）：文件夹名里带这几个字就是那张；值是编号前缀，总表里落在这些前缀下的编号都该有
CATALOGS = {
    "草坪婚礼的人": ("LM-WEDCOUPLE-", "LM-HOST-", "LM-BRIDESMAID-", "LM-GROOMSMAN-"),
    "小孩": ("LM-KID-",),
    "草坪的东西": ("LW-",),
    "湖边和果园的人": ("LM-FISHER-", "LM-BOATMAN-", "LM-MUSIC-", "LM-FARMER-"),
    "湖边的东西": ("LK-",),
    "果园的东西": ("OR-",),
    "后厅的人": ("LM-MAKEUP-", "LM-ELDER-"),
    "后厅的东西": ("BH-",),
}
ID = re.compile(r"(?:LM-[A-Z]+-[0-9]{2}(?:\s*[～~至]\s*[0-9]{2})?|(?:LW|LK|OR|BH)-[A-Z][0-9]{2})")
ROW = re.compile(r"^\| ((?:LM-[A-Z]+-[0-9]{2}(?:～[0-9]{2})?)|(?:LW|LK|OR|BH)-[A-Z][0-9]{2}) \| ([^|]*?) \|")


def expand(code):
    """LM-KID-01～08 → LM-KID-01 … LM-KID-08；单个的原样"""
    m = re.match(r"^(LM-[A-Z]+-)([0-9]{2})\s*[～~至]\s*([0-9]{2})$", code)
    if not m:
        return [code]
    return ["%s%02d" % (m.group(1), n) for n in range(int(m.group(2)), int(m.group(3)) + 1)]


def table_ids(path=TABLE):
    """零件总表里 LM、LW、LK、OR、BH 的编号（一行一批的展开）→ 名字"""
    out = {}
    for line in open(path, encoding="utf-8").read().split("\n"):
        m = ROW.match(line)
        if m:
            for c in expand(m.group(1)):
                out[c] = m.group(2).strip().replace("**", "")
    return out


def _walk(v, found):
    """交付.json 格式 GPT 自己定，不死认键名：找带编号的那一条（dict），记下是什么、在第几行第几列"""
    if isinstance(v, dict):
        code = None
        for k in ("编号", "id", "code", "ID"):
            if isinstance(v.get(k), str) and ID.fullmatch(v[k].strip()):
                code = v[k].strip()
        if code:
            what = next((str(v[k]) for k in ("是什么", "name", "名字", "说明", "desc") if k in v), "")
            pos = next((str(v[k]) for k in ("位置", "在图里", "pos", "position", "格") if k in v), "")
            if not pos:
                r = next((v[k] for k in ("行", "row") if k in v), None)
                c = next((v[k] for k in ("列", "col", "column") if k in v), None)
                if r is not None or c is not None:
                    pos = "第%s行第%s列" % (r, c)
            for e in expand(code):
                found.setdefault(e, (what, pos))
        for x in v.values():
            _walk(x, found)
    elif isinstance(v, list):
        for x in v:
            _walk(x, found)


def read_delivery(path):
    raw = open(path, encoding="utf-8").read()
    try:
        d = json.loads(raw)
    except Exception as e:
        return {"bad": "读不了（%s）" % e}
    found = {}
    _walk(d, found)
    for m in ID.finditer(raw):   # 只写在一句话里的编号（「scope」那种）也算交了，没有说明
        for e in expand(m.group(0)):
            found.setdefault(e, ("", ""))
    status = next((str(d[k]) for k in ("状态", "status") if k in d), "（没写）") if isinstance(d, dict) else "（没写）"
    ok = d.get("阿鱼确认") if isinstance(d, dict) else None
    return {"status": status, "ayu": ok, "ids": found}


def report(root=ROOT, since=0.0, table=TABLE):
    """回一串给人看的行（没有目录文件夹回空）"""
    ids = table_ids(table)
    base = os.path.join(root, "地图一-苏七镇", "罗曼山庄")
    rows = []
    for sc in SCENES:
        for folder in sorted(glob.glob(os.path.join(base, sc, "拆景", "目录-*"))):
            if not os.path.isdir(folder):
                continue
            rel = os.path.relpath(folder, base)
            files = [os.path.join(dp, f) for dp, _, fs in os.walk(folder) for f in fs if f != ".DS_Store"]
            newest = max([os.path.getmtime(f) for f in files] or [os.path.getmtime(folder)])
            pngs = [f for f in files if f.lower().endswith(".png") and "生图原稿" not in f and "-raw" not in f]
            fresh = "（新）" if newest > since else ""
            dj = os.path.join(folder, "交付.json")
            if not os.path.exists(dj):
                rows.append("★ %s%s：还没写交付.json（图 %d 张）" % (rel, fresh, len(pngs)))
                continue
            info = read_delivery(dj)
            if "bad" in info:
                rows.append("★ %s%s：交付.json %s" % (rel, fresh, info["bad"]))
                continue
            ayu = info["ayu"]
            ayu_s = ("阿鱼确认：%s「%s」" % (ayu.get("时间", ""), ayu.get("原话", ""))) if isinstance(ayu, dict) else "阿鱼还没确认"
            rows.append("★ %s%s：状态「%s」，%s，图 %d 张，%s" % (rel, fresh, info["status"], ayu_s, len(pngs),
                                                         time.strftime("%m-%d %H:%M", time.localtime(newest))))
            got = info["ids"]
            for c in sorted(got):
                what, pos = got[c]
                name = ids.get(c)
                tail = "；".join(x for x in (what, pos) if x)
                rows.append("    %s %s%s" % (c, name if name else "【总表里没有这个编号】", "（%s）" % tail if tail else ""))
            want = next((v for k, v in CATALOGS.items() if k in os.path.basename(folder)), None)
            if want:
                miss = [c for c in ids if c.startswith(want) and c not in got]
                if miss:
                    rows.append("    该有没交：" + "、".join(miss))
            else:
                rows.append("    （文件夹名对不上 8 张目录里哪一张，看一眼是不是起错名了）")
    return rows


if __name__ == "__main__":
    for line in report(sys.argv[1] if len(sys.argv) > 1 else ROOT) or ["四块还没有目录文件夹"]:
        print(line)
