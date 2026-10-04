#!/usr/bin/env python3
"""导出包里引用的文件齐不齐（03 看第 65 版用；第 62 版踩过：插件设置脚本引用的 test_scene.tscn 没进包）。
用法：python3 tools/pack_refs_check.py <godot 目录> <导出目录（里面有 engine/demo-pck.bin）>
做法：
  1 解析 demo-pck.bin 的文件清单（Godot 4 PCK）
  2 扫项目里「进了包的」脚本、场景、资源、json 里写的 res:// 路径（字面写死的，和带 %s %d 的拼法按硬盘上的文件展开）
  3 引用到的文件：硬盘上有、导出过滤器没排除、却不在包里 → 缺（真问题）；硬盘上有、被排除过滤器排除了 → 「引用了被排除的」（要人看是不是运行时会走到）；硬盘上没有 → 悬空引用（列出）
  包里的名字：脚本是 .gdc（+ .gd.remap）、场景 .tscn.remap + .godot/exported/…、图 .png.import + .godot/imported/…ctex，其余原名
退出码：有「缺」就非 0
"""
import fnmatch
import glob
import os
import re
import struct
import sys

ROOT = sys.argv[1]
EXP = sys.argv[2]


def pck_names(path):
    b = open(path, "rb").read()
    assert b[:4] == b"GDPC", b[:4]
    ver = struct.unpack_from("<I", b, 4)[0]
    o = 20
    base = 0
    dir_off = None
    if ver >= 2:
        _flags, base = struct.unpack_from("<IQ", b, o)
        o += 12
    if ver >= 3:
        dir_off = struct.unpack_from("<Q", b, o)[0]
        o += 8
    o += 64
    if dir_off:
        o = dir_off
    n = struct.unpack_from("<I", b, o)[0]
    o += 4
    names = set()
    for _ in range(n):
        ln = struct.unpack_from("<I", b, o)[0]
        o += 4
        names.add(b[o:o + ln].rstrip(b"\0").decode("utf-8"))
        o += ln + 16 + 16 + 4
    return names


def excludes():
    cfg = open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()
    pats = set()
    for m in re.finditer(r'^exclude_filter="([^"]*)"', cfg, re.M):
        pats.update(p.strip() for p in m.group(1).split(",") if p.strip())
    return sorted(pats)


def excluded(rel, pats):
    return any(fnmatch.fnmatch(rel, p) for p in pats)


def in_pack(rel, names):
    if rel in names or rel + ".remap" in names or rel + ".import" in names:
        return True
    if rel.endswith(".gd") and rel + "c" in names:
        return True
    return False


def main():
    names = pck_names(os.path.join(EXP, "engine", "demo-pck.bin"))
    pats = excludes()
    print("包里 %d 个文件；导出排除规则 %d 条" % (len(names), len(pats)))
    texts = []
    for rel in sorted(names):
        base = rel[:-6] if rel.endswith(".remap") else rel
        if base.endswith(".gdc"):
            continue
        if rel.startswith(".godot/"):
            continue
        ext = base.rsplit(".", 1)[-1]
        if ext in ("gd", "tscn", "tres", "json", "cfg", "dialogue", "gdshader"):
            texts.append(base)
    # .gdc 对应的源码 .gd
    for rel in sorted(names):
        if rel.endswith(".gd.remap"):
            texts.append(rel[:-6])
    texts = sorted(set(texts))
    refs = {}
    pat = re.compile(r'res://[^\s"\'\\)\]},;<>|`]+')
    rel_pat = re.compile(r'(?:preload|load)\(\s*"(\.{1,2}/[^"]+)"')
    for rel in texts:
        p = os.path.join(ROOT, rel)
        if not os.path.exists(p):
            continue
        try:
            s = open(p, encoding="utf-8", errors="ignore").read()
        except Exception:
            continue
        for m in pat.finditer(s):
            r = m.group(0).rstrip(".,:")
            r = r.split("::")[0]
            refs.setdefault(r, set()).add(rel)
        # preload("./x.tscn") 这种相对写法（第 62 版踩的 test_scene.tscn 就是 settings.gd 里这么写的）：按脚本所在目录展开
        for m in rel_pat.finditer(s):
            r = "res://" + os.path.normpath(os.path.join(os.path.dirname(rel), m.group(1))).replace(os.sep, "/")
            refs.setdefault(r, set()).add(rel)
    missing = []
    excl_hit = []
    dangling = []
    dyn_n = 0
    checked = 0
    for r, srcs in sorted(refs.items()):
        rel = r[len("res://"):]
        if "%" in rel or "*" in rel or "{" in rel:
            dyn_n += 1
            g = re.sub(r"%[0-9.]*[sdif]", "*", rel)
            files = [os.path.relpath(f, ROOT) for f in glob.glob(os.path.join(ROOT, g))]
            for f in files:
                if os.path.isdir(os.path.join(ROOT, f)) or f.endswith(".import") or f.endswith(".uid"):
                    continue
                checked += 1
                if excluded(f, pats):
                    excl_hit.append((f, sorted(srcs)[0] + "（拼法 " + rel + "）"))
                elif not in_pack(f, names):
                    missing.append((f, sorted(srcs)[0] + "（拼法 " + rel + "）"))
            continue
        if rel.endswith("/"):
            continue
        full = os.path.join(ROOT, rel)
        if not os.path.exists(full):
            dangling.append((rel, sorted(srcs)[0]))
            continue
        if os.path.isdir(full):
            continue
        checked += 1
        if excluded(rel, pats):
            excl_hit.append((rel, sorted(srcs)[0]))
        elif not in_pack(rel, names):
            missing.append((rel, sorted(srcs)[0]))
    print("扫了 %d 个进包的文本文件，%d 条不同的 res:// 引用（%d 条是拼法），核了 %d 个落在硬盘上的文件" % (len(texts), len(refs), dyn_n, checked))
    # 已知无害：插件 compilation.gd 的 get_autoload_names() 读 res://project.godot（包里是 project.binary，读不到只返回空列表、不崩；只有现编译 .dialogue 文本才走到，游戏用的是导入好的）
    benign = [x for x in missing if x[0] == "project.godot"]
    missing = [x for x in missing if x[0] != "project.godot"]
    print("已知无害的缺：%d（project.godot，插件编辑期才读）" % len(benign))
    print("缺（硬盘上有、没被排除、却不在包里）：%d" % len(missing))
    for f, s in missing[:40]:
        print("   缺 %s  ← %s" % (f, s))
    print("引用了被导出过滤器排除的：%d" % len(excl_hit))
    seen = set()
    for f, s in excl_hit:
        if f in seen:
            continue
        seen.add(f)
        print("   排除 %s  ← %s" % (f, s))
    print("悬空引用（硬盘上没有这个文件）：%d" % len(dangling))
    for f, s in dangling[:40]:
        print("   悬空 %s  ← %s" % (f, s))
    for must in ["addons/dialogue_manager/test_scene.tscn", "addons/dialogue_manager/settings.gd", "scripts/drive_in.gd", "scripts/area.gd",
                 "assets/layered/scene_luoman_garden/layout.json", "assets/layered/scene_luoman_wkitchen/layout.json", "assets/areas/lines.json",
                 "assets/ambience/ambience_55.json", "assets/layered/scene_roman_banquet_55/scene.json", "assets/layered/scene_roman_banquet_55/base.png"]:
        print("   %s %s" % ("在包里" if in_pack(must, names) else "不在包里！", must))
    sys.exit(1 if missing else 0)


main()
