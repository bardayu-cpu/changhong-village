extends SceneTree
## 娱乐室截图（庄Z2 10/6，采用 v3 画面）：从后厅走廊走进门、用游戏寻路走过去拍：1 进门、2 走到地毯那桌、3 坐下摸两把、4 北边电视那块、5 西北沙发区；
## --full=1：窗口开成整间大小（1152×960），镜头放中间、1 倍，拍坐满人的整间一张（6-坐满整间）。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_mahjong_room.gd -- --dir=目录 [--tag=手机]
## Godot --path . --resolution 1152x960 --script res://tools/shot_mahjong_room.gd -- --dir=目录 --full=1
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "手机", "full": "0"}

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
    await frames(3)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])
    print("SHOT ", name, " 站在 ", m.cv.pos)

func walk(c, target: Vector2) -> void:
    c.go_to(c.nearest_free(target))
    for i in 1500:
        await process_frame
        if c.path.is_empty():
            break
    await frames(10)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_mahjong_court.json"
    m.games_save.local_path = "user://shot_mahjong_games.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    m.dialog.visible = false
    var b = m.backhall
    b.walking_enabled = true
    b.reset_to(b.spot_pos("to_mahjong") + Vector2(0, 40))
    b.cam.reset_smoothing()
    await frames(4)
    b.go_to(b.spot_pos("to_mahjong"))
    for i in 600:
        await process_frame
        if m.state == "mahjong":
            break
    await create_timer(0.5).timeout
    var c = m.cv
    c.walking_enabled = true
    await frames(10)
    if str(opt["full"]) == "1":
        var vis: Vector2 = get_root().get_visible_rect().size   # 游戏按 540 宽拉伸：整间 1100 宽塞进一屏，窗口 1100 宽时正好 1 比 1
        c.cam.zoom = Vector2.ONE * (vis.x / float(c.cfg["size"][0]))
        c.cam.position_smoothing_enabled = false
        c.cam.limit_left = -10000
        c.cam.limit_top = -10000
        c.cam.limit_right = 10000
        c.cam.limit_bottom = 10000
        c.set_process(false)
        c.cam.global_position = Vector2(float(c.cfg["size"][0]), float(c.cfg["size"][1])) / 2.0
        m.hud.visible = false
        await frames(6)
        await snap("6-坐满整间")
        quit(0)
        return
    await snap("1-进门")
    var seat: Dictionary = {}
    for s in c.lives[0].seats:
        if str(s["id"]) == "seat_mahjong_play":
            seat = s
    await walk(c, seat["stand"] + Vector2(0, 30))
    await snap("2-走到地毯那桌")
    await walk(c, seat["stand"])
    for i in 60:
        await process_frame
        if m.lounge_ui.seat_btn.visible:
            break
    m.lounge_ui.seat_btn.pressed.emit()
    for i in 120:
        await process_frame
        if is_instance_valid(m.game_host):
            break
    await create_timer(0.3).timeout
    if is_instance_valid(m.game_host):
        m.game_host._start()
        await create_timer(0.5).timeout
    await snap("3-坐下摸两把")
    if is_instance_valid(m.game_host):
        m.game_host._close()
    await create_timer(0.5).timeout
    await walk(c, Vector2(790, 204))
    await snap("4-北边电视那块")
    await walk(c, Vector2(270, 205))
    await snap("5-西北沙发区")
    print("SHOT DONE 窗口 ", get_root().size)
    quit(0)
