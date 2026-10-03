extends SceneTree
## 后厅手机屏截图（03，10/3，测 lounge01 用）：窗口按 --resolution 开（540x960 或长屏 585x1266），人站到每个关键点，存整个窗口（带界面）。
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_phone_backhall.gd -- --dir=目录 [--tag=p]
## 每个点存 <dir>/<tag>-<名字>.png；出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p", "canvas": "backhall", "spots": ""}
var SPOTS := {}
var CANVAS := "backhall"

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and "=" in a:
            var kv := a.substr(2).split("=", true, 1)
            opt[kv[0]] = kv[1]
    CANVAS = str(opt["canvas"])
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
    m.court_save.local_path = "user://shot_spots_court.json"
    m.ensure_canvas(CANVAS)
    m._show_canvas(CANVAS)
    m._goto(CANVAS)
    var b = {"backhall": m.backhall, "lawn": m.lawn, "lake": m.lake, "parking": m.parking}[CANVAS]
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
    var f := FileAccess.open("%s/%s-locs.json" % [opt["dir"], opt["tag"]], FileAccess.WRITE)
    f.store_string(JSON.stringify(locs))
    f.close()
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
