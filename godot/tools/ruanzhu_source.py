#!/usr/bin/env python3
"""软著源代码文档：从 main 上我们自己写的代码里取前 30 页、后 30 页，每页 50 行，出 HTML 给 Chrome 打成 PDF（01 E 10/2 派）。

用法：python3 godot/tools/ruanzhu_source.py <输出目录>
  出 <输出目录>/源代码.html，再用 Chrome 无界面打印成 PDF（见回执）。

取哪些：客户端 GDScript（godot/scripts，main.gd 打头）→ 小游戏 JS 桥（godot/wxgame）→ 云函数和服务端规则（server-claude）。
不要：引擎、第三方库、node_modules、自动生成的文件、测试、调试用的试验脚本。
处理：去掉注释和空行（注释里是团队内部的过程记录）；Tab 换 4 个空格；
      云环境 ID、AppID、像真 openid 的串换成占位；太长的行按显示宽度折行，折出来的每一截算一行。
"""
import html
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TITLE = "苏七镇奇缘游戏软件 V1.0"
ROWS = 50
PAGES = 30          # 前、后各 30 页
COLS = 100          # 折行的显示宽度（中文算 2）
SKIP = {"godot/scripts/hall55_test.gd", "godot/scripts/remote_probe.gd", "godot/wxgame/debug-console.js"}   # 调试用

MASKS = [
    (re.compile(r"cloud\d+-[0-9a-z]{6,}"), "<云环境ID>"),
    (re.compile(r"wx[0-9a-f]{16}"), "<AppID>"),
    (re.compile(r"\bo[A-Za-z0-9_-]{27}\b"), "<openid>"),
]


def files():
    out = subprocess.run(["git", "ls-files", "-z", "godot/scripts", "godot/wxgame", "server-claude/src",
                          "server-claude/lib", "server-claude/cloudfunctions"],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout.split("\0")
    out = [f for f in out if re.search(r"\.(gd|js)$", f) and "node_modules" not in f and f not in SKIP]
    def key(f):
        if f == "godot/scripts/main.gd":
            return (0, f)
        if f.startswith("godot/scripts/"):
            return (1, f)
        if f.startswith("godot/wxgame/"):
            return (2, f)
        if f.startswith("server-claude/src/") or f.startswith("server-claude/lib/"):
            return (3, f)
        return (4, f)
    return sorted(out, key=key)


def strip_gd(text):
    """GDScript：# 到行尾是注释（字符串里的 # 不算）；三引号字符串原样留着。"""
    out, i, n = [], 0, len(text)
    buf = []
    while i < n:
        c = text[i]
        if text.startswith('"""', i) or text.startswith("'''", i):
            q = text[i:i + 3]
            j = text.find(q, i + 3)
            j = n if j < 0 else j + 3
            buf.append(text[i:j]); i = j; continue
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            buf.append(text[i:j + 1]); i = j + 1; continue
        if c == "#":
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        buf.append(c); i += 1
    return "".join(buf)


def strip_js(text):
    """JS：// 和 /* */ 是注释；字符串、模板串、正则字面量里的不算。"""
    buf, i, n = [], 0, len(text)
    prev = ""   # 上一个不是空白的字符，判断 / 是除号还是正则
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            j = text.find("\n", i); i = n if j < 0 else j; continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2); seg = text[i:n if j < 0 else j + 2]
            buf.append("\n" * seg.count("\n")); i = n if j < 0 else j + 2; continue
        if c in "\"'`":
            j = i + 1
            while j < n and text[j] != c and (c == "`" or text[j] != "\n"):
                j += 2 if text[j] == "\\" else 1
            buf.append(text[i:j + 1]); i = j + 1; prev = c; continue
        if c == "/" and (prev == "" or prev in "(,=:[!&|?{};+-*%<>~^" or buf and "".join(buf[-7:]).rstrip().endswith("return")):
            j, cls = i + 1, False
            while j < n and text[j] != "\n":
                if text[j] == "\\":
                    j += 2; continue
                if text[j] == "[":
                    cls = True
                elif text[j] == "]":
                    cls = False
                elif text[j] == "/" and not cls:
                    break
                j += 1
            j += 1
            while j < n and text[j].isalpha():
                j += 1
            buf.append(text[i:j]); i = j; prev = "/"; continue
        buf.append(c)
        if not c.isspace():
            prev = c
        i += 1
    return "".join(buf)


def width(s):
    return sum(2 if ord(ch) > 0x2E7F else 1 for ch in s)


def wrap(line):
    out, cur, w = [], "", 0
    for ch in line:
        cw = 2 if ord(ch) > 0x2E7F else 1
        if w + cw > COLS:
            out.append(cur); cur, w = "", 0
        cur += ch; w += cw
    out.append(cur)
    return out


def rows():
    allrows = []
    for f in files():
        text = open(os.path.join(ROOT, f), encoding="utf-8").read()
        text = strip_gd(text) if f.endswith(".gd") else strip_js(text)
        for line in text.split("\n"):
            line = line.replace("\t", "    ").rstrip()
            if not line.strip():
                continue
            for pat, rep in MASKS:
                line = pat.sub(rep, line)
            allrows.extend(wrap(line))
    return allrows


def page_html(no, chunk):
    body = "".join('<div class="r">%s</div>' % (html.escape(r) or "&nbsp;") for r in chunk)
    return ('<section class="pg"><header><span>%s</span><span>%d</span></header>%s</section>'
            % (TITLE, no, body))


def main():
    out_dir = sys.argv[1]
    allrows = rows()
    total_pages = (len(allrows) + ROWS - 1) // ROWS
    if total_pages <= PAGES * 2:
        picked = [allrows[k:k + ROWS] for k in range(0, len(allrows), ROWS)]
    else:
        head = allrows[:PAGES * ROWS]
        tail_start = len(allrows) - PAGES * ROWS
        tail = allrows[tail_start:]
        picked = [head[k:k + ROWS] for k in range(0, len(head), ROWS)] + [tail[k:k + ROWS] for k in range(0, len(tail), ROWS)]
    css = """
@page { size: A4 portrait; margin: 12mm 14mm 12mm 14mm; }
body { margin: 0; font-family: Menlo, "PingFang SC", "STHeiti", monospace; font-size: 8pt; color: #000; }
.pg { page-break-after: always; break-after: page; }
.pg:last-child { page-break-after: auto; break-after: auto; }
header { display: flex; justify-content: space-between; font-family: "PingFang SC", "STHeiti", sans-serif; font-size: 9pt;
         border-bottom: 0.5pt solid #000; padding-bottom: 1.5mm; margin-bottom: 3mm; }
.r { height: 4.5mm; line-height: 4.5mm; white-space: pre; overflow: hidden; }
"""
    doc = ('<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>%s 源代码</title><style>%s</style></head><body>%s</body></html>'
           % (TITLE, css, "".join(page_html(i + 1, c) for i, c in enumerate(picked))))
    os.makedirs(out_dir, exist_ok=True)
    open(os.path.join(out_dir, "源代码.html"), "w", encoding="utf-8").write(doc)
    print("总行数（去注释、空行、折行后）%d，合 %d 页；出了 %d 页" % (len(allrows), total_pages, len(picked)))
    print("每页行数：", sorted(set(len(c) for c in picked)))


if __name__ == "__main__":
    main()
