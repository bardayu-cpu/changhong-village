# 阿鱼家 v2 · 原画还原三处样板

正式范围：门前院子、客厅、餐厅。以 2026-10-04「紧急更正—原画还原」及用户最新指示为准。场景直接来自「七缘地图2-裳泓村参考图/定稿形象图」当前三张房屋原图；不重新设计场景，不重画家具，不换颜色。代码绘制只用于人物、宠物及光影/粒子等叠加效果。

## 开工及交付前

先重新打开定稿文件夹里的三张图，再运行：

```sh
python3 godot/ayu_home/v2/tools/check_references.py
```

它核对实际文件路径、尺寸及 SHA-256；任何文件被替换都会失败，必须重新拆层、改坐标、验收。不能用旧的图片名或历史截图当定稿。当前院子和一楼均无标注文字。二楼原图已替换到旧资源槽，但二楼玩法和去字不在这次三处样板范围。

## 本机查看

运行工程根目录 `打开阿鱼家.command`，或：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot -- --ayu-home
```

点地面走动；走近物件后点底部动作，或用「看看屋里」选择目的地。访客先敲门；无人时可留便笺。默认启动婚宴，阿鱼家入口隔离。开发截图可加 `--ayu-hour=12.5 --ayu-month=10 --ayu-weather=clear`。主人流程在开发版可加 `--ayu-owner=true`；正式调用方应根据真实认证结果调用 `set_identity(true)`。本样板没有虚构或硬编码阿鱼的账号身份。

三餐为 07:30–08:15、12:00–13:00、18:00–19:00；三人坐在原图餐椅上。09:00–10:00 全家外出，10:00–12:00 爸爸外出，14:00–15:00 妈妈外出。其余卧室、书房、后园暂不连接进 v2。吉他改进保存在共享 `activities.gd`，通过独立触摸测试；本轮三处只有相册/拼图入口。

## 原图拆层

`tools/restore_original.py` 输出 60 件透明层、3 张无透明洞的底图，以及原坐标、脚点、碰撞、可走区域、坐席和交互点。透明掩膜只有 0/255。所有可见零件颜色直接复制原图像素，拼回后逐通道差异 0。所有遮住的底面仅克隆同张图的地面像素；范围见 `evidence/restoration/*-hidden-fill-mask.png` 及 `*-fill-marked.png`。镜头裁在原图场景内，游戏区域填满屏幕，不需要扩画原图之外的区域。

`build_art.py` 只生成代码人物/宠物和声音，然后调用原图拆层；已移除旧的场景绘制函数与修饰脚本。旧重画截图归档在忽略的 `evidence/superseded-repaint/`，不进入交付，不算验收证据。

运行时 `world.gd` 将地面与站立物件分层，按脚点排序遮挡。手机画面只显示一间的局部，由镜头跟随，使用最近邻采样。原图玻璃内部有小幅视差，窗框位置保留；前景盆栽最多移动 1 原图像素。时段色调、暖灯、动态影子、微尘、雨雪/落叶、鱼缸泡泡均在原图上叠加，原文件不改。原图自身已有的光影也保留。

原图中的门口装饰人物同样保留；它属于原图，不是额外生成的家人 NPC。原图没有狗窝，因此不在院子里另画一个；喜多的活动区域位于原图院墙内。

## 自验

```sh
python3 godot/ayu_home/v2/tools/build_art.py
python3 godot/ayu_home/v2/tools/make_proofs.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://ayu_home/v2/tests/test_v2.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://ayu_home/v2/tests/test_touch.gd
```

原生 GPU 截图：`tests/capture_restore.gd`、`capture_suite.gd`、`capture_motion.gd`、`capture_roman.gd`。`capture_restore.gd` 调用真实 World 渲染器，仅在原画对照模式关闭角色/UI/效果，保留原始画布尺寸。原图及实际 Godot 输出用项目 `tools/restore_check.py --game-scale 1 --align 0 --search 0 --pass 12,0,0` 对照。另有直接逐通道最大误差核验；不会只拿 Python 拼合图冒充游戏截图。生活和光影证据单独保存在 `runtime/`、`motion/`。

人物基础图集 1024×168，单格 64×84，脚点 (32,84)；三人四向站立 84 px，基础坐姿 62 px（呼吸第二帧上下 1 px）。生活动作四向两帧。全身定稿只用于对话/身份卡对照。

旧版罗曼通用比例尺结果为：4 绿、1 黄、1 红。原图圆桌宽 133 px，对通用宴会桌 86 px 为 1.55 倍；原图椅高 61 px 对 46 px 为 1.33 倍。不能称这项旧量尺全过；紧急更正要求原图优先，保留原图家具尺寸。

## 数据、发布和边界

生活册只写 `user://ayu_home_life_v2.json` 中的便笺、收藏、小游戏完成状态，不碰钱包、不跳时间。作息和日常对白是虚构，天气是按日确定的游戏天气。相册/拼图采用原图院子，不包含家庭实拍或编造的往事配文。

运行资源在 `assets/manifest.json` 逐项列出大小和哈希，桌面/云缓存 PNG/WAV 按文件读取，发布包使用 Godot 的无损纹理和音频资源读取；资源放引擎分包；测试、证据、生成工具、旧版整图不进发布包。`cloud_assets.gd.ensure_all(bridge, file_ids)` 可在创建场景前预取原图拆件，经文件长度和 SHA-256 校验后放入缓存，支持离线命中、坏缓存重试、失败不加载；测试使用本地模拟桥。旧整图接口也保留。本次未上传或配置任何线上 fileID。

电脑上的触摸事件测试、两种手机尺寸和本地微信导出都不能替代真机微信预览。Claude 收 bundle 后仍需独立回归、确认主人认证接线并出手机预览码；阿鱼确认三处后才扩到全屋。
