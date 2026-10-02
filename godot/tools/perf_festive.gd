extends SceneTree
## 量彩带与飘落加了以后的绘制次数和帧（01 E 10/2：阿鱼手机现在 60 帧、绘制 93 次）。电脑上量，真机另验。
## 要有窗口（headless 没有绘制次数）：Godot --path . --resolution 540x960 --script res://tools/perf_festive.gd
## 进 55 桌厅、站在自己桌边（跟手机进厅一样），开席坐满；量三段各 3 秒：
##   没有彩带飘落（把 festive 藏起来）/ 平时（只有红绸）/ 开席飘落那一阵（同时 60 片）/ 再藏起来量一次
## 打一行「PERF 段 绘制次数平均/最多 帧平均」

const Main = preload("res://scripts/main.gd")

var m
var started := false

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func measure(label: String, secs: float) -> void:
    var calls: Array = []
    var fps: Array = []
    var t0 := Time.get_ticks_msec()
    while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
        await process_frame
        await RenderingServer.frame_post_draw
        calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        fps.append(Engine.get_frames_per_second())
    var avg := 0.0
    for c in calls:
        avg += float(c)
    avg /= maxf(1.0, float(calls.size()))
    var favg := 0.0
    for f in fps:
        favg += float(f)
    favg /= maxf(1.0, float(fps.size()))
    var pieces: int = m.hall.festive.pieces.size() if m.hall.festive != null else 0
    print("PERF %s 绘制 平均 %.1f 最多 %d 帧 平均 %.0f（%d 帧，此刻飘的 %d 片）" % [label, avg, calls.max(), favg, calls.size(), pieces])

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await create_timer(0.2).timeout
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await create_timer(2.0).timeout
    m.dialog.visible = false
    m._set_feast_force("feast")
    var rel = m.hall.life.relatives
    for i in int(60.0 / 0.05):
        rel._process(0.05)
    var f = m.hall.festive
    f.visible = false
    await measure("没有彩带飘落", 3.0)
    f.visible = true
    await measure("平时（红绸）", 3.0)
    f.request("feast")
    await create_timer(0.8).timeout
    await measure("开席飘落", 2.0)
    await create_timer(3.0).timeout
    f.visible = false
    await measure("没有彩带飘落（再量一次，前后对着看：亲友在走，绘制次数会跟着变）", 3.0)
    quit(0)
