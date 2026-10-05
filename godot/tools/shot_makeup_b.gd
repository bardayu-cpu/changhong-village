extends SceneTree
## 化妆间手机屏截图（03 10/5，测 makeup-gpt-1）：进屋第一眼、站在各处、跟人说话（对话框开着）。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_makeup_b.gd -- --dir=目录 --tag=p
## 每个场景存 <dir>/<tag>-<名字>.png，出完打「SHOT DONE n」
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

func snap(name: String) -> void:
    await frames(8)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])

func enter_room() -> void:
    m.switching = false
    if m.lounge_ui.is_open():
        m.lounge_ui.hide_all()
    m.dialog.visible = false
    m._show_canvas("makeup")
    m._goto("makeup")
    await frames(4)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_mkb_court.json"
    m.court_save.signed_in = true
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")
    var r = m.areas["makeup"]
    var n := 0
    # 1 进屋第一眼（刚进来，屋名框还在）
    await enter_room()
    r.reset_to(r.SPAWN)
    await snap("1-进门第一眼")
    n += 1
    # 2 走到最里（北边化妆台前）、3 站在首饰柜后（红毯中间）、4 沙发旁
    var spots := {"2-走到最里化妆台前": Vector2(260, 190), "3-红毯中间首饰柜旁": Vector2(290, 480), "4-试衣间前": Vector2(138, 725), "5-沙发区": Vector2(250, 800)}
    for k in spots:
        r.reset_to(spots[k])
        r.cam.reset_smoothing()
        await snap(k)
        n += 1
    # 6 跟新娘 / 化妆师 / 助理说话（对话框开着，镜头上抬）
    for pr in [["bride", "6-跟新娘说话"], ["makeup_1", "7-跟化妆师说话"], ["makeup_2", "8-跟化妆助理说话"]]:
        await enter_room()
        r.reset_to(r.SPAWN)
        m.lounge_ui.open_talk(pr[0])
        for i in 200:
            await process_frame
            if m.lounge_ui.talk_box.visible and m.lounge_ui.line_label.text != "":
                break
        # 走过去的话（approach）等一下
        await frames(20)
        await snap(pr[1])
        n += 1
        m.lounge_ui.close_talk()
        await frames(4)
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
