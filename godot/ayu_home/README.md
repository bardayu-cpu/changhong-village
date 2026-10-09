# 阿鱼家的日常

从院门走近正门，敲门等家人邀请。进屋后点地面散步，点亮点走近物件；「屋内导览」可以选择房间里的目的地。「看全景 / 走近看」切换镜头，「生活册」保存自己的游玩记录与文字。

- 家庭作息跟随设备当地时间。三餐 07:30–08:15、12:00–13:00、18:00–19:00；09:00–10:00 全家外出，仍可在院外及后园玩。
- 一楼：餐桌、厨房、三只猫、麻将小聚、电视、唱片、喂鱼、工具台、相册、爸妈卧室与家务。
- 二楼：吉他原创小曲、书架九格拼图、电脑、阅读、阿鱼卧室、露台；客房大床可以躺下，点「起身，继续散步」回来。
- 喜多住在院外小窝，会散步嗅闻。
- 果园按真实月份换四季画面与物种。三块菜畦可选当季种子、浇水，真实 60 秒成熟；离开后继续生长，再回来采收。果树分别观花或采果；菜篮和进度保存在本机，不涉及钱。
- 所有生活安排与未提供的日常情节都是游戏创作，不作为真人经历。

## 本地运行

双击工程根目录 `打开阿鱼家.command`。本机使用 `/Applications/Godot.app/Contents/MacOS/Godot`。也可运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot -- --ayu-home
```

普通启动仍进入苏七原有婚宴。阿鱼家开发入口独立，`home.tscn` 可由上层地图接入。主人身份由 `set_identity(true)` 设置；上层须使用已验证的身份。命令行 `--ayu-owner=true` 仅用于开发验收。

## 测试与证据

`zsh godot/ayu_home/run_qa.sh` 跑家庭/导航、小游戏/果园、最终角色图集、资源缓存和触屏集成五组专项。`tests/test_garden_live.gd` 单独实际等待 61 秒验证离线成长。项目回归：`zsh godot/tools/run_tests.sh "$PWD/godot"`。

`evidence/runtime_final/` 是最终 1024×768 世界的截图及旁置状态 JSON；`evidence/actors_*` 是最终角色动作；`evidence/activities_*` 是手机小游戏界面；`evidence/ayu-home-demo.mp4` 是 Godot 实际录制的演示。`evidence/superseded/` 内的图为过程资料，不用于最终验收。

截图命令示例：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --script res://ayu_home/tests/capture_home.gd -- --ayu-render-size=1170x2532 --ayu-area=floor1 --ayu-hour=12.5 --ayu-month=10 --ayu-focus=meal --ayu-screenshot=/private/tmp/ayu-meal.png --ayu-capture-exit --ayu-save=/private/tmp/ayu-shot-save.json
```

## 素材与接入

`asset_manifest.json` 列出 11 张最终 PNG 的尺寸、字节数与 SHA-256。`asset_store.gd` 先验证本地/内容哈希缓存，再使用项目已有 `@fetchChunks` / `@fetchFile` 微信桥下载，完整校验后原子替换缓存；断网、坏文件会出现重试与返回入口。

两个小游戏导出预设均排除 `ayu_home/assets/*`、验收文件与测试脚本，只含代码和小清单。远程发布时，将同名 PNG 上传到现有项目云存储，把真实 `file_id` 写进清单。清单当前留空，不伪造线上地址。本地画面、下载桥接口与模拟网络分支已测；真实云下载、完整主包 ≤4MB、微信设备性能仍由主项目发布验收确认。

世界逻辑尺寸 1024×768；人站立实物高 84px、脚点为坐标原点；地图按定稿的俯视示意投影保留。横向主要家具量尺 12 项无红项、4 项黄项；这不是建筑测绘图，未把示意纵深宣称为严格 32px/m。
