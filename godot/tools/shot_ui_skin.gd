extends SceneTree
## 冒泡、对话框三种样子（scripts/ui/dialog_skin.gd，05 10/4）同一机位的手机截图：每种样子跑一遍，出这几张（存整个窗口）：
##   bubbles   麻将室两个人在冒泡（同屏最多两个），再加两个「这里能点」的提示泡（只出样子）
##   talk      点大爷：对话框、名字牌、身份卡、选项开着（翻到有选项那句）
##   type1～3  大爷第一句，字一个个出来的连拍（开头、一半、出完带小三角）
##   bride     化妆间新娘：没头像时框怎么摆
##   ayu       阿鱼说话（原来屏幕上边那条，换到下面同一个框）
##   edge      走到头：人头顶冒一句
## 要窗口：Godot --path . --resolution 540x960 --script res://tools/shot_ui_skin.gd -- --dir=目录 --ui_skin=A
## 长屏用 --resolution 585x1266。每张存 <dir>/<样子>-<名字>.png，出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"dir": "", "ui_skin": "A"}
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
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], str(opt["ui_skin"]).to_upper(), name])
    n += 1

func life_by(b, room: String):
    for l in b.lives:
        if l.room == room:
            return l
    return null

func quiet(b) -> void:
    for lf in b.lives:
        lf.frozen = true
        for id in lf.bubbles.keys():
            lf._hide_bubble(id)

func open_talk(b, ui, lf, id: String, to_choice: bool) -> void:
    if ui.is_open():
        ui.close_talk()
    await frames(2)
    b.reset_to(b.nearest_free(lf.approach_of(id)))
    b.cam.reset_smoothing()
    lf.request_talk(id)
    for i in 90:
        await process_frame
        if ui.talk_box.visible:
            break
    await frames(6)
    if to_choice:
        for k in 4:
            if ui.talk_box.visible and not ui.choices.visible:
                ui.next_line()
                await frames(10)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_ui_skin_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    m.dialog.visible = false
    var b = m.backhall
    var ui = m.lounge_ui
    b.walking_enabled = true
    ui.attach(b.lounge)
    await create_timer(0.6).timeout
    var mj = life_by(b, "mahjong")
    var mk = life_by(b, "makeup")
    # 冒泡：麻将室两个人
    quiet(b)
    b.reset_to(Vector2(700, 640))
    b.cam.reset_smoothing()
    await frames(10)
    mj.show_bubble("elder_n", "我听牌了哦")
    mj.show_bubble("elder_6", "眼睛花了，看不清")
    # 「这里能点」的提示泡：只出样子（什么时候出、出在谁头上以后交 07），放在麻将室能聊的人头顶（除了正冒泡的两位）
    var Skin = load("res://scripts/ui/dialog_skin.gd")
    var hints: Array = []
    for id in mj.people:
        if hints.size() >= 2:
            break
        if id in ["elder_n", "elder_6"] or not mj.can_talk(id):
            continue
        var h: Node2D = Skin.tap_hint("talk")
        h.position = (mj.people[id]["head"] as Vector2) + Vector2(0, -4)
        h.scale = Vector2.ONE / maxf(b.cam.zoom.x, 0.2)
        mj.add_child(h)
        hints.append(h)
    await frames(20)
    await shot("bubbles")
    for h in hints:
        h.queue_free()
    quiet(b)
    # 大爷：选项那句
    await open_talk(b, ui, mj, "elder_n", true)
    await frames(10)
    await shot("talk")
    # 字一个个出：大爷第一句，打字开着
    ui.close_talk()
    await frames(4)
    await open_talk(b, ui, mj, "elder_n", false)
    var typer = ui.talk_box.get_node("typer")
    typer.instant = false
    ui.line_label.text = ""
    await frames(1)
    ui.line_label.text = "你会不会打麻将？我们这桌三缺一。"
    await frames(4)
    await shot("type1")
    await create_timer(0.35).timeout
    await shot("type2")
    await create_timer(1.2).timeout
    await shot("type3")
    typer.instant = true
    ui.close_talk()
    await frames(4)
    # 新娘：没头像
    await open_talk(b, ui, mk, "bride", true)
    await frames(10)
    await shot("bride")
    ui.close_talk()
    await frames(4)
    # 阿鱼说话
    b.reset_to(Vector2(700, 640))
    b.cam.reset_smoothing()
    await frames(6)
    m._say("到啦～ 罗曼山庄 席还没散", 0.0)
    await frames(10)
    await shot("ayu")
    m.dialog.visible = false
    # 走到头
    m._on_edge_bump("up")
    await frames(10)
    await shot("edge")
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
