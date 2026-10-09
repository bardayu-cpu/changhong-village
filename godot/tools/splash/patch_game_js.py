#!/usr/bin/env python3
"""导出时改模板的 game.js（export-wechat.sh 调）：开屏加载页用我们的图、我们的字、我们的动画（wxgame/splash.js，01 E 10/3）。
  - import './splash' 排在 import './godot-loader' 后面（要先有 GodotLoader 才能换它的画法），game.js 最后 new GodotLoader 之前
  - materialConfig.backgroundImage → images/splash.jpg；模板的 Godot 小标（iconConfig）不出
  - textConfig 换成喜宴的口吻（照原意：首次加载请耐心等待 / 加载中 / 编译中 / 引擎初始化中 / 开始游戏），等阿鱼定
模板的 game.js 换了样子、找不到要改的那几行就报错退出，不悄悄出一个没改的包。
用法：python3 patch_game_js.py <导出目录>/game.js
"""
import re
import sys

TEXT = {
    "firstStartText": "头一回来，喜宴还在布置，稍等一下",
    "downloadingText": ["正在摆桌子", "正在挂红绸", "正在摆碗筷"],
    "compilingText": "厨房起锅了",
    "initText": "马上开席",
    "completeText": "开席啦",
}


def main():
    p = sys.argv[1]
    s = open(p, encoding="utf-8").read()
    need = [
        ("import './godot-loader'\n", "import './godot-loader'\nimport './splash'\n"),
        ("backgroundImage: 'images/background.jpg'", "backgroundImage: 'images/splash.jpg'"),
    ]
    for a, b in need:
        if a not in s:
            sys.exit("game.js 里找不到「%s」，模板变了，开屏没接上" % a.strip())
        s = s.replace(a, b, 1)
    s, n = re.subn(r"(iconConfig:\s*\{\s*visible:\s*)true", r"\1false", s, count=1)
    if n != 1:
        sys.exit("game.js 里找不到 iconConfig.visible，模板变了")
    for k, v in TEXT.items():
        if isinstance(v, list):
            val = "[" + ", ".join("'%s'" % x for x in v) + "]"
            s, n = re.subn(r"(%s:\s*)\[[^\]]*\]" % k, lambda m: m.group(1) + val, s, count=1)
        else:
            s, n = re.subn(r"(%s:\s*)'[^']*'" % k, lambda m: m.group(1) + "'%s'" % v, s, count=1)
        if n != 1:
            sys.exit("game.js 里找不到 textConfig.%s，模板变了" % k)
    open(p, "w", encoding="utf-8").write(s)
    print("开屏：game.js 改好了（图、字、动画）")


if __name__ == "__main__":
    main()
