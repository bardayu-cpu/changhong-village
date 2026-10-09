extends SceneTree
## 后厅手机屏截图（03，10/3，测 lounge01 用）：窗口按 --resolution 开（540x960 或长屏 585x1266），人站到每个关键点，存整个窗口（带界面）。
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_phone_backhall.gd -- --dir=目录 [--tag=p]
## 每个点存 <dir>/<tag>-<名字>.png；出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p"}
const SPOTS := {
    "l01-休息间门口": Vector2(504, 672), "l02-北茶座前": Vector2(567, 336), "l03-唱片机前": Vector2(424, 312), "l04-唱片箱旁": Vector2(372, 312),
    "l05-西小茶几前": Vector2(433, 432), "l06-西小茶几旁": Vector2(376, 430), "l07-看书角前": Vector2(404, 604), "l08-看书角里": Vector2(440, 580),
    "l09-电视前": Vector2(616, 476), "l10-电视沙发西": Vector2(534, 420), "l11-东南双人沙发前": Vector2(596, 604), "l12-衣帽架旁": Vector2(580, 666),
    "l13-金桔旁": Vector2(650, 662), "l14-最北": Vector2(500, 262), "l15-休息间中间": Vector2(504, 520), "l16-书架前": Vector2(378, 360),
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
