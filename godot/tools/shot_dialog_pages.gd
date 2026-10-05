extends SceneTree
## 罗-11 点框也翻页的截图（庄Z2 10/5）：后厅每间屋找一位能说话的人，让他说一句超过 2 行的话，拍第一页，再点框（不点三角）翻到第二页拍一张；
## 阿鱼说话那个框也一样。存整个窗口。要窗口：
## Godot --path . --resolution 540x960 --script res://tools/shot_dialog_pages.gd -- --dir=目录 [--tag=手机]
## 每间存 <dir>/<tag>-<屋>-1第一页.png、-2点框翻到第二页.png；出完打「SHOT DONE n」
const Main = preload("res://scripts/main.gd")
const DSkin = preload("res://scripts/ui/dialog_skin.gd")
const LONG := "今天这天气真好，早上还有点凉，到中午就暖和了。等下开席有红烧肉、清蒸鱼，还有一锅老鸭汤，听说炖了一上午，你待会儿多吃点，别光顾着拍照。"
var m
var started := false
var opt := {"dir": "", "tag": "手机"}

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
    await frames(4)
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png("%s/%s-%s.png" % [opt["dir"], opt["tag"], name])
    print("SHOT ", name)

## 点框：真的往对话框中间送一下鼠标（不点三角）
func click_box(box: Control) -> void:
    var r := box.get_global_rect()
    var p := Vector2(r.position.x + r.size.x * 0.45, r.position.y + r.size.y * 0.35)
    for down in [true, false]:
        var e := InputEventMouseButton.new()
        e.button_index = MOUSE_BUTTON_LEFT
        e.pressed = down
        e.position = p
        e.global_position = p
        get_root().push_input(e)
        await frames(2)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://shot_dialog_pages_court.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    m.dialog.visible = false
    var b = m.backhall
    var ui = m.lounge_ui
    b.walking_enabled = true
    ui.attach(b.lounge)
    await create_timer(0.6).timeout
    var n := 0
    var done := {}
    for lf in b.lives:
        var room := str(lf.room)
        if done.has(room):
            continue
        var id := ""
        for k in lf.people:
            if lf.can_talk(str(k)):
                id = str(k)
                break
        if id == "":
            continue
        done[room] = true
        if ui.is_open():
            ui.hide_all()
        b.reset_to(b.nearest_free(lf.approach_of(id)))
        b.cam.reset_smoothing()
        lf.request_talk(id)
        for i in 60:
            await process_frame
            if ui.talk_box.visible:
                break
        ui.line_label.text = LONG + "（%s）" % room   # 每间句子不一样：一样的话对话框当成没换句，页码不归零
        await frames(3)
        DSkin.finish(ui.talk_box)
        await snap("%s-1第一页" % room)
        await click_box(ui.talk_box)
        await snap("%s-2点框翻到第二页" % room)
        n += 2
    # 阿鱼说话
    if ui.is_open():
        ui.hide_all()
    m._say(LONG + "（阿鱼）", 30.0)
    await frames(3)
    DSkin.finish(m.dialog)
    await snap("阿鱼说话-1第一页")
    await click_box(m.dialog)
    await snap("阿鱼说话-2点框翻到第二页")
    n += 2
    print("SHOT DONE ", n, " 窗口 ", get_root().size)
    quit(0)
