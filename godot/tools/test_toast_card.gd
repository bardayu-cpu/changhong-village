extends SceneTree
## 验收：体验第二轮 新 5 和「点一下继续」（01 取舍 `回执/体验第二轮-派活.md`，04 复看 `回执/体验-第43版-复看.md`）
##   新 5：干杯插图卡的高度跟着内容走——没有「谁敬了谁」那行时不留一块空红，有那行时排在两个人和「点一下继续」中间
##   点一下继续：卡上有这行小字，比「干杯」小、颜色淡；真点一下卡就收（原来就会收，这里钉住）
## 只跑 toast_scene.gd 自己，不起 main.gd
## 用法：Godot --headless --path . --script res://tools/test_toast_card.gd
## 最后一行 RESULT PASS 才算过

const ToastScene = preload("res://scripts/toast_scene.gd")
const FONT_PATH := "res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"

var started := false
var ok := true
var font: Font

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

## 卡上所有看得见的东西（人、杯子、字）最低到哪；金光飞出去会被卡边裁掉，不算
func content_bottom(sc) -> float:
    var b := 0.0
    for c in [sc.left_p, sc.right_p, sc.title, sc.cap, sc.hint]:
        if c != null:
            b = maxf(b, (c as Control).position.y + (c as Control).size.y)
    return b

func open_card(caption: String):
    var sc = ToastScene.new()
    get_root().add_child(sc)
    sc.play(font, 0, 5, "干杯", caption)
    # 等人走到位、碰完杯（插图自己的钟过 1.2 秒）
    for i in 600:
        if sc.t >= 1.2:
            break
        await process_frame
    return sc

func run() -> void:
    font = load(FONT_PATH)
    var vp: Vector2 = get_root().get_visible_rect().size

    # 1. 没有那行字（敬人、别人当场敬你，B22 以后都是这样）
    print("1 没有「谁敬了谁」那行：卡跟着内容收高（新 5）")
    var sc = await open_card("")
    var ps: Vector2 = sc.panel.size
    var bottom: float = content_bottom(sc)
    var people_bottom: float = sc.left_p.position.y + sc.left_p.size.y
    print("  卡 %.0f×%.0f，内容到 %.0f，两个人脚底 %.0f，「点一下继续」顶 %.0f" % [ps.x, ps.y, bottom, people_bottom, sc.hint.position.y])
    check("没排那行字", sc.cap == null)
    check("卡底下不留空：内容底到卡底 %.0f ≤ 16" % (ps.y - bottom), ps.y - bottom <= 16.0)
    check("两个人和「点一下继续」中间不空一行：%.0f ≤ 12" % (sc.hint.position.y - people_bottom), sc.hint.position.y - people_bottom <= 12.0)
    check("比原来 300 高的矮", ps.y < 300.0)
    check("卡在屏幕正中", absf(sc.panel.position.y + ps.y * 0.5 - vp.y * 0.5) <= 1.0)

    # 2. 「点一下继续」
    print("2 点一下继续")
    var h: Label = sc.hint
    check("有这行：「%s」" % h.text, h != null and h.text == "点一下继续" and h.visible)
    var h_size: int = h.get_theme_font_size("font_size")
    var t_size: int = sc.title.get_theme_font_size("font_size")
    var h_col: Color = h.get_theme_color("font_color")
    check("字比「干杯」小（%d < %d）" % [h_size, t_size], h_size < t_size)
    check("颜色淡（透明度 %.2f ≤ 0.6）" % h_col.a, h_col.a <= 0.6)
    check("在两个人下面、卡里面", h.position.y >= people_bottom and h.position.y + h.size.y <= ps.y)
    check("不压「干杯」", h.position.y >= sc.title.position.y + sc.title.size.y)

    # 真点一下：卡收了
    var done := [false]
    sc.finished.connect(func(): done[0] = true)
    var c: Vector2 = vp * 0.5
    for pressed in [true, false]:
        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = pressed
        ev.position = c
        ev.global_position = c
        get_root().push_input(ev, true)
        await process_frame
    for i in 120:
        if done[0]:
            break
        await process_frame
    check("点一下卡就收了", done[0] and not is_instance_valid(sc))

    # 3. 有那行字（进厅先见人：别人不在时敬了你，进厅补放一张）
    print("3 有「谁敬了谁」那行：排在两个人和「点一下继续」中间")
    var sc2 = await open_card("小李 敬了你一杯")
    var ps2: Vector2 = sc2.panel.size
    var pb2: float = sc2.left_p.position.y + sc2.left_p.size.y
    print("  卡 %.0f×%.0f，那行 y %.0f，「点一下继续」y %.0f" % [ps2.x, ps2.y, sc2.cap.position.y, sc2.hint.position.y])
    check("排了那行", sc2.cap != null and sc2.cap.text == "小李 敬了你一杯")
    check("那行在两个人下面、「点一下继续」上面，不重叠",
        sc2.cap.position.y >= pb2 and sc2.cap.position.y + sc2.cap.size.y <= sc2.hint.position.y)
    check("卡底下不留空：%.0f ≤ 16" % (ps2.y - content_bottom(sc2)), ps2.y - content_bottom(sc2) <= 16.0)
    check("有那行的卡比没有的高", ps2.y > ps.y)
    check("卡没出屏幕", sc2.panel.position.y >= 0.0 and sc2.panel.position.y + ps2.y <= vp.y)
    sc2.queue_free()
    await frames(2)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
