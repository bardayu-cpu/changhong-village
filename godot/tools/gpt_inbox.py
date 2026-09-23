# -*- coding: utf-8 -*-
# 盯 GPT 的交接文件夹（01 9/24 交给 02 的长期活）：列出上次查看以后新放进来、或者改过的文件。
# 不算：.DS_Store、claude-* 开头的（我们自己写的回执、对照图）、*-raw/ 草稿文件夹里的。
# 用法：python3 godot/tools/gpt_inbox.py          只列，不动记号
#       python3 godot/tools/gpt_inbox.py --done   列完把「上次查看」的时间记成现在（处理完一批再加 --done）
import os, sys, time, json

ROOT = "/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作"
STAMP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".gpt_inbox_stamp.json")

def load_stamp():
    try:
        return json.load(open(STAMP))
    except Exception:
        return {"at": 0}

def skip(path):
    parts = path.split(os.sep)
    name = parts[-1]
    if name == ".DS_Store" or name.startswith("claude-"):
        return True
    return any(p.endswith("-raw") for p in parts)

st = load_stamp()
since = float(st.get("at", 0))
rows = []
for d, _, fs in os.walk(ROOT):
    for f in fs:
        p = os.path.join(d, f)
        rel = os.path.relpath(p, ROOT)
        if skip(rel):
            continue
        m = os.path.getmtime(p)
        if m > since:
            rows.append((m, rel, os.path.getsize(p)))
rows.sort()
print("上次查看：", time.strftime("%m-%d %H:%M", time.localtime(since)) if since else "（第一次）", "；新的/改过的", len(rows), "个")
for m, rel, sz in rows[-400:]:
    print(time.strftime("%m-%d %H:%M", time.localtime(m)), f"{sz//1024:>6}KB", rel)
if "--done" in sys.argv:
    json.dump({"at": time.time()}, open(STAMP, "w"))
    print("已记下这次查看的时间")
