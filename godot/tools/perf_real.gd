extends SceneTree
## 真游戏量宴会厅性能（01 E 10/3「宴会厅换真人物以后的性能和打开速度」）：跟 perf_hall55.gd（色块试验）不同，这个跑真的 main.gd——
## 进 55 桌厅、开席坐满、放开席飘落，人从西边走到东边再走回来（镜头跟着），量每帧时间、画图调用、内存。
## 要开窗口跑（headless 不画图）；不限帧（关垂直同步），看的是一帧要多少毫秒，不是电脑上多少帧：
##   Godot --path . --resolution 540x960 --script res://tools/perf_real.gd -- --secs=20 [--lm_dir=一套人物图的文件夹] [--fx=feast]
## 老提交也能跑（拷进去跑，跟 shot.sh 一样），只用 _enter_banquet、_set_feast_force、hall.go_to 这几个入口
## 最后一行「PERF」是汇总（JSON），回执照它填

var m
var started := false
var opt := {"secs": "20", "lm_dir": "", "fx": "feast", "warm": "3", "lowend": "0", "still": "", "hide": ""}
## --still=x,y：人站在这一点不动（镜头不动，每回量的画面一样，比得出哪样东西多少画图调用）
## --hide=guests,waiters,seat_tags,festive,relatives,hud：把这几样藏起来再量（拆画图调用是谁的）
var samples: Array = []   # [帧毫秒, 画图调用, 图元, 对象]
var proc_ms: Array = []
var t_enter := 0

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and "=" in a:
            var kv := a.substr(2).split("=", true, 1)
            opt[kv[0]] = kv[1]
    if str(opt["lm_dir"]) != "":
        var LMPeople = load("res://scripts/lm_people.gd")
        if LMPeople != null:
            LMPeople.dir = str(opt["lm_dir"]).trim_suffix("/") + "/"
            LMPeople.clear_cache()
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

func pct(a: Array, p: float) -> float:
    if a.is_empty():
        return 0.0
    var b := a.duplicate()
    b.sort()
    return float(b[clampi(int(p * (b.size() - 1)), 0, b.size() - 1)])

func run() -> void:
    var t0 := Time.get_ticks_msec()
    for i in 1200:
        if m.state == "title":
            break
        await process_frame
    var t_title := Time.get_ticks_msec() - t0
    m.nickname = "小李"
    if m.cloud.get("fake_no_news") != null:
        m.cloud.fake_no_news = true
    var te := Time.get_ticks_msec()
    await m._enter_banquet()
    t_enter = Time.get_ticks_msec() - te
    if m.has_method("_set_feast_force"):
        m._set_feast_force("feast")
    var h = m.hall
    if str(opt["lowend"]) == "1" and h.has_method("set_low_end"):
        h.set_low_end(true)
    if str(opt["still"]) != "":
        var xy: PackedStringArray = str(opt["still"]).split(",")
        h.reset_to(Vector2(float(xy[0]), float(xy[1])))
    for what in str(opt["hide"]).split(",", false):
        match what:
            "guests":
                if h.life != null and h.life.guest_holder != null: h.life.guest_holder.visible = false
            "waiters":
                if h.life != null:
                    for w in h.life.waiters: w.node.visible = false
            "seat_tags":
                if h.seat_tags != null: h.seat_tags.visible = false
            "festive":
                if h.festive != null: h.festive.visible = false
            "relatives":
                if h.life != null and h.life.relatives != null: h.life.relatives.visible = false
            "hud":
                m.hud.visible = false
    await frames(int(opt["warm"]) * 30)
    if str(opt["fx"]) != "" and h.get("festive") != null and h.festive != null:
        h.festive.request(str(opt["fx"]), [h.pos, h.pos + Vector2(70, 0)])
    # 西边走到东边、再回来（镜头跟人）：照满厅 550 人里最挤的那条横路走
    var y: float = h.pos.y
    var path_pts := [Vector2(200, y), Vector2(1330, y), Vector2(700, y - 600), Vector2(700, y + 300)]
    var pi := 0
    if str(opt["still"]) == "":
        h.go_to(path_pts[0])
    var secs := float(opt["secs"])
    var start := Time.get_ticks_usec()
    var last := start
    var fx_again := 0.0
    while (Time.get_ticks_usec() - start) / 1e6 < secs:
        await process_frame
        var now := Time.get_ticks_usec()
        var ms := (now - last) / 1000.0
        last = now
        samples.append([ms, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
            Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
        proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
        if h.path.is_empty() and str(opt["still"]) == "":
            pi = (pi + 1) % path_pts.size()
            h.go_to(path_pts[pi])
        fx_again += ms / 1000.0
        if str(opt["fx"]) != "" and fx_again > 6.0 and h.get("festive") != null and h.festive != null:
            fx_again = 0.0
            h.festive.request(str(opt["fx"]), [h.pos, h.pos + Vector2(70, 0)])
    var fms: Array = samples.map(func(s): return float(s[0]))
    var dc: Array = samples.map(func(s): return float(s[1]))
    var obj: Array = samples.map(func(s): return float(s[3]))
    var avg := 0.0
    for v in fms:
        avg += v
    avg /= maxf(1.0, fms.size())
    var out := {
        "frames": fms.size(), "ms_avg": snappedf(avg, 0.01), "ms_p50": snappedf(pct(fms, 0.5), 0.01), "ms_p99": snappedf(pct(fms, 0.99), 0.01),
        "fps_equiv": snappedf(1000.0 / maxf(0.01, avg), 0.1),
        "process_ms_p50": snappedf(pct(proc_ms, 0.5), 0.01), "process_ms_p99": snappedf(pct(proc_ms, 0.99), 0.01),
        "draw_p50": pct(dc, 0.5), "draw_max": pct(dc, 1.0), "objects_p50": pct(obj, 0.5),
        "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
        "mem_static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
        "video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
        "texture_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
        "boot_to_title_ms": t_title, "enter_hall_ms": t_enter,
        "guests": h.life.guests.size() if h.get("life") != null and h.life != null else -1,
        "waiters_lm": h.life.waiters.filter(func(w): return w.kind == "waiter" and w.get("lm") != null and not w.lm.is_empty()).size() if h.get("life") != null and h.life != null else -1,
        "lm_dir": str(opt["lm_dir"]), "fx": str(opt["fx"]), "lowend": str(opt["lowend"]), "still": str(opt["still"]), "hide": str(opt["hide"]),
    }
    print("PERF ", JSON.stringify(out))
    quit(0)
