#!/bin/zsh
set -eu
VILLAGE_ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
exec /usr/bin/python3 "$VILLAGE_ROOT/候选/试玩收尾-1028/serve_web.py"
