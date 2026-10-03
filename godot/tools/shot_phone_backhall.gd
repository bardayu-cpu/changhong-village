extends SceneTree
## 后厅手机屏截图（03，10/3，测 lounge01 用）：窗口按 --resolution 开（540x960 或长屏 585x1266），人站到每个关键点，存整个窗口（带界面）。
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_phone_backhall.gd -- --dir=目录 [--tag=p]
## 每个点存 <dir>/<tag>-<名字>.png；出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p"}
const SPOTS := {
    "a-宴会厅口": Vector2(100, 780), "b-草坪口": Vector2(1440, 780), "c-厨房里": Vector2(1272, 420), "d-化妆室门口": Vector2(168, 672),
    "e-休息间门口": Vector2(504, 672), "f-麻将室门口": Vector2(840, 672), "g-厨房门口": Vector2(1176, 672), "h-休息间中间": Vector2(504, 420),
    "i-唱片机前": Vector2(424, 320), "j-最北休息间": Vector2(560, 250), "k-最南走廊": Vector2(768, 868),
}

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
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    var b = m.backhall
    b.walking_enabled = false
    m.dialog.visible = false
    await create_timer(0.8).timeout
    var n := 0
    for k in SPOTS:
        b.reset_to(SPOTS[k])
        b.cam.reset_smoothing()
        await frames(6)
        await RenderingServer.frame_post_draw
        var img: Image = get_root().get_texture().get_image()
        img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], k])
        n += 1
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
