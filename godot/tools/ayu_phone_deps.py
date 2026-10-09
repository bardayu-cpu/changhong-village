#!/usr/bin/env python3
"""阿鱼家手机预览要进包的文件：从 phone_boot.tscn、home.tscn 起，顺着 .gd/.tscn 里写死的 res:// 路径（preload、load、ext_resource）一路找下去。
Godot 导出「选中的场景」不会顺着脚本里的 preload 找，所以这里自己找，写进 export_presets.cfg 的 export_files。
图和声音（ayu_home 下的 png/wav）不进包，走云存储；json、nav 由 include_filter 带上。
用法：python3 tools/ayu_phone_deps.py  （在 godot 目录下跑，打印列表；--write 直接写进「阿鱼家手机预览」那一节）"""
import os, re, sys
START = ["res://ayu_home/v4/phone_boot.tscn", "res://ayu_home/v4/home.tscn"]
pat = re.compile(r'res://[A-Za-z0-9_./\-一-鿿]+\.(?:gd|tscn|tres|res|woff2|otf|ttf|png|jpg|wav|ogg|gdshader|json)')
seen, todo = set(), list(START)
while todo:
    p = todo.pop()
    if p in seen: continue
    f = p.replace("res://", "")
    if not os.path.exists(f): continue
    seen.add(p)
    if f.endswith((".gd", ".tscn", ".tres")):
        for m in pat.findall(open(f, encoding="utf-8", errors="ignore").read()):
            todo.append(m)
# 访客用罗曼的宾客图（scripts/lm_people.gd 在运行时拼路径读 assets/characters/lm/ 下的图），整个文件夹带上
for x in sorted(os.listdir("assets/characters/lm")):
    if x.endswith(".png"): seen.add("res://assets/characters/lm/" + x)
# 项目的自动加载（DialogueManager 对话插件）每个包都会加载；它用 class_name（DMConstants 这些）互相引用，路径不写在代码里，
# 顺着 res:// 找不到。照主线导出的做法带上插件里运行要用的全部文件，只去掉编辑器那部分（跟「小游戏」那套的 exclude 一样）。
# V1.0.1.1 第一次导出漏了这些，手机上报 454 条「DMConstants not declared」（10/5 晚）
import fnmatch
DM_SKIP = ["*.cs", "*.uid", "*.import", "components/*", "debugger_plugin.gd", "editor_translation_parser_plugin.gd", "example_balloon/*",
           "export_plugin.gd", "import_plugin.gd", "inspector_plugin.gd", "nodes/dialogue_label/DialogueLabel.tscn", "plugin.gd", "views/*", "LICENSE", "plugin.cfg"]
for root, _, files in os.walk("addons/dialogue_manager"):
    for x in files:
        rel = os.path.relpath(os.path.join(root, x), "addons/dialogue_manager")
        if not any(fnmatch.fnmatch(rel, p) for p in DM_SKIP): seen.add("res://addons/dialogue_manager/" + rel)
keep = sorted(p for p in seen if not (p.startswith("res://ayu_home/") and p.endswith((".png", ".wav", ".webp", ".json"))) and not p.endswith(".json"))
if "--write" in sys.argv:
    s = open("export_presets.cfg", encoding="utf-8").read()
    i = s.index('name="阿鱼家手机预览"'); j = s.index("export_files=", i); k = s.index("\n", j)
    s = s[:j] + "export_files=PackedStringArray(" + ", ".join('"%s"' % p for p in keep) + ")" + s[k:]
    j = s.index("export_filter=", i); k = s.index("\n", j); s = s[:j] + 'export_filter="resources"' + s[k:]   # 「选中的场景」不顺着 preload 找，要按资源列
    open("export_presets.cfg", "w", encoding="utf-8").write(s)
for p in keep: print(p)
print(len(keep), "个", file=sys.stderr)
