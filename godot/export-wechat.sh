#!/bin/zsh
# 导出微信小游戏到 ../wechat-build/
# 插件默认读 GitHub latest 版本表，那份表格式不对，会找不到模板；这里固定到 4.7 版。
# 模板（约 11MB）第一次会下载到 Godot 的项目缓存：
#   ~/Library/Application Support/Godot/app_userdata/苏七镇奇缘/toolkit/templates/
set -e
setopt null_glob   # zsh 里通配符没匹配到会直接报错退出，这里让它当作空
cd "$(dirname "$0")"
export TOOLKIT_RELEASE_PROVIDER=github
export TOOLKIT_RELEASE_OWNER=godothub
export TOOLKIT_RELEASE_REPO=godot-minigame
export TOOLKIT_RELEASE_TAG=4.7
# 默认导调试版（带帧率、日志面板、报错弹窗）；正式上传前用 SUQI_DEBUG=0 ./export-wechat.sh
if [ "${SUQI_DEBUG:-1}" != "0" ]; then PRESET="小游戏调试"; else PRESET="小游戏"; fi
# 每次从空目录导出：插件不会覆盖已有文件，旧文件留着会让结果对不上
rm -rf ../wechat-build
mkdir -p ../wechat-build
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "$PRESET" ../wechat-build/suqi.bin

# 插件（3 月版）把游戏包写成 engine/demo-pck.bin，4.7 模板却去读 engine/empty-tips.bin（模板自带的示例）。
# 这里改成读我们的包，并删掉示例包和我们用不到的分包示例。
cd ../wechat-build
[ -f engine/demo-pck.bin ] || { echo "没有找到 engine/demo-pck.bin，导出失败" >&2; exit 1; }
sed -i '' "s#const pack = '/engine/empty-tips.bin';#const pack = '/engine/demo-pck.bin';#" engine/game.js
grep -q "demo-pck.bin" engine/game.js || { echo "engine/game.js 没改成功" >&2; exit 1; }
rm -rf engine/empty-tips.bin subpackages subpacks .godot-subpack-managed.json .eslintrc.js images/*.import ./*.md
python3 - <<'PY'
import json
p = "game.json"
d = json.load(open(p, encoding="utf-8"))
d["subpackages"] = [s for s in d.get("subpackages", []) if s.get("name") == "engine"]
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=4)
p = "project.private.config.json"   # 模板里写的是 minigame4.7，会盖掉我们的项目名
d = json.load(open(p, encoding="utf-8"))
d["projectname"] = "suqi-town"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
# 转发：打开右上角「转发」，卡片带分享人 id（wxgame/share.js）
cp ../godot/wxgame/share.js .
cp ../godot/wxgame/share.jpg images/share.jpg
printf "import './share'\n" | cat - game.js > game.js.tmp && mv game.js.tmp game.js
# 登录：一启动就调 login 云函数拿 openid（wxgame/cloud.js）
cp ../godot/wxgame/cloud.js .
printf "import './cloud'\n" | cat - game.js > game.js.tmp && mv game.js.tmp game.js
# 调试弹窗：手机上显示启动日志和报错。要排在最前面，才能收到后面所有脚本的日志
if [ "${SUQI_DEBUG:-1}" != "0" ]; then
    cp ../godot/wxgame/debug-console.js .
    sed -i '' "s/__SUQI_BUILD__/$(date +%m%d-%H%M)/" debug-console.js   # 版本号＝导出时间
    printf "import './debug-console'\n" | cat - game.js > game.js.tmp && mv game.js.tmp game.js
    echo "调试版：已加帧率、日志面板和报错弹窗"
fi
echo "导出完成：$(pwd)"
du -sh . engine/demo-pck.bin
