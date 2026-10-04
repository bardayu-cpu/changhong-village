extends SceneTree
## 验收：罗曼山庄全景地图、点一块传送（07 10/4，蓝图第 22 条，01 H 派）。无界面跑整个 main.gd。
##   1 数据：15 块（宴会厅、迎宾院、后厅、草坪、湖边、果园、停车场、喷泉广场和七块灰盒）、27 条路；方向照游戏（前门在下、湖在上、草坪在左）
##   2 入口：「罗曼山庄」名字牌——签到前没传送门图标、点了不开；签到后有图标、点名字牌打开
##   3 打不开的时候：开车、说话框开着、对话框（后厅聊天）开着、写悄悄话、不在能走的场景（厨房小游戏）
##   4 打开以后：人不能走、标着你在哪；点自己那块说「你就在这里」不问；点别的块问「去 XX？」，点「不去」收起
##   5 每一块都试传一次：点那块（真点在地图上那块的位置）→「去」→ 到了那块、站在门口能走的地上、不弹回去、又能走、地图收了
## 用法：Godot --headless --path . --script res://tools/test_estate_map.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const SAVE := "user://test_estate_map_court.json"
var m
var started := false
var ok := true
var em

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

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func frames(n: int) -> void:
    for i in n:
        await process_frame

func click(c: Control, at: Vector2) -> void:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = at
    c.gui_input.emit(e)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = SAVE
    m.games_save.local_path = "user://test_estate_map_games.json"
    m.court_save.signed_in = false
    em = m.estate_map

    print("1 数据")
    var ids: Array = em.data["blocks"].map(func(b): return str(b["id"]))
    var want := ["court", "banquet", "backhall", "lawn", "lake", "orchard", "parking", "plaza", "kids", "shop", "rest2", "wkitchen", "garden", "frontgate", "backgate"]
    var all_in := true
    for w in want:
        all_in = all_in and w in ids
    check("15 块都在（%s）、27 条路（%d）" % [ids, em.data["roads"].size()], ids.size() == 15 and all_in and em.data["roads"].size() == 27)
    var fg: Array = em.block("frontgate")["rect"]
    var lk: Array = em.block("lake")["rect"]
    var lw: Array = em.block("lawn")["rect"]
    var pz: Array = em.block("plaza")["rect"]
    check("方向照游戏：前门在喷泉下面、湖在最上面、草坪在左边", float(fg[1]) > float(pz[3]) and float(lk[1]) < float(pz[1]) and float(lw[2]) <= float(pz[0]) + 1.0)

    print("2 入口")
    m._enter_court()
    for i in 200:
        await process_frame
        if m.state == "court" and not m.switching:
            break
    m.dialog.visible = false
    m.court.walking_enabled = true
    await frames(3)
    check("签到前：名字牌里没有传送门图标", not em.icon.visible)
    click(em.chip, Vector2(20, 20))
    await frames(2)
    check("签到前点名字牌：地图不开", not em.is_open())
    m.court_save.signed_in = true
    await frames(3)
    check("签到后：名字牌里出传送门图标（在名字牌那一行里）", em.icon.visible and em.icon.get_parent().get_parent() == em.chip)
    click(em.chip, Vector2(20, 20))
    await frames(2)
    check("点名字牌：地图开了、人不能走、标着你在迎宾院", em.is_open() and not m.court.walking_enabled and em.view.here == "court")
    em.close_map()
    await frames(2)
    check("关上：地图收了、又能走", not em.is_open() and m.court.walking_enabled)

    print("3 打不开的时候")
    m.driving = true
    var c1: bool = em.can_open()
    m.driving = false
    m.dialog.visible = true
    var c2: bool = em.can_open()
    m.dialog.visible = false
    m.whisper_box.visible = true
    var c3: bool = em.can_open()
    m.whisper_box.visible = false
    var st: String = m.state
    m.state = "kitchen"
    var c4: bool = em.can_open()
    m.state = st
    m.court_save.signed_in = false
    var c5: bool = em.can_open()
    m.court_save.signed_in = true
    m.court.walking_enabled = false
    var c6: bool = em.can_open()
    m.court.walking_enabled = true
    check("开车 %s、说话框 %s、写悄悄话 %s、厨房小游戏 %s、签到前 %s、画布不能走（签到面板这类开着）%s：都打不开" % [c1, c2, c3, c4, c5, c6], not (c1 or c2 or c3 or c4 or c5 or c6) and em.can_open())
    # 后厅聊天的对话框开着
    m.teleport_to("backhall", Vector2.ZERO)
    for i in 300:
        await process_frame
        if m.state == "backhall" and not m.switching:
            break
    m.dialog.visible = false
    m.backhall.walking_enabled = true
    m.lounge_ui.attach(m.backhall.lounge)
    m.backhall.reset_to(m.backhall.lounge.approach_of("lounge_10"))
    m.backhall.lounge.request_talk("lounge_10")
    for i in 300:
        await process_frame
        if m.lounge_ui.talk_box.visible:
            break
    check("后厅跟爷爷说着话：打不开", m.lounge_ui.talk_box.visible and not em.can_open())
    m.lounge_ui.close_talk()
    await frames(3)

    print("4 点块")
    em.open()
    await frames(2)
    var r: Rect2 = em.view.rect_of(em.block("backhall"))
    em.view._gui_input(_press(r.get_center()))
    await frames(2)
    check("点自己那块（后厅）：说「%s」、不问" % em.hint.text, em.hint.text == em._t("here") and not em.confirm.visible)
    r = em.view.rect_of(em.block("lake"))
    em.view._gui_input(_press(r.get_center()))
    await frames(2)
    check("点湖边：问「%s」" % em.confirm_label.text, em.confirm.visible and em.confirm_label.text == em._t("go_fmt") % "湖边")
    (em.confirm.find_child("map_no", true, false) as Button).pressed.emit()
    await frames(2)
    check("点「不去」：确认框收了、还在后厅、地图还开着", not em.confirm.visible and m.state == "backhall" and em.is_open())
    em.close_map()

    print("5 每块试传一次")
    var bad: Array = []
    var order: Array = ["court", "banquet", "lawn", "lake", "orchard", "backgate", "parking", "plaza", "kids", "shop", "rest2", "wkitchen", "garden", "frontgate", "backhall"]
    for id in order:
        if id == m.state:
            continue
        m.dialog.visible = false
        m.cv.walking_enabled = true
        await frames(2)
        if not em.can_open():
            bad.append("%s：在 %s 打不开地图" % [id, m.state])
            continue
        em.open()
        await frames(2)
        var rr: Rect2 = em.view.rect_of(em.block(id))
        em.view._gui_input(_press(rr.get_center()))
        await frames(1)
        if not em.confirm.visible or em.picked != id:
            bad.append("%s：点了没问（picked %s）" % [id, em.picked])
            em.close_map()
            continue
        var want_at: Vector2 = em.target_pos(id)
        (em.confirm.find_child("map_yes", true, false) as Button).pressed.emit()
        for i in 400:
            await process_frame
            if m.state == id and not m.switching:
                break
        await frames(60)
        var c = m.cv
        var at: Vector2 = c.pos
        var issues: Array = []
        if m.state != id:
            issues.append("没到（在 %s）" % m.state)
        if want_at != Vector2.ZERO and at.distance_to(want_at) > 1.0:
            issues.append("站 %s 不是门口 %s" % [at, want_at])
        if not c._free(at):
            issues.append("站的地方 %s 不能走" % at)
        if em.is_open():
            issues.append("地图没收")
        if m.dialog.visible:
            m.dialog.visible = false
        if not c.walking_enabled:
            issues.append("到了不能走")
        print("    %s：站 %s %s" % [id, at, "" if issues.is_empty() else str(issues)])
        if not issues.is_empty():
            bad.append("%s：%s" % [id, issues])
    check("从迎宾院出发一块一块传了 14 次（%d 处不对 %s），每块都到了、站在门口能走的地上、不弹回去、地图收了、又能走" % [bad.size(), bad], bad.is_empty())

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_estate_map_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

func _press(at: Vector2) -> InputEventMouseButton:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = at
    return e
