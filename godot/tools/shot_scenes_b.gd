extends SceneTree
## 每块用 layered_hall 的场景进一次、站在出生点，存整个窗口（03 10/5，测 makeup-125 改了公共 layered_hall）。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_scenes_b.gd -- --dir=目录 --tag=540x960
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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_scn_court.json"
    m.court_save.signed_in = true
    var ids: Array = ["court", "banquet", "backhall", "lawn", "lake", "orchard", "parking", "plaza", "kids", "shop", "rest2", "wkitchen", "garden", "frontgate", "backgate", "makeup"]
    var n := 0
    for id in ids:
        if id != "court" and id != "banquet":
            m.ensure_canvas(id)
        m.switching = false
        if m.lounge_ui != null and m.lounge_ui.is_open():
            m.lounge_ui.hide_all()
        m.dialog.visible = false
        m._show_canvas(id)
        m._goto(id)
        await frames(4)
        var c = m.cv
        c.reset_to(c.SPAWN)
        c.cam.reset_smoothing()
        await frames(6)
        await RenderingServer.frame_post_draw
        get_root().get_texture().get_image().save_png("%s/%s-%02d-%s.png" % [opt["dir"], opt["tag"], n, id])
        n += 1
    print("SHOT DONE ", n)
    quit(0)
