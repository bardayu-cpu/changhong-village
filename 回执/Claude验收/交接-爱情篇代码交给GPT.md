# 交接：爱情篇代码从 Claude 交给 GPT 小组（阿鱼 11/06）

阿鱼 11/06 定：**爱情篇的玩法、体验和交互由 GPT 小组接手补齐、跑通**。D2 可以改代码，D4 照旧验收。之前「D2 不写代码」的分工到此作废。

现在的状态：序章一直到终章「入席」都能完整玩下来。冒烟测试 `hongyuan/tests/scenes_walkthrough.gd` 从驾驶跑到入席，结果是 0 失败。

## 一、代码怎么组织

| 文件 | 管什么 |
| --- | --- |
| `godot/hongyuan/player.gd` | 总播放器，按 `chapter_order.json` 的顺序一步步播 `chapters/*.json`。序章、上海、成都是 W1 时 GPT 写的老步骤类型，包括 walk、drive、chat 等 |
| `godot/hongyuan/stage.gd` | 老步骤的绘制。上海两屏的人物身高在 `PEOPLE_HEIGHT` 里调，阿晓的站位在 `_feet()` 里 |
| `godot/hongyuan/scene_runner.gd` | **新的可操控场景**（`type: "scene"`）。负责背景、人物 y 排序、摇杆和点地走路、靠近出互动按钮、对白、转场卡、材料入请柬 |
| `godot/hongyuan/games/*.gd` | 小游戏：drive（俯视驾驶和停车）、fishing、ringtoss、fireworks、call（来电）、mail（Offer 邮件）、finale（写名字、选形象、盖火漆） |
| `godot/hongyuan/chapters/call、shizuoka、hainan、hongkong、finale.json` | 由 `hongyuan/tools/make_chapters.py` 生成。**改这五章就改这个脚本再运行**，不要手改 JSON |
| `godot/hongyuan/copy.json` | 全部文案，按原稿编号引用 |

### scene 的写法（看 make_chapters.py 就懂）
- **布景字段**：`bg`、`walkArea`（多边形）、`start`、`actors`（id、tex、at）、`hotspots`（id、at、snap、face、pose、label 或 icon）。
- **beats 按顺序执行**：
  - `{"narrate": 编号}`：旁白，点一下继续。
  - `{"say": 编号, "who": "ayu|toretto|axiao"}`：人物对白。
  - `{"card": 编号}`：转场卡。
  - `{"go": 热点id, "hint": 编号}`：玩家自己走过去点按钮。
  - `{"game": 名字}`：小游戏。
  - `{"material": "paper|stamp|wax|envelope"}`：材料入请柬。
  - `{"button": 编号}`：等玩家点按钮。
  - 只含布景字段的 beat：立即换景。
- **图的找法**：图名可以写成 `a.png|b.png`，前一个没有就用后一个。路径先找 `assets/<名字>`，再找 `assets/w2/<名字>`；都找不到就画占位，不会报错。

## 二、自测和出包

```
# 冒烟测试（要有显示，云端用 xvfb-run）
godot --path godot -s res://hongyuan/tests/scenes_walkthrough.gd -- <截图目录>

# 新加了运行时按名字加载的图或脚本后，先同步导出清单
python3 godot/hongyuan/tools/sync_export_files.py

# 出 Web 包
godot --headless --path godot --export-release "红缘Web" <目录>/index.html
```

`hongyuan/tools/pack_web_artifact.py` 是 Claude 用来把包放进私密试玩链接的工具。GPT 自己出包测试用不到它。

## 三、Claude 已知但没做完的（请 GPT 接着做）

1. **阿晓画风**和阿鱼对不上，见 `退回-04-阿晓画风.md`。
2. **人物比例**：上海两屏已经按车调到 82 高。其他场景用的是原图尺寸，约 128 高。请 D2 按每屏的参照物（床、长椅、摊位、闸门）逐屏核一遍，做法照 `stage.gd` 里 `_draw_person` 那样按不透明部分量身高。
3. **烟花**还是代码画的点阵，`w2/hainan/firework_*` 那批帧图还没接。
4. **摇杆**还是代码画的圆，`w2/common/joystick_base/knob.png` 没接。
5. **套圈**的木桩坐标是按 `ring_stall.png` 量的，在 `ringtoss.gd` 第一段。换了图要重新量。
6. 成都、上海仍走老步骤（walk 和 chat 类型）。要统一操控手感，可以改写成 scene。
7. **微信包**：导出预设「小游戏」的 include_filter 还缺 `hongyuan/*.json` 和 `hongyuan/chapters/*.json`；export_files 也要照 `sync_export_files.py` 的做法补上 hongyuan 的图和脚本。
8. 对白里的 emoji（😂🤔）字体里没有，需要确认在手机上的显示效果。
9. **终章入席**以后现在是一屏占位文字「婚宴篇 马上开席」，下周接婚宴。

## 四、规则照旧
- 剧情和文案不改，只按原稿编号引用。
- 画风统一走 `回执/W2工位/风格样板.png`。
- 每次推代码都写看板卡，由 D4 来判。
