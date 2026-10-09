extends SceneTree
## 宫灯动效每帧多画几次（03 测第 66 版，01 G 10/4 派）：真游戏进 55 桌厅开席，人站着不动（画面每回一样），
## 同一个位置把动效节点藏起来（等于没挂）、再放出来，来回量 3 轮，每轮 90 帧；量画图调用、图元、对象、帧用时（中位数）。
## 三个位置：灯最多的（视野里灯数最多）、一盏灯都看不见的、大门口。要开窗口（headless 不画图）：
##   Godot --path . --resolution 540x960 --script res://tools/perf_lamp_draws.gd     最后一行「PERF」是汇总
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
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    if m.has_method("_set_feast_force"):
        m._set_feast_force("feast")
    var h = m.hall
    var amb: Node2D = h.get_node("ambient")
    var lg = amb.get_child(0)
    var vs := Vector2(m.view.get_child(0).size)
    # 挑位置：视野里灯数最多 / 0 盏
    var best := Vector2.ZERO
    var best_n := -1
    var zero := Vector2.ZERO
    var zoom := 1.0
    h.reset_to(h.SPAWN)
    await frames(3)
    zoom = h.cam.zoom.x
    var half := vs / zoom * 0.5
    for y in range(300, 2000, 40):
        for x in range(120, 1420, 40):
            var p := Vector2(x, y)
            if not h._free(p):
                continue
            var n := 0
            for q in lg.points:
                if absf(q.x - p.x) < half.x and absf(q.y - p.y) < half.y:
                    n += 1
            if n > best_n:
                best_n = n
                best = p
            if n == 0 and zero == Vector2.ZERO:
                zero = p
    var spots := {"灯最多（视野里 %d 盏）" % best_n: best, "一盏灯都看不见": zero, "大门口": h.SPAWN}
    var out := {}
    for name in spots:
        h.reset_to(spots[name])
        h.snap_cam()
        await frames(40)
        var on_a: Array = []
        var off_a: Array = []
        for r in 3:
            amb.visible = true
            await frames(10)
            on_a.append(await sample(90))
            amb.visible = false
            await frames(10)
            off_a.append(await sample(90))
        amb.visible = true
        var f := func(a: Array, k: String) -> float:
            return med(a.map(func(s): return float(s[k])))
        var row := {"有动效 画图": f.call(on_a, "draw"), "没动效 画图": f.call(off_a, "draw"), "有 图元": f.call(on_a, "prim"), "没 图元": f.call(off_a, "prim"),
            "有 对象": f.call(on_a, "obj"), "没 对象": f.call(off_a, "obj"), "有 毫秒": snappedf(f.call(on_a, "ms"), 0.01), "没 毫秒": snappedf(f.call(off_a, "ms"), 0.01)}
        out[name] = row
        print("  ", name, " ", JSON.stringify(row))
    print("PERF ", JSON.stringify(out))
    quit(0)
