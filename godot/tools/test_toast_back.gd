extends SceneTree
## 验收：回敬（蓝图 3.2「可回敬一次」，01 9/19 派）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 被敬以后（进厅提示、厅里当场收到两种）顶部那句提示右边出「回敬一杯」，跟着那句提示留 6 秒；
## 点了直接敬回去，几个人一起敬的回敬最新那位；每天几杯、敬过没有由服务端定；按钮浮在干杯插图上面也点得到；
## 开着小游戏、看人卡片、簿子时不出
## 用法：Godot --headless --path . --script res://tools/test_toast_back.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true   # 淡入淡出直接跳过
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

## 厅里当场收到敬酒：照 hallPulse 回来的样子直接喂给 _on_pulse
func pulse(toasts: Array, names: Dictionary) -> void:
    m._on_pulse({"ok": true, "now": 100000, "toasts": toasts, "names": names})
    await frames(2)   # 让 _layout_top 排一次

func run() -> void:
    # 0. 挑最新的那条：hallPulse 按时间升序、进厅提示按文档 id 排（不按时间），都要按时间取最大；一样大取后面那条
    print("0 挑最新的那条")
    check("升序取最后", str(Main.latest_toast([{"from": "a", "created_at": 1}, {"from": "b", "created_at": 2}], "created_at").get("from")) == "b")
    check("乱序取时间最大", str(Main.latest_toast([{"from": "a", "at": 9}, {"from": "b", "at": 3}, {"from": "c", "at": 5}], "at").get("from")) == "a")
    check("时间一样取后面", str(Main.latest_toast([{"from": "a", "at": 5}, {"from": "b", "at": 5}], "at").get("from")) == "b")
    check("空的回空", Main.latest_toast([], "at").is_empty())

    # 等 main 开场走完（不然它会在测试中途切回开场）
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)

    # 1. 进厅先见人（01 9/23）：有人敬过我（假数据：老王），先放一次干杯插图，放完出进厅小卡，
    #    「老王敬了你一杯」那一行右边就是「回敬一杯」。原来顶上那一行提示 + 旁边的按钮并进了卡里（体验 B6）
    print("1 进厅小卡")
    m.nickname = "小李"
    await m._enter_banquet()
    var waited := 0.0
    while not is_instance_valid(m.arrival_card) and waited < 8.0:
        await create_timer(0.1).timeout
        waited += 0.1
    await frames(3)
    var card = m.arrival_card
    check("插图放完出了小卡（等了 %.1f 秒）" % waited, is_instance_valid(card))
    check("原来那一行提示和旁边的按钮不再出", not m.toast_back_btn.visible and not m.note.text.contains("敬了你"))
    check("对白框收起了，一次只留一层", not m.dialog.visible)
    var texts: Array = []
    for row in card.rows_box.get_children():
        texts.append(str((row.get_child(0) as Label).text))
    check("三行：%s" % [texts], texts.size() == 3 and texts[0] == "老王 敬了你一杯"
        and texts[1] == "小李 在你这桌簿子上写了 2 句" and texts[2] == "还有 3 位来过")
    var tb: Button = card.rows_box.get_child(0).get_node("btn")
    check("敬酒那行右边是回敬一杯", tb.text == "回敬一杯")
    check("簿子那行右边是翻簿子", (card.rows_box.get_child(1).get_node("btn") as Button).text == "翻簿子")
    var cr: Rect2 = card.get_global_rect()
    check("卡在屏幕里、不出边 %s" % cr, cr.position.x >= 0.0 and cr.end.x <= m.ui.size.x and cr.size.y < m.ui.size.y * 0.3)

    # 2. 点卡上的回敬：直接敬老王，和看人卡片「敬一杯」同一条路——顶部「敬了 老王 一杯」、插图；卡收起
    print("2 点卡上的回敬")
    tb.emit_signal("pressed")
    await frames(3)
    check("服务端收到敬老王", m.cloud.fake_toasts_today.has("fake_wang"))
    check("顶部一句：" + m.note.text, m.note.text == "敬了 老王 一杯")
    check("卡收起了", not is_instance_valid(m.arrival_card))
    var has_scene: bool = is_instance_valid(m.toast_scene) or not m.toast_queue.is_empty()
    check("有干杯插图（在放或排队）", has_scene)
    if is_instance_valid(m.toast_scene):
        m.toast_scene.closing = m.toast_scene.t
    await create_timer(0.6).timeout

    # 3. 当场收到两杯（乱序），回敬最新的老王；今天已经敬过老王，服务端拒，显示原因
    print("3 两个人一起敬、服务端拒")
    await pulse([{"from": "fake_wang", "created_at": 200}, {"from": "fake_li", "created_at": 100}],
        {"fake_wang": {"nick": "老王", "avatar": 1}, "fake_li": {"nick": "小李", "avatar": 5}})
    check("提示：" + m.note.text, m.note.text == "老王 等 2 人敬了你")
    check("回敬最新的老王", m.toast_back_btn.visible and m.toast_back_to == "fake_wang")
    m._on_toast_back_pressed()
    await frames(2)
    check("被拒显示原因：" + m.note.text, m.note.text == "这杯敬过了")
    check("按钮收了", not m.toast_back_btn.visible)

    # 4. 敬我的人不在我这边的厅里（我进厅以后才进来的）：名字、形象用 hallPulse 带回的，不是「有人」
    print("4 对方不在我这边的厅里")
    await pulse([{"from": "fake_wang", "created_at": 300}, {"from": "fake_new", "created_at": 400}],
        {"fake_wang": {"nick": "老王", "avatar": 1}, "fake_new": {"nick": "阿强", "avatar": 3}})
    check("回敬最新的阿强", m.toast_back_to == "fake_new")
    m._on_toast_back_pressed()
    await frames(2)
    check("顶部一句：" + m.note.text, m.note.text == "敬了 阿强 一杯")
    check("服务端收到敬阿强", m.cloud.fake_toasts_today.has("fake_new"))

    # 5. 提示换了一句（比如「坐好了」），按钮跟着收
    print("5 提示换了")
    await pulse([{"from": "fake_li", "created_at": 500}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("出按钮", m.toast_back_btn.visible)
    m._note("坐好了")
    await frames(2)
    check("按钮收了", not m.toast_back_btn.visible and m.toast_back_to == "")

    # 6. 提示到时间收了，按钮跟着收（到时间 _note 自己把提示框藏起来，这里直接藏）
    print("6 提示收了")
    await pulse([{"from": "fake_li", "created_at": 600}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("出按钮", m.toast_back_btn.visible)
    m.note_box.visible = false
    await frames(2)
    check("按钮收了", not m.toast_back_btn.visible)

    # 7. 插图开着：按钮叠在插图上面、黑幕下面；真点一下按钮，是按钮接到（回敬出去了），不是插图接走
    print("7 插图开着也点得到")
    await pulse([{"from": "fake_li", "created_at": 700}], {"fake_li": {"nick": "小李", "avatar": 5}})
    for i in 300:
        if is_instance_valid(m.toast_scene):
            break
        await process_frame
    var sc = m.toast_scene
    check("插图在放", is_instance_valid(sc))
    if is_instance_valid(sc):
        check("按钮在插图上面", m.toast_back_btn.get_index() > sc.get_index())
    check("黑幕在最上面", m.fade.get_index() == m.ui.get_child_count() - 1)
    var before: int = m.cloud.fake_toasts_today.size()
    var c: Vector2 = m.toast_back_btn.get_global_rect().get_center()
    for pressed in [true, false]:
        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = pressed
        ev.position = c
        ev.global_position = c
        get_root().push_input(ev, true)
        await process_frame
    await frames(2)
    check("按钮接到了点击，回敬了小李", m.cloud.fake_toasts_today.size() == before + 1 and m.cloud.fake_toasts_today.has("fake_li"))
    check("顶部一句：" + m.note.text, m.note.text == "敬了 小李 一杯")

    # 7b. 调试版：日志面板打开时盖住回敬按钮（面板在按钮上面、黑幕还是最上面）
    print("7b 调试面板盖住回敬按钮")
    m._build_debug()
    await pulse([{"from": "fake_li", "created_at": 750}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("出按钮", m.toast_back_btn.visible)
    check("日志面板在按钮上面", m.dbg_panel.get_index() > m.toast_back_btn.get_index())
    check("黑幕还是最上面", m.fade.get_index() == m.ui.get_child_count() - 1)

    # 8. 开着小游戏时不出按钮（提示也被小游戏盖着）
    print("8 开着小游戏")
    var fake_game := Control.new()
    m.game_host = fake_game
    await pulse([{"from": "fake_li", "created_at": 800}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("不出按钮", not m.toast_back_btn.visible and m.toast_back_to == "")
    m.game_host = null
    fake_game.free()

    # 8b. 看人卡片、簿子开着：按钮不出、已经出了的收掉（提示被暗底盖着，按钮不能浮在卡片上）
    print("8b 开着看人卡片、簿子")
    m._open_person_card("fake_wang")
    await pulse([{"from": "fake_li", "created_at": 820}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("卡片开着收到敬酒：不出按钮", not m.toast_back_btn.visible and m.toast_back_to == "")
    m._close_person_card()
    await pulse([{"from": "fake_li", "created_at": 840}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("出按钮", m.toast_back_btn.visible)
    m._open_person_card("fake_wang")
    await frames(2)
    check("打开卡片：按钮收了", not m.toast_back_btn.visible and m.toast_back_to == "")
    m._close_person_card()
    await pulse([{"from": "fake_li", "created_at": 860}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("出按钮", m.toast_back_btn.visible)
    m._open_book_panel("T1")
    await frames(2)
    check("打开簿子：按钮收了", not m.toast_back_btn.visible and m.toast_back_to == "")
    m._close_book_panel()

    # 9. 离开宴会厅，按钮收
    print("9 离开宴会厅")
    await pulse([{"from": "fake_li", "created_at": 900}], {"fake_li": {"nick": "小李", "avatar": 5}})
    check("出按钮", m.toast_back_btn.visible)
    m._goto("end")
    await frames(2)
    check("按钮收了", not m.toast_back_btn.visible)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
