# 完整Home最小闭环（1017）

生产源SHA：`09618ac14c5bdabe206db79b20474ab3ba42fa66`，生产未修改。Godot 4.7.2原生headless，唯一一次新档运行，11项通过、0失败，进程退出0。使用真正Home.new及其_process移动/门切换，不是Host夹具；不是GUI或真人点击验收。

## 隔离与正常触发

启动前创建全新唯一目录，强制传--ayu-save/--core-save并拒绝默认路径、已有档及其他Home覆盖参数；root设独立测试profile，避开用户profile读写。启动后life.path/state.path逐字等于传入路径才执行任何go。全程无set_test_clock、focus、角色传送、库存/进度/奖励注入。测试档与日志在测试数据/Home闭环-1017/7a01d1de4761440ea22e45c091c23ff6，均不归档。

正常链：阿鱼家院子 → go(to_side_path)沿路过门 → go(visit_mayor)入村委 → go(village_tasks)走到桌前并打开事务 → begin及三次正确分类 → collect → Interface.close → go(outside)实际恢复行走并回村路 → checkpoint。各段有超时及失败清理，未重跑首日/95/28/87。

| 编号 | 实际检查 | 场景/位置 | 结果 |
|---|---|---|---|
| 1 | both runtime save paths equal explicit isolated paths | exterior [754.0, 898.0] | 通过 |
| 2 | normal fresh Home starts at Ayu courtyard | exterior [754.0, 898.0] | 通过 |
| 3 | normal go to_side_path reaches village | village [1496.0, 2184.0] | 通过 |
| 4 | normal go visit_mayor reaches v_mayor | v_mayor [138.0, 442.0] | 通过 |
| 5 | normal go walks to civic table and opens game | v_mayor [318.0, 322.0] | 通过 |
| 6 | three normal category steps enable collection | v_mayor [318.0, 322.0] | 通过 |
| 7 | normal collect awards exactly one bamboo | v_mayor [318.0, 322.0] | 通过 |
| 8 | close restores actual Home HUD | v_mayor [318.0, 322.0] | 通过 |
| 9 | actual Home resumes walking after closing game | v_mayor [309.007446289062, 330.992553710938] | 通过 |
| 10 | normal exit returns to village | village [1704.0, 2856.0] | 通过 |
| 11 | final checkpoint preserves real village position and one reward | village [1704.0, 2856.0] | 通过 |

## 结果边界

正常事务领取竹材恰好+1；真实Home关闭小游戏后HUD恢复、角色再次行走并成功回村路，checkpoint记录实际位置。本轮不包含重开此完整Home存档、真实跨日、真人点击/视觉验收。退出仍报5 CanvasItem RID、22 ObjectDB、5 DummyTexture释放警告及系统证书环境错误；进程退出0，不把资源释放宣称无警告，本波不扩大修复。

## 可复跑入口与哈希

脚本：工具/test_home_civic_loop_1017.gd。先在测试数据/Home闭环-1017/下建全新唯一子目录，再运行Godot --headless --path godot --script ../工具/test_home_civic_loop_1017.gd --log-file <该目录>/godot.log -- --ayu-save=<该目录>/life.json --core-save=<该目录>/core；必须使用绝对路径，不复用本次档。

- `工具/test_home_civic_loop_1017.gd` SHA256 `f319fa7fd2e3368c972ed9a7a087822e6307f18196e59e4543113f34496bc156`
- `godot/ayu_home/v4/home.gd` SHA256 `fe3dace588319a98133a0d40a9d026f7cb0bb9a646ec185f90dd8b17a0c288d4`
- `godot/ayu_home/v4/core/interface.gd` SHA256 `012dc79ca9fd2d9e7d0400458090a2c49fcb82239cfa04fd44906c3f9efd7074`
- `godot/ayu_home/v4/core/institution_game.gd` SHA256 `fb1aab50a066a277b008a7a41defae0c051ffb1a05688c59b8cf28ac6b404839`
- `godot/ayu_home/v4/core/state.gd` SHA256 `645ff3f520d5135f4cd411ac83e478c8bc4b956ef69c2186d26a30f9dc8c321e`

本波一条完整衔接成功即收口，未添加生产接口、新玩法、启动包或输入框架；待C3有限独立审查。

隔离guard后续加固：拒绝相对路径、simplify_path与输入不一致的路径及重复save参数，再校验目录前缀/同父目录。11项实际通过使用加固前脚本SHA256 `577d82b4f7bf4fb4bf5a61fb82eb032551bcccb7055af31e1ffe56b3e3a23feb`；加固只改变启动预检，不改变Home行为链，本轮仅对加固后脚本做--check-only解析，不重复运行11项。
