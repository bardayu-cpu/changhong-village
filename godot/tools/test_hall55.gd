extends SceneTree
## 验收：55 桌试验厅（01 9/24 派，真机看帧率）。只在调试版日志面板里有入口；点进去原来的场景停掉、藏起来，
## 换成 55 桌色块厅（330 个 NPC），屏上写帧率；「550 人」换坐满；「回去」原样回来，宴会厅接着能走
## 用法：Godot --headless --path . --script res://tools/test_hall55.gd
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

    print("0 正式版没有入口")
    check("不是调试版时没有调试面板", m.dbg == null or m.is_debug())

    print("1 调试面板里有入口")
    m._build_debug()
    var found := false
    for b in m.dbg_panel.find_children("*", "Button", true, false):
        if (b as Button).text == "55 桌试验厅":
            found = true
            (b as Button).emit_signal("pressed")
    check("日志面板里有「55 桌试验厅」按钮", found)
    await frames(3)

    print("2 点进去")
    check("试验厅开了", m.h55 != null)
    check("55 桌 %d、NPC %d" % [m.h55.slots.size(), m.h55.guests.size()], m.h55.slots.size() == 55 and m.h55.guests.size() == 330)
    check("原来的场景藏起来、停掉", not m.view.visible and m.view.get_child(0).process_mode == Node.PROCESS_MODE_DISABLED)
    check("日志面板收了", not m.dbg_panel.visible)
    await create_timer(12.0).timeout
    await frames(2)
    check("量完一轮有数：%s" % m.h55_info.text.replace("\n", " / "), not m.h55.stats.is_empty() and m.h55_info.text.contains("上一轮"))

    print("3 换 550 人")
    for b in m.h55_box.find_children("*", "Button", true, false):
        if (b as Button).text == "550 人":
            (b as Button).emit_signal("pressed")
    await frames(3)
    check("坐满 550：%d" % m.h55.guests.size(), m.h55 != null and m.h55.guests.size() == 550)
    var boxes := 0
    for c in m.ui.get_children():
        if c is SubViewportContainer and c != m.view and not c.is_queued_for_deletion():
            boxes += 1
    check("只留一个试验厅（旧的收掉了）：%d" % boxes, boxes == 1)

    print("4 回去")
    for b in m.h55_box.find_children("*", "Button", true, false):
        if (b as Button).text == "回去":
            (b as Button).emit_signal("pressed")
    await frames(3)
    check("试验厅关了", m.h55 == null)
    check("原来的场景回来、接着跑", m.view.visible and m.view.get_child(0).process_mode == Node.PROCESS_MODE_INHERIT)
    check("还在宴会厅", m.state == "banquet")
    var p0: Vector2 = m.hall.pos
    m.hall.walking_enabled = true
    m.hall.go_to(p0 + Vector2(-60, -40))
    await create_timer(1.0).timeout
    check("宴会厅接着能走（走了 %.0f）" % m.hall.pos.distance_to(p0), m.hall.pos.distance_to(p0) > 10.0)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
