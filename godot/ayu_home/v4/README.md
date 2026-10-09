# 阿鱼家 v4

入口为 `../home.tscn`，默认婚宴入口不变。在工程根目录双击 `打开阿鱼家.command` 打开电脑试玩版。开发环境为 Godot 4.7.2；这里不是独立的 Steam 安装包。晚间补充已并入：恢复已认可的 v3 清晰底图，统一较粗颗粒的像素风；短面板贴合内容，长页滚动，新增纸张来信、日历和家人人物卡。与最初软原稿的色差限制未通过，见原稿/已认可底图两份独立审计。

## 操作与生活

点地面走路，走近气泡再操作；也能用方向键或 WASD 走、E 操作、M 地图、J 生活册、C 拍立得、Esc 收起。地图到各房门口，普通走路用实际门槛判断。

第一次到访可以先看「今日小事」；三位家人的请求会带路。二楼客房点床可以留宿，饭点在家的家人会邀请下楼。客人的进度按玩家 ID 单独保存，存档损坏时尝试上一份备份。

种子每季一包，当季蔬菜 2–4 小时、花 4 小时、果树 3 天。只按真实秒数生长，离线也长；不腐烂，不扣东西。收成留种，蔬菜进入饭桌菜单，花可插瓶，果子可吃和分享。电脑「试玩」切季节和天气仅用于看表现，不推进生长。

拍立得存地点、形象、姿势、在场人物、天气与摆设状态；翻相册时重画同一时刻，不读取 GPU 截图，不使用摄像头。支持 Roman `gpt_look(preset)` 形象。镇入口接入时在实例的 `town_profile` 或 SceneTree 根节点元数据 `player_profile` 传 `{id, avatar}`；本电脑独立入口首次生成本地 ID 并保存选定形象。

## 维护与验证

- `tools/build_world.py`：27 区域几何和交互数据，修改后用 `tools/bake_navigation.gd` 重新生成 `.nav`。
- `tools/make_manifest.py`：图、导航、声音的长度和 SHA-256。
- `tests/test_navigation.gd`、`tests/test_walk_actions.gd`、`tests/test_ground_doors.gd`：连通、所有操作及普通走路过门。保持生产的门判定，没有 999 冷却。
- `tests/test_life.gd`、`tests/test_feedback.gd`：真实时间语义、持久化隔离、损坏恢复、开关与声音收尾。
- `tests/play_gestures.gd`：实际输入事件完成全部小游戏。`harvest-*` 段使用单独测试存档时钟检查成熟状态，正式游戏没有加速功能。
- `tests/story_play.gd`：第一次到访、入住、邀请和 30 分钟连续实时时间遍历。`-- --story-flow-only` 可独立复测最后 UI 流程；不覆盖 30 分钟报告。
- `tests/capture_validation.gd`：27 区域、两种竖屏、昼夜季节的实际渲染。
- `tools/check_restoration.py`：与最新定稿的原坐标对照，单列已批准去字区域。
- `tools/make_clips.py`：把实际操作帧序列合为 GIF。GIF 是加速回顾，无音轨；真实时间、断言结果以 JSON 和日志为准。

运行 GDScript 测试：`Godot --headless --path godot --script res://ayu_home/v4/tests/test_life.gd`。图像与手势录制须去掉 `--headless`。全工程回归仍为原来的 `zsh godot/tools/run_tests.sh godot`，未修改它的断言或测试范围。

## 云素材与包体

`cloud_assets.gd` 支持调用方经已有认证桥下载、校验、缓存与离线重用；本地启动使用随包文件。接云端时由主工程提供真实 fileID，不内置或上传线上数据。v2/v3 依赖维持原工程资源布局，v4 新资源清单在 `assets/manifest.json`。

发布预设排除证据、测试脚本、生成工具与原始帧。微信主包和 engine 分包的实测大小见 `evidence/package-audit.json`；桌面触屏模拟不能代替微信真机或 Steam 平台验收。

图像、声音与头像处理方式见 [ART_SOURCES.md](ART_SOURCES.md)。本轮安装并使用的三个纯文字 skills 在 `evidence/skills.json` 中记录校验值。
