extends SceneTree
## 验收：宴会厅性能兜底（02 10/3「性能-真人物满厅」）
## 1 坐着的宾客只动看得见的那些（手机屏 540×960 下大约三成），屏幕外的不动；走到别处，那边的动起来
## 2 掉帧兜底：set_low_end(true) 宾客 15 帧一动、灯笼光不闪；set_low_end(false) 照常
## 3 打开用时：标题、进厅都记了时间（日志「[suqi] 打开用时」）
## 4 后厅、草坪、湖边、果园开场不搭，第一次走进去（切画布黑屏那一下）才搭，搭完照样走得进去
## 用法：Godot --headless --path . --script res://tools/test_perf_guards.gd ；最后一行 RESULT PASS 才算过

var m
var started := false
var ok := true

func _initialize() -> void:
    m = load("res://scripts/main.gd").new()
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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var built_at_title: Dictionary = m.canvas_built.duplicate()
    var lawn_world_at_title = m.lawn.world
    get_root().size = Vector2i(540, 960)
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    m._set_feast_force("feast")
    await frames(5)
    var h = m.hall
    var life = h.life

    print("1 只动看得见的")
    h.reset_to(Vector2(320, 1700))
    await frames(3)
    life._process(0.016)
    var n1: int = life.guests_stepped
    check("西边：%d 位里动了 %d 位（只动看得见的）" % [life.guests.size(), n1], n1 > 20 and n1 < life.guests.size() / 2)
    var view: Rect2 = life._anim_view()
    var far = life.guests.filter(func(g): return not view.has_point(g.node.position))[0]
    var off0: Vector2 = far.body.offset
    var dip0: float = far.dip
    for i in 60:
        life._process(0.05)
    check("屏幕外的那位 3 秒没动（低头、计时都停着）", far.body.offset == off0 and far.dip == dip0)
    h.reset_to(far.node.position + Vector2(0, 40))
    await frames(3)
    life._process(0.016)
    check("走到那边，那边的动起来（动了 %d 位）" % life.guests_stepped, life._anim_view().has_point(far.node.position) and life.guests_stepped > 20)

    print("2 掉帧兜底")
    h.set_low_end(true)
    check("开：low_end=1", int(life.low_end) == 1)
    life.guest_tick = 0.0
    life.guests_stepped = -1
    life._process(0.016)
    check("开着时一帧 16 毫秒不够 1/15 秒，宾客这帧不动", life.guests_stepped == -1)
    life._process(0.06)
    check("攒够 1/15 秒动一下（动了 %d 位）" % life.guests_stepped, life.guests_stepped > 0)
    h.set_low_end(false)
    check("关：low_end=0", int(life.low_end) == 0)

    print("3 打开用时")
    check("标题、进厅都记了时间 %s" % [m.boot_marks], m.boot_marks.has("title") and m.boot_marks.has("hall"))

    print("4 四块进去才搭")
    check("开场到标题：四块都没搭（%s）、草坪还没有画面" % [built_at_title], built_at_title.is_empty() and lawn_world_at_title == null)
    await m._enter_court()
    m.dialog.visible = false
    m._switch_canvas("lawn")
    for i in 120:
        await process_frame
        if m.state == "lawn" and not m.switching:
            break
    check("从迎宾院走去草坪：这时才搭（%s），人在草坪、能走" % [m.canvas_built.keys()], m.state == "lawn" and m.canvas_built.has("lawn") and m.lawn.world != null and m.lawn.walking_enabled)
    check("别的三块还没搭", not m.canvas_built.has("backhall") and not m.canvas_built.has("lake") and not m.canvas_built.has("orchard"))
    check("草坪上的人穿的是现在的形象（%s）" % m.lawn.player.texture, m.lawn.player.texture == m.court.player.texture)

    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
