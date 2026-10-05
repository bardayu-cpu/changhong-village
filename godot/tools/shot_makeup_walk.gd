extends SceneTree
## 化妆间第二轮截图（庄Z2 10/6；庄Z3 体验复看第 4 条：别摆位置，照真走法拍）：从后厅走廊走进化妆间门口，用游戏自己的寻路（go_to，跟点地走一样）
## 一路走过去拍：进门、走到首饰柜后、走到衣架后、走到奶油沙发空座跟前点「坐下」、走到最左、走到最右。存整个窗口。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_makeup_walk.gd -- --dir=目录 [--tag=手机]
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "手机"}

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

## 点地走过去（跟玩家点一下地一样走寻路），走到或者 20 秒停
func walk(c, target: Vector2) -> void:
    c.go_to(c.nearest_free(target))
    for i in 1200:
        await process_frame
        if c.path.is_empty():
            break
    await frames(10)

func item(c, id: String) -> Array:
    for it in c.cfg["items"]:
        if str(it["id"]) == id:
            return it["rect"]
    return []

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_makeup_walk_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    m.dialog.visible = false
    var b = m.backhall
    b.walking_enabled = true
    b.reset_to(b.spot_pos("to_makeup") + Vector2(0, 40))
    b.cam.reset_smoothing()
    await frames(4)
    b.go_to(b.spot_pos("to_makeup"))   # 走进化妆间门口：整屏换进屋
    for i in 600:
        await process_frame
        if m.state == "makeup":
            break
    await create_timer(0.5).timeout
    var c = m.cv
    c.walking_enabled = true
    await frames(10)
    await snap("1-进门")
    var j: Array = item(c, "jewel_2")
    await walk(c, Vector2((j[0] + j[2]) * 0.5, j[1] - 30))
    await snap("2-走到首饰柜后")
    var r: Array = item(c, "rack_w2")
    await walk(c, Vector2((r[0] + r[2]) * 0.5, r[1] - 30))
    await snap("3-走到衣架后")
    var sofa: Array = item(c, "sofa_cream")
    await walk(c, Vector2(sofa[2] - 30, sofa[3] + 20))
    var ui = m.lounge_ui
    for i in 60:
        await process_frame
        if ui.seat_btn.visible:
            break
    if ui.seat_btn.visible:
        ui.seat_btn.pressed.emit()
        await create_timer(1.0).timeout
    else:
        print("没出「坐下」按钮")
    await snap("4-坐奶油沙发")
    if ui.seat_btn.visible and c.get("seated"):
        ui.seat_btn.pressed.emit()   # 起身
        await create_timer(1.0).timeout
    var mid := float(c.cfg["size"][1]) * 0.5
    await walk(c, Vector2(20, mid))
    await snap("5-走到最左")
    await walk(c, Vector2(float(c.cfg["size"][0]) - 20, mid))
    await snap("6-走到最右")
    print("SHOT DONE 窗口 ", get_root().size)
    quit(0)
