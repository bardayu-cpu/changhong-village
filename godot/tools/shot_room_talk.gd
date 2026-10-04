extends SceneTree
## 后厅麻将室、化妆间对话截图（03，10/4，测第 67 版）：站到人跟前、点开对话、翻到选项出来那句，存整个窗口。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_room_talk.gd -- --dir=目录 --tag=p --who=mahjong:elder_n,makeup:bride [--lines=3]
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p", "who": "mahjong:elder_n", "lines": "2", "wait": "0"}

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
    m.court_save.local_path = "user://shot_room_talk_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    m.dialog.visible = false
    var b = m.backhall
    var ui = m.lounge_ui
    b.walking_enabled = true
    ui.attach(b.lounge)
    await create_timer(0.6).timeout
    var n := 0
    for pair in str(opt["who"]).split(","):
        var rid := pair.split(":")[0]
        var id := pair.split(":")[1]
        var lf = null
        for l in b.lives:
            if l.room == rid:
                lf = l
        if ui.is_open():
            ui.hide_all()
        var ap: Vector2 = lf.approach_of(id)
        b.reset_to(b.nearest_free(ap))
        b.cam.reset_smoothing()
        lf.request_talk(id)
        for i in 60:
            await process_frame
            if ui.talk_box.visible:
                break
        await frames(6)
        for k in int(opt["lines"]):
            if ui.talk_box.visible and not ui.choices.visible:
                ui.next_line()
                await frames(8)
        await frames(10)
        await RenderingServer.frame_post_draw
        get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], id])
        n += 1
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
