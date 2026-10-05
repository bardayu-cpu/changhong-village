extends SceneTree
## 化妆间（单独那间）手机屏截图（庄Z2 10/5，化妆间-gpt接入-2）：人站到几个看遮挡的点，存整个窗口（带界面）。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_makeup_room.gd -- --dir=目录 [--tag=手机]
## 长屏 1170×2532 用 --resolution 540x1168。每个点存 <dir>/<tag>-<名字>.png；出完打「SHOT DONE n」
## --set=125：化妆间家具 1.25 倍那版（675×1200）的机位：四个看遮挡的点 ×1.25，再加走到最左、最右看镜头跟不跟
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "手机", "set": ""}
const SPOTS := {   # 脚点（画布坐标）；站不了的格子挪到最近能站的
    "1-化妆台前": Vector2(223, 170), "2-首饰柜后（露半身）": Vector2(232, 490), "3-试衣间": Vector2(138, 712), "4-沙发后": Vector2(94, 750),
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
    m._show_canvas("makeup")
    m._goto("makeup")
    m.dialog.visible = false
    var a = m._canvas_by("makeup")
    a.walking_enabled = false
    await create_timer(0.8).timeout
    var spots := SPOTS
    if str(opt["set"]) == "125":
        spots = {"1-化妆台前": Vector2(279, 212), "2-首饰柜后（露半身）": Vector2(300, 612), "3-试衣间": Vector2(172, 890),
            "4-沙发后": Vector2(117, 937), "5-走到最左": Vector2(30, 660), "6-走到最右": Vector2(645, 660)}
    var n := 0
    for k in spots:
        var p: Vector2 = a.nearest_free(spots[k])
        a.reset_to(p)
        a.cam.reset_smoothing()
        await create_timer(0.4).timeout
        await RenderingServer.frame_post_draw
        get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], k])
        print("SHOT ", k, " 脚点 ", p)
        n += 1
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
