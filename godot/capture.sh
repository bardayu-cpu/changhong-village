#!/bin/sh
# 开发用：在后台打开游戏窗口，按指定步骤截图，不抢前台焦点
# 用法：./capture.sh 输出目录 title nick avatar clip arrive walk couple leave end stick share
# 横屏对照图：RES=1280x720 ./capture.sh 输出目录 overview
RES="${RES:-540x960}"
cd "$(dirname "$0")"
OUT="$1"; shift
mkdir -p "$OUT"
for shot in "$@"; do
  rm -f "$OUT/$shot.png"
  open -g -W -n -a /Applications/Godot.app --args --path "$(pwd)" --resolution "$RES" -- --capture="$OUT" --shot="$shot"
  [ -f "$OUT/$shot.png" ] && echo "ok $shot" || echo "FAIL $shot"
done
