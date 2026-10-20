# C2 完整 Home 跨进程重开最小核查

生产基线 `09618ac14c5bdabe206db79b20474ab3ba42fa66`；起点分支 `village-deep-1010`、HEAD `158d64893107bf2bf42100f50f0503d64a2fa205`。远端 main 仍为 `93d61574fb70c7bb1ffe9e1c6599623aa35215dc`，无新增覆盖任务。生产文件零修改。本批仅 headless，不是 GUI 或真人点击验收。

## 结果与实际尝试

- 派单的可执行名 Godot4.7.2 不存在，首次启动在 Python Popen 前失败，未创建 Godot 进程。只读确认后使用 `/Applications/Godot.app/Contents/MacOS/Godot`（原生 Godot 4.7.2）。
- create 进程 PID 50795：12/12，通过，退出码 0，22.23 秒。完整 Home 正常 go 从阿鱼院到村路、村委；正常 begin/3卡 step/collect 获竹材 1；close 后恢复行走并回村路 checkpoint。实际房间 village、实际坐标 [1704,2856]、竹材 0→1、正常收取的非空旧 run 为 `1`。
- 首次 reopen：退出码 1，1.59 秒，在 Home 实例化前被测试凭据守卫误拒绝。JSON avatar 数值恢复为 float，与原内存 int 的 Dictionary 整体比较不等；仅测试脚本改逐字段及键数校验，身份/路径边界保持。没有生产失败。
- 同一隔离档 phase2 第2次：PID 51133，9/9，通过，退出码 0。启动后先核双存档实际路径、稳定 profile、state.blocked=false；再核实际房间 village、实际位置 [1704,2856]、竹材仍为 1。旧 run 通过正常 `state.act("institution_complete", {"run":"1"})` 返回 `ok=false`、message=“这一份已经收好或放下了”，竹材仍为 1。之后正常 go 可继续移动并进入村委。

没有重跑 create，没有时钟、库存、位置、进度注入。create 12 项运行在旧守卫版；reopen 9 项运行在修正守卫并增加防重结果输出的版本。旧脚本未单独冻结哈希，不补造。最终脚本 SHA256 `6d1baacd30cca85680c459f59fc2221d6b307544d7c0c92d500344239e074094`。

## 进程顺序及隔离证据

外层 Python 对 create 执行 `subprocess.run(..., timeout=300)` 并等待返回，记录 exit=0 后才启动首次 reopen；其返回 exit=1 后，后续独立调用 `Popen(...).wait(timeout=300)` 才启动 PID 51133。因此阶段之间确实退出，不只比较 PID。原始工具输出保留上述先后顺序。各 go 等待90秒、boot30秒，外层每进程300秒封顶。

本次采用本轮32位随机隔离标识，具体值仅在本地测试数据（非服务登录凭据）；绝对隔离目录位于工程 `测试数据/Home重开-1020/` 下同名目录。两个阶段强制显式 `--ayu-save=<目录>/life.json`、`--core-save=<目录>/core`，root 测试身份 `c2-reopen-<token>`；启动后核 life.path/state.path。create 要求空目录；reopen 只接受绑定同目录、token、profile、原 PID 的 handoff 及存在的本轮档，拒绝时在 Home.new 前退出，不回退默认档。日志和存档仅本地，不提交。

## 保留限制

两成功进程都有沙箱 user 日志写入失败、系统 `ret != noErr` 条件消息；退出时 create 有5个 CanvasItem/5个 DummyTexture RID 和20个 ObjectDB泄漏，reopen 有3个/3个 RID 和14个 ObjectDB泄漏。退出码均0，结果断言通过；本轮不为清理释放警告扩修。保留实机欠验，不启动 GUI、临时包或定位尝试。
