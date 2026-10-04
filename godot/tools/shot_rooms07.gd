extends SceneTree
## 07 自己看用（10/4）：后厅麻将室、化妆间俯看一比一，不带界面。人照常
## Godot --path . --resolution 1040x480 --script res://tools/shot_rooms07.gd -- --out=图.png --cx=700 --cy=450 [--secs=0]
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"out": "", "cx": "700", "cy": "450", "secs": "0", "zoom": "1"}

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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await process_frame
    var b = m.backhall
    b.walking_enabled = false
    m.dialog.visible = false
    b.reset_to(Vector2(1436, 780))
    for i in int(float(opt["secs"]) * 30.0):
        b._process(1.0 / 30.0)
    m.hint.visible = false
    b.reset_to(Vector2(float(opt["cx"]), float(opt["cy"])))
    b.cam.zoom = Vector2.ONE * float(opt["zoom"])
    b.cam.reset_smoothing()
    for i in 6:
        await process_frame
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png(opt["out"])
    print("SHOT SAVED ", opt["out"])
    quit()
