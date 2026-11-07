#!/bin/bash
# 跑 hongyuan/tests 下全部 *_test.gd 和 scenes_walkthrough.gd。
# 用法：GODOT=/path/to/godot ./run_all.sh   （需先在 godot 目录 godot --headless --import 一次；Linux 无显示器时用 xvfb-run）
# fishing_touch、skip 只打印过程（没有 PASS/FAILURES 行），这两个只检查有没有脚本报错。
# 退出码：有任何测试 FAILURES 非 0 或脚本报错即为 1。
cd "$(dirname "$0")/../.." || exit 1
GODOT=${GODOT:-godot}
RUN=""; command -v xvfb-run >/dev/null && [ -z "$DISPLAY" ] && RUN="xvfb-run -a"
bad=0
for t in hongyuan/tests/*_test.gd hongyuan/tests/scenes_walkthrough.gd; do
  out=$(timeout 300 $RUN "$GODOT" --path . -s "res://$t" -- /tmp/hongyuan_shots 2>&1)
  if echo "$out" | grep -qE "^FAILURES [1-9]|^SHOTS [0-9]+ FAILS [1-9]|SCRIPT ERROR|Parse Error"; then
    echo "FAIL $t"; echo "$out" | grep -E "^ERROR: [A-Z]|^FAIL|SCRIPT ERROR|Parse Error" | grep -v "godot-minigame\|status < 0" | head -5; bad=1
  else echo "ok   $t"; fi
done
exit $bad
