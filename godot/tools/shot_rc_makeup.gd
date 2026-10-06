extends SceneTree
## 化妆间照真走法拍（03 10/6，把关 rc-makeup）：从后厅走廊走进门（屋名框在）、用摇杆往北顶、走到最里、走到试衣间前、走到沙发坐下、点新娘说话、点助理说话、走到最左最右。
## 全程用游戏自己的走法（go_to 寻路、摇杆、点人），不把人直接放到某处。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_rc_makeup.gd -- --dir=目录 --tag=540x960
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p"}
var mk
var ui

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and "=" in a:
            var kv := a.substr(2).split("=", true, 1)
            opt[kv[0]] = kv[1]
    m = Main.new()
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

func snap(name: String) -> void:
    await frames(6)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])

func walk_to(c, target: Vector2, secs := 40.0) -> void:
    c.walking_enabled = true
    c.go_to(target)
    var t0: int = Time.get_ticks_msec()
    while float(Time.get_ticks_msec() - t0) / 1000.0 < secs and not c.path.is_empty():
        await process_frame
    await frames(10)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_rcm_court.json"
    m.court_save.signed_in = true
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")
    mk = m.areas["makeup"]
    ui = m.lounge_ui
    var n := 0
    # 1 从后厅走廊走进门（真走进去：整屏换进屋，上方出屋名）
    m.switching = false
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(6)
    var b = m.backhall
    b.walking_enabled = true
    b.reset_to(Vector2(1363, 800))
    b.cam.reset_smoothing()
    await frames(4)
    b.go_to(b.points["to_makeup"]["pos"])
    for i in 900:
        await process_frame
        if m.state == "makeup" and not m.switching:
            break
    await frames(14)   # 屋名框刚出来
    m.dialog.visible = false
    await snap("1-真走进门第一眼")
    n += 1
    # 2 摇杆正着往上推 3 秒（看红毯上被拦住是什么样）
    mk.stick = Vector2(0, -1)
    await create_timer(3.0).timeout
    mk.stick = Vector2.ZERO
    await frames(4)
    await snap("2-摇杆正着往上推 3 秒")
    n += 1
    # 3 走到最里（新娘跟前）
    var bride_at := Vector2(float(mk.cfg["npcs"][0]["approach"][0]), float(mk.cfg["npcs"][0]["approach"][1]))
    await walk_to(mk, bride_at)
    await snap("3-走到最里新娘跟前")
    n += 1
    # 4 试衣间前
    await walk_to(mk, mk.points["dress"]["pos"])
    await snap("4-走到试衣间前")
    n += 1
    # 5 走到沙发空座坐下
    var lf = mk.lives[0]
    var seat: Dictionary = {}
    for s in lf.seats:
        if str(s.get("id", "")) == "seat_sofa_cream_free":
            seat = s
    if not seat.is_empty():
        await walk_to(mk, seat["stand"])
        await snap("5-走到沙发空座跟前（出坐下）")
        n += 1
        ui.seat_btn.pressed.emit()
        await frames(40)
        await snap("6-坐在沙发上")
        n += 1
        ui.seat_btn.pressed.emit()
        await frames(40)
    # 7 点新娘说话（点她本人：走过去再开口）
    var bn: Dictionary = lf.person("bride")
    mk.tap(mk.get_viewport().get_canvas_transform() * (bn["head"] as Vector2 + Vector2(0, 30)))
    for i in 900:
        await process_frame
        if ui.talk_box.visible:
            break
    await frames(30)
    await snap("7-点新娘走过去说话（框开着）")
    n += 1
    ui.close_talk()
    await frames(20)
    # 8 点化妆助理说话
    var asst: Dictionary = lf.person("makeup_2")
    mk.tap(mk.get_viewport().get_canvas_transform() * (asst["head"] as Vector2 + Vector2(0, 30)))
    for i in 900:
        await process_frame
        if ui.talk_box.visible:
            break
    await frames(30)
    await snap("8-点化妆助理走过去说话（框开着）")
    n += 1
    ui.close_talk()
    await frames(20)
    # 9、10 走到最左、最右
    var wb: Array = mk.cfg["walk"][0]
    await walk_to(mk, mk.nearest_free(Vector2(float(wb[0][0]) + 20.0, 700.0)))
    await snap("9-走到最左")
    n += 1
    await walk_to(mk, mk.nearest_free(Vector2(float(wb[1][0]) - 20.0, 700.0)))
    await snap("10-走到最右")
    n += 1
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
