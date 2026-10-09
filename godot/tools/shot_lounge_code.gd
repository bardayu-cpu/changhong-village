extends SceneTree
## 休息间代码小人截图（03，10/4，测 build57 第 61 版用）：窗口按 --resolution 开，存整个窗口（带界面）。
## 出：chat（四位坐着冒泡）、walk_down/left/right/up（叔叔迈步四个方向，人站旁边）、talk（跟阿姨说话她站起来 + 对话框）、sit（玩家坐北边沙发中间、奶奶爷爷在两头）
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

func shot(name: String) -> void:
    await frames(8)
    await RenderingServer.frame_post_draw
    var img: Image = get_root().get_texture().get_image()
    img.save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_lcode_court.json"
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
    b.walking_enabled = true
    await create_timer(0.6).timeout
    life.frozen = true
    for id in life.bubbles.keys():
        life._hide_bubble(id)
    b.reset_to(Vector2(470, 610))
    b.face = "up"
    b.cam.reset_smoothing()
    await frames(20)
    life.show_bubble("lounge_10", str(life.data["chat"][0]["lines"][1][1]))
    life.show_bubble("lounge_05", str(life.data["chat"][1]["lines"][0][1]))
    await frames(10)
    await shot("1-chat")
    for id in life.bubbles.keys():
        life._hide_bubble(id)
    var u: Dictionary = life.person("lounge_05")
    var k := 2
    for dir in ["down", "left", "right", "up"]:
        u["foot"] = Vector2(530, 500)
        u["mode"] = "walk"
        u["face"] = dir
        u["walk_t"] = 0.15
        life._head(u)
        life._pose(u, 0.15)
        b.reset_to(Vector2(470, 560))
        b.cam.reset_smoothing()
        await frames(12)
        await shot("%d-walk_%s" % [k, dir])
        k += 1
    u["foot"] = u["home"]
    u["mode"] = "sit"
    u["face"] = u["seat_face"]
    life._head(u)
    life._pose(u, 0.0)
    life.frozen = false
    b.reset_to(Vector2(504, 470))
    life.request_talk("lounge_06")
    for i in 600:
        await process_frame
        if ui.talk_box.visible:
            break
    await frames(20)
    await shot("6-talk")
    ui.close_talk()
    await frames(30)
    life.frozen = true
    var sm: Dictionary = life.seat_by_id("sofa_m")
    b.reset_to(sm["stand"])
    life.sit(sm)
    b.cam.reset_smoothing()
    for i in 80:
        await process_frame
    ui.sync()
    await shot("7-sit")
    print("SHOT DONE ", get_root().size)
    quit(0)
