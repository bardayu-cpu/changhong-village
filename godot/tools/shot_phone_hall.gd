extends SceneTree
## 宴会厅手机屏截图（03，10/4，测 liantu01 第 65 版）：人站到指定点，存整个窗口（带界面）。要有窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_phone_hall.gd -- --dir=目录 --tag=p --spots="名=x,y;名=x,y"
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p", "spots": ""}
var SPOTS := {}

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and "=" in a:
            var kv := a.substr(2).split("=", true, 1)
            opt[kv[0]] = kv[1]
    for part in str(opt["spots"]).split(";"):
        var kv := part.split("=")
        if kv.size() == 2:
            var xy := kv[1].split(",")
            SPOTS[kv[0]] = Vector2(float(xy[0]), float(xy[1]))
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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_hall_court.json"
    await m._enter_court()
    m.dialog.visible = false
    m._show_canvas("banquet")
    m._goto("banquet")
    var h = m.hall
    h.walking_enabled = false
    await create_timer(0.8).timeout
    var n := 0
    for k in SPOTS:
        h.reset_to(SPOTS[k])
        h.snap_cam()
        await frames(8)
        await RenderingServer.frame_post_draw
        var img: Image = get_root().get_texture().get_image()
        img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], k])
        n += 1
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
