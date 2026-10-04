extends SceneTree
## 手机视角截一块画布（沙盒截图，01 G 10/4 派：新地图先出沙盒截图给阿鱼，过了再让 GPT 画效果图）：
## 进到那块、人站在 --at、朝 --face，镜头照游戏自己的跟人走，截整个窗口（带界面，跟手机上看到的一样）。不改 main.gd
## 要有窗口：Godot --path . --resolution 540x960 --script res://tools/shot_view.gd -- --canvas=plaza --at=768,820 [--face=up] --out=图.png
## 出完打一行「SHOT SAVED <路径> <宽>x<高>」；出错打「SHOT FAILED 原因」，退出码 1
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"canvas": "plaza", "at": "", "face": "up", "out": ""}

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

func fail(why: String) -> void:
    print("SHOT FAILED ", why)
    quit(1)

func frames(n: int) -> void:
    for i in n:
        await process_frame

func run() -> void:
    if str(opt["out"]) == "":
        fail("没给 --out=")
        return
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "阿花"
    m.cloud.fake_no_news = true
    await m._enter_court()
    var cn := str(opt["canvas"])
    m.ensure_canvas(cn)
    m._show_canvas(cn)
    m._goto(cn)
    for i in 300:   # 等换块那一下淡出淡入走完（不等的话偶尔截到一整屏深灰）
        await process_frame
        if not m.switching and m.fade.color.a < 0.01:
            break
    var c = m.cv
    if str(opt["at"]) != "":
        var xy: PackedStringArray = str(opt["at"]).split(",")
        c.reset_to(Vector2(float(xy[0]), float(xy[1])))
    c.face = str(opt["face"])
    await frames(10)
    if c.has_method("snap_cam"):
        c.snap_cam()
    m.dialog.visible = false
    m.note_box.visible = false
    await create_timer(0.6).timeout
    m.dialog.visible = false
    m.note_box.visible = false
    await frames(5)
    await RenderingServer.frame_post_draw
    var img: Image = get_root().get_texture().get_image()
    if img.save_png(str(opt["out"])) != OK:
        fail("存不下 %s" % opt["out"])
        return
    print("SHOT SAVED ", opt["out"], " ", img.get_width(), "x", img.get_height())
    quit(0)
