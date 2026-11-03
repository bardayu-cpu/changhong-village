# 完整Home串行过门巡回（1017）

源SHA `09618ac14c5bdabe206db79b20474ab3ba42fa66`，生产未改。Godot 4.7.2 headless，一次全新独立双档巡回，22项通过、0失败、进程退出0；无GUI/真人点击，不等于画面验收。

| 正常触发 | 实际结果 |
|---|---|
| 新档启动 | 明确绝对规范双存档路径、拒绝重复参数/旧档、独立profile；启动后life/state路径逐字核对通过才go。 |
| 阿鱼院go(to_side_path) | 真实Home移动并进入村路，transition结束、pending清空。 |
| go(visit_community)→按本屋配置返回门go | 进入活动中心my_cabin，实际能走向出口并回村路。 |
| go(visit_h3)→按本屋配置返回门go | 进入磨坊v_h3，实际能走向出口并回村路。 |
| go(visit_h5)→按本屋配置返回门go | 进入蜂蜜屋v_h5，实际能走向出口并回村路。 |
| go(visit_laowu)→按本屋配置返回门go | 进入老屋v_laowu，实际能走向出口并回村路。 |
| go(visit_ayu)→checkpoint | 正常回阿鱼院，实际位置保存一致；库存/金币/人情全程不变。 |

逐段使用真实Home._process及go，等待目标area/transition/pending和位置移动；阶段超时即清理失败退出。没有调用enter_room传送，没有时钟/物品/进度注入，未开小游戏领奖，未跑95/87/首日。22项分解：隔离/初始场景2、出院1、四室各进入/返回门存在/实际移动/回村4×4、回院/位置/资源3。

原始行级结果与日志、双档位于测试数据/Home闭环-1017/tour-d271fb1234664443afe4beddf23a5668，均不归档。系统证书环境错误及退出5 CanvasItem RID、20 ObjectDB、5 DummyTexture释放警告仍有，未宣称无警告；未发现本巡回的确定卡门/功能阻断，不扩大修复。

可复跑：在测试数据/Home闭环-1017下新建唯一空子目录，Godot --headless --path godot --script ../工具/test_home_door_tour_1017.gd --log-file <绝对新目录>/godot.log -- --ayu-save=<绝对新目录>/life.json --core-save=<绝对新目录>/core。不可复用本次档。

- `工具/test_home_door_tour_1017.gd` SHA256 `fbb960aab81691fd47b20161f2d66be7724e906b0bea5143f4a14a3e485e45b5`
- `godot/ayu_home/v4/home.gd` SHA256 `fe3dace588319a98133a0d40a9d026f7cb0bb9a646ec185f90dd8b17a0c288d4`
- `godot/ayu_home/v4/world.gd` SHA256 `fafc90171fa5fcab3c22e0224689e4b680ed3d146b88b855a6c7807a382192e6`

成功一次即收口，等待C3有限独立review和C1冻结后统一封存；真人视觉/点击仍欠验。
