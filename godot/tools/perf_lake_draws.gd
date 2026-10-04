extends SceneTree
## 湖边动效每帧多画几次（05 10/4，01 H 派；量法照 03 的 perf_lamp_draws.gd）：真游戏进湖边，人站着不动（画面每回一样），
## 同一个位置把动效关掉（全关档：波光藏掉、船停在原位）、再打开，来回量 3 轮，每轮 90 帧；量画图调用、图元、对象、帧用时（中位数）。
## 两个位置：东半边（曲桥南边，看得到篷船、湖心亭）、西半边（码头南边，看得到四条小船）。要开窗口（headless 不画图）：
##   Godot --path . --resolution 540x960 --script res://tools/perf_lake_draws.gd     最后一行「PERF」是汇总
const Ambient = preload("res://scripts/ambient/ambient.gd")
var m
var started := false

func _initialize() -> void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    m = load("res://scripts/main.gd").new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func frames(n: int) -> void:
    for i in n:
        await process_frame

func med(a: Array) -> float:
    var b := a.duplicate()
    b.sort()
    return float(b[b.size() / 2]) if not b.is_empty() else 0.0

func sample(n: int) -> Dictionary:
    var dc: Array = []
    var pr: Array = []
    var ob: Array = []
    var ms: Array = []
    var last := Time.get_ticks_usec()
    for i in n:
        await process_frame
        var now := Time.get_ticks_usec()
        ms.append((now - last) / 1000.0)
        last = now
        dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        pr.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
        ob.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
    return {"draw": med(dc), "prim": med(pr), "obj": med(ob), "ms": med(ms)}

func run() -> void:
    for i in 1200:
        if m.state == "title":
            break
        await process_frame
    await m._setup_shot("lake")
    while m.switching or m.fade.color.a > 0.0:
        await process_frame
    var lk = m.lake
    var spots := {"东半边（曲桥南边）": Vector2(2420, 900), "西半边（码头南边）": Vector2(900, 900)}
    var out := {}
    for name in spots:
        lk.reset_to(spots[name])
        lk.face = "up"
        lk.cam.reset_smoothing()
        await frames(40)
        var off_d: Array = []
        var on_d: Array = []
        var res := {}
        for r in 3:
            Ambient.set_forced(0)
            await frames(10)
            var a := await sample(90)
            Ambient.set_forced(2)
            await frames(10)
            var b := await sample(90)
            off_d.append(a)
            on_d.append(b)
        var f := func(arr: Array, k: String) -> float:
            var v: Array = []
            for x in arr:
                v.append(x[k])
            return med(v)
        res = {"关 画图": f.call(off_d, "draw"), "开 画图": f.call(on_d, "draw"), "关 对象": f.call(off_d, "obj"), "开 对象": f.call(on_d, "obj"),
            "关 毫秒": f.call(off_d, "ms"), "开 毫秒": f.call(on_d, "ms")}
        out[name] = res
        print("[perf] ", name, " ", res)
    Ambient.set_forced(-1)
    print("PERF ", JSON.stringify(out))
    quit()
