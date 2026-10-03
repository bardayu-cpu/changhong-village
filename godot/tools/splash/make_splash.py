#!/usr/bin/env python3
"""开屏素材（阿鱼 10/3 交的那包：「苏七镇-开屏文件」）转成游戏用的三样，都放 assets/splash/：
  splash_bg.jpg      背景，540×960。两层共用这一张：引擎起来之前的加载页（wxgame/splash.js，导出时拷成 images/splash.jpg）
                     和开场（scripts/title_screen.gd）。.import 是 keep，原 jpg 进包，两处解出来是同一张图
  title_ui_logo.png  标题 logo，透明底。开场里最宽约 500 个视口像素（屏宽 92%），手机上 2～3 倍像素比，取 720 宽；进包按有损 WebP 压
  title_bgm.wav      开场音乐，9 秒、首尾已交叉淡化。Godot 导入时压成 QOA、整段循环（.import 里写着），不用另装转码工具

背景用 GPT 原图（关键帧2_原图.png，941×1672）直接缩，不用视频截帧（阿鱼 10/3：「GPT 原图，像素最正」）。
原图 941×1672 缩成 540×960 横竖差 0.05%，直接拉，不裁。

用法：python3 godot/tools/splash/make_splash.py [素材文件夹，默认 桌面/苏七镇奇缘/苏七镇-开屏文件]
"""
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(GODOT, "assets", "splash")
SRC = os.path.expanduser("~/Desktop/苏七镇奇缘/苏七镇-开屏文件")
BG_SIZE = (540, 960)
BG_QUALITY = 85     # 4:4:4 不抽色度（红灯笼边上不糊）；约 300 KB。主包、引擎分包各一份
LOGO_W = 720


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else SRC
    os.makedirs(OUT, exist_ok=True)
    bg = Image.open(os.path.join(src, "关键帧2_原图.png")).convert("RGB").resize(BG_SIZE, Image.LANCZOS)
    p = os.path.join(OUT, "splash_bg.jpg")
    bg.save(p, "JPEG", quality=BG_QUALITY, optimize=True, subsampling=0)
    print("背景 %s %d KB" % (p, os.path.getsize(p) // 1024))
    logo = Image.open(os.path.join(src, "logo.png")).convert("RGBA")
    logo = logo.resize((LOGO_W, round(logo.height * LOGO_W / logo.width)), Image.LANCZOS)
    p = os.path.join(OUT, "title_ui_logo.png")
    logo.save(p, "PNG", optimize=True)
    print("logo %s %dx%d %d KB（进包按 WebP 有损压）" % (p, logo.width, logo.height, os.path.getsize(p) // 1024))
    p = os.path.join(OUT, "title_bgm.wav")
    shutil.copyfile(os.path.join(src, "bgm.wav"), p)
    print("音乐 %s %d KB（进包压成 QOA）" % (p, os.path.getsize(p) // 1024))


if __name__ == "__main__":
    main()
