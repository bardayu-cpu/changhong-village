extends SceneTree
## 休息间人物样板截图（03，10/4，测 build57 第 58、59 版用）：窗口按 --resolution 开（540x960 或长屏 585x1266），存整个窗口（带界面）。
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_lounge_ui.gd -- --dir=目录 --tag=p
## 出：bubbles（站休息间中间、四位在冒泡）、near_seat（走到空座位跟前出「坐下」）、seated_mid（坐北边沙发中间，按钮「起来」「跟奶奶聊聊」）、talk（对话框）、card（身份卡）、
##   seated_tv / seated_reading / seated_love（坐电视沙发、看书角单人沙发、东南双人沙发）
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p"}

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

func shot(name: String) -> void:
    await frames(8)
    await RenderingServer.frame_post_draw
    var img: Image = get_root().get_texture().get_image()
    img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_lounge_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    var b = m.backhall
    var life = b.lounge
    var ui = m.lounge_ui
    ui.attach(life)
    m.dialog.visible = false
    m.hint.visible = false
    b.walking_enabled = true
    await create_timer(0.6).timeout
    # 1 冒泡（两组各一句，停住）
    b.reset_to(Vector2(504, 470))
    b.face = "up"
    b.cam.reset_smoothing()
    await frames(20)
    life.frozen = true
    for id in life.bubbles.keys():
        life._hide_bubble(id)
    life.show_bubble("lounge_10", str(life.data["chat"][0]["lines"][1][1]))
    life.show_bubble("lounge_05", str(life.data["chat"][1]["lines"][0][1]))
    await frames(20)
    ui.sync()
    await shot("1-bubbles")
    # 2 走到空座位跟前出「坐下」：东南双人沙发北座
    var seat_a: Dictionary = life.seat_by_id("loveseat_n")
    b.reset_to(seat_a["stand"])
    b.face = str(seat_a["face"])
    b.cam.reset_smoothing()
    await frames(10)
    ui.sync()
    await shot("2-near_seat")
    # 3 坐北边沙发中间
    var sm: Dictionary = life.seat_by_id("sofa_m")
    b.reset_to(sm["stand"])
    life.sit(sm)
    b.cam.reset_smoothing()
    for i in 80:
        await process_frame
    ui.sync()
    await shot("3-seated_mid")
    # 4 对话框、5 身份卡
    life.request_talk("lounge_09")
    await frames(6)
    await shot("4-talk")
    ui.open_card("lounge_09")
    await frames(6)
    await shot("5-card")
    ui.close_card()
    ui.close_talk()
    b.stand_up()
    await frames(30)
    # 6 别的座位
    for pr in [["tv_sofa_s", "6-seated_tv"], ["reading_chair", "7-seated_reading"], ["loveseat_s", "8-seated_love"]]:
        var s: Dictionary = life.seat_by_id(pr[0])
        b.reset_to(s["stand"])
        life.sit(s)
        b.cam.reset_smoothing()
        for i in 80:
            await process_frame
        ui.sync()
        await shot(pr[1])
        b.stand_up()
        await frames(20)
    print("SHOT DONE ", get_root().size)
    quit(0)
