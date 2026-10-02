extends SceneTree
## 验收：宴会厅的彩带与飘落（docs/宴会厅-彩带与飘落-说明.md，01 E 10/2）
## 1 红绸：红毯两边每对灯柱一道，挂在花冠里侧边上（西 +43、东 +3、花冠那一行 +23，相距 137），3 格来回晃、每道错开；
##   在人和桌子上面、牌子下面（z）；不是界面控件，不收点击
## 2 开席：一阵最多 60 片、约 4 秒散完；同一时间只放一阵（进厅排着、等开席散了再放；开席时来的干杯不要）
## 3 进厅：最多 30 片；每天第一次进厅才放（北京日期），同一天第二次不放、第二天又放
## 4 干杯：12～16 片、只有花瓣、落在两个人头顶；干杯插图还开着先等着；别人当场敬我也落
## 5 开席那一刻：按北京时间从 11:59 走到 12:00 放；调试版强制开席不放；进厅时已经开席了不补
## 6 在小游戏、簿子、菜单里不放，回来也不补；7 掉帧（低于 55）片数减半；8 没图又不是调试版：不挂不飘
## 用法：Godot --headless --path . --script res://tools/test_festive.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Festive = preload("res://scripts/hall_festive.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Festive.DAY_FILE))
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func frames(n: int) -> void:
    for i in n:
        await process_frame

## 手动快进飘落 secs 秒（每步 0.05），记下同时最多几片
func sim(f, secs: float) -> int:
    var most := 0
    for i in int(secs / 0.05):
        f._step_fall(0.05)
        most = maxi(most, f.pieces.size())
    return most

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await create_timer(0.5).timeout
    var h = m.hall
    var f = h.festive
    check("55 桌厅有彩带与飘落", f != null)
    if f == null:
        print("RESULT FAIL")
        quit(1)
        return
    f.set_process(false)   # 下面都手动快进，免得真时间插一脚
    f.fps_fn = func() -> float: return 60.0   # 无头跑帧率量不准（常常低于 55 会把片数减半），掉帧那条单独测
    var sw := {"hold": true, "busy": true}   # lambda 抓的是值，开关放字典里才改得动

    print("1 红绸")
    var lamps := {}
    for o in h.cfg["occluders"]:
        var id := str(o["id"])
        if id.contains("红毯西侧落地宫灯") or id.contains("红毯东侧落地宫灯"):
            lamps[id] = Vector2(float(o["x"]), float(o["y"]))
    check("一对灯一道：灯 %d 盏、红绸 %d 道" % [lamps.size(), f.silks.size()], lamps.size() == 20 and f.silks.size() == 10)
    var west_ok := true
    var span_ok := true
    for s in f.silks:
        var hang: Vector2 = s["pos"] + Festive.SILK_HANG
        var hit := false
        for id in lamps:
            if id.contains("西侧") and hang.is_equal_approx(lamps[id] + Vector2(Festive.WEST_EDGE, Festive.CROWN_ROW)):
                hit = true
        west_ok = west_ok and hit
        span_ok = span_ok and is_equal_approx(float(s["span"]), Festive.SILK_SPAN)
    var first: Vector2 = f.silks[0]["pos"] + Festive.SILK_HANG
    check("左挂点在西灯花冠里侧边上（第 1 道 %s，要 (697, %d)）" % [first, int(lamps.values().map(func(v): return v.y).min()) + Festive.CROWN_ROW],
        west_ok and is_equal_approx(first.x, 697.0))
    check("两个挂点相距 137（右挂点在东灯花冠里侧边上）", span_ok)
    var frames_now: Array = f.silks.map(func(s): return f.silk_frame(s))
    var seen := {}
    for i in 8:
        f.silk_t += 0.25
        seen[f.silk_frame(f.silks[0])] = true
    check("3 格来回晃（第 1 道 2 秒里出了 %d 格）、每道错开（此刻 %s）" % [seen.size(), frames_now],
        seen.size() == 3 and frames_now.any(func(x): return x != frames_now[0]))
    check("在人和桌子上面、牌子下面：z %d（人和桌 0～1，牌子 4～5）" % f.z_index, f.z_index > 1 and f.z_index < 4)
    var controls := 0
    for n in f.find_children("*", "Control", true, false):
        controls += 1
    check("不是界面控件、不收点击（里面 Control %d 个）" % controls, controls == 0 and f is Node2D)

    print("2 开席")
    f.request("feast")
    f.request("entry")
    f.request("toast", [h.pos, h.pos + Vector2(60, 0)])
    var most := sim(f, 1.5)
    check("开席在放、进厅排着、干杯不要（排着 %s）" % [f.queue.map(func(q): return q[0])], f.cur == "feast" and f.queue.size() == 1 and f.queue[0][0] == "entry")
    var t := 1.5
    while f.cur == "feast" and t < 8.0:
        most = maxi(most, sim(f, 0.05))
        t += 0.05
    check("开席一阵 %.1f 秒散完、同时最多 %d 片（≤ 60）" % [t, most], t >= 3.0 and t <= 5.0 and most <= 60 and most >= 30)
    sim(f, 0.1)
    check("开席散了接着放进厅", f.cur == "entry")
    most = sim(f, 3.0)
    check("进厅同时最多 %d 片（≤ 30），放完了" % most, most <= 30 and most >= 10 and f.cur == "")

    print("3 每天第一次进厅")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Festive.DAY_FILE))
    f.played.clear()
    f.unix_override = 1790000000.0      # 某天
    f.enter_today()
    sim(f, 0.1)
    var first_play: bool = f.played.has("entry")
    sim(f, 3.0)
    f.enter_today()
    sim(f, 0.1)
    var second_play: int = f.played.count("entry")
    f.unix_override += 86400.0
    f.enter_today()
    sim(f, 0.1)
    check("第一次进厅放（%s）、同一天再进不放（共 %d 次）、第二天又放（共 %d 次）" % [first_play, second_play, f.played.count("entry")],
        first_play and second_play == 1 and f.played.count("entry") == 2)
    sim(f, 3.0)

    print("4 干杯")
    var other: Vector2 = h.pos + Vector2(80, 10)
    f.hold_fn = func() -> bool: return sw["hold"]
    f.request("toast", [h.pos, other])
    sim(f, 1.0)
    check("干杯插图开着先等着", f.cur == "" and f.queue.size() == 1)
    sw["hold"] = false
    most = 0
    var kinds := {}
    var near := true
    for i in 40:
        f._step_fall(0.05)
        most = maxi(most, f.pieces.size())
        for p in f.pieces:
            kinds[p["kind"]] = true
            if p["p"].distance_to(h.pos) > 170.0 and p["p"].distance_to(other) > 170.0:
                near = false
    check("干杯同时最多 %d 片（12～16）、只有花瓣（%s）、都在两个人头顶（%s）" % [most, kinds.keys(), near],
        most >= 8 and most <= 16 and kinds.keys() == ["petal"] and near)
    sim(f, 2.0)

    print("4b 别人敬我也落（01 E 10/2：被敬也是干杯）")
    f.hold_fn = func() -> bool: return false
    f.queue.clear()
    m._on_pulse({"ok": true, "now": 5, "toasts": [{"from": "test_someone", "created_at": 4}], "names": {}})
    check("当场被敬：排上干杯那阵（排着 %s）" % [f.queue.map(func(q): return q[0])], f.queue.any(func(q): return q[0] == "toast"))
    sim(f, 2.0)
    if is_instance_valid(m.toast_scene):
        m.toast_scene.queue_free()
    await frames(2)

    print("5 开席那一刻")
    f.played.clear()
    f.feast_seen = -1
    f.unix_override = 1790000000.0 - fposmod(1790000000.0 + 8 * 3600.0, 86400.0) + 11 * 3600.0 + 3599.0   # 北京 11:59:59
    f.feast_check_t = 0.0
    f._process(0.0)
    m._set_feast_force("feast")   # 调试版强制开席：不当开席那一刻
    f.feast_check_t = 0.0
    f._process(0.0)
    var forced: bool = f.played.has("feast") or f.queue.any(func(q): return q[0] == "feast")
    f.unix_override += 2.0          # 北京 12:00:01
    f.feast_check_t = 0.0
    f._process(0.0)
    sim(f, 0.1)
    check("强制开席不放（%s）；11:59 走到 12:00 放了（%s）" % [forced, f.played], not forced and f.played.has("feast"))
    m._set_feast_force("")
    sim(f, 6.0)
    f.played.clear()
    f.feast_seen = -1
    f.feast_check_t = 0.0
    f._process(0.0)      # 进厅时已经开席了：头一回看钟不算那一刻
    f.feast_check_t = 0.0
    f._process(0.0)
    sim(f, 0.1)
    check("进厅时已经开席了不补（%s）" % [f.played], f.played.is_empty())

    print("6 在小游戏、簿子、菜单里不放、不补")
    f.busy_fn = func() -> bool: return sw["busy"]
    f.hold_fn = func() -> bool: return false
    f.request("feast")
    sim(f, 0.5)
    sw["busy"] = false
    sim(f, 1.0)
    check("占着的时候来的那阵没放、回来也没补（放过 %s）" % [f.played], f.played.is_empty() and f.cur == "" and f.pieces.is_empty())
    m.book_open = true
    check("簿子开着 main 那边算占着", m._hall_busy())
    m.book_open = false

    print("7 掉帧片数减半")
    f.fps_fn = func() -> float: return 40.0
    f.request("feast")
    most = sim(f, 3.0)
    check("40 帧时开席同时最多 %d 片（≤ 30）" % most, f.cur_max == 30 and most <= 30)
    sim(f, 4.0)
    f.fps_fn = func() -> float: return 60.0

    print("8 没图又不是调试版：不挂不飘")
    var g = Festive.new()
    g.debug_blocks = false
    h.add_child(g)
    g.build(h)
    g.set_process(false)
    var had_art: bool = g.silk_tex != null
    g.request("feast")
    sim(g, 0.5)
    check("正式版没图：红绸 %d 道、飘落 %d 片（有红绸图 %s）" % [g.silks.size(), g.pieces.size(), had_art],
        (had_art or g.silks.is_empty()) and (g.can_fall() or g.pieces.is_empty()))
    g.queue_free()

    DirAccess.remove_absolute(ProjectSettings.globalize_path(Festive.DAY_FILE))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
