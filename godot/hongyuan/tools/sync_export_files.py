"""把红缘运行时按文件名加载的图补进 Web 和小游戏导出预设的 export_files（resources 模式只会带依赖）。"""
import os, re, glob
os.chdir(os.path.join(os.path.dirname(__file__), "..", ".."))
files = []
for f in sorted(glob.glob("hongyuan/assets/**/*", recursive=True)):
    if f.endswith((".png", ".webp", ".svg")) and "/w2_review/" not in f and os.path.exists(f + ".import"):
        files.append("res://" + f)
for f in sorted(glob.glob("assets/characters/lm/chr_LM-GUEST-*.png")):
    files.append("res://" + f)
for f in sorted(glob.glob("hongyuan/**/*.gd", recursive=True)):
    if "/tests/" not in f and "/tools/" not in f:
        files.append("res://" + f)
files += ["res://hongyuan/boot.tscn", "res://hongyuan/player.tscn"]
cfg = open("export_presets.cfg").read()
def fix(block):
    m = re.search(r'export_files=PackedStringArray\((.*?)\)\n', block)
    have = re.findall(r'"([^"]+)"', m.group(1)) if m else []
    allf = list(dict.fromkeys(have + files))
    return block.replace(m.group(0), "export_files=PackedStringArray(" + ", ".join('"%s"' % x for x in allf) + ")\n")
parts = re.split(r'(?=^\[preset\.\d+\]$)', cfg, flags=re.M)
out = []
for part in parts:
    if 'name="红缘Web"' in part:
        part = fix(part)
    out.append(part)
open("export_presets.cfg", "w").write("".join(out))
print(len(files), "files")
