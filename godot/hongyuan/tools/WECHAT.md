# 红缘大冒险：微信真机候选

在干净工作区用 Godot 4.7.2 导出。微信 AppID 来自 `红缘微信` 预设，导出器会核对实际生成的配置。

```sh
python3 godot/hongyuan/tools/export_wechat.py <新小游戏目录> \
  --cloud-output <另一个新目录> \
  --cloud-prefix 'cloud://<环境>.<存储桶>/hongyuan/content/'
```

小游戏目录包括主包 `love.bin`、引擎、山庄、村子及两地共用的代码分包。大图和音频按爱情篇章节或目的地加载，共用图只加载一次。云目录与小游戏工程分开，不会计入微信代码包。文件名带内容哈希；同名文件可复用。导出器按文件实际字节数检查主包小于 4 MB、总包小于 20 MB，为不同账号的额度留余量。

把云目录内的所有 `.bin` 放进配置所指的同一个云目录。该小游戏账号必须能读取这些对象。保留 `manifest.json` 作交付校验，它记录源码 SHA、各文件字节数与 SHA-256。先确认云对象可读，再导入小游戏目录生成预览码。

本地可直接用桌面 Godot 加载拆出的包，测试脚本会校验云资源文件、序章入口、各章 BGM 流、原宴会厅、村子和正常入口续玩：

```sh
candidate="/绝对路径/小游戏目录"
cloud="/绝对路径/云目录"
smoke_home="$(mktemp -d /tmp/hongyuan-wechat-smoke.XXXXXX)"
HOME="$smoke_home" /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$candidate" --main-pack "$candidate/love.bin" \
  --script "$PWD/godot/hongyuan/tests/wechat_pack_smoke.gd" -- "$candidate" "$cloud"
```

真机预览从微信扫一扫进入，先用空存档，从序章走到终章、入席、进村。用同一部手机分别检查章节背景乐可听、切后台后恢复、从微信退出并重进后续玩。记录手机型号、微信版本、包 SHA 和测试结果。真机通过后才上传体验版。
