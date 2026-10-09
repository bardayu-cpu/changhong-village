extends SceneTree
## 后厅手机屏截图（03，10/3，测 lounge01 用）：窗口按 --resolution 开（540x960 或长屏 585x1266），人站到每个关键点，存整个窗口（带界面）。
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_phone_backhall.gd -- --dir=目录 [--tag=p]
## 每个点存 <dir>/<tag>-<名字>.png；出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p"}
const SPOTS := {
    "m01-化妆间门口": Vector2(168, 672), "m02-梳妆台前": Vector2(130, 300), "m03-新娘化妆师旁": Vector2(215, 300), "m04-中式区": Vector2(60, 412),
    "m05-西式区": Vector2(280, 412), "m06-日式区": Vector2(60, 486), "m07-民族区": Vector2(262, 486), "m08-岛西边": Vector2(126, 514),
    "m09-岛东边": Vector2(210, 514), "m10-岛北横道": Vector2(168, 486), "m11-沙发区": Vector2(82, 614), "m12-行李礼物道": Vector2(240, 666),
    "m13-西式后排道": Vector2(258, 354), "m14-全身镜前": Vector2(30, 624), "m15-屏风前": Vector2(296, 620),
    "l01-休息间门口": Vector2(504, 672), "l02-休息间中间": Vector2(504, 420), "l03-唱片机前": Vector2(424, 320), "l04-衣帽架旁": Vector2(630, 618),
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
    var locs := {}
    for k in SPOTS:
        b.reset_to(SPOTS[k])
        b.cam.reset_smoothing()
        await frames(6)
        await RenderingServer.frame_post_draw
        var img: Image = get_root().get_texture().get_image()
        img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], k])
        var c: Vector2 = b.cam.get_screen_center_position()
        var vs: Vector2 = Vector2(m.view.get_child(0).size)
        var scr: Vector2 = (SPOTS[k] - c) * b.cam.zoom.x + vs * 0.5
        locs[k] = [scr.x, scr.y, b.cam.zoom.x, float(get_root().size.x) / 540.0]
        n += 1
    var f := FileAccess.open("%s/%s-locs.json" % [opt["dir"], opt["tag"]], FileAccess.WRITE)
    f.store_string(JSON.stringify(locs))
    f.close()
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
