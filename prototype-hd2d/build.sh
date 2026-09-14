#!/bin/sh
# 用法：
#   ./build.sh         拼出 index.html（本地打开）和 artifact.html（发布成 Claude 网页），Three.js 从 jsDelivr 加载
#   ./build.sh share   打出 share/index.html：Three.js 打包进文件，不连任何国外服务器，收起调试面板，给朋友看
cd "$(dirname "$0")"
SRC="src/10-core.js src/20-pixel.js src/25-facades.js src/30-sprites.js src/40-kit.js src/45-layout.js src/46-town.js src/50-nav.js src/55-actors.js src/60-render.js src/70-ui.js"

if [ "$1" = "share" ]; then
  ESBUILD="${ESBUILD:-/Users/kayra_ayu/Desktop/红缘大冒险/回到那一天/node_modules/@esbuild/darwin-arm64/bin/esbuild}"
  mkdir -p .build share
  cat $SRC | sed "s#from 'three/addons/#from '../vendor/three/examples/jsm/#" > .build/entry.js
  "$ESBUILD" .build/entry.js --bundle --format=iife --target=es2017,safari12 --minify \
    --alias:three=./vendor/three/build/three.module.js --outfile=.build/app.js --log-level=warning || exit 1
  python3 - <<'PY'
import re
head = open("src/00-head.html", encoding="utf-8").read()
head = re.sub(r'<link rel="preconnect"[^>]*>\n', '', head)
head = re.sub(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com[^>]*>\n', '', head)
head = re.sub(r'<script type="importmap">.*?</script>\n?', '', head, flags=re.S)
head = head.replace('</style>', '  [data-dev]{display:none!important}\n</style>', 1)
app = open(".build/app.js", encoding="utf-8").read().replace("</script", "<\\/script")
out = ('<!doctype html>\n<html lang="zh-CN">\n<head>\n<meta charset="utf-8">\n'
       '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
       '</head>\n<body>\n' + head + '\n<script>\n' + app + '\n</script>\n</body>\n</html>\n')
open("share/index.html", "w", encoding="utf-8").write(out)
ext = sorted(set(re.findall(r'https?://[a-zA-Z0-9.\-]+', out)))
print("share/index.html", len(out.encode("utf-8")), "bytes; external hosts referenced:", ext)
PY
  exit 0
fi

{ cat src/00-head.html; echo '<script type="module">'; cat $SRC; echo '</script>'; } > artifact.html
{ printf '<!doctype html>\n<html lang="zh-CN">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>\n<body>\n'; cat artifact.html; printf '\n</body>\n</html>\n'; } > index.html
echo "built: $(wc -c < index.html) bytes"
