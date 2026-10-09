# 阿鱼家 v3

入口仍为工程根目录 `打开阿鱼家.command`，它以 `--ayu-home --ayu-test` 启动。不带参数的工程入口仍是婚宴。v3 由 `ayu_home/home.tscn` 加载；v2 保留供差异核查。

本版包含 26 个独立位置、87 个物件互动、56 条有方向的门连接。地图分一楼、二楼、屋外，卡片可直接到每处。走动用点地面或 WASD / 方向键；走近门自动过门，也可点门气泡。E 操作最近物件，M 打开地图，Esc 退出玩法，F2 打开电脑测试面板。

## 素材与风格

用户 2026-10-04 最新补充要求：补充画面须有外观图那样的明显像素颗粒，不能写实。鱼缸、电视背景已按该参照重新处理；所有场景最近邻采样。三只猫分别为灰虎斑求求、橘虎斑落落、金色长毛天天；四只宠物用 64×64 图集，脚点 y=62。

`tools/build_home.py` 是整数坐标拆图、隔离房间、补地板、生成门和互动数据的可复现脚本。它读取同级参考图文件夹和本版保留的生成源图。`assets/rooms.json` 是入口索引；每间独立 JSON 含源图裁框、偏移、物件脚点、阻挡、门位置与可行走接近点。

**一楼使用清晰化重构图，不能冒称原图逐像素复原。** `evidence/clarity-comparison.json`、前后对照和差异图记录颜色变化。房间拆层与实际 Godot 渲染另在 `evidence/restore-check.json` 核对；“素材拼回一致”和“符合原始定稿”是两项独立结果。

院门蓝衣人和二楼标注仅在 `allowed-edit-mask-*.png` 内替换。完整生成候选留存溯源，正式导出排除候选。`asset-provenance.json` 记录来源。其余细看图尚未进入定稿文件夹，当前为可拖动平面裁景占位；仅书桌使用用户提供的正式特写。一家三口按第零节许可保留代码角色。

## 验证

在工程根目录执行，Godot 路径可替换为对应机器安装位置：

```sh
python3 godot/ayu_home/v3/tools/build_home.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://ayu_home/v3/tests/test_routes.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://ayu_home/v3/tests/test_playthrough.gd -- --ayu-test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://ayu_home/v3/tests/test_cloud_assets.gd
/Applications/Godot.app/Contents/MacOS/Godot --path godot --script res://ayu_home/v3/tests/capture_suite.gd -- --ayu-test
/Applications/Godot.app/Contents/MacOS/Godot --path godot --script res://ayu_home/v3/tests/capture_restore.gd
python3 godot/ayu_home/v3/tools/restore_check.py
zsh godot/tools/run_tests.sh godot
```

截图套件覆盖 540×960 与 1170×2532（逻辑 540×1168）。本轮没有真实手机触屏或微信线上验证，不把桌面等比例渲染叫作手机实测。跨房间测试用实际 AStar 路线和移动、门触发逻辑，等待真实淡入完成；小玩法通过 `InputEventScreenTouch` 操作控件。

`test_build57_walk.gd` 和 `test_build60_walk.gd` 自身最长 580 秒，回归脚本外层时限由 300 调整为 620 秒；没有改这些测试断言。电脑测试面板要求 `--ayu-test` 且 `OS.is_debug_build()`，正式版隐藏。

## 大素材下载

`assets/manifest.json` 记录运行素材字节数及 SHA-256。`cloud_assets.gd` 使用既有认证 bridge 的 `@fetchChunks`，下载临时文件、核对大小和哈希、原子改名、复用离线缓存。调用方提供真实云 fileID；本版不编造云配置、不自动上传。桌面默认读本地素材。云通道以本地 fixture 覆盖断网、损坏、错误哈希、重试和缓存；尚未验证真实云端服务。

## 仍需如实验收的限制

原图没有明确连通口的浴室、后门等采用逻辑连接，不能声称所有门在原画中都一一成立。部分小房间延伸仍能辨认裁景边界，不满足“完全看不出接缝”；延伸区用于填充视野，可行走区域仍以原平面图为主。清晰重构的颜色容差不通过。这些在交付单中直接标为没过，最终是否满意由阿鱼试玩和 Claude 验收。
