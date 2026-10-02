#!/bin/zsh
# 截图专用环境：一条命令把固定的 worktree（.claude/worktrees/shot）更新到指定提交、跑完导入、核过导入，再截一张（00 10/2 批、01 E 派）。
# 用法见 godot/tools/截图环境-用法.md。
#   zsh godot/tools/shot.sh <提交> --out=图.png [--rect=x,y,w,h] [--zoom=1] [--people=0] [--ui=0] [--hall=55] [--feast=] [--fx=feast|entry|toast] [--fx_t=1.0]
#   zsh godot/tools/shot.sh <提交> --prepare-only        只更新、导入、核，不截
# 导入没跑完（Scan thread aborted、有图没有 .import、.import 指的导入结果不在）→ 报错退出 2，不截（免得拿空厅截图）。
# 截图脚本 shot_canvas.gd 用这份仓库里最新的（拷进 worktree），所以老提交也能截。
set -u
HERE=${0:A:h}
# 仓库根：照 git 的公共目录找，从哪个 worktree 里跑都落到同一个（主仓库）的 .claude/worktrees/shot
REPO=$(cd "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)
W="$REPO/.claude/worktrees/shot"
G=${SUQI_GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}   # 测「导入不全会报错」时可以换成假的
[ $# -ge 1 ] || { echo "用法：zsh godot/tools/shot.sh <提交> --out=图.png [...]"; exit 64; }
REV=$(git -C "$REPO" rev-parse --verify --quiet "$1^{commit}") || { echo "SHOT FAILED 认不出提交 $1"; exit 64; }
shift

# 1. worktree：没有就建；有就清掉本地改动、切到这个提交（.godot 导入缓存是 git 不管的，留着，下次快）
if [ ! -d "$W" ]; then
  git -C "$REPO" worktree add --detach "$W" "$REV" >/dev/null 2>&1 || { echo "SHOT FAILED 建不了 worktree $W"; exit 2; }
elif [ "$(git -C "$W" rev-parse HEAD)" != "$REV" ]; then
  # 只有换提交才清：同一个提交再截，导入生成的 .import（提交里没带的）要留着，清掉了图就没了（10/2 礼物堆截不出来就是这么丢的）
  git -C "$W" reset -q --hard && git -C "$W" clean -qfd && git -C "$W" checkout -q --detach "$REV" || { echo "SHOT FAILED 切不到 $REV"; exit 2; }
fi
STAMP="$W/godot/.godot/shot_ready"

# 2. 导入：这个提交没导过、上回没导完、或者导入结果对不上了（每次截之前都核一遍，核不过就重导）
if [ "$(cat "$STAMP" 2>/dev/null)" = "$REV" ] && ! python3 "$HERE/shot_import_check.py" "$W/godot" >/dev/null 2>&1; then
  echo "导入结果对不上了，重导"
  rm -f "$STAMP"
fi
if [ "$(cat "$STAMP" 2>/dev/null)" != "$REV" ]; then
  rm -f "$STAMP"
  LOG="$W/godot/.godot/shot_import.log"
  mkdir -p "$W/godot/.godot"
  echo "导入 ${REV:0:7}（600 秒）…"
  "$G" --headless --editor --quit-after 600 --path "$W/godot" > "$LOG" 2>&1
  if grep -aq "Scan thread aborted" "$LOG"; then
    echo "SHOT FAILED 导入没跑完：Scan thread aborted（日志 $LOG）"; exit 2
  fi
  python3 "$HERE/shot_import_check.py" "$W/godot" || exit 2
  echo "$REV" > "$STAMP"
fi

[ "${1:-}" = "--prepare-only" ] && { echo "SHOT READY ${REV:0:7} $W"; exit 0; }

# 3. 截：shot_canvas.gd 用这份仓库最新的
cp "$HERE/shot_canvas.gd" "$W/godot/tools/shot_canvas.gd"
OUT=""
ARGS=()
for a in "$@"; do
  case "$a" in
    --out=*) OUT="${a#--out=}"; OUT="${OUT:A}"; ARGS+=("--out=$OUT") ;;
    *) ARGS+=("$a") ;;
  esac
done
[ -n "$OUT" ] || { echo "SHOT FAILED 没给 --out="; exit 64; }
mkdir -p "${OUT:h}"
"$G" --path "$W/godot" --resolution 540x960 --script res://tools/shot_canvas.gd -- "${ARGS[@]}" 2>&1 | grep -a "SHOT "
[ -f "$OUT" ] || exit 1
