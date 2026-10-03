extends SceneTree
## 对话插件截图（03，10/4，测 dialogue01 第 62 版用）：窗口按 --resolution 开（540x960 或长屏 585x1266），存整个窗口（带界面）。
## 出：1-first（点奶奶，第一句，笑）、2-second（第二句）、3-choices（问「你是哪边的客人呀？」出三个选项）、4-reply（选了第一个，奶奶回话）、5-last（最后一句）、
##   6-court（迎宾院里临时给新娘妈妈挂奶奶那段，点她，出选项）、7-card（有选项时开身份卡）
const Main = preload("res://scripts/main.gd")
const DLG := "res://assets/backhall/dialogue/lounge_09.dialogue"
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

func shot(name: String) -> void:
    await frames(10)
    await RenderingServer.frame_post_draw
    var img: Image = get_root().get_texture().get_image()
    img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])

func click(ui) -> void:
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    ui.talk_box.gui_input.emit(ev)

func wait_talk(ui) -> void:
    for i in 600:
        await process_frame
        if ui.talk_box.visible and ui.line_label.text != "":
            return

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_dlg_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    var b = m.backhall
    var life = b.lounge
    var ui = m.lounge_ui
    ui.attach(life)
    m.dialog.visible = false
    m.hint.visible = false
    await create_timer(0.6).timeout
    life.frozen = true
    for id in life.bubbles.keys():
        life._hide_bubble(id)
    b.reset_to(Vector2(504, 470))
    b.face = "up"
    b.cam.reset_smoothing()
    life.request_talk("lounge_09")
    await wait_talk(ui)
    await shot("1-first")
    click(ui)
    await frames(15)
    await shot("2-second")
    click(ui)
    await frames(15)
    await shot("3-choices")
    ui.card_btn.pressed.emit()
    await frames(6)
    await shot("7-card")
    ui.close_card()
    await frames(4)
    var btns: Array = ui.choices.get_children().filter(func(x): return not x.is_queued_for_deletion())
    (btns[0] as Button).pressed.emit()
    await frames(15)
    await shot("4-reply")
    click(ui)
    await frames(15)
    await shot("5-last")
    click(ui)
    await frames(20)
    # 迎宾院：临时给新娘妈妈挂奶奶那段
    m.switching = false
    m._show_canvas("court")
    m._goto("court")
    var c = m.court
    c.walking_enabled = true
    var foot := Vector2(1060, 590)
    c.add_talker("bride_mom", foot, 84.0, DLG, "新娘妈妈（测试）", "LM-GUEST-09")
    c.reset_to(foot + Vector2(0, 120))
    c.cam.reset_smoothing()
    c.request_talker("bride_mom")
    await wait_talk(ui)
    click(ui)
    await frames(15)
    click(ui)
    await frames(15)
    await shot("6-court")
    c.talkers.erase("bride_mom")
    print("SHOT DONE ", get_root().size)
    quit(0)
