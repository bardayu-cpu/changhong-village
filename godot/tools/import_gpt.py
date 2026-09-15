#!/usr/bin/env python3
"""把 GPT 交付的一批素材接进 godot/assets（ASSETS.md 第 8、10 节）。

用法：python3 tools/import_gpt.py handoff_scene_roman_banquet_v4.json
    参数是「素材交付」根目录下的交接单文件名。

做的事：
- 只读交接单 files 里列的文件
- 检查：PNG 透明度只有 0/255、颜色不超过 24 种；不合格的自动修（透明度二值化）并在结果里标出
- 道具、装饰贴片裁掉四周透明边，游戏里按 height_m 算大小
- 拷进 godot/assets/<类型>/，去掉 _v4 这类版本后缀：工程里永远用「当前版」，版本记在 assets/sources.json
- reference/、style_anchor、preview 不进工程
"""
import json
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
DELIVERY = os.path.join(os.path.dirname(os.path.dirname(GODOT)), "苏七镇奇缘 -gpt 总文件夹", "素材交付")
KINDS = {"textures", "characters", "props", "decals", "scenes", "copy"}
VERSION = re.compile(r"_v\d+(?=\.)")


def fix_png(src, dst, crop):
    im = Image.open(src)
    notes = []
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        a = im.getchannel("A")
        if set(a.getdata()) - {0, 255}:
            im.putalpha(a.point(lambda v: 255 if v >= 128 else 0))
            notes.append("透明度已二值化")
        if crop:
            box = im.getchannel("A").getbbox()
            if box and box != (0, 0) + im.size:
                im = im.crop(box)
                notes.append("裁掉透明边 → %dx%d" % im.size)
    colors = im.getcolors(1 << 16)
    if colors is None or len(colors) > 24 + (1 if im.mode == "RGBA" else 0):
        notes.append("颜色超过 24 种（%s），没改，回执里提" % ("很多" if colors is None else len(colors)))
    im.save(dst)
    return notes


def write_import(dst, kind):
    """第一次导入前先写好导入设置：像素图不压缩（有损压缩会糊）；
    贴图和贴片要铺在 3D 表面上（地面、桌面），远处会闪，所以生成 mipmap；角色和道具不用。
    detect_3d 关掉：不然 Godot 发现它用在 3D 里会自动改成显卡压缩格式。"""
    path = dst + ".import"
    if os.path.exists(path):
        return
    with open(path, "w", encoding="utf-8") as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n')
        f.write("compress/mode=0\n")
        f.write("mipmaps/generate=%s\n" % ("true" if kind in ("textures", "decals") else "false"))
        f.write("detect_3d/compress_to=0\n")


def main():
    handoff_name = sys.argv[1]
    handoff = json.load(open(os.path.join(DELIVERY, handoff_name), encoding="utf-8"))
    sources_path = os.path.join(GODOT, "assets", "sources.json")
    sources = json.load(open(sources_path, encoding="utf-8")) if os.path.exists(sources_path) else {}
    for rel in handoff["files"]:
        kind = rel.split("/")[0]
        if kind not in KINDS:
            print("跳过（不进工程）", rel)
            continue
        src = os.path.join(DELIVERY, rel)
        name = VERSION.sub("", os.path.basename(rel))
        out_dir = os.path.join(GODOT, "assets", kind)
        os.makedirs(out_dir, exist_ok=True)
        dst = os.path.join(out_dir, name)
        if rel.endswith(".png"):
            notes = fix_png(src, dst, crop=kind in ("props", "decals"))
            write_import(dst, kind)
        else:
            data = json.load(open(src, encoding="utf-8"))
            json.dump(data, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
            notes = []
        sources["%s/%s" % (kind, name)] = {"from": rel, "batch": handoff.get("batch"), "revision": handoff.get("revision")}
        print("接入", rel, "→", "assets/%s/%s" % (kind, name), ("；" + "；".join(notes)) if notes else "")
    json.dump(sources, open(sources_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
