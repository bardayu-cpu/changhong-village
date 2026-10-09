#!/bin/zsh
# 云桥两头一起测：Godot 这边拆名字，node 那边（wxgame/cloud.js）还原成请求。
# 两个 RESULT 都是 PASS 才算过。
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/suqi_bridge_names.json"
echo "=== Godot 这边 ==="
SUQI_BRIDGE_OUT="$OUT" /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/test_bridge.gd
echo "=== JS 那边（回放）==="
node tools/replay_bridge.js "$OUT"
