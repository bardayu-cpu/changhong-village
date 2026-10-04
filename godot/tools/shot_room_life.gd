extends SceneTree
## 07 10/4：麻将室、化妆间活起来的手机截图（冒泡、对话框、选项、走动）。要有窗口：
##   Godot --path . --resolution 540x960 --script res://tools/shot_room_life.gd -- --dir=目录 [--tag=p]
## 长屏用 --resolution 585x1266（1170×2532 的一半）。每张存 <dir>/<tag>-<名字>.png，出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "tag": "p"}
var n := 0

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

func frames(k: int) -> void:
    for i in k:
        await process_frame

func shot(name: String) -> void:
    await frames(8)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])
    n += 1

func life_by(b, room: String):
    for lf in b.lives:
        if lf.room == room:
            return lf
    return null

func quiet(b) -> void:
    for lf in b.lives:
        lf.frozen = true
        for id in lf.bubbles.keys():
            lf._hide_bubble(id)

## 点他、等对话框出来；到第 to 句（有选项那句停住）
func talk(b, lf, id: String, to: int) -> void:
    var ui = m.lounge_ui
    lf.request_talk(id)
    for i in 900:
        await process_frame
        if ui.talk_box.visible:
            break
    await frames(6)
    for k in to:
        if ui.choices.visible:
            break
        ui.next_line()
        await frames(6)

func close(b) -> void:
    var ui = m.lounge_ui
    ui.close_talk()
    await frames(4)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_rl_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    var b = m.backhall
    var ui = m.lounge_ui
    ui.attach(b.lounge)
    m.dialog.visible = false
    m.hint.visible = false
    b.walking_enabled = true
    var mj = life_by(b, "mahjong")
    var mk = life_by(b, "makeup")
    await create_timer(0.6).timeout
    # 1 麻将室冒泡：四组各冒一句
    quiet(b)
    b.reset_to(Vector2(700, 640))
    b.face = "up"
    b.cam.reset_smoothing()
    await frames(20)
    mj.show_bubble("elder_e", "碰！")
    mj.show_bubble("card_w", "我看看")
    mj.show_bubble("mj3_e", "这把稳了")
    mj.show_bubble("elder_6", "你嘛")
    await shot("1-麻将室冒泡")
    quiet(b)
    # 2、3 跟大爷说话、选项
    for lf in b.lives:
        lf.frozen = false
    await talk(b, mj, "elder_n", 0)
    await shot("2-麻将室大爷对话框")
    await talk_rest(ui)
    await shot("3-麻将室大爷选项")
    await close(b)
    # 4 打牌的妹妹起身走到糖果桌
    var p: Dictionary = mj.people["card_e"]
    p["wait"] = 0.0
    b.reset_to(Vector2(700, 640))
    b.cam.reset_smoothing()
    for i in 1200:
        await process_frame
        if str(p["mode"]) == "walk" and (p["foot"] as Vector2).y > 420.0:
            break
    quiet(b)
    await shot("4-麻将室妹妹走动")
    for lf in b.lives:
        lf.frozen = false
    # 5 化妆间冒泡
    quiet(b)
    b.reset_to(Vector2(1370, 420))
    b.face = "up"
    b.cam.reset_smoothing()
    await frames(20)
    mk.show_bubble("makeup_1", "头抬高一点")
    mk.show_bubble("makeup_2", "耳环拿来了")
    await shot("5-化妆间冒泡")
    quiet(b)
    for lf in b.lives:
        lf.frozen = false
    # 6 新娘选项
    await talk(b, mk, "bride", 5)
    await shot("6-化妆间新娘选项")
    await close(b)
    # 7 化妆助理走动
    var q: Dictionary = mk.people["makeup_2"]
    q["wait"] = 0.0
    for i in 1500:
        await process_frame
        if str(q["mode"]) == "walk" and (q["foot"] as Vector2).y < 420.0:
            break
    quiet(b)
    await shot("7-化妆间助理走动")
    print("SHOT DONE ", n)
    quit()

func talk_rest(ui) -> void:
    for k in 6:
        if ui.choices.visible:
            break
        ui.next_line()
        await frames(6)
