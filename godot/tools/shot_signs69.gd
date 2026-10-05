extends SceneTree
## 第 69 版路牌截图（03，10/4）：人站到指定块指定点，存整个窗口（带界面）。要有窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_signs69.gd -- --dir=目录 --tag=p --spots="名=块:x,y;名=块:x,y"
## 例：--spots="果园南=orchard:386,1000;后厅=backhall:264,830"
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p", "spots": ""}

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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_signs69_court.json"
    m.court_save.signed_in = true
    var n := 0
    for part in str(opt["spots"]).split(";"):
        var kv := part.split("=")
        if kv.size() != 2:
            continue
        var cp := kv[1].split(":")
        var k: String = cp[0]
        var xy := cp[1].split(",")
        var sp := Vector2(float(xy[0]), float(xy[1]))
        m.ensure_canvas(k)
        m.switching = false
        m._show_canvas(k)
        m._goto(k)
        var b = m.cv
        b.walking_enabled = false
        m.dialog.visible = false
        b.reset_to(sp)
        if b.get("cam") != null:
            b.cam.reset_smoothing()
        await frames(8)
        await RenderingServer.frame_post_draw
        var img: Image = get_root().get_texture().get_image()
        img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], kv[0]])
        n += 1
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
