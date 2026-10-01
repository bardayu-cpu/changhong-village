#!/bin/zsh
# 跑客户端全部 headless 测试：zsh godot/tools/run_tests.sh <godot 目录>（02 用了一路，10/2 换窗口前放进仓库）
# 每个 test_*.gd 最后一行 RESULT PASS、而且日志里没有 Parse Error / Compile Error / Failed to load script 才算过
# （只看 RESULT 会被骗：脚本编译挂了也可能打出 PASS）。test_map.gd 本来就没有 RESULT 行，它「FAIL」是正常的
cd "$1"
G=/Applications/Godot.app/Contents/MacOS/Godot
D=$(mktemp -d)
pass=0; fail=0; failed=""
for f in tools/test_*.gd; do
  n=$(basename $f)
  $G --headless --path . --script res://$f > "$D/$n.log" 2>&1
  if grep -q "^RESULT PASS" "$D/$n.log" && ! grep -q "^RESULT FAIL" "$D/$n.log" && ! grep -aq "Parse Error\|Compile Error\|Failed to load script" "$D/$n.log"; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); failed="$failed $n"
    echo "=== FAIL $n"; grep -a "不行\|SCRIPT ERROR\|RESULT\|Parse Error" "$D/$n.log" | head -15
  fi
done
echo "PASS $pass FAIL $fail$failed  (logs $D)"
