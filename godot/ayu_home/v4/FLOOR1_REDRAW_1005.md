# 阿鱼家 · 一楼新定稿与小游戏重画 · 2026-10-05

![一楼新定稿重画与二楼原图并排](evidence/floor1-redraw/floor1-floor2.png)

一楼照新定稿重画并接入。采用粗颗粒、最近邻显示：一楼工作网格 724×543；小游戏新背景工作网格 154×188，在 540 宽竖屏中约每格 3 像素。`sharp=false`，未叠加锐化噪点。

基线 `2b7e0cf`；分支 `village/ayu-home-v4-floor1`。旧「统一质感」未混入本次。

## 一楼每间房 · 540×960

### 客厅

![客厅](evidence/floor1-redraw/room-living.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-living.png)

### 餐厅

![餐厅](evidence/floor1-redraw/room-dining.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-dining.png)

### 厨房

![厨房](evidence/floor1-redraw/room-kitchen.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-kitchen.png)

### 卫生间与洗衣

![卫生间与洗衣](evidence/floor1-redraw/room-laundry.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-laundry.png)

### 楼梯旁猫窝走道

![楼梯旁猫窝走道](evidence/floor1-redraw/room-cats.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-cats.png)

### 一楼楼梯

![一楼楼梯](evidence/floor1-redraw/room-stairs1.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-stairs1.png)

### 茶桌与麻将室

![茶桌与麻将室](evidence/floor1-redraw/room-mahjong.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-mahjong.png)

### 爸妈卧室

![爸妈卧室](evidence/floor1-redraw/room-parents.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-parents.png)

### 爸爸的手作房

![爸爸的手作房](evidence/floor1-redraw/room-workshop.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-workshop.png)

### 车库

![车库](evidence/floor1-redraw/room-garage.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-garage.png)

### 东侧过道与次净衣柜

![东侧过道与次净衣柜](evidence/floor1-redraw/room-closet1.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-closet1.png)

### 爸妈卧室浴室

![爸妈卧室浴室](evidence/floor1-redraw/room-bath1.png)

[查看这间房的可走区叠加图](evidence/floor1-redraw/walk-bath1.png)

## 门的表

共 15 对连接，30 个方向均以正常地面过门判定走过。没有修改过门冷却，也没有以直接调用传送函数替代门槛测试。邻接屋外/二楼只验证与一楼相连的门口。

| 从哪里 | 到哪里 | 对应开口 | 结果 |
|---|---|---|---|
| 客厅 | 餐厅 | 餐厅南侧右门 | 双向通过 |
| 客厅 | 楼梯旁猫窝走道 | 猫窝走道南门 | 双向通过 |
| 客厅 | 一楼楼梯 | 楼梯底部 | 双向通过 |
| 客厅 | 东侧过道与次净衣柜 | 客厅东侧过道 | 双向通过 |
| 客厅 | 门前院子 | 客厅南侧外门 | 双向通过 |
| 餐厅 | 厨房 | 餐厅西侧上门 | 双向通过 |
| 餐厅 | 卫生间与洗衣 | 餐厅西侧下门 | 双向通过 |
| 餐厅 | 车库 | 餐厅南侧左门 | 双向通过 |
| 楼梯旁猫窝走道 | 后花园 · 果园 · 菜地 | 猫窝走道北门 | 双向通过 |
| 一楼楼梯 | 二楼楼梯与过道 | 逐级上楼，实测 11 次台阶进度 | 双向通过 |
| 茶桌与麻将室 | 东侧过道与次净衣柜 | 东侧过道北门 | 双向通过 |
| 爸妈卧室 | 东侧过道与次净衣柜 | 东侧过道南门 | 双向通过 |
| 爸妈卧室 | 爸妈卧室浴室 | 卧室浴室门 | 双向通过 |
| 爸爸的手作房 | 门前院子 | 手作房南门 | 双向通过 |
| 车库 | 门前院子 | 车库南门 | 双向通过 |

新定稿的北门位于猫窝走道，因此把后花园现有返回入口的目标从厨房改为猫窝走道。仅改 `garden.json` 的这一对接目标，并清除旧版人工加上的带字门框绘制数据；后花园的底图、碰撞、种植和其他玩法未改。

## 一楼原有玩法的位置与验收

保留全部 53 个固定热点的 ID 与玩法类型；逐个走近、打开并退出。小游戏的手势、按钮、步骤、计时、完成与存档函数均与基线逐函数比对一致。表内“通过”指真实入口与退出验证，不代表新增了玩法。

| 房间 | 物件/动作 | 热点 ID | 入口与退出 |
|---|---|---|---|
| 客厅 | 喂一撮鱼食 | `fish` | 通过 |
| 客厅 | 开关电视 | `tv` | 通过 |
| 客厅 | 坐一会儿 | `sofa` | 通过 |
| 客厅 | 翻开相册 | `album` | 通过 |
| 客厅 | 开关落地灯 | `lamp` | 通过 |
| 客厅 | 坐在这里 | `seat_0` | 通过 |
| 客厅 | 坐在这里 | `seat_1` | 通过 |
| 客厅 | 坐在这里 | `seat_2` | 通过 |
| 餐厅 | 坐下来吃饭 | `meal` | 通过 |
| 餐厅 | 倒一杯温水 | `tea` | 通过 |
| 餐厅 | 翻翻食谱 | `recipe` | 通过 |
| 餐厅 | 照顾桌上的花 | `flowers` | 通过 |
| 餐厅 | 坐在这里 | `seat_0` | 通过 |
| 餐厅 | 坐在这里 | `seat_1` | 通过 |
| 餐厅 | 坐在这里 | `seat_2` | 通过 |
| 餐厅 | 坐在这里 | `seat_3` | 通过 |
| 厨房 | 煮一锅汤 | `stove` | 通过 |
| 厨房 | 开冰箱 | `fridge` | 通过 |
| 厨房 | 洗洗手 | `sink` | 通过 |
| 卫生间与洗衣 | 洗一筐衣服 | `wash` | 通过 |
| 卫生间与洗衣 | 拧开水龙头 | `basin` | 通过 |
| 卫生间与洗衣 | 整理毛巾 | `towel` | 通过 |
| 卫生间与洗衣 | 晾衣 / 收衣 | `drying` | 通过 |
| 楼梯旁猫窝走道 | 猫窝 | `nest` | 通过 |
| 楼梯旁猫窝走道 | 猫抓柱 | `scratch` | 通过 |
| 楼梯旁猫窝走道 | 添水和猫粮 | `bowls` | 通过 |
| 一楼楼梯 | 摸摸木扶手 | `rail` | 通过 |
| 一楼楼梯 | 浇一小杯水 | `plant` | 通过 |
| 一楼楼梯 | 看看小画 | `picture` | 通过 |
| 茶桌与麻将室 | 沏茶 | `tea` | 通过 |
| 茶桌与麻将室 | 坐下聊会儿 | `chair` | 通过 |
| 茶桌与麻将室 | 照顾绿植 | `plant` | 通过 |
| 茶桌与麻将室 | 花纹翻牌 | `pairs` | 通过 |
| 茶桌与麻将室 | 坐在这里 | `seat_0` | 通过 |
| 茶桌与麻将室 | 坐在这里 | `seat_1` | 通过 |
| 茶桌与麻将室 | 坐在这里 | `seat_2` | 通过 |
| 茶桌与麻将室 | 坐在这里 | `seat_3` | 通过 |
| 爸妈卧室 | 开关床头灯 | `lamp` | 通过 |
| 爸妈卧室 | 把被子铺好 | `bed` | 通过 |
| 爸妈卧室 | 听听窗外 | `window` | 通过 |
| 爸爸的手作房 | 磨一只木鸟 | `wood` | 通过 |
| 爸爸的手作房 | 收好工具 | `tools` | 通过 |
| 爸爸的手作房 | 工作台小灯 | `lamp` | 通过 |
| 爸爸的手作房 | 坐在这里 | `seat_0` | 通过 |
| 车库 | 擦一擦车窗 | `car` | 通过 |
| 车库 | 转转自行车铃 | `bike` | 通过 |
| 车库 | 整理杂物架 | `shelf` | 通过 |
| 东侧过道与次净衣柜 | 叠好次净衣 | `hang` | 通过 |
| 东侧过道与次净衣柜 | 打开抽屉 | `drawer` | 通过 |
| 东侧过道与次净衣柜 | 整理衣柜 | `tidy` | 通过 |
| 爸妈卧室浴室 | 洗手台 | `sink` | 通过 |
| 爸妈卧室浴室 | 打开淋浴 | `shower` | 通过 |
| 爸妈卧室浴室 | 整理浴巾 | `towel` | 通过 |
| 楼梯旁猫窝走道 | 求求、落落、天天分别走近互动，寻猫达到 3/3 | 人物交互 | 通过 |
| 厨房 → 餐厅 | 午饭邀请出现，点“这就下楼”进入新餐桌吃饭 | 饭点邀请 | 通过 |

## 重画画面 · 540×960

### 插花 · 花、枝叶、花瓶，完成后的摆放

![插花 · 花、枝叶、花瓶，完成后的摆放](evidence/floor1-redraw/game-flowers-finished.png)

### 沏茶 · 茶具与铺满的茶桌

![沏茶 · 茶具与铺满的茶桌](evidence/floor1-redraw/game-tea.png)

### 煮汤 · 灶台、锅、菜与透明汤碗

![煮汤 · 灶台、锅、菜与透明汤碗](evidence/floor1-redraw/game-soup.png)

### 洗衣 · 洗衣机、衣物与晾衣场景

![洗衣 · 洗衣机、衣物与晾衣场景](evidence/floor1-redraw/game-laundry-finished.png)

### 磨木鸟 · 工作台、木纹与成品

![磨木鸟 · 工作台、木纹与成品](evidence/floor1-redraw/game-wood-finished.png)

### 花纹翻牌 · 四种植物图案

![花纹翻牌 · 四种植物图案](evidence/floor1-redraw/game-pairs-finished.png)

### 种树 · 不规则泥土树坑

![种树 · 不规则泥土树坑](evidence/floor1-redraw/game-tree.png)

### 摘果 · 透明果子与编织篮

![摘果 · 透明果子与编织篮](evidence/floor1-redraw/game-fruit-finished.png)

### 看天空 · 白天云层与树林

![看天空 · 白天云层与树林](evidence/floor1-redraw/game-stars-day.png)

### 看星星 · 夜空、月相、树林

![看星星 · 夜空、月相、树林](evidence/floor1-redraw/game-stars-night.png)

### 星座与流星 · 保留原有交互

![星座与流星 · 保留原有交互](evidence/floor1-redraw/game-stars-constellation-meteor.png)

### 饭桌菜肴 · 按现有菜单选择菜图

![饭桌菜肴 · 按现有菜单选择菜图](evidence/floor1-redraw/meal.png)

### 足球 · 圆形黑白皮球

![足球 · 圆形黑白皮球](evidence/floor1-redraw/football.png)

## 改动与验证范围

- 一楼重画 12 个空间，保留 53 个固定热点；重新提取 28 张前景遮挡。可走区按新图重建、重新烘焙，仅烘焙一楼。
- 新增 7 张小游戏背景、48 个透明图集项、1 个次净衣柜图件。插花桌面保留原构图并统一粗颗粒采样；树和摘果保留已有果园背景，替换要求重画的物件。
- 16 道菜图对应现有季节/每日菜单，家务完成后场景里的汤、衣服、木鸟、茶具和花瓶也使用这些图件。
- 地图中一楼的缩略图同步更新；`打开阿鱼家.command` 已改为启动当前工程的新一楼客厅。
- 一楼定向检查 **154/154**；家具/墙体按键阻挡和逐级上楼 **13/13**；重画小游戏触摸操作 **17/17**。
- 小游戏测试通过真实 viewport 触摸事件完成 8 个有结束条件的小游戏；观星覆盖白天、夜晚、星座与流星许愿输入。测试计时在隔离存档中推进，没有修改生产逻辑。
- 33 张游戏截图来自 Godot 的 540×960 视口；另外提供整层并排图、每间房可走区图。并非实体手机设备测试。
- 婚宴入口 `godot/project.godot`、二楼参照图逐字节未变。二楼、院外、老屋、树林的房间数据与几何保持基线；唯一边界例外是上文说明的一楼北门对接。
- 未跑全局 `run_tests.sh`、未跑 30 分钟耐久、未录全量 GIF、未打 bundle。

本次派活范围内没有未完成项。桌面 Godot 竖屏检查通过；实体手机触感、全局回归及 Claude 负责的坐躺/话泡/栏位/声音体验不在本轮结论内。

## Claude 接入

同一台电脑直接读取工程分支 `village/ayu-home-v4-floor1`。基线为 `2b7e0cf`，无需 bundle。图和数据的生成脚本、源图、透明素材与测试证据均随提交保存。

工程：`/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘 -gpt 总文件夹/裳泓村-工程`

核心文件：`v4/world.gd` 仅画面引用/绘制；`v4/life_games.gd` 仅绘制函数；`v4/home.gd` 仅地图缩略图引用；玩法逻辑保留。`assets/floor1-redraw/sources/prompts.json` 为内置 image_gen 的提示词集，`ART_SOURCES.md` 为来源记录。

证据：

- [一楼交互与门路记录](evidence/floor1-redraw/floor1-checks.json)
- [碰撞与逐级楼梯记录](evidence/floor1-redraw/collision-checks.json)
- [重画小游戏操作记录](evidence/floor1-redraw/game-checks.json)
- [玩法函数/前景/截图范围审计](evidence/floor1-redraw/render-scope-audit.json)
- [未改区域审计](evidence/floor1-redraw/scope-audit.json)
