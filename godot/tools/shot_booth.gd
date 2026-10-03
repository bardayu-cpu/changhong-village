extends SceneTree
## 截后厅、草坪、湖边、果园（四块展位）：1:1、不放人、没界面、不写字（03，10/3；给 GPT 出四块色块参考的「现状图」用，照 shot_court.gd 的做法，不改 main.gd）
## 要有窗口（headless 不出画面）：Godot --path . --resolution 540x960 --script res://tools/shot_booth.gd -- --scene=lawn --out=图.png [--world=1] [--labels=0] [--people=0]
##   --scene=backhall|lawn|lake|orchard   哪一块；画布多大按布局文件里的 size（后厅、草坪 1536×1024，湖边、果园 1536×1280）
##   --labels=0 藏灰盒上的「化妆室」「去果园」那些字（图上不写字）；1 留着
##   --world=0 桌椅、树、船、墙这些物件整层都藏，只剩地面和路（量物件框时拿它跟带物件的那张做差）；1 留着
##   --people=1 人和草坪的球、喜多留着（给对人的位置用）；0 全藏（默认）
## 出完打一行「SHOT SAVED <路径> <宽>x<高>」；出错打「SHOT FAILED 原因」，退出码 1
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"scene": "", "zoom": "1", "out": "", "labels": "0", "world": "1", "people": "0"}

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
    var which := str(opt["scene"])
    if str(opt["out"]) == "" or not which in ["backhall", "lawn", "lake", "orchard"]:
        fail("要 --scene=backhall|lawn|lake|orchard 和 --out=")
        return
    var zoom: float = float(opt["zoom"])
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.ensure_canvas(which)
    m._show_canvas(which)
    m._goto(which)
    await create_timer(1.0).timeout
    m.dialog.visible = false
    m.hint.visible = false
    var c = m.cv
    var sz: Array = c.cfg["size"]
    var rect := Rect2(0, 0, float(sz[0]), float(sz[1]))
    if str(opt["people"]) == "0":
        for n in [c.player, c.tag_anchor, c.sign_mark, c.sign_arrow]:
            if n != null:
                n.visible = false
        for id in c.npc_nodes:
            (c.npc_nodes[id] as CanvasItem).visible = false
        for k in ["ball", "dog", "couple"]:
            var nd = c.get(k)
            if nd is CanvasItem:
                (nd as CanvasItem).visible = false
        # 后厅：东边厨房里来回走的两位服务员，和指向厨房的金箭头（屏幕边上那个）
        var kw = c.get("kitchen_walkers")
        if kw is Array:
            for w in kw:
                (w as CanvasItem).visible = false
        var ka = c.get("kitchen_arrow")
        if ka is CanvasItem:
            (ka as CanvasItem).visible = false
        var cp = c.world.get_node_or_null("couple")
        if cp != null:
            cp.visible = false
        for ch in c.world.get_children():
            if str(ch.name).begins_with("walker_"):
                (ch as CanvasItem).visible = false
    if str(opt["labels"]) == "0" and c.labels != null:
        c.labels.visible = false
    if str(opt["world"]) == "0":
        c.world.visible = false
    if c.exit_mark != null:
        c.exit_mark.visible = false
    for n in [m.hud, m.dialog, m.note_box]:
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
