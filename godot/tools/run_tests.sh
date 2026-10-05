#!/bin/zsh
# 跑客户端全部 headless 测试：zsh godot/tools/run_tests.sh <godot 目录>（02 用了一路，10/2 换窗口前放进仓库）
# 每个 test_*.gd 最后一行 RESULT PASS、而且日志里没有 Parse Error / Compile Error / Failed to load script 才算过
# （只看 RESULT 会被骗：脚本编译挂了也可能打出 PASS）。
# 文件头写一行「## 跳过：原因」的测试这一轮不跑、单独数成 SKIP（测试写在游戏前头、等对应的东西合进来再删这一行；跳过的会在最后一行列出来，不算 PASS）。
# （10/5 以前 test_map.gd 在这里「FAIL」是正常的——它其实是打印宴会厅格子的小工具，不是测试，已改名 dump_hall12_grid.gd）
cd "$1"
G=/Applications/Godot.app/Contents/MacOS/Godot
D=$(mktemp -d)
pass=0; fail=0; skip=0; failed=""; skipped=""
for f in tools/test_*.gd; do
  n=$(basename $f)
  sk=$(grep -a -m1 '^## 跳过：' "$f" | sed 's/^## 跳过：//')
  if [ -n "$sk" ]; then
    skip=$((skip+1)); skipped="$skipped $n"; echo "=== SKIP $n（$sk）"
    continue
  fi
  # 每个测试最多跑 5 分钟：测试脚本中途报错常常就停在那儿不退出，整套会一直挂着（10/2 test_relatives 就挂过）。
  # 个别本来就长的测试在文件头写一行「## 时限：秒数」可以放宽（10/5：走路类测试拆小了，最长的后厅那份机器忙时可能超 5 分钟，写了 900）
  lim=$(grep -a -m1 '^## 时限：' "$f" | grep -o '[0-9]*' | head -1)
  perl -e 'alarm shift; exec @ARGV' ${lim:-300} $G --headless --path . --script res://$f > "$D/$n.log" 2>&1
  if grep -q "^RESULT PASS" "$D/$n.log" && ! grep -q "^RESULT FAIL" "$D/$n.log" && ! grep -aq "Parse Error\|Compile Error\|Failed to load script" "$D/$n.log"; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); failed="$failed $n"
    echo "=== FAIL $n"; grep -a "不行\|SCRIPT ERROR\|RESULT\|Parse Error" "$D/$n.log" | head -15
  fi
done
echo "PASS $pass FAIL $fail SKIP $skip$failed$([ -n "$skipped" ] && echo "（跳过：$skipped）")  (logs $D)"
