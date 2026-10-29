#!/bin/zsh
set -eu
VILLAGE_ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
VILLAGE_APP="$VILLAGE_ROOT/发布/试玩收尾-1028/Mac/裳泓村试玩.app"
if [[ ! -f "$VILLAGE_ROOT/发布/试玩收尾-1028/.verified-1028.5" ]]; then
  print '本轮试玩包正在更新或等待核验，暂不打开旧包。'
  read -r '?按回车关闭'
  exit 1
fi
if [[ ! -d "$VILLAGE_APP" ]]; then
  print '尚未找到本轮试玩包。请查看同目录的「试玩说明.md」。'
  read -r '?按回车关闭'
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$VILLAGE_APP/Contents/Info.plist")" != '1028.5' ]]; then
  print '试玩包版本与本轮入口不一致，已停止打开。'
  exit 1
fi
/usr/bin/open "$VILLAGE_APP"
