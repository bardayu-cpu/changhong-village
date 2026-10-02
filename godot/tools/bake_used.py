#!/usr/bin/env python3
"""游戏里不从显卡读图（README：纹理的 get_image 在微信里调 WebGL 的 getBufferSubData，不支持，第 5、6 版就这么崩的）。
原来有三处在手机上运行时读图：罗曼山庄的人量「画了多高」、拼宾客大图；合影相纸、海报量人和新人画了多大；厨房菜图裁空白边。
都改成电脑上先算好、存成文件跟着进包（02，10/3「性能-真人物满厅」）：
  ① assets/characters/lm/lm_index.json：每个 chr_LM-*.png 第一帧画的人从哪行到哪行（top、h）、朝前站着那一帧不透明的那块（front）
  ② assets/characters/lm/guest_atlas.png：宾客 01～12 里在的，一人一行拼好（hall_life 别桌宾客、亲友共用这一张）；lm_index 记拼了哪几位、每张图的 sha1
  ③ assets/used_rects.json：整张图不透明的那块——新人合照、厨房的图（菜图裁边用）。这一样在 Godot 里量导入以后的图
     （有的厨房图导入时缩了一半），这个脚本调 tools/bake_used_rects.gd
图换了（GPT 交新图、阿鱼点头拷进来）要重跑这个；test_no_readback.gd 在电脑上逐个核（跟 Godot 自己算的一样、sha1 对得上），对不上测试就不过。

用法：python3 godot/tools/bake_used.py           重算、写回三样
      python3 godot/tools/bake_used.py --check   只核，变了退出码 1
"""
import glob
import subprocess
import hashlib
import json
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
LM = os.path.join(GODOT, "assets", "characters", "lm")
INDEX = os.path.join(LM, "lm_index.json")
ATLAS = os.path.join(LM, "guest_atlas.png")
USED = os.path.join(GODOT, "assets", "used_rects.json")
GODOT_BIN = "/Applications/Godot.app/Contents/MacOS/Godot"


def res(p):
    return "res://" + os.path.relpath(p, GODOT).replace(os.sep, "/")


def sha1(p):
    return hashlib.sha1(open(p, "rb").read()).hexdigest()


def content(alpha, x0, y0, w, h):
    """一格里画的人从哪行到哪行：(最上面不透明的那行, 画了多高)，跟 lm_people.gd 原来的 _content 一样（a > 0.5）"""
    top = bottom = -1
    for y in range(h):
        for x in range(w):
            if alpha.getpixel((x0 + x, y0 + y)) > 127:
                if top < 0:
                    top = y
                bottom = y
                break
    if top < 0:
        return 0, h
    return top, bottom - top + 1


def used(alpha, box=None):
    """不透明的那块 [x, y, w, h]，跟 Godot 的 Image.get_used_rect 一样（alpha 不是 0）"""
    a = alpha.crop(box) if box else alpha
    b = a.getbbox()
    if not b:
        return [0, 0, 0, 0]
    return [b[0], b[1], b[2] - b[0], b[3] - b[1]]


def build():
    index = {"note": "bake_used.py 生成，别手改：罗曼山庄的人每张图第一帧画的人从哪行到哪行（top、h）、朝前站着那一帧不透明的那块（front，格子里的坐标）；"
                     "guest_atlas 是拼好的宾客大图拼了哪几位。游戏在手机上不从显卡读图，这些都照这份", "looks": {}, "guest_atlas": {}}
    pngs = sorted(glob.glob(os.path.join(LM, "chr_LM-*.png")))
    guests = []
    for p in pngs:
        code = os.path.basename(p)[4:-4]
        js = p[:-4] + ".json"
        if not os.path.exists(js):
            continue
        j = json.load(open(js, encoding="utf-8"))
        fw, fh = int(j["frame"][0]), int(j["frame"][1])
        frames = j["frames"]
        im = Image.open(p).convert("RGBA")
        alpha = im.getchannel("A")
        hf = max(1, im.width // fw)
        first = 0
        for k in ["down", "play"]:
            if frames.get(k):
                first = int(frames[k][0])
                break
        top, h = content(alpha, (first % hf) * fw, (first // hf) * fh, fw, fh)
        idle = int(frames.get("down", [first])[0]) if frames.get("down") else first
        fx, fy = (idle % hf) * fw, (idle // hf) * fh
        index["looks"][code] = {"top": top, "h": h, "front": used(alpha, (fx, fy, fx + fw, fy + fh)), "sha1": sha1(p)}
        if code.startswith("LM-GUEST-"):
            guests.append((code, im, fw, fh, hf))
    if guests:
        fw, fh, hf = guests[0][2], guests[0][3], guests[0][4]
        atlas = Image.new("RGBA", (fw * hf, fh * len(guests)), (0, 0, 0, 0))
        for i, (code, im, _, _, _) in enumerate(guests):
            atlas.paste(im.crop((0, 0, min(im.width, fw * hf), min(im.height, fh))), (0, i * fh))
        index["guest_atlas"] = {"file": "guest_atlas.png", "codes": [g[0] for g in guests], "fw": fw, "fh": fh, "hframes": hf}
    else:
        atlas = None
    return index, atlas


def dumps(d):
    return json.dumps(d, ensure_ascii=False, indent=1) + "\n"


def main():
    index, atlas = build()
    check = "--check" in sys.argv
    changed = []
    r = subprocess.run([GODOT_BIN, "--headless", "--path", GODOT, "--script", "res://tools/bake_used_rects.gd", "--"] + (["--check"] if check else []),
                       capture_output=True, text=True)
    print("\n".join(l for l in r.stdout.splitlines() if "used_rects" in l))
    if check and r.returncode != 0:
        changed.append("used_rects.json")
    if check:
        if not os.path.exists(INDEX) or open(INDEX, encoding="utf-8").read() != dumps(index):
            changed.append("lm_index.json")
        if atlas is not None:
            if not os.path.exists(ATLAS) or list(Image.open(ATLAS).convert("RGBA").getdata()) != list(atlas.getdata()):
                changed.append("guest_atlas.png")
        print("变了：" + "、".join(changed) if changed else "没变")
        sys.exit(1 if changed else 0)
    open(INDEX, "w", encoding="utf-8").write(dumps(index))
    if atlas is not None:
        atlas.save(ATLAS, optimize=True)
    print("罗曼山庄的人 %d 张、宾客大图 %s" % (len(index["looks"]), index["guest_atlas"].get("codes")))


if __name__ == "__main__":
    main()
