#!/usr/bin/env python3
"""shot.sh 用：核一个 Godot 工程的导入齐不齐（素材都有 .import、.import 指的导入结果都在）。齐退出 0，不齐打 SHOT FAILED 退出 2"""
import os, re, sys
root = sys.argv[1]
EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".ttf", ".otf", ".woff", ".woff2", ".wav", ".ogg", ".mp3")
missing, broken = [], []
for d, dirs, files in os.walk(root):
    rel = os.path.relpath(d, root)
    if rel.startswith(".godot") or os.path.exists(os.path.join(d, ".gdignore")):
        dirs[:] = []
        continue
    for f in files:
        p = os.path.join(d, f)
        if f.lower().endswith(EXT) and not os.path.exists(p + ".import"):
            missing.append(os.path.relpath(p, root))
        if f.endswith(".import"):
            txt = open(p, encoding="utf-8", errors="ignore").read()
            if 'valid=false' in txt:
                continue   # Godot 自己标了不导的
            m = re.search(r"dest_files=\[(.*?)\]", txt, re.S)
            for res in re.findall(r'"res://([^"]+)"', m.group(1) if m else ""):
                if not os.path.exists(os.path.join(root, res)):
                    broken.append(os.path.relpath(p, root))
                    break
if missing or broken:
    print("SHOT FAILED 导入不全：没有 .import 的 %d 个 %s；导入结果不在的 %d 个 %s" % (len(missing), missing[:5], len(broken), broken[:5]))
    sys.exit(2)
print("导入核过：素材都有 .import、导入结果都在")
