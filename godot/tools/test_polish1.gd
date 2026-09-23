extends SceneTree
## 验收：体验第一轮（01 9/23 派，04 基线报告 `回执/体验-第41版-全场.md`）里 02 自己做的宴会厅、顶上那几条：
## A1 金币和席面菜单不压胶囊、B1 走路提示有底框只出一次、五.1 摇杆看得见和提示提到摇杆、B2 世界里的字 18 号带暗底、
## B3 自己的名字碰到别的字就让开、B4 名字牌不出屏幕边、B17/B18 添礼金、B22 敬酒那句只说一遍、B23「看看 XX」、
## B24 点暗处关卡片和簿子（原来就管用，04 是读代码判的，这里钉住）
## 无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据
## 用法：Godot --headless --path . --script res://tools/test_polish1.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")

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

## 屏上点一下（坐标是视口里的，窗口有缩放，push_input 要按本地坐标）
func click(p: Vector2) -> void:
    var mv := InputEventMouseMotion.new()
    mv.position = p
    mv.global_position = p
    root.push_input(mv, true)
    await process_frame
    for pressed in [true, false]:
        var e := InputEventMouseButton.new()
        e.button_index = MOUSE_BUTTON_LEFT
        e.pressed = pressed
        e.position = p
        e.global_position = p
        root.push_input(e, true)
        await process_frame

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    # 进厅小卡那一套（插图、卡）这里不看，关掉，免得插图整屏接点击、把下面点暗处那两下吃掉
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await create_timer(0.6).timeout

    # A1：右上角整块留给微信胶囊（下沿约 y 124，左沿约 x 400 起）
    print("A1 金币、席面菜单不压胶囊")
    var capsule := Rect2(m.ui.size.x - 140.0, 0.0, 140.0, 124.0)
    var coins: Rect2 = (m.hud.find_child("coins_chip", true, false) as Control).get_global_rect()
    check("金币在左上角 %s" % coins, not coins.intersects(capsule) and coins.position.x < m.ui.size.x * 0.5)
    m.banquet_ui.chip.visible = true
    var menu: Rect2 = m.banquet_ui.chip.get_global_rect()
    check("席面菜单挪到左边 %s" % menu, not menu.intersects(capsule) and menu.position.x < m.ui.size.x * 0.5)

    # B1：走路提示有底框、在屏幕下半截，走过一次以后换场景也不再出
    print("B1 走路提示")
    check("有底框（是一块面板，不是光字）", m.hint is PanelContainer)
    check("提示提到摇杆：%s" % m.LINE_WALK_HINT, m.LINE_WALK_HINT.contains("圈"))
    var hr: Rect2 = m.hint.get_global_rect()
    check("在屏幕下半截，不压喜字和新人 %s" % hr, hr.position.y > m.ui.size.y * 0.5)
    m._hide_hint()
    await m._enter_banquet()
    await frames(2)
    check("走过一次，再进场景不再出", not m.hint.visible)

    # 五.1：摇杆在浅色地上看得见——底子是深色半透明
    print("五.1 摇杆")
    var sb: StyleBoxFlat = m.stick_base.get_theme_stylebox("panel")
    check("摇杆底是深色 %s" % sb.bg_color, sb.bg_color.v < 0.3 and sb.bg_color.a >= 0.25)

    # B2：世界里的字 18 号、垫暗底
    print("B2 世界里的字")
    var tag: Label = m.hall.tag
    check("自己的名字 %d 号" % tag.get_theme_font_size("font_size"), tag.get_theme_font_size("font_size") >= 16)
    var tsb := tag.get_theme_stylebox("normal") as StyleBoxFlat
    check("自己的名字有暗底", tsb != null and tsb.bg_color.a > 0.5 and tsb.bg_color.v < 0.2)
    var small := 0
    for c in m.hall.seat_tags.get_children():
        if c is Label and (c as Label).get_theme_font_size("font_size") < 16:
            small += 1
    check("桌牌、别人的名字都不小于 16 号（小的 %d 个）" % small, small == 0)

    # B3：自己的名字碰到别的字就让开
    print("B3 名字让开")
    var other: Control = null
    for c in m.hall.seat_tags.get_children():
        if c is Label:
            other = c
            break
    if other != null:
        m.hall.tag_anchor.global_position = other.global_position + other.size * 0.5 + Vector2(0, tag.size.y * 0.5)
        check("叠上了：自己的名字让开", not m.hall._tag_clear())
        m.hall.tag_anchor.global_position = other.global_position + Vector2(0, 400)
        check("走开了：自己的名字回来", m.hall._tag_clear())

    # B4：名字牌不出屏幕边
    print("B4 名字牌往屏幕里收")
    await frames(3)
    var cam: Camera2D = m.hall.cam
    var half: float = m.ui.size.x * 0.5 / cam.zoom.x
    var cx: float = cam.get_screen_center_position().x
    var out := 0
    for c in m.hall.seat_tags.get_children():
        if c is Control and (c as Control).visible:
            var l: Control = c
            if l.position.x < cx - half - 0.5 or l.position.x + l.size.x > cx + half + 0.5:
                out += 1
    check("出屏幕边的名字牌 %d 个" % out, out == 0)

    # B17、B18：添礼金，数字带「金」，「全部」先问一句，「手上 N 金」那行留着
    print("B17、B18 添礼金")
    m.games_save.coins = 120
    m._refresh_gift_row()
    m._open_gift_pick()
    await frames(2)
    var texts: Array = []
    for c in m.gift_pick.get_children():
        if c is Button and not c.is_queued_for_deletion():
            texts.append((c as Button).text)
    check("数字后面都带金：%s" % [texts], texts.has("8 金") and texts.has("88 金") and texts.has("全部 120 金"))
    check("「手上 120 金」那行还在", m.gift_row.visible and (m.gift_row.get_node("coins") as Label).text == "手上 120 金")
    var all_btn: Button = null
    for c in m.gift_pick.get_children():
        if c is Button and (c as Button).text == "全部 120 金":
            all_btn = c
    all_btn.emit_signal("pressed")
    await frames(2)
    check("点全部先问一句，金币还没动", m.games_save.coins == 120 and m.gift_pick.get_node_or_null("yes") != null)
    (m.gift_pick.get_node("yes") as Button).emit_signal("pressed")
    await frames(2)
    check("点「添」才添", m.games_save.coins == 0)

    # B22：敬酒以后那句只在顶上说一遍，插图下面不重复
    print("B22 敬酒那句只说一遍")
    m._on_toast_result({"ok": true}, "fake_li", {"nick": "小李", "avatar": 5})
    await frames(2)
    var sc = m.toast_scene
    var dup := false
    if is_instance_valid(sc):
        for c in sc.find_children("*", "Label", true, false):
            if (c as Label).text == m.note.text:
                dup = true
        sc.closing = sc.t
    check("顶上「%s」，插图里不再有同一句" % m.note.text, m.note.text.contains("敬了") and not dup)
    await create_timer(0.6).timeout

    # B23：走近坐着的人，底下那个按钮写「看看 XX」
    print("B23 看看 XX")
    m._on_person_near("fake_wang")
    await frames(2)
    check("按钮：%s" % m.person_btn.text, m.person_btn.text == "看看 老王")
    m._on_person_near("")

    # B24：点暗处关卡片、簿子
    print("B24 点暗处关")
    m._open_person_card("fake_wang")
    await frames(2)
    check("卡片开了", m.card_open)
    await click(Vector2(20, m.ui.size.y - 20))
    await frames(2)
    check("点暗处关了卡片", not m.card_open)
    m._open_book_panel("T1")
    await create_timer(0.3).timeout
    check("簿子开了", m.book_open)
    await click(Vector2(20, m.ui.size.y - 20))
    await frames(2)
    check("点暗处关了簿子", not m.book_open)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
