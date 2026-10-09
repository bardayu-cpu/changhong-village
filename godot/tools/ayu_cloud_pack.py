#!/usr/bin/env python3
"""阿鱼家手机预览：把运行时真用到的图和声音（asset_tour.gd 量出来的清单）备成一个「传云存储」文件夹 + 游戏读的清单。
- 图一律转无损 WebP（画面一个像素不变，约省 23%），声音照原样
- 文件名改成只有英文、数字、下划线、点、连字符（云函数 canvasFile 的白名单），全部放同一层，阿鱼在控制台全选传一次
- 清单写进 godot/ayu_home/v4/cloud_manifest.json：res:// 路径 → 云上的名字、字节、sha256；File ID = prefix + 名字
用法：python3 godot/tools/ayu_cloud_pack.py <used.txt> <输出文件夹>
分批：读 godot/ayu_home/v4/cloud_groups_measured.json（tests/asset_groups.gd 量的：每个入口要哪些），写进清单的 groups 和后台下载顺序 order
"""
import hashlib, io, json, os, re, sys
from PIL import Image
PREFIX = "cloud://cloud1-d9ggg36tj34742bef.636c-cloud1-d9ggg36tj34742bef-1488216695/canvas/ayu_home/"
used, out = sys.argv[1], sys.argv[2]
godot = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.makedirs(out, exist_ok=True)
files = {}
names = set()
for line in open(used, encoding="utf-8"):
    res = line.strip()
    if not res: continue
    src = os.path.join(godot, res.replace("res://", ""))
    rel = res.replace("res://ayu_home/", "").replace("/assets/", "/").replace("/", "-")
    base, ext = os.path.splitext(rel)
    name = re.sub(r"[^A-Za-z0-9_.-]", "_", base) + (".webp" if ext == ".png" else ext)
    assert name not in names and ".." not in name, name
    names.add(name)
    if ext == ".png":
        buf = io.BytesIO(); Image.open(src).save(buf, "WEBP", lossless=True, method=4); data = buf.getvalue()
    else:
        data = open(src, "rb").read()
    open(os.path.join(out, name), "wb").write(data)
    files[res] = {"name": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
# 分批下载（10/5 晚，001：第一次进门等 10 秒左右）：boot＝开家进院子要的 + 换时间要的声音 + 三张对话头像（小，开门那句话要用）
measured = json.load(open(os.path.join(godot, "ayu_home/v4/cloud_groups_measured.json"), encoding="utf-8"))["groups"]
groups = {k: sorted(p for p in v if p in files) for k, v in measured.items() if k not in ("boot", "clock")}
groups["boot"] = sorted(set(measured["boot"]) | set(measured.get("clock", [])) | {p for p in files if "/talk-faces/" in p})
size = lambda g: sum(files[p]["bytes"] for p in groups[g] if p not in groups["boot"])
rooms = sorted((g for g in groups if g.startswith("room:")), key=size)
others = sorted((g for g in groups if g.split(":")[0] in ("immersive", "activity", "game", "photo")), key=size)
order = ["boot", "panels"] + rooms + others
covered = set(p for g in order for p in groups[g])
assert covered == set(files), ("有文件不在任何一组里", set(files) - covered)
manifest = {"version": 2, "prefix": PREFIX, "files": files, "groups": groups, "order": order}
json.dump(manifest, open(os.path.join(godot, "ayu_home/v4/cloud_manifest.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
print("%d 个文件，共 %.1f MB → %s" % (len(files), sum(f["bytes"] for f in files.values()) / 1e6, out))
