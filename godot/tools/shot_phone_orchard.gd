extends SceneTree
## 后厅手机屏截图（03，10/3，测 lounge01 用）：窗口按 --resolution 开（540x960 或长屏 585x1266），人站到每个关键点，存整个窗口（带界面）。
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_phone_backhall.gd -- --dir=目录 [--tag=p]
## 每个点存 <dir>/<tag>-<名字>.png；出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p"}
const SPOTS := {
    "o01-进场": Vector2(768, 1076), "o02-草莓点": Vector2(400, 796), "o03-枇杷点": Vector2(1150, 756), "o04-收购处点": Vector2(980, 1122),
    "o05-最北": Vector2(768, 480), "o06-路中": Vector2(768, 760), "o07-摊子后": Vector2(980, 990), "o08-摊子前": Vector2(980, 1112),
    "o09-摊子左": Vector2(872, 1050), "o10-摊子右": Vector2(1086, 1050), "o11-板车后": Vector2(1180, 996), "o12-板车前": Vector2(1180, 1114),
    "o13-枇杷树后": Vector2(862, 585), "o14-枇杷树前": Vector2(862, 640), "o15-稻草人后": Vector2(400, 500), "o16-稻草人前": Vector2(400, 556),
    "o17-垄间": Vector2(400, 590), "o18-篱笆后": Vector2(300, 440), "o19-枇杷树间": Vector2(1000, 760),
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
    m.orchard_save.local_path = "user://shot_orchard.json"
    m.orchard_save.plots = {}
    m.ensure_canvas("orchard")
    m._show_canvas("orchard")
    m._goto("orchard")
    var b = m.orchard
    b.save = m.orchard_save
    b.fake_now = 1_789_876_800.0
    b.refresh_fruit()
    b.walking_enabled = false
    m.dialog.visible = false
    await create_timer(0.8).timeout
    var n := 0
    var locs := {}
    for k in SPOTS:
        var sp: Vector2 = SPOTS[k]
        if not b._free(sp):
            var nc: Vector2i = b._nearest_free(b._cell_of(sp))
            sp = Vector2((nc.x + 0.5) * b.cell, (nc.y + 0.5) * b.cell)
        b.reset_to(sp)
        b.cam.reset_smoothing()
        await frames(6)
        await RenderingServer.frame_post_draw
        var img: Image = get_root().get_texture().get_image()
        img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], k])
        var c: Vector2 = b.cam.get_screen_center_position()
        var vs: Vector2 = Vector2(m.view.get_child(0).size)
        var scr: Vector2 = (sp - c) * b.cam.zoom.x + vs * 0.5
        locs[k] = [scr.x, scr.y, b.cam.zoom.x, float(get_root().size.x) / 540.0, sp.x, sp.y]
        n += 1
    for p in b.plots:
        m.orchard_save.mark_plot(p["id"], b.now())
    b.refresh_fruit()
    for k in ["o02-草莓点", "o03-枇杷点", "o17-垄间"]:
        var sp2: Vector2 = Vector2(locs[k][4], locs[k][5])
        b.reset_to(sp2)
        b.cam.reset_smoothing()
        await frames(6)
        await RenderingServer.frame_post_draw
        var img2: Image = get_root().get_texture().get_image()
        img2.save_png("%s/%s-%s-收完没果.png" % [opt["dir"], opt["tag"], k])
    var f := FileAccess.open("%s/%s-locs.json" % [opt["dir"], opt["tag"]], FileAccess.WRITE)
    f.store_string(JSON.stringify(locs))
    f.close()
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
