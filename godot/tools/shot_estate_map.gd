extends SceneTree
## 全景地图手机截图（07 10/4）：迎宾院里名字牌上的传送门、地图打开、点后花园问「去后花园？」、点「去」到了后花园、点自己那块「你就在这里」。
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_estate_map.gd -- --dir=目录 [--tag=540x960]
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "540x960"}
var n := 0

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

func frames(k: int) -> void:
    for i in k:
        await process_frame

func shot(name: String) -> void:
    await frames(8)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])
    n += 1

func press(at: Vector2) -> InputEventMouseButton:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = at
    return e

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_estate_map_court.json"
    m.court_save.signed_in = true
    m._enter_court()
    for i in 200:
        await process_frame
        if m.state == "court" and not m.switching:
            break
    m.dialog.visible = false
    m.hint.visible = false
    m.court.walking_enabled = true
    m.court.reset_to(Vector2(900, 640))
    m.court.cam.reset_smoothing()
    var em = m.estate_map
    await shot("1-名字牌上的传送门")
    em.open()
    await shot("2-地图打开")
    em.view._gui_input(press(em.view.rect_of(em.block("garden")).get_center()))
    await shot("3-问去后花园")
    (em.confirm.find_child("map_yes", true, false) as Button).pressed.emit()
    for i in 400:
        await process_frame
        if m.state == "garden" and not m.switching:
            break
    m.dialog.visible = false
    m.hint.visible = false
    await shot("4-到了后花园")
    em.open()
    em.view._gui_input(press(em.view.rect_of(em.block("garden")).get_center()))
    await shot("5-点自己那块")
    print("SHOT DONE ", n)
    quit()
