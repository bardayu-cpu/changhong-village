extends SceneTree
## 验收：进厅先见人（01 9/23 派活，体验评审 0923 改法一；同批体验 B6「进厅三层框叠在一起」）。
## 无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据（fake_arrival_mode）。服务端那头（谁来过、谁写了、排法）
## 在 server-claude/test 里测；这里测手机这头：第一次进厅那句话、没新鲜事不弹卡、卡上的人站起来、翻簿子、一次只留一层
## 用法：Godot --headless --path . --script res://tools/test_arrival.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Card = preload("res://scripts/arrival_card.gd")

var m
var started := false
var ok := true

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

func wait(secs: float) -> void:
    await create_timer(secs).timeout

## 一份假的 enterHall 返回：我坐 tid，这桌还有谁（openid -> sat_at），我的邀请人是谁
func fake(tid: String, seats: Dictionary, inviter, empty := false) -> Dictionary:
    var st: Array = []
    for who in seats:
        st.append({"openid": who, "chair_no": 1, "sat_at": seats[who]})
    st.append({"openid": "me", "chair_no": 9, "sat_at": 999})
    return {"me": {"table_id": tid, "chair_no": 9},
        "tables": [{"id": tid, "seats": st}, {"id": "T9", "seats": [{"openid": "far", "sat_at": 1}]}],
        "arrival": {"first_visit": true, "table_was_empty": empty},
        "names": {"me": {"nick": "我", "inviter": inviter}, "wang": {"nick": "老王"}, "li": {"nick": "小李"},
            "long": {"nick": "一二三四五六七八九十"}}}

func run() -> void:
    # 0. 第一次进厅那句话：坐谁那桌（这桌第一个坐下的人，和桌牌一个算法）、谁带你来的
    print("0 第一次进厅那句话")
    var f := func(d): return Main.first_visit_line(d, "me")
    check("邀请人就是这桌第一个坐的：%s" % f.call(fake("T3", {"wang": 10, "li": 20}, "wang")),
        f.call(fake("T3", {"wang": 10, "li": 20}, "wang")) == "老王 带你来的 你们坐一桌")
    check("邀请人不是这桌第一个坐的：%s" % f.call(fake("T3", {"li": 5, "wang": 10}, "wang")),
        f.call(fake("T3", {"li": 5, "wang": 10}, "wang")) == "老王 带你来的 你坐 小李 那桌")
    check("邀请人那桌满了、这一枝新开一桌：%s" % f.call(fake("T4", {}, "wang", true)),
        f.call(fake("T4", {}, "wang", true)) == "老王 带你来的 这桌还空着 你先坐")
    check("没邀请人、空桌：%s" % f.call(fake("T4", {}, null, true)), f.call(fake("T4", {}, null, true)) == "这桌还空着 你是第一个坐的")
    check("没邀请人、桌上有人：%s" % f.call(fake("T4", {"li": 3}, null)), f.call(fake("T4", {"li": 3}, null)) == "你坐 小李 那桌")
    check("长名字截到 6 个字：%s" % f.call(fake("T4", {"long": 3}, null)), f.call(fake("T4", {"long": 3}, null)) == "你坐 一二三四五六… 那桌")
    var bench := fake("bench", {}, "wang")
    check("坐长凳不在这说（另有长凳那句）", f.call(bench) == "")

    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    # 这里测的是有没有新鲜事弹不弹卡：当这位进过后厅了（没进过后厅的人卡上多一行「东边侧门通后厅」，test_fixes_1003 测）
    m.court_save.local_path = "user://test_arrival_court.json"
    m.court_save.backhall_seen = true

    # 1. 第一次进厅（假数据 first）：新人那句换掉「到啦～」，不弹卡
    print("1 第一次进厅")
    m.cloud.fake_arrival_mode = "first"
    m.nickname = "小李"
    await m._enter_banquet()
    await wait(2.0)
    check("对白框说的是坐哪桌：%s" % m.dialog_text.text, m.dialog.visible and m.dialog_text.text.contains("那桌"))
    check("第一次进厅不弹卡", not is_instance_valid(m.arrival_card))
    check("也不出原来那一行提示", not (m.note_box.visible and m.note.text.contains("敬了你")))

    # 2. 没有新鲜事：什么都不弹（别写「没人来过」这种冷清话）
    print("2 没新鲜事")
    m.cloud.fake_arrival_mode = "card"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await wait(3.0)
    check("不弹卡", not is_instance_valid(m.arrival_card))
    check("也没有冷清话", not m.note.text.contains("没人"))
    m.cloud.fake_no_news = false

    # 3. 有新鲜事：插图放完出卡；卡上说到的、正坐在厅里的人站起来朝我举杯（老王坐 T1）
    print("3 出卡、卡上的人站起来")
    await m._enter_banquet()
    var waited := 0.0
    while not is_instance_valid(m.arrival_card) and waited < 8.0:
        await wait(0.1)
        waited += 0.1
    await frames(2)
    check("出卡了", is_instance_valid(m.arrival_card))
    check("卡上说到老王和小李：%s" % [m.arrival_card.people], "fake_wang" in m.arrival_card.people and "fake_li" in m.arrival_card.people)
    var standing := 0
    for n in m.hall.world.get_children():
        if str(n.name).begins_with("toast_stand"):
            standing += 1
    check("坐在厅里的站起来举杯：%d 个" % standing, standing >= 1)
    # 一次只留一层：对白框收起；卡排在屏幕上方，不压底下的按钮
    check("对白框收起", not m.dialog.visible)
    var cr: Rect2 = m.arrival_card.get_global_rect()
    check("卡最多三行、不超过屏幕三成高（%.0f / %.0f）" % [cr.size.y, m.ui.size.y], m.arrival_card.rows_box.get_child_count() <= 3 and cr.size.y < m.ui.size.y * 0.3)

    # 4. 点「翻簿子」：打开我这桌的簿子，卡收起
    print("4 点翻簿子")
    var bb: Button = m.arrival_card.rows_box.get_child(1).get_node("btn")
    bb.emit_signal("pressed")
    await frames(3)
    check("簿子开了", m.book_open)
    check("卡收了", not is_instance_valid(m.arrival_card))
    m._close_book_panel() if m.has_method("_close_book_panel") else null
    await frames(2)

    # 5. 点卡上没按钮的地方：收起
    print("5 点一下收起")
    m._show_arrival_card([{"kind": "visit", "who": "fake_li", "count": 1}], m.hall.resident_names)
    await frames(2)
    check("卡在", is_instance_valid(m.arrival_card))
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    m.arrival_card._gui_input(ev)
    await frames(2)
    check("点一下收了", not is_instance_valid(m.arrival_card))

    # 6. 开小游戏、离开宴会厅：卡跟着收（它们有自己的一层）
    print("6 离开宴会厅卡跟着收")
    m._show_arrival_card([{"kind": "visit", "who": "fake_li", "count": 1}], m.hall.resident_names)
    await frames(2)
    m._goto("end")
    await frames(3)
    check("离开宴会厅：卡收了", not is_instance_valid(m.arrival_card))

    # 7. 03 第 43 版回归：插图放着的时候开了席面菜单，插图放完不能把走路放开（原来一律放开）
    print("7 插图放完不盖掉「菜单开着不能走」")
    m.cloud.fake_no_news = false
    m.cloud.fake_arrival_mode = "card"
    await m._enter_banquet()
    var w2 := 0.0
    while not is_instance_valid(m.toast_scene) and w2 < 3.0:
        await wait(0.05)
        w2 += 0.05
    m.banquet_ui.open_menu()
    while is_instance_valid(m.toast_scene) and w2 < 8.0:
        await wait(0.1)
        w2 += 0.1
    await frames(3)
    check("菜单开着，插图放完仍不能走", m._menu_open() and not m.hall.walking_enabled)
    if m.banquet_ui.has_method("close_menu"):
        m.banquet_ui.close_menu()

    # 8. 画布里画出来的牌都得是出口牌（03：「回忆册」回字开头漏过了）
    print("8 画出来的牌都是出口牌")
    var bad: Array = []
    for cv in [m.court, m.backhall, m.lawn, m.lake, m.orchard]:
        for l in cv.labels.get_children():
            if not m.court.is_exit_label(str((l as Label).text)):
                bad.append(str((l as Label).text))
    check("不是出口的牌 %s" % [bad], bad.is_empty() and not m.court.is_exit_label("回忆册"))

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
