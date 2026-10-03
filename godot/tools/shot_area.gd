extends SceneTree
## 截后厅、草坪、湖边、果园：1:1、没界面（02 10/3，代码画的像素成品要逐像素跟样板对，整块图不能被窗口缩放糊掉）。
## 照 shot_court.gd 的做法：起 main、走截图预设 <画布>_overview 进去，把那块子画面设成要的大小、镜头对准，存子画面；不改 main.gd。
## 要有窗口（headless 不出画面）：
##   Godot --path . --resolution 540x960 --script res://tools/shot_area.gd -- --canvas=backhall --out=图.png [--rect=x,y,w,h] [--zoom=1] [--people=1]
##   --canvas   backhall / lawn / lake / orchard
##   --rect     画布上哪一块，默认整块
##   --people=0 藏人（玩家、站桩的人）；1 留着
## 出完打一行「SHOT SAVED <路径> <宽>x<高>」；出错打「SHOT FAILED 原因」，退出码 1
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"canvas": "backhall", "rect": "", "zoom": "1", "out": "", "people": "1"}

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
    var cn := str(opt["canvas"])
    if str(opt["out"]) == "" or not cn in ["backhall", "lawn", "lake", "orchard"]:
        fail("要 --out= 和 --canvas=backhall|lawn|lake|orchard")
        return
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    await m._setup_shot(cn + "_overview")
    await frames(10)
    var c = m.get(cn)
    var size := Vector2(float(c.cfg["size"][0]), float(c.cfg["size"][1]))
    var rect := Rect2(Vector2.ZERO, size)
    if str(opt["rect"]) != "":
        var r: PackedStringArray = str(opt["rect"]).split(",")
        rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
    var zoom: float = float(opt["zoom"])
    if str(opt["people"]) == "0":
        for id in c.npc_nodes:
            (c.npc_nodes[id] as CanvasItem).visible = false
        if c.player != null:
            c.player.visible = false
    for n in [m.hud, m.dialog, m.note_box, c.get("exit_mark"), c.get("kitchen_arrow")]:
        if n != null:
            (n as CanvasItem).visible = false
    c.set_process(false)
    var out_size := Vector2i(int(round(rect.size.x * zoom)), int(round(rect.size.y * zoom)))
    var sv: SubViewport = m.view.get_child(0)
    m.view.stretch = false
    sv.size = out_size
    await frames(5)
    c.cam.limit_left = -100000
    c.cam.limit_top = -100000
    c.cam.limit_bottom = 100000
    c.cam.limit_right = 100000
    c.cam.zoom = Vector2(zoom, zoom)
    c.cam.position = rect.get_center()
    c.cam.reset_smoothing()
    await frames(10)
    await RenderingServer.frame_post_draw
    var img: Image = sv.get_texture().get_image()
    if img.save_png(str(opt["out"])) != OK:
        fail("存不下 %s" % opt["out"])
        return
    print("SHOT SAVED ", opt["out"], " ", img.get_width(), "x", img.get_height())
    quit(0)
