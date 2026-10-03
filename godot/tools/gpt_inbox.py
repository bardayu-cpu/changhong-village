# -*- coding: utf-8 -*-
# 盯 GPT 的交接文件夹（01 9/24 交给 02 的长期活）：列出上次查看以后新放进来、或者改过的文件。
# 不算：.DS_Store、claude-* 开头的（我们自己写的回执、对照图）、*-raw/ 草稿文件夹里的。
# 用法：python3 godot/tools/gpt_inbox.py          只列，不动记号
#       python3 godot/tools/gpt_inbox.py --done   列完把零件总表改了、把「上次查看」的时间记成现在（处理完一批再加 --done）
# 列完会对新交的 .png、.json 跑一遍 check_assets.py（硬检查），有「拦下」的写进给 01 的报告里
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
# 交付单、交接单先单独列在最上面：文件一多，翻到最后几行就看不到它们了（10/2 漏看过一次 gpt-后厨交付-v1.2.md）
notes = [r for r in rows if ("交付" in r[1] or "交接" in r[1] or "handoff" in r[1].lower()) and r[1].lower().endswith((".md", ".json"))]
if notes:
    print("★ 交付单／交接单 %d 个（先看这些）：" % len(notes))
    for m, rel, sz in notes:
        print("★", time.strftime("%m-%d %H:%M", time.localtime(m)), rel)
for m, rel, sz in rows[-400:]:
    print(time.strftime("%m-%d %H:%M", time.localtime(m)), f"{sz//1024:>6}KB", rel)
# 山庄四块（003 后厅、004 草坪、005 湖边、006 果园）的目录图：拆景/目录-*/交付.json 按编号列给 01（01 E 10/3）；
# 每回都列（不光是新的），阿鱼点没点头、该交没交的一眼看得到
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import catalog_inbox
cat = catalog_inbox.report(ROOT, since)
if cat:
    print("—— 山庄四块目录（按编号）——")
    for line in cat:
        print(line)
# 新交的图和 JSON 顺手过一遍提交前检查那套硬规则（check_assets.py：JSON 能读、零件透明 0/255、背景和瓦片尺寸、图多大），
# 交来就知道哪张不合格，不用等进仓库（01 D 10/1）
fresh = [os.path.join(ROOT, rel) for _, rel, _ in rows if rel.lower().endswith((".png", ".json"))]
if fresh:
    import subprocess
    print("—— 硬检查（check_assets.py）%d 个文件 ——" % len(fresh))
    r = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "check_assets.py")] + fresh)
    if r.returncode == 0:
        print("硬检查：没有要拦的")
# 零件总表（docs/零件总表.md）：新交的零件图对得上编号就把状态改成「交了」，对不上的报出来（01 D 10/2）
if fresh:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import parts_table
    # 01 E 10/2（03 报）：不带 --done 只是看看，不改表；带 --done 才把「交了」写进零件总表
    write = "--done" in sys.argv
    notes = parts_table.apply(fresh, write=write)
    if notes:
        print("—— 零件总表 ——" + ("" if write else "（只是预览，没写表；处理完加 --done 才写）"))
        for n in notes:
            print(n)
if "--done" in sys.argv:
    json.dump({"at": time.time()}, open(STAMP, "w"))
    print("已记下这次查看的时间")
